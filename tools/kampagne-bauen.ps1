<#
.SYNOPSIS
  Baut die Kampagne "Die Smaragdinseln" (6 eigene Szenarien) fuer Anno 1602 History Edition.

.DESCRIPTION
  Grundlage sind die Endlos-Vorlagen Szenes\[[48]]<Schwierigkeit><Anordnung>.szs (nur gelesen).
  Je Kapitel: gespiegelte Inselanordnung (damit jede Karte anders aussieht und das Werkzeug sie
  nicht als Endlos-Vorlage erkennt), eigene Rohstoffmengen, Ureinwohner, Startgold, Schwierigkeit,
  Piraten und ein Auftrag mit Text. Die Karten sind fuer 500 x 350 gebaut und laufen damit auch ohne
  Erweiterungen. Dazu traegt jedes Kapitel eine grosse Fassung fuer 1000 x 700 (bis 50 Inseln, mit dem
  Inselplaner des Werkzeugs, mitwachsenden Rohstoffen und mehr Doerfern) hinter dem SZENE-Abschnitt
  (Kennung 'GROS', siehe weltgroesse.ps1 "Grosse Kampagnenkarten"). Das Werkzeug nimmt sie, wenn die
  Karte mindestens 1000 x 700 gross ist und "Mehr Inseln" gewaehlt ist; sonst gilt die kleine Fassung.

  Ausgabe: tools\kampagne\*.szs; mit -Installieren zusaetzlich nach
  Dokumente\Anno 1602 History Edition\Own Scenarios (erscheinen im Spiel unter "Eigene Szenarien").
#>
param([switch]$Installieren, [string]$Spielpfad)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'szenario-bauer.ps1')

if (-not $Spielpfad) {
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $Spielpfad = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
    }
}
if (-not $Spielpfad) { $Spielpfad = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition' }
$Szenes = Join-Path $Spielpfad 'Szenes'
$Ausgabe = Join-Path $PSScriptRoot 'kampagne'
New-Item -ItemType Directory -Force -Path $Ausgabe | Out-Null

$KlasseB = @(30, 40, 50, 70, 100); $KlasseH = @(30, 40, 52, 60, 90)
# Inselplaner aus weltgroesse.ps1 (gleiche Regeln wie fuer das grosse Endlosspiel), per Syntaxbaum geladen.
$GrossB = 1000; $GrossH = 700
$werkzeugAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'weltgroesse.ps1'), [ref]$null, [ref]$null)
foreach ($stmt in $werkzeugAst.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function Inselplan\b') -or $txt -match '^\$(InselMax|InselDichte)\b') { . ([scriptblock]::Create($txt)) }
}
$RohMengenOffsets = @(0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE, 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE, 0x106, 0x10E, 0x116)
# SZENE: Rohstoffeintraege zu 8 Byte ab +0x94 (Haus-Nr. = Id - 20000, Menge = Zahl der Inseln).
$RohNr = @{ ErzKlein = 0x94; ErzGross = 0x9C; Gold = 0xA4; Schatz = 0x114 }
$Pflanze = @{ Baumwolle = 1332; Tabak = 1336; Kakao = 1338; Zucker = 1340; Gewuerze = 1342; Wein = 1344 }
# Monopol-Rohstoffe (Fruchtbarkeit, FUN_1400ae010): 0x2D Getreide, 0x2E Tabak, 0x2F Gewuerze, 0x30 Zucker,
# 0x31 Baumwolle, 0x32 Wein, 0x33 Kakao. Waren (Lager): 12 Musketen, 13 Kanonen, 16 Gewuerze, 21 Schmuck, 22 Werkzeug.

function Insel-Liste([byte[]]$szene) {
    $n = [BitConverter]::ToInt32($szene, 0x64)
    for ($i = 0; $i -lt $n; $i++) {
        $o = 0x174 + 16 * $i
        @{ Klima = $szene[$o]; Klasse = $szene[$o + 1]; X = [BitConverter]::ToInt32($szene, $o + 8); Y = [BitConverter]::ToInt32($szene, $o + 12); Dorf = $false; Datei = $null }
    }
}
# Spiegeln an der Kartenmitte; beim Spiegeln in y tauschen Nord- und Suedklima (Lage bleibt stimmig).
function Spiegle($inseln, [bool]$x, [bool]$y) {
    foreach ($e in $inseln) {
        $n = $e.Clone()
        if ($x) { $n.X = 500 - $e.X - $KlasseB[$e.Klasse] }
        if ($y) { $n.Y = 350 - $e.Y - $KlasseH[$e.Klasse]; if ($e.Klima -lt 2) { $n.Klima = 1 - $e.Klima } }
        $n
    }
}
function Pruefe-Karte($inseln, [string]$name, [int]$breite = 500, [int]$hoehe = 350) {
    for ($i = 0; $i -lt $inseln.Count; $i++) {
        $a = $inseln[$i]; $aw = $KlasseB[$a.Klasse]; $ah = $KlasseH[$a.Klasse]
        if ($a.X -lt 0 -or $a.Y -lt 0 -or $a.X + $aw -gt $breite -or $a.Y + $ah -gt $hoehe) { throw "$($name): Insel $i ausserhalb der Karte." }
        for ($j = $i + 1; $j -lt $inseln.Count; $j++) {
            $b = $inseln[$j]
            if ($a.X -lt $b.X + $KlasseB[$b.Klasse] -and $b.X -lt $a.X + $aw -and $a.Y -lt $b.Y + $KlasseH[$b.Klasse] -and $b.Y -lt $a.Y + $ah) { throw "$($name): Inseln $i und $j ueberschneiden sich." }
        }
    }
}
# Inseln vergroessern, wo die naechstgroessere Klasse frei bleibt (Abstand 6 Felder).
function Vergroessere($inseln, [int]$anzahl) {
    $n = 0
    for ($i = 0; $i -lt $inseln.Count -and $n -lt $anzahl; $i++) {
        $e = $inseln[$i]; if ($e.Klasse -ge 3) { continue }
        $k = $e.Klasse + 1; $frei = ($e.X + $KlasseB[$k] -le 494 -and $e.Y + $KlasseH[$k] -le 344)
        for ($j = 0; $j -lt $inseln.Count -and $frei; $j++) {
            if ($j -eq $i) { continue }; $b = $inseln[$j]
            if ($e.X -lt $b.X + $KlasseB[$b.Klasse] + 6 -and $b.X -lt $e.X + $KlasseB[$k] + 6 -and $e.Y -lt $b.Y + $KlasseH[$b.Klasse] + 6 -and $b.Y -lt $e.Y + $KlasseH[$k] + 6) { $frei = $false }
        }
        if ($frei) { $e.Klasse = $k; $n++ }
    }
}
# Startschiffe: Die Schiffspositionen (SHIP4 +0x1C/+0x1E) werden nicht mitgestreckt, die Inseln schon.
# Gesucht wird ein Wasserpunkt, der in allen Kartenfassungen mindestens $Abstand Felder von jeder Insel
# entfernt ist: kleine Karte bei 500/750/1000/2000 Breite (Faktor 1, 1.5, 2, 4) und grosse Fassung bei
# 1000/2000 (Faktor 1, 2) - moeglichst nahe am Startpunkt der Vorlage.
function Inselrechtecke([byte[]]$s, [int]$o0, [double]$f) {
    $n = [BitConverter]::ToInt32($s, $o0 + 0x64)
    for ($i = 0; $i -lt $n; $i++) {
        $o = $o0 + 0x174 + 16 * $i; $c = $s[$o + 1]
        @{ X = [math]::Truncate([BitConverter]::ToInt32($s, $o + 8) * $f); Y = [math]::Truncate([BitConverter]::ToInt32($s, $o + 12) * $f); B = $KlasseB[$c]; H = $KlasseH[$c] }
    }
}
function Freier-Startpunkt([byte[]]$klein, [byte[]]$gross, [int]$x0, [int]$y0, [int]$abstand = 14) {
    $rechtecke = @()
    foreach ($f in 1, 1.5, 2, 4) { $rechtecke += @(Inselrechtecke $klein 0 $f) }
    foreach ($f in 1, 2) { $rechtecke += @(Inselrechtecke $gross 0 $f) }
    $best = $null; $bestD = [double]::MaxValue
    for ($y = 20; $y -le 330; $y += 2) {
        for ($x = 20; $x -le 480; $x += 2) {
            $d = [math]::Sqrt(($x - $x0) * ($x - $x0) + ($y - $y0) * ($y - $y0)); if ($d -ge $bestD) { continue }
            $frei = $true
            foreach ($r in $rechtecke) { if ($x -gt $r.X - $abstand -and $x -lt $r.X + $r.B + $abstand -and $y -gt $r.Y - $abstand -and $y -lt $r.Y + $r.H + $abstand) { $frei = $false; break } }
            if ($frei) { $best = @($x, $y); $bestD = $d }
        }
    }
    if (-not $best) { throw 'Kein freier Startpunkt fuer die Schiffe gefunden.' }
    , $best
}
function Setze-Menge([byte[]]$s, [int]$nr, [int]$menge) {
    for ($o = 0x94; $o -le 0x114; $o += 8) { if ([BitConverter]::ToUInt16($s, $o) -eq $nr) { Setze-U16 $s ($o + 2) $menge } }
}

function Baue-Kapitel($k) {
    $vorlage = Lies-Szenario (Join-Path $Szenes ('[[48]]{0}{1}.szs' -f $k.Schwierigkeit, $k.Anordnung))
    $szene = [byte[]](Abschnitt $vorlage 'SZENE').Daten.Clone()
    $inseln = @(Spiegle @(Insel-Liste $szene) $k.SpiegelX $k.SpiegelY)
    if ($k.Groesser) { Vergroessere $inseln $k.Groesser }
    if ($k.Klima -ne $null) { foreach ($e in $inseln) { $e.Klima = $k.Klima } }
    Pruefe-Karte $inseln $k.Datei
    Setze-Inseln $szene $inseln
    Setze-I32 $szene 0x40 $k.DoerferNord; Setze-I32 $szene 0x44 $k.DoerferSued
    if ($k.Mengen) { foreach ($m in $k.Mengen.GetEnumerator()) { if ($RohNr.ContainsKey($m.Key)) { Setze-U16 $szene ($RohNr[$m.Key] + 2) $m.Value } else { Setze-Menge $szene $Pflanze[$m.Key] $m.Value } } }

    # Grosse Fassung fuer 1000 x 700: Inselplaner, Rohstoffe mit der Inselzahl, mehr Doerfer.
    $gross = [byte[]]$szene.Clone()
    $klein16 = @(for ($i = 0; $i -lt $inseln.Count; $i++) { , [byte[]]$szene[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
    $plan = Inselplan $klein16 $GrossB $GrossH $false $k.GrossGroesse
    [Array]::Clear($gross, 0x174, 50 * 16)
    for ($i = 0; $i -lt $plan.Count; $i++) { [Array]::Copy($plan[$i], 0, $gross, 0x174 + 16 * $i, 16) }
    Setze-I32 $gross 0x64 $plan.Count
    foreach ($o in $RohMengenOffsets) {
        $m = [BitConverter]::ToUInt16($gross, $o)
        if ($m) { Setze-U16 $gross $o ([math]::Min($plan.Count, [int][math]::Round($m * $plan.Count / $inseln.Count))) }
    }
    $gd = if ($k.GrossDoerfer) { $k.GrossDoerfer } else { 5 }
    Setze-I32 $gross 0x40 $gd; Setze-I32 $gross 0x44 $gd
    if ($k.GrossMengen) { foreach ($m in $k.GrossMengen.GetEnumerator()) { if ($RohNr.ContainsKey($m.Key)) { Setze-U16 $gross ($RohNr[$m.Key] + 2) $m.Value } else { Setze-Menge $gross $Pflanze[$m.Key] $m.Value } } }
    Pruefe-Karte @(Insel-Liste $gross) ($k.Datei + ' (gross)') $GrossB $GrossH
    $kennung = New-Object byte[] 16
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('GROS'), $kennung, 4); Setze-I32 $kennung 4 $GrossB; Setze-I32 $kennung 8 $GrossH; Setze-I32 $kennung 12 1
    $szeneDatei = [byte[]]($szene + $kennung + $gross)

    # Startschiffe auf einen freien Wasserpunkt setzen (Abstaende untereinander wie in der Vorlage).
    $schiffe = [byte[]](Abschnitt $vorlage 'SHIP4').Daten.Clone()
    $sx0 = [BitConverter]::ToInt16($schiffe, 0x1C); $sy0 = [BitConverter]::ToInt16($schiffe, 0x1E)
    $start = Freier-Startpunkt $szene $gross $sx0 $sy0
    for ($i = 0; $i -lt $schiffe.Length / 0x1B4; $i++) {
        $o = $i * 0x1B4
        $dx = [BitConverter]::ToInt16($schiffe, $o + 0x1C) - $sx0; $dy = [BitConverter]::ToInt16($schiffe, $o + 0x1E) - $sy0
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $dx)), 0, $schiffe, $o + 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $dy)), 0, $schiffe, $o + 0x1E, 2)
    }
    # Zusaetzliche Startschiffe fuer den Menschen: Kopie seines Schiffs (Eintrag 0) mit neuem Platz
    # (+0x46), Figurtyp (+0x48: 21/23 kleines/grosses Handelsschiff, 25/27 kleines/grosses Kriegsschiff),
    # Laderaum (+0x3C, x 32) und voller Kanonenzahl (+0x42), ohne Ladung, neben dem Startpunkt.
    $FlotteWerte = @{ 21 = @(1600, 6); 23 = @(2560, 10); 25 = @(2080, 8); 27 = @(3840, 14) }
    $versatz = @(@(7, 4), @(8, -3), @(-9, 0))
    $n = 0
    foreach ($fs in @($k.Flotte | Where-Object { $_ })) {
        if ($n -ge $versatz.Count) { throw 'Hoechstens 3 zusaetzliche Startschiffe.' }
        $r = [byte[]]$schiffe[0..(0x1B4 - 1)]
        [Array]::Clear($r, 0, 0x18); $nb = [Text.Encoding]::GetEncoding(1252).GetBytes($fs.Name); [Array]::Copy($nb, $r, [math]::Min(0x17, $nb.Length))
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $versatz[$n][0])), 0, $r, 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $versatz[$n][1])), 0, $r, 0x1E, 2)
        Setze-U16 $r 0x3C $FlotteWerte[$fs.Typ][0]; $r[0x42] = [byte]$FlotteWerte[$fs.Typ][1]
        Setze-U16 $r 0x46 ($schiffe.Length / 0x1B4); Setze-U16 $r 0x48 $fs.Typ
        [Array]::Clear($r, 0x174, 0x1B4 - 0x174)
        $schiffe = [byte[]]($schiffe + $r); $n++
    }

    $spieler = [byte[]](Abschnitt $vorlage 'PLAYER4').Daten.Clone()
    for ($p = 0; $p -lt 7; $p++) { $spieler[$p * 0x430 + 0x0C] = 0xFF }
    $spieler[0x0C] = 0                                                   # Mensch: Auftrag 0
    # Wettlauf: die drei Computergegner bekommen denselben Auftrag; Zielbit 0x800 laesst sie gewinnen.
    # Erfuellt ein Gegner ihn zuerst, endet die Partie mit seinem Sieg (FUN_1400b0000, Nachricht 0x3E -> 0x53).
    if ($k.Wettlauf) { foreach ($p in 1..3) { $spieler[$p * 0x430 + 0x0C] = 0 } }
    Setze-I32 $spieler 0 $k.Gold
    foreach ($p in 1..3) { Setze-I32 $spieler ($p * 0x430) $k.GoldGegner }

    $timers = [byte[]](Abschnitt $vorlage 'TIMERS').Daten.Clone()
    $flags = [BitConverter]::ToInt32($timers, 0xA8)
    $flags = if ($k.Piraten) { $flags -band (-bnot 1) } else { $flags -bor 1 }   # Bit 0: Piraten nur gesichtet
    Setze-I32 $timers 0xA8 $flags
    # Gegnerstaerke ohne andere Vorlage (gleiche Karte): TIMERS +0xA6 = Schwierigkeit 0-3 (Spiel: 0x1405ec1c0).
    if ($k.ContainsKey('KI')) { $timers[0xA6] = [byte]$k.KI }

    $auftrag = $k.Auftrag.Clone(); $auftrag.Platz = 0; $auftrag.Text = $k.Text
    if ($k.Wettlauf) { $auftrag.AuchKI = $true }
    $liste = New-Object System.Collections.Generic.List[object]
    $liste.Add(@{ Name = 'SZENE_PLAYERMIN'; Daten = [BitConverter]::GetBytes([int32]1) })
    $liste.Add(@{ Name = 'SZENE_PLAYERMAX'; Daten = [BitConverter]::GetBytes([int32]0) })
    $liste.Add(@{ Name = 'SZENE_GAMEID'; Daten = [BitConverter]::GetBytes([int32](0x53D00000 + $k.Nr)) })
    $liste.Add(@{ Name = 'SZENE_RANKING'; Daten = [BitConverter]::GetBytes([int32]2) })
    foreach ($a in $vorlage) {
        switch ($a.Name) {
            'RANDTAB' { $liste.Add($a) }
            'SZENE' { $liste.Add(@{ Name = 'AUFTRAG4'; Daten = (Neuer-Auftrag $auftrag) }); $liste.Add(@{ Name = 'SZENE'; Daten = $szeneDatei }) }
            'PLAYER4' { $liste.Add(@{ Name = 'PLAYER4'; Daten = $spieler }) }
            'SHIP4' { $liste.Add(@{ Name = 'SHIP4'; Daten = $schiffe }) }
            'TIMERS' { $liste.Add(@{ Name = 'TIMERS'; Daten = $timers }) }
        }
    }
    $pfad = Join-Path $Ausgabe ($k.Datei + '.szs')
    Schreibe-Szenario $pfad $liste
    '{0,-36} {1,2} Inseln (gross {2}, {3}), Start {9},{10} (Vorlage {11},{12}), Schwierigkeit {4}, Piraten {5}, Gold {6}/{7}, Text {8}' -f $k.Datei, $inseln.Count, $plan.Count, $k.GrossGroesse, $(if ($k.ContainsKey('KI')) { '{0} (Gegner {1})' -f $k.Schwierigkeit, $k.KI } else { $k.Schwierigkeit }), $(if ($k.Piraten) { 'aktiv' } else { 'gesichtet' }), $k.Gold, $k.GoldGegner, $k.Text.Length, $start[0], $start[1], $sx0, $sy0
}

$Kapitel = @(
    @{ Nr = 1; GrossGroesse = 'Normal'; Datei = 'Smaragdinseln 1 - Landung'; Schwierigkeit = 0; Anordnung = 1; SpiegelX = $true; SpiegelY = $false
        Gold = 30000; GoldGegner = 15000; Piraten = $false; DoerferNord = 3; DoerferSued = 3
        Auftrag = @{ Staedte = @(@{ Einwohner = 250; Stufe = 1; Davon = 150 }); Bilanz = 0 }
        Text = @'
DIE SMARAGDINSELN - Kapitel 1: Landung

Gouverneur, nach elf Wochen auf See liegt sie vor uns: die Inselwelt, die unsere Kartographen die Smaragdinseln nennen. Die Handelskompanie hat Euch Schiff, Werkzeug und ein bescheidenes Startkapital anvertraut. Drei andere Häuser haben ebenfalls Schiffe ausgesandt - wer zuerst Fuss fasst, wird hier herrschen.

Euer Auftrag:
- Gründet eine Stadt mit mindestens 250 Einwohnern.
- Mindestens 150 davon sollen Siedler (oder höher) sein.
- Haltet die Bilanz Eurer Kolonie im Plus.

Rat des Steuermanns: Sucht eine grosse Insel mit Wald und fruchtbarem Boden nahe der Kartenmitte. Die Ureinwohner sind friedlich, solange Ihr sie in Ruhe lasst.
'@
    }
    @{ Nr = 2; GrossGroesse = 'Normal'; GrossMengen = @{ Gewuerze = 3 }; Datei = 'Smaragdinseln 2 - Gewuerzfieber'; Schwierigkeit = 1; Anordnung = 0; SpiegelX = $false; SpiegelY = $true
        Gold = 25000; GoldGegner = 25000; Piraten = $false; DoerferNord = 2; DoerferSued = 3
        Mengen = @{ Gewuerze = 2; Tabak = 4; Kakao = 4 }   # Monopol = alle Gewuerzinseln (das Spiel zaehlt sie beim Start, FUN_1400ceea0)
        Auftrag = @{ Monopol1 = @{ Rohstoff = 0x2F; Inseln = 1 }; Staedte = @(@{ Einwohner = 500; Stufe = 2; Davon = 250 }) }
        Text = @'
DIE SMARAGDINSELN - Kapitel 2: Gewürzfieber

In den Häfen der Alten Welt zahlt man für ein Fass Gewürze mehr als für ein ganzes Schiff. Auf diesem Archipel gibt es nur wenige Inseln, auf denen Gewürze gedeihen - und Eure Rivalen wissen das ebenso gut wie Ihr.

Euer Auftrag:
- Sichert Euch das Gewürzmonopol: Gründet auf JEDER Insel, auf der Gewürze wachsen, eine eigene Siedlung und duldet dort keine fremde. Es sind nur drei oder vier.
- Baut eine Stadt mit mindestens 500 Einwohnern, davon 250 Bürger oder höher.

Rat des Steuermanns: Erkundet früh mit dem Schiff, welche Inseln Gewürze tragen (Fruchtbarkeit im Inselinfo). Wer zu spät kommt, muss den Rivalen verdrängen.
'@
    }
    @{ Nr = 3; GrossGroesse = 'Gross'; Datei = 'Smaragdinseln 3 - Zwei Kolonien'; Schwierigkeit = 1; Anordnung = 2; SpiegelX = $true; SpiegelY = $true; Groesser = 3
        Gold = 30000; GoldGegner = 30000; Piraten = $false; DoerferNord = 2; DoerferSued = 2
        Auftrag = @{ Staedte = @(@{ Einwohner = 800; Stufe = 3; Davon = 300 }, @{ Einwohner = 500; Stufe = 2; Davon = 250 }); Bilanz = 300 }
        Text = @'
DIE SMARAGDINSELN - Kapitel 3: Zwei Kolonien

Die Kompanie ist zufrieden, doch eine einzige Stadt reicht ihr nicht. Im kalten Norden wachsen Getreide und Wein, im heissen Süden Zuckerrohr, Kakao und Tabak. Nur wer beide Welten verbindet, versorgt seine Kaufleute.

Euer Auftrag:
- Eine Hauptstadt mit mindestens 800 Einwohnern, davon 300 Kaufleute oder höher.
- Eine zweite Stadt mit mindestens 500 Einwohnern, davon 250 Bürger oder höher.
- Eine Bilanz von mindestens +300 Talern.

Rat des Steuermanns: Richtet früh Handelsrouten zwischen Euren Inseln ein. Ein zweites Schiff ist Gold wert.
'@
    }
    @{ Nr = 4; GrossGroesse = 'Gross'; Flotte = @(@{ Typ = 25; Name = 'Wehrhaft' }); Datei = 'Smaragdinseln 4 - Schwarze Segel'; Schwierigkeit = 2; Anordnung = 1; SpiegelX = $false; SpiegelY = $true; Groesser = 2
        Gold = 30000; GoldGegner = 30000; Piraten = $true; DoerferNord = 2; DoerferSued = 2
        Mengen = @{ ErzKlein = 6; ErzGross = 10 }
        Auftrag = @{ Staedte = @(@{ Einwohner = 1000; Stufe = 3; Davon = 500 }); Ware1 = @{ Ware = 13; Tonnen = 20 }; Ware2 = @{ Ware = 12; Tonnen = 40 } }
        Text = @'
DIE SMARAGDINSELN - Kapitel 4: Schwarze Segel

Schwarze Segel am Horizont! Ein Piratenkapitän hat sich in den Riffen eingenistet und kapert jedes Schiff, das schwach bewaffnet ist. Die Kompanie schickt keine Flotte - Ihr müsst Euch selbst wappnen.

Euer Auftrag:
- Eine Stadt mit mindestens 1000 Einwohnern, davon 500 Kaufleute oder höher.
- Legt ein Waffenlager an: mindestens 20 Tonnen Kanonen und 40 Tonnen Musketen in Euren Kontoren.

Rat des Steuermanns: Eisen braucht Erz und Holzkohle. Sichert Euch eine Erzinsel, bevor die Rivalen es tun, und lasst Eure Handelsschiffe nicht unbegleitet fahren.
'@
    }
    @{ Nr = 5; GrossGroesse = 'Normal'; Flotte = @(@{ Typ = 27; Name = 'Königsadler' }); Datei = 'Smaragdinseln 5 - Der Eroberer'; Schwierigkeit = 2; Anordnung = 0; SpiegelX = $true; SpiegelY = $false; Groesser = 3
        Gold = 50000; GoldGegner = 40000; Piraten = $true; DoerferNord = 2; DoerferSued = 2
        Mengen = @{ ErzKlein = 6; ErzGross = 10; Gold = 3 }
        Auftrag = @{ Besiegen = @(1, 2, 3) }
        Text = @'
DIE SMARAGDINSELN - Kapitel 5: Der Eroberer

Die Zeit der Verhandlungen ist vorbei. Die drei Rivalen haben sich gegen Euch verbündet, Eure Händler werden abgewiesen, Eure Schiffe beschossen. Die Kompanie erteilt Euch freie Hand.

Euer Auftrag:
- Besiegt alle drei Rivalen. Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.

Rat des Steuermanns: Ein Krieg wird mit Gold gewonnen. Baut zuerst eine starke Wirtschaft, dann Burgen, Kasernen und eine Flotte. Nehmt Euch die Rivalen einzeln vor.
'@
    }
    @{ Nr = 6; GrossGroesse = 'Riesig'; GrossDoerfer = 6; Flotte = @(@{ Typ = 23; Name = 'Fortuna' }); Datei = 'Smaragdinseln 6 - Krone der Inseln'; Schwierigkeit = 3; Anordnung = 2; SpiegelX = $false; SpiegelY = $true; Groesser = 4
        Gold = 40000; GoldGegner = 50000; Piraten = $true; DoerferNord = 3; DoerferSued = 3
        Mengen = @{ ErzKlein = 6; ErzGross = 10; Gold = 3; Schatz = 10 }
        Auftrag = @{ Staedte = @(@{ Einwohner = 2500; Stufe = 4; Davon = 1200 }, @{ Einwohner = 1500; Stufe = 3; Davon = 800 }, @{ Einwohner = 800; Stufe = 2; Davon = 400 }); Bilanz = 1000 }
        Text = @'
DIE SMARAGDINSELN - Kapitel 6: Krone der Inseln

Der König selbst hat von Euren Taten gehört. Er will die Smaragdinseln zu einem eigenen Reich erheben - und Euch zu seinem Vizekönig, sofern Ihr ihm eine Residenz bietet, die der Alten Welt in nichts nachsteht. Doch die Rivalen sind stärker als je zuvor, und die Piraten wittern Beute.

Euer Auftrag:
- Eine Residenzstadt mit mindestens 2500 Einwohnern, davon 1200 Aristokraten.
- Eine zweite Stadt mit mindestens 1500 Einwohnern, davon 800 Kaufleute oder höher.
- Eine dritte Stadt mit mindestens 800 Einwohnern, davon 400 Bürger oder höher.
- Eine Bilanz von mindestens +1000 Talern.

Dies ist das letzte Kapitel. Möge Euer Name in die Chroniken eingehen!
'@
    }

    # --- Kampagne 2: Wettlauf der Häuser (die Rivalen haben denselben Auftrag) -------------------
    # Gegnerstaerke (KI) nach Messung 2026-11-12: Schwierigkeit 0 brauchte ~10,7 h fuer 300/150, Schwierigkeit 2 ~3,7 h.
    @{ Nr = 11; GrossGroesse = 'Normal'; Datei = 'Wettlauf 1 - Erster Hafen'; Schwierigkeit = 0; KI = 1; Anordnung = 0; SpiegelX = $true; SpiegelY = $true; Wettlauf = $true
        Gold = 30000; GoldGegner = 20000; Piraten = $false; DoerferNord = 3; DoerferSued = 3
        Auftrag = @{ Staedte = @(@{ Einwohner = 300; Stufe = 1; Davon = 150 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 1: Erster Hafen

Der König hat vier Handelshäuser über den Ozean geschickt und ein Versprechen gegeben: Wer als Erster eine blühende Hafenstadt gründet, erhält das Handelsprivileg für die ganze Küste. Eure drei Rivalen verfolgen dasselbe Ziel - und sie warten nicht auf Euch.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 300 Einwohnern, davon 150 Siedler oder höher.

Erreicht ein Rivale das Ziel vor Euch, ist das Rennen verloren.

Rat des Steuermanns: Zeit ist alles. Baut zügig, aber lasst Eure Kasse nicht leerlaufen.
'@
    }
    # Zweite Stadt 200/100: Die zweiten Staedte der Gegner bleiben bei 144 Siedlern und 187-290 Einwohnern stehen (Messungen),
    # 300/150 waere fuer sie unerreichbar, 250 nur knapp (Wettlauf 2 mit 250: Sieg des Gegners nach 9,6 h bei 251).
    @{ Nr = 12; GrossGroesse = 'Gross'; Datei = 'Wettlauf 2 - Buergerstolz'; Schwierigkeit = 1; KI = 2; Anordnung = 1; SpiegelX = $true; SpiegelY = $true; Groesser = 2; Wettlauf = $true
        Gold = 30000; GoldGegner = 30000; Piraten = $false; DoerferNord = 2; DoerferSued = 3
        Auftrag = @{ Staedte = @(@{ Einwohner = 700; Stufe = 2; Davon = 350 }, @{ Einwohner = 200; Stufe = 1; Davon = 100 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz

Das Handelsprivileg war nur der Anfang. Nun sucht der König einen Statthalter für die neuen Kolonien - und wieder sollen die Häuser gegeneinander antreten. Der Preis: zwei Städte, die der Krone Ehre machen.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 700 Einwohnern, davon 350 Bürger oder höher,
- und eine zweite Stadt mit mindestens 200 Einwohnern, davon 100 Siedler oder höher.

Rat des Steuermanns: Eine zweite Insel mit anderem Klima liefert, was Eure Bürger verlangen. Wer sie zuerst besetzt, hat die Nase vorn.
'@
    }
    @{ Nr = 13; GrossGroesse = 'Gross'; Datei = 'Wettlauf 3 - Kaufmannsrepublik'; Schwierigkeit = 2; Anordnung = 2; SpiegelX = $true; SpiegelY = $false; Groesser = 3; Wettlauf = $true
        Gold = 35000; GoldGegner = 35000; Piraten = $true; DoerferNord = 2; DoerferSued = 2
        Auftrag = @{ Staedte = @(@{ Einwohner = 1000; Stufe = 3; Davon = 400 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 3: Kaufmannsrepublik

Die Kaufleute der Alten Welt wollen eine freie Handelsstadt jenseits des Meeres. Sie werden das Haus unterstützen, das ihnen zuerst eine würdige Heimat baut. Doch Piraten lauern in diesen Gewässern, und die Rivalen schrecken vor nichts zurück.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1000 Einwohnern, davon 400 Kaufleute oder höher.

Rat des Steuermanns: Kaufleute verlangen Tuch, Alkohol und Tabakwaren. Sichert Euch die Rohstoffe, bevor es die anderen tun.
'@
    }
    @{ Nr = 14; GrossGroesse = 'Riesig'; GrossDoerfer = 6; Datei = 'Wettlauf 4 - Die Krone'; Schwierigkeit = 3; Anordnung = 1; SpiegelX = $true; SpiegelY = $false; Groesser = 4; Wettlauf = $true
        Gold = 40000; GoldGegner = 45000; Piraten = $true; DoerferNord = 3; DoerferSued = 3
        Mengen = @{ ErzKlein = 6; ErzGross = 10; Gold = 3 }
        # 1500 statt 2000: Die Hauptstadt der Gegner bleibt bei ~1500-1610 Einwohnern stehen (Messung); mit 1500/600 + Bilanz 500
        # gewinnt der beste Gegner nach rund 20 Spielstunden - ein echtes Rennen fuer das Finale.
        Auftrag = @{ Staedte = @(@{ Einwohner = 1500; Stufe = 4; Davon = 600 }); Bilanz = 500 }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 4: Die Krone

Das letzte Rennen. Der König wird alt, und er hat verkündet, wer die prächtigste Residenz der Neuen Welt errichtet, soll sein Vizekönig werden. Alle vier Häuser setzen nun alles auf eine Karte.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1500 Einwohnern, davon 600 Aristokraten,
- und eine Bilanz von mindestens +500 Talern.

Rat des Steuermanns: Ein Rivale, der keine Stadt mehr hat, kann auch nicht gewinnen ...
'@
    }

    # --- Herausforderungen (einzelne Szenarien mit besonderen Zielen) -----------------------------
    @{ Nr = 21; GrossGroesse = 'Normal'; Datei = 'Herausforderung - Inselreich'; Schwierigkeit = 1; Anordnung = 1; SpiegelX = $false; SpiegelY = $true
        Gold = 40000; GoldGegner = 25000; Piraten = $false; DoerferNord = 2; DoerferSued = 2
        Auftrag = @{ AnzahlStaedte = 8; EinwohnerGesamt = 3000 }
        Text = @'
HERAUSFORDERUNG: Inselreich

Ein Reich, über dem die Sonne nie untergeht, besteht nicht aus einer einzigen Stadt. Die Krone will Flaggen auf möglichst vielen Inseln sehen.

Euer Auftrag:
- Gründet mindestens 8 eigene Siedlungen (je ein Kontor) auf den Inseln dieses Archipels.
- Alle Eure Siedlungen zusammen sollen mindestens 3000 Einwohner haben.

Rat des Steuermanns: Kleine Inseln sind billig zu besiedeln. Ein Kontor und ein paar Häuser zählen schon als Siedlung - aber die Einwohner wollen versorgt sein.
'@
    }
    @{ Nr = 22; GrossGroesse = 'Gross'; Datei = 'Herausforderung - Handelsimperium'; Schwierigkeit = 2; Anordnung = 0; SpiegelX = $true; SpiegelY = $true; Groesser = 3
        Gold = 30000; GoldGegner = 30000; Piraten = $false; DoerferNord = 2; DoerferSued = 3
        Mengen = @{ Gold = 3 }
        Auftrag = @{ Ware1 = @{ Ware = 21; Tonnen = 50 }; Ware2 = @{ Ware = 20; Tonnen = 80 }; Handelsbilanz = 300 }
        Text = @'
HERAUSFORDERUNG: Handelsimperium

Nicht Kanonen, sondern volle Lagerhäuser regieren die Welt. Die Kaufleute von Antwerpen wollen sehen, wer die reichsten Speicher der Neuen Welt füllt.

Euer Auftrag:
- Lagert mindestens 50 Tonnen Schmuck und 80 Tonnen Kleidung in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +300 Talern: Eure Verkäufe an Händler und Rivalen müssen Eure Einkäufe deutlich übersteigen.

Rat des Steuermanns: Schmuck braucht Gold aus den Bergen, Kleidung braucht Stoffe aus Wolle oder Baumwolle. Stellt in den Kontoren ein, was Ihr verkaufen wollt, und baut Lager aus, damit nichts verloren geht.
'@
    }
    @{ Nr = 23; GrossGroesse = 'Normal'; Flotte = @(@{ Typ = 25; Name = 'Goldwächter' }); Datei = 'Herausforderung - Goldrausch'; Schwierigkeit = 2; Anordnung = 2; SpiegelX = $false; SpiegelY = $true; Groesser = 2
        Gold = 35000; GoldGegner = 35000; Piraten = $true; DoerferNord = 2; DoerferSued = 2
        Mengen = @{ Gold = 4; ErzKlein = 6; ErzGross = 9; Schatz = 12 }
        Auftrag = @{ Ware1 = @{ Ware = 3; Tonnen = 60 }; Ware2 = @{ Ware = 21; Tonnen = 40 } }
        Text = @'
HERAUSFORDERUNG: Goldrausch

In den Bergen dieser Inseln soll es Gold geben - genug, um eine Flotte zu kaufen. Die Gerüchte haben nicht nur Euch angelockt: Rivalen und Piraten sind schon unterwegs.

Euer Auftrag:
- Lagert mindestens 60 Tonnen Gold und 40 Tonnen Schmuck in Euren Kontoren.

Rat des Steuermanns: Goldminen gibt es nur an wenigen Bergen. Wer sie zuerst besetzt und gut schützt, gewinnt. Und lasst Eure Goldschiffe nie allein fahren.
'@
    }
)

foreach ($k in $Kapitel) { Baue-Kapitel $k }

if ($Installieren) {
    $own = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
    New-Item -ItemType Directory -Force -Path $own | Out-Null
    Get-ChildItem $Ausgabe -Filter '*.szs' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $own -Force }
    "Installiert nach: $own"
}
