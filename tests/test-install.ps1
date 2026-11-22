<#
.SYNOPSIS
  Tests install.cmd / uninstall.cmd for real, but in a sandbox: every user folder (programs, settings, documents,
  desktop, start menu) lies in a temporary folder (src\install.ps1 -SandboxRoot). The installed game is only read
  (the scenarios are built from its templates). Nothing outside the sandbox is changed; the test checks that too.

.DESCRIPTION
  1. A sandbox like a PC with the older version: old program folder Anno1602-Erweiterungen, old shortcut, old
     settings, plus the player's own files (own scenarios, the game's "Last Szenario", a savegame).
  2. Install in German: new program folder with exactly the files of src\ and docs\FINDINGS.md, old folder gone,
     German shortcut in the start menu and on the desktop pointing to the new launcher, every scenario of
     build-scenarios.ps1 in Own Scenarios, the full set with the chapter index in the program folder, own files kept.
  3. Install again in English with "unlock chapters one by one" on and some won chapters in logbook.json (German and
     English names): English shortcut instead of the German one, English scenarios added, of each campaign only the
     chapters up to the first one not won (in both languages), challenges and the player's files untouched.
  4. The installed launcher in the sandbox (-TestClicks): the scenario designer builds "Eigenes - Testinsel" into Own
     Scenarios and the list shows it, the daily adventure is built, chapters on shows locks, off copies every chapter back.
     Updates: after an update (settings LastVersion older) the launcher says so once; an older release changes nothing;
     a newer one shows the notice and its button downloads get.ps1 and starts it as a file; with "Update automatically"
     the update starts by itself, but only once per version and day.
  5. Adventures, daily adventures and designer scenarios appear (both languages); then -Remove through the installed
     copy, as the Windows "Apps" list does it: program folders, both shortcut names, both settings folders, the Apps
     entry and all our scenarios are gone, the player's files stay.
  6. The one-line installer get.ps1, run through Invoke-Expression like "irm ... | iex", with a ZIP of the repository
     in the layout of a GitHub release (ANNO_EXTENSIONS_SOURCE) into a second sandbox: everything installed, the
     launcher would open, the temporary download folder is gone; a broken ZIP gives a message and no exception.
  The Apps entry is written to apps-entry.json in the sandbox instead of the registry.

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
function Invoke-Installer([string]$lang, [switch]$Remove, [switch]$StartLauncher, [string]$Script = $installer) {
    $env:ANNO_EXTENSIONS_LANG = $lang
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-SandboxRoot', $sandbox)
    if ($Remove) { $a += '-Remove' }
    if ($StartLauncher) { $a += '-StartLauncher' }
    $out = & powershell @a 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Installer failed: $out" }
    $out
}
# Every scenario definition of the builder (titles in both languages), so that new campaigns are counted too.
$definitions = @(& { . (Join-Path $root 'src\build-scenarios.ps1') -Library; $Scenarios })
$titles = @{ de = @($definitions | ForEach-Object { $_.Title.de }); en = @($definitions | ForEach-Object { $_.Title.en }) }
$chapterCount = @($titles.de | Where-Object { $_ -match '^(.+?) (\d+) - ' }).Count
# Chapter title in a language: campaign of the given title, chapter number n.
function Get-Chapter([string]$lang, [string]$campaign, [int]$n) { @($titles[$lang] | Where-Object { $_ -like "$campaign $n - *" })[0] }

# Fingerprint of the real installation, so that the test can prove it does not touch it.
function Get-RealState {
    $parts = foreach ($p in (Join-Path $env:LOCALAPPDATA 'Programs\Anno1602-Extensions'), (Join-Path $env:APPDATA 'Anno1602-Extensions'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'),
        [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
        if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -File -Filter '*' | Where-Object { $_.Name -match 'Anno 1602|\.szs$|\.ps1$|\.json$|\.md$|\.txt$' } | ForEach-Object { '{0}|{1}|{2}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks } }
    }
    # The real entry in the Windows Apps list.
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Anno1602-Extensions'
    if (Test-Path -LiteralPath $key) { $parts = @($parts) + ('apps|' + ((Get-ItemProperty -LiteralPath $key | Select-Object DisplayVersion, InstallDate, UninstallString | ConvertTo-Json -Compress))) }
    ($parts | Sort-Object) -join "`n"
}
# Version of the repository (newest entry of CHANGELOG.md), as install.ps1 writes it to version.txt.
$repoVersion = ((Select-String -LiteralPath (Join-Path $root 'CHANGELOG.md') -Pattern '^## (\d+\.\d+\.\d+)' | Select-Object -First 1).Matches[0].Groups[1].Value)
$langBefore = $env:ANNO_EXTENSIONS_LANG
$realBefore = Get-RealState
try {
    # --- 1. A PC with the older version ---------------------------------------------------------------------------
    $local = Join-Path $sandbox 'LocalAppData'; $app = Join-Path $sandbox 'AppData'; $docs = Join-Path $sandbox 'Documents\Anno 1602 History Edition'
    $desk = Join-Path $sandbox 'Desktop'; $start = Join-Path $sandbox 'StartMenu'
    $new = Join-Path $local 'Programs\Anno1602-Extensions'; $old = Join-Path $local 'Programs\Anno1602-Erweiterungen'
    $own = Join-Path $docs 'Own Scenarios'; $set = Join-Path $new 'scenarios'
    $playerFiles = @('Last Szenario.szs', 'Meine Karte.szs', 'Meine Karte 2 - Fortsetzung.szs')
    foreach ($d in $old, (Join-Path $app 'Anno1602-Erweiterungen'), $own, (Join-Path $docs 'Savegame'), $desk, $start) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    Set-Content -LiteralPath (Join-Path $old 'weltgroesse.ps1') 'old version'
    Set-Content -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen\einstellungen.json') '{}'
    $l = Get-Shortcut (Join-Path $desk 'Anno 1602 - Erweiterungen.lnk'); $l.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"; $l.Arguments = "-File `"$old\anno-starter.ps1`""; $l.Save()
    Set-Content -LiteralPath (Join-Path $own 'Meine Karte.szs') 'own scenario'
    Set-Content -LiteralPath (Join-Path $own 'Meine Karte 2 - Fortsetzung.szs') 'own scenario, named like a chapter'
    Set-Content -LiteralPath (Join-Path $own 'Last Szenario.szs') 'the game''s own autosave'
    Set-Content -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam') 'savegame'

    # --- 2. Install in German ---------------------------------------------------------------------------------------
    "Install (German) into the sandbox $sandbox"
    $out = Invoke-Installer 'de' -StartLauncher
    $copied = @('anno-patcher.ps1', 'island-forge.cs', 'launcher.ps1', 'logbook.ps1', 'random-adventure.ps1', 'scenario-designer.ps1', 'build-scenarios.ps1', 'scenario-lib.ps1', 'install.ps1', 'README.txt', 'README.de.txt', 'FINDINGS.md')
    $expected = $copied + 'version.txt'
    $have = @(Get-ChildItem -LiteralPath $new -File | ForEach-Object Name)
    Test-That "program folder holds exactly the $($expected.Count) files ($($have.Count))" ($have.Count -eq $expected.Count -and -not ($expected | Where-Object { $_ -notin $have }))
    $differ = @($copied | Where-Object { $src = if ($_ -eq 'FINDINGS.md') { Join-Path $root 'docs\FINDINGS.md' } else { Join-Path $root "src\$_" }; (Get-FileHash -LiteralPath (Join-Path $new $_)).Hash -ne (Get-FileHash -LiteralPath $src).Hash })
    Test-That "installed files identical to the repository ($($copied.Count - $differ.Count)/$($copied.Count)$(if ($differ.Count) { ', different: ' + ($differ -join ', ') }))" ($differ.Count -eq 0)
    $installedVersion = (Get-Content -LiteralPath (Join-Path $new 'version.txt') -Raw).Trim()
    Test-That "version.txt = newest CHANGELOG entry ($installedVersion)" ($installedVersion -eq $repoVersion)
    $apps = Get-Content -LiteralPath (Join-Path $sandbox 'apps-entry.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Test-That "Apps entry: `"$($apps.DisplayName)`" $($apps.DisplayVersion), uninstall runs the installed copy with -Remove" ($apps.DisplayName -eq "Anno 1602 $([char]0x2013) Erweiterungen" -and $apps.DisplayVersion -eq $repoVersion -and $apps.InstallLocation -eq $new -and $apps.UninstallString -like "*-File `"$new\install.ps1`" -Remove -PauseAtEnd" -and $apps.QuietUninstallString -like '*-Remove' -and $apps.EstimatedSize -gt 100)
    Test-That 'launcher would open at the end (-StartLauncher)' ($out -match ('START .*powershell\.exe .*-WindowStyle Hidden -File "' + [regex]::Escape("$new\launcher.ps1") + '"') -and $out -match 'Fertig!')
    Test-That 'older installation Anno1602-Erweiterungen removed' (-not (Test-Path -LiteralPath $old))
    foreach ($f in $desk, $start) {
        $lnk = Join-Path $f 'Anno 1602 - Erweiterungen.lnk'
        Test-That "German shortcut in $(Split-Path $f -Leaf) points to the new launcher" ((Test-Path -LiteralPath $lnk) -and (Get-Shortcut $lnk).Arguments -like "*$new\launcher.ps1*")
    }
    $ours = @(Get-ChildItem -LiteralPath $own -Filter '*.szs' | Where-Object { $_.Name -notin $playerFiles })
    $missing = @($titles.de | Where-Object { -not (Test-Path -LiteralPath (Join-Path $own "$_.szs")) })
    Test-That "all $($definitions.Count) German scenarios installed ($($ours.Count), missing: $($missing -join ', '))" ($ours.Count -eq $definitions.Count -and $missing.Count -eq 0)
    $index = Get-Content -LiteralPath (Join-Path $set 'chapters.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $setFiles = @(Get-ChildItem -LiteralPath $set -Filter '*.szs')
    $sameSet = @($setFiles | Where-Object { (Get-FileHash -LiteralPath $_.FullName).Hash -eq (Get-FileHash -LiteralPath (Join-Path $own $_.Name)).Hash }).Count
    Test-That "full set in the program folder ($($setFiles.Count) files, $sameSet identical to Own Scenarios)" ($setFiles.Count -eq $definitions.Count -and $sameSet -eq $definitions.Count)
    $badChapters = @($index.chapters | Where-Object { $_.file -notmatch '^(.+?) (\d+) - ' -or $_.campaign -ne $Matches[1] -or $_.chapter -ne [int]$Matches[2] -or @($_.names).Count -ne 2 -or $_.file -notin $titles.de })
    Test-That "chapter index: $(@($index.chapters).Count) campaign chapters of $chapterCount, campaign/number/both names right ($($badChapters.Count) wrong)" (@($index.chapters).Count -eq $chapterCount -and $badChapters.Count -eq 0)
    Test-That "the player's scenarios, Last Szenario and savegame untouched" ((Get-Content -LiteralPath (Join-Path $own 'Meine Karte.szs')) -eq 'own scenario' -and (Test-Path -LiteralPath (Join-Path $own 'Last Szenario.szs')) -and (Test-Path -LiteralPath (Join-Path $own 'Meine Karte 2 - Fortsetzung.szs')) -and (Test-Path -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam')))
    Test-That 'old settings left for the launcher to take over' (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen\einstellungen.json'))

    # --- 3. Install again in English, chapters one by one -------------------------------------------------------------
    # Won: Emerald Isles 1 (German name), Race 1 (English name) and Race 2 (German name) -> open: Emerald Isles 1-2,
    # Race 1-3 and chapter 1 of every other campaign.
    New-Item -ItemType Directory -Force -Path (Join-Path $app 'Anno1602-Extensions') | Out-Null
    '{ "UnlockChapters": "1", "World": "1000x700" }' | Set-Content -LiteralPath (Join-Path $app 'Anno1602-Extensions\settings.json') -Encoding UTF8
    $won = @((Get-Chapter 'de' 'Smaragdinseln' 1), (Get-Chapter 'en' 'Race' 1), (Get-Chapter 'de' 'Wettlauf' 2))
    $log = @{ version = 1; achievements = @(); settings = @{}; missions = @($won | ForEach-Object { @{ scenario = $_; title = 'test'; result = 'won'; date = '2026-11-14T12:00:00'; gameHours = 5 } }) + @(@{ scenario = (Get-Chapter 'en' 'Storm Sea' 1); result = 'lost'; date = '2026-11-14T13:00:00' }) }
    $log | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $app 'Anno1602-Extensions\logbook.json') -Encoding UTF8
    'Install again (English), chapters one by one'
    $out = Invoke-Installer 'en'
    Test-That 'English shortcut on the desktop' (Test-Path -LiteralPath (Join-Path $desk 'Anno 1602 - Extensions.lnk'))
    Test-That 'German shortcuts replaced' (-not (Test-Path -LiteralPath (Join-Path $desk 'Anno 1602 - Erweiterungen.lnk')) -and -not (Test-Path -LiteralPath (Join-Path $start 'Anno 1602 - Erweiterungen.lnk')))
    Test-That 'English scenarios added (Storm Sea 1)' (@(Get-ChildItem -LiteralPath $own -Filter 'Storm Sea 1 - *.szs').Count -eq 1)
    $expectOpen = @{ 'Smaragdinseln' = 2; 'Wettlauf' = 3 }
    $wrong = foreach ($t in $titles.de) {
        if ($t -notmatch '^(.+?) (\d+) - ') { continue }
        $campaign = $Matches[1]; $n = [int]$Matches[2]; $openUpTo = if ($expectOpen.ContainsKey($campaign)) { $expectOpen[$campaign] } else { 1 }
        $en = $titles.en[[array]::IndexOf($titles.de, $t)]
        $hasEn = Test-Path -LiteralPath (Join-Path $own "$en.szs"); $hasDe = Test-Path -LiteralPath (Join-Path $own "$t.szs")
        if ($n -le $openUpTo -and -not $hasEn) { "$en missing" }
        if ($n -gt $openUpTo -and ($hasEn -or $hasDe)) { "$t / $en not locked" }
    }
    Test-That "only the unlocked chapters are in Own Scenarios, in both languages ($(@($wrong) -join '; '))" (@($wrong).Count -eq 0 -and $out -match 'locked')
    $challenges = @($titles.en | Where-Object { $_ -notmatch ' \d+ - ' })
    Test-That "challenges stay ($(@($challenges | Where-Object { Test-Path -LiteralPath (Join-Path $own "$_.szs") }).Count) of $($challenges.Count))" (@($challenges | Where-Object { -not (Test-Path -LiteralPath (Join-Path $own "$_.szs")) }).Count -eq 0)
    Test-That "the player's scenarios untouched by the unlocking" (@($playerFiles | Where-Object { Test-Path -LiteralPath (Join-Path $own $_) }).Count -eq $playerFiles.Count)

    # --- 4. The installed launcher in the sandbox ----------------------------------------------------------------------
    'Launcher click test in the sandbox (designer, daily adventure, chapters on/off, updates)'
    $env:ANNO_EXTENSIONS_LANG = 'de'
    # As after an automatic update: the launcher last ran as version 1.0.0.
    $settingsPath = Join-Path $app 'Anno1602-Extensions\settings.json'
    $s = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $s | Add-Member -NotePropertyName LastVersion -NotePropertyValue '1.0.0' -Force
    $s | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    $clicks = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $new 'launcher.ps1') -TestClicks -AppDataFolder $app -DocumentsFolder (Join-Path $sandbox 'Documents') -TestOutFolder (Join-Path $sandbox 'launcher-test') 2>&1 | ForEach-Object { "$_" })
    $clickText = $clicks -join "`n"
    Test-That 'designer: "Eigenes - Testinsel" built into Own Scenarios and selected in the list' ((Test-Path -LiteralPath (Join-Path $own 'Eigenes - Testinsel.szs')) -and $clickText -match 'LIST tab 2, selected: Eigenes - Testinsel')
    Test-That 'daily adventure built ("Tagesabenteuer <today>")' ($clickText -match ('Tagesabenteuer {0}' -f (Get-Date -Format 'yyyy-MM-dd')) -and (Test-Path -LiteralPath (Join-Path $sandbox ('launcher-test\Tagesabenteuer {0}.szs' -f (Get-Date -Format 'yyyy-MM-dd')))))
    $onLine = @($clicks | Where-Object { $_ -like 'ON *' })[0]; $offLine = @($clicks | Where-Object { $_ -like 'OFF *' })[0]
    $locked = if ($onLine -match ', (\d+) locked') { [int]$Matches[1] } else { -1 }
    Test-That "chapters on: $locked locked chapters with a lock in the list, setting saved" ($locked -gt 0 -and $onLine -match 'UnlockChapters=1' -and @($clicks | Where-Object { $_ -match '^\s+.* \| .*gesperrt' }).Count -eq $locked)
    # The set in the program folder is English now (the last installation).
    Test-That 'chapters off: every chapter of the set back in Own Scenarios, setting saved' ($offLine -match ', 0 locked' -and $offLine -match 'UnlockChapters=0' -and @($titles.en | Where-Object { $_ -match ' \d+ - ' -and -not (Test-Path -LiteralPath (Join-Path $own "$_.szs")) }).Count -eq 0)
    Test-That 'click test: patcher started, no exception' ($clickText -match 'START powershell .*anno-patcher\.ps1' -and $clickText -notmatch 'Exception|Fehler')
    $v = [regex]::Escape($repoVersion)
    Test-That "after an update: `"Aktualisiert auf Version $repoVersion.`" with the button for the release notes, version saved" ($clickText -match "UPDATED-NOTE visible: True Aktualisiert auf Version $v\. \| news button True" -and (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).LastVersion -eq $repoVersion)
    Test-That 'update: nothing for an older release; without "automatically" the notice and the button (download + get.ps1 as a file)' ($clickText -match "UPDATE v1\.0\.0: Aktualisiert auf Version $v\." -and $clickText -match 'UPDATE v99\.0\.0 auto off: Version 99\.0\.0 ist da\., starts 0' -and $clickText -match 'UPDATE button: starts 1' -and $clickText -match 'DOWNLOAD https://raw\.githubusercontent\.com/MisterDeeds/anno1602-extensions/main/get\.ps1' -and $clickText -match 'START powershell -NoProfile -ExecutionPolicy Bypass -File ".*anno1602-extensions-update\.ps1"')
    $today = Get-Date -Format 'yyyy-MM-dd'
    Test-That 'update automatically: starts by itself, saved, only once per version and day' ($clickText -match "UPDATE auto on: starts 2, Version 99\.0\.0 ist da und wird installiert .*, saved AutoUpdate=1 UpdateTried=99\.0\.0 $today" -and $clickText -match 'UPDATE auto again the same day: starts 2')

    # --- 5. Remove ----------------------------------------------------------------------------------------------------
    foreach ($n in 'Abenteuer 4711.szs', 'Adventure 99 Easy.szs', 'Tagesabenteuer 2026-11-14.szs', 'Daily Adventure 2026-11-14.szs', 'Custom - My Island.szs') { Set-Content -LiteralPath (Join-Path $own $n) 'made by the extensions' }
    New-Item -ItemType Directory -Force -Path (Join-Path $app 'Anno1602-Extensions') | Out-Null
    Set-Content -LiteralPath (Join-Path $app 'Anno1602-Extensions\settings.json') '{}'
    # Islands of the island forge (3.4), as the tool leaves them below LOCALAPPDATA.
    $forgeFolder = Join-Path $local 'Anno1602-Extensions\islands\0123abcd-r1-m1-v1-g8\Nord'
    New-Item -ItemType Directory -Force -Path $forgeFolder | Out-Null
    Set-Content -LiteralPath (Join-Path $forgeFolder 'lar20.scp') 'giant island'
    $before = @(Get-ChildItem -LiteralPath $new -Recurse -File | ForEach-Object { '{0}|{1}' -f $_.FullName, $_.LastWriteTimeUtc.Ticks }) -join "`n"
    $out = Invoke-Installer 'de' -Script (Join-Path $new 'install.ps1')
    Test-That 'the installed copy does not install over itself (only removes)' ($out -match 'installierte Kopie' -and $before -eq (@(Get-ChildItem -LiteralPath $new -Recurse -File | ForEach-Object { '{0}|{1}' -f $_.FullName, $_.LastWriteTimeUtc.Ticks }) -join "`n"))
    'Remove through the installed copy (Windows Apps list)'
    $null = Invoke-Installer 'de' -Remove -Script (Join-Path $new 'install.ps1')
    Test-That 'program folder removed, with the installed copy itself' (-not (Test-Path -LiteralPath $new))
    Test-That 'Apps entry removed' (-not (Test-Path -LiteralPath (Join-Path $sandbox 'apps-entry.json')))
    Test-That 'no shortcut left (both names, desktop and start menu)' (-not (Get-ChildItem -LiteralPath $desk, $start -Filter 'Anno 1602 - *.lnk'))
    Test-That 'both settings folders removed' (-not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Extensions')) -and -not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen')))
    Test-That 'islands of the island forge removed (LOCALAPPDATA\Anno1602-Extensions)' (-not (Test-Path -LiteralPath (Join-Path $local 'Anno1602-Extensions')))
    $left = @(Get-ChildItem -LiteralPath $own -Filter '*.szs' | ForEach-Object Name | Sort-Object)
    Test-That "only the player's files are left in Own Scenarios ($($left -join ', '))" (($left -join '|') -eq (($playerFiles | Sort-Object) -join '|'))
    Test-That 'savegame untouched' (Test-Path -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam'))

    # --- 6. One-line installer (get.ps1) ------------------------------------------------------------------------------
    # A ZIP like GitHub builds it for a release: one folder anno1602-extensions-<version> with the repository's files
    # (git ls-files, including files not committed yet; without git: the folders and files the installer needs).
    $staging = Join-Path $sandbox "zip\anno1602-extensions-$repoVersion"
    $repoFiles = @()
    try { $repoFiles = @(& git -C $root ls-files --cached --others --exclude-standard 2>$null) } catch { }
    if (-not $repoFiles.Count) { $repoFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'src'), (Join-Path $root 'docs') -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1) }) + @('CHANGELOG.md', 'get.ps1', 'install.cmd', 'uninstall.cmd') }
    foreach ($f in $repoFiles) {
        $src = Join-Path $root $f
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
        $dst = Join-Path $staging $f
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $sandbox 'release.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $sandbox 'zip'), $zip)
    $broken = Join-Path $sandbox 'broken.zip'
    $brokenFolder = Join-Path $sandbox 'broken\anno1602-extensions-0.0.0'
    New-Item -ItemType Directory -Force -Path $brokenFolder | Out-Null
    Set-Content -LiteralPath (Join-Path $brokenFolder 'README.md') 'no src folder'
    [IO.Compression.ZipFile]::CreateFromDirectory((Split-Path $brokenFolder), $broken)
    $sandbox2 = Join-Path $sandbox 'oneliner'
    $setupFolders = { @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'anno1602-extensions-setup-*').Count }
    $setupBefore = & $setupFolders
    # As "irm <url> | iex": the script text through Invoke-Expression, in a PowerShell window of its own; afterwards the
    # window must still have no variable of the script and the default error preference.
    $getScript = Join-Path $root 'get.ps1'
    $command = "Invoke-Expression ([IO.File]::ReadAllText('$getScript')); 'AFTER work=' + [bool](Get-Variable work -ErrorAction SilentlyContinue) + ' pref=' + `$ErrorActionPreference"
    "One-line installer (get.ps1 through Invoke-Expression, English) into $sandbox2"
    $env:ANNO_EXTENSIONS_SOURCE = $zip; $env:ANNO_EXTENSIONS_SANDBOX = $sandbox2; $env:ANNO_EXTENSIONS_LANG = 'en'
    $out = & powershell -NoProfile -Command $command 2>&1 | Out-String
    $code = $LASTEXITCODE
    $new2 = Join-Path $sandbox2 'LocalAppData\Programs\Anno1602-Extensions'
    $differ2 = @($copied | Where-Object { $src = if ($_ -eq 'FINDINGS.md') { Join-Path $root 'docs\FINDINGS.md' } else { Join-Path $root "src\$_" }; -not (Test-Path -LiteralPath (Join-Path $new2 $_)) -or (Get-FileHash -LiteralPath (Join-Path $new2 $_)).Hash -ne (Get-FileHash -LiteralPath $src).Hash })
    Test-That "get.ps1: installed from the ZIP, files identical to the repository ($($copied.Count - $differ2.Count)/$($copied.Count)), version $repoVersion" ($code -eq 0 -and $differ2.Count -eq 0 -and (Get-Content -LiteralPath (Join-Path $new2 'version.txt') -Raw).Trim() -eq $repoVersion)
    $own2 = @(Get-ChildItem -LiteralPath (Join-Path $sandbox2 'Documents\Anno 1602 History Edition\Own Scenarios') -Filter '*.szs' -ErrorAction SilentlyContinue)
    Test-That "get.ps1: all $($definitions.Count) English scenarios, English shortcut on the desktop and in the start menu" ($own2.Count -eq $definitions.Count -and @($titles.en | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sandbox2 "Documents\Anno 1602 History Edition\Own Scenarios\$_.szs")) }).Count -eq 0 -and (Test-Path -LiteralPath (Join-Path $sandbox2 'Desktop\Anno 1602 - Extensions.lnk')) -and (Test-Path -LiteralPath (Join-Path $sandbox2 'StartMenu\Anno 1602 - Extensions.lnk')))
    $apps2 = if (Test-Path -LiteralPath (Join-Path $sandbox2 'apps-entry.json')) { Get-Content -LiteralPath (Join-Path $sandbox2 'apps-entry.json') -Raw -Encoding UTF8 | ConvertFrom-Json }
    Test-That "get.ps1: Apps entry `"$($apps2.DisplayName)`" $($apps2.DisplayVersion)" ($apps2 -and $apps2.DisplayName -eq "Anno 1602 $([char]0x2013) Extensions" -and $apps2.DisplayVersion -eq $repoVersion)
    Test-That 'get.ps1: launcher would open, "Done!" shown' ($out -match ('START .*-File "' + [regex]::Escape("$new2\launcher.ps1") + '"') -and $out -match 'Done!' -and $out -match 'have fun')
    Test-That "get.ps1: nothing left in the PowerShell window ($(($out -split "`r?`n" | Where-Object { $_ -like 'AFTER*' }) -join ''))" ($out -match 'AFTER work=False pref=Continue')
    Test-That 'get.ps1: temporary download folder removed' ((& $setupFolders) -eq $setupBefore)
    $env:ANNO_EXTENSIONS_SOURCE = $broken
    $out = & powershell -NoProfile -Command $command 2>&1 | Out-String
    Test-That 'get.ps1 with a broken ZIP: clear message, no exception, window stays usable' ($LASTEXITCODE -eq 0 -and $out -match 'incomplete' -and $out -match 'AFTER work=False pref=Continue' -and $out -notmatch 'At line|ParserError|Exception')
}
finally {
    foreach ($n in 'ANNO_EXTENSIONS_SOURCE', 'ANNO_EXTENSIONS_SANDBOX') { Remove-Item -LiteralPath "Env:$n" -ErrorAction SilentlyContinue }
    $env:ANNO_EXTENSIONS_LANG = $langBefore
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
Test-That 'real installation, settings, own scenarios and shortcuts unchanged' ((Get-RealState) -eq $realBefore)
if ($script:fail) { "{0} of {1} checks FAILED." -f $script:fail, ($script:ok + $script:fail); exit 1 }
"All {0} checks passed." -f $script:ok
