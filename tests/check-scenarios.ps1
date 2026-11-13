<#
.SYNOPSIS
  Checks custom scenarios (.szs): sections, mission, texts, island maps (small and big), player data,
  ships and their cargo; optionally regenerates the random adventures and compares them byte for byte.

.DESCRIPTION
  Read-only (except -Reproduce, which writes into a temporary folder and deletes it again). For every file:
  - sections in the order the game expects, AUFTRAG4 length
  - mission decoded (towns, all towns at least, number of towns, total residents, balance, trade balance,
    goods, monopolies, defeat, race), value ranges, town goals in descending order (the game assigns them
    greedily), every goal number also written in the mission text
  - text: language recognised (German "Euer Auftrag" / English "Your orders"), at most 2047 bytes, no CR,
    English texts and all file names in plain ASCII
  - race setting (rivals with the same mission and goal bit 0x800) or rivals without a mission
  - small map 500 x 350 and big version ('GROS') inside the map and without overlaps, resources, villages
  - ships: positions in the water in all map versions, cargo space and cannons match the ship type,
    cargo (house no. known, whole tons, at most one hold per slot of the ship type), names
  - random adventures ("Abenteuer <seed>" / "Adventure <seed>"): game id = seed and difficulty
  Exit code 1 if a check fails.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tests\check-scenarios.ps1 -Folder .\src\scenarios
  powershell -ExecutionPolicy Bypass -File .\tests\check-scenarios.ps1 -Folder .\src\scenarios -Reproduce
#>
param([string]$Folder = (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\scenarios'), [switch]$Reproduce, [string]$GamePath, [switch]$Quiet)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\scenario-lib.ps1')
$ClassW = @(30, 40, 50, 70, 100); $ClassH = @(30, 40, 52, 60, 90)
$stageNames = 'pioneers', 'settlers', 'citizens', 'merchants', 'aristocrats'
$goodsNames = @{ 2 = 'iron ore'; 3 = 'gold'; 4 = 'wool'; 5 = 'sugar'; 6 = 'tobacco'; 7 = 'cattle'; 8 = 'grain'; 9 = 'flour'; 10 = 'iron'; 11 = 'swords'; 12 = 'muskets'; 13 = 'cannons'; 14 = 'food'; 15 = 'tobacco goods'; 16 = 'spices'; 17 = 'cocoa'; 18 = 'liquor'; 19 = 'cloth'; 20 = 'clothes'; 21 = 'jewelry'; 22 = 'tools'; 23 = 'wood'; 24 = 'bricks' }
$cropNames = @{ 0x2D = 'grain'; 0x2E = 'tobacco'; 0x2F = 'spices'; 0x30 = 'sugar'; 0x31 = 'cotton'; 0x32 = 'wine'; 0x33 = 'cocoa' }
$houseNames = @{}; foreach ($k in $CargoHouse.Keys) { $houseNames[[int]$CargoHouse[$k]] = $k }
# House no. in ship cargo -> good of the goods list (as in AUFTRAG4).
$houseGood = @{ 515 = 22; 2001 = 23; 1075 = 14; 513 = 24; 507 = 19; 519 = 18; 525 = 15; 517 = 11; 527 = 13; 521 = 10; 2401 = 2; 2405 = 3; 1501 = 16; 1509 = 17; 1507 = 6; 1505 = 4 }
$failures = 0; $files = 0
function Assert-Check([string]$what, [bool]$ok) { if (-not $ok) { Write-Host "   FAILED $what" -ForegroundColor Red; $script:failures++ } }
function Write-Info([string]$line) { if (-not $Quiet) { $line } }
function Test-Ascii([string]$s) { foreach ($ch in $s.ToCharArray()) { if ([int]$ch -gt 126 -or ([int]$ch -lt 32 -and $ch -ne "`n")) { return $false } }; $true }

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
    Assert-Check "$($name): at most 10 islands of class lar ($($cls[4]))" ($cls[4] -le 10)
    # The computer rivals need an island of class med (50 x 52) or bigger; with only lit/mit islands they drop out at
    # the start (kind 9) and the game ends as lost at the first mission check (seen in game 2026-11-12).
    Assert-Check "$($name): at least 4 islands of class med or bigger for the rivals ($($cls[2] + $cls[3] + $cls[4]))" (($cls[2] + $cls[3] + $cls[4]) -ge 4)
    $res = foreach ($r in 0..17) { $o = $o0 + 0x94 + 8 * $r; $nr = [BitConverter]::ToUInt16($s, $o); $m = [BitConverter]::ToUInt16($s, $o + 2); if ($nr) { "$($nr):$m" } }
    '{0}: {1} islands (lit/mit/med/big/lar {2}), villages {3}+{4}, resources {5}' -f $name, $n, ($cls -join '/'), [BitConverter]::ToInt32($s, $o0 + 0x40), [BitConverter]::ToInt32($s, $o0 + 0x44), ($res -join ' ')
}
# Town goal at offset o of AUFTRAG4: residents, stage, of which.
function Get-TownGoal([byte[]]$a, [int]$o) { @{ Residents = [BitConverter]::ToInt32($a, $o); Stage = [BitConverter]::ToInt32($a, $o + 4); OfWhich = [BitConverter]::ToInt32($a, $o + 8) } }

$adventures = New-Object System.Collections.Generic.List[object]
foreach ($f in Get-ChildItem -LiteralPath $Folder -Filter *.szs | Sort-Object Name) {
    $files++
    if (-not $Quiet) { Write-Host $f.BaseName -ForegroundColor Cyan } else { Write-Host ("{0}: {1}" -f $files, $f.BaseName) }
    Assert-Check "File name in plain ASCII ($($f.Name))" (Test-Ascii $f.Name)
    $l = Read-Scenario $f.FullName
    $names = ($l | ForEach-Object { $_.Name }) -join ','
    Assert-Check "Sections: $names" ($names -eq 'SZENE_PLAYERMIN,SZENE_PLAYERMAX,SZENE_GAMEID,SZENE_RANKING,RANDTAB,AUFTRAG4,SZENE,PLAYER4,SHIP4,TIMERS')
    $a = (Get-Section $l 'AUFTRAG4').Data; $s = (Get-Section $l 'SZENE').Data; $p = (Get-Section $l 'PLAYER4').Data; $t = (Get-Section $l 'TIMERS').Data
    $gameId = [BitConverter]::ToInt32((Get-Section $l 'SZENE_GAMEID').Data, 0)
    Assert-Check "AUFTRAG4 length $($a.Length)" ($a.Length -eq 0x8C4)
    $txt = [Text.Encoding]::GetEncoding(1252).GetString($a, 0x68, 0x800).Split([char]0)[0]

    # Mission: decode, check ranges, collect the numbers that the text must mention.
    $bits = [BitConverter]::ToInt32($a, 4); $z = @(); $numbers = @()
    $known = 0x1 -bor 0x2 -bor 0x4 -bor 0x8 -bor 0x20 -bor 0x80 -bor 0x100 -bor 0x200 -bor 0x400 -bor 0x800 -bor 0x1000 -bor 0x2000 -bor 0x4000 -bor 0x8000 -bor 0x10000
    Assert-Check ('Goal bits 0x{0:X} known' -f $bits) (($bits -band (-bnot $known)) -eq 0)
    $last = [int]::MaxValue
    foreach ($k in 0..2) {
        $g = Get-TownGoal $a (0x870 + 12 * $k); $has = ($bits -band (1 -shl $k)) -ne 0
        Assert-Check "Town goal $($k + 1): goal bit and values agree" ($has -eq ($g.Residents -gt 0))
        if (-not $has) { continue }
        Assert-Check "Town goal $($k + 1): stage $($g.Stage), $($g.OfWhich) of $($g.Residents)" ($g.Stage -ge 0 -and $g.Stage -le 4 -and $g.OfWhich -ge 1 -and $g.OfWhich -le $g.Residents)
        Assert-Check "Town goals in descending order ($($g.Residents) after $last)" ($g.Residents -le $last); $last = $g.Residents
        $z += 'town {0} residents ({1} {2})' -f $g.Residents, $g.OfWhich, $stageNames[$g.Stage]; $numbers += $g.Residents, $g.OfWhich
    }
    if ($bits -band 0x8) {
        $g = Get-TownGoal $a 0x8AC
        Assert-Check "All towns at least: stage $($g.Stage), $($g.OfWhich) of $($g.Residents)" ($g.Stage -ge 0 -and $g.Stage -le 4 -and $g.OfWhich -ge 1 -and $g.OfWhich -le $g.Residents)
        $z += 'EVERY town {0} residents ({1} {2})' -f $g.Residents, $g.OfWhich, $stageNames[$g.Stage]; $numbers += $g.Residents, $g.OfWhich
    }
    if ($bits -band 0x20) { $v = [BitConverter]::ToInt32($a, 0x40); Assert-Check "Number of towns $v" ($v -ge 1 -and $v -le 20); $z += '{0} towns' -f $v; $numbers += $v }
    if ($bits -band 0x80) { $v = [BitConverter]::ToInt32($a, 0x44); Assert-Check "Total residents $v" ($v -ge 100); $z += '{0} residents in total' -f $v; $numbers += $v }
    if ($bits -band 0x100) { $v = [BitConverter]::ToInt32($a, 0x4C); Assert-Check "Balance $v" ($v -ge 0 -and $v -le 2000); $z += 'balance >= ' + $v; if ($v) { $numbers += $v } }
    if ($bits -band 0x10000) { $v = [BitConverter]::ToInt32($a, 0x54); Assert-Check "Trade balance $v" ($v -ge 0 -and $v -le 1000); $z += 'trade balance >= ' + $v; if ($v) { $numbers += $v } }
    if ($bits -band 0x200) { $z += '{0} rivals defeated' -f $a[0x2B]; $numbers += $a[0x2B] }
    if ($bits -band 0x400) {
        $def = @(0..6 | Where-Object { $a[0x2C + $_] })
        Assert-Check "Defeat: players $($def -join ',') are computer rivals" ($def.Count -ge 1 -and ($def | Where-Object { $_ -lt 1 -or $_ -gt 3 }).Count -eq 0)
        $z += 'defeat: players ' + ($def -join ',')
    }
    foreach ($m in 0, 1) {
        if ($bits -band (0x4000 -shl $m)) {
            $res = [int]$a[0x20 + 2 * $m]
            Assert-Check ('Monopoly {0}: crop 0x{1:X2}' -f ($m + 1), $res) ($cropNames.ContainsKey($res))
            $z += 'monopoly {0}' -f $cropNames[$res]
        }
    }
    foreach ($w in 0, 1) {
        if ($bits -band (0x1000 -shl $w)) {
            $nr = [int]$a[0x868 + 4 * $w]; $q = [BitConverter]::ToUInt16($a, 0x86A + 4 * $w)
            Assert-Check "Goods $($w + 1): good $nr, $($q / 32) t" ($goodsNames.ContainsKey($nr) -and $q -gt 0 -and $q % 32 -eq 0 -and $q / 32 -le 200)
            $z += '{0} t {1}' -f ($q / 32), $goodsNames[$nr]; $numbers += $q / 32
        }
    }
    if ($bits -band 0x2000) { Assert-Check 'Two different goods' ($a[0x868] -ne $a[0x86C]) }
    if (($bits -band 0xC000) -eq 0xC000) { Assert-Check 'Two different monopolies' ($a[0x20] -ne $a[0x22]) }
    $race = ($bits -band 0x800) -ne 0
    Assert-Check 'Mission has at least one goal' ($z.Count -gt 0)
    Write-Info ('   Mission: {0}{1}' -f ($z -join '; '), $(if ($race) { '  [RACE: also applies to the rivals]' } else { '' }))

    # Text: language, length, encoding, the goal numbers.
    $de = $txt.Contains('Euer Auftrag'); $en = $txt.Contains('Your orders')
    Assert-Check 'Mission text present and at most 2047 bytes' ($txt.Length -gt 50 -and $txt.Length -le 2047)
    Assert-Check 'Text language recognised (exactly one of "Euer Auftrag" / "Your orders")' ($de -xor $en)
    Assert-Check 'Text without CR' (-not $txt.Contains("`r"))
    if ($en) { Assert-Check 'English text in plain ASCII' (Test-Ascii $txt) }
    $missing = @($numbers | Select-Object -Unique | Where-Object { $txt -notmatch ('(?<![0-9])' + $_ + '(?![0-9])') })
    Assert-Check "Goal numbers in the text (missing: $($missing -join ', '))" ($missing.Count -eq 0)

    $missionSlots = 0..3 | ForEach-Object { $p[$_ * 0x430 + 0x0C] }
    Assert-Check "Mission slot of the human player = 0" ($missionSlots[0] -eq 0)
    if ($race) { Assert-Check "Race: rivals on mission 0 ($($missionSlots -join '/'))" (($missionSlots | Where-Object { $_ -ne 0 }).Count -eq 0) }
    else { Assert-Check "Rivals without a mission ($($missionSlots -join '/'))" (($missionSlots[1..3] | Where-Object { $_ -ne 0xFF }).Count -eq 0) }
    $rivalNames = (1..3 | ForEach-Object { [Text.Encoding]::GetEncoding(1252).GetString($p, $_ * 0x430 + 0x3C0, 0x40).Split([char]0)[0] }) -join ' / '
    Write-Info ('   Gold player {0}, rivals {1}; difficulty {2}; pirates {3}; text {4} characters ({5}); rivals {6}' -f [BitConverter]::ToInt32($p, 0), (((1..3) | ForEach-Object { [BitConverter]::ToInt32($p, $_ * 0x430) }) -join '/'), $t[0xA6], $(if ([BitConverter]::ToInt32($t, 0xA8) -band 1) { 'only sighted' } else { 'active' }), $txt.Length, $(if ($de) { 'de' } elseif ($en) { 'en' } else { '?' }), $rivalNames)
    $line = Test-IslandBlock $s 0 500 350 'small'; Write-Info ('   ' + $line)
    if ($s.Length -ge 2360 -and [Text.Encoding]::ASCII.GetString($s, 0x494, 4) -eq 'GROS') {
        $bw = [BitConverter]::ToInt32($s, 0x498); $bh = [BitConverter]::ToInt32($s, 0x49C)
        Assert-Check "big version: length $($s.Length)" ($s.Length -eq 2360)
        $line = Test-IslandBlock $s 0x4A4 $bw $bh "big $bw x $bh"; Write-Info ('   ' + $line)
    }
    else { Assert-Check 'big version present' $false }

    # Ships: names, types, cargo; positions in the water in all map versions (ships are not stretched, islands are).
    $sh = (Get-Section $l 'SHIP4').Data; $conflicts = @(); $shipInfo = @(); $ownCargo = @()
    Assert-Check "SHIP4 length $($sh.Length) = n x 0x1B4" ($sh.Length -gt 0 -and $sh.Length % 0x1B4 -eq 0)
    $ships = for ($i = 0; $i -lt $sh.Length / 0x1B4; $i++) { , @([BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($sh, $i * 0x1B4 + 0x1E)) }
    for ($i = 0; $i -lt $sh.Length / 0x1B4; $i++) {
        $o = $i * 0x1B4; $type = [int][BitConverter]::ToUInt16($sh, $o + 0x48); $owner = $sh[$o + 0x4B]; $st = $ShipTypes[$type]
        $name = [Text.Encoding]::GetEncoding(1252).GetString($sh, $o, 0x18).Split([char]0)[0]
        Assert-Check "Ship $i '$name': known type $type, slot $([BitConverter]::ToUInt16($sh, $o + 0x46))" ($st -and [BitConverter]::ToUInt16($sh, $o + 0x46) -eq $i -and $name.Length -ge 1)
        if (-not $st) { continue }
        Assert-Check "Ship $i '$name': cargo space $([BitConverter]::ToUInt16($sh, $o + 0x3C) / 32) t per hold, $($sh[$o + 0x42]) cannons" ([BitConverter]::ToUInt16($sh, $o + 0x3C) -eq $st[1] * 32 -and $sh[$o + 0x42] -le $st[2])
        $cargo = @()
        for ($k = 0; $k -lt 8; $k++) {
            $q = $o + 0x174 + 8 * $k; $house = [int][BitConverter]::ToUInt16($sh, $q); $amount = [int][BitConverter]::ToUInt16($sh, $q + 2); $flag = [BitConverter]::ToUInt32($sh, $q + 4)
            if (-not $house -and -not $amount -and -not $flag) { continue }
            $knownHouse = $houseNames.ContainsKey($house) -or ($house -ge 9901 -and $house -le 9920)
            Assert-Check "Ship $i '$name' hold $($k): house $house, $amount/32 t, flags $flag" ($knownHouse -and $k -lt $st[0] -and $amount -gt 0 -and $amount % 32 -eq 0 -and $amount / 32 -le $st[1] -and $flag -eq 0)
            if ($owner -eq 0 -and $houseGood.ContainsKey($house)) { $ownCargo += $houseGood[$house] }
            $cargo += '{0} {1} t' -f $(if ($houseNames.ContainsKey($house)) { $houseNames[$house] } else { "house $house" }), ($amount / 32)
        }
        $shipInfo += "{0} '{1}' (player {2}, type {3}{4})" -f $i, $name, $owner, $type, $(if ($cargo) { ': ' + ($cargo -join ', ') } else { '' })
    }
    Assert-Check 'Ship 0 belongs to the human player' ($sh[0x4B] -eq 0)
    # A goods goal must not be fulfilled by unloading the start cargo.
    foreach ($w in 0, 1) { if ($bits -band (0x1000 -shl $w)) { $nr = [int]$a[0x868 + 4 * $w]; Assert-Check "Goal good $nr ($($goodsNames[$nr])) not in the start cargo" ($ownCargo -notcontains $nr) } }
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
    Write-Info ('   Ships: ' + ($shipInfo -join '; ') + $(if ($conflicts.Count -eq 0) { ' - all in the water in every map version' } else { '' }))

    # Random adventures: the game id carries seed and difficulty.
    if ($f.BaseName -match '^(Abenteuer|Adventure) (\d+)$') {
        $seed = [int]$Matches[2]; $lang = if ($Matches[1] -eq 'Abenteuer') { 'de' } else { 'en' }; $diff = ($gameId -shr 20) -band 0xF
        Assert-Check ('Adventure game id 0x{0:X8} = seed {1}, difficulty {2}' -f $gameId, $seed, $diff) (($gameId -band 0xFFC00000) -eq 0x53000000 -and ($gameId -band 0xFFFFF) -eq $seed)
        Assert-Check "Adventure language $lang matches the text" (($lang -eq 'de' -and $de) -or ($lang -eq 'en' -and $en))
        $adventures.Add(@{ File = $f.FullName; Seed = $seed; Language = $lang; Difficulty = @('Easy', 'Average', 'Demanding', 'Hard')[$diff] })
    }
}

# Regenerate every adventure with the same seed, difficulty and language; the files must be byte-identical.
if ($Reproduce -and $adventures.Count) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('anno-adventure-check-' + [guid]::NewGuid().ToString('N'))
    try {
        foreach ($adv in $adventures) {
            $gp = @{}; if ($GamePath) { $gp.GamePath = $GamePath }
            & (Join-Path (Split-Path -Parent $PSScriptRoot) 'src\random-adventure.ps1') -Seed $adv.Seed -Difficulty $adv.Difficulty -Language $adv.Language -OutFolder $tmp @gp | Out-Null
            $new = Join-Path $tmp ([IO.Path]::GetFileName($adv.File))
            $same = (Test-Path -LiteralPath $new) -and ((Get-FileHash -LiteralPath $new).Hash -eq (Get-FileHash -LiteralPath $adv.File).Hash)
            Assert-Check "Reproduced byte for byte: $([IO.Path]::GetFileName($adv.File)) (seed $($adv.Seed), $($adv.Difficulty), $($adv.Language))" $same
        }
        Write-Host "$($adventures.Count) adventure(s) regenerated and compared."
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } }
}
if ($failures) { Write-Host "$files file(s), $failures check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host "All $files scenarios OK." -ForegroundColor Green
