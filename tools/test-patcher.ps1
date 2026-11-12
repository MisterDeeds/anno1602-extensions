<#
.SYNOPSIS
  Offline test for tools\anno-patcher.ps1, without starting the game.

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
       site set; without -Pirates all untouched. Function test: the code cave runs in the
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
    O  -Cargo: the 8 cargo values of the buildable ships are multiplied, the trader stays.
    P  -Production: intervals of the building table are divided (at least 1, 0 stays 0),
       marker set; a second run does not divide again.
    Q  -Turbo: F7 site "mov ecx,8", F6 untouched.
    R  -RivalGold: the code cave sets the gold of slots 1-3 in a new game (trader in
       slot 4 stays), nothing with savegames.
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
       version, wrong marker / too short -> small version. H: without the big map code cave.
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
    AH Everything together: all options, code caves and markers do not overlap, production x2 shortens
       exactly the 125 intervals counted in the game (2026-11-10).
  Expected bytes and plans come from the same functions in anno-patcher.ps1 (loaded via
  the syntax tree); the expected scaled values are computed separately in this test.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = Join-Path $PSScriptRoot 'anno-patcher.ps1'
$exe = Join-Path $root 'analysis\bin\Anno1602.exe'
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
    if (($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $txt -match '^function (Txt|Bytes|Rel32|Build-IslandCode|Build-ResourceCode|Read-Template|Read-Ships|Get-IslandPlan|Build-IslandTable|Build-PirateCode|Get-ShipSpeedBytes|Build-FleetCode|Build-TraderCode|Build-BigMapCode|Add-FertilityBlock|Build-FertilityCode)\b') -or
        $txt -match '^\$(GameFolder|CaveRva|TableRva|TableMax|HookRva|HookContinue|ClassW|ClassH|PirateCaveRva|TimersHookRva|TimersContinue|FlagsRva|TimersMovapsTarget|ClockRva|Gold0Rva|PlayerSize|CannonRva|CannonOrig|CannonTarget|FigureRva|FigureSize|SpeedOffset|ShipSpeedOrig|BuildingRva|BuildingSize|StorageOffset|StorageOrig|ResidentRva|ResidentSize|ResidentOrig|CargoOffset|CargoOrig|IntervalOffset|BuildingCount|ProdMarkerRva|ResourceCaveRva|ResourceCaveEnd|ResourceOffsets|IslandMax|IslandDensity|RivalSites|FleetCaveRva|FleetCallRva|LevelRva|FleetWait|TraderCaveRva|TraderRva|TraderMax|BigMapCaveRva|BigMapMarker|FertMagic|FertAmount|FertCaveRva|FertHookRva|FertAcceptRva|FertJumpTableRva|FertHookOrig|CostMarkerRva|UpkeepMarkerRva|CostHash|UpkeepHash|TaxRva|TaxOrig|RadiusOffset|RadiusMax|RadiusOrig|MineSites|DisasterOffSites|DisasterMoreSites)\b') { . ([scriptblock]::Create($txt)) }
}
$PirateHookOrig = '0F 29 05 B7 B3 4F 00'
$PirateHookTarget = Hex ([byte[]](@(0xE9) + (Rel32 $PirateCaveRva ($TimersHookRva + 5)) + @(0x66, 0x90)))
function Test-Pirates($a, [string]$mode, [string]$when, [int]$gold = 0) {
    $code = Build-PirateCode $mode $gold
    $c = Hex (Read-Image $a $PirateCaveRva 41); $k = Hex (Read-Image $a $TimersHookRva 7); $can = Hex (Read-Image $a $CannonRva 7)
    if ($mode -eq 'Default' -and $gold -eq 0) {
        Assert-Check "$when TIMERS code cave empty" ($c -eq ((@('00') * 41) -join ' '))
        Assert-Check "$when TIMERS jump original ($k)" ($k -eq $PirateHookOrig)
    }
    else {
        $target = Hex ([byte[]]($code + (New-Object byte[] (41 - $code.Length))))
        Assert-Check "$when TIMERS code cave $mode/gold $gold set ($($code.Length) bytes)" ($c -eq $target)
        Assert-Check "$when TIMERS jump set ($k)" ($k -eq $PirateHookTarget)
    }
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

    Write-Host 'O  -Cargo'
    function Get-CargoAddress([int]$nr) { $FigureRva + $nr * $FigureSize + $CargoOffset }
    $a = Start-ImageProcess
    Invoke-SimulatedStart $a
    foreach ($nr in $CargoOrig.Keys) { Write-Image $a (Get-CargoAddress $nr) ([BitConverter]::GetBytes([uint16]$CargoOrig[$nr])) }
    $r = Invoke-Tool $a @('-Cargo', '1.5')
    Assert-Check "O exit code $($r.Code)" ($r.Code -eq 0)
    foreach ($nr in ($CargoOrig.Keys | Sort-Object)) {
        $n = [BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress $nr) 2), 0)
        $target = [int][math]::Round($CargoOrig[$nr] * 1.5)
        Assert-Check ('O ship no. {0}: {1} -> {2} (expected {3})' -f $nr, $CargoOrig[$nr], $n, $target) ($n -eq $target)
    }
    Assert-Check 'O trader (no. 29) untouched' ((Hex (Read-Image $a (Get-CargoAddress 29) 2)) -eq '00 00')
    $r = Invoke-Tool $a @('-Cargo', '1.5')
    Assert-Check "O second run: exit code $($r.Code), no. 21 = $([BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress 21) 2), 0))" ($r.Code -eq 0 -and [BitConverter]::ToUInt16((Read-Image $a (Get-CargoAddress 21) 2), 0) -eq 2400)
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
    function Get-StretchedBig([byte[]]$g, [int]$w, [int]$h) {
        $e = [byte[]]$g.Clone(); $n = [BitConverter]::ToInt32($g, 0x64)
        for ($i = 0; $i -lt $n; $i++) { $p = 0x174 + 16 * $i
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 8) * $w / 1000))), 0, $e, $p + 8, 4)
            [Array]::Copy((I32 ([int][math]::Truncate([BitConverter]::ToInt32($g, $p + 12) * $h / 700))), 0, $e, $p + 12, 4) }
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

    Write-Host 'AH Everything together (real haeuser.cod)'
    $a = Start-ImageProcess -Crt
    Invoke-SimulatedStart $a
    [void](Invoke-HaeuserParser $a)
    foreach ($nr in $ShipSpeedOrig.Keys) { Write-Image $a ($FigureRva + $nr * $FigureSize + $SpeedOffset) (Bytes $ShipSpeedOrig[$nr]) }
    foreach ($nr in $CargoOrig.Keys) { Write-Image $a ($FigureRva + $nr * $FigureSize + $CargoOffset) ([BitConverter]::GetBytes([uint16]$CargoOrig[$nr])) }
    $all = @('-IslandSize', 'Huge', '-Resources', 'Lots', '-Natives', 'Lots', '-Rivals', 'Hard', '-PirateFleet', 'Huge', '-Traders', 'Lots',
        '-Pirates', 'Strong', '-StartGold', '50000', '-RivalGold', '60000', '-Residents', '5', '-Turbo', '-TurboLevel', '16', '-Production', '2', '-Storage', '5', '-ShipSpeed', '2', '-Cargo', '3',
        '-BuildCost', '0.25', '-Upkeep', '0.5', '-Taxes', '3', '-Radius', '2', '-Fertility', 'Everywhere', '-Mines', 'Infinite', '-Disasters', 'Off')
    $r = Invoke-Tool $a $all
    Assert-Check "AH all options: exit code $($r.Code), production x2 shortens the 125 intervals counted in the game" ($r.Code -eq 0 -and $r.Text -match 'Production x2: 125 work intervals shortened' -and $r.Text -match 'Storage x5' -and $r.Text -match 'Residents x5' -and $r.Text -match 'Ship speed x2' -and $r.Text -match 'Cargo x3')
    if ($r.Code -ne 0) { Write-Host $r.Text }
    $t1 = Read-Image $a $BuildingRva $tabLen
    Assert-Check "AH build cost x0.25, upkeep x0.5, taxes x3, radius x2 all set" ((Compare-ScaledTable $t0 $t1 $TestCostFields 0.25).Wrong -eq 0 -and (Compare-ScaledTable $t0 $t1 $TestUpkeepFields 0.5).Wrong -eq 0 -and (Get-Taxes $a) -eq '21/24/33/36/39' -and $t1[270 * 0x90 + 0x20] -eq 32 -and $t1[461 * 0x90 + 0x20] -eq 48)
    $tabH = Build-IslandTable 1000 700 $false 'Huge'
    $rc = Build-ResourceCode 200 7 $true; $fc = Build-FertilityCode
    $ranges = @(@('IslandTable', $TableRva, $tabH), @('Fertility', $FertCaveRva, $fc), @('BuildCostMarker', $CostMarkerRva, (New-Object byte[] 8)), @('UpkeepMarker', $UpkeepMarkerRva, (New-Object byte[] 8)), @('Resources', $ResourceCaveRva, $rc),
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
