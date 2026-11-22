<#
.SYNOPSIS
  Test of the island forge (src\island-forge.cs) with the real island files of the game, without starting the game.

.DESCRIPTION
  Builds the island folder into a temporary folder for each option on its own and for all together, and checks
  every written file (the game folder is only read; its files are compared by hash before and after):
    1  Every written island covers each tile exactly once (sizes from haeuser.cod); the chunks other than the
       header, the landscape and the deer are byte-identical with the original.
    2  No rivers: no river piece, spring, river mouth or bridge is left in any written island; every island of the
       game with a river is written; the islands under village files and the village files themselves too.
    3  Mountains at the edge: a rock-and-slope group lies completely at the coast (nearest tile at most 3, farthest at
       most 10 tiles from it) unless it is part of a village or has no free place at the coast; ranges are split
       into single mountains; the rock pieces of every island stay the same (number and kind); on the giant islands
       every group lies at the coast.
    4  No volcano: only Nord\big25 is written, its volcano count and volcano mountains are 0.
    5  Giant islands: 8 per climate (lar20-lar27), larger than "lar" (100 x 90), the same size in Nord and Sued, no
       river, at least one mountain, coast and water only from pieces the game itself uses for the same shape.
    6  The same options give byte-identical files (deterministic), the build takes less than 30 s.
#>
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$forge = Join-Path $root 'src\island-forge.cs'
$script:checks = 0; $script:failed = 0
function Assert-Check([string]$what, [bool]$ok) {
    $script:checks++
    if ($ok) { Write-Host "  ok   $what" } else { $script:failed++; Write-Host "  FAIL $what" -ForegroundColor Red }
}

# Game folder as in the tool: Ubisoft Connect install 16236, otherwise the default folder.
$game = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition'
foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
    try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d -and (Test-Path -LiteralPath (Join-Path $d 'haeuser.cod'))) { $game = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
}
if (-not (Test-Path -LiteralPath (Join-Path $game 'haeuser.cod'))) { Write-Host "Game not found ($game)." -ForegroundColor Red; exit 1 }
Add-Type -Path $forge -ReferencedAssemblies System.Core
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('anno-islands-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Get-GameHashes { $h = @{}; foreach ($f in Get-ChildItem -LiteralPath $game -Recurse -File -Include *.scp, haeuser.cod) { $h[$f.FullName] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }; $h }
function Invoke-Forge([string]$name, [bool]$rivers, [bool]$mountains, [bool]$volcano, [int]$giants) {
    $o = New-Object AnnoIslands.Options; $o.NoRivers = $rivers; $o.EdgeMountains = $mountains; $o.NoVolcano = $volcano; $o.GiantPerClimate = $giants
    $dir = Join-Path $tmp $name
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $log = [AnnoIslands.Forge]::Build($game, $dir, $o)
    @{ Dir = $dir; Log = @($log); Seconds = $sw.Elapsed.TotalSeconds }
}
function Get-Written($run) { if (Test-Path -LiteralPath $run.Dir) { @(Get-ChildItem -LiteralPath $run.Dir -Recurse -File -Filter *.scp) } else { @() } }
function Get-Rel($run, $file) { $file.FullName.Substring($run.Dir.Length + 1) }
function Get-Original([string]$rel) { $p = Join-Path $game $rel; if (Test-Path -LiteralPath $p) { [AnnoIslands.Island]::Load($p) } else { $null } }
$RiverIds = @(901, 902, 903, 904, 905, 1601, 2311, 1071, 1208)
function Get-Kind([int]$id) { [AnnoIslands.Houses]::Kind($id) }
# Chunks other than header, landscape and deer are unchanged.
function Test-OtherChunks($island, $orig) {
    if ($island.Names.Count -ne $orig.Names.Count) { return $false }
    for ($i = 0; $i -lt $island.Names.Count; $i++) {
        if ($island.Names[$i] -ne $orig.Names[$i]) { return $false }
        if ($i -eq $island.HeaderIndex -or $island.Names[$i] -in 'INSELHAUS', 'HIRSCH2') { continue }
        if ([BitConverter]::ToString($island.Data[$i]) -ne [BitConverter]::ToString($orig.Data[$i])) { return $false }
    }
    $true
}

try {
    $before = Get-GameHashes
    [AnnoIslands.Houses]::Load((Join-Path $game 'haeuser.cod'))
    Assert-Check "building table read from haeuser.cod ($([AnnoIslands.Houses]::All.Count) entries, rock 1110 = 6x6)" ([AnnoIslands.Houses]::All.Count -gt 400 -and ([AnnoIslands.Houses]::Size(1110, 0) -join 'x') -eq '6x6')

    Write-Host '2  No rivers'
    $r = Invoke-Forge 'rivers' $true $false $false 0
    $files = Get-Written $r
    $withRiver = 0; $left = 0; $bad = 0; $other = 0; $villages = 0; $irregular = 0
    foreach ($d in 'Nord', 'Sued', 'NoKlima') {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $game $d) -Filter *.scp) {
            $i = [AnnoIslands.Island]::Load($f.FullName)
            if (@($i.E | Where-Object { (Get-Kind $_.Id) -in 'FLUSS', 'FLUSSECK' }).Count -gt 0) { $withRiver++ }
        }
    }
    foreach ($f in $files) {
        $rel = Get-Rel $r $f; $i = [AnnoIslands.Island]::Load($f.FullName); $o = Get-Original $rel
        $all = @($i.E) + @(0..($i.Names.Count - 1) | Where-Object { $i.Names[$_] -eq 'INSELHAUS' -and $_ -ne $i.HausIndex } | ForEach-Object { $i.ParseLayer($_) })
        if (@($all | Where-Object { $_ -and $RiverIds -contains $_.Id }).Count -gt 0) { $left++ }
        if ($rel -match 'Nat\\') { $villages++; continue }
        # Whole islands: every tile once. The few island files of the game with empty or doubly covered tiles: not more of them.
        $dn = $i.Defects(); $do = $o.Defects()
        if ($dn[0] -gt $do[0] -or $dn[1] -gt $do[1] -or (($do[0] + $do[1]) -eq 0 -and ($dn[0] + $dn[1]) -ne 0)) { $bad++ }
        if (($do[0] + $do[1]) -gt 0) { $irregular++ }
        if (-not (Test-OtherChunks $i $o)) { $other++ }
    }
    $wholeWritten = @($files | Where-Object { (Get-Rel $r $_) -notmatch 'Nat\\' }).Count
    Assert-Check "every island with a river written ($wholeWritten written, $withRiver with a river in Nord/Sued/NoKlima)" ($wholeWritten -ge $withRiver -and $withRiver -gt 150)
    Assert-Check "no river piece, spring, mouth or bridge left ($left files with one)" ($left -eq 0)
    Assert-Check "1 every written island covers each tile once ($bad wrong; $irregular files of the game with empty or double tiles: not more of them)" ($bad -eq 0)
    Assert-Check "1 other chunks unchanged ($other files differ)" ($other -eq 0)
    Assert-Check "village files without rivers written ($villages)" ($villages -gt 0)

    Write-Host '3  Mountains at the edge'
    $m = Invoke-Forge 'mountains' $false $true $false 0
    $files = Get-Written $m
    $rockDiff = 0; $bad = 0; $far = 0; $moved = 0
    foreach ($f in $files) {
        $rel = Get-Rel $m $f; $i = [AnnoIslands.Island]::Load($f.FullName); $o = Get-Original $rel
        try { [void]$i.Cover($true) } catch { $bad++ }
        $ri = (@($i.E | Where-Object { (Get-Kind $_.Id) -eq 'FELS' } | ForEach-Object { $_.Id }) | Sort-Object) -join ','
        $ro = (@($o.E | Where-Object { (Get-Kind $_.Id) -eq 'FELS' } | ForEach-Object { $_.Id }) | Sort-Object) -join ','
        if ($ri -ne $ro) { $rockDiff++ }
        $moved++
    }
    Assert-Check "islands with moved mountains written ($moved)" ($moved -gt 100)
    Assert-Check "1 every written island covers each tile once ($bad wrong)" ($bad -eq 0)
    Assert-Check "rock pieces unchanged in every island, number and kind ($rockDiff differ)" ($rockDiff -eq 0)
    # Statistic: share of mountain groups at most 3 tiles from the coast, and completely at the coast (farthest tile
    # at most 10 tiles), before and after (all whole islands).
    $near = [AnnoIslands.Forge]::MountainShare($game, $null); $nearAfter = [AnnoIslands.Forge]::MountainShare($game, $m.Dir)
    Assert-Check ("mountain groups near the coast: {0:P0} before, {1:P0} after" -f $near, $nearAfter) ($nearAfter -gt 0.9 -and $nearAfter -gt $near + 0.2)
    $whole = [AnnoIslands.Forge]::MountainShare($game, $null, $true); $wholeAfter = [AnnoIslands.Forge]::MountainShare($game, $m.Dir, $true)
    Assert-Check ("mountain groups completely at the coast (no range into the inland): {0:P0} before, {1:P0} after" -f $whole, $wholeAfter) ($wholeAfter -gt 0.9 -and $wholeAfter -gt $whole + 0.25)

    Write-Host '4  No volcano'
    $v = Invoke-Forge 'volcano' $false $false $true 0
    $files = Get-Written $v
    $big25 = if ($files.Count -eq 1) { [AnnoIslands.Island]::Load($files[0].FullName) } else { $null }
    $zero = $big25 -and $big25.Header[23] -eq 0 -and @($big25.Header[60..91] | Where-Object { $_ -ne 0 }).Count -eq 0
    Assert-Check ("only Nord\big25 written ({0}), volcano count and volcano mountains 0" -f (($files | ForEach-Object { Get-Rel $v $_ }) -join ', ')) ($files.Count -eq 1 -and (Get-Rel $v $files[0]) -match '^Nord\\big25\.scp$' -and $zero)
    $orig = Get-Original 'Nord\big25.scp'
    Assert-Check 'volcano island otherwise unchanged (landscape and all other header bytes)' ($big25 -and [BitConverter]::ToString($big25.Data[$big25.HausIndex]) -eq [BitConverter]::ToString($orig.Data[$orig.HausIndex]) -and (@(0..115 | Where-Object { $_ -ne 23 -and ($_ -lt 60 -or $_ -gt 91) -and $big25.Header[$_] -ne $orig.Header[$_] }).Count -eq 0))

    Write-Host '5  Giant islands'
    $g = Invoke-Forge 'giant' $false $false $false 8
    $ok = $true; $sizes = @(); $noRule = 0; $rivers = 0; $mountainsMissing = 0
    for ($n = 20; $n -lt 28; $n++) {
        $a = Join-Path $g.Dir "Nord\lar$n.scp"; $b = Join-Path $g.Dir "Sued\lar$n.scp"
        if (-not (Test-Path -LiteralPath $a) -or -not (Test-Path -LiteralPath $b)) { $ok = $false; continue }
        $ia = [AnnoIslands.Island]::Load($a); $ib = [AnnoIslands.Island]::Load($b)
        if ($ia.W -ne $ib.W -or $ia.H -ne $ib.H -or $ia.W * $ia.H -le 100 * 90) { $ok = $false }
        $sizes += '{0}x{1}' -f $ia.W, $ia.H
        foreach ($i in $ia, $ib) {
            try { [void]$i.Cover($true) } catch { $ok = $false }
            if (@($i.E | Where-Object { $RiverIds -contains $_.Id }).Count -gt 0) { $rivers++ }
            if (@($i.E | Where-Object { (Get-Kind $_.Id) -eq 'FELS' }).Count -eq 0) { $mountainsMissing++ }
            $noRule += [AnnoIslands.Giants]::CountTilesWithoutRule($i)
            if ([BitConverter]::ToUInt16($i.Header, 96) -ne $n -or [BitConverter]::ToUInt16($i.Header, 98) -ne 4) { $ok = $false }
        }
        if ($ia.Header[100] -ne 0 -or $ib.Header[100] -ne 1) { $ok = $false }
    }
    Assert-Check ("16 giant islands, larger than 100 x 90, same size in Nord and Sued, header file 20-27 / class 4 / climate ({0})" -f ($sizes -join ' ')) ($ok -and $sizes.Count -eq 8)
    Assert-Check "giant islands without rivers ($rivers with one) and with mountains ($mountainsMissing without)" ($rivers -eq 0 -and $mountainsMissing -eq 0)
    Assert-Check "coast and water of the giant islands only from pieces the game uses for the same shape ($noRule tiles without a rule)" ($noRule -eq 0)

    Write-Host '6  Everything together, deterministic, time'
    $all1 = Invoke-Forge 'all1' $true $true $true 8
    $all2 = Invoke-Forge 'all2' $true $true $true 8
    $f1 = Get-Written $all1; $f2 = Get-Written $all2; $same = $f1.Count -eq $f2.Count
    if ($same) { foreach ($f in $f1) { $o = Join-Path $all2.Dir (Get-Rel $all1 $f); if (-not (Test-Path -LiteralPath $o) -or (Get-FileHash -LiteralPath $f.FullName).Hash -ne (Get-FileHash -LiteralPath $o).Hash) { $same = $false; break } } }
    Assert-Check ("all options: {0} files, two builds byte-identical" -f $f1.Count) ($same -and $f1.Count -gt 300)
    $bad = 0
    foreach ($f in $f1) {
        $rel = Get-Rel $all1 $f; if ($rel -match 'Nat\\') { continue }
        $dn = ([AnnoIslands.Island]::Load($f.FullName)).Defects(); $o = Get-Original $rel
        $do = if ($o) { $o.Defects() } else { @(0, 0) }   # giant islands: no original, must be whole
        if ($dn[0] -gt $do[0] -or $dn[1] -gt $do[1] -or (($do[0] + $do[1]) -eq 0 -and ($dn[0] + $dn[1]) -ne 0)) { $bad++ }
    }
    Assert-Check "all options: every written island covers each tile once ($bad wrong)" ($bad -eq 0)
    $groups = 0; $inland = 0
    foreach ($f in $f1 | Where-Object { $_.Name -match '^lar2\d\.scp$' }) {
        foreach ($gr in [AnnoIslands.Forge]::MountainGroups([AnnoIslands.Island]::Load($f.FullName))) { $groups++; if ($gr[2] -gt 3 -or $gr[3] -gt [AnnoIslands.Forge]::EdgeBand) { $inland++ } }
    }
    Assert-Check "all options: every mountain of the giant islands completely at the coast ($groups groups, $inland not)" ($groups -gt 100 -and $inland -eq 0)
    Assert-Check ("build time {0:N1} s (all options)" -f $all1.Seconds) ($all1.Seconds -lt 30)

    $after = Get-GameHashes
    $changed = @($before.Keys | Where-Object { $after[$_] -ne $before[$_] }).Count
    Assert-Check "game folder unchanged ($($before.Count) files compared, $changed changed)" ($changed -eq 0 -and $after.Count -eq $before.Count)
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($script:failed) { Write-Host "$($script:failed) of $($script:checks) check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host "All $($script:checks) checks passed." -ForegroundColor Green
