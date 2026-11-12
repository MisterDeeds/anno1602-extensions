<#
.SYNOPSIS
  Installiert (oder entfernt) die Anno-1602-Erweiterungen auf diesem PC.

.DESCRIPTION
  Kopiert die Dateien aus dem Ordner "programm" nach %LOCALAPPDATA%\Programs\Anno1602-Erweiterungen
  und legt die Verknuepfung "Anno 1602 - Erweiterungen" im Startmenue und auf dem Desktop an.
  Spieldateien werden nicht veraendert. Vorher wird geprueft, ob Anno 1602 History Edition
  (Ubisoft Connect) installiert ist und ob die Spielversion passt.
  -Entfernen loescht die installierten Dateien und die Verknuepfungen wieder (Spielstaende bleiben).
#>
param(
    [switch]$Entfernen,
    # Nur zum Pruefen: anderer Zielordner, keine Verknuepfungen.
    [string]$Zielordner = (Join-Path $env:LOCALAPPDATA 'Programs\Anno1602-Erweiterungen'),
    [switch]$OhneVerknuepfungen
)
$ErrorActionPreference = 'Stop'
$Name = 'Anno 1602 - Erweiterungen.lnk'
$ErwarteterHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'

function Desktop-Ordner {
    $d = [Environment]::GetFolderPath('Desktop')
    if (-not $d) { try { $d = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders').Desktop } catch { } }
    $d
}
# Kampagnen und Herausforderungen: eigene Szenarien, erscheinen im Spiel unter "Eigene Szenarien".
$EigeneSzenarien = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
$KampagnenMuster = @('Smaragdinseln *.szs', 'Wettlauf *.szs', 'Herausforderung - *.szs')
$Verknuepfungen = @((Join-Path ([Environment]::GetFolderPath('Programs')) $Name))
$desk = Desktop-Ordner
if ($desk) { $Verknuepfungen += (Join-Path $desk $Name) }

if ($Entfernen) {
    if (Test-Path -LiteralPath $Zielordner) { Remove-Item -LiteralPath $Zielordner -Recurse -Force; Write-Host "Entfernt: $Zielordner" }
    if (-not $OhneVerknuepfungen) {
        foreach ($v in $Verknuepfungen) { if (Test-Path -LiteralPath $v) { Remove-Item -LiteralPath $v -Force; Write-Host "Entfernt: $v" } }
    }
    $einst = Join-Path $env:APPDATA 'Anno1602-Erweiterungen'
    if (-not $OhneVerknuepfungen -and (Test-Path -LiteralPath $einst)) { Remove-Item -LiteralPath $einst -Recurse -Force; Write-Host "Entfernt: $einst" }
    if (-not $OhneVerknuepfungen -and (Test-Path -LiteralPath $EigeneSzenarien)) {
        foreach ($muster in $KampagnenMuster) { Get-ChildItem -LiteralPath $EigeneSzenarien -Filter $muster -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; Write-Host "Entfernt: $($_.Name)" } }
    }
    Write-Host 'Die Erweiterungen sind entfernt. Spiel und Spielstaende sind unveraendert.' -ForegroundColor Green
    return
}

# --- Spiel suchen (wie weltgroesse.ps1) -------------------------------------------------------
$spiel = $null
foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
    try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $spiel = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
}
if (-not $spiel -or -not (Test-Path -LiteralPath (Join-Path $spiel 'Anno1602.exe'))) {
    Write-Host 'Anno 1602 History Edition wurde in Ubisoft Connect nicht gefunden.' -ForegroundColor Yellow
    Write-Host 'Bitte zuerst das Spiel ueber Ubisoft Connect installieren. Die Erweiterungen werden trotzdem installiert.' -ForegroundColor Yellow
}
else {
    $hash = (Get-FileHash -LiteralPath (Join-Path $spiel 'Anno1602.exe') -Algorithm SHA256).Hash.ToLower()
    if ($hash -eq $ErwarteterHash) { Write-Host "Spiel gefunden: $spiel (Version passt)." -ForegroundColor Green }
    else { Write-Host "Spiel gefunden: $spiel, aber eine andere Version als getestet. Das Werkzeug bricht dann beim Start ab, ohne etwas zu aendern." -ForegroundColor Yellow }
}

# --- Dateien kopieren -------------------------------------------------------------------------
# Paket (ZIP): Ordner "programm" neben diesem Skript. Quellordner (GitHub): tools\paket\.. und analysis\BEFUNDE.md.
$quelle = Join-Path $PSScriptRoot 'programm'
$tools = Split-Path -Parent $PSScriptRoot
if (Test-Path -LiteralPath (Join-Path $quelle 'weltgroesse.ps1')) {
    $dateien = @(Get-ChildItem -LiteralPath $quelle -File)
}
elseif (Test-Path -LiteralPath (Join-Path $tools 'weltgroesse.ps1')) {
    $dateien = @('weltgroesse.ps1', 'anno-starter.ps1', 'LIESMICH.txt' | ForEach-Object { Get-Item -LiteralPath (Join-Path $tools $_) })
    $befunde = Join-Path (Split-Path -Parent $tools) 'analysis\BEFUNDE.md'
    if (Test-Path -LiteralPath $befunde) { $dateien += Get-Item -LiteralPath $befunde }
}
else { throw "Ordner 'programm' mit weltgroesse.ps1 fehlt neben installieren.ps1." }
New-Item -ItemType Directory -Force -Path $Zielordner | Out-Null
$dateien | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $Zielordner -Force
    try { Unblock-File -LiteralPath (Join-Path $Zielordner $_.Name) } catch { }   # Herkunftsmarke aus dem Internet entfernen
}
Write-Host "Installiert nach: $Zielordner"

# --- Kampagne ---------------------------------------------------------------------------------
$kampagne = Join-Path $PSScriptRoot 'kampagne'
$bauer = Join-Path $tools 'kampagne-bauen.ps1'
if (-not $OhneVerknuepfungen -and -not (Test-Path -LiteralPath $kampagne) -and (Test-Path -LiteralPath $bauer)) {
    # Quellordner (GitHub): Die Szenarien liegen nicht bei, sie entstehen aus den eigenen Spieldateien.
    if ($spiel -and (Test-Path -LiteralPath (Join-Path $spiel 'Szenes'))) {
        Write-Host 'Baue Kampagnen und Herausforderungen aus den Spieldateien ...'
        try { & $bauer -Spielpfad $spiel | Out-Null; $kampagne = Join-Path $tools 'kampagne' }
        catch { Write-Host "Szenarien konnten nicht gebaut werden: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    else { Write-Host 'Ohne installiertes Spiel keine Kampagnen (sie werden aus den Spieldateien gebaut).' -ForegroundColor Yellow }
}
if (-not $OhneVerknuepfungen -and (Test-Path -LiteralPath $kampagne)) {
    New-Item -ItemType Directory -Force -Path $EigeneSzenarien | Out-Null
    $n = 0
    Get-ChildItem -LiteralPath $kampagne -Filter '*.szs' -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $EigeneSzenarien -Force
        try { Unblock-File -LiteralPath (Join-Path $EigeneSzenarien $_.Name) } catch { }
        $n++
    }
    Write-Host "Kampagnen und Herausforderungen: $n Szenarien nach $EigeneSzenarien (im Spiel unter 'Eigene Szenarien')."
}

# --- Verknuepfungen ---------------------------------------------------------------------------
if (-not $OhneVerknuepfungen) {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($v in $Verknuepfungen) {
        New-Item -ItemType Directory -Force -Path (Split-Path $v) | Out-Null
        $l = $ws.CreateShortcut($v)
        $l.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $l.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Zielordner\anno-starter.ps1`""
        $l.WorkingDirectory = $Zielordner
        if ($spiel) { $l.IconLocation = "$(Join-Path $spiel 'Anno1602.exe'),0" }
        $l.Description = 'Anno 1602 History Edition mit grosser Welt und weiteren Optionen starten'
        $l.Save()
        Write-Host "Verknuepfung: $v"
    }
}
Write-Host 'Fertig. Start ueber "Anno 1602 - Erweiterungen" im Startmenue oder auf dem Desktop.' -ForegroundColor Green
