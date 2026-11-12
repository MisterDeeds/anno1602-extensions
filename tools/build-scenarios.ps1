<#
.SYNOPSIS
  Builds the 13 custom scenarios for Anno 1602 History Edition: the campaigns "Die Smaragdinseln"
  (6 chapters) and "Wettlauf" (4 chapters) and 3 single challenges.

.DESCRIPTION
  Based on the endless-game templates Szenes\[[48]]<difficulty><layout>.szs (only read).
  Per scenario: mirrored island layout (so every map looks different and the patcher does not
  recognise it as an endless-game template), own resource amounts, natives, starting gold, difficulty,
  pirates and a mission with text. The maps are built for 500 x 350 and therefore also run without the
  extensions. In addition every scenario carries a big version for 1000 x 700 (up to 50 islands, made
  with the patcher's island planner, with resources growing along and more villages) behind the SZENE
  section (marker 'GROS', see the big campaign maps in anno-patcher.ps1). The patcher uses it when the
  map is at least 1000 x 700 and "more islands" is selected; otherwise the small version applies.

  Output: tools\scenarios\*.szs; with -Install also copied to
  Documents\Anno 1602 History Edition\Own Scenarios (shown in the game's list of custom scenarios).
#>
param([switch]$Install, [string]$GamePath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scenario-lib.ps1')

if (-not $GamePath) {
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallDir; if ($d) { $GamePath = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
    }
}
if (-not $GamePath) { $GamePath = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition' }
$SzenesFolder = Join-Path $GamePath 'Szenes'
$OutputFolder = Join-Path $PSScriptRoot 'scenarios'
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

# Island class sizes (width/height). Get-IslandPlan reads them too, so they carry the patcher's names.
$ClassW = @(30, 40, 50, 70, 100); $ClassH = @(30, 40, 52, 60, 90)
# Island planner from anno-patcher.ps1 (same rules as for the big endless game), loaded through the syntax tree.
$BigWidth = 1000; $BigHeight = 700
$patcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'anno-patcher.ps1'), [ref]$null, [ref]$null)
foreach ($stmt in $patcherAst.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function Get-IslandPlan\b') -or $txt -match '^\$(IslandMax|IslandDensity)\b') { . ([scriptblock]::Create($txt)) }
}
$ResourceAmountOffsets = @(0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE, 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE, 0x106, 0x10E, 0x116)
# SZENE: resource entries of 8 bytes from +0x94 (house no. = id - 20000, amount = number of islands).
$ResourceEntry = @{ OreSmall = 0x94; OreLarge = 0x9C; Gold = 0xA4; Treasure = 0x114 }
$PlantHouse = @{ Cotton = 1332; Tobacco = 1336; Cocoa = 1338; Sugar = 1340; Spices = 1342; Wine = 1344 }
# Monopoly resources (fertility, FUN_1400ae010): 0x2D grain, 0x2E tobacco, 0x2F spices, 0x30 sugar,
# 0x31 cotton, 0x32 wine, 0x33 cocoa. Goods (storage): 12 muskets, 13 cannons, 16 spices, 21 jewelry, 22 tools.

function Get-IslandList([byte[]]$scene) {
    $n = [BitConverter]::ToInt32($scene, 0x64)
    for ($i = 0; $i -lt $n; $i++) {
        $o = 0x174 + 16 * $i
        @{ Climate = $scene[$o]; Class = $scene[$o + 1]; X = [BitConverter]::ToInt32($scene, $o + 8); Y = [BitConverter]::ToInt32($scene, $o + 12); Village = $false; File = $null }
    }
}
# Mirror at the map centre; mirroring in y swaps north and south climate (so the position stays consistent).
function Get-MirroredIslands($islands, [bool]$x, [bool]$y) {
    foreach ($e in $islands) {
        $n = $e.Clone()
        if ($x) { $n.X = 500 - $e.X - $ClassW[$e.Class] }
        if ($y) { $n.Y = 350 - $e.Y - $ClassH[$e.Class]; if ($e.Climate -lt 2) { $n.Climate = 1 - $e.Climate } }
        $n
    }
}
function Assert-Map($islands, [string]$name, [int]$width = 500, [int]$height = 350) {
    for ($i = 0; $i -lt $islands.Count; $i++) {
        $a = $islands[$i]; $aw = $ClassW[$a.Class]; $ah = $ClassH[$a.Class]
        if ($a.X -lt 0 -or $a.Y -lt 0 -or $a.X + $aw -gt $width -or $a.Y + $ah -gt $height) { throw "$($name): island $i is outside the map." }
        for ($j = $i + 1; $j -lt $islands.Count; $j++) {
            $b = $islands[$j]
            if ($a.X -lt $b.X + $ClassW[$b.Class] -and $b.X -lt $a.X + $aw -and $a.Y -lt $b.Y + $ClassH[$b.Class] -and $b.Y -lt $a.Y + $ah) { throw "$($name): islands $i and $j overlap." }
        }
    }
}
# Enlarge islands where the next bigger class stays clear (6 fields apart).
function Expand-Islands($islands, [int]$count) {
    $n = 0
    for ($i = 0; $i -lt $islands.Count -and $n -lt $count; $i++) {
        $e = $islands[$i]; if ($e.Class -ge 3) { continue }
        $k = $e.Class + 1; $free = ($e.X + $ClassW[$k] -le 494 -and $e.Y + $ClassH[$k] -le 344)
        for ($j = 0; $j -lt $islands.Count -and $free; $j++) {
            if ($j -eq $i) { continue }; $b = $islands[$j]
            if ($e.X -lt $b.X + $ClassW[$b.Class] + 6 -and $b.X -lt $e.X + $ClassW[$k] + 6 -and $e.Y -lt $b.Y + $ClassH[$b.Class] + 6 -and $b.Y -lt $e.Y + $ClassH[$k] + 6) { $free = $false }
        }
        if ($free) { $e.Class = $k; $n++ }
    }
}
# Starting ships: the ship positions (SHIP4 +0x1C/+0x1E) are not stretched, the islands are.
# Wanted: a water point that is at least $distance fields away from every island in all map versions:
# small map at 500/750/1000/2000 width (factor 1, 1.5, 2, 4) and big version at
# 1000/2000 (factor 1, 2) - as close as possible to the template's starting point.
function Get-IslandRects([byte[]]$s, [int]$o0, [double]$f) {
    $n = [BitConverter]::ToInt32($s, $o0 + 0x64)
    for ($i = 0; $i -lt $n; $i++) {
        $o = $o0 + 0x174 + 16 * $i; $c = $s[$o + 1]
        @{ X = [math]::Truncate([BitConverter]::ToInt32($s, $o + 8) * $f); Y = [math]::Truncate([BitConverter]::ToInt32($s, $o + 12) * $f); W = $ClassW[$c]; H = $ClassH[$c] }
    }
}
function Find-FreeStartPoint([byte[]]$small, [byte[]]$big, [int]$x0, [int]$y0, [int]$distance = 14) {
    $rects = @()
    foreach ($f in 1, 1.5, 2, 4) { $rects += @(Get-IslandRects $small 0 $f) }
    foreach ($f in 1, 2) { $rects += @(Get-IslandRects $big 0 $f) }
    $best = $null; $bestD = [double]::MaxValue
    for ($y = 20; $y -le 330; $y += 2) {
        for ($x = 20; $x -le 480; $x += 2) {
            $d = [math]::Sqrt(($x - $x0) * ($x - $x0) + ($y - $y0) * ($y - $y0)); if ($d -ge $bestD) { continue }
            $free = $true
            foreach ($r in $rects) { if ($x -gt $r.X - $distance -and $x -lt $r.X + $r.W + $distance -and $y -gt $r.Y - $distance -and $y -lt $r.Y + $r.H + $distance) { $free = $false; break } }
            if ($free) { $best = @($x, $y); $bestD = $d }
        }
    }
    if (-not $best) { throw 'No free starting point found for the ships.' }
    , $best
}
function Set-Amount([byte[]]$s, [int]$house, [int]$amount) {
    for ($o = 0x94; $o -le 0x114; $o += 8) { if ([BitConverter]::ToUInt16($s, $o) -eq $house) { Set-U16 $s ($o + 2) $amount } }
}

function Build-Scenario($sc) {
    $template = Read-Scenario (Join-Path $SzenesFolder ('[[48]]{0}{1}.szs' -f $sc.Difficulty, $sc.Layout))
    $scene = [byte[]](Get-Section $template 'SZENE').Data.Clone()
    $islands = @(Get-MirroredIslands @(Get-IslandList $scene) $sc.MirrorX $sc.MirrorY)
    if ($sc.Enlarge) { Expand-Islands $islands $sc.Enlarge }
    if ($sc.Climate -ne $null) { foreach ($e in $islands) { $e.Climate = $sc.Climate } }
    Assert-Map $islands $sc.File
    Set-Islands $scene $islands
    Set-I32 $scene 0x40 $sc.VillagesNorth; Set-I32 $scene 0x44 $sc.VillagesSouth
    if ($sc.Amounts) { foreach ($m in $sc.Amounts.GetEnumerator()) { if ($ResourceEntry.ContainsKey($m.Key)) { Set-U16 $scene ($ResourceEntry[$m.Key] + 2) $m.Value } else { Set-Amount $scene $PlantHouse[$m.Key] $m.Value } } }

    # Big version for 1000 x 700: island planner, resources scaled with the island count, more villages.
    $big = [byte[]]$scene.Clone()
    $small16 = @(for ($i = 0; $i -lt $islands.Count; $i++) { , [byte[]]$scene[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
    $plan = Get-IslandPlan $small16 $BigWidth $BigHeight $false $sc.BigIslandSize
    [Array]::Clear($big, 0x174, 50 * 16)
    for ($i = 0; $i -lt $plan.Count; $i++) { [Array]::Copy($plan[$i], 0, $big, 0x174 + 16 * $i, 16) }
    Set-I32 $big 0x64 $plan.Count
    foreach ($o in $ResourceAmountOffsets) {
        $m = [BitConverter]::ToUInt16($big, $o)
        if ($m) { Set-U16 $big $o ([math]::Min($plan.Count, [int][math]::Round($m * $plan.Count / $islands.Count))) }
    }
    $bv = if ($sc.BigVillages) { $sc.BigVillages } else { 5 }
    Set-I32 $big 0x40 $bv; Set-I32 $big 0x44 $bv
    if ($sc.BigAmounts) { foreach ($m in $sc.BigAmounts.GetEnumerator()) { if ($ResourceEntry.ContainsKey($m.Key)) { Set-U16 $big ($ResourceEntry[$m.Key] + 2) $m.Value } else { Set-Amount $big $PlantHouse[$m.Key] $m.Value } } }
    Assert-Map @(Get-IslandList $big) ($sc.File + ' (big)') $BigWidth $BigHeight
    $marker = New-Object byte[] 16
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('GROS'), $marker, 4); Set-I32 $marker 4 $BigWidth; Set-I32 $marker 8 $BigHeight; Set-I32 $marker 12 1
    $sceneData = [byte[]]($scene + $marker + $big)

    # Put the starting ships on a free water point (distances between them as in the template).
    $ships = [byte[]](Get-Section $template 'SHIP4').Data.Clone()
    $sx0 = [BitConverter]::ToInt16($ships, 0x1C); $sy0 = [BitConverter]::ToInt16($ships, 0x1E)
    $start = Find-FreeStartPoint $scene $big $sx0 $sy0
    for ($i = 0; $i -lt $ships.Length / 0x1B4; $i++) {
        $o = $i * 0x1B4
        $dx = [BitConverter]::ToInt16($ships, $o + 0x1C) - $sx0; $dy = [BitConverter]::ToInt16($ships, $o + 0x1E) - $sy0
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $dx)), 0, $ships, $o + 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $dy)), 0, $ships, $o + 0x1E, 2)
    }
    # Extra starting ships for the human player: copy of his ship (entry 0) with a new slot
    # (+0x46), figure type (+0x48: 21/23 small/large trading ship, 25/27 small/large warship),
    # cargo space (+0x3C, x 32) and the full number of cannons (+0x42), without cargo, next to the starting point.
    $FleetValues = @{ 21 = @(1600, 6); 23 = @(2560, 10); 25 = @(2080, 8); 27 = @(3840, 14) }
    $offsets = @(@(7, 4), @(8, -3), @(-9, 0))
    $n = 0
    foreach ($fs in @($sc.Fleet | Where-Object { $_ })) {
        if ($n -ge $offsets.Count) { throw 'At most 3 extra starting ships.' }
        $r = [byte[]]$ships[0..(0x1B4 - 1)]
        [Array]::Clear($r, 0, 0x18); $nb = [Text.Encoding]::GetEncoding(1252).GetBytes($fs.Name); [Array]::Copy($nb, $r, [math]::Min(0x17, $nb.Length))
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $offsets[$n][0])), 0, $r, 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $offsets[$n][1])), 0, $r, 0x1E, 2)
        Set-U16 $r 0x3C $FleetValues[$fs.Type][0]; $r[0x42] = [byte]$FleetValues[$fs.Type][1]
        Set-U16 $r 0x46 ($ships.Length / 0x1B4); Set-U16 $r 0x48 $fs.Type
        [Array]::Clear($r, 0x174, 0x1B4 - 0x174)
        $ships = [byte[]]($ships + $r); $n++
    }

    $players = [byte[]](Get-Section $template 'PLAYER4').Data.Clone()
    for ($p = 0; $p -lt 7; $p++) { $players[$p * 0x430 + 0x0C] = 0xFF }
    $players[0x0C] = 0                                                   # human player: mission 0
    # Race: the three computer rivals get the same mission; goal bit 0x800 lets them win.
    # If a rival fulfils it first, the game ends with his victory (FUN_1400b0000, message 0x3E -> 0x53).
    if ($sc.Race) { foreach ($p in 1..3) { $players[$p * 0x430 + 0x0C] = 0 } }
    Set-I32 $players 0 $sc.Gold
    foreach ($p in 1..3) { Set-I32 $players ($p * 0x430) $sc.RivalGold }

    $timers = [byte[]](Get-Section $template 'TIMERS').Data.Clone()
    $flags = [BitConverter]::ToInt32($timers, 0xA8)
    $flags = if ($sc.Pirates) { $flags -band (-bnot 1) } else { $flags -bor 1 }   # bit 0: pirates only sighted
    Set-I32 $timers 0xA8 $flags
    # Rival strength without another template (same map): TIMERS +0xA6 = difficulty 0-3 (game: 0x1405ec1c0).
    if ($sc.ContainsKey('AI')) { $timers[0xA6] = [byte]$sc.AI }

    $mission = $sc.Mission.Clone(); $mission.Slot = 0; $mission.Text = $sc.Text
    if ($sc.Race) { $mission.AlsoAI = $true }
    $list = New-Object System.Collections.Generic.List[object]
    $list.Add(@{ Name = 'SZENE_PLAYERMIN'; Data = [BitConverter]::GetBytes([int32]1) })
    $list.Add(@{ Name = 'SZENE_PLAYERMAX'; Data = [BitConverter]::GetBytes([int32]0) })
    $list.Add(@{ Name = 'SZENE_GAMEID'; Data = [BitConverter]::GetBytes([int32](0x53D00000 + $sc.Number)) })
    $list.Add(@{ Name = 'SZENE_RANKING'; Data = [BitConverter]::GetBytes([int32]2) })
    foreach ($a in $template) {
        switch ($a.Name) {
            'RANDTAB' { $list.Add($a) }
            'SZENE' { $list.Add(@{ Name = 'AUFTRAG4'; Data = (New-Mission $mission) }); $list.Add(@{ Name = 'SZENE'; Data = $sceneData }) }
            'PLAYER4' { $list.Add(@{ Name = 'PLAYER4'; Data = $players }) }
            'SHIP4' { $list.Add(@{ Name = 'SHIP4'; Data = $ships }) }
            'TIMERS' { $list.Add(@{ Name = 'TIMERS'; Data = $timers }) }
        }
    }
    $path = Join-Path $OutputFolder ($sc.File + '.szs')
    Write-Scenario $path $list
    '{0,-36} {1,2} islands (big {2}, {3}), start {9},{10} (template {11},{12}), difficulty {4}, pirates {5}, gold {6}/{7}, text {8}' -f $sc.File, $islands.Count, $plan.Count, $sc.BigIslandSize, $(if ($sc.ContainsKey('AI')) { '{0} (rivals {1})' -f $sc.Difficulty, $sc.AI } else { $sc.Difficulty }), $(if ($sc.Pirates) { 'active' } else { 'sighted' }), $sc.Gold, $sc.RivalGold, $sc.Text.Length, $start[0], $start[1], $sx0, $sy0
}

$Scenarios = @(
    @{ Number = 1; BigIslandSize = 'Normal'; File = 'Smaragdinseln 1 - Landung'; Difficulty = 0; Layout = 1; MirrorX = $true; MirrorY = $false
        Gold = 30000; RivalGold = 15000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 250; Stage = 1; OfWhich = 150 }); Balance = 0 }
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
    @{ Number = 2; BigIslandSize = 'Normal'; BigAmounts = @{ Spices = 3 }; File = 'Smaragdinseln 2 - Gewuerzfieber'; Difficulty = 1; Layout = 0; MirrorX = $false; MirrorY = $true
        Gold = 25000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Amounts = @{ Spices = 2; Tobacco = 4; Cocoa = 4 }   # monopoly = all spice islands (the game counts them at start, FUN_1400ceea0)
        Mission = @{ Monopoly1 = @{ Resource = 0x2F; Islands = 1 }; Towns = @(@{ Residents = 500; Stage = 2; OfWhich = 250 }) }
        Text = @'
DIE SMARAGDINSELN - Kapitel 2: Gewürzfieber

In den Häfen der Alten Welt zahlt man für ein Fass Gewürze mehr als für ein ganzes Schiff. Auf diesem Archipel gibt es nur wenige Inseln, auf denen Gewürze gedeihen - und Eure Rivalen wissen das ebenso gut wie Ihr.

Euer Auftrag:
- Sichert Euch das Gewürzmonopol: Gründet auf JEDER Insel, auf der Gewürze wachsen, eine eigene Siedlung und duldet dort keine fremde. Es sind nur drei oder vier.
- Baut eine Stadt mit mindestens 500 Einwohnern, davon 250 Bürger oder höher.

Rat des Steuermanns: Erkundet früh mit dem Schiff, welche Inseln Gewürze tragen (Fruchtbarkeit im Inselinfo). Wer zu spät kommt, muss den Rivalen verdrängen.
'@
    }
    @{ Number = 3; BigIslandSize = 'Large'; File = 'Smaragdinseln 3 - Zwei Kolonien'; Difficulty = 1; Layout = 2; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ Towns = @(@{ Residents = 800; Stage = 3; OfWhich = 300 }, @{ Residents = 500; Stage = 2; OfWhich = 250 }); Balance = 300 }
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
    @{ Number = 4; BigIslandSize = 'Large'; Fleet = @(@{ Type = 25; Name = 'Wehrhaft' }); File = 'Smaragdinseln 4 - Schwarze Segel'; Difficulty = 2; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 30000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 10 }
        Mission = @{ Towns = @(@{ Residents = 1000; Stage = 3; OfWhich = 500 }); Goods1 = @{ Good = 13; Tons = 20 }; Goods2 = @{ Good = 12; Tons = 40 } }
        Text = @'
DIE SMARAGDINSELN - Kapitel 4: Schwarze Segel

Schwarze Segel am Horizont! Ein Piratenkapitän hat sich in den Riffen eingenistet und kapert jedes Schiff, das schwach bewaffnet ist. Die Kompanie schickt keine Flotte - Ihr müsst Euch selbst wappnen.

Euer Auftrag:
- Eine Stadt mit mindestens 1000 Einwohnern, davon 500 Kaufleute oder höher.
- Legt ein Waffenlager an: mindestens 20 Tonnen Kanonen und 40 Tonnen Musketen in Euren Kontoren.

Rat des Steuermanns: Eisen braucht Erz und Holzkohle. Sichert Euch eine Erzinsel, bevor die Rivalen es tun, und lasst Eure Handelsschiffe nicht unbegleitet fahren.
'@
    }
    @{ Number = 5; BigIslandSize = 'Normal'; Fleet = @(@{ Type = 27; Name = 'Königsadler' }); File = 'Smaragdinseln 5 - Der Eroberer'; Difficulty = 2; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 50000; RivalGold = 40000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        Mission = @{ Defeat = @(1, 2, 3) }
        Text = @'
DIE SMARAGDINSELN - Kapitel 5: Der Eroberer

Die Zeit der Verhandlungen ist vorbei. Die drei Rivalen haben sich gegen Euch verbündet, Eure Händler werden abgewiesen, Eure Schiffe beschossen. Die Kompanie erteilt Euch freie Hand.

Euer Auftrag:
- Besiegt alle drei Rivalen. Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.

Rat des Steuermanns: Ein Krieg wird mit Gold gewonnen. Baut zuerst eine starke Wirtschaft, dann Burgen, Kasernen und eine Flotte. Nehmt Euch die Rivalen einzeln vor.
'@
    }
    @{ Number = 6; BigIslandSize = 'Huge'; BigVillages = 6; Fleet = @(@{ Type = 23; Name = 'Fortuna' }); File = 'Smaragdinseln 6 - Krone der Inseln'; Difficulty = 3; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 4
        Gold = 40000; RivalGold = 50000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3; Treasure = 10 }
        Mission = @{ Towns = @(@{ Residents = 2500; Stage = 4; OfWhich = 1200 }, @{ Residents = 1500; Stage = 3; OfWhich = 800 }, @{ Residents = 800; Stage = 2; OfWhich = 400 }); Balance = 1000 }
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

    # --- Campaign 2: Wettlauf der Häuser (the rivals have the same mission) ------------------------
    # Rival strength (AI) from a measurement on 2026-11-12: difficulty 0 needed ~10.7 h for 300/150, difficulty 2 ~3.7 h.
    @{ Number = 11; BigIslandSize = 'Normal'; File = 'Wettlauf 1 - Erster Hafen'; Difficulty = 0; AI = 1; Layout = 0; MirrorX = $true; MirrorY = $true; Race = $true
        Gold = 30000; RivalGold = 20000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 300; Stage = 1; OfWhich = 150 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 1: Erster Hafen

Der König hat vier Handelshäuser über den Ozean geschickt und ein Versprechen gegeben: Wer als Erster eine blühende Hafenstadt gründet, erhält das Handelsprivileg für die ganze Küste. Eure drei Rivalen verfolgen dasselbe Ziel - und sie warten nicht auf Euch.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 300 Einwohnern, davon 150 Siedler oder höher.

Erreicht ein Rivale das Ziel vor Euch, ist das Rennen verloren.

Rat des Steuermanns: Zeit ist alles. Baut zügig, aber lasst Eure Kasse nicht leerlaufen.
'@
    }
    # Second town 200/100: the rivals' second towns stall at 144 settlers and 187-290 residents (measurements);
    # 300/150 would be out of their reach, 250 only just (Wettlauf 2 with 250: the rival won after 9.6 h at 251).
    @{ Number = 12; BigIslandSize = 'Large'; File = 'Wettlauf 2 - Buergerstolz'; Difficulty = 1; AI = 2; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 2; Race = $true
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 700; Stage = 2; OfWhich = 350 }, @{ Residents = 200; Stage = 1; OfWhich = 100 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz

Das Handelsprivileg war nur der Anfang. Nun sucht der König einen Statthalter für die neuen Kolonien - und wieder sollen die Häuser gegeneinander antreten. Der Preis: zwei Städte, die der Krone Ehre machen.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 700 Einwohnern, davon 350 Bürger oder höher,
- und eine zweite Stadt mit mindestens 200 Einwohnern, davon 100 Siedler oder höher.

Rat des Steuermanns: Eine zweite Insel mit anderem Klima liefert, was Eure Bürger verlangen. Wer sie zuerst besetzt, hat die Nase vorn.
'@
    }
    @{ Number = 13; BigIslandSize = 'Large'; File = 'Wettlauf 3 - Kaufmannsrepublik'; Difficulty = 2; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 3; Race = $true
        Gold = 35000; RivalGold = 35000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ Towns = @(@{ Residents = 1000; Stage = 3; OfWhich = 400 }) }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 3: Kaufmannsrepublik

Die Kaufleute der Alten Welt wollen eine freie Handelsstadt jenseits des Meeres. Sie werden das Haus unterstützen, das ihnen zuerst eine würdige Heimat baut. Doch Piraten lauern in diesen Gewässern, und die Rivalen schrecken vor nichts zurück.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1000 Einwohnern, davon 400 Kaufleute oder höher.

Rat des Steuermanns: Kaufleute verlangen Tuch, Alkohol und Tabakwaren. Sichert Euch die Rohstoffe, bevor es die anderen tun.
'@
    }
    @{ Number = 14; BigIslandSize = 'Huge'; BigVillages = 6; File = 'Wettlauf 4 - Die Krone'; Difficulty = 3; Layout = 1; MirrorX = $true; MirrorY = $false; Enlarge = 4; Race = $true
        Gold = 40000; RivalGold = 45000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        # 1500 instead of 2000: the rivals' capital stalls at ~1500-1610 residents (measurement); with 1500/600 + balance 500
        # the best rival wins after about 20 game hours - a real race for the finale.
        Mission = @{ Towns = @(@{ Residents = 1500; Stage = 4; OfWhich = 600 }); Balance = 500 }
        Text = @'
WETTLAUF DER HÄUSER - Kapitel 4: Die Krone

Das letzte Rennen. Der König wird alt, und er hat verkündet, wer die prächtigste Residenz der Neuen Welt errichtet, soll sein Vizekönig werden. Alle vier Häuser setzen nun alles auf eine Karte.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1500 Einwohnern, davon 600 Aristokraten,
- und eine Bilanz von mindestens +500 Talern.

Rat des Steuermanns: Ein Rivale, der keine Stadt mehr hat, kann auch nicht gewinnen ...
'@
    }

    # --- Challenges (single scenarios with special goals) -----------------------------------------
    @{ Number = 21; BigIslandSize = 'Normal'; File = 'Herausforderung - Inselreich'; Difficulty = 1; Layout = 1; MirrorX = $false; MirrorY = $true
        Gold = 40000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ TownCount = 8; TotalResidents = 3000 }
        Text = @'
HERAUSFORDERUNG: Inselreich

Ein Reich, über dem die Sonne nie untergeht, besteht nicht aus einer einzigen Stadt. Die Krone will Flaggen auf möglichst vielen Inseln sehen.

Euer Auftrag:
- Gründet mindestens 8 eigene Siedlungen (je ein Kontor) auf den Inseln dieses Archipels.
- Alle Eure Siedlungen zusammen sollen mindestens 3000 Einwohner haben.

Rat des Steuermanns: Kleine Inseln sind billig zu besiedeln. Ein Kontor und ein paar Häuser zählen schon als Siedlung - aber die Einwohner wollen versorgt sein.
'@
    }
    @{ Number = 22; BigIslandSize = 'Large'; File = 'Herausforderung - Handelsimperium'; Difficulty = 2; Layout = 0; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Amounts = @{ Gold = 3 }
        Mission = @{ Goods1 = @{ Good = 21; Tons = 50 }; Goods2 = @{ Good = 20; Tons = 80 }; TradeBalance = 300 }
        Text = @'
HERAUSFORDERUNG: Handelsimperium

Nicht Kanonen, sondern volle Lagerhäuser regieren die Welt. Die Kaufleute von Antwerpen wollen sehen, wer die reichsten Speicher der Neuen Welt füllt.

Euer Auftrag:
- Lagert mindestens 50 Tonnen Schmuck und 80 Tonnen Kleidung in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +300 Talern: Eure Verkäufe an Händler und Rivalen müssen Eure Einkäufe deutlich übersteigen.

Rat des Steuermanns: Schmuck braucht Gold aus den Bergen, Kleidung braucht Stoffe aus Wolle oder Baumwolle. Stellt in den Kontoren ein, was Ihr verkaufen wollt, und baut Lager aus, damit nichts verloren geht.
'@
    }
    @{ Number = 23; BigIslandSize = 'Normal'; Fleet = @(@{ Type = 25; Name = 'Goldwächter' }); File = 'Herausforderung - Goldrausch'; Difficulty = 2; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 35000; RivalGold = 35000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ Gold = 4; OreSmall = 6; OreLarge = 9; Treasure = 12 }
        Mission = @{ Goods1 = @{ Good = 3; Tons = 60 }; Goods2 = @{ Good = 21; Tons = 40 } }
        Text = @'
HERAUSFORDERUNG: Goldrausch

In den Bergen dieser Inseln soll es Gold geben - genug, um eine Flotte zu kaufen. Die Gerüchte haben nicht nur Euch angelockt: Rivalen und Piraten sind schon unterwegs.

Euer Auftrag:
- Lagert mindestens 60 Tonnen Gold und 40 Tonnen Schmuck in Euren Kontoren.

Rat des Steuermanns: Goldminen gibt es nur an wenigen Bergen. Wer sie zuerst besetzt und gut schützt, gewinnt. Und lasst Eure Goldschiffe nie allein fahren.
'@
    }
)

foreach ($sc in $Scenarios) { Build-Scenario $sc }

if ($Install) {
    $own = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
    New-Item -ItemType Directory -Force -Path $own | Out-Null
    Get-ChildItem $OutputFolder -Filter '*.szs' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $own -Force }
    "Installed to: $own"
}
