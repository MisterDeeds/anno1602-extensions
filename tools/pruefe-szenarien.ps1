<#
.SYNOPSIS
  Prueft eigene Szenarien (.szs): Abschnitte, Auftrag, Inselkarten (klein und gross), Spielerdaten.

.DESCRIPTION
  Nur lesend. Fuer jede Datei: Auftrag entschluesselt (Ziele, Text, Laenge), Wettlauf-Einstellung
  (Gegner mit demselben Auftrag und Zielbit 0x800), kleine Karte 500 x 350 und grosse Fassung ('GROS')
  innerhalb der Karte und ohne Ueberschneidung, Rohstoffe, Doerfer, Gold, Schwierigkeit, Piraten.
  Exit-Code 1, wenn eine Pruefung fehlschlaegt.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\pruefe-szenarien.ps1 -Ordner .\tools\kampagne
#>
param([string]$Ordner = (Join-Path $PSScriptRoot 'kampagne'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'szenario-bauer.ps1')
$KB = @(30, 40, 50, 70, 100); $KH = @(30, 40, 52, 60, 90)
$stufe = 'Pioniere', 'Siedler', 'Buerger', 'Kaufleute', 'Aristokraten'
$ware = @{ 3 = 'Gold'; 12 = 'Musketen'; 13 = 'Kanonen'; 16 = 'Gewuerze'; 20 = 'Kleidung'; 21 = 'Schmuck'; 22 = 'Werkzeug' }
$fehler = 0
function Melde([string]$was, [bool]$ok) { if (-not $ok) { Write-Host "   FEHLER $was" -ForegroundColor Red; $script:fehler++ } }

function Pruefe-Block([byte[]]$s, [int]$o0, [int]$b, [int]$h, [string]$name) {
    $n = [BitConverter]::ToInt32($s, $o0 + 0x64)
    Melde "$($name): Inselzahl $n" ($n -ge 1 -and $n -le 50)
    $ok = $true; $kl = @(0, 0, 0, 0, 0)
    for ($i = 0; $i -lt $n; $i++) {
        $o = $o0 + 0x174 + 16 * $i; $x = [BitConverter]::ToInt32($s, $o + 8); $y = [BitConverter]::ToInt32($s, $o + 12); $c = $s[$o + 1]
        if ($c -gt 4) { $ok = $false; continue }
        $kl[$c]++
        if ($x -lt 0 -or $y -lt 0 -or $x + $KB[$c] -gt $b -or $y + $KH[$c] -gt $h) { $ok = $false }
        for ($j = $i + 1; $j -lt $n; $j++) {
            $q = $o0 + 0x174 + 16 * $j; $x2 = [BitConverter]::ToInt32($s, $q + 8); $y2 = [BitConverter]::ToInt32($s, $q + 12); $c2 = $s[$q + 1]
            if ($c2 -le 4 -and $x -lt $x2 + $KB[$c2] -and $x2 -lt $x + $KB[$c] -and $y -lt $y2 + $KH[$c2] -and $y2 -lt $y + $KH[$c]) { $ok = $false }
        }
    }
    Melde "$($name): Inseln in der Karte und ohne Ueberschneidung" $ok
    $roh = foreach ($r in 0..17) { $o = $o0 + 0x94 + 8 * $r; $nr = [BitConverter]::ToUInt16($s, $o); $m = [BitConverter]::ToUInt16($s, $o + 2); if ($nr) { "$($nr):$m" } }
    '{0}: {1} Inseln (lit/mit/med/big/lar {2}), Doerfer {3}+{4}, Rohstoffe {5}' -f $name, $n, ($kl -join '/'), [BitConverter]::ToInt32($s, $o0 + 0x40), [BitConverter]::ToInt32($s, $o0 + 0x44), ($roh -join ' ')
}

foreach ($f in Get-ChildItem $Ordner -Filter *.szs | Sort-Object Name) {
    Write-Host $f.BaseName -ForegroundColor Cyan
    $l = Lies-Szenario $f.FullName
    $namen = ($l | ForEach-Object { $_.Name }) -join ','
    Melde "Abschnitte: $namen" ($namen -eq 'SZENE_PLAYERMIN,SZENE_PLAYERMAX,SZENE_GAMEID,SZENE_RANKING,RANDTAB,AUFTRAG4,SZENE,PLAYER4,SHIP4,TIMERS')
    $a = (Abschnitt $l 'AUFTRAG4').Daten; $s = (Abschnitt $l 'SZENE').Daten; $p = (Abschnitt $l 'PLAYER4').Daten; $t = (Abschnitt $l 'TIMERS').Daten
    Melde "AUFTRAG4 Laenge $($a.Length)" ($a.Length -eq 0x8C4)
    $bits = [BitConverter]::ToInt32($a, 4); $z = @()
    foreach ($k in 0..2) { $o = 0x870 + 12 * $k; $e = [BitConverter]::ToInt32($a, $o); if ($e) { $st = [BitConverter]::ToInt32($a, $o + 4); Melde "Stufe $st" ($st -ge 0 -and $st -le 4); $z += 'Stadt {0} Einw. ({1} {2})' -f $e, [BitConverter]::ToInt32($a, $o + 8), $stufe[$st] } }
    if ($bits -band 0x20) { $z += '{0} Staedte' -f [BitConverter]::ToInt32($a, 0x40) }
    if ($bits -band 0x80) { $z += '{0} Einwohner gesamt' -f [BitConverter]::ToInt32($a, 0x44) }
    if ($bits -band 0x100) { $z += 'Bilanz >= ' + [BitConverter]::ToInt32($a, 0x4C) }
    if ($bits -band 0x10000) { $z += 'Handelsbilanz >= ' + [BitConverter]::ToInt32($a, 0x54) }
    if ($bits -band 0x400) { $z += 'besiegen: Spieler ' + ((0..6 | Where-Object { $a[0x2C + $_] }) -join ',') }
    if ($bits -band 0x4000) { $z += 'Monopol 0x{0:X2}' -f $a[0x20] }
    foreach ($w in 0, 1) { if ($bits -band (0x1000 -shl $w)) { $nr = $a[0x868 + 4 * $w]; $z += '{0} t {1}' -f ([BitConverter]::ToUInt16($a, 0x86A + 4 * $w) / 32), $(if ($ware.ContainsKey([int]$nr)) { $ware[[int]$nr] } else { "Ware $nr" }) } }
    $wettlauf = ($bits -band 0x800) -ne 0
    $txt = [Text.Encoding]::GetEncoding(1252).GetString($a, 0x68, 0x800).Split([char]0)[0]
    Melde 'Auftragstext vorhanden und hoechstens 2047 Byte' ($txt.Length -gt 50 -and $txt.Length -le 2047)
    Melde 'Auftrag hat mindestens ein Ziel' ($z.Count -gt 0)
    '   Auftrag: {0}{1}' -f ($z -join '; '), $(if ($wettlauf) { '  [WETTLAUF: gilt auch fuer die Gegner]' } else { '' })
    $auftragSp = 0..3 | ForEach-Object { $p[$_ * 0x430 + 0x0C] }
    Melde "Auftragsplatz Mensch = 0" ($auftragSp[0] -eq 0)
    if ($wettlauf) { Melde "Wettlauf: Gegner auf Auftrag 0 ($($auftragSp -join '/'))" (($auftragSp | Where-Object { $_ -ne 0 }).Count -eq 0) }
    else { Melde "Gegner ohne Auftrag ($($auftragSp -join '/'))" (($auftragSp[1..3] | Where-Object { $_ -ne 0xFF }).Count -eq 0) }
    '   Gold Spieler {0}, Gegner {1}; Schwierigkeit {2}; Piraten {3}; Text {4} Zeichen' -f [BitConverter]::ToInt32($p, 0), (((1..3) | ForEach-Object { [BitConverter]::ToInt32($p, $_ * 0x430) }) -join '/'), $t[0xA6], $(if ([BitConverter]::ToInt32($t, 0xA8) -band 1) { 'nur gesichtet' } else { 'aktiv' }), $txt.Length
    '   ' + (Pruefe-Block $s 0 500 350 'klein')
    if ($s.Length -ge 2360 -and [Text.Encoding]::ASCII.GetString($s, 0x494, 4) -eq 'GROS') {
        $gb = [BitConverter]::ToInt32($s, 0x498); $gh = [BitConverter]::ToInt32($s, 0x49C)
        Melde "grosse Fassung: Laenge $($s.Length)" ($s.Length -eq 2360)
        '   ' + (Pruefe-Block $s 0x4A4 $gb $gh "gross $gb x $gh")
    }
    else { Melde 'grosse Fassung vorhanden' $false }
    # Startschiffe: im Wasser in allen Kartenfassungen (Schiffe werden nicht gestreckt, Inseln schon).
    $sh = (Abschnitt $l 'SHIP4').Daten; $konflikt = @()
    $schiffe = for ($i = 0; $i -lt $sh.Length / 0x1B4; $i++) { , @([BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1E)) }
    $fassungen = @(@(0, 1.0, 'klein 500'), @(0, 1.5, 'klein 750'), @(0, 2.0, 'klein 1000'), @(0, 4.0, 'klein 2000'))
    if ($s.Length -ge 2360) { $fassungen += @(@(0x4A4, 1.0, 'gross 1000'), @(0x4A4, 2.0, 'gross 2000')) }
    foreach ($fa in $fassungen) {
        $n = [BitConverter]::ToInt32($s, $fa[0] + 0x64)
        for ($i = 0; $i -lt $n; $i++) {
            $o = $fa[0] + 0x174 + 16 * $i; $c = $s[$o + 1]; $x = [math]::Truncate([BitConverter]::ToInt32($s, $o + 8) * $fa[1]); $y = [math]::Truncate([BitConverter]::ToInt32($s, $o + 12) * $fa[1])
            foreach ($sp in $schiffe) { if ($sp[0] -gt $x - 3 -and $sp[0] -lt $x + $KB[$c] + 3 -and $sp[1] -gt $y - 3 -and $sp[1] -lt $y + $KH[$c] + 3) { $konflikt += "$($fa[2]): Schiff bei $($sp[0]),$($sp[1]) in Insel $i" } }
        }
    }
    Melde ("Startschiffe im Wasser ({0}) {1}" -f (($schiffe | ForEach-Object { "$($_[0]),$($_[1])" }) -join ' '), ($konflikt -join '; ')) ($konflikt.Count -eq 0)
    '   Startschiffe: ' + (($schiffe | ForEach-Object { "$($_[0]),$($_[1])" }) -join ' ') + $(if ($konflikt.Count -eq 0) { ' (in allen Kartenfassungen frei)' } else { '' })
}
if ($fehler) { Write-Host "$fehler Pruefung(en) fehlgeschlagen." -ForegroundColor Red; exit 1 }
Write-Host 'Alle Szenarien in Ordnung.' -ForegroundColor Green
