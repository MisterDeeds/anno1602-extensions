<#
.SYNOPSIS
  Launcher window for Anno 1602 History Edition with the extensions from anno-patcher.ps1.

.DESCRIPTION
  Three tabs:
  - "New game": all options as drop-down lists in four groups, presets, remembers the last choice.
  - "Continue": the savegames with the settings they were made with (recorded by anno-patcher.ps1 in
    %APPDATA%\Anno1602-Extensions\saves.json), so a big world is always loaded with the right size.
  - "Adventures": the own campaigns and challenges with their progress, random adventures, the daily adventure, the
    scenario designer (scenario-designer.ps1) and the option to unlock the campaign chapters one by one.
  "Play with extensions" starts anno-patcher.ps1 (in its own window that stays open until the game ends) and the
  game through Ubisoft Connect. "Start original" only starts the game, without changes.
  Updates (installed copy only, version.txt): at every start a background request asks GitHub for the newest release;
  if it is newer, "Update automatically" (on by default) downloads get.ps1 and runs it at once - at most once per
  version and day, never while the game runs - otherwise the button "Update now" does. The installer opens the new
  launcher, which then says "Updated to version x.y.z" once, with a button for the release notes.
  The settings are stored in %APPDATA%\Anno1602-Extensions\settings.json (option id -> value key,
  independent of the UI language; plus LogbookWithGame and UnlockChapters = 1/0). The settings of older versions
  (%APPDATA%\Anno1602-Erweiterungen\einstellungen.json) are taken over; the old file is left in place.

  Unlocking chapters one by one: the installer keeps the full set of campaigns and challenges in the program folder
  (scenarios\, with the index scenarios\chapters.json: file, campaign, chapter, names in both languages). With the
  option on, Own Scenarios holds of each campaign only the chapters up to the first one not won yet (the logbook's
  missions in logbook.json decide; a win in either language counts); the launcher copies the next chapter when it
  starts and finds a new win and lists the locked chapters with a lock. Turning the option off copies all chapters
  back. Only files named like a chapter of the index are copied or removed - never the player's own scenarios.
#>
param(
    # For testing only: build the window invisibly, save it as a PNG and exit.
    [string]$PreviewImage,
    # For testing only: tab shown in the preview (0 = new game, 1 = continue, 2 = adventures).
    [Parameter(DontShow)][int]$PreviewTab = 0,
    # For testing only: newest release ("v9.9.9") as if GitHub had reported it, so that the preview shows the update notice
    # (an update is never started from a preview); "updated" shows the note after an update, "error" a failed download.
    [Parameter(DontShow)][string]$PreviewUpdate = '',
    # Tab shown at the start (the scenario designer opens the adventure list with 2).
    [Parameter(DontShow)][int]$StartTab = 0,
    # For the installer: apply the saved "unlock chapters one by one" setting to Own Scenarios (no window) and exit.
    [Parameter(DontShow)][switch]$SyncChapters,
    # For testing only: folder of the full chapter set instead of the program folder's scenarios subfolder.
    [Parameter(DontShow)][string]$ChapterFolder = '',
    # For testing only: print the anno-patcher.ps1 arguments for the defaults, "Everything big",
    # "For campaigns" and the saved choice (one line each) and exit without showing the window.
    [Parameter(DontShow)][switch]$PrintArgs,
    # For testing only: print the savegame list of the "Continue" tab (one line each) and exit.
    [Parameter(DontShow)][switch]$PrintSaves,
    # For testing only: print every choice of every option with its arguments (one line each) and exit.
    [Parameter(DontShow)][switch]$PrintChoices,
    # For testing only: build the window invisibly, click the buttons in code (no process is started; random and daily
    # adventures go to -TestOutFolder instead of Own Scenarios, the designer builds a test design into Own Scenarios of
    # -DocumentsFolder if that is given, otherwise into -TestOutFolder), print what would have been started and exit.
    [Parameter(DontShow)][switch]$TestClicks,
    [Parameter(DontShow)][string]$TestOutFolder = (Join-Path ([IO.Path]::GetTempPath()) 'anno1602-launcher-test'),
    # For testing only: folder used instead of %APPDATA% for the settings.
    [Parameter(DontShow)][string]$AppDataFolder = $env:APPDATA,
    # For testing only: folder used instead of the Documents folder (savegames, own scenarios).
    [Parameter(DontShow)][string]$DocumentsFolder = [Environment]::GetFolderPath('MyDocuments')
)
$ErrorActionPreference = 'Stop'
# The click test builds the designer's test scenario into Own Scenarios only when a test documents folder is given.
$DocumentsGiven = $PSBoundParameters.ContainsKey('DocumentsFolder')
if (-not $ChapterFolder) { $ChapterFolder = Join-Path $PSScriptRoot 'scenarios' }

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }

$Patcher = Join-Path $PSScriptRoot 'anno-patcher.ps1'
$GameStart = 'uplay://launch/16236/0'
$DataFolder = Join-Path $AppDataFolder 'Anno1602-Extensions'
$SettingsFile = Join-Path $DataFolder 'settings.json'
$OldSettingsFile = Join-Path $AppDataFolder 'Anno1602-Erweiterungen\einstellungen.json'
# Written by anno-patcher.ps1 when the game ends: which savegame was written with which arguments.
$SavesFile = Join-Path $DataFolder 'saves.json'
$GameDocs = Join-Path $DocumentsFolder 'Anno 1602 History Edition'
$SaveFolder = Join-Path $GameDocs 'Savegame'

# One choice of an option: display text, the German text (older versions saved it, see below)
# and the arguments for anno-patcher.ps1.
function New-Choice([string]$en, [string]$de, [string[]]$patcherArgs = @()) {
    @{ Text = (Txt $en $de); De = $de; Args = $patcherArgs }
}

# Every option: group in the window, label, default and choices (value key -> choice). settings.json stores the
# value keys, so they must stay stable; the order here is the order of the argument list.
$Options = [ordered]@{
    World         = @{ Group = 'World'; Label = (Txt 'Map size' 'Kartengrösse'); Default = '1000x700'; Choices = [ordered]@{
            '500x350'   = New-Choice 'Original (500 × 350)' 'Original (500 × 350)' @('-Width', '500', '-Height', '350')
            '750x525'   = New-Choice 'Large (750 × 525)' 'Gross (750 × 525)' @('-Width', '750', '-Height', '525')
            '1000x700'  = New-Choice 'Very large (1000 × 700)' 'Sehr gross (1000 × 700)'
            '2000x1400' = New-Choice 'Huge (2000 × 1400)' 'Riesig (2000 × 1400)' @('-Width', '2000', '-Height', '1400') } }
    Islands       = @{ Group = 'World'; Label = (Txt 'Islands' 'Inseln'); Default = 'More'; Choices = [ordered]@{
            'More'        = New-Choice 'More islands (up to 50)' 'Mehr Inseln (bis 50)'
            'StretchOnly' = New-Choice 'Only spread over the map' 'Nur über die Karte verteilt' @('-StretchOnly')
            'Original'    = New-Choice 'As in the original' 'Wie im Original' @('-NoIslandSpread') } }
    IslandSize    = @{ Group = 'World'; Label = (Txt 'Island size' 'Inselgrösse'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'
            'Large'  = New-Choice 'Large (many large islands)' 'Gross (viele grosse Inseln)' @('-IslandSize', 'Large')
            'Huge'   = New-Choice 'Huge (almost only the largest)' 'Riesig (fast nur die grössten)' @('-IslandSize', 'Huge')
            'Giant'  = New-Choice 'Giant (larger than the largest)' 'Gigantisch (grösser als die grössten)' @('-IslandSize', 'Giant') } }
    Resources     = @{ Group = 'World'; Label = (Txt 'Resources' 'Rohstoffe'); Default = 'More'; Choices = [ordered]@{
            'Template' = New-Choice 'As in the template' 'Wie in der Vorlage'
            'More'     = New-Choice 'More (to match the islands)' 'Mehr (passend zur Inselzahl)' @('-Resources', 'More')
            'Lots'     = New-Choice 'Lots (twice as many)' 'Viele (doppelt so viele)' @('-Resources', 'Lots') } }
    Natives       = @{ Group = 'World'; Label = (Txt 'Natives' 'Ureinwohner'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'As template (2 + 2 villages)' 'Wie Vorlage (2 + 2 Dörfer)'
            'More'    = New-Choice 'More (4 + 4 villages)' 'Mehr (4 + 4 Dörfer)' @('-Natives', 'More')
            'Lots'    = New-Choice 'Lots (7 + 7 villages)' 'Viele (7 + 7 Dörfer)' @('-Natives', 'Lots') } }
    Traders       = @{ Group = 'Sea'; Label = (Txt 'Free traders' 'Freie Händler'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'
            'More'   = New-Choice 'More (twice as many)' 'Mehr (doppelt so viele)' @('-Traders', 'More')
            'Lots'   = New-Choice 'Lots (three times, up to 24)' 'Viele (dreimal, bis 24)' @('-Traders', 'Lots') } }
    Rivals        = @{ Group = 'Sea'; Label = (Txt 'Computer rivals' 'Computergegner'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            'Hard'       = New-Choice 'Always like “Hard”' 'Immer wie „Schwer“' @('-Rivals', 'Hard') } }
    # 3.4: the main towns of the rivals no longer stop at settlers, citizens or merchants: no dead ends in their
    # building plan, and the luxury goods they never make are supplied (anno-patcher.ps1 -RivalGrowth).
    RivalGrowth   = @{ Group = 'Sea'; Label = (Txt "Rivals' towns" 'Städte der Gegner'); Default = 'Default'; Choices = [ordered]@{
            'Default'   = New-Choice 'As in the original' 'Wie im Original'
            'Ambitious' = New-Choice 'Ambitious (with supplies)' 'Ehrgeizig (mit Nachschub)' @('-RivalGrowth', 'Ambitious') } }
    RivalGold     = @{ Group = 'Sea'; Label = (Txt "Rivals' gold" 'Gold der Gegner'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            '30000'      = New-Choice '30,000' '30 000' @('-RivalGold', '30000')
            '60000'      = New-Choice '60,000' '60 000' @('-RivalGold', '60000')
            '100000'     = New-Choice '100,000' '100 000' @('-RivalGold', '100000') } }
    Pirates       = @{ Group = 'Sea'; Label = (Txt 'Pirates' 'Piraten'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            'Active'     = New-Choice 'Always attack' 'Greifen immer an' @('-Pirates', 'Active')
            'Strong'     = New-Choice 'Strong (full cannons)' 'Stark (volle Kanonen)' @('-Pirates', 'Strong')
            'Off'        = New-Choice 'No pirates' 'Keine Piraten' @('-Pirates', 'Off') } }
    PirateFleet   = @{ Group = 'Sea'; Label = (Txt 'Pirate fleet' 'Piratenflotte'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal (up to 4 ships)' 'Normal (bis 4 Schiffe)'
            'Large'  = New-Choice 'Large (up to 8 ships)' 'Gross (bis 8 Schiffe)' @('-PirateFleet', 'Large')
            'Huge'   = New-Choice 'Huge (up to 12 ships)' 'Riesig (bis 12 Schiffe)' @('-PirateFleet', 'Huge') } }
    StartGold     = @{ Group = 'Economy'; Label = (Txt 'Your starting gold' 'Dein Startgold'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            '30000'      = New-Choice '30,000' '30 000' @('-StartGold', '30000')
            '50000'      = New-Choice '50,000' '50 000' @('-StartGold', '50000')
            '100000'     = New-Choice '100,000' '100 000' @('-StartGold', '100000') } }
    Residents     = @{ Group = 'Economy'; Label = (Txt 'Residents per house' 'Einwohner je Haus'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Residents', '1.5'); '2' = New-Choice '× 2' '× 2' @('-Residents', '2')
            '3' = New-Choice '× 3' '× 3' @('-Residents', '3'); '4' = New-Choice '× 4' '× 4' @('-Residents', '4'); '5' = New-Choice '× 5' '× 5' @('-Residents', '5') } }
    Turbo         = @{ Group = 'Ships'; Label = (Txt 'Turbo (F7 key)' 'Turbo (Taste F7)'); Default = 'Off'; Choices = [ordered]@{
            'Off' = New-Choice 'Off (4×)' 'Aus (4-fach)'; '8' = New-Choice '8×' '8-fach' @('-Turbo')
            '12' = New-Choice '12×' '12-fach' @('-Turbo', '-TurboLevel', '12'); '16' = New-Choice '16×' '16-fach' @('-Turbo', '-TurboLevel', '16') } }
    Production    = @{ Group = 'Economy'; Label = (Txt 'Production speed' 'Produktionstempo'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Production', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-Production', '2'); '3' = New-Choice '× 3' '× 3' @('-Production', '3') } }
    Storage       = @{ Group = 'Economy'; Label = (Txt 'Storage per good' 'Lager je Ware'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '2' = New-Choice '× 2' '× 2' @('-Storage', '2')
            '3' = New-Choice '× 3' '× 3' @('-Storage', '3'); '5' = New-Choice '× 5' '× 5' @('-Storage', '5') } }
    ShipSpeed     = @{ Group = 'Ships'; Label = (Txt 'Ship speed' 'Schiffstempo'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-ShipSpeed', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-ShipSpeed', '2'); '3' = New-Choice '× 3' '× 3' @('-ShipSpeed', '3') } }
    Cargo         = @{ Group = 'Ships'; Label = (Txt 'Cargo space' 'Laderaum der Schiffe'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Cargo', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-Cargo', '2'); '3' = New-Choice '× 3' '× 3' @('-Cargo', '3') } }
    BuildCost     = @{ Group = 'Economy'; Label = (Txt 'Building costs' 'Baukosten'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '0.75' = New-Choice '× 0.75' '× 0,75' @('-BuildCost', '0.75')
            '0.5' = New-Choice 'Half' 'Halb' @('-BuildCost', '0.5'); '0.25' = New-Choice 'A quarter' 'Ein Viertel' @('-BuildCost', '0.25')
            '0' = New-Choice 'Free' 'Gratis' @('-BuildCost', '0') } }
    Upkeep        = @{ Group = 'Economy'; Label = (Txt 'Running costs' 'Betriebskosten'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '0.75' = New-Choice '× 0.75' '× 0,75' @('-Upkeep', '0.75')
            '0.5' = New-Choice 'Half' 'Halb' @('-Upkeep', '0.5'); '0.25' = New-Choice 'A quarter' 'Ein Viertel' @('-Upkeep', '0.25')
            '0' = New-Choice 'None' 'Keine' @('-Upkeep', '0') } }
    Taxes         = @{ Group = 'Economy'; Label = (Txt 'Tax income' 'Steuereinnahmen'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Taxes', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-Taxes', '2'); '3' = New-Choice '× 3' '× 3' @('-Taxes', '3') } }
    Radius        = @{ Group = 'Economy'; Label = (Txt 'Influence radius' 'Einflussradius'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'
            '1.5' = New-Choice '× 1.5 (warehouse, market, public buildings)' '× 1,5 (Kontor, Markt, öffentliche Bauten)' @('-Radius', '1.5')
            '2' = New-Choice '× 2 (warehouse, market, public buildings)' '× 2 (Kontor, Markt, öffentliche Bauten)' @('-Radius', '2') } }
    Fertility     = @{ Group = 'World'; Label = (Txt 'Fertility' 'Fruchtbarkeit'); Default = 'Default'; Choices = [ordered]@{
            'Default'    = New-Choice 'As template' 'Wie Vorlage'
            'Everywhere' = New-Choice 'Every crop on every island' 'Jede Pflanze auf jeder Insel' @('-Fertility', 'Everywhere') } }
    Mines         = @{ Group = 'Economy'; Label = (Txt 'Ore and gold mines' 'Erz- und Goldminen'); Default = 'Default'; Choices = [ordered]@{
            'Default'  = New-Choice 'Normal (they run dry)' 'Normal (erschöpfen sich)'
            'Infinite' = New-Choice 'Inexhaustible' 'Unerschöpflich' @('-Mines', 'Infinite') } }
    Disasters     = @{ Group = 'Sea'; Label = (Txt 'Disasters' 'Katastrophen'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'Normal' 'Normal'
            'Off'     = New-Choice 'None (no fire, plague, drought)' 'Keine (kein Feuer, Pest, Dürre)' @('-Disasters', 'Off')
            'More'    = New-Choice 'More often' 'Häufiger' @('-Disasters', 'More') } }
    # Random events during the game, applied by the running tool and shown in the logbook (anno-patcher.ps1 -Events).
    Events        = @{ Group = 'Sea'; Label = (Txt 'Events' 'Ereignisse'); Default = 'Off'; Choices = [ordered]@{
            'Off'   = New-Choice 'Off' 'Aus'
            'Rare'  = New-Choice 'Rare' 'Selten' @('-Events', 'Rare')
            'Often' = New-Choice 'Often' 'Häufig' @('-Events', 'Often') } }
    # 3.4: the island forge changes the islands of new games (anno-patcher.ps1 -Rivers, -Mountains, -Volcanoes).
    Rivers        = @{ Group = 'Landscape'; Label = (Txt 'Rivers' 'Flüsse'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'As on the island' 'Wie auf der Insel'
            'Off'     = New-Choice 'None (more building land)' 'Keine (mehr Bauland)' @('-Rivers', 'Off') } }
    Mountains     = @{ Group = 'Landscape'; Label = (Txt 'Mountains' 'Berge'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'As on the island' 'Wie auf der Insel'
            'Edge'    = New-Choice 'At the coast (free inland)' 'Am Rand (Inselmitte frei)' @('-Mountains', 'Edge') } }
    Volcanoes     = @{ Group = 'Landscape'; Label = (Txt 'Volcano' 'Vulkan'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'As in the original' 'Wie im Original'
            'Off'     = New-Choice 'None (no eruptions)' 'Keiner (keine Ausbrüche)' @('-Volcanoes', 'Off') } }
}
# Groups in the window (order: left column top, right column top, left bottom, right bottom, right below that).
$Groups = [ordered]@{
    World     = Txt 'World' 'Welt'
    Economy   = Txt 'Economy' 'Wirtschaft'
    Sea       = Txt 'Rivals and dangers' 'Gegner und Gefahren'
    Ships     = Txt 'Ships and speed' 'Schiffe und Tempo'
    Landscape = Txt 'Landscape of the islands' 'Landschaft der Inseln'
}

# "Everything big": big world with huge islands, lots of resources, big towns and a fast game.
# 1000 x 700 instead of 2000 x 1400 because the game knows at most 50 islands; on 2000 x 1400 almost everything would be sea.
# Plus more life and more rivals: natives and traders "Lots", AI always "Hard", pirates attack
# and keep a fleet twice as big. Since 3.4 the giant islands of the island forge and ambitious rivals.
$EverythingBig = @{
    World = '1000x700'; Islands = 'More'; IslandSize = 'Giant'
    Resources = 'Lots'; Natives = 'Lots'; Traders = 'Lots'
    Rivals = 'Hard'; RivalGrowth = 'Ambitious'; RivalGold = '60000'; Pirates = 'Active'; PirateFleet = 'Large'
    StartGold = '50000'; Residents = '5'; Turbo = '16'; Production = '2'; Storage = '5'; ShipSpeed = '2'; Cargo = '3'
}

# "For campaigns": big version of the campaign maps (from 1000 x 700 with "More islands"), gold as intended by the
# scenario (the gold options would replace it), turbo; economy and rivals as in the original,
# so that the missions are as hard as planned.
$ForCampaigns = @{
    World = '1000x700'; Islands = 'More'; RivalGold = 'Difficulty'; StartGold = 'Difficulty'
    Turbo = '16'
}

# "Giant world" (since 3.1): the giant version of the World Empire maps (2000 x 1400, five island realms), ships twice
# as fast for the long sea routes, turbo; gold, rivals and economy as the scenario intends. Other scenarios get their
# big version stretched to this size, the endless game 50 islands spread over the giant world.
$GiantWorld = @{
    World = '2000x1400'; Islands = 'More'; RivalGold = 'Difficulty'; StartGold = 'Difficulty'
    ShipSpeed = '2'; Turbo = '16'
}

# "Relaxed": build in peace - cheap buildings, more taxes, every crop everywhere, no pirates and no disasters; since
# 3.4 islands without rivers, with the mountains at the coast and without the volcano (more room to build).
$Relaxed = @{
    World = '1000x700'; Islands = 'More'; IslandSize = 'Large'; Resources = 'Lots'; Fertility = 'Everywhere'; Mines = 'Infinite'
    Pirates = 'Off'; Disasters = 'Off'; StartGold = '100000'; Residents = '2'; Production = '2'; Storage = '3'
    BuildCost = '0.5'; Upkeep = '0.5'; Taxes = '2'; Radius = '1.5'; Turbo = '16'
    Rivers = 'Off'; Mountains = 'Edge'; Volcanoes = 'Off'
}

# "Tough test": the rivals at their strongest (since 3.4 also ambitious) with lots of gold, strong pirates with a huge
# fleet, more disasters.
$Tough = @{
    World = '1000x700'; Islands = 'More'; Resources = 'More'; Natives = 'More'
    Rivals = 'Hard'; RivalGrowth = 'Ambitious'; RivalGold = '100000'; Pirates = 'Strong'; PirateFleet = 'Huge'; Disasters = 'More'; Turbo = '16'
}

# Load the last choice (option id -> value key). Missing or broken file: defaults.
$saved = @{}
try {
    if (Test-Path -LiteralPath $SettingsFile) {
        $j = Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) { $saved[$p.Name] = [string]$p.Value }
    }
    elseif (Test-Path -LiteralPath $OldSettingsFile) {
        # Older versions stored the German display texts under German option ids. Translate them to value keys;
        # unknown values keep the default. The new file is written with the next start.
        $oldIds = @{
            Welt = 'World'; Inseln = 'Islands'; Inselgroesse = 'IslandSize'; Rohstoffe = 'Resources'; Ureinwohner = 'Natives'
            Haendler = 'Traders'; Gegner = 'Rivals'; GegnerGeld = 'RivalGold'; Piraten = 'Pirates'; Piratenflotte = 'PirateFleet'
            Startgeld = 'StartGold'; Einwohner = 'Residents'; Turbo = 'Turbo'; Produktion = 'Production'; Lager = 'Storage'
            Schiffstempo = 'ShipSpeed'; Laderaum = 'Cargo'
        }
        $j = Get-Content -LiteralPath $OldSettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            $id = $oldIds[$p.Name]
            if (-not $id) { continue }
            # Even older settings stored Turbo as yes/no.
            if ($id -eq 'Turbo' -and $p.Value -is [bool]) { if ($p.Value) { $saved[$id] = '8' }; continue }
            $choices = $Options[$id].Choices
            foreach ($key in $choices.Keys) { if ($choices[$key].De -ceq [string]$p.Value) { $saved[$id] = $key } }
        }
    }
}
catch { $saved = @{} }

# Complete choice (option id -> value key): the given values where valid, otherwise the defaults.
function Complete-Choice($values) {
    $choice = [ordered]@{}
    foreach ($name in $Options.Keys) {
        $o = $Options[$name]
        $choice[$name] = if ($values.Contains($name) -and $o.Choices.Contains([string]$values[$name])) { [string]$values[$name] } else { $o.Default }
    }
    $choice
}

# Arguments for anno-patcher.ps1 from a complete choice.
function Get-PatcherArgs($choice) {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($name in $Options.Keys) {
        foreach ($a in $Options[$name].Choices[[string]$choice[$name]].Args) { $list.Add($a) }
    }
    , $list
}

# Argument list -> parameter name -> value ('' for a switch), e.g. "-Turbo -TurboLevel 16" -> Turbo='', TurboLevel='16'.
function ConvertTo-ParameterTable([string[]]$patcherArgs) {
    $table = @{}
    for ($i = 0; $i -lt $patcherArgs.Count; $i++) {
        if ($patcherArgs[$i] -notlike '-*') { continue }
        $value = ''
        if ($i + 1 -lt $patcherArgs.Count -and $patcherArgs[$i + 1] -notlike '-*') { $value = $patcherArgs[$i + 1]; $i++ }
        $table[$patcherArgs[$i - [int]($value -ne '')].TrimStart('-')] = $value
    }
    $table
}
# Choice (option id -> value key) from a recorded argument list: per option the choice whose parameters all appear
# with the same values (the one with most parameters wins, e.g. "-Turbo -TurboLevel 16" before "-Turbo"),
# otherwise the choice without arguments.
function ConvertFrom-PatcherArgs([string[]]$patcherArgs) {
    $given = ConvertTo-ParameterTable $patcherArgs
    $choice = [ordered]@{}
    foreach ($name in $Options.Keys) {
        $best = $null; $bestCount = -1
        foreach ($key in $Options[$name].Choices.Keys) {
            $need = ConvertTo-ParameterTable @($Options[$name].Choices[$key].Args)
            $match = $true
            foreach ($p in $need.Keys) { if (-not $given.ContainsKey($p) -or $given[$p] -ne $need[$p]) { $match = $false } }
            if ($match -and $need.Count -gt $bestCount) { $best = $key; $bestCount = $need.Count }
        }
        $choice[$name] = if ($null -ne $best) { $best } else { $Options[$name].Default }
    }
    $choice
}

# Short description of a choice: the options that differ from the defaults.
function Get-ChoiceSummary($choice) {
    $parts = foreach ($name in $Options.Keys) {
        if ($name -eq 'World') { continue }
        $o = $Options[$name]
        if ([string]$choice[$name] -ne $o.Default) { '{0}: {1}' -f $o.Label, $o.Choices[[string]$choice[$name]].Text }
    }
    if ($parts) { $parts -join ' · ' } else { Txt 'standard options' 'Standardoptionen' }
}

# --- Savegames for the "Continue" tab -----------------------------------------------------------------------
# Time of the first start with the extensions: the oldest backup folder made by the patcher. Savegames written
# before that come from the original game.
function Get-FirstToolUse {
    $first = $null
    if (Test-Path -LiteralPath $GameDocs) {
        foreach ($d in Get-ChildItem -LiteralPath $GameDocs -Directory -ErrorAction SilentlyContinue) {
            if ($d.Name -match '^Savegame-(Sicherung|Backup)-(\d{8}-\d{6})$') {
                $t = [datetime]::ParseExact($Matches[2], 'yyyyMMdd-HHmmss', $null)
                if (-not $first -or $t -lt $first) { $first = $t }
            }
        }
    }
    $first
}

# One entry per savegame, newest first: name, time, map size, settings (choice or $null), kind:
# 'known' (recorded by the patcher), 'size' (only the size is known from the file name), 'original', 'unknown'.
function Get-SaveList {
    $records = @()
    try { if (Test-Path -LiteralPath $SavesFile) { $records = @(Get-Content -LiteralPath $SavesFile -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ }) } } catch { $records = @() }
    $firstUse = Get-FirstToolUse
    if (-not (Test-Path -LiteralPath $SaveFolder)) { return }
    foreach ($f in Get-ChildItem -LiteralPath $SaveFolder -Filter '*.gam' -File | Sort-Object LastWriteTime -Descending) {
        $entry = [ordered]@{ Name = $f.BaseName; File = $f.FullName; Time = $f.LastWriteTime; Width = 0; Height = 0; Args = $null; Choice = $null; Kind = 'unknown' }
        # Record of the patcher for exactly this file version (same name, same write time within 3 s).
        $rec = $records | Where-Object { $_.File -eq $f.Name -and [math]::Abs(([datetime]$_.Written - $f.LastWriteTime).TotalSeconds) -le 3 } | Select-Object -Last 1
        if ($rec) {
            $entry.Width = [int]$rec.Width; $entry.Height = [int]$rec.Height; $entry.Args = @($rec.Args); $entry.Choice = ConvertFrom-PatcherArgs @($rec.Args); $entry.Kind = 'known'
        }
        elseif ($f.Name -match '^lastgame-(\d+)x(\d+)-') {
            $entry.Width = [int]$Matches[1]; $entry.Height = [int]$Matches[2]; $entry.Kind = 'size'
        }
        elseif ($firstUse -and $f.LastWriteTime -lt $firstUse) {
            $entry.Width = 500; $entry.Height = 350; $entry.Kind = 'original'
        }
        $entry
    }
}

function Get-SaveDescription($entry) {
    switch ($entry.Kind) {
        'known' { Get-ChoiceSummary $entry.Choice }
        'size' { Txt 'autosave of a big world; other options unknown' 'Autosave einer grossen Welt; weitere Optionen unbekannt' }
        'original' { Txt 'original game (before the extensions)' 'Originalspiel (vor den Erweiterungen)' }
        default { Txt 'settings unknown' 'Einstellungen unbekannt' }
    }
}

# --- Own scenarios, progress and chapter unlocking (also used without the window: -SyncChapters) -------------------
$OwnScenarios = Join-Path $GameDocs 'Own Scenarios'
$LogbookFile = Join-Path $DataFolder 'logbook.json'
$Generator = Join-Path $PSScriptRoot 'random-adventure.ps1'
$Designer = Join-Path $PSScriptRoot 'scenario-designer.ps1'
$Logbook = Join-Path $PSScriptRoot 'logbook.ps1'
# Installed version (written by install.ps1; missing when the launcher runs from the repository). The launcher asks
# GitHub once per start, in the background, for the newest release and installs it (get.ps1) if it is newer - by
# itself with "Update automatically", otherwise with the button "Update now".
$InstalledVersion = $null
try { $v = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'version.txt') -Raw -ErrorAction Stop).Trim(); if ($v -match '^\d+\.\d+\.\d+$') { $InstalledVersion = [version]$v } } catch { }
$ReleaseApi = 'https://api.github.com/repos/MisterDeeds/anno1602-extensions/releases/latest'
$ChapterIndexFile = Join-Path $ChapterFolder 'chapters.json'

# Missions recorded by the logbook: scenario name -> best result ('won' beats 'lost') and date.
function Get-MissionResults {
    $results = @{}
    try {
        if (Test-Path -LiteralPath $LogbookFile) {
            $j = Get-Content -LiteralPath $LogbookFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($m in @($j.missions | ForEach-Object { $_ })) {
                if (-not $m.scenario) { continue }
                $old = $results[[string]$m.scenario]
                if (-not $old -or ($m.result -eq 'won' -and $old.result -ne 'won')) { $results[[string]$m.scenario] = $m }
            }
        }
    }
    catch { }
    $results
}
# Campaign of a scenario file: "Smaragdinseln 3 - Zwei Kolonien" -> "Smaragdinseln", "Herausforderung - Goldrausch"
# -> "Herausforderung", "Abenteuer 4711 Fordernd" -> "Abenteuer", "Tagesabenteuer 2026-11-14" -> "Tagesabenteuer",
# "Eigenes - Meine Inseln" -> "Eigenes".
function Get-CampaignName([string]$name) {
    if ($name -match '^(Abenteuer|Adventure) \d+') { return $Matches[1] }   # random adventures, also with the difficulty in the name
    if ($name -match '^(Tagesabenteuer|Daily Adventure) \d{4}-\d{2}-\d{2}$') { return $Matches[1] }
    if ($name -match '^(Eigenes|Custom) - ') { return $Matches[1] }
    if ($name -match '^(.+?)\s+\d+(\s+-\s+.*)?$') { return $Matches[1] }
    if ($name -match '^(.+?)\s+-\s+') { return $Matches[1] }
    $name
}
# Campaign chapters of the full set kept by the installer: @{ File; Campaign; Chapter; Names (both languages) },
# only those whose file is there. No index (older installation or no game): nothing.
function Get-ChapterIndex {
    try {
        if (-not (Test-Path -LiteralPath $ChapterIndexFile)) { return }
        $j = Get-Content -LiteralPath $ChapterIndexFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($c in @($j.chapters | ForEach-Object { $_ })) {
            if (-not $c.file -or -not (Test-Path -LiteralPath (Join-Path $ChapterFolder ([string]$c.file + '.szs')))) { continue }
            @{ File = [string]$c.file; Campaign = [string]$c.campaign; Chapter = [int]$c.chapter; Names = @(@($c.names) + [string]$c.file | Where-Object { $_ } | Select-Object -Unique) }
        }
    }
    catch { }
}
# Per chapter in campaign order: Locked ($true for every chapter after the first one not won yet) and Previous (number of the
# chapter before it, which must be won first). A win under any name of the chapter (German or English) counts.
function Get-ChapterStates($chapters, $results) {
    foreach ($group in @($chapters) | Group-Object { $_.Campaign }) {
        $open = $true; $previous = $null
        foreach ($ch in $group.Group | Sort-Object { $_.Chapter }) {
            $won = @($ch.Names | Where-Object { $results[$_] -and $results[$_].result -eq 'won' }).Count -gt 0
            @{ File = $ch.File; Names = $ch.Names; Locked = -not $open; Previous = $previous; Won = $won }
            if (-not $won) { $open = $false }
            $previous = $ch.Chapter
        }
    }
}
# Brings Own Scenarios in line with the option: $unlock = only the open chapters (copies missing ones, removes locked
# ones under any of their names), otherwise every chapter (copies the missing ones). Returns the copied chapters.
function Sync-Chapters([bool]$unlock) {
    $chapters = @(Get-ChapterIndex)
    if (-not $chapters.Count) { return }
    foreach ($ch in Get-ChapterStates $chapters (Get-MissionResults)) {
        if ($unlock -and $ch.Locked) {
            foreach ($n in $ch.Names) {
                $p = Join-Path $OwnScenarios ($n + '.szs')
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
            }
        }
        elseif (-not (Test-Path -LiteralPath (Join-Path $OwnScenarios ($ch.File + '.szs')))) {
            New-Item -ItemType Directory -Force -Path $OwnScenarios | Out-Null
            Copy-Item -LiteralPath (Join-Path $ChapterFolder ($ch.File + '.szs')) -Destination $OwnScenarios -Force
            $ch.File
        }
    }
}

if ($PrintArgs) {
    'default: ' + ((Get-PatcherArgs (Complete-Choice @{})) -join ' ')
    'everything-big: ' + ((Get-PatcherArgs (Complete-Choice $EverythingBig)) -join ' ')
    'campaigns: ' + ((Get-PatcherArgs (Complete-Choice $ForCampaigns)) -join ' ')
    'giant-world: ' + ((Get-PatcherArgs (Complete-Choice $GiantWorld)) -join ' ')
    'saved: ' + ((Get-PatcherArgs (Complete-Choice $saved)) -join ' ')
    'relaxed: ' + ((Get-PatcherArgs (Complete-Choice $Relaxed)) -join ' ')
    'tough: ' + ((Get-PatcherArgs (Complete-Choice $Tough)) -join ' ')
    return
}
if ($PrintChoices) {
    foreach ($name in $Options.Keys) { foreach ($key in $Options[$name].Choices.Keys) { '{0}={1}: {2}' -f $name, $key, ($Options[$name].Choices[$key].Args -join ' ') } }
    return
}
if ($PrintSaves) {
    foreach ($e in Get-SaveList) {
        $size = if ($e.Width) { '{0}x{1}' -f $e.Width, $e.Height } else { '?' }
        $start = if ($e.Kind -eq 'known') { ' | ' + ((Get-PatcherArgs $e.Choice) -join ' ') } else { '' }
        '{0} | {1:yyyy-MM-dd HH:mm} | {2} | {3} | {4}{5}' -f $e.Name, $e.Time, $size, $e.Kind, (Get-SaveDescription $e), $start
    }
    return
}
if ($SyncChapters) {
    $chapters = @(Get-ChapterIndex)
    if (-not $chapters.Count) { "No chapter set in $ChapterFolder - nothing to do."; return }
    if ($saved['UnlockChapters'] -ne '1') { "Unlock chapters one by one: off - all $($chapters.Count) chapters stay installed."; return }
    $added = @(Sync-Chapters $true)
    $states = @(Get-ChapterStates $chapters (Get-MissionResults))
    'Unlock chapters one by one: {0} of {1} chapters open, {2} locked; copied: {3}' -f @($states | Where-Object { -not $_.Locked }).Count, $states.Count, @($states | Where-Object { $_.Locked }).Count, $(if ($added.Count) { $added -join ', ' } else { '-' })
    return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace AnnoStarter -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][AnnoStarter.Dpi]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()

$font = New-Object Drawing.Font('Segoe UI', 10)
$form = New-Object Windows.Forms.Form
$form.Text = (Txt 'Anno 1602 – Extensions' 'Anno 1602 – Erweiterungen') + $(if ($InstalledVersion) { " $InstalledVersion" })
$form.Font = $font
$form.AutoScaleMode = 'Dpi'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Padding = New-Object Windows.Forms.Padding(12)
# Icon from the game exe (folder from Ubisoft Connect, as in anno-patcher.ps1).
try {
    $gameExe = $null
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $gameExe = Join-Path (($d -replace '/', '\').TrimEnd('\')) 'Anno1602.exe'; break } } catch { }
    }
    if ($gameExe -and (Test-Path -LiteralPath $gameExe)) { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($gameExe) }
}
catch { }

$outer = New-Object Windows.Forms.TableLayoutPanel
$outer.AutoSize = $true
$outer.ColumnCount = 1
$outer.Dock = 'Fill'
$form.Controls.Add($outer)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Padding = New-Object Drawing.Point(14, 5)
$tabs.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 8)
$outer.Controls.Add($tabs)

function New-Tab([string]$text) {
    $t = New-Object Windows.Forms.TabPage
    $t.Text = $text
    $t.Padding = New-Object Windows.Forms.Padding(10)
    $t.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($t)
    $panel = New-Object Windows.Forms.TableLayoutPanel
    $panel.AutoSize = $true
    $panel.ColumnCount = 1
    $panel.Dock = 'Fill'
    $t.Controls.Add($panel)
    $panel
}
function New-Label([string]$text, [bool]$dim = $false, [int]$top = 0, [int]$bottom = 8) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.AutoSize = $true
    if ($dim) { $l.ForeColor = [Drawing.Color]::DimGray }
    $l.Margin = New-Object Windows.Forms.Padding(3, $top, 3, $bottom)
    $l
}
function New-Button([string]$text, $parent) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.AutoSize = $true
    $b.Padding = New-Object Windows.Forms.Padding(10, 4, 10, 4)
    $b.Margin = New-Object Windows.Forms.Padding(3, 3, 8, 3)
    $parent.Controls.Add($b)
    $b
}
function New-ButtonRow($parent) {
    $row = New-Object Windows.Forms.FlowLayoutPanel
    $row.AutoSize = $true
    $row.FlowDirection = 'LeftToRight'
    $row.WrapContents = $false
    $parent.Controls.Add($row)
    $row
}

# --- Tab 1: new game ------------------------------------------------------------------------------------------
$pageNew = New-Tab (Txt 'New game' 'Neues Spiel')
$pageNew.Controls.Add((New-Label (Txt ('Choose the options, then “Play with extensions”. In the game: “New Game” – the endless game, or at the very bottom' + [Environment]::NewLine + '“Own Scenarios” (campaigns, challenges, random adventures). Continue big worlds via the “Continue” tab. Single player only.') `
                ('Optionen wählen, dann „Mit Erweiterungen spielen“. Im Spiel: „Neues Spiel“ – das Endlosspiel oder ganz unten „Eigene' + [Environment]::NewLine + 'Szenarien“ (Kampagnen, Herausforderungen, Zufallsabenteuer). Grosse Welten über „Weiterspielen“ fortsetzen. Nur Einzelspiel.') $true 0 10)))

$groupGrid = New-Object Windows.Forms.TableLayoutPanel
$groupGrid.AutoSize = $true
$groupGrid.ColumnCount = 2
foreach ($i in 1..2) { [void]$groupGrid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
$pageNew.Controls.Add($groupGrid)
# Two independent columns (World + dangers left, economy + ships right), so that the groups do not leave gaps.
$columns = foreach ($i in 0, 1) {
    $c = New-Object Windows.Forms.FlowLayoutPanel
    $c.AutoSize = $true
    $c.FlowDirection = 'TopDown'
    $c.WrapContents = $false
    $c.Margin = New-Object Windows.Forms.Padding(0)
    $groupGrid.Controls.Add($c)
    $c
}
$GroupColumn = @{ World = 0; Sea = 0; Economy = 1; Ships = 1; Landscape = 1 }

$combos = @{}
# All labels as wide as the widest one, so that the four groups line up.
$labelWidth = 0
foreach ($o in $Options.Values) { $labelWidth = [math]::Max($labelWidth, [Windows.Forms.TextRenderer]::MeasureText($o.Label, $font).Width) }
foreach ($g in $Groups.Keys) {
    $box = New-Object Windows.Forms.GroupBox
    $box.Text = $Groups[$g]
    $box.AutoSize = $true
    $box.Padding = New-Object Windows.Forms.Padding(8, 6, 8, 4)
    $box.Margin = New-Object Windows.Forms.Padding(3, 3, 10, 8)
    $inner = New-Object Windows.Forms.TableLayoutPanel
    $inner.AutoSize = $true
    $inner.ColumnCount = 2
    $inner.Dock = 'Fill'
    # One auto-size row per option and an empty last row that takes any extra height of the group box
    # (otherwise the last option row would be stretched).
    $inner.RowCount = @($Options.Values | Where-Object { $_.Group -eq $g }).Count + 1
    foreach ($i in 1..2) { [void]$inner.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
    foreach ($name in $Options.Keys) {
        $o = $Options[$name]
        if ($o.Group -ne $g) { continue }
        $l = New-Object Windows.Forms.Label
        $l.Text = $o.Label
        $l.AutoSize = $true
        $l.MinimumSize = New-Object Drawing.Size($labelWidth, 0)
        $l.Anchor = 'Left'
        $l.Margin = New-Object Windows.Forms.Padding(3, 5, 12, 5)
        [void]$inner.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
        $c = New-Object Windows.Forms.ComboBox
        $c.Name = "choice$name"
        $c.DropDownStyle = 'DropDownList'
        $c.Width = 250
        $c.Margin = New-Object Windows.Forms.Padding(3, 2, 3, 2)
        foreach ($key in $o.Choices.Keys) { [void]$c.Items.Add($o.Choices[$key].Text) }
        $inner.Controls.Add($l)
        $inner.Controls.Add($c)
        $combos[$name] = $c
    }
    [void]$inner.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 100)))
    $box.Controls.Add($inner)
    $columns[$GroupColumn[$g]].Controls.Add($box)
}

# Select a complete choice (option id -> value key) in the drop-down lists.
function Set-Selection($choice) {
    foreach ($name in $Options.Keys) { $combos[$name].SelectedIndex = [array]::IndexOf(@($Options[$name].Choices.Keys), [string]$choice[$name]) }
}
# Current selection as option id -> value key.
function Get-Selection {
    $choice = [ordered]@{}
    foreach ($name in $Options.Keys) { $choice[$name] = [string]@($Options[$name].Choices.Keys)[$combos[$name].SelectedIndex] }
    $choice
}
Set-Selection (Complete-Choice $saved)

$presetRow = New-ButtonRow $pageNew
$presetLabel = New-Label (Txt 'Presets:' 'Vorlagen:') $true 9 0
$presetRow.Controls.Add($presetLabel)
$buttonBig = New-Button (Txt 'Everything big' 'Alles gross') $presetRow
$buttonCampaigns = New-Button (Txt 'For campaigns' 'Für Kampagnen') $presetRow
$buttonGiant = New-Button (Txt 'Giant world' 'Riesenwelt') $presetRow
$buttonRelaxed = New-Button (Txt 'Relaxed' 'Gemütlich') $presetRow
$buttonTough = New-Button (Txt 'Tough test' 'Harte Probe') $presetRow
$buttonDefaults = New-Button (Txt 'Reset to defaults' 'Alles auf Standard') $presetRow
$presetTips = New-Object Windows.Forms.ToolTip
$presetTips.SetToolTip($buttonBig, (Txt 'Big world, giant islands, lots of everything, strong and ambitious rivals, turbo 16×' 'Grosse Welt, gigantische Inseln, von allem viel, starke und ehrgeizige Gegner, Turbo 16-fach'))
$presetTips.SetToolTip($buttonCampaigns, (Txt 'Big campaign maps and turbo; everything else as the scenario intends' 'Grosse Kampagnenkarten und Turbo; alles andere wie im Szenario vorgesehen'))
$presetTips.SetToolTip($buttonGiant, (Txt 'Giant world 2000 × 1400 for the World Empire campaign: five island realms, ships twice as fast, turbo; everything else as the scenario intends' 'Riesenwelt 2000 × 1400 für die Kampagne Weltreich: fünf Inselreiche, Schiffe doppelt so schnell, Turbo; alles andere wie im Szenario vorgesehen'))
$presetTips.SetToolTip($buttonRelaxed, (Txt 'Build in peace: cheap buildings, more taxes, every crop everywhere, no pirates, no disasters, no rivers, mountains at the coast' 'In Ruhe bauen: günstige Gebäude, mehr Steuern, jede Pflanze überall, keine Piraten, keine Katastrophen, keine Flüsse, Berge am Rand'))
$presetTips.SetToolTip($buttonTough, (Txt 'Rivals at their strongest and ambitious, strong pirates with a huge fleet, more disasters' 'Gegner in Höchstform und ehrgeizig, starke Piraten mit riesiger Flotte, mehr Katastrophen'))
$buttonBig.Add_Click({ Set-Selection (Complete-Choice $EverythingBig) })
$buttonCampaigns.Add_Click({ Set-Selection (Complete-Choice $ForCampaigns) })
$buttonGiant.Add_Click({ Set-Selection (Complete-Choice $GiantWorld) })
$buttonRelaxed.Add_Click({ Set-Selection (Complete-Choice $Relaxed) })
$buttonTough.Add_Click({ Set-Selection (Complete-Choice $Tough) })
$buttonDefaults.Add_Click({ Set-Selection (Complete-Choice @{}) })


# --- Tab 2: continue -----------------------------------------------------------------------------------------
$pageContinue = New-Tab (Txt 'Continue' 'Weiterspielen')
$pageContinue.Controls.Add((New-Label (Txt ('Your savegames with the settings they were made with. Select one and click “Play with these settings”,' + [Environment]::NewLine + 'then choose “Load Game” in the game and open it.') `
                ('Deine Spielstände mit den Einstellungen, mit denen sie entstanden sind. Einen auswählen, „Mit diesen' + [Environment]::NewLine + 'Einstellungen spielen“ klicken und im Spiel „Spiel laden“ wählen.') $true 0 10)))
$saveList = New-Object Windows.Forms.ListView
$saveList.View = 'Details'
$saveList.FullRowSelect = $true
$saveList.MultiSelect = $false
$saveList.HideSelection = $false
$saveList.Width = 900
$saveList.Height = 380
[void]$saveList.Columns.Add((Txt 'Savegame' 'Spielstand'), 250)
[void]$saveList.Columns.Add((Txt 'Saved' 'Gespeichert'), 135)
[void]$saveList.Columns.Add((Txt 'Map' 'Karte'), 95)
[void]$saveList.Columns.Add((Txt 'Settings' 'Einstellungen'), 395)
# Long descriptions as a tooltip.
$saveList.ShowItemToolTips = $true
$pageContinue.Controls.Add($saveList)

function Update-SaveList {
    $saveList.BeginUpdate()
    $saveList.Items.Clear()
    foreach ($e in Get-SaveList) {
        $item = New-Object Windows.Forms.ListViewItem($e.Name)
        [void]$item.SubItems.Add($e.Time.ToString('dd.MM.yyyy HH:mm'))
        [void]$item.SubItems.Add($(if ($e.Width) { '{0} × {1}' -f $e.Width, $e.Height } else { '?' }))
        [void]$item.SubItems.Add((Get-SaveDescription $e))
        if ($e.Kind -eq 'unknown') { $item.ForeColor = [Drawing.Color]::DimGray }
        $item.ToolTipText = Get-SaveDescription $e
        $item.Tag = $e
        [void]$saveList.Items.Add($item)
    }
    $saveList.EndUpdate()
}

$continueRow = New-ButtonRow $pageContinue
$buttonContinue = New-Button (Txt 'Play with these settings' 'Mit diesen Einstellungen spielen') $continueRow
$buttonContinue.Enabled = $false
$buttonSaveFolder = New-Button (Txt 'Open savegame folder' 'Spielstand-Ordner öffnen') $continueRow
$continueNote = New-Label '' $true 6 0
$pageContinue.Controls.Add($continueNote)

$saveList.Add_SelectedIndexChanged({
        $e = if ($saveList.SelectedItems.Count) { $saveList.SelectedItems[0].Tag } else { $null }
        $buttonContinue.Enabled = [bool]($e -and $e.Kind -ne 'unknown')
        $continueNote.Text = if (-not $e) { '' }
        elseif ($e.Kind -eq 'known') { Txt 'Starts the game with exactly the options of this savegame.' 'Startet das Spiel mit genau den Optionen dieses Spielstands.' }
        elseif ($e.Kind -eq 'size') { Txt 'Starts the game with this map size and your current options from “New game”.' 'Startet das Spiel mit dieser Kartengrösse und deinen aktuellen Optionen aus „Neues Spiel“.' }
        elseif ($e.Kind -eq 'original') { Txt 'Starts the original game without changes.' 'Startet das Originalspiel ohne Änderungen.' }
        else { Txt 'Unknown settings: start it with the map size it was played with (tab “New game”).' 'Einstellungen unbekannt: mit der Kartengrösse starten, mit der er gespielt wurde (Registerkarte „Neues Spiel“).' }
    })
$buttonSaveFolder.Add_Click({ if (Test-Path -LiteralPath $SaveFolder) { Start-Process explorer.exe -ArgumentList "`"$SaveFolder`"" } })

# --- Tab 3: adventures ---------------------------------------------------------------------------------------
$pageAdventures = New-Tab (Txt 'Adventures' 'Abenteuer')
$pageAdventures.Controls.Add((New-Label (Txt ('Your own scenarios (in the game under “New Game” → “Own Scenarios”). The logbook notes every mission' + [Environment]::NewLine + 'you win; the next open chapter of each campaign is marked. The World Empire campaign is made for the giant world:' + [Environment]::NewLine + 'choose the preset “Giant world” on the “New game” tab before you play it.') `
                ('Deine eigenen Szenarien (im Spiel unter „Neues Spiel“ → „Eigene Szenarien“). Das Logbuch merkt sich jede' + [Environment]::NewLine + 'gewonnene Mission; das nächste offene Kapitel jeder Kampagne ist markiert. Die Kampagne Weltreich ist für die' + [Environment]::NewLine + 'Riesenwelt gebaut: vorher im Tab „Neues Spiel“ die Vorlage „Riesenwelt“ wählen.') $true 0 10)))
$scenarioList = New-Object Windows.Forms.ListView
$scenarioList.View = 'Details'
$scenarioList.FullRowSelect = $true
$scenarioList.MultiSelect = $false
$scenarioList.Width = 900
$scenarioList.Height = 320
[void]$scenarioList.Columns.Add((Txt 'Scenario' 'Szenario'), 340)
[void]$scenarioList.Columns.Add((Txt 'Campaign' 'Kampagne'), 170)
[void]$scenarioList.Columns.Add((Txt 'Status' 'Stand'), 365)
$pageAdventures.Controls.Add($scenarioList)

function Update-ScenarioList {
    $results = Get-MissionResults
    $unlock = $checkUnlock.Checked -and $checkUnlock.Enabled
    $scenarioList.BeginUpdate()
    $scenarioList.Items.Clear()
    # The files in Own Scenarios plus, with chapters unlocked one by one, the locked chapters (not installed).
    $entries = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $OwnScenarios) {
        foreach ($f in Get-ChildItem -LiteralPath $OwnScenarios -Filter '*.szs' -File) {
            # "Last Szenario" is the game's own autosave of the last scenario, not a scenario of its own.
            if ($f.BaseName -ne 'Last Szenario') { $entries.Add(@{ Name = $f.BaseName; Locked = $null }) }
        }
    }
    if ($unlock) {
        $have = @{}; foreach ($e in $entries) { $have[$e.Name] = $true }
        foreach ($ch in Get-ChapterStates (Get-ChapterIndex) $results) { if ($ch.Locked -and -not $have.ContainsKey($ch.File)) { $entries.Add(@{ Name = $ch.File; Locked = $ch.Previous }) } }
    }
    $nextMarked = @{}
    foreach ($e in $entries | Sort-Object { Get-CampaignName $_.Name }, { if ($_.Name -match '\s(\d+)(\s|$)') { [int]$Matches[1] } else { 0 } }, { $_.Name }) {
        $campaign = Get-CampaignName $e.Name
        $item = New-Object Windows.Forms.ListViewItem($e.Name)
        [void]$item.SubItems.Add($campaign)
        $r = $results[$e.Name]
        $won = $r -and $r.result -eq 'won'
        # The first chapter of a campaign that is not won yet is the next one (also when it was lost before).
        $isNext = (-not $won) -and (-not $e.Locked) -and $e.Name -match '\s\d+\s+-\s' -and -not $nextMarked.ContainsKey($campaign)
        if ($isNext) { $nextMarked[$campaign] = $true }
        $new = if ($script:NewlyUnlocked -contains $e.Name) { Txt ' – just unlocked' ' – neu freigeschaltet' } else { '' }
        $status = if ($e.Locked) { (Txt '🔒 locked – win chapter {0} first' '🔒 gesperrt – zuerst Kapitel {0} gewinnen') -f $e.Locked }
        elseif ($won) { (Txt '✓ won {0}' '✓ gewonnen {0}') -f ([datetime]$r.date).ToString('dd.MM.yyyy') }
        elseif ($r -and $isNext) { Txt '→ next chapter (lost before – try again)' '→ nächstes Kapitel (verloren – nochmals versuchen)' }
        elseif ($r) { Txt 'lost – try again' 'verloren – nochmals versuchen' }
        elseif ($isNext) { (Txt '→ next chapter' '→ nächstes Kapitel') + $new }
        else { '' }
        if ($e.Locked) { $item.ForeColor = [Drawing.Color]::Gray }
        elseif ($won) { $item.ForeColor = [Drawing.Color]::SeaGreen }
        $item.Tag = $e
        [void]$item.SubItems.Add($status)
        [void]$scenarioList.Items.Add($item)
    }
    $scenarioList.EndUpdate()
}

# Below the list: the scenario designer and the option to unlock the campaign chapters one by one.
$adventureRow = New-ButtonRow $pageAdventures
$adventureRow.Margin = New-Object Windows.Forms.Padding(0, 6, 0, 0)
$buttonDesigner = New-Button (Txt 'Build your own scenario …' 'Eigenes Szenario bauen …') $adventureRow
$buttonDesigner.Enabled = (Test-Path -LiteralPath $Designer) -and (Test-Path -LiteralPath $Generator)
$checkUnlock = New-Object Windows.Forms.CheckBox
$checkUnlock.Text = Txt 'Unlock chapters one by one (the next chapter of a campaign after each win)' 'Kapitel nacheinander freischalten (das nächste Kapitel einer Kampagne nach jedem Sieg)'
$checkUnlock.AutoSize = $true
$checkUnlock.Margin = New-Object Windows.Forms.Padding(12, 9, 3, 3)
$adventureRow.Controls.Add($checkUnlock)
$adventureTips = New-Object Windows.Forms.ToolTip
$adventureTips.SetToolTip($buttonDesigner, (Txt 'Map, world, rivals, ships and a mission of your own – with a story and a preview of the mission text.' 'Karte, Welt, Gegner, Schiffe und ein eigener Auftrag – mit Geschichte und Vorschau des Auftragstexts.'))
$hasChapterSet = @(Get-ChapterIndex).Count -gt 0
$adventureTips.SetToolTip($checkUnlock, $(if ($hasChapterSet) { Txt 'Own Scenarios then holds of each campaign only the chapters you have won and the next one. Off: all chapters again.' 'In den eigenen Szenarien stehen dann von jeder Kampagne nur die gewonnenen Kapitel und das nächste. Aus: wieder alle Kapitel.' } else { Txt 'Needs the chapter set of the installer: please run install.cmd of this version again.' 'Braucht den Kapitelsatz des Installers: bitte install.cmd dieser Version nochmals ausführen.' }))
$checkUnlock.Enabled = $hasChapterSet
$checkUnlock.Checked = $hasChapterSet -and ($saved['UnlockChapters'] -eq '1')
# With the option on, install the next chapter after a new win (and remove chapters that are locked again).
$script:NewlyUnlocked = @()
if ($checkUnlock.Checked) { try { $script:NewlyUnlocked = @(Sync-Chapters $true) } catch { } }

# Random adventure: difficulty, optional seed, then build it into "Own Scenarios". The daily adventure: the same for
# everyone on that day.
$rollBox = New-Object Windows.Forms.GroupBox
$rollBox.Text = Txt 'Random adventure – a new island world with a new mission every time' 'Zufallsabenteuer – jedes Mal eine neue Inselwelt mit neuem Auftrag'
$rollBox.AutoSize = $true
$rollBox.Padding = New-Object Windows.Forms.Padding(8, 6, 8, 6)
$rollBox.Margin = New-Object Windows.Forms.Padding(3, 8, 3, 3)
$rollPanel = New-Object Windows.Forms.TableLayoutPanel
$rollPanel.AutoSize = $true
$rollPanel.ColumnCount = 6
$rollPanel.Dock = 'Fill'
$rollBox.Controls.Add($rollPanel)
$pageAdventures.Controls.Add($rollBox)
$rollPanel.Controls.Add((New-Label (Txt 'Difficulty' 'Schwierigkeit') $false 7 0))
$rollDifficulty = New-Object Windows.Forms.ComboBox
$rollDifficulty.DropDownStyle = 'DropDownList'
$rollDifficulty.Width = 170
$DifficultyKeys = @('Easy', 'Average', 'Demanding', 'Hard')
foreach ($d in (Txt 'Easy' 'Einfach'), (Txt 'Average' 'Durchschnittlich'), (Txt 'Demanding' 'Fordernd'), (Txt 'Hard' 'Schwer')) { [void]$rollDifficulty.Items.Add($d) }
$rollDifficulty.SelectedIndex = 1
$rollPanel.Controls.Add($rollDifficulty)
$rollPanel.Controls.Add((New-Label (Txt 'Number (optional)' 'Nummer (freiwillig)') $false 7 0))
$rollSeed = New-Object Windows.Forms.TextBox
$rollSeed.Width = 110
$rollSeed.MaxLength = 6
$rollPanel.Controls.Add($rollSeed)
$buttonRoll = New-Object Windows.Forms.Button
$buttonRoll.Text = Txt 'Roll an adventure' 'Abenteuer würfeln'
$buttonRoll.AutoSize = $true
$buttonRoll.Padding = New-Object Windows.Forms.Padding(10, 4, 10, 4)
$buttonRoll.Margin = New-Object Windows.Forms.Padding(12, 3, 3, 3)
$rollPanel.Controls.Add($buttonRoll)
$buttonDaily = New-Object Windows.Forms.Button
$buttonDaily.Text = Txt 'Daily adventure' 'Tagesabenteuer'
$buttonDaily.AutoSize = $true
$buttonDaily.Padding = New-Object Windows.Forms.Padding(10, 4, 10, 4)
$buttonDaily.Margin = New-Object Windows.Forms.Padding(8, 3, 3, 3)
$rollPanel.Controls.Add($buttonDaily)
$adventureTips.SetToolTip($buttonDaily, (Txt 'A new adventure every day (difficulty Average) – the same for everyone on that day.' 'Jeden Tag ein neues Abenteuer (Durchschnittlich) – an diesem Tag für alle gleich.'))
$rollResult = New-Object Windows.Forms.TextBox
$rollResult.Multiline = $true
$rollResult.ReadOnly = $true
$rollResult.ScrollBars = 'Vertical'
$rollResult.Width = 860
$rollResult.Height = 82
$rollResult.Text = Txt 'The same number always gives the same adventure – handy for playing a map again or sharing it with friends.' 'Dieselbe Nummer ergibt immer dasselbe Abenteuer – praktisch, um eine Karte nochmals zu spielen oder mit Freunden zu teilen.'
$rollPanel.Controls.Add($rollResult)
$rollPanel.SetColumnSpan($rollResult, 6)
if (-not (Test-Path -LiteralPath $Generator)) { $buttonRoll.Enabled = $false; $buttonDaily.Enabled = $false }

# Runs random-adventure.ps1 with these arguments (plus -Install, or -OutFolder in the click test) and shows the
# result: first line "<name>: <path>", then a technical summary, then the goals as "  - ...".
function Invoke-Generator([string[]]$generatorArgs, $button) {
    # Direct call of a native program: PowerShell quotes the path itself.
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Generator) + $generatorArgs
    $a += if ($TestClicks) { @('-OutFolder', $TestOutFolder) } else { @('-Install') }
    $form.Cursor = [Windows.Forms.Cursors]::WaitCursor
    $button.Enabled = $false
    try {
        $output = @(& powershell @a 2>&1 | ForEach-Object { "$_" })
        $titleLine = @($output | Where-Object { $_ -match '^\S.*\.szs$' } | Select-Object -First 1)
        $goals = @($output | Where-Object { $_ -match '^\s+- ' } | ForEach-Object { $_.Trim() })
        if ($LASTEXITCODE -eq 0 -and $titleLine.Count -and $goals.Count) {
            $name = ($titleLine[0] -replace ':\s+\S:\\.*$', '')
            $rollResult.Text = ((Txt '“{0}” is ready – in the game under “New Game” → “Own Scenarios”. Your mission:' '„{0}“ ist bereit – im Spiel unter „Neues Spiel“ → „Eigene Szenarien“. Dein Auftrag:') -f $name) + [Environment]::NewLine + ($goals -join [Environment]::NewLine)
        }
        else { $rollResult.Text = (@($output) | Where-Object { $_ } | Select-Object -Last 12) -join [Environment]::NewLine }
    }
    catch { $rollResult.Text = $_.Exception.Message }
    finally { $form.Cursor = [Windows.Forms.Cursors]::Default; $button.Enabled = $true }
    Update-ScenarioList
}
$buttonRoll.Add_Click({
        $seedText = $rollSeed.Text.Trim()
        if ($seedText -and $seedText -notmatch '^\d{1,6}$') { $rollResult.Text = Txt 'The number must be a whole number from 0 to 999999.' 'Die Nummer muss eine ganze Zahl von 0 bis 999999 sein.'; return }
        $a = @('-Difficulty', $DifficultyKeys[$rollDifficulty.SelectedIndex])
        if ($seedText) { $a += @('-Seed', $seedText) }
        Invoke-Generator $a $buttonRoll
    })
# The daily adventure always has the difficulty Average, so that it is the same for everyone.
$buttonDaily.Add_Click({ Invoke-Generator @('-Daily') $buttonDaily })

# The scenario designer opens as a dialog of this window; afterwards the list shows the new scenario.
$buttonDesigner.Add_Click({
        $designerArgs = @{ Owner = $form; AppDataFolder = $AppDataFolder; DocumentsFolder = $DocumentsFolder }
        if ($TestClicks) {
            # Click test: a fixed design, "Create" clicked in code; into Own Scenarios only of a test documents folder.
            $spec = Join-Path $TestOutFolder 'designer-test.json'
            New-Item -ItemType Directory -Force -Path $TestOutFolder | Out-Null
            @{ Name = 'Testinsel'; MapKind = 'Classic'; MapNumber = 4711; Difficulty = 1; StorySeed = 7; Towns = @(@{ Residents = 400; Stage = 1; OfWhich = 200 }); Balance = 0; Ships = @(23) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $spec -Encoding UTF8
            $designerArgs.SpecFile = $spec; $designerArgs.TestCreate = $true
            if (-not $DocumentsGiven) { $designerArgs.OutFolder = $TestOutFolder }
        }
        $result = $null
        $form.Cursor = [Windows.Forms.Cursors]::WaitCursor
        try { $result = @(& $Designer @designerArgs) | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1 }
        catch { $rollResult.Text = (Txt 'The scenario designer stopped: {0}' 'Der Szenario-Baukasten wurde beendet: {0}') -f $_.Exception.Message }
        finally { $form.Cursor = [Windows.Forms.Cursors]::Default }
        Update-ScenarioList
        if ($result -and @($result.Created).Count) {
            $name = @($result.Created)[-1]
            $rollResult.Text = (Txt '“{0}” is ready – in the game under “New Game” → “Own Scenarios”.' '„{0}“ ist bereit – im Spiel unter „Neues Spiel“ → „Eigene Szenarien“.') -f $name
            if ($result.ShowList) {
                $tabs.SelectedIndex = 2
                foreach ($item in $scenarioList.Items) { if ($item.Text -eq $name) { $item.Selected = $true; $item.Focused = $true; $item.EnsureVisible() } }
            }
        }
    })
$checkUnlock.Add_CheckedChanged({
        try { $script:NewlyUnlocked = @(Sync-Chapters $checkUnlock.Checked) } catch { $rollResult.Text = $_.Exception.Message }
        Save-Choice
        Update-ScenarioList
    })
Update-ScenarioList

# --- Buttons below the tabs ----------------------------------------------------------------------------------
# One row as wide as the tabs: the buttons flush left, the check boxes flush right, all centred vertically.
function New-WideRow([int]$columns, [int[]]$stretch) {
    $row = New-Object Windows.Forms.TableLayoutPanel
    $row.AutoSize = $true
    $row.Dock = 'Fill'
    $row.Margin = New-Object Windows.Forms.Padding(0)
    $row.RowCount = 1
    $row.ColumnCount = $columns
    foreach ($i in 0..($columns - 1)) {
        $style = if ($stretch -contains $i) { New-Object Windows.Forms.ColumnStyle('Percent', 50) } else { New-Object Windows.Forms.ColumnStyle('AutoSize') }
        [void]$row.ColumnStyles.Add($style)
    }
    [void]$row.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
    $outer.Controls.Add($row)
    $row
}
function Set-Cell($row, $control, [int]$column) {
    if ($control.Parent -ne $row) { $row.Controls.Add($control) }
    $row.SetCellPosition($control, (New-Object Windows.Forms.TableLayoutPanelCellPosition($column, 0)))
}
$buttons = New-WideRow 6 @(3)
$buttonStart = New-Button (Txt 'Play with extensions' 'Mit Erweiterungen spielen') $buttons
$buttonStart.Margin = New-Object Windows.Forms.Padding(0, 3, 8, 3)
$buttonOriginal = New-Button (Txt 'Start original' 'Original starten') $buttons
# The logbook: a small window next to the game with mission progress, statistics and milestones.
$buttonLogbook = New-Button (Txt 'Open logbook' 'Logbuch öffnen') $buttons
$buttonLogbook.Visible = (Test-Path -LiteralPath $Logbook)
function Start-Logbook { Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Logbook`"") }
$buttonLogbook.Add_Click({ Start-Logbook })
# Open the logbook together with the game (remembered in settings.json; the logbook itself allows only one window).
$checkLogbook = New-Object Windows.Forms.CheckBox
$checkLogbook.Text = Txt 'Open the logbook with the game' 'Logbuch mit dem Spiel öffnen'
$checkLogbook.AutoSize = $true
$checkLogbook.Anchor = 'None'
# GDI text (as measured) leaves no gap after the text, so that the last check box ends flush with the tabs; the margins
# put the text on the line of the button texts.
$checkLogbook.UseCompatibleTextRendering = $false
$checkLogbook.Margin = New-Object Windows.Forms.Padding(12, 6, 0, 2)
$checkLogbook.Checked = ($saved['LogbookWithGame'] -eq '1')
$checkLogbook.Visible = (Test-Path -LiteralPath $Logbook)
Set-Cell $buttons $buttonStart 0
Set-Cell $buttons $buttonOriginal 1
Set-Cell $buttons $buttonLogbook 2
Set-Cell $buttons $checkLogbook 4
function Start-LogbookIfWanted { if ($checkLogbook.Checked -and $checkLogbook.Visible) { Start-Logbook } }
# Install new versions by themselves (settings.json AutoUpdate, on unless switched off; only for an installed copy).
$checkAutoUpdate = New-Object Windows.Forms.CheckBox
$checkAutoUpdate.Text = Txt 'Update automatically' 'Automatisch aktualisieren'
$checkAutoUpdate.AutoSize = $true
$checkAutoUpdate.Anchor = 'None'
$checkAutoUpdate.UseCompatibleTextRendering = $false
$checkAutoUpdate.Margin = New-Object Windows.Forms.Padding(18, 6, 0, 2)
$checkAutoUpdate.Checked = ($saved['AutoUpdate'] -ne '0')
$checkAutoUpdate.Visible = [bool]$InstalledVersion
Set-Cell $buttons $checkAutoUpdate 5
$buttonTips = New-Object Windows.Forms.ToolTip
$buttonTips.AutoPopDelay = 20000
$buttonTips.SetToolTip($checkAutoUpdate, (Txt 'At every start the launcher asks GitHub for the newest version. A newer one is installed at once (settings, logbook and saves stay) and the launcher opens again.' 'Bei jedem Start fragt der Starter GitHub nach der neusten Version. Eine neuere wird gleich installiert (Einstellungen, Logbuch und Spielstände bleiben) und der Starter öffnet sich wieder.'))
$form.AcceptButton = $buttonStart

# --- Updates ----------------------------------------------------------------------------------------------------
# A bar below the buttons, as wide as the tabs and hidden until there is something to say: a newer release on GitHub
# (installed at once with "Update automatically", otherwise with the button), after an update the new version with its
# release notes, or why the download failed. Symbol, text and button sit in the middle of a rounded, coloured bar.
$UpdateStyles = @{
    Done  = @{ Back = [Drawing.Color]::FromArgb(232, 245, 233); Line = [Drawing.Color]::FromArgb(129, 199, 132); Fore = [Drawing.Color]::FromArgb(27, 94, 32); Symbol = [string][char]0x2714 }
    New   = @{ Back = [Drawing.Color]::FromArgb(227, 242, 253); Line = [Drawing.Color]::FromArgb(100, 181, 246); Fore = [Drawing.Color]::FromArgb(13, 71, 161); Symbol = [string][char]0x2B07 }
    Busy  = @{ Back = [Drawing.Color]::FromArgb(227, 242, 253); Line = [Drawing.Color]::FromArgb(100, 181, 246); Fore = [Drawing.Color]::FromArgb(13, 71, 161); Symbol = [string][char]0x21BB }
    Error = @{ Back = [Drawing.Color]::FromArgb(255, 235, 238); Line = [Drawing.Color]::FromArgb(229, 115, 115); Fore = [Drawing.Color]::FromArgb(183, 28, 28); Symbol = [string][char]0x26A0 }
}
$script:UpdateStyle = $UpdateStyles.Done
$updateRow = New-WideRow 6 @(0, 5)
$updateRow.Margin = New-Object Windows.Forms.Padding(0, 10, 0, 0)
$updateRow.Padding = New-Object Windows.Forms.Padding(12, 6, 12, 6)
$updateRow.Visible = $false
$updateRow.Add_Paint({
        param($bar, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $w = $bar.ClientSize.Width - 1; $h = $bar.ClientSize.Height - 1; $d = [Math]::Min(12, $h)
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc(0, 0, $d, $d, 180, 90); $path.AddArc($w - $d, 0, $d, $d, 270, 90)
        $path.AddArc($w - $d, $h - $d, $d, $d, 0, 90); $path.AddArc(0, $h - $d, $d, $d, 90, 90); $path.CloseFigure()
        $brush = New-Object Drawing.SolidBrush($script:UpdateStyle.Back); $pen = New-Object Drawing.Pen($script:UpdateStyle.Line)
        $g.FillPath($brush, $path); $g.DrawPath($pen, $path)
        $brush.Dispose(); $pen.Dispose(); $path.Dispose()
    })
$updateRow.Add_SizeChanged({ $this.Invalidate() })
$updateSymbol = New-Object Windows.Forms.Label
$updateSymbol.AutoSize = $true
$updateSymbol.Anchor = 'None'
$updateSymbol.BackColor = [Drawing.Color]::Transparent
$updateSymbol.Font = New-Object Drawing.Font('Segoe UI Symbol', 12)
$updateSymbol.UseCompatibleTextRendering = $false
$updateSymbol.Margin = New-Object Windows.Forms.Padding(0, 4, 6, 0)
Set-Cell $updateRow $updateSymbol 1
$updateLabel = New-Object Windows.Forms.Label
$updateLabel.AutoSize = $true
$updateLabel.Anchor = 'None'
$updateLabel.BackColor = [Drawing.Color]::Transparent
$updateLabel.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$updateLabel.MaximumSize = New-Object Drawing.Size(640, 0)
$updateLabel.UseCompatibleTextRendering = $false
$updateLabel.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 0)
Set-Cell $updateRow $updateLabel 2
$buttonUpdate = New-Button (Txt 'Update now' 'Jetzt aktualisieren') $updateRow
$buttonNews = New-Button (Txt 'What is new?' 'Was ist neu?') $updateRow
foreach ($b in $buttonUpdate, $buttonNews) { $b.Anchor = 'None'; $b.UseVisualStyleBackColor = $true; $b.Margin = New-Object Windows.Forms.Padding(14, 0, 0, 0) }
Set-Cell $updateRow $buttonUpdate 3
Set-Cell $updateRow $buttonNews 4
$buttonNews.Visible = $false
# Shows the bar in a style (Done, New, Busy, Error) with a text; the buttons are set by the caller.
function Set-UpdateBar([string]$kind, [string]$text) {
    $script:UpdateStyle = $UpdateStyles[$kind]
    $updateSymbol.Text = $script:UpdateStyle.Symbol
    $updateSymbol.ForeColor = $script:UpdateStyle.Fore
    $updateLabel.Text = $text
    $updateLabel.ForeColor = $script:UpdateStyle.Fore
    $updateRow.Visible = $true
    $updateRow.Invalidate($true)
}
$GetScriptUrl = 'https://raw.githubusercontent.com/MisterDeeds/anno1602-extensions/main/get.ps1'
$UpdateFile = Join-Path ([IO.Path]::GetTempPath()) 'anno1602-extensions-update.ps1'
# Version and day of the last automatic update ("3.3.0 2026-11-15"): at most one try per version and day, so that a
# failing update cannot run again and again.
$script:UpdateTried = [string]$saved['UpdateTried']

# Downloads get.ps1 and runs it as a file in a window of its own (it waits for Enter only after an error), then closes
# the launcher; the installer opens the new one.
function Start-Update {
    if ($PreviewImage) { return }
    Save-Choice
    try {
        if ($TestClicks) { $script:Started.Add("DOWNLOAD $GetScriptUrl") }
        else {
            $ProgressPreference = 'SilentlyContinue'
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $GetScriptUrl -OutFile $UpdateFile -UseBasicParsing -Headers @{ 'User-Agent' = 'anno1602-extensions-launcher' } -TimeoutSec 30
        }
    }
    catch {
        Set-UpdateBar 'Error' ((Txt 'The update could not be downloaded: {0}' 'Das Update konnte nicht geladen werden: {0}') -f $_.Exception.Message)
        $buttonUpdate.Visible = $true
        $buttonNews.Visible = $false
        return
    }
    $env:ANNO_EXTENSIONS_PAUSE_ON_ERROR = '1'
    Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$UpdateFile`"")
    $form.Close()
}
# Called with the newest release ("v3.3.0"): nothing if it is not newer than the installed version; otherwise the
# notice, and with "Update automatically" the update itself - not while the game runs, at most once per version and day.
function Show-UpdateNotice([string]$tag) {
    if (-not $InstalledVersion -or $tag -notmatch '^v?(\d+\.\d+\.\d+)$') { return }
    $newest = [version]$Matches[1]
    if ($newest -le $InstalledVersion) { return }
    Set-UpdateBar 'New' ((Txt 'Version {0} is out.' 'Version {0} ist da.') -f $newest)
    $buttonUpdate.Visible = $true
    $buttonNews.Visible = $false
    $attempt = '{0} {1}' -f $newest, (Get-Date -Format 'yyyy-MM-dd')
    if ($checkAutoUpdate.Checked -and $script:UpdateTried -ne $attempt -and -not (Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue)) {
        $script:UpdateTried = $attempt
        Set-UpdateBar 'Busy' ((Txt 'Version {0} is out and is being installed – the launcher opens again in a moment.' 'Version {0} ist da und wird installiert – der Starter öffnet sich gleich wieder.') -f $newest)
        $buttonUpdate.Visible = $false
        $form.Refresh()
        Start-Update
    }
}
$buttonUpdate.Add_Click({ Start-Update })
$checkAutoUpdate.Add_CheckedChanged({ Save-Choice })
# After an update (the version saved at the last start is older): say so once, with a button for the release notes.
function Show-UpdatedNote {
    Set-UpdateBar 'Done' ((Txt 'Updated to version {0}.' 'Aktualisiert auf Version {0}.') -f $InstalledVersion)
    $buttonUpdate.Visible = $false
    $buttonNews.Visible = $true
}
if ($InstalledVersion -and -not $PreviewImage -and $saved['LastVersion'] -match '^\d+\.\d+\.\d+$' -and [version]$saved['LastVersion'] -lt $InstalledVersion) { Show-UpdatedNote }
$buttonNews.Add_Click({ Start-Process "https://github.com/MisterDeeds/anno1602-extensions/releases/tag/v$InstalledVersion" })
# The downloaded copy of get.ps1 of the last update is no longer needed.
if (-not $TestClicks -and -not $PreviewImage) { try { if (Test-Path -LiteralPath $UpdateFile) { Remove-Item -LiteralPath $UpdateFile -Force } } catch { } }

function Save-Choice {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $SettingsFile) | Out-Null
        $sel = Get-Selection
        $sel['LogbookWithGame'] = if ($checkLogbook.Checked) { '1' } else { '0' }
        # Without a chapter set the check box is disabled: keep the saved value.
        $sel['UnlockChapters'] = if (-not $checkUnlock.Enabled) { if ($saved['UnlockChapters'] -eq '1') { '1' } else { '0' } } elseif ($checkUnlock.Checked) { '1' } else { '0' }
        $sel['AutoUpdate'] = if ($checkAutoUpdate.Checked) { '1' } else { '0' }
        if ($InstalledVersion) { $sel['LastVersion'] = [string]$InstalledVersion } elseif ($saved['LastVersion']) { $sel['LastVersion'] = $saved['LastVersion'] }
        if ($script:UpdateTried) { $sel['UpdateTried'] = $script:UpdateTried }
        $sel | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
    }
    catch { }
}
# Starts the patcher (in its own window until the game has ended; it closes by itself afterwards and stays open only on an
# error) and then the game.
function Start-WithPatcher($patcherArgs) {
    $ps = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Patcher`"") + @($patcherArgs) + @('-PauseOnError')
    Start-Process powershell -ArgumentList $ps
    Start-Sleep -Seconds 3
    Start-Process $GameStart
    Start-LogbookIfWanted
}

$buttonOriginal.Add_Click({
        Save-Choice
        Start-Process $GameStart
        Start-LogbookIfWanted
        $form.Close()
    })
$buttonStart.Add_Click({
        Save-Choice
        Start-WithPatcher (Get-PatcherArgs (Get-Selection))
        $form.Close()
    })
$buttonContinue.Add_Click({
        if (-not $saveList.SelectedItems.Count) { return }
        $e = $saveList.SelectedItems[0].Tag
        if ($e.Kind -eq 'original') { Start-Process $GameStart; Start-LogbookIfWanted }
        elseif ($e.Kind -eq 'known') { Start-WithPatcher $e.Args }
        elseif ($e.Kind -eq 'size') {
            # Current options, but the map size of the savegame.
            $a = @(Get-PatcherArgs (Get-Selection) | Where-Object { $_ })
            $clean = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $a.Count; $i++) { if ($a[$i] -in '-Width', '-Height') { $i++; continue }; $clean.Add($a[$i]) }
            $clean.AddRange([string[]]@('-Width', [string]$e.Width, '-Height', [string]$e.Height))
            Start-WithPatcher $clean
        }
        else { return }
        $form.Close()
    })
$tabs.Add_SelectedIndexChanged({
        # The play buttons below belong to the "New game" tab.
        $buttonStart.Enabled = ($tabs.SelectedIndex -ne 1)
        $buttonOriginal.Enabled = ($tabs.SelectedIndex -ne 1)
        if ($tabs.SelectedIndex -eq 1) { $form.AcceptButton = $buttonContinue } else { $form.AcceptButton = $buttonStart }
    })
Update-SaveList

# A TabControl does not size itself: make it as large as the largest page needs.
function Set-TabSize {
    $w = 0; $h = 0
    foreach ($page in $tabs.TabPages) {
        $s = $page.Controls[0].GetPreferredSize([Drawing.Size]::Empty)
        $w = [math]::Max($w, $s.Width); $h = [math]::Max($h, $s.Height)
    }
    $header = $tabs.GetTabRect(0).Height
    $tabs.Size = New-Object Drawing.Size(($w + 2 * $tabs.TabPages[0].Padding.Left + 12), ($h + $header + 2 * $tabs.TabPages[0].Padding.Top + 14))
}
Set-TabSize

if ($TestClicks) {
    # Record instead of starting: these functions hide the cmdlets for the button handlers of this script.
    $script:Started = New-Object System.Collections.Generic.List[string]
    function Start-Process { param([Parameter(Position = 0)]$FilePath, $ArgumentList, $WindowStyle) $script:Started.Add(('START {0} {1}' -f $FilePath, (@($ArgumentList) -join ' ')).TrimEnd()) }
    function Start-Sleep { }
    # Click in code (works also while the form is closing): call the protected OnClick of the button.
    function Invoke-Click($button) { $button.GetType().GetMethod('OnClick', [Reflection.BindingFlags]'NonPublic, Instance').Invoke($button, @([EventArgs]::Empty)) }
    function Write-Step([string]$what) { $script:Started.Add("--- $what") }
    $form.StartPosition = 'Manual'; $form.Location = New-Object Drawing.Point(-10000, -10000); $form.ShowInTaskbar = $false
    $form.Add_Shown({
            Write-Step ('At the start: version saved at the last start {0}' -f $(if ($saved['LastVersion']) { $saved['LastVersion'] } else { 'none' }))
            $script:Started.Add(('UPDATED-NOTE visible: {0} {1} | news button {2}' -f $updateRow.Visible, $updateLabel.Text, $buttonNews.Visible))
            Write-Step 'preset Relaxed, logbook with the game, Play with extensions'; $checkLogbook.Checked = $true; Invoke-Click $buttonRelaxed; Invoke-Click $buttonStart
            $script:Started.Add('SETTINGS LogbookWithGame=' + (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).LogbookWithGame); $checkLogbook.Checked = $false
            Write-Step 'preset Tough test, Start original'; Invoke-Click $buttonTough; Invoke-Click $buttonOriginal
            Write-Step 'preset Giant world, Play with extensions'; Invoke-Click $buttonGiant; Invoke-Click $buttonStart
            Write-Step 'Open logbook'; Invoke-Click $buttonLogbook
            # As a player would: switch to the tab first (the list only reports a selection once it is shown).
            $tabs.SelectedIndex = 1
            foreach ($kind in 'known', 'size', 'original') {
                $item = @($saveList.Items | Where-Object { $_.Tag.Kind -eq $kind }) | Select-Object -First 1
                if (-not $item) { Write-Step "Continue: no $kind savegame"; continue }
                Write-Step ('Continue: {0} savegame "{1}", button enabled: {2}' -f $kind, $item.Text, $($item.Selected = $true; $buttonContinue.Enabled)); Invoke-Click $buttonContinue
            }
            Write-Step 'Roll an adventure: Demanding, number 4711'; $rollDifficulty.SelectedIndex = 2; $rollSeed.Text = '4711'; Invoke-Click $buttonRoll
            $script:Started.Add('RESULT ' + ($rollResult.Text -replace "`r?`n", ' | '))
            Write-Step 'Roll with an invalid number'; $rollSeed.Text = '12345678'; Invoke-Click $buttonRoll
            $script:Started.Add('RESULT ' + $rollResult.Text)
            Write-Step 'Daily adventure'; $rollSeed.Text = ''; Invoke-Click $buttonDaily
            $script:Started.Add('RESULT ' + ($rollResult.Text -replace "`r?`n", ' | '))
            # The designer opens as a dialog of this window: a fixed test design, "Create" clicked in code, "show it" = yes.
            Write-Step 'Build your own scenario'; $tabs.SelectedIndex = 0; Invoke-Click $buttonDesigner
            $script:Started.Add('RESULT ' + ($rollResult.Text -replace "`r?`n", ' | '))
            $script:Started.Add(('LIST tab {0}, selected: {1}' -f $tabs.SelectedIndex, (@($scenarioList.SelectedItems | ForEach-Object { $_.Text }) -join ', ')))
            # Chapters one by one: on (locked chapters leave Own Scenarios and show a lock), then off (all back).
            $listState = { '{0} entries, {1} locked; Own Scenarios: {2} files' -f $scenarioList.Items.Count, @($scenarioList.Items | Where-Object { $_.Tag.Locked }).Count, @(Get-ChildItem -LiteralPath $OwnScenarios -Filter '*.szs' -ErrorAction SilentlyContinue).Count }
            # Only with a test documents folder: the check box copies and removes files in Own Scenarios.
            Write-Step ('Unlock chapters one by one: enabled {0}, test documents folder {1}, before: {2}' -f $checkUnlock.Enabled, $DocumentsGiven, (& $listState))
            if ($checkUnlock.Enabled -and $DocumentsGiven) {
                $checkUnlock.Checked = $false
                $checkUnlock.Checked = $true
                $script:Started.Add('ON  ' + (& $listState) + '; SETTINGS UnlockChapters=' + (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).UnlockChapters)
                foreach ($item in $scenarioList.Items) { if ($item.Text -match '\s\d+\s+-\s') { $script:Started.Add(('  {0} | {1}' -f $item.Text, $item.SubItems[2].Text)) } }
                $checkUnlock.Checked = $false
                $script:Started.Add('OFF ' + (& $listState) + '; SETTINGS UnlockChapters=' + (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).UnlockChapters)
            }
            # Updates: an older release changes nothing; a newer one with "Update automatically" off shows the notice and
            # the button downloads and starts get.ps1; with it on the update starts by itself, but only once a day.
            Write-Step ('Updates, installed version {0}' -f $(if ($InstalledVersion) { $InstalledVersion } else { 'none' }))
            $updateStarts = { @($script:Started | Where-Object { $_ -like 'START powershell*-File*anno1602-extensions-update.ps1*' }).Count }
            $checkAutoUpdate.Checked = $false
            Show-UpdateNotice 'v1.0.0'; $script:Started.Add('UPDATE v1.0.0: ' + $updateLabel.Text)
            Show-UpdateNotice 'v99.0.0'; $script:Started.Add(('UPDATE v99.0.0 auto off: {0}, starts {1}' -f $updateLabel.Text, (& $updateStarts)))
            Invoke-Click $buttonUpdate; $script:Started.Add('UPDATE button: starts ' + (& $updateStarts))
            $script:UpdateTried = ''; $checkAutoUpdate.Checked = $true
            Show-UpdateNotice 'v99.0.0'
            $script:Started.Add(('UPDATE auto on: starts {0}, {1}, saved AutoUpdate={2} UpdateTried={3}' -f (& $updateStarts), $updateLabel.Text, (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).AutoUpdate, (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).UpdateTried))
            Show-UpdateNotice 'v99.0.0'; $script:Started.Add('UPDATE auto again the same day: starts ' + (& $updateStarts))
            $form.Close()
        })
    [void]$form.ShowDialog()
    $script:Started
    return
}
if ($PreviewImage) {
    $form.StartPosition = 'Manual'
    $form.Location = New-Object Drawing.Point(-10000, -10000)
    $form.ShowInTaskbar = $false
    $form.Add_Shown({
            $tabs.SelectedIndex = $PreviewTab
            if ($PreviewUpdate -eq 'updated') { Show-UpdatedNote }
            elseif ($PreviewUpdate -eq 'error') { Set-UpdateBar 'Error' ((Txt 'The update could not be downloaded: {0}' 'Das Update konnte nicht geladen werden: {0}') -f 'Der Remotename konnte nicht aufgelöst werden: "raw.githubusercontent.com"'); $buttonNews.Visible = $false }
            elseif ($PreviewUpdate) { Show-UpdateNotice $PreviewUpdate }
            $form.Refresh()
            $image = New-Object Drawing.Bitmap($form.Width, $form.Height)
            $form.DrawToBitmap($image, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
            $image.Save($PreviewImage, [Drawing.Imaging.ImageFormat]::Png)
            $form.Close()
        })
}
elseif ($StartTab -gt 0 -and $StartTab -lt $tabs.TabCount) { $tabs.SelectedIndex = $StartTab }
# Remember this version, so that the note "Updated to version ..." appears only once.
if (-not $PreviewImage -and $InstalledVersion -and $saved['LastVersion'] -ne [string]$InstalledVersion) { Save-Choice }
# Ask GitHub for the newest release in the background (at most 8 s, only the version number is fetched; nothing is
# sent but the request itself). Off with $env:ANNO_EXTENSIONS_NO_UPDATE_CHECK = '1'.
if (-not $PreviewImage -and $InstalledVersion -and $env:ANNO_EXTENSIONS_NO_UPDATE_CHECK -ne '1') {
    try {
        $script:UpdateCheck = [PowerShell]::Create()
        [void]$script:UpdateCheck.AddScript({
                param($url)
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                    [string](Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'anno1602-extensions-launcher' } -TimeoutSec 8).tag_name
                }
                catch { '' }
            }).AddArgument($ReleaseApi)
        $script:UpdateHandle = $script:UpdateCheck.BeginInvoke()
        $updateTimer = New-Object Windows.Forms.Timer
        $updateTimer.Interval = 500
        $updateTimer.Add_Tick({
                if (-not $script:UpdateHandle.IsCompleted) { return }
                $updateTimer.Stop()
                try { Show-UpdateNotice ([string](@($script:UpdateCheck.EndInvoke($script:UpdateHandle)) | Select-Object -First 1)) } catch { }
                $script:UpdateCheck.Dispose()
            })
        $updateTimer.Start()
    }
    catch { }
}
[void]$form.ShowDialog()
