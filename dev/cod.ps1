<#
.SYNOPSIS
  Decodes and encodes Anno 1602 .cod files (haeuser.cod, figuren.cod, text.cod, editor.cod).

.DESCRIPTION
  The .cod files are only obfuscated: every byte is negated (two's complement).
  The same operation reverses it, so there is only one direction.

.EXAMPLE
  .\cod.ps1 -In "C:\...\haeuser.cod" -Out .\decoded\haeuser.txt     # make readable
  .\cod.ps1 -In .\decoded\haeuser.txt -Out .\mod\haeuser.cod        # encode again
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
"{0} -> {1} ({2:N0} bytes)" -f $In, $Out, $bytes.Length
