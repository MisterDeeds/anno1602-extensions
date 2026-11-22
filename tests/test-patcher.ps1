<#
.SYNOPSIS
  Offline test for src\anno-patcher.ps1, without starting the game.

.DESCRIPTION
  A helper process loads the exe copy analysis\bin\Anno1602.exe only as an image
  (LoadLibraryEx with DONT_RESOLVE_DLL_REFERENCES): the sections lie at load address + RVA
  as in the game, with the same memory protection, but no game code runs and
  no dependent DLL is loaded. Then anno-patcher.ps1 runs against this process.
  The tool runs with ANNO_EXTENSIONS_LANG=en (English messages); the checks marked "de"
  run it with ANNO_EXTENSIONS_LANG=de and expect the German messages.

  Checked:
    A  Game still starting (variables 0): the tool patches the code, waits for the start,
       the test replays the program start, afterwards all variables are right.
    B  Second run against the same process: runs through, nothing changes.
       English messages only with "en", German messages with "de".
    C  Other size against an already patched process: abort, nothing changed
       (German abort message with "de").
    D  One code site falsified: abort, none of the other sites changed.
    E  750 x 525 with the game already started (variables at the original).
    F  Process exits while the tool is waiting: the end is detected.
    G  -NoIslandSpread: jump, code cave and table stay untouched.
    H  -StretchOnly: table without entries, templates are only stretched.
    I  Function test of the code cave at its real address in the image: a thread in the
       helper process calls it with the real SZENE sections from Szenes\[[48]]00/01/02.szs
       (the files are only read). For that, the way back into the SZENE loader is replaced
       by "pop r15; ret", only in the image of the helper process. Expected: exactly the
       island list planned by the tool, originals stretched at the front, no overlap, all
       within the world; unknown template only stretched; island count > 50 no change.
    J  -Pirates Active / Off / Strong: code cave, jump in the TIMERS loader and (Strong) cannon
       site set (since 3.0.0 the TIMERS hook is always set, see AP). Function test: the code cave runs in the
       helper process (way back RVA 0xC3239 replaced by "ret" there) and sets or clears
       bit 0 of the game variable 0x1405ec188, the other bits stay. The option value is
       shown in English with "en" and in German with "de".
    L  -StartGold (also together with -Pirates Strong): the code cave sets the gold of slot 0
       only at game clock < 1000 (new game), with savegames it stays.
    M  -Storage: the 7 storage values (trading post I-IV, market) of the building table are
       multiplied by the factor, neighbours stay, no double multiplying, unexpected value: nothing.
    K  -ShipSpeed: the 12 ship values of the figure table (filled with the original values
       beforehand, as after reading figuren.cod) are multiplied by the factor, neighbours
       stay; a second run does not multiply twice; unexpected value: nothing set.
    N  -Residents: the 5 Maxwohn values (x 64) are multiplied, neighbours stay, no
       double multiplying, unexpected value: nothing set.
    O  -Cargo: the cargo holds of the 8 buildable ship entries are multiplied (at most 8), the hull and the trader stay.
    P  -Production: intervals of the building table are divided (at least 1, 0 stays 0),
       marker set; a second run does not divide again.
    Q  -Turbo: F7 site "mov ecx,8", F6 untouched.
    R  -RivalGold: the code cave sets the gold of slots 1-3 in a new game (trader in
       slot 4 stays), nothing with savegames.
    AP Mission time limit: without options the TIMERS hook is set; the code cave copies the deadline
       (mission table +0x20 of the local player's slot) to 0x1405ec1a8 only if that slot has goal bits,
       local player 0-3 only; flags and gold stay; only ecx/edx are used; everything fits the cave.
    S  -IslandSize Huge -Resources Lots: function test with the real templates.
    T  Large/Huge: geometry of all plans, at most 10 "lar".
    U  -Rivals Hard: the four AI sites read 3, natural events and pirate cannons do not.
    V  -PirateFleet: the code cave calls the real FUN_1400185f0 in the image (levels 0-4 via
       the civilisation bits of slot 0) and returns level x 2 or x 3; wait time divided.
    W  -Traders: the code cave returns target x 2 or x 3, at most 24.
    X  -Natives: real templates, villages 4/4 or 7/7, with and without resources.
    Y  50 islands at 1000 x 700; all options together, code caves do not overlap.
    Z  Big campaign maps: extended SZENE section ('GROS' + second block) in the image;
       1000 x 700 and 2000 x 1400 -> big version (stretched), 750 x 525 and 500 x 350 -> small
       version, wrong marker / too short -> small version. Since 3.1 a third version for the giant
       world: 2000 x 1400 -> giant version, 1999 x 1400 / 2000 x 1399 / 1500 x 1050 / 1000 x 700 -> big,
       broken giant version -> big x 2, unknown first marker -> small. H: without the big map code cave.
  The cases below (2 letters) run the game's own haeuser.cod parser FUN_140090660 (and FUN_140092e00)
  in the helper process: its CRT imports are resolved there and it runs in the game folder, so the
  building table and the population groups hold exactly the values of the running game.
    AA -BuildCost: checksum of the originals, every cost field of all 500 entries scaled (whole tons,
       at least 1), everything else unchanged, marker, second run, other factor, wrong original, 0 = free.
    AB -Upkeep: the same for the running costs (+0x2A/+0x2C).
    AC -Taxes: the 5 tax values, second run, other factor, German message.
    AD -Radius: 17 radii (at most 48), all other radius bytes unchanged, second run, unexpected value.
    AE -Fertility Everywhere: code cave and hook; function test of the resource code cave with the real
       templates (with and without -Resources/-Natives) and of the patched FUN_1400d0ce0 with test islands
       (unchanged for the limits 1-3, climate ignored for 'FERT'); -StretchOnly/-NoIslandSpread: nothing.
    AF -Mines Infinite: both subtractions NOPs, neighbours unchanged, falsified site -> abort.
    AG -Disasters Off/More: 5 calls NOPs or 10 limits changed; other mode in the same process -> abort.
    AQ -RivalGrowth Ambitious (3.4): the two phase exits and the goods wait of the AI become NOPs, the three money-only
       phase exits jumps to the building part (9 bytes).
    AR -Volcanoes Off: the volcano call alone a NOP; together with Disasters Off or More.
    AS Island forge: the folder is built below LOCALAPPDATA (of the test), its path lies at RVA 0x91B200, the five
       loader instructions point there, a second run reuses the folder, other options replace it.
    AT -IslandSize Giant: plans at 1000 x 700, 2000 x 1400 and 750 x 525 with the real giant islands: no overlap,
       everything inside, at most 6 giant islands each once, at most 10 of class "lar" in total.
    AU Supply for ambitious rivals: the tool's Invoke-RivalSupply against fake towns in the helper process: luxury goods
       of rival towns with settlers filled (by stage, up to the storage limit), human and other towns untouched,
       once per 2000 clock steps, nothing after the end of the game.
    AW -Explored All (3.5): the tool marks every existing island as known to the local player (island +0x43), only those
       bytes change, nothing before the clock runs or for an invalid player.
    AV -Ultra (3.5): the key filter in front of TranslateAcceleratorA lets F8 through; the "ja" of the key switch goes to the code cave, which compares F8 (0x77 - 0x10), sets the level
       with FUN_1400c8be0 and returns like the other keys; F7 untouched; same run again, other level, with -Turbo.
    AH Everything together: all options, code caves and markers do not overlap, production x2 shortens
       exactly the 125 intervals counted in the game (2026-11-10).
  The event cases run the tool's event engine (functions and C# class loaded via the syntax tree) in this test
  process against the helper process; the test writes the game clock and the game state and polls once at a time:
    AI -Events: each of the 7 events applies as specified (gold +4,000 / -1,200, goods up to the storage limit,
       taxes x1.5 / x0.75, work intervals x1/1.5 / x1/0.75) and is restored byte for byte at its end clock.
    AJ Overlapping events: taxes and production at once, a busy kind is skipped, separate ends.
    AK Together with -Taxes 2 -Production 2 (on top of them, restored to them); a second tool run meanwhile.
    AL events.json: format, umlauts, number formats, at most 200 (newest last), broken file, new folder; saves.json
       arguments keep -Events but not its test switches.
    AM Clock condition: clock standing still, no own town, game over (lock, human out), clock 0, a savegame
       loaded (clock back), implausible jumps; the interval 0.5-1.5 x the mean; the same seed gives the same events.
    AN Without -Events and with -Events Off nothing happens; the real event loop of the tool (-Events Often with
       the test switches) against the helper process: scripted events first, everything restored at the end.
    AO Values left behind by a killed tool window are restored by the next run (a value changed meanwhile stays);
       Stop() (window closed) restores and blocks every later write; dev\check-game.ps1 shows the active events.
  Expected bytes and plans come from the same functions in anno-patcher.ps1 (loaded via
  the syntax tree); the expected scaled values are computed separately in this test.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = Join-Path $root 'src\anno-patcher.ps1'
$exe = Join-Path $root 'analysis\bin\Anno1602.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    # No local copy (e.g. a fresh clone of the repository): use the exe of the installed game. It is only mapped
    # as an image (read only), the game itself is not started.
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $exe = Join-Path (($d -replace '/', '\').TrimEnd('\')) 'Anno1602.exe'; break } } catch { }
    }
}
if (-not (Test-Path -LiteralPath $exe)) { throw 'Anno1602.exe not found: neither analysis\bin\Anno1602.exe nor an installed Anno 1602 History Edition.' }
$tmp = Join-Path ([IO.Path]::GetTempPath()) "anno-patcher-test-$PID"
New-Item -ItemType Directory -Force $tmp | Out-Null
# The tool runs in English (child processes inherit the variable); Invoke-Tool can switch to 'de'.
$langBefore = $env:ANNO_EXTENSIONS_LANG
$env:ANNO_EXTENSIONS_LANG = 'en'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TestMem {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtectEx(IntPtr h, IntPtr addr, IntPtr size, uint prot, out uint old);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, IntPtr size, uint type, uint prot);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, IntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr attr, IntPtr stack, IntPtr start, IntPtr param, uint flags, out uint tid);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeThread(IntPtr h, out uint code);
}
'@

# Code sites (RVA of the instruction) and variables as in the tool.
$Code = [ordered]@{
    'Width start' = 0x0DC7E5; 'Height start' = 0x0DC7EF; 'Range start' = 0x0DC7F9
    'Width new' = 0x08DC90; 'Height new' = 0x08DC9A; 'Range new' = 0x08DCA4; '1/Width new' = 0x08DCAE; '1/Height new' = 0x08DCB8
}
$Var = [ordered]@{ Width = 0x5EBE40; Height = 0x5EBE98; Range = 0x5EB840; InvWidth = 0x5EBC7C; InvHeight = 0x5EBC80 }

function I32([int]$v) { [BitConverter]::GetBytes([int32]$v) }
function F32([double]$v) { [BitConverter]::GetBytes([single]$v) }
function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
function Get-ExpectedValues([int]$w, [int]$h) {
    [ordered]@{ Width = I32 $w; Height = I32 $h; Range = I32 ([math]::Floor($w / 2) + [math]::Floor($h / 2)); InvWidth = F32 (1.0 / $w); InvHeight = F32 (1.0 / $h) }
}
$CodeKind = @{ 'Width start' = 'Width'; 'Height start' = 'Height'; 'Range start' = 'Range'; 'Width new' = 'Width'; 'Height new' = 'Height'; 'Range new' = 'Range'; '1/Width new' = 'InvWidth'; '1/Height new' = 'InvHeight' }

# Island spread: compute the expected bytes with the same functions as the tool
# (loaded from anno-patcher.ps1 via the syntax tree; the tool itself does not run here).
$ast = [System.Management.Automation.Language.Parser]::ParseFile($tool, [ref]$null, [ref]$null)
foreach ($stmt in $ast.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function (Txt|Bytes|Rel32|Build-IslandCode|Build-ResourceCode|Read-Template|Read-Ships|Get-IslandPlan|Build-IslandTable|Build-PirateCode|Get-ShipSpeedBytes|Build-FleetCode|Build-TraderCode|Build-BigMapCode|Add-FertilityBlock|Build-FertilityCode|Build-UltraCode|Get-CargoHolds|Build-UltraAccelCode)\b') -or
        $txt -match '^\$(GameFolder|CaveRva|TableRva|TableMax|HookRva|HookContinue|ClassW|ClassH|PirateCaveRva|TimersHookRva|TimersContinue|FlagsRva|TimersMovapsTarget|ClockRva|Gold0Rva|PlayerSize|TimeLimitRva|MissionRva|MissionSize|LocalPlayerRva|CannonRva|CannonOrig|CannonTarget|FigureRva|FigureSize|SpeedOffset|ShipSpeedOrig|BuildingRva|BuildingSize|StorageOffset|StorageOrig|ResidentRva|ResidentSize|ResidentOrig|CargoOffset|CargoOrig|CargoMaxHolds|IntervalOffset|BuildingCount|ProdMarkerRva|ResourceCaveRva|ResourceCaveEnd|ResourceOffsets|IslandMax|IslandDensity|RivalSites|FleetCaveRva|FleetCallRva|LevelRva|FleetWait|TraderCaveRva|TraderRva|TraderMax|BigMapCaveRva|BigMapMarker|FertMagic|FertAmount|FertCaveRva|FertHookRva|FertAcceptRva|FertJumpTableRva|FertHookOrig|CostMarkerRva|UpkeepMarkerRva|CostHash|UpkeepHash|TaxRva|TaxOrig|RadiusOffset|RadiusMax|RadiusOrig|MineSites|DisasterOffSites|DisasterMoreSites|VolcanoRva|RivalGrowthSites|IslandPathRva|IslandPathMax|IslandPathSites|GiantPerClimate|GiantMaxPerMap|SupplyGoods|SupplyBelow|SupplyTo|SupplyEveryClock|UltraCaveRva|UltraHookRva|UltraHookOrig|KeyEndRva|SetSpeedRva|UltraAccelCaveRva|UltraAccelCallRva|UltraAccelCallOrig|AccelIatRva|ModifierFlagsRva)\b') { . ([scriptblock]::Create($txt)) }
    # Event engine (cases AI-AO): its constants, functions and the two C# types run here in the test process, against
    # the helper process ($script:h / $script:base as in the tool).
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function (Invoke-RivalSupply|Read-Mem|Write-Mem|Test-Running|Read-Abs|Format-EventNumber|ConvertTo-AsciiGerman|Get-EventRoundHalfUp|Get-EventTaxTarget|Get-EventIntervalTarget|Get-EventTaxes|Get-EventIntervals|Get-EventPage|Test-EventOwnerAlive|Repair-EventLeftovers|Initialize-EventState|New-EventInterval|Get-EventGameState|Get-EventGiftChoices|Test-EventEligible|Add-EventJson|Write-EventJsonList|Set-EventEndedEarly|Write-EventRecord|Invoke-GameEvent|Start-NextEvent|Stop-TemporaryEvents|Invoke-EventTick|Get-SessionArgs|Invoke-Explore)\b') -or
        $txt -cmatch '^\$(Event|Explore)[A-Z]\w*\s*=' -or ($txt -match '^Add-Type -TypeDefinition' -and $txt -match 'public static class (AnnoMem|AnnoEvents) ')) { . ([scriptblock]::Create($txt)) }
}
$PirateHookOrig = '0F 29 05 B7 B3 4F 00'
$PirateHookTarget = Hex ([byte[]](@(0xE9) + (Rel32 $PirateCaveRva ($TimersHookRva + 5)) + @(0x66, 0x90)))
function Test-Pirates($a, [string]$mode, [string]$when, [int]$gold = 0) {
    # Since 3.0.0 the TIMERS hook is always set (mission time limit).
    $code = Build-PirateCode $mode $gold
    $c = Hex (Read-Image $a $PirateCaveRva $code.Length); $k = Hex (Read-Image $a $TimersHookRva 7); $can = Hex (Read-Image $a $CannonRva 7)
    $target = Hex $code
    Assert-Check "$when TIMERS code cave $mode/gold $gold set ($($code.Length) bytes)" ($c -eq $target)
    Assert-Check "$when TIMERS jump set ($k)" ($k -eq $PirateHookTarget)
    if ($mode -eq 'Strong') { Assert-Check "$when cannon site set ($can)" ($can -eq $CannonTarget) }
    else { Assert-Check "$when cannon site original ($can)" ($can -eq $CannonOrig) }
}
$IslandCodeRva = $CaveRva; $IslandHookRva = $HookRva; $LoaderContinueRva = $HookContinue
$IslandHookOrig = '4C 8D 1D D0 F1 F2 FF'
$IslandHookTarget = 'E9 D2 42 01 00 66 90'
$IslandCode = Build-IslandCode $false $true   # like the tool without -StretchOnly (with the big map call)
function Get-ExpectedTable([int]$w, [int]$h, [bool]$stretchOnly) { $t = Build-IslandTable $w $h $stretchOnly; @{ Table = $t; Plans = $script:IslandPlans.Clone() } }
function Test-Islands($a, [bool]$active, [string]$when, $exp) {
    $c = Hex (Read-Image $a $IslandCodeRva $IslandCode.Length); $k = Hex (Read-Image $a $IslandHookRva 7)
    $tl = if ($exp) { $exp.Table.Length } else { 2452 }
    $t = Hex (Read-Image $a $TableRva $tl)
    if ($active) {
        Assert-Check "$when island spread code cave set ($($IslandCode.Length) bytes)" ($c -eq (Hex $IslandCode))
        Assert-Check "$when island spread table set ($tl bytes)" ($t -eq (Hex $exp.Table))
        Assert-Check "$when island spread jump set ($k)" ($k -eq $IslandHookTarget)
    }
    else {
        Assert-Check "$when island spread code cave empty" ($c -eq ((@('00') * $IslandCode.Length) -join ' '))
        Assert-Check "$when island spread table empty" ($t -eq ((@('00') * $tl) -join ' '))
        Assert-Check "$when island spread jump original ($k)" ($k -eq $IslandHookOrig)
    }
}
# Geometry of an island plan: everything within the world, no overlap, slot = index.
function Test-Geometry($plan, [int]$w, [int]$h, [string]$when) {
    $ok = $true; $reason = ''
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $p = $plan[$i]; $x = [BitConverter]::ToInt32($p, 8); $y = [BitConverter]::ToInt32($p, 12); $pw = $ClassW[$p[1]]; $ph = $ClassH[$p[1]]
        if ($x -lt 0 -or $y -lt 0 -or $x + $pw -gt $w -or $y + $ph -gt $h) { $ok = $false; $reason = "island $i outside" }
        if ($p[3] -ne $i) { $ok = $false; $reason = "slot $i wrong" }
        for ($j = $i + 1; $j -lt $plan.Count; $j++) {
            $q = $plan[$j]; $qx = [BitConverter]::ToInt32($q, 8); $qy = [BitConverter]::ToInt32($q, 12)
            if ($x -lt $qx + $ClassW[$q[1]] -and $qx -lt $x + $pw -and $y -lt $qy + $ClassH[$q[1]] -and $qy -lt $y + $ph) { $ok = $false; $reason = "islands $i and $j overlap" }
        }
    }
    Assert-Check "$when geometry: $($plan.Count) islands within the world, without overlap $reason" $ok
}
# SZENE section of the endless template (read only).
function Read-Scene([string]$name = '[[48]]10.szs') {
    $f = Join-Path 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition\Szenes' $name
    $d = [IO.File]::ReadAllBytes($f); $o = 0
    while ($o -lt $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($name -eq 'SZENE') { return , [byte[]]$d[($o + 20)..($o + 19 + $len)] }
        $o += 20 + $len
    }
    throw 'SZENE section not found.'
}
# Expected result of the code cave for an unknown template: positions only stretched.
function Get-StretchedScene([byte[]]$s, [int]$w, [int]$h) {
    $e = [byte[]]$s.Clone(); $n = [BitConverter]::ToInt32($s, 0x64)
    if ($n -gt 50 -or $n -lt 0) { return , $e }
    for ($i = 0; $i -lt $n; $i++) {
        $p = 0x174 + 16 * $i
        $x = [BitConverter]::ToInt32($s, $p + 8); $y = [BitConverter]::ToInt32($s, $p + 12)
        [Array]::Copy((I32 ([int][math]::Truncate($x * $w / 500))), 0, $e, $p + 8, 4)
        [Array]::Copy((I32 ([int][math]::Truncate($y * $h / 350))), 0, $e, $p + 12, 4)
    }
    , $e
}
# Runs the code cave in the helper process with a SZENE buffer and returns the buffer.
# Stub (own memory): push r15 / mov r15,rcx / mov rax,<code cave> / jmp rax.
# Way back: at RVA 0xD0E30 (only in this image) "pop r15; ret".
function Invoke-IslandCode($a, [byte[]]$scene, [int]$w, [int]$h) {
    Write-Image $a $Var.Width (I32 $w); Write-Image $a $Var.Height (I32 $h)
    Write-Image $a $LoaderContinueRva ([byte[]](0x41, 0x5F, 0xC3)) $true
    $buf = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]8192, 0x3000, 0x04)
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($buf -eq [IntPtr]::Zero -or $stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx failed.' }
    $done = [IntPtr]::Zero
    [void][TestMem]::WriteProcessMemory($a.H, $buf, $scene, [IntPtr]$scene.Length, [ref]$done)
    # Section header (name, length) at buffer+0x1800; rcx points to it as in the SZENE loader.
    $head = New-Object byte[] 20; [Array]::Copy([Text.Encoding]::ASCII.GetBytes('SZENE'), $head, 5); [Array]::Copy((I32 $scene.Length), 0, $head, 16, 4)
    [void][TestMem]::WriteProcessMemory($a.H, [IntPtr]($buf.ToInt64() + 0x1800), $head, [IntPtr]20, [ref]$done)
    $s = [byte[]](@(0x41, 0x57, 0x49, 0x89, 0xCF, 0x48, 0xB9) + [BitConverter]::GetBytes([long]($buf.ToInt64() + 0x1800)) + @(0x48, 0xB8) + [BitConverter]::GetBytes([long]($a.Base + $IslandCodeRva)) + @(0xFF, 0xE0))
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $s, [IntPtr]$s.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, $buf, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $wait = [TestMem]::WaitForSingleObject($t, 5000)
    [void][TestMem]::CloseHandle($t)
    if ($wait -ne 0) { throw "Thread did not finish (wait $wait)." }
    $r = New-Object byte[] $scene.Length
    [void][TestMem]::ReadProcessMemory($a.H, $buf, $r, [IntPtr]$r.Length, [ref]$done)
    [void][TestMem]::VirtualFreeEx($a.H, $buf, [IntPtr]::Zero, 0x8000)
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    , $r
}
# Runs the pirate code cave in the helper process and returns the game variable afterwards.
# Stub (own memory): mov rax,<code cave> / jmp rax. Way back RVA 0xC3239 only here: "ret".
function Invoke-PirateCode($a, [int]$flagsBefore, [int]$clock = 30000, [int]$goldBefore = 15000) {
    Write-Image $a $FlagsRva (I32 $flagsBefore)
    Write-Image $a $ClockRva (I32 $clock)
    Write-Image $a $Gold0Rva (I32 $goldBefore)
    Write-Image $a $TimersContinue ([byte[]](0xC3)) $true
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx failed.' }
    $done = [IntPtr]::Zero
    $s = [byte[]](@(0x48, 0xB8) + [BitConverter]::GetBytes([long]($a.Base + $PirateCaveRva)) + @(0xFF, 0xE0))
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $s, [IntPtr]$s.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, [IntPtr]::Zero, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $wait = [TestMem]::WaitForSingleObject($t, 5000)
    [void][TestMem]::CloseHandle($t)
    if ($wait -ne 0) { throw "Thread did not finish (wait $wait)." }
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    $script:GoldAfter = [BitConverter]::ToInt32((Read-Image $a $Gold0Rva 4), 0)
    [BitConverter]::ToInt32((Read-Image $a $FlagsRva 4), 0)
}

# Calls a function in the image of the helper process (thread) and returns eax as the result.
# Stub: [mov edx,<edx>] / sub rsp,0x28 / mov rax,<address> / call rax / add rsp,0x28 / [mov eax,edx] / ret
function Invoke-InImage($a, [long]$rva, [int]$edx = 0, [bool]$returnEdx = $false, [uint32]$timeoutMs = 5000) {
    $s = New-Object System.Collections.Generic.List[byte]
    $s.Add(0xBA); $s.AddRange([BitConverter]::GetBytes([int32]$edx))
    $s.AddRange([byte[]](0x48, 0x83, 0xEC, 0x28, 0x48, 0xB8)); $s.AddRange([BitConverter]::GetBytes([long]($a.Base + $rva)))
    $s.AddRange([byte[]](0xFF, 0xD0, 0x48, 0x83, 0xC4, 0x28))
    if ($returnEdx) { $s.AddRange([byte[]](0x89, 0xD0)) }
    $s.Add(0xC3)
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    if ($stub -eq [IntPtr]::Zero) { throw 'VirtualAllocEx failed.' }
    $done = [IntPtr]::Zero; $b = $s.ToArray()
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $b, [IntPtr]$b.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, [IntPtr]::Zero, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $wait = [TestMem]::WaitForSingleObject($t, $timeoutMs)
    $ec = [uint32]0; [void][TestMem]::GetExitCodeThread($t, [ref]$ec)
    [void][TestMem]::CloseHandle($t)
    if ($wait -ne 0) { throw "Thread did not finish (wait $wait)." }
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    [int]$ec
}

$script:failed = 0; $script:checks = 0
function Assert-Check([string]$what, [bool]$ok) {
    $script:checks++
    if ($ok) { Write-Host "  OK    $what" -ForegroundColor Green } else { Write-Host "  FAILED $what" -ForegroundColor Red; $script:failed++ }
}

# -Crt: additionally resolve the imports of the C runtime and kernel32 in the helper process and start it
# in the game folder, so that code of the game which reads files (haeuser.cod parser) can run there.
function Start-ImageProcess([switch]$Crt) {
    $out = Join-Path $tmp "image-$([guid]::NewGuid().ToString('N')).txt"
    $cmd = @"
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class L { [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryExW(string p, IntPtr f, uint fl); }'
`$m = [L]::LoadLibraryExW('$exe', [IntPtr]::Zero, 1)
if (`$m -eq [IntPtr]::Zero) { 'ERROR ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error() | Set-Content '$out'; exit 1 }
`$m.ToInt64().ToString() | Set-Content '$out'
Start-Sleep -Seconds 600
"@
    if ($Crt) {
        # Import directory: for every DLL api-ms-win-crt-*, VCRUNTIME140 and KERNEL32 GetProcAddress by name
        # into the IAT (other DLLs stay unresolved; the code run in the tests does not call them).
        $cmd = @"
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class L { [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryExW(string p, IntPtr f, uint fl); [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryW(string p); [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string n); [DllImport("kernel32.dll", SetLastError=true)] public static extern bool VirtualProtect(IntPtr a, IntPtr s, uint p, out uint o); }'
`$m = [L]::LoadLibraryExW('$exe', [IntPtr]::Zero, 1)
if (`$m -eq [IntPtr]::Zero) { 'ERROR ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error() | Set-Content '$out'; exit 1 }
`$b = `$m.ToInt64(); `$miss = 0
function Get-ImageI32([long]`$o) { [Runtime.InteropServices.Marshal]::ReadInt32([IntPtr](`$b + `$o)) }
function Get-ImageI64([long]`$o) { [Runtime.InteropServices.Marshal]::ReadInt64([IntPtr](`$b + `$o)) }
`$d = Get-ImageI32 ((Get-ImageI32 0x3C) + 24 + 120)
while ((Get-ImageI32 (`$d + 12)) -ne 0) {
    `$dll = [Runtime.InteropServices.Marshal]::PtrToStringAnsi([IntPtr](`$b + (Get-ImageI32 (`$d + 12))))
    if (`$dll -like 'api-ms-win-crt-*' -or `$dll -eq 'VCRUNTIME140.dll' -or `$dll -eq 'KERNEL32.dll') {
        `$h = [L]::LoadLibraryW(`$dll); `$ilt = Get-ImageI32 `$d; `$iat = Get-ImageI32 (`$d + 16); `$k = 0
        while ((`$v = Get-ImageI64 (`$ilt + 8 * `$k)) -ne 0) {
            `$p = [IntPtr]::Zero
            if (`$v -gt 0 -and `$h -ne [IntPtr]::Zero) { `$p = [L]::GetProcAddress(`$h, [Runtime.InteropServices.Marshal]::PtrToStringAnsi([IntPtr](`$b + `$v + 2))) }
            if (`$p -ne [IntPtr]::Zero) { `$a = [IntPtr](`$b + `$iat + 8 * `$k); `$o = [uint32]0; [void][L]::VirtualProtect(`$a, [IntPtr]8, 4, [ref]`$o); [Runtime.InteropServices.Marshal]::WriteInt64(`$a, `$p.ToInt64()); [void][L]::VirtualProtect(`$a, [IntPtr]8, `$o, [ref]`$o) } else { `$miss++ }
            `$k++
        }
    }
    `$d += 20
}
if (`$miss) { 'ERROR ' + `$miss + ' imports not resolved' | Set-Content '$out'; exit 1 }
`$m.ToInt64().ToString() | Set-Content '$out'
Start-Sleep -Seconds 600
"@
    }
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $p = if ($Crt) { Start-Process powershell -ArgumentList '-NoProfile', '-EncodedCommand', $enc -WindowStyle Hidden -PassThru -WorkingDirectory $GameFolder }
    else { Start-Process powershell -ArgumentList '-NoProfile', '-EncodedCommand', $enc -WindowStyle Hidden -PassThru }
    for ($i = 0; $i -lt 100 -and -not (Test-Path $out); $i++) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 200
    $txt = (Get-Content $out -Raw).Trim()
    if ($txt -like 'ERROR*') { throw "Image could not be loaded: $txt" }
    $h = [TestMem]::OpenProcess(0x0002 -bor 0x0008 -bor 0x0010 -bor 0x0020 -bor 0x0400, $false, $p.Id)
    @{ Proc = $p; Base = [long]$txt; H = $h }
}
function Stop-ImageProcess($a) { [void][TestMem]::CloseHandle($a.H); Stop-Process -Id $a.Proc.Id -Force -ErrorAction SilentlyContinue }
function Read-Image($a, [long]$rva, [int]$n) {
    $buf = New-Object byte[] $n; $done = [IntPtr]::Zero
    if (-not [TestMem]::ReadProcessMemory($a.H, [IntPtr]($a.Base + $rva), $buf, [IntPtr]$n, [ref]$done)) { throw ('Reading 0x{0:X}' -f $rva) }
    , $buf
}
function Write-Image($a, [long]$rva, [byte[]]$d, [bool]$code = $false) {
    $old = [uint32]0; $done = [IntPtr]::Zero
    if ($code) { [void][TestMem]::VirtualProtectEx($a.H, [IntPtr]($a.Base + $rva), [IntPtr]$d.Length, 0x40, [ref]$old) }
    if (-not [TestMem]::WriteProcessMemory($a.H, [IntPtr]($a.Base + $rva), $d, [IntPtr]$d.Length, [ref]$done)) { throw ('Writing 0x{0:X}' -f $rva) }
    if ($code) { $x = [uint32]0; [void][TestMem]::VirtualProtectEx($a.H, [IntPtr]($a.Base + $rva), [IntPtr]$d.Length, $old, [ref]$x) }
}
# Runs the tool against the helper process; $lang sets ANNO_EXTENSIONS_LANG for this run only.
function Invoke-Tool($a, [string[]]$extra, [string]$lang = 'en') {
    $ErrorActionPreference = 'Continue'   # the tool's error text comes via stderr
    $env:ANNO_EXTENSIONS_LANG = $lang
    try { $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $tool -TestProcessId $a.Proc.Id -TestBase $a.Base -WaitMinutes 1 @extra 2>&1 | Out-String }
    finally { $env:ANNO_EXTENSIONS_LANG = 'en' }
    @{ Code = $LASTEXITCODE; Text = $o }
}
function Get-CodeValues($a) { $r = [ordered]@{}; foreach ($k in $Code.Keys) { $r[$k] = Hex (Read-Image $a ($Code[$k] + 6) 4) }; $r }
function Get-VarValues($a) { $r = [ordered]@{}; foreach ($k in $Var.Keys) { $r[$k] = Hex (Read-Image $a $Var[$k] 4) }; $r }
function Test-Code($a, $expected, [string]$when) {
    $actual = Get-CodeValues $a
    foreach ($k in $Code.Keys) { Assert-Check "$when code $k = $($actual[$k])" ($actual[$k] -eq (Hex $expected[$CodeKind[$k]])) }
}
function Test-Vars($a, $expected, [string]$when) {
    $actual = Get-VarValues $a
    foreach ($k in $Var.Keys) { Assert-Check "$when variable $k = $($actual[$k])" ($actual[$k] -eq (Hex $expected[$k])) }
}
# Replays the program start (FUN_1400dbc60): width/height/range from the (possibly patched)
# immediates, 1/width and 1/height from the .rdata constants 0xEB8F4/0xEB8F8.
function Invoke-SimulatedStart($a) {
    Write-Image $a $Var.InvWidth (Read-Image $a 0xEB8F4 4)
    Write-Image $a $Var.Width (Read-Image $a ($Code['Width start'] + 6) 4)
    Write-Image $a $Var.Height (Read-Image $a ($Code['Height start'] + 6) 4)
    Write-Image $a $Var.Range (Read-Image $a ($Code['Range start'] + 6) 4)
    Write-Image $a $Var.InvHeight (Read-Image $a 0xEB8F8 4)
}

# --- Helpers for the cases AA-AH -------------------------------------------------------------------
# Runs the game's haeuser.cod parser in the image (helper process from Start-ImageProcess -Crt), then the
# follow-up FUN_140092e00 as at the program start (FUN_1400dbc60). Returns the result of the parser (1 = ok).
function Invoke-HaeuserParser($a) {
    $r = Invoke-InImage $a 0x90660 0 $false 30000
    [void](Invoke-InImage $a 0x92E00 0 $false 30000)
    $r
}
# Expected scaled value (independent of the tool): 0 stays 0, factor 0 -> 0, otherwise round half up, at
# least 1; $tons: in whole tons (x 32).
function Get-ExpectedScaled([long]$v, [double]$f, [bool]$tons) {
    if ($v -eq 0 -or $f -eq 0) { return [long]0 }
    $x = if ($tons) { $v / 32.0 * $f } else { $v * $f }
    $n = [long][math]::Floor($x + 0.5); if ($n -lt 1) { $n = 1 }
    if ($tons) { 32 * $n } else { $n }
}
function Get-TestSha256([byte[]]$b) { [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-', '').ToLower() }
# Bytes of the given fields (offset, length) of all 500 building entries in table order.
function Get-TestFieldBytes([byte[]]$tab, $fields) {
    $l = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt 500; $i++) { foreach ($f in $fields) { $l.AddRange([byte[]]$tab[($i * 0x90 + $f[0])..($i * 0x90 + $f[0] + $f[1] - 1)]) } }
    , $l.ToArray()
}
$TestCostFields = @(@(0x50, 2, $true), @(0x52, 2, $true), @(0x54, 2, $true), @(0x58, 4, $false))
$TestUpkeepFields = @(@(0x2A, 2, $false), @(0x2C, 2, $false))
function Get-TestField([byte[]]$tab, [int]$off, [int]$n) { if ($n -eq 4) { [long][BitConverter]::ToInt32($tab, $off) } else { [long][BitConverter]::ToUInt16($tab, $off) } }
# Compares a table after the tool with the original: the fields must be scaled, every other byte unchanged.
# Returns @{ Wrong = fields with a wrong value; Changed = changed fields; Other = other changed bytes }.
function Compare-ScaledTable([byte[]]$before, [byte[]]$after, $fields, [double]$f) {
    $wrong = 0; $changed = 0; $mask = New-Object bool[] $before.Length
    for ($i = 0; $i -lt 500; $i++) {
        foreach ($fd in $fields) {
            $off = $i * 0x90 + $fd[0]
            for ($k = 0; $k -lt $fd[1]; $k++) { $mask[$off + $k] = $true }
            $v = Get-TestField $before $off $fd[1]; $t = Get-TestField $after $off $fd[1]
            if ($t -ne (Get-ExpectedScaled $v $f $fd[2])) { $wrong++ }
            if ($t -ne $v) { $changed++ }
        }
    }
    $other = 0; for ($j = 0; $j -lt $before.Length; $j++) { if (-not $mask[$j] -and $before[$j] -ne $after[$j]) { $other++ } }
    @{ Wrong = $wrong; Changed = $changed; Other = $other }
}
# Test island in the island table of the image (0x14062ddc0, 50 x 0x2CC8): number, climate +0x1C, class +0x18,
# flags +0x44, fertility count +0x47, crop bits +0x5C, grid pointer +0x2CB0 (only "not 0" matters).
function Set-TestIsland($a, [int]$i, [int]$climate, [int]$class, [int]$flags, [int]$count, [int]$bits, [bool]$present = $true) {
    $o = 0x62DDC0 + $i * 0x2CC8
    Write-Image $a $o (I32 $i); Write-Image $a ($o + 0x1C) ([byte[]]@([byte]$climate)); Write-Image $a ($o + 0x18) ([BitConverter]::GetBytes([uint16]$class))
    Write-Image $a ($o + 0x44) ([byte[]]@([byte]$flags)); Write-Image $a ($o + 0x47) ([byte[]]@([byte]$count)); Write-Image $a ($o + 0x5C) (I32 $bits)
    Write-Image $a ($o + 0x2CB0) ([BitConverter]::GetBytes([long]$(if ($present) { 1 } else { 0 })))
}
# Calls FUN_1400d0ce0(crop, class min, class max, limit, out) in the image; returns the island numbers found.
function Invoke-CandidateIslands($a, [int]$ware, [int]$min, [int]$max, [int]$limit) {
    $buf = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x04)
    $stub = [TestMem]::VirtualAllocEx($a.H, [IntPtr]::Zero, [IntPtr]4096, 0x3000, 0x40)
    $s = New-Object System.Collections.Generic.List[byte]
    $s.AddRange([byte[]](0x48, 0x83, 0xEC, 0x38, 0x48, 0xB8)); $s.AddRange([BitConverter]::GetBytes([long]$buf.ToInt64()))   # sub rsp,0x38 / mov rax,out
    $s.AddRange([byte[]](0x48, 0x89, 0x44, 0x24, 0x20))                                                                     # mov [rsp+0x20],rax
    $s.Add(0xB9); $s.AddRange([BitConverter]::GetBytes([int32]$ware)); $s.Add(0xBA); $s.AddRange([BitConverter]::GetBytes([int32]$min))
    $s.AddRange([byte[]](0x41, 0xB8)); $s.AddRange([BitConverter]::GetBytes([int32]$max)); $s.AddRange([byte[]](0x41, 0xB9)); $s.AddRange([BitConverter]::GetBytes([int32]$limit))
    $s.AddRange([byte[]](0x48, 0xB8)); $s.AddRange([BitConverter]::GetBytes([long]($a.Base + 0xD0CE0)))
    $s.AddRange([byte[]](0xFF, 0xD0, 0x48, 0x83, 0xC4, 0x38, 0xC3))                                                         # call rax / add rsp,0x38 / ret
    $done = [IntPtr]::Zero; $b = $s.ToArray()
    [void][TestMem]::WriteProcessMemory($a.H, $stub, $b, [IntPtr]$b.Length, [ref]$done)
    $tid = [uint32]0
    $t = [TestMem]::CreateRemoteThread($a.H, [IntPtr]::Zero, [IntPtr]::Zero, $stub, [IntPtr]::Zero, 0, [ref]$tid)
    if ($t -eq [IntPtr]::Zero) { throw "CreateRemoteThread failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
    $wait = [TestMem]::WaitForSingleObject($t, 5000)
    $ec = [uint32]0; [void][TestMem]::GetExitCodeThread($t, [ref]$ec)
    [void][TestMem]::CloseHandle($t)
    if ($wait -ne 0) { throw "Thread did not finish (wait $wait)." }
    $r = New-Object byte[] 64
    [void][TestMem]::ReadProcessMemory($a.H, $buf, $r, [IntPtr]64, [ref]$done)
    [void][TestMem]::VirtualFreeEx($a.H, $buf, [IntPtr]::Zero, 0x8000)
    [void][TestMem]::VirtualFreeEx($a.H, $stub, [IntPtr]::Zero, 0x8000)
    (@(for ($k = 0; $k -lt [int]$ec; $k++) { $r[$k] }) -join ',')
}

# --- Helpers for the event cases AI-AO -------------------------------------------------------------------
# The tool's event engine runs in this test process against the helper process, exactly as in the tool (same
# functions, same C# class); only the timing is driven by the test (clock written, one poll at a time).
function Connect-EventEngine($a) { $script:h = [IntPtr]$a.H; $script:base = [IntPtr]$a.Base }
# Settlement table (75 x 600 bytes from RVA 0x622DC0): all slots free (+0x18 = 0xFF), then the given towns:
# @{ Slot; Name; Island; Owner; Limit (+0x20); Markets (+0x1FA); Workers (+0x218); Stages (+0x220, 5 ints); Stock = @{ good = amount x 32 } }
function Set-EventTowns($a, $towns) {
    $sb = New-Object byte[] (75 * 600)
    for ($i = 0; $i -lt 75; $i++) { $sb[$i * 600 + 0x18] = 0xFF }
    foreach ($t in $towns) {
        $o = $t.Slot * 600
        $nb = [Text.Encoding]::ASCII.GetBytes($t.Name); [Array]::Copy($nb, 0, $sb, $o, $nb.Length)
        $sb[$o + 0x18] = [byte]$t.Island; $sb[$o + 0x1A] = [byte]$t.Owner
        [Array]::Copy((I32 $t.Limit), 0, $sb, $o + 0x20, 4)
        [Array]::Copy([BitConverter]::GetBytes([uint16]$t.Markets), 0, $sb, $o + 0x1FA, 2)
        [Array]::Copy((I32 $t.Workers), 0, $sb, $o + 0x218, 4)
        for ($k = 0; $k -lt 5; $k++) { [Array]::Copy((I32 $t.Stages[$k]), 0, $sb, $o + 0x220 + 4 * $k, 4) }
        foreach ($gd in $t.Stock.Keys) { [Array]::Copy([BitConverter]::GetBytes([uint16]$t.Stock[$gd]), 0, $sb, $o + 0x2A + $gd * 12, 2) }
    }
    Write-Image $a $EventSettlementRva $sb
}
# The human's town: 100 pioneers + 50 settlers (stage 1), storage 30 t per good (960 - 320 + 1 x 320), tools 10 t,
# wood 30 t (full), bricks 28.1 t (less than 5 t room), food 25 t (5 t room).
$TestTown = @{ Slot = 3; Name = 'Testhafen'; Island = 2; Owner = 0; Limit = 960; Markets = 1; Workers = 20; Stages = @(100, 50, 0, 0, 0); Stock = @{ 22 = 320; 23 = 960; 24 = 900; 14 = 800 } }
$TestRivalTown = @{ Slot = 5; Name = 'Rivalia'; Island = 4; Owner = 1; Limit = 960; Markets = 1; Workers = 10; Stages = @(80, 0, 0, 0, 0); Stock = @{ 22 = 320 } }
$TestVillage = @{ Slot = 6; Name = 'Waldvolk'; Island = 7; Owner = 6; Limit = 960; Markets = 0; Workers = 0; Stages = @(60, 0, 0, 0, 0); Stock = @{} }
# Game clock, lock, local player 0 and player 0 (kind, gold).
function Set-EventGame($a, [int]$clock, [int]$gold = 20000, [int]$kind = 0, [int]$lock = 0) {
    Write-Image $a $ClockRva (I32 $clock); Write-Image $a $EventLockRva (I32 $lock); Write-Image $a $EventLocalPlayerRva (I32 0)
    Write-Image $a $EventPlayersRva (I32 $kind); Write-Image $a ($EventPlayersRva + 4) (I32 $gold)
}
function Get-EventGold($a) { [BitConverter]::ToInt32((Read-Image $a ($EventPlayersRva + 4) 4), 0) }
function Get-EventTaxText($a) { (0..4 | ForEach-Object { [BitConverter]::ToInt32((Read-Image $a ($TaxRva + $_ * $ResidentSize) 4), 0) }) -join '/' }
# Without the parser (plain image): taxes and a few intervals by hand, the storage of trading post I as the "loaded" signal.
function Set-EventTables($a) {
    for ($g = 0; $g -lt 5; $g++) { Write-Image $a ($TaxRva + $g * $ResidentSize) (I32 $TaxOrig[$g]) }
    Write-Image $a ($BuildingRva + 270 * $BuildingSize + $StorageOffset) ([BitConverter]::GetBytes([uint16]960))
    foreach ($e in @(@(10, 15), @(11, 30), @(12, 1), @(13, 330), @(14, 2))) { Write-Image $a ($BuildingRva + $e[0] * $BuildingSize + $IntervalOffset) ([BitConverter]::GetBytes([uint16]$e[1])) }
}
# A fresh engine for the helper process: page (allocated or reused), state, owner = this test process.
function New-EventEngine($a, [string]$first = '', [int]$seed = 1, [int]$duration = 1000, [string]$file = '', [int]$mean = 1000) {
    Connect-EventEngine $a
    $page = Get-EventPage $true
    Initialize-EventState $a.Proc.Id $mean $duration $seed $first $file
    [void][AnnoEvents]::SetOwner($PID, 0)
    $script:Ev.Next = [int]::MaxValue
    $page
}
# One poll at game clock $clock; $ms = real time since the previous poll (10 s: clock steps up to 2,200 are continuous).
function Step-Events($a, [int]$clock, [double]$ms = 10000) { Write-Image $a $ClockRva (I32 $clock); Invoke-EventTick $ms }
# A poll that triggers the next event (white box: the random interval is set to 1, afterwards to "never").
function Step-ForcedEvent($a, [int]$clock) { $script:Ev.Next = 1; $script:Ev.Progress = 0; Step-Events $a $clock; $script:Ev.Next = [int]::MaxValue }
function Get-EventPageInt([int]$off) { [BitConverter]::ToInt32([AnnoEvents]::ReadPage(), $off) }
function Get-EventIds { ($script:Ev.History | ForEach-Object { $_.id }) -join ',' }
# Work intervals of a building table snapshot; expected interval for a speed factor (round half up, 0 stays 0, at least 1).
function Get-TestIntervals([byte[]]$tab) { , [int[]]@(for ($i = 0; $i -lt 500; $i++) { [BitConverter]::ToUInt16($tab, $i * 0x90 + 0x3A) }) }
function Get-TestIntervalTarget([int]$v, [double]$f) { if ($v -eq 0) { 0 } else { [math]::Min(32767, [math]::Max(1, [int][math]::Floor($v / $f + 0.5))) } }
# Compares a table after an event with the snapshot: every interval as expected for $f, every other byte unchanged.
function Compare-EventTable([byte[]]$before, [byte[]]$after, [double]$f) {
    $wrong = 0; $changed = 0; $other = 0
    for ($j = 0; $j -lt $before.Length; $j++) {
        $k = $j % 0x90
        if ($k -eq 0x3A) {
            $v = [BitConverter]::ToUInt16($before, $j); $t = [BitConverter]::ToUInt16($after, $j)
            if ($t -ne (Get-TestIntervalTarget $v $f)) { $wrong++ }
            if ($t -ne $v) { $changed++ }
        }
        elseif ($k -ne 0x3B -and $before[$j] -ne $after[$j]) { $other++ }
    }
    @{ Wrong = $wrong; Changed = $changed; Other = $other }
}
function Read-EventJson([string]$file) { Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json }

function Test-EventCases {
    $tabLen = 500 * 0x90; $grpLen = 5 * 0x50; $setLen = 75 * 600
    $evDir = Join-Path $tmp 'events'
    $b = $null
    try {
        Write-Host 'AI Events: every event applies and restores exactly (real haeuser.cod)'
        $b = Start-ImageProcess -Crt
        Invoke-SimulatedStart $b
        [void](Invoke-HaeuserParser $b)
        Assert-Check 'AI event marker at RVA 0xE5BD0: 16 bytes 0 in a fresh image' ((Hex (Read-Image $b $EventMarkerRva 16)) -eq ((@('00') * 16) -join ' '))
        Set-EventTowns $b @($TestTown, $TestRivalTown, $TestVillage)
        Set-EventGame $b 1000 20000
        $g0 = Read-Image $b 0x6BA020 $grpLen; $t0 = Read-Image $b $BuildingRva $tabLen; $s0 = Read-Image $b $EventSettlementRva $setLen
        $file = Join-Path $evDir 'ai\events.json'
        $page = New-EventEngine $b 'patron,warehouse_fire,trader_gift,tax_windfall,tax_slump,harvest_boom,marsh_fever' 1 1000 $file
        $mk = Read-Image $b $EventMarkerRva 16; $pg = [AnnoEvents]::ReadPage()
        Assert-Check ("AI marker 'EVNT' version 1 -> page 0x{0:X} (allocated in the helper process), page header 'EVST', owner this test" -f $page) ([Text.Encoding]::ASCII.GetString($mk, 0, 4) -eq 'EVNT' -and [BitConverter]::ToInt32($mk, 4) -eq 1 -and [BitConverter]::ToInt64($mk, 8) -eq $page -and $page -ne 0 -and
            [Text.Encoding]::ASCII.GetString($pg, 0, 4) -eq 'EVST' -and [BitConverter]::ToInt32($pg, 8) -eq $PID)
        $gs = Get-EventGameState
        Assert-Check "AI game state: 1 own town (rival town and native village not counted), stage 1, 150 residents, gold 20,000" ($gs.Towns.Count -eq 1 -and $gs.Towns[0].Name -eq 'Testhafen' -and $gs.Stage -eq 1 -and $gs.Residents -eq 150 -and $gs.Gold -eq 20000 -and $gs.Towns[0].Limit -eq 960)
        Step-Events $b 1000
        Step-ForcedEvent $b 1100
        Assert-Check "AI patron: gold 20,000 -> $(Get-EventGold $b) (+4,000 at stage 1)" ((Get-EventGold $b) -eq 24000 -and (Get-EventIds) -eq 'patron')
        Step-ForcedEvent $b 1200
        Assert-Check "AI fire in the warehouse: gold 24,000 -> $(Get-EventGold $b) (-5 % = 1,200, at most 2,000 at stage 1)" ((Get-EventGold $b) -eq 22800 -and (Get-EventIds) -eq 'patron,warehouse_fire')
        Step-ForcedEvent $b 1300
        $s1 = Read-Image $b $EventSettlementRva $setLen
        $diff = @(for ($j = 0; $j -lt $setLen; $j++) { if ($s0[$j] -ne $s1[$j]) { $j } })
        $tools = [BitConverter]::ToUInt16($s1, 3 * 600 + 0x2A + 22 * 12); $food = [BitConverter]::ToUInt16($s1, 3 * 600 + 0x2A + 14 * 12)
        $okGift = ($tools -eq 800 -and $food -eq 800 -and @($diff | Where-Object { $_ -lt 3 * 600 + 0x2A + 22 * 12 -or $_ -gt 3 * 600 + 0x2A + 22 * 12 + 1 }).Count -eq 0) -or
            ($tools -eq 320 -and $food -eq 960 -and @($diff | Where-Object { $_ -lt 3 * 600 + 0x2A + 14 * 12 -or $_ -gt 3 * 600 + 0x2A + 14 * 12 + 1 }).Count -eq 0)
        Assert-Check "AI trader's gift: tools 10 t -> $($tools / 32) t (+15 t) or food 25 t -> $($food / 32) t (+5 t, up to the 30 t limit); wood (full) and bricks (< 5 t room) untouched, nothing else in the settlement table changed ($($diff.Count) bytes)" ($okGift -and (Get-EventGold $b) -eq 22800)
        $c = 1400
        foreach ($case in @(@('tax_windfall', '11/12/17/18/20', 1500), @('tax_slump', '5/6/8/9/10', 750))) {
            Step-ForcedEvent $b $c
            $g1 = Read-Image $b 0x6BA020 $grpLen
            $otherG = 0; for ($j = 0; $j -lt $grpLen; $j++) { if ((($j % 0x50) -lt 0x10 -or ($j % 0x50) -ge 0x14) -and $g0[$j] -ne $g1[$j]) { $otherG++ } }
            $pg = [AnnoEvents]::ReadPage()
            $pageBase = (0..4 | ForEach-Object { [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTaxBase + 4 * $_) }) -join '/'
            $pageNow = (0..4 | ForEach-Object { [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTaxApplied + 4 * $_) }) -join '/'
            Assert-Check "AI $($case[0]): taxes $(Get-EventTaxText $b) (expected $($case[1])), $otherG other group bytes changed; page: active, factor $([BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax + 8)), ends $([BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax + 12)), originals $pageBase, written $pageNow" (
                (Get-EventTaxText $b) -eq $case[1] -and $otherG -eq 0 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax) -eq 1 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax + 8) -eq $case[2] -and
                [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax + 12) -eq $c + 1000 -and $pageBase -eq '7/8/11/12/13' -and $pageNow -eq $case[1])
            Step-Events $b ($c + 999)
            Assert-Check "AI $($case[0]) still active one clock step before the end" ((Get-EventTaxText $b) -eq $case[1] -and $script:Ev.Tax)
            Step-Events $b ($c + 1000)
            Assert-Check "AI $($case[0]) over at its end clock: the 5 group records byte for byte as before, page inactive" ([BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g0) -and (Get-EventPageInt ([AnnoEvents]::OffTax)) -eq 0 -and -not $script:Ev.Tax)
            $c += 1100
        }
        foreach ($case in @(@('harvest_boom', 1.5, 1500), @('marsh_fever', 0.75, 750))) {
            Step-ForcedEvent $b $c
            $t1 = Read-Image $b $BuildingRva $tabLen
            $cmp = Compare-EventTable $t0 $t1 $case[1]
            $pg = [AnnoEvents]::ReadPage()
            Assert-Check "AI $($case[0]): $($cmp.Changed) work intervals x1/$($case[1]) ($($cmp.Wrong) wrong, $($cmp.Other) other bytes of the building table changed); page: active, factor $([BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd + 8)), $([BitConverter]::ToInt32($pg, [AnnoEvents]::OffProdCount)) changed" (
                $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $cmp.Changed -gt 100 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd) -eq 1 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd + 8) -eq $case[2] -and
                [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProdCount) -eq $cmp.Changed -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd + 12) -eq $c + 1000)
            Step-Events $b ($c + 1000)
            Assert-Check "AI $($case[0]) over: the building table byte for byte as before, page inactive" ([BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and (Get-EventPageInt ([AnnoEvents]::OffProd)) -eq 0 -and -not $script:Ev.Production)
            $c += 1100
        }
        Assert-Check "AI all 7 events in order: $(Get-EventIds)" ((Get-EventIds) -eq 'patron,warehouse_fire,trader_gift,tax_windfall,tax_slump,harvest_boom,marsh_fever')
        $j = Read-EventJson $file
        Assert-Check "AI events.json: $(@($j.events).Count) events, the same ids" (@($j.events).Count -eq 7 -and (@($j.events | ForEach-Object { $_.id }) -join ',') -eq (Get-EventIds))
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AJ Events: overlapping events (taxes and production at once; a busy kind is skipped)'
        $b = Start-ImageProcess -Crt
        Invoke-SimulatedStart $b
        [void](Invoke-HaeuserParser $b)
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 5000 20000
        $g0 = Read-Image $b 0x6BA020 $grpLen; $t0 = Read-Image $b $BuildingRva $tabLen
        [void](New-EventEngine $b 'tax_windfall,harvest_boom,tax_slump,marsh_fever,patron' 2 1000 (Join-Path $evDir 'aj\events.json'))
        Step-Events $b 5000
        Step-ForcedEvent $b 5100
        Step-ForcedEvent $b 5500
        $gs = Get-EventGameState
        $busy = @('tax_windfall', 'tax_slump', 'harvest_boom', 'marsh_fever' | Where-Object { Test-EventEligible $_ $gs })
        Assert-Check "AJ tax windfall (until 6100) and bumper harvest (until 6500) at once: taxes $(Get-EventTaxText $b), intervals x1/1.5; no further tax or production event possible ($($busy -join ','))" (
            (Get-EventTaxText $b) -eq '11/12/17/18/20' -and (Compare-EventTable $t0 (Read-Image $b $BuildingRva $tabLen) 1.5).Wrong -eq 0 -and $busy.Count -eq 0)
        Step-ForcedEvent $b 5700
        Assert-Check "AJ next event: tax slump and marsh fever skipped (busy), the patron instead: $(Get-EventIds), gold $(Get-EventGold $b)" ((Get-EventIds) -eq 'tax_windfall,harvest_boom,patron' -and (Get-EventGold $b) -eq 24000)
        Step-Events $b 6100
        Assert-Check "AJ 6100: windfall over (groups as before), harvest still on" ([BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g0) -and (Compare-EventTable $t0 (Read-Image $b $BuildingRva $tabLen) 1.5).Wrong -eq 0 -and $script:Ev.Production -and -not $script:Ev.Tax)
        Step-Events $b 6499
        Assert-Check 'AJ 6499: harvest still on' ((Compare-EventTable $t0 (Read-Image $b $BuildingRva $tabLen) 1.5).Wrong -eq 0)
        Step-Events $b 6500
        Assert-Check 'AJ 6500: harvest over, building table and groups byte for byte as before, page inactive' ([BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and [BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g0) -and
            (Get-EventPageInt ([AnnoEvents]::OffTax)) -eq 0 -and (Get-EventPageInt ([AnnoEvents]::OffProd)) -eq 0)
        # Since 3.0: a temporary event that ends before its time is marked "endedEarly" in events.json (the logbook then
        # stops showing it as running); events that ran their hour are not.
        $ajFile = Join-Path $evDir 'aj\events.json'
        $aj = Get-Content -LiteralPath $ajFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Check "AJ events that ran their hour are not marked as ended early ($(@($aj.events | Where-Object { $_.endedEarly }).Count) of $(@($aj.events).Count))" (@($aj.events | Where-Object { $_.endedEarly }).Count -eq 0 -and @($aj.events).Count -eq 3)
        $script:Ev.Script.Enqueue('marsh_fever')
        Step-ForcedEvent $b 6600
        Write-Image $b $EventLockRva (I32 1)
        Step-Events $b 6700
        Write-Image $b $EventLockRva (I32 0)
        $aj = Get-Content -LiteralPath $ajFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $ajLast = @($aj.events)[-1]
        Assert-Check "AJ marsh fever ended with the game: '$($ajLast.id)' endedEarly $($ajLast.endedEarly) in events.json, the others not, intervals byte for byte as before" ($ajLast.id -eq 'marsh_fever' -and $ajLast.endedEarly -eq $true -and @($aj.events | Where-Object { $_.endedEarly }).Count -eq 1 -and
            [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and -not (Get-ChildItem -LiteralPath (Split-Path $ajFile) -Filter '*.tmp-*'))
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AK Events with -Taxes 2 -Production 2'
        $b = Start-ImageProcess -Crt
        Invoke-SimulatedStart $b
        [void](Invoke-HaeuserParser $b)
        $t0 = Read-Image $b $BuildingRva $tabLen
        $r = Invoke-Tool $b @('-Taxes', '2', '-Production', '2')
        $g2 = Read-Image $b 0x6BA020 $grpLen; $t2 = Read-Image $b $BuildingRva $tabLen
        $halved = @(for ($i = 0; $i -lt 500; $i++) { $v = [BitConverter]::ToUInt16($t0, $i * 0x90 + 0x3A); if ([BitConverter]::ToUInt16($t2, $i * 0x90 + 0x3A) -ne $(if ($v) { [math]::Max(1, [math]::Round($v / 2)) } else { 0 })) { $i } })
        Assert-Check "AK tool with -Taxes 2 -Production 2: exit code $($r.Code), taxes $(Get-EventTaxText $b), intervals halved ($($halved.Count) wrong)" ($r.Code -eq 0 -and (Get-EventTaxText $b) -eq '14/16/22/24/26' -and $halved.Count -eq 0)
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 1000 20000
        [void](New-EventEngine $b 'tax_windfall,harvest_boom' 3 1000 '')
        Step-Events $b 1000
        Step-ForcedEvent $b 1100
        Step-ForcedEvent $b 1200
        $cmp = Compare-EventTable $t2 (Read-Image $b $BuildingRva $tabLen) 1.5
        Assert-Check "AK windfall on top of x2: taxes $(Get-EventTaxText $b) (14/16/22/24/26 x1.5); harvest on top of the halved intervals: $($cmp.Changed) changed, $($cmp.Wrong) wrong, $($cmp.Other) other bytes" ((Get-EventTaxText $b) -eq '21/24/33/36/39' -and $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $cmp.Changed -gt 50)
        $r = Invoke-Tool $b @('-Taxes', '2', '-Production', '2')
        Assert-Check "AK second tool run while the events run (owner alive): exit code $($r.Code), taxes and production not touched, no restore by that run" ($r.Code -eq 0 -and $r.Text -match 'Taxes: unexpected value 21 instead of 7' -and $r.Text -match 'Production x2: already set' -and $r.Text -notmatch 'earlier tool window' -and
            (Get-EventTaxText $b) -eq '21/24/33/36/39' -and (Compare-EventTable $t2 (Read-Image $b $BuildingRva $tabLen) 1.5).Wrong -eq 0)
        Step-Events $b 2100
        Assert-Check "AK windfall over: taxes back to the x2 values $(Get-EventTaxText $b), groups byte for byte" ([BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g2))
        Step-Events $b 2200
        Assert-Check 'AK harvest over: the halved intervals byte for byte (building table as after the tool)' ([BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t2))
        $r = Invoke-Tool $b @('-Taxes', '2', '-Production', '2')
        Assert-Check "AK third tool run: exit code $($r.Code), taxes x2 confirmed, production already set, nothing changed" ($r.Code -eq 0 -and $r.Text -match 'Taxes x2: 14/16/22/24/26 per resident group' -and $r.Text -match 'Production x2: already set' -and
            [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t2) -and [BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g2))
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AL events.json: format, newest last, at most 200, broken file, new folder'
        $b = Start-ImageProcess
        Invoke-SimulatedStart $b
        Set-EventTables $b
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 1000 20000
        $file = Join-Path $evDir 'al\new folder\events.json'
        [void](New-EventEngine $b 'patron,tax_windfall,trader_gift' 4 1000 $file)
        Step-Events $b 1000
        Step-ForcedEvent $b 1100; Step-ForcedEvent $b 1200; Step-ForcedEvent $b 1300
        $raw = [IO.File]::ReadAllBytes($file)
        $j = Read-EventJson $file
        $ev = @($j.events)
        Assert-Check "AL file in a new folder, UTF-8 without BOM, version $($j.version), $($ev.Count) events, newest last" ($raw[0] -eq [byte][char]'{' -and $j.version -eq 1 -and $ev.Count -eq 3 -and (@($ev | ForEach-Object { $_.id }) -join ',') -eq 'patron,tax_windfall,trader_gift')
        $okFields = $true
        foreach ($e in $ev) {
            foreach ($k in 'title', 'text', 'effect') { foreach ($l in 'de', 'en') { if (-not ($e.$k.$l -is [string]) -or -not $e.$k.$l) { $okFields = $false } } }
            if ($e.time -notmatch '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$' -or $e.pid -ne $b.Proc.Id -or -not ($e.clock -is [int])) { $okFields = $false }
        }
        Assert-Check 'AL every event: time (local ISO), pid of the game, clock, id, title/text/effect in de and en' $okFields
        Assert-Check "AL clocks $($ev[0].clock)/$($ev[1].clock)/$($ev[2].clock), endsClock $($ev[0].endsClock)/$($ev[1].endsClock)/$($ev[2].endsClock) (0 for instant events)" ($ev[0].clock -eq 1100 -and $ev[1].clock -eq 1200 -and $ev[2].clock -eq 1300 -and $ev[0].endsClock -eq 0 -and $ev[1].endsClock -eq 2200 -and $ev[2].endsClock -eq 0)
        Assert-Check "AL patron: '$($ev[0].title.de)' / '$($ev[0].title.en)', effect '$($ev[0].effect.de)' / '$($ev[0].effect.en)'" ($ev[0].title.de -ceq "Ein G$([char]0xF6)nner" -and $ev[0].title.en -ceq 'A patron' -and $ev[0].effect.de -ceq "+4'000 Gold" -and $ev[0].effect.en -ceq '+4,000 gold')
        Assert-Check "AL windfall effect '$($ev[1].effect.de)' / '$($ev[1].effect.en)'" ($ev[1].effect.de -ceq "Steuern +50 % f$([char]0xFC)r 1 Spielstunde" -and $ev[1].effect.en -ceq 'Taxes +50% for 1 game hour' -and $ev[1].text.de -match 'Konkurrenten')
        Assert-Check "AL gift names the town and the goods: '$($ev[2].effect.de)' / '$($ev[2].effect.en)'" ($ev[2].text.de -match 'Testhafen' -and $ev[2].text.en -match 'Testhafen' -and (($ev[2].effect.de -ceq '+15 t Werkzeug' -and $ev[2].effect.en -ceq '+15 t tools') -or ($ev[2].effect.de -ceq '+5 t Nahrung' -and $ev[2].effect.en -ceq '+5 t food')))
        Assert-Check 'AL no temp file left' (@(Get-ChildItem -LiteralPath (Split-Path $file) -Filter '*.tmp-*').Count -eq 0)
        $old = [ordered]@{ version = 1; events = @(1..199 | ForEach-Object { [ordered]@{ time = '2026-11-01T10:00:00'; pid = 1; clock = $_; id = "old-$_"; title = @{ de = 'a'; en = 'a' }; text = @{ de = 'b'; en = 'b' }; effect = @{ de = 'c'; en = 'c' }; endsClock = 0 } }) }
        [IO.File]::WriteAllText($file, (ConvertTo-Json -InputObject $old -Depth 5), (New-Object Text.UTF8Encoding $false))
        $n0 = $script:Ev.History.Count
        Step-ForcedEvent $b 1400; Step-ForcedEvent $b 1500; Step-ForcedEvent $b 1600
        $ev = @((Read-EventJson $file).events)
        $newIds = (@($script:Ev.History | Select-Object -Skip $n0 | ForEach-Object { $_.id }) -join ',')
        Assert-Check "AL 199 old + 3 new: $($ev.Count) kept, first '$($ev[0].id)', last three '$((@($ev | Select-Object -Last 3 | ForEach-Object { $_.id })) -join ',')'" ($ev.Count -eq 200 -and $ev[0].id -eq 'old-3' -and (@($ev | Select-Object -Last 3 | ForEach-Object { $_.id }) -join ',') -eq $newIds)
        Set-Content -LiteralPath $file -Value 'this is { not json'
        Step-ForcedEvent $b 1700
        $ev = @((Read-EventJson $file).events)
        Assert-Check "AL broken file: replaced by a valid one with $($ev.Count) event" ($ev.Count -eq 1 -and $ev[0].id -eq $script:Ev.History[-1].id)
        Set-Content -LiteralPath $file -Value '{"version":1}'
        Step-ForcedEvent $b 1800
        Assert-Check 'AL file without events: 1 event' (@((Read-EventJson $file).events).Count -eq 1)
        Assert-Check "AL number formats: $(Format-EventNumber 1234567 'de') / $(Format-EventNumber 1234567 'en') / $(Format-EventNumber -10000 'de')" ((Format-EventNumber 1234567 'de') -ceq "1'234'567" -and (Format-EventNumber 1234567 'en') -ceq '1,234,567' -and (Format-EventNumber -10000 'de') -ceq "10'000")
        $Width = 1000; $Height = 700
        $sa = (Get-SessionArgs ([ordered]@{ Events = 'Rare'; EventSeed = 3; EventScript = 'patron'; EventFile = 'x.json'; EventPollMs = 100; EventIntervalClock = 300; EventDurationClock = 500; EventTestUntilClock = 4000; Taxes = 2.5 })) -join ' '
        Assert-Check "AL saves.json arguments: '$sa' (-Events kept, its test switches not)" ($sa -eq '-Width 1000 -Height 700 -Events Rare -Taxes 2.5')
        Stop-TemporaryEvents 'Exit'
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AM Events: clock condition (clock stands still, no town, game over, load, jumps), interval, seed'
        $b = Start-ImageProcess
        Invoke-SimulatedStart $b
        Set-EventTables $b
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 1000 20000
        [void](New-EventEngine $b 'patron,patron,tax_windfall,tax_windfall,tax_windfall,tax_windfall' 5 1000 '')
        Step-Events $b 1000
        $script:Ev.Next = 1
        Step-Events $b 1000; Step-Events $b 1000
        Assert-Check "AM clock stands still (1000, 1000, 1000): no event, progress $($script:Ev.Progress)" ($script:Ev.History.Count -eq 0 -and $script:Ev.Progress -eq 0 -and (Get-EventGold $b) -eq 20000)
        Set-EventTowns $b @($TestRivalTown, $TestVillage)
        Step-Events $b 1100; Step-Events $b 1200
        Assert-Check "AM no own town (only a rival town and a native village): no event, progress $($script:Ev.Progress)" ($script:Ev.History.Count -eq 0 -and $script:Ev.Progress -eq 0)
        Set-EventTowns $b @($TestTown, $TestRivalTown, $TestVillage)
        Step-Events $b 1300
        $script:Ev.Next = [int]::MaxValue
        Assert-Check "AM first own town: the event comes ($(Get-EventIds), gold $(Get-EventGold $b))" ((Get-EventIds) -eq 'patron' -and (Get-EventGold $b) -eq 24000)
        Step-ForcedEvent $b 1400
        Step-ForcedEvent $b 1500
        Assert-Check "AM tax windfall running: $(Get-EventTaxText $b)" ((Get-EventTaxText $b) -eq '11/12/17/18/20')
        Write-Image $b $EventLockRva (I32 1)
        $script:Ev.Next = 1
        Step-Events $b 1600
        Assert-Check "AM game over (lock 1): windfall ended at once (taxes $(Get-EventTaxText $b)), no event ($(Get-EventIds))" ((Get-EventTaxText $b) -eq '7/8/11/12/13' -and -not $script:Ev.Tax -and (Get-EventIds) -eq 'patron,patron,tax_windfall' -and (Get-EventPageInt ([AnnoEvents]::OffTax)) -eq 0)
        Step-Events $b 1700
        Write-Image $b $EventLockRva (I32 0); Write-Image $b $EventPlayersRva (I32 9)
        Step-Events $b 1800; Step-Events $b 1900
        Assert-Check "AM lock 1 and then the human out (kind 9): no event ($($script:Ev.History.Count) in total)" ($script:Ev.History.Count -eq 3)
        Write-Image $b $EventPlayersRva (I32 0)
        Step-Events $b 0; Step-Events $b 0
        Assert-Check 'AM clock 0 (main menu): no event' ($script:Ev.History.Count -eq 3)
        $script:Ev.Next = [int]::MaxValue
        Step-Events $b 100
        Step-ForcedEvent $b 200
        Assert-Check "AM windfall again: $(Get-EventTaxText $b)" ((Get-EventTaxText $b) -eq '11/12/17/18/20')
        Step-Events $b 50
        Assert-Check "AM clock jumps back (a savegame is loaded): windfall ended at once ($(Get-EventTaxText $b)), progress $($script:Ev.Progress)" ((Get-EventTaxText $b) -eq '7/8/11/12/13' -and -not $script:Ev.Tax -and $script:Ev.Progress -eq 0)
        Step-Events $b 100
        Step-ForcedEvent $b 150
        Step-Events $b 5150 1000
        Assert-Check "AM clock +5,000 within 1 s (more than 16x can run): treated as another game, windfall ended ($(Get-EventTaxText $b))" ((Get-EventTaxText $b) -eq '7/8/11/12/13' -and -not $script:Ev.Tax -and $script:Ev.Progress -eq 0)
        Step-Events $b 5200
        Step-ForcedEvent $b 5300
        $script:Ev.Progress = 0
        Step-Events $b 8300 20000
        Assert-Check "AM clock +3,000 within 20 s (16x): the same game; the windfall ran its hour and ended normally ($(Get-EventTaxText $b)), progress $($script:Ev.Progress)" ((Get-EventTaxText $b) -eq '7/8/11/12/13' -and -not $script:Ev.Tax -and $script:Ev.Progress -eq 3000)
        $script:Ev.Progress = 0; $script:Ev.Next = 1000; $n0 = $script:Ev.History.Count
        Step-Events $b 8600; Step-Events $b 8900; Step-Events $b 9200
        $p900 = $script:Ev.Progress; $n900 = $script:Ev.History.Count
        Step-Events $b 9400
        Assert-Check "AM interval 1000: after +900 no event (progress $p900), after +1100 one event (progress $($script:Ev.Progress), next in $($script:Ev.Next))" ($p900 -eq 900 -and $n900 -eq $n0 -and $script:Ev.History.Count -eq $n0 + 1 -and $script:Ev.Progress -eq 0 -and $script:Ev.Next -ge 500 -and $script:Ev.Next -le 1500)
        Stop-TemporaryEvents 'Exit'
        Initialize-EventState 1 1000 1000 9 '' ''
        $iv = @(1..2000 | ForEach-Object { New-EventInterval })
        $avg = ($iv | Measure-Object -Average).Average
        Assert-Check ("AM 2,000 intervals for mean 1,000: {0}..{1}, average {2:0}; Rare {3}, Often {4}, duration {5} clock units" -f ($iv | Measure-Object -Minimum).Minimum, ($iv | Measure-Object -Maximum).Maximum, $avg, $EventMean.Rare, $EventMean.Often, $EventDuration) (
            ($iv | Measure-Object -Minimum).Minimum -ge 500 -and ($iv | Measure-Object -Maximum).Maximum -le 1500 -and [math]::Abs($avg - 1000) -lt 25 -and $EventMean.Rare -eq 98100 -and $EventMean.Often -eq 32700 -and $EventDuration -eq 32700)
        $seq = foreach ($seed in 21, 21, 22) {
            Set-EventTables $b; Set-EventTowns $b @($TestTown); Set-EventGame $b 1000 20000
            [void](New-EventEngine $b '' $seed 600 '' 1000)
            $script:Ev.Next = New-EventInterval
            Step-Events $b 1000
            for ($k = 1; $k -le 60; $k++) { Step-Events $b (1000 + 300 * $k) }
            Stop-TemporaryEvents 'Exit'
            Get-EventIds
        }
        $kinds = @($seq[0] -split ',' | Sort-Object -Unique)
        Assert-Check "AM seed 21 twice: the same $(@($seq[0] -split ',').Count) events ($($kinds -join ', ')); seed 22 another sequence" ($seq[0] -eq $seq[1] -and $seq[0] -ne $seq[2] -and @($seq[0] -split ',').Count -ge 10 -and $kinds.Count -ge 4)
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AN -Events Off; the real event loop of the tool (German messages)'
        $b = Start-ImageProcess -Crt
        Invoke-SimulatedStart $b
        [void](Invoke-HaeuserParser $b)
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 100 20000
        $g0 = Read-Image $b 0x6BA020 $grpLen; $t0 = Read-Image $b $BuildingRva $tabLen
        $file = Join-Path $evDir 'an\events.json'
        foreach ($ex in @(@(), @('-Events', 'Off', '-EventScript', 'patron'))) {
            $r = Invoke-Tool $b (@($ex) + @('-EventFile', $file))
            Assert-Check "AN $(if ($ex.Count) { '-Events Off' } else { 'without -Events' }): exit code $($r.Code), no event marker, no events.json, taxes, intervals and gold unchanged, no event message" ($r.Code -eq 0 -and (Hex (Read-Image $b $EventMarkerRva 16)) -eq ((@('00') * 16) -join ' ') -and -not (Test-Path -LiteralPath $file) -and
                [BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g0) -and [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and (Get-EventGold $b) -eq 20000 -and $r.Text -notmatch 'Event')
        }
        $log = Join-Path $tmp 'an.txt'
        $env:ANNO_EXTENSIONS_LANG = 'de'
        $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-TestProcessId', $b.Proc.Id, '-TestBase', $b.Base, '-WaitMinutes', 2, '-Events', 'Often', '-EventSeed', 4,
            '-EventScript', 'tax_windfall,patron,harvest_boom', '-EventIntervalClock', 300, '-EventDurationClock', 500, '-EventPollMs', 100, '-EventTestUntilClock', 4000, '-EventFile', "`"$file`"" -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
        $env:ANNO_EXTENSIONS_LANG = 'en'
        [void]$p.Handle
        # The clock only starts once the tool's event loop runs (marker written), so a slow start costs no events.
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt 60 -and [Text.Encoding]::ASCII.GetString((Read-Image $b $EventMarkerRva 4)) -ne 'EVNT') { Start-Sleep -Milliseconds 100 }
        $clock = 100; $sawTax = $false; $sawProd = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt 100) {
            Start-Sleep -Milliseconds 100
            if ($clock -lt 4100) { $clock += 15; Write-Image $b $ClockRva (I32 $clock) }
            if ((Get-EventTaxText $b) -eq '11/12/17/18/20') { $sawTax = $true }
            if (-not $sawProd -and [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -ne [BitConverter]::ToString($t0)) { $sawProd = $true }
        }
        $p.WaitForExit(30000) | Out-Null
        $out = (Get-Content $log -Raw) + (Get-Content "$log.err" -Raw)
        $ev = @((Read-EventJson $file).events)
        Assert-Check "AN -Events Often in the tool (clock +15 per 0.1 s up to 4,000): exit code $($p.ExitCode) after $([int]$sw.Elapsed.TotalSeconds) s, $($ev.Count) events: $((@($ev | ForEach-Object { $_.id })) -join ',')" (
            $p.ExitCode -eq 0 -and $ev.Count -ge 5 -and (@($ev | Select-Object -First 3 | ForEach-Object { $_.id }) -join ',') -eq 'tax_windfall,patron,harvest_boom' -and @($ev | Where-Object { $_.pid -ne $b.Proc.Id }).Count -eq 0)
        Assert-Check "AN during the run: taxes x1.5 seen $sawTax, intervals changed seen $sawProd" ($sawTax -and $sawProd)
        $pgOk = $false
        try { Connect-EventEngine $b; [void](Get-EventPage $false); $pg = [AnnoEvents]::ReadPage(); $pgOk = [BitConverter]::ToInt32($pg, [AnnoEvents]::OffOwner) -eq 0 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax) -eq 0 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd) -eq 0 }
        finally { [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0) }
        Assert-Check 'AN after the tool stopped: taxes and building table byte for byte as before, page without owner and without active events' (
            [BitConverter]::ToString((Read-Image $b 0x6BA020 $grpLen)) -eq [BitConverter]::ToString($g0) -and [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and $pgOk)
        Assert-Check 'AN German messages: events on, "*** Ereignis: Steuersegen - Steuern +50 % fuer 1 Spielstunde", "Ereignis vorbei", no English' (
            $out -match 'Ereignisse sind an \(Haeufig\)' -and $out -match '\*\*\* Ereignis: Steuersegen - Steuern \+50 % fuer 1 Spielstunde' -and $out -match 'Ein gutes Jahr auf allen Inseln' -and $out -match 'Ereignis vorbei: ' -and $out -notmatch '\*\*\* Event:' -and $out -notmatch 'Exception')
        if ($p.ExitCode -ne 0) { Write-Host $out }
        Stop-ImageProcess $b; $b = $null

        Write-Host 'AO Events left behind by a killed tool window; Stop() as on closing the window; check-game.ps1'
        $b = Start-ImageProcess -Crt
        Invoke-SimulatedStart $b
        [void](Invoke-HaeuserParser $b)
        $r = Invoke-Tool $b @()
        Set-EventTowns $b @($TestTown)
        Set-EventGame $b 1000 20000
        $g0 = Read-Image $b 0x6BA020 $grpLen; $t0 = Read-Image $b $BuildingRva $tabLen
        [void](New-EventEngine $b 'tax_windfall,harvest_boom' 6 5000 '')
        Step-Events $b 1000; Step-ForcedEvent $b 1100; Step-ForcedEvent $b 1200
        $r = Invoke-Tool $b @()
        Assert-Check "AO tool run while the owner (this test) still runs: exit code $($r.Code), nothing restored" ($r.Code -eq 0 -and $r.Text -notmatch 'earlier tool window' -and (Get-EventTaxText $b) -eq '11/12/17/18/20')
        Connect-EventEngine $b; [void](Get-EventPage $false)
        [void][AnnoEvents]::SetOwner(4, 1200)   # the owner is gone (PID 4 is no tool window)
        Write-Image $b ($TaxRva + 2 * $ResidentSize) (I32 99)   # meanwhile changed by someone else
        $r = Invoke-Tool $b @('-Events', 'Off')
        $pg = $null; try { Connect-EventEngine $b; [void](Get-EventPage $false); $pg = [AnnoEvents]::ReadPage() } finally { [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0) }
        Assert-Check "AO next tool run (-Events Off) after the owner is gone: exit code $($r.Code), taxes $(Get-EventTaxText $b) (group 2 left alone), building table as before, page cleared" ($r.Code -eq 0 -and
            $r.Text -match 'an earlier tool window left event values in the game; restored \(4 taxes, \d+ work intervals; 1 left alone' -and (Get-EventTaxText $b) -eq '7/8/99/12/13' -and
            [BitConverter]::ToString((Read-Image $b $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t0) -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffTax) -eq 0 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffProd) -eq 0 -and [BitConverter]::ToInt32($pg, [AnnoEvents]::OffOwner) -eq 0)
        Write-Image $b ($TaxRva + 2 * $ResidentSize) (I32 11)
        [void](New-EventEngine $b 'tax_slump,patron' 7 5000 '')
        Step-Events $b 1300; Step-ForcedEvent $b 1400
        $slump = Get-EventTaxText $b
        $rs = [AnnoEvents]::Stop()
        $apply = [AnnoEvents]::ApplyTax([int[]](7, 8, 11, 12, 13), [int[]](70, 80, 110, 120, 130), 3, 1500, 9999)
        $gold = [AnnoEvents]::AddGold($script:base.ToInt64() + $EventPlayersRva + 4, 5000, 0)
        Step-ForcedEvent $b 1500
        Assert-Check "AO Stop() (closing the window): slump $slump -> $(Get-EventTaxText $b) ($($rs[0]) restored), owner $(Get-EventPageInt ([AnnoEvents]::OffOwner)); afterwards nothing is written (ApplyTax $apply, AddGold blocked, patron not paid: gold $(Get-EventGold $b))" (
            $slump -eq '5/6/8/9/10' -and (Get-EventTaxText $b) -eq '7/8/11/12/13' -and $rs[0] -eq 5 -and (Get-EventPageInt ([AnnoEvents]::OffOwner)) -eq 0 -and $apply -eq 1 -and $gold -eq [long]::MinValue -and (Get-EventGold $b) -eq 20000 -and (Get-EventIds) -eq 'tax_slump')
        [void](New-EventEngine $b 'tax_windfall,marsh_fever' 8 5000 '')
        Step-Events $b 1600; Step-ForcedEvent $b 1700; Step-ForcedEvent $b 1800
        $check = Join-Path $root 'dev\check-game.ps1'
        $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $check -Short -TestProcessId $b.Proc.Id -TestBase $b.Base 2>&1 | Out-String
        Assert-Check "AO dev\check-game.ps1 shows the active events: $((($o -split "`n") | Where-Object { $_ -match '^Event' }) -join ' | ')" (
            $o -match 'Event taxes: Tax windfall x1\.5 until clock 6700: now 11/12/17/18/20, originals 7/8/11/12/13' -and $o -match 'Event production: Marsh fever x0\.75 until clock 6800: \d+ work intervals changed, as written' -and $o -match "Events \(marker 0xE5BD0\): page 0x[0-9A-F]+ \(EVST\), tool PID $PID \(running\)")
        Stop-TemporaryEvents 'Exit'
        $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $check -Short -TestProcessId $b.Proc.Id -TestBase $b.Base 2>&1 | Out-String
        Assert-Check 'AO check-game.ps1 after the end: no active event' ($o -match 'Event taxes: none' -and $o -match 'Event production: none')
        [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0)
        Assert-Check 'AO helper process still alive' (-not $b.Proc.HasExited)
        Stop-ImageProcess $b; $b = $null
    }
    finally {
        [AnnoEvents]::Configure([IntPtr]::Zero, 0, 0, 0, 0, 0, 0)
        if ($b) { Stop-ImageProcess $b }
    }
}

$orig = Get-ExpectedValues 500 350
$big = Get-ExpectedValues 1000 700
$exp1000 = Get-ExpectedTable 1000 700 $false
$exp750 = Get-ExpectedTable 750 525 $false
try {
    Write-Host 'Loading image ...'
    $a = Start-ImageProcess
    Write-Host ('  helper process PID {0}, image at 0x{1:X}' -f $a.Proc.Id, $a.Base)
    Test-Code $a $orig 'before'
    Assert-Check 'rdata 0xEB8F4 = 1/500' ((Hex (Read-Image $a 0xEB8F4 4)) -eq (Hex $orig.InvWidth))
    Assert-Check 'rdata 0xEB8F8 = 1/350' ((Hex (Read-Image $a 0xEB8F8 4)) -eq (Hex $orig.InvHeight))
    Test-Islands $a $false 'before'
    Assert-Check 'variables 0 at the start' (((Get-VarValues $a).Values | Where-Object { $_ -ne '00 00 00 00' }).Count -eq 0)

    Write-Host 'A  Game still starting (tool waits, then the program start is replayed)'
    $log = Join-Path $tmp 'a.txt'
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-TestProcessId', $a.Proc.Id, '-TestBase', $a.Base, '-WaitMinutes', 1 -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
    [void]$p.Handle   # otherwise ExitCode returns nothing later
    Start-Sleep -Seconds 4
    Assert-Check 'tool still waiting' (-not $p.HasExited)
    Test-Code $a $big 'A during'
    Invoke-SimulatedStart $a
    $p.WaitForExit(30000) | Out-Null
    Assert-Check "A exit code $($p.ExitCode)" ($p.ExitCode -eq 0)
    Write-Host (Get-Content $log -Raw)
    Test-Code $a $big 'A'
    Test-Vars $a $big 'A'
    Test-Islands $a $true 'A' $exp1000
    Test-Pirates $a 'Default' 'A'

    Write-Host 'B  Second run, same size (en and de)'
    $r = Invoke-Tool $a @()
    Assert-Check "B exit code $($r.Code)" ($r.Code -eq 0)
    Test-Code $a $big 'B'
    Test-Vars $a $big 'B'
    Test-Islands $a $true 'B' $exp1000
    Assert-Check 'B en: English messages only' ($r.Text -match 'exe checked: version matches, all \d+ sites found\.' -and $r.Text -match 'Target: 1000 x 700 tiles' -and
        $r.Text -match 'Game found \(PID' -and $r.Text -match 'Done\. Now start a NEW endless game' -and $r.Text -notmatch 'geprueft|Spiel gefunden|Inselplan|Fertig\.')
    $r = Invoke-Tool $a @() 'de'
    Assert-Check "B de: exit code $($r.Code), German messages" ($r.Code -eq 0 -and $r.Text -match 'exe geprueft: Version passt, alle \d+ Stellen gefunden\.' -and
        $r.Text -match 'Ziel: 1000 x 700 Felder \(normal 500 x 350\), Scrollbereich 850 \(normal 425\)\.' -and $r.Text -match 'Inselplan Anordnung 0: \d+ Inseln' -and
        $r.Text -match '  Breite        \(Programmstart\): 1000' -and $r.Text -match 'Aktuelle Kartengroesse im Spiel: 1000 x 700' -and
        $r.Text -match 'Fertig\. Jetzt im Spiel ein NEUES Endlosspiel starten \(keinen alten Spielstand laden\)\.' -and $r.Text -notmatch 'exe checked|Game found')

    Write-Host 'C  Other size against an already patched process'
    $r = Invoke-Tool $a @('-Width', '750', '-Height', '525')
    Assert-Check "C abort (exit code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes')
    Test-Code $a $big 'C'
    Test-Vars $a $big 'C'
    Test-Islands $a $true 'C' $exp1000
    $r = Invoke-Tool $a @('-Width', '750', '-Height', '525') 'de'
    # The error text arrives via stderr, wrapped at the console width: compare it without any whitespace.
    Assert-Check "C de: abort (exit code $($r.Code)), German message" ($r.Code -ne 0 -and $r.Text -match 'unerwartete Bytes' -and
        ($r.Text -replace '\s+', '') -match 'ImSpeicherstehenanBreite\(Programmstart\)unerwarteteBytes\([0-9A-F]+\)\.Abbruch,nichtsgeaendert\.')
    Stop-ImageProcess $a

    Write-Host 'D  One code site falsified'
    $a = Start-ImageProcess
    Write-Image $a ($Code['1/Height new'] + 6) ([byte[]](1, 2, 3, 4)) $true
    $r = Invoke-Tool $a @()
    Assert-Check "D abort (exit code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes')
    $actual = Get-CodeValues $a
    foreach ($k in @($Code.Keys | Where-Object { $_ -ne '1/Height new' })) { Assert-Check "D code $k unchanged" ($actual[$k] -eq (Hex $orig[$CodeKind[$k]])) }
    Test-Islands $a $false 'D'
    Assert-Check 'D variables unchanged 0' (((Get-VarValues $a).Values | Where-Object { $_ -ne '00 00 00 00' }).Count -eq 0)
    Stop-ImageProcess $a

    Write-Host 'E  750 x 525, game already started (variables at the original)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    Test-Vars $a $orig 'E before'
    $r = Invoke-Tool $a @('-Width', '750', '-Height', '525')
    Assert-Check "E exit code $($r.Code)" ($r.Code -eq 0)
    Write-Host $r.Text
    $mid = Get-ExpectedValues 750 525
    Test-Code $a $mid 'E'
    Test-Vars $a $mid 'E'
    Assert-Check 'E range = 637' ((Hex (Read-Image $a $Var.Range 4)) -eq (Hex (I32 637)))
    Test-Islands $a $true 'E' $exp750

    Stop-ImageProcess $a

    Write-Host 'I  Function test of the code cave with the real endless templates'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @()
    Assert-Check "I tool exit code $($r.Code)" ($r.Code -eq 0)
    Test-Islands $a $true 'I' $exp1000
    foreach ($lay in 0, 1, 2) {
        $scene = Read-Scene "[[48]]0$lay.szs"
        $plan = $exp1000.Plans[$lay]
        $target = [byte[]]$scene.Clone(); [Array]::Copy((I32 $plan.Count), 0, $target, 0x64, 4)
        for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $plan.Count) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $target, 0x174 + 16 * $i, 16) }
        $actual = Invoke-IslandCode $a $scene 1000 700
        Assert-Check ("I layout {0}: {1} -> {2} islands, all 1172 bytes as planned" -f $lay, [BitConverter]::ToInt32($scene, 0x64), [BitConverter]::ToInt32($actual, 0x64)) ((Hex $actual) -eq (Hex $target))
        $result = @(for ($i = 0; $i -lt [BitConverter]::ToInt32($actual, 0x64); $i++) { , [byte[]]$actual[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
        Test-Geometry $result 1000 700 "I layout $lay"
        $template = Get-StretchedScene $scene 1000 700
        $frontOk = $true
        for ($i = 0; $i -lt [BitConverter]::ToInt32($scene, 0x64); $i++) {
            if ((Hex $result[$i]) -ne (Hex ([byte[]]$template[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)]))) { $frontOk = $false }
        }
        Assert-Check "I layout ${lay}: the original islands are stretched at the front" $frontOk
    }
    $foreign = Read-Scene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($foreign, 0x17C) + 1)), 0, $foreign, 0x17C, 4)
    $actual = Invoke-IslandCode $a $foreign 1000 700
    Assert-Check 'I unknown template (x of the 1st island +1): only stretched' ((Hex $actual) -eq (Hex (Get-StretchedScene $foreign 1000 700)))
    $tooMany = Read-Scene '[[48]]10.szs'; [Array]::Copy((I32 60), 0, $tooMany, 0x64, 4)
    $actual = Invoke-IslandCode $a $tooMany 1000 700
    Assert-Check 'I island count 60 (> 50): nothing changed' ((Hex $actual) -eq (Hex $tooMany))
    Assert-Check 'I helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'H  -StretchOnly: templates are only stretched'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-StretchOnly')
    Assert-Check "H exit code $($r.Code)" ($r.Code -eq 0)
    $expStretch = Get-ExpectedTable 1000 700 $true
    $script:IslandCode = Build-IslandCode $false $false   # -StretchOnly: without the big map call
    Test-Islands $a $true 'H' $expStretch
    Assert-Check 'H big map code cave not set' ((Hex (Read-Image $a $BigMapCaveRva 8)) -eq '00 00 00 00 00 00 00 00')
    foreach ($g in @(@(1000, 700), @(750, 525), @(500, 350))) {
        $scene = Read-Scene '[[48]]10.szs'
        $actual = Invoke-IslandCode $a $scene $g[0] $g[1]
        Assert-Check ('H {0} x {1}: all 1172 bytes stretched (island 0: x {2}, y {3})' -f $g[0], $g[1], [BitConverter]::ToInt32($actual, 0x17C), [BitConverter]::ToInt32($actual, 0x180)) ((Hex $actual) -eq (Hex (Get-StretchedScene $scene $g[0] $g[1])))
    }
    $script:IslandCode = Build-IslandCode $false $true
    Stop-ImageProcess $a

    Write-Host 'G  -NoIslandSpread'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-NoIslandSpread')
    Assert-Check "G exit code $($r.Code)" ($r.Code -eq 0)
    Test-Code $a $big 'G'
    Test-Vars $a $big 'G'
    Test-Islands $a $false 'G'
    Stop-ImageProcess $a

    Write-Host 'J  -Pirates Active / Off / Strong'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Pirates', 'Active')
    Assert-Check "J Active exit code $($r.Code)" ($r.Code -eq 0)
    Assert-Check 'J en: option value shown in English (Pirates: Active)' ($r.Text -cmatch 'Pirates: Active')
    Test-Code $a $big 'J Active'
    Test-Islands $a $true 'J Active' $exp1000
    Test-Pirates $a 'Active' 'J Active'
    $r = Invoke-Tool $a @('-Pirates', 'Off')
    Assert-Check "J other pirate mode in the same process: abort (exit code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes')
    Test-Pirates $a 'Active' 'J after abort'
    $r = Invoke-Tool $a @('-Pirates', 'Active') 'de'
    Assert-Check "J de: exit code $($r.Code), option value shown in German (Piraten: Aktiv)" ($r.Code -eq 0 -and $r.Text -cmatch 'Piraten: Aktiv' -and $r.Text -cnotmatch 'Active')
    foreach ($case in @(@(0x9, 0x8), @(0x8, 0x8), @(0x2D, 0x2C), @(0x1, 0x0))) {
        $actual = Invoke-PirateCode $a $case[0]
        Assert-Check ('J Active function: flags 0x{0:X} -> 0x{1:X} (expected 0x{2:X})' -f $case[0], $actual, $case[1]) ($actual -eq $case[1])
    }
    Assert-Check 'J helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Pirates', 'Off')
    Assert-Check "J Off exit code $($r.Code)" ($r.Code -eq 0)
    Test-Pirates $a 'Off' 'J Off'
    foreach ($case in @(@(0x8, 0x9), @(0x9, 0x9), @(0x2C, 0x2D), @(0x0, 0x1))) {
        $actual = Invoke-PirateCode $a $case[0]
        Assert-Check ('J Off function: flags 0x{0:X} -> 0x{1:X} (expected 0x{2:X})' -f $case[0], $actual, $case[1]) ($actual -eq $case[1])
    }
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Pirates', 'Strong', '-NoIslandSpread')
    Assert-Check "J Strong exit code $($r.Code)" ($r.Code -eq 0)
    Test-Islands $a $false 'J Strong'
    Test-Pirates $a 'Strong' 'J Strong'
    $actual = Invoke-PirateCode $a 0x9
    Assert-Check ('J Strong function: flags 0x9 -> 0x{0:X}' -f $actual) ($actual -eq 0x8)
    Stop-ImageProcess $a

    Write-Host 'L  -StartGold (with and without -Pirates)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-StartGold', '50000')
    Assert-Check "L exit code $($r.Code)" ($r.Code -eq 0)
    Test-Pirates $a 'Default' 'L' 50000
    $actual = Invoke-PirateCode $a 0x9 24 15000
    Assert-Check "L new game (clock 24): gold 15000 -> $($script:GoldAfter), flags 0x$('{0:X}' -f $actual) unchanged" ($script:GoldAfter -eq 50000 -and $actual -eq 0x9)
    $actual = Invoke-PirateCode $a 0x9 999 15000
    Assert-Check "L clock 999: gold -> $($script:GoldAfter)" ($script:GoldAfter -eq 50000)
    $actual = Invoke-PirateCode $a 0x9 1000 12345
    Assert-Check "L savegame (clock 1000): gold stays $($script:GoldAfter)" ($script:GoldAfter -eq 12345)
    $actual = Invoke-PirateCode $a 0x8 84541 777
    Assert-Check "L savegame (clock 84541): gold stays $($script:GoldAfter), flags 0x$('{0:X}' -f $actual)" ($script:GoldAfter -eq 777 -and $actual -eq 0x8)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-StartGold', '1000000', '-Pirates', 'Strong')
    Assert-Check "L Strong+gold exit code $($r.Code)" ($r.Code -eq 0)
    Test-Pirates $a 'Strong' 'L Strong+gold' 1000000
    $actual = Invoke-PirateCode $a 0x9 10 15000
    Assert-Check "L Strong+gold new game: flags 0x$('{0:X}' -f $actual), gold $($script:GoldAfter)" ($actual -eq 0x8 -and $script:GoldAfter -eq 1000000)
    Assert-Check 'L helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'K  -ShipSpeed'
    function Get-SpeedAddress([int]$nr) { $FigureRva + $nr * $FigureSize + $SpeedOffset }
    function Set-OriginalSpeeds($a) { foreach ($nr in $ShipSpeedOrig.Keys) { Write-Image $a (Get-SpeedAddress $nr) (Bytes $ShipSpeedOrig[$nr]) } }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    Set-OriginalSpeeds $a
    $r = Invoke-Tool $a @('-ShipSpeed', '2')
    Assert-Check "K exit code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in $ShipSpeedOrig.Keys) {
        $o = [BitConverter]::ToSingle((Bytes $ShipSpeedOrig[$nr]), 0); $n = [BitConverter]::ToSingle((Read-Image $a (Get-SpeedAddress $nr) 4), 0)
        Assert-Check ('K ship no. {0}: {1} -> {2}' -f $nr, $o, $n) ([math]::Abs($n - 2 * $o) -lt 1e-6)
    }
    Assert-Check 'K neighbours no. 20 and 33 untouched' (((Hex (Read-Image $a (Get-SpeedAddress 20) 4)) -eq '00 00 00 00') -and ((Hex (Read-Image $a (Get-SpeedAddress 33) 4)) -eq '00 00 00 00'))
    $r = Invoke-Tool $a @('-ShipSpeed', '2')
    $n = [BitConverter]::ToSingle((Read-Image $a (Get-SpeedAddress 21) 4), 0)
    Assert-Check "K second run: exit code $($r.Code), small trading ship $n (not doubled)" ($r.Code -eq 0 -and [math]::Abs($n - 0.1) -lt 1e-6)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    Set-OriginalSpeeds $a
    Write-Image $a (Get-SpeedAddress 25) (F32 1.0)
    $r = Invoke-Tool $a @('-ShipSpeed', '1.5')
    Assert-Check "K unexpected value: exit code $($r.Code), note in the text" ($r.Code -eq 0 -and $r.Text -match 'NOT set')
    Assert-Check 'K unexpected value: nothing set' ((Hex (Read-Image $a (Get-SpeedAddress 21) 4)) -eq $ShipSpeedOrig[21])
    Test-Code $a $big 'K'
    Stop-ImageProcess $a

    Write-Host 'M  -Storage'
    function Get-StorageAddress([int]$nr) { $BuildingRva + $nr * $BuildingSize + $StorageOffset }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in $StorageOrig.Keys) { Write-Image $a (Get-StorageAddress $nr) ([BitConverter]::GetBytes([uint16]$StorageOrig[$nr])) }
    $r = Invoke-Tool $a @('-Storage', '3', '-ShipSpeed', '1.5')
    Assert-Check "M exit code $($r.Code) (ship values missing in the image: note expected)" ($r.Code -eq 0 -and $r.Text -match 'Ship values not loaded yet')
    foreach ($nr in ($StorageOrig.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Read-Image $a (Get-StorageAddress $nr) 2), 0)
        Assert-Check ('M building no. {0}: {1} -> {2} (expected {3})' -f $nr, $StorageOrig[$nr], $n, (3 * $StorageOrig[$nr])) ($n -eq 3 * $StorageOrig[$nr])
    }
    Assert-Check 'M neighbours no. 269 and 274 untouched' (((Hex (Read-Image $a (Get-StorageAddress 269) 2)) -eq '00 00') -and ((Hex (Read-Image $a (Get-StorageAddress 274) 2)) -eq '00 00'))
    $r = Invoke-Tool $a @('-Storage', '3')
    Assert-Check "M second run: exit code $($r.Code), trading post I $([BitConverter]::ToUInt16((Read-Image $a (Get-StorageAddress 270) 2), 0)) (not 9 times)" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Read-Image $a (Get-StorageAddress 270) 2), 0) -eq 2880)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in $StorageOrig.Keys) { Write-Image $a (Get-StorageAddress $nr) ([BitConverter]::GetBytes([uint16]$StorageOrig[$nr])) }
    Write-Image $a (Get-StorageAddress 272) ([BitConverter]::GetBytes([uint16]1234))
    $r = Invoke-Tool $a @('-Storage', '2')
    Assert-Check "M unexpected value: exit code $($r.Code), note in the text" ($r.Code -eq 0 -and $r.Text -match 'storage NOT set')
    Assert-Check 'M unexpected value: nothing set' ([BitConverter]::ToUInt16((Read-Image $a (Get-StorageAddress 270) 2), 0) -eq 960)
    Stop-ImageProcess $a

    Write-Host 'N  -Residents'
    function Get-ResidentAddress([int]$nr) { $ResidentRva + $nr * $ResidentSize }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in 0..4) { Write-Image $a (Get-ResidentAddress $nr) (I32 $ResidentOrig[$nr]) }
    $r = Invoke-Tool $a @('-Residents', '2')
    Assert-Check "N exit code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in 0..4) {
        $n = [BitConverter]::ToInt32((Read-Image $a (Get-ResidentAddress $nr) 4), 0)
        Assert-Check ('N group {0}: {1} -> {2} (expected {3})' -f $nr, $ResidentOrig[$nr], $n, (2 * $ResidentOrig[$nr])) ($n -eq 2 * $ResidentOrig[$nr])
    }
    Assert-Check 'N neighbour (tax of group 0, +4) untouched' ((Hex (Read-Image $a ((Get-ResidentAddress 0) + 4) 4)) -eq '00 00 00 00')
    $r = Invoke-Tool $a @('-Residents', '2')
    Assert-Check "N second run: exit code $($r.Code), group 4 = $([BitConverter]::ToInt32((Read-Image $a (Get-ResidentAddress 4) 4), 0)) (not 4 times)" ($r.Code -eq 0 -and [BitConverter]::ToInt32((Read-Image $a (Get-ResidentAddress 4) 4), 0) -eq 5120)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in 0..4) { Write-Image $a (Get-ResidentAddress $nr) (I32 $ResidentOrig[$nr]) }
    Write-Image $a (Get-ResidentAddress 2) (I32 999)
    $r = Invoke-Tool $a @('-Residents', '1.5')
    Assert-Check "N unexpected value: exit code $($r.Code), note in the text" ($r.Code -eq 0 -and $r.Text -match 'Residents: unexpected value')
    Assert-Check 'N unexpected value: nothing set' ([BitConverter]::ToInt32((Read-Image $a (Get-ResidentAddress 0) 4), 0) -eq 128)
    Stop-ImageProcess $a

    Write-Host 'O  -Cargo (holds; since 3.5 no longer the hull)'
    function Get-CargoAddress([int]$nr) { $FigureRva + $nr * $FigureSize + $CargoOffset }
    # The hull ("Maxenergy" x32 at +0x3E: 50/80/65/120) lies next to the holds and must stay.
    $HullOrig = @{ 21 = 1600; 22 = 1600; 23 = 2560; 24 = 2560; 25 = 2080; 26 = 2080; 27 = 3840; 28 = 3840 }
    function Get-Hulls($a) { ((21..28) | ForEach-Object { [BitConverter]::ToUInt16((Read-Image $a ($FigureRva + $_ * $FigureSize + 0x3E) 2), 0) }) -join '/' }
    Assert-Check "O holds offset +0x3A (Maxware), at most 8 holds, originals 4/6/3/8" ($CargoOffset -eq 0x3A -and $CargoMaxHolds -eq 8 -and (((21, 23, 25, 27) | ForEach-Object { $CargoOrig[$_] }) -join '/') -eq '4/6/3/8')
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in $CargoOrig.Keys) { Write-Image $a (Get-CargoAddress $nr) ([BitConverter]::GetBytes([uint16]$CargoOrig[$nr])); Write-Image $a ($FigureRva + $nr * $FigureSize + 0x3E) ([BitConverter]::GetBytes([uint16]$HullOrig[$nr])) }
    $hullsBefore = Get-Hulls $a
    $r = Invoke-Tool $a @('-Cargo', '1.5')
    Assert-Check "O exit code $($r.Code)" ($r.Code -eq 0)
    $expect15 = @{ 21 = 6; 22 = 6; 23 = 8; 24 = 8; 25 = 5; 26 = 5; 27 = 8; 28 = 8 }
    foreach ($nr in ($CargoOrig.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress $nr) 2), 0)
        Assert-Check ('O x1.5 ship no. {0}: {1} -> {2} holds (expected {3})' -f $nr, $CargoOrig[$nr], $n, $expect15[$nr]) ($n -eq $expect15[$nr] -and $n -eq (Get-CargoHolds $CargoOrig[$nr] 1.5))
    }
    Assert-Check "O hull untouched ($(Get-Hulls $a))" ((Get-Hulls $a) -eq $hullsBefore -and $hullsBefore -eq '1600/1600/2560/2560/2080/2080/3840/3840')
    Assert-Check 'O trader (no. 29) untouched' ((Hex (Read-Image $a (Get-CargoAddress 29) 2)) -eq '00 00')
    Assert-Check "O message: holds of 50 t" ($r.Text -match 'Cargo x1\.5: 6/8/5/8 holds of 50 t')
    $r = Invoke-Tool $a @('-Cargo', '1.5')
    Assert-Check "O second run: exit code $($r.Code), no. 21 = $([BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress 21) 2), 0)) holds" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress 21) 2), 0) -eq 6)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in $CargoOrig.Keys) { Write-Image $a (Get-CargoAddress $nr) ([BitConverter]::GetBytes([uint16]$CargoOrig[$nr])) }
    $r = Invoke-Tool $a @('-Cargo', '3')
    $holds = ((21..28) | ForEach-Object { [BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress $_) 2), 0) }) -join '/'
    Assert-Check "O x3: every buildable ship 8 holds ($holds), exit code $($r.Code)" ($r.Code -eq 0 -and $holds -eq '8/8/8/8/8/8/8/8')
    Stop-ImageProcess $a

    Write-Host 'P  -Production'
    function Get-IntervalAddress([int]$nr) { $BuildingRva + $nr * $BuildingSize + $IntervalOffset }
    # Plain hashtable: with [ordered], $probe[10] would be the 11th position instead of the key 10.
    $probe = @{ 10 = 15; 11 = 10; 12 = 330; 13 = 1; 14 = 0; 499 = 900 }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    Write-Image $a ($BuildingRva + 270 * $BuildingSize + $StorageOffset) ([BitConverter]::GetBytes([uint16]960))   # haeuser.cod has been read
    foreach ($nr in $probe.Keys) { Write-Image $a (Get-IntervalAddress $nr) ([BitConverter]::GetBytes([uint16]$probe[$nr])) }
    $r = Invoke-Tool $a @('-Production', '2')
    Assert-Check "P exit code $($r.Code), message" ($r.Code -eq 0 -and $r.Text -match 'Production x2: 4 work intervals shortened')
    foreach ($nr in ($probe.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Read-Image $a (Get-IntervalAddress $nr) 2), 0)
        $target = if ($probe[$nr] -eq 0) { 0 } else { [math]::Max(1, [int][math]::Round($probe[$nr] / 2)) }
        Assert-Check ('P building no. {0}: interval {1} -> {2} (expected {3})' -f $nr, $probe[$nr], $n, $target) ($n -eq $target)
    }
    Assert-Check 'P storage value (neighbouring field) untouched' ([BitConverter]::ToUInt16((Read-Image $a ($BuildingRva + 270 * $BuildingSize + $StorageOffset) 2), 0) -eq 960)
    Assert-Check "P marker set ($(Hex (Read-Image $a $ProdMarkerRva 8)))" ((Hex (Read-Image $a $ProdMarkerRva 8)) -eq '4E 55 46 52 C8 00 00 00')
    $r = Invoke-Tool $a @('-Production', '2')
    Assert-Check "P second run: exit code $($r.Code), no. 12 = $([BitConverter]::ToUInt16((Read-Image $a (Get-IntervalAddress 12) 2), 0)) (not quartered)" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Read-Image $a (Get-IntervalAddress 12) 2), 0) -eq 165 -and $r.Text -match 'already set')
    Stop-ImageProcess $a

    Write-Host 'Q  -Turbo'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    Assert-Check "Q before F7 = $(Hex (Read-Image $a 0xE3376 5))" ((Hex (Read-Image $a 0xE3376 5)) -eq 'B9 04 00 00 00')
    $r = Invoke-Tool $a @('-Turbo')
    Assert-Check "Q exit code $($r.Code)" ($r.Code -eq 0)
    Assert-Check "Q F7 = $(Hex (Read-Image $a 0xE3376 5))" ((Hex (Read-Image $a 0xE3376 5)) -eq 'B9 08 00 00 00')
    Assert-Check "Q F6 untouched ($(Hex (Read-Image $a 0xE335F 5)))" ((Hex (Read-Image $a 0xE335F 5)) -eq 'B9 02 00 00 00')
    $r = Invoke-Tool $a @('-Turbo', '-TurboLevel', '16')
    Assert-Check "Q other level in the already patched process: abort (exit code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes')
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Turbo', '-TurboLevel', '16')
    Assert-Check "Q 16x: exit code $($r.Code), F7 = $(Hex (Read-Image $a 0xE3376 5))" ($r.Code -eq 0 -and (Hex (Read-Image $a 0xE3376 5)) -eq 'B9 10 00 00 00')
    Stop-ImageProcess $a

    Write-Host 'R  -RivalGold'
    function Get-GoldAddress([int]$slot) { $Gold0Rva + $slot * $PlayerSize }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-RivalGold', '30000', '-StartGold', '50000')
    Assert-Check "R exit code $($r.Code)" ($r.Code -eq 0)
    # Do not call it $code: PowerShell does not distinguish upper and lower case, $Code is the table of code sites.
    $pirateCode = Build-PirateCode 'Default' 50000 30000
    Assert-Check "R code cave set ($($pirateCode.Length) bytes)" ((Hex (Read-Image $a $PirateCaveRva $pirateCode.Length)) -eq (Hex $pirateCode))
    foreach ($p in 1..4) { Write-Image $a (Get-GoldAddress $p) (I32 15000) }
    [void](Invoke-PirateCode $a 0x9 24 15000)
    $g = foreach ($p in 1..4) { [BitConverter]::ToInt32((Read-Image $a (Get-GoldAddress $p) 4), 0) }
    Assert-Check "R new game: player $($script:GoldAfter), rivals $($g[0..2] -join '/'), trader $($g[3])" ($script:GoldAfter -eq 50000 -and $g[0] -eq 30000 -and $g[1] -eq 30000 -and $g[2] -eq 30000 -and $g[3] -eq 15000)
    foreach ($p in 1..3) { Write-Image $a (Get-GoldAddress $p) (I32 4321) }
    [void](Invoke-PirateCode $a 0x9 30000 777)
    $g = foreach ($p in 1..3) { [BitConverter]::ToInt32((Read-Image $a (Get-GoldAddress $p) 4), 0) }
    Assert-Check "R savegame: player $($script:GoldAfter), rivals $($g -join '/') unchanged" ($script:GoldAfter -eq 777 -and ($g | Where-Object { $_ -ne 4321 }).Count -eq 0)
    Stop-ImageProcess $a

    Write-Host 'AP Mission time limit (TIMERS hook without options, function test)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @()
    Assert-Check "AP exit code $($r.Code)" ($r.Code -eq 0)
    Test-Pirates $a 'Default' 'AP'
    # local player, goal bits and deadline per mission slot, time limit before -> expected time limit afterwards
    $tlCases = @(
        @{ Name = 'scenario with a limit (slot 0)'; Local = 0; Bits = @(0x80, 0, 0, 0); Deadline = @(216000, 0, 0, 0); Before = 0; Expect = 216000 }
        @{ Name = 'endless game (no goal bits), stale deadline'; Local = 0; Bits = @(0, 0, 0, 0); Deadline = @(999, 0, 0, 0); Before = 0; Expect = 0 }
        @{ Name = 'original scenario (deadline 0)'; Local = 0; Bits = @(0x121, 0x121, 0, 0); Deadline = @(0, 0, 0, 0); Before = 5; Expect = 0 }
        @{ Name = 'local player 2 uses slot 2'; Local = 2; Bits = @(0x80, 0, 0x100, 0); Deadline = @(36000, 0, 72000, 0); Before = 0; Expect = 72000 }
        @{ Name = 'local player 3 (last slot)'; Local = 3; Bits = @(0, 0, 0, 0x20); Deadline = @(0, 0, 0, 108000); Before = 0; Expect = 108000 }
        @{ Name = 'local player out of range (7)'; Local = 7; Bits = @(0x80, 0x80, 0x80, 0x80); Deadline = @(1, 2, 3, 4); Before = 0; Expect = 0 }
        @{ Name = 'local player negative (-1)'; Local = -1; Bits = @(0x80, 0x80, 0x80, 0x80); Deadline = @(1, 2, 3, 4); Before = 0; Expect = 0 }
    )
    foreach ($tc in $tlCases) {
        Write-Image $a $LocalPlayerRva (I32 $tc.Local)
        foreach ($slot in 0..3) {
            Write-Image $a ($MissionRva + $slot * $MissionSize) (I32 $tc.Bits[$slot])
            Write-Image $a ($MissionRva + $slot * $MissionSize + 0x20) (I32 $tc.Deadline[$slot])
        }
        Write-Image $a $TimeLimitRva (I32 $tc.Before)
        $flags = Invoke-PirateCode $a 0x9 30000 4242
        $tl = [BitConverter]::ToInt32((Read-Image $a $TimeLimitRva 4), 0)
        Assert-Check ("AP {0}: time limit {1} (expected {2}), flags 0x{3:X} and gold {4} unchanged" -f $tc.Name, $tl, $tc.Expect, $flags, $script:GoldAfter) ($tl -eq $tc.Expect -and $flags -eq 0x9 -and $script:GoldAfter -eq 4242)
    }
    # The hook leaves rax (the loader's result) alone: only ecx/edx and RIP-relative stores in the time-limit part.
    $tlOnly = Build-PirateCode 'Default' 0 0 $true; $noTl = Build-PirateCode 'Default' 0 0 $false
    Assert-Check "AP time-limit part is $($tlOnly.Length - $noTl.Length) bytes, without it the cave is the old one ($($noTl.Length) bytes)" ($tlOnly.Length - $noTl.Length -eq 41 -and $noTl.Length -eq 12)
    $tlPart = Hex ($tlOnly[7..47])
    Assert-Check "AP time-limit part uses no rax/eax ($tlPart)" ($tlPart -match '^8B 0D .. .. .. .. 83 F9 03 77 1E 69 C9 8C 10 00 00 48 8D 15 .. .. .. .. 48 01 CA 83 3A 00 74 09 8B 52 20 89 15 .. .. .. ..$')
    $all = Build-PirateCode 'Strong' 1000000 60000
    Assert-Check "AP everything in the TIMERS cave fits ($($all.Length) bytes up to 0x$('{0:X}' -f ($PirateCaveRva + $all.Length)))" ($PirateCaveRva + $all.Length -le 0xE6000)
    Assert-Check 'AP helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'S  -IslandSize Huge -Resources Lots (function test with the real templates)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-IslandSize', 'Huge', '-Resources', 'Lots')
    Assert-Check "S exit code $($r.Code)" ($r.Code -eq 0)
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $tabS = Build-IslandTable 1000 700 $false 'Huge'; $plansS = $script:IslandPlans.Clone()
    $codeS = Build-IslandCode $true $true; $resS = Build-ResourceCode 200
    Assert-Check "S island code with call set ($($codeS.Length) bytes)" ((Hex (Read-Image $a $IslandCodeRva $codeS.Length)) -eq (Hex $codeS))
    Assert-Check "S resource code set ($($resS.Length) bytes)" ((Hex (Read-Image $a $ResourceCaveRva $resS.Length)) -eq (Hex $resS))
    Assert-Check "S table (Huge) set ($($tabS.Length) bytes)" ((Hex (Read-Image $a $TableRva $tabS.Length)) -eq (Hex $tabS))
    foreach ($file in '[[48]]00.szs', '[[48]]11.szs', '[[48]]32.szs') {
        $lay = [int][string]$file[7]
        $scene = Read-Scene $file
        $plan = $plansS[$lay]
        $old = [BitConverter]::ToInt32($scene, 0x64); $new = $plan.Count
        $target = [byte[]]$scene.Clone(); [Array]::Copy((I32 $new), 0, $target, 0x64, 4)
        for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $new) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $target, 0x174 + 16 * $i, 16) }
        $amounts = @()
        foreach ($o in $ResourceOffsets) {
            $m = [int][BitConverter]::ToUInt16($scene, $o)
            $v = [math]::Min($new, [int][math]::Truncate($m * $new * 200 / ($old * 100)))
            [Array]::Copy([BitConverter]::GetBytes([uint16]$v), 0, $target, $o, 2)
            if ($m -gt 0) { $amounts += "$m->$v" }
        }
        $actual = Invoke-IslandCode $a $scene 1000 700
        Assert-Check ("S {0}: {1} -> {2} islands, amounts {3}, all 1172 bytes as expected" -f $file, $old, $new, ($amounts -join ' ')) ((Hex $actual) -eq (Hex $target))
        $result = @(for ($i = 0; $i -lt $new; $i++) { , [byte[]]$actual[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] })
        Test-Geometry $result 1000 700 "S $file"
    }
    $foreign = Read-Scene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($foreign, 0x17C) + 1)), 0, $foreign, 0x17C, 4)
    $actual = Invoke-IslandCode $a $foreign 1000 700
    Assert-Check 'S unknown template: only stretched, resources unchanged' ((Hex $actual) -eq (Hex (Get-StretchedScene $foreign 1000 700)))
    Assert-Check 'S helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'T  IslandSize Large/Huge: geometry of all plans, start ships in the water'
    foreach ($g in @(@(1000, 700), @(2000, 1400), @(750, 525))) {
        foreach ($size in 'Normal', 'Large', 'Huge') {
            [void](Build-IslandTable $g[0] $g[1] $false $size)
            foreach ($lay in 0, 1, 2) {
                $ships = Read-Ships (Join-Path $GameFolder "Szenes\[[48]]1$lay.szs"); $hits = @()
                foreach ($e in $script:IslandPlans[$lay]) {
                    $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12); $c = $e[1]
                    foreach ($sp in $ships) { if ($sp[0] -ge $x - 2 -and $sp[0] -lt $x + $ClassW[$c] + 2 -and $sp[1] -ge $y - 2 -and $sp[1] -lt $y + $ClassH[$c] + 2) { $hits += "$($sp[0]),$($sp[1])" } }
                }
                Assert-Check ("T {0} {1}x{2} layout {3}: {4} start ships free {5}" -f $size, $g[0], $g[1], $lay, $ships.Count, ($hits -join ' ')) ($ships.Count -eq 4 -and $hits.Count -eq 0)
            }
        }
        foreach ($size in 'Large', 'Huge') {
            [void](Build-IslandTable $g[0] $g[1] $false $size)
            foreach ($lay in 0, 1, 2) {
                $p = $script:IslandPlans[$lay]
                $bigCount = @($p | Where-Object { $_[1] -ge 3 }).Count; $lar = @($p | Where-Object { $_[1] -eq 4 }).Count
                Test-Geometry $p $g[0] $g[1] ("T {0} {1}x{2} layout {3} ({4} of them big/lar)" -f $size, $g[0], $g[1], $lay, $bigCount)
                Assert-Check ("T {0} {1}x{2} layout {3}: at most 10 lar ({4})" -f $size, $g[0], $g[1], $lay, $lar) ($lar -le 10)
            }
        }
    }

    Write-Host 'U  -Rivals Hard'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($g in $RivalSites) { Assert-Check ("U before {0} = {1}" -f $g.Name, (Hex (Read-Image $a $g.Rva 6))) ((Hex (Read-Image $a $g.Rva 6)) -eq $g.Original) }
    $r = Invoke-Tool $a @('-Rivals', 'Hard')
    Assert-Check "U exit code $($r.Code)" ($r.Code -eq 0 -and $r.Text -match 'always as on Hard')
    foreach ($g in $RivalSites) { Assert-Check ("U {0} = {1}" -f $g.Name, (Hex (Read-Image $a $g.Rva 6))) ((Hex (Read-Image $a $g.Rva 6)) -eq 'B8 03 00 00 00 90') }
    Assert-Check "U natural events (RVA 0x9E781) untouched" ((Hex (Read-Image $a 0x9E781 6)) -eq '8B 05 39 DA 54 00')
    Assert-Check "U pirate cannons (RVA 0x3B94B) untouched" ((Hex (Read-Image $a 0x3B94B 6)) -eq '8B 05 6F 08 5B 00')
    $r = Invoke-Tool $a @('-Rivals', 'Hard')
    Assert-Check "U second run: exit code $($r.Code)" ($r.Code -eq 0)
    Stop-ImageProcess $a

    Write-Host 'V  -PirateFleet Large/Huge (function test with FUN_1400185f0 in the image)'
    $FlagsSlot0 = 0x5F09CC   # player table slot 0 +0x6C: civilisation bits 18/24/29/30
    foreach ($mode in 'Large', 'Huge') {
        $f = @{ Large = 2; Huge = 3 }[$mode]
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        Assert-Check "V $mode before call = $(Hex (Read-Image $a $FleetCallRva 5))" ((Hex (Read-Image $a $FleetCallRva 5)) -eq 'E8 FA CD FD FF')
        $r = Invoke-Tool $a @('-PirateFleet', $mode)
        Assert-Check "V $mode exit code $($r.Code)" ($r.Code -eq 0)
        $fc = Build-FleetCode $f
        Assert-Check "V $mode code cave set ($(Hex $fc))" ((Hex (Read-Image $a $FleetCaveRva $fc.Length)) -eq (Hex $fc))
        $call = Hex ([byte[]](@(0xE8) + (Rel32 $FleetCaveRva ($FleetCallRva + 5))))
        Assert-Check "V $mode call redirected ($(Hex (Read-Image $a $FleetCallRva 5)))" ((Hex (Read-Image $a $FleetCallRva 5)) -eq $call)
        foreach ($w in $FleetWait) {
            $actual = [BitConverter]::ToInt32((Read-Image $a ($w.Rva + 6) 4), 0); $target = [int][math]::Floor(1000 / $f)
            Assert-Check ("V {0} wait time RVA 0x{1:X}: x{2} (expected {3}), instruction otherwise the same" -f $mode, $w.Rva, $actual, $target) ($actual -eq $target -and (Hex (Read-Image $a $w.Rva 6)) -eq (Hex (Bytes $w.Original)[0..5]))
        }
        foreach ($level in @(@(0, 0), @(0x00040000, 1), @(0x01000000, 2), @(0x20000000, 3), @(0x40000000, 4))) {
            Write-Image $a $FlagsSlot0 (I32 $level[0])
            $o = Invoke-InImage $a $LevelRva; $n = Invoke-InImage $a $FleetCaveRva
            Assert-Check ("V {0} level {1}: FUN_1400185f0 = {2}, code cave = {3} (expected {4})" -f $mode, $level[1], $o, $n, ($level[1] * $f)) ($o -eq $level[1] -and $n -eq $level[1] * $f)
        }
        Assert-Check "V $mode helper process still alive" (-not $a.Proc.HasExited)
        Stop-ImageProcess $a
    }

    Write-Host 'W  -Traders More/Lots (function test)'
    foreach ($mode in 'More', 'Lots') {
        $f = @{ More = 2; Lots = 3 }[$mode]
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        Assert-Check "W $mode before = $(Hex (Read-Image $a $TraderRva 5))" ((Hex (Read-Image $a $TraderRva 5)) -eq 'C1 E8 1F 03 D0')
        $r = Invoke-Tool $a @('-Traders', $mode)
        Assert-Check "W $mode exit code $($r.Code)" ($r.Code -eq 0)
        $tc = Build-TraderCode $f
        Assert-Check "W $mode code cave set ($(Hex $tc))" ((Hex (Read-Image $a $TraderCaveRva $tc.Length)) -eq (Hex $tc))
        $call = Hex ([byte[]](@(0xE8) + (Rel32 $TraderCaveRva ($TraderRva + 5))))
        Assert-Check "W $mode call set ($(Hex (Read-Image $a $TraderRva 5)))" ((Hex (Read-Image $a $TraderRva 5)) -eq $call)
        Assert-Check "W $mode instructions before/after untouched" ((Hex (Read-Image $a 0xBC13E 2)) -eq '8B C2' -and (Hex (Read-Image $a 0xBC145 2)) -eq '39 15')
        foreach ($n in 0, 1, 4, 5, 8, 12, 13, 30) {
            $actual = Invoke-InImage $a $TraderCaveRva $n $true; $target = [math]::Min($n * $f, 24)
            Assert-Check ("W {0}: target {1} -> {2} (expected {3})" -f $mode, $n, $actual, $target) ($actual -eq $target)
        }
        Stop-ImageProcess $a
    }

    Write-Host 'X  -Natives (function test with the real templates, with and without resources)'
    foreach ($case in @(@('More', 'Normal', 4, 0), @('Lots', 'Lots', 7, 200))) {
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-Natives', $case[0], '-Resources', $case[1])
        Assert-Check "X $($case[0])/$($case[1]) exit code $($r.Code)" ($r.Code -eq 0 -and $r.Text -match ("{0} villages per climate zone" -f $case[2]))
        [void](Build-IslandTable 1000 700 $false 'Normal'); $plansX = $script:IslandPlans.Clone()
        $resX = Build-ResourceCode $case[3] $case[2]
        Assert-Check "X $($case[0]) scene code cave set ($($resX.Length) bytes, ends before 0x$('{0:X}' -f $ResourceCaveEnd))" ((Hex (Read-Image $a $ResourceCaveRva $resX.Length)) -eq (Hex $resX) -and $ResourceCaveRva + $resX.Length -le $ResourceCaveEnd)
        foreach ($file in '[[48]]00.szs', '[[48]]21.szs') {
            $lay = [int][string]$file[7]
            $scene = Read-Scene $file
            $plan = $plansX[$lay]
            $old = [BitConverter]::ToInt32($scene, 0x64); $new = $plan.Count
            $target = [byte[]]$scene.Clone(); [Array]::Copy((I32 $new), 0, $target, 0x64, 4)
            for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $new) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $target, 0x174 + 16 * $i, 16) }
            if ($case[3] -gt 0) {
                foreach ($o in $ResourceOffsets) {
                    $m = [int][BitConverter]::ToUInt16($scene, $o)
                    [Array]::Copy([BitConverter]::GetBytes([uint16][math]::Min($new, [int][math]::Truncate($m * $new * $case[3] / ($old * 100)))), 0, $target, $o, 2)
                }
            }
            [Array]::Copy((I32 $case[2]), 0, $target, 0x40, 4); [Array]::Copy((I32 $case[2]), 0, $target, 0x44, 4)
            $actual = Invoke-IslandCode $a $scene 1000 700
            Assert-Check ("X {0} {1}: {2} -> {3} islands, villages {4}/{5} -> {6}/{7}, all 1172 bytes as expected" -f $case[0], $file, $old, $new, [BitConverter]::ToInt32($scene, 0x40), [BitConverter]::ToInt32($scene, 0x44), [BitConverter]::ToInt32($actual, 0x40), [BitConverter]::ToInt32($actual, 0x44)) ((Hex $actual) -eq (Hex $target))
        }
        Stop-ImageProcess $a
    }

    Write-Host 'Z  Big campaign maps (extended SZENE section, function test)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @()
    Assert-Check "Z exit code $($r.Code)" ($r.Code -eq 0)
    $bm = Build-BigMapCode
    Assert-Check "Z big map code cave set ($($bm.Length) bytes)" ((Hex (Read-Image $a $BigMapCaveRva $bm.Length)) -eq (Hex $bm))
    # Small version: endless template with a shifted first island (unknown -> only stretch).
    $small = Read-Scene '[[48]]10.szs'; [Array]::Copy((I32 ([BitConverter]::ToInt32($small, 0x17C) + 1)), 0, $small, 0x17C, 4)
    # Big version: the tool's plan for 1000 x 700, plus other village and gold amounts.
    $plan = Get-IslandPlan (Read-Template (Join-Path $GameFolder 'Szenes\[[48]]10.szs')) 1000 700 $false 'Normal'
    $bigB = [byte[]]$small.Clone(); [Array]::Copy((I32 $plan.Count), 0, $bigB, 0x64, 4)
    for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $plan.Count) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $bigB, 0x174 + 16 * $i, 16) }
    [Array]::Copy((I32 5), 0, $bigB, 0x40, 4); [Array]::Copy([BitConverter]::GetBytes([uint16]7), 0, $bigB, 0xA6, 2)
    function Join-Versions([byte[]]$k, [byte[]]$g, [string]$marker = 'GROS', [int]$shorter = 0) {
        $x = New-Object byte[] 16; [Array]::Copy([Text.Encoding]::ASCII.GetBytes($marker), $x, 4); [Array]::Copy((I32 1000), 0, $x, 4, 4); [Array]::Copy((I32 700), 0, $x, 8, 4); [Array]::Copy((I32 1), 0, $x, 12, 4)
        $l = [byte[]]($k + $x + $g); , [byte[]]$l[0..($l.Length - 1 - $shorter)]
    }
    function Get-StretchedBig([byte[]]$g, [int]$w, [int]$h, [int]$dw = 1000, [int]$dh = 700) {
        $e = [byte[]]$g.Clone(); $n = [BitConverter]::ToInt32($g, 0x64)
        for ($i = 0; $i -lt $n; $i++) { $p = 0x174 + 16 * $i
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 8) * $w / $dw))), 0, $e, $p + 8, 4)
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 12) * $h / $dh))), 0, $e, $p + 12, 4) }
        , $e
    }
    $long = Join-Versions $small $bigB
    Assert-Check "Z extended section: $($long.Length) bytes" ($long.Length -eq 2360)
    foreach ($case in @(@(1000, 700, 'big'), @(2000, 1400, 'big'), @(750, 525, 'small'), @(500, 350, 'small'))) {
        $actual = Invoke-IslandCode $a $long $case[0] $case[1]
        $front = if ($case[2] -eq 'big') { Get-StretchedBig $bigB $case[0] $case[1] } else { Get-StretchedScene $small $case[0] $case[1] }
        $ok = ((Hex ([byte[]]$actual[0..1171])) -eq (Hex $front)) -and ((Hex ([byte[]]$actual[1172..2359])) -eq (Hex ([byte[]]$long[1172..2359])))
        Assert-Check ('Z {0} x {1}: {2} version ({3} islands, island 0 at {4}/{5}, villages {6}), rest unchanged' -f $case[0], $case[1], $case[2], [BitConverter]::ToInt32($actual, 0x64), [BitConverter]::ToInt32($actual, 0x17C), [BitConverter]::ToInt32($actual, 0x180), [BitConverter]::ToInt32($actual, 0x40)) $ok
        if ($case[2] -eq 'big') { $e = @(for ($i = 0; $i -lt [BitConverter]::ToInt32($actual, 0x64); $i++) { , [byte[]]$actual[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] }); Test-Geometry $e $case[0] $case[1] "Z $($case[0]) x $($case[1])" }
    }
    foreach ($case in @(@('wrong marker', (Join-Versions $small $bigB 'GROX')), @('too short', (Join-Versions $small $bigB 'GROS' 10)))) {
        $actual = Invoke-IslandCode $a $case[1] 1000 700
        Assert-Check "Z $($case[0]): only the small version stretched" ((Hex ([byte[]]$actual[0..1171])) -eq (Hex (Get-StretchedScene $small 1000 700)))
    }
    # Since 3.1: a third version for the giant world (designed for 2000 x 1400) behind the big one; the code cave takes
    # the last version that fits the map, so the giant one at 2000 x 1400 and the big one below.
    $planG = Get-IslandPlan (Read-Template (Join-Path $GameFolder 'Szenes\[[48]]10.szs')) 2000 1400 $false 'Large'
    $giantB = [byte[]]$small.Clone(); [Array]::Copy((I32 $planG.Count), 0, $giantB, 0x64, 4)
    for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $planG.Count) { $planG[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $giantB, 0x174 + 16 * $i, 16) }
    [Array]::Copy((I32 7), 0, $giantB, 0x40, 4); [Array]::Copy((I32 7), 0, $giantB, 0x44, 4)
    function New-VersionHead([string]$marker, [int]$w, [int]$h) {
        $x = New-Object byte[] 16; [Array]::Copy([Text.Encoding]::ASCII.GetBytes($marker), $x, 4); [Array]::Copy((I32 $w), 0, $x, 4, 4); [Array]::Copy((I32 $h), 0, $x, 8, 4); [Array]::Copy((I32 1), 0, $x, 12, 4); , $x
    }
    $three = [byte[]]($long + (New-VersionHead 'GROS' 2000 1400) + $giantB)
    Assert-Check "Z three versions: $($three.Length) bytes, giant version with $($planG.Count) islands" ($three.Length -eq 3548 -and $planG.Count -ge 40)
    foreach ($case in @(@(2000, 1400, 'giant'), @(1999, 1400, 'big'), @(2000, 1399, 'big'), @(1500, 1050, 'big'), @(1000, 700, 'big'), @(750, 525, 'small'))) {
        $actual = Invoke-IslandCode $a $three $case[0] $case[1]
        $front = switch ($case[2]) { 'giant' { Get-StretchedBig $giantB $case[0] $case[1] 2000 1400 } 'big' { Get-StretchedBig $bigB $case[0] $case[1] } default { Get-StretchedScene $small $case[0] $case[1] } }
        $ok = ((Hex ([byte[]]$actual[0..1171])) -eq (Hex $front)) -and ((Hex ([byte[]]$actual[1172..3547])) -eq (Hex ([byte[]]$three[1172..3547])))
        Assert-Check ('Z three versions, {0} x {1}: {2} version ({3} islands, island 0 at {4}/{5}, villages {6}), rest unchanged' -f $case[0], $case[1], $case[2], [BitConverter]::ToInt32($actual, 0x64), [BitConverter]::ToInt32($actual, 0x17C), [BitConverter]::ToInt32($actual, 0x180), [BitConverter]::ToInt32($actual, 0x40)) $ok
        if ($case[2] -ne 'small') { $e = @(for ($i = 0; $i -lt [BitConverter]::ToInt32($actual, 0x64); $i++) { , [byte[]]$actual[(0x174 + 16 * $i)..(0x174 + 16 * $i + 15)] }); Test-Geometry $e $case[0] $case[1] "Z three versions $($case[0]) x $($case[1])" }
    }
    # A broken giant version is skipped: wrong marker, or 10 bytes missing -> the big version, stretched x 2.
    $wrongG = [byte[]]($long + (New-VersionHead 'GROX' 2000 1400) + $giantB)
    $shortG = [byte[]]($three[0..($three.Length - 11)])
    foreach ($case in @(@('wrong marker of the giant version', $wrongG), @('giant version 10 bytes short', $shortG))) {
        $actual = Invoke-IslandCode $a $case[1] 2000 1400
        Assert-Check "Z $($case[0]): big version x 2 at 2000 x 1400" ((Hex ([byte[]]$actual[0..1171])) -eq (Hex (Get-StretchedBig $bigB 2000 1400)))
    }
    # The search stops at the first version without the marker: unknown first marker -> small version.
    $actual = Invoke-IslandCode $a ([byte[]]($small + (New-VersionHead 'XXXX' 1000 700) + $bigB + (New-VersionHead 'GROS' 2000 1400) + $giantB)) 2000 1400
    Assert-Check 'Z first version unknown: small version stretched (later versions are not searched)' ((Hex ([byte[]]$actual[0..1171])) -eq (Hex (Get-StretchedScene $small 2000 1400)))
    Assert-Check 'Z helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'Y  50 islands and everything together'
    [void](Build-IslandTable 1000 700 $false 'Normal')
    $counts = foreach ($lay in 0, 1, 2) { $script:IslandPlans[$lay].Count }
    Assert-Check "Y 1000x700 Normal: $($counts -join '/') islands (at most $IslandMax, at least one layout with 50)" (($counts | Measure-Object -Maximum).Maximum -eq 50 -and ($counts | Where-Object { $_ -gt 50 }).Count -eq 0)
    foreach ($lay in 0, 1, 2) { Test-Geometry $script:IslandPlans[$lay] 1000 700 "Y layout $lay" }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $all = @('-IslandSize', 'Huge', '-Resources', 'Lots', '-Natives', 'Lots', '-Rivals', 'Hard', '-PirateFleet', 'Huge', '-Traders', 'Lots',
        '-Pirates', 'Strong', '-StartGold', '50000', '-RivalGold', '60000', '-Residents', '5', '-Turbo', '-TurboLevel', '16', '-Production', '2', '-Storage', '5', '-ShipSpeed', '2', '-Cargo', '3')
    $r = Invoke-Tool $a $all
    Assert-Check "Y all options: exit code $($r.Code)" ($r.Code -eq 0)
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $res = Build-ResourceCode 200 7; $fc = Build-FleetCode 3; $tc = Build-TraderCode 3; $pc = Build-PirateCode 'Strong' 50000 60000; $bm = Build-BigMapCode
    $ranges = @(@('Resources', $ResourceCaveRva, $res), @('PirateFleet', $FleetCaveRva, $fc), @('Traders', $TraderCaveRva, $tc), @('BigMap', $BigMapCaveRva, $bm), @('Marker', $ProdMarkerRva, (New-Object byte[] 8)), @('TIMERS', $PirateCaveRva, $pc))
    $ok = $true
    for ($i = 0; $i -lt $ranges.Count - 1; $i++) { if ($ranges[$i][1] + $ranges[$i][2].Length -gt $ranges[$i + 1][1]) { $ok = $false } }
    Assert-Check ("Y code caves do not overlap ({0})" -f (($ranges | ForEach-Object { '{0} 0x{1:X}+{2}' -f $_[0], $_[1], $_[2].Length }) -join ', ')) ($ok -and $PirateCaveRva + $pc.Length -le 0xE6000)
    foreach ($b in $ranges) { if ($b[0] -ne 'Marker') { Assert-Check "Y $($b[0]) in memory as built" ((Hex (Read-Image $a $b[1] $b[2].Length)) -eq (Hex $b[2])) } }
    Assert-Check 'Y helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a

    Write-Host 'AA -BuildCost (real haeuser.cod, parsed in the image by FUN_140090660)'
    $tabLen = 500 * 0x90
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    $p = Invoke-HaeuserParser $a
    $t0 = Read-Image $a $BuildingRva $tabLen
    $maxwohn = (0..4 | ForEach-Object { [BitConverter]::ToInt32((Read-Image $a ($ResidentRva + $_ * $ResidentSize) 4), 0) }) -join '/'
    Assert-Check "AA parser result $p, storage trading post I $([BitConverter]::ToUInt16($t0, 270 * 0x90 + 0x30)), Maxwohn $maxwohn (as read in the game)" ($p -eq 1 -and [BitConverter]::ToUInt16($t0, 270 * 0x90 + 0x30) -eq 960 -and $maxwohn -eq '128/384/960/1600/2560')
    Assert-Check "AA trading post I costs 100 gold, 3 t tools, 6 t wood (as paid in the game)" ([BitConverter]::ToInt32($t0, 270 * 0x90 + 0x58) -eq 100 -and [BitConverter]::ToUInt16($t0, 270 * 0x90 + 0x50) -eq 96 -and [BitConverter]::ToUInt16($t0, 270 * 0x90 + 0x52) -eq 192)
    $sumCost = Get-TestSha256 (Get-TestFieldBytes $t0 $TestCostFields); $sumUpkeep = Get-TestSha256 (Get-TestFieldBytes $t0 $TestUpkeepFields)
    Assert-Check "AA checksum build cost of the real table = tool ($($sumCost.Substring(0, 16)))" ($sumCost -eq $CostHash)
    Assert-Check "AA checksum upkeep of the real table = tool ($($sumUpkeep.Substring(0, 16)))" ($sumUpkeep -eq $UpkeepHash)
    $rWrong = @($RadiusOrig.Keys | Where-Object { $t0[$_ * 0x90 + $RadiusOffset] -ne $RadiusOrig[$_] })
    Assert-Check "AA the 17 radius originals of the tool match the real table ($($rWrong -join ','))" ($rWrong.Count -eq 0 -and $RadiusOrig.Count -eq 17)
    $taxNow = (0..4 | ForEach-Object { [BitConverter]::ToInt32((Read-Image $a ($TaxRva + $_ * $ResidentSize) 4), 0) }) -join '/'
    Assert-Check "AA tax originals of the tool match the real groups ($taxNow)" ($taxNow -eq ($TaxOrig -join '/'))
    $maxR = 0; for ($i = 0; $i -lt 500; $i++) { if ($t0[$i * 0x90 + $RadiusOffset] -gt $maxR) { $maxR = $t0[$i * 0x90 + $RadiusOffset] } }
    Assert-Check "AA largest radius in the table $maxR (x2 fits into the AI buffer of 52 bytes)" ($maxR -eq 24 -and 2 * $maxR -le $RadiusMax)
    $r = Invoke-Tool $a @('-BuildCost', '0.5')
    $t1 = Read-Image $a $BuildingRva $tabLen
    $cmp = Compare-ScaledTable $t0 $t1 $TestCostFields 0.5
    Assert-Check "AA x0.5: exit code $($r.Code), $($cmp.Changed) values changed, $($cmp.Wrong) wrong, $($cmp.Other) other bytes changed" ($r.Code -eq 0 -and $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $cmp.Changed -gt 200 -and $r.Text -match "Build cost x0[.,]5: $($cmp.Changed) values changed")
    Assert-Check "AA x0.5: trading post I 50 gold, 2 t tools, 3 t wood (message)" ([BitConverter]::ToInt32($t1, 270 * 0x90 + 0x58) -eq 50 -and [BitConverter]::ToUInt16($t1, 270 * 0x90 + 0x50) -eq 64 -and [BitConverter]::ToUInt16($t1, 270 * 0x90 + 0x52) -eq 96 -and $r.Text -match 'trading post I now: 50 gold, 2 t tools, 3 t wood')
    $c56 = @(0..499 | Where-Object { [BitConverter]::ToUInt16($t0, $_ * 0x90 + 0x56) -ne [BitConverter]::ToUInt16($t1, $_ * 0x90 + 0x56) }).Count
    Assert-Check "AA cannons (+0x56) untouched ($c56 changed)" ($c56 -eq 0)
    Assert-Check "AA marker $(Hex (Read-Image $a $CostMarkerRva 8))" ((Hex (Read-Image $a $CostMarkerRva 8)) -eq '42 41 55 4B 32 00 00 00')
    $r = Invoke-Tool $a @('-BuildCost', '0.5')
    Assert-Check "AA second run: exit code $($r.Code), already set, table unchanged" ($r.Code -eq 0 -and $r.Text -match 'Build cost x0[.,]5: already set' -and [BitConverter]::ToString((Read-Image $a $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t1))
    $r = Invoke-Tool $a @('-BuildCost', '0.25') 'de'
    Assert-Check "AA other factor in the same process (de): exit code $($r.Code), German note, nothing changed" ($r.Code -eq 0 -and $r.Text -match 'Baukosten: im Spiel ist schon ein anderer Faktor gesetzt' -and $r.Text -match 'NICHT geaendert' -and [BitConverter]::ToString((Read-Image $a $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t1))
    Stop-ImageProcess $a
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    Write-Image $a ($BuildingRva + 463 * 0x90 + 0x58) (I32 1301)
    $tw = Read-Image $a $BuildingRva $tabLen
    $r = Invoke-Tool $a @('-BuildCost', '0')
    Assert-Check "AA wrong original (church 1301 gold): exit code $($r.Code), note, nothing changed, no marker" ($r.Code -eq 0 -and $r.Text -match 'Build cost: unexpected values in the building table \(checksum [0-9a-f]{16}\); NOT set' -and [BitConverter]::ToString((Read-Image $a $BuildingRva $tabLen)) -eq [BitConverter]::ToString($tw) -and (Hex (Read-Image $a $CostMarkerRva 8)) -eq '00 00 00 00 00 00 00 00')
    Write-Image $a ($BuildingRva + 463 * 0x90 + 0x58) (I32 ([BitConverter]::ToInt32($t0, 463 * 0x90 + 0x58)))
    $r = Invoke-Tool $a @('-BuildCost', '0') 'de'
    $t2 = Read-Image $a $BuildingRva $tabLen
    $cmp = Compare-ScaledTable $t0 $t2 $TestCostFields 0
    $left = @(0..499 | Where-Object { $i = $_; @($TestCostFields | Where-Object { (Get-TestField $t2 ($i * 0x90 + $_[0]) $_[1]) -ne 0 }).Count -gt 0 }).Count
    Assert-Check "AA 0 = free (de): exit code $($r.Code), $($cmp.Changed) values 0, $left entries with costs left, $($cmp.Other) other bytes changed" ($r.Code -eq 0 -and $left -eq 0 -and $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $r.Text -match "Baukosten x0: $($cmp.Changed) Werte geaendert" -and $r.Text -match 'Kontor I jetzt: 0 Gold, 0 t Werkzeug, 0 t Holz')
    Assert-Check "AA 0: marker $(Hex (Read-Image $a $CostMarkerRva 8))" ((Hex (Read-Image $a $CostMarkerRva 8)) -eq '42 41 55 4B 00 00 00 00')
    Stop-ImageProcess $a

    Write-Host 'AB -Upkeep'
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    $r = Invoke-Tool $a @('-Upkeep', '0.5')
    $t1 = Read-Image $a $BuildingRva $tabLen
    $cmp = Compare-ScaledTable $t0 $t1 $TestUpkeepFields 0.5
    Assert-Check "AB x0.5: exit code $($r.Code), $($cmp.Changed) values changed, $($cmp.Wrong) wrong, $($cmp.Other) other bytes changed" ($r.Code -eq 0 -and $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $cmp.Changed -gt 80 -and $r.Text -match "Upkeep x0[.,]5: $($cmp.Changed) values changed")
    Assert-Check "AB x0.5: trading post I 8/8 (active/paused), church 25, chapel 3 (message)" ([BitConverter]::ToUInt16($t1, 270 * 0x90 + 0x2C) -eq 8 -and [BitConverter]::ToUInt16($t1, 270 * 0x90 + 0x2A) -eq 8 -and [BitConverter]::ToUInt16($t1, 463 * 0x90 + 0x2C) -eq 25 -and [BitConverter]::ToUInt16($t1, 462 * 0x90 + 0x2C) -eq 3 -and $r.Text -match 'trading post I now: 8 \(originally 15\), church 25')
    Assert-Check "AB marker $(Hex (Read-Image $a $UpkeepMarkerRva 8)), build cost marker empty" ((Hex (Read-Image $a $UpkeepMarkerRva 8)) -eq '55 4E 54 48 32 00 00 00' -and (Hex (Read-Image $a $CostMarkerRva 8)) -eq '00 00 00 00 00 00 00 00')
    $r = Invoke-Tool $a @('-Upkeep', '0.5', '-BuildCost', '0.5')
    $t2 = Read-Image $a $BuildingRva $tabLen
    Assert-Check "AB second run with build cost: exit code $($r.Code), upkeep already set and unchanged, build cost set" ($r.Code -eq 0 -and $r.Text -match 'Upkeep x0[.,]5: already set' -and (Get-TestSha256 (Get-TestFieldBytes $t2 $TestUpkeepFields)) -eq (Get-TestSha256 (Get-TestFieldBytes $t1 $TestUpkeepFields)) -and (Compare-ScaledTable $t0 $t2 $TestCostFields 0.5).Wrong -eq 0)
    Stop-ImageProcess $a
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    Write-Image $a ($BuildingRva + 270 * 0x90 + 0x2C) ([BitConverter]::GetBytes([uint16]16))
    $r = Invoke-Tool $a @('-Upkeep', '0')
    Assert-Check "AB wrong original (trading post I 16): exit code $($r.Code), note, no marker" ($r.Code -eq 0 -and $r.Text -match 'Upkeep: unexpected values in the building table' -and (Hex (Read-Image $a $UpkeepMarkerRva 8)) -eq '00 00 00 00 00 00 00 00' -and [BitConverter]::ToUInt16((Read-Image $a ($BuildingRva + 463 * 0x90 + 0x2C) 2), 0) -eq 50)
    Write-Image $a ($BuildingRva + 270 * 0x90 + 0x2C) ([BitConverter]::GetBytes([uint16]15))
    $r = Invoke-Tool $a @('-Upkeep', '0') 'de'
    $t1 = Read-Image $a $BuildingRva $tabLen
    $cmp = Compare-ScaledTable $t0 $t1 $TestUpkeepFields 0
    $left = @(0..499 | Where-Object { [BitConverter]::ToUInt16($t1, $_ * 0x90 + 0x2A) -ne 0 -or [BitConverter]::ToUInt16($t1, $_ * 0x90 + 0x2C) -ne 0 }).Count
    Assert-Check "AB 0 (de): exit code $($r.Code), no running costs left ($left), $($cmp.Other) other bytes changed" ($r.Code -eq 0 -and $left -eq 0 -and $cmp.Wrong -eq 0 -and $cmp.Other -eq 0 -and $r.Text -match "Betriebskosten x0: $($cmp.Changed) Werte geaendert")
    Stop-ImageProcess $a

    Write-Host 'AC -Taxes'
    function Get-Taxes($a) { (0..4 | ForEach-Object { [BitConverter]::ToInt32((Read-Image $a ($TaxRva + $_ * $ResidentSize) 4), 0) }) -join '/' }
    foreach ($case in @(@('1.5', '11/12/17/18/20'), @('2', '14/16/22/24/26'), @('3', '21/24/33/36/39'))) {
        $a = Start-ImageProcess -Crt
        Invoke-SimulatedStart $a
        [void](Invoke-HaeuserParser $a)
        $g0 = Read-Image $a 0x6BA020 (5 * 0x50)
        $r = Invoke-Tool $a @('-Taxes', $case[0])
        $g1 = Read-Image $a 0x6BA020 (5 * 0x50)
        $otherG = 0; for ($j = 0; $j -lt $g0.Length; $j++) { if (($j % 0x50) -lt 0x10 -or ($j % 0x50) -ge 0x14) { if ($g0[$j] -ne $g1[$j]) { $otherG++ } } }
        Assert-Check "AC x$($case[0]): exit code $($r.Code), taxes $(Get-Taxes $a) (expected $($case[1])), $otherG other group bytes changed" ($r.Code -eq 0 -and (Get-Taxes $a) -eq $case[1] -and $otherG -eq 0 -and $r.Text -match "Taxes x$($case[0].Replace(".", "[.,]")): $($case[1]) per resident group")
        if ($case[0] -eq '2') {
            $r = Invoke-Tool $a @('-Taxes', '2') 'de'
            Assert-Check "AC second run (de): exit code $($r.Code), $(Get-Taxes $a) not doubled again, German message" ($r.Code -eq 0 -and (Get-Taxes $a) -eq '14/16/22/24/26' -and $r.Text -match 'Steuern x2: 14/16/22/24/26 je Bevoelkerungsgruppe')
            $r = Invoke-Tool $a @('-Taxes', '3')
            Assert-Check "AC other factor in the same process: exit code $($r.Code), note, unchanged $(Get-Taxes $a)" ($r.Code -eq 0 -and $r.Text -match 'Taxes: unexpected value 14 instead of 7' -and (Get-Taxes $a) -eq '14/16/22/24/26')
        }
        Stop-ImageProcess $a
    }

    Write-Host 'AD -Radius'
    foreach ($f in 1.5, 2) {
        $a = Start-ImageProcess -Crt
        Invoke-SimulatedStart $a
        [void](Invoke-HaeuserParser $a)
        $r = Invoke-Tool $a @('-Radius', "$f")
        $t1 = Read-Image $a $BuildingRva $tabLen
        $wrong = @(); $other = 0; $maxR = 0
        for ($i = 0; $i -lt 500; $i++) {
            $o = $i * 0x90 + $RadiusOffset; $v0 = $t0[$o]; $v1 = $t1[$o]
            if ($v1 -gt $maxR) { $maxR = $v1 }
            if ($RadiusOrig.ContainsKey($i)) { if ($v1 -ne [math]::Min(48, [int][math]::Floor($v0 * $f + 0.5))) { $wrong += "$i=$v1" } }
            elseif ($v1 -ne $v0) { $other++ }
        }
        $sameElse = $true; for ($j = 0; $j -lt $tabLen; $j++) { if (($j % 0x90) -ne $RadiusOffset -and $t0[$j] -ne $t1[$j]) { $sameElse = $false; break } }
        Assert-Check "AD x${f}: exit code $($r.Code), trading post $($t1[270 * 0x90 + 0x20]), market $($t1[467 * 0x90 + 0x20]), cathedral $($t1[461 * 0x90 + 0x20]), church $($t1[463 * 0x90 + 0x20]); wrong $($wrong -join ' '), $other other radii changed, largest $maxR" ($r.Code -eq 0 -and $wrong.Count -eq 0 -and $other -eq 0 -and $maxR -le 48 -and $sameElse -and $r.Text -match "Radius x${f}: trading post and market $([int][math]::Floor(16 * $f + 0.5))")
        $r = Invoke-Tool $a @('-Radius', "$f")
        Assert-Check "AD x${f} second run: exit code $($r.Code), unchanged" ($r.Code -eq 0 -and [BitConverter]::ToString((Read-Image $a $BuildingRva $tabLen)) -eq [BitConverter]::ToString($t1))
        Stop-ImageProcess $a
    }
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    Write-Image $a ($BuildingRva + 469 * 0x90 + $RadiusOffset) ([byte[]]@(17))
    $r = Invoke-Tool $a @('-Radius', '2') 'de'
    Assert-Check "AD unexpected value (doctor 17, de): exit code $($r.Code), German note, nothing set" ($r.Code -eq 0 -and $r.Text -match 'Radius: unerwarteter Wert 17 statt 16' -and $r.Text -match 'NICHT gesetzt' -and (Read-Image $a ($BuildingRva + 270 * 0x90 + $RadiusOffset) 1)[0] -eq 16)
    Stop-ImageProcess $a

    Write-Host 'AE -Fertility Everywhere'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    # Test islands: no., climate, class, flags, fertilities, crop bits (bit = crop - 0x2D), present
    Set-TestIsland $a 0 0 2 4 0 0
    Set-TestIsland $a 1 1 3 4 0 0
    Set-TestIsland $a 2 0 1 4 1 0x20            # grapes already (bit 5): no sugar cane there originally
    Set-TestIsland $a 3 1 4 0 0 0               # no fertile land (flag bit 2 clear)
    Set-TestIsland $a 4 0 2 4 0 0 $false        # island not present
    Set-TestIsland $a 5 0 2 4 2 0               # already two fertilities
    Set-TestIsland $a 6 1 0 4 0 0x04            # spices already (bit 2)
    $calls = @(@(0x2F, 0, 4, 2), @(0x30, 0, 4, 2), @(0x2E, 2, 3, 2), @(0x33, 0, 4, 1), @(0x32, 1, 4, 3), @(0x31, 0, 4, 2))
    $before = foreach ($cl in $calls) { Invoke-CandidateIslands $a $cl[0] $cl[1] $cl[2] $cl[3] }
    Assert-Check "AE original FUN_1400d0ce0 with the test islands: $($before -join ' | ')" (($before -join '|') -eq '1|0|0|1,6|0,5|1,6')
    $r = Invoke-Tool $a @('-Fertility', 'Everywhere')
    Assert-Check "AE exit code $($r.Code), message" ($r.Code -eq 0 -and $r.Text -match 'Fertility: Everywhere \(every island with fertile land grows all six crops')
    $fc = Build-FertilityCode
    Assert-Check "AE fertility code cave set ($($fc.Length) bytes, ends before the markers)" ((Hex (Read-Image $a $FertCaveRva $fc.Length)) -eq (Hex $fc) -and $FertCaveRva + $fc.Length -le $CostMarkerRva)
    $hookT = [byte[]](@(0xE9) + (Rel32 $FertCaveRva ($FertHookRva + 5)) + @(0x90) * 11)
    Assert-Check "AE jump in FUN_1400d0ce0 set ($(Hex (Read-Image $a $FertHookRva 16))), surroundings unchanged" ((Hex (Read-Image $a $FertHookRva 16)) -eq (Hex $hookT) -and (Hex (Read-Image $a 0xD0D4E 8)) -eq '8D 4F D2 83 F9 05 77 41' -and (Hex (Read-Image $a 0xD0D66 4)) -eq '80 78 D8 00')
    $rc = Build-ResourceCode 0 0 $true
    Assert-Check "AE resource code cave: fertility block only ($($rc.Length) bytes), island code with call" ((Hex (Read-Image $a $ResourceCaveRva $rc.Length)) -eq (Hex $rc) -and (Hex (Read-Image $a $IslandCodeRva (Build-IslandCode $true $true).Length)) -eq (Hex (Build-IslandCode $true $true)))
    $after = foreach ($cl in $calls) { Invoke-CandidateIslands $a $cl[0] $cl[1] $cl[2] $cl[3] }
    Assert-Check "AE patched FUN_1400d0ce0 with limits 1-3: unchanged ($($after -join ' | '))" (($after -join '|') -eq ($before -join '|'))
    $magic = foreach ($cl in $calls) { Invoke-CandidateIslands $a $cl[0] $cl[1] $cl[2] $FertMagic }
    Assert-Check "AE limit 'FERT': climate ignored ($($magic -join ' | '))" (($magic -join '|') -eq '0,1,2,5|0,1,2,5,6|0,1,5|0,1,2,5,6|0,1,5|0,1,2,5,6')
    $none = Invoke-CandidateIslands $a 0x34 0 4 $FertMagic
    Assert-Check "AE limit 'FERT', grass (0x34, not a crop): no island ('$none')" ($none -eq '')
    function Get-FertileScene([byte[]]$scene, $plan, [int]$percent, [int]$villages) {
        $old = [BitConverter]::ToInt32($scene, 0x64); $new = $plan.Count
        $e = [byte[]]$scene.Clone(); [Array]::Copy((I32 $new), 0, $e, 0x64, 4)
        for ($i = 0; $i -lt 50; $i++) { $q = if ($i -lt $new) { $plan[$i] } else { New-Object byte[] 16 }; [Array]::Copy($q, 0, $e, 0x174 + 16 * $i, 16) }
        if ($percent -gt 0) { foreach ($o in $ResourceOffsets) { $m = [int][BitConverter]::ToUInt16($scene, $o); [Array]::Copy([BitConverter]::GetBytes([uint16][math]::Min($new, [int][math]::Truncate($m * $new * $percent / ($old * 100)))), 0, $e, $o, 2) } }
        if ($villages -gt 0) { [Array]::Copy((I32 $villages), 0, $e, 0x40, 4); [Array]::Copy((I32 $villages), 0, $e, 0x44, 4) }
        for ($k = 0; $k -lt 12; $k++) { if ([BitConverter]::ToUInt16($scene, 0xB4 + 8 * $k) -ne 0) { [Array]::Copy([BitConverter]::GetBytes([uint16]50), 0, $e, 0xB6 + 8 * $k, 2) } }
        [Array]::Copy((I32 $FertMagic), 0, $e, 0x60, 4)
        , $e
    }
    foreach ($file in '[[48]]00.szs', '[[48]]21.szs', '[[48]]32.szs') {
        $scene = Read-Scene $file; $plan = $exp1000.Plans[[int][string]$file[7]]
        $actual = Invoke-IslandCode $a $scene 1000 700
        $nf = @(0..11 | Where-Object { [BitConverter]::ToUInt16($actual, 0xB4 + 8 * $_) -ne 0 -and [BitConverter]::ToUInt16($actual, 0xB6 + 8 * $_) -eq 50 }).Count
        Assert-Check ("AE {0}: {1} islands, {2} crop amounts 50, +0x60 = 0x{3:X}, all 1172 bytes as expected" -f $file, [BitConverter]::ToInt32($actual, 0x64), $nf, [BitConverter]::ToInt32($actual, 0x60)) ((Hex $actual) -eq (Hex (Get-FertileScene $scene $plan 0 0)) -and $nf -eq 6)
    }
    Assert-Check 'AE helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Fertility', 'Everywhere', '-Resources', 'Lots', '-Natives', 'More')
    $rc = Build-ResourceCode 200 4 $true
    Assert-Check "AE with -Resources Lots -Natives More: exit code $($r.Code), code cave $($rc.Length) bytes set" ($r.Code -eq 0 -and (Hex (Read-Image $a $ResourceCaveRva $rc.Length)) -eq (Hex $rc) -and $ResourceCaveRva + $rc.Length -le $ResourceCaveEnd)
    foreach ($file in '[[48]]10.szs', '[[48]]22.szs') {
        $scene = Read-Scene $file; $plan = $exp1000.Plans[[int][string]$file[7]]
        $actual = Invoke-IslandCode $a $scene 1000 700
        Assert-Check ("AE {0} with resources Lots and villages 4: ore {1}, treasure {2}, crops 50, villages {3}/{4}, all 1172 bytes as expected" -f $file, [BitConverter]::ToUInt16($actual, 0x96), [BitConverter]::ToUInt16($actual, 0x116), [BitConverter]::ToInt32($actual, 0x40), [BitConverter]::ToInt32($actual, 0x44)) ((Hex $actual) -eq (Hex (Get-FertileScene $scene $plan 200 4)))
    }
    Stop-ImageProcess $a
    foreach ($case in @(@('-StretchOnly', 'not with -StretchOnly'), @('-NoIslandSpread', 'not with -NoIslandSpread'))) {
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-Fertility', 'Everywhere', $case[0])
        Assert-Check "AE $($case[0]): exit code $($r.Code), note, jump and code cave untouched" ($r.Code -eq 0 -and $r.Text -match ([regex]::Escape($case[1]) + '\); NOT set') -and (Hex (Read-Image $a $FertHookRva 16)) -eq $FertHookOrig -and (Hex (Read-Image $a $FertCaveRva 8)) -eq '00 00 00 00 00 00 00 00')
        Stop-ImageProcess $a
    }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Fertility', 'Everywhere') 'de'
    Assert-Check "AE de: exit code $($r.Code), German message" ($r.Code -eq 0 -and $r.Text -cmatch 'Fruchtbarkeit: Ueberall \(jede Insel mit fruchtbarem Land' -and $r.Text -cnotmatch 'Everywhere')
    Stop-ImageProcess $a

    Write-Host 'AF -Mines Infinite'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($m in $MineSites) { Assert-Check ("AF before 0x{0:X} = {1}" -f $m.Rva, (Hex (Read-Image $a $m.Rva ((Bytes $m.Original).Length)))) ((Hex (Read-Image $a $m.Rva ((Bytes $m.Original).Length))) -eq $m.Original) }
    $around = Hex (Read-Image $a 0xBA400 0xC0)
    $r = Invoke-Tool $a @('-Mines', 'Infinite')
    Assert-Check "AF exit code $($r.Code), message" ($r.Code -eq 0 -and $r.Text -match 'Mines: Infinite \(ore and gold deposits are never used up\)')
    foreach ($m in $MineSites) { Assert-Check ("AF 0x{0:X} = {1} (NOP of the same length)" -f $m.Rva, (Hex (Read-Image $a $m.Rva ((Bytes $m.Target).Length)))) ((Hex (Read-Image $a $m.Rva ((Bytes $m.Target).Length))) -eq $m.Target -and (Bytes $m.Target).Length -eq (Bytes $m.Original).Length) }
    $now = Read-Image $a 0xBA400 0xC0; $exp = Bytes $around
    foreach ($m in $MineSites) { $tb = Bytes $m.Target; for ($k = 0; $k -lt $tb.Length; $k++) { $exp[$m.Rva - 0xBA400 + $k] = $tb[$k] } }
    Assert-Check 'AF the rest of FUN_1400b9ed0 around the sites unchanged (192 bytes)' ((Hex $now) -eq (Hex $exp))
    $r = Invoke-Tool $a @('-Mines', 'Infinite') 'de'
    Assert-Check "AF second run (de): exit code $($r.Code), German message" ($r.Code -eq 0 -and $r.Text -cmatch 'Minen: Unendlich \(Erz- und Goldvorkommen werden nie aufgebraucht\)')
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Write-Image $a 0xBA429 ([byte[]](0x66, 0x29, 0x42, 0x07)) $true
    $r = Invoke-Tool $a @('-Mines', 'Infinite')
    Assert-Check "AF falsified site: abort (exit code $($r.Code)), the other site unchanged" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes' -and (Hex (Read-Image $a 0xBA495 5)) -eq '66 44 2B 47 26')
    Stop-ImageProcess $a

    Write-Host 'AG -Disasters Off / More'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $snap = @{}; foreach ($rv in 0x9E800, 0xBCA80) { $snap[$rv] = Read-Image $a $rv 0x180 }
    $r = Invoke-Tool $a @('-Disasters', 'Off')
    Assert-Check "AG Off: exit code $($r.Code), message" ($r.Code -eq 0 -and $r.Text -match 'Disasters: Off \(no new fire, plague, drought or volcanic eruption\)')
    foreach ($s in $DisasterOffSites) { Assert-Check ("AG Off {0} 0x{1:X} = {2}" -f $s.Name, $s.Rva, (Hex (Read-Image $a $s.Rva 5))) ((Hex (Read-Image $a $s.Rva 5)) -eq '0F 1F 44 00 00' -and $s.Original -like 'E8 *') }
    $diff = 0; foreach ($rv in $snap.Keys) { $now = Read-Image $a $rv 0x180; for ($k = 0; $k -lt 0x180; $k++) { if ($now[$k] -ne $snap[$rv][$k]) { $diff++ } } }
    Assert-Check "AG Off: exactly 25 bytes changed in the two functions ($diff)" ($diff -eq 25)
    $r = Invoke-Tool $a @('-Disasters', 'More')
    Assert-Check "AG More against Off in the same process: abort (exit code $($r.Code)), More not set" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes' -and (Hex (Read-Image $a 0xBCABB 3)) -eq '83 FA 0C')
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Disasters', 'More') 'de'
    Assert-Check "AG More (de): exit code $($r.Code), German message" ($r.Code -eq 0 -and $r.Text -cmatch 'Katastrophen: Mehr \(Feuer und Pest doppelt so wahrscheinlich')
    foreach ($s in $DisasterMoreSites) { $n = (Bytes $s.Target).Length; Assert-Check ("AG More 0x{0:X} = {1}" -f $s.Rva, (Hex (Read-Image $a $s.Rva $n))) ((Hex (Read-Image $a $s.Rva $n)) -eq $s.Target) }
    foreach ($s in $DisasterOffSites) { Assert-Check ("AG More: call 0x{0:X} untouched" -f $s.Rva) ((Hex (Read-Image $a $s.Rva 5)) -eq $s.Original) }
    Stop-ImageProcess $a

    Write-Host 'AQ -RivalGrowth Ambitious'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($g in $RivalGrowthSites) { $n = (Bytes $g.Original).Length; Assert-Check ("AQ before {0} = {1}" -f $g.Name, (Hex (Read-Image $a $g.Rva $n))) ((Hex (Read-Image $a $g.Rva $n)) -eq $g.Original) }
    $r = Invoke-Tool $a @('-RivalGrowth', 'Ambitious') 'de'
    Assert-Check "AQ exit code $($r.Code), German message" ($r.Code -eq 0 -and $r.Text -cmatch 'Gegner-Ausbau: ehrgeizig')
    foreach ($g in $RivalGrowthSites) { $n = (Bytes $g.Original).Length; Assert-Check ("AQ {0} = {1}" -f $g.Name, (Hex (Read-Image $a $g.Rva $n))) ((Hex (Read-Image $a $g.Rva $n)) -eq $g.Target) }
    $diff = 0; foreach ($g in $RivalGrowthSites) { $t = Bytes $g.Target; $o = Bytes $g.Original; for ($k = 0; $k -lt $t.Length; $k++) { if ($t[$k] -ne $o[$k]) { $diff++ } } }
    Assert-Check "AQ exactly 9 bytes differ from the original (two jumps and one wait become NOPs, three money exits jumps: $diff)" ($diff -eq 9)
    $r = Invoke-Tool $a @('-RivalGrowth', 'Ambitious')
    Assert-Check "AQ second run: exit code $($r.Code)" ($r.Code -eq 0)
    Stop-ImageProcess $a

    # The island forge writes below LOCALAPPDATA: for these cases a folder of the test.
    $localBefore = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = Join-Path $tmp 'localappdata'
    try {
        $islandsRoot = Join-Path $env:LOCALAPPDATA 'Anno1602-Extensions\islands'
        Write-Host 'AR -Volcanoes Off (alone, with Disasters Off, with Disasters More)'
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-Volcanoes', 'Off')
        Assert-Check "AR alone: exit code $($r.Code), volcano call 0x9E93E = $(Hex (Read-Image $a $VolcanoRva 5)), other disaster calls untouched" ($r.Code -eq 0 -and (Hex (Read-Image $a $VolcanoRva 5)) -eq '0F 1F 44 00 00' -and @($DisasterOffSites | Where-Object { $_.Rva -ne $VolcanoRva -and (Hex (Read-Image $a $_.Rva 5)) -ne $_.Original }).Count -eq 0)
        if ($r.Code -ne 0) { Write-Host $r.Text }
        Stop-ImageProcess $a
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-Volcanoes', 'Off', '-Disasters', 'Off')
        Assert-Check "AR with Disasters Off: exit code $($r.Code), all five calls NOPs" ($r.Code -eq 0 -and @($DisasterOffSites | Where-Object { (Hex (Read-Image $a $_.Rva 5)) -ne '0F 1F 44 00 00' }).Count -eq 0)
        Stop-ImageProcess $a
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-Volcanoes', 'Off', '-Disasters', 'More')
        Assert-Check "AR with Disasters More: exit code $($r.Code), volcano NOP, plague limit 25, fire calls untouched" ($r.Code -eq 0 -and (Hex (Read-Image $a $VolcanoRva 5)) -eq '0F 1F 44 00 00' -and (Hex (Read-Image $a 0xBCABB 3)) -eq '83 FA 19' -and (Hex (Read-Image $a 0xBCB07 5)) -eq 'E8 E4 A6 FF FF')
        Stop-ImageProcess $a

        Write-Host 'AS Island forge: folder, path for the game, the five loaders, reuse'
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        foreach ($s in $IslandPathSites) { Assert-Check ("AS before 0x{0:X} = {1}" -f $s.Rva, (Hex (Read-Image $a $s.Rva 7))) ((Hex (Read-Image $a $s.Rva 7)) -eq $s.Original) }
        Assert-Check "AS before: free end of .pdata at 0x$('{0:X}' -f $IslandPathRva) is empty" ((Hex (Read-Image $a $IslandPathRva 256)) -eq ((@('00') * 256) -join ' '))
        $r = Invoke-Tool $a @('-Rivers', 'Off', '-Mountains', 'Edge') 'de'
        Assert-Check "AS exit code $($r.Code), German message" ($r.Code -eq 0 -and $r.Text -cmatch 'Inselschmiede: keine Fluesse, Berge am Rand' -and $r.Text -cmatch 'baue die Inseln')
        if ($r.Code -ne 0) { Write-Host $r.Text }
        $dirs = @(Get-ChildItem -LiteralPath $islandsRoot -Directory -ErrorAction SilentlyContinue)
        $built = if ($dirs.Count -eq 1) { $dirs[0] } else { $null }
        Assert-Check ("AS one island folder built ({0}) with log and changed islands" -f (($dirs | ForEach-Object Name) -join ', ')) ($built -and $built.Name -match '^[0-9a-f]{8}-r1-m1-v0-g0$' -and (Test-Path -LiteralPath (Join-Path $built.FullName 'forge.log')) -and @(Get-ChildItem -LiteralPath $built.FullName -Recurse -Filter *.scp).Count -gt 300)
        $want = [byte[]]([Text.Encoding]::Default.GetBytes($built.FullName + '\') + [byte]0)
        Assert-Check "AS folder path in memory (ANSI, $($want.Length) bytes with the end zero)" ((Hex (Read-Image $a $IslandPathRva $want.Length)) -eq (Hex $want))
        foreach ($s in $IslandPathSites) {
            $now = Read-Image $a $s.Rva 7
            $target = $s.Rva + 7 + [BitConverter]::ToInt32($now, 3)
            Assert-Check ("AS loader 0x{0:X}: same instruction ({1}), now points to 0x{2:X}" -f $s.Rva, (Hex $now[0..2]), $target) ((Hex $now[0..2]) -eq (Hex (Bytes $s.Original)[0..2]) -and $target -eq $IslandPathRva)
        }
        $stamp = (Get-Item -LiteralPath (Join-Path $built.FullName 'forge.log')).LastWriteTimeUtc
        $r = Invoke-Tool $a @('-Rivers', 'Off', '-Mountains', 'Edge')
        Assert-Check "AS second run: exit code $($r.Code), folder reused (not built again)" ($r.Code -eq 0 -and $r.Text -notmatch 'building the islands' -and (Get-Item -LiteralPath (Join-Path $built.FullName 'forge.log')).LastWriteTimeUtc -eq $stamp)
        Stop-ImageProcess $a
        $a = Start-ImageProcess
        Invoke-SimulatedStart $a
        $r = Invoke-Tool $a @('-IslandSize', 'Giant')
        $dirs = @(Get-ChildItem -LiteralPath $islandsRoot -Directory)
        Assert-Check ("AS other options: exit code {0}, new folder, the old one removed ({1})" -f $r.Code, (($dirs | ForEach-Object Name) -join ', ')) ($r.Code -eq 0 -and $dirs.Count -eq 1 -and $dirs[0].Name -match '-r0-m0-v0-g8$' -and $r.Text -match '8 giant islands')
        Stop-ImageProcess $a

        Write-Host 'AT IslandSize Giant: plans with the real giant islands'
        $gdir = $dirs[0].FullName
        $script:GiantDims = @{}
        for ($n = 20; $n -lt 20 + $GiantPerClimate; $n++) { $f = [IO.File]::ReadAllBytes((Join-Path $gdir "Nord\lar$n.scp")); $script:GiantDims[$n] = @([int]$f[21], [int]$f[22]) }
        $script:GiantMaxPerMap = $GiantMaxPerMap
        foreach ($geo in @(1000, 700), @(2000, 1400), @(750, 525)) {
            [void](Build-IslandTable $geo[0] $geo[1] $false 'Giant')
            foreach ($lay in ($script:IslandPlans.Keys | Sort-Object)) {
                $plan = $script:IslandPlans[$lay]; $rects = @()
                foreach ($p in $plan) {
                    $n = [int][BitConverter]::ToUInt16($p, 4)
                    $wh = if ($p[1] -eq 4 -and $script:GiantDims.ContainsKey($n)) { $script:GiantDims[$n] } else { @($ClassW[$p[1]], $ClassH[$p[1]]) }
                    $rects += , @([BitConverter]::ToInt32($p, 8), [BitConverter]::ToInt32($p, 12), $wh[0], $wh[1], $n, $p[1])
                }
                $giants = @($rects | Where-Object { $_[5] -eq 4 -and $_[4] -ge 20 -and $_[4] -lt 20 + $GiantPerClimate })
                $overlap = 0; for ($i = 0; $i -lt $rects.Count; $i++) { for ($j = $i + 1; $j -lt $rects.Count; $j++) { $p = $rects[$i]; $q = $rects[$j]; if ($p[0] -lt $q[0] + $q[2] -and $q[0] -lt $p[0] + $p[2] -and $p[1] -lt $q[1] + $q[3] -and $q[1] -lt $p[1] + $p[3]) { $overlap++ } } }
                $outside = @($rects | Where-Object { $_[0] -lt 0 -or $_[1] -lt 0 -or $_[0] + $_[2] -gt $geo[0] -or $_[1] + $_[3] -gt $geo[1] }).Count
                $class4 = @($rects | Where-Object { $_[5] -eq 4 }).Count
                $unique = @($giants | ForEach-Object { $_[4] } | Sort-Object -Unique).Count -eq $giants.Count
                $minGiants = if ($geo[0] -ge 1000) { 1 } else { 0 }
                Assert-Check ("AT {0}x{1} layout {2}: {3} islands, {4} giant, {5} of class lar in total, no overlap ({6}), inside ({7})" -f $geo[0], $geo[1], $lay, $rects.Count, $giants.Count, $class4, $overlap, $outside) ($overlap -eq 0 -and $outside -eq 0 -and $giants.Count -ge $minGiants -and $giants.Count -le $GiantMaxPerMap -and $class4 -le 10 -and $unique)
            }
        }
        $script:GiantDims = @{}
    }
    finally { $env:LOCALAPPDATA = $localBefore }

    Write-Host 'AU Supply for ambitious rivals (Invoke-RivalSupply against the helper process)'
    $a = Start-ImageProcess
    Connect-EventEngine $a
    # Players: 0 human, 1 and 2 computer rivals (0xC), 3 not a rival.
    foreach ($k in @(@(0, 0), @(1, 12), @(2, 12), @(3, 0))) { Write-Image $a ($EventPlayersRva + $k[0] * $PlayerSize) (I32 $k[1]) }
    Write-Image $a $ClockRva (I32 5000); Write-Image $a $EventLockRva (I32 0)
    $supTowns = @(
        @{ Slot = 1; Name = 'Mensch'; Island = 1; Owner = 0; Limit = 960; Markets = 1; Workers = 0; Stages = @(10, 90, 0, 0, 0); Stock = @{} }
        @{ Slot = 2; Name = 'Rivalia'; Island = 2; Owner = 1; Limit = 960; Markets = 1; Workers = 0; Stages = @(5, 100, 0, 0, 0); Stock = @{ 18 = 320; 19 = 800 } }
        @{ Slot = 3; Name = 'Hochburg'; Island = 3; Owner = 2; Limit = 640; Markets = 1; Workers = 0; Stages = @(0, 0, 10, 20, 0); Stock = @{} }
        @{ Slot = 4; Name = 'Kleinhof'; Island = 4; Owner = 1; Limit = 960; Markets = 1; Workers = 0; Stages = @(40, 0, 0, 0, 0); Stock = @{} }
        @{ Slot = 5; Name = 'Niemand'; Island = 5; Owner = 3; Limit = 960; Markets = 1; Workers = 0; Stages = @(0, 80, 0, 0, 0); Stock = @{} }
    )
    Set-EventTowns $a $supTowns
    $s0 = Read-Image $a $EventSettlementRva (75 * 600)
    $script:SupplyClock = -1; $script:SupplyTons = 0
    $t1 = Invoke-RivalSupply
    $s1 = Read-Image $a $EventSettlementRva (75 * 600)
    $stock = { param([byte[]]$s, [int]$slot, [int]$good) [BitConverter]::ToUInt16($s, $slot * 600 + 0x2A + $good * 12) }
    Assert-Check ("AU settler town of a rival: liquor 10 -> {0} t, tobacco goods {1} t, spices {2} t, tools {3} t, bricks {4} t, cloth stays {5} t (above 20 t), no cocoa ({6})" -f ((& $stock $s1 2 18) / 32), ((& $stock $s1 2 15) / 32), ((& $stock $s1 2 16) / 32), ((& $stock $s1 2 22) / 32), ((& $stock $s1 2 24) / 32), ((& $stock $s1 2 19) / 32), (& $stock $s1 2 17)) (
        (& $stock $s1 2 18) -eq 960 -and (& $stock $s1 2 15) -eq 960 -and (& $stock $s1 2 16) -eq 960 -and (& $stock $s1 2 22) -eq 960 -and (& $stock $s1 2 24) -eq 960 -and (& $stock $s1 2 19) -eq 800 -and (& $stock $s1 2 17) -eq 0)
    $merchantGoods = @(15, 16, 17, 18, 19, 20, 21, 22, 24)
    Assert-Check ("AU merchant town of a rival with 20 t storage: the 7 luxury goods, tools and bricks filled to 20 t ({0})" -f (($merchantGoods | ForEach-Object { (& $stock $s1 3 $_) / 32 }) -join '/')) (@($merchantGoods | Where-Object { (& $stock $s1 3 $_) -ne 640 }).Count -eq 0)
    $diff = @(for ($j = 0; $j -lt $s0.Length; $j++) { if ($s0[$j] -ne $s1[$j]) { $j } })
    $allowed = @(foreach ($g in 18, 15, 16, 22, 24) { 2 * 600 + 0x2A + $g * 12; 2 * 600 + 0x2A + $g * 12 + 1 }) + @(foreach ($g in $merchantGoods) { 3 * 600 + 0x2A + $g * 12; 3 * 600 + 0x2A + $g * 12 + 1 })
    Assert-Check "AU nothing else changed: the human's town, the pioneer town of a rival and the town of a non-rival untouched ($($diff.Count) bytes changed, delivered $t1 t)" (@($diff | Where-Object { $allowed -notcontains $_ }).Count -eq 0 -and $t1 -eq 320)
    Write-Image $a $ClockRva (I32 6000)
    $t2 = Invoke-RivalSupply
    Write-Image $a ($EventSettlementRva + 2 * 600 + 0x2A + 18 * 12) ([BitConverter]::GetBytes([uint16]100))
    Write-Image $a $ClockRva (I32 7000)
    $t3 = Invoke-RivalSupply
    Write-Image $a $EventLockRva (I32 1); Write-Image $a ($EventSettlementRva + 2 * 600 + 0x2A + 18 * 12) ([BitConverter]::GetBytes([uint16]0)); Write-Image $a $ClockRva (I32 20000)
    $t4 = Invoke-RivalSupply
    Assert-Check "AU only every 2000 clock steps ($t2 t at +1000, $t3 t at +2000 after the liquor fell to 3 t), nothing after the end of the game ($t4 t)" ($t2 -eq 0 -and [math]::Abs($t3 - (860 / 32)) -lt 0.001 -and $t4 -eq 0 -and (& $stock (Read-Image $a $EventSettlementRva (75 * 600)) 2 18) -eq 0)
    Stop-ImageProcess $a

    Write-Host 'AW -Explored All (Invoke-Explore against the helper process)'
    $a = Start-ImageProcess
    Connect-EventEngine $a
    Write-Image $a $ClockRva (I32 500); Write-Image $a $EventLocalPlayerRva ([byte[]]@(0))
    # Islands 0, 1, 2 and 49 exist (tiles pointer), slot 3 is free; island 1 is known to rivals 1 and 2, island 2 to the human.
    $isl = @{ 0 = @(0x1000, 0x00); 1 = @(0x2000, 0x06); 2 = @(0x3000, 0x01); 3 = @(0, 0x00); 49 = @(0x4000, 0x00) }
    foreach ($k in $isl.Keys) { $o = $ExploreIslandRva + $k * $ExploreIslandSize; Write-Image $a ($o + $ExploreTilesOffset) ([BitConverter]::GetBytes([int64]$isl[$k][0])); Write-Image $a ($o + $ExploreBitOffset) ([byte[]]@($isl[$k][1])) }
    $x0 = Read-Image $a $ExploreIslandRva (50 * $ExploreIslandSize)
    $n1 = Invoke-Explore
    $x1 = Read-Image $a $ExploreIslandRva (50 * $ExploreIslandSize)
    $bits = { param($t, $i) $t[$i * $ExploreIslandSize + $ExploreBitOffset] }
    Assert-Check ("AW human (player 0): {0} islands marked; bits 0x{1:X2}/0x{2:X2}/0x{3:X2}, free slot 0x{4:X2}, island 49 0x{5:X2}" -f $n1, (& $bits $x1 0), (& $bits $x1 1), (& $bits $x1 2), (& $bits $x1 3), (& $bits $x1 49)) ($n1 -eq 3 -and (& $bits $x1 0) -eq 1 -and (& $bits $x1 1) -eq 7 -and (& $bits $x1 2) -eq 1 -and (& $bits $x1 3) -eq 0 -and (& $bits $x1 49) -eq 1)
    $diff = @(for ($j = 0; $j -lt $x0.Length; $j++) { if ($x0[$j] -ne $x1[$j]) { $j } })
    Assert-Check "AW only the bit bytes changed ($($diff.Count) bytes)" ($diff.Count -eq 3 -and @($diff | Where-Object { ($_ % $ExploreIslandSize) -ne $ExploreBitOffset }).Count -eq 0)
    $n2 = Invoke-Explore
    Write-Image $a $EventLocalPlayerRva ([byte[]]@(2))
    $n3 = Invoke-Explore
    $x3 = Read-Image $a $ExploreIslandRva (50 * $ExploreIslandSize)
    Assert-Check ("AW second round {0} (nothing new); local player 2: {1} islands, island 0 = 0x{2:X2}, island 1 stays 0x{3:X2}" -f $n2, $n3, (& $bits $x3 0), (& $bits $x3 1)) ($n2 -eq 0 -and $n3 -eq 3 -and (& $bits $x3 0) -eq 5 -and (& $bits $x3 1) -eq 7 -and (& $bits $x3 2) -eq 5 -and (& $bits $x3 49) -eq 5)
    Write-Image $a ($ExploreIslandRva + 0 * $ExploreIslandSize + $ExploreBitOffset) ([byte[]]@(0)); Write-Image $a $ClockRva (I32 0)
    $n4 = Invoke-Explore
    Write-Image $a $ClockRva (I32 500); Write-Image $a $EventLocalPlayerRva ([byte[]]@(7))
    $n5 = Invoke-Explore
    Assert-Check "AW nothing before the game clock runs ($n4) and nothing for an invalid local player ($n5)" ($n4 -eq 0 -and $n5 -eq 0 -and (& $bits (Read-Image $a $ExploreIslandRva (50 * $ExploreIslandSize)) 0) -eq 0)
    Stop-ImageProcess $a

    Write-Host 'AV -Ultra (F8)'
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $zero32 = (@('00') * 32) -join ' '
    Assert-Check "AV before: switch jump $(Hex (Read-Image $a $UltraHookRva 6)), accelerator call $(Hex (Read-Image $a $UltraAccelCallRva 6)), caves empty" ((Hex (Read-Image $a $UltraHookRva 6)) -eq $UltraHookOrig -and (Hex (Read-Image $a $UltraAccelCallRva 6)) -eq $UltraAccelCallOrig -and (Hex (Read-Image $a $UltraCaveRva 32)) -eq $zero32 -and (Hex (Read-Image $a $UltraAccelCaveRva 32)) -eq $zero32)
    # The original "ja" leads to the end of the switch (return 0), the table has 0x67 entries (keys 0x10-0x76).
    $ja = Read-Image $a $UltraHookRva 6
    Assert-Check ("AV original jump target 0x{0:X} = end of the key switch, compare 'cmp r8d,0x66' before it ({1})" -f ($UltraHookRva + 6 + [BitConverter]::ToInt32($ja, 2)), (Hex (Read-Image $a ($UltraHookRva - 4) 4))) (($UltraHookRva + 6 + [BitConverter]::ToInt32($ja, 2)) -eq $KeyEndRva -and (Hex (Read-Image $a ($UltraHookRva - 4) 4)) -eq '41 83 F8 66')
    $r = Invoke-Tool $a @('-Ultra') 'de'
    Assert-Check "AV exit code $($r.Code), message 'Ultra: F8 = 32-fach'" ($r.Code -eq 0 -and $r.Text -match 'Ultra: F8 = 32-fach')
    $uc = Build-UltraCode 32
    $cave = Read-Image $a $UltraCaveRva $uc.Length
    Assert-Check "AV cave = $(Hex $cave)" ((Hex $cave) -eq (Hex $uc) -and $uc.Length -le 32)
    $ja = Read-Image $a $UltraHookRva 6
    Assert-Check ("AV switch jump {0} -> 0x{1:X} (the cave)" -f (Hex $ja), ($UltraHookRva + 6 + [BitConverter]::ToInt32($ja, 2))) ($ja[0] -eq 0x0F -and $ja[1] -eq 0x87 -and ($UltraHookRva + 6 + [BitConverter]::ToInt32($ja, 2)) -eq $UltraCaveRva)
    # Decode the cave: cmp r8d,0x67 (F8 = 0x77 after "add r8d,-0x10"), jne over 10 bytes to the jmp, mov ecx,32, call, jmp.
    $callTarget = $UltraCaveRva + 16 + [BitConverter]::ToInt32($cave, 12); $jmpTarget = $UltraCaveRva + 21 + [BitConverter]::ToInt32($cave, 17)
    Assert-Check ("AV cave: F8 compare {0}, jne +{1}, level {2}, call 0x{3:X} (FUN_1400c8be0, like F5-F7), jmp 0x{4:X} (return 0)" -f (Hex $cave[0..3]), $cave[5], [BitConverter]::ToInt32($cave, 7), $callTarget, $jmpTarget) ((Hex $cave[0..3]) -eq '41 83 F8 67' -and $cave[4] -eq 0x75 -and $cave[5] -eq 10 -and $cave[6] -eq 0xB9 -and [BitConverter]::ToInt32($cave, 7) -eq 32 -and $cave[11] -eq 0xE8 -and $callTarget -eq $SetSpeedRva -and $cave[16] -eq 0xE9 -and $jmpTarget -eq $KeyEndRva)
    Assert-Check "AV F5/F6/F7 calls the same function: F7 at 0xE337B calls 0x$('{0:X}' -f (0xE3380 + [BitConverter]::ToInt32((Read-Image $a 0xE337C 4), 0)))" ((0xE3380 + [BitConverter]::ToInt32((Read-Image $a 0xE337C 4), 0)) -eq $SetSpeedRva)
    Assert-Check "AV F7 untouched ($(Hex (Read-Image $a 0xE3376 5)))" ((Hex (Read-Image $a 0xE3376 5)) -eq 'B9 04 00 00 00')
    # The key filter in front of TranslateAcceleratorA (F8 alone is the game's shortcut for the player status).
    $kc = Build-UltraAccelCode
    $kcave = Read-Image $a $UltraAccelCaveRva $kc.Length
    $call = Read-Image $a $UltraAccelCallRva 6
    $callTarget = $UltraAccelCallRva + 5 + [BitConverter]::ToInt32($call, 1)
    $flagTarget = $UltraAccelCaveRva + 24 + [BitConverter]::ToInt32($kcave, 19)
    $iatTarget = $UltraAccelCaveRva + 35 + [BitConverter]::ToInt32($kcave, 31)
    Assert-Check ("AV key filter: call 0x{0:X} -> {1} (cave 0x{2:X}), nop" -f $UltraAccelCallRva, (Hex $call), $callTarget) ($call[0] -eq 0xE8 -and $callTarget -eq $UltraAccelCaveRva -and $call[5] -eq 0x90 -and $UltraAccelCallOrig -eq 'FF 15 A1 77 0D 00')
    Assert-Check ("AV key filter cave {0}: WM_KEYDOWN, F8, Shift/Ctrl flags 0x{1:X} & 0x0C, else jmp [IAT 0x{2:X}]" -f (Hex $kcave), $flagTarget, $iatTarget) ((Hex $kcave) -eq (Hex $kc) -and (Hex $kcave[0..7]) -eq '41 81 78 08 00 01 00 00' -and (Hex $kcave[10..14]) -eq '41 83 78 10 77' -and $kcave[23] -eq 0x0C -and $flagTarget -eq $ModifierFlagsRva -and (Hex $kcave[26..28]) -eq '31 C0 C3' -and $kcave[29] -eq 0xFF -and $kcave[30] -eq 0x25 -and $iatTarget -eq $AccelIatRva)
    Assert-Check ("AV key filter jumps all lead to the jmp (+{0}, +{1}, +{2})" -f $kcave[9], $kcave[16], $kcave[25]) ((10 + $kcave[9]) -eq 29 -and (17 + $kcave[16]) -eq 29 -and (26 + $kcave[25]) -eq 29)
    $r = Invoke-Tool $a @('-Ultra')
    Assert-Check "AV second run with the same level: exit code $($r.Code), cave and jump unchanged" ($r.Code -eq 0 -and $r.Text -notmatch 'unexpected bytes' -and (Hex (Read-Image $a $UltraCaveRva $uc.Length)) -eq (Hex $uc) -and (Hex (Read-Image $a $UltraHookRva 6)) -eq (Hex $ja))
    $r = Invoke-Tool $a @('-Ultra', '-UltraLevel', '64')
    Assert-Check "AV other level in the already patched process: abort (exit code $($r.Code))" ($r.Code -ne 0 -and $r.Text -match 'unexpected bytes')
    Stop-ImageProcess $a
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    $r = Invoke-Tool $a @('-Ultra', '-UltraLevel', '64', '-Turbo', '-TurboLevel', '16')
    $cave = Read-Image $a $UltraCaveRva 21
    Assert-Check "AV 64x with turbo 16x: exit code $($r.Code), F8 level $([BitConverter]::ToInt32($cave, 7)), F7 = $(Hex (Read-Image $a 0xE3376 5))" ($r.Code -eq 0 -and [BitConverter]::ToInt32($cave, 7) -eq 64 -and (Hex (Read-Image $a 0xE3376 5)) -eq 'B9 10 00 00 00' -and $r.Text -match 'F8 = 64x')
    $r = Invoke-Tool $a @('-Ultra', '-UltraLevel', '40')
    Assert-Check "AV level 40 refused by the parameter check (exit code $($r.Code)), F8 level stays 64" ($r.Code -ne 0 -and [BitConverter]::ToInt32((Read-Image $a $UltraCaveRva 11), 7) -eq 64)
    Stop-ImageProcess $a

    Write-Host 'AH Everything together (real haeuser.cod)'
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    foreach ($nr in $ShipSpeedOrig.Keys) { Write-Image $a ($FigureRva + $nr * $FigureSize + $SpeedOffset) (Bytes $ShipSpeedOrig[$nr]) }
    foreach ($nr in $CargoOrig.Keys) { Write-Image $a ($FigureRva + $nr * $FigureSize + $CargoOffset) ([BitConverter]::GetBytes([uint16]$CargoOrig[$nr])) }
    $all = @('-IslandSize', 'Huge', '-Resources', 'Lots', '-Natives', 'Lots', '-Rivals', 'Hard', '-PirateFleet', 'Huge', '-Traders', 'Lots',
        '-Pirates', 'Strong', '-StartGold', '50000', '-RivalGold', '60000', '-Residents', '5', '-Turbo', '-TurboLevel', '16', '-Production', '2', '-Storage', '5', '-ShipSpeed', '2', '-Cargo', '3',
        '-BuildCost', '0.25', '-Upkeep', '0.5', '-Taxes', '3', '-Radius', '2', '-Fertility', 'Everywhere', '-Mines', 'Infinite', '-Disasters', 'Off', '-Ultra')
    $r = Invoke-Tool $a $all
    Assert-Check "AH all options: exit code $($r.Code), production x2 shortens the 125 intervals counted in the game" ($r.Code -eq 0 -and $r.Text -match 'Production x2: 125 work intervals shortened' -and $r.Text -match 'Storage x5' -and $r.Text -match 'Residents x5' -and $r.Text -match 'Ship speed x2' -and $r.Text -match 'Cargo x3')
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $t1 = Read-Image $a $BuildingRva $tabLen
    Assert-Check "AH build cost x0.25, upkeep x0.5, taxes x3, radius x2 all set" ((Compare-ScaledTable $t0 $t1 $TestCostFields 0.25).Wrong -eq 0 -and (Compare-ScaledTable $t0 $t1 $TestUpkeepFields 0.5).Wrong -eq 0 -and (Get-Taxes $a) -eq '21/24/33/36/39' -and $t1[270 * 0x90 + 0x20] -eq 32 -and $t1[461 * 0x90 + 0x20] -eq 48)
    $tabH = Build-IslandTable 1000 700 $false 'Huge'
    $rc = Build-ResourceCode 200 7 $true; $fc = Build-FertilityCode
    $ranges = @(@('IslandTable', $TableRva, $tabH), @('Fertility', $FertCaveRva, $fc), @('BuildCostMarker', $CostMarkerRva, (New-Object byte[] 8)), @('UpkeepMarker', $UpkeepMarkerRva, (New-Object byte[] 8)), @('EventMarker', $EventMarkerRva, (New-Object byte[] 16)), @('Ultra', $UltraCaveRva, (Build-UltraCode 32)), @('Resources', $ResourceCaveRva, $rc), @('UltraKeys', $UltraAccelCaveRva, (Build-UltraAccelCode)),
        @('PirateFleet', $FleetCaveRva, (Build-FleetCode 3)), @('Traders', $TraderCaveRva, (Build-TraderCode 3)), @('BigMap', $BigMapCaveRva, (Build-BigMapCode)), @('ProductionMarker', $ProdMarkerRva, (New-Object byte[] 8)), @('TIMERS', $PirateCaveRva, (Build-PirateCode 'Strong' 50000 60000)))
    $ok = $true
    for ($i = 0; $i -lt $ranges.Count - 1; $i++) { if ($ranges[$i][1] + $ranges[$i][2].Length -gt $ranges[$i + 1][1]) { $ok = $false } }
    Assert-Check ("AH code caves, tables and markers do not overlap ({0})" -f (($ranges | ForEach-Object { '{0} 0x{1:X}+{2}' -f $_[0], $_[1], $_[2].Length }) -join ', ')) ($ok -and $PirateCaveRva + $ranges[-1][2].Length -le 0xE6000 -and $TableRva + $tabH.Length -le $TableRva + $TableMax)
    foreach ($b in $ranges) { if ($b[0] -notlike '*Marker') { Assert-Check "AH $($b[0]) in memory as built" ((Hex (Read-Image $a $b[1] $b[2].Length)) -eq (Hex $b[2])) } }
    Assert-Check "AH markers: build cost $(Hex (Read-Image $a $CostMarkerRva 8)), upkeep $(Hex (Read-Image $a $UpkeepMarkerRva 8)), production $(Hex (Read-Image $a $ProdMarkerRva 8))" ((Hex (Read-Image $a $CostMarkerRva 8)) -eq '42 41 55 4B 19 00 00 00' -and (Hex (Read-Image $a $UpkeepMarkerRva 8)) -eq '55 4E 54 48 32 00 00 00' -and (Hex (Read-Image $a $ProdMarkerRva 8)) -eq '4E 55 46 52 C8 00 00 00')
    $r = Invoke-Tool $a $all
    $t2 = Read-Image $a $BuildingRva $tabLen
    Assert-Check "AH second run with all options: exit code $($r.Code), building table unchanged" ($r.Code -eq 0 -and [BitConverter]::ToString($t2) -eq [BitConverter]::ToString($t1))
    Assert-Check 'AH helper process still alive' (-not $a.Proc.HasExited)
    Stop-ImageProcess $a
    $a = $null

    Test-EventCases

    Write-Host 'F  Process exits while the tool waits for the start'
    $a = Start-ImageProcess
    $log = Join-Path $tmp 'f.txt'
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tool`"", '-TestProcessId', $a.Proc.Id, '-TestBase', $a.Base, '-WaitMinutes', 1 -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
    [void]$p.Handle
    Start-Sleep -Seconds 4
    Assert-Check 'F tool still waiting' (-not $p.HasExited)
    Stop-ImageProcess $a
    $p.WaitForExit(30000) | Out-Null
    $err = Get-Content "$log.err" -Raw
    Assert-Check "F detects the end of the process (exit code $($p.ExitCode))" ($p.ExitCode -ne 0 -and $err -match 'Test process has exited')
    $a = $null
}
finally {
    if ($a) { Stop-ImageProcess $a }
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    $env:ANNO_EXTENSIONS_LANG = $langBefore
}
if ($script:failed) { Write-Host "$($script:failed) of $($script:checks) check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host "All $($script:checks) checks passed." -ForegroundColor Green
