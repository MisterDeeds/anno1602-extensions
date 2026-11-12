<#
.SYNOPSIS
  Installs (or removes) the Anno 1602 extensions on this PC.

.DESCRIPTION
  Copies the tool (anno-patcher.ps1), the launcher, the logbook, the scenario builder with the random adventure
  generator, README.txt, README.de.txt and ..\analysis\FINDINGS.md to %LOCALAPPDATA%\Programs\Anno1602-Extensions,
  builds the campaigns and challenges from the game files (build-scenarios.ps1, in the UI language) and copies them to Documents\Anno 1602 History Edition\Own Scenarios, and creates
  the shortcut "Anno 1602 - Extensions" (German Windows: "Anno 1602 - Erweiterungen") in the Start menu
  and on the desktop. Game files are not changed. Checks first whether Anno 1602 History Edition
  (Ubisoft Connect) is installed and whether the game version matches.
  An older installation (%LOCALAPPDATA%\Programs\Anno1602-Erweiterungen) is replaced.
  -Remove deletes the installed files, the shortcuts, the settings and the scenarios again (saved games stay).
#>
param(
    [switch]$Remove,
    # For testing only: different target folder; with -NoShortcuts no shortcuts, settings, scenarios
    # or older installation are touched.
    [string]$TargetFolder = (Join-Path $env:LOCALAPPDATA 'Programs\Anno1602-Extensions'),
    [switch]$NoShortcuts
)
$ErrorActionPreference = 'Stop'

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }

$ShortcutName = Txt 'Anno 1602 - Extensions.lnk' 'Anno 1602 - Erweiterungen.lnk'
# Both names, so that a shortcut from an older version or the other language is replaced or removed.
$AllShortcutNames = @('Anno 1602 - Erweiterungen.lnk', 'Anno 1602 - Extensions.lnk')
$OldInstallFolder = Join-Path $env:LOCALAPPDATA 'Programs\Anno1602-Erweiterungen'
$SettingsFolders = @((Join-Path $env:APPDATA 'Anno1602-Extensions'), (Join-Path $env:APPDATA 'Anno1602-Erweiterungen'))
$ExpectedHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'

function Get-DesktopFolder {
    $d = [Environment]::GetFolderPath('Desktop')
    if (-not $d) { try { $d = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders').Desktop } catch { } }
    $d
}
# Campaigns and challenges: own scenarios, shown in the game under "Own Scenarios" ("Eigene Szenarien").
$OwnScenarios = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
# File names of the scenarios made by this project, both languages, including the random adventures.
$ScenarioNames = '^((Smaragdinseln|Wettlauf|Sturmsee|Emerald Isles|Race|Storm Sea) \d+ - .+|(Herausforderung|Challenge) - .+|(Abenteuer|Adventure) \d+)\.szs$'
$ShortcutFolders = @([Environment]::GetFolderPath('Programs'))
$desk = Get-DesktopFolder
if ($desk) { $ShortcutFolders += $desk }
$Shortcuts = @($ShortcutFolders | ForEach-Object { Join-Path $_ $ShortcutName })

# Deletes the shortcuts with any of the known names (current and older versions, both languages),
# except $keep (it is overwritten anyway).
function Remove-Shortcuts([string]$keep) {
    foreach ($folder in $ShortcutFolders) {
        foreach ($n in $AllShortcutNames) {
            if ($n -eq $keep) { continue }
            $v = Join-Path $folder $n
            if (Test-Path -LiteralPath $v) { Remove-Item -LiteralPath $v -Force; Write-Host (Txt "Removed: $v" "Entfernt: $v") }
        }
    }
}
$targetFull = [IO.Path]::GetFullPath($TargetFolder).TrimEnd('\')
$isOldTarget = $targetFull -eq [IO.Path]::GetFullPath($OldInstallFolder).TrimEnd('\')

if ($Remove) {
    if (Test-Path -LiteralPath $TargetFolder) { Remove-Item -LiteralPath $TargetFolder -Recurse -Force; Write-Host (Txt "Removed: $TargetFolder" "Entfernt: $TargetFolder") }
    if (-not $NoShortcuts) {
        if (-not $isOldTarget -and (Test-Path -LiteralPath $OldInstallFolder)) { Remove-Item -LiteralPath $OldInstallFolder -Recurse -Force; Write-Host (Txt "Removed: $OldInstallFolder" "Entfernt: $OldInstallFolder") }
        Remove-Shortcuts
        foreach ($s in $SettingsFolders) {
            if (Test-Path -LiteralPath $s) { Remove-Item -LiteralPath $s -Recurse -Force; Write-Host (Txt "Removed: $s" "Entfernt: $s") }
        }
        if (Test-Path -LiteralPath $OwnScenarios) {
            Get-ChildItem -LiteralPath $OwnScenarios -Filter '*.szs' -File | Where-Object { $_.Name -match $ScenarioNames } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; Write-Host (Txt "Removed: $($_.Name)" "Entfernt: $($_.Name)") }
        }
    }
    Write-Host (Txt 'The extensions have been removed. Game and saved games are unchanged.' 'Die Erweiterungen sind entfernt. Spiel und Spielstaende sind unveraendert.') -ForegroundColor Green
    return
}

# --- Find the game (as in anno-patcher.ps1) ---------------------------------------------------
$game = $null
foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
    try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $game = ($d -replace '/', '\').TrimEnd('\'); break } } catch { }
}
if (-not $game -or -not (Test-Path -LiteralPath (Join-Path $game 'Anno1602.exe'))) {
    Write-Host (Txt 'Anno 1602 History Edition was not found in Ubisoft Connect.' 'Anno 1602 History Edition wurde in Ubisoft Connect nicht gefunden.') -ForegroundColor Yellow
    Write-Host (Txt 'Please install the game through Ubisoft Connect first. The extensions are installed anyway.' 'Bitte zuerst das Spiel ueber Ubisoft Connect installieren. Die Erweiterungen werden trotzdem installiert.') -ForegroundColor Yellow
}
else {
    $hash = (Get-FileHash -LiteralPath (Join-Path $game 'Anno1602.exe') -Algorithm SHA256).Hash.ToLower()
    if ($hash -eq $ExpectedHash) { Write-Host (Txt "Game found: $game (version matches)." "Spiel gefunden: $game (Version passt).") -ForegroundColor Green }
    else { Write-Host (Txt "Game found: $game, but a different version than tested. The tool then stops at the start without changing anything." "Spiel gefunden: $game, aber eine andere Version als getestet. Das Werkzeug bricht dann beim Start ab, ohne etwas zu aendern.") -ForegroundColor Yellow }
}

# --- Copy files -------------------------------------------------------------------------------
# Repository layout: this script lies in tools\, FINDINGS.md in analysis\ (optional).
# The random adventure generator needs the scenario builder, its library and the island planner of the patcher.
$files = foreach ($n in 'anno-patcher.ps1', 'launcher.ps1', 'logbook.ps1', 'random-adventure.ps1', 'build-scenarios.ps1', 'scenario-lib.ps1', 'README.txt', 'README.de.txt') {
    $f = Join-Path $PSScriptRoot $n
    if (-not (Test-Path -LiteralPath $f)) { throw (Txt "File missing next to install.ps1: $n" "Datei fehlt neben install.ps1: $n") }
    Get-Item -LiteralPath $f
}
$findings = Join-Path (Split-Path -Parent $PSScriptRoot) 'analysis\FINDINGS.md'
if (Test-Path -LiteralPath $findings) { $files = @($files) + (Get-Item -LiteralPath $findings) }
# Upgrade: the older version was installed in ...\Anno1602-Erweiterungen (its settings are taken over by the launcher).
if (-not $NoShortcuts -and -not $isOldTarget -and (Test-Path -LiteralPath $OldInstallFolder)) {
    Remove-Item -LiteralPath $OldInstallFolder -Recurse -Force
    Write-Host (Txt "Removed older installation: $OldInstallFolder" "Aeltere Installation entfernt: $OldInstallFolder")
}
New-Item -ItemType Directory -Force -Path $TargetFolder | Out-Null
$files | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $TargetFolder -Force
    try { Unblock-File -LiteralPath (Join-Path $TargetFolder $_.Name) } catch { }   # remove the downloaded-from-the-internet mark
}
Write-Host (Txt "Installed to: $TargetFolder" "Installiert nach: $TargetFolder")

# --- Scenarios --------------------------------------------------------------------------------
# The scenarios are not part of the repository, they are built from the player's own game files.
$scenarios = $null
$builder = Join-Path $PSScriptRoot 'build-scenarios.ps1'
if (-not $NoShortcuts -and (Test-Path -LiteralPath $builder)) {
    if ($game -and (Test-Path -LiteralPath (Join-Path $game 'Szenes'))) {
        Write-Host (Txt 'Building campaigns and challenges from the game files ...' 'Baue Kampagnen und Herausforderungen aus den Spieldateien ...')
        # Into a fresh folder, so that only the scenarios of this run (in the UI language) are installed.
        $scenarios = Join-Path ([IO.Path]::GetTempPath()) ('anno1602-scenarios-' + [guid]::NewGuid().ToString('N'))
        try { & $builder -GamePath $game -OutFolder $scenarios | Out-Null }
        catch { $scenarios = $null; Write-Host (Txt "Could not build the scenarios: $($_.Exception.Message)" "Szenarien konnten nicht gebaut werden: $($_.Exception.Message)") -ForegroundColor Yellow }
    }
    else { Write-Host (Txt 'No campaigns without the installed game (they are built from the game files).' 'Ohne installiertes Spiel keine Kampagnen (sie werden aus den Spieldateien gebaut).') -ForegroundColor Yellow }
}
if (-not $NoShortcuts -and $scenarios -and (Test-Path -LiteralPath $scenarios)) {
    New-Item -ItemType Directory -Force -Path $OwnScenarios | Out-Null
    $n = 0
    Get-ChildItem -LiteralPath $scenarios -Filter '*.szs' -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $OwnScenarios -Force
        try { Unblock-File -LiteralPath (Join-Path $OwnScenarios $_.Name) } catch { }
        $n++
    }
    Write-Host (Txt "Campaigns and challenges: $n scenarios to $OwnScenarios (in the game under 'Own Scenarios')." "Kampagnen und Herausforderungen: $n Szenarien nach $OwnScenarios (im Spiel unter 'Eigene Szenarien').")
    Remove-Item -LiteralPath $scenarios -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Shortcuts --------------------------------------------------------------------------------
if (-not $NoShortcuts) {
    Remove-Shortcuts $ShortcutName
    $ws = New-Object -ComObject WScript.Shell
    foreach ($v in $Shortcuts) {
        New-Item -ItemType Directory -Force -Path (Split-Path $v) | Out-Null
        $l = $ws.CreateShortcut($v)
        $l.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $l.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TargetFolder\launcher.ps1`""
        $l.WorkingDirectory = $TargetFolder
        if ($game) { $l.IconLocation = "$(Join-Path $game 'Anno1602.exe'),0" }
        $l.Description = Txt 'Start Anno 1602 History Edition with a bigger world and more options' 'Anno 1602 History Edition mit grosser Welt und weiteren Optionen starten'
        $l.Save()
        Write-Host (Txt "Shortcut: $v" "Verknuepfung: $v")
    }
}
Write-Host (Txt 'Done. Start with "Anno 1602 - Extensions" in the Start menu or on the desktop.' 'Fertig. Start ueber "Anno 1602 - Erweiterungen" im Startmenue oder auf dem Desktop.') -ForegroundColor Green
