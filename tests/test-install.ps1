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
  5. Adventures, daily adventures and designer scenarios appear (both languages); then -Remove: program folders, both
     shortcut names, both settings folders and all our scenarios are gone, the player's files stay.

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
    ($parts | Sort-Object) -join "`n"
}
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
    $null = Invoke-Installer 'de'
    $expected = @('anno-patcher.ps1', 'launcher.ps1', 'logbook.ps1', 'random-adventure.ps1', 'scenario-designer.ps1', 'build-scenarios.ps1', 'scenario-lib.ps1', 'README.txt', 'README.de.txt', 'FINDINGS.md')
    $have = @(Get-ChildItem -LiteralPath $new -File | ForEach-Object Name)
    Test-That "program folder holds exactly the $($expected.Count) files ($($have.Count))" ($have.Count -eq $expected.Count -and -not ($expected | Where-Object { $_ -notin $have }))
    $differ = @($expected | Where-Object { $src = if ($_ -eq 'FINDINGS.md') { Join-Path $root 'docs\FINDINGS.md' } else { Join-Path $root "src\$_" }; (Get-FileHash -LiteralPath (Join-Path $new $_)).Hash -ne (Get-FileHash -LiteralPath $src).Hash })
    Test-That "installed files identical to the repository ($($expected.Count - $differ.Count)/$($expected.Count)$(if ($differ.Count) { ', different: ' + ($differ -join ', ') }))" ($differ.Count -eq 0)
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
    'Launcher click test in the sandbox (designer, daily adventure, chapters on/off)'
    $env:ANNO_EXTENSIONS_LANG = 'de'
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

    # --- 5. Remove ----------------------------------------------------------------------------------------------------
    foreach ($n in 'Abenteuer 4711.szs', 'Adventure 99 Easy.szs', 'Tagesabenteuer 2026-11-14.szs', 'Daily Adventure 2026-11-14.szs', 'Custom - My Island.szs') { Set-Content -LiteralPath (Join-Path $own $n) 'made by the extensions' }
    New-Item -ItemType Directory -Force -Path (Join-Path $app 'Anno1602-Extensions') | Out-Null
    Set-Content -LiteralPath (Join-Path $app 'Anno1602-Extensions\settings.json') '{}'
    'Remove (uninstall.cmd)'
    $null = Invoke-Installer 'de' -Remove
    Test-That 'program folder removed' (-not (Test-Path -LiteralPath $new))
    Test-That 'no shortcut left (both names, desktop and start menu)' (-not (Get-ChildItem -LiteralPath $desk, $start -Filter 'Anno 1602 - *.lnk'))
    Test-That 'both settings folders removed' (-not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Extensions')) -and -not (Test-Path -LiteralPath (Join-Path $app 'Anno1602-Erweiterungen')))
    $left = @(Get-ChildItem -LiteralPath $own -Filter '*.szs' | ForEach-Object Name | Sort-Object)
    Test-That "only the player's files are left in Own Scenarios ($($left -join ', '))" (($left -join '|') -eq (($playerFiles | Sort-Object) -join '|'))
    Test-That 'savegame untouched' (Test-Path -LiteralPath (Join-Path $docs 'Savegame\Meine Welt.gam'))
}
finally {
    $env:ANNO_EXTENSIONS_LANG = $langBefore
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
Test-That 'real installation, settings, own scenarios and shortcuts unchanged' ((Get-RealState) -eq $realBefore)
if ($script:fail) { "{0} of {1} checks FAILED." -f $script:fail, ($script:ok + $script:fail); exit 1 }
"All {0} checks passed." -f $script:ok
