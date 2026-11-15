<#
.SYNOPSIS
  Scenario designer for Anno 1602 History Edition: click your own scenario together - map, world, rivals,
  ships and a mission - and play it under "Own Scenarios" ("Eigenes - <Name>" / "Custom - <Name>").

.DESCRIPTION
  A window (German on a German Windows, English otherwise; $env:ANNO_EXTENSIONS_LANG) with
    Scenario   name, map kind (classic / archipelago / continents, the map rules of the random adventures),
               map number (the same number gives the same map), difficulty
    World      your starting gold, the rivals' gold and strength, pirates, natives, resources, start cargo,
               extra trading ships and warships
    Mission    any combination of the goal types the campaigns use: up to 3 towns with a stage goal, every
               settlement at least, number of settlements, total residents, balance, trade balance, up to 2 goods
               in stock, up to 2 crop monopolies, defeat chosen rivals
    Story      generated from the text blocks of the random adventures, freely editable
  The preview shows the mission text exactly as the game shows it (and the map of both versions). "Create" builds
  the scenario with build-scenarios.ps1 (through random-adventure.ps1 -Library), checks that the computer rivals
  find islands of class med or bigger, and puts it into Documents\Anno 1602 History Edition\Own Scenarios.
  The last design is remembered in %APPDATA%\Anno1602-Extensions\designer.json.

  Started from the launcher (-Owner), the designer is a dialog of the launcher and returns
  @{ Created = <file names>; ShowList = $true/$false }; the launcher then shows its adventure list.

  Hidden switches for tests:
    -PreviewImage <png> [-SpecFile <json>] [-PreviewMap]   render the window (filled with the design) and exit
    -BuildSpec <json> [-OutFolder <folder>]                build a design without the window (exit 1 if invalid)
    -SpecFile <json> -TestCreate [-OutFolder <folder>]     show the window off-screen, click "Create" in code
  A design file is JSON with the keys of New-DefaultDesign (missing keys keep their defaults).
#>
param(
    # The launcher's window: the designer opens as its dialog and returns the result instead of starting the launcher.
    [Parameter(DontShow)]$Owner,
    [ValidateSet('', 'de', 'en')][string]$Language = '',
    # For testing only: render the window as a PNG and exit (with -PreviewMap the map tab).
    [Parameter(DontShow)][string]$PreviewImage,
    [Parameter(DontShow)][switch]$PreviewMap,
    # For testing only: a design (JSON) to fill the window with.
    [Parameter(DontShow)][string]$SpecFile,
    # For testing only: build this design (JSON) without the window and exit.
    [Parameter(DontShow)][string]$BuildSpec,
    # For testing only: with -SpecFile, show the window off-screen, click "Create" in code and answer every question with yes.
    [Parameter(DontShow)][switch]$TestCreate,
    # For testing only: put the scenario here instead of Own Scenarios.
    [Parameter(DontShow)][string]$OutFolder,
    [Parameter(DontShow)][string]$AppDataFolder = $env:APPDATA,
    [Parameter(DontShow)][string]$DocumentsFolder = [Environment]::GetFolderPath('MyDocuments'),
    [Parameter(DontShow)][string]$GamePath,
    # For testing only: define the functions (dot-source the script) and return without a window.
    [Parameter(DontShow)][switch]$FunctionsOnly
)
$ErrorActionPreference = 'Stop'

# UI language = language of the scenario: German on a German Windows, English otherwise.
if (-not $Language) { $Language = if ($env:ANNO_EXTENSIONS_LANG) { if ($env:ANNO_EXTENSIONS_LANG -eq 'de') { 'de' } else { 'en' } } elseif ((Get-UICulture).TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' } }
$UiGerman = $Language -eq 'de'
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }

$DesignDataFolder = Join-Path $AppDataFolder 'Anno1602-Extensions'
$DesignFile = Join-Path $DesignDataFolder 'designer.json'
$DesignTarget = if ($OutFolder) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFolder) } else { Join-Path $DocumentsFolder 'Anno 1602 History Edition\Own Scenarios' }
$LauncherScript = Join-Path $PSScriptRoot 'launcher.ps1'
# Built first into a folder of its own, checked, then copied to the target.
$DesignBuildFolder = Join-Path ([IO.Path]::GetTempPath()) ('anno1602-designer-' + [guid]::NewGuid().ToString('N'))
# Building blocks of the random adventures (texts, map rules, random numbers) and the scenario builder.
# Their parameters land in this scope (Seed, Difficulty, Date ... carry validation attributes): do not reuse those names.
. (Join-Path $PSScriptRoot 'random-adventure.ps1') -Library -Language $Language -OutFolder $DesignBuildFolder -GamePath $GamePath

# --- The design: defaults, choices, loading ----------------------------------------------------------
$ShipTypeKeys = @(21, 23, 25, 27)   # small/large trading ship, small/large warship
$GoalGoods = @(21, 3, 20, 19, 18, 15, 16, 17, 12, 13, 24)
$CropKeys = @($Crops | ForEach-Object { $_.Plant })
$NativesChoices = [ordered]@{ Few = @(1, 1, 3); Normal = @(2, 2, 5); Many = @(4, 4, 7) }   # north, south, big version per climate
$ResourceChoices = [ordered]@{
    Few = [ordered]@{ OreSmall = 3; OreLarge = 5; Gold = 1; Treasure = 2 }
    Normal = [ordered]@{ OreSmall = 5; OreLarge = 8; Gold = 2; Treasure = 6 }
    Lots = [ordered]@{ OreSmall = 7; OreLarge = 11; Gold = 4; Treasure = 10 }
}
$CargoChoices = [ordered]@{
    Standard = $null   # the template's 50 t tools, 30 t wood, 10 t food
    Rich = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = 'Bricks'; Tons = 20 }, @{ Good = 'Food'; Tons = 20 })
    Lean = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 20 }, @{ Good = 'Food'; Tons = 10 })
    Shipwreck = @(@{ Good = 'Tools'; Tons = 20 }, @{ Good = 'Wood'; Tons = 12 }, @{ Good = 'Food'; Tons = 8 })
}
# Value ranges of the mission (tests\check-scenarios.ps1 accepts them; the town goals as in the campaigns).
$Limits = @{
    Residents = @(20, 5000); TownCount = @(1, 20); TotalResidents = @(100, 20000); Balance = @(0, 2000); TradeBalance = @(50, 1000)
    Tons = @(5, 200); Gold = @(0, 250000); TimeLimit = @(1, 50)
}
$MaxNameLength = 40

function New-DefaultDesign {
    @{
        Name = (Txt 'My Isles' 'Meine Inseln'); MapKind = 'Classic'; MapNumber = (Get-Random -Minimum 1 -Maximum 1000000); Difficulty = 1
        Gold = 30000; RivalGold = 25000; RivalStrength = 1; Pirates = $false; Natives = 'Normal'; Resources = 'Normal'; Cargo = 'Standard'; Ships = @()
        Towns = @(@{ Residents = 500; Stage = 2; OfWhich = 250 }); AllTowns = $null; TownCount = 0; TotalResidents = 0
        Balance = 0; TradeBalance = $null; Goods = @(); Monopolies = @(); Defeat = @(); TimeLimitHours = 0
        StorySeed = (Get-Random -Minimum 1 -Maximum 1000000); Story = $null
    }
}
# A design from JSON (file or designer.json): known keys only, missing keys keep their defaults.
function ConvertTo-Design($obj) {
    $d = New-DefaultDesign
    if (-not $obj) { return $d }
    $p = @{}; foreach ($x in $obj.PSObject.Properties) { $p[$x.Name] = $x.Value }
    $town = { param($t) if ($null -eq $t) { $null } else { @{ Residents = [int]$t.Residents; Stage = [int]$t.Stage; OfWhich = [int]$t.OfWhich } } }
    foreach ($k in 'Name', 'MapKind', 'Natives', 'Resources', 'Cargo') { if ($p.ContainsKey($k) -and $null -ne $p[$k]) { $d[$k] = [string]$p[$k] } }
    foreach ($k in 'MapNumber', 'Difficulty', 'Gold', 'RivalGold', 'RivalStrength', 'TownCount', 'TotalResidents', 'StorySeed', 'TimeLimitHours') { if ($p.ContainsKey($k) -and $null -ne $p[$k]) { $d[$k] = [int]$p[$k] } }
    foreach ($k in 'Balance', 'TradeBalance') { if ($p.ContainsKey($k)) { $d[$k] = if ($null -eq $p[$k]) { $null } else { [int]$p[$k] } } }
    if ($p.ContainsKey('Pirates')) { $d.Pirates = [bool]$p.Pirates }
    if ($p.ContainsKey('Story')) { $d.Story = if ($null -eq $p.Story) { $null } else { [string]$p.Story } }
    if ($p.ContainsKey('Ships')) { $d.Ships = @($p.Ships | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }) }
    if ($p.ContainsKey('Towns')) { $d.Towns = @($p.Towns | Where-Object { $_ } | ForEach-Object { & $town $_ }) }
    if ($p.ContainsKey('AllTowns')) { $d.AllTowns = & $town $p.AllTowns }
    if ($p.ContainsKey('Goods')) { $d.Goods = @($p.Goods | Where-Object { $_ } | ForEach-Object { @{ Good = [int]$_.Good; Tons = [int]$_.Tons } }) }
    if ($p.ContainsKey('Monopolies')) { $d.Monopolies = @($p.Monopolies | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
    if ($p.ContainsKey('Defeat')) { $d.Defeat = @($p.Defeat | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique) }
    $d
}
function Read-DesignFile([string]$path) { ConvertTo-Design (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }

# --- Names ------------------------------------------------------------------------------------------------
# File name part of the scenario name: umlauts spelled out, accents dropped, only printable ASCII and no
# characters that Windows forbids in file names (the project's scenario files are plain ASCII).
function ConvertTo-AsciiName([string]$name) {
    $s = $name -creplace 'ä', 'ae' -creplace 'ö', 'oe' -creplace 'ü', 'ue' -creplace 'Ä', 'Ae' -creplace 'Ö', 'Oe' -creplace 'Ü', 'Ue' -creplace 'ß', 'ss'
    $s = $s.Normalize([Text.NormalizationForm]::FormD)
    $s = -join @($s.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' -and [int]$_ -ge 32 -and [int]$_ -le 126 -and '\/:*?"<>|'.IndexOf($_) -lt 0 })
    ($s -replace '\s+', ' ').Trim().TrimEnd('.').Trim()
}
function Get-DesignTitle($d) { '{0} - {1}' -f $(if ($Language -eq 'de') { 'Eigenes' } else { 'Custom' }), (ConvertTo-AsciiName $d.Name) }
# Typographic characters (quotes, dashes, special spaces, ellipsis) become plain ASCII, as in the campaign texts.
$PlainCharacters = @(
    @((-join ([char[]](0x2018, 0x2019, 0x201A, 0x2032))), "'"), @((-join ([char[]](0x201C, 0x201D, 0x201E, 0xAB, 0xBB, 0x2033))), '"'),
    @((-join ([char[]](0x2013, 0x2014, 0x2212))), '-'), @((-join ([char[]](0xA0, 0x2009, 0x202F))), ' '))
function ConvertTo-PlainText([string]$s) {
    foreach ($p in $PlainCharacters) { $s = $s -replace ('[' + $p[0] + ']'), $p[1] }
    ($s -replace ([string][char]0x2026), '...') -replace "`r", ''
}
# Characters of a text that the game cannot show (German: outside Windows-1252, English: outside plain ASCII).
function Get-BadCharacters([string]$s) {
    $bad = New-Object System.Collections.Generic.List[string]
    $e = [Globalization.StringInfo]::GetTextElementEnumerator($s)
    while ($e.MoveNext()) {
        $t = [string]$e.Current
        if ($t -eq "`n" -or $bad.Contains($t)) { continue }
        $ok = if ($Language -eq 'en') { $t.Length -eq 1 -and [int]$t[0] -ge 32 -and [int]$t[0] -le 126 } else { $t.Length -eq 1 -and [int]$t[0] -ge 32 -and $Cp1252.GetString($Cp1252.GetBytes($t)) -ceq $t }
        if (-not $ok) { $bad.Add($t) }
    }
    $bad.ToArray()
}

# --- From the design to the scenario ------------------------------------------------------------------------
# Texts and names from the story seed, always drawn in the same order so that changing an option does not change
# the place, the names or the opening.
function Get-DesignStoryParts($d) {
    Reset-AdvRandom 0 $d.StorySeed
    $parts = @{}
    $parts.Place = Get-AdvPick $Places
    $parts.Opening = Get-AdvPick $AdvOpenings[$d.MapKind]
    $parts.MotiveIndex = Get-AdvInt 2
    $parts.HintIndex = Get-AdvInt 2
    $parts.Closing = Get-AdvPick $AdvClosings
    $parts.Houses = Get-AdvShuffled $Houses
    $parts.Traders = Get-AdvShuffled $TraderNames
    $parts.Warships = Get-AdvShuffled $WarshipNames
    $parts.Twists = Get-AdvInt 1000000
    $parts
}
# Main goal of a design (for motive and advice): conquest before monopoly, realm, trade, towns.
function Get-DesignPrimary($d) {
    if (@($d.Defeat).Count) { 'Conquest' }
    elseif (@($d.Monopolies).Count) { 'Monopoly' }
    elseif ($d.TownCount -or $d.AllTowns) { 'Realm' }
    elseif (@($d.Goods).Count -or $null -ne $d.TradeBalance) { 'Trade' }
    else { 'Towns' }
}
# Full scenario definition for Build-Scenario plus the pieces of the text. $attempt varies the map only.
function ConvertTo-DesignScenario($d, [int]$attempt = 0) {
    $lv = [int]$d.Difficulty
    $sc = @{ Number = 0; GameId = 0x54000000 + ($lv -shl 20) + [int]$d.MapNumber; Difficulty = $lv }
    Reset-AdvRandom $attempt $d.MapNumber
    Set-AdvMap $sc $d.MapKind
    $nat = $NativesChoices[$d.Natives]; $sc.VillagesNorth = $nat[0]; $sc.VillagesSouth = $nat[1]; $sc.BigVillages = $nat[2]
    $sc.Gold = [int]$d.Gold; $sc.RivalGold = [int]$d.RivalGold; $sc.AI = [int]$d.RivalStrength; $sc.Pirates = [bool]$d.Pirates
    $parts = Get-DesignStoryParts $d
    $primary = Get-DesignPrimary $d

    # Mission and the goal texts.
    $mission = @{}; $bullets = New-Object System.Collections.Generic.List[object]; $hints = New-Object System.Collections.Generic.List[object]
    $amounts = [ordered]@{}; foreach ($k in $ResourceChoices[$d.Resources].Keys) { $amounts[$k] = $ResourceChoices[$d.Resources][$k] }
    $bigAmounts = [ordered]@{}; $rivals = @(); $houses = @()
    $targets = @($d.Defeat | Sort-Object -Unique)
    if ($targets.Count) {
        $mission.Defeat = $targets
        if ($targets.Count -lt 3) {
            $houses = @($parts.Houses[0..($targets.Count - 1)])
            for ($k = 0; $k -lt $targets.Count; $k++) { $rivals += @{ Player = $targets[$k]; Name = @{ de = "Haus $($houses[$k])"; en = "House $($houses[$k])" }; Ship = $houses[$k] } }
        }
        $bullets.Add((Get-AdvDefeatBullet $houses))
    }
    $towns = @($d.Towns | Where-Object { $_ } | Sort-Object { - $_.Residents })
    if ($towns.Count) {
        $mission.Towns = @($towns | ForEach-Object { @{ Residents = [int]$_.Residents; Stage = [int]$_.Stage; OfWhich = [int]$_.OfWhich } })
        for ($k = 0; $k -lt $towns.Count; $k++) { $bullets.Add((Get-AdvTownBullet $mission.Towns[$k] ($k + 1))) }
    }
    if ($d.TownCount) { $mission.TownCount = [int]$d.TownCount; $bullets.Add((Get-AdvTownCountBullet $d.TownCount (-not $d.AllTowns))) }
    if ($d.AllTowns) { $mission.AllTowns = @{ Residents = [int]$d.AllTowns.Residents; Stage = [int]$d.AllTowns.Stage; OfWhich = [int]$d.AllTowns.OfWhich }; $bullets.Add((Get-AdvAllTownsBullet $mission.AllTowns)) }
    if ($d.TotalResidents) { $mission.TotalResidents = [int]$d.TotalResidents; $bullets.Add((Get-AdvTotalBullet $d.TotalResidents)) }
    $crops = @($d.Monopolies | ForEach-Object { $key = $_; $Crops | Where-Object { $_.Plant -eq $key } })
    for ($k = 0; $k -lt $crops.Count; $k++) {
        $mission["Monopoly$($k + 1)"] = @{ Resource = $crops[$k].Res; Islands = 1 }
        $amounts[$crops[$k].Plant] = 2; $bigAmounts[$crops[$k].Plant] = 3   # never 1: the crop might land on no island
        $bullets.Add((Get-AdvMonopolyBullet $crops[$k]))
    }
    $goods = @($d.Goods | Where-Object { $_ } | ForEach-Object { @{ Good = [int]$_.Good; Tons = [int]$_.Tons } })
    for ($k = 0; $k -lt $goods.Count; $k++) { $mission["Goods$($k + 1)"] = $goods[$k] }
    if ($goods.Count) { $bullets.Add((Get-AdvGoodsBullet $goods)) }
    if ($null -ne $d.TradeBalance) { $mission.TradeBalance = [int]$d.TradeBalance; $bullets.Add((Get-AdvTradeBalanceBullet $d.TradeBalance)) }
    if ($null -ne $d.Balance) { $mission.Balance = [int]$d.Balance; $bullets.Add((Get-AdvBalanceBullet $d.Balance)) }
    # Time limit (AUFTRAG4 +0x58): only the patcher's TIMERS hook makes the game use it, so the text says so.
    if ($d.TimeLimitHours) {
        $h = [int]$d.TimeLimitHours; $sc.TimeLimitHours = $h
        $bullets.Add((New-AdvText ('Zeitlimit: {0} {1} - nur mit den Anno 1602 Erweiterungen. Die Uhr zeigt die verstrichene Spielzeit; bei {2}:00 ist die Mission verloren.' -f $h, $(if ($h -eq 1) { 'Stunde' } else { 'Stunden' }), (60 * $h)) ('Time limit: {0} {1} - only with the Anno 1602 Extensions. The clock shows the elapsed game time; at {2}:00 the mission is lost.' -f $h, $(if ($h -eq 1) { 'hour' } else { 'hours' }), (60 * $h))))
    }

    # World to match the mission (as for the random adventures).
    $goodIds = @($goods | ForEach-Object { $_.Good })
    if ($targets.Count -or ($goodIds | Where-Object { $_ -in 12, 13 })) { $amounts.OreSmall = [math]::Max($amounts.OreSmall, 6); $amounts.OreLarge = [math]::Max($amounts.OreLarge, 9) }
    if ($goodIds | Where-Object { $_ -in 3, 21 }) { $amounts.Gold = [math]::Max($amounts.Gold, 3) }
    Add-AdvCropsForGoods $amounts $goodIds
    $sc.Amounts = $amounts
    if ($bigAmounts.Count) { $sc.BigAmounts = $bigAmounts }

    # Ships: start cargo (bricks give way to food when bricks are a goal), extra ships with names.
    $cargoNote = $null
    if ($d.Cargo -ne 'Standard') {
        $sc.Cargo = @($CargoChoices[$d.Cargo])
        if ($d.Cargo -eq 'Rich') { $cargoNote = $AdvTwists.RichCargo; if ($goodIds -contains 24) { $sc.Cargo = @($sc.Cargo[0], $sc.Cargo[1], @{ Good = 'Food'; Tons = 30 }) } }
        else { $cargoNote = $AdvTwists.LeanCargo; $hints.Add($AdvHints.Tools) }
    }
    $fleet = New-Object System.Collections.Generic.List[object]; $ti = 0; $wi = 0
    foreach ($t in @($d.Ships | Sort-Object)) {
        if ($t -ge 25) { $fleet.Add(@{ Type = $t; Name = $parts.Warships[$wi] }); $wi++ }
        else { $fleet.Add(@{ Type = $t; Name = $parts.Traders[$ti]; Cargo = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 30 }) }); $ti++ }
    }
    if ($fleet.Count) { $sc.Fleet = $fleet.ToArray() }
    if ($rivals.Count) { $sc.Rivals = $rivals }

    # Story, advice and the whole text.
    $motive = switch ($primary) {
        'Conquest' { Get-AdvConquestMotive $houses }
        'Monopoly' { Get-AdvMonopolyMotive $crops }
        default { $AdvMotives[$primary][$parts.MotiveIndex] }
    }
    $mainHint = if ($primary -eq 'Towns') { $AdvMainHints.Towns[$parts.HintIndex] } else { $AdvMainHints[$primary][0] }
    $twists = New-Object System.Collections.Generic.List[object]
    if ($sc.Pirates) { $twists.Add($AdvTwists.Pirates); $hints.Add($AdvHints.Pirates) }
    $extra = @()
    if ($sc.AI -ge 3) { $extra += , $AdvTwists.StrongRivals } elseif ($sc.AI -eq 0) { $extra += , $AdvTwists.WeakRivals }
    if ($sc.VillagesNorth + $sc.VillagesSouth -ge 6) { $extra += , $AdvTwists.Natives }
    if ($cargoNote) { $extra += , $cargoNote }
    Reset-AdvRandom 1 $parts.Twists
    foreach ($e in @((Get-AdvShuffled $extra) | Select-Object -First 2)) { $twists.Add($e) }
    if ($fleet.Count) { $twists.Add((Get-AdvFleetTwist @($fleet | ForEach-Object { $_.Name }))) }
    if ($goodIds | Where-Object { $_ -in 12, 13 }) { $hints.Add($AdvHints.Ore) } elseif ($goodIds | Where-Object { $_ -in 3, 21 }) { $hints.Add($AdvHints.Gold) }
    $generated = Get-AdvStory $Language $parts.Opening $parts.Place $motive $twists
    $story = (ConvertTo-PlainText $(if ($null -ne $d.Story) { $d.Story } else { $generated })).Trim()
    $titleLine = if ($Language -eq 'de') { 'EIGENES SZENARIO: ' + ($d.Name -replace '\s+', ' ').Trim() } else { 'CUSTOM SCENARIO: ' + (ConvertTo-AsciiName $d.Name) }
    $advice = @($mainHint) + @($hints | Select-Object -First 2)
    $text = Format-AdvText $Language $titleLine $lv $story $bullets (Get-AdvDefeatNote $(if ($targets.Count -lt 3) { $targets.Count } else { 0 })) $advice $parts.Closing
    $sc.Title = @{ $Language = (Get-DesignTitle $d) }
    $sc.Text = @{ $Language = $text }
    $sc.Mission = $mission
    @{ Scenario = $sc; Text = $text; GeneratedStory = $generated; Bullets = $bullets; Primary = $primary }
}

# --- Maps: the small map (500 x 350) as Build-Scenario makes it, and its big version (1000 x 700) ----------------------
# Used for the checks of a design (islands per climate, number of islands) and for the map preview.
$script:MapCache = @{}
function Get-DesignMaps($d, [switch]$Big) {
    $key = '{0}|{1}|{2}' -f $d.MapKind, $d.MapNumber, $d.Difficulty
    if (-not $script:MapCache.ContainsKey($key)) {
        $sc = @{ Number = 0; GameId = 0x54000000 + ([int]$d.Difficulty -shl 20) + [int]$d.MapNumber; Difficulty = [int]$d.Difficulty }
        Reset-AdvRandom 0 $d.MapNumber
        Set-AdvMap $sc $d.MapKind
        # The same steps as Build-Scenario (build-scenarios.ps1).
        $template = Read-Scenario (Join-Path $SzenesFolder ('[[48]]{0}{1}.szs' -f $sc.Difficulty, $sc.Layout))
        $scene = [byte[]](Get-Section $template 'SZENE').Data.Clone()
        $islands = @(Get-MirroredIslands @(Get-IslandList $scene) $sc.MirrorX $sc.MirrorY)
        if ($sc.Continents) { $islands = @(Get-ContinentIslands $islands $sc.Continents.Lar $sc.Continents.Big $sc.Continents.Small) }
        if ($sc.ContainsKey('MaxClass')) { foreach ($e in $islands) { if ($e.Class -gt $sc.MaxClass) { $e.Class = [int]$sc.MaxClass } } }
        if ($sc.AddIslands) { $islands = @(Add-Islands $islands $sc.AddIslands @(0, 1) ([int]$sc.Number + [int]$sc.GameId)) }
        if ($sc.Enlarge) { Expand-Islands $islands $sc.Enlarge }
        $script:MapCache[$key] = @{ Small = $islands; Scene = $scene; BigSize = $sc.BigIslandSize; Big = $null }
    }
    $m = $script:MapCache[$key]
    if ($Big -and $null -eq $m.Big) {
        $scene = [byte[]]$m.Scene.Clone(); Set-Islands $scene $m.Small
        $small16 = @(for ($i = 0; $i -lt $m.Small.Count; $i++) { , [byte[]]$scene[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
        $plan = Get-IslandPlan $small16 $BigWidth $BigHeight $false $m.BigSize
        $m.Big = @(foreach ($p in $plan) { @{ Class = [int]$p[1]; Climate = [int]$p[0]; X = [BitConverter]::ToInt32($p, 8); Y = [BitConverter]::ToInt32($p, 12) } })
    }
    $m
}
# Islands per climate (0 north, 1 south, 2 by position) of an island list.
function Get-ClimateCounts($islands) { $c = @(0, 0, 0); foreach ($e in $islands) { if ([int]$e.Climate -le 2) { $c[[int]$e.Climate]++ } }; , $c }
# Map problems of a design on a given island list ($null = fine): more settlements than islands (one warehouse per
# island and player), a monopoly crop without an island of its climate (the game puts tobacco, sugar cane and wine
# only on northern, spices and cocoa only on southern islands; climate 2 = by position counts for both).
$CropClimate = @{ Tobacco = 0; Sugar = 0; Wine = 0; Spices = 1; Cocoa = 1 }
function Get-DesignMapProblem($d, $islands) {
    $n = @($islands).Count
    if ($d.TownCount -gt $n) { return ((Txt 'This map has only {0} islands: at most {0} settlements (one warehouse per island).' 'Diese Karte hat nur {0} Inseln: höchstens {0} Siedlungen (ein Kontor je Insel).') -f $n) }
    $clim = Get-ClimateCounts $islands
    foreach ($m in @($d.Monopolies)) {
        if (-not $CropClimate.ContainsKey([string]$m)) { continue }
        $c = $CropClimate[[string]$m]
        if ($clim[$c] + $clim[2] -eq 0) {
            $crop = $Crops | Where-Object { $_.Plant -eq $m }
            $mono = if ($Language -eq 'de') { $crop.deMono.Substring(0, 1).ToUpper() + $crop.deMono.Substring(1) } else { $crop.enMono.Substring(0, 1).ToUpper() + $crop.enMono.Substring(1) }
            return ((Txt '{0} needs a {1} island, and this map has none - choose another map number or crop.' '{0} braucht eine Insel im {1}; diese Karte hat keine – wähle eine andere Kartennummer oder Pflanze.') -f $mono, $(if ($c -eq 0) { Txt 'northern' 'Norden' } else { Txt 'southern' 'Süden' }))
        }
    }
    $null
}
# Problems of a design: Errors (no scenario) and Hints (the scenario is built anyway).
function Test-Design($d) {
    $errors = New-Object System.Collections.Generic.List[string]; $hintList = New-Object System.Collections.Generic.List[string]
    $ascii = ConvertTo-AsciiName $d.Name
    if (-not $ascii) { $errors.Add((Txt 'Give the scenario a name (letters or digits).' 'Gib dem Szenario einen Namen (Buchstaben oder Ziffern).')) }
    elseif ($d.Name.Trim().Length -gt $MaxNameLength) { $errors.Add(((Txt 'The name is too long (at most {0} characters).' 'Der Name ist zu lang (höchstens {0} Zeichen).') -f $MaxNameLength)) }
    $badName = @(Get-BadCharacters ($d.Name -replace '\s', ' '))
    if ($Language -eq 'de' -and $badName.Count) { $errors.Add(((Txt 'The name contains characters the game cannot show: {0}' 'Der Name enthält Zeichen, die das Spiel nicht zeigen kann: {0}') -f ($badName -join ' '))) }
    if ($d.MapKind -notin 'Classic', 'Archipelago', 'Continents') { $errors.Add("Unknown map kind '$($d.MapKind)'.") }
    if ($d.MapNumber -lt 0 -or $d.MapNumber -gt 999999) { $errors.Add((Txt 'The map number must lie between 0 and 999999.' 'Die Kartennummer muss zwischen 0 und 999999 liegen.')) }
    if ($d.Difficulty -lt 0 -or $d.Difficulty -gt 3 -or $d.RivalStrength -lt 0 -or $d.RivalStrength -gt 3) { $errors.Add('Difficulty and rival strength: 0 to 3.') }
    if (-not $NativesChoices.Contains([string]$d.Natives) -or -not $ResourceChoices.Contains([string]$d.Resources) -or -not $CargoChoices.Contains([string]$d.Cargo)) { $errors.Add('Unknown choice for natives, resources or cargo.') }
    foreach ($g in @($d.Gold, $d.RivalGold)) { if ($g -lt $Limits.Gold[0] -or $g -gt $Limits.Gold[1]) { $errors.Add(((Txt 'Gold: {0} to {1}.' 'Gold: {0} bis {1}.') -f $Limits.Gold[0], $Limits.Gold[1])); break } }
    if (@($d.Ships).Count -gt 3) { $errors.Add((Txt 'At most 3 extra ships.' 'Höchstens 3 weitere Schiffe.')) }
    if (@($d.Ships | Where-Object { $_ -notin $ShipTypeKeys }).Count) { $errors.Add('Unknown ship type.') }

    $goalCount = @($d.Towns).Count + @($d.Goods).Count + @($d.Monopolies).Count + @($d.Defeat).Count + [int][bool]$d.AllTowns + [int][bool]$d.TownCount + [int][bool]$d.TotalResidents + [int]($null -ne $d.Balance) + [int]($null -ne $d.TradeBalance)
    if ($goalCount -eq 0) { $errors.Add((Txt 'Choose at least one goal for the mission.' 'Wähle mindestens ein Ziel für den Auftrag.')) }
    if (@($d.Towns).Count -gt 3) { $errors.Add((Txt 'At most 3 town goals.' 'Höchstens 3 Stadt-Ziele.')) }
    $checkTown = {
        param($t, [string]$what)
        if ($t.Residents -lt $Limits.Residents[0] -or $t.Residents -gt $Limits.Residents[1]) { $errors.Add(((Txt '{0}: {1} to {2} residents.' '{0}: {1} bis {2} Einwohner.') -f $what, $Limits.Residents[0], $Limits.Residents[1])) }
        elseif ($t.OfWhich -lt 1 -or $t.OfWhich -gt $t.Residents) { $errors.Add(((Txt '{0}: “of which” must lie between 1 and the number of residents.' '{0}: „davon“ muss zwischen 1 und der Einwohnerzahl liegen.') -f $what)) }
        if ($t.Stage -lt 0 -or $t.Stage -gt 4) { $errors.Add("$($what): stage 0 to 4.") }
    }
    $k = 0; foreach ($t in @($d.Towns)) { $k++; & $checkTown $t ((Txt 'Town {0}' 'Stadt {0}') -f $k) }
    if ($d.AllTowns) { & $checkTown $d.AllTowns (Txt 'Every settlement' 'Jede Siedlung') }
    if ($d.TownCount -and ($d.TownCount -lt $Limits.TownCount[0] -or $d.TownCount -gt $Limits.TownCount[1])) { $errors.Add(((Txt 'Settlements: {0} to {1}.' 'Siedlungen: {0} bis {1}.') -f $Limits.TownCount[0], $Limits.TownCount[1])) }
    if ($d.TotalResidents -and ($d.TotalResidents -lt $Limits.TotalResidents[0] -or $d.TotalResidents -gt $Limits.TotalResidents[1])) { $errors.Add(((Txt 'Residents in total: {0} to {1}.' 'Einwohner insgesamt: {0} bis {1}.') -f $Limits.TotalResidents[0], $Limits.TotalResidents[1])) }
    if ($null -ne $d.Balance -and ($d.Balance -lt $Limits.Balance[0] -or $d.Balance -gt $Limits.Balance[1])) { $errors.Add(((Txt 'Balance: {0} to {1} talers.' 'Bilanz: {0} bis {1} Taler.') -f $Limits.Balance[0], $Limits.Balance[1])) }
    if ($null -ne $d.TradeBalance -and ($d.TradeBalance -lt $Limits.TradeBalance[0] -or $d.TradeBalance -gt $Limits.TradeBalance[1])) { $errors.Add(((Txt 'Trade balance: {0} to {1} talers.' 'Handelsbilanz: {0} bis {1} Taler.') -f $Limits.TradeBalance[0], $Limits.TradeBalance[1])) }
    if ($d.TimeLimitHours -and ($d.TimeLimitHours -lt $Limits.TimeLimit[0] -or $d.TimeLimitHours -gt $Limits.TimeLimit[1])) { $errors.Add(((Txt 'Time limit: {0} to {1} hours.' 'Zeitlimit: {0} bis {1} Stunden.') -f $Limits.TimeLimit[0], $Limits.TimeLimit[1])) }
    if (@($d.Goods).Count -gt 2) { $errors.Add((Txt 'At most 2 goods.' 'Höchstens 2 Waren.')) }
    foreach ($g in @($d.Goods)) {
        if ($g.Good -notin $GoalGoods) { $errors.Add("Unknown good $($g.Good).") }
        if ($g.Tons -lt $Limits.Tons[0] -or $g.Tons -gt $Limits.Tons[1]) { $errors.Add(((Txt 'Goods: {0} to {1} tons.' 'Waren: {0} bis {1} Tonnen.') -f $Limits.Tons[0], $Limits.Tons[1])); break }
    }
    if (@($d.Goods).Count -eq 2 -and $d.Goods[0].Good -eq $d.Goods[1].Good) { $errors.Add((Txt 'The same good twice - choose two different goods.' 'Zweimal dieselbe Ware – wähle zwei verschiedene.')) }
    if (@($d.Monopolies).Count -gt 2) { $errors.Add((Txt 'At most 2 monopolies.' 'Höchstens 2 Monopole.')) }
    if (@($d.Monopolies | Where-Object { $_ -notin $CropKeys }).Count) { $errors.Add('Unknown crop.') }
    if (@($d.Monopolies).Count -eq 2 -and $d.Monopolies[0] -eq $d.Monopolies[1]) { $errors.Add((Txt 'The same monopoly twice - choose two different crops.' 'Zweimal dasselbe Monopol – wähle zwei verschiedene Pflanzen.')) }
    if (@($d.Defeat | Where-Object { $_ -lt 1 -or $_ -gt 3 }).Count) { $errors.Add('Only the rivals 1 to 3 can be defeated.') }
    if ($null -ne $d.Story) {
        $bad = @(Get-BadCharacters (ConvertTo-PlainText $d.Story))
        if ($bad.Count) { $errors.Add(((Txt 'The story contains characters the game cannot show: {0}' 'Die Geschichte enthält Zeichen, die das Spiel nicht zeigen kann: {0}') -f ($bad -join ' '))) }
    }
    if ($errors.Count -eq 0) {
        $bytes = $Cp1252.GetByteCount((ConvertTo-DesignScenario $d).Text)
        if ($bytes -gt 2047) { $errors.Add(((Txt 'The mission text is too long ({0} of 2047 characters) - shorten the story.' 'Der Auftragstext ist zu lang ({0} von 2047 Zeichen) – kürze die Geschichte.') -f $bytes)) }
        try { $p = Get-DesignMapProblem $d (Get-DesignMaps $d).Small; if ($p) { $errors.Add($p) } }
        catch { $errors.Add(((Txt 'The map cannot be read: {0}' 'Die Karte lässt sich nicht lesen: {0}') -f $_.Exception.Message)) }
    }
    # Hints: allowed, but probably not what the player wants.
    $goodIds = @($d.Goods | ForEach-Object { $_.Good })
    if ($d.MapKind -eq 'Archipelago' -and ($goodIds | Where-Object { $_ -in 3, 12, 13, 21 })) { $hintList.Add((Txt 'Small islands may have no ore or gold mountains - gold, jewellery and weapons could be hard to make.' 'Auf kleinen Inseln gibt es vielleicht keine Erz- und Goldberge – Gold, Schmuck und Waffen werden dann schwierig.')) }
    $big = @($d.Towns | Where-Object { $_.Residents -ge 800 })
    if ($d.MapKind -eq 'Archipelago' -and $big.Count) { $hintList.Add((Txt 'Archipelago islands are small (at most 50 × 52): a town of 800 residents or more will be hard.' 'Archipel-Inseln sind klein (höchstens 50 × 52): eine Stadt ab 800 Einwohnern wird schwierig.')) }
    if (@($d.Defeat).Count -and -not @($d.Ships | Where-Object { $_ -ge 25 }).Count) { $hintList.Add((Txt 'Without a warship a war takes long - take one along.' 'Ohne Kriegsschiff dauert ein Krieg lange – nimm eines mit.')) }
    if ($d.Pirates -and -not @($d.Ships | Where-Object { $_ -ge 25 }).Count -and $d.Cargo -eq 'Shipwreck') { $hintList.Add((Txt 'Pirates and a shipwreck: one lost ship and the game is over.' 'Piraten und Schiffbruch: ein verlorenes Schiff, und das Spiel ist aus.')) }
    if ($d.TownCount -and $d.TownCount -lt @($d.Towns).Count) { $hintList.Add(((Txt 'The town goals alone already need {0} settlements.' 'Die Stadt-Ziele allein brauchen schon {0} Siedlungen.') -f @($d.Towns).Count)) }
    @{ Errors = $errors.ToArray(); Hints = $hintList.ToArray() }
}

# Builds the design (retrying other map variants if the map does not work) and copies it to the target folder.
# Returns @{ Title; Path; Summary; Bullets }.
function Invoke-DesignBuild($d) {
    $last = $null
    try {
        for ($attempt = 0; $attempt -lt 6; $attempt++) {
            $r = ConvertTo-DesignScenario $d $attempt
            try {
                $built = Build-Scenario $r.Scenario
                $counts = @(Get-AdvRivalIslandCounts $built.Path)
                if (@($counts | Where-Object { $_ -lt 4 }).Count) { throw "too few islands of class med or bigger for the rivals ($($counts -join ' / '))" }
                # The same map checks as for the preview, on both versions of the file (a retry builds another variant).
                $s = (Get-Section (Read-Scenario $built.Path) 'SZENE').Data
                foreach ($block in @(, $s) + @(, [byte[]]$s[0x4A4..($s.Length - 1)])) { $p = Get-DesignMapProblem $d @(Get-IslandList $block); if ($p) { throw $p } }
                New-Item -ItemType Directory -Force -Path $DesignTarget | Out-Null
                $target = Join-Path $DesignTarget ([IO.Path]::GetFileName($built.Path))
                Copy-Item -LiteralPath $built.Path -Destination $target -Force
                return @{ Title = (Get-DesignTitle $d); Path = $target; Summary = $built.Summary; Bullets = $r.Bullets; Attempt = $attempt }
            }
            catch { $last = $_.Exception.Message; Write-Verbose "Attempt $attempt failed: $last" }
        }
        throw ((Txt 'This map does not work ({0}). Please choose another map number.' 'Diese Karte geht nicht ({0}). Bitte eine andere Kartennummer wählen.') -f $last)
    }
    finally { if (Test-Path -LiteralPath $DesignBuildFolder) { Remove-Item -LiteralPath $DesignBuildFolder -Recurse -Force -ErrorAction SilentlyContinue } }
}
function Save-Design($d) {
    try {
        New-Item -ItemType Directory -Force -Path $DesignDataFolder | Out-Null
        $d | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $DesignFile -Encoding UTF8
    }
    catch { }
}

if ($FunctionsOnly) { return }

# --- Without a window: build a design file (tests) ---------------------------------------------------------
if ($BuildSpec) {
    $d = Read-DesignFile $BuildSpec
    $check = Test-Design $d
    foreach ($h in $check.Hints) { "HINT: $h" }
    if ($check.Errors.Count) { foreach ($e in $check.Errors) { "INVALID: $e" }; exit 1 }
    $r = Invoke-DesignBuild $d
    '{0}: {1}' -f $r.Title, $r.Path
    '  ' + $r.Summary + $(if ($r.Attempt) { " (map variant $($r.Attempt))" } else { '' })
    foreach ($b in $r.Bullets) { '  - ' + $b[$Language] }
    return
}

# --- The window ----------------------------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not $Owner) {
    if (-not ('AnnoStarter.Dpi' -as [type])) { Add-Type -Namespace AnnoStarter -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' }
    [void][AnnoStarter.Dpi]::SetProcessDPIAware()
    [Windows.Forms.Application]::EnableVisualStyles()
}
$design = $null
try { if ($SpecFile) { $design = Read-DesignFile $SpecFile } elseif (Test-Path -LiteralPath $DesignFile) { $design = Read-DesignFile $DesignFile } } catch { $design = $null }
if (-not $design) { $design = New-DefaultDesign }
$script:Result = @{ Created = @(); ShowList = $false }
$script:Loading = $false

$font = New-Object Drawing.Font('Segoe UI', 9)
$form = New-Object Windows.Forms.Form
$form.Text = Txt 'Build your own scenario – Anno 1602' 'Eigenes Szenario bauen – Anno 1602'
$form.Font = $font
$form.AutoScaleMode = 'Dpi'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = if ($Owner) { 'CenterParent' } else { 'CenterScreen' }
$form.Padding = New-Object Windows.Forms.Padding(10)
if ($Owner -and $Owner.Icon) { $form.Icon = $Owner.Icon }
$tips = New-Object Windows.Forms.ToolTip

$outer = New-Object Windows.Forms.TableLayoutPanel
$outer.AutoSize = $true
$outer.ColumnCount = 2
foreach ($i in 1..2) { [void]$outer.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
$form.Controls.Add($outer)
function New-Column {
    $c = New-Object Windows.Forms.FlowLayoutPanel
    $c.AutoSize = $true; $c.FlowDirection = 'TopDown'; $c.WrapContents = $false; $c.Margin = New-Object Windows.Forms.Padding(0, 0, 8, 0)
    $outer.Controls.Add($c); $c
}
$leftColumn = New-Column
$rightColumn = New-Column

function New-Group([string]$text, $parent, [int]$columns = 2) {
    $box = New-Object Windows.Forms.GroupBox
    $box.Text = $text; $box.AutoSize = $true
    $box.Padding = New-Object Windows.Forms.Padding(6, 4, 6, 2); $box.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 6)
    $grid = New-Object Windows.Forms.TableLayoutPanel
    $grid.AutoSize = $true; $grid.ColumnCount = $columns; $grid.Dock = 'Fill'
    for ($i = 0; $i -lt $columns; $i++) { [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
    $box.Controls.Add($grid); $parent.Controls.Add($box)
    $grid
}
function New-Text([string]$text, [int]$top = 6, [int]$left = 3) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text; $l.AutoSize = $true; $l.Margin = New-Object Windows.Forms.Padding($left, $top, 3, 0)
    $l
}
function New-Combo($items, [int]$width) {
    $c = New-Object Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'; $c.Width = $width; $c.Margin = New-Object Windows.Forms.Padding(3, 2, 3, 2)
    foreach ($i in $items) { [void]$c.Items.Add($i) }
    $c
}
function New-Number([int]$min, [int]$max, [int]$step, [int]$width) {
    $n = New-Object Windows.Forms.NumericUpDown
    $n.Minimum = $min; $n.Maximum = $max; $n.Increment = $step; $n.Width = $width; $n.ThousandsSeparator = $true
    $n.Margin = New-Object Windows.Forms.Padding(3, 2, 3, 2); $n.TextAlign = 'Right'
    $n
}
function New-Check([string]$text, [int]$width = 0) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $text; $c.AutoSize = $true; $c.Margin = New-Object Windows.Forms.Padding(3, 4, 3, 0)
    if ($width) { $c.MinimumSize = New-Object Drawing.Size($width, 0) }
    $c
}
function New-Flow {
    $f = New-Object Windows.Forms.FlowLayoutPanel
    $f.AutoSize = $true; $f.WrapContents = $false; $f.Margin = New-Object Windows.Forms.Padding(0)
    $f
}
# A labelled row of a group: label in the first column, the controls in the second.
function Add-Row($grid, [string]$label, $controls) {
    $l = New-Text $label 6 3; $l.Margin = New-Object Windows.Forms.Padding(3, 6, 10, 0)
    $grid.Controls.Add($l)
    $f = New-Flow; foreach ($c in @($controls)) { $f.Controls.Add($c) }
    $grid.Controls.Add($f)
}

# --- Scenario ---
$gridScenario = New-Group (Txt 'Scenario' 'Szenario') $leftColumn
$nameBox = New-Object Windows.Forms.TextBox
$nameBox.Width = 250; $nameBox.MaxLength = $MaxNameLength; $nameBox.Margin = New-Object Windows.Forms.Padding(3, 3, 3, 2)
Add-Row $gridScenario (Txt 'Name' 'Name') $nameBox
$fileLabel = New-Text '' 2 3; $fileLabel.ForeColor = [Drawing.Color]::DimGray
Add-Row $gridScenario '' $fileLabel
$MapKinds = @('Classic', 'Archipelago', 'Continents')
$mapCombo = New-Combo @((Txt 'Classic (large and small islands)' 'Klassisch (grosse und kleine Inseln)'), (Txt 'Archipelago (many small islands)' 'Archipel (viele kleine Inseln)'), (Txt 'Continents (a few huge islands)' 'Kontinente (wenige riesige Inseln)')) 250
Add-Row $gridScenario (Txt 'Map' 'Karte') $mapCombo
$mapNumber = New-Number 0 999999 1 85; $mapNumber.ThousandsSeparator = $false
$buttonNewMap = New-Object Windows.Forms.Button
$buttonNewMap.Text = Txt 'New map' 'Neue Karte'; $buttonNewMap.AutoSize = $true; $buttonNewMap.Margin = New-Object Windows.Forms.Padding(6, 1, 3, 1)
$tips.SetToolTip($buttonNewMap, (Txt 'Rolls another map of the same kind. The same number always gives the same map.' 'Würfelt eine andere Karte derselben Art. Dieselbe Nummer ergibt immer dieselbe Karte.'))
Add-Row $gridScenario (Txt 'Map number' 'Kartennummer') @($mapNumber, $buttonNewMap)
$difficultyCombo = New-Combo @($LevelText | ForEach-Object { $_[$Language] }) 170
$tips.SetToolTip($difficultyCombo, (Txt 'The game''s difficulty and the template of the map.' 'Schwierigkeit des Spiels und Vorlage der Karte.'))
Add-Row $gridScenario (Txt 'Difficulty' 'Schwierigkeit') $difficultyCombo

# --- World and rivals ---
$gridWorld = New-Group (Txt 'World, rivals and ships' 'Welt, Gegner und Schiffe') $leftColumn
$goldBox = New-Number $Limits.Gold[0] $Limits.Gold[1] 5000 100
Add-Row $gridWorld (Txt 'Your starting gold' 'Dein Startgold') $goldBox
$rivalGoldBox = New-Number $Limits.Gold[0] $Limits.Gold[1] 5000 100
Add-Row $gridWorld (Txt "Rivals' gold" 'Gold der Gegner') $rivalGoldBox
$strengthCombo = New-Combo @((Txt 'Hesitant (like Easy)' 'Zögerlich (wie Einfach)'), (Txt 'Normal (like Average)' 'Normal (wie Durchschnittlich)'), (Txt 'Determined (like Demanding)' 'Entschlossen (wie Fordernd)'), (Txt 'Strong (like Hard)' 'Stark (wie Schwer)')) 250
Add-Row $gridWorld (Txt "Rivals' strength" 'Stärke der Gegner') $strengthCombo
$piratesCombo = New-Combo @((Txt 'Only sighted (no attacks)' 'Nur gesichtet (keine Angriffe)'), (Txt 'They attack' 'Greifen an')) 250
Add-Row $gridWorld (Txt 'Pirates' 'Piraten') $piratesCombo
$NativesKeys = @($NativesChoices.Keys)
$nativesCombo = New-Combo @((Txt 'Few (1 + 1 villages)' 'Wenige (1 + 1 Dörfer)'), (Txt 'Normal (2 + 2 villages)' 'Normal (2 + 2 Dörfer)'), (Txt 'Many (4 + 4 villages)' 'Viele (4 + 4 Dörfer)')) 250
Add-Row $gridWorld (Txt 'Natives' 'Ureinwohner') $nativesCombo
$ResourceKeys = @($ResourceChoices.Keys)
$resourcesCombo = New-Combo @((Txt 'Few (little ore and gold)' 'Wenig (wenig Erz und Gold)'), (Txt 'Normal' 'Normal'), (Txt 'Lots (plenty of ore, gold, treasures)' 'Viel (reichlich Erz, Gold, Schätze)')) 250
$tips.SetToolTip($resourcesCombo, (Txt 'The crops and ore that the mission needs are added anyway.' 'Pflanzen und Erz, die der Auftrag braucht, kommen sowieso dazu.'))
Add-Row $gridWorld (Txt 'Resources' 'Rohstoffe') $resourcesCombo
$CargoKeys = @($CargoChoices.Keys)
$cargoCombo = New-Combo @((Txt 'Standard' 'Standard'), (Txt 'Rich' 'Reichlich'), (Txt 'Lean' 'Knapp'), (Txt 'Shipwreck (very little)' 'Schiffbruch (sehr wenig)')) 250
Add-Row $gridWorld (Txt 'Start cargo' 'Startladung') $cargoCombo
$cargoLabel = New-Text '' 1 3; $cargoLabel.ForeColor = [Drawing.Color]::DimGray
Add-Row $gridWorld '' $cargoLabel
$CargoGoodText = @{ Tools = (Txt 'tools' 'Werkzeug'); Wood = (Txt 'wood' 'Holz'); Food = (Txt 'food' 'Nahrung'); Bricks = (Txt 'bricks' 'Ziegel') }
$shipBoxes = @{}
foreach ($t in $ShipTypeKeys) { $shipBoxes[$t] = New-Number 0 3 1 42 }
Add-Row $gridWorld (Txt 'Extra trading ships' 'Weitere Handelsschiffe') @((New-Text (Txt 'small' 'klein') 5), $shipBoxes[21], (New-Text (Txt 'large' 'gross') 5 10), $shipBoxes[23])
Add-Row $gridWorld (Txt 'Extra warships' 'Weitere Kriegsschiffe') @((New-Text (Txt 'small' 'klein') 5), $shipBoxes[25], (New-Text (Txt 'large' 'gross') 5 10), $shipBoxes[27])
$tips.SetToolTip($shipBoxes[21], (Txt 'At most 3 extra ships. Trading ships carry 30 t tools and 30 t wood.' 'Höchstens 3 weitere Schiffe. Handelsschiffe bringen 30 t Werkzeug und 30 t Holz mit.'))

# --- Story ---
$storyBox = New-Object Windows.Forms.GroupBox
$storyBox.Text = Txt 'Story (generated – change it as you like)' 'Geschichte (erzeugt – ändere sie nach Lust und Laune)'
$storyBox.AutoSize = $true; $storyBox.Padding = New-Object Windows.Forms.Padding(6, 4, 6, 4); $storyBox.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 6)
$storyPanel = New-Object Windows.Forms.FlowLayoutPanel
$storyPanel.AutoSize = $true; $storyPanel.FlowDirection = 'TopDown'; $storyPanel.WrapContents = $false; $storyPanel.Dock = 'Fill'
$storyBox.Controls.Add($storyPanel)
$storyText = New-Object Windows.Forms.TextBox
$storyText.Multiline = $true; $storyText.AcceptsReturn = $true; $storyText.ScrollBars = 'Vertical'; $storyText.Width = 390; $storyText.Height = 112; $storyText.MaxLength = 1400
$storyPanel.Controls.Add($storyText)
$storyRow = New-Flow
$buttonNewStory = New-Object Windows.Forms.Button
$buttonNewStory.Text = Txt 'New story' 'Neue Geschichte'; $buttonNewStory.AutoSize = $true
$storyRow.Controls.Add($buttonNewStory)
$storyNote = New-Text '' 7 6; $storyNote.ForeColor = [Drawing.Color]::DimGray
$storyRow.Controls.Add($storyNote)
$storyPanel.Controls.Add($storyRow)
$leftColumn.Controls.Add($storyBox)

# --- Mission ---
$missionBox = New-Object Windows.Forms.GroupBox
$missionBox.Text = Txt 'Mission – tick the goals' 'Auftrag – Ziele ankreuzen'
$missionBox.AutoSize = $true; $missionBox.Padding = New-Object Windows.Forms.Padding(6, 4, 6, 2); $missionBox.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 6)
$missionPanel = New-Object Windows.Forms.FlowLayoutPanel
$missionPanel.AutoSize = $true; $missionPanel.FlowDirection = 'TopDown'; $missionPanel.WrapContents = $false; $missionPanel.Dock = 'Fill'
$missionBox.Controls.Add($missionPanel)
$rightColumn.Controls.Add($missionBox)
$StageNames = @($StageText[$Language] | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) })
# First column as wide as the longest town label, so that the four town rows line up.
$CheckWidth = 22 + [math]::Max([Windows.Forms.TextRenderer]::MeasureText((Txt 'Every settlement' 'Jede Siedlung'), $font).Width, [Windows.Forms.TextRenderer]::MeasureText((Txt 'Town 3' 'Stadt 3'), $font).Width)
# Town goal row: [x] label  [residents] residents, of which [n] [stage] or higher
function New-TownRow([string]$label) {
    $row = New-Flow
    $c = New-Check $label $CheckWidth
    $res = New-Number $Limits.Residents[0] $Limits.Residents[1] 50 60
    $of = New-Number 1 $Limits.Residents[1] 10 56
    $stage = New-Combo $StageNames 92
    $row.Controls.Add($c); $row.Controls.Add($res); $row.Controls.Add((New-Text (Txt 'residents, of which' 'Einwohner, davon') 5)); $row.Controls.Add($of); $row.Controls.Add($stage)
    $row.Controls.Add((New-Text (Txt 'or higher' 'oder höher') 5))
    $missionPanel.Controls.Add($row)
    @{ Check = $c; Residents = $res; OfWhich = $of; Stage = $stage }
}
$townRows = @(1..3 | ForEach-Object { New-TownRow ((Txt 'Town {0}' 'Stadt {0}') -f $_) })
$allRow = New-TownRow (Txt 'Every settlement' 'Jede Siedlung')
$tips.SetToolTip($allRow.Check, (Txt 'Every settlement of yours must reach this - even a warehouse without houses counts.' 'Jede deiner Siedlungen muss das erreichen – auch ein Kontor ohne Häuser zählt.'))
$row = New-Flow
$checkTownCount = New-Check (Txt 'Settlements, at least' 'Siedlungen, mindestens') $CheckWidth
$townCountBox = New-Number $Limits.TownCount[0] $Limits.TownCount[1] 1 50
$checkTotal = New-Check (Txt 'Residents in total' 'Einwohner insgesamt'); $checkTotal.Margin = New-Object Windows.Forms.Padding(24, 4, 3, 0)
$totalBox = New-Number $Limits.TotalResidents[0] $Limits.TotalResidents[1] 100 72
foreach ($c in $checkTownCount, $townCountBox, $checkTotal, $totalBox) { $row.Controls.Add($c) }
$missionPanel.Controls.Add($row)
$row = New-Flow
$checkBalance = New-Check (Txt 'Balance at least +' 'Bilanz mindestens +') $CheckWidth
$balanceBox = New-Number $Limits.Balance[0] $Limits.Balance[1] 50 62
$checkTrade = New-Check (Txt 'Trade balance at least +' 'Handelsbilanz mind. +'); $checkTrade.Margin = New-Object Windows.Forms.Padding(24, 4, 3, 0)
$tradeBox = New-Number $Limits.TradeBalance[0] $Limits.TradeBalance[1] 50 62
foreach ($c in $checkBalance, $balanceBox, $checkTrade, $tradeBox) { $row.Controls.Add($c) }
$missionPanel.Controls.Add($row)
$tips.SetToolTip($checkBalance, (Txt 'Balance as in the status window: taxes + sales - purchases - running costs. 0 = in the black.' 'Bilanz wie im Statusfenster: Steuern + Verkäufe - Einkäufe - Betriebskosten. 0 = im Plus.'))
$tips.SetToolTip($checkTrade, (Txt 'Sales minus purchases.' 'Verkäufe minus Einkäufe.'))
$GoodNames = @($GoalGoods | ForEach-Object { $n = $GoodText[$_][$Language]; $n.Substring(0, 1).ToUpper() + $n.Substring(1) })
$goodsRows = foreach ($k in 1, 2) {
    $row = New-Flow
    $c = New-Check $(if ($k -eq 1) { Txt 'Goods in stock' 'Waren im Lager' } else { Txt 'and' 'und' }) $CheckWidth
    $good = New-Combo $GoodNames 120
    $tons = New-Number $Limits.Tons[0] $Limits.Tons[1] 5 52
    foreach ($x in $c, $good, $tons) { $row.Controls.Add($x) }
    $row.Controls.Add((New-Text (Txt 'tons' 'Tonnen') 5))
    $missionPanel.Controls.Add($row)
    @{ Check = $c; Good = $good; Tons = $tons }
}
$CropNames = @($Crops | ForEach-Object { $n = $_[$(if ($Language -eq 'de') { 'de' } else { 'en' })]; $n.Substring(0, 1).ToUpper() + $n.Substring(1) })
$row = New-Flow
$monoRows = foreach ($k in 1, 2) {
    $c = New-Check $(if ($k -eq 1) { Txt 'Monopoly' 'Monopol' } else { Txt 'and' 'und' }) $(if ($k -eq 1) { $CheckWidth } else { 0 })
    if ($k -eq 2) { $c.Margin = New-Object Windows.Forms.Padding(14, 4, 3, 0) }
    $crop = New-Combo $CropNames 110
    $row.Controls.Add($c); $row.Controls.Add($crop)
    @{ Check = $c; Crop = $crop }
}
$missionPanel.Controls.Add($row)
$tips.SetToolTip($monoRows[0].Check, (Txt 'A settlement of your own on every island where the crop grows, and no rival there.' 'Eine eigene Siedlung auf jeder Insel, auf der die Pflanze wächst, und kein Rivale dort.'))
$row = New-Flow
$row.Controls.Add((New-Text (Txt 'Defeat' 'Besiegen') 5 3))
$defeatChecks = @(1..3 | ForEach-Object { $c = New-Check ((Txt 'Rival {0}' 'Gegner {0}') -f $_); $c.Margin = New-Object Windows.Forms.Padding(12, 4, 3, 0); $row.Controls.Add($c); $c })
$row.Controls[0].MinimumSize = New-Object Drawing.Size(($CheckWidth - 12), 0)
$missionPanel.Controls.Add($row)
$tips.SetToolTip($defeatChecks[0], (Txt 'A rival is defeated when he owns no settlement and no ship any more. The text names his flagship.' 'Ein Gegner ist besiegt, wenn er keine Siedlung und kein Schiff mehr hat. Der Text nennt sein Flaggschiff.'))
$row = New-Flow
$checkTime = New-Check (Txt 'Time limit' 'Zeitlimit') $CheckWidth
$timeBox = New-Number $Limits.TimeLimit[0] $Limits.TimeLimit[1] 1 50
$row.Controls.Add($checkTime); $row.Controls.Add($timeBox)
$row.Controls.Add((New-Text (Txt 'game hours (only with the extensions)' 'Spielstunden (nur mit den Erweiterungen)') 5))
$missionPanel.Controls.Add($row)
$tips.SetToolTip($checkTime, (Txt 'The mission is lost when the time runs out. Only when the game runs with the extensions; the logbook shows the time left.' 'Läuft die Zeit ab, ist der Auftrag verloren. Nur wenn das Spiel mit den Erweiterungen läuft; das Logbuch zeigt die verbleibende Zeit.'))

# --- Preview: mission text and map ---
$previewTabs = New-Object Windows.Forms.TabControl
$previewTabs.Width = 524; $previewTabs.Height = 318; $previewTabs.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 4)
$tabText = New-Object Windows.Forms.TabPage; $tabText.Text = Txt 'Mission text as in the game' 'Auftragstext wie im Spiel'
$tabMap = New-Object Windows.Forms.TabPage; $tabMap.Text = Txt 'Map' 'Karte'
$previewTabs.TabPages.Add($tabText); $previewTabs.TabPages.Add($tabMap)
$previewBox = New-Object Windows.Forms.TextBox
$previewBox.Multiline = $true; $previewBox.ReadOnly = $true; $previewBox.ScrollBars = 'Vertical'; $previewBox.Dock = 'Fill'
$previewBox.BackColor = [Drawing.Color]::FromArgb(246, 238, 216); $previewBox.ForeColor = [Drawing.Color]::FromArgb(60, 40, 20)
$previewBox.Font = New-Object Drawing.Font('Georgia', 9)
$tabText.Controls.Add($previewBox)
$mapPicture = New-Object Windows.Forms.PictureBox
$mapPicture.Dock = 'Fill'; $mapPicture.BackColor = [Drawing.Color]::White
$tabMap.Controls.Add($mapPicture)
$rightColumn.Controls.Add($previewTabs)
$messageLabel = New-Object Windows.Forms.Label
$messageLabel.AutoSize = $true; $messageLabel.MaximumSize = New-Object Drawing.Size(524, 0); $messageLabel.Margin = New-Object Windows.Forms.Padding(3, 0, 3, 4)
$rightColumn.Controls.Add($messageLabel)

# --- Buttons ---
$buttonRow = New-Flow
$buttonRow.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 0)
function New-BigButton([string]$text) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.AutoSize = $true; $b.Padding = New-Object Windows.Forms.Padding(8, 3, 8, 3); $b.Margin = New-Object Windows.Forms.Padding(0, 0, 8, 0)
    $buttonRow.Controls.Add($b); $b
}
$buttonCreate = New-BigButton (Txt 'Create scenario' 'Szenario erstellen')
$buttonReset = New-BigButton (Txt 'Start afresh' 'Neu beginnen')
$buttonClose = New-BigButton (Txt 'Close' 'Schliessen')
$leftColumn.Controls.Add($buttonRow)
$form.CancelButton = $buttonClose

# --- Design <-> controls ---------------------------------------------------------------------------------------
function Set-Number($box, $value) { $box.Value = [decimal][math]::Min([math]::Max([double]$value, [double]$box.Minimum), [double]$box.Maximum) }
function Set-Town($r, $t, [int]$res, [int]$stage, [int]$of) {
    $r.Check.Checked = [bool]$t
    if ($t) { $res = $t.Residents; $stage = $t.Stage; $of = $t.OfWhich }
    Set-Number $r.Residents $res; Set-Number $r.OfWhich $of; $r.Stage.SelectedIndex = [math]::Min(4, [math]::Max(0, $stage))
}
function Set-DesignControls($d) {
    $script:Loading = $true
    try {
        $nameBox.Text = $d.Name
        $mapCombo.SelectedIndex = [math]::Max(0, [array]::IndexOf($MapKinds, [string]$d.MapKind))
        Set-Number $mapNumber $d.MapNumber
        $difficultyCombo.SelectedIndex = [math]::Min(3, [math]::Max(0, $d.Difficulty))
        Set-Number $goldBox $d.Gold; Set-Number $rivalGoldBox $d.RivalGold
        $strengthCombo.SelectedIndex = [math]::Min(3, [math]::Max(0, $d.RivalStrength))
        $piratesCombo.SelectedIndex = [int][bool]$d.Pirates
        $nativesCombo.SelectedIndex = [math]::Max(0, [array]::IndexOf($NativesKeys, [string]$d.Natives))
        $resourcesCombo.SelectedIndex = [math]::Max(0, [array]::IndexOf($ResourceKeys, [string]$d.Resources))
        $cargoCombo.SelectedIndex = [math]::Max(0, [array]::IndexOf($CargoKeys, [string]$d.Cargo))
        foreach ($t in $ShipTypeKeys) { Set-Number $shipBoxes[$t] @($d.Ships | Where-Object { $_ -eq $t }).Count }
        $defaults = @(@(500, 2, 250), @(300, 1, 150), @(200, 1, 100))
        for ($k = 0; $k -lt 3; $k++) { Set-Town $townRows[$k] @($d.Towns)[$k] $defaults[$k][0] $defaults[$k][1] $defaults[$k][2] }
        Set-Town $allRow $d.AllTowns 150 1 60
        $checkTownCount.Checked = [bool]$d.TownCount; Set-Number $townCountBox $(if ($d.TownCount) { $d.TownCount } else { 5 })
        $checkTotal.Checked = [bool]$d.TotalResidents; Set-Number $totalBox $(if ($d.TotalResidents) { $d.TotalResidents } else { 2000 })
        $checkBalance.Checked = $null -ne $d.Balance; Set-Number $balanceBox $(if ($null -ne $d.Balance) { $d.Balance } else { 300 })
        $checkTrade.Checked = $null -ne $d.TradeBalance; Set-Number $tradeBox $(if ($null -ne $d.TradeBalance) { $d.TradeBalance } else { 200 })
        $goodDefaults = @(@(21, 40), @(20, 60))
        for ($k = 0; $k -lt 2; $k++) {
            $g = @($d.Goods)[$k]
            $goodsRows[$k].Check.Checked = [bool]$g
            $goodsRows[$k].Good.SelectedIndex = [math]::Max(0, [array]::IndexOf($GoalGoods, [int]$(if ($g) { $g.Good } else { $goodDefaults[$k][0] })))
            Set-Number $goodsRows[$k].Tons $(if ($g) { $g.Tons } else { $goodDefaults[$k][1] })
        }
        for ($k = 0; $k -lt 2; $k++) {
            $m = @($d.Monopolies)[$k]
            $monoRows[$k].Check.Checked = [bool]$m
            $monoRows[$k].Crop.SelectedIndex = [math]::Max(0, [array]::IndexOf($CropKeys, [string]$(if ($m) { $m } else { $CropKeys[$k] })))
        }
        for ($k = 0; $k -lt 3; $k++) { $defeatChecks[$k].Checked = @($d.Defeat) -contains ($k + 1) }
        $checkTime.Checked = [bool]$d.TimeLimitHours; Set-Number $timeBox $(if ($d.TimeLimitHours) { $d.TimeLimitHours } else { 4 })
        $script:StorySeed = $d.StorySeed
        $script:StoryEdited = $null -ne $d.Story
        if ($script:StoryEdited) { $storyText.Text = $d.Story -replace "`r?`n", "`r`n" }
    }
    finally { $script:Loading = $false }
}
function Get-DesignFromControls {
    $d = New-DefaultDesign
    $d.Name = $nameBox.Text
    $d.MapKind = $MapKinds[$mapCombo.SelectedIndex]; $d.MapNumber = [int]$mapNumber.Value; $d.Difficulty = $difficultyCombo.SelectedIndex
    $d.Gold = [int]$goldBox.Value; $d.RivalGold = [int]$rivalGoldBox.Value; $d.RivalStrength = $strengthCombo.SelectedIndex; $d.Pirates = $piratesCombo.SelectedIndex -eq 1
    $d.Natives = $NativesKeys[$nativesCombo.SelectedIndex]; $d.Resources = $ResourceKeys[$resourcesCombo.SelectedIndex]; $d.Cargo = $CargoKeys[$cargoCombo.SelectedIndex]
    $d.Ships = @(foreach ($t in $ShipTypeKeys) { for ($i = 0; $i -lt [int]$shipBoxes[$t].Value; $i++) { $t } })
    $d.Towns = @($townRows | Where-Object { $_.Check.Checked } | ForEach-Object { @{ Residents = [int]$_.Residents.Value; Stage = $_.Stage.SelectedIndex; OfWhich = [int]$_.OfWhich.Value } })
    $d.AllTowns = if ($allRow.Check.Checked) { @{ Residents = [int]$allRow.Residents.Value; Stage = $allRow.Stage.SelectedIndex; OfWhich = [int]$allRow.OfWhich.Value } } else { $null }
    $d.TownCount = if ($checkTownCount.Checked) { [int]$townCountBox.Value } else { 0 }
    $d.TotalResidents = if ($checkTotal.Checked) { [int]$totalBox.Value } else { 0 }
    $d.Balance = if ($checkBalance.Checked) { [int]$balanceBox.Value } else { $null }
    $d.TradeBalance = if ($checkTrade.Checked) { [int]$tradeBox.Value } else { $null }
    $d.Goods = @($goodsRows | Where-Object { $_.Check.Checked } | ForEach-Object { @{ Good = $GoalGoods[$_.Good.SelectedIndex]; Tons = [int]$_.Tons.Value } })
    $d.Monopolies = @($monoRows | Where-Object { $_.Check.Checked } | ForEach-Object { $CropKeys[$_.Crop.SelectedIndex] })
    $d.Defeat = @(for ($k = 0; $k -lt 3; $k++) { if ($defeatChecks[$k].Checked) { $k + 1 } })
    $d.TimeLimitHours = if ($checkTime.Checked) { [int]$timeBox.Value } else { 0 }
    $d.StorySeed = $script:StorySeed
    $d.Story = if ($script:StoryEdited) { $storyText.Text } else { $null }
    $d
}

function Update-MapPicture {
    $w = [math]::Max(200, $mapPicture.ClientSize.Width); $h = [math]::Max(150, $mapPicture.ClientSize.Height)
    $bmp = New-Object Drawing.Bitmap($w, $h)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::White)
    try {
        $maps = Get-DesignMaps (Get-DesignFromControls) -Big
        $mw = [math]::Floor(($w - 30) / 2); $mh = [math]::Floor($mw * 0.7)
        $sea = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(70, 130, 180))
        $land = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(222, 205, 140))
        $green = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(96, 150, 70))
        $textBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(40, 40, 40))
        foreach ($v in @(@{ X = 10; List = $maps.Small; W = 500; H = 350; Label = (Txt 'Original map 500 × 350: {0} islands' 'Originalkarte 500 × 350: {0} Inseln') },
                @{ X = 20 + $mw; List = $maps.Big; W = 1000; H = 700; Label = (Txt 'With the extensions 1000 × 700: {0} islands' 'Mit Erweiterungen 1000 × 700: {0} Inseln') })) {
            $g.FillRectangle($sea, $v.X, 10, $mw, $mh)
            $f = $mw / $v.W
            foreach ($e in $v.List) {
                $rw = [math]::Max(2, $ClassW[$e.Class] * $f); $rh = [math]::Max(2, $ClassH[$e.Class] * $f)
                $x = $v.X + $e.X * $f; $y = 10 + $e.Y * $f
                $g.FillEllipse($land, [single]$x, [single]$y, [single]$rw, [single]$rh)
                $g.FillEllipse($green, [single]($x + $rw * 0.15), [single]($y + $rh * 0.15), [single]($rw * 0.7), [single]($rh * 0.7))
            }
            $g.DrawString(($v.Label -f @($v.List).Count), $font, $textBrush, [single]$v.X, [single](16 + $mh))
        }
        $kindText = @{ Classic = (Txt 'Classic: some islands one size bigger.' 'Klassisch: einige Inseln eine Grösse grösser.'); Archipelago = (Txt 'Archipelago: many small islands (at most 50 × 52).' 'Archipel: viele kleine Inseln (höchstens 50 × 52).'); Continents = (Txt 'Continents: a few huge islands.' 'Kontinente: wenige riesige Inseln.') }[$MapKinds[$mapCombo.SelectedIndex]]
        $note = $kindText + ' ' + (Txt 'Island sizes as drawn; the game draws the coasts itself. The big version is used with the launcher (map 1000 × 700, “More islands”).' 'Inselgrössen wie gezeichnet; die Küsten zeichnet das Spiel selbst. Die grosse Version gilt im Starter mit Karte 1000 × 700 und „Mehr Inseln“.')
        $g.DrawString($note, $font, $textBrush, (New-Object Drawing.RectangleF(10, (40 + $mh), ($w - 20), ($h - 45 - $mh))))
    }
    catch { $g.DrawString(((Txt 'No map preview: {0}' 'Keine Kartenvorschau: {0}') -f $_.Exception.Message), $font, [Drawing.Brushes]::DarkRed, (New-Object Drawing.RectangleF(10, 10, ($w - 20), ($h - 20)))) }
    finally { $g.Dispose() }
    if ($mapPicture.Image) { $mapPicture.Image.Dispose() }
    $mapPicture.Image = $bmp
}

# --- Live preview ---------------------------------------------------------------------------------------------
function Update-Preview {
    if ($script:Loading) { return }
    $d = Get-DesignFromControls
    $fileLabel.Text = (Txt 'File: “{0}.szs”' 'Datei: „{0}.szs“') -f (Get-DesignTitle $d)
    $check = Test-Design $d
    try {
        $r = ConvertTo-DesignScenario $d
        $cargo = if ($r.Scenario.Cargo) { $r.Scenario.Cargo } else { @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 30 }, @{ Good = 'Food'; Tons = 10 }) }
        $cargoLabel.Text = @($cargo | ForEach-Object { '{0} t {1}' -f $_.Tons, $CargoGoodText[$_.Good] }) -join ', '
        if (-not $script:StoryEdited) {
            $script:Loading = $true
            try { $storyText.Text = $r.GeneratedStory } finally { $script:Loading = $false }
        }
        $previewBox.Text = ($r.Text -replace "`n", "`r`n")
        $bytes = $Cp1252.GetByteCount($r.Text)
        $storyNote.Text = if ($script:StoryEdited) { (Txt 'changed by you · text {0} of 2047 characters' 'von dir geändert · Text {0} von 2047 Zeichen') -f $bytes } else { (Txt 'text {0} of 2047 characters' 'Text {0} von 2047 Zeichen') -f $bytes }
    }
    catch { $previewBox.Text = $_.Exception.Message }
    $lines = @($check.Errors | ForEach-Object { '✗ ' + $_ }) + @($check.Hints | ForEach-Object { 'ⓘ ' + $_ })
    $messageLabel.Text = $lines -join [Environment]::NewLine
    $messageLabel.ForeColor = if ($check.Errors.Count) { [Drawing.Color]::Firebrick } else { [Drawing.Color]::FromArgb(150, 90, 0) }
    $buttonCreate.Enabled = $check.Errors.Count -eq 0
    if ($previewTabs.SelectedTab -eq $tabMap) { Update-MapPicture }
}

# Every change of a control updates the preview.
foreach ($c in @($nameBox)) { $c.Add_TextChanged({ Update-Preview }) }
foreach ($c in @($mapCombo, $difficultyCombo, $strengthCombo, $piratesCombo, $nativesCombo, $resourcesCombo, $cargoCombo) + @($townRows + $allRow | ForEach-Object { $_.Stage }) + @($goodsRows | ForEach-Object { $_.Good }) + @($monoRows | ForEach-Object { $_.Crop })) { $c.Add_SelectedIndexChanged({ Update-Preview }) }
foreach ($c in @($mapNumber, $goldBox, $rivalGoldBox, $townCountBox, $totalBox, $balanceBox, $tradeBox, $timeBox) +@($shipBoxes.Values) + @($townRows + $allRow | ForEach-Object { $_.Residents; $_.OfWhich }) + @($goodsRows | ForEach-Object { $_.Tons })) { $c.Add_ValueChanged({ Update-Preview }) }
foreach ($c in @($checkTownCount, $checkTotal, $checkBalance, $checkTrade, $checkTime) + $defeatChecks + @($townRows + $allRow + $goodsRows + $monoRows | ForEach-Object { $_.Check })) { $c.Add_CheckedChanged({ Update-Preview }) }
$storyText.Add_TextChanged({ if (-not $script:Loading) { $script:StoryEdited = $true; Update-Preview } })
$buttonNewStory.Add_Click({ $script:StorySeed = Get-Random -Minimum 1 -Maximum 1000000; $script:StoryEdited = $false; Update-Preview })
$buttonNewMap.Add_Click({ $mapNumber.Value = Get-Random -Minimum 1 -Maximum 1000000 })
$previewTabs.Add_SelectedIndexChanged({ if ($previewTabs.SelectedTab -eq $tabMap) { $form.Cursor = [Windows.Forms.Cursors]::WaitCursor; try { Update-MapPicture } finally { $form.Cursor = [Windows.Forms.Cursors]::Default } } })
$buttonReset.Add_Click({ Set-DesignControls (New-DefaultDesign); Update-Preview })
$buttonClose.Add_Click({ $form.Close() })

# Questions: a message box, or "yes" in the click test.
function Show-Question([string]$text) {
    if ($TestCreate) { $script:Questions += $text; return $true }
    [Windows.Forms.MessageBox]::Show($form, $text, $form.Text, 'YesNo', 'Question') -eq 'Yes'
}
$script:Questions = @()
$buttonCreate.Add_Click({
        $d = Get-DesignFromControls
        $check = Test-Design $d
        if ($check.Errors.Count) { return }
        $title = Get-DesignTitle $d
        if ((Test-Path -LiteralPath (Join-Path $DesignTarget "$title.szs")) -and -not (Show-Question ((Txt '“{0}” exists already. Replace it?' '„{0}“ gibt es schon. Ersetzen?') -f $title))) { return }
        $form.Cursor = [Windows.Forms.Cursors]::WaitCursor
        try { $r = Invoke-DesignBuild $d }
        catch { $form.Cursor = [Windows.Forms.Cursors]::Default; $messageLabel.ForeColor = [Drawing.Color]::Firebrick; $messageLabel.Text = '✗ ' + $_.Exception.Message; return }
        $form.Cursor = [Windows.Forms.Cursors]::Default
        Save-Design $d
        $script:Result.Created += $r.Title
        $script:Result.Path = $r.Path
        $question = (Txt '“{0}” is ready – in the game under “New Game” → “Own Scenarios”.{1}{1}Show it now in the launcher''s list of adventures?' '„{0}“ ist bereit – im Spiel unter „Neues Spiel“ → „Eigene Szenarien“.{1}{1}Jetzt in der Abenteuer-Liste des Starters zeigen?') -f $r.Title, [Environment]::NewLine
        if (Show-Question $question) {
            $script:Result.ShowList = $true
            if (-not $Owner -and -not $TestCreate -and (Test-Path -LiteralPath $LauncherScript)) {
                Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$LauncherScript`"", '-StartTab', '2')
            }
            $form.Close()
        }
    })
$form.Add_FormClosing({ if (-not $TestCreate -and -not $PreviewImage) { Save-Design (Get-DesignFromControls) } })

Set-DesignControls $design
Update-Preview

if ($PreviewImage -or $TestCreate) {
    $form.StartPosition = 'Manual'; $form.Location = New-Object Drawing.Point(-10000, -10000); $form.ShowInTaskbar = $false
    $form.Add_Shown({
            if ($PreviewImage) {
                if ($PreviewMap) { $previewTabs.SelectedTab = $tabMap }
                $form.Refresh()
                $image = New-Object Drawing.Bitmap($form.Width, $form.Height)
                $form.DrawToBitmap($image, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                $image.Save($PreviewImage, [Drawing.Imaging.ImageFormat]::Png)
            }
            else { $buttonCreate.GetType().GetMethod('OnClick', [Reflection.BindingFlags]'NonPublic, Instance').Invoke($buttonCreate, @([EventArgs]::Empty)) }
            $form.Close()
        })
}
if ($Owner) { [void]$form.ShowDialog($Owner) } else { [void]$form.ShowDialog() }
$lastMessage = $messageLabel.Text
$form.Dispose()
if ($TestCreate) {
    foreach ($q in $script:Questions) { 'QUESTION ' + ($q -replace "`r?`n", ' ') }
    'MESSAGE ' + ($lastMessage -replace "`r?`n", ' | ')
}
if ($Owner -or $TestCreate) { $script:Result }
