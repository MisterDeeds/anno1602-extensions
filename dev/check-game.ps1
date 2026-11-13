<#
.SYNOPSIS
  Reads from the running Anno1602.exe (read only) the values that anno-patcher.ps1 sets,
  plus gold, game speed, island count and camera position. For tests in the game.
#>
param([switch]$Short)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CheckMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
}
'@
$p = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'Game is not running.'; return }
$base = $p.MainModule.BaseAddress.ToInt64()
$h = [CheckMem]::OpenProcess(0x0010 -bor 0x0400, $false, $p.Id)
function Read-Memory([long]$adr, [int]$n) { $b = New-Object byte[] $n; $d = [IntPtr]::Zero; [void][CheckMem]::ReadProcessMemory($h, [IntPtr]$adr, $b, [IntPtr]$n, [ref]$d); , $b }
function Read-Rva([long]$rva, [int]$n) { Read-Memory ($base + $rva) $n }
function I32([long]$rva) { [BitConverter]::ToInt32((Read-Rva $rva 4), 0) }
function U16([long]$rva) { [int][BitConverter]::ToUInt16((Read-Rva $rva 2), 0) }
try {
    $res = [ordered]@{}
    $res['World'] = '{0} x {1}, camera range {2}' -f (I32 0x5EBE40), (I32 0x5EBE98), (I32 0x5EB840)
    $res['F7'] = (((Read-Rva 0xE3376 5) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') + $(if ((Read-Rva 0xE3377 1)[0] -eq 8) { ' (8x)' } else { ' (4x)' })
    $res['Game speed now'] = I32 0xF99F8
    $res['Residents per house'] = ((0..4 | ForEach-Object { (I32 (0x6BA02C + $_ * 0x50)) / 64 }) -join '/')
    $res['Cargo t'] = ((21, 23, 25, 27 | ForEach-Object { (U16 (0x6D80C0 + $_ * 0x18C + 0x3E)) / 32 }) -join '/') + ' (small/large trade, small/large war)'
    $res['Ship speed small'] = [BitConverter]::ToSingle((Read-Rva (0x6D80C0 + 21 * 0x18C + 0x10) 4), 0)
    $res['Storage trading post I t'] = (U16 (0x6BA1C0 + 270 * 0x90 + 0x30)) / 32
    $mark = Read-Rva 0xE5F70 8
    $res['Production mark'] = if ($mark[0] -eq 0x4E) { 'NUFR x{0}' -f ([BitConverter]::ToInt32($mark, 4) / 100) } else { 'none' }
    $iv = foreach ($i in 0..499) { U16 (0x6BA1C0 + $i * 0x90 + 0x3A) }
    $res['Intervals (first 8 > 0)'] = (($iv | Where-Object { $_ -gt 0 } | Select-Object -First 8) -join ', ')
    $res['Game clock'] = I32 0x5EC0F8
    $res['Flags (bit 0 = pirates sightings only)'] = '0x{0:X}' -f (I32 0x5EC188)
    $res['Difficulty'] = I32 0x5EC1C0
    $res['Gold slot 0-4'] = ((0..4 | ForEach-Object { I32 (0x5F0964 + $_ * 0x280) }) -join ' / ')
    $n = 0; foreach ($i in 0..49) { if ([BitConverter]::ToInt64((Read-Rva (0x62DDC0 + $i * 0x2CC8 + 0x2CB0) 8), 0) -ne 0) { $n++ } }
    $res['Islands used'] = $n
    $nat = 0; foreach ($i in 0..49) { $ii = 0x62DDC0 + $i * 0x2CC8; if ([BitConverter]::ToInt64((Read-Rva ($ii + 0x2CB0) 8), 0) -ne 0 -and ((Read-Rva ($ii + 0x44) 1)[0] -band 2)) { $nat++ } }
    $res['Islands with natives flag'] = $nat
    # Settlements: 75 slots of 600 bytes from 0x140622DC0, +0x18 = 0xFF free, +0x1A owner.
    $sb = Read-Rva 0x622DC0 (75 * 600); $perOwner = @{}
    for ($i = 0; $i -lt 75; $i++) { if ($sb[$i * 600 + 0x18] -ne 0xFF) { $o = $sb[$i * 600 + 0x1A]; $perOwner[$o] = 1 + [int]$perOwner[$o] } }
    # Residents per player: sum of the fields +0x218, +0x220 ... +0x230 of all settlements (FUN_1400ae010).
    $residents = @{}
    for ($i = 0; $i -lt 75; $i++) { $b0 = $i * 600; if ($sb[$b0 + 0x18] -ne 0xFF) { $o = $sb[$b0 + 0x1A]; $sum = 0; foreach ($f in 0x218, 0x220, 0x224, 0x228, 0x22C, 0x230) { $sum += [BitConverter]::ToInt32($sb, $b0 + $f) }; $residents[$o] = $sum + [int]$residents[$o] } }
    $res['Residents per player 0-3'] = ((0..3 | ForEach-Object { [int]$residents[[byte]$_] }) -join ' / ')
    $res['Settlements per owner (6 = natives)'] = (($perOwner.Keys | Sort-Object | ForEach-Object { "$($_): $($perOwner[$_])" }) -join ', ') + " (used $(($perOwner.Values | Measure-Object -Sum).Sum) of 75)"
    # Ships: 200 slots of 0x328 bytes from 0x1401D8BB0, byte 0 = 0x50 used, +0x28 owner.
    $sh = Read-Rva 0x1D8BB0 (200 * 0x328); $ships = @{}
    for ($i = 0; $i -lt 200; $i++) { if ($sh[$i * 0x328] -eq 0x50) { $o = $sh[$i * 0x328 + 0x28]; $ships[$o] = 1 + [int]$ships[$o] } }
    $res['Ships per owner (4 traders, 5 pirates)'] = ($ships.Keys | Sort-Object | ForEach-Object { "$($_): $($ships[$_])" }) -join ', '
    $res['Traders created / settlement counter'] = '{0} / {1}' -f (I32 0x6D7E68), (I32 0x5B20C4)
    $levels = foreach ($pl in 0..3) { $f = I32 (0x5F09CC + $pl * 0x280); $s = 0; if ($f -band 0x40000) { $s = 1 }; if ($f -band 0x1000000) { $s = 2 }; if ($f -band 0x20000000) { $s = 3 }; if ($f -band 0x40000000) { $s = 4 }; $s }
    $res['Civilization level slot 0-3'] = $levels -join ' / '
    $res['Pirate control: ships in list'] = I32 (0x6EC220 + 5 * 0x11EC8 + 0x1076C)
    $hx = { param($r, $n) ((Read-Rva $r $n) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
    $res['AI hard (0x17A8E)'] = & $hx 0x17A8E 6
    $res['Pirate fleet call (0x3B7F1) / code cave'] = '{0} / {1}' -f (& $hx 0x3B7F1 5), (& $hx 0xE5E00 17)
    $res['Traders call (0xBC140) / code cave'] = '{0} / {1}' -f (& $hx 0xBC140 5), (& $hx 0xE5E20 14)
    # Build cost, upkeep, taxes, radius (anno-patcher.ps1 -BuildCost/-Upkeep/-Taxes/-Radius).
    $mark = { param($rva, $tag) $m = Read-Rva $rva 8; if ([Text.Encoding]::ASCII.GetString($m, 0, 4) -eq $tag) { '{0} x{1}' -f $tag, ([BitConverter]::ToInt32($m, 4) / 100) } else { 'none' } }
    $k1 = 0x6BA1C0 + 270 * 0x90
    $res['Build cost marker / trading post I'] = '{0} / {1} gold, {2} t tools, {3} t wood (original 100, 3, 6)' -f (& $mark 0xE5BC0 'BAUK'), (I32 ($k1 + 0x58)), ((U16 ($k1 + 0x50)) / 32), ((U16 ($k1 + 0x52)) / 32)
    $res['Upkeep marker / trading post I, church'] = '{0} / {1}, {2} (original 15, 50)' -f (& $mark 0xE5BC8 'UNTH'), (U16 ($k1 + 0x2C)), (U16 (0x6BA1C0 + 463 * 0x90 + 0x2C))
    $res['Taxes per group (original 7/8/11/12/13)'] = ((0..4 | ForEach-Object { I32 (0x6BA030 + $_ * 0x50) }) -join '/')
    $res['Radius trading post/market/church/doctor (16/16/21/16)'] = ((270, 467, 463, 469 | ForEach-Object { (Read-Rva (0x6BA1C0 + $_ * 0x90 + 0x20) 1)[0] }) -join '/')
    # Upkeep and taxes per player: running costs = towns +0x1D8 (+0x1DC for the human), taxes as FUN_1400bbdc0.
    $cost = @{}; $tax = @{}
    for ($i = 0; $i -lt 75; $i++) {
        $b0 = $i * 600; if ($sb[$b0 + 0x18] -eq 0xFF) { continue }
        $o = $sb[$b0 + 0x1A]; $cost[$o] = [int]$cost[$o] + [BitConverter]::ToInt32($sb, $b0 + 0x1D8) + $(if ($o -eq 0) { [BitConverter]::ToInt32($sb, $b0 + 0x1DC) } else { 0 })
        $t = 0; foreach ($g in 0..4) { $v = [BitConverter]::ToInt32($sb, $b0 + 0x220 + 4 * $g) * (I32 (0x6BA030 + $g * 0x50)) * 6; $t += [math]::Truncate([math]::Truncate($v / 32) * $sb[$b0 + 0x24D + $g] / 128) }
        $tax[$o] = [int]$tax[$o] + $t
    }
    $res['Taxes / running costs per tick, player 0-3'] = ((0..3 | ForEach-Object { '{0}/{1}' -f [int]$tax[[byte]$_], [int]$cost[[byte]$_] }) -join '  ')
    # Fertility (-Fertility Everywhere): hook in FUN_1400d0ce0 and islands with all six crops (+0x5C bits 1-6).
    $six = 0; $used = 0
    foreach ($i in 0..49) { $ii = 0x62DDC0 + $i * 0x2CC8; if ([BitConverter]::ToInt64((Read-Rva ($ii + 0x2CB0) 8), 0) -ne 0) { $used++; if (((I32 ($ii + 0x5C)) -band 0x7E) -eq 0x7E) { $six++ } } }
    $res['Fertility jump (0xD0D56) / islands with all six crops'] = '{0} / {1} of {2}' -f (& $hx 0xD0D56 5), $six, $used
    # Mines (-Mines Infinite) and the ore/gold still in the deposits (island +0x20 + i*8: ware, x, y, -, kind, -, amount x 32).
    $ore = 0; $gold = 0
    foreach ($i in 0..49) { $ii = 0x62DDC0 + $i * 0x2CC8; if ([BitConverter]::ToInt64((Read-Rva ($ii + 0x2CB0) 8), 0) -eq 0) { continue }; $n = (Read-Rva ($ii + 0x41) 1)[0]; $dep = Read-Rva ($ii + 0x20) (8 * [math]::Max(1, $n)); for ($j = 0; $j -lt $n; $j++) { $amt = [BitConverter]::ToUInt16($dep, 8 * $j + 6); if ($dep[8 * $j] -eq 2) { $ore += $amt } elseif ($dep[8 * $j] -eq 3) { $gold += $amt } } }
    $res['Mines (0xBA429 / 0xBA495) / ore, gold t in deposits'] = '{0} / {1} / {2}, {3}' -f (& $hx 0xBA429 4), (& $hx 0xBA495 5), [math]::Round($ore / 32), [math]::Round($gold / 32)
    $dis = if ((& $hx 0xBCAC3 5) -eq '0F 1F 44 00 00') { 'Off' } elseif ((& $hx 0xBCABB 3) -eq '83 FA 19') { 'More' } else { 'Default' }
    $res['Disasters (plague call 0xBCAC3, limit 0xBCABB)'] = '{0} ({1}, {2}); drought on island 0-49: {3}' -f $dis, (& $hx 0xBCAC3 5), (& $hx 0xBCABB 3), (@(0..49 | Where-Object { (Read-Rva (0x62DDC0 + $_ * 0x2CC8 + 0x45) 1)[0] -ne 0 }).Count)
    $cam = [BitConverter]::ToInt64((Read-Rva 0xF9A00 8), 0)
    if ($cam) { $k = Read-Memory $cam 0x4C; $res['Camera world x/y, scroll s/t, rotation'] = '{0}/{1}, {2}/{3}, {4}' -f [BitConverter]::ToInt32($k, 0x1C), [BitConverter]::ToInt32($k, 0x20), [BitConverter]::ToInt32($k, 0x24), [BitConverter]::ToInt32($k, 0x28), [BitConverter]::ToInt32($k, 0x48) }
    if ($Short) { $res.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } } else { [pscustomobject]$res | Format-List }
}
finally { [void][CheckMem]::CloseHandle($h) }
