<#
.SYNOPSIS
  Builds the 49 custom scenarios for Anno 1602 History Edition: the campaigns "Die Smaragdinseln"
  (The Emerald Isles, 6 chapters), "Wettlauf der Haeuser" (Race of the Houses, 4 chapters),
  "Die Sturmsee" (The Storm Sea, 6 chapters), "Die Neue Welt" (The New World, 6 chapters),
  "Die Handelsliga" (The Trade League, 6 chapters) and "Das Weltreich" (The World Empire, 6 chapters,
  made for the giant world 2000 x 1400) and 15 single challenges (two of them with a time limit that
  needs the extensions, two for the giant world) - in German or English.

.DESCRIPTION
  Based on the endless-game templates Szenes\[[48]]<difficulty><layout>.szs (only read).
  Per scenario: mirrored island layout (so every map looks different and the patcher does not
  recognise it as an endless-game template), own resource amounts, natives, starting gold, difficulty,
  pirates and a mission with text. The maps are built for 500 x 350 and therefore also run without the
  extensions. In addition every scenario carries a big version for 1000 x 700 (up to 50 islands, made
  with the patcher's island planner, with resources growing along and more villages) behind the SZENE
  section (marker 'GROS', see the big campaign maps in anno-patcher.ps1). The patcher uses it when the
  map is at least 1000 x 700 and "more islands" is selected; otherwise the small version applies.
  Scenarios with the key Giant (since 3.1) carry a third version for the giant world 2000 x 1400 behind
  that: the 50 islands grouped into five realms with open sea between them (Get-GiantPlan); the patcher
  takes the biggest version that fits the map.

  -Language de|en: language of the file names (= titles in the game), mission texts and ship names.
  Default: German on a German Windows, English otherwise; override with $env:ANNO_EXTENSIONS_LANG.
  The German files of the first 13 scenarios are byte-identical to the builds before the English texts.

  Output: src\scenarios\*.szs (or -OutFolder); with -Install the files of this run are also copied to
  Documents\Anno 1602 History Edition\Own Scenarios (shown in the game's list of custom scenarios).

  Library use: dot-source with -Library (plain dot-sourcing works too) to get Build-Scenario and the
  helpers without building anything; src\random-adventure.ps1 does this. Pass the same -GamePath,
  -Language and -OutFolder, because the parameters land in the caller's scope.

  Scenario keys (Number, Title, Text, Difficulty, Layout, Mission required):
    Number           SZENE_GAMEID = 0x53D00000 + Number (GameId overrides it)
    Title, Text      string or @{ de = ...; en = ... }; Title = file name = name in the game's list
    Difficulty       template [[48]]<Difficulty><Layout>.szs (0 Einfach ... 3 Schwer); AI = rival strength
                     0-3 (TIMERS +0xA6, the game's difficulty variable) without changing the template
    MirrorX/MirrorY  mirror the template layout; Enlarge = n islands one class bigger; Climate = 0/1 all
    MaxClass         shrink every island to at most this class (0 lit ... 4 lar)
    AddIslands       fill the small map with more islands up to this count (AddClasses, default 0, 1)
    Continents       @{ Lar = n; Big = n; Small = n }: few huge islands built from the template positions
    BigIslandSize    Normal/Large/Huge for the big version; BigVillages (default 5), BigAmounts
    Giant            @{ Villages = n (or @(north, south), default 7); Amounts = @{...}; Islands = per realm
                     @(lar, big, med, mit) (default $GiantDefault); Seed = n }: the giant world version
    Amounts          OreSmall, OreLarge, Gold, Treasure (islands) or a crop (Cotton, Tobacco, Cocoa,
                     Sugar, Spices, Wine: fertility islands)
    VillagesNorth/VillagesSouth, Gold, RivalGold, Pirates ($true = they attack), Race ($true)
    Rivals           @(@{ Player = 1-3; Gold = n; Name = player name; Ship = name of its start ship })
    ShipName         name of the human's start ship
    Cargo            cargo of the human's start ship, replaces the template's 50 t tools, 30 t wood,
                     10 t food: @(@{ Good = 'Tools'; Tons = 20 }, ...), goods see $CargoHouse
    Fleet            extra ships: @(@{ Type = 23/25/27; Name = ...; Cargo = @(...) }), at most 3
    Mission          see New-Mission in scenario-lib.ps1
  Crops by climate (fertility, FUN_1400d0ce0): Tobacco, Sugar and Wine grow only on northern islands (climate 0;
  sugar and wine never on the same island), Spices, Cotton and Cocoa only on southern ones (climate 1).
    TimeLimitHours   mission time limit in hours of the game's own clock display (1-50, whole or half hours; also
                     allowed inside Mission). The game never loads its time limit (0x1405ec1a8, clock units) from a
                     scenario or savegame, so it goes to AUFTRAG4 +0x58 (copied to mission +0x20 and kept in
                     savegames) and the patcher's TIMERS hook copies it to 0x1405ec1a8 at every load. Without the
                     extensions there is no limit, so the mission text must say so (docs\FINDINGS.md,
                     "Mission time limits").
#>
param([switch]$Install, [string]$GamePath, [ValidateSet('', 'de', 'en')][string]$Language = '', [string]$OutFolder, [switch]$Library)
$ErrorActionPreference = 'Stop'
$BuildLibraryOnly = $Library -or $MyInvocation.InvocationName -eq '.'
. (Join-Path $PSScriptRoot 'scenario-lib.ps1')

if (-not $Language) {
    $Language = if ($env:ANNO_EXTENSIONS_LANG) { if ($env:ANNO_EXTENSIONS_LANG -eq 'de') { 'de' } else { 'en' } } elseif ((Get-UICulture).TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' }
}
if (-not $GamePath) {
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallDir; if ($d) { $GamePath = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
    }
}
if (-not $GamePath) { $GamePath = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition' }
$SzenesFolder = Join-Path $GamePath 'Szenes'
$OutputFolder = if ($OutFolder) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFolder) } else { Join-Path $PSScriptRoot 'scenarios' }

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
# 0x31 cotton, 0x32 wine, 0x33 cocoa. Goods (storage, the game's goods list from NOWARE = 0): 3 gold,
# 12 muskets, 13 cannons, 15 tobacco goods, 16 spices, 17 cocoa, 18 liquor, 19 cloth, 20 clothes,
# 21 jewelry, 22 tools, 23 wood, 24 bricks.

# Text in the build language: a plain string or @{ de = ...; en = ... }.
function Get-Localized($value) {
    if ($value -is [System.Collections.IDictionary]) {
        if (-not $value.Contains($Language)) { throw "Text without language '$Language': $($value.Values | Select-Object -First 1)" }
        return $value[$Language]
    }
    $value
}

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
# True if a w x h island at x/y keeps $gap fields to every island of the list and the map edge (8).
function Test-IslandFree($list, [int]$x, [int]$y, [int]$w, [int]$h, [int]$gap) {
    if ($x -lt 8 -or $y -lt 8 -or $x + $w -gt 492 -or $y + $h -gt 342) { return $false }
    foreach ($p in $list) {
        if ($x -lt $p.X + $ClassW[$p.Class] + $gap -and $p.X -lt $x + $w + $gap -and $y -lt $p.Y + $ClassH[$p.Class] + $gap -and $p.Y -lt $y + $h + $gap) { return $false }
    }
    $true
}
# Archipelago: more islands of the given classes in the gaps (14 fields apart, deterministic: LCG from $seed).
function Add-Islands($islands, [int]$target, $classes, [int]$seed) {
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($e in $islands) { $list.Add($e) }
    $rng = [long](([long]$seed * 7919 + 17) % 2147483648); $k = 0; $failures = 0
    while ($list.Count -lt [math]::Min(50, $target) -and $failures -lt 40) {
        $c = [int]$classes[$k % $classes.Count]; $k++
        $w = $ClassW[$c]; $h = $ClassH[$c]; $placed = $false
        for ($t = 0; $t -lt 800 -and -not $placed; $t++) {
            $rng = ($rng * 1103515245 + 12345) % 2147483648; $x = 8 + [int](($rng -shr 16) % (484 - $w))
            $rng = ($rng * 1103515245 + 12345) % 2147483648; $y = 8 + [int](($rng -shr 16) % (334 - $h))
            if (Test-IslandFree $list $x $y $w $h 14) { $list.Add(@{ Climate = 2; Class = $c; X = $x; Y = $y; Village = $false; File = $null }); $placed = $true }
        }
        if ($placed) { $failures = 0 } else { $failures++ }
    }
    $list.ToArray()
}
# Continents: the template islands (largest first) become 'lar' (100 x 90) or 'big' (70 x 60) around
# their centre where that keeps 14 fields to the islands placed so far; then up to $small of the
# remaining small islands (class 0/1) stay. At most 10 'lar' per map (island files, see FINDINGS).
function Get-ContinentIslands($islands, [int]$lar, [int]$big, [int]$small) {
    $order = @(0..($islands.Count - 1) | Sort-Object { - $islands[$_].Class }, { $_ })
    $placed = New-Object System.Collections.Generic.List[object]; $used = @{}
    foreach ($want in @(@(4) * [math]::Min(10, $lar) + @(3) * $big)) {
        $w = $ClassW[$want]; $h = $ClassH[$want]
        foreach ($i in $order) {
            if ($used.ContainsKey($i)) { continue }
            $e = $islands[$i]
            $x = [int][math]::Floor($e.X + $ClassW[$e.Class] / 2 - $w / 2); $y = [int][math]::Floor($e.Y + $ClassH[$e.Class] / 2 - $h / 2)
            $x = [math]::Min([math]::Max(8, $x), 492 - $w); $y = [math]::Min([math]::Max(8, $y), 342 - $h)
            if (Test-IslandFree $placed $x $y $w $h 14) {
                $n = $e.Clone(); $n.Class = $want; $n.X = $x; $n.Y = $y; $placed.Add($n); $used[$i] = $true; break
            }
        }
    }
    $kept = 0
    for ($k = $order.Count - 1; $k -ge 0 -and $kept -lt $small; $k--) {
        $i = $order[$k]; $e = $islands[$i]
        if ($used.ContainsKey($i) -or $e.Class -gt 1) { continue }
        if (Test-IslandFree $placed $e.X $e.Y $ClassW[$e.Class] $ClassH[$e.Class] 14) { $placed.Add($e.Clone()); $used[$i] = $true; $kept++ }
    }
    $placed.ToArray()
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
function Find-FreeStartPoint([byte[]]$small, [byte[]]$big, [int]$x0, [int]$y0, [int]$distance = 14, [byte[]]$giant = $null) {
    $rects = @()
    foreach ($f in 1, 1.5, 2, 4) { $rects += @(Get-IslandRects $small 0 $f) }
    foreach ($f in 1, 2) { $rects += @(Get-IslandRects $big 0 $f) }
    if ($giant) { $rects += @(Get-IslandRects $giant 0 1) }
    $best = $null; $bestD = [double]::MaxValue
    for ($y = 20; $y -le 330; $y += 2) {
        for ($x = 20; $x -le 480; $x += 2) {
            $d = [math]::Sqrt(($x - $x0) * ($x - $x0) + ($y - $y0) * ($y - $y0)); if ($d -ge $bestD) { continue }
            $free = $true
            foreach ($r in $rects) { if ($x -gt $r.X - $distance -and $x -lt $r.X + $r.W + $distance -and $y -gt $r.Y - $distance -and $y -lt $r.Y + $r.H + $distance) { $free = $false; break } }
            if ($free) { $best = @($x, $y); $bestD = $d }
        }
    }
    if (-not $best) { return $null }
    , $best
}
function Set-Amount([byte[]]$s, [int]$house, [int]$amount) {
    for ($o = 0x94; $o -le 0x114; $o += 8) { if ([BitConverter]::ToUInt16($s, $o) -eq $house) { Set-U16 $s ($o + 2) $amount } }
}

# --- Giant world (since 3.1) ----------------------------------------------------------------------------------
# A third version for 2000 x 1400 ('GROS', 2000, 1400) behind the big one; the patcher takes the biggest version that
# fits the map. The game knows at most 50 islands (at most 10 of class lar), so spread evenly they would leave the
# giant world almost empty. Here they are grouped into five realms instead - dense archipelagos with long sea routes
# between them. The starting ships are not stretched and stay in the north-west, so the home realm lies around them.
$GiantWidth = 2000; $GiantHeight = 1400
# Realms: x, y, width, height, climate (0 north, 1 south, 2 = by the island's centre: north above the middle).
$GiantRealms = [ordered]@{
    Home   = @(20, 20, 760, 540, 0)
    North  = @(1180, 20, 800, 560, 0)
    Middle = @(720, 500, 600, 420, 2)
    South  = @(20, 860, 800, 520, 1)
    East   = @(1220, 840, 760, 540, 1)
}
# Islands per realm: lar (100 x 90), big (70 x 60), med (50 x 52), mit (40 x 40); 50 in all with 10 lar and 35 big,
# about as much land as the game can hold (the big version "Huge" at 1000 x 700 has 10 lar and 40 big).
$GiantDefault = [ordered]@{ Home = @(2, 8, 1, 0); North = @(2, 7, 1, 0); Middle = @(1, 6, 1, 0); South = @(2, 7, 1, 0); East = @(3, 7, 1, 0) }
# Places the islands realm by realm (largest first, LCG from $seed, $gap fields between islands, 8 from the map edge,
# no island within $clear fields of a starting ship). A class that finds no room falls back to the next smaller one.
function Get-GiantPlan($counts, [int]$seed, $keepFree = @(), [int]$gap = 24, [int]$clear = 40) {
    $list = New-Object System.Collections.Generic.List[object]
    $rng = [long](([long]$seed * 7919 + 4099) % 2147483648); $lar = 0
    $next = { $script:giantRng = ($script:giantRng * 1103515245 + 12345) % 2147483648; [int]($script:giantRng -shr 16) }
    $script:giantRng = $rng
    foreach ($realm in $GiantRealms.Keys) {
        $r = $GiantRealms[$realm]; $n = $counts[$realm]; if (-not $n) { continue }
        # Every scenario shifts the realms a little (up to 40 fields), so no two giant maps look alike.
        $rx = $r[0] + ((& $next) % 81) - 40; $ry = $r[1] + ((& $next) % 81) - 40
        $rx = [math]::Min([math]::Max(8, $rx), $GiantWidth - 8 - $r[2]); $ry = [math]::Min([math]::Max(8, $ry), $GiantHeight - 8 - $r[3])
        $classes = @(); for ($k = 0; $k -lt 4; $k++) { $classes += @(4 - $k) * [int]$n[$k] }
        foreach ($c0 in $classes) {
            $placed = $false
            foreach ($c in (@($c0, ($c0 - 1)) | Where-Object { $_ -ge 1 })) {
                if ($c -eq 4 -and $lar -ge 10) { continue }
                $w = $ClassW[$c]; $h = $ClassH[$c]
                for ($t = 0; $t -lt 1500 -and -not $placed; $t++) {
                    $x = $rx + (& $next) % [math]::Max(1, $r[2] - $w); $y = $ry + (& $next) % [math]::Max(1, $r[3] - $h)
                    if ($x -lt 8 -or $y -lt 8 -or $x + $w -gt $GiantWidth - 8 -or $y + $h -gt $GiantHeight - 8) { continue }
                    $free = $true
                    foreach ($p in $list) { if ($x -lt $p.X + $ClassW[$p.Class] + $gap -and $p.X -lt $x + $w + $gap -and $y -lt $p.Y + $ClassH[$p.Class] + $gap -and $p.Y -lt $y + $h + $gap) { $free = $false; break } }
                    foreach ($sp in $keepFree) { if ($free -and $sp[0] -gt $x - $clear -and $sp[0] -lt $x + $w + $clear -and $sp[1] -gt $y - $clear -and $sp[1] -lt $y + $h + $clear) { $free = $false } }
                    if ($free) {
                        $climate = if ($r[4] -lt 2) { $r[4] } elseif ($y + $h / 2 -lt $GiantHeight / 2) { 0 } else { 1 }
                        $list.Add(@{ Climate = $climate; Class = $c; X = $x; Y = $y; Village = $false; File = $null; Realm = $realm }); $placed = $true
                    }
                }
                if ($placed) { if ($c -eq 4) { $lar++ }; break }
            }
        }
    }
    if ($list.Count -gt 50) { throw 'Giant plan: more than 50 islands.' }
    $list.ToArray()
}

# Builds one scenario file; returns @{ Path; Summary }.
function Build-Scenario($sc) {
    $title = Get-Localized $sc.Title
    $template = Read-Scenario (Join-Path $SzenesFolder ('[[48]]{0}{1}.szs' -f $sc.Difficulty, $sc.Layout))
    $scene = [byte[]](Get-Section $template 'SZENE').Data.Clone()
    $islands = @(Get-MirroredIslands @(Get-IslandList $scene) $sc.MirrorX $sc.MirrorY)
    if ($sc.Continents) { $islands = @(Get-ContinentIslands $islands $sc.Continents.Lar $sc.Continents.Big $sc.Continents.Small) }
    if ($sc.ContainsKey('MaxClass')) { foreach ($e in $islands) { if ($e.Class -gt $sc.MaxClass) { $e.Class = [int]$sc.MaxClass } } }
    if ($sc.AddIslands) { $islands = @(Add-Islands $islands $sc.AddIslands $(if ($sc.AddClasses) { $sc.AddClasses } else { @(0, 1) }) ([int]$sc.Number + [int]$sc.GameId)) }
    if ($sc.Enlarge) { Expand-Islands $islands $sc.Enlarge }
    if ($sc.Climate -ne $null) { foreach ($e in $islands) { $e.Climate = $sc.Climate } }
    Assert-Map $islands $title
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
    Assert-Map @(Get-IslandList $big) ($title + ' (big)') $BigWidth $BigHeight
    $marker = New-Object byte[] 16
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('GROS'), $marker, 4); Set-I32 $marker 4 $BigWidth; Set-I32 $marker 8 $BigHeight; Set-I32 $marker 12 1
    $sceneData = [byte[]]($scene + $marker + $big)
    $ships = [byte[]](Get-Section $template 'SHIP4').Data.Clone()
    $sx0 = [BitConverter]::ToInt16($ships, 0x1C); $sy0 = [BitConverter]::ToInt16($ships, 0x1E)

    # Giant world (key Giant, since 3.1): five realms on 2000 x 1400, resources growing along, 7 + 7 villages.
    $giant = $null
    if ($sc.Giant) {
        $gs = $sc.Giant
        $tplShips = @(for ($i = 0; $i -lt $ships.Length / 0x1B4; $i++) { , @([BitConverter]::ToInt16($ships, $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($ships, $i * 0x1B4 + 0x1E)) })
        $gi = @(Get-GiantPlan $(if ($gs.Islands) { $gs.Islands } else { $GiantDefault }) ([int]$sc.Number * 31 + [int]$gs.Seed) $tplShips)
        $giant = [byte[]]$scene.Clone()
        Set-Islands $giant $gi
        foreach ($o in $ResourceAmountOffsets) {
            $m = [BitConverter]::ToUInt16($giant, $o)
            if ($m) { Set-U16 $giant $o ([math]::Min($gi.Count, [int][math]::Round($m * $gi.Count / $islands.Count))) }
        }
        $gv = if ($gs.Villages) { @($gs.Villages) } else { @(7) }
        Set-I32 $giant 0x40 $gv[0]; Set-I32 $giant 0x44 $gv[-1]
        if ($gs.Amounts) { foreach ($m in $gs.Amounts.GetEnumerator()) { if ($ResourceEntry.ContainsKey($m.Key)) { Set-U16 $giant ($ResourceEntry[$m.Key] + 2) $m.Value } else { Set-Amount $giant $PlantHouse[$m.Key] $m.Value } } }
        Assert-Map @(Get-IslandList $giant) ($title + ' (giant)') $GiantWidth $GiantHeight
        $marker2 = New-Object byte[] 16
        [Array]::Copy([Text.Encoding]::ASCII.GetBytes('GROS'), $marker2, 4); Set-I32 $marker2 4 $GiantWidth; Set-I32 $marker2 8 $GiantHeight; Set-I32 $marker2 12 1
        $sceneData = [byte[]]($sceneData + $marker2 + $giant)
    }

    # Put the starting ships on a free water point (distances between them as in the template).
    # 14 fields from every island; crowded maps (archipelago) fall back to 12 or 10.
    $start = $null
    foreach ($distance in 14, 12, 10) { $start = Find-FreeStartPoint $scene $big $sx0 $sy0 $distance $giant; if ($start) { break } }
    if (-not $start) { throw "$($title): no free starting point found for the ships." }
    for ($i = 0; $i -lt $ships.Length / 0x1B4; $i++) {
        $o = $i * 0x1B4
        $dx = [BitConverter]::ToInt16($ships, $o + 0x1C) - $sx0; $dy = [BitConverter]::ToInt16($ships, $o + 0x1E) - $sy0
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $dx)), 0, $ships, $o + 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $dy)), 0, $ships, $o + 0x1E, 2)
    }
    if ($ships[0x4B] -ne 0) { throw "$($title): the first SHIP4 entry does not belong to the human player." }
    # Human's start ship (entry 0, small trading ship): own name and cargo instead of the template's.
    if ($sc.ShipName) { Set-FixedString $ships 0 0x18 (Get-Localized $sc.ShipName) }
    if ($sc.ContainsKey('Cargo')) { [Array]::Copy((New-CargoBytes $sc.Cargo ([BitConverter]::ToUInt16($ships, 0x48))), 0, $ships, 0x174, 0x40) }
    # Extra starting ships for the human player: copy of his ship (entry 0) with a new slot
    # (+0x46), figure type (+0x48: 21/23 small/large trading ship, 25/27 small/large warship),
    # cargo space (+0x3C, x 32) and the full number of cannons (+0x42), without cargo (or the given one),
    # next to the starting point (closer if the starting point is less than 14 fields from the islands).
    $FleetValues = @{ 21 = @(1600, 6); 23 = @(2560, 10); 25 = @(2080, 8); 27 = @(3840, 14) }
    $offsets = if ($distance -ge 14) { @(@(7, 4), @(8, -3), @(-9, 0)) } else { @(@(4, 3), @(4, -3), @(-5, 0)) }
    $n = 0; $shipCount0 = $ships.Length / 0x1B4
    foreach ($fs in @($sc.Fleet | Where-Object { $_ })) {
        if ($n -ge $offsets.Count) { throw 'At most 3 extra starting ships.' }
        $r = [byte[]]$ships[0..(0x1B4 - 1)]
        [Array]::Clear($r, 0, 0x18); $nb = $Cp1252.GetBytes((Get-Localized $fs.Name)); [Array]::Copy($nb, $r, [math]::Min(0x17, $nb.Length))
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[0] + $offsets[$n][0])), 0, $r, 0x1C, 2)
        [Array]::Copy([BitConverter]::GetBytes([int16]($start[1] + $offsets[$n][1])), 0, $r, 0x1E, 2)
        Set-U16 $r 0x3C $FleetValues[$fs.Type][0]; $r[0x42] = [byte]$FleetValues[$fs.Type][1]
        Set-U16 $r 0x46 ($ships.Length / 0x1B4); Set-U16 $r 0x48 $fs.Type
        [Array]::Clear($r, 0x174, 0x1B4 - 0x174)
        if ($fs.Cargo) { [Array]::Copy((New-CargoBytes $fs.Cargo $fs.Type), 0, $r, 0x174, 0x40) }
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
    # Single rivals: own gold, player name (PLAYER4 +0x3C0) and name of its start ship (SHIP4 entry with owner +0x4B).
    foreach ($rv in @($sc.Rivals | Where-Object { $_ })) {
        $p = [int]$rv.Player; if ($p -lt 1 -or $p -gt 3) { throw "$($title): rival $p is not a computer player (1-3)." }
        if ($rv.ContainsKey('Gold')) { Set-I32 $players ($p * 0x430) $rv.Gold }
        if ($rv.Name) { Set-FixedString $players ($p * 0x430 + 0x3C0) 0x40 (Get-Localized $rv.Name) }
        if ($rv.Ship) {
            $found = $false
            for ($i = 0; $i -lt $shipCount0; $i++) { if ($ships[$i * 0x1B4 + 0x4B] -eq $p) { Set-FixedString $ships ($i * 0x1B4) 0x18 (Get-Localized $rv.Ship); $found = $true; break } }
            if (-not $found) { throw "$($title): rival $p has no start ship." }
        }
    }

    $timers = [byte[]](Get-Section $template 'TIMERS').Data.Clone()
    $flags = [BitConverter]::ToInt32($timers, 0xA8)
    $flags = if ($sc.Pirates) { $flags -band (-bnot 1) } else { $flags -bor 1 }   # bit 0: pirates only sighted
    Set-I32 $timers 0xA8 $flags
    # Rival strength without another template (same map): TIMERS +0xA6 = difficulty 0-3 (game: 0x1405ec1c0).
    if ($sc.ContainsKey('AI')) { $timers[0xA6] = [byte]$sc.AI }

    $mission = $sc.Mission.Clone(); $mission.Slot = 0; $mission.Text = Get-Localized $sc.Text
    if ($sc.Race) { $mission.AlsoAI = $true }
    if ($sc.TimeLimitHours) { $mission.TimeLimitHours = $sc.TimeLimitHours }
    $gameId = if ($sc.GameId) { [int]$sc.GameId } else { 0x53D00000 + $sc.Number }
    $list = New-Object System.Collections.Generic.List[object]
    $list.Add(@{ Name = 'SZENE_PLAYERMIN'; Data = [BitConverter]::GetBytes([int32]1) })
    $list.Add(@{ Name = 'SZENE_PLAYERMAX'; Data = [BitConverter]::GetBytes([int32]0) })
    $list.Add(@{ Name = 'SZENE_GAMEID'; Data = [BitConverter]::GetBytes([int32]$gameId) })
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
    New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
    $path = Join-Path $OutputFolder ($title + '.szs')
    Write-Scenario $path $list
    $summary = '{0,-36} {1,2} islands (big {2}, {3}), start {9},{10} (template {11},{12}), difficulty {4}, pirates {5}, gold {6}/{7}, text {8}' -f $title, $islands.Count, $plan.Count, $sc.BigIslandSize, $(if ($sc.ContainsKey('AI')) { '{0} (rivals {1})' -f $sc.Difficulty, $sc.AI } else { $sc.Difficulty }), $(if ($sc.Pirates) { 'active' } else { 'sighted' }), $sc.Gold, $sc.RivalGold, $mission.Text.Length, $start[0], $start[1], $sx0, $sy0
    if ($mission.TimeLimitHours) { $summary += ', time limit {0} h' -f $mission.TimeLimitHours }
    if ($giant) { $summary += ', giant world {0} islands ({1} lar)' -f $gi.Count, @($gi | Where-Object { $_.Class -eq 4 }).Count }
    @{ Path = $path; Summary = $summary }
}

$Scenarios = @(
    @{ Number = 1; BigIslandSize = 'Normal'; Title = @{ de = 'Smaragdinseln 1 - Landung'; en = 'Emerald Isles 1 - Landfall' }; Difficulty = 0; Layout = 1; MirrorX = $true; MirrorY = $false
        Gold = 30000; RivalGold = 15000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 250; Stage = 1; OfWhich = 150 }); Balance = 0 }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 1: Landung

Gouverneur, nach elf Wochen auf See liegt sie vor uns: die Inselwelt, die unsere Kartographen die Smaragdinseln nennen. Die Handelskompanie hat Euch Schiff, Werkzeug und ein bescheidenes Startkapital anvertraut. Drei andere Häuser haben ebenfalls Schiffe ausgesandt - wer zuerst Fuss fasst, wird hier herrschen.

Euer Auftrag:
- Gründet eine Stadt mit mindestens 250 Einwohnern.
- Mindestens 150 davon sollen Siedler (oder höher) sein.
- Haltet die Bilanz Eurer Kolonie im Plus.

Rat des Steuermanns: Sucht eine grosse Insel mit Wald und fruchtbarem Boden nahe der Kartenmitte. Die Ureinwohner sind friedlich, solange Ihr sie in Ruhe lasst.
'@; en = @'
THE EMERALD ISLES - Chapter 1: Landfall

Governor, after eleven weeks at sea it lies before us: the island world our cartographers call the Emerald Isles. The trading company has entrusted you with a ship, tools and a modest starting capital. Three other houses have sent out ships as well - whoever gains a foothold first will rule here.

Your orders:
- Found a town with at least 250 residents.
- At least 150 of them shall be settlers (or higher).
- Keep the balance of your colony in the black.

The helmsman's advice: Look for a large island with forest and fertile soil near the centre of the map. The natives are peaceful as long as you leave them alone.
'@ }
    }
    @{ Number = 2; BigIslandSize = 'Normal'; BigAmounts = @{ Spices = 3 }; Title = @{ de = 'Smaragdinseln 2 - Gewuerzfieber'; en = 'Emerald Isles 2 - Spice Fever' }; Difficulty = 1; Layout = 0; MirrorX = $false; MirrorY = $true
        Gold = 25000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Amounts = @{ Spices = 2; Tobacco = 4; Cocoa = 4 }   # monopoly = all spice islands (the game counts them at start, FUN_1400ceea0)
        Mission = @{ Monopoly1 = @{ Resource = 0x2F; Islands = 1 }; Towns = @(@{ Residents = 500; Stage = 2; OfWhich = 250 }) }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 2: Gewürzfieber

In den Häfen der Alten Welt zahlt man für ein Fass Gewürze mehr als für ein ganzes Schiff. Auf diesem Archipel gibt es nur wenige Inseln, auf denen Gewürze gedeihen - und Eure Rivalen wissen das ebenso gut wie Ihr.

Euer Auftrag:
- Sichert Euch das Gewürzmonopol: Gründet auf JEDER Insel, auf der Gewürze wachsen, eine eigene Siedlung und duldet dort keine fremde. Es ist nur eine Handvoll.
- Baut eine Stadt mit mindestens 500 Einwohnern, davon 250 Bürger oder höher.

Rat des Steuermanns: Erkundet früh mit dem Schiff, welche Inseln Gewürze tragen (Fruchtbarkeit im Inselinfo). Wer zu spät kommt, muss den Rivalen verdrängen.
'@; en = @'
THE EMERALD ISLES - Chapter 2: Spice Fever

In the ports of the Old World a barrel of spices fetches more than a whole ship. In this archipelago there are only a few islands where spices grow - and your rivals know that as well as you do.

Your orders:
- Secure the spice monopoly: found a settlement of your own on EVERY island where spices grow, and tolerate no foreign one there. There are only a handful of them.
- Build a town with at least 500 residents, 250 of them citizens or higher.

The helmsman's advice: Explore early by ship to find out which islands bear spices (fertility in the island info). Whoever comes too late must drive the rival out.
'@ }
    }
    @{ Number = 3; BigIslandSize = 'Large'; Title = @{ de = 'Smaragdinseln 3 - Zwei Kolonien'; en = 'Emerald Isles 3 - Two Colonies' }; Difficulty = 1; Layout = 2; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ Towns = @(@{ Residents = 800; Stage = 3; OfWhich = 300 }, @{ Residents = 500; Stage = 2; OfWhich = 250 }); Balance = 300 }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 3: Zwei Kolonien

Die Kompanie ist zufrieden, doch eine einzige Stadt reicht ihr nicht. Im kalten Norden wachsen Getreide und Wein, im heissen Süden Zuckerrohr, Kakao und Tabak. Nur wer beide Welten verbindet, versorgt seine Kaufleute.

Euer Auftrag:
- Eine Hauptstadt mit mindestens 800 Einwohnern, davon 300 Kaufleute oder höher.
- Eine zweite Stadt mit mindestens 500 Einwohnern, davon 250 Bürger oder höher.
- Eine Bilanz von mindestens +300 Talern.

Rat des Steuermanns: Richtet früh Handelsrouten zwischen Euren Inseln ein. Ein zweites Schiff ist Gold wert.
'@; en = @'
THE EMERALD ISLES - Chapter 3: Two Colonies

The company is pleased, but a single town is not enough for it. Grain and wine grow in the cold north, sugar cane, cocoa and tobacco in the hot south. Only those who unite both worlds can supply their merchants.

Your orders:
- A capital with at least 800 residents, 300 of them merchants or higher.
- A second town with at least 500 residents, 250 of them citizens or higher.
- A balance of at least +300 talers.

The helmsman's advice: Set up trade routes between your islands early. A second ship is worth its weight in gold.
'@ }
    }
    @{ Number = 4; BigIslandSize = 'Large'; Fleet = @(@{ Type = 25; Name = @{ de = 'Wehrhaft'; en = 'Stalwart' } }); Title = @{ de = 'Smaragdinseln 4 - Schwarze Segel'; en = 'Emerald Isles 4 - Black Sails' }; Difficulty = 2; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 30000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 10 }
        Mission = @{ Towns = @(@{ Residents = 1000; Stage = 3; OfWhich = 500 }); Goods1 = @{ Good = 13; Tons = 20 }; Goods2 = @{ Good = 12; Tons = 40 } }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 4: Schwarze Segel

Schwarze Segel am Horizont! Ein Piratenkapitän hat sich in den Riffen eingenistet und kapert jedes Schiff, das schwach bewaffnet ist. Die Kompanie schickt keine Flotte - Ihr müsst Euch selbst wappnen.

Euer Auftrag:
- Eine Stadt mit mindestens 1000 Einwohnern, davon 500 Kaufleute oder höher.
- Legt ein Waffenlager an: mindestens 20 Tonnen Kanonen und 40 Tonnen Musketen in Euren Kontoren.

Rat des Steuermanns: Eisen braucht Erz und Holzkohle. Sichert Euch eine Erzinsel, bevor die Rivalen es tun, und lasst Eure Handelsschiffe nicht unbegleitet fahren.
'@; en = @'
THE EMERALD ISLES - Chapter 4: Black Sails

Black sails on the horizon! A pirate captain has settled in the reefs and seizes every ship that is poorly armed. The company sends no fleet - you must arm yourself.

Your orders:
- A town with at least 1000 residents, 500 of them merchants or higher.
- Lay in an arsenal: at least 20 tons of cannons and 40 tons of muskets in your warehouses.

The helmsman's advice: Iron needs ore and charcoal. Secure an ore island before the rivals do, and do not let your trading ships sail unescorted.
'@ }
    }
    @{ Number = 5; BigIslandSize = 'Normal'; Fleet = @(@{ Type = 27; Name = @{ de = 'Königsadler'; en = 'Royal Eagle' } }); Title = @{ de = 'Smaragdinseln 5 - Der Eroberer'; en = 'Emerald Isles 5 - The Conqueror' }; Difficulty = 2; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 50000; RivalGold = 40000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        Mission = @{ Defeat = @(1, 2, 3) }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 5: Der Eroberer

Die Zeit der Verhandlungen ist vorbei. Die drei Rivalen haben sich gegen Euch verbündet, Eure Händler werden abgewiesen, Eure Schiffe beschossen. Die Kompanie erteilt Euch freie Hand.

Euer Auftrag:
- Besiegt alle drei Rivalen. Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.

Rat des Steuermanns: Ein Krieg wird mit Gold gewonnen. Baut zuerst eine starke Wirtschaft, dann Burgen, Kasernen und eine Flotte. Nehmt Euch die Rivalen einzeln vor.
'@; en = @'
THE EMERALD ISLES - Chapter 5: The Conqueror

The time for negotiations is over. The three rivals have allied against you, your traders are turned away, your ships fired upon. The company gives you a free hand.

Your orders:
- Defeat all three rivals. A rival counts as defeated when he owns no settlement and no ship any more.

The helmsman's advice: A war is won with gold. First build a strong economy, then castles, barracks and a fleet. Take on the rivals one by one.
'@ }
    }
    @{ Number = 6; BigIslandSize = 'Huge'; BigVillages = 6; Fleet = @(@{ Type = 23; Name = 'Fortuna' }); Title = @{ de = 'Smaragdinseln 6 - Krone der Inseln'; en = 'Emerald Isles 6 - Crown of the Isles' }; Difficulty = 3; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 4
        Gold = 40000; RivalGold = 50000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3; Treasure = 10 }
        Mission = @{ Towns = @(@{ Residents = 2500; Stage = 4; OfWhich = 1200 }, @{ Residents = 1500; Stage = 3; OfWhich = 800 }, @{ Residents = 800; Stage = 2; OfWhich = 400 }); Balance = 1000 }
        Text = @{ de = @'
DIE SMARAGDINSELN - Kapitel 6: Krone der Inseln

Der König selbst hat von Euren Taten gehört. Er will die Smaragdinseln zu einem eigenen Reich erheben - und Euch zu seinem Vizekönig, sofern Ihr ihm eine Residenz bietet, die der Alten Welt in nichts nachsteht. Doch die Rivalen sind stärker als je zuvor, und die Piraten wittern Beute.

Euer Auftrag:
- Eine Residenzstadt mit mindestens 2500 Einwohnern, davon 1200 Aristokraten.
- Eine zweite Stadt mit mindestens 1500 Einwohnern, davon 800 Kaufleute oder höher.
- Eine dritte Stadt mit mindestens 800 Einwohnern, davon 400 Bürger oder höher.
- Eine Bilanz von mindestens +1000 Talern.

Dies ist das letzte Kapitel. Möge Euer Name in die Chroniken eingehen!
'@; en = @'
THE EMERALD ISLES - Chapter 6: Crown of the Isles

The King himself has heard of your deeds. He wants to raise the Emerald Isles to a realm of their own - and you to his viceroy, provided you offer him a residence in no way inferior to those of the Old World. But the rivals are stronger than ever, and the pirates scent booty.

Your orders:
- A residence city with at least 2500 residents, 1200 of them aristocrats.
- A second town with at least 1500 residents, 800 of them merchants or higher.
- A third town with at least 800 residents, 400 of them citizens or higher.
- A balance of at least +1000 talers.

This is the last chapter. May your name enter the chronicles!
'@ }
    }

    # --- Campaign 2: Wettlauf der Häuser (the rivals have the same mission) ------------------------
    # Rival strength (AI) from a measurement on 2026-11-12: difficulty 0 needed ~10.7 h for 300/150, difficulty 2 ~3.7 h.
    @{ Number = 11; BigIslandSize = 'Normal'; Title = @{ de = 'Wettlauf 1 - Erster Hafen'; en = 'Race 1 - First Harbour' }; Difficulty = 0; AI = 1; Layout = 0; MirrorX = $true; MirrorY = $true; Race = $true
        Gold = 30000; RivalGold = 20000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 300; Stage = 1; OfWhich = 150 }) }
        Text = @{ de = @'
WETTLAUF DER HÄUSER - Kapitel 1: Erster Hafen

Der König hat vier Handelshäuser über den Ozean geschickt und ein Versprechen gegeben: Wer als Erster eine blühende Hafenstadt gründet, erhält das Handelsprivileg für die ganze Küste. Eure drei Rivalen verfolgen dasselbe Ziel - und sie warten nicht auf Euch.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 300 Einwohnern, davon 150 Siedler oder höher.

Erreicht ein Rivale das Ziel vor Euch, ist das Rennen verloren.

Rat des Steuermanns: Zeit ist alles. Baut zügig, aber lasst Eure Kasse nicht leerlaufen.
'@; en = @'
RACE OF THE HOUSES - Chapter 1: First Harbour

The King has sent four trading houses across the ocean and made a promise: whoever is first to found a flourishing port town receives the trading privilege for the whole coast. Your three rivals pursue the same goal - and they will not wait for you.

Your orders (they apply to your rivals as well):
- Be the first to have a town with at least 300 residents, 150 of them settlers or higher.

If a rival reaches the goal before you, the race is lost.

The helmsman's advice: Time is everything. Build briskly, but do not let your coffers run dry.
'@ }
    }
    # Second town 200/100: the rivals' second towns stall at 144 settlers and 187-290 residents (measurements);
    # 300/150 would be out of their reach, 250 only just (Wettlauf 2 with 250: the rival won after 9.6 h at 251).
    @{ Number = 12; BigIslandSize = 'Large'; Title = @{ de = 'Wettlauf 2 - Buergerstolz'; en = 'Race 2 - Civic Pride' }; Difficulty = 1; AI = 2; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 2; Race = $true
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Mission = @{ Towns = @(@{ Residents = 700; Stage = 2; OfWhich = 350 }, @{ Residents = 200; Stage = 1; OfWhich = 100 }) }
        Text = @{ de = @'
WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz

Das Handelsprivileg war nur der Anfang. Nun sucht der König einen Statthalter für die neuen Kolonien - und wieder sollen die Häuser gegeneinander antreten. Der Preis: zwei Städte, die der Krone Ehre machen.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 700 Einwohnern, davon 350 Bürger oder höher,
- und eine zweite Stadt mit mindestens 200 Einwohnern, davon 100 Siedler oder höher.

Rat des Steuermanns: Eine zweite Insel mit anderem Klima liefert, was Eure Bürger verlangen. Wer sie zuerst besetzt, hat die Nase vorn.
'@; en = @'
RACE OF THE HOUSES - Chapter 2: Civic Pride

The trading privilege was only the beginning. Now the King seeks a governor for the new colonies - and once again the houses are to compete. The prize: two towns that do the Crown honour.

Your orders (they apply to your rivals as well):
- Be the first to have a town with at least 700 residents, 350 of them citizens or higher,
- and a second town with at least 200 residents, 100 of them settlers or higher.

The helmsman's advice: A second island with a different climate supplies what your citizens demand. Whoever occupies it first is ahead.
'@ }
    }
    @{ Number = 13; BigIslandSize = 'Large'; Title = @{ de = 'Wettlauf 3 - Kaufmannsrepublik'; en = 'Race 3 - Merchant Republic' }; Difficulty = 2; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 3; Race = $true
        Gold = 35000; RivalGold = 35000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ Towns = @(@{ Residents = 1000; Stage = 3; OfWhich = 400 }) }
        Text = @{ de = @'
WETTLAUF DER HÄUSER - Kapitel 3: Kaufmannsrepublik

Die Kaufleute der Alten Welt wollen eine freie Handelsstadt jenseits des Meeres. Sie werden das Haus unterstützen, das ihnen zuerst eine würdige Heimat baut. Doch Piraten lauern in diesen Gewässern, und die Rivalen schrecken vor nichts zurück.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1000 Einwohnern, davon 400 Kaufleute oder höher.

Rat des Steuermanns: Kaufleute verlangen Tuch, Alkohol und Tabakwaren. Sichert Euch die Rohstoffe, bevor es die anderen tun.
'@; en = @'
RACE OF THE HOUSES - Chapter 3: Merchant Republic

The merchants of the Old World want a free trading city beyond the sea. They will support the house that first builds them a worthy home. But pirates lurk in these waters, and the rivals stop at nothing.

Your orders (they apply to your rivals as well):
- Be the first to have a town with at least 1000 residents, 400 of them merchants or higher.

The helmsman's advice: Merchants demand cloth, liquor and tobacco goods. Secure the raw materials before the others do.
'@ }
    }
    @{ Number = 14; BigIslandSize = 'Huge'; BigVillages = 6; Title = @{ de = 'Wettlauf 4 - Die Krone'; en = 'Race 4 - The Crown' }; Difficulty = 3; Layout = 1; MirrorX = $true; MirrorY = $false; Enlarge = 4; Race = $true
        Gold = 40000; RivalGold = 45000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        # 1500 instead of 2000: the rivals' capital stalls at ~1500-1610 residents (measurement); with 1500/600 + balance 500
        # the best rival wins after about 20 game hours - a real race for the finale.
        Mission = @{ Towns = @(@{ Residents = 1500; Stage = 4; OfWhich = 600 }); Balance = 500 }
        Text = @{ de = @'
WETTLAUF DER HÄUSER - Kapitel 4: Die Krone

Das letzte Rennen. Der König wird alt, und er hat verkündet, wer die prächtigste Residenz der Neuen Welt errichtet, soll sein Vizekönig werden. Alle vier Häuser setzen nun alles auf eine Karte.

Euer Auftrag (er gilt auch für Eure Rivalen):
- Als Erster eine Stadt mit mindestens 1500 Einwohnern, davon 600 Aristokraten,
- und eine Bilanz von mindestens +500 Talern.

Rat des Steuermanns: Ein Rivale, der keine Stadt mehr hat, kann auch nicht gewinnen ...
'@; en = @'
RACE OF THE HOUSES - Chapter 4: The Crown

The last race. The King is growing old, and he has proclaimed that whoever builds the most splendid residence in the New World shall be his viceroy. All four houses now stake everything on one card.

Your orders (they apply to your rivals as well):
- Be the first to have a town with at least 1500 residents, 600 of them aristocrats,
- and a balance of at least +500 talers.

The helmsman's advice: A rival who no longer has a town cannot win either ...
'@ }
    }

    # --- Challenges (single scenarios with special goals) -----------------------------------------
    @{ Number = 21; BigIslandSize = 'Normal'; Title = @{ de = 'Herausforderung - Inselreich'; en = 'Challenge - Island Realm' }; Difficulty = 1; Layout = 1; MirrorX = $false; MirrorY = $true
        Gold = 40000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Mission = @{ TownCount = 8; TotalResidents = 3000 }
        Text = @{ de = @'
HERAUSFORDERUNG: Inselreich

Ein Reich, über dem die Sonne nie untergeht, besteht nicht aus einer einzigen Stadt. Die Krone will Flaggen auf möglichst vielen Inseln sehen.

Euer Auftrag:
- Gründet mindestens 8 eigene Siedlungen (je ein Kontor) auf den Inseln dieses Archipels.
- Alle Eure Siedlungen zusammen sollen mindestens 3000 Einwohner haben.

Rat des Steuermanns: Kleine Inseln sind billig zu besiedeln. Ein Kontor und ein paar Häuser zählen schon als Siedlung - aber die Einwohner wollen versorgt sein.
'@; en = @'
CHALLENGE: Island Realm

An empire on which the sun never sets does not consist of a single town. The Crown wants to see flags on as many islands as possible.

Your orders:
- Found at least 8 settlements of your own (one warehouse each) on the islands of this archipelago.
- All your settlements together shall have at least 3000 residents.

The helmsman's advice: Small islands are cheap to settle. A warehouse and a few houses already count as a settlement - but the residents want to be supplied.
'@ }
    }
    @{ Number = 22; BigIslandSize = 'Large'; Title = @{ de = 'Herausforderung - Handelsimperium'; en = 'Challenge - Trade Empire' }; Difficulty = 2; Layout = 0; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        Amounts = @{ Gold = 3 }
        Mission = @{ Goods1 = @{ Good = 21; Tons = 50 }; Goods2 = @{ Good = 20; Tons = 80 }; TradeBalance = 300 }
        Text = @{ de = @'
HERAUSFORDERUNG: Handelsimperium

Nicht Kanonen, sondern volle Lagerhäuser regieren die Welt. Die Kaufleute von Antwerpen wollen sehen, wer die reichsten Speicher der Neuen Welt füllt.

Euer Auftrag:
- Lagert mindestens 50 Tonnen Schmuck und 80 Tonnen Kleidung in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +300 Talern: Eure Verkäufe an Händler und Rivalen müssen Eure Einkäufe deutlich übersteigen.

Rat des Steuermanns: Schmuck braucht Gold aus den Bergen, Kleidung braucht Stoffe aus Wolle oder Baumwolle. Stellt in den Kontoren ein, was Ihr verkaufen wollt, und baut Lager aus, damit nichts verloren geht.
'@; en = @'
CHALLENGE: Trade Empire

Not cannons but full warehouses rule the world. The merchants of Antwerp want to see who fills the richest storehouses of the New World.

Your orders:
- Store at least 50 tons of jewellery and 80 tons of clothes in your warehouses.
- Reach a trade balance of at least +300 talers: your sales to traders and rivals must clearly exceed your purchases.

The helmsman's advice: Jewellery needs gold from the mountains, clothes need cloth from wool or cotton. Set in the warehouses what you want to sell, and expand your storage so that nothing is lost.
'@ }
    }
    @{ Number = 23; BigIslandSize = 'Normal'; Fleet = @(@{ Type = 25; Name = @{ de = 'Goldwächter'; en = 'Gold Warden' } }); Title = @{ de = 'Herausforderung - Goldrausch'; en = 'Challenge - Gold Rush' }; Difficulty = 2; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 35000; RivalGold = 35000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ Gold = 4; OreSmall = 6; OreLarge = 9; Treasure = 12 }
        Mission = @{ Goods1 = @{ Good = 3; Tons = 60 }; Goods2 = @{ Good = 21; Tons = 40 } }
        Text = @{ de = @'
HERAUSFORDERUNG: Goldrausch

In den Bergen dieser Inseln soll es Gold geben - genug, um eine Flotte zu kaufen. Die Gerüchte haben nicht nur Euch angelockt: Rivalen und Piraten sind schon unterwegs.

Euer Auftrag:
- Lagert mindestens 60 Tonnen Gold und 40 Tonnen Schmuck in Euren Kontoren.

Rat des Steuermanns: Goldminen gibt es nur an wenigen Bergen. Wer sie zuerst besetzt und gut schützt, gewinnt. Und lasst Eure Goldschiffe nie allein fahren.
'@; en = @'
CHALLENGE: Gold Rush

There is said to be gold in the mountains of these islands - enough to buy a fleet. The rumours have lured not only you: rivals and pirates are already on their way.

Your orders:
- Store at least 60 tons of gold and 40 tons of jewellery in your warehouses.

The helmsman's advice: Gold mines exist only at a few mountains. Whoever occupies them first and guards them well wins. And never let your gold ships sail alone.
'@ }
    }
    # New challenges (2026-11-12): many small islands, few huge islands, a merchant fleet, a war fleet.
    @{ Number = 24; BigIslandSize = 'Normal'; BigVillages = 6; Title = @{ de = 'Herausforderung - Archipel'; en = 'Challenge - Archipelago' }; Difficulty = 1; Layout = 1; MirrorX = $true; MirrorY = $false; MaxClass = 2; AddIslands = 30
        Gold = 40000; RivalGold = 25000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Food'; Tons = 20 }, @{ Good = 'Bricks'; Tons = 20 })
        Fleet = @(@{ Type = 21; Name = @{ de = 'Inselspringer'; en = 'Island Hopper' }; Cargo = @(@{ Good = 'Tools'; Tons = 40 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Food'; Tons = 20 }) })
        Mission = @{ TownCount = 10; AllTowns = @{ Residents = 100; Stage = 1; OfWhich = 40 } }
        Text = @{ de = @'
HERAUSFORDERUNG: Archipel

Dutzende kleiner Inseln, keine einzige gross genug für ein Königreich. Wer hier herrschen will, muss von Insel zu Insel springen - und jede Siedlung muss für sich allein bestehen können.

Euer Auftrag:
- Gründet mindestens 10 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 100 Einwohner, davon 40 Siedler oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!

Rat des Steuermanns: Der "Inselspringer" bringt zusätzliches Werkzeug und Holz für die vielen Kontore. Jede kleine Stadt braucht ihren eigenen Marktplatz - baut die Häuser eng darum herum.
'@; en = @'
CHALLENGE: Archipelago

Dozens of small islands, not one of them big enough for a kingdom. Whoever wants to rule here must hop from island to island - and every settlement must be able to stand on its own.

Your orders:
- Found at least 10 settlements of your own.
- EVERY one of your settlements needs at least 100 residents, 40 of them settlers or higher. Even a warehouse without houses counts as a settlement!

The helmsman's advice: The "Island Hopper" brings extra tools and wood for the many warehouses. Every small town needs its own marketplace - build the houses close around it.
'@ }
    }
    @{ Number = 25; BigIslandSize = 'Huge'; Title = @{ de = 'Herausforderung - Kontinente'; en = 'Challenge - Continents' }; Difficulty = 2; AI = 2; Layout = 0; MirrorX = $false; MirrorY = $true; Continents = @{ Lar = 5; Big = 4; Small = 3 }
        Gold = 35000; RivalGold = 35000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 9; Gold = 3 }
        Mission = @{ Towns = @(@{ Residents = 1500; Stage = 4; OfWhich = 400 }); TotalResidents = 3000; Balance = 300 }
        Text = @{ de = @'
HERAUSFORDERUNG: Kontinente

Nur eine Handvoll gewaltiger Inseln ragt aus diesem Meer - Land genug für Metropolen, aber zu wenig für vier Häuser. Wer zuerst die besten Küsten besetzt, baut die grösste Stadt.

Euer Auftrag:
- Eine Metropole mit mindestens 1500 Einwohnern, davon 400 Aristokraten.
- Alle Eure Siedlungen zusammen sollen mindestens 3000 Einwohner haben.
- Eine Bilanz von mindestens +300 Talern.

Rat des Steuermanns: Auf einer so grossen Insel sind die Wege weit. Setzt Marktplätze so, dass ihr Einzugsbereich die ganze Stadt abdeckt, und lasst den Rivalen keine Bucht übrig, in der sie sich festsetzen können.
'@; en = @'
CHALLENGE: Continents

Only a handful of mighty islands rise from this sea - land enough for great cities, but too little for four houses. Whoever occupies the best coasts first builds the greatest city.

Your orders:
- A metropolis with at least 1500 residents, 400 of them aristocrats.
- All your settlements together shall have at least 3000 residents.
- A balance of at least +300 talers.

The helmsman's advice: On an island this large the roads are long. Place marketplaces so that their reach covers the whole town, and leave the rivals no bay in which to take hold.
'@ }
    }
    @{ Number = 26; BigIslandSize = 'Large'; BigAmounts = @{ Spices = 4; Cocoa = 4 }; Title = @{ de = 'Herausforderung - Handelsflotte'; en = 'Challenge - Merchant Fleet' }; Difficulty = 1; Layout = 2; MirrorX = $true; MirrorY = $true; Enlarge = 2
        Gold = 15000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ Spices = 3; Cocoa = 3 }
        Fleet = @(
            @{ Type = 23; Name = @{ de = 'Merkur'; en = 'Mercury' }; Cargo = @(@{ Good = 'Cloth'; Tons = 50 }, @{ Good = 'Liquor'; Tons = 50 }, @{ Good = 'TobaccoGoods'; Tons = 30 }) }
            @{ Type = 23; Name = @{ de = 'Neptun'; en = 'Neptune' }; Cargo = @(@{ Good = 'Tools'; Tons = 40 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 30 }) }
            @{ Type = 25; Name = @{ de = 'Geleit'; en = 'Escort' } }
        )
        Mission = @{ TownCount = 4; Goods1 = @{ Good = 16; Tons = 60 }; Goods2 = @{ Good = 17; Tons = 60 } }
        Text = @{ de = @'
HERAUSFORDERUNG: Handelsflotte

Die Kompanie hat Euch vier Schiffe anvertraut, aber kaum Gold. Gewürze und Kakao gedeihen nur auf wenigen Inseln im warmen Süden, und die Lagerhäuser der Kompanie sind leer. Eine Flotte, die im Hafen liegt, verdient nichts.

Euer Auftrag:
- Gründet mindestens 4 eigene Siedlungen.
- Lagert mindestens 60 Tonnen Gewürze und 60 Tonnen Kakao in Euren Kontoren.

Rat des Steuermanns: Die "Merkur" ist voll mit Stoffen, Alkohol und Tabakwaren - verkauft sie für Euer erstes Gold. Richtet dann Handelsrouten ein, damit Eure Schiffe die Ernte aus dem Süden selbstständig heimbringen.
'@; en = @'
CHALLENGE: Merchant Fleet

The company has entrusted you with four ships, but hardly any gold. Spices and cocoa thrive only on a few islands in the warm south, and the company's storehouses are empty. A fleet that lies in port earns nothing.

Your orders:
- Found at least 4 settlements of your own.
- Store at least 60 tons of spices and 60 tons of cocoa in your warehouses.

The helmsman's advice: The "Mercury" is full of cloth, liquor and tobacco goods - sell them for your first gold. Then set up trade routes so that your ships bring the harvest home from the south on their own.
'@ }
    }
    @{ Number = 27; BigIslandSize = 'Normal'; Title = @{ de = 'Herausforderung - Seemacht'; en = 'Challenge - Sea Power' }; Difficulty = 2; AI = 1; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 60000; RivalGold = 10000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 2 }
        Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 40 }, @{ Good = 'Food'; Tons = 20 })
        Fleet = @(
            @{ Type = 27; Name = @{ de = 'Dreizack'; en = 'Trident' }; Cargo = @(@{ Good = 'Cannons'; Tons = 40 }, @{ Good = 'Swords'; Tons = 40 }) }
            @{ Type = 27; Name = @{ de = 'Donnerkeil'; en = 'Thunderbolt' }; Cargo = @(@{ Good = 'Cannons'; Tons = 30 }, @{ Good = 'Tools'; Tons = 30 }) }
            @{ Type = 25; Name = @{ de = 'Hai'; en = 'Shark' } }
        )
        Mission = @{ Defeat = @(1, 2, 3) }
        Text = @{ de = @'
HERAUSFORDERUNG: Seemacht

Drei Häuser, arm und zerstritten - und Eure Flotte, wie sie die Neue Welt noch nicht gesehen hat. Die Krone erwartet einen schnellen Sieg, denn jedes Kriegsjahr kostet ein Vermögen.

Euer Auftrag:
- Besiegt alle drei Rivalen. Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.

Rat des Steuermanns: "Dreizack" und "Donnerkeil" haben Kanonen und Schwerter geladen. Schlagt zu, bevor die Rivalen Burgen bauen: Versenkt ihre Schiffe, stellt Truppen auf und nehmt ihre Kontore. Wer zögert, kämpft bald gegen Festungen.
'@; en = @'
CHALLENGE: Sea Power

Three houses, poor and quarrelling - and your fleet, such as the New World has never seen. The Crown expects a quick victory, for every year of war costs a fortune.

Your orders:
- Defeat all three rivals. A rival counts as defeated when he owns no settlement and no ship any more.

The helmsman's advice: The "Trident" and the "Thunderbolt" carry cannons and swords. Strike before the rivals build castles: sink their ships, raise troops and take their warehouses. Whoever hesitates will soon be fighting fortresses.
'@ }
    }

    # --- Campaign 3: Die Sturmsee (The Storm Sea), 2026-11-12 -------------------------------------
    # One story, six different kinds of goal: shipwreck start with little gold and cargo, a double
    # monopoly, a trade-only chapter, every town must hold out against pirates, one specific rival
    # (House Valcourt = player 2, rich, its start ship renamed) must fall while two stay, grand finale.
    @{ Number = 31; BigIslandSize = 'Normal'; Title = @{ de = 'Sturmsee 1 - Schiffbruch'; en = 'Storm Sea 1 - Shipwreck' }; Difficulty = 1; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 2
        Gold = 10000; RivalGold = 20000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 12 }, @{ Good = 'Food'; Tons = 8 })
        Mission = @{ Towns = @(@{ Residents = 200; Stage = 1; OfWhich = 100 }); TownCount = 2; Balance = 0 }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 1: Schiffbruch

Gouverneur, der Sturm kam in der dritten Nacht. Von den fünf Schiffen Eures Konvois hat nur die "Morgenstern" die Riffe der Sturmsee überstanden - mit halb leerem Laderaum und kaum Gold in der Kasse. Die Überlebenden der anderen Schiffe wurden an eine fremde Küste gespült und warten auf Euch.

Euer Auftrag:
- Gründet eine Stadt mit mindestens 200 Einwohnern, davon 100 Siedler oder höher.
- Gründet für die Schiffbrüchigen eine zweite Siedlung auf einer anderen Insel - insgesamt mindestens 2 eigene Siedlungen.
- Haltet die Bilanz Eurer Kolonie im Plus.

Rat des Steuermanns: An Bord sind nur 20 Tonnen Werkzeug, 12 Tonnen Holz und etwas Proviant. Baut zuerst Försterhäuser - sie kosten kein Holz. Fehlt Werkzeug, stellt es im Kontor auf Einkauf: Die freien Händler bringen es Euch.
'@; en = @'
THE STORM SEA - Chapter 1: Shipwreck

Governor, the storm came in the third night. Of the five ships of your convoy only the "Morning Star" survived the reefs of the Storm Sea - with a half-empty hold and hardly any gold in the coffers. The survivors of the other ships were washed up on a foreign shore and are waiting for you.

Your orders:
- Found a town with at least 200 residents, 100 of them settlers or higher.
- Found a second settlement for the castaways on another island - at least 2 settlements of your own in total.
- Keep the balance of your colony in the black.

The helmsman's advice: On board are only 20 tons of tools, 12 tons of wood and a few provisions. Build forester's lodges first - they cost no wood. If tools run short, set them to "buy" in the warehouse: the free traders will bring them to you.
'@ }
    }
    @{ Number = 32; BigIslandSize = 'Normal'; BigAmounts = @{ Tobacco = 3; Cocoa = 3 }; Title = @{ de = 'Sturmsee 2 - Tabak und Kakao'; en = 'Storm Sea 2 - Tobacco and Cocoa' }; Difficulty = 1; AI = 2; Layout = 0; MirrorX = $true; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ Tobacco = 2; Cocoa = 2; Spices = 3; Sugar = 3 }   # both monopolies: all tobacco and all cocoa islands
        Mission = @{ Monopoly1 = @{ Resource = 0x2E; Islands = 1 }; Monopoly2 = @{ Resource = 0x33; Islands = 1 }; Towns = @(@{ Residents = 600; Stage = 2; OfWhich = 300 }) }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 2: Tabak und Kakao

Die Kolonie lebt, doch die Kompanie will mehr als Überleben. In den Kaffeehäusern Europas reisst man sich um Tabak und Trinkschokolade - und in der Sturmsee gedeihen Tabak und Kakao nur auf wenigen Inseln. Wer sie alle besitzt, bestimmt die Preise. Eure Rivalen haben das ebenfalls begriffen, und sie sind diesmal gerissener.

Euer Auftrag:
- Sichert Euch das Tabakmonopol: eine eigene Siedlung auf JEDER Insel, auf der Tabak wächst, und keine fremde dort.
- Sichert Euch ebenso das Kakaomonopol.
- Baut eine Stadt mit mindestens 600 Einwohnern, davon 300 Bürger oder höher.

Rat des Steuermanns: Schickt die "Morgenstern" sofort auf Erkundungsfahrt und prüft die Fruchtbarkeit im Inselinfo. Dörfer der Ureinwohner stören ein Monopol nicht, Siedlungen der Rivalen schon.
'@; en = @'
THE STORM SEA - Chapter 2: Tobacco and Cocoa

The colony lives, but the company wants more than survival. In the coffee houses of Europe people scramble for tobacco and drinking chocolate - and in the Storm Sea tobacco and cocoa grow on only a few islands. Whoever owns them all sets the prices. Your rivals have understood this as well, and this time they are more cunning.

Your orders:
- Secure the tobacco monopoly: a settlement of your own on EVERY island where tobacco grows, and no foreign one there.
- Secure the cocoa monopoly in the same way.
- Build a town with at least 600 residents, 300 of them citizens or higher.

The helmsman's advice: Send the "Morning Star" exploring at once and check the fertility in the island info. Native villages do not spoil a monopoly, rival settlements do.
'@ }
    }
    @{ Number = 33; BigIslandSize = 'Large'; Title = @{ de = 'Sturmsee 3 - Der Freihafen'; en = 'Storm Sea 3 - The Free Port' }; Difficulty = 2; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ Tobacco = 4; Cocoa = 4 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Hoffnung'; en = 'Hope' }; Cargo = @(@{ Good = 'Cloth'; Tons = 50 }, @{ Good = 'Liquor'; Tons = 50 }) })
        Mission = @{ TradeBalance = 400; Goods1 = @{ Good = 15; Tons = 40 }; Goods2 = @{ Good = 17; Tons = 40 } }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 3: Der Freihafen

Tabak und Kakao haben die Kompanie reich gemacht. Nun soll Eure Kolonie zum Freihafen der Sturmsee werden: ein Ort, an dem Händler aus aller Welt kaufen und verkaufen. Die Kompanie schickt Euch dazu die "Hoffnung", ein grosses Handelsschiff mit Stoffen und Alkohol an Bord. Einwohnerzahlen kümmern die Herren in Amsterdam diesmal nicht - nur die Zahlen in den Kontobüchern.

Euer Auftrag:
- Erreicht eine Handelsbilanz von mindestens +400 Talern: Eure Verkäufe müssen Eure Einkäufe deutlich übersteigen.
- Lagert mindestens 40 Tonnen Tabakwaren und 40 Tonnen Kakao in Euren Kontoren.

Rat des Steuermanns: Verkauft, was Ihr im Überfluss habt, und kauft nur, was Ihr wirklich braucht. Die Ladung der "Hoffnung" bringt gutes Geld - stellt sie im Kontor zum Verkauf.
'@; en = @'
THE STORM SEA - Chapter 3: The Free Port

Tobacco and cocoa have made the company rich. Now your colony is to become the free port of the Storm Sea: a place where traders from all over the world buy and sell. For this the company sends you the "Hope", a large trading ship with cloth and liquor on board. This time the gentlemen in Amsterdam care nothing for population figures - only for the figures in the ledgers.

Your orders:
- Reach a trade balance of at least +400 talers: your sales must clearly exceed your purchases.
- Store at least 40 tons of tobacco goods and 40 tons of cocoa in your warehouses.

The helmsman's advice: Sell what you have in abundance and buy only what you really need. The cargo of the "Hope" fetches good money - put it up for sale in the warehouse.
'@ }
    }
    @{ Number = 34; BigIslandSize = 'Large'; Title = @{ de = 'Sturmsee 4 - Die Rote Flagge'; en = 'Storm Sea 4 - The Red Flag' }; Difficulty = 2; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 35000; RivalGold = 30000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ OreSmall = 6; OreLarge = 9 }
        Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 40 }, @{ Good = 'Bricks'; Tons = 30 }, @{ Good = 'Cannons'; Tons = 10 })
        Fleet = @(@{ Type = 25; Name = @{ de = 'Wachhund'; en = 'Watchdog' } }, @{ Type = 25; Name = @{ de = 'Sturmvogel'; en = 'Storm Petrel' } })
        Mission = @{ TownCount = 3; AllTowns = @{ Residents = 300; Stage = 2; OfWhich = 100 } }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 4: Die Rote Flagge

Der Reichtum des Freihafens hat Geier angelockt. Piraten unter roter Flagge überfallen jedes Schiff zwischen den Inseln, und man munkelt, ein mächtiges Handelshaus bezahle sie. Die Kompanie schickt Euch zwei Kriegsschiffe und Kanonen für Wachtürme - halten müsst Ihr die Kolonie selbst.

Euer Auftrag:
- Gründet mindestens 3 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 300 Einwohner, davon 100 Bürger oder höher. Auch kleine Aussenposten zählen - eine Siedlung, die zurückbleibt, hält den Auftrag auf.

Rat des Steuermanns: Gründet nur Siedlungen, die Ihr auch zu Städten ausbauen wollt. Ein Wachturm braucht 2 Tonnen Kanonen - 10 Tonnen sind an Bord. Lasst die Handelsschiffe nie ohne Geleit fahren.
'@; en = @'
THE STORM SEA - Chapter 4: The Red Flag

The wealth of the free port has attracted vultures. Pirates under a red flag attack every ship between the islands, and rumour has it that a powerful trading house pays them. The company sends you two warships and cannons for watchtowers - but you must hold the colony yourself.

Your orders:
- Found at least 3 settlements of your own.
- EVERY one of your settlements needs at least 300 residents, 100 of them citizens or higher. Small outposts count too - a settlement that lags behind holds up the mission.

The helmsman's advice: Found only settlements you also want to grow into towns. A watchtower needs 2 tons of cannons - 10 tons are on board. Never let the trading ships sail without an escort.
'@ }
    }
    @{ Number = 35; BigIslandSize = 'Large'; Title = @{ de = 'Sturmsee 5 - Verrat'; en = 'Storm Sea 5 - Betrayal' }; Difficulty = 2; AI = 3; Layout = 0; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 40000; RivalGold = 20000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Rivals = @(@{ Player = 2; Gold = 60000; Name = @{ de = 'Haus Valcourt'; en = 'House Valcourt' }; Ship = @{ de = 'Valcourts Stolz'; en = 'Valcourt Pride' } })
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        Fleet = @(@{ Type = 27; Name = @{ de = 'Vergeltung'; en = 'Retribution' } }, @{ Type = 25; Name = @{ de = 'Falke'; en = 'Falcon' } })
        Mission = @{ Defeat = @(2); Towns = @(@{ Residents = 1000; Stage = 3; OfWhich = 400 }) }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 5: Verrat

Ein gefangener Piratenkapitän hat geredet: Das Haus Valcourt hat die Überfälle bezahlt, um Euch aus der Sturmsee zu vertreiben. Die beiden anderen Häuser wollen von dem Streit nichts wissen und haben sich für neutral erklärt - doch Neutralität ist in diesen Gewässern ein dehnbarer Begriff. Die Kompanie stellt Euch die "Vergeltung" zur Seite, ihr bestes Kriegsschiff.

Euer Auftrag:
- Besiegt das Haus Valcourt. Ihr erkennt es an seinem Flaggschiff, der "Valcourts Stolz". Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.
- Baut eine Stadt mit mindestens 1000 Einwohnern, davon 400 Kaufleute oder höher.

Die beiden anderen Rivalen müsst Ihr nicht besiegen.

Rat des Steuermanns: Valcourt ist reich und wird sich wehren. Sichert Euch Erz für Kanonen und Musketen, bevor Ihr angreift, und lasst Euch von den neutralen Häusern nicht in einen zweiten Krieg ziehen.
'@; en = @'
THE STORM SEA - Chapter 5: Betrayal

A captured pirate captain has talked: House Valcourt paid for the raids to drive you out of the Storm Sea. The other two houses want nothing to do with the quarrel and have declared themselves neutral - but in these waters neutrality is an elastic term. The company places the "Retribution" at your side, its best warship.

Your orders:
- Defeat House Valcourt. You will know it by its flagship, the "Valcourt Pride". A rival counts as defeated when he owns no settlement and no ship any more.
- Build a town with at least 1000 residents, 400 of them merchants or higher.

You do not have to defeat the other two rivals.

The helmsman's advice: Valcourt is rich and will fight back. Secure ore for cannons and muskets before you attack, and do not let the neutral houses drag you into a second war.
'@ }
    }
    @{ Number = 36; BigIslandSize = 'Huge'; BigVillages = 6; Title = @{ de = 'Sturmsee 6 - Das Goldene Zeitalter'; en = 'Storm Sea 6 - The Golden Age' }; Difficulty = 3; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 4
        Gold = 50000; RivalGold = 50000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3; Treasure = 10 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Morgenstern II'; en = 'Morning Star II' }; Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 50 }, @{ Good = 'Wood'; Tons = 40 }) }, @{ Type = 27; Name = 'Admiral' })
        Mission = @{ Towns = @(@{ Residents = 2000; Stage = 4; OfWhich = 800 }, @{ Residents = 1200; Stage = 3; OfWhich = 500 }); TotalResidents = 4000; Goods1 = @{ Good = 21; Tons = 40 }; Balance = 800 }
        Text = @{ de = @'
DIE STURMSEE - Kapitel 6: Das Goldene Zeitalter

Valcourt ist gefallen, die Piraten sind zerstreut, und die Sturmsee gehört den Mutigen. Der König will die Inseln unter einer Krone vereinen und sucht einen Herrscher, der ihnen ein goldenes Zeitalter schenkt. Die "Morgenstern II" bringt Werkzeug und Ziegel für den Aufbau, die "Admiral" schützt Eure Küsten. Doch die übrigen Häuser greifen nun selbst nach der Krone, und die Piraten sammeln sich ein letztes Mal.

Euer Auftrag:
- Eine Residenzstadt mit mindestens 2000 Einwohnern, davon 800 Aristokraten.
- Eine zweite Stadt mit mindestens 1200 Einwohnern, davon 500 Kaufleute oder höher.
- Alle Eure Siedlungen zusammen sollen mindestens 4000 Einwohner haben.
- Lagert mindestens 40 Tonnen Schmuck in Euren Kontoren.
- Eine Bilanz von mindestens +800 Talern.

Dies ist das letzte Kapitel der Sturmsee. Möge Euer Name in die Chroniken eingehen!
'@; en = @'
THE STORM SEA - Chapter 6: The Golden Age

Valcourt has fallen, the pirates are scattered, and the Storm Sea belongs to the bold. The King wants to unite the islands under one crown and seeks a ruler who will give them a golden age. The "Morning Star II" brings tools and bricks for the building work, the "Admiral" guards your coasts. But the remaining houses now reach for the crown themselves, and the pirates gather one last time.

Your orders:
- A residence city with at least 2000 residents, 800 of them aristocrats.
- A second town with at least 1200 residents, 500 of them merchants or higher.
- All your settlements together shall have at least 4000 residents.
- Store at least 40 tons of jewellery in your warehouses.
- A balance of at least +800 talers.

This is the last chapter of the Storm Sea. May your name enter the chronicles!
'@ }
    }

    # --- Campaign 4: Die Neue Welt (The New World), 2026-11-14 ------------------------------------
    # Exploration and natives: many villages (up to 5 + 5, big version 7 + 7 as in the patcher's -Natives Lots),
    # outposts on many islands, a monopoly of a crop that grows on few islands, huge islands shared with the
    # natives, a treasure fleet under pirate threat, one named rival (player 3, rich) who must fall while the
    # other two stay, finale with three towns in six settlements. Crop climates (FUN_1400d0ce0): tobacco,
    # sugar cane and wine only on climate 0 (north) islands, spices, cotton and cocoa only on climate 1 (south).
    @{ Number = 41; BigIslandSize = 'Normal'; BigVillages = 7; Title = @{ de = 'Neue Welt 1 - Die Ueberfahrt'; en = 'New World 1 - The Crossing' }; Difficulty = 0; AI = 0; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 2
        Gold = 35000; RivalGold = 15000; Pirates = $false; VillagesNorth = 4; VillagesSouth = 4
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Fleet = @(@{ Type = 21; Name = @{ de = 'Kundschafter'; en = 'Pathfinder' }; Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 30 }, @{ Good = 'Food'; Tons = 10 }) })
        Mission = @{ Towns = @(@{ Residents = 300; Stage = 1; OfWhich = 150 }); TownCount = 3; Balance = 0 }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 1: Die Überfahrt

Kommandant, vierzig Tage lang sahen wir nichts als Wasser. Nun liegt vor dem Bug eine Küste, die auf keiner Karte steht: die Neue Welt. Die Krone hat Euch an die Spitze dieser Expedition gestellt, mit der "Kompass" als Flaggschiff und dem kleinen "Kundschafter" für die Erkundung. Rauch steigt aus vielen Dörfern - dieses Land ist längst bewohnt.

Euer Auftrag:
- Gründet eine erste Stadt mit mindestens 300 Einwohnern, davon 150 Siedler oder höher.
- Errichtet Stützpunkte auf weiteren Inseln, damit die Kartographen die Küsten vermessen können: insgesamt mindestens 3 eigene Siedlungen.
- Haltet die Bilanz Eurer Kolonie im Plus.

Rat des Steuermanns: Schickt den "Kundschafter" voraus, während die "Kompass" Euer erstes Kontor baut - er hat Werkzeug und Holz für einen zweiten Stützpunkt an Bord. Die Ureinwohner sind friedlich, solange Ihr ihre Dörfer in Ruhe lasst.
'@; en = @'
THE NEW WORLD - Chapter 1: The Crossing

Commander, for forty days we saw nothing but water. Now a coast lies before the bow that is on no map: the New World. The Crown has placed you at the head of this expedition, with the "Compass" as flagship and the little "Pathfinder" for scouting. Smoke rises from many villages - this land has long been inhabited.

Your orders:
- Found a first town with at least 300 residents, 150 of them settlers or higher.
- Set up outposts on further islands so that the cartographers can survey the coasts: at least 3 settlements of your own in total.
- Keep the balance of your colony in the black.

The helmsman's advice: Send the "Pathfinder" ahead while the "Compass" builds your first warehouse - it carries tools and wood for a second outpost. The natives are peaceful as long as you leave their villages alone.
'@ }
    }
    @{ Number = 42; BigIslandSize = 'Normal'; BigVillages = 6; BigAmounts = @{ Sugar = 3 }; Title = @{ de = 'Neue Welt 2 - Zucker und Rum'; en = 'New World 2 - Sugar and Rum' }; Difficulty = 1; AI = 1; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 25000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 4
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Amounts = @{ Sugar = 2 }   # monopoly = all sugar cane islands (the game counts them at start)
        Mission = @{ Monopoly1 = @{ Resource = 0x30; Islands = 1 }; Goods1 = @{ Good = 18; Tons = 40 }; Towns = @(@{ Residents = 500; Stage = 2; OfWhich = 200 }) }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 2: Zucker und Rum

Die Kolonie steht, doch die Expedition hat die Krone ein Vermögen gekostet, und der Schatzmeister will Erträge sehen. Die Seeleute schwören auf den Rum der Neuen Welt, und die Hafenschänken der Alten Welt zahlen jeden Preis dafür. Zuckerrohr wächst in diesem Land aber nur auf ganz wenigen Inseln - wer sie alle hält, bestimmt den Preis.

Euer Auftrag:
- Sichert Euch das Zuckermonopol: eine eigene Siedlung auf JEDER Insel, auf der Zuckerrohr wächst, und keine fremde dort.
- Lagert mindestens 40 Tonnen Alkohol in Euren Kontoren.
- Baut eine Stadt mit mindestens 500 Einwohnern, davon 200 Bürger oder höher.

Rat des Steuermanns: Erkundet früh, welche Inseln Zuckerrohr tragen (Fruchtbarkeit im Inselinfo), und gründet dort Siedlungen, bevor es die Rivalen tun. Die Zuckerrohrplantage liefert Zucker, die Rumbrennerei macht daraus Alkohol - auch ein Weingut liefert Alkohol. Dörfer der Ureinwohner stören das Monopol nicht.
'@; en = @'
THE NEW WORLD - Chapter 2: Sugar and Rum

The colony stands, but the expedition has cost the Crown a fortune, and the Treasurer wants to see returns. Sailors swear by the rum of the New World, and the harbour taverns of the Old World pay any price for it. In this land, however, sugar cane grows on only a very few islands - whoever holds them all sets the price.

Your orders:
- Secure the sugar monopoly: a settlement of your own on EVERY island where sugar cane grows, and no foreign one there.
- Store at least 40 tons of liquor in your warehouses.
- Build a town with at least 500 residents, 200 of them citizens or higher.

The helmsman's advice: Find out early which islands bear sugar cane (fertility in the island info) and settle there before the rivals do. The sugarcane plantation yields sugar, the distillery turns it into liquor - a winery yields liquor as well. Native villages do not spoil the monopoly.
'@ }
    }
    @{ Number = 43; BigIslandSize = 'Large'; BigVillages = 7; Title = @{ de = 'Neue Welt 3 - Land der vielen Voelker'; en = 'New World 3 - Land of Many Peoples' }; Difficulty = 1; AI = 2; Layout = 0; MirrorX = $true; MirrorY = $true; Continents = @{ Lar = 4; Big = 5; Small = 4 }
        Gold = 35000; RivalGold = 30000; Pirates = $false; VillagesNorth = 5; VillagesSouth = 5
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Mission = @{ Towns = @(@{ Residents = 800; Stage = 3; OfWhich = 300 }); TownCount = 4; AllTowns = @{ Residents = 200; Stage = 1; OfWhich = 80 } }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 3: Land der vielen Völker

Hinter den Küsten liegen gewaltige Inseln, so gross, dass die Kundschafter tagelang marschieren - und überall stossen sie auf Dörfer. Die Krone hat entschieden: Die Völker dieses Landes sollen in Frieden leben. Die Kolonie soll zwischen ihren Dörfern wachsen, nicht auf ihren Trümmern. Auch die Rivalen haben auf den grossen Inseln Fuss gefasst.

Euer Auftrag:
- Eine Hauptstadt mit mindestens 800 Einwohnern, davon 300 Kaufleute oder höher.
- Mindestens 4 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 200 Einwohner, davon 80 Siedler oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!

Rat des Steuermanns: Die riesigen Inseln bieten Platz für Euch und Eure Rivalen, doch die besten Buchten sind schnell vergeben. Setzt Eure Kontore mit Bedacht und baut jede Siedlung zu einer richtigen kleinen Stadt aus.
'@; en = @'
THE NEW WORLD - Chapter 3: Land of Many Peoples

Beyond the coasts lie mighty islands, so vast that the scouts march for days - and everywhere they come upon villages. The Crown has decided: the peoples of this land shall live in peace. The colony is to grow between their villages, not on their ruins. The rivals, too, have gained a foothold on the great islands.

Your orders:
- A capital with at least 800 residents, 300 of them merchants or higher.
- At least 4 settlements of your own.
- EVERY one of your settlements needs at least 200 residents, 80 of them settlers or higher. Even a warehouse without houses counts as a settlement!

The helmsman's advice: The giant islands offer room for you and your rivals alike, but the best bays are taken quickly. Place your warehouses with care and build every settlement into a proper little town.
'@ }
    }
    @{ Number = 44; BigIslandSize = 'Large'; BigVillages = 6; Title = @{ de = 'Neue Welt 4 - Die Schatzflotte'; en = 'New World 4 - The Treasure Fleet' }; Difficulty = 2; AI = 2; Layout = 0; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 35000; RivalGold = 30000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Amounts = @{ Gold = 4; Spices = 3; OreSmall = 6; OreLarge = 9; Treasure = 12 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Galeone'; en = 'Galleon' }; Cargo = @(@{ Good = 'Tools'; Tons = 40 }, @{ Good = 'Bricks'; Tons = 30 }, @{ Good = 'Wood'; Tons = 30 }) }, @{ Type = 25; Name = @{ de = 'Wache'; en = 'Sentinel' } })
        Mission = @{ Goods1 = @{ Good = 16; Tons = 60 }; Goods2 = @{ Good = 3; Tons = 40 }; TradeBalance = 300 }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 4: Die Schatzflotte

Die Krone ist hoch verschuldet, und ihre Gläubiger werden ungeduldig. Im Frühjahr soll eine Schatzflotte in die Alte Welt segeln, beladen mit Gold aus den Bergen und den Gewürzen des heissen Südens. Doch die Kunde von den Schätzen hat sich herumgesprochen: Piraten kreuzen vor den Inseln.

Euer Auftrag:
- Lagert mindestens 60 Tonnen Gewürze und 40 Tonnen Gold in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +300 Talern: Eure Verkäufe müssen Eure Einkäufe deutlich übersteigen.

Rat des Steuermanns: Goldminen gibt es nur an wenigen Bergen, und sie lassen sich erst bauen, wenn Eure Stadt Bürger hat. Die "Galeone" bringt Werkzeug, Ziegel und Holz für den Aufbau, die "Wache" schützt sie. Lasst Eure Schiffe nie unbegleitet fahren.
'@; en = @'
THE NEW WORLD - Chapter 4: The Treasure Fleet

The Crown is deeply in debt, and its creditors are growing impatient. In spring a treasure fleet is to sail for the Old World, laden with gold from the mountains and the spices of the hot south. But word of the treasures has spread: pirates are cruising off the islands.

Your orders:
- Store at least 60 tons of spices and 40 tons of gold in your warehouses.
- Reach a trade balance of at least +300 talers: your sales must clearly exceed your purchases.

The helmsman's advice: Gold mines exist only at a few mountains, and you can build them only once your town has citizens. The "Galleon" brings tools, bricks and wood for the building work, the "Sentinel" protects it. Never let your ships sail unescorted.
'@ }
    }
    @{ Number = 45; BigIslandSize = 'Large'; BigVillages = 6; Title = @{ de = 'Neue Welt 5 - Der Konquistador'; en = 'New World 5 - The Conquistador' }; Difficulty = 2; AI = 3; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 40000; RivalGold = 20000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Rivals = @(@{ Player = 3; Gold = 70000; Name = @{ de = 'Haus Valdoro'; en = 'House Valdoro' }; Ship = @{ de = 'Valdoros Zorn'; en = 'Valdoro Wrath' } })
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 2 }
        Fleet = @(@{ Type = 27; Name = @{ de = 'Gerechtigkeit'; en = 'Justice' } }, @{ Type = 25; Name = @{ de = 'Sperber'; en = 'Sparrowhawk' } })
        Mission = @{ Defeat = @(3); TownCount = 4; TotalResidents = 2500 }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 5: Der Konquistador

Ein neues Haus ist in der Neuen Welt gelandet: das Haus Valdoro, reich, gierig und schwer bewaffnet. Seine Söldner brennen Dörfer nieder und vertreiben die Ureinwohner von ihren Inseln. Die Krone hat genug gesehen - sie stellt Euch die "Gerechtigkeit" zur Seite, ein schweres Kriegsschiff, und gibt Euch freie Hand.

Euer Auftrag:
- Besiegt das Haus Valdoro. Ihr erkennt es an seinem Flaggschiff, der "Valdoros Zorn". Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.
- Haltet mindestens 4 eigene Siedlungen.
- Alle Eure Siedlungen zusammen sollen mindestens 2500 Einwohner haben.

Die beiden anderen Rivalen müsst Ihr nicht besiegen.

Rat des Steuermanns: Valdoro hat mehr Gold als Ihr und baut schnell Burgen. Sichert Euch zuerst Erz für Kanonen und Schwerter, dann greift seine Kontore an. Ein Krieg gegen alle drei Häuser zugleich wäre Euer Ende.
'@; en = @'
THE NEW WORLD - Chapter 5: The Conquistador

A new house has landed in the New World: House Valdoro, rich, greedy and heavily armed. Its mercenaries burn villages and drive the natives from their islands. The Crown has seen enough - it places the "Justice", a heavy warship, at your side and gives you a free hand.

Your orders:
- Defeat House Valdoro. You will know it by its flagship, the "Valdoro Wrath". A rival counts as defeated when he owns no settlement and no ship any more.
- Hold at least 4 settlements of your own.
- All your settlements together shall have at least 2500 residents.

You do not have to defeat the other two rivals.

The helmsman's advice: Valdoro has more gold than you and builds castles quickly. First secure ore for cannons and swords, then attack his warehouses. A war against all three houses at once would be your end.
'@ }
    }
    @{ Number = 46; BigIslandSize = 'Huge'; BigVillages = 7; Title = @{ de = 'Neue Welt 6 - Der Vizekoenig'; en = 'New World 6 - The Viceroy' }; Difficulty = 3; AI = 3; Layout = 1; MirrorX = $true; MirrorY = $false; Enlarge = 4
        Gold = 50000; RivalGold = 50000; Pirates = $true; VillagesNorth = 4; VillagesSouth = 4
        ShipName = @{ de = 'Kompass'; en = 'Compass' }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3; Treasure = 10 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Kompass II'; en = 'Compass II' }; Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 50 }, @{ Good = 'Wood'; Tons = 40 }) }, @{ Type = 27; Name = @{ de = 'Krone'; en = 'Crown' } })
        Mission = @{ Towns = @(@{ Residents = 2000; Stage = 4; OfWhich = 800 }, @{ Residents = 1200; Stage = 3; OfWhich = 500 }, @{ Residents = 600; Stage = 2; OfWhich = 250 }); TownCount = 6; Balance = 800 }
        Text = @{ de = @'
DIE NEUE WELT - Kapitel 6: Der Vizekönig

Valdoro ist besiegt, und in der Neuen Welt herrscht Frieden - vorerst. Die Krone will das Land zu einem Vizekönigreich erheben, und Ihr sollt sein erster Vizekönig werden. Dafür braucht es eine Hauptstadt, die sich mit den Residenzen der Alten Welt messen kann, und Städte in allen Teilen des Landes. Doch die übrigen Häuser wollen sich nicht unterordnen, und Piraten lauern in den Meerengen.

Euer Auftrag:
- Eine Hauptstadt mit mindestens 2000 Einwohnern, davon 800 Aristokraten.
- Eine zweite Stadt mit mindestens 1200 Einwohnern, davon 500 Kaufleute oder höher.
- Eine dritte Stadt mit mindestens 600 Einwohnern, davon 250 Bürger oder höher.
- Mindestens 6 eigene Siedlungen.
- Eine Bilanz von mindestens +800 Talern.

Rat des Steuermanns: Die "Kompass II" bringt Werkzeug, Ziegel und Holz für die neuen Städte, die "Krone" schützt Eure Küsten.

Dies ist das letzte Kapitel der Neuen Welt. Möge Euer Name in die Chroniken eingehen!
'@; en = @'
THE NEW WORLD - Chapter 6: The Viceroy

Valdoro is defeated, and peace reigns in the New World - for now. The Crown wants to raise the land to a viceroyalty, and you are to be its first viceroy. That takes a capital that can match the residences of the Old World, and towns in every part of the land. But the remaining houses will not submit, and pirates lurk in the straits.

Your orders:
- A capital with at least 2000 residents, 800 of them aristocrats.
- A second town with at least 1200 residents, 500 of them merchants or higher.
- A third town with at least 600 residents, 250 of them citizens or higher.
- At least 6 settlements of your own.
- A balance of at least +800 talers.

The helmsman's advice: The "Compass II" brings tools, bricks and wood for the new towns, the "Crown" guards your coasts.

This is the last chapter of the New World. May your name enter the chronicles!
'@ }
    }

    # --- Campaign 5: Die Handelsliga (The Trade League), 2026-11-14 -------------------------------
    # Economy without war: the rivals are weak-willed (AI 0-2), every chapter asks for goods, trade balance or
    # profit: cloth and a first trade surplus, two goods from two climates, a network of settlements that all
    # have to grow, a cotton monopoly with clothes, a balance chapter, finale with jewellery and both balances.
    @{ Number = 51; BigIslandSize = 'Normal'; Title = @{ de = 'Handelsliga 1 - Das erste Kontor'; en = 'Trade League 1 - The First Warehouse' }; Difficulty = 0; AI = 0; Layout = 2; MirrorX = $false; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 15000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Mission = @{ Towns = @(@{ Residents = 250; Stage = 1; OfWhich = 120 }); Goods1 = @{ Good = 19; Tons = 30 }; TradeBalance = 100 }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 1: Das erste Kontor

Die Liga der Sieben Städte ist der mächtigste Kaufmannsbund der Alten Welt. Sie führt keine Kriege - sie führt Bücher. Nun schickt der Rat der Liga Euch, ihren jüngsten Faktor, über das Meer, um jenseits des Ozeans das erste Kontor der Liga zu gründen. Die Ratsherren wollen sehen, ob Ihr rechnen könnt.

Euer Auftrag:
- Gründet eine Stadt mit mindestens 250 Einwohnern, davon 120 Siedler oder höher.
- Lagert mindestens 30 Tonnen Stoffe in Euren Kontoren - die Tuchhändler der Liga warten darauf.
- Erreicht eine Handelsbilanz von mindestens +100 Talern: Verkauft mehr, als Ihr einkauft.

Rat des Steuermanns: Stoffe webt die Webstube aus Wolle, und die Wolle liefert die Schaffarm - beides könnt Ihr von Anfang an bauen. Stellt im Kontor zum Verkauf ein, was Ihr im Überfluss habt, und lasst die freien Händler kaufen.
'@; en = @'
THE TRADE LEAGUE - Chapter 1: The First Warehouse

The League of the Seven Cities is the mightiest merchant alliance of the Old World. It wages no wars - it keeps ledgers. Now the League's council sends you, its youngest factor, across the sea to found the League's first warehouse beyond the ocean. The councillors want to see whether you can count.

Your orders:
- Found a town with at least 250 residents, 120 of them settlers or higher.
- Store at least 30 tons of cloth in your warehouses - the League's drapers are waiting for it.
- Reach a trade balance of at least +100 talers: sell more than you buy.

The helmsman's advice: The weaver's hut weaves cloth from wool, and the sheep farm supplies the wool - you can build both from the start. Put up for sale in the warehouse what you have in abundance, and let the free traders buy.
'@ }
    }
    @{ Number = 52; BigIslandSize = 'Normal'; BigAmounts = @{ Tobacco = 6; Spices = 6 }; Title = @{ de = 'Handelsliga 2 - Markttag'; en = 'Trade League 2 - Market Day' }; Difficulty = 1; AI = 1; Layout = 0; MirrorX = $true; MirrorY = $true; Enlarge = 2
        Gold = 30000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 3
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Amounts = @{ Tobacco = 3; Spices = 3 }
        Fleet = @(@{ Type = 21; Name = @{ de = 'Bote'; en = 'Courier' } })
        Mission = @{ Towns = @(@{ Residents = 500; Stage = 2; OfWhich = 200 }); Goods1 = @{ Good = 15; Tons = 40 }; Goods2 = @{ Good = 16; Tons = 40 } }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 2: Markttag

Euer erstes Kontor hat den Rat überzeugt. Nun soll in der Neuen Welt ein Markt entstehen, auf dem die Schiffe der Liga alles finden, was in den Städten der Alten Welt Geld bringt: Tabakwaren für die Kontorstuben und Gewürze für die Tafeln der Reichen. Tabak und Gewürze wachsen aber in verschiedenen Klimazonen - eine einzige Insel genügt nicht.

Euer Auftrag:
- Baut eine Stadt mit mindestens 500 Einwohnern, davon 200 Bürger oder höher.
- Lagert mindestens 40 Tonnen Tabakwaren und 40 Tonnen Gewürze in Euren Kontoren.

Rat des Steuermanns: Prüft die Fruchtbarkeit im Inselinfo und gründet eine zweite Siedlung dort, wo wächst, was Eurer Hauptinsel fehlt. Die "Bote" kann auf einer Handelsroute die Ernte heimbringen.
'@; en = @'
THE TRADE LEAGUE - Chapter 2: Market Day

Your first warehouse has convinced the council. Now a market is to arise in the New World where the League's ships find everything that brings money in the towns of the Old World: tobacco goods for the counting houses and spices for the tables of the rich. But tobacco and spices grow in different climates - a single island will not do.

Your orders:
- Build a town with at least 500 residents, 200 of them citizens or higher.
- Store at least 40 tons of tobacco goods and 40 tons of spices in your warehouses.

The helmsman's advice: Check the fertility in the island info and found a second settlement where the crops grow that your main island lacks. The "Courier" can bring the harvest home on a trade route.
'@ }
    }
    @{ Number = 53; BigIslandSize = 'Normal'; Title = @{ de = 'Handelsliga 3 - Das Kontornetz'; en = 'Trade League 3 - The Warehouse Network' }; Difficulty = 1; AI = 1; Layout = 1; MirrorX = $false; MirrorY = $true; AddIslands = 30; AddClasses = @(1, 2)
        Gold = 35000; RivalGold = 25000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Food'; Tons = 20 }, @{ Good = 'Bricks'; Tons = 20 })
        Fleet = @(@{ Type = 21; Name = @{ de = 'Möwe'; en = 'Gull' }; Cargo = @(@{ Good = 'Tools'; Tons = 40 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Food'; Tons = 20 }) })
        Mission = @{ TownCount = 6; AllTowns = @{ Residents = 150; Stage = 1; OfWhich = 60 }; TradeBalance = 200 }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 3: Das Kontornetz

Ein Markt allein macht noch keinen Handel. Der Rat will ein Netz von Kontoren über diesen Archipel spannen, damit die Schiffe der Liga in jeder Bucht Ladung finden. Die Inseln sind zahlreich, aber die meisten sind klein - und jede Niederlassung soll eine Stadt sein, auf die die Liga stolz sein kann, kein verlassener Bretterverschlag.

Euer Auftrag:
- Gründet mindestens 6 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 150 Einwohner, davon 60 Siedler oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!
- Erreicht eine Handelsbilanz von mindestens +200 Talern.

Rat des Steuermanns: Die "Möwe" bringt zusätzliches Werkzeug und Holz für die neuen Kontore. Jede kleine Stadt braucht ihren eigenen Marktplatz und ihre Waren - richtet Handelsrouten ein, damit keine Siedlung zurückbleibt.
'@; en = @'
THE TRADE LEAGUE - Chapter 3: The Warehouse Network

A market alone does not make trade. The council wants to spread a network of warehouses across this archipelago, so that the League's ships find cargo in every bay. The islands are many, but most of them are small - and every branch is to be a town the League can be proud of, not an abandoned shack.

Your orders:
- Found at least 6 settlements of your own.
- EVERY one of your settlements needs at least 150 residents, 60 of them settlers or higher. Even a warehouse without houses counts as a settlement!
- Reach a trade balance of at least +200 talers.

The helmsman's advice: The "Gull" brings extra tools and wood for the new warehouses. Every small town needs its own marketplace and its goods - set up trade routes so that no settlement falls behind.
'@ }
    }
    @{ Number = 54; BigIslandSize = 'Large'; BigAmounts = @{ Cotton = 3 }; Title = @{ de = 'Handelsliga 4 - Das Baumwollkartell'; en = 'Trade League 4 - The Cotton Cartel' }; Difficulty = 2; AI = 2; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 35000; RivalGold = 30000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Amounts = @{ Cotton = 2 }   # monopoly = all cotton islands
        Fleet = @(@{ Type = 25; Name = @{ de = 'Wächterin'; en = 'Warden' } })
        Mission = @{ Monopoly1 = @{ Resource = 0x31; Islands = 1 }; Goods1 = @{ Good = 20; Tons = 50 }; TradeBalance = 300 }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 4: Das Baumwollkartell

Die Tuchmacher der Sieben Städte verlangen nach Baumwolle, und die Liga will diesen Handel ganz in ihrer Hand. Baumwolle wächst nur auf wenigen Inseln des Südens. Wer sie alle besitzt, bestimmt den Preis jeder Elle Tuch - und jedes Gewandes, das daraus genäht wird. Die Gewinne locken allerdings auch Piraten an.

Euer Auftrag:
- Sichert Euch das Baumwollmonopol: eine eigene Siedlung auf JEDER Insel, auf der Baumwolle wächst, und keine fremde dort.
- Lagert mindestens 50 Tonnen Kleidung in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +300 Talern.

Rat des Steuermanns: Baumwollplantagen und Schneidereien lassen sich erst bauen, wenn Eure Stadt Bürger hat. Die Baumwollplantage liefert Wolle, die Webstube webt daraus Stoffe, die Schneiderei näht Kleidung. Die "Wächterin" begleitet Eure Handelsschiffe.
'@; en = @'
THE TRADE LEAGUE - Chapter 4: The Cotton Cartel

The clothmakers of the Seven Cities clamour for cotton, and the League wants this trade entirely in its own hands. Cotton grows on only a few islands of the south. Whoever owns them all sets the price of every yard of cloth - and of every garment sewn from it. But the profits lure pirates as well.

Your orders:
- Secure the cotton monopoly: a settlement of your own on EVERY island where cotton grows, and no foreign one there.
- Store at least 50 tons of clothes in your warehouses.
- Reach a trade balance of at least +300 talers.

The helmsman's advice: Cotton plantations and tailor's shops can only be built once your town has citizens. The cotton plantation yields wool, the weaver's hut weaves it into cloth, the tailor's shop sews clothes. The "Warden" escorts your trading ships.
'@ }
    }
    @{ Number = 55; BigIslandSize = 'Large'; Title = @{ de = 'Handelsliga 5 - Die Bank der Liga'; en = 'Trade League 5 - The League Bank' }; Difficulty = 2; AI = 2; Layout = 0; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 35000; RivalGold = 35000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Amounts = @{ Tobacco = 3; Spices = 3; Cocoa = 3 }
        Mission = @{ Towns = @(@{ Residents = 1200; Stage = 3; OfWhich = 600 }); Balance = 500; TradeBalance = 400 }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 5: Die Bank der Liga

Die Liga will in der Neuen Welt eine eigene Bank gründen, die Pflanzern und Kapitänen Geld leiht. Dafür braucht sie eine reiche Kaufmannsstadt und einen Faktor, dessen Bücher stets schwarze Zahlen zeigen. Der Rat wird jeden Taler prüfen.

Euer Auftrag:
- Eine Kaufmannsstadt mit mindestens 1200 Einwohnern, davon 600 Kaufleute oder höher.
- Eine Bilanz von mindestens +500 Talern.
- Eine Handelsbilanz von mindestens +400 Talern.

Rat des Steuermanns: Kaufleute zahlen gute Steuern, aber sie verlangen Stoffe, Alkohol, Kakao, Tabakwaren und Gewürze. Baut nur, was Ihr braucht - jeder Betrieb kostet Unterhalt. Überschüsse verkauft Ihr im Kontor.
'@; en = @'
THE TRADE LEAGUE - Chapter 5: The League Bank

The League wants to found a bank of its own in the New World that lends money to planters and captains. For that it needs a rich merchant city and a factor whose ledgers are always in the black. The council will check every taler.

Your orders:
- A merchant city with at least 1200 residents, 600 of them merchants or higher.
- A balance of at least +500 talers.
- A trade balance of at least +400 talers.

The helmsman's advice: Merchants pay good taxes, but they demand cloth, liquor, cocoa, tobacco goods and spices. Build only what you need - every workshop costs upkeep. Sell your surpluses in the warehouse.
'@ }
    }
    @{ Number = 56; BigIslandSize = 'Huge'; BigVillages = 6; Title = @{ de = 'Handelsliga 6 - Der Fuerst der Kaufleute'; en = 'Trade League 6 - The Merchant Prince' }; Difficulty = 3; AI = 2; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 4
        Gold = 50000; RivalGold = 45000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Kaufmannsglück'; en = "Merchant's Luck" }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3; Treasure = 8 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Kaufmannsglück II'; en = "Merchant's Luck II" }; Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 50 }, @{ Good = 'Wood'; Tons = 40 }) }, @{ Type = 27; Name = @{ de = 'Löwe'; en = 'Lion' } })
        Mission = @{ Towns = @(@{ Residents = 2000; Stage = 4; OfWhich = 700 }); Goods1 = @{ Good = 21; Tons = 50 }; TradeBalance = 500; Balance = 800 }
        Text = @{ de = @'
DIE HANDELSLIGA - Kapitel 6: Der Fürst der Kaufleute

Der alte Vorsteher der Liga legt sein Amt nieder, und der Rat wählt seinen Nachfolger nicht nach Herkunft, sondern nach Vermögen. Wer die prächtigste Stadt, die vollsten Schatzkammern und die besten Bücher vorweist, wird Fürst der Kaufleute. Die anderen Häuser neiden Euch den Erfolg - und die Piraten wollen Eure Ladung.

Euer Auftrag:
- Eine Residenzstadt mit mindestens 2000 Einwohnern, davon 700 Aristokraten.
- Lagert mindestens 50 Tonnen Schmuck in Euren Kontoren.
- Eine Handelsbilanz von mindestens +500 Talern.
- Eine Bilanz von mindestens +800 Talern.

Rat des Steuermanns: Schmuck verlangt Gold aus den Bergen und eine Goldschmiede, die erst Kaufleute bauen können. Die "Kaufmannsglück II" bringt Werkzeug, Ziegel und Holz, der "Löwe" schützt Eure Küsten.

Dies ist das letzte Kapitel der Handelsliga. Möge Euer Name in die Chroniken eingehen!
'@; en = @'
THE TRADE LEAGUE - Chapter 6: The Merchant Prince

The old head of the League is stepping down, and the council chooses his successor not by birth but by fortune. Whoever shows the most splendid city, the fullest treasuries and the best ledgers will become Merchant Prince. The other houses begrudge you your success - and the pirates want your cargo.

Your orders:
- A residence city with at least 2000 residents, 700 of them aristocrats.
- Store at least 50 tons of jewellery in your warehouses.
- A trade balance of at least +500 talers.
- A balance of at least +800 talers.

The helmsman's advice: Jewellery needs gold from the mountains and a goldsmith, which only merchants can build. The "Merchant's Luck II" brings tools, bricks and wood, the "Lion" guards your coasts.

This is the last chapter of the Trade League. May your name enter the chronicles!
'@ }
    }

    # --- Challenges 2026-11-14: two monopolies in two climates, two monopolies against strong rivals,
    # a calm sea with poor islands and rich rivals, a start with almost nothing.
    @{ Number = 61; BigIslandSize = 'Large'; BigAmounts = @{ Wine = 3; Cocoa = 3 }; Title = @{ de = 'Herausforderung - Kolonialherr'; en = 'Challenge - Colonial Lord' }; Difficulty = 2; AI = 2; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 35000; RivalGold = 30000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ Wine = 2; Cocoa = 2 }   # wine only on northern, cocoa only on southern islands
        Mission = @{ Monopoly1 = @{ Resource = 0x32; Islands = 1 }; Monopoly2 = @{ Resource = 0x33; Islands = 1 }; TownCount = 4; AllTowns = @{ Residents = 250; Stage = 2; OfWhich = 80 } }
        Text = @{ de = @'
HERAUSFORDERUNG: Kolonialherr

Ein wahrer Kolonialherr gebietet über den kühlen Norden ebenso wie über den heissen Süden. Die Krone verlangt von Euch beides: den Wein des Nordens und den Kakao des Südens - ganz in Eurer Hand, und jede Eurer Siedlungen eine blühende Stadt.

Euer Auftrag:
- Sichert Euch das Weinmonopol: eine eigene Siedlung auf JEDER Insel, auf der Wein wächst, und keine fremde dort.
- Sichert Euch ebenso das Kakaomonopol.
- Gründet mindestens 4 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 250 Einwohner, davon 80 Bürger oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!

Rat des Steuermanns: Wein und Kakao wachsen nie auf derselben Insel. Jede Monopolinsel muss zu einer Stadt mit Bürgern werden - gründet keine Siedlung, die Ihr nicht ausbauen wollt. Dörfer der Ureinwohner stören ein Monopol nicht.
'@; en = @'
CHALLENGE: Colonial Lord

A true colonial lord commands the cool north as well as the hot south. The Crown demands both of you: the wine of the north and the cocoa of the south - entirely in your hands, and every one of your settlements a flourishing town.

Your orders:
- Secure the wine monopoly: a settlement of your own on EVERY island where wine grows, and no foreign one there.
- Secure the cocoa monopoly in the same way.
- Found at least 4 settlements of your own.
- EVERY one of your settlements needs at least 250 residents, 80 of them citizens or higher. Even a warehouse without houses counts as a settlement!

The helmsman's advice: Wine and cocoa never grow on the same island. Every monopoly island must become a town with citizens - found no settlement you do not intend to expand. Native villages do not spoil a monopoly.
'@ }
    }
    @{ Number = 62; BigIslandSize = 'Large'; BigAmounts = @{ Spices = 3; Tobacco = 3 }; Title = @{ de = 'Herausforderung - Monopolist'; en = 'Challenge - Monopolist' }; Difficulty = 2; AI = 3; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 40000; RivalGold = 50000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ Spices = 2; Tobacco = 2; OreSmall = 6; OreLarge = 9 }
        Fleet = @(@{ Type = 27; Name = @{ de = 'Faust'; en = 'Iron Fist' } })
        Mission = @{ Monopoly1 = @{ Resource = 0x2F; Islands = 1 }; Monopoly2 = @{ Resource = 0x2E; Islands = 1 }; TradeBalance = 400 }
        Text = @{ de = @'
HERAUSFORDERUNG: Monopolist

Wer alles besitzt, verkauft teuer. Auf diesen Inseln wachsen Gewürze und Tabak nur an wenigen Orten, und drei gierige Häuser wissen das so gut wie Ihr. Sie sind reich, schnell und rücksichtslos.

Euer Auftrag:
- Sichert Euch das Gewürzmonopol: eine eigene Siedlung auf JEDER Insel, auf der Gewürze wachsen, und keine fremde dort.
- Sichert Euch ebenso das Tabakmonopol.
- Erreicht eine Handelsbilanz von mindestens +400 Talern: Verkauft, was nur Ihr anbieten könnt.

Rat des Steuermanns: Die Rivalen greifen ebenfalls nach den Monopolinseln. Erkundet sofort und setzt Eure Kontore, bevor sie es tun - sonst müsst Ihr eine fremde Siedlung auf einer solchen Insel erobern. Die "Faust" ist dafür gerüstet.
'@; en = @'
CHALLENGE: Monopolist

Whoever owns everything sells dear. On these islands spices and tobacco grow in only a few places, and three greedy houses know that as well as you do. They are rich, quick and ruthless.

Your orders:
- Secure the spice monopoly: a settlement of your own on EVERY island where spices grow, and no foreign one there.
- Secure the tobacco monopoly in the same way.
- Reach a trade balance of at least +400 talers: sell what only you can offer.

The helmsman's advice: The rivals reach for the monopoly islands too. Explore at once and place your warehouses before they do - otherwise you will have to conquer a foreign settlement on such an island. The "Iron Fist" is armed for that.
'@ }
    }
    @{ Number = 63; BigIslandSize = 'Normal'; Title = @{ de = 'Herausforderung - Ruhige See'; en = 'Challenge - Calm Seas' }; Difficulty = 3; AI = 3; Layout = 2; MirrorX = $true; MirrorY = $true; Enlarge = 2
        Gold = 25000; RivalGold = 60000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        Amounts = @{ OreSmall = 2; OreLarge = 3; Gold = 1; Treasure = 2; Tobacco = 2; Spices = 2; Sugar = 2; Cotton = 2; Wine = 2; Cocoa = 2 }
        BigAmounts = @{ OreSmall = 4; OreLarge = 6; Gold = 2; Treasure = 4; Tobacco = 3; Spices = 3; Sugar = 3; Cotton = 3; Wine = 3; Cocoa = 3 }
        Mission = @{ Towns = @(@{ Residents = 1200; Stage = 3; OfWhich = 500 }); TotalResidents = 2500; Balance = 300 }
        Text = @{ de = @'
HERAUSFORDERUNG: Ruhige See

Kein Pirat weit und breit, kein Sturm am Horizont - eine ruhige See. Doch die Ruhe täuscht: Die Inseln sind karg, Erz und Gold sind rar, und die drei Rivalen sind reich, erfahren und hungrig nach jedem Fleck Land.

Euer Auftrag:
- Eine Stadt mit mindestens 1200 Einwohnern, davon 500 Kaufleute oder höher.
- Alle Eure Siedlungen zusammen sollen mindestens 2500 Einwohner haben.
- Eine Bilanz von mindestens +300 Talern.

Rat des Steuermanns: Sichert Euch früh eine Insel mit Erz - ohne Werkzeug wächst keine Stadt. Was Euch fehlt, kauft Ihr bei den freien Händlern, aber jeder Taler zählt.
'@; en = @'
CHALLENGE: Calm Seas

Not a pirate far and wide, not a storm on the horizon - a calm sea. But the calm is deceptive: the islands are barren, ore and gold are scarce, and the three rivals are rich, experienced and hungry for every patch of land.

Your orders:
- A town with at least 1200 residents, 500 of them merchants or higher.
- All your settlements together shall have at least 2500 residents.
- A balance of at least +300 talers.

The helmsman's advice: Secure an island with ore early - without tools no town grows. Whatever you lack you can buy from the free traders, but every taler counts.
'@ }
    }
    @{ Number = 64; BigIslandSize = 'Normal'; Title = @{ de = 'Herausforderung - Habenichts'; en = 'Challenge - Shoestring' }; Difficulty = 1; AI = 2; Layout = 0; MirrorX = $true; MirrorY = $true; Enlarge = 2
        Gold = 8000; RivalGold = 35000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Letzter Taler'; en = 'Last Taler' }
        Cargo = @(@{ Good = 'Tools'; Tons = 15 }, @{ Good = 'Wood'; Tons = 10 }, @{ Good = 'Food'; Tons = 5 })
        Mission = @{ Towns = @(@{ Residents = 600; Stage = 2; OfWhich = 250 }); Balance = 200 }
        Text = @{ de = @'
HERAUSFORDERUNG: Habenichts

Die Kompanie ist bankrott, ihre Gläubiger haben alles gepfändet - nur nicht Euer kleines Schiff, die "Letzter Taler". Mit 8000 Talern, ein paar Tonnen Werkzeug und viel Mut wagt Ihr den Neuanfang. Die Rivalen haben volle Kassen und lachen über Euch.

Euer Auftrag:
- Baut eine Stadt mit mindestens 600 Einwohnern, davon 250 Bürger oder höher.
- Eine Bilanz von mindestens +200 Talern.

Rat des Steuermanns: An Bord sind nur 15 Tonnen Werkzeug, 10 Tonnen Holz und 5 Tonnen Proviant. Baut nach dem Kontor zuerst Forsthäuser - sie kosten kein Holz -, dann Fischerhütten, und keine Prachtbauten. Verkauft jeden Überschuss an die freien Händler und baut erst, wenn die Kasse es erlaubt.
'@; en = @'
CHALLENGE: Shoestring

The company is bankrupt, its creditors have seized everything - except your little ship, the "Last Taler". With 8000 talers, a few tons of tools and plenty of courage you dare a fresh start. The rivals have full coffers and laugh at you.

Your orders:
- Build a town with at least 600 residents, 250 of them citizens or higher.
- A balance of at least +200 talers.

The helmsman's advice: On board are only 15 tons of tools, 10 tons of wood and 5 tons of provisions. After the warehouse build forester's huts first - they cost no wood -, then fisher's huts, and no grand buildings. Sell every surplus to the free traders and build only when the coffers allow it.
'@ }
    }

    # --- Challenges with a time limit (3.0.0): only with the extensions (the patcher's TIMERS hook sets the limit).
    @{ Number = 65; BigIslandSize = 'Normal'; Title = @{ de = 'Herausforderung - Gegen die Uhr'; en = 'Challenge - Against the Clock' }; Difficulty = 1; AI = 1; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 2
        Gold = 30000; RivalGold = 20000; Pirates = $false; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Sanduhr'; en = 'Hourglass' }
        TimeLimitHours = 3
        Mission = @{ Towns = @(@{ Residents = 500; Stage = 1; OfWhich = 250 }) }
        Text = @{ de = @'
HERAUSFORDERUNG: Gegen die Uhr

Der Gouverneur hat eine tollkühne Wette abgeschlossen: In nur drei Stunden, so prahlte er beim Bankett, baut Ihr auf diesen Inseln eine Stadt, die sich sehen lassen kann. Gewinnt Ihr, ist Euch seine Gunst sicher. Verliert Ihr, verliert er ein Vermögen - und Ihr Euer Amt.

Euer Auftrag:
- Eine Stadt mit mindestens 500 Einwohnern, davon 250 Siedler oder höher.
- Zeitlimit: 3 Stunden. Die Uhr zeigt die verstrichene Spielzeit; bei 180:00 ist die Mission verloren.

Rat des Steuermanns: Das Zeitlimit gilt nur, wenn Ihr mit den Anno 1602 Erweiterungen spielt; das Logbuch zeigt Euch die verbleibende Zeit. Gründet sofort, baut Fischerhütten, Schaffarmen und eine Webstube vor allem anderen und lasst Euch von keinem Prachtbau ablenken. Pausieren hält die Uhr an, der Turbo lässt sie schneller laufen.
'@; en = @'
CHALLENGE: Against the Clock

The governor has made a reckless wager: in just three hours, he boasted at the banquet, you would build a town on these islands worth seeing. Win, and his favour is yours. Lose, and he loses a fortune - and you your post.

Your orders:
- A town with at least 500 residents, 250 of them settlers or higher.
- Time limit: 3 hours. The clock shows the elapsed game time; at 180:00 the mission is lost.

The helmsman's advice: The time limit only applies when you play with the Anno 1602 Extensions; the logbook shows you the time left. Found your town at once, build fisher's huts, sheep farms and a weaver's hut before anything else and let no grand building distract you. Pausing stops the clock, the turbo makes it run faster.
'@ }
    }
    @{ Number = 66; BigIslandSize = 'Large'; Title = @{ de = 'Herausforderung - Die Frist des Koenigs'; en = 'Challenge - The Royal Deadline' }; Difficulty = 2; AI = 2; Layout = 2; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 30000; RivalGold = 30000; Pirates = $true; VillagesNorth = 2; VillagesSouth = 2
        ShipName = @{ de = 'Königsbote'; en = 'Royal Courier' }
        Fleet = @(@{ Type = 25; Name = @{ de = 'Siegel'; en = 'Royal Seal' } })
        TimeLimitHours = 6
        Mission = @{ Towns = @(@{ Residents = 1000; Stage = 2; OfWhich = 400 }); Balance = 300 }
        Text = @{ de = @'
HERAUSFORDERUNG: Die Frist des Königs

Ein Brief mit dem königlichen Siegel: Seine Majestät wünscht, dass auf diesen Inseln binnen sechs Stunden eine wohlhabende Bürgerstadt entsteht, die ihre Steuern pünktlich zahlt. Drei Rivalen hoffen auf Euer Scheitern - und Piraten lauern auf jedes beladene Schiff.

Euer Auftrag:
- Eine Stadt mit mindestens 1000 Einwohnern, davon 400 Bürger oder höher.
- Eine Bilanz von mindestens +300 Talern.
- Zeitlimit: 6 Stunden. Die Uhr zeigt die verstrichene Spielzeit; bei 360:00 ist die Mission verloren.

Rat des Steuermanns: Das Zeitlimit gilt nur, wenn Ihr mit den Anno 1602 Erweiterungen spielt; das Logbuch zeigt Euch die verbleibende Zeit. Eine zweite Insel mit anderem Klima liefert, was Eure Bürger verlangen. Das "Siegel" begleitet Eure Handelsschiffe - die Piraten warten nicht.
'@; en = @'
CHALLENGE: The Royal Deadline

A letter bearing the royal seal: His Majesty wishes a prosperous town of citizens to rise on these islands within six hours, one that pays its taxes on time. Three rivals hope you will fail - and pirates lie in wait for every laden ship.

Your orders:
- A town with at least 1000 residents, 400 of them citizens or higher.
- A balance of at least +300 talers.
- Time limit: 6 hours. The clock shows the elapsed game time; at 360:00 the mission is lost.

The helmsman's advice: The time limit only applies when you play with the Anno 1602 Extensions; the logbook shows you the time left. A second island with another climate supplies what your citizens demand. The "Royal Seal" escorts your trading ships - the pirates will not wait.
'@ }
    }

    # --- Campaign 6: Das Weltreich (The World Empire), 2026-11-15 ---------------------------------------
    # Made for the giant world (key Giant: 50 islands in five realms on 2000 x 1400, see Get-GiantPlan); the big
    # version (1000 x 700, Huge) and the small map stay as with every scenario. Home realm in the north-west around
    # the starting ships; cloth and tobacco from the north-east, spices from the far south, two crop monopolies in
    # the south, a war against one named house, finale with three towns, seven settlements and 8000 residents.
    @{ Number = 71; BigIslandSize = 'Huge'; BigVillages = 6; Giant = @{ Villages = 6 }; Title = @{ de = 'Weltreich 1 - Die grosse Fahrt'; en = 'World Empire 1 - The Great Voyage' }; Difficulty = 0; AI = 0; Layout = 0; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 40000; RivalGold = 15000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Fernweh'; en = 'Wanderlust' }; Cargo = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 40 }, @{ Good = 'Food'; Tons = 20 }) })
        Mission = @{ Towns = @(@{ Residents = 500; Stage = 1; OfWhich = 250 }); TownCount = 3; TotalResidents = 900 }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 1: Die grosse Fahrt

Kapitän, die Krone schickt Euch auf die grösste Reise, die je ein Schiff gewagt hat: hinaus auf ein Meer, so weit, dass selbst die kühnsten Kartographen aufgeben. Fünf Inselreiche sollen dort liegen, getrennt durch Wochen auf offener See - die Kronsee hier im Nordwesten, das Nebelmeer im fernen Nordosten, die Mittelsee, die Korallensee im Süden und ganz im Südosten die sagenhaften Gewürzinseln. Wer sie alle verbindet, wird ein Weltreich regieren.

Euer Auftrag:
- Gründet eine erste Stadt mit mindestens 500 Einwohnern, davon 250 Siedler oder höher.
- Mindestens 3 eigene Siedlungen.
- Alle Eure Siedlungen zusammen sollen mindestens 900 Einwohner haben.

Rat des Steuermanns: Diese Kampagne ist für die Riesenwelt gebaut - spielt sie mit den Anno 1602 Erweiterungen in der Kartengrösse Riesig (2000 x 1400), am einfachsten mit dem Knopf "Riesenwelt" im Starter. Die "Fernweh" hat Werkzeug, Holz und Nahrung für eine zweite Siedlung an Bord. Erkundet zuerst die Kronsee, bevor Ihr in die Ferne segelt.
'@; en = @'
THE WORLD EMPIRE - Chapter 1: The Great Voyage

Captain, the Crown is sending you on the greatest voyage any ship has ever dared: out onto a sea so vast that even the boldest cartographers give up. Five island realms are said to lie there, weeks of open sea apart - the Crown Sea here in the north-west, the Mist Sea in the far north-east, the Middle Sea, the Coral Sea in the south and, far in the south-east, the fabled Spice Islands. Whoever links them all will rule a world empire.

Your orders:
- Found a first town with at least 500 residents, 250 of them settlers or higher.
- At least 3 settlements of your own.
- All your settlements together shall have at least 900 residents.

The helmsman's advice: This campaign is made for the giant world - play it with the Anno 1602 Extensions at map size Huge (2000 x 1400), easiest with the "Giant world" button in the launcher. The "Wanderlust" carries tools, wood and food for a second settlement. Explore the Crown Sea first, before you sail far away.
'@ }
    }
    @{ Number = 72; BigIslandSize = 'Huge'; BigVillages = 6; BigAmounts = @{ Tobacco = 5 }; Giant = @{ Villages = 6; Amounts = @{ Tobacco = 8 } }; Title = @{ de = 'Weltreich 2 - Das Nebelmeer'; en = 'World Empire 2 - The Mist Sea' }; Difficulty = 1; AI = 1; Layout = 1; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 35000; RivalGold = 25000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ Tobacco = 3 }
        Fleet = @(@{ Type = 21; Name = @{ de = 'Nordlicht'; en = 'Northern Light' }; Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 30 }) })
        Mission = @{ Goods1 = @{ Good = 19; Tons = 50 }; Goods2 = @{ Good = 15; Tons = 40 }; Towns = @(@{ Residents = 800; Stage = 2; OfWhich = 300 }); TownCount = 4 }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 2: Das Nebelmeer

Weit im Osten, hinter Wochen auf offener See, liegt das Nebelmeer: kühle Inseln voller Wälder und Weiden, auf denen der beste Tabak der Welt wächst. Die Krone braucht Stoffe für ihre Flotte und Tabakwaren für ihre Höflinge - und Ihr sollt die Brücke über das Meer schlagen. Auch die Rivalen haben ihre Schiffe nach Osten geschickt.

Euer Auftrag:
- Lagert mindestens 50 Tonnen Stoffe und 40 Tonnen Tabakwaren in Euren Kontoren.
- Eine Stadt mit mindestens 800 Einwohnern, davon 300 Bürger oder höher.
- Mindestens 4 eigene Siedlungen.

Rat des Steuermanns: In der Riesenwelt (2000 x 1400, mit den Erweiterungen) liegt das Nebelmeer im Nordosten, weit weg von der Kronsee. Ein Kontor dort spart Euren Schiffen die lange Reise: Lasst Tabak und Wolle vor Ort verarbeiten und holt nur die fertigen Waren heim. Die "Nordlicht" bringt Werkzeug und Holz für den Aufbau.
'@; en = @'
THE WORLD EMPIRE - Chapter 2: The Mist Sea

Far to the east, beyond weeks of open sea, lies the Mist Sea: cool islands full of forests and pastures, where the finest tobacco in the world grows. The Crown needs cloth for its fleet and tobacco goods for its courtiers - and you are to bridge the sea. The rivals, too, have sent their ships east.

Your orders:
- Store at least 50 tons of cloth and 40 tons of tobacco goods in your warehouses.
- A town with at least 800 residents, 300 of them citizens or higher.
- At least 4 settlements of your own.

The helmsman's advice: In the giant world (2000 x 1400, with the extensions) the Mist Sea lies in the north-east, far from the Crown Sea. A warehouse there spares your ships the long voyage: have tobacco and wool processed on the spot and bring home only the finished goods. The "Northern Light" brings tools and wood for the building work.
'@ }
    }
    @{ Number = 73; BigIslandSize = 'Huge'; BigVillages = 6; BigAmounts = @{ Spices = 5 }; Giant = @{ Villages = 6; Amounts = @{ Spices = 8 } }; Title = @{ de = 'Weltreich 3 - Die Gewuerzroute'; en = 'World Empire 3 - The Spice Route' }; Difficulty = 1; AI = 2; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 35000; RivalGold = 30000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ Spices = 3 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Pfefferkorn'; en = 'Peppercorn' } }, @{ Type = 25; Name = @{ de = 'Geleit'; en = 'Escort' } })
        Mission = @{ Goods1 = @{ Good = 16; Tons = 60 }; TradeBalance = 250; Towns = @(@{ Residents = 1200; Stage = 3; OfWhich = 400 }) }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 3: Die Gewürzroute

Im fernen Südosten liegen die Gewürzinseln, heiss und grün, wo der Pfeffer wächst, nach dem die halbe Welt verlangt. Wer die Route dorthin beherrscht, füllt die Schatzkammer der Krone. Doch die Reise ist lang, und die Piraten kennen die Seewege besser als jeder Lotse.

Euer Auftrag:
- Lagert mindestens 60 Tonnen Gewürze in Euren Kontoren.
- Erreicht eine Handelsbilanz von mindestens +250 Talern: Eure Verkäufe müssen Eure Einkäufe deutlich übersteigen.
- Eine Stadt mit mindestens 1200 Einwohnern, davon 400 Kaufleute oder höher.

Rat des Steuermanns: Gewürze wachsen nur auf Inseln des Südens. In der Riesenwelt (2000 x 1400, mit den Erweiterungen) liegen sie in der Korallensee und auf den Gewürzinseln - eine Handelsroute dorthin braucht Zeit und Geleitschutz. Die "Pfefferkorn" fasst viel Ladung, die "Geleit" hält Euch die Piraten vom Leib.
'@; en = @'
THE WORLD EMPIRE - Chapter 3: The Spice Route

Far in the south-east lie the Spice Islands, hot and green, where the pepper grows that half the world craves. Whoever masters the route there fills the Crown's treasury. But the voyage is long, and the pirates know the sea lanes better than any pilot.

Your orders:
- Store at least 60 tons of spices in your warehouses.
- Reach a trade balance of at least +250 talers: your sales must clearly exceed your purchases.
- A town with at least 1200 residents, 400 of them merchants or higher.

The helmsman's advice: Spices grow only on southern islands. In the giant world (2000 x 1400, with the extensions) they lie in the Coral Sea and on the Spice Islands - a trade route there takes time and an escort. The "Peppercorn" holds a lot of cargo, the "Escort" keeps the pirates off your back.
'@ }
    }
    @{ Number = 74; BigIslandSize = 'Huge'; BigVillages = 7; BigAmounts = @{ Cotton = 3; Cocoa = 3 }; Giant = @{ Villages = 7; Amounts = @{ Cotton = 3; Cocoa = 3 } }; Title = @{ de = 'Weltreich 4 - Die Korallensee'; en = 'World Empire 4 - The Coral Sea' }; Difficulty = 2; AI = 2; Layout = 0; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 40000; RivalGold = 35000; Pirates = $true; VillagesNorth = 4; VillagesSouth = 4
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ Cotton = 2; Cocoa = 2 }   # monopolies = all islands with the crop (the game counts them at start)
        Fleet = @(@{ Type = 21; Name = @{ de = 'Seeschwalbe'; en = 'Tern' }; Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 30 }) }, @{ Type = 25; Name = @{ de = 'Riffwache'; en = 'Reef Guard' } })
        Mission = @{ Monopoly1 = @{ Resource = 0x31; Islands = 1 }; Monopoly2 = @{ Resource = 0x33; Islands = 1 }; TownCount = 5; TotalResidents = 3000 }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 4: Die Korallensee

Die Flotte der Krone braucht Segeltuch, und am Hof trinkt man Kakao aus feinem Porzellan. Baumwolle und Kakao wachsen nur im warmen Süden, und die Händler der Korallensee verkaufen sie an den Meistbietenden. Die Krone will das ändern: Jede dieser Inseln soll unter ihrer Flagge stehen.

Euer Auftrag:
- Sichert Euch das Baumwollmonopol: eine eigene Siedlung auf JEDER Insel, auf der Baumwolle wächst, und keine fremde dort.
- Sichert Euch ebenso das Kakaomonopol: eine eigene Siedlung auf JEDER Insel, auf der Kakao wächst.
- Mindestens 5 eigene Siedlungen mit zusammen mindestens 3000 Einwohnern.

Rat des Steuermanns: Prüft im Inselinfo, wo Baumwolle und Kakao wachsen - in der Riesenwelt (2000 x 1400, mit den Erweiterungen) sind diese Inseln über den ganzen Süden verstreut. Die Rivalen werden Euch zuvorkommen wollen. Dörfer der Ureinwohner stören die Monopole nicht. Die "Riffwache" schützt die "Seeschwalbe" auf ihren Fahrten.
'@; en = @'
THE WORLD EMPIRE - Chapter 4: The Coral Sea

The Crown's fleet needs sailcloth, and at court they drink cocoa from fine porcelain. Cotton and cocoa grow only in the warm south, and the traders of the Coral Sea sell them to the highest bidder. The Crown wants to change that: every one of those islands shall fly its flag.

Your orders:
- Secure the cotton monopoly: a settlement of your own on EVERY island where cotton grows, and no foreign one there.
- Secure the cocoa monopoly as well: a settlement of your own on EVERY island where cocoa grows.
- At least 5 settlements of your own with at least 3000 residents together.

The helmsman's advice: Check the island info for where cotton and cocoa grow - in the giant world (2000 x 1400, with the extensions) those islands are scattered across the whole south. The rivals will try to get there first. Native villages do not spoil the monopolies. The "Reef Guard" protects the "Tern" on her voyages.
'@ }
    }
    @{ Number = 75; BigIslandSize = 'Huge'; BigVillages = 6; Giant = @{ Villages = 6; Amounts = @{ OreSmall = 14; OreLarge = 20 } }; Title = @{ de = 'Weltreich 5 - Krieg der Kronen'; en = 'World Empire 5 - War of the Crowns' }; Difficulty = 2; AI = 3; Layout = 1; MirrorX = $true; MirrorY = $true; Enlarge = 3
        Gold = 45000; RivalGold = 25000; Pirates = $false; VillagesNorth = 3; VillagesSouth = 3
        Rivals = @(@{ Player = 2; Gold = 80000; Name = @{ de = 'Haus Morvan'; en = 'House Morvan' }; Ship = @{ de = 'Eiserne Faust'; en = 'Iron Fist' } })
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ OreSmall = 6; OreLarge = 10 }
        Fleet = @(@{ Type = 27; Name = @{ de = 'Löwenherz'; en = 'Lionheart' } }, @{ Type = 25; Name = @{ de = 'Habicht'; en = 'Goshawk' } })
        Mission = @{ Defeat = @(2); TownCount = 5; TotalResidents = 4000 }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 5: Krieg der Kronen

Das Haus Morvan beansprucht die Seewege zwischen den Inselreichen für sich. Seine Kaperschiffe überfallen Eure Handelsfahrer, seine Söldner besetzen Inseln, die der Krone zustehen. Nun ist es genug: Die Krone schickt Euch die "Löwenherz", ihr stärkstes Kriegsschiff, und erklärt dem Haus Morvan den Krieg.

Euer Auftrag:
- Besiegt das Haus Morvan. Ihr erkennt es an seinem Flaggschiff, der "Eiserne Faust". Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.
- Haltet mindestens 5 eigene Siedlungen.
- Alle Eure Siedlungen zusammen sollen mindestens 4000 Einwohner haben.

Die beiden anderen Rivalen müsst Ihr nicht besiegen.

Rat des Steuermanns: In der Riesenwelt (2000 x 1400, mit den Erweiterungen) können Morvans Kontore weit verstreut liegen - schickt den schnellen "Habicht" als Kundschafter voraus, bevor die Flotte ausläuft. Erz für Kanonen und Schwerter findet Ihr in den Bergen vieler Inseln. Ein Krieg gegen alle drei Häuser zugleich wäre Euer Ende.
'@; en = @'
THE WORLD EMPIRE - Chapter 5: War of the Crowns

House Morvan claims the sea lanes between the island realms for itself. Its privateers raid your trading ships, its mercenaries occupy islands that belong to the Crown. Enough is enough: the Crown sends you the "Lionheart", its strongest warship, and declares war on House Morvan.

Your orders:
- Defeat House Morvan. You will know it by its flagship, the "Iron Fist". A rival counts as defeated when he owns no settlement and no ship any more.
- Hold at least 5 settlements of your own.
- All your settlements together shall have at least 4000 residents.

You do not have to defeat the other two rivals.

The helmsman's advice: In the giant world (2000 x 1400, with the extensions) Morvan's warehouses may lie far apart - send the swift "Goshawk" ahead as a scout before the fleet sets sail. Ore for cannons and swords is found in the mountains of many islands. A war against all three houses at once would be your end.
'@ }
    }
    @{ Number = 76; BigIslandSize = 'Huge'; BigVillages = 7; Giant = @{ Villages = 7 }; Title = @{ de = 'Weltreich 6 - Das Weltreich'; en = 'World Empire 6 - The World Empire' }; Difficulty = 3; AI = 3; Layout = 2; MirrorX = $true; MirrorY = $false; Enlarge = 4
        Gold = 60000; RivalGold = 50000; Pirates = $true; VillagesNorth = 4; VillagesSouth = 4
        ShipName = @{ de = 'Morgenstern'; en = 'Morning Star' }
        Amounts = @{ OreSmall = 6; OreLarge = 10; Gold = 3 }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Morgenstern II'; en = 'Morning Star II' }; Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 50 }, @{ Good = 'Wood'; Tons = 40 }) }, @{ Type = 27; Name = @{ de = 'Kaiserkrone'; en = 'Imperial Crown' } })
        Mission = @{ Towns = @(@{ Residents = 3000; Stage = 4; OfWhich = 1200 }, @{ Residents = 2000; Stage = 3; OfWhich = 800 }, @{ Residents = 1200; Stage = 2; OfWhich = 500 }); TownCount = 7; TotalResidents = 8000; Balance = 1500 }
        Text = @{ de = @'
DAS WELTREICH - Kapitel 6: Das Weltreich

Morvan ist geschlagen, die Seewege sind frei. Nun soll aus Euren Kolonien ein Reich werden, das von der Kronsee bis zu den Gewürzinseln reicht - das erste Weltreich der Geschichte. Die Krone verlangt eine Hauptstadt voller Paläste, blühende Städte in allen Teilen des Meeres und eine Kasse, die überquillt. Doch die übrigen Häuser wollen sich nicht beugen, und Piraten lauern auf den langen Routen.

Euer Auftrag:
- Eine Hauptstadt mit mindestens 3000 Einwohnern, davon 1200 Aristokraten.
- Eine zweite Stadt mit mindestens 2000 Einwohnern, davon 800 Kaufleute oder höher.
- Eine dritte Stadt mit mindestens 1200 Einwohnern, davon 500 Bürger oder höher.
- Mindestens 7 eigene Siedlungen mit zusammen mindestens 8000 Einwohnern.
- Eine Bilanz von mindestens +1500 Talern.

Rat des Steuermanns: Dies ist die grösste Aufgabe der Erweiterungen - plant viele Spielstunden ein. Die "Morgenstern II" bringt Werkzeug, Ziegel und Holz für die neuen Städte, die "Kaiserkrone" schützt Eure Routen. Am schönsten in der Riesenwelt (2000 x 1400, mit den Erweiterungen).

Dies ist das letzte Kapitel des Weltreichs. Möge Euer Name über alle Meere getragen werden!
'@; en = @'
THE WORLD EMPIRE - Chapter 6: The World Empire

Morvan is beaten, the sea lanes are free. Now your colonies shall become an empire that reaches from the Crown Sea to the Spice Islands - the first world empire in history. The Crown demands a capital full of palaces, thriving towns in every part of the sea and a treasury that overflows. But the remaining houses will not bow, and pirates lurk on the long routes.

Your orders:
- A capital with at least 3000 residents, 1200 of them aristocrats.
- A second town with at least 2000 residents, 800 of them merchants or higher.
- A third town with at least 1200 residents, 500 of them citizens or higher.
- At least 7 settlements of your own with at least 8000 residents together.
- A balance of at least +1500 talers.

The helmsman's advice: This is the biggest task of the extensions - plan for many hours of play. The "Morning Star II" brings tools, bricks and wood for the new towns, the "Imperial Crown" guards your routes. Best in the giant world (2000 x 1400, with the extensions).

This is the last chapter of the World Empire. May your name be carried across every sea!
'@ }
    }

    # Two challenges for the giant world: seven settlements that all have to grow, and two crop monopolies at the
    # opposite ends of the map (wine only grows in the north, spices only in the south).
    @{ Number = 67; BigIslandSize = 'Huge'; BigVillages = 6; Giant = @{ Villages = 6 }; Title = @{ de = 'Herausforderung - Sieben Meere'; en = 'Challenge - Seven Seas' }; Difficulty = 2; AI = 2; Layout = 1; MirrorX = $true; MirrorY = $false; Enlarge = 3
        Gold = 50000; RivalGold = 30000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Windrose'; en = 'Compass Rose' }
        Fleet = @(@{ Type = 23; Name = @{ de = 'Fernhafen'; en = 'Far Harbour' }; Cargo = @(@{ Good = 'Tools'; Tons = 40 }, @{ Good = 'Wood'; Tons = 40 }, @{ Good = 'Bricks'; Tons = 20 }) }, @{ Type = 21; Name = @{ de = 'Möwe'; en = 'Gull' }; Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 30 }) })
        Mission = @{ TownCount = 7; AllTowns = @{ Residents = 300; Stage = 1; OfWhich = 120 }; TotalResidents = 4000; Balance = 300 }
        Text = @{ de = @'
HERAUSFORDERUNG: Sieben Meere

Ein Kapitän, der auf sieben Meeren seine Flagge gehisst hat, gilt in jedem Hafen als Legende. Gründet sieben Siedlungen und macht aus jeder einen richtigen Ort - keine leeren Kontore, sondern lebendige Städtchen.

Euer Auftrag:
- Mindestens 7 eigene Siedlungen.
- JEDE Eurer Siedlungen braucht mindestens 300 Einwohner, davon 120 Siedler oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!
- Alle Siedlungen zusammen mindestens 4000 Einwohner.
- Eine Bilanz von mindestens +300 Talern.

Rat des Steuermanns: Gebaut für die Riesenwelt (2000 x 1400, mit den Erweiterungen): Verteilt Eure Siedlungen über mehrere Inselreiche, damit jede genug Platz zum Wachsen hat. Die "Fernhafen" und die "Möwe" bringen Baumaterial für die ersten Aussenposten. Piraten kreuzen auf den langen Routen.
'@; en = @'
CHALLENGE: Seven Seas

A captain who has raised his flag on seven seas is a legend in every harbour. Found seven settlements and make each of them a proper place - not empty warehouses, but lively little towns.

Your orders:
- At least 7 settlements of your own.
- EVERY one of your settlements needs at least 300 residents, 120 of them settlers or higher. Even a warehouse without houses counts as a settlement!
- All settlements together at least 4000 residents.
- A balance of at least +300 talers.

The helmsman's advice: Made for the giant world (2000 x 1400, with the extensions): spread your settlements over several island realms so that each has room to grow. The "Far Harbour" and the "Gull" bring building material for the first outposts. Pirates cruise the long routes.
'@ }
    }
    @{ Number = 68; BigIslandSize = 'Huge'; BigVillages = 6; BigAmounts = @{ Wine = 3; Spices = 3 }; Giant = @{ Villages = 6; Amounts = @{ Wine = 3; Spices = 3 } }; Title = @{ de = 'Herausforderung - Die Weltumsegelung'; en = 'Challenge - Around the World' }; Difficulty = 2; AI = 1; Layout = 0; MirrorX = $false; MirrorY = $true; Enlarge = 3
        Gold = 45000; RivalGold = 25000; Pirates = $true; VillagesNorth = 3; VillagesSouth = 3
        ShipName = @{ de = 'Weltenbummler'; en = 'Globetrotter' }
        Amounts = @{ Wine = 2; Spices = 2 }   # monopolies = all islands with the crop (the game counts them at start)
        Fleet = @(@{ Type = 21; Name = @{ de = 'Passat'; en = 'Trade Wind' }; Cargo = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 30 }) }, @{ Type = 25; Name = @{ de = 'Wellenreiter'; en = 'Wave Rider' } })
        Mission = @{ Monopoly1 = @{ Resource = 0x32; Islands = 1 }; Monopoly2 = @{ Resource = 0x2F; Islands = 1 }; TradeBalance = 400 }
        Text = @{ de = @'
HERAUSFORDERUNG: Die Weltumsegelung

Die Kaufleute der Alten Welt wetten, dass niemand den Wein des Nordens und die Gewürze des Südens zugleich beherrschen kann - zu weit liegen die Inseln auseinander. Beweist das Gegenteil: Umsegelt die Welt und hisst Eure Flagge auf jeder Insel, die Wein oder Gewürze trägt.

Euer Auftrag:
- Sichert Euch das Weinmonopol: eine eigene Siedlung auf JEDER Insel, auf der Wein wächst, und keine fremde dort.
- Sichert Euch ebenso das Gewürzmonopol: eine eigene Siedlung auf JEDER Insel, auf der Gewürze wachsen.
- Erreicht eine Handelsbilanz von mindestens +400 Talern.

Rat des Steuermanns: Wein wächst nur im Norden, Gewürze nur im Süden. In der Riesenwelt (2000 x 1400, mit den Erweiterungen) liegen diese Inseln in verschiedenen Inselreichen - ohne gute Routen ist das nicht zu schaffen. Dörfer der Ureinwohner stören die Monopole nicht. Der "Wellenreiter" begleitet die "Passat" auf ihren langen Fahrten.
'@; en = @'
CHALLENGE: Around the World

The merchants of the Old World are betting that no one can master the wine of the north and the spices of the south at the same time - the islands lie too far apart. Prove them wrong: sail around the world and raise your flag on every island that bears wine or spices.

Your orders:
- Secure the wine monopoly: a settlement of your own on EVERY island where wine grows, and no foreign one there.
- Secure the spice monopoly as well: a settlement of your own on EVERY island where spices grow.
- Reach a trade balance of at least +400 talers.

The helmsman's advice: Wine grows only in the north, spices only in the south. In the giant world (2000 x 1400, with the extensions) those islands lie in different island realms - without good routes it cannot be done. Native villages do not spoil the monopolies. The "Wave Rider" escorts the "Trade Wind" on her long voyages.
'@ }
    }
)

if ($BuildLibraryOnly) { return }

$paths = @()
foreach ($sc in $Scenarios) { $r = Build-Scenario $sc; $r.Summary; $paths += $r.Path }
if ($Install) {
    $own = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
    New-Item -ItemType Directory -Force -Path $own | Out-Null
    foreach ($p in $paths) { Copy-Item -LiteralPath $p -Destination $own -Force }
    "Installed $($paths.Count) scenarios to: $own"
}
