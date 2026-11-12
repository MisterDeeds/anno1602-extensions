<#
.SYNOPSIS
  Liest aus dem laufenden Anno1602.exe (nur lesend) die Werte, die weltgroesse.ps1 setzt,
  dazu Gold, Spieltempo, Inselzahl und Kameraposition. Fuer Tests im Spiel.
#>
param([switch]$Kurz)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PruefMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
}
'@
$p = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'Spiel laeuft nicht.'; return }
$basis = $p.MainModule.BaseAddress.ToInt64()
$h = [PruefMem]::OpenProcess(0x0010 -bor 0x0400, $false, $p.Id)
function Abs([long]$adr, [int]$n) { $b = New-Object byte[] $n; $d = [IntPtr]::Zero; [void][PruefMem]::ReadProcessMemory($h, [IntPtr]$adr, $b, [IntPtr]$n, [ref]$d); , $b }
function LiesRva([long]$rva, [int]$n) { Abs ($basis + $rva) $n }
function I32([long]$rva) { [BitConverter]::ToInt32((LiesRva $rva 4), 0) }
function U16([long]$rva) { [int][BitConverter]::ToUInt16((LiesRva $rva 2), 0) }
try {
    $erg = [ordered]@{}
    $erg['Welt'] = '{0} x {1}, Kamerabereich {2}' -f (I32 0x5EBE40), (I32 0x5EBE98), (I32 0x5EB840)
    $erg['F7'] = (((LiesRva 0xE3376 5) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') + $(if ((LiesRva 0xE3377 1)[0] -eq 8) { ' (8-fach)' } else { ' (4-fach)' })
    $erg['Spieltempo jetzt'] = I32 0xF99F8
    $erg['Einwohner je Haus'] = ((0..4 | ForEach-Object { (I32 (0x6BA02C + $_ * 0x50)) / 64 }) -join '/')
    $erg['Laderaum t'] = ((21, 23, 25, 27 | ForEach-Object { (U16 (0x6D80C0 + $_ * 0x18C + 0x3E)) / 32 }) -join '/') + ' (klein/gross Handel, klein/gross Krieg)'
    $erg['Schiffstempo klein'] = [BitConverter]::ToSingle((LiesRva (0x6D80C0 + 21 * 0x18C + 0x10) 4), 0)
    $erg['Lager Kontor I t'] = (U16 (0x6BA1C0 + 270 * 0x90 + 0x30)) / 32
    $marke = LiesRva 0xE5F70 8
    $erg['Produktions-Marke'] = if ($marke[0] -eq 0x4E) { 'NUFR x{0}' -f ([BitConverter]::ToInt32($marke, 4) / 100) } else { 'keine' }
    $iv = foreach ($i in 0..499) { U16 (0x6BA1C0 + $i * 0x90 + 0x3A) }
    $erg['Intervalle (erste 8 > 0)'] = (($iv | Where-Object { $_ -gt 0 } | Select-Object -First 8) -join ', ')
    $erg['Spieluhr'] = I32 0x5EC0F8
    $erg['Flags (Bit 0 = Piraten nur Sichtungen)'] = '0x{0:X}' -f (I32 0x5EC188)
    $erg['Schwierigkeit'] = I32 0x5EC1C0
    $erg['Gold Platz 0-4'] = ((0..4 | ForEach-Object { I32 (0x5F0964 + $_ * 0x280) }) -join ' / ')
    $n = 0; foreach ($i in 0..49) { if ([BitConverter]::ToInt64((LiesRva (0x62DDC0 + $i * 0x2CC8 + 0x2CB0) 8), 0) -ne 0) { $n++ } }
    $erg['Inseln belegt'] = $n
    $nat = 0; foreach ($i in 0..49) { $ii = 0x62DDC0 + $i * 0x2CC8; if ([BitConverter]::ToInt64((LiesRva ($ii + 0x2CB0) 8), 0) -ne 0 -and ((LiesRva ($ii + 0x44) 1)[0] -band 2)) { $nat++ } }
    $erg['Inseln mit Eingeborenen-Flag'] = $nat
    # Siedlungen: 75 Plaetze a 600 Byte ab 0x140622DC0, +0x18 = 0xFF frei, +0x1A Besitzer.
    $sb = LiesRva 0x622DC0 (75 * 600); $proBesitzer = @{}
    for ($i = 0; $i -lt 75; $i++) { if ($sb[$i * 600 + 0x18] -ne 0xFF) { $o = $sb[$i * 600 + 0x1A]; $proBesitzer[$o] = 1 + [int]$proBesitzer[$o] } }
    # Einwohner je Spieler: Summe der Felder +0x218, +0x220 ... +0x230 aller Siedlungen (FUN_1400ae010).
    $einw = @{}
    for ($i = 0; $i -lt 75; $i++) { $b0 = $i * 600; if ($sb[$b0 + 0x18] -ne 0xFF) { $o = $sb[$b0 + 0x1A]; $sum = 0; foreach ($f in 0x218, 0x220, 0x224, 0x228, 0x22C, 0x230) { $sum += [BitConverter]::ToInt32($sb, $b0 + $f) }; $einw[$o] = $sum + [int]$einw[$o] } }
    $erg['Einwohner je Spieler 0-3'] = ((0..3 | ForEach-Object { [int]$einw[[byte]$_] }) -join ' / ')
    $erg['Siedlungen je Besitzer (6 = Eingeborene)'] = (($proBesitzer.Keys | Sort-Object | ForEach-Object { "$($_): $($proBesitzer[$_])" }) -join ', ') + " (belegt $(($proBesitzer.Values | Measure-Object -Sum).Sum) von 75)"
    # Schiffe: 200 Plaetze a 0x328 Byte ab 0x1401D8BB0, Byte 0 = 0x50 belegt, +0x28 Besitzer.
    $sh = LiesRva 0x1D8BB0 (200 * 0x328); $schiffe = @{}
    for ($i = 0; $i -lt 200; $i++) { if ($sh[$i * 0x328] -eq 0x50) { $o = $sh[$i * 0x328 + 0x28]; $schiffe[$o] = 1 + [int]$schiffe[$o] } }
    $erg['Schiffe je Besitzer (4 Haendler, 5 Piraten)'] = ($schiffe.Keys | Sort-Object | ForEach-Object { "$($_): $($schiffe[$_])" }) -join ', '
    $erg['Haendler erzeugt / Siedlungszaehler'] = '{0} / {1}' -f (I32 0x6D7E68), (I32 0x5B20C4)
    $stufen = foreach ($pl in 0..3) { $f = I32 (0x5F09CC + $pl * 0x280); $s = 0; if ($f -band 0x40000) { $s = 1 }; if ($f -band 0x1000000) { $s = 2 }; if ($f -band 0x20000000) { $s = 3 }; if ($f -band 0x40000000) { $s = 4 }; $s }
    $erg['Zivilisationsstufe Platz 0-3'] = $stufen -join ' / '
    $erg['Piraten-Steuerung: Schiffe in Liste'] = I32 (0x6EC220 + 5 * 0x11EC8 + 0x1076C)
    $hx = { param($r, $n) ((LiesRva $r $n) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
    $erg['KI Schwer (0x17A8E)'] = & $hx 0x17A8E 6
    $erg['Piratenflotte Aufruf (0x3B7F1) / Codestueck'] = '{0} / {1}' -f (& $hx 0x3B7F1 5), (& $hx 0xE5E00 17)
    $erg['Haendler Aufruf (0xBC140) / Codestueck'] = '{0} / {1}' -f (& $hx 0xBC140 5), (& $hx 0xE5E20 14)
    $kam = [BitConverter]::ToInt64((LiesRva 0xF9A00 8), 0)
    if ($kam) { $k = Abs $kam 0x4C; $erg['Kamera Welt x/y, Scroll s/t, Drehung'] = '{0}/{1}, {2}/{3}, {4}' -f [BitConverter]::ToInt32($k, 0x1C), [BitConverter]::ToInt32($k, 0x20), [BitConverter]::ToInt32($k, 0x24), [BitConverter]::ToInt32($k, 0x28), [BitConverter]::ToInt32($k, 0x48) }
    if ($Kurz) { $erg.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } } else { [pscustomobject]$erg | Format-List }
}
finally { [void][PruefMem]::CloseHandle($h) }
