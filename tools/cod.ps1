<#
.SYNOPSIS
  Ent- und verschluesselt Anno-1602-.cod-Dateien (haeuser.cod, figuren.cod, text.cod, editor.cod).

.DESCRIPTION
  Die .cod-Dateien sind nur verschleiert: jedes Byte ist negiert (Zweierkomplement).
  Dieselbe Operation macht es wieder rueckgaengig, deshalb gibt es nur eine Richtung.

.EXAMPLE
  .\cod.ps1 -In "C:\...\haeuser.cod" -Out .\decoded\haeuser.txt     # lesbar machen
  .\cod.ps1 -In .\decoded\haeuser.txt -Out .\mod\haeuser.cod        # wieder verschluesseln
#>
param(
    [Parameter(Mandatory)][string]$In,
    [Parameter(Mandatory)][string]$Out
)

$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $In))
for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [byte]((256 - $bytes[$i]) -band 0xFF)
}

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
[IO.File]::WriteAllBytes($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out), $bytes)
"{0} -> {1} ({2:N0} Bytes)" -f $In, $Out, $bytes.Length
