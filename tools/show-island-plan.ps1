<#
.SYNOPSIS
  Shows what tools\anno-patcher.ps1 computes for the islands, without touching the game:
  code cave (hex), island table and one map per endless layout as PNG.
  The functions are loaded from anno-patcher.ps1 (syntax tree); the tool itself does not run.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\show-island-plan.ps1 -Width 1000 -Height 700 -Folder .\analysis\test
#>
param([int]$Width = 1000, [int]$Height = 700, [string]$Folder = '', [switch]$HexOnly)
$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'anno-patcher.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($tool, [ref]$null, [ref]$null)
# Take over the constants and functions of the island part.
foreach ($stmt in $ast.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if ($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
        $txt -match '^\$(GameFolder|CaveRva|TableRva|TableMax|HookRva|HookContinue|ClassW|ClassH|IslandMax|IslandDensity)\b') { . ([scriptblock]::Create($txt)) }
}
$code = Build-IslandCode
$tab = Build-IslandTable $Width $Height $false
'CODEHEX ' + (($code | ForEach-Object { '{0:X2}' -f $_ }) -join '')
"Code cave: $($code.Length) bytes at RVA 0x{0:X}; table: $($tab.Length) bytes at RVA 0x{1:X}" -f $CaveRva, $TableRva
if ($HexOnly) { return }
Add-Type -AssemblyName System.Drawing
foreach ($a in ($script:IslandPlans.Keys | Sort-Object)) {
    $plan = $script:IslandPlans[$a]
    $f = 0.8
    $bmp = New-Object System.Drawing.Bitmap ([int]($Width * $f) + 20), ([int]($Height * $f) + 40)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::FromArgb(30, 60, 110))
    $g.DrawRectangle([System.Drawing.Pens]::White, 10, 30, [int]($Width * $f), [int]($Height * $f))
    $g.DrawRectangle([System.Drawing.Pens]::Gray, 10, 30, [int](500 * $f), [int](350 * $f))
    $font = New-Object System.Drawing.Font 'Arial', 9
    $g.DrawString("Layout $a ([[48]]x$a.szs): $($plan.Count) islands, world $Width x $Height (grey: old area 500 x 350)", $font, [System.Drawing.Brushes]::White, 10, 8)
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $e = $plan[$i]; $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12)
        $w = $ClassW[$e[1]]; $h = $ClassH[$e[1]]
        $color = if ([BitConverter]::ToUInt16($e, 4) -eq 0xFFFF -and $e[0] -eq 2 -and $i -ge $plan.Count) { 'Orange' } else { 'ForestGreen' }
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::$color)
        $g.FillRectangle($brush, [int](10 + $x * $f), [int](30 + $y * $f), [int]($w * $f), [int]($h * $f))
        $g.DrawString("$i", $font, [System.Drawing.Brushes]::White, [int](10 + $x * $f), [int](30 + $y * $f))
    }
    $g.Dispose()
    if ($Folder) { $z = Join-Path $Folder ("island-plan-{0}x{1}-layout-{2}.png" -f $Width, $Height, $a); $bmp.Save($z); "Map: $z" }
    $bmp.Dispose()
}
