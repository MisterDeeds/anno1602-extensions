<#
.SYNOPSIS
  EXPERIMENT: sets the map size of Anno 1602 History Edition in memory (default 1000 x 700).

.DESCRIPTION
  Changes no game files. Steps:
    1. Checks the exe on disk (SHA-256 and the original bytes at every site).
    2. Backs up the savegame folder (Documents\Anno 1602 History Edition\Savegame), but only
       if it has changed since the last backup.
    3. Waits until Anno1602.exe is running (start the game as usual via Ubisoft Connect).
       If the first process exits right away (Ubisoft Connect then restarts the game),
       the tool waits for the next one and patches that.
    4. Checks all code sites in memory (8 for the size, plus island spread and pirates/start
       gold depending on the switches) and 5 variables; only when all of them match are the
       code sites replaced (on an error everything is rolled back: all or nothing).
    5. Waits until the game has set its start values, then sets the 5 variables,
       optionally also ship speed and storage (values from figuren.cod/haeuser.cod in memory).
    6. Stays open until the game exits. If the game wrote lastgame.gam during that time
       (automatic savegame for "Continue game"), the file is renamed to
       lastgame-<width>x<height>-<time>.gam. That way "Continue game" without the tool
       does not load a big world. Switch off with -NoLastgameProtection. With -Events Rare|Often the
       window also runs the random events during this time.
  After the game exits everything is as before.
  Convenient start of tool and game together: the launcher (src\launcher.ps1, shortcut "Anno 1602 - Erweiterungen").

  What is set (see docs\FINDINGS.md, section "Map size"):
    Width, Height                 Map size in tiles (normally 500 x 350)
    Scroll range                  Camera range = Width/2 + Height/2 (normally 425); limits
                                  edge scrolling and the arrow keys
    1/Width, 1/Height (float)     Scale for the markers on the minimap
    Island spread                 Jump in the SZENE loader (FUN_1400d0de0, RVA 0xD0E29) to a
                                  short code cave in the free end of .text (RVA 0xE5100) with
                                  an island table behind it (RVA 0xE5200). For the three
                                  endless layouts (Szenes\[[48]]x0/x1/x2.szs) it inserts a
                                  list planned by the tool: original islands stretched
                                  (Width/500, Height/350), plus copies in free gaps
                                  (at 1000 x 700: 50/50/47 instead of 18/20/17 islands, all
                                  50 slots usable). Other templates are only stretched.
                                  Savegames contain no SZENE section and stay
                                  untouched. -StretchOnly: no additional islands.
                                  -NoIslandSpread: all of it off.
                                  View the plan: dev\show-island-plan.ps1
                                  Own scenarios with a big version (marker 'GROS' behind the
                                  SZENE section, e.g. the campaigns from src\build-scenarios.ps1):
                                  from the map size they were designed for (1000 x 700) on the big
                                  version is used (code cave RVA 0xE5E40), otherwise the small one, stretched.
                                  Since 3.1 a scenario can carry several versions (the campaign
                                  "Weltreich": 1000 x 700 and the giant world 2000 x 1400); the
                                  biggest one that fits the map is used.
    Pirates (-Pirates)            Default: as the chosen difficulty.
                                  Active: pirates attack, also on Easy/Average
                                  (otherwise only "occasional sightings" there).
                                  Strong: like Active, and the pirates always equip their ships
                                  with the full number of cannons.
                                  Off: pirates never attack, not even on Hard.
                                  Works when loading a template and a savegame
                                  (hook at the end of the TIMERS loader, RVA 0xC3232).
    Start gold (-StartGold)       The player's gold in new games (0 = as the chosen
                                  difficulty). Savegames stay untouched (recognised by
                                  the game clock; in the same hook as the pirates).
    Storage (-Storage)            Factor 1 to 5 for the storage per good of trading post I-IV (30/50/
                                  75/100 t) and market (10 t). Building table (from haeuser.cod,
                                  RVA 0x6BA1C0 + no. * 0x90, 16-bit value x 32 at +0x30, no. 270-273,
                                  401, 467, 468). A newly built trading post takes over the value
                                  (checked in the game); upgraded trading posts presumably as well.
    Ship speed (-ShipSpeed)       Factor 1.0 to 3.0 for the speed of all ships
                                  (also AI, traders, pirates). Normally 1.0. Set in the
                                  figure table (from figuren.cod, RVA 0x6D80C0 + no. * 0x18C,
                                  float at +0x10, ship types no. 21-32).
    Island size (-IslandSize)     Normal: classes of the template. Large: original islands one class
                                  larger (where there is room), extra islands "lar" (100 x 90) and "big"
                                  (70 x 60). Huge: almost only "lar". Fewer, but much larger islands.
                                  Giant (3.4): as Large, plus up to 6 giant islands of the island forge
                                  (135 x 120 to 160 x 140, file numbers lar20-lar27).
    Island forge (3.4)            -Rivers Off, -Mountains Edge, -Volcanoes Off and -IslandSize Giant: the C#
                                  code src\island-forge.cs writes changed copies of the game's island files
                                  (and the giant islands) once into %LOCALAPPDATA%\Anno1602-Extensions\islands;
                                  five LEA instructions of the island loaders (RVA 0xD13B2, 0xD13CF, 0x9C01A,
                                  0x9C381, 0x9C42B) point to that folder (path at RVA 0x91B200), files that
                                  are not there come from the game folder. New games only; savegames hold
                                  their islands completely. -Volcanoes Off also stops eruptions (RVA 0x9E93E).
    Rival growth (-RivalGrowth)   Ambitious (3.4): the main towns of the AI no longer end in the phases without
                                  church/bathhouse (0x22) or theatre/college (0x2C); the wait for merchant goods
                                  before church and bathhouse is dropped (RVA 0x37517, 0x37B9C, 0x37A7D); a rich AI
                                  no longer leaves phases 0x1E/0x20/0x21 on money alone before it has built there
                                  (RVA 0x36FE2, 0x37302, 0x374F4). While the game runs, this window tops up tools,
                                  bricks and the luxury goods of their towns (below 20 t -> 30 t), which the AI
                                  hardly makes itself.
    Resources (-Resources)        Normal: amounts of the template (meant for 17-20 islands). More: ore,
                                  gold, fertility of the plantations and treasures grow with the
                                  island count. Lots: twice as much. Each amount at most as
                                  large as the island count. Code cave at RVA 0xE5C00, called from
                                  the island spread (endless templates only).
    Residents (-Residents)        Factor 1 to 5 for the maximum number of residents per house and
                                  level (normally 2/6/15/25/40). haeuser.cod "Maxwohn" of the 5
                                  population groups, x 64 as int at RVA 0x6BA02C + no. * 0x50
                                  (parser FUN_140090660, read among others in FUN_1400b7c60).
    Cargo (-Cargo)                Factor 1 to 3 for the number of cargo holds of the buildable ships
                                  (small/large trading and war ship, no. 21-28), at most 8 (the ship
                                  record has 8 holds, the large war ship already uses them); every hold
                                  takes 50 t. figuren.cod "Maxware", 16 bits at figure table +0x3A
                                  (4/6/3/8). Until 3.4 this option scaled +0x3E, which is "Maxenergy"
                                  (the hull): start ships then began with a third of their hull.
    Production (-Production)      Factor 1 to 3 for the work speed of all production buildings. Divides
                                  haeuser.cod "Interval" (16 bits at building table +0x3A) of all
                                  500 entries by the factor. The game reads the value at
                                  every work step (FUN_1400b43e0, FUN_1400b9ed0), so it also works
                                  in loaded savegames. A marker at RVA 0xE5F70
                                  prevents dividing twice in the same game process.
    Turbo (-Turbo)                F7 switches to 8x instead of 4x, with -TurboLevel 12 or 16
                                  correspondingly faster (FUN_1400e2d60, RVA 0xE3376:
                                  mov ecx,4 -> mov ecx,8/12/16). The game loop FUN_1400c8e20 works
                                  with any factor; F5/F6 stay 1x and 2x.
    Explored (-Explored All)      Every island counts as explored by you from the start: its ore and gold
                                  deposits are visible and the natives are known without sailing there.
                                  Island table RVA 0x62DDC0 (50 x 0x2CC8), +0x43 = one bit per player
                                  who knows the island (set by FUN_140077210 when a ship of that player
                                  reaches it; FUN_1400c6c50 then draws the explored tiles of +0x2CB0
                                  instead of +0x2CC0). While the game runs, this window sets the bit of
                                  the local player (RVA 0x5F1D60) on every island (new and loaded games).
    Home island (-HomeIsland Perfect)
                                  New endless games get a perfect home island right at your start ship:
                                  the island forge builds Nord\lar28 (160 x 140, flat, no river, four
                                  large ore mountains 1110 in the corners at the coast); the planner puts
                                  it as a northern island (climate 0) so that the human's start ship
                                  (SHIP4 owner 0) lies on open sea just in front of its coast; at the
                                  start the tool window gives it 2 ore and 2 gold deposits on the four
                                  mountains (island +0x20 slots, +0x41 count), all six crops at 100 %
                                  (+0x5C) and marks it explored.
    Ultra (-Ultra)                New key F8: 32x, with -UltraLevel 48, 64, 96 or 128 correspondingly.
                                  The key switch of FUN_1400e2d60 ends at F7 (keys 0x10-0x76);
                                  its "ja" to the end (RVA 0xE2D7E) goes to a code cave (RVA
                                  0xE5BE0): F8 -> FUN_1400c8be0(level) like F5-F7, every other key
                                  on to the end as before. Works with or without -Turbo. F8 alone
                                  is also an accelerator of the game (player status): a filter in
                                  front of TranslateAcceleratorA (RVA 0xED11 -> code cave 0xE5D00)
                                  lets F8 without Shift/Ctrl through to the switch; the status stays
                                  on the STATUS button and Shift/Ctrl+F8.
    Rival gold (-RivalGold)       Gold of the three computer rivals (slots 1-3) in new games,
                                  0 = as the template. In the same hook as the start gold.
    Rivals (-Rivals)              Hard: the computer rivals always plan military and expansion as
                                  on the highest difficulty (FUN_140017840, FUN_140017b30,
                                  FUN_140032090, FUN_140035220 read a 3 instead of the difficulty).
                                  Natural events and pirates stay at the chosen level.
    Pirate fleet (-PirateFleet)   Large / Huge: the pirates keep 2 or 3 times as many ships
                                  (original: as many as the highest civilisation level, 2-4) and
                                  rebuild correspondingly faster (FUN_14003b7e0).
    Natives (-Natives)            More / Lots: 4 or 7 villages per climate zone instead of 2 (SZENE +0x40/
                                  +0x44, endless templates with additional islands only). Villages
                                  only appear on islands with a village site; each one takes one of
                                  the game's 75 settlement slots.
    Traders (-Traders)            More / Lots: 2 or 3 times as many free trader ships
                                  (original: 1 per 3 settlements, FUN_1400bc030), at most 24
                                  (the game has 30 trader slots).
    Build cost (-BuildCost)       Factor 0 to 1 for the construction costs of all buildings: gold and the
                                  materials tools, wood and bricks (haeuser.cod Money/Werkzeug/Holz/Ziegel,
                                  building table +0x58 int, +0x50/+0x52/+0x54 16 bits x 32). 0 = free.
                                  Materials are rounded to whole tons; with a factor above 0 everything
                                  that cost something keeps at least 1 gold or 1 t. Cannons stay. Applies
                                  to house upgrades and to the computer rivals as well. The 500 original
                                  entries are checked with a checksum; marker 'BAUK' at RVA 0xE5BC0.
    Upkeep (-Upkeep)              Factor 0 to 1 for the running costs of all buildings (haeuser.cod Kosten,
                                  16 bits at +0x2C active and +0x2A paused). A town adds them up when a
                                  building is built or a savegame is loaded; FUN_1400bc030 charges the sum
                                  with the taxes. Ships and soldiers keep their costs. Marker 'UNTH' at
                                  RVA 0xE5BC8.
    Taxes (-Taxes)                Factor 1 to 3 for the tax income per resident (haeuser.cod Steuer of the
                                  5 population groups, int at RVA 0x6BA030 + no. * 0x50, 7/8/11/12/13).
                                  Read by FUN_1400bbdc0 (income) and the town window; the tax rate slider
                                  works as before. Also for the computer rivals.
    Radius (-Radius)              Factor 1 to 2 for the radius of trading post I-IV and market (building
                                  area) and of the public buildings (chapel, church, cathedral, tavern,
                                  doctor, bathhouse, theatre, school, university, fire brigade, gallows):
                                  building table +0x20 (8 bits), 17 entries. At most 48 (circle buffer of
                                  the AI at +0x1D94 holds 52 bytes). New buildings take the area; the
                                  supply of the houses is computed all the time, also in savegames.
    Fertility (-Fertility)        Everywhere: in new endless games every island with fertile land gets all
                                  six crops (tobacco, spices, sugar cane, cotton, grapes, cocoa). In the
                                  resource code cave the fertility amounts become 50 and SZENE +0x60 the
                                  marker 'FERT'; a hook in FUN_1400d0ce0 (RVA 0xD0D56, code cave RVA
                                  0xE5BA0) then ignores the climate of the crop. Endless templates with
                                  additional islands only (not campaigns, not savegames).
    Mines (-Mines)                Infinite: ore and gold deposits are never used up (FUN_1400b9ed0, the two
                                  subtractions at RVA 0xBA429 and 0xBA495 become NOPs).
    Disasters (-Disasters)        Off: no new fire, plague, drought or volcanic eruption (5 calls in
                                  FUN_1400bc030 and FUN_14009e390 become NOPs). More: fire and plague
                                  twice as likely, the drought check (Demanding/Hard only) twice as often.
    Events (-Events)              Rare / Often: while the game runs, this window triggers random events for
                                  you, on average every 3 game hours (Rare) or every game hour (Often),
                                  measured by the game clock (turbo speeds them up, a paused game has none),
                                  only once you have a town and never after the game has ended:
                                    patron (+2,000 to +10,000 gold by your highest population level),
                                    fire in the warehouse (-5 % of your gold, at most 1,000 per level),
                                    trader's gift (10-30 t tools, wood, bricks or food in your largest town),
                                    tax windfall / tax slump (taxes x1.5 / x0.75 for one game hour),
                                    bumper harvest / marsh fever (production x1.5 / x0.75 for one game hour).
                                  Taxes and production are game-wide values (the rivals share them), they
                                  are combined with -Taxes/-Production and restored exactly when the event
                                  ends, when a game is loaded or ends, and when this window is closed. Gold
                                  and goods are real changes and are saved with the game. Every event goes to
                                  %APPDATA%\Anno1602-Extensions\events.json (shown by the logbook).
                                  State in memory: marker 'EVNT' at RVA 0xE5BD0 -> page with the originals.

  Single player only. Load savegames from the big world only with the tool active
  (the savegame does not store the size). This also applies to "Continue game"
  (lastgame.gam), which contains the big world after a game in it.
  The island spread affects every scenario template; do not use the tool
  for campaign scenarios.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\src\anno-patcher.ps1
  powershell -ExecutionPolicy Bypass -File .\src\anno-patcher.ps1 -Width 750 -Height 525
  powershell -ExecutionPolicy Bypass -File .\src\anno-patcher.ps1 -CheckOnly
  powershell -ExecutionPolicy Bypass -File .\src\anno-patcher.ps1 -Pirates Strong
#>
param(
    [ValidateRange(100, 2000)][int]$Width = 1000,
    [ValidateRange(100, 2000)][int]$Height = 700,
    # Only check the exe on disk, write nothing.
    [switch]$CheckOnly,
    [int]$WaitMinutes = 15,
    # The game has been running for a while and is surely in the main menu (no game loaded).
    [switch]$GameAlreadyRunning,
    # Do not stretch the island positions of the templates (islands stay within 500 x 350).
    [switch]$NoIslandSpread,
    # Only stretch, no additional islands.
    [switch]$StretchOnly,
    # Do not wait after the game and do not rename lastgame.gam.
    [switch]$NoLastgameProtection,
    # Pirates: Default (as the difficulty), Active, Strong (active and full cannons), Off.
    [ValidateSet('Default', 'Active', 'Strong', 'Off')][string]$Pirates = 'Default',
    # Factor for the speed of all ships (1.0 = normal).
    [ValidateRange(1.0, 3.0)][double]$ShipSpeed = 1.0,
    # Factor for the storage of trading post I-IV and market (1 = normal 30/50/75/100 t).
    [ValidateRange(1, 5)][int]$Storage = 1,
    # The player's start gold in new games (0 = as the difficulty: 20'000/15'000/10'000).
    [ValidateRange(0, 9999999)][int]$StartGold = 0,
    # Factor for the residents per house (1 = normal 2/6/15/25/40).
    [ValidateRange(1.0, 5.0)][double]$Residents = 1.0,
    # Island size in the endless game: Normal (as the template), Large (many large), Huge (almost only the largest),
    # Giant (up to 6 giant islands of the island forge, larger than the largest of the game).
    [ValidateSet('Normal', 'Large', 'Huge', 'Giant')][string]$IslandSize = 'Normal',
    # Rivers on the islands of new games: Default (as the island files) or Off (no rivers, the land becomes meadow).
    [ValidateSet('Default', 'Off')][string]$Rivers = 'Default',
    # Mountains on the islands of new games: Default (as the island files) or Edge (moved to the coast).
    [ValidateSet('Default', 'Edge')][string]$Mountains = 'Default',
    # Volcano: Default or Off (the only volcano of the game is a normal mountain, no eruptions).
    [ValidateSet('Default', 'Off')][string]$Volcanoes = 'Default',
    # Resources in the endless game: Normal (as the template), More (growing with the island count), Lots (twice as many).
    [ValidateSet('Normal', 'More', 'Lots')][string]$Resources = 'Normal',
    # Factor for the tons per cargo slot of the buildable ships (1 = normal).
    [ValidateRange(1.0, 3.0)][double]$Cargo = 1.0,
    # Factor for the work speed of all production buildings (1 = normal, 2 = twice as fast).
    [ValidateRange(1.0, 3.0)][double]$Production = 1.0,
    # F7 = 8x instead of 4x.
    [switch]$Turbo,
    # Speed of F7 with -Turbo: 8, 12 or 16x.
    [ValidateSet(8, 12, 16)][int]$TurboLevel = 8,
    # Islands explored from the start: Default (as in the game, a ship has to visit them) or All (the resources of every
    # island are known at once).
    [ValidateSet('Default', 'All')][string]$Explored = 'Default',
    # Home island: Default (find one yourself) or Perfect (a giant flat northern island with ore and gold and every crop,
    # right at the start ship).
    [ValidateSet('Default', 'Perfect')][string]$HomeIsland = 'Default',
    # New key F8 for ultra speed (the game has no F8 speed).
    [switch]$Ultra,
    # Speed of F8 with -Ultra: 32, 48, 64, 96 or 128x (measured in the game at 2000 x 1400 with giant islands: all exact).
    [ValidateSet(32, 48, 64, 96, 128)][int]$UltraLevel = 32,
    # Gold of the three computer rivals in new games (0 = as the template).
    [ValidateRange(0, 9999999)][int]$RivalGold = 0,
    # Computer rivals: Default (as the difficulty) or Hard (always as the highest level).
    [ValidateSet('Default', 'Hard')][string]$Rivals = 'Default',
    # Rival growth: Default or Ambitious (their main towns no longer stop at Buerger/Kaufleute).
    [ValidateSet('Default', 'Ambitious')][string]$RivalGrowth = 'Default',
    # Pirate fleet: Normal, Large (2 times as many ships), Huge (3 times).
    [ValidateSet('Normal', 'Large', 'Huge')][string]$PirateFleet = 'Normal',
    # Native villages per climate zone: Default (2), More (4), Lots (7).
    [ValidateSet('Default', 'More', 'Lots')][string]$Natives = 'Default',
    # Free trader ships: Default, More (2 times), Lots (3 times), at most 24.
    [ValidateSet('Default', 'More', 'Lots')][string]$Traders = 'Default',
    # Factor for the construction costs in gold, tools, wood and bricks (1 = normal, 0 = free).
    [ValidateRange(0.0, 1.0)][double]$BuildCost = 1.0,
    # Factor for the running costs of the buildings (1 = normal, 0 = none).
    [ValidateRange(0.0, 1.0)][double]$Upkeep = 1.0,
    # Factor for the tax income per resident (1 = normal).
    [ValidateRange(1.0, 3.0)][double]$Taxes = 1.0,
    # Factor for the radius of trading post, market and public buildings (1 = normal).
    [ValidateRange(1.0, 2.0)][double]$Radius = 1.0,
    # Fertility in the endless game: Default (as the template), Everywhere (all six crops on every island).
    [ValidateSet('Default', 'Everywhere')][string]$Fertility = 'Default',
    # Ore and gold deposits: Default (they run out), Infinite.
    [ValidateSet('Default', 'Infinite')][string]$Mines = 'Default',
    # Fire, plague, drought, volcano: Default, Off, More (fire and plague twice as likely).
    [ValidateSet('Default', 'Off', 'More')][string]$Disasters = 'Default',
    # Random events while you play: Off, Rare (on average every 3 game hours), Often (every game hour).
    [ValidateSet('Off', 'Rare', 'Often')][string]$Events = 'Off',
    # Started from the launcher in its own window: after the game the window closes by itself; on an error it stays
    # open until Enter is pressed, so that the message can be read.
    [switch]$PauseOnError,
    # Game folder given by hand (otherwise taken from Ubisoft Connect).
    [string]$GamePath,
    # Only for tests\test-patcher.ps1: other process and load address, no backup.
    [Parameter(DontShow)][int]$TestProcessId = 0,
    [Parameter(DontShow)][long]$TestBase = 0,
    # Only for tests: events reproducible (random seed >= 0; comma-separated event ids that come first, in this
    # order), events.json at another place, poll interval, mean interval and duration in game clock units, and in
    # test mode the game clock at which the event loop stops (as if the tool window was closed).
    [Parameter(DontShow)][int]$EventSeed = -1,
    [Parameter(DontShow)][string]$EventScript = '',
    [Parameter(DontShow)][string]$EventFile = '',
    [Parameter(DontShow)][int]$EventPollMs = 0,
    [Parameter(DontShow)][int]$EventIntervalClock = 0,
    [Parameter(DontShow)][int]$EventDurationClock = 0,
    [Parameter(DontShow)][int]$EventTestUntilClock = 0
)

$ErrorActionPreference = 'Stop'

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }
# German names of the option values (the values themselves are English), for the German messages.
$GermanValueNames = @{ Ambitious = 'Ehrgeizig'; Default = 'Standard'; Active = 'Aktiv'; Strong = 'Stark'; Off = 'Aus'; Normal = 'Normal'; Large = 'Gross'; Huge = 'Riesig'; Giant = 'Gigantisch'; Edge = 'Am Rand'; More = 'Mehr'; Lots = 'Viele'; Hard = 'Schwer'; Everywhere = 'Ueberall'; Infinite = 'Unendlich'; Rare = 'Selten'; Often = 'Haeufig' }
function Get-ValueName([string]$value) { if ($UiGerman) { $GermanValueNames[$value] } else { $value } }

# Every error stops the tool as before; started from the launcher the window then waits for Enter.
trap {
    if ($PauseOnError) {
        Write-Host ''
        Write-Host ((Txt 'Error: {0}' 'Fehler: {0}') -f $_.Exception.Message) -ForegroundColor Red
        [void](Read-Host (Txt 'Press Enter to close this window' 'Enter druecken, um dieses Fenster zu schliessen'))
    }
    break
}

$GameFolder = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition'
# Game folder on this PC: -GamePath, otherwise Ubisoft Connect (install ID 16236), otherwise
# the uninstall entry, otherwise the default folder above.
function Find-GameFolder {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $candidates.Add($d) } } catch { }
    }
    $un = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $un -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'Anno 1602 - History Edition' -and $_.InstallLocation } | ForEach-Object { $candidates.Add($_.InstallLocation) }
    foreach ($d in $candidates) {
        $d = ($d -replace '/', '\').TrimEnd('\')
        if (Test-Path -LiteralPath (Join-Path $d 'Anno1602.exe')) { return $d }
    }
    $null
}
if ($GamePath) { $GameFolder = $GamePath.TrimEnd('\') }
else { $found = Find-GameFolder; if ($found) { $GameFolder = $found } }
if (-not (Test-Path -LiteralPath (Join-Path $GameFolder 'Anno1602.exe'))) {
    throw (Txt "Anno 1602 History Edition not found (searched in: $GameFolder). Install the game via Ubisoft Connect or give the folder with -GamePath." "Anno 1602 History Edition nicht gefunden (gesucht in: $GameFolder). Spiel ueber Ubisoft Connect installieren oder den Ordner mit -GamePath angeben.")
}
$ExpectedHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'

# RVA = address in memory relative to the load address of the exe (Ghidra address minus 0x140000000).
# Each code site is "mov dword ptr [rip+rel32], imm32" (C7 05 rel32 imm32), the value starts at byte 6.
$Patches = @(
    @{ Name = (Txt 'Width         (program start)' 'Breite        (Programmstart)'); Rva = 0x0DC7E5; Original = 'C7 05 51 F6 50 00 F4 01 00 00'; Kind = 'Width' }
    @{ Name = (Txt 'Height        (program start)' 'Hoehe         (Programmstart)'); Rva = 0x0DC7EF; Original = 'C7 05 9F F6 50 00 5E 01 00 00'; Kind = 'Height' }
    @{ Name = (Txt 'Scroll range  (program start)' 'Scrollbereich (Programmstart)'); Rva = 0x0DC7F9; Original = 'C7 05 3D F0 50 00 A9 01 00 00'; Kind = 'Range' }
    @{ Name = (Txt 'Width         (new game)     ' 'Breite        (neues Spiel)  '); Rva = 0x08DC90; Original = 'C7 05 A6 E1 55 00 F4 01 00 00'; Kind = 'Width' }
    @{ Name = (Txt 'Height        (new game)     ' 'Hoehe         (neues Spiel)  '); Rva = 0x08DC9A; Original = 'C7 05 F4 E1 55 00 5E 01 00 00'; Kind = 'Height' }
    @{ Name = (Txt 'Scroll range  (new game)     ' 'Scrollbereich (neues Spiel)  '); Rva = 0x08DCA4; Original = 'C7 05 92 DB 55 00 A9 01 00 00'; Kind = 'Range' }
    @{ Name = (Txt '1/Width       (new game)     ' '1/Breite      (neues Spiel)  '); Rva = 0x08DCAE; Original = 'C7 05 C4 DF 55 00 6F 12 03 3B'; Kind = 'InvWidth' }
    @{ Name = (Txt '1/Height      (new game)     ' '1/Hoehe       (neues Spiel)  '); Rva = 0x08DCB8; Original = 'C7 05 BE DF 55 00 E7 3E 3B 3B'; Kind = 'InvHeight' }
)
# The variables in .data. At program start the game sets 1/Width and 1/Height from constants
# in .rdata (not as an immediate), so the variables are set directly after the start.
$Variables = @(
    @{ Name = (Txt 'Width        ' 'Breite       '); Rva = 0x5EBE40; Kind = 'Width' }
    @{ Name = (Txt 'Height       ' 'Hoehe        '); Rva = 0x5EBE98; Kind = 'Height' }
    @{ Name = (Txt 'Scroll range ' 'Scrollbereich'); Rva = 0x5EB840; Kind = 'Range' }
    @{ Name = (Txt '1/Width      ' '1/Breite     '); Rva = 0x5EBC7C; Kind = 'InvWidth' }
    @{ Name = (Txt '1/Height     ' '1/Hoehe      '); Rva = 0x5EBC80; Kind = 'InvHeight' }
)
# The game sets this variable last of the five at start (FUN_1400dbc60, RVA 0xDC812).
$RvaStartDone = 0x5EBC80

function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
function Bytes([string]$hex) { [byte[]]($hex -split ' ' | ForEach-Object { [Convert]::ToByte($_, 16) }) }
function Get-SizeValues([int]$w, [int]$h) {
    @{
        Width     = [BitConverter]::GetBytes([int32]$w)
        Height    = [BitConverter]::GetBytes([int32]$h)
        Range     = [BitConverter]::GetBytes([int32]([math]::Floor($w / 2) + [math]::Floor($h / 2)))
        InvWidth  = [BitConverter]::GetBytes([single](1.0 / $w))
        InvHeight = [BitConverter]::GetBytes([single](1.0 / $h))
    }
}
function Format-Value([string]$kind, [byte[]]$b) {
    if ($kind -like 'Inv*') { '1/{0:0.##}' -f (1.0 / [BitConverter]::ToSingle($b, 0)) } else { [BitConverter]::ToInt32($b, 0) }
}

if (-not [Environment]::Is64BitProcess) { throw (Txt 'Please use the 64-bit PowerShell.' 'Bitte die 64-Bit-PowerShell verwenden.') }

# Self-test: at 500 x 350 the formulas must give exactly the original bytes.
$orig = Get-SizeValues 500 350
foreach ($s in $Patches) {
    if ((Hex $orig[$s.Kind]) -ne (Hex (Bytes $s.Original)[6..9])) { throw (Txt "Internal error: formula for $($s.Kind) does not match the original." "Interner Fehler: Formel fuer $($s.Kind) passt nicht zum Original.") }
}
$values = Get-SizeValues $Width $Height
foreach ($s in $Patches) { $s.Target = [byte[]]((Bytes $s.Original)[0..5] + $values[$s.Kind]) }

# --- Island spread -------------------------------------------------------------------------------
# Derivation: docs\FINDINGS.md, sections "Distributing islands" and "More islands".
# Jump in the SZENE loader (RVA 0xD0E29, R15 = section data) to a code cave in the free end
# of .text (RVA 0xE5100). The code cave looks up the template in a table (RVA 0xE5200,
# recognised by island count and position of the first island) and then copies the island
# list computed by the tool into it. Unknown templates: positions are only stretched (x*Width/500,
# y*Height/350). Savegames have no SZENE section and stay untouched.
# The table needs at most 4 + 3 x 816 = 2452 bytes (three endless layouts); from 0xE5BA0: fertility code
# cave and markers, from 0xE5C00: resources, from 0xE5F80: pirates.
$CaveRva = 0xE5100; $TableRva = 0xE5200; $TableMax = 0xE5BA0 - 0xE5200
$HookRva = 0xD0E29; $HookContinue = 0xD0E30
# At most 50 islands (SZENE section, island table 0x14062DDC0 and grid FUN_14009ce30 have
# 50 slots). Density: extra islands per area as in the template x 0.7 (until 2026-11-11: 0.6 and 48).
$IslandMax = 50; $IslandDensity = 0.7
$ClassW = @(30, 40, 50, 70, 100); $ClassH = @(30, 40, 52, 60, 90)   # .rdata 0xEA1E0 / 0xEA1C0

function Rel32([long]$target, [long]$end) { [BitConverter]::GetBytes([int32]($target - $end)) }

# Big campaign maps: an own scenario can carry more versions behind the normal SZENE section
# (1172 bytes, used without the tool). Each version is 1188 bytes: 'GROS', width, height it was
# designed for, version (16 bytes), then a complete SZENE block (1172 bytes); the first one starts at
# +0x494. Since 3.1 a scenario may carry several, sorted by size (1000 x 700, then the giant world
# 2000 x 1400). Without the tool the loader only reads the fixed offsets of the first block (checked in
# the game). The code cave at RVA 0xE5E40 walks the versions (RCX = section header, +0x10 length) and
# takes the LAST one with the marker whose designed size the current map reaches (so the biggest that
# fits); it copies that block to the front and stretches its positions to the current map size
# (x*Width/designed width). eax = 1: done, otherwise 0 (normal path; then only eax and edx have changed,
# rsi and rdi are restored). A file with a single version behaves as before 3.1.
$BigMapCaveRva = 0xE5E40; $BigMapMarker = 0x534F5247   # 'GROS'
function Build-BigMapCode {
    $c = New-Object System.Collections.Generic.List[byte]
    $label = @{}; $fixups = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$target) $c.Add($op); $fixups.Add(@($c.Count, $target)); $c.Add(0) }
    $Rip = { param([byte[]]$op, [long]$targetRva) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($BigMapCaveRva + $c.Count + 4))) { $c.Add($x) } }
    & $E 0x56, 0x57                                              # push rsi / push rdi
    & $E 0x8B, 0x51, 0x10                                        # mov edx,[rcx+0x10]   section length
    & $E 0x81, 0xEA, 0x94, 0x04, 0x00, 0x00                      # sub edx,1172         bytes behind the normal block
    & $E 0x49, 0x8D, 0xB7, 0x94, 0x04, 0x00, 0x00                # lea rsi,[r15+0x494]  first version
    & $E 0x31, 0xFF                                              # xor edi,edi          none chosen yet
    $label.search = $c.Count
    & $E 0x81, 0xFA, 0xA4, 0x04, 0x00, 0x00                      # cmp edx,1188
    & $J8 0x7C 'pick'                                            # jl pick              no complete version left
    & $E 0x81, 0x3E; & $E ([BitConverter]::GetBytes([int32]$BigMapMarker))   # cmp dword [rsi],'GROS'
    & $J8 0x75 'pick'                                            # jne pick
    & $E 0x83, 0x7E, 0x04, 0x64                                  # cmp dword [rsi+4],100
    & $J8 0x7C 'next'                                            # jl next
    & $E 0x83, 0x7E, 0x08, 0x64                                  # cmp dword [rsi+8],100
    & $J8 0x7C 'next'                                            # jl next
    & $Rip ([byte[]](0x8B, 0x05)) 0x5EBE40                       # mov eax,[Width]
    & $E 0x3B, 0x46, 0x04                                        # cmp eax,[rsi+4]
    & $J8 0x7C 'next'                                            # jl next              map narrower than designed
    & $Rip ([byte[]](0x8B, 0x05)) 0x5EBE98                       # mov eax,[Height]
    & $E 0x3B, 0x46, 0x08                                        # cmp eax,[rsi+8]
    & $J8 0x7C 'next'                                            # jl next
    & $E 0x48, 0x89, 0xF7                                        # mov rdi,rsi          fits: remember it
    $label.next = $c.Count
    & $E 0x48, 0x81, 0xC6, 0xA4, 0x04, 0x00, 0x00                # add rsi,1188
    & $E 0x81, 0xEA, 0xA4, 0x04, 0x00, 0x00                      # sub edx,1188
    & $J8 0xEB 'search'                                          # jmp search
    $label.pick = $c.Count
    & $E 0x31, 0xC0                                              # xor eax,eax
    & $E 0x48, 0x85, 0xFF                                        # test rdi,rdi
    & $J8 0x74 'exit'                                            # jz exit              normal path
    & $E 0x49, 0x89, 0xF9                                        # mov r9,rdi           header of the chosen version
    & $E 0x48, 0x8D, 0x77, 0x10                                  # lea rsi,[rdi+0x10]
    & $E 0x4C, 0x89, 0xFF                                        # mov rdi,r15
    & $E 0xB9, 0x94, 0x04, 0x00, 0x00                            # mov ecx,1172
    & $E 0xF3, 0xA4                                              # rep movsb
    & $E 0x45, 0x8B, 0x47, 0x64                                  # mov r8d,[r15+0x64]   island count
    & $E 0x41, 0x83, 0xF8, 0x32                                  # cmp r8d,50
    & $J8 0x77 'done'                                            # ja done
    & $E 0x49, 0x8D, 0xB7, 0x74, 0x01, 0x00, 0x00                # lea rsi,[r15+0x174]
    $label.loop = $c.Count
    & $E 0x45, 0x85, 0xC0                                        # test r8d,r8d
    & $J8 0x7E 'done'                                            # jle done
    & $E 0x8B, 0x46, 0x08                                        # mov eax,[rsi+8]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE40                 # imul eax,[Width]
    & $E 0x99, 0x41, 0xF7, 0x79, 0x04                            # cdq / idiv dword [r9+4]
    & $E 0x89, 0x46, 0x08                                        # mov [rsi+8],eax
    & $E 0x8B, 0x46, 0x0C                                        # mov eax,[rsi+0xc]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE98                 # imul eax,[Height]
    & $E 0x99, 0x41, 0xF7, 0x79, 0x08                            # cdq / idiv dword [r9+8]
    & $E 0x89, 0x46, 0x0C                                        # mov [rsi+0xc],eax
    & $E 0x48, 0x83, 0xC6, 0x10                                  # add rsi,16
    & $E 0x41, 0xFF, 0xC8                                        # dec r8d
    & $J8 0xEB 'loop'                                            # jmp loop
    $label.done = $c.Count
    & $E 0xB8, 0x01, 0x00, 0x00, 0x00                            # mov eax,1
    $label.exit = $c.Count
    & $E 0x5F, 0x5E, 0xC3                                        # pop rdi / pop rsi / ret
    foreach ($f in $fixups) {
        $d = $label[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw (Txt "Internal error: jump to $($f[1]) too far." "Interner Fehler: Sprung zu $($f[1]) zu weit.") }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($BigMapCaveRva + $c.Count -gt 0xE5F70) { throw (Txt 'Internal error: big map code cave too long.' 'Interner Fehler: Grosskarten-Codestueck zu lang.') }
    , $c.ToArray()
}

# Small assembler with jump labels for the code cave. With $withResources it calls the resource
# code cave after copying the island list (call; the registers are already saved then). With
# $withBigMap it first calls the big map code cave (eax = 1: already done).
function Build-IslandCode([bool]$withResources = $false, [bool]$withBigMap = $false, [bool]$withHomeFlag = $false) {
    $c = New-Object System.Collections.Generic.List[byte]
    $label = @{}; $fixups = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$target) $c.Add($op); $fixups.Add(@($c.Count, $target, 8)); $c.Add(0) }
    $J32 = { param([byte[]]$op, [string]$target) foreach ($x in $op) { $c.Add($x) }; $fixups.Add(@($c.Count, $target, 32)); 1..4 | ForEach-Object { $c.Add(0) } }
    $Rip = { param([byte[]]$op, [long]$targetRva) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($CaveRva + $c.Count + 4))) { $c.Add($x) } }
    & $E 0x50, 0x51, 0x52, 0x41, 0x50, 0x41, 0x51, 0x56, 0x57   # push rax,rcx,rdx,r8,r9,rsi,rdi
    if ($withBigMap) {
        & $Rip ([byte[]](0xE8)) $BigMapCaveRva                   # call big map code cave (rcx = section header)
        & $E 0x85, 0xC0                                          # test eax,eax
        & $J32 ([byte[]](0x0F, 0x85)) 'finish'                   # jnz finish
    }
    & $E 0x45, 0x8B, 0x47, 0x64                                  # mov r8d,[r15+0x64]   island count
    & $E 0x41, 0x83, 0xF8, 0x32                                  # cmp r8d,50
    & $J32 ([byte[]](0x0F, 0x87)) 'finish'                       # ja finish
    & $Rip ([byte[]](0x4C, 0x8D, 0x0D)) $TableRva                # lea r9,[table]
    & $E 0x41, 0x8B, 0x09                                        # mov ecx,[r9]         number of entries
    & $E 0x49, 0x83, 0xC1, 0x04                                  # add r9,4
    $label.search = $c.Count
    & $E 0x85, 0xC9                                              # test ecx,ecx
    & $J8 0x7E 'stretch'                                         # jle stretch
    & $E 0x45, 0x3B, 0x01                                        # cmp r8d,[r9]
    & $J8 0x75 'next'                                            # jne next
    & $E 0x41, 0x8B, 0x87, 0x7C, 0x01, 0x00, 0x00                # mov eax,[r15+0x17c]  x of the 1st island
    & $E 0x41, 0x3B, 0x41, 0x04                                  # cmp eax,[r9+4]
    & $J8 0x75 'next'
    & $E 0x41, 0x8B, 0x87, 0x80, 0x01, 0x00, 0x00                # mov eax,[r15+0x180]  y of the 1st island
    & $E 0x41, 0x3B, 0x41, 0x08                                  # cmp eax,[r9+8]
    & $J8 0x75 'next'
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]     new island count
    & $E 0x41, 0x89, 0x47, 0x64                                  # mov [r15+0x64],eax
    & $E 0x49, 0x8D, 0x71, 0x10                                  # lea rsi,[r9+0x10]
    & $E 0x49, 0x8D, 0xBF, 0x74, 0x01, 0x00, 0x00                # lea rdi,[r15+0x174]
    & $E 0xB9, 0x20, 0x03, 0x00, 0x00                            # mov ecx,800
    & $E 0xF3, 0xA4                                              # rep movsb
    if ($withHomeFlag) {                                         # mov byte [home flag],1 (an endless template: move the human's ship)
        $c.Add(0xC6); $c.Add(0x05); foreach ($x in (Rel32 $HomeFlagRva ($CaveRva + $c.Count + 5))) { $c.Add($x) }; $c.Add(1)
    }
    if ($withResources) { & $Rip ([byte[]](0xE8)) $ResourceCaveRva }   # call resource code cave
    & $J8 0xEB 'finish'                                          # jmp finish
    $label.next = $c.Count
    & $E 0x49, 0x81, 0xC1, 0x30, 0x03, 0x00, 0x00                # add r9,816
    & $E 0xFF, 0xC9                                              # dec ecx
    & $J8 0xEB 'search'                                          # jmp search
    $label.stretch = $c.Count
    & $E 0x4D, 0x8D, 0x8F, 0x74, 0x01, 0x00, 0x00                # lea r9,[r15+0x174]
    $label.loop = $c.Count
    & $E 0x45, 0x85, 0xC0                                        # test r8d,r8d
    & $J8 0x7E 'finish'                                          # jle finish
    & $E 0x41, 0x8B, 0x41, 0x08                                  # mov eax,[r9+8]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE40                 # imul eax,[Width]
    & $E 0x99, 0xB9, 0xF4, 0x01, 0x00, 0x00, 0xF7, 0xF9          # cdq / mov ecx,500 / idiv ecx
    & $E 0x41, 0x89, 0x41, 0x08                                  # mov [r9+8],eax
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE98                 # imul eax,[Height]
    & $E 0x99, 0xB9, 0x5E, 0x01, 0x00, 0x00, 0xF7, 0xF9          # cdq / mov ecx,350 / idiv ecx
    & $E 0x41, 0x89, 0x41, 0x0C                                  # mov [r9+0xc],eax
    & $E 0x49, 0x83, 0xC1, 0x10                                  # add r9,16
    & $E 0x41, 0xFF, 0xC8                                        # dec r8d
    & $J8 0xEB 'loop'                                            # jmp loop
    $label.finish = $c.Count
    & $E 0x5F, 0x5E, 0x41, 0x59, 0x41, 0x58, 0x5A, 0x59, 0x58   # pop rdi,rsi,r9,r8,rdx,rcx,rax
    & $Rip ([byte[]](0x4C, 0x8D, 0x1D)) 0                        # lea r11,[image base]  (replaced instruction)
    & $Rip ([byte[]](0xE9)) $HookContinue                        # jmp back
    foreach ($f in $fixups) {
        $pos = $f[0]; $target = $label[$f[1]]
        if ($f[2] -eq 8) {
            $d = $target - ($pos + 1); if ($d -lt -128 -or $d -gt 127) { throw (Txt "Internal error: jump to $($f[1]) too far." "Interner Fehler: Sprung zu $($f[1]) zu weit.") }
            $c[$pos] = [byte]($d -band 0xFF)
        }
        else { $b4 = [BitConverter]::GetBytes([int32]($target - ($pos + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$pos + $i] = $b4[$i] } }
    }
    if ($CaveRva + $c.Count -gt $TableRva) { throw (Txt 'Internal error: code cave too long.' 'Interner Fehler: Codestueck zu lang.') }
    , $c.ToArray()
}

# --- Resources -------------------------------------------------------------------------------------
# Derivation: docs\FINDINGS.md, section "Resources".
# From +0x94 the SZENE section holds entries of 8 bytes (house no. 16 bits, amount 16 bits, int):
# ore 2401 (+0x96, +0x9E), gold 2405 (+0xA6), 12 plantation fertilities (+0xB6 ... +0x10E),
# treasure 533 (+0x116). The amounts are meant for the 17-20 template islands. The code cave is
# called after the island list was copied (r8d = old, [r15+0x64] = new island count) and sets
# each amount to min(new island count, amount x new / old x percent / 100). The loader FUN_1400d0de0
# only hands out fertility while matching islands are free, and ore at most 2 per island;
# whatever finds no place is dropped.
# Natives: in the same code cave. SZENE +0x40 / +0x44 = number of native villages in the north /
# south (template 2 / 2). The loader picks that many islands whose island file has a village site
# (table 0x1400F94E4-0x1400F98A3: 240 files of the classes lit to big, no "lar") and loads them
# from NORDNAT/SUEDNAT. Each village takes one of the 75 settlement slots (FUN_14009a9f0, 0x140622DC0).
$ResourceCaveRva = 0xE5C00; $ResourceCaveEnd = 0xE5D00   # from 0xE5D00: F8 accelerator cave (3.5), from 0xE5E00: pirates and traders
$ResourceOffsets = @(0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE, 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE, 0x106, 0x10E, 0x116)
# Fertility everywhere: the 12 fertility entries from +0xB4 (house no. 16 bits, amount 16 bits, int) get the
# amount 50 (where a house no. is set), SZENE +0x60 (most fertilities per island, template 2) the marker
# 'FERT'. The loader passes +0x60 as the limit to FUN_1400d0ce0 (candidate islands for a crop); the hook
# there skips the climate check of the crop when the limit is 'FERT'. All other calls (limit 1, 2, 3 or the
# +0x60 of other scenarios) run unchanged.
$FertMagic = 0x54524546; $FertAmount = 50   # 'FERT'
$FertCaveRva = 0xE5BA0; $FertHookRva = 0xD0D56; $FertAcceptRva = 0xD0D8A; $FertJumpTableRva = 0xD0DC4
$CostMarkerRva = 0xE5BC0; $UpkeepMarkerRva = 0xE5BC8   # markers of build cost and upkeep (8 bytes each, up to 0xE5BD0)
$FertHookOrig = '48 63 C9 41 8B 94 8F C4 0D 0D 00 49 03 D7 FF E2'
function Add-FertilityBlock($c) {
    foreach ($x in 0x49, 0x8D, 0xB7, 0xB4, 0x00, 0x00, 0x00) { $c.Add($x) }                    # lea rsi,[r15+0xB4]
    foreach ($x in 0xB9, 0x0C, 0x00, 0x00, 0x00) { $c.Add($x) }                                # mov ecx,12
    foreach ($x in 0x66, 0x83, 0x3E, 0x00) { $c.Add($x) }                                      # loop: cmp word [rsi],0
    foreach ($x in 0x74, 0x06) { $c.Add($x) }                                                  # je skip
    foreach ($x in 0x66, 0xC7, 0x46, 0x02) { $c.Add($x) }; foreach ($x in [BitConverter]::GetBytes([uint16]$FertAmount)) { $c.Add($x) }   # mov word [rsi+2],50
    foreach ($x in 0x48, 0x83, 0xC6, 0x08) { $c.Add($x) }                                      # skip: add rsi,8
    foreach ($x in 0xFF, 0xC9) { $c.Add($x) }                                                  # dec ecx
    foreach ($x in 0x75, 0xEC) { $c.Add($x) }                                                  # jnz loop
    foreach ($x in 0x41, 0xC7, 0x47, 0x60) { $c.Add($x) }; foreach ($x in [BitConverter]::GetBytes([int32]$FertMagic)) { $c.Add($x) }   # mov dword [r15+0x60],'FERT'
}
function Build-ResourceCode([int]$percent, [int]$villages = 0, [bool]$fertility = $false) {
    $c = New-Object System.Collections.Generic.List[byte]
    $label = @{}; $fixups = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$target) $c.Add($op); $fixups.Add(@($c.Count, $target)); $c.Add(0) }
    if ($percent -le 0) {
        if ($villages -gt 0) {
            & $E 0x41, 0xC7, 0x47, 0x40; & $E ([BitConverter]::GetBytes([int32]$villages))   # mov dword [r15+0x40],villages
            & $E 0x41, 0xC7, 0x47, 0x44; & $E ([BitConverter]::GetBytes([int32]$villages))   # mov dword [r15+0x44],villages
        }
        if ($fertility) { Add-FertilityBlock $c }
        & $E 0xC3                                                                          # ret
        return , $c.ToArray()
    }
    & $E 0x48, 0x8D, 0x35; $listFix = $c.Count; & $E 0, 0, 0, 0       # lea rsi,[list]
    & $E 0x45, 0x8B, 0x4F, 0x64                                       # mov r9d,[r15+0x64]   new island count
    $label.nextItem = $c.Count
    & $E 0x0F, 0xB7, 0x0E                                             # movzx ecx,word [rsi]  offset
    & $E 0x85, 0xC9                                                   # test ecx,ecx
    & $J8 0x74 'listEnd'                                              # jz listEnd
    & $E 0x41, 0x0F, 0xB7, 0x04, 0x0F                                 # movzx eax,word [r15+rcx]  amount
    & $E 0x41, 0x0F, 0xAF, 0xC1                                       # imul eax,r9d
    & $E 0x69, 0xC0; & $E ([BitConverter]::GetBytes([int32]$percent)) # imul eax,eax,percent
    & $E 0x44, 0x89, 0xC7                                             # mov edi,r8d          old island count
    & $E 0x6B, 0xFF, 0x64                                             # imul edi,edi,100
    & $E 0x85, 0xFF                                                   # test edi,edi
    & $J8 0x74 'skip'                                                 # jz skip
    & $E 0x99, 0xF7, 0xFF                                             # cdq / idiv edi
    & $E 0x44, 0x39, 0xC8                                             # cmp eax,r9d
    & $E 0x7E, 0x03                                                   # jle +3
    & $E 0x44, 0x89, 0xC8                                             # mov eax,r9d           at most the new island count
    & $E 0x66, 0x41, 0x89, 0x04, 0x0F                                 # mov [r15+rcx],ax
    $label.skip = $c.Count
    & $E 0x48, 0x83, 0xC6, 0x02                                       # add rsi,2
    & $J8 0xEB 'nextItem'                                             # jmp nextItem
    $label.listEnd = $c.Count
    if ($villages -gt 0) {
        & $E 0x41, 0xC7, 0x47, 0x40; & $E ([BitConverter]::GetBytes([int32]$villages))   # mov dword [r15+0x40],villages
        & $E 0x41, 0xC7, 0x47, 0x44; & $E ([BitConverter]::GetBytes([int32]$villages))   # mov dword [r15+0x44],villages
    }
    if ($fertility) { Add-FertilityBlock $c }                         # after the scaling: fertility amounts 50
    & $E 0xC3                                                         # ret
    $list = $c.Count
    foreach ($o in $ResourceOffsets) { & $E ([BitConverter]::GetBytes([uint16]$o)) }
    & $E 0, 0
    $b4 = [BitConverter]::GetBytes([int32]($list - ($listFix + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$listFix + $i] = $b4[$i] }
    foreach ($f in $fixups) {
        $d = $label[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw (Txt "Internal error: jump to $($f[1]) too far." "Interner Fehler: Sprung zu $($f[1]) zu weit.") }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($ResourceCaveRva + $c.Count -gt $ResourceCaveEnd) { throw (Txt 'Internal error: resource code cave too long.' 'Interner Fehler: Rohstoff-Codestueck zu lang.') }
    , $c.ToArray()
}
$ResourcePercent = @{ Normal = 0; More = 100; Lots = 200 }[$Resources]
$Villages = @{ Default = 0; More = 4; Lots = 7 }[$Natives]   # per climate zone (template 2)
$FertilityAll = $Fertility -eq 'Everywhere'
# FUN_1400d0ce0(crop, class min, class max, limit, out): after the checks island present, flag +0x44 bit 2,
# class, count +0x47 < limit, crop bit +0x5C not yet set and crop 0x2E-0x33, it branches through a jump table
# (RVA 0xD0DC4) by crop to the climate check (+0x1C: 0x2E/0x30/0x32 only climate 0, 0x30 and 0x32 not
# together, 0x2F/0x31/0x33 only climate 1). The hook replaces the dispatch (RVA 0xD0D56, 16 bytes,
# r15 = load address) by a jump to this code cave: limit 'FERT' -> take the island (RVA 0xD0D8A),
# otherwise the original dispatch.
function Build-FertilityCode {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x41, 0x81, 0xF9) { $c.Add($x) }; foreach ($x in [BitConverter]::GetBytes([int32]$FertMagic)) { $c.Add($x) }   # cmp r9d,'FERT'
    foreach ($x in 0x74, 0x10) { $c.Add($x) }                                                  # je accept
    foreach ($x in 0x48, 0x63, 0xC9) { $c.Add($x) }                                            # movsxd rcx,ecx
    foreach ($x in 0x41, 0x8B, 0x94, 0x8F) { $c.Add($x) }; foreach ($x in [BitConverter]::GetBytes([int32]$FertJumpTableRva)) { $c.Add($x) }   # mov edx,[r15+rcx*4+0xD0DC4]
    foreach ($x in 0x49, 0x03, 0xD7) { $c.Add($x) }                                            # add rdx,r15
    foreach ($x in 0xFF, 0xE2) { $c.Add($x) }                                                  # jmp rdx
    $c.Add(0xE9); foreach ($x in (Rel32 $FertAcceptRva ($FertCaveRva + $c.Count + 4))) { $c.Add($x) }   # accept: jmp 0xD0D8A
    if ($FertCaveRva + $c.Count -gt $CostMarkerRva) { throw (Txt 'Internal error: fertility code cave too long.' 'Interner Fehler: Fruchtbarkeits-Codestueck zu lang.') }
    , $c.ToArray()
}

# Reads the island list (entries of 16 bytes) from the SZENE section of a template.
function Read-Template([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $d = [IO.File]::ReadAllBytes($path); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0) { break }
        if ($name -eq 'SZENE' -and $len -ge 0x174 + 50 * 16) {
            $s = $o + 20; $n = [BitConverter]::ToInt32($d, $s + 0x64)
            if ($n -lt 1 -or $n -gt 50) { return $null }
            return , @(for ($i = 0; $i -lt $n; $i++) { , [byte[]]$d[($s + 0x174 + 16 * $i)..($s + 0x174 + 16 * $i + 15)] })
        }
        $o += 20 + $len
    }
    $null
}

# Start positions of the ships (SHIP4: entries of 0x1B4 bytes, x/y as int16 at +0x1C/+0x1E, owner +0x4B).
# The ships are not stretched; the island planner keeps these spots free. Each: x, y, owner.
function Read-Ships([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return , @() }
    $d = [IO.File]::ReadAllBytes($path); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0) { break }
        if ($name -eq 'SHIP4') { return , @(for ($i = 0; $i -lt [math]::Floor($len / 0x1B4); $i++) { $e = $o + 20 + $i * 0x1B4; , @([BitConverter]::ToInt16($d, $e + 0x1C), [BitConverter]::ToInt16($d, $e + 0x1E), [int]$d[$e + 0x4B]) }) }
        $o += 20 + $len
    }
    , @()
}

# Plans the islands for a template: originals stretched, plus copies in free gaps.
# Result: list of 16-byte entries (climate, class, flags, slot, file, -, x, y).
# $size: Normal = classes of the template; Large = originals one class larger (where there is room),
# copies alternately "lar" (100 x 90) and "big" (70 x 60); Huge = originals and copies "lar",
# "big" where that does not fit. Changed originals get a random island file (0xFFFF).
# $ships: start points of the ships (x, y); enlarged and new islands keep a gap of 2 tiles.
# (At 1000 x 700 and 2000 x 1400 this does not change the plans; at 750 x 525 Large/Huge
# start ships were otherwise inside an island.)
# Giant (3.4): originals as with Large; then the giant islands of the island forge (file numbers 20+ of the class
# "lar", sizes in $GiantDims, each one once, at most $GiantMaxPerMap), then copies alternately "lar" and "big".
# Giant islands count towards the limit of "lar" islands per map.
function Get-IslandPlan($template, [int]$mapW, [int]$mapH, [bool]$stretchOnly, [string]$size = 'Normal', $ships = @()) {
    $shipFree = { param([int]$x, [int]$y, [int]$w, [int]$hh) foreach ($sp in $ships) { if ($sp[0] -ge $x - 2 -and $sp[0] -lt $x + $w + 2 -and $sp[1] -ge $y - 2 -and $sp[1] -lt $y + $hh + 2) { return $false } }; $true }
    $giantDims = if ($script:GiantDims) { $script:GiantDims } else { @{} }
    $giantMax = if ($script:GiantMaxPerMap) { $script:GiantMaxPerMap } else { 6 }
    # Width and height of a plan entry: the giant island of its file number, otherwise its class.
    $homeInfo = $script:HomeInfo
    $dimW = { param($p) $n = [int][BitConverter]::ToUInt16($p, 4); if ($p[1] -eq 4 -and $homeInfo -and $n -eq $HomeFileNumber) { $homeInfo.W } elseif ($p[1] -eq 4 -and $giantDims.ContainsKey($n)) { $giantDims[$n][0] } else { $ClassW[$p[1]] } }
    $dimH = { param($p) $n = [int][BitConverter]::ToUInt16($p, 4); if ($p[1] -eq 4 -and $homeInfo -and $n -eq $HomeFileNumber) { $homeInfo.H } elseif ($p[1] -eq 4 -and $giantDims.ContainsKey($n)) { $giantDims[$n][1] } else { $ClassH[$p[1]] } }
    $giant = ($size -eq 'Giant')
    if ($giant) { $size = 'Large' }
    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($e in $template) {
        $n = [byte[]]$e.Clone()
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Truncate([BitConverter]::ToInt32($e, 8) * $mapW / 500)), 0, $n, 8, 4)
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Truncate([BitConverter]::ToInt32($e, 12) * $mapH / 350)), 0, $n, 12, 4)
        $plan.Add($n)
    }
    $goal = [math]::Min($IslandMax, [math]::Max($template.Count, [math]::Floor($template.Count * ($mapW * $mapH) / (500 * 350) * $IslandDensity)))
    if ($stretchOnly) { $goal = $template.Count }
    $gap = 14; $margin = 8
    # Home island (3.6): all four start ships of the endless templates lie within 10 tiles of each other, so the island
    # does not go there (the rivals would settle it at once): it goes to the place (grid of 10 tiles inside the map) that
    # lies farthest from the start ships (counted up to 600 tiles) and covers the fewest originals (each counts 120
    # tiles), as a northern island (climate 0, class lar, its file); originals it covers give way. The human's ship is
    # moved to the ship place of the island on the side facing the start ships (see the SHIP4 code cave):
    # HomePlaced = island x, y, side, ship x, y and the template's start of the human ship.
    $script:HomePlaced = $null
    $human = @($ships | Where-Object { $_.Count -ge 3 -and $_[2] -eq 0 }) | Select-Object -First 1
    if ($homeInfo -and $human -and -not $stretchOnly) {
        $sx = 0.0; $sy = 0.0; foreach ($s in $ships) { $sx += $s[0]; $sy += $s[1] }; $sx /= $ships.Count; $sy /= $ships.Count
        $best = $null; $bestScore = [double]::MinValue
        $rects = @(foreach ($p in $plan) { , @([BitConverter]::ToInt32($p, 8), [BitConverter]::ToInt32($p, 12), (& $dimW $p), (& $dimH $p)) })
        $hw = $homeInfo.W; $hh0 = $homeInfo.H
        for ($hx = $margin; $hx + $hw -le $mapW - $margin; $hx += 10) {
            for ($hy = $margin; $hy + $hh0 -le $mapH - $margin; $hy += 10) {
                $free = $true
                foreach ($s in $ships) { if ($s[0] -ge $hx - 2 -and $s[0] -lt $hx + $hw + 2 -and $s[1] -ge $hy - 2 -and $s[1] -lt $hy + $hh0 + 2) { $free = $false; break } }
                if (-not $free) { continue }
                $cx = $hx + $hw / 2 - $sx; $cy = $hy + $hh0 / 2 - $sy
                $score = [math]::Min(600.0, [math]::Sqrt($cx * $cx + $cy * $cy))
                foreach ($r in $rects) { if ($hx -lt $r[0] + $r[2] + $gap -and $r[0] -lt $hx + $hw + $gap -and $hy -lt $r[1] + $r[3] + $gap -and $r[1] -lt $hy + $hh0 + $gap) { $score -= 120 } }
                if ($score -gt $bestScore) { $bestScore = $score; $best = @($hx, $hy) }
            }
        }
        if ($best) {
            $hx = $best[0]; $hy = $best[1]
            # The ship place on the side that faces the start ships (the nearest one to them).
            $hb = $homeInfo.Harbours | Sort-Object { $dx = $hx + $_[1] - $sx; $dy = $hy + $_[2] - $sy; $dx * $dx + $dy * $dy } | Select-Object -First 1
            $kept = New-Object System.Collections.Generic.List[object]
            foreach ($p in $plan) {
                $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12)
                if (-not ($hx -lt $px + (& $dimW $p) + $gap -and $px -lt $hx + $homeInfo.W + $gap -and $hy -lt $py + (& $dimH $p) + $gap -and $py -lt $hy + $homeInfo.H + $gap)) { $kept.Add($p) }
            }
            $e = New-Object byte[] 16
            $e[0] = 0; $e[1] = 4; $e[2] = 0; $e[3] = 0
            [Array]::Copy([BitConverter]::GetBytes([uint16]$HomeFileNumber), 0, $e, 4, 2)
            [Array]::Copy([BitConverter]::GetBytes([int32]$hx), 0, $e, 8, 4); [Array]::Copy([BitConverter]::GetBytes([int32]$hy), 0, $e, 12, 4)
            $kept.Insert(0, $e)
            $script:HomePlaced = @{ X = $hx; Y = $hy; Side = $hb[0]; ShipX = $hx + $hb[1]; ShipY = $hy + $hb[2]; FromX = [int]$human[0]; FromY = [int]$human[1]; Removed = $plan.Count - ($kept.Count - 1) }
            $plan = $kept
        }
    }
    # There are only 6 (NORD) or 7 (SUED) island files of the class "lar", none in NORDNAT/SUEDNAT.
    # In the game (2026-11-11) only 15 of 23 planned "lar" islands were loaded, the rest was missing.
    # Hence at most $LarMax of them per map, otherwise "big" (68 + 64 files).
    $LarMax = 10
    $lar = @($plan | Where-Object { $_[1] -eq 4 }).Count
    # With giant islands the originals leave their places among the "lar" islands to them.
    $larCap = if ($giant) { $LarMax - [math]::Min($giantMax, $giantDims.Count) } else { $LarMax }
    if ($size -ne 'Normal' -and -not $stretchOnly) {
        for ($i = 0; $i -lt $plan.Count; $i++) {
            $e = $plan[$i]; $k0 = [int]$e[1]
            $wanted = if ($size -eq 'Huge') { @(4, 3) } else { @([math]::Min(4, $k0 + 1)) }
            foreach ($k in $wanted) {
                if ($k -le $k0) { continue }
                if ($k -eq 4 -and $lar -ge $larCap) { continue }
                $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12)
                if ($x + $ClassW[$k] -gt $mapW - $margin -or $y + $ClassH[$k] -gt $mapH - $margin) { continue }
                $free = & $shipFree $x $y $ClassW[$k] $ClassH[$k]
                for ($j = 0; $j -lt $plan.Count -and $free; $j++) {
                    if ($j -eq $i) { continue }
                    $p = $plan[$j]; $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12)
                    if ($x -lt $px + (& $dimW $p) + $gap -and $px -lt $x + $ClassW[$k] + $gap -and $y -lt $py + (& $dimH $p) + $gap -and $py -lt $y + $ClassH[$k] + $gap) { $free = $false }
                }
                if ($free) { $e[1] = [byte]$k; $e[4] = 0xFF; $e[5] = 0xFF; if ($k -eq 4) { $lar++ }; break }
            }
        }
    }
    $classSeq = switch ($size) { 'Large' { @(4, 3) } 'Huge' { @(4, 4, 4, 3) } default { $null } }
    $script:rng = [long](($template.Count * 7919 + [BitConverter]::ToInt32($template[0], 8) * 31 + [BitConverter]::ToInt32($template[0], 12)) % 2147483648)
    # Giant islands first (the largest first), each file once, at random free places (2000 tries each).
    if ($giant -and -not $stretchOnly) {
        $placedGiants = 0
        foreach ($n in @($giantDims.Keys | Sort-Object { - $giantDims[$_][0] * $giantDims[$_][1] }, { $_ })) {
            if ($placedGiants -ge $giantMax -or $lar -ge $LarMax -or $plan.Count -ge $goal) { break }
            $w = $giantDims[$n][0]; $hh = $giantDims[$n][1]
            if ($mapW - 2 * $margin - $w -le 0 -or $mapH - 2 * $margin - $hh -le 0) { continue }
            for ($t = 0; $t -lt 2000; $t++) {
                $script:rng = ($script:rng * 1103515245 + 12345) % 2147483648; $x = $margin + [int]($script:rng % ($mapW - 2 * $margin - $w))
                $script:rng = ($script:rng * 1103515245 + 12345) % 2147483648; $y = $margin + [int]($script:rng % ($mapH - 2 * $margin - $hh))
                $free = & $shipFree $x $y $w $hh
                foreach ($p in $plan) {
                    $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12)
                    if ($x -lt $px + (& $dimW $p) + $gap -and $px -lt $x + $w + $gap -and $y -lt $py + (& $dimH $p) + $gap -and $py -lt $y + $hh + $gap) { $free = $false; break }
                }
                if ($free) {
                    $e = New-Object byte[] 16
                    $e[0] = 2; $e[1] = 4; $e[2] = 0; $e[3] = [byte]$plan.Count
                    [Array]::Copy([BitConverter]::GetBytes([uint16]$n), 0, $e, 4, 2)
                    [Array]::Copy([BitConverter]::GetBytes([int32]$x), 0, $e, 8, 4); [Array]::Copy([BitConverter]::GetBytes([int32]$y), 0, $e, 12, 4)
                    $plan.Add($e); $lar++; $placedGiants++; break
                }
            }
        }
    }
    $sources = @($template | Sort-Object { - $_[1] }, { $_[3] })
    $qi = 0; $failures = 0
    while ($plan.Count -lt $goal -and $failures -lt $sources.Count) {
        $q = $sources[$qi % $sources.Count]
        $k = if ($classSeq) { $classSeq[$qi % $classSeq.Count] } else { $q[1] }
        if ($k -eq 4 -and $lar -ge $LarMax) { $k = 3 }
        $qi++
        $w = $ClassW[$k]; $hh = $ClassH[$k]
        $placed = $false
        for ($t = 0; $t -lt 800 -and -not $placed; $t++) {
            $script:rng = ($script:rng * 1103515245 + 12345) % 2147483648; $x = $margin + [int]($script:rng % ($mapW - 2 * $margin - $w))
            $script:rng = ($script:rng * 1103515245 + 12345) % 2147483648; $y = $margin + [int]($script:rng % ($mapH - 2 * $margin - $hh))
            $free = & $shipFree $x $y $w $hh
            foreach ($p in $plan) {
                $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12); $pw = & $dimW $p; $ph = & $dimH $p
                if ($x -lt $px + $pw + $gap -and $px -lt $x + $w + $gap -and $y -lt $py + $ph + $gap -and $py -lt $y + $hh + $gap) { $free = $false; break }
            }
            if ($free) {
                $n = New-Object byte[] 16
                $n[0] = 2; $n[1] = $k; $n[2] = 0; $n[3] = [byte]$plan.Count; $n[4] = 0xFF; $n[5] = 0xFF
                [Array]::Copy([BitConverter]::GetBytes([int32]$x), 0, $n, 8, 4); [Array]::Copy([BitConverter]::GetBytes([int32]$y), 0, $n, 12, 4)
                $plan.Add($n); $placed = $true; if ($k -eq 4) { $lar++ }
            }
        }
        if ($placed) { $failures = 0 } else { $failures++ }
    }
    for ($i = 0; $i -lt $plan.Count; $i++) { $plan[$i][3] = [byte]$i }   # slot = index
    , $plan.ToArray()
}

# Table: int32 number of entries, then per entry: island count, x0, y0 of the template, new island count, 50 x 16 bytes.
function Build-IslandTable([int]$mapW, [int]$mapH, [bool]$stretchOnly, [string]$size = 'Normal') {
    $t = New-Object System.Collections.Generic.List[byte]
    $count = 0; $script:IslandPlans = @{}; $script:HomeAt = @{}
    if (-not $stretchOnly) {
        foreach ($layout in 0, 1, 2) {
            $tpl = Read-Template (Join-Path $GameFolder "Szenes\[[48]]0$layout.szs")
            if (-not $tpl) { continue }
            $plan = Get-IslandPlan $tpl $mapW $mapH $false $size (Read-Ships (Join-Path $GameFolder "Szenes\[[48]]1$layout.szs"))
            $script:IslandPlans[$layout] = $plan; $script:HomeAt[$layout] = $script:HomePlaced
            foreach ($x in [BitConverter]::GetBytes([int32]$tpl.Count)) { $t.Add($x) }
            foreach ($x in $tpl[0][8..15]) { $t.Add($x) }
            foreach ($x in [BitConverter]::GetBytes([int32]$plan.Count)) { $t.Add($x) }
            for ($i = 0; $i -lt 50; $i++) { if ($i -lt $plan.Count) { foreach ($x in $plan[$i]) { $t.Add($x) } } else { 1..16 | ForEach-Object { $t.Add(0) } } }
            $count++
        }
    }
    $head = [BitConverter]::GetBytes([int32]$count)
    $all = [byte[]]($head + $t.ToArray())
    if ($all.Length -gt $TableMax) { throw (Txt 'Internal error: island table too large.' 'Interner Fehler: Inseltabelle zu gross.') }
    , $all
}

# --- Island forge (-Rivers, -Mountains, -Volcanoes, -IslandSize Giant) -----------------------------
# Derivation: docs\FINDINGS.md, section "Island forge". src\island-forge.cs writes changed copies of the game's
# island files (rivers -> meadow, inland mountains -> coast, the volcano mark of Nord\big25 removed) and the giant
# islands Nord|Sued\lar20 ... lar27 into %LOCALAPPDATA%\Anno1602-Extensions\islands\<hash>-<options>\, once per
# version and set of options (reused afterwards, other sets deleted). Both island loaders of the game (the SZENE
# loader FUN_1400d0de0 and the INSEL3/4/5 loader FUN_14009bdd0, which reads the island under a village file and the
# ground of savegame islands) first try the same relative path ("Nord\lar20.SCP") below a second folder (normally
# Loca\<language>\, which holds no island files) and fall back to the game folder. Five LEA instructions that load that
# folder point to our folder instead; its path (ANSI, at most 255 bytes) lies in the free end of .pdata (RVA 0x91B200,
# readable, in memory only). Island files that are not in our folder still come from the game folder; savegames
# contain their islands completely and do not depend on the folder.
$GiantPerClimate = 8; $GiantMaxPerMap = 6
$IslandForgeUsed = ($Rivers -eq 'Off' -or $Mountains -eq 'Edge' -or $Volcanoes -eq 'Off' -or $IslandSize -eq 'Giant' -or $HomeIsland -eq 'Perfect')
$GiantDims = @{}   # giant file number -> @(width, height), only numbers that exist for both climates
# Home island (3.6): Nord\lar28 of the forge; $HomeInfo = width, height, ship places per side (side, x, y) and the four
# ore mountains (x, y), read from the built file. The planner (Get-IslandPlan) and the tool window use it.
$HomeFileNumber = 28; $HomeInfo = $null
# The human's start ship goes to the home island: the island code cave sets a flag (RVA 0xE5D30) when it copies a plan
# into an endless template; the ship loader FUN_14008e4f0 (chunk SHIP4, entries of 0x1B4 bytes: x/y int16 at +0x1C,
# owner +0x4B; the ship's figure is created at that place) starts with "push rbx / push rsi / sub rsp,0x68" (7 bytes,
# RVA 0x8E4F0), which jumps to a code cave (RVA 0xE5D50): if the flag is set and the chunk is "SHIP4", it clears the flag
# and gives the entry of owner 0 whose place is the template's start of one of the three layouts (table RVA 0xE5D38: 3 x
# from x|y<<16, to x|y<<16) the ship place of the home island; then the three instructions and back. Savegames (no SZENE,
# flag clear) and scenarios (other places) are not touched.
$HomeFlagRva = 0xE5D30; $HomeShipTableRva = 0xE5D38; $HomeShipCaveRva = 0xE5D50; $ShipLoaderRva = 0x8E4F0; $ShipLoaderOrig = '40 53 56 48 83 EC 68'
function Build-HomeShipCode {
    $c = New-Object System.Collections.Generic.List[byte]
    $label = @{}; $fixups = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$target) $c.Add($op); $fixups.Add(@($c.Count, $target)); $c.Add(0) }
    $RipImm = { param([byte[]]$op, [long]$targetRva, [byte[]]$imm) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($HomeShipCaveRva + $c.Count + 4 + $imm.Length))) { $c.Add($x) }; foreach ($x in $imm) { $c.Add($x) } }
    & $RipImm ([byte[]](0x80, 0x3D)) $HomeFlagRva ([byte[]]@(0))       # cmp byte [flag],0
    & $J8 0x74 'orig'                                                  # je orig
    & $E 0x81, 0x39, 0x53, 0x48, 0x49, 0x50                            # cmp dword [rcx],'SHIP'
    & $J8 0x75 'orig'
    & $E 0x80, 0x79, 0x04, 0x34                                        # cmp byte [rcx+4],'4'
    & $J8 0x75 'orig'
    & $RipImm ([byte[]](0xC6, 0x05)) $HomeFlagRva ([byte[]]@(0))       # mov byte [flag],0
    & $E 0x4C, 0x8B, 0xCA                                              # mov r9,rdx (first entry)
    & $E 0x44, 0x89, 0xC0                                              # mov eax,r8d (length)
    $label.loop = $c.Count
    & $E 0x3D, 0xB4, 0x01, 0x00, 0x00                                  # cmp eax,0x1B4
    & $J8 0x72 'orig'                                                  # jb orig
    & $E 0x41, 0x80, 0x79, 0x4B, 0x00                                  # cmp byte [r9+0x4B],0 (owner)
    & $J8 0x75 'next'
    & $E 0x45, 0x8B, 0x51, 0x1C                                        # mov r10d,[r9+0x1C] (x | y<<16)
    & $RipImm ([byte[]](0x4C, 0x8D, 0x1D)) $HomeShipTableRva ([byte[]]@())   # lea r11,[table]
    & $E 0x45, 0x3B, 0x13; & $J8 0x74 'hit0'                           # cmp r10d,[r11] / je
    & $E 0x45, 0x3B, 0x53, 0x08; & $J8 0x74 'hit1'                     # cmp r10d,[r11+8] / je
    & $E 0x45, 0x3B, 0x53, 0x10; & $J8 0x74 'hit2'                     # cmp r10d,[r11+16] / je
    & $J8 0xEB 'next'
    $label.hit2 = $c.Count; & $E 0x49, 0x83, 0xC3, 0x08                # add r11,8
    $label.hit1 = $c.Count; & $E 0x49, 0x83, 0xC3, 0x08                # add r11,8
    $label.hit0 = $c.Count
    & $E 0x45, 0x8B, 0x53, 0x04                                        # mov r10d,[r11+4]
    & $E 0x45, 0x89, 0x51, 0x1C                                        # mov [r9+0x1C],r10d
    $label.next = $c.Count
    & $E 0x49, 0x81, 0xC1, 0xB4, 0x01, 0x00, 0x00                      # add r9,0x1B4
    & $E 0x2D, 0xB4, 0x01, 0x00, 0x00                                  # sub eax,0x1B4
    & $J8 0xEB 'loop'
    $label.orig = $c.Count
    & $E (Bytes $ShipLoaderOrig)                                       # push rbx / push rsi / sub rsp,0x68
    $c.Add(0xE9); foreach ($x in (Rel32 ($ShipLoaderRva + 7) ($HomeShipCaveRva + $c.Count + 4))) { $c.Add($x) }   # jmp back
    foreach ($f in $fixups) {
        $d = $label[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw (Txt "Internal error: jump to $($f[1]) too far." "Interner Fehler: Sprung zu $($f[1]) zu weit.") }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($HomeShipCaveRva + $c.Count -gt 0xE5E00) { throw (Txt 'Internal error: home ship code cave too long.' 'Interner Fehler: Heimatschiff-Codestueck zu lang.') }
    , $c.ToArray()
}
# Table for the code cave: per layout 0-2 the template's start of the human ship and its place at the home island.
function Build-HomeShipTable($homeAt) {
    $t = New-Object byte[] 24
    foreach ($lay in 0, 1, 2) {
        $hp = $homeAt[$lay]
        $from = if ($hp) { [uint32](($hp.FromX -band 0xFFFF) -bor (($hp.FromY -band 0xFFFF) -shl 16)) } else { [uint32]::MaxValue }
        $to = if ($hp) { [uint32](($hp.ShipX -band 0xFFFF) -bor (($hp.ShipY -band 0xFFFF) -shl 16)) } else { [uint32]0 }
        [Array]::Copy([BitConverter]::GetBytes($from), 0, $t, $lay * 8, 4); [Array]::Copy([BitConverter]::GetBytes($to), 0, $t, $lay * 8 + 4, 4)
    }
    , $t
}
$IslandPathRva = 0x91B200; $IslandPathMax = 0x100
$IslandPathSites = @(
    @{ Rva = 0xD13B2; Original = '4C 8D 05 E7 41 4F 00' }   # SZENE loader: lea r8 (source of strncpy_s)
    @{ Rva = 0xD13CF; Original = '48 8D 0D CA 41 4F 00' }   # SZENE loader: lea rcx (its length)
    @{ Rva = 0x9C01A; Original = '4C 8D 2D 7F 95 52 00' }   # INSEL4/5 loader: lea r13 (first island)
    @{ Rva = 0x9C381; Original = '4C 8D 2D 18 92 52 00' }   # INSEL4/5 loader: lea r13 (next island)
    @{ Rva = 0x9C42B; Original = '4C 8D 2D 6E 91 52 00' }   # INSEL3 loader: lea r13
)
function Get-IslandFolder {
    $root = Join-Path $env:LOCALAPPDATA 'Anno1602-Extensions\islands'
    $forge = Join-Path $PSScriptRoot 'island-forge.cs'
    if (-not (Test-Path -LiteralPath $forge)) { throw (Txt "island-forge.cs is missing next to the tool ($forge)." "island-forge.cs fehlt neben dem Werkzeug ($forge).") }
    $giants = if ($IslandSize -eq 'Giant') { $GiantPerClimate } else { 0 }
    $hash = (Get-FileHash -LiteralPath $forge -Algorithm SHA256).Hash.Substring(0, 8).ToLower()
    $sig = '{0}-r{1}-m{2}-v{3}-g{4}-h{5}' -f $hash, [int]($Rivers -eq 'Off'), [int]($Mountains -eq 'Edge'), [int]($Volcanoes -eq 'Off'), $giants, [int]($HomeIsland -eq 'Perfect')
    $dir = Join-Path $root $sig
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'forge.log'))) {
        Write-Host (Txt 'Island forge: building the islands for these options (once) ...' 'Inselschmiede: baue die Inseln fuer diese Optionen (einmalig) ...')
        if (-not ('AnnoIslands.Forge' -as [type])) { Add-Type -Path $forge -ReferencedAssemblies System.Core }
        $tmp = "$dir.tmp$PID"
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        $o = New-Object AnnoIslands.Options
        $o.NoRivers = ($Rivers -eq 'Off'); $o.EdgeMountains = ($Mountains -eq 'Edge'); $o.NoVolcano = ($Volcanoes -eq 'Off'); $o.GiantPerClimate = $giants
        $o.HomeIsland = ($HomeIsland -eq 'Perfect')
        $log = [AnnoIslands.Forge]::Build($GameFolder, $tmp, $o)
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $log | Set-Content -LiteralPath (Join-Path $tmp 'forge.log') -Encoding UTF8
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Move-Item -LiteralPath $tmp -Destination $dir
    }
    # Folders of other options or older versions are no longer needed.
    foreach ($old in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $sig })) {
        try { Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction Stop } catch { }
    }
    $dir
}
# Home island: size, ship places and ore mountains from the built file (island-forge.cs, Home.Harbours / Home.OreSpots).
function Get-HomeInfo([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    if (-not ('AnnoIslands.Home' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'island-forge.cs') -ReferencedAssemblies System.Core }
    if ([AnnoIslands.Houses]::All.Count -eq 0) { [AnnoIslands.Houses]::Load((Join-Path $GameFolder 'haeuser.cod')) }
    $f = [AnnoIslands.Island]::Load($path)
    $ore = @([AnnoIslands.Home]::OreSpots($f) | ForEach-Object { , @([int]$_[0], [int]$_[1]) })
    $harbours = @([AnnoIslands.Home]::Harbours($f) | ForEach-Object { , @([int]$_[0], [int]$_[1], [int]$_[2]) })
    if ($ore.Count -ne 4 -or $harbours.Count -eq 0) { return $null }
    @{ W = $f.W; H = $f.H; Harbours = $harbours; Ore = $ore }
}
# Size of a giant island from its file header (INSEL5: width +1, height +2 of the chunk data).
function Get-IslandFileSize([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $b = [IO.File]::ReadAllBytes($path)
    if ($b.Length -lt 23 -or [Text.Encoding]::ASCII.GetString($b, 0, 5) -ne 'INSEL') { return $null }
    , @([int]$b[21], [int]$b[22])
}
if ($IslandForgeUsed) {
    # -CheckOnly writes nothing: the sites are checked with the path of the folder, which is not built.
    if ($CheckOnly) { $IslandFolder = Join-Path $env:LOCALAPPDATA 'Anno1602-Extensions\islands\check'; $summary = @('SUMMARY (not built with -CheckOnly)') }
    else {
        $IslandFolder = Get-IslandFolder
        $summary = @(Get-Content -LiteralPath (Join-Path $IslandFolder 'forge.log') | Where-Object { $_ -match '^SUMMARY' })
    }
    for ($n = 20; $n -lt 20 + $GiantPerClimate; $n++) {
        $a = Get-IslandFileSize (Join-Path $IslandFolder "Nord\lar$n.scp"); $b = Get-IslandFileSize (Join-Path $IslandFolder "Sued\lar$n.scp")
        if ($a -and $b -and $a[0] -eq $b[0] -and $a[1] -eq $b[1]) { $GiantDims[$n] = $a }
    }
    if ($HomeIsland -eq 'Perfect' -and -not $CheckOnly) { $HomeInfo = Get-HomeInfo (Join-Path $IslandFolder "Nord\lar$HomeFileNumber.scp") }
    # Path of the folder for the game (ANSI; if a character cannot be written so, the short 8.3 name).
    $islandPath = $IslandFolder.TrimEnd('\') + '\'
    $ansi = [Text.Encoding]::Default
    if (-not $CheckOnly -and $ansi.GetString($ansi.GetBytes($islandPath)) -ne $islandPath) {
        try { $islandPath = (New-Object -ComObject Scripting.FileSystemObject).GetFolder($IslandFolder).ShortPath.TrimEnd('\') + '\' } catch { }
    }
    $pathBytes = [byte[]]($ansi.GetBytes($islandPath) + [byte]0)
    if ($pathBytes.Length -gt $IslandPathMax -or (-not $CheckOnly -and $ansi.GetString($ansi.GetBytes($islandPath)) -ne $islandPath)) {
        throw (Txt "The folder of the island forge cannot be handed to the game ($islandPath)." "Der Ordner der Inselschmiede kann dem Spiel nicht uebergeben werden ($islandPath).")
    }
    # Order: first the path, then the five loaders (rollback in reverse order).
    $Patches += @{ Name = (Txt 'Island forge (folder)       ' 'Inselschmiede (Ordner)      '); Rva = $IslandPathRva; Original = ((@('00') * $pathBytes.Length) -join ' '); Target = $pathBytes; MemoryOnly = $true }
    foreach ($s in $IslandPathSites) {
        $Patches += @{ Name = (Txt 'Island forge (loader)       ' 'Inselschmiede (Lader)       '); Rva = $s.Rva; Original = $s.Original; Target = [byte[]]((Bytes $s.Original)[0..2] + (Rel32 $IslandPathRva ($s.Rva + 7))) }
    }
    $parts = @()
    if ($Rivers -eq 'Off') { $parts += (Txt 'no rivers' 'keine Fluesse') }
    if ($Mountains -eq 'Edge') { $parts += (Txt 'mountains at the coast' 'Berge am Rand') }
    if ($Volcanoes -eq 'Off') { $parts += (Txt 'no volcano' 'kein Vulkan') }
    if ($IslandSize -eq 'Giant') { $parts += ((Txt '{0} giant islands' '{0} Riesen-Inseln') -f $GiantDims.Count) }
    if ($HomeIsland -eq 'Perfect') { $parts += $(if ($HomeInfo -or $CheckOnly) { (Txt 'perfect home island' 'perfekte Heimatinsel') } else { (Txt 'home island MISSING' 'Heimatinsel FEHLT') }) }
    Write-Host ((Txt 'Island forge: {0} ({1})' 'Inselschmiede: {0} ({1})') -f ($parts -join ', '), (($summary -join ' ') -replace '^SUMMARY ', ''))
    if ($IslandSize -eq 'Giant' -and $GiantDims.Count -eq 0 -and -not $CheckOnly) { Write-Host (Txt 'Island forge: no giant island could be built; the map uses the largest islands of the game instead.' 'Inselschmiede: keine Riesen-Insel gebaut; die Karte nimmt stattdessen die groessten Inseln des Spiels.') -ForegroundColor Yellow }
}

if (-not $NoIslandSpread) {
    $withResources = ($ResourcePercent -gt 0 -or $Villages -gt 0 -or $FertilityAll) -and -not $StretchOnly
    $withBigMap = -not $StretchOnly
    $withHome = [bool]$HomeInfo -and -not $StretchOnly
    $IslandCode = Build-IslandCode $withResources $withBigMap $withHome
    if ($withBigMap) {
        $BigMapCode = Build-BigMapCode
        $Patches += @{ Name = (Txt 'Big campaign maps           ' 'Grosse Kampagnenkarten      '); Rva = $BigMapCaveRva; Original = ((@('00') * $BigMapCode.Length) -join ' '); Target = $BigMapCode; MemoryOnly = $true }
    }
    $IslandTable = Build-IslandTable $Width $Height $StretchOnly.IsPresent $IslandSize
    $Hook = [byte[]](@(0xE9) + (Rel32 $CaveRva ($HookRva + 5)) + @(0x66, 0x90))
    # Order matters: first the table and the code caves, then the jump (rollback in reverse).
    $Patches += @{ Name = (Txt 'Island spread (table)       ' 'Inselverteilung (Tabelle)   '); Rva = $TableRva; Original = ((@('00') * $IslandTable.Length) -join ' '); Target = $IslandTable; MemoryOnly = $true }
    if ($withHome) {
        # Order: flag, table, code cave, then the jump of the ship loader (the flag byte stays 0 until a new endless game).
        # The game's own code writes the flag, and the free end of .text is read-only for the game (found in the game test:
        # the island code cave crashed the game at "Spiel starten"), so its page stays writable.
        $HomeShipTable = Build-HomeShipTable $script:HomeAt
        $HomeShipCode = Build-HomeShipCode
        $Patches += @{ Name = (Txt 'Home island ship (flag)     ' 'Heimatinsel Schiff (Merker) '); Rva = $HomeFlagRva; Original = '00'; Target = [byte[]]@(0); MemoryOnly = $true; Writable = $true }
        $Patches += @{ Name = (Txt 'Home island ship (table)    ' 'Heimatinsel Schiff (Tabelle)'); Rva = $HomeShipTableRva; Original = ((@('00') * 24) -join ' '); Target = $HomeShipTable; MemoryOnly = $true }
        $Patches += @{ Name = (Txt 'Home island ship (code cave)' 'Heimatinsel Schiff (Code)   '); Rva = $HomeShipCaveRva; Original = ((@('00') * $HomeShipCode.Length) -join ' '); Target = $HomeShipCode; MemoryOnly = $true }
        $Patches += @{ Name = (Txt 'Home island ship (jump)     ' 'Heimatinsel Schiff (Sprung) '); Rva = $ShipLoaderRva; Original = $ShipLoaderOrig; Target = [byte[]](@(0xE9) + (Rel32 $HomeShipCaveRva ($ShipLoaderRva + 5)) + @(0x90, 0x90)) }
    }
    if ($withResources) {
        $ResourceCode = Build-ResourceCode $ResourcePercent $Villages $FertilityAll
        $Patches += @{ Name = (Txt 'Resources (code cave)       ' 'Rohstoffe (Codestueck)      '); Rva = $ResourceCaveRva; Original = ((@('00') * $ResourceCode.Length) -join ' '); Target = $ResourceCode; MemoryOnly = $true }
        if ($ResourcePercent -gt 0) { Write-Host ((Txt 'Resources: {0} (ore, gold, fertility and treasures with the island count x {1} %, at most 1 per island)' 'Rohstoffe: {0} (Erz, Gold, Fruchtbarkeit und Schaetze mit der Inselzahl x {1} %, hoechstens 1 je Insel)') -f (Get-ValueName $Resources), $ResourcePercent) }
        if ($Villages -gt 0) { Write-Host ((Txt 'Natives: {0} ({1} villages per climate zone instead of 2)' 'Ureinwohner: {0} ({1} Doerfer je Klimazone statt 2)') -f (Get-ValueName $Natives), $Villages) }
        if ($FertilityAll) {
            # Order: first the code cave, then the jump into it.
            $FertilityCode = Build-FertilityCode
            $Patches += @{ Name = (Txt 'Fertility (code cave)       ' 'Fruchtbarkeit (Codestueck)  '); Rva = $FertCaveRva; Original = ((@('00') * $FertilityCode.Length) -join ' '); Target = $FertilityCode; MemoryOnly = $true }
            $Patches += @{ Name = (Txt 'Fertility (jump)            ' 'Fruchtbarkeit (Sprung)      '); Rva = $FertHookRva; Original = $FertHookOrig; Target = [byte[]](@(0xE9) + (Rel32 $FertCaveRva ($FertHookRva + 5)) + @(0x90) * 11) }
            Write-Host ((Txt 'Fertility: {0} (every island with fertile land grows all six crops in new endless games)' 'Fruchtbarkeit: {0} (jede Insel mit fruchtbarem Land traegt in neuen Endlosspielen alle sechs Pflanzen)') -f (Get-ValueName $Fertility))
        }
    }
    else {
        if ($ResourcePercent -gt 0 -or $Villages -gt 0) { Write-Host (Txt 'Resources/natives: only work with additional islands (not with -StretchOnly); NOT set.' 'Rohstoffe/Ureinwohner: wirken nur mit zusaetzlichen Inseln (nicht mit -StretchOnly); NICHT gesetzt.') -ForegroundColor Yellow }
        if ($FertilityAll) { Write-Host (Txt 'Fertility: only works with additional islands (not with -StretchOnly); NOT set.' 'Fruchtbarkeit: wirkt nur mit zusaetzlichen Inseln (nicht mit -StretchOnly); NICHT gesetzt.') -ForegroundColor Yellow }
    }
    if ($IslandSize -ne 'Normal') { Write-Host (Txt "Island size: $IslandSize" "Inselgroesse: $(Get-ValueName $IslandSize)") }
    $Patches += @{ Name = (Txt 'Island spread (code cave)   ' 'Inselverteilung (Codestueck)'); Rva = $CaveRva; Original = ((@('00') * $IslandCode.Length) -join ' '); Target = $IslandCode }
    $Patches += @{ Name = (Txt 'Island spread (jump)        ' 'Inselverteilung (Sprung)    '); Rva = $HookRva; Original = '4C 8D 1D D0 F1 F2 FF'; Target = $Hook }
    foreach ($a in ($script:IslandPlans.Keys | Sort-Object)) {
        $homeNote = ''
        if ($HomeInfo) {
            $hp = $script:HomeAt[$a]
            $homeNote = if ($hp) { (Txt ', home island at the start ship ({0} side)' ', Heimatinsel beim Start-Schiff ({0})') -f @(@((Txt 'west' 'Westseite'), (Txt 'north' 'Nordseite'), (Txt 'east' 'Ostseite'), (Txt 'south' 'Suedseite'))[$hp.Side]) } else { (Txt ', home island: no room at the start ship' ', Heimatinsel: kein Platz beim Start-Schiff') }
        }
        Write-Host ((Txt 'Island plan layout {0}: {1} islands{2}' 'Inselplan Anordnung {0}: {1} Inseln{2}') -f $a, $script:IslandPlans[$a].Count, $homeNote)
    }
}
elseif ($FertilityAll) { Write-Host (Txt 'Fertility: only works with the island spread (not with -NoIslandSpread); NOT set.' 'Fruchtbarkeit: wirkt nur mit der Inselverteilung (nicht mit -NoIslandSpread); NICHT gesetzt.') -ForegroundColor Yellow }

# --- Pirates -------------------------------------------------------------------------------------
# Derivation: docs\FINDINGS.md, section "Rivals and pirates".
# The pirates (player kind 0xE) only act in FUN_14003dc40 when bit 0 of the game variable
# 0x1405ec188 is clear (set on Easy/Average = "occasional sightings").
# The value comes from the TIMERS section when a template or a savegame is loaded
# (FUN_1400c2da0). At the end of this loader (RVA 0xC3232, only on the path "section recognised")
# a hook jumps to a code cave (RVA 0xE5F80): replaced instruction, set/clear the bit, back.
# Strong: FUN_14003b7e0 equips pirate ships depending on the difficulty with (n+1)/2, n+2 or 2n+4
# cannons, at most the maximum of the ship type. RVA 0x3B94B: "mov esi,256; jmp" -> always the maximum.
# Start gold: in the same code cave. New game = game clock 0x1405ec0f8 (from TIMERS +0xA0) below 1000
# (templates 10-24, savegames > 20'000; the clock runs about 10 per second). Then the gold
# of the player in slot 0 (player table 0x1405f0960, gold +4) is set. PLAYER4 (start gold of the
# template) is loaded before TIMERS, so the template's value gets overwritten.
# Mission time limit: the game ends a mission as lost when the int 0x1405ec1a8 is not 0 and the clock reaches it
# (FUN_1400af980; while it is set the screen shows the elapsed time mm:ss), but nothing in the History Edition
# sets it: command 0x36 (new game, loading) clears it, no scenario or savegame section carries it. Own scenarios
# put the deadline (clock units, 36,000 per displayed hour) into AUFTRAG4 +0x58, which the loader copies to the
# mission table +0x20 (0x1405ec740 + slot x 0x108C) and the saver writes back; the game never reads it. The same
# code cave copies it at the end of every TIMERS load (scenarios and savegames load AUFTRAG4 before TIMERS, and
# command 0x36 runs before both): if the local player (0x1405f1d60, 0-3) has a mission (goal bits +0 not 0), the
# deadline +0x20 goes to 0x1405ec1a8. Original scenarios have 0 there, so nothing changes for them. Only volatile
# registers (rcx, rdx) are used: the loader returns right after the hook (rax = its result stays untouched).
$PirateCaveRva = 0xE5F80; $TimersHookRva = 0xC3232; $TimersContinue = 0xC3239
$FlagsRva = 0x5EC188; $TimersMovapsTarget = 0x5BE5F0; $ClockRva = 0x5EC0F8; $Gold0Rva = 0x5F0964
$PlayerSize = 0x280   # player table: 7 slots of 640 bytes (FUN_1400a87f0); 1-3 = computer rivals
$TimeLimitRva = 0x5EC1A8; $MissionRva = 0x5EC720; $MissionSize = 0x108C; $LocalPlayerRva = 0x5F1D60
$CannonRva = 0x3B94B; $CannonOrig = '8B 05 6F 08 5B 00 83'; $CannonTarget = 'BE 00 01 00 00 EB 3B'
function Build-PirateCode([string]$mode, [int]$gold = 0, [int]$rivalGold = 0, [bool]$timeLimit = $true) {
    $c = New-Object System.Collections.Generic.List[byte]
    # RIP-relative: rel32 refers to the end of the instruction (after a possible immediate $after).
    $Rip = { param([byte[]]$op, [long]$targetRva, [byte[]]$after) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($PirateCaveRva + $c.Count + 4 + $after.Length))) { $c.Add($x) }; foreach ($x in $after) { $c.Add($x) } }
    & $Rip ([byte[]](0x0F, 0x29, 0x05)) $TimersMovapsTarget ([byte[]]@())      # movaps [0x1405be5f0],xmm0 (replaced instruction)
    if ($timeLimit) {
        & $Rip ([byte[]](0x8B, 0x0D)) $LocalPlayerRva ([byte[]]@())             # mov ecx,[local player]
        foreach ($x in 0x83, 0xF9, 0x03, 0x77, 30) { $c.Add($x) }                # cmp ecx,3 / ja skip (+30)
        foreach ($x in @(0x69, 0xC9) + [BitConverter]::GetBytes([int32]$MissionSize)) { $c.Add($x) }   # imul ecx,ecx,0x108C
        & $Rip ([byte[]](0x48, 0x8D, 0x15)) $MissionRva ([byte[]]@())          # lea rdx,[mission table]
        foreach ($x in 0x48, 0x01, 0xCA, 0x83, 0x3A, 0x00, 0x74, 9) { $c.Add($x) }   # add rdx,rcx / cmp dword [rdx],0 / je skip (+9)
        foreach ($x in 0x8B, 0x52, 0x20) { $c.Add($x) }                          # mov edx,[rdx+0x20]
        & $Rip ([byte[]](0x89, 0x15)) $TimeLimitRva ([byte[]]@())              # mov [time limit],edx
    }                                                                            # skip:
    if ($mode -eq 'Off') { & $Rip ([byte[]](0x83, 0x0D)) $FlagsRva ([byte[]](0x01)) }   # or  dword [0x1405ec188],1
    elseif ($mode -ne 'Default') { & $Rip ([byte[]](0x83, 0x25)) $FlagsRva ([byte[]](0xFE)) }   # and dword [0x1405ec188],~1
    if ($gold -gt 0) {
        & $Rip ([byte[]](0x81, 0x3D)) $ClockRva ([BitConverter]::GetBytes([int32]1000))   # cmp dword [game clock],1000
        $c.Add(0x73); $c.Add(10)                                                       # jae +10 (savegame: do nothing)
        & $Rip ([byte[]](0xC7, 0x05)) $Gold0Rva ([BitConverter]::GetBytes([int32]$gold))  # mov dword [gold slot 0],gold
    }
    if ($rivalGold -gt 0) {
        & $Rip ([byte[]](0x81, 0x3D)) $ClockRva ([BitConverter]::GetBytes([int32]1000))   # cmp dword [game clock],1000
        $c.Add(0x73); $c.Add(30)                                                       # jae +30 (savegame: do nothing)
        foreach ($slot in 1..3) {                                                      # mov dword [gold slot 1-3],rivalGold
            & $Rip ([byte[]](0xC7, 0x05)) ($Gold0Rva + $slot * $PlayerSize) ([BitConverter]::GetBytes([int32]$rivalGold))
        }
    }
    & $Rip ([byte[]](0xE9)) $TimersContinue ([byte[]]@())                       # jmp back (end of the loader)
    if ($PirateCaveRva + $c.Count -gt 0xE6000) { throw (Txt 'Internal error: pirate code cave too long.' 'Interner Fehler: Piraten-Codestueck zu lang.') }
    , $c.ToArray()
}
# Always installed: the mission time limit of own scenarios needs the hook even without the other options.
if ($true) {
    $PirateCode = Build-PirateCode $Pirates $StartGold $RivalGold
    $PirateHook = [byte[]](@(0xE9) + (Rel32 $PirateCaveRva ($TimersHookRva + 5)) + @(0x66, 0x90))
    # Order: first the code cave, then the jump.
    $Patches += @{ Name = (Txt 'TIMERS loader (code cave)   ' 'TIMERS-Lader (Codestueck)   '); Rva = $PirateCaveRva; Original = ((@('00') * $PirateCode.Length) -join ' '); Target = $PirateCode; MemoryOnly = $true }
    $Patches += @{ Name = (Txt 'TIMERS loader (jump)        ' 'TIMERS-Lader (Sprung)       '); Rva = $TimersHookRva; Original = '0F 29 05 B7 B3 4F 00'; Target = $PirateHook }
    if ($Pirates -eq 'Strong') {
        $Patches += @{ Name = (Txt 'Pirates (full cannons)      ' 'Piraten (volle Kanonen)     '); Rva = $CannonRva; Original = $CannonOrig; Target = (Bytes $CannonTarget) }
    }
    if ($Pirates -ne 'Default') { Write-Host (Txt "Pirates: $Pirates" "Piraten: $(Get-ValueName $Pirates)") }
    if ($StartGold -gt 0) { Write-Host ((Txt 'Start gold in new games: {0}' 'Startgeld bei neuen Spielen: {0}') -f $StartGold) }
    if ($RivalGold -gt 0) { Write-Host ((Txt 'Gold of the computer rivals in new games: {0}' 'Gold der Computergegner bei neuen Spielen: {0}') -f $RivalGold) }
}

# --- Rivals, pirate fleet, traders ---------------------------------------------------------------
# Derivation: docs\FINDINGS.md, section "Rivals, pirate fleet, natives, traders".
# Rivals Hard: the AI reads the difficulty 0x1405ec1c0 (0-3) at four sites with
# "mov eax,[rip+rel32]" (8B 05 rel32) and sets its goals with it (military compared to the
# strongest player, ships, expansion): level 3 = x2 or +50 %. Replaced by "mov eax,3; nop".
# Natural events (FUN_14009e390) and the pirates' cannons (FUN_14003b7e0) stay at the real level.
$RivalSites = @(
    @{ Name = (Txt 'AI hard (FUN_140017840)' 'KI Schwer (FUN_140017840)'); Rva = 0x17A8E; Original = '8B 05 2C 47 5D 00' }
    @{ Name = (Txt 'AI hard (FUN_140017b30)' 'KI Schwer (FUN_140017b30)'); Rva = 0x17EA1; Original = '8B 05 19 43 5D 00' }
    @{ Name = (Txt 'AI hard (FUN_140032090)' 'KI Schwer (FUN_140032090)'); Rva = 0x321C9; Original = '8B 05 F1 9F 5B 00' }
    @{ Name = (Txt 'AI hard (FUN_140035220)' 'KI Schwer (FUN_140035220)'); Rva = 0x35344; Original = '8B 05 76 6E 5B 00' }
)
if ($Rivals -eq 'Hard') {
    foreach ($g in $RivalSites) { $Patches += @{ Name = $g.Name.PadRight(28); Rva = $g.Rva; Original = $g.Original; Target = (Bytes 'B8 03 00 00 00 90') } }
    Write-Host (Txt 'Computer rivals: always as on Hard' 'Computergegner: immer wie Schwer')
}
# Rival growth Ambitious (3.4): the AI builds each town along a phase machine (dispatcher FUN_1400393e0, phase at
# city record +0x10). Two exits lead into phases that never build the next public buildings: at the end of phase
# 0x21 (FUN_1400374b0) a free island area below 951 leads to phase 0x22 (no church, no bathhouse: the town stays at
# Buerger), at the end of phase 0x29 (FUN_140037b50) below 1101 to phase 0x2C (no theatre, no college: Kaufleute).
# Both jumps become NOPs, so the main town always goes on to 0x28 and 0x32. In phase 0x28 church and bathhouse wait for
# 3 of 4 merchant goods in stock (FUN_140036100); that wait is dropped too. The goods gate before theatre and college
# (phase 0x32, 4 of 6 goods) stays, so those come only once the chains run. Secondary towns stay plantation colonies.
$RivalGrowthSites = @(
    @{ Name = (Txt 'AI growth (phase 0x21)' 'KI Ausbau (Phase 0x21)'); Rva = 0x37510; Original = '81 78 1C B6 03 00 00 7E 1C'; Target = '81 78 1C B6 03 00 00 90 90' }
    @{ Name = (Txt 'AI growth (phase 0x29)' 'KI Ausbau (Phase 0x29)'); Rva = 0x37B95; Original = '81 78 1C 4C 04 00 00 7E 43'; Target = '81 78 1C 4C 04 00 00 90 90' }
    @{ Name = (Txt 'AI growth (church, bath)' 'KI Ausbau (Kirche, Bad)'); Rva = 0x37A7A; Original = '83 F8 03 7C 1E'; Target = '83 F8 03 90 90' }
    # Measured in the game (2026-11-22): a rich AI leaves phases 0x1E (plantations), 0x20 (tavern, school, doctor) and
    # 0x21 on money alone (>= 15001 / 20001 / 25001 gold) before it has built anything there, so its towns never get the
    # public buildings of the next level. The money-only exits become jumps to the building part ("jle" -> "jmp"); the
    # town goes on when enough residents of the next level live there (170 settlers / 250 / 340 citizens).
    @{ Name = (Txt 'AI growth (build first 1E)' 'KI Ausbau (erst bauen 1E)'); Rva = 0x36FDB; Original = '81 79 04 98 3A 00 00 7E 79'; Target = '81 79 04 98 3A 00 00 EB 79' }
    @{ Name = (Txt 'AI growth (build first 20)' 'KI Ausbau (erst bauen 20)'); Rva = 0x372FB; Original = '81 78 04 20 4E 00 00 7E 5C'; Target = '81 78 04 20 4E 00 00 EB 5C' }
    @{ Name = (Txt 'AI growth (build first 21)' 'KI Ausbau (erst bauen 21)'); Rva = 0x374EE; Original = '81 F9 A8 61 00 00 7E 7D'; Target = '81 F9 A8 61 00 00 EB 7D' }
)
if ($RivalGrowth -eq 'Ambitious') {
    foreach ($g in $RivalGrowthSites) { $Patches += @{ Name = $g.Name.PadRight(28); Rva = $g.Rva; Original = $g.Original; Target = (Bytes $g.Target) } }
    Write-Host (Txt 'Rival growth: ambitious (the main towns of the rivals go on to merchants and aristocrats; this window supplies the luxury goods they do not make)' 'Gegner-Ausbau: ehrgeizig (die Hauptstaedte der Gegner wachsen weiter zu Kaufleuten und Aristokraten; dieses Fenster liefert ihnen die Luxuswaren nach, die sie nicht herstellen)')
}

# Pirate fleet: FUN_14003b7e0 (pirates only, called from FUN_14003dc40) compares the number of
# pirate ships (+0x1076c) with FUN_1400185f0 (highest civilisation level of human and AI, 0-4)
# and lets a new one appear when there are fewer ships (FUN_140070d80(3), ship table 200 slots).
# RVA 0x3B7F1 "call FUN_1400185f0" -> "call code cave" (RVA 0xE5E00): sub rsp,0x28 (shadow space
# and alignment) / call FUN_1400185f0 / add rsp,0x28 / imul eax,eax,F / ret. The wait time until the
# next ship (0x1405ebf1c x 1000, RVA 0x3B8D2 and 0x3B9CE) is divided by F.
$FleetCaveRva = 0xE5E00; $FleetCallRva = 0x3B7F1; $LevelRva = 0x185F0
$FleetFactor = @{ Normal = 1; Large = 2; Huge = 3 }[$PirateFleet]
$FleetWait = @(
    @{ Rva = 0x3B8D2; Original = '69 05 40 06 5B 00 E8 03 00 00' }
    @{ Rva = 0x3B9CE; Original = '69 05 44 05 5B 00 E8 03 00 00' }
)
function Build-FleetCode([int]$factor) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x48, 0x83, 0xEC, 0x28) { $c.Add($x) }                                          # sub rsp,0x28
    $c.Add(0xE8); foreach ($x in (Rel32 $LevelRva ($FleetCaveRva + $c.Count + 4))) { $c.Add($x) }   # call FUN_1400185f0
    foreach ($x in 0x48, 0x83, 0xC4, 0x28) { $c.Add($x) }                                          # add rsp,0x28
    foreach ($x in 0x6B, 0xC0, [byte]$factor) { $c.Add($x) }                                       # imul eax,eax,factor
    $c.Add(0xC3)                                                                                    # ret
    , $c.ToArray()
}
if ($FleetFactor -gt 1) {
    $FleetCode = Build-FleetCode $FleetFactor
    $Patches += @{ Name = (Txt 'Pirate fleet (code cave)    ' 'Piratenflotte (Codestueck)  '); Rva = $FleetCaveRva; Original = ((@('00') * $FleetCode.Length) -join ' '); Target = $FleetCode; MemoryOnly = $true }
    $Patches += @{ Name = (Txt 'Pirate fleet (call)         ' 'Piratenflotte (Aufruf)      '); Rva = $FleetCallRva; Original = 'E8 FA CD FD FF'; Target = [byte[]](@(0xE8) + (Rel32 $FleetCaveRva ($FleetCallRva + 5))) }
    foreach ($w in $FleetWait) {
        $target = Bytes $w.Original
        [Array]::Copy([BitConverter]::GetBytes([int32][math]::Floor(1000 / $FleetFactor)), 0, $target, 6, 4)
        $Patches += @{ Name = (Txt 'Pirate fleet (wait time)    ' 'Piratenflotte (Wartezeit)   '); Rva = $w.Rva; Original = $w.Original; Target = $target }
    }
    Write-Host ((Txt 'Pirate fleet: {0} ({1} times as many ships, up to {2})' 'Piratenflotte: {0} ({1}-mal so viele Schiffe, bis {2})') -f (Get-ValueName $PirateFleet), $FleetFactor, (4 * $FleetFactor))
}

# Traders: FUN_1400bc030 counts the settlements (0x1405bd228) and keeps (number + 2) / 3 free
# trader ships (counter 0x1406d7e68). RVA 0xBC140 "shr eax,31; add edx,eax" (sign correction,
# always 0 here; eax is not read afterwards) -> "call code cave" (RVA 0xE5E20):
# edx = min(edx x F, 24); ret. There are 30 trader records (0x1405a8450, FUN_14008be30 stops at
# no. 30), hence at most 24.
$TraderCaveRva = 0xE5E20; $TraderRva = 0xBC140; $TraderMax = 24
$TraderFactor = @{ Default = 1; More = 2; Lots = 3 }[$Traders]
function Build-TraderCode([int]$factor) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x6B, 0xD2, [byte]$factor) { $c.Add($x) }                 # imul edx,edx,factor
    foreach ($x in 0x83, 0xFA, [byte]$TraderMax) { $c.Add($x) }              # cmp edx,24
    foreach ($x in 0x7E, 0x05) { $c.Add($x) }                                # jle +5
    $c.Add(0xBA); foreach ($x in [BitConverter]::GetBytes([int32]$TraderMax)) { $c.Add($x) }   # mov edx,24
    $c.Add(0xC3)                                                             # ret
    , $c.ToArray()
}
if ($TraderFactor -gt 1) {
    $TraderCode = Build-TraderCode $TraderFactor
    $Patches += @{ Name = (Txt 'Traders (code cave)         ' 'Haendler (Codestueck)       '); Rva = $TraderCaveRva; Original = ((@('00') * $TraderCode.Length) -join ' '); Target = $TraderCode; MemoryOnly = $true }
    $Patches += @{ Name = (Txt 'Traders (call)              ' 'Haendler (Aufruf)           '); Rva = $TraderRva; Original = 'C1 E8 1F 03 D0'; Target = [byte[]](@(0xE8) + (Rel32 $TraderCaveRva ($TraderRva + 5))) }
    Write-Host ((Txt 'Traders: {0} ({1} times as many free trader ships, at most {2})' 'Haendler: {0} ({1}-mal so viele freie Haendlerschiffe, hoechstens {2})') -f (Get-ValueName $Traders), $TraderFactor, $TraderMax)
}

# --- Turbo ---------------------------------------------------------------------------------------
# Keyboard FUN_1400e2d60: F5/F6/F7 call FUN_1400c8be0(1/2/4) (game speed 0x1400f99f8).
# The game loop FUN_1400c8e20 computes time x factor in steps of 200; FUN_140060560 already
# knows factors from 5 on. F7 at RVA 0xE3376: "mov ecx,4" -> "mov ecx,<TurboLevel>". Measured at 8x
# (40 large islands): exactly 8.0x at about 53 % of one processor core.
if ($Turbo) {
    $Patches += @{ Name = ((Txt 'Game speed F7 ({0}x)' 'Spieltempo F7 ({0}-fach)') -f $TurboLevel).PadRight(28); Rva = 0xE3376; Original = 'B9 04 00 00 00'; Target = [byte[]](0xB9, $TurboLevel, 0, 0, 0) }
    Write-Host (Txt "Turbo: F7 = ${TurboLevel}x" "Turbo: F7 = $TurboLevel-fach")
}

# --- Ultra (F8) ----------------------------------------------------------------------------------
# The key switch of FUN_1400e2d60: "add r8d,-0x10 / cmp r8d,0x66 / ja end" (RVA 0xE2D7E, 0F 87 to RVA 0xE3380 =
# "return 0"), then a byte table of 0x67 entries. F8 (0x77) is 0x67 after the subtraction, just behind the table.
# The "ja" goes to a code cave (RVA 0xE5BE0, free bytes after the event marker): cmp r8d,0x67 / jne end /
# mov ecx,<level> / call FUN_1400c8be0 / jmp end. Same stack as in the switch cases (they call FUN_1400c8be0 too).
$UltraCaveRva = 0xE5BE0; $UltraHookRva = 0xE2D7E; $UltraHookOrig = '0F 87 FC 05 00 00'; $KeyEndRva = 0xE3380; $SetSpeedRva = 0xC8BE0
function Build-UltraCode([int]$level) {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x41, 0x83, 0xF8, 0x67) { $c.Add($x) }                                                # cmp r8d,0x67 (F8)
    foreach ($x in 0x75, 0x0A) { $c.Add($x) }                                                            # jne +10
    $c.Add(0xB9); foreach ($x in [BitConverter]::GetBytes([int32]$level)) { $c.Add($x) }                 # mov ecx,level
    $c.Add(0xE8); foreach ($x in (Rel32 $SetSpeedRva ($UltraCaveRva + $c.Count + 4))) { $c.Add($x) }     # call FUN_1400c8be0
    $c.Add(0xE9); foreach ($x in (Rel32 $KeyEndRva ($UltraCaveRva + $c.Count + 4))) { $c.Add($x) }       # jmp end (return 0)
    , $c.ToArray()
}
# F8 alone is also an accelerator of the game (resource 0x8B: F8 -> command 0x9CBA = player status, Ctrl+F8 0x9CBB,
# Shift+F8 0x9CCA; F9-F12 too): the message loop FUN_14000ec00 calls TranslateAcceleratorA (RVA 0xED11,
# "call [IAT 0xE64B8]") and does not dispatch a translated key, so the WM_KEYDOWN of F8 never reached the switch
# (measured in the game: speed stayed 1, the status page opened). That call goes to a second code cave (RVA 0xE5D00):
# WM_KEYDOWN (msg +8 = 0x100) of F8 (msg +0x10 = 0x77) without Shift/Ctrl (the game keeps them in bits 4/8 of RVA
# 0x5EBE9C, from every mouse message and the Shift/Ctrl keys) -> eax = 0 ("not translated", TranslateMessage and
# DispatchMessage follow); everything else -> jmp [IAT] (TranslateAcceleratorA with the same registers and stack).
# The player status stays on the STATUS button and Shift/Ctrl+F8.
$UltraAccelCaveRva = 0xE5D00; $UltraAccelCallRva = 0xED11; $UltraAccelCallOrig = 'FF 15 A1 77 0D 00'; $AccelIatRva = 0xE64B8; $ModifierFlagsRva = 0x5EBE9C
function Build-UltraAccelCode {
    $c = New-Object System.Collections.Generic.List[byte]
    foreach ($x in 0x41, 0x81, 0x78, 0x08, 0x00, 0x01, 0x00, 0x00) { $c.Add($x) }                     # cmp dword [r8+8],0x100 (WM_KEYDOWN)
    $c.Add(0x75); $c.Add(0); $j1 = $c.Count - 1                                                          # jne translate
    foreach ($x in 0x41, 0x83, 0x78, 0x10, 0x77) { $c.Add($x) }                                         # cmp dword [r8+0x10],0x77 (F8)
    $c.Add(0x75); $c.Add(0); $j2 = $c.Count - 1                                                          # jne translate
    $c.Add(0xF6); $c.Add(0x05); foreach ($x in (Rel32 $ModifierFlagsRva ($UltraAccelCaveRva + $c.Count + 5))) { $c.Add($x) }; $c.Add(0x0C)   # test byte [flags],0x0C (Shift/Ctrl)
    $c.Add(0x75); $c.Add(0); $j3 = $c.Count - 1                                                          # jne translate
    foreach ($x in 0x31, 0xC0, 0xC3) { $c.Add($x) }                                                     # xor eax,eax / ret
    $t = $c.Count
    foreach ($j in $j1, $j2, $j3) { $c[$j] = [byte]($t - ($j + 1)) }
    $c.Add(0xFF); $c.Add(0x25); foreach ($x in (Rel32 $AccelIatRva ($UltraAccelCaveRva + $c.Count + 4))) { $c.Add($x) }   # translate: jmp [TranslateAcceleratorA]
    , $c.ToArray()
}
if ($Ultra) {
    $UltraCode = Build-UltraCode $UltraLevel
    $UltraAccelCode = Build-UltraAccelCode
    $Patches += @{ Name = (Txt 'Ultra speed F8 (code cave)  ' 'Ultra-Tempo F8 (Codestueck) '); Rva = $UltraCaveRva; Original = ((@('00') * $UltraCode.Length) -join ' '); Target = $UltraCode; MemoryOnly = $true }
    $Patches += @{ Name = (Txt 'Ultra speed F8 (key filter) ' 'Ultra-Tempo F8 (Tastenfilter'); Rva = $UltraAccelCaveRva; Original = ((@('00') * $UltraAccelCode.Length) -join ' '); Target = $UltraAccelCode; MemoryOnly = $true }
    $Patches += @{ Name = (Txt 'Ultra speed F8 (accelerator)' 'Ultra-Tempo F8 (Kuerzel)    '); Rva = $UltraAccelCallRva; Original = $UltraAccelCallOrig; Target = [byte[]](@(0xE8) + (Rel32 $UltraAccelCaveRva ($UltraAccelCallRva + 5)) + @(0x90)) }
    $Patches += @{ Name = ((Txt 'Ultra speed F8 ({0}x)' 'Ultra-Tempo F8 ({0}-fach)') -f $UltraLevel).PadRight(28); Rva = $UltraHookRva; Original = $UltraHookOrig; Target = [byte[]](@(0x0F, 0x87) + (Rel32 $UltraCaveRva ($UltraHookRva + 6))) }
    Write-Host (Txt "Ultra: F8 = ${UltraLevel}x" "Ultra: F8 = $UltraLevel-fach")
}

# --- Mines ---------------------------------------------------------------------------------------
# FUN_1400b9ed0, case 3 (mine): the deposit (island +0x20 + i*8: ware, x, y, -, kind +4, amount +6 in
# tons x 32) loses haeuser.cod "Rohmenge" (+0x26 of the mine) per work step and disappears below 1 t
# (FUN_14009eab0). Two paths: kind 1 or more than 0xEFF (human and gold excepted below 0x500 for the AI,
# gold never) -> RVA 0xBA495 "sub r8w,[rdi+0x26]"; otherwise (only when flag 0x1405ec188 bit 3 is clear;
# the endless templates set it) -> RVA 0xBA429 "sub word [rdx+6],ax". Both become NOPs of the same length,
# the amount stays and the check "< 1 t" never fires.
$MineSites = @(
    @{ Name = (Txt 'Mines infinite (path 1)' 'Minen unendlich (Weg 1)'); Rva = 0xBA495; Original = '66 44 2B 47 26'; Target = '0F 1F 44 00 00' }
    @{ Name = (Txt 'Mines infinite (path 2)' 'Minen unendlich (Weg 2)'); Rva = 0xBA429; Original = '66 29 42 06'; Target = '0F 1F 40 00' }
)
if ($Mines -eq 'Infinite') {
    foreach ($m in $MineSites) { $Patches += @{ Name = $m.Name.PadRight(28); Rva = $m.Rva; Original = $m.Original; Target = (Bytes $m.Target) } }
    Write-Host ((Txt 'Mines: {0} (ore and gold deposits are never used up)' 'Minen: {0} (Erz- und Goldvorkommen werden nie aufgebraucht)') -f (Get-ValueName $Mines))
}

# --- Disasters -----------------------------------------------------------------------------------
# FUN_1400bc030 (economy tick per town): plague FUN_1400b7360 (towns from 200 citizens: rand % 400/250/180
# <= 12; doctor and bathhouse protect), fire by a figure FUN_1400b71f0 (from 300 merchants: rand %
# 400/250/180 <= 150; the gallows protect) and fire in small houses FUN_1400b7040 (rand % 100/150/200 <= 30,
# rand % 100/180/250 <= 15, rand & 0xFF <= 7). FUN_14009e390 (natural events per island): drought
# FUN_14009e320 (Demanding/Hard only, checked every (27-34) x 600 clock steps) and volcano FUN_1400715b0.
# Off: the five calls become 5-byte NOPs (eax is not used afterwards). More: plague and the two fire
# chances doubled (limit +1 doubled, or the divisor halved where the limit sits in eax and is reused),
# drought checks every (13-20) x 600 clock steps.
$DisasterOffSites = @(
    @{ Name = (Txt 'Disasters off (plague)' 'Katastrophen aus (Pest)'); Rva = 0xBCAC3; Original = 'E8 98 A8 FF FF' }
    @{ Name = (Txt 'Disasters off (fire 1)' 'Katastrophen aus (Feuer 1)'); Rva = 0xBCB07; Original = 'E8 E4 A6 FF FF' }
    @{ Name = (Txt 'Disasters off (fire 2)' 'Katastrophen aus (Feuer 2)'); Rva = 0xBCBBB; Original = 'E8 80 A4 FF FF' }
    @{ Name = (Txt 'Disasters off (drought)' 'Katastrophen aus (Duerre)'); Rva = 0x9E860; Original = 'E8 BB FA FF FF' }
    @{ Name = (Txt 'Disasters off (volcano)' 'Katastrophen aus (Vulkan)'); Rva = 0x9E93E; Original = 'E8 6D 2C FD FF' }
)
$DisasterMoreSites = @(
    @{ Rva = 0xBCABB; Original = '83 FA 0C'; Target = '83 FA 19' }          # plague: rand % n <= 12 -> 25
    @{ Rva = 0xBCAD8; Original = 'BB B4 00 00 00'; Target = 'BB 5A 00 00 00' }   # fire 1: divisor 180 -> 90
    @{ Rva = 0xBCAE5; Original = 'BB 90 01 00 00'; Target = 'BB C8 00 00 00' }   #         400 -> 200
    @{ Rva = 0xBCAEA; Original = 'B8 FA 00 00 00'; Target = 'B8 7D 00 00 00' }   #         250 -> 125
    @{ Rva = 0xBCB2E; Original = '83 FA 1E'; Target = '83 FA 3D' }          # fire 2: <= 30 -> 61
    @{ Rva = 0xBCB4A; Original = '83 FA 1E'; Target = '83 FA 3D' }
    @{ Rva = 0xBCB76; Original = '83 FA 0F'; Target = '83 FA 1F' }          #         <= 15 -> 31
    @{ Rva = 0xBCB94; Original = '83 FA 0F'; Target = '83 FA 1F' }
    @{ Rva = 0xBCBB3; Original = '83 F8 07'; Target = '83 F8 0F' }          #         rand & 0xFF <= 7 -> 15
    @{ Rva = 0x9E875; Original = '83 C0 1B'; Target = '83 C0 0D' }          # drought: next check (27-34) -> (13-20) x 600
)
# Each mode also checks the sites of the other mode for their original bytes (target = original), so a
# second run with the other mode in the same game process aborts instead of mixing both.
$VolcanoRva = 0x9E93E
if ($Disasters -eq 'Off') {
    foreach ($s in $DisasterOffSites) { $Patches += @{ Name = $s.Name.PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes '0F 1F 44 00 00') } }
    foreach ($s in $DisasterMoreSites) { $Patches += @{ Name = (Txt 'Disasters (check)' 'Katastrophen (Kontrolle)').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Original) } }
    Write-Host ((Txt 'Disasters: {0} (no new fire, plague, drought or volcanic eruption)' 'Katastrophen: {0} (kein neues Feuer, keine Pest, Duerre oder Vulkanausbruch)') -f (Get-ValueName $Disasters))
}
elseif ($Disasters -eq 'More') {
    foreach ($s in $DisasterMoreSites) { $Patches += @{ Name = (Txt 'Disasters more' 'Katastrophen mehr').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Target) } }
    foreach ($s in $DisasterOffSites) { if ($Volcanoes -eq 'Off' -and $s.Rva -eq $VolcanoRva) { continue }; $Patches += @{ Name = (Txt 'Disasters (check)' 'Katastrophen (Kontrolle)').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Original) } }
    Write-Host ((Txt 'Disasters: {0} (fire and plague twice as likely, droughts on Demanding/Hard twice as often)' 'Katastrophen: {0} (Feuer und Pest doppelt so wahrscheinlich, Duerre bei Fordernd/Schwer doppelt so oft)') -f (Get-ValueName $Disasters))
}
# Volcano off (3.4): no eruption (the call in FUN_14009e390 becomes a NOP, as with Disasters Off), and the island
# forge removes the volcano mark of the only volcano island (Nord\big25: count +23, volcano mountains +60..+91).
if ($Volcanoes -eq 'Off' -and $Disasters -ne 'Off') {
    $Patches += @{ Name = (Txt 'Volcano off' 'Vulkan aus').PadRight(28); Rva = $VolcanoRva; Original = 'E8 6D 2C FD FF'; Target = (Bytes '0F 1F 44 00 00') }
}

# --- Residents, cargo, production ----------------------------------------------------------------
# Residents: haeuser.cod "Maxwohn" of the population groups 0-4 (BGRUPPE), stored by the parser x 64
# as int at RVA 0x6BA02C + no. * 0x50. Houses store their residents x 64 as 16 bits (house +6);
# FUN_1400b7c60 compares with it and advances the level. All five values are multiplied by the same
# factor, so the ratios stay the same.
$ResidentRva = 0x6BA02C; $ResidentSize = 0x50
$ResidentOrig = @(128, 384, 960, 1600, 2560)   # 2/6/15/25/40 residents x 64
if ($Residents -ne 1.0) { Write-Host ((Txt 'Residents: x{0:0.##} ({1} instead of 40 per house of the highest level)' 'Einwohner: x{0:0.##} ({1} statt 40 je Haus der hoechsten Stufe)') -f $Residents, [int][math]::Round(40 * $Residents)) }
# Cargo: figuren.cod "Maxware" = number of cargo holds, 16 bits at figure table +0x3A (parser FUN_140068f10;
# the ship functions loop over that many holds of 4 bytes at ship +0x300, e.g. FUN_140021840). The figure parser
# stores "Maxtrag" x32 at +0x38, "Maxkanon" at +0x3C, "Maxenergy" x32 at +0x3E (hull: ship +0x12 is the current
# value, the ship loader FUN_14008e4f0 caps it there, the shipyard repairs up to it), "Hitpoint" at +0x40.
# Every hold takes 50 t (0x640 in the loading code). No. 21-28: small/large trading ship, small/large war ship,
# two entries each: 4/6/3/8 holds (figuren.cod). The ship record has 8 holds (SHIP4 +0x174: 8 x 8 bytes), so at
# most 8, as the large war ship already has.
$CargoOffset = 0x3A; $CargoMaxHolds = 8
$CargoOrig = @{ 21 = 4; 22 = 4; 23 = 6; 24 = 6; 25 = 3; 26 = 3; 27 = 8; 28 = 8 }
function Get-CargoHolds([int]$orig, [double]$factor) { [int][math]::Min($CargoMaxHolds, [math]::Floor($orig * $factor + 0.5)) }
if ($Cargo -ne 1.0) { Write-Host ((Txt 'Cargo: x{0:0.##} (small trading ship {1} holds of 50 t instead of 4)' 'Laderaum: x{0:0.##} (kleines Handelsschiff {1} Laderaeume zu 50 t statt 4)') -f $Cargo, (Get-CargoHolds 4 $Cargo)) }
# Production: haeuser.cod "Interval" as 16 bits at building table +0x3A (parser 0x140091... ,
# DAT_1406ba1fa). Read at every work step in FUN_1400b43e0 and FUN_1400b9ed0 through the
# pointer to the building entry. Marker 'NUFR' + factor x 100 at RVA 0xE5F70 (free bytes before the
# pirate code cave, in memory only) prevents dividing twice in the same game process.
$IntervalOffset = 0x3A; $BuildingCount = 500   # MAXHAUS (FUN_140002ae0("MAXHAUS",500))
$ProdMarkerRva = 0xE5F70
if ($Production -ne 1.0) { Write-Host ((Txt 'Production: x{0:0.##} (work intervals of all production buildings divided)' 'Produktion: x{0:0.##} (Arbeitsintervalle aller Betriebe geteilt)') -f $Production) }

# --- Ship speed ----------------------------------------------------------------------------------
# Figure table from RVA 0x6D80C0, 0x18C bytes each; figuren.cod "Speed" is stored at program start as
# a float (Speed/10000) at +0x10 (parser 0x14006A4D7) and read all the time (e.g.
# FUN_1400b9760). Ship types no. 21-32 (two entries each): small/large trading ship,
# small/large war ship, trader, pirate. Original values read in the game (2026-11-09).
$FigureRva = 0x6D80C0; $FigureSize = 0x18C; $SpeedOffset = 0x10
# Plain hashtable: with [ordered], $x[21] would be the 22nd position instead of the key 21.
$ShipSpeedOrig = @{
    21 = 'CD CC 4C 3D'; 22 = 'CD CC 4C 3D'; 23 = '0A D7 23 3D'; 24 = '0A D7 23 3D'; 25 = 'AE 47 61 3D'; 26 = 'AE 47 61 3D'
    27 = '8F C2 75 3D'; 28 = '8F C2 75 3D'; 29 = 'A6 9B 44 3D'; 30 = 'A6 9B 44 3D'; 31 = 'EC 51 38 3D'; 32 = 'EC 51 38 3D'
}
function Get-ShipSpeedBytes([string]$origHex, [double]$factor) {
    [BitConverter]::GetBytes([single]([double][BitConverter]::ToSingle((Bytes $origHex), 0) * $factor))
}
if ($ShipSpeed -ne 1.0) { Write-Host ((Txt 'Ship speed: x{0:0.##}' 'Schiffstempo: x{0:0.##}') -f $ShipSpeed) }

# --- Storage -------------------------------------------------------------------------------------
# Building table from RVA 0x6BA1C0, 0x90 bytes each; haeuser.cod "Maxlager" is stored as a 16-bit value x 32
# at +0x30 (parser 0x1400919C4). A new trading post takes over the value as its storage limit (trading post +0x20,
# read in the game: 960 = 30 t). No. 270-273 trading post I-IV, 401/467/468 market (read in the game).
$BuildingRva = 0x6BA1C0; $BuildingSize = 0x90; $StorageOffset = 0x30
$StorageOrig = @{ 270 = 960; 271 = 1600; 272 = 2400; 273 = 3200; 401 = 320; 467 = 320; 468 = 320 }
if ($Storage -ne 1) { Write-Host ((Txt 'Storage: x{0} (trading post I {1} t instead of 30 t)' 'Lager: x{0} (Kontor I {1} t statt 30 t)') -f $Storage, (30 * $Storage)) }

# --- Build cost, upkeep, taxes, radius -----------------------------------------------------------
# Derivation: parser FUN_140090660 (haeuser.cod), building table RVA 0x6BA1C0 + no. * 0x90:
#   HAUS_BAUKOST: Werkzeug +0x50, Holz +0x52, Ziegel +0x54, Kanon +0x56 (16 bits, tons x 32), Money +0x58 (int).
#     Read by the building site check FUN_14000ef50 (stock >= cost, gold check only when the cost is not 0),
#     paid in FUN_140010390 / FUN_14000ef50, house upgrades FUN_1400b7c60, AI FUN_14002a300/FUN_14002a360.
#   HAUS_PRODTYP: Kosten +0x2C (active) and +0x2A (paused, "_SLP"), 16 bits; Radius +0x20 (8 bits).
#   BGRUPPE (RVA 0x6BA020 + no. * 0x50): Steuer = (int)(value x 5.333) at +0x10 (RVA 0x6BA030).
# Build cost and upkeep touch hundreds of values: the fields of all 500 entries are checked against a
# SHA-256 checksum of the original values (table order, field order as listed), then scaled once per game
# process (marker = tag + factor x 100, like production). Gold and upkeep: round(v x factor), at least 1;
# materials in whole tons, at least 1 t; factor 0: everything 0. Values that are 0 stay 0.
$CostFields = @(@{ Offset = 0x50; Bytes = 2; Tons = $true }, @{ Offset = 0x52; Bytes = 2; Tons = $true }, @{ Offset = 0x54; Bytes = 2; Tons = $true }, @{ Offset = 0x58; Bytes = 4; Tons = $false })
$CostHash = '01bbc1ab830c7fafbb22dec388e7152d78746d95217c70d174f4be8f7a604e6d'
$UpkeepFields = @(@{ Offset = 0x2A; Bytes = 2; Tons = $false }, @{ Offset = 0x2C; Bytes = 2; Tons = $false })
$UpkeepHash = 'd8b34943002b07efc753a4a6f8720dfe34b4596c441d4b45749c6ba468f09f8f'
function Get-ScaledValue([long]$v, [double]$factor, [bool]$tons) {
    if ($v -eq 0 -or $factor -eq 0) { return 0 }
    if ($tons) { return 32 * [math]::Max(1, [long][math]::Round($v / 32 * $factor, [MidpointRounding]::AwayFromZero)) }
    [math]::Max(1, [long][math]::Round($v * $factor, [MidpointRounding]::AwayFromZero))
}
if ($BuildCost -ne 1.0) { Write-Host ((Txt 'Build cost: x{0:0.##} (trading post I {1} gold instead of 100)' 'Baukosten: x{0:0.##} (Kontor I {1} Gold statt 100)') -f $BuildCost, (Get-ScaledValue 100 $BuildCost $false)) }
if ($Upkeep -ne 1.0) { Write-Host ((Txt 'Upkeep: x{0:0.##} (trading post I {1} instead of 15)' 'Betriebskosten: x{0:0.##} (Kontor I {1} statt 15)') -f $Upkeep, (Get-ScaledValue 15 $Upkeep $false)) }
# Taxes: income of a town = sum over the groups of residents x Steuer x 6 / 32 x tax rate / 128 (FUN_1400bbdc0).
$TaxRva = 0x6BA030; $TaxOrig = @(7, 8, 11, 12, 13)
if ($Taxes -ne 1.0) { Write-Host ((Txt 'Taxes: x{0:0.##} (income per resident)' 'Steuern: x{0:0.##} (Einnahmen je Einwohner)') -f $Taxes) }
# Radius: territory of trading post (PRODTYP 8, at least 8) and market (7) in FUN_140095560 -> FUN_14009d730
# (circle from the table 0x1405ec300, 128 radii, clipped at the island border, only free land changes owner);
# supply of the houses by the public buildings in FUN_1400bea30 (also through the circle table). The AI
# copies the circle of a radius into its 0xA0-byte task block (+0x1D94, room for 52 bytes, FUN_140007c60),
# hence at most 48. Not changed: military, production buildings, natives.
# No. 270-273 trading post I-IV, 461 cathedral, 462 chapel, 463 church, 464 tavern, 465 theatre, 466 bathhouse,
# 467/468 market, 469 doctor, 470 university, 471 school, 472 fire brigade, 474 gallows.
$RadiusOffset = 0x20; $RadiusMax = 48
$RadiusOrig = @{ 270 = 16; 271 = 16; 272 = 16; 273 = 16; 461 = 24; 462 = 8; 463 = 21; 464 = 12; 465 = 20; 466 = 20; 467 = 16; 468 = 16; 469 = 16; 470 = 15; 471 = 12; 472 = 15; 474 = 16 }
function Get-ScaledRadius([int]$r, [double]$factor) { [math]::Min($RadiusMax, [int][math]::Round($r * $factor, [MidpointRounding]::AwayFromZero)) }
if ($Radius -ne 1.0) { Write-Host ((Txt 'Radius: x{0:0.##} (trading post and market {1} instead of 16)' 'Radius: x{0:0.##} (Kontor und Markt {1} statt 16)') -f $Radius, (Get-ScaledRadius 16 $Radius)) }

# --- Events (-Events) ----------------------------------------------------------------------------
# Derivation: docs\FINDINGS.md, sections "Ships, money" (game clock, gold = player +4), "Logbook" (lock 0x5EBF68,
# local player 0x5F1D60, settlements), "Gameplay options" (taxes, intervals). The tool window polls the game every
# second. An event is due when the game clock has advanced by a random interval (0.5 to 1.5 x the mean) while a game
# runs (clock > 0, lock 0, human kind 0) and the human owns at least one settlement; a clock that stands still adds
# nothing. Temporary events change game-wide values (taxes of the 5 population groups, the 500 work intervals):
# the originals and the values written go to a page that the tool allocates in the game process (marker 'EVNT' at
# RVA 0xE5BD0: version, address of the page). They are restored when the event ends, when the clock jumps
# (new game, savegame loaded: command 0x36 resets the clock), when the game ends and when the tool stops; a tool
# that is killed leaves them to the next tool run in the same game process (and to the game's exit). Neither
# value is in a savegame (they come from haeuser.cod at program start). Gold and goods changes are permanent.
$EventMarkerRva = 0xE5BD0                       # 16 bytes up to 0xE5BE0 (free; markers end at 0xE5BD0)
$EventLockRva = 0x5EBF68                        # end-of-game lock (1 = game over), reset by command 0x36
$EventLocalPlayerRva = 0x5F1D60                 # number of the local (human) player (0 in single player)
$EventPlayersRva = 0x5F0960                     # 7 players x 0x280: +0 kind (0 human, 9 out), +4 gold
$EventSettlementRva = 0x622DC0; $EventSettlementSize = 600; $EventSettlementCount = 75
$EventClockPerHour = 32700                      # game clock units per game hour at normal speed (measured)
$EventMaxClockPerSecond = 200                   # 16x turbo = 160 per second, plus a margin
$EventClockSlack = 200
$EventMean = @{ Rare = 3 * $EventClockPerHour; Often = $EventClockPerHour }
$EventDuration = $EventClockPerHour
# Goods of the trader's gift (good code = index in the goods list, stock at settlement +0x2A + good x 12).
$EventGiftGoods = @(@{ Good = 22; De = 'Werkzeug'; En = 'tools' }, @{ Good = 23; De = 'Holz'; En = 'wood' }, @{ Good = 24; De = 'Ziegel'; En = 'bricks' }, @{ Good = 14; De = 'Nahrung'; En = 'food' })
# Events: id (stable, events.json), code (state page), weight, kind, factor (taxes, production speed). German with
# umlauts for events.json (the logbook shows them); the console gets the same text without umlauts.
$EventDefs = [ordered]@{
    patron         = @{ Code = 1; Weight = 3; Kind = 'Gold'
        Title = @{ de = 'Ein Gönner'; en = 'A patron' }
        Text = @{ de = 'Ein wohlhabender Kaufmann aus der alten Heimat glaubt an deine Kolonie und schickt dir Gold für den Aufbau.'; en = 'A wealthy merchant from the old country believes in your colony and sends you gold to help it grow.' } }
    warehouse_fire = @{ Code = 2; Weight = 2; Kind = 'Gold'
        Title = @{ de = 'Brand im Kontor'; en = 'Fire in the warehouse' }
        Text = @{ de = 'Funkenflug setzt das Dach deines Kontors in Brand. Die Löschmannschaft ist schnell zur Stelle, doch die Reparatur kostet.'; en = 'Flying sparks set the roof of your warehouse alight. The fire crew is quick, but the repairs are costly.' } }
    tax_windfall   = @{ Code = 3; Weight = 2; Kind = 'Tax'; Factor = 1.5
        Title = @{ de = 'Steuersegen'; en = 'Tax windfall' }
        Text = @{ de = 'Ein gutes Jahr auf allen Inseln: Die Bürger zahlen gern und reichlich. Eine Spielstunde lang bringen die Steuern die Hälfte mehr ein, auch deinen Konkurrenten.'; en = 'A good year on every island: citizens pay gladly and generously. For one game hour taxes bring in half as much again, for your rivals too.' } }
    tax_slump      = @{ Code = 4; Weight = 2; Kind = 'Tax'; Factor = 0.75
        Title = @{ de = 'Steuerflaute'; en = 'Tax slump' }
        Text = @{ de = 'Eine Flaute im Handel: Überall halten die Leute ihr Geld zusammen. Eine Spielstunde lang bringen die Steuern ein Viertel weniger ein, auch bei deinen Konkurrenten.'; en = 'Trade is slack: everywhere people are holding on to their money. For one game hour taxes bring in a quarter less, for your rivals too.' } }
    harvest_boom   = @{ Code = 5; Weight = 2; Kind = 'Production'; Factor = 1.5
        Title = @{ de = 'Erntesegen'; en = 'Bumper harvest' }
        Text = @{ de = 'Sonne und Regen zur rechten Zeit: Eine Spielstunde lang arbeiten alle Felder und Betriebe anderthalbmal so schnell, auch die deiner Konkurrenten.'; en = 'Sun and rain at just the right time: for one game hour all farms and workshops work half as fast again, your rivals'' too.' } }
    marsh_fever    = @{ Code = 6; Weight = 2; Kind = 'Production'; Factor = 0.75
        Title = @{ de = 'Sumpffieber'; en = 'Marsh fever' }
        Text = @{ de = 'Ein Fieber geht um, viele Arbeiter liegen krank darnieder. Eine Spielstunde lang arbeiten alle Felder und Betriebe ein Viertel langsamer, auch die deiner Konkurrenten.'; en = 'A fever is going round and many workers are laid up. For one game hour all farms and workshops work a quarter slower, your rivals'' too.' } }
    trader_gift    = @{ Code = 7; Weight = 2; Kind = 'Goods'
        Title = @{ de = 'Geschenk eines Händlers'; en = 'A trader''s gift' }
        Text = @{ de = 'Ein freier Händler bedankt sich für gute Geschäfte und lässt {0} t {1} in deinem Kontor in {2} abladen.'; en = 'A free trader thanks you for good business and unloads {0} t of {1} at your warehouse in {2}.' } }
}
if ($Events -ne 'Off') {
    Write-Host ((Txt 'Events: {0} (random events on average every {1} game hour(s) once you have a town; this window must stay open)' 'Ereignisse: {0} (zufaellige Ereignisse im Schnitt alle {1} Spielstunde(n), sobald du eine Stadt hast; dieses Fenster muss offen bleiben)') -f (Get-ValueName $Events), ($EventMean[$Events] / $EventClockPerHour))
}
foreach ($s in $Patches) { $s.Size = (Bytes $s.Original).Length }
function Format-Patch($s, [byte[]]$b) {
    if ($s.Kind) { Format-Value $s.Kind $b[6..9] } else { Txt "set ($($b.Length) bytes)" "gesetzt ($($b.Length) Bytes)" }
}

# --- 1. Check the exe on disk --------------------------------------------------------------------
$exe = Join-Path $GameFolder 'Anno1602.exe'
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $ExpectedHash) {
    throw (Txt "Unknown version of Anno1602.exe (SHA-256 $hash). The tool only fits $ExpectedHash. Aborted, nothing changed." "Unbekannte Version von Anno1602.exe (SHA-256 $hash). Das Werkzeug passt nur zu $ExpectedHash. Abbruch, nichts geaendert.")
}
$file = [IO.File]::ReadAllBytes($exe)
foreach ($s in $Patches) {
    if ($s.MemoryOnly) { continue }   # lies behind the file data of .text, in memory only
    $off = $s.Rva - 0x1000 + 0x400   # .text: RVA 0x1000 is at 0x400 in the file
    $actual = Hex $file[$off..($off + $s.Size - 1)]
    if ($actual -ne $s.Original) { throw (Txt "Bytes at $($s.Name) do not match ($actual). Aborted, nothing changed." "Bytes an $($s.Name) passen nicht ($actual). Abbruch, nichts geaendert.") }
}
Write-Host (Txt "exe checked: version matches, all $($Patches.Count) sites found." "exe geprueft: Version passt, alle $($Patches.Count) Stellen gefunden.") -ForegroundColor Green
if ($CheckOnly) { return }

# --- 2. Back up the savegames --------------------------------------------------------------------
# Options of this run as an argument list, for saves.json: everything that changes the game, always with the map size;
# numbers with a dot (independent of the Windows language).
function Get-SessionArgs($bound) {
    $list = New-Object System.Collections.Generic.List[string]
    $list.AddRange([string[]]@('-Width', [string]$Width, '-Height', [string]$Height))
    foreach ($k in $bound.Keys) {
        if ($k -in 'Width', 'Height', 'CheckOnly', 'WaitMinutes', 'GameAlreadyRunning', 'GamePath', 'NoLastgameProtection', 'PauseOnError', 'TestProcessId', 'TestBase') { continue }
        if ($k -in 'EventSeed', 'EventScript', 'EventFile', 'EventPollMs', 'EventIntervalClock', 'EventDurationClock', 'EventTestUntilClock') { continue }   # test switches; -Events is recorded
        $v = $bound[$k]
        if ($v -is [System.Management.Automation.SwitchParameter]) { if ($v.IsPresent) { $list.Add("-$k") }; continue }
        $list.Add("-$k")
        $list.Add([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $v))
    }
    , $list.ToArray()
}
# Notes every savegame written since $since with the options in $file (JSON array, at most 500 entries).
# Returns the number of savegames noted.
function Save-SessionRecord([string]$saveFolder, [datetime]$since, [string[]]$sessionArgs, [string]$file) {
    if (-not (Test-Path -LiteralPath $saveFolder)) { return 0 }
    $written = @(Get-ChildItem -LiteralPath $saveFolder -Filter '*.gam' -File | Where-Object { $_.LastWriteTime -gt $since })
    if (-not $written.Count) { return 0 }
    $all = @()
    if (Test-Path -LiteralPath $file) { $all = @(Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ }) }
    foreach ($f in $written) {
        $time = $f.LastWriteTime.ToString('s')
        # Same file version already noted (e.g. the tool ran twice for one game): replace that entry.
        $all = @($all | Where-Object { -not ($_.File -eq $f.Name -and $_.Written -eq $time) })
        $all += [pscustomobject]@{ File = $f.Name; Written = $time; Width = $Width; Height = $Height; Args = $sessionArgs }
    }
    $all = @($all | Select-Object -Last 500)
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    ConvertTo-Json -InputObject $all -Depth 4 | Set-Content -LiteralPath $file -Encoding UTF8
    $written.Count
}
# Keeps the backups from growing without end (each one is a full copy of the Savegame folder, about 20 MB): the
# oldest backup (the state before the first use of the tool) and the newest $keep stay, the others go to the recycle
# bin, so they can still be restored. Returns the names of the moved folders.
function Limit-Backups([string]$parent, [int]$keep = 5) {
    $all = @(Get-ChildItem -LiteralPath $parent -Directory | Where-Object { $_.Name -match '^Savegame-(Backup|Sicherung)-\d{8}-\d{6}$' } |
            Sort-Object { $_.Name -replace '^Savegame-(Backup|Sicherung)-', '' })
    if ($all.Count -le $keep + 1) { return }
    Add-Type -AssemblyName Microsoft.VisualBasic
    foreach ($d in $all[1..($all.Count - $keep - 1)]) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($d.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        $d.Name
    }
}
$toolStart = Get-Date
$saves = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Savegame'
# Content of a folder as text: relative path, size and modification time of every file.
function Get-FolderSignature([string]$folder) {
    Get-ChildItem -LiteralPath $folder -Recurse -File | Sort-Object FullName |
        ForEach-Object { '{0}|{1}|{2}' -f $_.FullName.Substring($folder.Length), $_.Length, $_.LastWriteTimeUtc.Ticks } | Out-String
}
if ($TestProcessId -eq 0 -and (Test-Path -LiteralPath $saves)) {
    # Backups made before the translation are called Savegame-Sicherung-<time>; sort by the time.
    $latest = Get-ChildItem -LiteralPath (Split-Path $saves) -Directory | Where-Object { $_.Name -like 'Savegame-Backup-*' -or $_.Name -like 'Savegame-Sicherung-*' } |
        Sort-Object { $_.Name -replace '^Savegame-(Backup|Sicherung)-', '' } | Select-Object -Last 1
    if ($latest -and (Get-FolderSignature $latest.FullName) -eq (Get-FolderSignature $saves)) {
        Write-Host (Txt "Savegames unchanged since the backup $($latest.Name); no new backup needed." "Spielstaende unveraendert seit der Sicherung $($latest.Name); keine neue Sicherung noetig.")
    }
    else {
        $dest = "$saves-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $saves -Destination $dest -Recurse
        Write-Host (Txt "Savegames backed up to: $dest" "Spielstaende gesichert nach: $dest")
        try {
            $old = @(Limit-Backups (Split-Path $saves) 5)
            if ($old.Count) { Write-Host ((Txt 'Older backups moved to the recycle bin: {0} (kept: the first one and the newest 5).' 'Aeltere Sicherungen in den Papierkorb verschoben: {0} (behalten: die erste und die neuesten 5).') -f $old.Count) }
        }
        catch { Write-Host ((Txt 'Could not tidy up the older backups: {0}' 'Aeltere Sicherungen konnten nicht aufgeraeumt werden: {0}') -f $_.Exception.Message) -ForegroundColor Yellow }
    }
}

# --- 3. Wait for the game ------------------------------------------------------------------------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AnnoMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtectEx(IntPtr h, IntPtr addr, IntPtr size, uint prot, out uint old);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FlushInstructionCache(IntPtr h, IntPtr addr, IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
}
'@
# Events: every write of an event into the game goes through this class, under one lock. The page in the game
# process (allocated by the tool, see "Events" above) holds the originals and the values written; Restore() puts the
# originals back wherever the game still holds the value the tool wrote. The console handler calls Stop() when the
# window is closed or Ctrl+C is pressed (the main thread may be writing at that moment, hence the lock and the
# Stopping flag: nothing is written after Stop()).
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AnnoEvents {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, IntPtr size, uint type, uint prot);
    public delegate bool CtrlHandler(uint ctrlType);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetConsoleCtrlHandler(CtrlHandler handler, bool add);

    // Page layout (all little endian): 'EVST', version, owner tool PID (0 = none), last game clock,
    // taxes: active, event code, factor x 1000, ends at clock, 5 originals, 5 written values,
    // production: active, event code, factor x 1000, ends at clock, entries changed, 500 originals, 500 written values.
    public const int PageSize = 0x860;
    public const int OffOwner = 0x08, OffClock = 0x0C;
    public const int OffTax = 0x10, OffTaxBase = 0x20, OffTaxApplied = 0x34;
    public const int OffProd = 0x48, OffProdCount = 0x58, OffProdBase = 0x60, OffProdApplied = 0x450;

    public static readonly object Sync = new object();
    public static IntPtr Handle = IntPtr.Zero;
    public static long Page, TaxAddr, IntervalAddr;
    public static int TaxStride, IntervalStride, Count;
    public static volatile bool Stopping;
    public static int[] LastRestore = new int[4];
    static CtrlHandler handler;

    public static void Configure(IntPtr h, long page, long taxAddr, int taxStride, long intervalAddr, int intervalStride, int count) {
        lock (Sync) { Handle = h; Page = page; TaxAddr = taxAddr; TaxStride = taxStride; IntervalAddr = intervalAddr; IntervalStride = intervalStride; Count = count; Stopping = false; }
    }
    static byte[] Read(long addr, int n) {
        byte[] b = new byte[n]; IntPtr d;
        if (!ReadProcessMemory(Handle, (IntPtr)addr, b, (IntPtr)n, out d) || d.ToInt64() != n) return null;
        return b;
    }
    static bool Write(long addr, byte[] b) { IntPtr d; return WriteProcessMemory(Handle, (IntPtr)addr, b, (IntPtr)b.Length, out d) && d.ToInt64() == b.Length; }
    static void Put(byte[] b, int off, int v) { Array.Copy(BitConverter.GetBytes(v), 0, b, off, 4); }
    static void Put16(byte[] b, int off, int v) { Array.Copy(BitConverter.GetBytes((ushort)v), 0, b, off, 2); }
    public static byte[] ReadPage() { lock (Sync) { return (Handle == IntPtr.Zero || Page == 0) ? null : Read(Page, PageSize); } }
    public static bool SetOwner(int pid, int clock) {
        lock (Sync) {
            if (Stopping || Handle == IntPtr.Zero || Page == 0) return false;
            byte[] b = new byte[8]; Put(b, 0, pid); Put(b, 4, clock);
            return Write(Page + OffOwner, b);
        }
    }

    // Starts a tax event. Result: 0 written, 1 stopping or no page, 2 the game does not hold the originals
    // (or a tax event is active), 3 read/write error. The page is written first, then the values.
    public static int ApplyTax(int[] orig, int[] target, int code, int factor, int ends) {
        lock (Sync) {
            if (Stopping || Handle == IntPtr.Zero || Page == 0) return 1;
            byte[] page = Read(Page, PageSize); if (page == null) return 3;
            if (BitConverter.ToInt32(page, OffTax) != 0) return 2;
            for (int g = 0; g < 5; g++) {
                byte[] c = Read(TaxAddr + (long)g * TaxStride, 4); if (c == null) return 3;
                if (BitConverter.ToInt32(c, 0) != orig[g]) return 2;
            }
            byte[] blk = new byte[OffProd - OffTax];
            Put(blk, 0, 1); Put(blk, 4, code); Put(blk, 8, factor); Put(blk, 12, ends);
            for (int g = 0; g < 5; g++) { Put(blk, OffTaxBase - OffTax + 4 * g, orig[g]); Put(blk, OffTaxApplied - OffTax + 4 * g, target[g]); }
            if (!Write(Page + OffTax, blk)) return 3;
            for (int g = 0; g < 5; g++) if (!Write(TaxAddr + (long)g * TaxStride, BitConverter.GetBytes(target[g]))) return 3;
            return 0;
        }
    }

    // Starts a production event (500 work intervals, 16 bits); results as ApplyTax.
    public static int ApplyProduction(int[] orig, int[] target, int code, int factor, int ends) {
        lock (Sync) {
            if (Stopping || Handle == IntPtr.Zero || Page == 0) return 1;
            byte[] page = Read(Page, PageSize); if (page == null) return 3;
            if (BitConverter.ToInt32(page, OffProd) != 0) return 2;
            byte[] tab = Read(IntervalAddr, (Count - 1) * IntervalStride + 2); if (tab == null) return 3;
            int changed = 0;
            for (int i = 0; i < Count; i++) {
                if (BitConverter.ToUInt16(tab, i * IntervalStride) != orig[i]) return 2;
                if (target[i] != orig[i]) changed++;
            }
            byte[] blk = new byte[PageSize - OffProd];
            Put(blk, 0, 1); Put(blk, 4, code); Put(blk, 8, factor); Put(blk, 12, ends); Put(blk, OffProdCount - OffProd, changed);
            for (int i = 0; i < Count; i++) { Put16(blk, OffProdBase - OffProd + 2 * i, orig[i]); Put16(blk, OffProdApplied - OffProd + 2 * i, target[i]); }
            if (!Write(Page + OffProd, blk)) return 3;
            for (int i = 0; i < Count; i++) {
                if (target[i] == orig[i]) continue;
                if (!Write(IntervalAddr + (long)i * IntervalStride, BitConverter.GetBytes((ushort)target[i]))) return 3;
            }
            return 0;
        }
    }

    // Restores taxes and/or production: every value that still holds what the tool wrote gets its original back.
    // Returns { taxes restored, taxes left (changed by someone else), intervals restored, intervals left }.
    public static int[] Restore(bool tax, bool prod) {
        lock (Sync) { return RestoreLocked(tax, prod); }
    }
    static int[] RestoreLocked(bool tax, bool prod) {
        int[] r = new int[4];
        if (Handle == IntPtr.Zero || Page == 0) return r;
        byte[] page = Read(Page, PageSize); if (page == null) return r;
        if (tax && BitConverter.ToInt32(page, OffTax) != 0) {
            for (int g = 0; g < 5; g++) {
                long a = TaxAddr + (long)g * TaxStride;
                int orig = BitConverter.ToInt32(page, OffTaxBase + 4 * g), done = BitConverter.ToInt32(page, OffTaxApplied + 4 * g);
                byte[] c = Read(a, 4); if (c == null) { r[1]++; continue; }
                int cur = BitConverter.ToInt32(c, 0);
                if (cur == orig) continue;
                if (cur == done && Write(a, BitConverter.GetBytes(orig))) r[0]++; else r[1]++;
            }
            Write(Page + OffTax, new byte[4]);
        }
        if (prod && BitConverter.ToInt32(page, OffProd) != 0) {
            byte[] tab = Read(IntervalAddr, (Count - 1) * IntervalStride + 2);
            for (int i = 0; i < Count; i++) {
                int orig = BitConverter.ToUInt16(page, OffProdBase + 2 * i), done = BitConverter.ToUInt16(page, OffProdApplied + 2 * i);
                if (orig == done) continue;
                if (tab == null) { r[3]++; continue; }
                int cur = BitConverter.ToUInt16(tab, i * IntervalStride);
                if (cur == orig) continue;
                if (cur == done && Write(IntervalAddr + (long)i * IntervalStride, BitConverter.GetBytes((ushort)orig))) r[2]++; else r[3]++;
            }
            Write(Page + OffProd, new byte[4]);
        }
        LastRestore = r;
        return r;
    }

    // Gold: adds delta (int, at most int.MaxValue). Returns the new gold, or long.MinValue if nothing was written
    // (stopping, read error, or the result would be below minimum).
    public static long AddGold(long addr, int delta, int minimum) {
        lock (Sync) {
            if (Stopping || Handle == IntPtr.Zero) return long.MinValue;
            byte[] c = Read(addr, 4); if (c == null) return long.MinValue;
            long n = (long)BitConverter.ToInt32(c, 0) + delta;
            if (n > int.MaxValue) n = int.MaxValue;
            if (n < minimum) return long.MinValue;
            return Write(addr, BitConverter.GetBytes((int)n)) ? n : long.MinValue;
        }
    }
    // Goods: adds delta to a 16-bit stock, at most up to cap. Returns the amount added (0 = nothing written).
    public static int AddStock(long addr, int delta, int cap) {
        lock (Sync) {
            if (Stopping || Handle == IntPtr.Zero) return 0;
            byte[] c = Read(addr, 2); if (c == null) return 0;
            int cur = BitConverter.ToUInt16(c, 0), n = Math.Min(Math.Min(cur + delta, cap), 65535);
            if (n <= cur) return 0;
            return Write(addr, BitConverter.GetBytes((ushort)n)) ? n - cur : 0;
        }
    }

    // Stops all event writing for good and restores (window closed, Ctrl+C, tool ends).
    public static int[] Stop() {
        lock (Sync) {
            Stopping = true;
            int[] r = RestoreLocked(true, true);
            if (Handle != IntPtr.Zero && Page != 0) Write(Page + OffOwner, new byte[4]);
            return r;
        }
    }
    static bool OnConsoleCtrl(uint ctrlType) {
        try { Stop(); } catch { }
        return false;
    }
    public static void InstallConsoleHandler() {
        if (handler != null) return;
        handler = new CtrlHandler(OnConsoleCtrl);
        SetConsoleCtrlHandler(handler, true);
    }
}
'@

function Read-Mem([long]$rva, [int]$n) {
    $buf = New-Object byte[] $n
    $done = [IntPtr]::Zero
    if (-not [AnnoMem]::ReadProcessMemory($script:h, [IntPtr]($script:base.ToInt64() + $rva), $buf, [IntPtr]$n, [ref]$done)) {
        throw ((Txt 'Reading at RVA 0x{0:X} failed (error {1}).' 'Lesen bei RVA 0x{0:X} fehlgeschlagen (Fehler {1}).') -f $rva, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    , $buf
}
function Write-Mem([long]$rva, [byte[]]$data, [bool]$code) {
    $addr = [IntPtr]($script:base.ToInt64() + $rva)
    $old = [uint32]0
    if ($code -and -not [AnnoMem]::VirtualProtectEx($script:h, $addr, [IntPtr]$data.Length, 0x40, [ref]$old)) {
        throw ((Txt 'Write protection at RVA 0x{0:X} cannot be lifted (error {1}).' 'Schreibschutz bei RVA 0x{0:X} nicht aufhebbar (Fehler {1}).') -f $rva, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    $done = [IntPtr]::Zero
    $ok = [AnnoMem]::WriteProcessMemory($script:h, $addr, $data, [IntPtr]$data.Length, [ref]$done)
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($code) {
        $ignored = [uint32]0
        [void][AnnoMem]::VirtualProtectEx($script:h, $addr, [IntPtr]$data.Length, $old, [ref]$ignored)
        [void][AnnoMem]::FlushInstructionCache($script:h, $addr, [IntPtr]$data.Length)
    }
    if (-not $ok) { throw ((Txt 'Writing at RVA 0x{0:X} failed (error {1}).' 'Schreiben bei RVA 0x{0:X} fehlgeschlagen (Fehler {1}).') -f $rva, $err) }
}
# Is the process behind $script:h still running? (STILL_ACTIVE = 259)
function Test-Running {
    $c = [uint32]0
    [AnnoMem]::GetExitCodeProcess($script:h, [ref]$c) -and $c -eq 259
}

# Set table values with known originals (like storage): wait until all are loaded (not 0),
# each must be the original or already the target value, then write all and read them back.
# $entries: @{ Rva; Orig; Target; Bytes = 2 or 4 }. Returns $true set, $false not set,
# $null = the process has exited.
function Read-Number($e) {
    $b = Read-Mem $e.Rva $e.Bytes
    if ($e.Bytes -eq 1) { [int]$b[0] }
    elseif ($e.Bytes -eq 2) { [int][BitConverter]::ToUInt16($b, 0) } else { [BitConverter]::ToInt32($b, 0) }
}
function Set-TableValues([string]$what, $entries) {
    while ($true) {
        $ready = $true
        foreach ($e in $entries) {
            $actual = Read-Number $e
            if ($actual -eq 0) { $ready = $false; break }
            if ($actual -ne $e.Orig -and $actual -ne $e.Target) {
                Write-Host ((Txt '{0}: unexpected value {1} instead of {2} (RVA 0x{3:X}); NOT set (the rest is active).' '{0}: unerwarteter Wert {1} statt {2} (RVA 0x{3:X}); NICHT gesetzt (Rest ist aktiv).') -f $what, $actual, $e.Orig, $e.Rva) -ForegroundColor Yellow
                return $false
            }
        }
        if ($ready) { break }
        if (-not (Test-Running)) { return $null }
        if ((Get-Date) -gt $script:deadline) { Write-Host (Txt "${what}: values not loaded yet; NOT set." "${what}: Werte noch nicht geladen; NICHT gesetzt.") -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    foreach ($e in $entries) {
        $d = if ($e.Bytes -eq 1) { [byte[]]@([byte]$e.Target) } elseif ($e.Bytes -eq 2) { [BitConverter]::GetBytes([uint16]$e.Target) } else { [BitConverter]::GetBytes([int32]$e.Target) }
        Write-Mem $e.Rva $d $false
    }
    foreach ($e in $entries) { if ((Read-Number $e) -ne $e.Target) { throw ((Txt 'Check of {0} failed (RVA 0x{1:X}).' 'Kontrolle {0} fehlgeschlagen (RVA 0x{1:X}).') -f $what, $e.Rva) } }
    $true
}

# Production: divide all intervals of the building table by the factor (once per game process).
function Set-Production([double]$factor) {
    $signal = $BuildingRva + 270 * $BuildingSize + $StorageOffset   # storage of trading post I: haeuser.cod has been read
    while ([BitConverter]::ToUInt16((Read-Mem $signal 2), 0) -eq 0) {
        if (-not (Test-Running)) { return $null }
        if ((Get-Date) -gt $script:deadline) { Write-Host (Txt 'Production: building values not loaded yet; NOT set.' 'Produktion: Gebaeudewerte noch nicht geladen; NICHT gesetzt.') -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    $marker = [byte[]](@(0x4E, 0x55, 0x46, 0x52) + [BitConverter]::GetBytes([int32][math]::Round($factor * 100)))   # 'NUFR', factor x 100
    $actual = Hex (Read-Mem $ProdMarkerRva 8)
    if ($actual -eq (Hex $marker)) { Write-Host ((Txt 'Production x{0:0.##}: already set in this game process.' 'Produktion x{0:0.##}: in diesem Spielprozess schon gesetzt.') -f $factor) -ForegroundColor Green; return $true }
    if ($actual -ne (Hex ([byte[]](0, 0, 0, 0, 0, 0, 0, 0)))) {
        Write-Host (Txt "Production: a different factor is already set in the game ($actual); NOT changed. Restart the game for a different factor." "Produktion: im Spiel ist schon ein anderer Faktor gesetzt ($actual); NICHT geaendert. Fuer einen anderen Faktor das Spiel neu starten.") -ForegroundColor Yellow
        return $false
    }
    # Only read once the table no longer changes (the parser might still be running).
    $length = $BuildingCount * $BuildingSize
    $tab = Read-Mem $BuildingRva $length
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 300
        $new = Read-Mem $BuildingRva $length
        if ((Hex $new) -eq (Hex $tab)) { break }
        $tab = $new
    }
    $n = 0
    for ($i = 0; $i -lt $BuildingCount; $i++) {
        $off = $i * $BuildingSize + $IntervalOffset
        $v = [int][BitConverter]::ToUInt16($tab, $off)
        if ($v -eq 0) { continue }
        $target = [math]::Max(1, [int][math]::Round($v / $factor))
        if ($target -ne $v) { Write-Mem ($BuildingRva + $off) ([BitConverter]::GetBytes([uint16]$target)) $false; $n++ }
    }
    Write-Mem $ProdMarkerRva $marker $true
    if ((Hex (Read-Mem $ProdMarkerRva 8)) -ne (Hex $marker)) { throw (Txt 'Check of the production marker failed.' 'Kontrolle der Produktions-Marke fehlgeschlagen.') }
    Write-Host ((Txt 'Production x{0:0.##}: {1} work intervals shortened.' 'Produktion x{0:0.##}: {1} Arbeitsintervalle verkuerzt.') -f $factor, $n) -ForegroundColor Green
    $true
}

# Fields of all 500 building entries in table order (for the checksum of build cost and upkeep).
function Get-FieldBytes([byte[]]$tab, $fields) {
    $l = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $BuildingCount; $i++) { foreach ($f in $fields) { for ($k = 0; $k -lt $f.Bytes; $k++) { $l.Add($tab[$i * $BuildingSize + $f.Offset + $k]) } } }
    , $l.ToArray()
}
function Get-Sha256Hex([byte[]]$b) { (([Security.Cryptography.SHA256]::Create().ComputeHash($b)) | ForEach-Object { '{0:x2}' -f $_ }) -join '' }
function Get-FieldValue([byte[]]$tab, [int]$off, [int]$bytes) { if ($bytes -eq 2) { [long][BitConverter]::ToUInt16($tab, $off) } else { [long][BitConverter]::ToInt32($tab, $off) } }
function Get-FieldData([long]$v, [int]$bytes) { if ($bytes -eq 2) { [BitConverter]::GetBytes([uint16]$v) } else { [BitConverter]::GetBytes([int32]$v) } }

# Build cost / upkeep: scale the fields of all building entries once per game process. $tag: 4 letters of
# the marker. Returns $true set, $false not set, $null = the process has exited.
function Set-BuildingFields([string]$what, $fields, [string]$hash, [long]$markerRva, [string]$tag, [double]$factor) {
    $signal = $BuildingRva + 270 * $BuildingSize + $StorageOffset   # storage of trading post I: haeuser.cod has been read
    while ([BitConverter]::ToUInt16((Read-Mem $signal 2), 0) -eq 0) {
        if (-not (Test-Running)) { return $null }
        if ((Get-Date) -gt $script:deadline) { Write-Host ((Txt '{0}: building values not loaded yet; NOT set.' '{0}: Gebaeudewerte noch nicht geladen; NICHT gesetzt.') -f $what) -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    $marker = [byte[]]([Text.Encoding]::ASCII.GetBytes($tag) + [BitConverter]::GetBytes([int32][math]::Round($factor * 100)))
    $actual = Hex (Read-Mem $markerRva 8)
    if ($actual -eq (Hex $marker)) { Write-Host ((Txt '{0} x{1:0.##}: already set in this game process.' '{0} x{1:0.##}: in diesem Spielprozess schon gesetzt.') -f $what, $factor) -ForegroundColor Green; return $true }
    if ($actual -ne (Hex ([byte[]](0, 0, 0, 0, 0, 0, 0, 0)))) {
        Write-Host ((Txt '{0}: a different factor is already set in the game ({1}); NOT changed. Restart the game for a different factor.' '{0}: im Spiel ist schon ein anderer Faktor gesetzt ({1}); NICHT geaendert. Fuer einen anderen Faktor das Spiel neu starten.') -f $what, $actual) -ForegroundColor Yellow
        return $false
    }
    # Only read once the table no longer changes (the parser might still be running).
    $length = $BuildingCount * $BuildingSize
    $tab = Read-Mem $BuildingRva $length
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 300
        $new = Read-Mem $BuildingRva $length
        if ([BitConverter]::ToString($new) -eq [BitConverter]::ToString($tab)) { break }
        $tab = $new
    }
    $sum = Get-Sha256Hex (Get-FieldBytes $tab $fields)
    if ($sum -ne $hash) {
        Write-Host ((Txt '{0}: unexpected values in the building table (checksum {1}); NOT set (the rest is active).' '{0}: unerwartete Werte in der Gebaeudetabelle (Pruefsumme {1}); NICHT gesetzt (Rest ist aktiv).') -f $what, $sum.Substring(0, 16)) -ForegroundColor Yellow
        return $false
    }
    $changes = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $BuildingCount; $i++) {
        foreach ($f in $fields) {
            $off = $i * $BuildingSize + $f.Offset
            $v = Get-FieldValue $tab $off $f.Bytes
            $t = Get-ScaledValue $v $factor $f.Tons
            if ($t -ne $v) { $changes.Add(@{ Off = $off; Bytes = $f.Bytes; Target = $t }) }
        }
    }
    foreach ($c in $changes) { Write-Mem ($BuildingRva + $c.Off) (Get-FieldData $c.Target $c.Bytes) $false }
    $tab = Read-Mem $BuildingRva $length
    foreach ($c in $changes) { if ((Get-FieldValue $tab $c.Off $c.Bytes) -ne $c.Target) { throw ((Txt 'Check of {0} failed (RVA 0x{1:X}).' 'Kontrolle {0} fehlgeschlagen (RVA 0x{1:X}).') -f $what, ($BuildingRva + $c.Off)) } }
    Write-Mem $markerRva $marker $true
    if ((Hex (Read-Mem $markerRva 8)) -ne (Hex $marker)) { throw ((Txt 'Check of the {0} marker failed.' 'Kontrolle der Marke {0} fehlgeschlagen.') -f $what) }
    Write-Host ((Txt '{0} x{1:0.##}: {2} values changed.' '{0} x{1:0.##}: {2} Werte geaendert.') -f $what, $factor, $changes.Count) -ForegroundColor Green
    $true
}

# --- Events: engine ------------------------------------------------------------------------------
# Reads at an absolute address of the game process (the event page lies outside the image).
function Read-Abs([long]$address, [int]$n) { Read-Mem ($address - $script:base.ToInt64()) $n }
# Thousands separators: German 5'000 (Swiss style, as in events.json), English 5,000.
function Format-EventNumber([long]$n, [string]$lang) {
    $s = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:N0}', [math]::Abs($n))
    if ($lang -eq 'de') { $s.Replace(',', "'") } else { $s }
}
# The console keeps to plain ASCII like every other message of the tool.
function ConvertTo-AsciiGerman([string]$s) {
    $s.Replace([string][char]0xE4, 'ae').Replace([string][char]0xF6, 'oe').Replace([string][char]0xFC, 'ue').Replace([string][char]0xC4, 'Ae').Replace([string][char]0xD6, 'Oe').Replace([string][char]0xDC, 'Ue').Replace([string][char]0xDF, 'ss')
}
function Get-EventRoundHalfUp([double]$x) { [int][math]::Floor($x + 0.5) }
# Taxes during an event: original (after -Taxes) x factor, at least 1.
function Get-EventTaxTarget([int[]]$orig, [double]$factor) { , [int[]]@(foreach ($v in $orig) { [math]::Max(1, (Get-EventRoundHalfUp ($v * $factor))) }) }
# Work intervals during an event: original (after -Production) / speed factor; 0 stays 0, at least 1; never above
# 32767 (the production records count the interval down as a signed 16-bit value) unless the original already is.
function Get-EventIntervalTarget([int[]]$orig, [double]$speed) {
    , [int[]]@(foreach ($v in $orig) {
            if ($v -eq 0) { 0; continue }
            $t = [math]::Max(1, (Get-EventRoundHalfUp ($v / $speed)))
            if ($t -gt 32767) { $t = [math]::Max($v, 32767) }
            $t
        })
}
# Current taxes (5 groups) and work intervals (500 buildings) of the game.
function Get-EventTaxes { , [int[]]@(foreach ($g in 0..4) { [BitConverter]::ToInt32((Read-Mem ($TaxRva + $g * $ResidentSize) 4), 0) }) }
function Get-EventIntervals {
    $tab = Read-Mem ($BuildingRva + $IntervalOffset) (($BuildingCount - 1) * $BuildingSize + 2)
    , [int[]]@(for ($i = 0; $i -lt $BuildingCount; $i++) { [int][BitConverter]::ToUInt16($tab, $i * $BuildingSize) })
}

# The marker 'EVNT' (RVA 0xE5BD0: 'EVNT', version 1, address of the page) and the page in the game process.
# $create: allocate the page if there is none yet. Returns the page address (0 = none) and configures AnnoEvents.
function Get-EventPage([bool]$create) {
    $m = Read-Mem $EventMarkerRva 16
    $magic = [Text.Encoding]::ASCII.GetString($m, 0, 4)
    if ($magic -eq 'EVNT') { $page = [BitConverter]::ToInt64($m, 8) }
    elseif (@($m | Where-Object { $_ -ne 0 }).Count -eq 0) {
        if (-not $create) { return 0 }
        $p = [AnnoEvents]::VirtualAllocEx($script:h, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x04)   # MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE
        if ($p -eq [IntPtr]::Zero) { Write-Host ((Txt 'Events: no memory for the event state in the game (error {0}); events NOT started.' 'Ereignisse: kein Speicher fuer den Ereignis-Zustand im Spiel (Fehler {0}); Ereignisse NICHT gestartet.') -f [Runtime.InteropServices.Marshal]::GetLastWin32Error()) -ForegroundColor Yellow; return 0 }
        $page = $p.ToInt64()
        Write-Mem ($page - $script:base.ToInt64()) ([byte[]]([Text.Encoding]::ASCII.GetBytes('EVST') + [BitConverter]::GetBytes([int32]1))) $false
        Write-Mem $EventMarkerRva ([byte[]]([Text.Encoding]::ASCII.GetBytes('EVNT') + [BitConverter]::GetBytes([int32]1) + [BitConverter]::GetBytes([long]$page))) $true
    }
    else { Write-Host ((Txt 'Events: unexpected bytes at RVA 0x{0:X} ({1}); events NOT started.' 'Ereignisse: unerwartete Bytes bei RVA 0x{0:X} ({1}); Ereignisse NICHT gestartet.') -f $EventMarkerRva, (Hex $m)) -ForegroundColor Yellow; return 0 }
    [AnnoEvents]::Configure($script:h, $page, $script:base.ToInt64() + $TaxRva, $ResidentSize, $script:base.ToInt64() + $BuildingRva + $IntervalOffset, $BuildingSize, $BuildingCount)
    $hdr = [AnnoEvents]::ReadPage()
    if ($null -eq $hdr -or [Text.Encoding]::ASCII.GetString($hdr, 0, 4) -ne 'EVST') {
        [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0)
        Write-Host ((Txt 'Events: the event state at 0x{0:X} cannot be read; events NOT started.' 'Ereignisse: Ereignis-Zustand bei 0x{0:X} nicht lesbar; Ereignisse NICHT gestartet.') -f $page) -ForegroundColor Yellow
        return 0
    }
    $page
}
# Is the tool window that owns the event state still running?
function Test-EventOwnerAlive([int]$ownerPid) {
    if ($ownerPid -le 0 -or $ownerPid -eq $PID) { return $false }
    $p = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    [bool]($p -and $p.ProcessName -match '^(powershell|pwsh)$')
}
# Event values left behind by a tool window that no longer runs (killed): restore them. Every run of the tool
# does this, also with -Events Off. Returns $false if another running tool window owns the events.
function Repair-EventLeftovers {
    $page = Get-EventPage $false
    if (-not $page) { return $true }
    try {
        $b = [AnnoEvents]::ReadPage()
        $owner = [BitConverter]::ToInt32($b, [AnnoEvents]::OffOwner)
        if (Test-EventOwnerAlive $owner) { return $false }
        if ([BitConverter]::ToInt32($b, [AnnoEvents]::OffTax) -ne 0 -or [BitConverter]::ToInt32($b, [AnnoEvents]::OffProd) -ne 0) {
            $r = [AnnoEvents]::Restore($true, $true)
            Write-Host ((Txt 'Events: an earlier tool window left event values in the game; restored ({0} taxes, {1} work intervals; {2} left alone because the game holds other values).' 'Ereignisse: ein frueheres Werkzeugfenster hat Ereigniswerte im Spiel hinterlassen; zurueckgesetzt ({0} Steuern, {1} Arbeitsintervalle; {2} unberuehrt, weil das Spiel andere Werte hat).') -f $r[0], $r[2], ($r[1] + $r[3])) -ForegroundColor Yellow
        }
        [void][AnnoEvents]::SetOwner(0, [BitConverter]::ToInt32($b, [AnnoEvents]::OffClock))
        $true
    }
    finally { [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0) }
}

# State of the engine. $mean/$duration in game clock units; $seed < 0: random; $first: event ids that come first
# (comma-separated).
function Initialize-EventState([int]$gamePid, [int]$mean, [int]$duration, [int]$seed, [string]$first, [string]$file) {
    $queue = New-Object System.Collections.Generic.Queue[string]
    foreach ($id in ($first -split ',')) {
        $id = $id.Trim()
        if (-not $id) { continue }
        if (-not $EventDefs.Contains($id)) { throw "Unknown event id '$id'." }
        $queue.Enqueue($id)
    }
    $rng = if ($seed -ge 0) { New-Object System.Random $seed } else { New-Object System.Random }
    $script:Ev = @{ Rng = $rng; Script = $queue; Mean = [math]::Max(1, $mean); Duration = [math]::Max(1, $duration); File = $file; GamePid = $gamePid
        LastClock = -1; Progress = 0; Next = 0; Tax = $null; Production = $null; History = (New-Object System.Collections.Generic.List[object])
    }
    $script:Ev.Next = New-EventInterval
}
# Clock units until the next event: 0.5 to 1.5 x the mean.
function New-EventInterval { [math]::Max(1, [int][math]::Round($script:Ev.Mean * (0.5 + $script:Ev.Rng.NextDouble()))) }

# What the engine needs from the game: clock, lock, the human player (kind, gold) and his settlements.
function Get-EventGameState {
    $clock = [BitConverter]::ToInt32((Read-Mem $ClockRva 4), 0)
    $lock = [BitConverter]::ToInt32((Read-Mem $EventLockRva 4), 0)
    $local = [BitConverter]::ToInt32((Read-Mem $EventLocalPlayerRva 4), 0)
    $slot = if ($local -ge 0 -and $local -le 3) { $local } else { 0 }
    $pl = Read-Mem ($EventPlayersRva + $slot * $PlayerSize) 8
    $sb = Read-Mem $EventSettlementRva ($EventSettlementCount * $EventSettlementSize)
    $towns = New-Object System.Collections.Generic.List[object]
    $stage = 0; $residents = 0
    for ($i = 0; $i -lt $EventSettlementCount; $i++) {
        $o = $i * $EventSettlementSize
        # In use: island set (as the game checks) and a name (every new settlement gets one; an empty table is all 0).
        if ($sb[$o + 0x18] -eq 0xFF -or $sb[$o] -eq 0 -or $sb[$o + 0x1A] -ne $slot) { continue }
        $total = [BitConverter]::ToInt32($sb, $o + 0x218)
        for ($k = 0; $k -lt 5; $k++) {
            $n = [BitConverter]::ToInt32($sb, $o + 0x220 + 4 * $k)
            if ($n -gt 0) { $residents += $n; $total += $n; if ($k -gt $stage) { $stage = $k } }
        }
        $len = 0; while ($len -lt 0x18 -and $sb[$o + $len] -ne 0) { $len++ }
        # Storage limit per good as the game computes it (FUN_1400b64d0): +0x20 - 10 t + 10 t x (+0x1FA).
        $limit = [BitConverter]::ToInt32($sb, $o + 0x20) - 0x140 + [BitConverter]::ToUInt16($sb, $o + 0x1FA) * 0x140
        $towns.Add(@{ Offset = $o; Name = [Text.Encoding]::GetEncoding(1252).GetString($sb, $o, $len); Total = $total; Limit = $limit })
    }
    @{ Clock = $clock; Lock = $lock; Slot = $slot; Kind = [BitConverter]::ToInt32($pl, 0); Gold = [BitConverter]::ToInt32($pl, 4)
        GoldAddress = $script:base.ToInt64() + $EventPlayersRva + $slot * $PlayerSize + 4; Towns = $towns; Stage = $stage; Residents = $residents; Settlements = $sb
    }
}

# Trader's gift: the human's largest town and the goods with room for at least 5 t (no random numbers used here).
function Get-EventGiftChoices($g) {
    if (-not $g.Towns.Count) { return @() }
    $town = $g.Towns | Sort-Object { $_.Total } -Descending | Select-Object -First 1
    if ($town.Limit -le 0 -or $town.Limit -gt 65535) { return @() }
    $want = (10 + 5 * $g.Stage) * 32
    @(foreach ($gd in $EventGiftGoods) {
            $stock = [int][BitConverter]::ToUInt16($g.Settlements, $town.Offset + 0x2A + $gd.Good * 12)
            $room = $town.Limit - $stock
            $give = [math]::Min($want, $room); $give -= $give % 32
            if ($give -ge 5 * 32) { @{ Town = $town; Good = $gd; Give = $give } }
        })
}
function Test-EventEligible([string]$id, $g) {
    $d = $EventDefs[$id]
    switch ($d.Kind) {
        'Gold' { if ($id -eq 'warehouse_fire') { return $g.Gold -ge 2000 } else { return $g.Gold -lt 2000000000 } }
        'Tax' {
            if ($script:Ev.Tax -or $g.Residents -le 0) { return $false }
            return @(Get-EventTaxes | Where-Object { $_ -lt 1 -or $_ -gt 1000 }).Count -eq 0
        }
        'Production' {
            if ($script:Ev.Production) { return $false }
            if ([BitConverter]::ToUInt16((Read-Mem ($BuildingRva + 270 * $BuildingSize + $StorageOffset) 2), 0) -eq 0) { return $false }   # haeuser.cod not read
            return @(Get-EventIntervals | Where-Object { $_ -gt 0 }).Count -gt 0
        }
        'Goods' { return @(Get-EventGiftChoices $g).Count -gt 0 }
    }
    $false
}

# events.json (%APPDATA%\Anno1602-Extensions, read by the logbook): { version 1, events [ ... ] }, at most 200,
# newest last, written through a temp file. A missing or broken file starts a new list.
function Add-EventJson($record, [string]$file) {
    if (-not $file) { return }
    try {
        $dir = Split-Path $file
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $list = New-Object System.Collections.Generic.List[object]
        if (Test-Path -LiteralPath $file) {
            try {
                $old = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($old -and $old.events) { foreach ($e in @($old.events)) { if ($e) { $list.Add($e) } } }
            }
            catch { $list.Clear() }
        }
        $list.Add($record)
        Write-EventJsonList $list $file
    }
    catch {
        Write-Host ((Txt 'Events: events.json could not be written: {0}' 'Ereignisse: events.json konnte nicht geschrieben werden: {0}') -f $_.Exception.Message) -ForegroundColor Yellow
    }
}
# Writes the list (the newest 200) through a temp file that replaces events.json.
function Write-EventJsonList($list, [string]$file) {
    $keep = @($list | Select-Object -Last 200)
    $json = ConvertTo-Json -InputObject ([ordered]@{ version = 1; events = $keep }) -Depth 6
    $tmp = "$file.tmp-$PID"
    try {
        [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding $false))
        for ($try = 0; ; $try++) {
            try {
                # [NullString]: PowerShell would pass $null as "" (no backup file wanted).
                if (Test-Path -LiteralPath $file) { [IO.File]::Replace($tmp, $file, [NullString]::Value) } else { [IO.File]::Move($tmp, $file) }
                break
            }
            catch { if ($try -ge 9) { throw }; Start-Sleep -Milliseconds 100 }
        }
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
# A temporary event that ends before its time (game over, another game, the tool stops) gets "endedEarly": true in
# events.json, so the logbook no longer shows it as running.
function Set-EventEndedEarly([string]$id, [long]$ends) {
    $file = $script:Ev.File
    if (-not $file -or -not (Test-Path -LiteralPath $file)) { return }
    try {
        $j = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($e in @($j.events)) { if ($e) { $list.Add($e) } }
        for ($i = $list.Count - 1; $i -ge 0; $i--) {
            $e = $list[$i]
            if ([int]$e.pid -eq $script:Ev.GamePid -and [string]$e.id -eq $id -and [long]$e.endsClock -eq $ends) {
                $e | Add-Member -NotePropertyName endedEarly -NotePropertyValue $true -Force
                Write-EventJsonList $list $file
                return
            }
        }
    }
    catch { Write-Host ((Txt 'Events: events.json could not be written: {0}' 'Ereignisse: events.json konnte nicht geschrieben werden: {0}') -f $_.Exception.Message) -ForegroundColor Yellow }
}
# One event happened: console (UI language) and events.json (both languages).
function Write-EventRecord([string]$id, [int]$clock, [int]$endsClock, $title, $text, $effect, [string]$detail) {
    $rec = [ordered]@{ time = (Get-Date).ToString('s'); pid = $script:Ev.GamePid; clock = $clock; id = $id
        title = [ordered]@{ de = $title.de; en = $title.en }; text = [ordered]@{ de = $text.de; en = $text.en }; effect = [ordered]@{ de = $effect.de; en = $effect.en }
        endsClock = $endsClock
    }
    $script:Ev.History.Add($rec)
    Add-EventJson $rec $script:Ev.File
    Write-Host ''
    Write-Host ((Txt '*** Event: {0} - {1}' '*** Ereignis: {0} - {1}') -f (Txt $title.en (ConvertTo-AsciiGerman $title.de)), (Txt $effect.en (ConvertTo-AsciiGerman $effect.de))) -ForegroundColor Cyan
    Write-Host ('    ' + (Txt $text.en (ConvertTo-AsciiGerman $text.de)))
    if ($detail) { Write-Host ('    ' + $detail) }
}

# Carries out one event. Returns $true if it changed the game.
function Invoke-GameEvent([string]$id, $g) {
    $d = $EventDefs[$id]; $ev = $script:Ev
    switch ($d.Kind) {
        'Gold' {
            if ($id -eq 'patron') { $delta = 2000 * ($g.Stage + 1) }
            else { $delta = - [math]::Max(100, [math]::Min(1000 * ($g.Stage + 1), 10 * [int][math]::Round($g.Gold * 0.05 / 10))) }
            $new = [AnnoEvents]::AddGold($g.GoldAddress, $delta, 0)
            if ($new -eq [long]::MinValue) { return $false }
            $sign = if ($delta -ge 0) { '+' } else { '-' }
            $effect = @{ de = '{0}{1} Gold' -f $sign, (Format-EventNumber $delta 'de'); en = '{0}{1} gold' -f $sign, (Format-EventNumber $delta 'en') }
            Write-EventRecord $id $g.Clock 0 $d.Title $d.Text $effect ((Txt 'Gold now: {0}' 'Gold jetzt: {0}') -f (Format-EventNumber $new $(if ($UiGerman) { 'de' } else { 'en' })))
            return $true
        }
        'Tax' {
            $orig = Get-EventTaxes
            $target = Get-EventTaxTarget $orig $d.Factor
            $ends = $g.Clock + $ev.Duration
            $r = [AnnoEvents]::ApplyTax($orig, $target, $d.Code, [int]($d.Factor * 1000), $ends)
            if ($r -ne 0) { if ($r -ne 1) { Write-Host ((Txt 'Events: taxes not changed ({0}).' 'Ereignisse: Steuern nicht geaendert ({0}).') -f $(if ($r -eq 2) { Txt 'unexpected values' 'unerwartete Werte' } else { Txt 'memory error' 'Speicherfehler' })) -ForegroundColor Yellow }; return $false }
            $ev.Tax = @{ Id = $id; Ends = $ends; Orig = $orig; Target = $target }
            $pct = [int][math]::Round(($d.Factor - 1) * 100); $p = if ($pct -ge 0) { "+$pct" } else { "$pct" }
            $effect = @{ de = "Steuern $p % für 1 Spielstunde"; en = "Taxes $p% for 1 game hour" }
            Write-EventRecord $id $g.Clock $ends $d.Title $d.Text $effect ((Txt 'Taxes per group now {0} instead of {1}, until game clock {2}.' 'Steuern je Gruppe jetzt {0} statt {1}, bis Spieluhr {2}.') -f ($target -join '/'), ($orig -join '/'), $ends)
            return $true
        }
        'Production' {
            $orig = Get-EventIntervals
            $target = Get-EventIntervalTarget $orig $d.Factor
            $ends = $g.Clock + $ev.Duration
            $r = [AnnoEvents]::ApplyProduction($orig, $target, $d.Code, [int]($d.Factor * 1000), $ends)
            if ($r -ne 0) { if ($r -ne 1) { Write-Host ((Txt 'Events: work intervals not changed ({0}).' 'Ereignisse: Arbeitsintervalle nicht geaendert ({0}).') -f $(if ($r -eq 2) { Txt 'unexpected values' 'unerwartete Werte' } else { Txt 'memory error' 'Speicherfehler' })) -ForegroundColor Yellow }; return $false }
            $n = 0; for ($i = 0; $i -lt $orig.Count; $i++) { if ($orig[$i] -ne $target[$i]) { $n++ } }
            $ev.Production = @{ Id = $id; Ends = $ends; Changed = $n }
            $pct = [int][math]::Round(($d.Factor - 1) * 100); $p = if ($pct -ge 0) { "+$pct" } else { "$pct" }
            $effect = @{ de = "Produktion $p % für 1 Spielstunde"; en = "Production $p% for 1 game hour" }
            Write-EventRecord $id $g.Clock $ends $d.Title $d.Text $effect ((Txt '{0} work intervals changed until game clock {1}.' '{0} Arbeitsintervalle geaendert bis Spieluhr {1}.') -f $n, $ends)
            return $true
        }
        'Goods' {
            $choices = @(Get-EventGiftChoices $g)
            if (-not $choices.Count) { return $false }
            $c = $choices[$ev.Rng.Next($choices.Count)]
            $address = $script:base.ToInt64() + $EventSettlementRva + $c.Town.Offset + 0x2A + $c.Good.Good * 12
            $added = [AnnoEvents]::AddStock($address, $c.Give, $c.Town.Limit)
            if ($added -le 0) { return $false }
            $t = [math]::Floor($added / 32)
            $text = @{ de = $d.Text.de -f $t, $c.Good.De, $c.Town.Name; en = $d.Text.en -f $t, $c.Good.En, $c.Town.Name }
            $effect = @{ de = "+$t t $($c.Good.De)"; en = "+$t t $($c.Good.En)" }
            Write-EventRecord $id $g.Clock 0 $d.Title $text $effect ''
            return $true
        }
    }
    $false
}

# The next event: first the ids of -EventScript (one that is not possible right now is skipped), then by weight
# among the possible ones. Returns the id or $null.
function Start-NextEvent($g) {
    $ev = $script:Ev
    while ($ev.Script.Count -gt 0) {
        $id = $ev.Script.Dequeue()
        if ((Test-EventEligible $id $g) -and (Invoke-GameEvent $id $g)) { return $id }
        Write-Host ((Txt 'Events: {0} is not possible right now; skipped.' 'Ereignisse: {0} ist gerade nicht moeglich; uebersprungen.') -f $id)
    }
    $ids = @($EventDefs.Keys | Where-Object { Test-EventEligible $_ $g })
    if (-not $ids.Count) { return $null }
    $sum = 0; foreach ($id in $ids) { $sum += $EventDefs[$id].Weight }
    $r = $ev.Rng.Next($sum)
    foreach ($id in $ids) { $r -= $EventDefs[$id].Weight; if ($r -lt 0) { break } }
    if (Invoke-GameEvent $id $g) { return $id }
    $null
}

# Ends temporary events and restores the values. $why: Over (time is up), Session (other game loaded or started),
# Ended (game over), Exit (the tool stops). $only: 'Tax' or 'Production' (default both).
function Stop-TemporaryEvents([string]$why, [string]$only = '') {
    $ev = $script:Ev
    foreach ($kind in @(if ($only) { $only } else { 'Tax', 'Production' })) {
        $t = $ev[$kind]
        if (-not $t) { continue }
        $r = [AnnoEvents]::Restore($kind -eq 'Tax', $kind -eq 'Production')
        $ev[$kind] = $null
        $d = $EventDefs[$t.Id]; $name = Txt $d.Title.en (ConvertTo-AsciiGerman $d.Title.de)
        $what = if ($kind -eq 'Tax') { (Txt 'taxes back to {0}' 'Steuern wieder {0}') -f ($t.Orig -join '/') } else { (Txt '{0} work intervals back to normal' '{0} Arbeitsintervalle wieder normal') -f $r[2] }
        $msg = switch ($why) {
            'Over' { (Txt 'Event over: {0} - {1}.' 'Ereignis vorbei: {0} - {1}.') -f $name, $what }
            'Session' { (Txt 'Event ended early (another game was started or loaded): {0} - {1}.' 'Ereignis vorzeitig beendet (anderes Spiel gestartet oder geladen): {0} - {1}.') -f $name, $what }
            'Ended' { (Txt 'Event ended with the game: {0} - {1}.' 'Ereignis mit dem Spiel beendet: {0} - {1}.') -f $name, $what }
            default { (Txt 'Event ended because this window closes: {0} - {1}.' 'Ereignis beendet, weil dieses Fenster schliesst: {0} - {1}.') -f $name, $what }
        }
        Write-Host $msg -ForegroundColor Cyan
        if ($why -ne 'Over') { Set-EventEndedEarly $t.Id $t.Ends }
        $left = $r[1] + $r[3]
        if ($left) { Write-Host ((Txt 'Events: {0} value(s) had been changed by someone else meanwhile and were left alone.' 'Ereignisse: {0} Wert(e) wurden inzwischen anderweitig geaendert und blieben unberuehrt.') -f $left) -ForegroundColor Yellow }
    }
}

# One poll of the engine. $elapsedMs: real time since the previous poll (bounds a plausible clock step).
function Invoke-EventTick([double]$elapsedMs) {
    $ev = $script:Ev
    $g = Get-EventGameState
    $prev = $ev.LastClock
    $continuous = $false
    if ($prev -ge 0) {
        $maxStep = [math]::Ceiling($elapsedMs / 1000.0 * $EventMaxClockPerSecond) + $EventClockSlack
        if ($g.Clock -lt $prev -or $g.Clock - $prev -gt $maxStep) {
            # Command 0x36 (new game, loading a savegame) resets the clock; a big jump means another game as well.
            Stop-TemporaryEvents 'Session'
            $ev.Progress = 0; $ev.Next = New-EventInterval
        }
        else { $continuous = $true }
    }
    $ev.LastClock = $g.Clock
    [void][AnnoEvents]::SetOwner($PID, $g.Clock)
    if ($g.Clock -gt 0 -and ($g.Lock -ne 0 -or $g.Kind -eq 9)) {
        Stop-TemporaryEvents 'Ended'
        $ev.Progress = 0
        return
    }
    foreach ($kind in 'Tax', 'Production') { if ($ev[$kind] -and $g.Clock -ge $ev[$kind].Ends) { Stop-TemporaryEvents 'Over' $kind } }
    # Only a running game with an advancing clock and a town of the human counts towards the next event.
    if (-not ($continuous -and $g.Clock -gt $prev -and $g.Lock -eq 0 -and $g.Kind -eq 0 -and $g.Towns.Count -gt 0)) { return }
    $ev.Progress += $g.Clock - $prev
    if ($ev.Progress -lt $ev.Next) { return }
    $ev.Progress = 0
    $ev.Next = New-EventInterval
    [void](Start-NextEvent $g)
}

# Runs the events until the game exits (or, in tests, until the clock reaches -EventTestUntilClock). Restores
# everything temporary before it returns.
# --- Supply for ambitious rivals (-RivalGrowth Ambitious, 3.4) ------------------------------------
# Measured in the game (2026-11-22, docs\FINDINGS.md "Ambitious rivals"): the main towns of the AI wait in phase 0x1F
# for 2 of the 3 goods spices, tobacco goods and liquor (20 t without an own workshop) and never build those chains, so
# they stop at 34 settler houses; and they hardly make bricks, so even with the goods the AI's building jobs (tavern,
# school, ...) stop at the first one it cannot pay - 40 t of bricks given in the game gave every rival capital a tavern
# and the first citizens within 3 minutes. While the game runs, this window therefore tops up the goods of every town of
# a computer rival (player kind 0xC) that has settlers or more: a good below 20 t is filled up to 30 t (at most the
# town's storage limit), at most once per 2000 clock steps (about 4 game minutes): tools, bricks, cloth, liquor, tobacco
# goods and spices from settlers on, cocoa from citizens, clothes and jewellery from merchants. Their gold is not touched.
$SupplyGoods = @(@{ Good = 22; Stage = 1 }, @{ Good = 24; Stage = 1 }, @{ Good = 19; Stage = 1 }, @{ Good = 18; Stage = 1 }, @{ Good = 15; Stage = 1 }, @{ Good = 16; Stage = 1 }, @{ Good = 17; Stage = 2 }, @{ Good = 20; Stage = 3 }, @{ Good = 21; Stage = 3 })
$SupplyBelow = 640; $SupplyTo = 960; $SupplyEveryClock = 2000
$script:SupplyClock = -1; $script:SupplyTons = 0; $script:SupplyReported = 0
# One supply round (needs $script:h and $script:base). Returns the tons delivered.
function Invoke-RivalSupply {
    $clock = [BitConverter]::ToInt32((Read-Mem $ClockRva 4), 0)
    if ($clock -le 0 -or [BitConverter]::ToInt32((Read-Mem $EventLockRva 4), 0) -ne 0) { return 0 }
    if ($script:SupplyClock -ge 0 -and $clock -ge $script:SupplyClock -and $clock - $script:SupplyClock -lt $SupplyEveryClock) { return 0 }
    $script:SupplyClock = $clock
    $pl = Read-Mem $EventPlayersRva (4 * $PlayerSize)
    $sb = Read-Mem $EventSettlementRva ($EventSettlementCount * $EventSettlementSize)
    $tons = 0
    for ($i = 0; $i -lt $EventSettlementCount; $i++) {
        $o = $i * $EventSettlementSize
        if ($sb[$o + 0x18] -eq 0xFF -or $sb[$o] -eq 0) { continue }
        $owner = [int]$sb[$o + 0x1A]
        if ($owner -lt 1 -or $owner -gt 3 -or [BitConverter]::ToInt32($pl, $owner * $PlayerSize) -ne 12) { continue }
        $stage = -1; for ($k = 0; $k -lt 5; $k++) { if ([BitConverter]::ToInt32($sb, $o + 0x220 + 4 * $k) -gt 0) { $stage = $k } }
        if ($stage -lt 1) { continue }
        $limit = [BitConverter]::ToInt32($sb, $o + 0x20) - 0x140 + [BitConverter]::ToUInt16($sb, $o + 0x1FA) * 0x140
        $to = [math]::Min($SupplyTo, $limit)
        foreach ($gd in $SupplyGoods) {
            if ($stage -lt $gd.Stage) { continue }
            $off = $o + 0x2A + $gd.Good * 12; $stock = [int][BitConverter]::ToUInt16($sb, $off)
            if ($stock -ge $SupplyBelow -or $to -le $stock) { continue }
            Write-Mem ($EventSettlementRva + $off) ([BitConverter]::GetBytes([uint16]$to)) $false
            $tons += ($to - $stock) / 32
        }
    }
    $script:SupplyTons += $tons
    $tons
}
# Called by the waiting loops; reports every 50 t delivered.
function Invoke-RivalSupplyTick {
    if ($RivalGrowth -ne 'Ambitious') { return }
    try { [void](Invoke-RivalSupply) } catch { return }
    if ($script:SupplyTons -ge $script:SupplyReported + 50) {
        $script:SupplyReported = $script:SupplyTons
        Write-Host ((Txt 'Supply for the rivals: {0:0} t of luxury goods so far.' 'Nachschub fuer die Gegner: bisher {0:0} t Luxuswaren.') -f $script:SupplyTons)
    }
}

# --- All islands explored (-Explored All, 3.5) -----------------------------------------------------
# Island table RVA 0x62DDC0, 50 slots of 0x2CC8 (tiles at +0x2CB0, 0 = free slot); +0x43 holds one bit per player that
# knows the island. The game sets it in FUN_140077210 when a ship reaches the island (and reports the natives there to
# the local player); FUN_1400c6c50 draws an island the local player knows with its explored tiles (+0x2CB0, ore and
# gold deposits) instead of +0x2CC0. This window sets the local player's bit on every island while the game runs (new
# games and loaded ones; once set, the game keeps it and stores it in the savegame).
$ExploreIslandRva = 0x62DDC0; $ExploreIslandSize = 0x2CC8; $ExploreIslandCount = 50; $ExploreBitOffset = 0x43; $ExploreTilesOffset = 0x2CB0
$script:ExploredTotal = 0
# One round (needs $script:h and $script:base). Returns the number of islands newly marked.
function Invoke-Explore {
    if ([BitConverter]::ToInt32((Read-Mem $ClockRva 4), 0) -le 0) { return 0 }
    $me = (Read-Mem $EventLocalPlayerRva 1)[0]
    if ($me -gt 3) { return 0 }
    $bit = [byte](1 -shl $me)
    $t = Read-Mem $ExploreIslandRva ($ExploreIslandCount * $ExploreIslandSize)
    $n = 0
    for ($i = 0; $i -lt $ExploreIslandCount; $i++) {
        $o = $i * $ExploreIslandSize
        if ([BitConverter]::ToInt64($t, $o + $ExploreTilesOffset) -eq 0) { continue }
        $v = $t[$o + $ExploreBitOffset]
        if (($v -band $bit) -ne 0) { continue }
        Write-Mem ($ExploreIslandRva + $o + $ExploreBitOffset) ([byte[]]@([byte]($v -bor $bit))) $false
        $n++
    }
    $n
}
# Called by the waiting loops.
function Invoke-ExploreTick {
    if ($Explored -ne 'All') { return }
    $n = 0
    try { $n = Invoke-Explore } catch { return }
    if ($n -gt 0) {
        $script:ExploredTotal += $n
        Write-Host ((Txt 'Islands explored: {0} more ({1} in this session) - their ore and gold deposits are visible.' 'Inseln erkundet: {0} weitere ({1} in dieser Sitzung) - ihre Erz- und Goldvorkommen sind sichtbar.') -f $n, $script:ExploredTotal)
    }
}

# --- Perfect home island (-HomeIsland Perfect, 3.6) ------------------------------------------------
# At the start of a new game (game clock at most $HomeClockMax) the island of the home file (island record +0x18 class 4,
# +0x1A file 28, +0x1C climate 0) gets: deposits on its four ore mountains (slots of 8 bytes at +0x20, as the SZENE loader
# FUN_1400d0de0 writes them: +0 ware 2 ore / 3 gold (= building +0x21 of the mine; FUN_14009ebb0 only finds a deposit of
# the mine's ware), +1 x, +2 y, +4 kind 0 large / 1 small or gold, +6 amount x 32: ore 240 t large, gold 50 t kind 1 like
# the loader - a gold mine never uses it up (FUN_1400b9ed0); count +0x41 = 4), every crop at 100 % (+0x5C bits 1-6 =
# tobacco, spices, sugar cane, cotton, wine, cocoa; FUN_14009db40) and the local player's explored bit (+0x43). Once per
# island in a session; loaded games (later clock) only get the repair below.
# 3.6.0 wrote the two gold deposits as small ore deposits (ware 2, kind 1, 80 t). In a game with a later clock the tool
# turns exactly these two slots (ware 2, kind 1, 0xA00 on the third or fourth mountain) into gold, once per island.
$HomeClockMax = 3000; $HomeDepositWares = @(2, 2, 3, 3); $HomeDepositKinds = @(0, 0, 1, 1); $HomeDepositAmounts = @(0x1E00, 0x1E00, 0x640, 0x640); $HomeCropBits = 0x7E
$script:HomeDone = @{}; $script:HomeChecked = @{}
# One round (needs $script:h and $script:base). Returns 1 if the home island was set up now, 2 if the gold deposits of a
# 3.6.0 game were repaired now, else 0.
function Invoke-Home {
    if (-not $HomeInfo) { return 0 }
    $clock = [BitConverter]::ToInt32((Read-Mem $ClockRva 4), 0)
    if ($clock -le 0) { return 0 }
    $me = (Read-Mem $EventLocalPlayerRva 1)[0]
    $t = Read-Mem $ExploreIslandRva ($ExploreIslandCount * $ExploreIslandSize)
    for ($i = 0; $i -lt $ExploreIslandCount; $i++) {
        $o = $i * $ExploreIslandSize
        $tiles = [BitConverter]::ToInt64($t, $o + $ExploreTilesOffset)
        if ($tiles -eq 0 -or [BitConverter]::ToUInt16($t, $o + 0x18) -ne 4 -or [BitConverter]::ToUInt16($t, $o + 0x1A) -ne $HomeFileNumber -or $t[$o + 0x1C] -ne 0) { continue }
        if ([BitConverter]::ToInt32($t, $o + 0xC) -ne $HomeInfo.W -or [BitConverter]::ToInt32($t, $o + 0x10) -ne $HomeInfo.H) { continue }
        $key = [string]$tiles
        $rec = $ExploreIslandRva + $o
        if ($clock -le $HomeClockMax -and -not $script:HomeDone.ContainsKey($key)) {
            $slots = New-Object byte[] 32
            for ($k = 0; $k -lt 4; $k++) {
                $slots[$k * 8] = [byte]$HomeDepositWares[$k]; $slots[$k * 8 + 1] = [byte]$HomeInfo.Ore[$k][0]; $slots[$k * 8 + 2] = [byte]$HomeInfo.Ore[$k][1]
                $slots[$k * 8 + 4] = [byte]$HomeDepositKinds[$k]
                [Array]::Copy([BitConverter]::GetBytes([uint16]$HomeDepositAmounts[$k]), 0, $slots, $k * 8 + 6, 2)
            }
            Write-Mem ($rec + 0x20) $slots $false
            Write-Mem ($rec + 0x41) ([byte[]]@(4)) $false
            Write-Mem ($rec + 0x5C) ([BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($t, $o + 0x5C) -bor $HomeCropBits))) $false
            if ($me -le 3) { Write-Mem ($rec + $ExploreBitOffset) ([byte[]]@([byte]($t[$o + $ExploreBitOffset] -bor (1 -shl $me)))) $false }
            $script:HomeDone[$key] = $true; $script:HomeChecked[$key] = $true
            return 1
        }
        if ($script:HomeDone.ContainsKey($key) -or $script:HomeChecked.ContainsKey($key)) { return 0 }
        $script:HomeChecked[$key] = $true
        $fixed = 0
        # At most 4 slots (+0x20 .. +0x3F; +0x40 and the count +0x41 follow).
        for ($k = 0; $k -lt [math]::Min([int]$t[$o + 0x41], 4); $k++) {
            $s = $o + 0x20 + 8 * $k
            if ($t[$s] -ne 2 -or $t[$s + 4] -ne 1 -or [BitConverter]::ToUInt16($t, $s + 6) -ne 0xA00) { continue }
            if (-not @(2, 3 | Where-Object { $HomeInfo.Ore[$_][0] -eq $t[$s + 1] -and $HomeInfo.Ore[$_][1] -eq $t[$s + 2] }).Count) { continue }
            Write-Mem ($rec + 0x20 + 8 * $k) ([byte[]]@(3)) $false
            Write-Mem ($rec + 0x26 + 8 * $k) ([BitConverter]::GetBytes([uint16]0x640)) $false
            $fixed++
        }
        if ($fixed) { return 2 }
        return 0
    }
    0
}
# Called by the waiting loops.
function Invoke-HomeTick {
    if ($HomeIsland -ne 'Perfect') { return }
    $n = 0
    try { $n = Invoke-Home } catch { return }
    if ($n -eq 1) { Write-Host (Txt 'Home island: 2 ore and 2 gold deposits on its four mountains, every crop at 100 %, explored.' 'Heimatinsel: 2 Erz- und 2 Goldvorkommen auf den vier Bergen, jede Pflanze zu 100 %, erkundet.') -ForegroundColor Green }
    elseif ($n -eq 2) { Write-Host (Txt 'Home island: the two gold deposits of a game from version 3.6.0 repaired (they were small ore deposits).' 'Heimatinsel: die zwei Goldvorkommen eines Spiels aus Version 3.6.0 berichtigt (es waren kleine Erzvorkommen).') -ForegroundColor Green }
}

function Invoke-EventLoop($proc) {
    $script:h = [AnnoMem]::OpenProcess(0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $proc.Id)
    if ($script:h -eq [IntPtr]::Zero) {
        Write-Host ((Txt 'Events: access to the game denied (error {0}); no events.' 'Ereignisse: Zugriff auf das Spiel verweigert (Fehler {0}); keine Ereignisse.') -f [Runtime.InteropServices.Marshal]::GetLastWin32Error()) -ForegroundColor Yellow
        if ($TestProcessId -eq 0) { while (-not $proc.HasExited) { Start-Sleep -Seconds 2; $proc.Refresh() } }
        return
    }
    $on = $false
    try {
        if (-not (Repair-EventLeftovers)) {
            Write-Host (Txt 'Events: another tool window already runs the events for this game; none from this window.' 'Ereignisse: ein anderes Werkzeugfenster fuehrt die Ereignisse fuer dieses Spiel schon; keine aus diesem Fenster.') -ForegroundColor Yellow
        }
        elseif (Get-EventPage $true) {
            $mean = if ($EventIntervalClock -gt 0) { $EventIntervalClock } else { $EventMean[$Events] }
            $duration = if ($EventDurationClock -gt 0) { $EventDurationClock } else { $EventDuration }
            $file = if ($EventFile) { $EventFile } elseif ($TestProcessId -eq 0) { Join-Path $env:APPDATA 'Anno1602-Extensions\events.json' } else { '' }
            Initialize-EventState $proc.Id $mean $duration $EventSeed $EventScript $file
            [void][AnnoEvents]::SetOwner($PID, 0)
            [AnnoEvents]::InstallConsoleHandler()
            $on = $true
            Write-Host ((Txt 'Events are on ({0}). The first one comes once you have a town; close this window only after the game.' 'Ereignisse sind an ({0}). Das erste kommt, sobald du eine Stadt hast; dieses Fenster erst nach dem Spiel schliessen.') -f (Get-ValueName $Events)) -ForegroundColor Green
        }
        $poll = if ($EventPollMs -gt 0) { $EventPollMs } else { 1000 }
        $sw = [Diagnostics.Stopwatch]::StartNew(); $last = 0; $errors = 0
        while (Test-Running) {
            Start-Sleep -Milliseconds $poll
            if (-not (Test-Running)) { break }
            if ($TestProcessId -ne 0 -and ((Get-Date) -gt $script:deadline -or ($EventTestUntilClock -gt 0 -and [BitConverter]::ToInt32((Read-Mem $ClockRva 4), 0) -ge $EventTestUntilClock))) { break }
            Invoke-RivalSupplyTick
            Invoke-ExploreTick
            Invoke-HomeTick
            if (-not $on) { continue }
            $now = $sw.ElapsedMilliseconds
            try { Invoke-EventTick ($now - $last); $errors = 0 }
            catch {
                if (-not (Test-Running)) { break }
                $errors++
                Write-Host ((Txt 'Events: {0}' 'Ereignisse: {0}') -f $_.Exception.Message) -ForegroundColor Yellow
                if ($errors -ge 10) { Stop-TemporaryEvents 'Exit'; [void][AnnoEvents]::Stop(); $on = $false; Write-Host (Txt 'Events: stopped after repeated errors.' 'Ereignisse: nach wiederholten Fehlern beendet.') -ForegroundColor Yellow }
            }
            $last = $now
        }
    }
    finally {
        if ($on) {
            if (Test-Running) { Stop-TemporaryEvents 'Exit' }
            [void][AnnoEvents]::Stop()
        }
        [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0)
        [void][AnnoMem]::CloseHandle($script:h)
    }
}

# Patches the process behind $script:h. Returns $true = done, $false = the process exited before.
function Invoke-Patch($proc) {
    # --- 4. First check all sites, then write (all or nothing) -------------------------------
    foreach ($s in $Patches) {
        $actual = Hex (Read-Mem $s.Rva $s.Size)
        if ($actual -ne $s.Original -and $actual -ne (Hex $s.Target)) { throw (Txt "Unexpected bytes in memory at $($s.Name) ($actual). Aborted, nothing changed." "Im Speicher stehen an $($s.Name) unerwartete Bytes ($actual). Abbruch, nichts geaendert.") }
    }
    # Variables: 0 (game still starting), original value or already the target value.
    foreach ($v in $Variables) {
        $actual = Hex (Read-Mem $v.Rva 4)
        if ($actual -ne $null4 -and $actual -ne (Hex $orig[$v.Kind]) -and $actual -ne (Hex $values[$v.Kind])) {
            throw (Txt "Variable $($v.Name.Trim()) has an unexpected value ($actual). Aborted, nothing changed." "Variable $($v.Name.Trim()) hat einen unerwarteten Wert ($actual). Abbruch, nichts geaendert.")
        }
    }
    # If a game with 500 x 350 is already running, grid and size would no longer fit together.
    $widthNow = [BitConverter]::ToInt32((Read-Mem $Variables[0].Rva 4), 0)
    $age = [TimeSpan]::Zero
    try { $age = (Get-Date) - $proc.StartTime } catch { }
    if ($TestProcessId -eq 0 -and $widthNow -ne 0 -and $widthNow -ne $Width -and $age.TotalSeconds -gt 120 -and -not $GameAlreadyRunning) {
        $en = 'The game has been running for {0:0} minutes. If a map is loaded right now, switching would be dangerous. ' +
            'Quit the game, start the tool, then start the game. (If it is surely in the main menu: -GameAlreadyRunning.) Aborted, nothing changed.'
        $de = 'Das Spiel laeuft schon seit {0:0} Minuten. Wenn gerade eine Karte geladen ist, waere das Umstellen gefaehrlich. ' +
            'Spiel beenden, Werkzeug starten, dann Spiel starten. (Steht es sicher im Hauptmenue: -GameAlreadyRunning.) Abbruch, nichts geaendert.'
        throw ((Txt $en $de) -f $age.TotalMinutes)
    }

    $written = New-Object System.Collections.ArrayList
    try {
        foreach ($s in $Patches) {
            $before = Read-Mem $s.Rva $s.Size
            Write-Mem $s.Rva $s.Target $true
            if ($s.Writable) {
                # The game itself writes here (a flag of a code cave): the page stays writable (PAGE_EXECUTE_READWRITE).
                $old = [uint32]0
                if (-not [AnnoMem]::VirtualProtectEx($script:h, [IntPtr]($script:base.ToInt64() + $s.Rva), [IntPtr]$s.Size, 0x40, [ref]$old)) { throw ((Txt 'Page at RVA 0x{0:X} cannot be made writable (error {1}).' 'Seite bei RVA 0x{0:X} nicht beschreibbar (Fehler {1}).') -f $s.Rva, [Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
            }
            [void]$written.Add(@{ Rva = $s.Rva; Old = $before })
            $new = Read-Mem $s.Rva $s.Size
            if ((Hex $new) -ne (Hex $s.Target)) { throw (Txt "Check at $($s.Name) failed ($(Hex $new))." "Kontrolle an $($s.Name) fehlgeschlagen ($(Hex $new)).") }
            Write-Host ("  {0}: {1}" -f $s.Name, (Format-Patch $s $new))
        }
    }
    catch {
        if (-not (Test-Running)) { return $false }
        Write-Host (Txt 'Error while writing, rolling back ...' 'Fehler beim Schreiben, baue zurueck ...') -ForegroundColor Red
        for ($i = $written.Count - 1; $i -ge 0; $i--) {
            try { Write-Mem $written[$i].Rva $written[$i].Old $true } catch { Write-Host (Txt "  Rollback at RVA 0x$('{0:X}' -f $written[$i].Rva) failed: $_" "  Rueckbau bei RVA 0x$('{0:X}' -f $written[$i].Rva) fehlgeschlagen: $_") -ForegroundColor Red }
        }
        throw
    }

    # --- 5. Wait until the game has set its start values, then set the variables --------------
    while ((Hex (Read-Mem $RvaStartDone 4)) -eq $null4) {
        if (-not (Test-Running)) { return $false }
        if ((Get-Date) -gt $script:deadline) { Write-Host (Txt 'The game has not set its start values yet; setting the variables anyway.' 'Spiel hat seine Startwerte noch nicht gesetzt; setze die Variablen trotzdem.') -ForegroundColor Yellow; break }
        Start-Sleep -Milliseconds 100
    }
    foreach ($v in $Variables) { Write-Mem $v.Rva $values[$v.Kind] $false }
    foreach ($v in $Variables) {
        $new = Read-Mem $v.Rva 4
        if ((Hex $new) -ne (Hex $values[$v.Kind])) { throw (Txt "Check of variable $($v.Name.Trim()) failed ($(Hex $new))." "Kontrolle der Variable $($v.Name.Trim()) fehlgeschlagen ($(Hex $new)).") }
    }
    $w = [BitConverter]::ToInt32((Read-Mem $Variables[0].Rva 4), 0)
    $hh = [BitConverter]::ToInt32((Read-Mem $Variables[1].Rva 4), 0)
    Write-Host (Txt "Current map size in the game: $w x $hh" "Aktuelle Kartengroesse im Spiel: $w x $hh") -ForegroundColor Green
    Write-Host ((Txt 'Scroll range: {0}, minimap scale: {1} / {2}' 'Scrollbereich: {0}, Minikarten-Massstab: {1} / {2}') -f (Format-Value 'Range' (Read-Mem $Variables[2].Rva 4)),
        (Format-Value 'InvWidth' (Read-Mem $Variables[3].Rva 4)), (Format-Value 'InvHeight' (Read-Mem $Variables[4].Rva 4))) -ForegroundColor Green
    # Event values that a killed tool window left in this game process (any -Events setting), before the table
    # options below compare taxes and intervals with their originals.
    [void](Repair-EventLeftovers)

    # --- Ship speed: wait until figuren.cod has been read, then set the ship values -------------
    if ($ShipSpeed -ne 1.0) {
        $speedOk = $true
        while ($true) {
            $ready = $true
            foreach ($nr in $ShipSpeedOrig.Keys) {
                $actual = Hex (Read-Mem ($FigureRva + $nr * $FigureSize + $SpeedOffset) 4)
                if ($actual -eq $null4) { $ready = $false; break }
                if ($actual -ne $ShipSpeedOrig[$nr] -and $actual -ne (Hex (Get-ShipSpeedBytes $ShipSpeedOrig[$nr] $ShipSpeed))) {
                    Write-Host (Txt "Ship value no. $nr has an unexpected value ($actual); ship speed NOT set (the rest is active)." "Schiffswert Nr. $nr hat einen unerwarteten Wert ($actual); Schiffstempo NICHT gesetzt (Rest ist aktiv).") -ForegroundColor Yellow
                    $speedOk = $false; break
                }
            }
            if ($ready -or -not $speedOk) { break }
            if (-not (Test-Running)) { return $false }
            if ((Get-Date) -gt $script:deadline) { Write-Host (Txt 'Ship values not loaded yet; ship speed NOT set.' 'Schiffswerte noch nicht geladen; Schiffstempo NICHT gesetzt.') -ForegroundColor Yellow; $speedOk = $false; break }
            Start-Sleep -Milliseconds 100
        }
        if ($speedOk) {
            foreach ($nr in $ShipSpeedOrig.Keys) { Write-Mem ($FigureRva + $nr * $FigureSize + $SpeedOffset) (Get-ShipSpeedBytes $ShipSpeedOrig[$nr] $ShipSpeed) $false }
            foreach ($nr in $ShipSpeedOrig.Keys) {
                $new = Read-Mem ($FigureRva + $nr * $FigureSize + $SpeedOffset) 4
                if ((Hex $new) -ne (Hex (Get-ShipSpeedBytes $ShipSpeedOrig[$nr] $ShipSpeed))) { throw (Txt "Check of ship speed no. $nr failed ($(Hex $new))." "Kontrolle Schiffstempo Nr. $nr fehlgeschlagen ($(Hex $new)).") }
            }
            Write-Host ((Txt 'Ship speed x{0:0.##}: small trading ship {1:0.####} instead of 0.05 (12 ship values set).' 'Schiffstempo x{0:0.##}: kleines Handelsschiff {1:0.####} statt 0.05 (12 Schiffswerte gesetzt).') -f $ShipSpeed,
                [BitConverter]::ToSingle((Read-Mem ($FigureRva + 21 * $FigureSize + $SpeedOffset) 4), 0)) -ForegroundColor Green
        }
    }

    # --- Storage: wait until haeuser.cod has been read, then set the storage values -------------
    if ($Storage -ne 1) {
        $storageOk = $true
        while ($true) {
            $ready = $true
            foreach ($nr in $StorageOrig.Keys) {
                $actual = [BitConverter]::ToUInt16((Read-Mem ($BuildingRva + $nr * $BuildingSize + $StorageOffset) 2), 0)
                if ($actual -eq 0) { $ready = $false; break }
                if ($actual -ne $StorageOrig[$nr] -and $actual -ne $StorageOrig[$nr] * $Storage) {
                    Write-Host (Txt "Storage value no. $nr has an unexpected value ($actual); storage NOT set (the rest is active)." "Lagerwert Nr. $nr hat einen unerwarteten Wert ($actual); Lager NICHT gesetzt (Rest ist aktiv).") -ForegroundColor Yellow
                    $storageOk = $false; break
                }
            }
            if ($ready -or -not $storageOk) { break }
            if (-not (Test-Running)) { return $false }
            if ((Get-Date) -gt $script:deadline) { Write-Host (Txt 'Building values not loaded yet; storage NOT set.' 'Gebaeudewerte noch nicht geladen; Lager NICHT gesetzt.') -ForegroundColor Yellow; $storageOk = $false; break }
            Start-Sleep -Milliseconds 100
        }
        if ($storageOk) {
            foreach ($nr in $StorageOrig.Keys) { Write-Mem ($BuildingRva + $nr * $BuildingSize + $StorageOffset) ([BitConverter]::GetBytes([uint16]($StorageOrig[$nr] * $Storage))) $false }
            foreach ($nr in $StorageOrig.Keys) {
                $new = [BitConverter]::ToUInt16((Read-Mem ($BuildingRva + $nr * $BuildingSize + $StorageOffset) 2), 0)
                if ($new -ne $StorageOrig[$nr] * $Storage) { throw (Txt "Check of storage no. $nr failed ($new)." "Kontrolle Lager Nr. $nr fehlgeschlagen ($new).") }
            }
            Write-Host ((Txt 'Storage x{0}: trading post I-IV {1}/{2}/{3}/{4} t, market {5} t (7 values set).' 'Lager x{0}: Kontor I-IV {1}/{2}/{3}/{4} t, Markt {5} t (7 Werte gesetzt).') -f $Storage, (30 * $Storage), (50 * $Storage), (75 * $Storage), (100 * $Storage), (10 * $Storage)) -ForegroundColor Green
        }
    }

    # --- Residents, cargo, production: wait until the .cod values have been read ---------------
    if ($Residents -ne 1.0) {
        $e = foreach ($nr in 0..4) { @{ Rva = $ResidentRva + $nr * $ResidentSize; Orig = $ResidentOrig[$nr]; Target = [int][math]::Round($ResidentOrig[$nr] * $Residents); Bytes = 4 } }
        $r = Set-TableValues (Txt 'Residents' 'Einwohner') $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt 'Residents x{0:0.##}: at most {1} per house (5 values set).' 'Einwohner x{0:0.##}: hoechstens {1} je Haus (5 Werte gesetzt).') -f $Residents, (($e | ForEach-Object { [math]::Round($_.Target / 64, 1) }) -join '/')) -ForegroundColor Green }
    }
    if ($Cargo -ne 1.0) {
        $e = foreach ($nr in ($CargoOrig.Keys | Sort-Object)) { @{ Rva = $FigureRva + $nr * $FigureSize + $CargoOffset; Orig = $CargoOrig[$nr]; Target = (Get-CargoHolds $CargoOrig[$nr] $Cargo); Bytes = 2 } }
        $r = Set-TableValues (Txt 'Cargo' 'Laderaum') $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt 'Cargo x{0:0.##}: {1} holds of 50 t (small/large trading ship, small/large war ship; 8 ship values set).' 'Laderaum x{0:0.##}: {1} Laderaeume zu 50 t (kleines/grosses Handelsschiff, kleines/grosses Kriegsschiff; 8 Schiffswerte gesetzt).') -f $Cargo, (($e | Select-Object -Index 0, 2, 4, 6 | ForEach-Object { $_.Target }) -join '/')) -ForegroundColor Green }
    }
    if ($Production -ne 1.0) {
        $r = Set-Production $Production
        if ($null -eq $r) { return $false }
    }

    # --- Build cost, upkeep, taxes, radius ---------------------------------------------------------
    if ($BuildCost -ne 1.0) {
        $r = Set-BuildingFields (Txt 'Build cost' 'Baukosten') $CostFields $CostHash $CostMarkerRva 'BAUK' $BuildCost
        if ($null -eq $r) { return $false }
        if ($r) {
            $k = $BuildingRva + 270 * $BuildingSize
            Write-Host ((Txt '  trading post I now: {0} gold, {1} t tools, {2} t wood (originally 100, 3, 6).' '  Kontor I jetzt: {0} Gold, {1} t Werkzeug, {2} t Holz (original 100, 3, 6).') -f [BitConverter]::ToInt32((Read-Mem ($k + 0x58) 4), 0), ([BitConverter]::ToUInt16((Read-Mem ($k + 0x50) 2), 0) / 32), ([BitConverter]::ToUInt16((Read-Mem ($k + 0x52) 2), 0) / 32)) -ForegroundColor Green
        }
    }
    if ($Upkeep -ne 1.0) {
        $r = Set-BuildingFields (Txt 'Upkeep' 'Betriebskosten') $UpkeepFields $UpkeepHash $UpkeepMarkerRva 'UNTH' $Upkeep
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt '  trading post I now: {0} (originally 15), church {1} (originally 50).' '  Kontor I jetzt: {0} (original 15), Kirche {1} (original 50).') -f [BitConverter]::ToUInt16((Read-Mem ($BuildingRva + 270 * $BuildingSize + 0x2C) 2), 0), [BitConverter]::ToUInt16((Read-Mem ($BuildingRva + 463 * $BuildingSize + 0x2C) 2), 0)) -ForegroundColor Green }
    }
    if ($Taxes -ne 1.0) {
        $e = foreach ($nr in 0..4) { @{ Rva = $TaxRva + $nr * $ResidentSize; Orig = $TaxOrig[$nr]; Target = [int][math]::Round($TaxOrig[$nr] * $Taxes, [MidpointRounding]::AwayFromZero); Bytes = 4 } }
        $r = Set-TableValues (Txt 'Taxes' 'Steuern') $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt 'Taxes x{0:0.##}: {1} per resident group instead of 7/8/11/12/13 (5 values set).' 'Steuern x{0:0.##}: {1} je Bevoelkerungsgruppe statt 7/8/11/12/13 (5 Werte gesetzt).') -f $Taxes, (($e | ForEach-Object { $_.Target }) -join '/')) -ForegroundColor Green }
    }
    if ($Radius -ne 1.0) {
        $e = foreach ($nr in ($RadiusOrig.Keys | Sort-Object)) { @{ Rva = $BuildingRva + $nr * $BuildingSize + $RadiusOffset; Orig = $RadiusOrig[$nr]; Target = (Get-ScaledRadius $RadiusOrig[$nr] $Radius); Bytes = 1 } }
        $r = Set-TableValues (Txt 'Radius' 'Radius') $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt 'Radius x{0:0.##}: trading post and market {1}, church {2}, doctor {3} ({4} values set).' 'Radius x{0:0.##}: Kontor und Markt {1}, Kirche {2}, Arzt {3} ({4} Werte gesetzt).') -f $Radius, (Get-ScaledRadius 16 $Radius), (Get-ScaledRadius 21 $Radius), (Get-ScaledRadius 16 $Radius), @($e).Count) -ForegroundColor Green }
    }
    $true
}

$null4 = Hex ([byte[]](0, 0, 0, 0))
Write-Host ((Txt 'Target: {0} x {1} tiles (normal 500 x 350), scroll range {2} (normal 425).' 'Ziel: {0} x {1} Felder (normal 500 x 350), Scrollbereich {2} (normal 425).') -f $Width, $Height, (Format-Value 'Range' $values.Range))
if ($TestProcessId -eq 0) {
    Write-Host (Txt "Now start Anno 1602 History Edition via Ubisoft Connect. I will wait up to $WaitMinutes minutes ..." "Starte jetzt Anno 1602 History Edition ueber Ubisoft Connect. Ich warte bis zu $WaitMinutes Minuten ...") -ForegroundColor Yellow
}
$script:deadline = (Get-Date).AddMinutes($WaitMinutes)
# On the first start Anno1602.exe often exits again right away and is restarted by Ubisoft
# Connect (observed 2026-11-08). Then wait for the next process.
$exited = @{}
$finished = $false
while (-not $finished) {
    if ($TestProcessId -ne 0) {
        $proc = Get-Process -Id $TestProcessId
        $script:base = [IntPtr]$TestBase
    }
    else {
        $proc = $null
        while (-not $proc) {
            $proc = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Where-Object { -not $exited.ContainsKey($_.Id) } | Select-Object -First 1
            if (-not $proc) {
                if ((Get-Date) -gt $script:deadline) { throw (Txt 'The game was not (re)started. Aborted.' 'Spiel wurde nicht (neu) gestartet. Abbruch.') }
                Start-Sleep -Milliseconds 50
            }
        }
        # Determine the load address of the exe (ASLR) as soon as the module is visible.
        $script:base = [IntPtr]::Zero
        for ($i = 0; $i -lt 200 -and $script:base -eq [IntPtr]::Zero; $i++) {
            try { $proc.Refresh(); $script:base = $proc.MainModule.BaseAddress } catch { Start-Sleep -Milliseconds 25 }
        }
        if ($script:base -eq [IntPtr]::Zero) {
            if ($proc.HasExited) { $exited[$proc.Id] = $true; continue }
            throw (Txt 'Cannot determine the load address of the game. Aborted, nothing changed.' 'Ladeadresse des Spiels nicht ermittelbar. Abbruch, nichts geaendert.')
        }
    }
    Write-Host ((Txt 'Game found (PID {0}), loaded at 0x{1:X}.' 'Spiel gefunden (PID {0}), geladen bei 0x{1:X}.') -f $proc.Id, $script:base.ToInt64())

    # PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION
    $script:h = [AnnoMem]::OpenProcess(0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $proc.Id)
    if ($script:h -eq [IntPtr]::Zero) { throw (Txt "Access to the game denied (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." "Zugriff auf das Spiel verweigert (Fehler $([Runtime.InteropServices.Marshal]::GetLastWin32Error())).") }
    try {
        try { $finished = Invoke-Patch $proc }
        catch { if (Test-Running) { throw }; $finished = $false }
    }
    finally {
        [void][AnnoMem]::CloseHandle($script:h)
    }
    if (-not $finished) {
        if ($TestProcessId -ne 0) { throw (Txt 'Test process has exited.' 'Testprozess hat sich beendet.') }
        $exited[$proc.Id] = $true
        Write-Host ((Txt 'The game (PID {0}) exited before it had finished starting. Ubisoft Connect usually restarts it; waiting for the next start ...' 'Das Spiel (PID {0}) hat sich beendet, bevor es fertig gestartet war. Ubisoft Connect startet es meist neu; warte auf den naechsten Start ...') -f $proc.Id) -ForegroundColor Yellow
    }
}
Write-Host (Txt 'Done. Now start a NEW endless game in the game (do not load an old savegame).' 'Fertig. Jetzt im Spiel ein NEUES Endlosspiel starten (keinen alten Spielstand laden).') -ForegroundColor Green

# --- 6. Protection for "Continue game", events ---------------------------------------------------
$eventsOn = $Events -ne 'Off'
$supplyOn = $RivalGrowth -eq 'Ambitious' -or $Explored -eq 'All' -or ($HomeIsland -eq 'Perfect' -and $HomeInfo)   # the waiting loop with the ticks of supply / exploring / home island
if ($TestProcessId -eq 0 -and (-not $NoLastgameProtection -or $eventsOn -or $supplyOn)) {
    if ($NoLastgameProtection) { Write-Host (Txt 'This window stays open until the game exits (events, supply for the rivals, exploring).' 'Dieses Fenster bleibt offen, bis das Spiel beendet ist (Ereignisse, Nachschub fuer die Gegner, Erkunden).') -ForegroundColor Yellow }
    else { Write-Host (Txt 'This window stays open until the game exits (protection for "Continue game").' 'Dieses Fenster bleibt offen, bis das Spiel beendet ist (Schutz fuer "Spiel fortsetzen").') -ForegroundColor Yellow }
    # The events (and the supply for the rivals) run while the game runs; whatever happens to them, the protection
    # below still follows.
    if ($eventsOn) {
        try { Invoke-EventLoop $proc }
        catch { Write-Host ((Txt 'Events: stopped ({0}).' 'Ereignisse: beendet ({0}).') -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    elseif ($supplyOn) {
        $script:h = [AnnoMem]::OpenProcess(0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $proc.Id)
        if ($script:h -ne [IntPtr]::Zero) {
            try { while (-not $proc.HasExited) { Invoke-RivalSupplyTick; Invoke-ExploreTick; Invoke-HomeTick; Start-Sleep -Seconds 2; $proc.Refresh() } }
            finally { [void][AnnoMem]::CloseHandle($script:h) }
        }
    }
    while (-not $proc.HasExited) { Start-Sleep -Seconds 2; $proc.Refresh() }
    Start-Sleep -Seconds 2
    if (-not $NoLastgameProtection) {
        $lg = Join-Path $saves 'lastgame.gam'
        if ((Test-Path -LiteralPath $lg) -and (Get-Item -LiteralPath $lg).LastWriteTime -gt $toolStart) {
            $name = 'lastgame-{0}x{1}-{2}.gam' -f $Width, $Height, (Get-Date -Format 'yyyyMMdd-HHmmss')
            Move-Item -LiteralPath $lg -Destination (Join-Path $saves $name)
            Write-Host (Txt "lastgame.gam from the big world renamed to $name." "lastgame.gam aus der grossen Welt umbenannt in $name.") -ForegroundColor Green
            Write-Host (Txt '"Continue game" thus loads no big world without the tool. To play on: start the tool, then load this savegame.' '"Spiel fortsetzen" laedt so ohne Werkzeug keine grosse Welt. Weiterspielen: Werkzeug starten, dann diesen Spielstand laden.')
        }
        else { Write-Host (Txt 'Game exited; lastgame.gam was not written in this session.' 'Spiel beendet; lastgame.gam wurde in dieser Sitzung nicht geschrieben.') }
        # Remember the options of every savegame written in this session (launcher tab "Continue").
        try {
            $n = Save-SessionRecord $saves $toolStart (Get-SessionArgs $PSBoundParameters) (Join-Path $env:APPDATA 'Anno1602-Extensions\saves.json')
            if ($n) { Write-Host ((Txt 'Options noted for {0} savegame(s) - the launcher tab "Continue" starts them with the same settings.' 'Optionen fuer {0} Spielstand/Spielstaende gemerkt - die Registerkarte "Weiterspielen" startet sie mit denselben Einstellungen.') -f $n) -ForegroundColor Green }
        }
        catch { Write-Host ((Txt 'Could not note the options of the savegames: {0}' 'Optionen der Spielstaende konnten nicht gemerkt werden: {0}') -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if ($PauseOnError) {
        Write-Host (Txt 'All done. This window closes in 10 seconds.' 'Alles erledigt. Dieses Fenster schliesst sich in 10 Sekunden.')
        Start-Sleep -Seconds 10
    }
}
elseif ($TestProcessId -ne 0 -and $eventsOn) {
    # Tests: the event loop against the helper process, until -EventTestUntilClock or -WaitMinutes.
    Invoke-EventLoop $proc
}
