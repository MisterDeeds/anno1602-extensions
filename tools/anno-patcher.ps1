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
       does not load a big world. Switch off with -NoLastgameProtection.
  After the game exits everything is as before.
  Convenient start of tool and game together: tools\start-big-world.cmd

  What is set (see analysis\FINDINGS.md, section "Map size"):
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
                                  View the plan: tools\show-island-plan.ps1
                                  Own scenarios with a big version (marker 'GROS' behind the
                                  SZENE section, e.g. the campaigns from tools\build-scenarios.ps1):
                                  from the map size they were designed for (1000 x 700) on the big
                                  version is used (code cave RVA 0xE5E40), otherwise the small one, stretched.
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
    Resources (-Resources)        Normal: amounts of the template (meant for 17-20 islands). More: ore,
                                  gold, fertility of the plantations and treasures grow with the
                                  island count. Lots: twice as much. Each amount at most as
                                  large as the island count. Code cave at RVA 0xE5C00, called from
                                  the island spread (endless templates only).
    Residents (-Residents)        Factor 1 to 5 for the maximum number of residents per house and
                                  level (normally 2/6/15/25/40). haeuser.cod "Maxwohn" of the 5
                                  population groups, x 64 as int at RVA 0x6BA02C + no. * 0x50
                                  (parser FUN_140090660, read among others in FUN_1400b7c60).
    Cargo (-Cargo)                Factor 1 to 3 for the tons per cargo slot of the buildable ships
                                  (small/large trading and war ship, no. 21-28).
                                  figuren.cod "Maxware", 16 bits x 32 at figure table +0x3E.
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

  Single player only. Load savegames from the big world only with the tool active
  (the savegame does not store the size). This also applies to "Continue game"
  (lastgame.gam), which contains the big world after a game in it.
  The island spread affects every scenario template; do not use the tool
  for campaign scenarios.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\anno-patcher.ps1
  powershell -ExecutionPolicy Bypass -File .\tools\anno-patcher.ps1 -Width 750 -Height 525
  powershell -ExecutionPolicy Bypass -File .\tools\anno-patcher.ps1 -CheckOnly
  powershell -ExecutionPolicy Bypass -File .\tools\anno-patcher.ps1 -Pirates Strong
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
    # Island size in the endless game: Normal (as the template), Large (many large), Huge (almost only the largest).
    [ValidateSet('Normal', 'Large', 'Huge')][string]$IslandSize = 'Normal',
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
    # Gold of the three computer rivals in new games (0 = as the template).
    [ValidateRange(0, 9999999)][int]$RivalGold = 0,
    # Computer rivals: Default (as the difficulty) or Hard (always as the highest level).
    [ValidateSet('Default', 'Hard')][string]$Rivals = 'Default',
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
    # Game folder given by hand (otherwise taken from Ubisoft Connect).
    [string]$GamePath,
    # Only for tools\test-patcher.ps1: other process and load address, no backup.
    [Parameter(DontShow)][int]$TestProcessId = 0,
    [Parameter(DontShow)][long]$TestBase = 0
)

$ErrorActionPreference = 'Stop'

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }
# German names of the option values (the values themselves are English), for the German messages.
$GermanValueNames = @{ Default = 'Standard'; Active = 'Aktiv'; Strong = 'Stark'; Off = 'Aus'; Normal = 'Normal'; Large = 'Gross'; Huge = 'Riesig'; More = 'Mehr'; Lots = 'Viele'; Hard = 'Schwer'; Everywhere = 'Ueberall'; Infinite = 'Unendlich' }
function Get-ValueName([string]$value) { if ($UiGerman) { $GermanValueNames[$value] } else { $value } }

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
# Derivation: analysis\FINDINGS.md, sections "Distributing islands" and "More islands".
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

# Big campaign maps: an own scenario can carry a second version behind the normal SZENE section
# (1172 bytes, used without the tool): +0x494 'GROS', +0x498 width, +0x49C height it was
# designed for, +0x4A0 version, from +0x4A4 a complete SZENE block (1172 bytes). Without the tool
# the loader only reads the fixed offsets of the first block (checked in the game). The code cave
# at RVA 0xE5E40 checks the length (RCX = section header, +0x10 length), the marker and the map size
# (at least the designed size), then copies the big block to the front and stretches its positions
# to the current map size (x*Width/designed width). eax = 1: done, otherwise 0 (normal path).
$BigMapCaveRva = 0xE5E40; $BigMapMarker = 0x534F5247   # 'GROS'
function Build-BigMapCode {
    $c = New-Object System.Collections.Generic.List[byte]
    $label = @{}; $fixups = New-Object System.Collections.Generic.List[object]
    $E = { param([byte[]]$b) foreach ($x in $b) { $c.Add($x) } }
    $J8 = { param([byte]$op, [string]$target) $c.Add($op); $fixups.Add(@($c.Count, $target, 8)); $c.Add(0) }
    # Early exits to "ret" (end of the code cave): 32-bit jump, Jcc rel8 -> 0F (op+0x10) rel32.
    $J32 = { param([byte]$op8, [string]$target) $c.Add(0x0F); $c.Add([byte]($op8 + 0x10)); $fixups.Add(@($c.Count, $target, 32)); 1..4 | ForEach-Object { $c.Add(0) } }
    $Rip = { param([byte[]]$op, [long]$targetRva) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($BigMapCaveRva + $c.Count + 4))) { $c.Add($x) } }
    & $E 0x31, 0xC0                                              # xor eax,eax
    & $E 0x8B, 0x51, 0x10                                        # mov edx,[rcx+0x10]   section length
    & $E 0x81, 0xFA, 0x38, 0x09, 0x00, 0x00                      # cmp edx,2360
    & $J32 0x72 'ret'                                             # jb ret
    & $E 0x41, 0x81, 0xBF, 0x94, 0x04, 0x00, 0x00; & $E ([BitConverter]::GetBytes([int32]$BigMapMarker))   # cmp dword [r15+0x494],'GROS'
    & $J32 0x75 'ret'                                             # jne ret
    & $E 0x41, 0x83, 0xBF, 0x98, 0x04, 0x00, 0x00, 0x64          # cmp dword [r15+0x498],100
    & $J32 0x7C 'ret'                                             # jl ret
    & $E 0x41, 0x83, 0xBF, 0x9C, 0x04, 0x00, 0x00, 0x64          # cmp dword [r15+0x49C],100
    & $J32 0x7C 'ret'                                             # jl ret
    & $Rip ([byte[]](0x8B, 0x15)) 0x5EBE40                       # mov edx,[Width]
    & $E 0x41, 0x3B, 0x97, 0x98, 0x04, 0x00, 0x00                # cmp edx,[r15+0x498]
    & $J32 0x7C 'ret'                                             # jl ret
    & $Rip ([byte[]](0x8B, 0x15)) 0x5EBE98                       # mov edx,[Height]
    & $E 0x41, 0x3B, 0x97, 0x9C, 0x04, 0x00, 0x00                # cmp edx,[r15+0x49C]
    & $J32 0x7C 'ret'                                             # jl ret
    & $E 0x49, 0x8D, 0xB7, 0xA4, 0x04, 0x00, 0x00                # lea rsi,[r15+0x4A4]
    & $E 0x4C, 0x89, 0xFF                                        # mov rdi,r15
    & $E 0xB9, 0x94, 0x04, 0x00, 0x00                            # mov ecx,1172
    & $E 0xF3, 0xA4                                              # rep movsb
    & $E 0x45, 0x8B, 0x47, 0x64                                  # mov r8d,[r15+0x64]
    & $E 0x41, 0x83, 0xF8, 0x32                                  # cmp r8d,50
    & $J8 0x77 'done'                                            # ja done
    & $E 0x4D, 0x8D, 0x8F, 0x74, 0x01, 0x00, 0x00                # lea r9,[r15+0x174]
    $label.loop = $c.Count
    & $E 0x45, 0x85, 0xC0                                        # test r8d,r8d
    & $J8 0x7E 'done'                                            # jle done
    & $E 0x41, 0x8B, 0x41, 0x08                                  # mov eax,[r9+8]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE40                 # imul eax,[Width]
    & $E 0x99, 0x41, 0xF7, 0xBF, 0x98, 0x04, 0x00, 0x00          # cdq / idiv dword [r15+0x498]
    & $E 0x41, 0x89, 0x41, 0x08                                  # mov [r9+8],eax
    & $E 0x41, 0x8B, 0x41, 0x0C                                  # mov eax,[r9+0xc]
    & $Rip ([byte[]](0x0F, 0xAF, 0x05)) 0x5EBE98                 # imul eax,[Height]
    & $E 0x99, 0x41, 0xF7, 0xBF, 0x9C, 0x04, 0x00, 0x00          # cdq / idiv dword [r15+0x49C]
    & $E 0x41, 0x89, 0x41, 0x0C                                  # mov [r9+0xc],eax
    & $E 0x49, 0x83, 0xC1, 0x10                                  # add r9,16
    & $E 0x41, 0xFF, 0xC8                                        # dec r8d
    & $J8 0xEB 'loop'                                            # jmp loop
    $label.done = $c.Count
    & $E 0xB8, 0x01, 0x00, 0x00, 0x00                            # mov eax,1
    $label.ret = $c.Count
    & $E 0xC3                                                    # ret
    foreach ($f in $fixups) {
        if ($f[2] -eq 32) { $b4 = [BitConverter]::GetBytes([int32]($label[$f[1]] - ($f[0] + 4))); for ($i = 0; $i -lt 4; $i++) { $c[$f[0] + $i] = $b4[$i] }; continue }
        $d = $label[$f[1]] - ($f[0] + 1); if ($d -lt -128 -or $d -gt 127) { throw (Txt "Internal error: jump to $($f[1]) too far." "Interner Fehler: Sprung zu $($f[1]) zu weit.") }
        $c[$f[0]] = [byte]($d -band 0xFF)
    }
    if ($BigMapCaveRva + $c.Count -gt 0xE5F70) { throw (Txt 'Internal error: big map code cave too long.' 'Interner Fehler: Grosskarten-Codestueck zu lang.') }
    , $c.ToArray()
}

# Small assembler with jump labels for the code cave. With $withResources it calls the resource
# code cave after copying the island list (call; the registers are already saved then). With
# $withBigMap it first calls the big map code cave (eax = 1: already done).
function Build-IslandCode([bool]$withResources = $false, [bool]$withBigMap = $false) {
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
# Derivation: analysis\FINDINGS.md, section "Resources".
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
$ResourceCaveRva = 0xE5C00; $ResourceCaveEnd = 0xE5E00   # from 0xE5E00: code caves for pirates and traders
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

# Start positions of the ships (SHIP4: entries of 0x1B4 bytes, x/y as int16 at +0x1C/+0x1E).
# The ships are not stretched; the island planner keeps these spots free.
function Read-Ships([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return , @() }
    $d = [IO.File]::ReadAllBytes($path); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0) { break }
        if ($name -eq 'SHIP4') { return , @(for ($i = 0; $i -lt [math]::Floor($len / 0x1B4); $i++) { , @([BitConverter]::ToInt16($d, $o + 20 + $i * 0x1B4 + 0x1C), [BitConverter]::ToInt16($d, $o + 20 + $i * 0x1B4 + 0x1E)) }) }
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
function Get-IslandPlan($template, [int]$mapW, [int]$mapH, [bool]$stretchOnly, [string]$size = 'Normal', $ships = @()) {
    $shipFree = { param([int]$x, [int]$y, [int]$w, [int]$hh) foreach ($sp in $ships) { if ($sp[0] -ge $x - 2 -and $sp[0] -lt $x + $w + 2 -and $sp[1] -ge $y - 2 -and $sp[1] -lt $y + $hh + 2) { return $false } }; $true }
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
    # There are only 6 (NORD) or 7 (SUED) island files of the class "lar", none in NORDNAT/SUEDNAT.
    # In the game (2026-11-11) only 15 of 23 planned "lar" islands were loaded, the rest was missing.
    # Hence at most $LarMax of them per map, otherwise "big" (68 + 64 files).
    $LarMax = 10
    $lar = @($plan | Where-Object { $_[1] -eq 4 }).Count
    if ($size -ne 'Normal' -and -not $stretchOnly) {
        for ($i = 0; $i -lt $plan.Count; $i++) {
            $e = $plan[$i]; $k0 = [int]$e[1]
            $wanted = if ($size -eq 'Huge') { @(4, 3) } else { @([math]::Min(4, $k0 + 1)) }
            foreach ($k in $wanted) {
                if ($k -le $k0) { continue }
                if ($k -eq 4 -and $lar -ge $LarMax) { continue }
                $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12)
                if ($x + $ClassW[$k] -gt $mapW - $margin -or $y + $ClassH[$k] -gt $mapH - $margin) { continue }
                $free = & $shipFree $x $y $ClassW[$k] $ClassH[$k]
                for ($j = 0; $j -lt $plan.Count -and $free; $j++) {
                    if ($j -eq $i) { continue }
                    $p = $plan[$j]; $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12)
                    if ($x -lt $px + $ClassW[$p[1]] + $gap -and $px -lt $x + $ClassW[$k] + $gap -and $y -lt $py + $ClassH[$p[1]] + $gap -and $py -lt $y + $ClassH[$k] + $gap) { $free = $false }
                }
                if ($free) { $e[1] = [byte]$k; $e[4] = 0xFF; $e[5] = 0xFF; if ($k -eq 4) { $lar++ }; break }
            }
        }
    }
    $classSeq = switch ($size) { 'Large' { @(4, 3) } 'Huge' { @(4, 4, 4, 3) } default { $null } }
    $script:rng = [long](($template.Count * 7919 + [BitConverter]::ToInt32($template[0], 8) * 31 + [BitConverter]::ToInt32($template[0], 12)) % 2147483648)
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
                $px = [BitConverter]::ToInt32($p, 8); $py = [BitConverter]::ToInt32($p, 12); $pw = $ClassW[$p[1]]; $ph = $ClassH[$p[1]]
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
    $count = 0; $script:IslandPlans = @{}
    if (-not $stretchOnly) {
        foreach ($layout in 0, 1, 2) {
            $tpl = Read-Template (Join-Path $GameFolder "Szenes\[[48]]0$layout.szs")
            if (-not $tpl) { continue }
            $plan = Get-IslandPlan $tpl $mapW $mapH $false $size (Read-Ships (Join-Path $GameFolder "Szenes\[[48]]1$layout.szs"))
            $script:IslandPlans[$layout] = $plan
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

if (-not $NoIslandSpread) {
    $withResources = ($ResourcePercent -gt 0 -or $Villages -gt 0 -or $FertilityAll) -and -not $StretchOnly
    $withBigMap = -not $StretchOnly
    $IslandCode = Build-IslandCode $withResources $withBigMap
    if ($withBigMap) {
        $BigMapCode = Build-BigMapCode
        $Patches += @{ Name = (Txt 'Big campaign maps           ' 'Grosse Kampagnenkarten      '); Rva = $BigMapCaveRva; Original = ((@('00') * $BigMapCode.Length) -join ' '); Target = $BigMapCode; MemoryOnly = $true }
    }
    $IslandTable = Build-IslandTable $Width $Height $StretchOnly.IsPresent $IslandSize
    $Hook = [byte[]](@(0xE9) + (Rel32 $CaveRva ($HookRva + 5)) + @(0x66, 0x90))
    # Order matters: first the table and the code caves, then the jump (rollback in reverse).
    $Patches += @{ Name = (Txt 'Island spread (table)       ' 'Inselverteilung (Tabelle)   '); Rva = $TableRva; Original = ((@('00') * $IslandTable.Length) -join ' '); Target = $IslandTable; MemoryOnly = $true }
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
    foreach ($a in ($script:IslandPlans.Keys | Sort-Object)) { Write-Host ((Txt 'Island plan layout {0}: {1} islands' 'Inselplan Anordnung {0}: {1} Inseln') -f $a, $script:IslandPlans[$a].Count) }
}
elseif ($FertilityAll) { Write-Host (Txt 'Fertility: only works with the island spread (not with -NoIslandSpread); NOT set.' 'Fruchtbarkeit: wirkt nur mit der Inselverteilung (nicht mit -NoIslandSpread); NICHT gesetzt.') -ForegroundColor Yellow }

# --- Pirates -------------------------------------------------------------------------------------
# Derivation: analysis\FINDINGS.md, section "Rivals and pirates".
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
$PirateCaveRva = 0xE5F80; $TimersHookRva = 0xC3232; $TimersContinue = 0xC3239
$FlagsRva = 0x5EC188; $TimersMovapsTarget = 0x5BE5F0; $ClockRva = 0x5EC0F8; $Gold0Rva = 0x5F0964
$PlayerSize = 0x280   # player table: 7 slots of 640 bytes (FUN_1400a87f0); 1-3 = computer rivals
$CannonRva = 0x3B94B; $CannonOrig = '8B 05 6F 08 5B 00 83'; $CannonTarget = 'BE 00 01 00 00 EB 3B'
function Build-PirateCode([string]$mode, [int]$gold = 0, [int]$rivalGold = 0) {
    $c = New-Object System.Collections.Generic.List[byte]
    # RIP-relative: rel32 refers to the end of the instruction (after a possible immediate $after).
    $Rip = { param([byte[]]$op, [long]$targetRva, [byte[]]$after) foreach ($x in $op) { $c.Add($x) }; foreach ($x in (Rel32 $targetRva ($PirateCaveRva + $c.Count + 4 + $after.Length))) { $c.Add($x) }; foreach ($x in $after) { $c.Add($x) } }
    & $Rip ([byte[]](0x0F, 0x29, 0x05)) $TimersMovapsTarget ([byte[]]@())      # movaps [0x1405be5f0],xmm0 (replaced instruction)
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
if ($Pirates -ne 'Default' -or $StartGold -gt 0 -or $RivalGold -gt 0) {
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
# Derivation: analysis\FINDINGS.md, section "Rivals, pirate fleet, natives, traders".
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
if ($Disasters -eq 'Off') {
    foreach ($s in $DisasterOffSites) { $Patches += @{ Name = $s.Name.PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes '0F 1F 44 00 00') } }
    foreach ($s in $DisasterMoreSites) { $Patches += @{ Name = (Txt 'Disasters (check)' 'Katastrophen (Kontrolle)').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Original) } }
    Write-Host ((Txt 'Disasters: {0} (no new fire, plague, drought or volcanic eruption)' 'Katastrophen: {0} (kein neues Feuer, keine Pest, Duerre oder Vulkanausbruch)') -f (Get-ValueName $Disasters))
}
elseif ($Disasters -eq 'More') {
    foreach ($s in $DisasterMoreSites) { $Patches += @{ Name = (Txt 'Disasters more' 'Katastrophen mehr').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Target) } }
    foreach ($s in $DisasterOffSites) { $Patches += @{ Name = (Txt 'Disasters (check)' 'Katastrophen (Kontrolle)').PadRight(28); Rva = $s.Rva; Original = $s.Original; Target = (Bytes $s.Original) } }
    Write-Host ((Txt 'Disasters: {0} (fire and plague twice as likely, droughts on Demanding/Hard twice as often)' 'Katastrophen: {0} (Feuer und Pest doppelt so wahrscheinlich, Duerre bei Fordernd/Schwer doppelt so oft)') -f (Get-ValueName $Disasters))
}

# --- Residents, cargo, production ----------------------------------------------------------------
# Residents: haeuser.cod "Maxwohn" of the population groups 0-4 (BGRUPPE), stored by the parser x 64
# as int at RVA 0x6BA02C + no. * 0x50. Houses store their residents x 64 as 16 bits (house +6);
# FUN_1400b7c60 compares with it and advances the level. All five values are multiplied by the same
# factor, so the ratios stay the same.
$ResidentRva = 0x6BA02C; $ResidentSize = 0x50
$ResidentOrig = @(128, 384, 960, 1600, 2560)   # 2/6/15/25/40 residents x 64
if ($Residents -ne 1.0) { Write-Host ((Txt 'Residents: x{0:0.##} ({1} instead of 40 per house of the highest level)' 'Einwohner: x{0:0.##} ({1} statt 40 je Haus der hoechsten Stufe)') -f $Residents, [int][math]::Round(40 * $Residents)) }
# Cargo: figuren.cod "Maxware" (tons per cargo slot x 32) as 16 bits at figure table +0x3E;
# read among others by the ship loader FUN_14008e4f0. No. 21-28: small/large trading ship,
# small/large war ship (50/80/65/120 t, read in the game 2026-11-09).
$CargoOffset = 0x3E
$CargoOrig = @{ 21 = 1600; 22 = 1600; 23 = 2560; 24 = 2560; 25 = 2080; 26 = 2080; 27 = 3840; 28 = 3840 }
if ($Cargo -ne 1.0) { Write-Host ((Txt 'Cargo: x{0:0.##} (small trading ship {1} t instead of 50 t per cargo slot)' 'Laderaum: x{0:0.##} (kleines Handelsschiff {1} t statt 50 t je Laderaum)') -f $Cargo, [int][math]::Round(50 * $Cargo)) }
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
        if ($k -in 'Width', 'Height', 'CheckOnly', 'WaitMinutes', 'GameAlreadyRunning', 'GamePath', 'NoLastgameProtection', 'TestProcessId', 'TestBase') { continue }
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
        $e = foreach ($nr in ($CargoOrig.Keys | Sort-Object)) { @{ Rva = $FigureRva + $nr * $FigureSize + $CargoOffset; Orig = $CargoOrig[$nr]; Target = [math]::Min(65535, [int][math]::Round($CargoOrig[$nr] * $Cargo)); Bytes = 2 } }
        $r = Set-TableValues (Txt 'Cargo' 'Laderaum') $e
        if ($null -eq $r) { return $false }
        if ($r) { Write-Host ((Txt 'Cargo x{0:0.##}: {1} t per cargo slot (8 ship values set).' 'Laderaum x{0:0.##}: {1} t je Laderaum (8 Schiffswerte gesetzt).') -f $Cargo, (($e | Where-Object { $true } | Select-Object -Index 0, 2, 4, 6 | ForEach-Object { [math]::Round($_.Target / 32) }) -join '/')) -ForegroundColor Green }
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

# --- 6. Protection for "Continue game" -----------------------------------------------------------
if ($TestProcessId -eq 0 -and -not $NoLastgameProtection) {
    Write-Host (Txt 'This window stays open until the game exits (protection for "Continue game").' 'Dieses Fenster bleibt offen, bis das Spiel beendet ist (Schutz fuer "Spiel fortsetzen").') -ForegroundColor Yellow
    while (-not $proc.HasExited) { Start-Sleep -Seconds 2; $proc.Refresh() }
    Start-Sleep -Seconds 2
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
