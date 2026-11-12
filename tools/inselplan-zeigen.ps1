<#
.SYNOPSIS
  Zeigt, was tools\weltgroesse.ps1 fuer die Inseln berechnet, ohne das Spiel anzufassen:
  Codestueck (Hex), Inseltabelle und je Endlos-Anordnung eine Karte als PNG.
  Die Funktionen werden aus weltgroesse.ps1 geladen (Syntaxbaum), das Werkzeug selbst laeuft nicht.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tools\inselplan-zeigen.ps1 -Breite 1000 -Hoehe 700 -Ordner .\analysis\test
#>
param([int]$Breite = 1000, [int]$Hoehe = 700, [string]$Ordner = '', [switch]$NurHex)
$ErrorActionPreference = 'Stop'
$werkzeug = Join-Path $PSScriptRoot 'weltgroesse.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($werkzeug, [ref]$null, [ref]$null)
# Konstanten und Funktionen des Inselteils uebernehmen.
foreach ($stmt in $ast.EndBlock.Statements) {
    $txt = $stmt.Extent.Text
    if ($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
        $txt -match '^\$(SpielOrdner|CaveRva|TabelleRva|TabelleMax|HakenRva|HakenWeiter|KlasseB|KlasseH)\b') { . ([scriptblock]::Create($txt)) }
}
$code = Baue-Codestueck
$tab = Baue-Tabelle $Breite $Hoehe $false
'CODEHEX ' + (($code | ForEach-Object { '{0:X2}' -f $_ }) -join '')
"Codestueck: $($code.Length) Bytes ab RVA 0x{0:X}; Tabelle: $($tab.Length) Bytes ab RVA 0x{1:X}" -f $CaveRva, $TabelleRva
if ($NurHex) { return }
Add-Type -AssemblyName System.Drawing
foreach ($a in ($script:InselPlaene.Keys | Sort-Object)) {
    $plan = $script:InselPlaene[$a]
    $f = 0.8
    $bmp = New-Object System.Drawing.Bitmap ([int]($Breite * $f) + 20), ([int]($Hoehe * $f) + 40)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::FromArgb(30, 60, 110))
    $g.DrawRectangle([System.Drawing.Pens]::White, 10, 30, [int]($Breite * $f), [int]($Hoehe * $f))
    $g.DrawRectangle([System.Drawing.Pens]::Gray, 10, 30, [int](500 * $f), [int](350 * $f))
    $font = New-Object System.Drawing.Font 'Arial', 9
    $g.DrawString("Anordnung $a ([[48]]x$a.szs): $($plan.Count) Inseln, Welt $Breite x $Hoehe (grau: alter Bereich 500 x 350)", $font, [System.Drawing.Brushes]::White, 10, 8)
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $e = $plan[$i]; $x = [BitConverter]::ToInt32($e, 8); $y = [BitConverter]::ToInt32($e, 12)
        $w = $KlasseB[$e[1]]; $h = $KlasseH[$e[1]]
        $farbe = if ([BitConverter]::ToUInt16($e, 4) -eq 0xFFFF -and $e[0] -eq 2 -and $i -ge $plan.Count) { 'Orange' } else { 'ForestGreen' }
        $pinsel = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::$farbe)
        $g.FillRectangle($pinsel, [int](10 + $x * $f), [int](30 + $y * $f), [int]($w * $f), [int]($h * $f))
        $g.DrawString("$i", $font, [System.Drawing.Brushes]::White, [int](10 + $x * $f), [int](30 + $y * $f))
    }
    $g.Dispose()
    if ($Ordner) { $z = Join-Path $Ordner ("inselplan-{0}x{1}-anordnung-{2}.png" -f $Breite, $Hoehe, $a); $bmp.Save($z); "Karte: $z" }
    $bmp.Dispose()
}
