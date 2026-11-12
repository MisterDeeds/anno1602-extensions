<#
.SYNOPSIS
  Checks custom scenarios (.szs): sections, mission, island maps (small and big), player data.

.DESCRIPTION
  Read-only. For every file: mission decoded (goals, text, length), race setting
  (rivals with the same mission and goal bit 0x800), small map 500 x 350 and big version ('GROS')
  inside the map and without overlaps, resources, villages, gold, difficulty, pirates.
  Exit code 1 if a check fails.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\check-scenarios.ps1 -Folder .\tools\scenarios
#>
param([string]$Folder = (Join-Path $PSScriptRoot 'scenarios'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scenario-lib.ps1')
$ClassW = @(30, 40, 50, 70, 100); $ClassH = @(30, 40, 52, 60, 90)
$stageNames = 'pioneers', 'settlers', 'citizens', 'merchants', 'aristocrats'
$goodsNames = @{ 3 = 'gold'; 12 = 'muskets'; 13 = 'cannons'; 16 = 'spices'; 20 = 'clothes'; 21 = 'jewelry'; 22 = 'tools' }
$failures = 0
function Assert-Check([string]$what, [bool]$ok) { if (-not $ok) { Write-Host "   FAILED $what" -ForegroundColor Red; $script:failures++ } }

function Test-IslandBlock([byte[]]$s, [int]$o0, [int]$w, [int]$h, [string]$name) {
    $n = [BitConverter]::ToInt32($s, $o0 + 0x64)
    Assert-Check "$($name): island count $n" ($n -ge 1 -and $n -le 50)
    $ok = $true; $cls = @(0, 0, 0, 0, 0)
    for ($i = 0; $i -lt $n; $i++) {
        $o = $o0 + 0x174 + 16 * $i; $x = [BitConverter]::ToInt32($s, $o + 8); $y = [BitConverter]::ToInt32($s, $o + 12); $c = $s[$o + 1]
        if ($c -gt 4) { $ok = $false; continue }
        $cls[$c]++
        if ($x -lt 0 -or $y -lt 0 -or $x + $ClassW[$c] -gt $w -or $y + $ClassH[$c] -gt $h) { $ok = $false }
        for ($j = $i + 1; $j -lt $n; $j++) {
            $q = $o0 + 0x174 + 16 * $j; $x2 = [BitConverter]::ToInt32($s, $q + 8); $y2 = [BitConverter]::ToInt32($s, $q + 12); $c2 = $s[$q + 1]
            if ($c2 -le 4 -and $x -lt $x2 + $ClassW[$c2] -and $x2 -lt $x + $ClassW[$c] -and $y -lt $y2 + $ClassH[$c2] -and $y2 -lt $y + $ClassH[$c]) { $ok = $false }
        }
    }
    Assert-Check "$($name): islands inside the map and without overlaps" $ok
    $res = foreach ($r in 0..17) { $o = $o0 + 0x94 + 8 * $r; $nr = [BitConverter]::ToUInt16($s, $o); $m = [BitConverter]::ToUInt16($s, $o + 2); if ($nr) { "$($nr):$m" } }
    '{0}: {1} islands (lit/mit/med/big/lar {2}), villages {3}+{4}, resources {5}' -f $name, $n, ($cls -join '/'), [BitConverter]::ToInt32($s, $o0 + 0x40), [BitConverter]::ToInt32($s, $o0 + 0x44), ($res -join ' ')
}

foreach ($f in Get-ChildItem $Folder -Filter *.szs | Sort-Object Name) {
    Write-Host $f.BaseName -ForegroundColor Cyan
    $l = Read-Scenario $f.FullName
    $names = ($l | ForEach-Object { $_.Name }) -join ','
    Assert-Check "Sections: $names" ($names -eq 'SZENE_PLAYERMIN,SZENE_PLAYERMAX,SZENE_GAMEID,SZENE_RANKING,RANDTAB,AUFTRAG4,SZENE,PLAYER4,SHIP4,TIMERS')
    $a = (Get-Section $l 'AUFTRAG4').Data; $s = (Get-Section $l 'SZENE').Data; $p = (Get-Section $l 'PLAYER4').Data; $t = (Get-Section $l 'TIMERS').Data
    Assert-Check "AUFTRAG4 length $($a.Length)" ($a.Length -eq 0x8C4)
    $bits = [BitConverter]::ToInt32($a, 4); $z = @()
    foreach ($k in 0..2) { $o = 0x870 + 12 * $k; $e = [BitConverter]::ToInt32($a, $o); if ($e) { $st = [BitConverter]::ToInt32($a, $o + 4); Assert-Check "Stage $st" ($st -ge 0 -and $st -le 4); $z += 'town {0} residents ({1} {2})' -f $e, [BitConverter]::ToInt32($a, $o + 8), $stageNames[$st] } }
    if ($bits -band 0x20) { $z += '{0} towns' -f [BitConverter]::ToInt32($a, 0x40) }
    if ($bits -band 0x80) { $z += '{0} residents in total' -f [BitConverter]::ToInt32($a, 0x44) }
    if ($bits -band 0x100) { $z += 'balance >= ' + [BitConverter]::ToInt32($a, 0x4C) }
    if ($bits -band 0x10000) { $z += 'trade balance >= ' + [BitConverter]::ToInt32($a, 0x54) }
    if ($bits -band 0x400) { $z += 'defeat: players ' + ((0..6 | Where-Object { $a[0x2C + $_] }) -join ',') }
    if ($bits -band 0x4000) { $z += 'monopoly 0x{0:X2}' -f $a[0x20] }
    foreach ($w in 0, 1) { if ($bits -band (0x1000 -shl $w)) { $nr = $a[0x868 + 4 * $w]; $z += '{0} t {1}' -f ([BitConverter]::ToUInt16($a, 0x86A + 4 * $w) / 32), $(if ($goodsNames.ContainsKey([int]$nr)) { $goodsNames[[int]$nr] } else { "good $nr" }) } }
    $race = ($bits -band 0x800) -ne 0
    $txt = [Text.Encoding]::GetEncoding(1252).GetString($a, 0x68, 0x800).Split([char]0)[0]
    Assert-Check 'Mission text present and at most 2047 bytes' ($txt.Length -gt 50 -and $txt.Length -le 2047)
    Assert-Check 'Mission has at least one goal' ($z.Count -gt 0)
    '   Mission: {0}{1}' -f ($z -join '; '), $(if ($race) { '  [RACE: also applies to the rivals]' } else { '' })
    $missionSlots = 0..3 | ForEach-Object { $p[$_ * 0x430 + 0x0C] }
    Assert-Check "Mission slot of the human player = 0" ($missionSlots[0] -eq 0)
    if ($race) { Assert-Check "Race: rivals on mission 0 ($($missionSlots -join '/'))" (($missionSlots | Where-Object { $_ -ne 0 }).Count -eq 0) }
    else { Assert-Check "Rivals without a mission ($($missionSlots -join '/'))" (($missionSlots[1..3] | Where-Object { $_ -ne 0xFF }).Count -eq 0) }
    '   Gold player {0}, rivals {1}; difficulty {2}; pirates {3}; text {4} characters' -f [BitConverter]::ToInt32($p, 0), (((1..3) | ForEach-Object { [BitConverter]::ToInt32($p, $_ * 0x430) }) -join '/'), $t[0xA6], $(if ([BitConverter]::ToInt32($t, 0xA8) -band 1) { 'only sighted' } else { 'active' }), $txt.Length
    '   ' + (Test-IslandBlock $s 0 500 350 'small')
    if ($s.Length -ge 2360 -and [Text.Encoding]::ASCII.GetString($s, 0x494, 4) -eq 'GROS') {
        $bw = [BitConverter]::ToInt32($s, 0x498); $bh = [BitConverter]::ToInt32($s, 0x49C)
        Assert-Check "big version: length $($s.Length)" ($s.Length -eq 2360)
        '   ' + (Test-IslandBlock $s 0x4A4 $bw $bh "big $bw x $bh")
    }
    else { Assert-Check 'big version present' $false }
    # Starting ships: in the water in all map versions (ships are not stretched, islands are).
    $sh = (Get-Section $l 'SHIP4').Data; $conflicts = @()
    $ships = for ($i = 0; $i -lt $sh.Length / 0x1B4; $i++) { , @([BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1E)) }
    $versions = @(@(0, 1.0, 'small 500'), @(0, 1.5, 'small 750'), @(0, 2.0, 'small 1000'), @(0, 4.0, 'small 2000'))
    if ($s.Length -ge 2360) { $versions += @(@(0x4A4, 1.0, 'big 1000'), @(0x4A4, 2.0, 'big 2000')) }
    foreach ($v in $versions) {
        $n = [BitConverter]::ToInt32($s, $v[0] + 0x64)
        for ($i = 0; $i -lt $n; $i++) {
            $o = $v[0] + 0x174 + 16 * $i; $c = $s[$o + 1]; $x = [math]::Truncate([BitConverter]::ToInt32($s, $o + 8) * $v[1]); $y = [math]::Truncate([BitConverter]::ToInt32($s, $o + 12) * $v[1])
            foreach ($sp in $ships) { if ($sp[0] -gt $x - 3 -and $sp[0] -lt $x + $ClassW[$c] + 3 -and $sp[1] -gt $y - 3 -and $sp[1] -lt $y + $ClassH[$c] + 3) { $conflicts += "$($v[2]): ship at $($sp[0]),$($sp[1]) inside island $i" } }
        }
    }
    Assert-Check ("Starting ships in the water ({0}) {1}" -f (($ships | ForEach-Object { "$($_[0]),$($_[1])" }) -join ' '), ($conflicts -join '; ')) ($conflicts.Count -eq 0)
    '   Starting ships: ' + (($ships | ForEach-Object { "$($_[0]),$($_[1])" }) -join ' ') + $(if ($conflicts.Count -eq 0) { ' (clear in all map versions)' } else { '' })
}
if ($failures) { Write-Host "$failures check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All scenarios OK.' -ForegroundColor Green
