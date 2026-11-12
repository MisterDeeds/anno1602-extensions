<#
.SYNOPSIS
  Offline-Test fuer tools\weltgroesse.ps1, ohne das Spiel zu starten.

.DESCRIPTION
  Ein Hilfsprozess laedt die exe-Kopie analysis\bin\Anno1602.exe nur als Abbild
  (LoadLibraryEx mit DONT_RESOLVE_DLL_REFERENCES): Sektionen liegen wie im Spiel an
  Ladeadresse + RVA, mit denselben Speicherrechten, aber es laeuft kein Spielcode und
  keine abhaengige DLL wird geladen. Dann laeuft weltgroesse.ps1 gegen diesen Prozess.

  Geprueft wird:
    A  Spiel startet noch (Variablen 0): Werkzeug patcht den Code, wartet auf den Start,
       der Test spielt den Programmstart nach, danach stimmen alle Variablen.
    B  Zweiter Lauf gegen denselben Prozess: laeuft durch, nichts aendert sich.
    C  Andere Groesse gegen schon gepatchten Prozess: Abbruch, nichts geaendert.
    D  Eine Code-Stelle verfaelscht: Abbruch, keine der anderen Stellen geaendert.
    E  750 x 525 bei schon gestartetem Spiel (Variablen auf Original).
    F  Prozess endet, waehrend das Werkzeug wartet: Ende wird erkannt.
    G  -OhneInselVerteilung: Sprung, Codestueck und Tabelle bleiben unberuehrt.
    H  -NurStrecken: Tabelle ohne Eintraege, Vorlagen werden nur gestreckt.
    I  Funktionstest des Codestuecks an seiner echten Adresse im Abbild: ein Thread im
       Hilfsprozess ruft es mit den echten SZENE-Abschnitten aus Szenes\[[48]]00/01/02.szs auf
       (die Dateien werden nur gelesen). Der Rueckweg in den SZENE-Lader wird dafuer nur im
       Abbild des Hilfsprozesses durch "pop r15; ret" ersetzt. Erwartet: genau die vom
       Werkzeug geplante Inselliste, Originale gestreckt vorne, keine Ueberschneidung, alles
       in der Welt; unbekannte Vorlage nur gestreckt; Inselzahl > 50 keine Aenderung.
    J  -Piraten Aktiv / Aus / Stark: Codestueck, Sprung im TIMERS-Lader und (Stark) Kanonen-
       Stelle gesetzt; ohne -Piraten alles unberuehrt. Funktionstest: das Codestueck laeuft im
       Hilfsprozess (Rueckweg RVA 0xC3239 dort durch "ret" ersetzt) und setzt bzw. loescht
       Bit 0 der Spielvariable 0x1405ec188, die anderen Bits bleiben.
    L  -Startgeld (auch zusammen mit -Piraten Stark): das Codestueck setzt das Geld von Platz 0
       nur bei Spieluhr < 1000 (neues Spiel), bei Spielstaenden bleibt es.
    M  -Lager: die 7 Lagerwerte (Kontor I-IV, Markt) der Gebaeudetabelle werden mit dem Faktor
       multipliziert, Nachbarn bleiben, kein doppeltes Multiplizieren, unerwarteter Wert: nichts.
    K  -Schiffstempo: die 12 Schiffswerte der Figurentabelle (vorher mit den Originalwerten
       belegt, wie nach dem Lesen von figuren.cod) werden mit dem Faktor multipliziert, Nachbarn
       bleiben; zweiter Lauf multipliziert nicht doppelt; unerwarteter Wert: nichts gesetzt.
    N  -Einwohner: die 5 Maxwohn-Werte (x 64) werden multipliziert, Nachbarn bleiben, kein
       doppeltes Multiplizieren, unerwarteter Wert: nichts gesetzt.
    O  -Laderaum: die 8 Laderaum-Werte der baubaren Schiffe werden multipliziert, Haendler bleibt.
    P  -Produktion: Intervalle der Gebaeudetabelle werden geteilt (mindestens 1, 0 bleibt 0),
       Marke gesetzt; zweiter Lauf teilt nicht noch einmal.
    Q  -Turbo: F7-Stelle "mov ecx,8", F6 unberuehrt.
    R  -GegnerGeld: Codestueck setzt bei neuem Spiel das Geld der Plaetze 1-3 (Haendler auf
       Platz 4 bleibt), bei Spielstaenden nichts.
    S  -Inselgroesse Riesig -Rohstoffe Viele: Funktionstest mit den echten Vorlagen.
    T  Gross/Riesig: Geometrie aller Plaene, hoechstens 10 "lar".
    U  -Gegner Schwer: die vier KI-Stellen lesen 3, Naturereignisse und Piratenkanonen nicht.
    V  -Piratenflotte: Codestueck ruft im Abbild das echte FUN_1400185f0 auf (Stufen 0-4 ueber
       die Zivilisationsbits von Platz 0) und liefert Stufe x 2 bzw. x 3; Wartezeit geteilt.
    W  -Haendler: Codestueck liefert Ziel x 2 bzw. x 3, hoechstens 24.
    X  -Ureinwohner: echte Vorlagen, Doerfer 4/4 bzw. 7/7, mit und ohne Rohstoffe.
    Y  50 Inseln bei 1000 x 700; alle Optionen zusammen, Codestuecke ueberlappen nicht.
    Z  Grosse Kampagnenkarten: verlaengerter SZENE-Abschnitt ('GROS' + zweiter Block) im Abbild;
       1000 x 700 und 2000 x 1400 -> grosse Fassung (gestreckt), 750 x 525 und 500 x 350 -> kleine
       Fassung, falsche Kennung / zu kurz -> kleine Fassung. H: ohne Grosskarten-Codestueck.
  Erwartete Bytes und Plaene kommen aus denselben Funktionen in weltgroesse.ps1 (per
  Syntaxbaum geladen).
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = Join-Path $PSScriptRoot 'weltgroesse.ps1'
$exe = Join-Path $root 'analysis\bin\Anno1602.exe'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "weltgroesse-test-$PID"
New-Item -ItemType Directory -Force $tmp | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TestMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtectEx(IntPtr h, IntPtr addr, IntPtr size, uint prot, out uint old);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, IntPtr size, uint type, uint prot);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, IntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr attr, IntPtr stack, IntPtr start, IntPtr param, uint flags, out uint tid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeThread(IntPtr h, out uint code);
}
'@

# Code-Stellen (RVA des Befehls) und Variablen wie im Werkzeug.
$Code = [ordered]@{
    'Breite Start' = 0x0DC7E5; 'Hoehe Start' = 0x0DC7EF; 'Bereich Start' = 0x0DC7F9
    'Breite Neu' = 0x08DC90; 'Hoehe Neu' = 0x08DC9A; 'Bereich Neu' = 0x08DCA4; '1/Breite Neu' = 0x08DCAE; '1/Hoehe Neu' = 0x08DCB8
}
$Var = [ordered]@{ Breite = 0x5EBE40; Hoehe = 0x5EBE98; Bereich = 0x5EB840; KehrBreite = 0x5EBC7C; KehrHoehe = 0x5EBC80 }

function I32([int]$v) { [BitConverter]::GetBytes([int32]$v) }
function F32([double]$v) { [BitConverter]::GetBytes([single]$v) }
function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
function Soll([int]$b, [int]$h) {
    [ordered]@{ Breite = I32 $b; Hoehe = I32 $h; Bereich = I32 ([math]::Floor($b / 2) + [math]::Floor($h / 2)); KehrBreite = F32 (1.0 / $b); KehrHoehe = F32 (1.0 / $h) }
}
$CodeArt = @{ 'Breite Start' = 'Breite'; 'Hoehe Start' = 'Hoehe'; 'Bereich Start' = 'Bereich'; 'Breite Neu' = 'Breite'; 'Hoehe Neu' = 'Hoehe'; 'Bereich Neu' = 'Bereich'; '1/Breite Neu' = 'KehrBreite'; '1/Hoehe Neu' = 'KehrHoehe' }

# Inselverteilung: erwartete Bytes mit denselben Funktionen wie im Werkzeug berechnen
# (aus weltgroesse.ps1 per Syntaxbaum geladen, das Werkzeug selbst laeuft dabei nicht).
$ast = [System.Management.Automation.Language.Parser]::ParseFile($tool, [ref]$null, [ref]$null)
foreach ($stmt in $ast.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function (Bytes|Rel32|Baue-Codestueck|Baue-Rohstoffcode|Lies-Vorlage|Lies-Schiffe|Inselplan|Baue-Tabelle|Baue-Piratencode|Tempo-Soll|Baue-Flottencode|Baue-Haendlercode|Baue-Grosskartencode)\b') -or
        $txt -match '^\$(SpielOrdner|CaveRva|TabelleRva|TabelleMax|HakenRva|HakenWeiter|KlasseB|KlasseH|PiratCaveRva|TimersHakenRva|TimersWeiter|FlagsRva|TimersMovapsZiel|UhrRva|Geld0Rva|SpielerGroesse|KanonenRva|KanonenOrig|KanonenSoll|FigurRva|FigurGroesse|TempoOffset|SchiffTempoOrig|GebaeudeRva|GebaeudeGroesse|LagerOffset|LagerOrig|WohnRva|WohnGroesse|WohnOrig|LadeOffset|LadeOrig|IntervalOffset|GebaeudeAnzahl|ProdMarkeRva|RohCaveRva|RohCaveEnde|RohOffsets|InselMax|InselDichte|GegnerStellen|FlotteCaveRva|FlotteRufRva|StufeRva|FlotteWarte|HaendlerCaveRva|HaendlerRva|HaendlerMax|GrossCaveRva|GrossKennung)\b') { . ([scriptblock]::Create($txt)) }
}
$PiratHakenOrig = '0F 29 05 B7 B3 4F 00'
$PiratHakenSoll = Hex ([byte[]](@(0xE9) + (Rel32 $PiratCaveRva ($TimersHakenRva + 5)) + @(0x66, 0x90)))
function Pruefe-Piraten($a, [string]$art, [string]$wann, [int]$geld = 0) {
    $code = Baue-Piratencode $art $geld
    $c = Hex (Lies $a $PiratCaveRva 41); $k = Hex (Lies $a $TimersHakenRva 7); $kan = Hex (Lies $a $KanonenRva 7)
    if ($art -eq 'Standard' -and $geld -eq 0) {
        Pruefe "$wann TIMERS-Codestueck leer" ($c -eq ((@('00') * 41) -join ' '))
        Pruefe "$wann TIMERS-Sprung original ($k)" ($k -eq $PiratHakenOrig)
    }
    else {
        $soll = Hex ([byte[]]($code + (New-Object byte[] (41 - $code.Length))))
        Pruefe "$wann TIMERS-Codestueck $art/Geld $geld gesetzt ($($code.Length) Bytes)" ($c -eq $soll)
        Pruefe "$wann TIMERS-Sprung gesetzt ($k)" ($k -eq $PiratHakenSoll)
    }
    if ($art -eq 'Stark') { Pruefe "$wann Kanonen-Stelle gesetzt ($kan)" ($kan -eq $KanonenSoll) }
    else { Pruefe "$wann Kanonen-Stelle original ($kan)" ($kan -eq $KanonenOrig) }
}
$InselCodeRva = $CaveRva; $InselHakenRva = $HakenRva; $LaderWeiterRva = $HakenWeiter
$InselHakenOrig = '4C 8D 1D D0 F1 F2 FF'
$InselHakenSoll = 'E9 D2 42 01 00 66 90'
$InselCode = Baue-Codestueck $false $true   # wie das Werkzeug ohne -NurStrecken (mit Grosskarten-Aufruf)
function Erwartung-Tabelle([int]$b, [int]$h, [bool]$nur) { $t = Baue-Tabelle $b $h $nur; @{ Tabelle = $t; Plaene = $script:InselPlaene.Clone() } }
function Pruefe-Insel($a, [bool]$aktiv, [string]$wann, $erw) {
    $c = Hex (Lies $a $InselCodeRva $InselCode.Length); $k = Hex (Lies $a $InselHakenRva 7)
    $tl = if ($erw) { $erw.Tabelle.Length } else { 2452 }
    $t = Hex (Lies $a $TabelleRva $tl)
    if ($aktiv) {
        Pruefe "$wann Inselverteilung Codestueck gesetzt ($($InselCode.Length) Bytes)" ($c -eq (Hex $InselCode))
        Pruefe "$wann Inselverteilung Tabelle gesetzt ($tl Bytes)" ($t -eq (Hex $erw.Tabelle))
        Pruefe "$wann Inselverteilung Sprung gesetzt ($k)" ($k -eq $InselHakenSoll)
    }
    else {
        Pruefe "$wann Inselverteilung Codestueck leer" ($c -eq ((@('00') * $InselCode.Length) -join ' '))
        Pruefe "$wann Inselverteilung Tabelle leer" ($t -eq ((@('00') * $tl) -join ' '))
        Pruefe "$wann Inselverteilung Sprung original ($k)" ($k -eq $InselHakenOrig)
    }
}
# Geometrie eines Inselplans: alles in der Welt, keine Ueberschneidung, Platz = Index.
function Pruefe-Geometrie($plan, [int]$b, [int]$h, [string]$wann) {
    $ok = $true; $grund = ''
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $p = $plan[$i]; $x = [BitConverter]::ToInt32($p, 8); $y = [BitConverter]::ToInt32($p, 12); $w = $KlasseB[$p[1]]; $hh = $KlasseH[$p[1]]
        if ($x -lt 0 -or $y -lt 0 -or $x + $w -gt $b -or $y + $hh -gt $h) { $ok = $false; $grund = "Insel $i ausserhalb" }
        if ($p[3] -ne $i) { $ok = $false; $grund = "Platz $i falsch" }
        for ($j = $i + 1; $j -lt $plan.Count; $j++) {
            $q = $plan[$j]; $qx = [BitConverter]::ToInt32($q, 8); $qy = [BitConverter]::ToInt32($q, 12)
            if ($x -lt $qx + $KlasseB[$q[1]] -and $qx -lt $x + $w -and $y -lt $qy + $KlasseH[$q[1]] -and $qy -lt $y + $hh) { $ok = $false; $grund = "Inseln $i und $j ueberschneiden sich" }
        }
    }
    Pruefe "$wann Geometrie: $($plan.Count) Inseln in der Welt, ohne Ueberschneidung $grund" $ok
}
# SZENE-Abschnitt der Endlos-Vorlage (nur lesen).
function Lies-Szene([string]$name = '[[48]]10.szs') {
    $f = Join-Path 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition\Szenes' $name
    $d = [IO.File]::ReadAllBytes($f); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($name -eq 'SZENE') { return , [byte[]]$d[($o + 20)..($o + 19 + $len)] }
        $o += 20 + $len
    }
    throw 'SZENE-Abschnitt nicht gefunden.'
}
# Erwartetes Ergebnis des Codestuecks.
function Erwarte-Szene([byte[]]$s, [int]$b, [int]$h) {
    $e = [byte[]]$s.Clone(); $n = [BitConverter]::ToInt32($s, 0x64)
    if ($n -gt 50 -or $n -lt 0) { return , $e }
    for ($i = 0; $i -lt $n; $i++) {
        $p = 0x174 + 16 * $i
        $x = [BitConverter]::ToInt32($s, $p + 8); $y = [BitConverter]::ToInt32($s, $p + 12)
        [Array]::Copy((I32 ([int][math]::Truncate($x * $b / 500))), 0, $e, $p + 8, 4)
        [Array]::Copy((I32 ([int][math]::Truncate($y * $h / 350))), 0, $e, $p + 12, 4)
    }
    , $e
}
# Fuehrt das Codestueck im Hilfsprozess mit einem SZENE-Puffer aus und liefert den Puffer zurueck.
# Stub (eigener Speicher): push r15 / mov r15,rcx / mov rax,<Codestueck> / jmp rax.
# Rueckweg: an RVA 0xD0E30 (nur in diesem Abbild) "pop r15; ret".
function Fuehre-Inselcode-aus($a, [byte[]]$szene, [int]$b, [int]$h) {
    Schreib $a $Var.Breite (I32 $b); Schreib $a $Var.Hoehe (I32 $h)
    Schreib $a $LaderWeiterRva ([byte[]](0x41, 0x5F, 0xC3)) $true
    $buf = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]8192, 0x3000, 0x04)
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($buf -eq [IntPtr]::Zero -or $stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx fehlgeschlagen.' }
    $done = [IntPtr]::Zero
    [void][TestMem]::WriteProcessMemory($a.H, $buf, $szene, [IntPtr]$szene.Length, [ref]$done)
    # Abschnittskopf (Name, Laenge) bei Puffer+0x1800; rcx zeigt darauf wie im SZENE-Lader.
    $kopf = New-Object byte[] 20; [Array]::Copy([Text.Encoding]::ASCII.GetBytes('SZENE'), $kopf, 5); [Array]::Copy((I32 $szene.Length), 0, $kopf, 16, 4)
    [void][TestMem]::WriteProcessMemory($a.H, [IntPtr]($buf.ToInt64() + 0x1800), $kopf, [IntPtr]20, [ref]$done)
    $s = [byte[]](@(0x41, 0x57, 0x49, 0x89, 0xCF, 0x48, 0xB9) + [BitConverter]::GetBytes([long]($buf.ToInt64() + 0x1800)) + @(0x48, 0xB8) + [BitConverter]::GetBytes([long]($a.Basis + $InselCodeRva)) + @(0xFF, 0xE0))
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $s, [IntPtr]$s.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, $buf, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread fehlgeschlagen ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $w = [TestMem]::WaitForSingleObject($t, 5000)
    [void][TestMem]::CloseHandle($t)
    if ($w -ne 0) { throw "Thread nicht fertig geworden (Wait $w)." }
    $r = New-Object byte[] $szene.Length
    [void][TestMem]::ReadProcessMemory($a.H, $buf, $r, [IntPtr]$r.Length, [ref]$done)
    [void][TestMem]::VirtualFreeEx($a.H, $buf, [IntPtr]::Zero, 0x8000)
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    , $r
}
# Fuehrt das Piraten-Codestueck im Hilfsprozess aus und liefert die Spielvariable danach.
# Stub (eigener Speicher): mov rax,<Codestueck> / jmp rax. Rueckweg RVA 0xC3239 nur hier: "ret".
function Fuehre-Piratencode-aus($a, [int]$flagsVorher, [int]$uhr = 30000, [int]$geldVorher = 15000) {
    Schreib $a $FlagsRva (I32 $flagsVorher)
    Schreib $a $UhrRva (I32 $uhr)
    Schreib $a $Geld0Rva (I32 $geldVorher)
    Schreib $a $TimersWeiter ([byte[]](0xC3)) $true
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx fehlgeschlagen.' }
    $done = [IntPtr]::Zero
    $s = [byte[]](@(0x48, 0xB8) + [BitConverter]::GetBytes([long]($a.Basis + $PiratCaveRva)) + @(0xFF, 0xE0))
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $s, [IntPtr]$s.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, [IntPtr]::Zero, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread fehlgeschlagen ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $w = [TestMem]::WaitForSingleObject($t, 5000)
    [void][TestMem]::CloseHandle($t)
    if ($w -ne 0) { throw "Thread nicht fertig geworden (Wait $w)." }
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    $script:GeldNachher = [BitConverter]::ToInt32((Lies $a $Geld0Rva 4), 0)
    [BitConverter]::ToInt32((Lies $a $FlagsRva 4), 0)
}

# Ruft eine Funktion im Abbild des Hilfsprozesses auf (Thread) und liefert eax als Ergebnis.
# Stub: [mov edx,<edx>] / sub rsp,0x28 / mov rax,<Adresse> / call rax / add rsp,0x28 / [mov eax,edx] / ret
function Rufe-im-Abbild($a, [long]$rva, [int]$edx = 0, [bool]$edxZurueck = $false) {
    $s = New-Object System.Collections.Generic.List[byte]
    $s.Add(0xBA); $s.AddRange([BitConverter]::GetBytes([int32]$edx))
    $s.AddRange([byte[]](0x48, 0x83, 0xEC, 0x28, 0x48, 0xB8)); $s.AddRange([BitConverter]::GetBytes([long]($a.Basis + $rva)))
    $s.AddRange([byte[]](0xFF, 0xD0, 0x48, 0x83, 0xC4, 0x28))
    if ($edxZurueck) { $s.AddRange([byte[]](0x89, 0xD0)) }
    $s.Add(0xC3)
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx fehlgeschlagen.' }
    $done = [IntPtr]::Zero; $b = $s.ToArray()
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $b, [IntPtr]$b.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, [IntPtr]::Zero, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread fehlgeschlagen ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $w = [TestMem]::WaitForSingleObject($t, 5000)
    $ec = [uint32]0; [void][TestMem]::GetExitCodeThread($t, [ref]$ec)
    [void][TestMem]::CloseHandle($t)
    if ($w -ne 0) { throw "Thread nicht fertig geworden (Wait $w)." }
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    [int]$ec
}

$script:fehler = 0
function Pruefe([string]$was, [bool]$ok) {
    if ($ok) { Write-Host "  OK    $was" -ForegroundColor Green } else { Write-Host "  FEHLER $was" -ForegroundColor Red; $script:fehler++ }
}

function Starte-Abbild {
    $out = Join-Path $tmp "abbild-$([guid]::NewGuid().ToString('N')).txt"
    $cmd = @"
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class L { [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryExW(string p, IntPtr f, uint fl); }'
`$m = [L]::LoadLibraryExW('$exe', [IntPtr]::Zero, 1)
if (`$m -eq [IntPtr]::Zero) { 'FEHLER ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error() | Set-Content '$out'; exit 1 }
`$m.ToInt64().ToString() | Set-Content '$out'
Start-Sleep -Seconds 600
"@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-EncodedCommand', $enc -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 100 -and -not (Test-Path $out); $i++) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 200
    $txt = (Get-Content $out -Raw).Trim()
    if ($txt -like 'FEHLER*') { throw "Abbild konnte nicht geladen werden: $txt" }
    $h = [TestMem]::OpenProcess(0x0002 -bor 0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $p.Id)
    @{ Proc = $p; Basis = [long]$txt; H = $h }
}
function Stoppe-Abbild($a) { [void][TestMem]::CloseHandle($a.H); Stop-Process -Id $a.Proc.Id -Force -ErrorAction SilentlyContinue }
function Lies($a, [long]$rva, [int]$n) {
    $buf = New-Object byte[] $n; $done = [IntPtr]::Zero
    if (-not [TestMem]::ReadProcessMemory($a.H, [IntPtr]($a.Basis + $rva), $buf, [IntPtr]$n, [ref]$done)) { throw ('Lesen 0x{0:X}' -f $rva) }
    , $buf
}
function Schreib($a, [long]$rva, [byte[]]$d, [bool]$code = $false) {
    $alt = [uint32]0; $done = [IntPtr]::Zero
    if ($code) { [void][TestMem]::VirtualProtectEx($a.H, [IntPtr]($a.Basis + $rva), [IntPtr]$d.Length, 0x40, [ref]$alt) }
    if (-not [TestMem]::WriteProcessMemory($a.H, [IntPtr]($a.Basis + $rva), $d, [IntPtr]$d.Length, [ref]$done)) { throw ('Schreiben 0x{0:X}' -f $rva) }
    if ($code) { $x = [uint32]0; [void][TestMem]::VirtualProtectEx($a.H, [IntPtr]($a.Basis + $rva), [IntPtr]$d.Length, $alt, [ref]$x) }
}
function Werkzeug($a, [string[]]$extra) {
    $ErrorActionPreference = 'Continue'   # Fehlertext des Werkzeugs kommt ueber stderr
    $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $tool -TestProzessId $a.Proc.Id -TestBasis $a.Basis -WartezeitMinuten 1 @extra 2>&1 | Out-String
    @{ Code = $LASTEXITCODE; Text = $o }
}
function Code-Werte($a) { $r = [ordered]@{}; foreach ($k in $Code.Keys) { $r[$k] = Hex (Lies $a ($Code[$k] + 6) 4) }; $r }
function Var-Werte($a) { $r = [ordered]@{}; foreach ($k in $Var.Keys) { $r[$k] = Hex (Lies $a $Var[$k] 4) }; $r }
function Pruefe-Code($a, $soll, [string]$wann) {
    $ist = Code-Werte $a
    foreach ($k in $Code.Keys) { Pruefe "$wann Code $k = $($ist[$k])" ($ist[$k] -eq (Hex $soll[$CodeArt[$k]])) }
}
function Pruefe-Var($a, $soll, [string]$wann) {
    $ist = Var-Werte $a
    foreach ($k in $Var.Keys) { Pruefe "$wann Variable $k = $($ist[$k])" ($ist[$k] -eq (Hex $soll[$k])) }
}
# Spielt den Programmstart (FUN_1400dbc60) nach: Breite/Hoehe/Bereich aus den (evtl. gepatchten)
# Sofortwerten, 1/Breite und 1/Hoehe aus den .rdata-Konstanten 0xEB8F4/0xEB8F8.
function Simuliere-Start($a) {
    Schreib $a $Var.KehrBreite (Lies $a 0xEB8F4 4)
    Schreib $a $Var.Breite (Lies $a ($Code['Breite Start'] + 6) 4)
    Schreib $a $Var.Hoehe (Lies $a ($Code['Hoehe Start'] + 6) 4)
    Schreib $a $Var.Bereich (Lies $a ($Code['Bereich Start'] + 6) 4)
    Schreib $a $Var.KehrHoehe (Lies $a 0xEB8F8 4)
}

$orig = Soll 500 350
$gross = Soll 1000 700
$erw1000 = Erwartung-Tabelle 1000 700 $false
$erw750 = Erwartung-Tabelle 750 525 $false
try {
    Write-Host 'Abbild laden ...'
    $a = Starte-Abbild
    Write-Host ('  Hilfsprozess PID {0}, Abbild bei 0x{1:X}' -f $a.Proc.Id, $a.Basis)
    Pruefe-Code $a $orig 'vorher'
    Pruefe 'rdata 0xEB8F4 = 1/500' ((Hex (Lies $a 0xEB8F4 4)) -eq (Hex $orig.KehrBreite))
    Pruefe 'rdata 0xEB8F8 = 1/350' ((Hex (Lies $a 0xEB8F8 4)) -eq (Hex $orig.KehrHoehe))
    Pruefe-Insel $a $false 'vorher'
    Pruefe 'Variablen am Anfang 0' (((Var-Werte $a).Values | Where-Object { $_ -ne '00 00 00 00' }).Count -eq 0)

    Write-Host 'A  Spiel startet noch (Werkzeug wartet, dann Programmstart nachspielen)'
    $log = Join-Path $tmp 'a.txt'
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-TestProzessId', $a.Proc.Id, '-TestBasis', $a.Basis, '-WartezeitMinuten', 1 -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
    [void]$p.Handle   # sonst liefert ExitCode spaeter nichts
    Start-Sleep -Seconds 4
    Pruefe 'Werkzeug wartet noch' (-not $p.HasExited)
    Pruefe-Code $a $gross 'A waehrend'
    Simuliere-Start $a
    $p.WaitForExit(30000) | Out-Null
    Pruefe "A Exit-Code $($p.ExitCode)" ($p.ExitCode -eq 0)
    Write-Host (Get-Content $log -Raw)
    Pruefe-Code $a $gross 'A'
    Pruefe-Var $a $gross 'A'
    Pruefe-Insel $a $true 'A' $erw1000
    Pruefe-Piraten $a 'Standard' 'A'

    Write-Host 'B  Zweiter Lauf, gleiche Groesse'
    $r = Werkzeug $a @()
    Pruefe "B Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Code $a $gross 'B'
    Pruefe-Var $a $gross 'B'
    Pruefe-Insel $a $true 'B' $erw1000

    Write-Host 'C  Andere Groesse gegen schon gepatchten Prozess'
    $r = Werkzeug $a @('-Breite', '750', '-Hoehe', '525')
    Pruefe "C Abbruch (Exit-Code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unerwartete Bytes')
    Pruefe-Code $a $gross 'C'
    Pruefe-Var $a $gross 'C'
    Pruefe-Insel $a $true 'C' $erw1000
    Stoppe-Abbild $a

    Write-Host 'D  Eine Code-Stelle verfaelscht'
    $a = Starte-Abbild
    Schreib $a ($Code['1/Hoehe Neu'] + 6) ([byte[]](1, 2, 3, 4)) $true
    $r = Werkzeug $a @()
    Pruefe "D Abbruch (Exit-Code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unerwartete Bytes')
    $ist = Code-Werte $a
    foreach ($k in @($Code.Keys | Where-Object { $_ -ne '1/Hoehe Neu' })) { Pruefe "D Code $k unveraendert" ($ist[$k] -eq (Hex $orig[$CodeArt[$k]])) }
    Pruefe-Insel $a $false 'D'
    Pruefe 'D Variablen unveraendert 0' (((Var-Werte $a).Values | Where-Object { $_ -ne '00 00 00 00' }).Count -eq 0)
    Stoppe-Abbild $a

    Write-Host 'E  750 x 525, Spiel schon gestartet (Variablen auf Original)'
    $a = Starte-Abbild
    Simuliere-Start $a
    Pruefe-Var $a $orig 'E vorher'
    $r = Werkzeug $a @('-Breite', '750', '-Hoehe', '525')
    Pruefe "E Exit-Code $($r.Code)" ($r.Code -eq 0)
    Write-Host $r.Text
    $mittel = Soll 750 525
    Pruefe-Code $a $mittel 'E'
    Pruefe-Var $a $mittel 'E'
    Pruefe 'E Bereich = 637' ((Hex (Lies $a $Var.Bereich 4)) -eq (Hex (I32 637)))
    Pruefe-Insel $a $true 'E' $erw750

    Stoppe-Abbild $a

    Write-Host 'I  Funktionstest Codestueck mit den echten Endlos-Vorlagen'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @()
    Pruefe "I Werkzeug Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Insel $a $true 'I' $erw1000
    foreach ($lay in 0, 1, 2) {
        $szene = Lies-Szene "[[48]]0$lay.szs"
        $plan = $erw1000.Plaene[$lay]
        $soll = [byte[]]$szene.Clone(); [Array]::Copy((I32 $plan.Count), 0, $soll, 0x64, 4)
        for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $plan.Count) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $soll, 0x174 + 16 * $i, 16) }
        $ist = Fuehre-Inselcode-aus $a $szene 1000 700
        Pruefe ("I Anordnung {0}: {1} -> {2} Inseln, alle 1172 Byte wie geplant" -f $lay, [BitConverter]::ToInt32($szene, 0x64), [BitConverter]::ToInt32($ist, 0x64)) ((Hex $ist) -eq (Hex $soll))
        $ergebnis = @(for ($i = 0; $i -lt [BitConverter]::ToInt32($ist, 0x64); $i++) { , [byte[]]$ist[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
        Pruefe-Geometrie $ergebnis 1000 700 "I Anordnung $lay"
        $vorlage = Erwarte-Szene $szene 1000 700
        $orig = $true
        for ($i = 0; $i -lt [BitConverter]::ToInt32($szene, 0x64); $i++) {
            if ((Hex $ergebnis[$i]) -ne (Hex ([byte[]]$vorlage[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)]))) { $orig = $false }
        }
        Pruefe "I Anordnung ${lay}: die Originalinseln stehen gestreckt vorne" $orig
    }
    $fremd = Lies-Szene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($fremd, 0x17C) + 1)), 0, $fremd, 0x17C, 4)
    $ist = Fuehre-Inselcode-aus $a $fremd 1000 700
    Pruefe 'I unbekannte Vorlage (x der 1. Insel +1): nur gestreckt' ((Hex $ist) -eq (Hex (Erwarte-Szene $fremd 1000 700)))
    $zuviel = Lies-Szene '[[48]]10.szs'; [Array]::Copy((I32 60), 0, $zuviel, 0x64, 4)
    $ist = Fuehre-Inselcode-aus $a $zuviel 1000 700
    Pruefe 'I Inselzahl 60 (> 50): nichts geaendert' ((Hex $ist) -eq (Hex $zuviel))
    Pruefe 'I Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a

    Write-Host 'H  -NurStrecken: Vorlagen werden nur gestreckt'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-NurStrecken')
    Pruefe "H Exit-Code $($r.Code)" ($r.Code -eq 0)
    $erwNur = Erwartung-Tabelle 1000 700 $true
    $script:InselCode = Baue-Codestueck $false $false   # -NurStrecken: ohne Grosskarten-Aufruf
    Pruefe-Insel $a $true 'H' $erwNur
    Pruefe 'H Grosskarten-Codestueck nicht gesetzt' ((Hex (Lies $a $GrossCaveRva 8)) -eq '00 00 00 00 00 00 00 00')
    foreach ($g in @(@(1000, 700), @(750, 525), @(500, 350))) {
        $szene = Lies-Szene '[[48]]10.szs'
        $ist = Fuehre-Inselcode-aus $a $szene $g[0] $g[1]
        Pruefe ('H {0} x {1}: alle 1172 Byte gestreckt (Insel 0: x {2}, y {3})' -f $g[0], $g[1], [BitConverter]::ToInt32($ist, 0x17C), [BitConverter]::ToInt32($ist, 0x180)) ((Hex $ist) -eq (Hex (Erwarte-Szene $szene $g[0] $g[1])))
    }
    $script:InselCode = Baue-Codestueck $false $true
    Stoppe-Abbild $a

    Write-Host 'G  -OhneInselVerteilung'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-OhneInselVerteilung')
    Pruefe "G Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Code $a $gross 'G'
    Pruefe-Var $a $gross 'G'
    Pruefe-Insel $a $false 'G'
    Stoppe-Abbild $a

    Write-Host 'J  -Piraten Aktiv / Aus / Stark'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Piraten', 'Aktiv')
    Pruefe "J Aktiv Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Code $a $gross 'J Aktiv'
    Pruefe-Insel $a $true 'J Aktiv' $erw1000
    Pruefe-Piraten $a 'Aktiv' 'J Aktiv'
    $r = Werkzeug $a @('-Piraten', 'Aus')
    Pruefe "J anderer Piratenmodus im selben Prozess: Abbruch (Exit-Code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unerwartete Bytes')
    Pruefe-Piraten $a 'Aktiv' 'J nach Abbruch'
    foreach ($fall in @(@(0x9, 0x8), @(0x8, 0x8), @(0x2D, 0x2C), @(0x1, 0x0))) {
        $ist = Fuehre-Piratencode-aus $a $fall[0]
        Pruefe ('J Aktiv Funktion: Flags 0x{0:X} -> 0x{1:X} (erwartet 0x{2:X})' -f $fall[0], $ist, $fall[1]) ($ist -eq $fall[1])
    }
    Pruefe 'J Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Piraten', 'Aus')
    Pruefe "J Aus Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Piraten $a 'Aus' 'J Aus'
    foreach ($fall in @(@(0x8, 0x9), @(0x9, 0x9), @(0x2C, 0x2D), @(0x0, 0x1))) {
        $ist = Fuehre-Piratencode-aus $a $fall[0]
        Pruefe ('J Aus Funktion: Flags 0x{0:X} -> 0x{1:X} (erwartet 0x{2:X})' -f $fall[0], $ist, $fall[1]) ($ist -eq $fall[1])
    }
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Piraten', 'Stark', '-OhneInselVerteilung')
    Pruefe "J Stark Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Insel $a $false 'J Stark'
    Pruefe-Piraten $a 'Stark' 'J Stark'
    $ist = Fuehre-Piratencode-aus $a 0x9
    Pruefe ('J Stark Funktion: Flags 0x9 -> 0x{0:X}' -f $ist) ($ist -eq 0x8)
    Stoppe-Abbild $a

    Write-Host 'L  -Startgeld (mit und ohne -Piraten)'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Startgeld', '50000')
    Pruefe "L Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Piraten $a 'Standard' 'L' 50000
    $ist = Fuehre-Piratencode-aus $a 0x9 24 15000
    Pruefe "L neues Spiel (Uhr 24): Geld 15000 -> $($script:GeldNachher), Flags 0x$('{0:X}' -f $ist) unveraendert" ($script:GeldNachher -eq 50000 -and $ist -eq 0x9)
    $ist = Fuehre-Piratencode-aus $a 0x9 999 15000
    Pruefe "L Uhr 999: Geld -> $($script:GeldNachher)" ($script:GeldNachher -eq 50000)
    $ist = Fuehre-Piratencode-aus $a 0x9 1000 12345
    Pruefe "L Spielstand (Uhr 1000): Geld bleibt $($script:GeldNachher)" ($script:GeldNachher -eq 12345)
    $ist = Fuehre-Piratencode-aus $a 0x8 84541 777
    Pruefe "L Spielstand (Uhr 84541): Geld bleibt $($script:GeldNachher), Flags 0x$('{0:X}' -f $ist)" ($script:GeldNachher -eq 777 -and $ist -eq 0x8)
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Startgeld', '1000000', '-Piraten', 'Stark')
    Pruefe "L Stark+Geld Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe-Piraten $a 'Stark' 'L Stark+Geld' 1000000
    $ist = Fuehre-Piratencode-aus $a 0x9 10 15000
    Pruefe "L Stark+Geld neues Spiel: Flags 0x$('{0:X}' -f $ist), Geld $($script:GeldNachher)" ($ist -eq 0x8 -and $script:GeldNachher -eq 1000000)
    Pruefe 'L Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a

    Write-Host 'K  -Schiffstempo'
    function Tempo-Adr([int]$nr) { $FigurRva + $nr * $FigurGroesse + $TempoOffset }
    function Setze-Tempo-Original($a) { foreach ($nr in $SchiffTempoOrig.Keys) { Schreib $a (Tempo-Adr $nr) (Bytes $SchiffTempoOrig[$nr]) } }
    $a = Starte-Abbild
    Simuliere-Start $a
    Setze-Tempo-Original $a
    $r = Werkzeug $a @('-Schiffstempo', '2')
    Pruefe "K Exit-Code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in $SchiffTempoOrig.Keys) {
        $o = [BitConverter]::ToSingle((Bytes $SchiffTempoOrig[$nr]), 0); $n = [BitConverter]::ToSingle((Lies $a (Tempo-Adr $nr) 4), 0)
        Pruefe ('K Schiff Nr. {0}: {1} -> {2}' -f $nr, $o, $n) ([math]::Abs($n - 2 * $o) -lt 1e-6)
    }
    Pruefe 'K Nachbarn Nr. 20 und 33 unberuehrt' (((Hex (Lies $a (Tempo-Adr 20) 4)) -eq '00 00 00 00') -and ((Hex (Lies $a (Tempo-Adr 33) 4)) -eq '00 00 00 00'))
    $r = Werkzeug $a @('-Schiffstempo', '2')
    $n = [BitConverter]::ToSingle((Lies $a (Tempo-Adr 21) 4), 0)
    Pruefe "K zweiter Lauf: Exit-Code $($r.Code), kleines Handelsschiff $n (nicht doppelt)" ($r.Code -eq 0 -and [math]::Abs($n - 0.1) -lt 1e-6)
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    Setze-Tempo-Original $a
    Schreib $a (Tempo-Adr 25) (F32 1.0)
    $r = Werkzeug $a @('-Schiffstempo', '1.5')
    Pruefe "K unerwarteter Wert: Exit-Code $($r.Code), Hinweis im Text" ($r.Code -eq 0 -and $r.Text -match 'NICHT gesetzt')
    Pruefe 'K unerwarteter Wert: nichts gesetzt' ((Hex (Lies $a (Tempo-Adr 21) 4)) -eq $SchiffTempoOrig[21])
    Pruefe-Code $a $gross 'K'
    Stoppe-Abbild $a

    Write-Host 'M  -Lager'
    function Lager-Adr([int]$nr) { $GebaeudeRva + $nr * $GebaeudeGroesse + $LagerOffset }
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($nr in $LagerOrig.Keys) { Schreib $a (Lager-Adr $nr) ([BitConverter]::GetBytes([uint16]$LagerOrig[$nr])) }
    $r = Werkzeug $a @('-Lager', '3', '-Schiffstempo', '1.5')
    Pruefe "M Exit-Code $($r.Code) (Schiffswerte fehlen im Abbild: Hinweis erwartet)" ($r.Code -eq 0 -and $r.Text -match 'Schiffswerte noch nicht geladen')
    foreach ($nr in ($LagerOrig.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Lies $a (Lager-Adr $nr) 2), 0)
        Pruefe ('M Gebaeude Nr. {0}: {1} -> {2} (erwartet {3})' -f $nr, $LagerOrig[$nr], $n, (3 * $LagerOrig[$nr])) ($n -eq 3 * $LagerOrig[$nr])
    }
    Pruefe 'M Nachbarn Nr. 269 und 274 unberuehrt' (((Hex (Lies $a (Lager-Adr 269) 2)) -eq '00 00') -and ((Hex (Lies $a (Lager-Adr 274) 2)) -eq '00 00'))
    $r = Werkzeug $a @('-Lager', '3')
    Pruefe "M zweiter Lauf: Exit-Code $($r.Code), Kontor I $([BitConverter]::ToUInt16((Lies $a (Lager-Adr 270) 2), 0)) (nicht 9-fach)" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Lies $a (Lager-Adr 270) 2), 0) -eq 2880)
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($nr in $LagerOrig.Keys) { Schreib $a (Lager-Adr $nr) ([BitConverter]::GetBytes([uint16]$LagerOrig[$nr])) }
    Schreib $a (Lager-Adr 272) ([BitConverter]::GetBytes([uint16]1234))
    $r = Werkzeug $a @('-Lager', '2')
    Pruefe "M unerwarteter Wert: Exit-Code $($r.Code), Hinweis im Text" ($r.Code -eq 0 -and $r.Text -match 'Lager NICHT gesetzt')
    Pruefe 'M unerwarteter Wert: nichts gesetzt' ([BitConverter]::ToUInt16((Lies $a (Lager-Adr 270) 2), 0) -eq 960)
    Stoppe-Abbild $a

    Write-Host 'N  -Einwohner'
    function Wohn-Adr([int]$nr) { $WohnRva + $nr * $WohnGroesse }
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($nr in 0..4) { Schreib $a (Wohn-Adr $nr) (I32 $WohnOrig[$nr]) }
    $r = Werkzeug $a @('-Einwohner', '2')
    Pruefe "N Exit-Code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in 0..4) {
        $n = [BitConverter]::ToInt32((Lies $a (Wohn-Adr $nr) 4), 0)
        Pruefe ('N Gruppe {0}: {1} -> {2} (erwartet {3})' -f $nr, $WohnOrig[$nr], $n, (2 * $WohnOrig[$nr])) ($n -eq 2 * $WohnOrig[$nr])
    }
    Pruefe 'N Nachbar (Steuer der Gruppe 0, +4) unberuehrt' ((Hex (Lies $a ((Wohn-Adr 0) + 4) 4)) -eq '00 00 00 00')
    $r = Werkzeug $a @('-Einwohner', '2')
    Pruefe "N zweiter Lauf: Exit-Code $($r.Code), Gruppe 4 = $([BitConverter]::ToInt32((Lies $a (Wohn-Adr 4) 4), 0)) (nicht 4-fach)" ($r.Code -eq 0 -and [BitConverter]::ToInt32((Lies $a (Wohn-Adr 4) 4), 0) -eq 5120)
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($nr in 0..4) { Schreib $a (Wohn-Adr $nr) (I32 $WohnOrig[$nr]) }
    Schreib $a (Wohn-Adr 2) (I32 999)
    $r = Werkzeug $a @('-Einwohner', '1.5')
    Pruefe "N unerwarteter Wert: Exit-Code $($r.Code), Hinweis im Text" ($r.Code -eq 0 -and $r.Text -match 'Einwohner: unerwarteter Wert')
    Pruefe 'N unerwarteter Wert: nichts gesetzt' ([BitConverter]::ToInt32((Lies $a (Wohn-Adr 0) 4), 0) -eq 128)
    Stoppe-Abbild $a

    Write-Host 'O  -Laderaum'
    function Lade-Adr([int]$nr) { $FigurRva + $nr * $FigurGroesse + $LadeOffset }
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($nr in $LadeOrig.Keys) { Schreib $a (Lade-Adr $nr) ([BitConverter]::GetBytes([uint16]$LadeOrig[$nr])) }
    $r = Werkzeug $a @('-Laderaum', '1.5')
    Pruefe "O Exit-Code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in ($LadeOrig.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Lies $a (Lade-Adr $nr) 2), 0)
        $soll = [int][math]::Round($LadeOrig[$nr] * 1.5)
        Pruefe ('O Schiff Nr. {0}: {1} -> {2} (erwartet {3})' -f $nr, $LadeOrig[$nr], $n, $soll) ($n -eq $soll)
    }
    Pruefe 'O Haendler (Nr. 29) unberuehrt' ((Hex (Lies $a (Lade-Adr 29) 2)) -eq '00 00')
    $r = Werkzeug $a @('-Laderaum', '1.5')
    Pruefe "O zweiter Lauf: Exit-Code $($r.Code), Nr. 21 = $([BitConverter]::ToUInt16((Lies $a (Lade-Adr 21) 2), 0))" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Lies $a (Lade-Adr 21) 2), 0) -eq 2400)
    Stoppe-Abbild $a

    Write-Host 'P  -Produktion'
    function Intervall-Adr([int]$nr) { $GebaeudeRva + $nr * $GebaeudeGroesse + $IntervalOffset }
    # Normale Hashtable: bei [ordered] waere $probe[10] die 11. Position statt der Schluessel 10.
    $probe = @{ 10 = 15; 11 = 10; 12 = 330; 13 = 1; 14 = 0; 499 = 900 }
    $a = Starte-Abbild
    Simuliere-Start $a
    Schreib $a ($GebaeudeRva + 270 * $GebaeudeGroesse + $LagerOffset) ([BitConverter]::GetBytes([uint16]960))   # haeuser.cod gelesen
    foreach ($nr in $probe.Keys) { Schreib $a (Intervall-Adr $nr) ([BitConverter]::GetBytes([uint16]$probe[$nr])) }
    $r = Werkzeug $a @('-Produktion', '2')
    Pruefe "P Exit-Code $($r.Code), Meldung" ($r.Code -eq 0 -and $r.Text -match 'Produktion x2: 4 Arbeitsintervalle verkuerzt')
    foreach ($nr in ($probe.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Lies $a (Intervall-Adr $nr) 2), 0)
        $soll = if ($probe[$nr] -eq 0) { 0 } else { [math]::Max(1, [int][math]::Round($probe[$nr] / 2)) }
        Pruefe ('P Gebaeude Nr. {0}: Intervall {1} -> {2} (erwartet {3})' -f $nr, $probe[$nr], $n, $soll) ($n -eq $soll)
    }
    Pruefe 'P Lagerwert (Nachbarfeld) unberuehrt' ([BitConverter]::ToUInt16((Lies $a ($GebaeudeRva + 270 * $GebaeudeGroesse + $LagerOffset) 2), 0) -eq 960)
    Pruefe "P Marke gesetzt ($(Hex (Lies $a $ProdMarkeRva 8)))" ((Hex (Lies $a $ProdMarkeRva 8)) -eq '4E 55 46 52 C8 00 00 00')
    $r = Werkzeug $a @('-Produktion', '2')
    Pruefe "P zweiter Lauf: Exit-Code $($r.Code), Nr. 12 = $([BitConverter]::ToUInt16((Lies $a (Intervall-Adr 12) 2), 0)) (nicht geviertelt)" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Lies $a (Intervall-Adr 12) 2), 0) -eq 165 -and $r.Text -match 'schon gesetzt')
    Stoppe-Abbild $a

    Write-Host 'Q  -Turbo'
    $a = Starte-Abbild
    Simuliere-Start $a
    Pruefe "Q vorher F7 = $(Hex (Lies $a 0xE3376 5))" ((Hex (Lies $a 0xE3376 5)) -eq 'B9 04 00 00 00')
    $r = Werkzeug $a @('-Turbo')
    Pruefe "Q Exit-Code $($r.Code)" ($r.Code -eq 0)
    Pruefe "Q F7 = $(Hex (Lies $a 0xE3376 5))" ((Hex (Lies $a 0xE3376 5)) -eq 'B9 08 00 00 00')
    Pruefe "Q F6 unberuehrt ($(Hex (Lies $a 0xE335F 5)))" ((Hex (Lies $a 0xE335F 5)) -eq 'B9 02 00 00 00')
    $r = Werkzeug $a @('-Turbo', '-TurboStufe', '16')
    Pruefe "Q andere Stufe im schon gepatchten Prozess: Abbruch (Exit-Code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unerwartete Bytes')
    Stoppe-Abbild $a
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Turbo', '-TurboStufe', '16')
    Pruefe "Q 16-fach: Exit-Code $($r.Code), F7 = $(Hex (Lies $a 0xE3376 5))" ($r.Code -eq 0 -and (Hex (Lies $a 0xE3376 5)) -eq 'B9 10 00 00 00')
    Stoppe-Abbild $a

    Write-Host 'R  -GegnerGeld'
    function Geld-Adr([int]$platz) { $Geld0Rva + $platz * $SpielerGroesse }
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-GegnerGeld', '30000', '-Startgeld', '50000')
    Pruefe "R Exit-Code $($r.Code)" ($r.Code -eq 0)
    # Nicht $code nennen: PowerShell unterscheidet keine Gross-/Kleinschreibung, $Code ist die Tabelle der Code-Stellen.
    $piratCode = Baue-Piratencode 'Standard' 50000 30000
    Pruefe "R Codestueck gesetzt ($($piratCode.Length) Bytes)" ((Hex (Lies $a $PiratCaveRva $piratCode.Length)) -eq (Hex $piratCode))
    foreach ($p in 1..4) { Schreib $a (Geld-Adr $p) (I32 15000) }
    [void](Fuehre-Piratencode-aus $a 0x9 24 15000)
    $g = foreach ($p in 1..4) { [BitConverter]::ToInt32((Lies $a (Geld-Adr $p) 4), 0) }
    Pruefe "R neues Spiel: Spieler $($script:GeldNachher), Gegner $($g[0..2] -join '/'), Haendler $($g[3])" ($script:GeldNachher -eq 50000 -and $g[0] -eq 30000 -and $g[1] -eq 30000 -and $g[2] -eq 30000 -and $g[3] -eq 15000)
    foreach ($p in 1..3) { Schreib $a (Geld-Adr $p) (I32 4321) }
    [void](Fuehre-Piratencode-aus $a 0x9 30000 777)
    $g = foreach ($p in 1..3) { [BitConverter]::ToInt32((Lies $a (Geld-Adr $p) 4), 0) }
    Pruefe "R Spielstand: Spieler $($script:GeldNachher), Gegner $($g -join '/') unveraendert" ($script:GeldNachher -eq 777 -and ($g | Where-Object { $_ -ne 4321 }).Count -eq 0)
    Stoppe-Abbild $a

    Write-Host 'S  -Inselgroesse Riesig -Rohstoffe Viele (Funktionstest mit den echten Vorlagen)'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @('-Inselgroesse', 'Riesig', '-Rohstoffe', 'Viele')
    Pruefe "S Exit-Code $($r.Code)" ($r.Code -eq 0)
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $tabS = Baue-Tabelle 1000 700 $false 'Riesig'; $planeS = $script:InselPlaene.Clone()
    $codeS = Baue-Codestueck $true $true; $rohS = Baue-Rohstoffcode 200
    Pruefe "S Inselcode mit Aufruf gesetzt ($($codeS.Length) Bytes)" ((Hex (Lies $a $InselCodeRva $codeS.Length)) -eq (Hex $codeS))
    Pruefe "S Rohstoffcode gesetzt ($($rohS.Length) Bytes)" ((Hex (Lies $a $RohCaveRva $rohS.Length)) -eq (Hex $rohS))
    Pruefe "S Tabelle (Riesig) gesetzt ($($tabS.Length) Bytes)" ((Hex (Lies $a $TabelleRva $tabS.Length)) -eq (Hex $tabS))
    foreach ($datei in '[[48]]00.szs', '[[48]]11.szs', '[[48]]32.szs') {
        $lay = [int][string]$datei[7]
        $szene = Lies-Szene $datei
        $plan = $planeS[$lay]
        $alt = [BitConverter]::ToInt32($szene, 0x64); $neu = $plan.Count
        $soll = [byte[]]$szene.Clone(); [Array]::Copy((I32 $neu), 0, $soll, 0x64, 4)
        for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $neu) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $soll, 0x174 + 16 * $i, 16) }
        $mengen = @()
        foreach ($o in $RohOffsets) {
            $m = [int][BitConverter]::ToUInt16($szene, $o)
            $v = [math]::Min($neu, [int][math]::Truncate($m * $neu * 200 / ($alt * 100)))
            [Array]::Copy([BitConverter]::GetBytes([uint16]$v), 0, $soll, $o, 2)
            if ($m -gt 0) { $mengen += "$m->$v" }
        }
        $ist = Fuehre-Inselcode-aus $a $szene 1000 700
        Pruefe ("S {0}: {1} -> {2} Inseln, Mengen {3}, alle 1172 Byte wie erwartet" -f $datei, $alt, $neu, ($mengen -join ' ')) ((Hex $ist) -eq (Hex $soll))
        $ergebnis = @(for ($i = 0; $i -lt $neu; $i++) { , [byte[]]$ist[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
        Pruefe-Geometrie $ergebnis 1000 700 "S $datei"
    }
    $fremd = Lies-Szene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($fremd, 0x17C) + 1)), 0, $fremd, 0x17C, 4)
    $ist = Fuehre-Inselcode-aus $a $fremd 1000 700
    Pruefe 'S unbekannte Vorlage: nur gestreckt, Rohstoffe unveraendert' ((Hex $ist) -eq (Hex (Erwarte-Szene $fremd 1000 700)))
    Pruefe 'S Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a

    Write-Host 'T  Inselgroesse Gross/Riesig: Geometrie aller Plaene, Startschiffe im Wasser'
    foreach ($g in @(@(1000, 700), @(2000, 1400), @(750, 525))) {
        foreach ($groesse in 'Normal', 'Gross', 'Riesig') {
            [void](Baue-Tabelle $g[0] $g[1] $false $groesse)
            foreach ($lay in 0, 1, 2) {
                $schiffe = Lies-Schiffe (Join-Path $SpielOrdner "Szenes\[[48]]1$lay.szs"); $treffer = @()
                foreach ($e in $script:InselPlaene[$lay]) {
                    $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12); $c = $e[1]
                    foreach ($sp in $schiffe) { if ($sp[0] -ge $x - 2 -and $sp[0] -lt $x + $KlasseB[$c] + 2 -and $sp[1] -ge $y - 2 -and $sp[1] -lt $y + $KlasseH[$c] + 2) { $treffer += "$($sp[0]),$($sp[1])" } }
                }
                Pruefe ("T {0} {1}x{2} Anordnung {3}: {4} Startschiffe frei {5}" -f $groesse, $g[0], $g[1], $lay, $schiffe.Count, ($treffer -join ' ')) ($schiffe.Count -eq 4 -and $treffer.Count -eq 0)
            }
        }
        foreach ($groesse in 'Gross', 'Riesig') {
            [void](Baue-Tabelle $g[0] $g[1] $false $groesse)
            foreach ($lay in 0, 1, 2) {
                $p = $script:InselPlaene[$lay]
                $gross = @($p | Where-Object { $_[1] -ge 3 }).Count; $lar = @($p | Where-Object { $_[1] -eq 4 }).Count
                Pruefe-Geometrie $p $g[0] $g[1] ("T {0} {1}x{2} Anordnung {3} ({4} davon big/lar)" -f $groesse, $g[0], $g[1], $lay, $gross)
                Pruefe ("T {0} {1}x{2} Anordnung {3}: hoechstens 10 lar ({4})" -f $groesse, $g[0], $g[1], $lay, $lar) ($lar -le 10)
            }
        }
    }

    Write-Host 'U  -Gegner Schwer'
    $a = Starte-Abbild
    Simuliere-Start $a
    foreach ($g in $GegnerStellen) { Pruefe ("U vorher {0} = {1}" -f $g.Name, (Hex (Lies $a $g.Rva 6))) ((Hex (Lies $a $g.Rva 6)) -eq $g.Original) }
    $r = Werkzeug $a @('-Gegner', 'Schwer')
    Pruefe "U Exit-Code $($r.Code)" ($r.Code -eq 0 -and $r.Text -match 'immer wie Schwer')
    foreach ($g in $GegnerStellen) { Pruefe ("U {0} = {1}" -f $g.Name, (Hex (Lies $a $g.Rva 6))) ((Hex (Lies $a $g.Rva 6)) -eq 'B8 03 00 00 00 90') }
    Pruefe "U Naturereignisse (RVA 0x9E781) unberuehrt" ((Hex (Lies $a 0x9E781 6)) -eq '8B 05 39 DA 54 00')
    Pruefe "U Piratenkanonen (RVA 0x3B94B) unberuehrt" ((Hex (Lies $a 0x3B94B 6)) -eq '8B 05 6F 08 5B 00')
    $r = Werkzeug $a @('-Gegner', 'Schwer')
    Pruefe "U zweiter Lauf: Exit-Code $($r.Code)" ($r.Code -eq 0)
    Stoppe-Abbild $a

    Write-Host 'V  -Piratenflotte Gross/Riesig (Funktionstest mit FUN_1400185f0 im Abbild)'
    $FlagsPlatz0 = 0x5F09CC   # Spielertabelle Platz 0 +0x6C: Zivilisationsbits 18/24/29/30
    foreach ($art in 'Gross', 'Riesig') {
        $f = @{ Gross = 2; Riesig = 3 }[$art]
        $a = Starte-Abbild
        Simuliere-Start $a
        Pruefe "V $art vorher Aufruf = $(Hex (Lies $a $FlotteRufRva 5))" ((Hex (Lies $a $FlotteRufRva 5)) -eq 'E8 FA CD FD FF')
        $r = Werkzeug $a @('-Piratenflotte', $art)
        Pruefe "V $art Exit-Code $($r.Code)" ($r.Code -eq 0)
        $fc = Baue-Flottencode $f
        Pruefe "V $art Codestueck gesetzt ($(Hex $fc))" ((Hex (Lies $a $FlotteCaveRva $fc.Length)) -eq (Hex $fc))
        $ruf = Hex ([byte[]](@(0xE8) + (Rel32 $FlotteCaveRva ($FlotteRufRva + 5))))
        Pruefe "V $art Aufruf umgeleitet ($(Hex (Lies $a $FlotteRufRva 5)))" ((Hex (Lies $a $FlotteRufRva 5)) -eq $ruf)
        foreach ($w in $FlotteWarte) {
            $ist = [BitConverter]::ToInt32((Lies $a ($w.Rva + 6) 4), 0); $soll = [int][math]::Floor(1000 / $f)
            Pruefe ("V {0} Wartezeit RVA 0x{1:X}: x{2} (erwartet {3}), Befehl sonst gleich" -f $art, $w.Rva, $ist, $soll) ($ist -eq $soll -and (Hex (Lies $a $w.Rva 6)) -eq (Hex (Bytes $w.Original)[0..5]))
        }
        foreach ($stufe in @(@(0, 0), @(0x00040000, 1), @(0x01000000, 2), @(0x20000000, 3), @(0x40000000, 4))) {
            Schreib $a $FlagsPlatz0 (I32 $stufe[0])
            $o = Rufe-im-Abbild $a $StufeRva; $n = Rufe-im-Abbild $a $FlotteCaveRva
            Pruefe ("V {0} Stufe {1}: FUN_1400185f0 = {2}, Codestueck = {3} (erwartet {4})" -f $art, $stufe[1], $o, $n, ($stufe[1] * $f)) ($o -eq $stufe[1] -and $n -eq $stufe[1] * $f)
        }
        Pruefe "V $art Hilfsprozess lebt noch" (-not $a.Proc.HasExited)
        Stoppe-Abbild $a
    }

    Write-Host 'W  -Haendler Mehr/Viele (Funktionstest)'
    foreach ($art in 'Mehr', 'Viele') {
        $f = @{ Mehr = 2; Viele = 3 }[$art]
        $a = Starte-Abbild
        Simuliere-Start $a
        Pruefe "W $art vorher = $(Hex (Lies $a $HaendlerRva 5))" ((Hex (Lies $a $HaendlerRva 5)) -eq 'C1 E8 1F 03 D0')
        $r = Werkzeug $a @('-Haendler', $art)
        Pruefe "W $art Exit-Code $($r.Code)" ($r.Code -eq 0)
        $hc = Baue-Haendlercode $f
        Pruefe "W $art Codestueck gesetzt ($(Hex $hc))" ((Hex (Lies $a $HaendlerCaveRva $hc.Length)) -eq (Hex $hc))
        $ruf = Hex ([byte[]](@(0xE8) + (Rel32 $HaendlerCaveRva ($HaendlerRva + 5))))
        Pruefe "W $art Aufruf gesetzt ($(Hex (Lies $a $HaendlerRva 5)))" ((Hex (Lies $a $HaendlerRva 5)) -eq $ruf)
        Pruefe "W $art Befehle davor/danach unberuehrt" ((Hex (Lies $a 0xBC13E 2)) -eq '8B C2' -and (Hex (Lies $a 0xBC145 2)) -eq '39 15')
        foreach ($n in 0, 1, 4, 5, 8, 12, 13, 30) {
            $ist = Rufe-im-Abbild $a $HaendlerCaveRva $n $true; $soll = [math]::Min($n * $f, 24)
            Pruefe ("W {0}: Ziel {1} -> {2} (erwartet {3})" -f $art, $n, $ist, $soll) ($ist -eq $soll)
        }
        Stoppe-Abbild $a
    }

    Write-Host 'X  -Ureinwohner (Funktionstest mit den echten Vorlagen, mit und ohne Rohstoffe)'
    foreach ($fall in @(@('Mehr', 'Normal', 4, 0), @('Viele', 'Viele', 7, 200))) {
        $a = Starte-Abbild
        Simuliere-Start $a
        $r = Werkzeug $a @('-Ureinwohner', $fall[0], '-Rohstoffe', $fall[1])
        Pruefe "X $($fall[0])/$($fall[1]) Exit-Code $($r.Code)" ($r.Code -eq 0 -and $r.Text -match ("{0} Doerfer je Klimazone" -f $fall[2]))
        [void](Baue-Tabelle 1000 700 $false 'Normal'); $planeX = $script:InselPlaene.Clone()
        $rohX = Baue-Rohstoffcode $fall[3] $fall[2]
        Pruefe "X $($fall[0]) Szene-Codestueck gesetzt ($($rohX.Length) Bytes, endet vor 0x$('{0:X}' -f $RohCaveEnde))" ((Hex (Lies $a $RohCaveRva $rohX.Length)) -eq (Hex $rohX) -and $RohCaveRva + $rohX.Length -le $RohCaveEnde)
        foreach ($datei in '[[48]]00.szs', '[[48]]21.szs') {
            $lay = [int][string]$datei[7]
            $szene = Lies-Szene $datei
            $plan = $planeX[$lay]
            $alt = [BitConverter]::ToInt32($szene, 0x64); $neu = $plan.Count
            $soll = [byte[]]$szene.Clone(); [Array]::Copy((I32 $neu), 0, $soll, 0x64, 4)
            for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $neu) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $soll, 0x174 + 16 * $i, 16) }
            if ($fall[3] -gt 0) {
                foreach ($o in $RohOffsets) {
                    $m = [int][BitConverter]::ToUInt16($szene, $o)
                    [Array]::Copy([BitConverter]::GetBytes([uint16][math]::Min($neu, [int][math]::Truncate($m * $neu * $fall[3] / ($alt * 100)))), 0, $soll, $o, 2)
                }
            }
            [Array]::Copy((I32 $fall[2]), 0, $soll, 0x40, 4); [Array]::Copy((I32 $fall[2]), 0, $soll, 0x44, 4)
            $ist = Fuehre-Inselcode-aus $a $szene 1000 700
            Pruefe ("X {0} {1}: {2} -> {3} Inseln, Doerfer {4}/{5} -> {6}/{7}, alle 1172 Byte wie erwartet" -f $fall[0], $datei, $alt, $neu, [BitConverter]::ToInt32($szene, 0x40), [BitConverter]::ToInt32($szene, 0x44), [BitConverter]::ToInt32($ist, 0x40), [BitConverter]::ToInt32($ist, 0x44)) ((Hex $ist) -eq (Hex $soll))
        }
        Stoppe-Abbild $a
    }

    Write-Host 'Z  Grosse Kampagnenkarten (verlaengerter SZENE-Abschnitt, Funktionstest)'
    $a = Starte-Abbild
    Simuliere-Start $a
    $r = Werkzeug $a @()
    Pruefe "Z Exit-Code $($r.Code)" ($r.Code -eq 0)
    $gk = Baue-Grosskartencode
    Pruefe "Z Grosskarten-Codestueck gesetzt ($($gk.Length) Bytes)" ((Hex (Lies $a $GrossCaveRva $gk.Length)) -eq (Hex $gk))
    # Kleine Fassung: Endlos-Vorlage mit verschobener erster Insel (unbekannt -> nur strecken).
    $klein = Lies-Szene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($klein, 0x17C) + 1)), 0, $klein, 0x17C, 4)
    # Grosse Fassung: Plan des Werkzeugs fuer 1000 x 700, dazu andere Doerfer- und Goldmengen.
    $plan = Inselplan (Lies-Vorlage (Join-Path $SpielOrdner 'Szenes\[[48]]10.szs')) 1000 700 $false 'Normal'
    $grossB = [byte[]]$klein.Clone(); [Array]::Copy((I32 $plan.Count), 0, $grossB, 0x64, 4)
    for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $plan.Count) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $grossB, 0x174 + 16 * $i, 16) }
    [Array]::Copy((I32 5), 0, $grossB, 0x40, 4); [Array]::Copy([BitConverter]::GetBytes([uint16]7), 0, $grossB, 0xA6, 2)
    function Lang([byte[]]$k, [byte[]]$g, [string]$kenn = 'GROS', [int]$kuerzer = 0) {
        $x = New-Object byte[] 16; [Array]::Copy([Text.Encoding]::ASCII.GetBytes($kenn), $x, 4); [Array]::Copy((I32 1000), 0, $x, 4, 4); [Array]::Copy((I32 700), 0, $x, 8, 4); [Array]::Copy((I32 1), 0, $x, 12, 4)
        $l = [byte[]]($k + $x + $g); , [byte[]]$l[0..($l.Length - 1 - $kuerzer)]
    }
    function Gestreckt([byte[]]$g, [int]$b, [int]$h) {
        $e = [byte[]]$g.Clone(); $n = [BitConverter]::ToInt32($g, 0x64)
        for ($i = 0; $i -lt $n; $i++) { $p = 0x174 + 16 * $i
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 8) * $b / 1000))), 0, $e, $p + 8, 4)
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 12) * $h / 700))), 0, $e, $p + 12, 4) }
        , $e
    }
    $lang = Lang $klein $grossB
    Pruefe "Z verlaengerter Abschnitt: $($lang.Length) Byte" ($lang.Length -eq 2360)
    foreach ($fall in @(@(1000, 700, 'gross'), @(2000, 1400, 'gross'), @(750, 525, 'klein'), @(500, 350, 'klein'))) {
        $ist = Fuehre-Inselcode-aus $a $lang $fall[0] $fall[1]
        $vorne = if ($fall[2] -eq 'gross') { Gestreckt $grossB $fall[0] $fall[1] } else { Erwarte-Szene $klein $fall[0] $fall[1] }
        $ok = ((Hex ([byte[]]$ist[0..1171])) -eq (Hex $vorne)) -and ((Hex ([byte[]]$ist[1172..2359])) -eq (Hex ([byte[]]$lang[1172..2359])))
        Pruefe ('Z {0} x {1}: {2}e Fassung ({3} Inseln, Insel 0 bei {4}/{5}, Doerfer {6}), Rest unveraendert' -f $fall[0], $fall[1], $fall[2], [BitConverter]::ToInt32($ist, 0x64), [BitConverter]::ToInt32($ist, 0x17C), [BitConverter]::ToInt32($ist, 0x180), [BitConverter]::ToInt32($ist, 0x40)) $ok
        if ($fall[2] -eq 'gross') { $e = @(for ($i = 0; $i -lt [BitConverter]::ToInt32($ist, 0x64); $i++) { , [byte[]]$ist[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] }); Pruefe-Geometrie $e $fall[0] $fall[1] "Z $($fall[0]) x $($fall[1])" }
    }
    foreach ($fall in @(@('falsche Kennung', (Lang $klein $grossB 'GROX')), @('zu kurz', (Lang $klein $grossB 'GROS' 10)))) {
        $ist = Fuehre-Inselcode-aus $a $fall[1] 1000 700
        Pruefe "Z $($fall[0]): nur die kleine Fassung gestreckt" ((Hex ([byte[]]$ist[0..1171])) -eq (Hex (Erwarte-Szene $klein 1000 700)))
    }
    Pruefe 'Z Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a

    Write-Host 'Y  50 Inseln und alles zusammen'
    [void](Baue-Tabelle 1000 700 $false 'Normal')
    $zahlen = foreach ($lay in 0, 1, 2) { $script:InselPlaene[$lay].Count }
    Pruefe "Y 1000x700 Normal: $($zahlen -join '/') Inseln (hoechstens $InselMax, mindestens eine Anordnung mit 50)" (($zahlen | Measure-Object -Maximum).Maximum -eq 50 -and ($zahlen | Where-Object { $_ -gt 50 }).Count -eq 0)
    foreach ($lay in 0, 1, 2) { Pruefe-Geometrie $script:InselPlaene[$lay] 1000 700 "Y Anordnung $lay" }
    $a = Starte-Abbild
    Simuliere-Start $a
    $alle = @('-Inselgroesse', 'Riesig', '-Rohstoffe', 'Viele', '-Ureinwohner', 'Viele', '-Gegner', 'Schwer', '-Piratenflotte', 'Riesig', '-Haendler', 'Viele',
        '-Piraten', 'Stark', '-Startgeld', '50000', '-GegnerGeld', '60000', '-Einwohner', '5', '-Turbo', '-TurboStufe', '16', '-Produktion', '2', '-Lager', '5', '-Schiffstempo', '2', '-Laderaum', '3')
    $r = Werkzeug $a $alle
    Pruefe "Y alle Optionen: Exit-Code $($r.Code)" ($r.Code -eq 0)
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $roh = Baue-Rohstoffcode 200 7; $fc = Baue-Flottencode 3; $hc = Baue-Haendlercode 3; $pc = Baue-Piratencode 'Stark' 50000 60000; $gk = Baue-Grosskartencode
    $bereiche = @(@('Rohstoffe', $RohCaveRva, $roh), @('Piratenflotte', $FlotteCaveRva, $fc), @('Haendler', $HaendlerCaveRva, $hc), @('Grosskarte', $GrossCaveRva, $gk), @('Marke', $ProdMarkeRva, (New-Object byte[] 8)), @('TIMERS', $PiratCaveRva, $pc))
    $ok = $true
    for ($i = 0; $i -lt $bereiche.Count - 1; $i++) { if ($bereiche[$i][1] + $bereiche[$i][2].Length -gt $bereiche[$i + 1][1]) { $ok = $false } }
    Pruefe ("Y Codestuecke ueberlappen nicht ({0})" -f (($bereiche | ForEach-Object { '{0} 0x{1:X}+{2}' -f $_[0], $_[1], $_[2].Length }) -join ', ')) ($ok -and $PiratCaveRva + $pc.Length -le 0xE6000)
    foreach ($b in $bereiche) { if ($b[0] -ne 'Marke') { Pruefe "Y $($b[0]) im Speicher wie gebaut" ((Hex (Lies $a $b[1] $b[2].Length)) -eq (Hex $b[2])) } }
    Pruefe 'Y Hilfsprozess lebt noch' (-not $a.Proc.HasExited)
    Stoppe-Abbild $a

    Write-Host 'F  Prozess beendet sich, waehrend das Werkzeug auf den Start wartet'
    $a = Starte-Abbild
    $log = Join-Path $tmp 'f.txt'
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-TestProzessId', $a.Proc.Id, '-TestBasis', $a.Basis, '-WartezeitMinuten', 1 -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
    [void]$p.Handle
    Start-Sleep -Seconds 4
    Pruefe 'F Werkzeug wartet noch' (-not $p.HasExited)
    Stoppe-Abbild $a
    $p.WaitForExit(30000) | Out-Null
    $err = Get-Content "$log.err" -Raw
    Pruefe "F erkennt Prozessende (Exit-Code $($p.ExitCode))" ($p.ExitCode -ne 0 -and $err -match 'Testprozess hat sich beendet')
    $a = $null
}
finally {
    if ($a) { Stoppe-Abbild $a }
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
if ($script:fehler) { Write-Host "$($script:fehler) Pruefung(en) fehlgeschlagen." -ForegroundColor Red; exit 1 }
Write-Host 'Alle Pruefungen bestanden.' -ForegroundColor Green
