<#
.SYNOPSIS
  EXPERIMENT: setzt die Kartengroesse von Anno 1602 History Edition im Arbeitsspeicher (Standard 1000 x 700).

.DESCRIPTION
  Aendert keine Spieldateien. Ablauf:
    1. Prueft die exe auf der Festplatte (SHA-256 und Original-Bytes an allen Stellen).
    2. Sichert den Savegame-Ordner (Dokumente\Anno 1602 History Edition\Savegame), aber nur,
       wenn er sich seit der letzten Sicherung geaendert hat.
    3. Wartet, bis Anno1602.exe laeuft (Spiel ganz normal ueber Ubisoft Connect starten).
       Beendet sich der erste Prozess gleich wieder (Ubisoft Connect startet das Spiel dann neu),
       wartet das Werkzeug auf den naechsten und patcht diesen.
    4. Prueft im Speicher alle Code-Stellen (8 fuer die Groesse, dazu je nach Schalter
       Inselverteilung und Piraten/Startgeld) und 5 Variablen; erst wenn alle passen, werden
       die Code-Stellen ersetzt (bei einem Fehler wird zurueckgebaut: alles oder nichts).
    5. Wartet, bis das Spiel seine Startwerte gesetzt hat, und setzt dann die 5 Variablen,
       auf Wunsch auch Schiffstempo und Lager (Werte aus figuren.cod/haeuser.cod im Speicher).
    6. Bleibt offen, bis das Spiel beendet ist. Hat das Spiel in dieser Zeit lastgame.gam
       geschrieben (automatischer Spielstand fuer "Spiel fortsetzen"), wird die Datei in
       lastgame-<Breite>x<Hoehe>-<Zeit>.gam umbenannt. So laedt "Spiel fortsetzen" ohne
       Werkzeug keine grosse Welt. Abschalten mit -OhneLastgameSchutz.
  Nach dem Beenden des Spiels ist alles wieder wie vorher.
  Bequemer Start von Werkzeug und Spiel zusammen: tools\anno-grosse-welt.cmd

  Gesetzt werden (siehe analysis\BEFUNDE.md, Abschnitt "Kartengroesse"):
    Breite, Hoehe                 Kartengroesse in Feldern (normal 500 x 350)
    Scrollbereich                 Kamerabereich = Breite/2 + Hoehe/2 (normal 425); begrenzt
                                  Rand-Scrollen und Pfeiltasten
    1/Breite, 1/Hoehe (float)     Massstab fuer Markierungen auf der Minikarte
    Inselverteilung               Sprung im SZENE-Lader (FUN_1400d0de0, RVA 0xD0E29) auf ein
                                  kurzes Codestueck im freien Ende von .text (RVA 0xE5100) mit
                                  einer Inseltabelle dahinter (RVA 0xE5200). Fuer die drei
                                  Endlos-Anordnungen (Szenes\[[48]]x0/x1/x2.szs) setzt es eine
                                  vom Werkzeug geplante Liste ein: Originalinseln gestreckt
                                  (Breite/500, Hoehe/350), dazu Kopien in freien Luecken
                                  (bei 1000 x 700: 50/50/47 statt 18/20/17 Inseln, alle
                                  50 Plaetze nutzbar). Andere Vorlagen werden nur gestreckt.
                                  Spielstaende enthalten keinen SZENE-Abschnitt und bleiben
                                  unberuehrt. -NurStrecken: keine Zusatzinseln.
                                  -OhneInselVerteilung: alles aus.
                                  Plan ansehen: tools\inselplan-zeigen.ps1
                                  Eigene Szenarien mit grosser Fassung (Kennung 'GROS' hinter dem
                                  SZENE-Abschnitt, z. B. die Kampagnen aus tools\kampagne-bauen.ps1):
                                  ab Kartengroesse der Auslegung (1000 x 700) gilt die grosse Fassung
                                  (Codestueck RVA 0xE5E40), sonst die kleine, gestreckt.
    Piraten (-Piraten)            Standard: wie die gewaehlte Schwierigkeit.
                                  Aktiv: Piraten greifen an, auch bei Einfach/Durchschnittlich
                                  (dort sonst nur "gelegentliche Sichtungen").
                                  Stark: wie Aktiv, dazu bestuecken die Piraten ihre Schiffe
                                  immer mit der vollen Kanonenzahl.
                                  Aus: Piraten greifen nie an, auch nicht bei Schwer.
                                  Wirkt beim Laden einer Vorlage und eines Spielstands
                                  (Haken am Ende des TIMERS-Laders, RVA 0xC3232).
    Startgeld (-Startgeld)        Gold des Spielers bei neuen Spielen (0 = wie die gewaehlte
                                  Schwierigkeit). Spielstaende bleiben unberuehrt (erkannt an
                                  der Spieluhr; im selben Haken wie die Piraten).
    Lager (-Lager)                Faktor 1 bis 5 fuer das Lager je Ware von Kontor I-IV (30/50/
                                  75/100 t) und Markt (10 t). Gebaeudetabelle (aus haeuser.cod,
                                  RVA 0x6BA1C0 + Nr. * 0x90, 16-Bit-Wert x 32 bei +0x30, Nr. 270-273,
                                  401, 467, 468). Ein neu gebauter Kontor uebernimmt den Wert
                                  (im Spiel geprueft); ausgebaute Kontore vermutlich ebenso.
    Schiffstempo (-Schiffstempo)  Faktor 1.0 bis 3.0 fuer die Geschwindigkeit aller Schiffe
                                  (auch KI, Haendler, Piraten). Normal 1.0. Gesetzt in der
                                  Figurentabelle (aus figuren.cod, RVA 0x6D80C0 + Nr. * 0x18C,
                                  Kommazahl bei +0x10, Schiffstypen Nr. 21-32).
    Inselgroesse (-Inselgroesse)  Normal: Klassen der Vorlage. Gross: Originalinseln eine Klasse
                                  groesser (wo Platz ist), Zusatzinseln "lar" (100 x 90) und "big"
                                  (70 x 60). Riesig: fast nur "lar". Weniger, aber viel groessere Inseln.
    Rohstoffe (-Rohstoffe)        Normal: Mengen der Vorlage (gedacht fuer 17-20 Inseln). Mehr: Erz,
                                  Gold, Fruchtbarkeit der Plantagen und Schaetze wachsen mit der
                                  Inselzahl mit. Viele: doppelt so viel. Jede Menge hoechstens so
                                  gross wie die Inselzahl. Codestueck bei RVA 0xE5C00, aufgerufen aus
                                  der Inselverteilung (nur Endlos-Vorlagen).
    Einwohner (-Einwohner)        Faktor 1 bis 5 fuer die Hoechstzahl der Einwohner je Haus und
                                  Stufe (normal 2/6/15/25/40). haeuser.cod "Maxwohn" der 5
                                  Bevoelkerungsgruppen, x 64 als int bei RVA 0x6BA02C + Nr. * 0x50
                                  (Parser FUN_140090660, gelesen u. a. in FUN_1400b7c60).
    Laderaum (-Laderaum)          Faktor 1 bis 3 fuer die Tonnen je Laderaum der baubaren Schiffe
                                  (kleines/grosses Handels- und Kriegsschiff, Nr. 21-28).
                                  figuren.cod "Maxware", 16 Bit x 32 bei Figurentabelle +0x3E.
    Produktion (-Produktion)      Faktor 1 bis 3 fuer das Arbeitstempo aller Betriebe. Teilt
                                  haeuser.cod "Interval" (16 Bit bei Gebaeudetabelle +0x3A) aller
                                  500 Eintraege durch den Faktor. Das Spiel liest den Wert bei
                                  jedem Arbeitsschritt (FUN_1400b43e0, FUN_1400b9ed0), wirkt also
                                  auch in geladenen Spielstaenden. Eine Marke bei RVA 0xE5F70
                                  verhindert doppeltes Teilen im selben Spielprozess.
    Turbo (-Turbo)                F7 schaltet auf 8-fach statt 4-fach, mit -TurboStufe 12 oder 16
                                  entsprechend schneller (FUN_1400e2d60, RVA 0xE3376:
                                  mov ecx,4 -> mov ecx,8/12/16). Die Spielschleife FUN_1400c8e20 rechnet
                                  mit beliebigen Faktoren; F5/F6 bleiben 1- und 2-fach.
    Gegnergeld (-GegnerGeld)      Gold der drei Computergegner (Plaetze 1-3) bei neuen Spielen,
                                  0 = wie die Vorlage. Im selben Haken wie das Startgeld.
    Gegner (-Gegner)              Schwer: die Computergegner planen Militaer und Ausbau immer wie
                                  auf der hoechsten Schwierigkeit (FUN_140017840, FUN_140017b30,
                                  FUN_140032090, FUN_140035220 lesen statt der Schwierigkeit eine 3).
                                  Naturereignisse und Piraten bleiben bei der gewaehlten Stufe.
    Piratenflotte (-Piratenflotte) Gross / Riesig: die Piraten halten 2- bzw. 3-mal so viele Schiffe
                                  (Original: so viele wie die hoechste Zivilisationsstufe, 2-4) und
                                  bauen entsprechend schneller nach (FUN_14003b7e0).
    Ureinwohner (-Ureinwohner)    Mehr / Viele: 4 bzw. 7 Doerfer je Klimazone statt 2 (SZENE +0x40/
                                  +0x44, nur Endlos-Vorlagen mit zusaetzlichen Inseln). Doerfer
                                  entstehen nur auf Inseln mit Dorfplatz; jedes belegt einen der
                                  75 Siedlungsplaetze des Spiels.
    Haendler (-Haendler)          Mehr / Viele: 2- bzw. 3-mal so viele freie Haendlerschiffe
                                  (Original: 1 je 3 Siedlungen, FUN_1400bc030), hoechstens 24
                                  (das Spiel hat 30 Haendlerplaetze).

  Nur Einzelspieler. Spielstaende aus der grossen Welt nur mit aktivem Werkzeug laden
  (der Spielstand speichert die Groesse nicht). Das gilt auch fuer "Spiel fortsetzen"
  (lastgame.gam), das nach einem Spiel in der grossen Welt diese Welt enthaelt.
  Die Inselverteilung wirkt auf jede Szenario-Vorlage; fuer Kampagnen-Szenarien das
  Werkzeug nicht verwenden.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\weltgroesse.ps1
  powershell -ExecutionPolicy Bypass -File .\tools\weltgroesse.ps1 -Breite 750 -Hoehe 525
  powershell -ExecutionPolicy Bypass -File .\tools\weltgroesse.ps1 -NurPruefen
  powershell -ExecutionPolicy Bypass -File .\tools\weltgroesse.ps1 -Piraten Stark
#>
param(
    [ValidateRange(100, 2000)][int]$Breite = 1000,
    [ValidateRange(100, 2000)][int]$Hoehe = 700,
    # Nur die exe auf der Festplatte pruefen, nichts schreiben.
    [switch]$NurPruefen,
    [int]$WartezeitMinuten = 15,
    # Das Spiel laeuft schon laenger und steht sicher im Hauptmenue (kein Spiel geladen).
    [switch]$SpielLaeuftBereits,
    # Inselpositionen der Vorlagen nicht strecken (Inseln bleiben im Bereich 500 x 350).
    [switch]$OhneInselVerteilung,
    # Nur strecken, keine zusaetzlichen Inseln.
    [switch]$NurStrecken,
    # Nach dem Spiel nicht warten und lastgame.gam nicht umbenennen.
    [switch]$OhneLastgameSchutz,
    # Piraten: Standard (wie Schwierigkeit), Aktiv, Stark (aktiv und volle Kanonen), Aus.
    [ValidateSet('Standard', 'Aktiv', 'Stark', 'Aus')][string]$Piraten = 'Standard',
    # Faktor fuer die Geschwindigkeit aller Schiffe (1.0 = normal).
    [ValidateRange(1.0, 3.0)][double]$Schiffstempo = 1.0,
    # Faktor fuer das Lager von Kontor I-IV und Markt (1 = normal 30/50/75/100 t).
    [ValidateRange(1, 5)][int]$Lager = 1,
    # Startgeld des Spielers bei neuen Spielen (0 = wie die Schwierigkeit: 20'000/15'000/10'000).
    [ValidateRange(0, 9999999)][int]$Startgeld = 0,
    # Faktor fuer die Einwohner je Haus (1 = normal 2/6/15/25/40).
    [ValidateRange(1.0, 5.0)][double]$Einwohner = 1.0,
    # Groesse der Inseln im Endlosspiel: Normal (wie Vorlage), Gross (viele grosse), Riesig (fast nur die groessten).
    [ValidateSet('Normal', 'Gross', 'Riesig')][string]$Inselgroesse = 'Normal',
    # Rohstoffe im Endlosspiel: Normal (wie Vorlage), Mehr (mit der Inselzahl mitwachsend), Viele (doppelt so viele).
    [ValidateSet('Normal', 'Mehr', 'Viele')][string]$Rohstoffe = 'Normal',
    # Faktor fuer die Tonnen je Laderaum der baubaren Schiffe (1 = normal).
    [ValidateRange(1.0, 3.0)][double]$Laderaum = 1.0,
    # Faktor fuer das Arbeitstempo aller Betriebe (1 = normal, 2 = doppelt so schnell).
    [ValidateRange(1.0, 3.0)][double]$Produktion = 1.0,
    # F7 = 8-fach statt 4-fach.
    [switch]$Turbo,
    # Geschwindigkeit von F7 mit -Turbo: 8, 12 oder 16-fach.
    [ValidateSet(8, 12, 16)][int]$TurboStufe = 8,
    # Gold der drei Computergegner bei neuen Spielen (0 = wie die Vorlage).
    [ValidateRange(0, 9999999)][int]$GegnerGeld = 0,
    # Computergegner: Standard (wie Schwierigkeit) oder Schwer (immer wie die hoechste Stufe).
    [ValidateSet('Standard', 'Schwer')][string]$Gegner = 'Standard',
    # Piratenflotte: Normal, Gross (2-mal so viele Schiffe), Riesig (3-mal).
    [ValidateSet('Normal', 'Gross', 'Riesig')][string]$Piratenflotte = 'Normal',
    # Eingeborenendoerfer je Klimazone: Standard (2), Mehr (4), Viele (7).
    [ValidateSet('Standard', 'Mehr', 'Viele')][string]$Ureinwohner = 'Standard',
    # Freie Haendlerschiffe: Standard, Mehr (2-mal), Viele (3-mal), hoechstens 24.
    [ValidateSet('Standard', 'Mehr', 'Viele')][string]$Haendler = 'Standard',
    # Spielordner von Hand angeben (sonst aus Ubisoft Connect ermittelt).
    [string]$Spielpfad,
    # Nur fuer tools\test-weltgroesse.ps1: anderer Prozess und Ladeadresse, keine Sicherung.
    [Parameter(DontShow)][int]$TestProzessId = 0,
    [Parameter(DontShow)][long]$TestBasis = 0
)

$ErrorActionPreference = 'Stop'

$SpielOrdner = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition'
# Spielordner auf diesem PC: -Spielpfad, sonst Ubisoft Connect (Installations-ID 16236), sonst
# der Deinstallations-Eintrag, sonst der Standardordner oben.
function Finde-Spielordner {
    $kandidaten = New-Object System.Collections.Generic.List[string]
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $kandidaten.Add($d) } } catch { }
    }
    $un = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $un -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'Anno 1602 - History Edition' -and $_.InstallLocation } | ForEach-Object { $kandidaten.Add($_.InstallLocation) }
    foreach ($d in $kandidaten) {
        $d = ($d -replace '/', '\').TrimEnd('\')
        if (Test-Path -LiteralPath (Join-Path $d 'Anno1602.exe')) { return $d }
    }
    $null
}
if ($Spielpfad) { $SpielOrdner = $Spielpfad.TrimEnd('\') }
else { $gefunden = Finde-Spielordner; if ($gefunden) { $SpielOrdner = $gefunden } }
if (-not (Test-Path -LiteralPath (Join-Path $SpielOrdner 'Anno1602.exe'))) {
    throw "Anno 1602 History Edition nicht gefunden (gesucht in: $SpielOrdner). Spiel ueber Ubisoft Connect installieren oder den Ordner mit -Spielpfad angeben."
}
$ErwarteterHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'

# RVA = Adresse im Speicher relativ zur Ladeadresse der exe (Ghidra-Adresse minus 0x140000000).
# Jede Code-Stelle ist "mov dword ptr [rip+rel32], imm32" (C7 05 rel32 imm32), der Wert steht ab Byte 6.
$Stellen = @(
    @{ Name = 'Breite        (Programmstart)'; Rva = 0x0DC7E5; Original = 'C7 05 51 F6 50 00 F4 01 00 00'; Wert = 'Breite' }
    @{ Name = 'Hoehe         (Programmstart)'; Rva = 0x0DC7EF; Original = 'C7 05 9F F6 50 00 5E 01 00 00'; Wert = 'Hoehe' }
    @{ Name = 'Scrollbereich (Programmstart)'; Rva = 0x0DC7F9; Original = 'C7 05 3D F0 50 00 A9 01 00 00'; Wert = 'Bereich' }
    @{ Name = 'Breite        (neues Spiel)  '; Rva = 0x08DC90; Original = 'C7 05 A6 E1 55 00 F4 01 00 00'; Wert = 'Breite' }
    @{ Name = 'Hoehe         (neues Spiel)  '; Rva = 0x08DC9A; Original = 'C7 05 F4 E1 55 00 5E 01 00 00'; Wert = 'Hoehe' }
    @{ Name = 'Scrollbereich (neues Spiel)  '; Rva = 0x08DCA4; Original = 'C7 05 92 DB 55 00 A9 01 00 00'; Wert = 'Bereich' }
    @{ Name = '1/Breite      (neues Spiel)  '; Rva = 0x08DCAE; Original = 'C7 05 C4 DF 55 00 6F 12 03 3B'; Wert = 'KehrBreite' }
    @{ Name = '1/Hoehe       (neues Spiel)  '; Rva = 0x08DCB8; Original = 'C7 05 BE DF 55 00 E7 3E 3B 3B'; Wert = 'KehrHoehe' }
)
# Die Variablen in .data. Beim Programmstart setzt das Spiel 1/Breite und 1/Hoehe aus Konstanten
# in .rdata (nicht als Sofortwert), deshalb werden die Variablen nach dem Start direkt gesetzt.
$Variablen = @(
    @{ Name = 'Breite       '; Rva = 0x5EBE40; Wert = 'Breite' }
    @{ Name = 'Hoehe        '; Rva = 0x5EBE98; Wert = 'Hoehe' }
    @{ Name = 'Scrollbereich'; Rva = 0x5EB840; Wert = 'Bereich' }
    @{ Name = '1/Breite     '; Rva = 0x5EBC7C; Wert = 'KehrBreite' }
    @{ Name = '1/Hoehe      '; Rva = 0x5EBC80; Wert = 'KehrHoehe' }
)
# Diese Variable setzt das Spiel beim Start als letzte der fuenf (FUN_1400dbc60, RVA 0xDC812).
$RvaStartFertig = 0x5EBC80

function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
function Bytes([string]$hex) { [byte[]]($hex -split ' ' | ForEach-Object { [Convert]::ToByte($_, 16) }) }
function Werte([int]$b, [int]$h) {
    @{
        Breite     = [BitConverter]::GetBytes([int32]$b)
        Hoehe      = [BitConverter]::GetBytes([int32]$h)
        Bereich    = [BitConverter]::GetBytes([int32]([math]::Floor($b / 2) + [math]::Floor($h / 2)))
        KehrBreite = [BitConverter]::GetBytes([single](1.0 / $b))
        KehrHoehe  = [BitConverter]::GetBytes([single](1.0 / $h))
    }
}
function Anzeige([string]$art, [byte[]]$b) {
    if ($art -like 'Kehr*') { '1/{0:0.##}' -f (1.0 / [BitConverter]::ToSingle($b, 0)) } else { [BitConverter]::ToInt32($b, 0) }
}

if (-not [Environment]::Is64BitProcess) { throw 'Bitte die 64-Bit-PowerShell verwenden.' }

# Selbsttest: die Formeln muessen bei 500 x 350 genau die Original-Bytes ergeben.
$orig = Werte 500 350
foreach ($s in $Stellen) {
    if ((Hex $orig[$s.Wert]) -ne (Hex (Bytes $s.Original)[6..9])) { throw "Interner Fehler: Formel fuer $($s.Wert) passt nicht zum Original." }
}
$werte = Werte $Breite $Hoehe
foreach ($s in $Stellen) { $s.Soll = [byte[]]((Bytes $s.Original)[0..5] + $werte[$s.Wert]) }

# --- Inselverteilung --------------------------------------------------------------------------
# Herleitung: analysis\BEFUNDE.md, Abschnitte "Inseln verteilen" und "Mehr Inseln".
# Sprung im SZENE-Lader (RVA 0xD0E29, R15 = Abschnittsdaten) auf ein Codestueck im freien Ende
# von .text (RVA 0xE5100). Das Codestueck sucht die Vorlage in einer Tabelle (RVA 0xE5200,
# erkannt an Inselzahl und Position der ersten Insel) und kopiert dann die vom Werkzeug
# berechnete Inselliste hinein. Unbekannte Vorlagen: Positionen nur strecken (x*Breite/500,
# y*Hoehe/350). Spielstaende haben keinen SZENE-Abschnitt und bleiben unberuehrt.
$CaveRva = 0xE5100; $TabelleRva = 0xE5200; $TabelleMax = 0xE5C00 - 0xE5200   # ab 0xE5C00: Rohstoffe, ab 0xE5F80: Piraten
$HakenRva = 0xD0E29; $HakenWeiter = 0xD0E30
# Hoechstens 50 Inseln (SZENE-Abschnitt, Inseltabelle 0x14062DDC0 und Raster FUN_14009ce30 haben
# 50 Plaetze). Dichte: Zusatzinseln je Flaeche wie in der Vorlage x 0,7 (bis 2026-11-11: 0,6 und 48).
$InselMax = 50; $InselDichte = 0.7
$KlasseB = @(30, 40, 50, 70, 100); $KlasseH = @(30, 40, 52, 60, 90)   # .rdata 0xEA1E0 / 0xEA1C0

function Rel32([long]$ziel, [long]$ende) { [BitConverter]::GetBytes([int32]($ziel - $ende)) }

# Grosse Kampagnenkarten: Ein eigenes Szenario kann hinter dem normalen SZENE-Abschnitt (1172 Byte,
# gilt ohne Werkzeug) eine zweite Fassung tragen: +0x494 'GROS', +0x498 Breite, +0x49C Hoehe, auf die
# sie ausgelegt ist, +0x4A0 Version, ab +0x4A4 ein kompletter SZENE-Block (1172 Byte). Ohne Werkzeug
# liest der Lader nur die festen Offsets des ersten Blocks (im Spiel geprueft). Das Codestueck bei
# RVA 0xE5E40 prueft Laenge (RCX = Abschnittskopf, +0x10 Laenge), Kennung und Kartengroesse
# (mindestens die Auslegung), kopiert dann den grossen Block nach vorne und streckt seine Positionen
# auf die aktuelle Kartengroesse (x*Breite/Auslegung). eax = 1: erledigt, sonst 0 (normaler Weg).
$GrossCaveRva = 0xE5E40; $GrossKennung = 0x534F5247   # 'GROS'
function Baue-Grosskartencode {
    $c = New-Object System.Collections.Generic.List[byte]
    $marke = @{}; $fix = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$ziel) $c.Add($op); $fix.Add(@($c.Count, $ziel, 8)); $c.Add(0) }
    # Fruehe Ausstiege nach "ende" (Ende des Codestuecks): 32-Bit-Sprung, Jcc rel8 -> 0F (op+0x10) rel32.
    $J32 = { param([byte]$op8, [string]$ziel) $c.Add(0x0F); $c.Add([byte]($op8 + 0x10)); $fix.Add(@($c.Count, $ziel, 32)); 1..4 | ForEach-Object { $c.Add(0) } }
    $Rip = { param([byte[]]$op, [long]$zielRva) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $zielRva ($GrossCaveRva + $c.Count + 4))) { $c.Add($x) } }
    & $E 0x31, 0xC0                                              # xor eax,eax
    & $E 0x8B, 0x51, 0x10                                        # mov edx,[rcx+0x10]   Abschnittslaenge
    & $E 0x81, 0xFA, 0x38, 0x09, 0x00, 0x00                      # cmp edx,2360
    & $J32 0x72 'ende'                                            # jb ende
    & $E 0x41, 0x81, 0xBF, 0x94, 0x04, 0x00, 0x00; & $E ([BitConverter]::GetBytes([int32]$GrossKennung))   # cmp dword [r15+0x494],'GROS'
    & $J32 0x75 'ende'                                            # jne ende
    & $E 0x41, 0x83, 0xBF, 0x98, 0x04, 0x00, 0x00, 0x64          # cmp dword [r15+0x498],100
    & $J32 0x7C 'ende'                                            # jl ende
    & $E 0x41, 0x83, 0xBF, 0x9C, 0x04, 0x00, 0x00, 0x64          # cmp dword [r15+0x49C],100
    & $J32 0x7C 'ende'                                            # jl ende
    & $Rip ([byte[]](0x8B, 0x15)) 0x5EBE40                       # mov edx,[Breite]
    & $E 0x41, 0x3B, 0x97, 0x98, 0x04, 0x00, 0x00                # cmp edx,[r15+0x498]
    & $J32 0x7C 'ende'                                            # jl ende
    & $Rip ([byte[]](0x8B, 0x15)) 0x5EBE98                       # mov edx,[Hoehe]
    & $E 0x41, 0x3B, 0x97, 0x9C, 0x04, 0x00, 0x00                # cmp edx,[r15+0x49C]
    & $J32 0x7C 'ende'                                            # jl ende
    & $E 0x49, 0x8D, 0xB7, 0xA4, 0x04, 0x00, 0x00                # lea rsi,[r15+0x4A4]
    & $E 0x4C, 0x89, 0xFF                                        # mov rdi,r15
    & $E 0xB9, 0x94, 0x04, 0x00, 0x00                            # mov ecx,1172
    & $E 0xF3, 0xA4                                              # rep movsb
    & $E 0x45, 0x8B, 0x47, 0x64                                  # mov r8d,[r15+0x64]
    & $E 0x41, 0x83, 0xF8, 0x32                                  # cmp r8d,50
    & $J8 0x77 'erledigt'                                        # ja erledigt
    & $E 0x4D, 0x8D, 0x8F, 0x74, 0x01, 0x00, 0x00                # lea r9,[r15+0x174]
    $marke.schleife = $c.Count
    & $E 0x45, 0x85, 0xC0                                        # test r8d,r8d
    & $J8 0x7E 'erledigt'                                        # jle erledigt
    & $E 0x41, 0x8B, 0x41, 0x08                                  # mov eax,[r9+8]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE40                 # imul eax,[Breite]
    & $E 0x99, 0x41, 0xF7, 0xBF, 0x98, 0x04, 0x00, 0x00          # cdq / idiv dword [r15+0x498]
    & $E 0x41, 0x89, 0x41, 0x08                                  # mov [r9+8],eax
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE98                 # imul eax,[Hoehe]
    & $E 0x99, 0x41, 0xF7, 0xBF, 0x9C, 0x04, 0x00, 0x00          # cdq / idiv dword [r15+0x49C]
    & $E 0x41, 0x89, 0x41, 0x0C                                  # mov [r9+0xc],eax
    & $E 0x49, 0x83, 0xC1, 0x10                                  # add r9,16
    & $E 0x41, 0xFF, 0xC8                                        # dec r8d
    & $J8 0xEB 'schleife'                                        # jmp schleife
    $marke.erledigt = $c.Count
    & $E 0xB8, 0x01, 0x00, 0x00, 0x00                            # mov eax,1
    $marke.ende = $c.Count
    & $E 0xC3                                                    # ret
    foreach ($f in $fix) {
        if ($f[2] -eq 32) { $b4 = [BitConverter]::GetBytes([int32]($marke[$f[1]] - ($f[0] + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$f[0] + $i] = $b4[$i] }; continue }
        $d = $marke[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw "Interner Fehler: Sprung zu $($f[1]) zu weit." }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($GrossCaveRva + $c.Count -gt 0xE5F70) { throw 'Interner Fehler: Grosskarten-Codestueck zu lang.' }
    , $c.ToArray()
}

# Kleiner Assembler mit Sprungmarken fuer das Codestueck. Mit $rohstoffe ruft es nach dem Kopieren
# der Inselliste das Rohstoff-Codestueck auf (call, Register sind dann schon gesichert). Mit
# $grosskarte ruft es zuerst das Grosskarten-Codestueck auf (eax = 1: schon erledigt).
function Baue-Codestueck([bool]$rohstoffe = $false, [bool]$grosskarte = $false) {
    $c = New-Object System.Collections.Generic.List[byte]
    $marke = @{}; $fix = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$ziel) $c.Add($op); $fix.Add(@($c.Count, $ziel, 8)); $c.Add(0) }
    $J32 = { param([byte[]]$op, [string]$ziel) foreach ($x in $op) { $c.Add($x) }; $fix.Add(@($c.Count, $ziel, 32)); 1..4 | ForEach-Object { $c.Add(0) } }
    $Rip = { param([byte[]]$op, [long]$zielRva) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $zielRva ($CaveRva + $c.Count + 4))) { $c.Add($x) } }
    & $E 0x50, 0x51, 0x52, 0x41, 0x50, 0x41, 0x51, 0x56, 0x57   # push rax,rcx,rdx,r8,r9,rsi,rdi
    if ($grosskarte) {
        & $Rip ([byte[]](0xE8)) $GrossCaveRva                    # call Grosskarten-Codestueck (rcx = Abschnittskopf)
        & $E 0x85, 0xC0                                          # test eax,eax
        & $J32 ([byte[]](0x0F, 0x85)) 'fertig'                   # jnz fertig
    }
    & $E 0x45, 0x8B, 0x47, 0x64                                  # mov r8d,[r15+0x64]   Inselzahl
    & $E 0x41, 0x83, 0xF8, 0x32                                  # cmp r8d,50
    & $J32 ([byte[]](0x0F, 0x87)) 'fertig'                       # ja fertig
    & $Rip ([byte[]](0x4C, 0x8D, 0x0D)) $TabelleRva              # lea r9,[Tabelle]
    & $E 0x41, 0x8B, 0x09                                        # mov ecx,[r9]         Zahl der Eintraege
    & $E 0x49, 0x83, 0xC1, 0x04                                  # add r9,4
    $marke.suche = $c.Count
    & $E 0x85, 0xC9                                              # test ecx,ecx
    & $J8 0x7E 'strecken'                                        # jle strecken
    & $E 0x45, 0x3B, 0x01                                        # cmp r8d,[r9]
    & $J8 0x75 'weiter'                                          # jne weiter
    & $E 0x41, 0x8B, 0x87, 0x7C, 0x01, 0x00, 0x00                # mov eax,[r15+0x17c]  x der 1. Insel
    & $E 0x41, 0x3B, 0x41, 0x04                                  # cmp eax,[r9+4]
    & $J8 0x75 'weiter'
    & $E 0x41, 0x8B, 0x87, 0x80, 0x01, 0x00, 0x00                # mov eax,[r15+0x180]  y der 1. Insel
    & $E 0x41, 0x3B, 0x41, 0x08                                  # cmp eax,[r9+8]
    & $J8 0x75 'weiter'
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]     neue Inselzahl
    & $E 0x41, 0x89, 0x47, 0x64                                  # mov [r15+0x64],eax
    & $E 0x49, 0x8D, 0x71, 0x10                                  # lea rsi,[r9+0x10]
    & $E 0x49, 0x8D, 0xBF, 0x74, 0x01, 0x00, 0x00                # lea rdi,[r15+0x174]
    & $E 0xB9, 0x20, 0x03, 0x00, 0x00                            # mov ecx,800
    & $E 0xF3, 0xA4                                              # rep movsb
    if ($rohstoffe) { & $Rip ([byte[]](0xE8)) $RohCaveRva }      # call Rohstoff-Codestueck
    & $J8 0xEB 'fertig'                                          # jmp fertig
    $marke.weiter = $c.Count
    & $E 0x49, 0x81, 0xC1, 0x30, 0x03, 0x00, 0x00                # add r9,816
    & $E 0xFF, 0xC9                                              # dec ecx
    & $J8 0xEB 'suche'                                           # jmp suche
    $marke.strecken = $c.Count
    & $E 0x4D, 0x8D, 0x8F, 0x74, 0x01, 0x00, 0x00                # lea r9,[r15+0x174]
    $marke.schleife = $c.Count
    & $E 0x45, 0x85, 0xC0                                        # test r8d,r8d
    & $J8 0x7E 'fertig'                                          # jle fertig
    & $E 0x41, 0x8B, 0x41, 0x08                                  # mov eax,[r9+8]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE40                 # imul eax,[Breite]
    & $E 0x99, 0xB9, 0xF4, 0x01, 0x00, 0x00, 0xF7, 0xF9          # cdq / mov ecx,500 / idiv ecx
    & $E 0x41, 0x89, 0x41, 0x08                                  # mov [r9+8],eax
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE98                 # imul eax,[Hoehe]
    & $E 0x99, 0xB9, 0x5E, 0x01, 0x00, 0x00, 0xF7, 0xF9          # cdq / mov ecx,350 / idiv ecx
    & $E 0x41, 0x89, 0x41, 0x0C                                  # mov [r9+0xc],eax
    & $E 0x49, 0x83, 0xC1, 0x10                                  # add r9,16
    & $E 0x41, 0xFF, 0xC8                                        # dec r8d
    & $J8 0xEB 'schleife'                                        # jmp schleife
    $marke.fertig = $c.Count
    & $E 0x5F, 0x5E, 0x41, 0x59, 0x41, 0x58, 0x5A, 0x59, 0x58   # pop rdi,rsi,r9,r8,rdx,rcx,rax
    & $Rip ([byte[]](0x4C, 0x8D, 0x1D)) 0                        # lea r11,[Bildbasis]  (ersetzter Befehl)
    & $Rip ([byte[]](0xE9)) $HakenWeiter                         # jmp zurueck
    foreach ($f in $fix) {
        $pos = $f[0]; $ziel = $marke[$f[1]]
        if ($f[2] -eq 8) {
            $d = $ziel - ($pos + 1); if ($d -lt -128 -or $d -gt 127) { throw "Interner Fehler: Sprung zu $($f[1]) zu weit." }
            $c[$pos] = [byte]($d -band 0xFF)
        }
        else { $b4 = [BitConverter]::GetBytes([int32]($ziel - ($pos + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$pos + $i] = $b4[$i] } }
    }
    if ($CaveRva + $c.Count -gt $TabelleRva) { throw 'Interner Fehler: Codestueck zu lang.' }
    , $c.ToArray()
}

# --- Rohstoffe ------------------------------------------------------------------------------------
# Herleitung: analysis\BEFUNDE.md, Abschnitt "Rohstoffe".
# Im SZENE-Abschnitt stehen ab +0x94 Eintraege zu 8 Byte (Haus-Nr. 16 Bit, Menge 16 Bit, int):
# Erz 2401 (+0x96, +0x9E), Gold 2405 (+0xA6), 12 Plantagen-Fruchtbarkeiten (+0xB6 ... +0x10E),
# Schatz 533 (+0x116). Die Mengen sind fuer die 17-20 Vorlageninseln gedacht. Das Codestueck wird
# nach dem Kopieren der Inselliste aufgerufen (r8d = alte, [r15+0x64] = neue Inselzahl) und setzt
# jede Menge auf min(neue Inselzahl, Menge x neu / alt x Prozent / 100). Der Lader FUN_1400d0de0
# verteilt Fruchtbarkeit nur, solange passende Inseln frei sind, und Erz hoechstens 2 je Insel;
# was keinen Platz findet, entfaellt.
# Ureinwohner: im selben Codestueck. SZENE +0x40 / +0x44 = Zahl der Eingeborenendoerfer im Norden /
# Sueden (Vorlage 2 / 2). Der Lader waehlt so viele Inseln, deren Inseldatei einen Dorfplatz hat
# (Tabelle 0x1400F94E4-0x1400F98A3: 240 Dateien der Klassen lit bis big, keine "lar"), und laedt sie
# aus NORDNAT/SUEDNAT. Jedes Dorf belegt einen der 75 Siedlungsplaetze (FUN_14009a9f0, 0x140622DC0).
$RohCaveRva = 0xE5C00; $RohCaveEnde = 0xE5E00   # ab 0xE5E00: Codestuecke fuer Piraten und Haendler
$RohOffsets = @(0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE, 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE, 0x106, 0x10E, 0x116)
function Baue-Rohstoffcode([int]$prozent, [int]$doerfer = 0) {
    $c = New-Object System.Collections.Generic.List[byte]
    $marke = @{}; $fix = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$ziel) $c.Add($op); $fix.Add(@($c.Count, $ziel)); $c.Add(0) }
    if ($prozent -le 0) {
        if ($doerfer -gt 0) {
            & $E 0x41, 0xC7, 0x47, 0x40; & $E ([BitConverter]::GetBytes([int32]$doerfer))   # mov dword [r15+0x40],doerfer
            & $E 0x41, 0xC7, 0x47, 0x44; & $E ([BitConverter]::GetBytes([int32]$doerfer))   # mov dword [r15+0x44],doerfer
        }
        & $E 0xC3                                                                         # ret
        return , $c.ToArray()
    }
    & $E 0x48, 0x8D, 0x35; $listeFix = $c.Count; & $E 0, 0, 0, 0     # lea rsi,[liste]
    & $E 0x45, 0x8B, 0x4F, 0x64                                       # mov r9d,[r15+0x64]   neue Inselzahl
    $marke.naechste = $c.Count
    & $E 0x0F, 0xB7, 0x0E                                             # movzx ecx,word [rsi]  Offset
    & $E 0x85, 0xC9                                                   # test ecx,ecx
    & $J8 0x74 'ende'                                                 # jz ende
    & $E 0x41, 0x0F, 0xB7, 0x04, 0x0F                                 # movzx eax,word [r15+rcx]  Menge
    & $E 0x41, 0x0F, 0xAF, 0xC1                                       # imul eax,r9d
    & $E 0x69, 0xC0; & $E ([BitConverter]::GetBytes([int32]$prozent)) # imul eax,eax,prozent
    & $E 0x44, 0x89, 0xC7                                             # mov edi,r8d          alte Inselzahl
    & $E 0x6B, 0xFF, 0x64                                             # imul edi,edi,100
    & $E 0x85, 0xFF                                                   # test edi,edi
    & $J8 0x74 'weiter'                                               # jz weiter
    & $E 0x99, 0xF7, 0xFF                                             # cdq / idiv edi
    & $E 0x44, 0x39, 0xC8                                             # cmp eax,r9d
    & $E 0x7E, 0x03                                                   # jle +3
    & $E 0x44, 0x89, 0xC8                                             # mov eax,r9d           hoechstens neue Inselzahl
    & $E 0x66, 0x41, 0x89, 0x04, 0x0F                                 # mov [r15+rcx],ax
    $marke.weiter = $c.Count
    & $E 0x48, 0x83, 0xC6, 0x02                                       # add rsi,2
    & $J8 0xEB 'naechste'                                             # jmp naechste
    $marke.ende = $c.Count
    if ($doerfer -gt 0) {
        & $E 0x41, 0xC7, 0x47, 0x40; & $E ([BitConverter]::GetBytes([int32]$doerfer))   # mov dword [r15+0x40],doerfer
        & $E 0x41, 0xC7, 0x47, 0x44; & $E ([BitConverter]::GetBytes([int32]$doerfer))   # mov dword [r15+0x44],doerfer
    }
    & $E 0xC3                                                         # ret
    $liste = $c.Count
    foreach ($o in $RohOffsets) { & $E ([BitConverter]::GetBytes([uint16]$o)) }
    & $E 0, 0
    $b4 = [BitConverter]::GetBytes([int32]($liste - ($listeFix + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$listeFix + $i] = $b4[$i] }
    foreach ($f in $fix) {
        $d = $marke[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw "Interner Fehler: Sprung zu $($f[1]) zu weit." }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($RohCaveRva + $c.Count -gt $RohCaveEnde) { throw 'Interner Fehler: Rohstoff-Codestueck zu lang.' }
    , $c.ToArray()
}
$RohProzent = @{ Normal = 0; Mehr = 100; Viele = 200 }[$Rohstoffe]
$Doerfer = @{ Standard = 0; Mehr = 4; Viele = 7 }[$Ureinwohner]   # je Klimazone (Vorlage 2)

# Liest die Inselliste (Eintraege zu 16 Byte) aus dem SZENE-Abschnitt einer Vorlage.
function Lies-Vorlage([string]$pfad) {
    if (-not (Test-Path -LiteralPath $pfad)) { return $null }
    $d = [IO.File]::ReadAllBytes($pfad); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0) { break }
        if ($name -eq 'SZENE' -and $len -ge 0x174 + 50 * 16) {
            $s = $o + 20; $n = [BitConverter]::ToInt32($d, $s + 0x64)
            if ($n -lt 1 -or $n -gt 50) { return $null }
            return , @(for ($i = 0; $i -lt $n; $i++) { , [byte[]]$d[($s + 0x174 + 16 * $i)..($s + 0x174 + 16 * $i + 15)] })
        }
        $o += 20 + $len
    }
    $null
}

# Startpositionen der Schiffe (SHIP4: Eintraege zu 0x1B4 Byte, x/y als int16 bei +0x1C/+0x1E).
# Die Schiffe werden nicht gestreckt; der Inselplaner haelt diese Stellen frei.
function Lies-Schiffe([string]$pfad) {
    if (-not (Test-Path -LiteralPath $pfad)) { return , @() }
    $d = [IO.File]::ReadAllBytes($pfad); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0) { break }
        if ($name -eq 'SHIP4') { return , @(for ($i = 0; $i -lt [math]::Floor($len / 0x1B4); $i++) { , @([BitConverter]::ToInt16($d, $o + 20 + $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($d, $o + 20 + $i * 0x1B4 + 0x1E)) }) }
        $o += 20 + $len
    }
    , @()
}

# Plant die Inseln fuer eine Vorlage: Originale gestreckt, dazu Kopien in freien Luecken.
# Ergebnis: Liste von 16-Byte-Eintraegen (Klima, Klasse, Flags, Platz, Datei, -, x, y).
# $groesse: Normal = Klassen der Vorlage; Gross = Originale eine Klasse groesser (wo Platz ist),
# Kopien abwechselnd "lar" (100 x 90) und "big" (70 x 60); Riesig = Originale und Kopien "lar",
# wo das nicht passt "big". Geaenderte Originale bekommen eine zufaellige Inseldatei (0xFFFF).
# $schiffe: Startpunkte der Schiffe (x, y); vergroesserte und neue Inseln halten 2 Felder Abstand.
# (Bei 1000 x 700 und 2000 x 1400 aendert das die Plaene nicht; bei 750 x 525 Gross/Riesig lagen
# sonst Startschiffe in einer Insel.)
function Inselplan($vorlage, [int]$b, [int]$h, [bool]$nurStrecken, [string]$groesse = 'Normal', $schiffe = @()) {
    $schiffFrei = { param([int]$x, [int]$y, [int]$w, [int]$hh) foreach ($sp in $schiffe) { if ($sp[0] -ge $x - 2 -and $sp[0] -lt $x + $w + 2 -and $sp[1] -ge $y - 2 -and $sp[1] -lt $y + $hh + 2) { return $false } }; $true }
    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($e in $vorlage) {
        $n = [byte[]]$e.Clone()
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Truncate([BitConverter]::ToInt32($e, 8) * $b / 500)), 0, $n, 8, 4)
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Truncate([BitConverter]::ToInt32($e, 12) * $h / 350)), 0, $n, 12, 4)
        $plan.Add($n)
    }
    $ziel = [math]::Min($InselMax, [math]::Max($vorlage.Count, [math]::Floor($vorlage.Count * ($b * $h) / (500 * 350) * $InselDichte)))
    if ($nurStrecken) { $ziel = $vorlage.Count }
    $abstand = 14; $rand = 8
    # Inseldateien der Klasse "lar" gibt es nur 6 (NORD) bzw. 7 (SUED), in NORDNAT/SUEDNAT keine.
    # Im Spiel (2026-11-11) wurden von 23 geplanten "lar"-Inseln nur 15 geladen, der Rest fehlte.
    # Deshalb hoechstens $LarMax davon je Karte, sonst "big" (68 + 64 Dateien).
    $LarMax = 10
    $lar = @($plan | Where-Object { $_[1] -eq 4 }).Count
    if ($groesse -ne 'Normal' -and -not $nurStrecken) {
        for ($i = 0; $i -lt $plan.Count; $i++) {
            $e = $plan[$i]; $k0 = [int]$e[1]
            $wunsch = if ($groesse -eq 'Riesig') { @(4, 3) } else { @([math]::Min(4, $k0 + 1)) }
            foreach ($k in $wunsch) {
                if ($k -le $k0) { continue }
                if ($k -eq 4 -and $lar -ge $LarMax) { continue }
                $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12)
                if ($x + $KlasseB[$k] -gt $b - $rand -or $y + $KlasseH[$k] -gt $h - $rand) { continue }
                $frei = & $schiffFrei $x $y $KlasseB[$k] $KlasseH[$k]
                for ($j = 0; $j -lt $plan.Count -and $frei; $j++) {
                    if ($j -eq $i) { continue }
                    $p = $plan[$j]; $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12)
                    if ($x -lt $px + $KlasseB[$p[1]] + $abstand -and $px -lt $x + $KlasseB[$k] + $abstand -and $y -lt $py + $KlasseH[$p[1]] + $abstand -and $py -lt $y + $KlasseH[$k] + $abstand) { $frei = $false }
                }
                if ($frei) { $e[1] = [byte]$k; $e[4] = 0xFF; $e[5] = 0xFF; if ($k -eq 4) { $lar++ }; break }
            }
        }
    }
    $klassenFolge = switch ($groesse) { 'Gross' { @(4, 3) } 'Riesig' { @(4, 4, 4, 3) } default { $null } }
    $script:los = [long](($vorlage.Count * 7919 + [BitConverter]::ToInt32($vorlage[0], 8) * 31 + [BitConverter]::ToInt32($vorlage[0], 12)) % 2147483648)
    $quellen = @($vorlage | Sort-Object { - $_[1] }, { $_[3] })
    $qi = 0; $fehlschlaege = 0
    while ($plan.Count -lt $ziel -and $fehlschlaege -lt $quellen.Count) {
        $q = $quellen[$qi % $quellen.Count]
        $k = if ($klassenFolge) { $klassenFolge[$qi % $klassenFolge.Count] } else { $q[1] }
        if ($k -eq 4 -and $lar -ge $LarMax) { $k = 3 }
        $qi++
        $w = $KlasseB[$k]; $hh = $KlasseH[$k]
        $gefunden = $false
        for ($t = 0; $t -lt 800 -and -not $gefunden; $t++) {
            $script:los = ($script:los * 1103515245 + 12345) % 2147483648; $x = $rand + [int]($script:los % ($b - 2 * $rand - $w))
            $script:los = ($script:los * 1103515245 + 12345) % 2147483648; $y = $rand + [int]($script:los % ($h - 2 * $rand - $hh))
            $frei = & $schiffFrei $x $y $w $hh
            foreach ($p in $plan) {
                $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12); $pw = $KlasseB[$p[1]]; $ph = $KlasseH[$p[1]]
                if ($x -lt $px + $pw + $abstand -and $px -lt $x + $w + $abstand -and $y -lt $py + $ph + $abstand -and $py -lt $y + $hh + $abstand) { $frei = $false; break }
            }
            if ($frei) {
                $n = New-Object byte[] 16
                $n[0] = 2; $n[1] = $k; $n[2] = 0; $n[3] = [byte]$plan.Count; $n[4] = 0xFF; $n[5] = 0xFF
                [Array]::Copy([BitConverter]::GetBytes([int32]$x), 0, $n, 8, 4); [Array]::Copy([BitConverter]::GetBytes([int32]$y), 0, $n, 12, 4)
                $plan.Add($n); $gefunden = $true; if ($k -eq 4) { $lar++ }
            }
        }
        if ($gefunden) { $fehlschlaege = 0 } else { $fehlschlaege++ }
    }
    for ($i = 0; $i -lt $plan.Count; $i++) { $plan[$i][3] = [byte]$i }   # Platz = Index
    , $plan.ToArray()
}

# Tabelle: int32 Zahl der Eintraege, dann je Eintrag: Inselzahl, x0, y0 der Vorlage, neue Inselzahl, 50 x 16 Byte.
function Baue-Tabelle([int]$b, [int]$h, [bool]$nurStrecken, [string]$groesse = 'Normal') {
    $t = New-Object System.Collections.Generic.List[byte]
    $eintraege = 0; $script:InselPlaene = @{}
    if (-not $nurStrecken) {
        foreach ($anordnung in 0, 1, 2) {
            $v = Lies-Vorlage (Join-Path $SpielOrdner "Szenes\[[48]]0$anordnung.szs")
            if (-not $v) { continue }
            $plan = Inselplan $v $b $h $false $groesse (Lies-Schiffe (Join-Path $SpielOrdner "Szenes\[[48]]1$anordnung.szs"))
            $script:InselPlaene[$anordnung] = $plan
            foreach ($x in [BitConverter]::GetBytes([int32]$v.Count)) { $t.Add($x) }
            foreach ($x in $v[0][8..15]) { $t.Add($x) }
            foreach ($x in [BitConverter]::GetBytes([int32]$plan.Count)) { $t.Add($x) }
            for ($i = 0; $i -lt 50; $i++) { if ($i -lt $plan.Count) { foreach ($x in $plan[$i]) { $t.Add($x) } } else { 1..16 | ForEach-Object { $t.Add(0) } } }
            $eintraege++
        }
    }
    $kopf = [BitConverter]::GetBytes([int32]$eintraege)
    $alles = [byte[]]($kopf + $t.ToArray())
    if ($alles.Length -gt $TabelleMax) { throw 'Interner Fehler: Inseltabelle zu gross.' }
    , $alles
}

if (-not $OhneInselVerteilung) {
    $mitRohstoffen = ($RohProzent -gt 0 -or $Doerfer -gt 0) -and -not $NurStrecken
    $mitGrosskarte = -not $NurStrecken
    $InselCode = Baue-Codestueck $mitRohstoffen $mitGrosskarte
    if ($mitGrosskarte) {
        $GrossCode = Baue-Grosskartencode
        $Stellen += @{ Name = 'Grosse Kampagnenkarten      '; Rva = $GrossCaveRva; Original = ((@('00') * $GrossCode.Length) -join ' '); Soll = $GrossCode; NurSpeicher = $true }
    }
    $InselTabelle = Baue-Tabelle $Breite $Hoehe $NurStrecken.IsPresent $Inselgroesse
    $Haken = [byte[]](@(0xE9) + (Rel32 $CaveRva ($HakenRva + 5)) + @(0x66, 0x90))
    # Reihenfolge wichtig: erst Tabelle und Codestuecke, dann der Sprung (Rueckbau umgekehrt).
    $Stellen += @{ Name = 'Inselverteilung (Tabelle)   '; Rva = $TabelleRva; Original = ((@('00') * $InselTabelle.Length) -join ' '); Soll = $InselTabelle; NurSpeicher = $true }
    if ($mitRohstoffen) {
        $RohCode = Baue-Rohstoffcode $RohProzent $Doerfer
        $Stellen += @{ Name = 'Rohstoffe (Codestueck)      '; Rva = $RohCaveRva; Original = ((@('00') * $RohCode.Length) -join ' '); Soll = $RohCode; NurSpeicher = $true }
        if ($RohProzent -gt 0) { Write-Host ("Rohstoffe: {0} (Erz, Gold, Fruchtbarkeit und Schaetze mit der Inselzahl x {1} %, hoechstens 1 je Insel)" -f $Rohstoffe, $RohProzent) }
        if ($Doerfer -gt 0) { Write-Host ("Ureinwohner: {0} ({1} Doerfer je Klimazone statt 2)" -f $Ureinwohner, $Doerfer) }
    }
    elseif ($RohProzent -gt 0 -or $Doerfer -gt 0) { Write-Host 'Rohstoffe/Ureinwohner: wirken nur mit zusaetzlichen Inseln (nicht mit -NurStrecken); NICHT gesetzt.' -ForegroundColor Yellow }
    if ($Inselgroesse -ne 'Normal') { Write-Host "Inselgroesse: $Inselgroesse" }
    $Stellen += @{ Name = 'Inselverteilung (Codestueck)'; Rva = $CaveRva; Original = ((@('00') * $InselCode.Length) -join ' '); Soll = $InselCode }
    $Stellen += @{ Name = 'Inselverteilung (Sprung)    '; Rva = $HakenRva; Original = '4C 8D 1D D0 F1 F2 FF'; Soll = $Haken }
    foreach ($a in ($script:InselPlaene.Keys | Sort-Object)) { Write-Host ("Inselplan Anordnung {0}: {1} Inseln" -f $a, $script:InselPlaene[$a].Count) }
}

# --- Piraten ------------------------------------------------------------------------------------
# Herleitung: analysis\BEFUNDE.md, Abschnitt "Gegner und Piraten".
# Die Piraten (Spielerart 0xE) handeln in FUN_14003dc40 nur, wenn Bit 0 der Spielvariable
# 0x1405ec188 geloescht ist (gesetzt bei Einfach/Durchschnittlich = "gelegentliche Sichtungen").
# Der Wert kommt beim Laden einer Vorlage oder eines Spielstands aus dem TIMERS-Abschnitt
# (FUN_1400c2da0). Am Ende dieses Laders (RVA 0xC3232, nur auf dem Weg "Abschnitt erkannt")
# springt ein Haken in ein Codestueck (RVA 0xE5F80): ersetzter Befehl, Bit setzen/loeschen, zurueck.
# Stark: FUN_14003b7e0 bestueckt Piratenschiffe je nach Schwierigkeit mit (n+1)/2, n+2 oder 2n+4
# Kanonen, hoechstens dem Maximum des Schiffstyps. RVA 0x3B94B: "mov esi,256; jmp" -> immer Maximum.
# Startgeld: im selben Codestueck. Neues Spiel = Spieluhr 0x1405ec0f8 (aus TIMERS +0xA0) unter 1000
# (Vorlagen 10-24, Spielstaende > 20'000; die Uhr laeuft ca. 10 pro Sekunde). Dann wird das Geld
# des Spielers auf Platz 0 (Spielertabelle 0x1405f0960, Geld +4) gesetzt. PLAYER4 (Startgeld der
# Vorlage) wird vor TIMERS geladen, der Wert der Vorlage wird also ueberschrieben.
$PiratCaveRva = 0xE5F80; $TimersHakenRva = 0xC3232; $TimersWeiter = 0xC3239
$FlagsRva = 0x5EC188; $TimersMovapsZiel = 0x5BE5F0; $UhrRva = 0x5EC0F8; $Geld0Rva = 0x5F0964
$SpielerGroesse = 0x280   # Spielertabelle: 7 Plaetze a 640 Byte (FUN_1400a87f0); 1-3 = Computergegner
$KanonenRva = 0x3B94B; $KanonenOrig = '8B 05 6F 08 5B 00 83'; $KanonenSoll = 'BE 00 01 00 00 EB 3B'
function Baue-Piratencode([string]$art, [int]$geld = 0, [int]$gegnerGeld = 0) {
    $c = New-Object System.Collections.Generic.List[byte]
    # RIP-relativ: rel32 bezieht sich auf das Befehlsende (nach einem evtl. Sofortwert $nach).
    $Rip = { param([byte[]]$op, [long]$zielRva, [byte[]]$nach) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $zielRva ($PiratCaveRva + $c.Count + 4 + $nach.Length))) { $c.Add($x) }; foreach ($x in $nach) { $c.Add($x) } }
    & $Rip ([byte[]](0x0F, 0x29, 0x05)) $TimersMovapsZiel ([byte[]]@())        # movaps [0x1405be5f0],xmm0 (ersetzter Befehl)
    if ($art -eq 'Aus') { & $Rip ([byte[]](0x83, 0x0D)) $FlagsRva ([byte[]](0x01)) }   # or  dword [0x1405ec188],1
    elseif ($art -ne 'Standard') { & $Rip ([byte[]](0x83, 0x25)) $FlagsRva ([byte[]](0xFE)) }   # and dword [0x1405ec188],~1
    if ($geld -gt 0) {
        & $Rip ([byte[]](0x81, 0x3D)) $UhrRva ([BitConverter]::GetBytes([int32]1000))  # cmp dword [Spieluhr],1000
        $c.Add(0x73); $c.Add(10)                                                      # jae +10 (Spielstand: nichts tun)
        & $Rip ([byte[]](0xC7, 0x05)) $Geld0Rva ([BitConverter]::GetBytes([int32]$geld))  # mov dword [Geld Platz 0],geld
    }
    if ($gegnerGeld -gt 0) {
        & $Rip ([byte[]](0x81, 0x3D)) $UhrRva ([BitConverter]::GetBytes([int32]1000))  # cmp dword [Spieluhr],1000
        $c.Add(0x73); $c.Add(30)                                                      # jae +30 (Spielstand: nichts tun)
        foreach ($platz in 1..3) {                                                    # mov dword [Geld Platz 1-3],gegnerGeld
            & $Rip ([byte[]](0xC7, 0x05)) ($Geld0Rva + $platz * $SpielerGroesse) ([BitConverter]::GetBytes([int32]$gegnerGeld))
        }
    }
    & $Rip ([byte[]](0xE9)) $TimersWeiter ([byte[]]@())                         # jmp zurueck (Ende des Laders)
    if ($PiratCaveRva + $c.Count -gt 0xE6000) { throw 'Interner Fehler: Piraten-Codestueck zu lang.' }
    , $c.ToArray()
}
if ($Piraten -ne 'Standard' -or $Startgeld -gt 0 -or $GegnerGeld -gt 0) {
    $PiratCode = Baue-Piratencode $Piraten $Startgeld $GegnerGeld
    $PiratHaken = [byte[]](@(0xE9) + (Rel32 $PiratCaveRva ($TimersHakenRva + 5)) + @(0x66, 0x90))
    # Reihenfolge: erst Codestueck, dann Sprung.
    $Stellen += @{ Name = 'TIMERS-Lader (Codestueck)   '; Rva = $PiratCaveRva; Original = ((@('00') * $PiratCode.Length) -join ' '); Soll = $PiratCode; NurSpeicher = $true }
    $Stellen += @{ Name = 'TIMERS-Lader (Sprung)       '; Rva = $TimersHakenRva; Original = '0F 29 05 B7 B3 4F 00'; Soll = $PiratHaken }
    if ($Piraten -eq 'Stark') {
        $Stellen += @{ Name = 'Piraten (volle Kanonen)     '; Rva = $KanonenRva; Original = $KanonenOrig; Soll = (Bytes $KanonenSoll) }
    }
    if ($Piraten -ne 'Standard') { Write-Host "Piraten: $Piraten" }
    if ($Startgeld -gt 0) { Write-Host ("Startgeld bei neuen Spielen: {0}" -f $Startgeld) }
    if ($GegnerGeld -gt 0) { Write-Host ("Gold der Computergegner bei neuen Spielen: {0}" -f $GegnerGeld) }
}

# --- Gegner, Piratenflotte, Haendler -------------------------------------------------------------
# Herleitung: analysis\BEFUNDE.md, Abschnitt "Gegner, Piratenflotte, Ureinwohner, Haendler".
# Gegner Schwer: Die KI liest die Schwierigkeit 0x1405ec1c0 (0-3) an vier Stellen mit
# "mov eax,[rip+rel32]" (8B 05 rel32) und setzt damit ihre Ziele (Militaer im Vergleich zum
# staerksten Spieler, Schiffe, Ausbau): Stufe 3 = x2 bzw. +50 %. Ersetzt durch "mov eax,3; nop".
# Naturereignisse (FUN_14009e390) und Kanonen der Piraten (FUN_14003b7e0) bleiben bei der echten Stufe.
$GegnerStellen = @(
    @{ Name = 'KI Schwer (FUN_140017840)'; Rva = 0x17A8E; Original = '8B 05 2C 47 5D 00' }
    @{ Name = 'KI Schwer (FUN_140017b30)'; Rva = 0x17EA1; Original = '8B 05 19 43 5D 00' }
    @{ Name = 'KI Schwer (FUN_140032090)'; Rva = 0x321C9; Original = '8B 05 F1 9F 5B 00' }
    @{ Name = 'KI Schwer (FUN_140035220)'; Rva = 0x35344; Original = '8B 05 76 6E 5B 00' }
)
if ($Gegner -eq 'Schwer') {
    foreach ($g in $GegnerStellen) { $Stellen += @{ Name = $g.Name.PadRight(28); Rva = $g.Rva; Original = $g.Original; Soll = (Bytes 'B8 03 00 00 00 90') } }
    Write-Host 'Computergegner: immer wie Schwer'
}

# Piratenflotte: FUN_14003b7e0 (nur Piraten, aufgerufen aus FUN_14003dc40) vergleicht die Zahl der
# Piratenschiffe (+0x1076c) mit FUN_1400185f0 (hoechste Zivilisationsstufe von Mensch und KI, 0-4)
# und laesst bei weniger Schiffen ein neues entstehen (FUN_140070d80(3), Schiffstabelle 200 Plaetze).
# RVA 0x3B7F1 "call FUN_1400185f0" -> "call Codestueck" (RVA 0xE5E00): sub rsp,0x28 (Schattenbereich
# und Ausrichtung) / call FUN_1400185f0 / add rsp,0x28 / imul eax,eax,F / ret. Die Wartezeit bis zum
# naechsten Schiff (0x1405ebf1c x 1000, RVA 0x3B8D2 und 0x3B9CE) wird durch F geteilt.
$FlotteCaveRva = 0xE5E00; $FlotteRufRva = 0x3B7F1; $StufeRva = 0x185F0
$FlotteFaktor = @{ Normal = 1; Gross = 2; Riesig = 3 }[$Piratenflotte]
$FlotteWarte = @(
    @{ Rva = 0x3B8D2; Original = '69 05 40 06 5B 00 E8 03 00 00' }
    @{ Rva = 0x3B9CE; Original = '69 05 44 05 5B 00 E8 03 00 00' }
)
function Baue-Flottencode([int]$faktor) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x48, 0x83, 0xEC, 0x28) { $c.Add($x) }                                          # sub rsp,0x28
    $c.Add(0xE8); foreach ($x in (Rel32 $StufeRva ($FlotteCaveRva + $c.Count + 4))) { $c.Add($x) }   # call FUN_1400185f0
    foreach ($x in 0x48, 0x83, 0xC4, 0x28) { $c.Add($x) }                                          # add rsp,0x28
    foreach ($x in 0x6B, 0xC0, [byte]$faktor) { $c.Add($x) }                                       # imul eax,eax,faktor
    $c.Add(0xC3)                                                                                    # ret
    , $c.ToArray()
}
if ($FlotteFaktor -gt 1) {
    $FlotteCode = Baue-Flottencode $FlotteFaktor
    $Stellen += @{ Name = 'Piratenflotte (Codestueck)  '; Rva = $FlotteCaveRva; Original = ((@('00') * $FlotteCode.Length) -join ' '); Soll = $FlotteCode; NurSpeicher = $true }
    $Stellen += @{ Name = 'Piratenflotte (Aufruf)      '; Rva = $FlotteRufRva; Original = 'E8 FA CD FD FF'; Soll = [byte[]](@(0xE8) + (Rel32 $FlotteCaveRva ($FlotteRufRva + 5))) }
    foreach ($w in $FlotteWarte) {
        $soll = Bytes $w.Original
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Floor(1000 / $FlotteFaktor)), 0, $soll, 6, 4)
        $Stellen += @{ Name = 'Piratenflotte (Wartezeit)   '; Rva = $w.Rva; Original = $w.Original; Soll = $soll }
    }
    Write-Host ("Piratenflotte: {0} ({1}-mal so viele Schiffe, bis {2})" -f $Piratenflotte, $FlotteFaktor, (4 * $FlotteFaktor))
}

# Haendler: FUN_1400bc030 zaehlt die Siedlungen (0x1405bd228) und haelt (Zahl + 2) / 3 freie
# Haendlerschiffe (Zaehler 0x1406d7e68). RVA 0xBC140 "shr eax,31; add edx,eax" (Vorzeichenkorrektur,
# hier immer 0; eax wird danach nicht mehr gelesen) -> "call Codestueck" (RVA 0xE5E20):
# edx = min(edx x F, 24); ret. Es gibt 30 Haendlerdatensaetze (0x1405a8450, FUN_14008be30 bricht ab
# Nr. 30 ab), deshalb hoechstens 24.
$HaendlerCaveRva = 0xE5E20; $HaendlerRva = 0xBC140; $HaendlerMax = 24
$HaendlerFaktor = @{ Standard = 1; Mehr = 2; Viele = 3 }[$Haendler]
function Baue-Haendlercode([int]$faktor) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x6B, 0xD2, [byte]$faktor) { $c.Add($x) }                 # imul edx,edx,faktor
    foreach ($x in 0x83, 0xFA, [byte]$HaendlerMax) { $c.Add($x) }            # cmp edx,24
    foreach ($x in 0x7E, 0x05) { $c.Add($x) }                                # jle +5
    $c.Add(0xBA); foreach ($x in [BitConverter]::GetBytes([int32]$HaendlerMax)) { $c.Add($x) }   # mov edx,24
    $c.Add(0xC3)                                                             # ret
    , $c.ToArray()
}
if ($HaendlerFaktor -gt 1) {
    $HaendlerCode = Baue-Haendlercode $HaendlerFaktor
    $Stellen += @{ Name = 'Haendler (Codestueck)       '; Rva = $HaendlerCaveRva; Original = ((@('00') * $HaendlerCode.Length) -join ' '); Soll = $HaendlerCode; NurSpeicher = $true }
    $Stellen += @{ Name = 'Haendler (Aufruf)           '; Rva = $HaendlerRva; Original = 'C1 E8 1F 03 D0'; Soll = [byte[]](@(0xE8) + (Rel32 $HaendlerCaveRva ($HaendlerRva + 5))) }
    Write-Host ("Haendler: {0} ({1}-mal so viele freie Haendlerschiffe, hoechstens {2})" -f $Haendler, $HaendlerFaktor, $HaendlerMax)
}

# --- Turbo --------------------------------------------------------------------------------------
# Tastatur FUN_1400e2d60: F5/F6/F7 rufen FUN_1400c8be0(1/2/4) auf (Spielgeschwindigkeit 0x1400f99f8).
# Die Spielschleife FUN_1400c8e20 rechnet Zeit x Faktor in Schritten zu 200; FUN_140060560 kennt
# schon Faktoren ab 5. F7 bei RVA 0xE3376: "mov ecx,4" -> "mov ecx,<TurboStufe>". Gemessen bei 8-fach
# (40 grosse Inseln): genau 8,0-fach bei ca. 53 % eines Prozessorkerns.
if ($Turbo) {
    $Stellen += @{ Name = ('Spieltempo F7 ({0}-fach)' -f $TurboStufe).PadRight(28); Rva = 0xE3376; Original = 'B9 04 00 00 00'; Soll = [byte[]](0xB9, $TurboStufe, 0, 0, 0) }
    Write-Host "Turbo: F7 = $TurboStufe-fach"
}

# --- Einwohner, Laderaum, Produktion ------------------------------------------------------------
# Einwohner: haeuser.cod "Maxwohn" der Bevoelkerungsgruppen 0-4 (BGRUPPE), vom Parser x 64 als int
# bei RVA 0x6BA02C + Nr. * 0x50 abgelegt. Haeuser speichern ihre Einwohner x 64 als 16 Bit (Haus +6);
# FUN_1400b7c60 vergleicht damit und schaltet die Stufe weiter. Alle fuenf Werte werden mit demselben
# Faktor multipliziert, die Verhaeltnisse bleiben also gleich.
$WohnRva = 0x6BA02C; $WohnGroesse = 0x50
$WohnOrig = @(128, 384, 960, 1600, 2560)   # 2/6/15/25/40 Einwohner x 64
if ($Einwohner -ne 1.0) { Write-Host ("Einwohner: x{0:0.##} ({1} statt 40 je Haus der hoechsten Stufe)" -f $Einwohner, [int][math]::Round(40 * $Einwohner)) }
# Laderaum: figuren.cod "Maxware" (Tonnen je Laderaum x 32) als 16 Bit bei Figurentabelle +0x3E;
# gelesen u. a. vom Schiffslader FUN_14008e4f0. Nr. 21-28: kleines/grosses Handelsschiff,
# kleines/grosses Kriegsschiff (50/80/65/120 t, im Spiel gelesen 2026-11-09).
$LadeOffset = 0x3E
$LadeOrig = @{ 21 = 1600; 22 = 1600; 23 = 2560; 24 = 2560; 25 = 2080; 26 = 2080; 27 = 3840; 28 = 3840 }
if ($Laderaum -ne 1.0) { Write-Host ("Laderaum: x{0:0.##} (kleines Handelsschiff {1} t statt 50 t je Laderaum)" -f $Laderaum, [int][math]::Round(50 * $Laderaum)) }
# Produktion: haeuser.cod "Interval" als 16 Bit bei Gebaeudetabelle +0x3A (Parser 0x140091... ,
# DAT_1406ba1fa). Gelesen bei jedem Arbeitsschritt in FUN_1400b43e0 und FUN_1400b9ed0 ueber den
# Zeiger auf den Gebaeudeeintrag. Marke 'NUFR' + Faktor x 100 bei RVA 0xE5F70 (freie Bytes vor dem
# Piraten-Codestueck, nur im Speicher) verhindert doppeltes Teilen im selben Spielprozess.
$IntervalOffset = 0x3A; $GebaeudeAnzahl = 500   # MAXHAUS (FUN_140002ae0("MAXHAUS",500))
$ProdMarkeRva = 0xE5F70
if ($Produktion -ne 1.0) { Write-Host ("Produktion: x{0:0.##} (Arbeitsintervalle aller Betriebe geteilt)" -f $Produktion) }

# --- Schiffstempo -----------------------------------------------------------------------------
# Figurentabelle ab RVA 0x6D80C0, je 0x18C Byte; figuren.cod "Speed" wird beim Programmstart als
# Kommazahl (Speed/10000) bei +0x10 abgelegt (Parser 0x14006A4D7) und laufend gelesen (z. B.
# FUN_1400b9760). Schiffstypen Nr. 21-32 (je zwei Eintraege): kleines/grosses Handelsschiff,
# kleines/grosses Kriegsschiff, Haendler, Pirat. Originalwerte im Spiel gelesen (2026-11-09).
$FigurRva = 0x6D80C0; $FigurGroesse = 0x18C; $TempoOffset = 0x10
# Normale Hashtable: bei [ordered] waere $x[21] die 22. Position statt der Schluessel 21.
$SchiffTempoOrig = @{
    21 = 'CD CC 4C 3D'; 22 = 'CD CC 4C 3D'; 23 = '0A D7 23 3D'; 24 = '0A D7 23 3D'; 25 = 'AE 47 61 3D'; 26 = 'AE 47 61 3D'
    27 = '8F C2 75 3D'; 28 = '8F C2 75 3D'; 29 = 'A6 9B 44 3D'; 30 = 'A6 9B 44 3D'; 31 = 'EC 51 38 3D'; 32 = 'EC 51 38 3D'
}
function Tempo-Soll([string]$origHex, [double]$faktor) {
    [BitConverter]::GetBytes([single]([double][BitConverter]::ToSingle((Bytes $origHex), 0) * $faktor))
}
if ($Schiffstempo -ne 1.0) { Write-Host ("Schiffstempo: x{0:0.##}" -f $Schiffstempo) }

# --- Lager --------------------------------------------------------------------------------------
# Gebaeudetabelle ab RVA 0x6BA1C0, je 0x90 Byte; haeuser.cod "Maxlager" steht als 16-Bit-Wert x 32
# bei +0x30 (Parser 0x1400919C4). Ein neuer Kontor uebernimmt den Wert als Lagergrenze (Kontor +0x20,
# im Spiel gelesen: 960 = 30 t). Nr. 270-273 Kontor I-IV, 401/467/468 Markt (im Spiel gelesen).
$GebaeudeRva = 0x6BA1C0; $GebaeudeGroesse = 0x90; $LagerOffset = 0x30
$LagerOrig = @{ 270 = 960; 271 = 1600; 272 = 2400; 273 = 3200; 401 = 320; 467 = 320; 468 = 320 }
if ($Lager -ne 1) { Write-Host ("Lager: x{0} (Kontor I {1} t statt 30 t)" -f $Lager, (30 * $Lager)) }
foreach ($s in $Stellen) { $s.Laenge = (Bytes $s.Original).Length }
function Anzeige-Stelle($s, [byte[]]$b) {
    if ($s.Wert) { Anzeige $s.Wert $b[6..9] } else { "gesetzt ($($b.Length) Bytes)" }
}

# --- 1. exe auf der Festplatte pruefen -------------------------------------------------------
$exe = Join-Path $SpielOrdner 'Anno1602.exe'
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $ErwarteterHash) {
    throw "Unbekannte Version von Anno1602.exe (SHA-256 $hash). Das Werkzeug passt nur zu $ErwarteterHash. Abbruch, nichts geaendert."
}
$datei = [IO.File]::ReadAllBytes($exe)
foreach ($s in $Stellen) {
    if ($s.NurSpeicher) { continue }   # liegt hinter den Dateidaten von .text, nur im Speicher
    $off = $s.Rva - 0x1000 + 0x400   # .text: RVA 0x1000 liegt in der Datei bei 0x400
    $ist = Hex $datei[$off..($off + $s.Laenge - 1)]
    if ($ist -ne $s.Original) { throw "Bytes an $($s.Name) passen nicht ($ist). Abbruch, nichts geaendert." }
}
Write-Host "exe geprueft: Version passt, alle $($Stellen.Count) Stellen gefunden." -ForegroundColor Green
if ($NurPruefen) { return }

# --- 2. Spielstaende sichern -----------------------------------------------------------------
$werkzeugStart = Get-Date
$saves = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Savegame'
# Inhalt eines Ordners als Text: relativer Pfad, Groesse und Aenderungszeit jeder Datei.
function Signatur([string]$ordner) {
    Get-ChildItem -LiteralPath $ordner -Recurse -File | Sort-Object FullName |
        ForEach-Object { '{0}|{1}|{2}' -f $_.FullName.Substring($ordner.Length), $_.Length, $_.LastWriteTimeUtc.Ticks } | Out-String
}
if ($TestProzessId -eq 0 -and (Test-Path -LiteralPath $saves)) {
    $letzte = Get-ChildItem -LiteralPath (Split-Path $saves) -Directory | Where-Object { $_.Name -like 'Savegame-Sicherung-*' } |
        Sort-Object Name | Select-Object -Last 1
    if ($letzte -and (Signatur $letzte.FullName) -eq (Signatur $saves)) {
        Write-Host "Spielstaende unveraendert seit der Sicherung $($letzte.Name); keine neue Sicherung noetig."
    }
    else {
        $ziel = "$saves-Sicherung-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $saves -Destination $ziel -Recurse
        Write-Host "Spielstaende gesichert nach: $ziel"
    }
}

# --- 3. Auf das Spiel warten -----------------------------------------------------------------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AnnoMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtectEx(IntPtr h, IntPtr addr, IntPtr size, uint prot, out uint old);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FlushInstructionCache(IntPtr h, IntPtr addr, IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
}
'@

function Lies([long]$rva, [int]$n) {
    $buf = New-Object byte[] $n
    $done = [IntPtr]::Zero
    if (-not [AnnoMem]::ReadProcessMemory($script:h, [IntPtr]($script:basis.ToInt64() + $rva), $buf, [IntPtr]$n, [ref]$done)) {
        throw ("Lesen bei RVA 0x{0:X} fehlgeschlagen (Fehler {1})." -f $rva, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    , $buf
}
function Schreib([long]$rva, [byte[]]$daten, [bool]$code) {
    $addr = [IntPtr]($script:basis.ToInt64() + $rva)
    $alt = [uint32]0
    if ($code -and -not [AnnoMem]::VirtualProtectEx($script:h, $addr, [IntPtr]$daten.Length, 0x40, [ref]$alt)) {
        throw ("Schreibschutz bei RVA 0x{0:X} nicht aufhebbar (Fehler {1})." -f $rva, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    $done = [IntPtr]::Zero
    $ok = [AnnoMem]::WriteProcessMemory($script:h, $addr, $daten, [IntPtr]$daten.Length, [ref]$done)
    $fehler = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($code) {
        $egal = [uint32]0
        [void][AnnoMem]::VirtualProtectEx($script:h, $addr, [IntPtr]$daten.Length, $alt, [ref]$egal)
        [void][AnnoMem]::FlushInstructionCache($script:h, $addr, [IntPtr]$daten.Length)
    }
    if (-not $ok) { throw ("Schreiben bei RVA 0x{0:X} fehlgeschlagen (Fehler {1})." -f $rva, $fehler) }
}
# Laeuft der Prozess hinter $script:h noch? (STILL_ACTIVE = 259)
function Laeuft {
    $c = [uint32]0
    [AnnoMem]::GetExitCodeProcess($script:h, [ref]$c) -and $c -eq 259
}

# Tabellenwerte mit bekannten Originalen setzen (wie Lager): warten, bis alle geladen sind (nicht 0),
# jeder muss Original oder schon Zielwert sein, dann alle schreiben und nachlesen.
# $eintraege: @{ Rva; Orig; Soll; Bytes = 2 oder 4 }. Rueckgabe: $true gesetzt, $false nicht gesetzt,
# $null = Prozess hat sich beendet.
function Lies-Zahl($e) {
    $b = Lies $e.Rva $e.Bytes
    if ($e.Bytes -eq 2) { [int][BitConverter]::ToUInt16($b, 0) } else { [BitConverter]::ToInt32($b, 0) }
}
function Setze-Tabelle([string]$was, $eintraege) {
    while ($true) {
        $bereit = $true
        foreach ($e in $eintraege) {
            $ist = Lies-Zahl $e
            if ($ist -eq 0) { $bereit = $false; break }
            if ($ist -ne $e.Orig -and $ist -ne $e.Soll) {
                Write-Host ("{0}: unerwarteter Wert {1} statt {2} (RVA 0x{3:X}); NICHT gesetzt (Rest ist aktiv)." -f $was, $ist, $e.Orig, $e.Rva) -ForegroundColor Yellow
                return $false
            }
        }
        if ($bereit) { break }
        if (-not (Laeuft)) { return $null }
        if ((Get-Date) -gt $script:frist) { Write-Host "${was}: Werte noch nicht geladen; NICHT gesetzt." -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    foreach ($e in $eintraege) {
        $d = if ($e.Bytes -eq 2) { [BitConverter]::GetBytes([uint16]$e.Soll) } else { [BitConverter]::GetBytes([int32]$e.Soll) }
        Schreib $e.Rva $d $false
    }
    foreach ($e in $eintraege) { if ((Lies-Zahl $e) -ne $e.Soll) { throw ("Kontrolle {0} fehlgeschlagen (RVA 0x{1:X})." -f $was, $e.Rva) } }
    $true
}

# Produktion: alle Intervalle der Gebaeudetabelle durch den Faktor teilen (einmal je Spielprozess).
function Setze-Produktion([double]$faktor) {
    $signal = $GebaeudeRva + 270 * $GebaeudeGroesse + $LagerOffset   # Lager Kontor I: haeuser.cod gelesen
    while ([BitConverter]::ToUInt16((Lies $signal 2), 0) -eq 0) {
        if (-not (Laeuft)) { return $null }
        if ((Get-Date) -gt $script:frist) { Write-Host 'Produktion: Gebaeudewerte noch nicht geladen; NICHT gesetzt.' -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    $marke = [byte[]](@(0x4E, 0x55, 0x46, 0x52) + [BitConverter]::GetBytes([int32][math]::Round($faktor * 100)))   # 'NUFR', Faktor x 100
    $ist = Hex (Lies $ProdMarkeRva 8)
    if ($ist -eq (Hex $marke)) { Write-Host ("Produktion x{0:0.##}: in diesem Spielprozess schon gesetzt." -f $faktor) -ForegroundColor Green; return $true }
    if ($ist -ne (Hex ([byte[]](0, 0, 0, 0, 0, 0, 0, 0)))) {
        Write-Host "Produktion: im Spiel ist schon ein anderer Faktor gesetzt ($ist); NICHT geaendert. Fuer einen anderen Faktor das Spiel neu starten." -ForegroundColor Yellow
        return $false
    }
    # Erst lesen, wenn sich die Tabelle nicht mehr aendert (der Parser koennte noch laufen).
    $laenge = $GebaeudeAnzahl * $GebaeudeGroesse
    $tab = Lies $GebaeudeRva $laenge
    for ($versuch = 0; $versuch -lt 20; $versuch++) {
        Start-Sleep -Milliseconds 300
        $neu = Lies $GebaeudeRva $laenge
        if ((Hex $neu) -eq (Hex $tab)) { break }
        $tab = $neu
    }
    $n = 0
    for ($i = 0; $i -lt $GebaeudeAnzahl; $i++) {
        $off = $i * $GebaeudeGroesse + $IntervalOffset
        $v = [int][BitConverter]::ToUInt16($tab, $off)
        if ($v -eq 0) { continue }
        $soll = [math]::Max(1, [int][math]::Round($v / $faktor))
        if ($soll -ne $v) { Schreib ($GebaeudeRva + $off) ([BitConverter]::GetBytes([uint16]$soll)) $false; $n++ }
    }
    Schreib $ProdMarkeRva $marke $true
    if ((Hex (Lies $ProdMarkeRva 8)) -ne (Hex $marke)) { throw 'Kontrolle der Produktions-Marke fehlgeschlagen.' }
    Write-Host ("Produktion x{0:0.##}: {1} Arbeitsintervalle verkuerzt." -f $faktor, $n) -ForegroundColor Green
    $true
}

# Patcht den Prozess hinter $script:h. Rueckgabe: $true = fertig, $false = Prozess hat sich vorher beendet.
function Patche($proc) {
    # --- 4. Erst alle Stellen pruefen, dann schreiben (alles oder nichts) -------------------
    foreach ($s in $Stellen) {
        $ist = Hex (Lies $s.Rva $s.Laenge)
        if ($ist -ne $s.Original -and $ist -ne (Hex $s.Soll)) { throw "Im Speicher stehen an $($s.Name) unerwartete Bytes ($ist). Abbruch, nichts geaendert." }
    }
    # Variablen: 0 (Spiel startet noch), Originalwert oder schon der Zielwert.
    foreach ($v in $Variablen) {
        $ist = Hex (Lies $v.Rva 4)
        if ($ist -ne $null4 -and $ist -ne (Hex $orig[$v.Wert]) -and $ist -ne (Hex $werte[$v.Wert])) {
            throw "Variable $($v.Name.Trim()) hat einen unerwarteten Wert ($ist). Abbruch, nichts geaendert."
        }
    }
    # Laeuft schon ein Spiel mit 500 x 350, wuerden Raster und Groesse nicht mehr zusammenpassen.
    $breiteJetzt = [BitConverter]::ToInt32((Lies $Variablen[0].Rva 4), 0)
    $alter = [TimeSpan]::Zero
    try { $alter = (Get-Date) - $proc.StartTime } catch { }
    if ($TestProzessId -eq 0 -and $breiteJetzt -ne 0 -and $breiteJetzt -ne $Breite -and $alter.TotalSeconds -gt 120 -and -not $SpielLaeuftBereits) {
        throw (("Das Spiel laeuft schon seit {0:0} Minuten. Wenn gerade eine Karte geladen ist, waere das Umstellen gefaehrlich. " +
            "Spiel beenden, Werkzeug starten, dann Spiel starten. (Steht es sicher im Hauptmenue: -SpielLaeuftBereits.) Abbruch, nichts geaendert.") -f $alter.TotalMinutes)
    }

    $geschrieben = New-Object System.Collections.ArrayList
    try {
        foreach ($s in $Stellen) {
            $vorher = Lies $s.Rva $s.Laenge
            Schreib $s.Rva $s.Soll $true
            [void]$geschrieben.Add(@{ Rva = $s.Rva; Alt = $vorher })
            $neu = Lies $s.Rva $s.Laenge
            if ((Hex $neu) -ne (Hex $s.Soll)) { throw "Kontrolle an $($s.Name) fehlgeschlagen ($(Hex $neu))." }
            Write-Host ("  {0}: {1}" -f $s.Name, (Anzeige-Stelle $s $neu))
        }
    }
    catch {
        if (-not (Laeuft)) { return $false }
        Write-Host "Fehler beim Schreiben, baue zurueck ..." -ForegroundColor Red
        for ($i = $geschrieben.Count - 1; $i -ge 0; $i--) {
            try { Schreib $geschrieben[$i].Rva $geschrieben[$i].Alt $true } catch { Write-Host "  Rueckbau bei RVA 0x$('{0:X}' -f $geschrieben[$i].Rva) fehlgeschlagen: $_" -ForegroundColor Red }
        }
        throw
    }

    # --- 5. Warten, bis das Spiel seine Startwerte gesetzt hat, dann die Variablen setzen -----
    while ((Hex (Lies $RvaStartFertig 4)) -eq $null4) {
        if (-not (Laeuft)) { return $false }
        if ((Get-Date) -gt $script:frist) { Write-Host 'Spiel hat seine Startwerte noch nicht gesetzt; setze die Variablen trotzdem.' -ForegroundColor Yellow; break }
        Start-Sleep -Milliseconds 100
    }
    foreach ($v in $Variablen) { Schreib $v.Rva $werte[$v.Wert] $false }
    foreach ($v in $Variablen) {
        $neu = Lies $v.Rva 4
        if ((Hex $neu) -ne (Hex $werte[$v.Wert])) { throw "Kontrolle der Variable $($v.Name.Trim()) fehlgeschlagen ($(Hex $neu))." }
    }
    $b = [BitConverter]::ToInt32((Lies $Variablen[0].Rva 4), 0)
    $hh = [BitConverter]::ToInt32((Lies $Variablen[1].Rva 4), 0)
    Write-Host "Aktuelle Kartengroesse im Spiel: $b x $hh" -ForegroundColor Green
    Write-Host ("Scrollbereich: {0}, Minikarten-Massstab: {1} / {2}" -f (Anzeige 'Bereich' (Lies $Variablen[2].Rva 4)),
        (Anzeige 'KehrBreite' (Lies $Variablen[3].Rva 4)), (Anzeige 'KehrHoehe' (Lies $Variablen[4].Rva 4))) -ForegroundColor Green

    # --- Schiffstempo: warten, bis figuren.cod gelesen ist, dann die Schiffswerte setzen ------
    if ($Schiffstempo -ne 1.0) {
        $tempoOk = $true
        while ($true) {
            $bereit = $true
            foreach ($nr in $SchiffTempoOrig.Keys) {
                $ist = Hex (Lies ($FigurRva + $nr * $FigurGroesse + $TempoOffset) 4)
                if ($ist -eq $null4) { $bereit = $false; break }
                if ($ist -ne $SchiffTempoOrig[$nr] -and $ist -ne (Hex (Tempo-Soll $SchiffTempoOrig[$nr] $Schiffstempo))) {
                    Write-Host "Schiffswert Nr. $nr hat einen unerwarteten Wert ($ist); Schiffstempo NICHT gesetzt (Rest ist aktiv)." -ForegroundColor Yellow
                    $tempoOk = $false; break
                }
            }
            if ($bereit -or -not $tempoOk) { break }
            if (-not (Laeuft)) { return $false }
            if ((Get-Date) -gt $script:frist) { Write-Host 'Schiffswerte noch nicht geladen; Schiffstempo NICHT gesetzt.' -ForegroundColor Yellow; $tempoOk = $false; break }
            Start-Sleep -Milliseconds 100
        }
        if ($tempoOk) {
            foreach ($nr in $SchiffTempoOrig.Keys) { Schreib ($FigurRva + $nr * $FigurGroesse + $TempoOffset) (Tempo-Soll $SchiffTempoOrig[$nr] $Schiffstempo) $false }
            foreach ($nr in $SchiffTempoOrig.Keys) {
                $neu = Lies ($FigurRva + $nr * $FigurGroesse + $TempoOffset) 4
                if ((Hex $neu) -ne (Hex (Tempo-Soll $SchiffTempoOrig[$nr] $Schiffstempo))) { throw "Kontrolle Schiffstempo Nr. $nr fehlgeschlagen ($(Hex $neu))." }
            }
            Write-Host ("Schiffstempo x{0:0.##}: kleines Handelsschiff {1:0.####} statt 0.05 (12 Schiffswerte gesetzt)." -f $Schiffstempo,
                [BitConverter]::ToSingle((Lies ($FigurRva + 21 * $FigurGroesse + $TempoOffset) 4), 0)) -ForegroundColor Green
        }
    }

    # --- Lager: warten, bis haeuser.cod gelesen ist, dann die Lagerwerte setzen ----------------
    if ($Lager -ne 1) {
        $lagerOk = $true
        while ($true) {
            $bereit = $true
            foreach ($nr in $LagerOrig.Keys) {
                $ist = [BitConverter]::ToUInt16((Lies ($GebaeudeRva + $nr * $GebaeudeGroesse + $LagerOffset) 2), 0)
                if ($ist -eq 0) { $bereit = $false; break }
                if ($ist -ne $LagerOrig[$nr] -and $ist -ne $LagerOrig[$nr] * $Lager) {
                    Write-Host "Lagerwert Nr. $nr hat einen unerwarteten Wert ($ist); Lager NICHT gesetzt (Rest ist aktiv)." -ForegroundColor Yellow
                    $lagerOk = $false; break
                }
            }
            if ($bereit -or -not $lagerOk) { break }
            if (-not (Laeuft)) { return $false }
            if ((Get-Date) -gt $script:frist) { Write-Host 'Gebaeudewerte noch nicht geladen; Lager NICHT gesetzt.' -ForegroundColor Yellow; $lagerOk = $false; break }
            Start-Sleep -Milliseconds 100
        }
        if ($lagerOk) {
            foreach ($nr in $LagerOrig.Keys) { Schreib ($GebaeudeRva + $nr * $GebaeudeGroesse + $LagerOffset) ([BitConverter]::GetBytes([uint16]($LagerOrig[$nr] * $Lager))) $false }
            foreach ($nr in $LagerOrig.Keys) {
                $neu = [BitConverter]::ToUInt16((Lies ($GebaeudeRva + $nr * $GebaeudeGroesse + $LagerOffset) 2), 0)
                if ($neu -ne $LagerOrig[$nr] * $Lager) { throw "Kontrolle Lager Nr. $nr fehlgeschlagen ($neu)." }
            }
            Write-Host ("Lager x{0}: Kontor I-IV {1}/{2}/{3}/{4} t, Markt {5} t (7 Werte gesetzt)." -f $Lager, (30 * $Lager), (50 * $Lager), (75 * $Lager), (100 * $Lager), (10 * $Lager)) -ForegroundColor Green
        }
    }

    # --- Einwohner, Laderaum, Produktion: warten, bis die .cod-Werte gelesen sind --------------
    if ($Einwohner -ne 1.0) {
        $e = foreach ($nr in 0..4) { @{ Rva = $WohnRva + $nr * $WohnGroesse; Orig = $WohnOrig[$nr]; Soll = [int][math]::Round($WohnOrig[$nr] * $Einwohner); Bytes = 4 } }
        $r = Setze-Tabelle 'Einwohner' $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ("Einwohner x{0:0.##}: hoechstens {1} je Haus (5 Werte gesetzt)." -f $Einwohner, (($e | ForEach-Object { [math]::Round($_.Soll / 64, 1) }) -join '/')) -ForegroundColor Green }
    }
    if ($Laderaum -ne 1.0) {
        $e = foreach ($nr in ($LadeOrig.Keys | Sort-Object)) { @{ Rva = $FigurRva + $nr * $FigurGroesse + $LadeOffset; Orig = $LadeOrig[$nr]; Soll = [math]::Min(65535, [int][math]::Round($LadeOrig[$nr] * $Laderaum)); Bytes = 2 } }
        $r = Setze-Tabelle 'Laderaum' $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ("Laderaum x{0:0.##}: {1} t je Laderaum (8 Schiffswerte gesetzt)." -f $Laderaum, (($e | Where-Object { $true } | Select-Object -Index 0, 2, 4, 6 | ForEach-Object { [math]::Round($_.Soll / 32) }) -join '/')) -ForegroundColor Green }
    }
    if ($Produktion -ne 1.0) {
        $r = Setze-Produktion $Produktion
        if ($null -eq $r) { return $false }
    }
    $true
}

$null4 = Hex ([byte[]](0, 0, 0, 0))
Write-Host ("Ziel: {0} x {1} Felder (normal 500 x 350), Scrollbereich {2} (normal 425)." -f $Breite, $Hoehe, (Anzeige 'Bereich' $werte.Bereich))
if ($TestProzessId -eq 0) {
    Write-Host "Starte jetzt Anno 1602 History Edition ueber Ubisoft Connect. Ich warte bis zu $WartezeitMinuten Minuten ..." -ForegroundColor Yellow
}
$script:frist = (Get-Date).AddMinutes($WartezeitMinuten)
# Beim ersten Start beendet sich Anno1602.exe oft gleich wieder und wird von Ubisoft Connect
# neu gestartet (beobachtet 2026-11-08). Dann auf den naechsten Prozess warten.
$beendet = @{}
$fertig = $false
while (-not $fertig) {
    if ($TestProzessId -ne 0) {
        $proc = Get-Process -Id $TestProzessId
        $script:basis = [IntPtr]$TestBasis
    }
    else {
        $proc = $null
        while (-not $proc) {
            $proc = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Where-Object { -not $beendet.ContainsKey($_.Id) } | Select-Object -First 1
            if (-not $proc) {
                if ((Get-Date) -gt $script:frist) { throw 'Spiel wurde nicht (neu) gestartet. Abbruch.' }
                Start-Sleep -Milliseconds 50
            }
        }
        # Ladeadresse der exe (ASLR) ermitteln, sobald das Modul sichtbar ist.
        $script:basis = [IntPtr]::Zero
        for ($i = 0; $i -lt 200 -and $script:basis -eq [IntPtr]::Zero; $i++) {
            try { $proc.Refresh(); $script:basis = $proc.MainModule.BaseAddress } catch { Start-Sleep -Milliseconds 25 }
        }
        if ($script:basis -eq [IntPtr]::Zero) {
            if ($proc.HasExited) { $beendet[$proc.Id] = $true; continue }
            throw 'Ladeadresse des Spiels nicht ermittelbar. Abbruch, nichts geaendert.'
        }
    }
    Write-Host ("Spiel gefunden (PID {0}), geladen bei 0x{1:X}." -f $proc.Id, $script:basis.ToInt64())

    # PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION
    $script:h = [AnnoMem]::OpenProcess(0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $proc.Id)
    if ($script:h -eq [IntPtr]::Zero) { throw "Zugriff auf das Spiel verweigert (Fehler $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    try {
        try { $fertig = Patche $proc }
        catch { if (Laeuft) { throw }; $fertig = $false }
    }
    finally {
        [void][AnnoMem]::CloseHandle($script:h)
    }
    if (-not $fertig) {
        if ($TestProzessId -ne 0) { throw 'Testprozess hat sich beendet.' }
        $beendet[$proc.Id] = $true
        Write-Host ("Das Spiel (PID {0}) hat sich beendet, bevor es fertig gestartet war. Ubisoft Connect startet es meist neu; warte auf den naechsten Start ..." -f $proc.Id) -ForegroundColor Yellow
    }
}
Write-Host 'Fertig. Jetzt im Spiel ein NEUES Endlosspiel starten (keinen alten Spielstand laden).' -ForegroundColor Green

# --- 6. Schutz fuer "Spiel fortsetzen" -------------------------------------------------------
if ($TestProzessId -eq 0 -and -not $OhneLastgameSchutz) {
    Write-Host 'Dieses Fenster bleibt offen, bis das Spiel beendet ist (Schutz fuer "Spiel fortsetzen").' -ForegroundColor Yellow
    while (-not $proc.HasExited) { Start-Sleep -Seconds 2; $proc.Refresh() }
    Start-Sleep -Seconds 2
    $lg = Join-Path $saves 'lastgame.gam'
    if ((Test-Path -LiteralPath $lg) -and (Get-Item -LiteralPath $lg).LastWriteTime -gt $werkzeugStart) {
        $name = 'lastgame-{0}x{1}-{2}.gam' -f $Breite, $Hoehe, (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $lg -Destination (Join-Path $saves $name)
        Write-Host "lastgame.gam aus der grossen Welt umbenannt in $name." -ForegroundColor Green
        Write-Host '"Spiel fortsetzen" laedt so ohne Werkzeug keine grosse Welt. Weiterspielen: Werkzeug starten, dann diesen Spielstand laden.'
    }
    else { Write-Host 'Spiel beendet; lastgame.gam wurde in dieser Sitzung nicht geschrieben.' }
}
