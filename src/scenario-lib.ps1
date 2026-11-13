<#
.SYNOPSIS
  Builds custom scenarios (.szs) for Anno 1602 History Edition from an endless-game template.

.DESCRIPTION
  Loaded by dot-sourcing (. .\scenario-lib.ps1); provides these functions:
    Read-Scenario <path>                 -> list of @{ Name; Data } in file order
    Write-Scenario <path> <list>         -> write the file (section = 16-byte name, int32 length, data)
    New-Mission @{...}                   -> 0x8C4 bytes (AUFTRAG4 entry)
    Set-Islands <SZENE> <list>           -> island list (up to 50 entries of 16 bytes from +0x174)
    New-CargoBytes <cargo> <ship type>   -> cargo block of a SHIP4 entry (0x40 bytes from +0x174)
    Set-FixedString <bytes> <o> <size> <text> -> zero-terminated Windows-1252 text in a fixed field
  The template is only read. How the fields were worked out: docs\FINDINGS.md, section on
  custom scenarios.

  AUFTRAG4 entry (0x8C4 bytes; loader FUN_1400b1780, check FUN_1400ae010):
    +0x000 int   slot in the mission table (players refer to it via PLAYER4 +0x0C)
    +0x004 int   goal bits: 1/2/4 town 1-3 (set by the loader itself), 8 all towns at least,
                 0x10 support a player, 0x20 number of towns, 0x80 total residents,
                 0x100 balance, 0x200 rivals defeated (count), 0x400 defeat specific players,
                 0x800 also for the AI, 0x1000/0x2000 goods in stock, 0x4000/0x8000 resource monopoly
    +0x020 byte resource 1, +0x021 byte number of islands (overwritten by the game at start: all islands with the resource); +0x022/+0x023 resource 2
    +0x024 byte player to support (7 = any)
    +0x02B byte number of defeated rivals, +0x02C..+0x032 per player 1 = must be defeated
    +0x040 int number of towns, +0x044 int total residents, +0x04C int balance (talers, as in the status window:
               taxes + sales - purchases - operating and military costs, FUN_1400ad5d0)
    +0x054 int trade balance (sales - purchases, goal bit 0x10000)
    +0x050 int voice message/film on success (original 84-106)
    +0x068 text (0x800 bytes, Windows-1252)
    +0x868/+0x86C goods: byte 0 good, bytes 2-3 amount (x 32 = tons)
    +0x870/+0x87C/+0x888 town 1-3: total residents, stage (0 pioneers ... 4 aristocrats), of which at least
    +0x8AC all towns at least (bit 8), +0x8B8 town of the supported player (bit 0x10)

  SHIP4 entry (0x1B4 bytes; loader FUN_14008e4f0): +0x00 name (0x18 bytes), +0x1C/+0x1E x/y (int16),
  +0x3C capacity per hold x 32, +0x42 cannons, +0x46 slot, +0x48 figure type, +0x4B owner,
  +0x174 cargo: 8 holds of 8 bytes = uint16 house no. of the PRODUCING building (Id - 20000 in
  haeuser.cod; the loader maps it through the building table to the good, building +0x21), uint16 amount
  x 32 (14 bits, rounded down to whole tons), uint32 flags (0). Soldiers use 9901 + 4 x kind + owner.
  Same scheme in all 131 original scenarios (e.g. start ship of the endless game: 515 tools 50 t,
  2001 wood 30 t, 1075 food 10 t). PLAYER4 entry (0x430 bytes): +0x3C0 player name (0x40 bytes).
#>

$Cp1252 = [Text.Encoding]::GetEncoding(1252)

# Ship cargo: good -> house no. of the producing building. Only numbers that the original scenarios use.
$CargoHouse = [ordered]@{
    Tools = 515; Wood = 2001; Food = 1075; Bricks = 513; Cloth = 507; Liquor = 519; TobaccoGoods = 525; Swords = 517
    Cannons = 527; Iron = 521; Ore = 2401; Gold = 2405; Spices = 1501; Cocoa = 1509; Tobacco = 1507; Wool = 1505
}
# Ship types (figure no.): holds, tons per hold (figuren.cod "Maxware" / 32), cannons.
$ShipTypes = @{ 21 = @(4, 50, 6); 23 = @(6, 80, 10); 25 = @(3, 65, 8); 27 = @(8, 120, 14) }

# Cargo block (0x40 bytes) from @(@{ Good = 'Tools'; Tons = 20 }, ...), checked against the ship type.
function New-CargoBytes($cargo, [int]$shipType) {
    $r = New-Object byte[] 0x40
    $items = @($cargo | Where-Object { $_ })
    $holds = $ShipTypes[$shipType]
    if (-not $holds) { throw "Unknown ship type $shipType." }
    if ($items.Count -gt $holds[0]) { throw "Ship type $shipType has only $($holds[0]) holds." }
    for ($i = 0; $i -lt $items.Count; $i++) {
        $g = [string]$items[$i].Good; $t = [int]$items[$i].Tons
        if (-not $CargoHouse.Contains($g)) { throw "Unknown cargo good '$g'." }
        if ($t -lt 1 -or $t -gt $holds[1]) { throw "Cargo $g $t t: 1 to $($holds[1]) t per hold." }
        Set-U16 $r (8 * $i) $CargoHouse[$g]; Set-U16 $r (8 * $i + 2) ($t * 32)
    }
    , $r
}

# Zero-terminated Windows-1252 text in a fixed field (cleared first).
function Set-FixedString([byte[]]$b, [int]$o, [int]$size, [string]$text) {
    $t = $Cp1252.GetBytes($text)
    if ($t.Length -ge $size) { throw "Text too long for $size bytes: $text" }
    [Array]::Clear($b, $o, $size); [Array]::Copy($t, 0, $b, $o, $t.Length)
}

function Read-Scenario([string]$path) {
    $d = [IO.File]::ReadAllBytes($path); $o = 0
    $list = New-Object System.Collections.Generic.List[object]
    while ($o -le $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0 -or $o + 20 + $len -gt $d.Length) { throw "Section $name at $o is broken." }
        $data = New-Object byte[] $len
        if ($len -gt 0) { [Array]::Copy($d, $o + 20, $data, 0, $len) }
        $list.Add(@{ Name = $name; Data = $data })
        $o += 20 + $len
    }
    , $list
}

function Write-Scenario([string]$path, $list) {
    $ms = New-Object IO.MemoryStream
    foreach ($a in $list) {
        $header = New-Object byte[] 20
        $n = [Text.Encoding]::ASCII.GetBytes($a.Name)
        if ($n.Length -gt 15) { throw "Section name too long: $($a.Name)" }
        [Array]::Copy($n, $header, $n.Length)
        [Array]::Copy([BitConverter]::GetBytes([int32]$a.Data.Length), 0, $header, 16, 4)
        $ms.Write($header, 0, 20); $ms.Write($a.Data, 0, $a.Data.Length)
    }
    [IO.File]::WriteAllBytes($path, $ms.ToArray())
}

function Get-Section($list, [string]$name) { foreach ($a in $list) { if ($a.Name -eq $name) { return $a } }; $null }

function Set-I32([byte[]]$b, [int]$o, [long]$v) { [Array]::Copy([BitConverter]::GetBytes([int32]$v), 0, $b, $o, 4) }
function Set-U16([byte[]]$b, [int]$o, [int]$v) { [Array]::Copy([BitConverter]::GetBytes([uint16]$v), 0, $b, $o, 2) }

# Town goal: @{ Residents = 500; Stage = 3; OfWhich = 300 }  (stage 0 pioneers ... 4 aristocrats)
function Set-TownGoal([byte[]]$r, [int]$o, $z) {
    if (-not $z) { return }
    Set-I32 $r $o $z.Residents; Set-I32 $r ($o + 4) $z.Stage; Set-I32 $r ($o + 8) $z.OfWhich
}

# New AUFTRAG4 entry. Keys (all optional):
#   Slot, Text, Success, Towns (list of town goals, max. 3), AllTowns (town goal),
#   TownCount, TotalResidents, Balance, TradeBalance, Defeat (list of player numbers), DefeatedCount,
#   Goods1/Goods2 = @{ Good = no.; Tons = t }, Monopoly1/Monopoly2 = @{ Resource = no.; Islands = n },
#   Support = @{ Player = no. (7 = any); Town = town goal }, AlsoAI
function New-Mission($a) {
    $r = New-Object byte[] 0x8C4
    $bits = 0
    Set-I32 $r 0 ([int]$a.Slot)
    $towns = @($a.Towns | Where-Object { $_ })
    if ($towns.Count -gt 3) { throw 'At most 3 town goals.' }
    for ($i = 0; $i -lt $towns.Count; $i++) { Set-TownGoal $r (0x870 + 12 * $i) $towns[$i]; $bits = $bits -bor (1 -shl $i) }
    if ($a.AllTowns) { Set-TownGoal $r 0x8AC $a.AllTowns; $bits = $bits -bor 0x8 }
    if ($a.Support) { $r[0x24] = [byte]$a.Support.Player; Set-TownGoal $r 0x8B8 $a.Support.Town; $bits = $bits -bor 0x10 } else { $r[0x24] = 7 }
    if ($a.TownCount) { Set-I32 $r 0x40 $a.TownCount; $bits = $bits -bor 0x20 }
    if ($a.TotalResidents) { Set-I32 $r 0x44 $a.TotalResidents; $bits = $bits -bor 0x80 }
    if ($a.ContainsKey('Balance')) { Set-I32 $r 0x4C $a.Balance; $bits = $bits -bor 0x100 }
    if ($a.ContainsKey('TradeBalance')) { Set-I32 $r 0x54 $a.TradeBalance; $bits = $bits -bor 0x10000 }
    if ($a.DefeatedCount) { $r[0x2B] = [byte]$a.DefeatedCount; $bits = $bits -bor 0x200 }
    if ($a.Defeat) { foreach ($s in $a.Defeat) { $r[0x2C + $s] = 1 }; $bits = $bits -bor 0x400 }
    if ($a.AlsoAI) { $bits = $bits -bor 0x800 }
    foreach ($k in 1, 2) {
        $w = $a["Goods$k"]; if ($w) { $o = 0x868 + 4 * ($k - 1); $r[$o] = [byte]$w.Good; Set-U16 $r ($o + 2) ([int]($w.Tons * 32)); $bits = $bits -bor (0x1000 -shl ($k - 1)) }
        $m = $a["Monopoly$k"]; if ($m) { $o = 0x20 + 2 * ($k - 1); $r[$o] = [byte]$m.Resource; $r[$o + 1] = [byte]$m.Islands; $bits = $bits -bor (0x4000 -shl ($k - 1)) }
    }
    Set-I32 $r 4 $bits
    Set-I32 $r 0x50 $(if ($a.Success) { $a.Success } else { 85 })
    if ($a.Text) {
        $t = $Cp1252.GetBytes(($a.Text -replace "`r", ''))
        if ($t.Length -gt 0x7FF) { throw "Mission text too long ($($t.Length) bytes, at most 2047)." }
        [Array]::Copy($t, 0, $r, 0x68, $t.Length)
    }
    , $r
}

# Islands: list of @{ Climate = 0 north/1 south/2 by position; Class = 0 lit .. 4 lar; X; Y; File = no. or $null (random); Village = $true/$false }
function Set-Islands([byte[]]$scene, $islands) {
    if ($islands.Count -gt 50) { throw 'At most 50 islands.' }
    [Array]::Clear($scene, 0x174, 50 * 16)
    for ($i = 0; $i -lt $islands.Count; $i++) {
        $e = $islands[$i]; $o = 0x174 + 16 * $i
        $scene[$o] = [byte]$e.Climate; $scene[$o + 1] = [byte]$e.Class; $scene[$o + 2] = [byte]$(if ($e.Village) { 1 } else { 0 }); $scene[$o + 3] = [byte]$i
        Set-U16 $scene ($o + 4) $(if ($null -ne $e.File) { $e.File } else { 0xFFFF })
        Set-I32 $scene ($o + 8) $e.X; Set-I32 $scene ($o + 12) $e.Y
    }
    Set-I32 $scene 0x64 $islands.Count
}
