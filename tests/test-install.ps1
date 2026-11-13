<#
.SYNOPSIS
  Tests install.cmd / uninstall.cmd for real, but in a sandbox: every user folder (programs, settings, documents,
  desktop, start menu) lies in a temporary folder (src\install.ps1 -SandboxRoot). The installed game is only read
  (the scenarios are built from its templates). Nothing outside the sandbox is changed; the test checks that too.

.DESCRIPTION
  1. A sandbox like a PC with the older version: old program folder Anno1602-Erweiterungen, old shortcut, old
     settings, plus the player's own files (own scenario, the game's "Last Szenario", a savegame).
  2. Install in German: new program folder with exactly the files of src\ and docs\FINDINGS.md, old folder gone,
     German shortcut in the start menu and on the desktop pointing to the new launcher, 23 scenarios, own files kept.
  3. Install again in English: English shortcut instead of the German one, English scenarios added.
  4. Two random adventures appear (old and new name format); then -Remove: program folders, both shortcut names,
     both settings folders and all our scenarios (both languages, adventures) are gone, the player's files stay.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tests\test-install.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'src\install.ps1'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('anno1602-install-test-' + [guid]::NewGuid().ToString('N'))
$script:ok = 0; $script:fail = 0
function Test-That([string]$what, [bool]$cond) {
    if ($cond) { $script:ok++; "  OK    $what" } else { $script:fail++; "  FAIL  $what" }
}
function Get-Shortcut([string]$path) { (New-Object -ComObject WScript.Shell).CreateShortcut($path) }
function Invoke-Installer([string]$lang, [switch]$Remove) {
    $env:ANNO_EXTENSIONS_LANG = $lang
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-SandboxRoot', $sandbox)
    if ($Remove) { $a += '-Remove' }
    $out = & powershell @a 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Installer failed: $out" }
}

# Fingerprint of the real installation, so that the test can prove it does not touch it.
function Get-RealState {
    $parts = foreach ($p in (Join-Path $env:LOCALAPPDATA 'Programs\Anno1602-Extensions'), (Join-Path $env:APPDATA 'Anno1602-Extensions'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'),
        [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
        if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -File -Filter '*' | Where-Object { $_.Name -match 'Anno 1602|\.szs$|\.ps1$|\.json$|\.md$|\.txt$' } | ForEach-Object { '{0}|{1}|{2}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks } }
    }
    ($parts | Sort-Object) -join "`n"
}
$langBefore = $env:ANNO_EXTENSIONS_LANG
$realBefore = Get-RealState
try {
    # --- 1. A PC with the older version ---------------------------------------------------------------------------
    $local = Join-Path $sandbox 'LocalAppData'; $app = Join-Path $sandbox 'AppData'; $docs = Join-Path $sandbox 'Documents\Anno 1602 History Edition'
    $desk = Join-Path $sandbox 'Desktop'; $start = Join-Path $sandbox 'StartMenu'
    $new = Join-Path $local 'Programs\Anno1602-Extensions'; $old = Join-Path $local 'Programs\Anno1602-Erweiterungen'
    $own = Join-Path $docs 'Own Scenarios'
    foreach ($d in $old, (Join-Path $app 'Anno1602-Erweiterungen'), $own, (Join-Path $docs 'Savegame'), $desk, $start) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    Set-Content -LiteralPath (Join-Path $old 'weltgroesse.ps1') 'old version'
    Set-Content -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen\einstellungen.json') '{}'
    $l = Get-Shortcut (Join-Path $desk 'Anno 1602 - Erweiterungen.lnk'); $l.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"; $l.Arguments = "-File `"$old\anno-starter.ps1`""; $l.Save()
    Set-Content -LiteralPath (Join-Path $own 'Meine Karte.szs') 'own scenario'
    Set-Content -LiteralPath (Join-Path $own 'Last Szenario.szs') 'the game''s own autosave'
    Set-Content -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam') 'savegame'

    # --- 2. Install in German ---------------------------------------------------------------------------------------
    "Install (German) into the sandbox $sandbox"
    Invoke-Installer 'de'
    $expected = @('anno-patcher.ps1', 'launcher.ps1', 'logbook.ps1', 'random-adventure.ps1', 'build-scenarios.ps1', 'scenario-lib.ps1', 'README.txt', 'README.de.txt', 'FINDINGS.md')
    $have = @(Get-ChildItem -LiteralPath $new -File | ForEach-Object Name)
    Test-That "program folder holds exactly the 9 files ($($have.Count))" ($have.Count -eq 9 -and -not ($expected | Where-Object { $_ -notin $have }))
    $same = @($expected | Where-Object { $src = if ($_ -eq 'FINDINGS.md') { Join-Path $root 'docs\FINDINGS.md' } else { Join-Path $root "src\$_" }; (Get-FileHash -LiteralPath (Join-Path $new $_)).Hash -eq (Get-FileHash -LiteralPath $src).Hash }).Count
    Test-That "installed files identical to the repository ($same/9)" ($same -eq 9)
    Test-That 'older installation Anno1602-Erweiterungen removed' (-not (Test-Path -LiteralPath $old))
    foreach ($f in $desk, $start) {
        $lnk = Join-Path $f 'Anno 1602 - Erweiterungen.lnk'
        Test-That "German shortcut in $(Split-Path $f -Leaf) points to the new launcher" ((Test-Path -LiteralPath $lnk) -and (Get-Shortcut $lnk).Arguments -like "*$new\launcher.ps1*")
    }
    $ours = @(Get-ChildItem -LiteralPath $own -Filter '*.szs' | Where-Object { $_.Name -notin 'Meine Karte.szs', 'Last Szenario.szs' })
    Test-That "23 German scenarios installed ($($ours.Count))" ($ours.Count -eq 23 -and @($ours | Where-Object { $_.Name -like 'Sturmsee 1 - *' }).Count -eq 1)
    Test-That 'own scenario, Last Szenario and savegame untouched' ((Get-Content -LiteralPath (Join-Path $own 'Meine Karte.szs')) -eq 'own scenario' -and (Test-Path -LiteralPath (Join-Path $own 'Last Szenario.szs')) -and (Test-Path -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam')))
    Test-That 'old settings left for the launcher to take over' (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen\einstellungen.json'))

    # --- 3. Install again in English ----------------------------------------------------------------------------------
    'Install again (English)'
    Invoke-Installer 'en'
    Test-That 'English shortcut on the desktop' (Test-Path -LiteralPath (Join-Path $desk 'Anno 1602 - Extensions.lnk'))
    Test-That 'German shortcuts replaced' (-not (Test-Path -LiteralPath (Join-Path $desk 'Anno 1602 - Erweiterungen.lnk')) -and -not (Test-Path -LiteralPath (Join-Path $start 'Anno 1602 - Erweiterungen.lnk')))
    Test-That 'English scenarios added (Storm Sea 1)' (@(Get-ChildItem -LiteralPath $own -Filter 'Storm Sea 1 - *.szs').Count -eq 1)

    # --- 4. Remove ----------------------------------------------------------------------------------------------------
    Set-Content -LiteralPath (Join-Path $own 'Abenteuer 4711.szs') 'adventure, old name'
    Set-Content -LiteralPath (Join-Path $own 'Adventure 99 Easy.szs') 'adventure, new name'
    New-Item -ItemType Directory -Force -Path (Join-Path $app 'Anno1602-Extensions') | Out-Null
    Set-Content -LiteralPath (Join-Path $app 'Anno1602-Extensions\settings.json') '{}'
    'Remove (uninstall.cmd)'
    Invoke-Installer 'de' -Remove
    Test-That 'program folder removed' (-not (Test-Path -LiteralPath $new))
    Test-That 'no shortcut left (both names, desktop and start menu)' (-not (Get-ChildItem -LiteralPath $desk, $start -Filter 'Anno 1602 - *.lnk'))
    Test-That 'both settings folders removed' (-not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Extensions')) -and -not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen')))
    $left = @(Get-ChildItem -LiteralPath $own -Filter '*.szs' | ForEach-Object Name | Sort-Object)
    Test-That "only the player's files are left in Own Scenarios ($($left -join ', '))" (($left -join '|') -eq 'Last Szenario.szs|Meine Karte.szs')
    Test-That 'savegame untouched' (Test-Path -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam'))
}
finally {
    $env:ANNO_EXTENSIONS_LANG = $langBefore
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
Test-That 'real installation, settings, own scenarios and shortcuts unchanged' ((Get-RealState) -eq $realBefore)
if ($script:fail) { "{0} of {1} checks FAILED." -f $script:fail, ($script:ok + $script:fail); exit 1 }
"All {0} checks passed." -f $script:ok
