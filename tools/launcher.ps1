<#
.SYNOPSIS
  Launcher window for Anno 1602 History Edition with the extensions from anno-patcher.ps1.

.DESCRIPTION
  Shows all options as drop-down lists, remembers the last choice and then starts
  anno-patcher.ps1 (in its own window that stays open until the game ends) and the game
  through Ubisoft Connect. "Start original" only starts the game, without changes.
  The settings are stored in %APPDATA%\Anno1602-Extensions\settings.json (option id -> value key,
  independent of the UI language). The settings of older versions
  (%APPDATA%\Anno1602-Erweiterungen\einstellungen.json) are taken over; the old file is left in place.
#>
param(
    # For testing only: build the window invisibly, save it as a PNG and exit.
    [string]$PreviewImage,
    # For testing only: print the anno-patcher.ps1 arguments for the defaults, "Everything big",
    # "For campaigns" and the saved choice (one line each) and exit without showing the window.
    [Parameter(DontShow)][switch]$PrintArgs,
    # For testing only: folder used instead of %APPDATA% for the settings.
    [Parameter(DontShow)][string]$AppDataFolder = $env:APPDATA
)
$ErrorActionPreference = 'Stop'

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($UiGerman) { $de } else { $en } }

$Patcher = Join-Path $PSScriptRoot 'anno-patcher.ps1'
$GameStart = 'uplay://launch/16236/0'
$SettingsFile = Join-Path $AppDataFolder 'Anno1602-Extensions\settings.json'
$OldSettingsFile = Join-Path $AppDataFolder 'Anno1602-Erweiterungen\einstellungen.json'

# One choice of an option: display text, the German text (older versions saved it, see below)
# and the arguments for anno-patcher.ps1.
function New-Choice([string]$en, [string]$de, [string[]]$patcherArgs = @()) {
    @{ Text = (Txt $en $de); De = $de; Args = $patcherArgs }
}

# Every option: label, default and choices (value key -> choice). settings.json stores the value keys,
# so they must stay stable; the order here is the order in the window and in the argument list.
$Options = [ordered]@{
    World         = @{ Label = (Txt 'Map size' 'Kartengrösse'); Default = '1000x700'; Choices = [ordered]@{
            '500x350'   = New-Choice 'Original (500 × 350)' 'Original (500 × 350)' @('-Width', '500', '-Height', '350')
            '750x525'   = New-Choice 'Large (750 × 525)' 'Gross (750 × 525)' @('-Width', '750', '-Height', '525')
            '1000x700'  = New-Choice 'Very large (1000 × 700)' 'Sehr gross (1000 × 700)'
            '2000x1400' = New-Choice 'Huge (2000 × 1400)' 'Riesig (2000 × 1400)' @('-Width', '2000', '-Height', '1400') } }
    Islands       = @{ Label = (Txt 'Islands' 'Inseln'); Default = 'More'; Choices = [ordered]@{
            'More'        = New-Choice 'More islands (up to 50)' 'Mehr Inseln (bis 50)'
            'StretchOnly' = New-Choice 'Only spread over the map' 'Nur über die Karte verteilt' @('-StretchOnly')
            'Original'    = New-Choice 'As in the original' 'Wie im Original' @('-NoIslandSpread') } }
    IslandSize    = @{ Label = (Txt 'Island size' 'Inselgrösse'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'
            'Large'  = New-Choice 'Large (many large islands)' 'Gross (viele grosse Inseln)' @('-IslandSize', 'Large')
            'Huge'   = New-Choice 'Huge (almost only the largest)' 'Riesig (fast nur die grössten)' @('-IslandSize', 'Huge') } }
    Resources     = @{ Label = (Txt 'Resources' 'Rohstoffe'); Default = 'More'; Choices = [ordered]@{
            'Template' = New-Choice 'As in the template' 'Wie in der Vorlage'
            'More'     = New-Choice 'More (to match the islands)' 'Mehr (passend zur Inselzahl)' @('-Resources', 'More')
            'Lots'     = New-Choice 'Lots (twice as many)' 'Viele (doppelt so viele)' @('-Resources', 'Lots') } }
    Natives       = @{ Label = (Txt 'Natives' 'Ureinwohner'); Default = 'Default'; Choices = [ordered]@{
            'Default' = New-Choice 'As template (2 + 2 villages)' 'Wie Vorlage (2 + 2 Dörfer)'
            'More'    = New-Choice 'More (4 + 4 villages)' 'Mehr (4 + 4 Dörfer)' @('-Natives', 'More')
            'Lots'    = New-Choice 'Lots (7 + 7 villages)' 'Viele (7 + 7 Dörfer)' @('-Natives', 'Lots') } }
    Traders       = @{ Label = (Txt 'Free traders' 'Freie Händler'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'
            'More'   = New-Choice 'More (twice as many)' 'Mehr (doppelt so viele)' @('-Traders', 'More')
            'Lots'   = New-Choice 'Lots (three times, up to 24)' 'Viele (dreimal, bis 24)' @('-Traders', 'Lots') } }
    Rivals        = @{ Label = (Txt 'Computer rivals' 'Computergegner'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            'Hard'       = New-Choice 'Always like “Hard”' 'Immer wie „Schwer“' @('-Rivals', 'Hard') } }
    RivalGold     = @{ Label = (Txt "Rivals' gold" 'Gold der Gegner'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            '30000'      = New-Choice '30,000' '30 000' @('-RivalGold', '30000')
            '60000'      = New-Choice '60,000' '60 000' @('-RivalGold', '60000')
            '100000'     = New-Choice '100,000' '100 000' @('-RivalGold', '100000') } }
    Pirates       = @{ Label = (Txt 'Pirates' 'Piraten'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            'Active'     = New-Choice 'Always attack' 'Greifen immer an' @('-Pirates', 'Active')
            'Strong'     = New-Choice 'Strong (full cannons)' 'Stark (volle Kanonen)' @('-Pirates', 'Strong')
            'Off'        = New-Choice 'No pirates' 'Keine Piraten' @('-Pirates', 'Off') } }
    PirateFleet   = @{ Label = (Txt 'Pirate fleet' 'Piratenflotte'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal (up to 4 ships)' 'Normal (bis 4 Schiffe)'
            'Large'  = New-Choice 'Large (up to 8 ships)' 'Gross (bis 8 Schiffe)' @('-PirateFleet', 'Large')
            'Huge'   = New-Choice 'Huge (up to 12 ships)' 'Riesig (bis 12 Schiffe)' @('-PirateFleet', 'Huge') } }
    StartGold     = @{ Label = (Txt 'Your starting gold' 'Dein Startgold'); Default = 'Difficulty'; Choices = [ordered]@{
            'Difficulty' = New-Choice 'As per difficulty' 'Wie Schwierigkeit'
            '30000'      = New-Choice '30,000' '30 000' @('-StartGold', '30000')
            '50000'      = New-Choice '50,000' '50 000' @('-StartGold', '50000')
            '100000'     = New-Choice '100,000' '100 000' @('-StartGold', '100000') } }
    Residents     = @{ Label = (Txt 'Residents per house' 'Einwohner je Haus'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Residents', '1.5'); '2' = New-Choice '× 2' '× 2' @('-Residents', '2')
            '3' = New-Choice '× 3' '× 3' @('-Residents', '3'); '4' = New-Choice '× 4' '× 4' @('-Residents', '4'); '5' = New-Choice '× 5' '× 5' @('-Residents', '5') } }
    Turbo         = @{ Label = (Txt 'Turbo (F7 key)' 'Turbo (Taste F7)'); Default = 'Off'; Choices = [ordered]@{
            'Off' = New-Choice 'Off (4×)' 'Aus (4-fach)'; '8' = New-Choice '8×' '8-fach' @('-Turbo')
            '12' = New-Choice '12×' '12-fach' @('-Turbo', '-TurboLevel', '12'); '16' = New-Choice '16×' '16-fach' @('-Turbo', '-TurboLevel', '16') } }
    Production    = @{ Label = (Txt 'Production speed' 'Produktionstempo'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Production', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-Production', '2'); '3' = New-Choice '× 3' '× 3' @('-Production', '3') } }
    Storage       = @{ Label = (Txt 'Storage per good' 'Lager je Ware'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '2' = New-Choice '× 2' '× 2' @('-Storage', '2')
            '3' = New-Choice '× 3' '× 3' @('-Storage', '3'); '5' = New-Choice '× 5' '× 5' @('-Storage', '5') } }
    ShipSpeed     = @{ Label = (Txt 'Ship speed' 'Schiffstempo'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-ShipSpeed', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-ShipSpeed', '2'); '3' = New-Choice '× 3' '× 3' @('-ShipSpeed', '3') } }
    Cargo         = @{ Label = (Txt 'Cargo space' 'Laderaum der Schiffe'); Default = 'Normal'; Choices = [ordered]@{
            'Normal' = New-Choice 'Normal' 'Normal'; '1.5' = New-Choice '× 1.5' '× 1,5' @('-Cargo', '1.5')
            '2' = New-Choice '× 2' '× 2' @('-Cargo', '2'); '3' = New-Choice '× 3' '× 3' @('-Cargo', '3') } }
}

# "Everything big": big world with huge islands, lots of resources, big towns and a fast game.
# 1000 x 700 instead of 2000 x 1400 because the game knows at most 50 islands; on 2000 x 1400 almost everything would be sea.
# Plus more life and more rivals: natives and traders "Lots", AI always "Hard", pirates attack
# and keep a fleet twice as big.
$EverythingBig = @{
    World = '1000x700'; Islands = 'More'; IslandSize = 'Huge'
    Resources = 'Lots'; Natives = 'Lots'; Traders = 'Lots'
    Rivals = 'Hard'; RivalGold = '60000'; Pirates = 'Active'; PirateFleet = 'Large'
    StartGold = '50000'; Residents = '5'; Turbo = '16'; Production = '2'; Storage = '5'; ShipSpeed = '2'; Cargo = '3'
}

# "For campaigns": big version of the campaign maps (from 1000 x 700 with "More islands"), gold as intended by the
# scenario (the gold options would replace it), turbo; economy and rivals as in the original,
# so that the missions are as hard as planned.
$ForCampaigns = @{
    World = '1000x700'; Islands = 'More'; RivalGold = 'Difficulty'; StartGold = 'Difficulty'
    Turbo = '16'
}

# Load the last choice (option id -> value key). Missing or broken file: defaults.
$saved = @{}
try {
    if (Test-Path -LiteralPath $SettingsFile) {
        $j = Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) { $saved[$p.Name] = [string]$p.Value }
    }
    elseif (Test-Path -LiteralPath $OldSettingsFile) {
        # Older versions stored the German display texts under German option ids. Translate them to value keys;
        # unknown values keep the default. The new file is written with the next start.
        $oldIds = @{
            Welt = 'World'; Inseln = 'Islands'; Inselgroesse = 'IslandSize'; Rohstoffe = 'Resources'; Ureinwohner = 'Natives'
            Haendler = 'Traders'; Gegner = 'Rivals'; GegnerGeld = 'RivalGold'; Piraten = 'Pirates'; Piratenflotte = 'PirateFleet'
            Startgeld = 'StartGold'; Einwohner = 'Residents'; Turbo = 'Turbo'; Produktion = 'Production'; Lager = 'Storage'
            Schiffstempo = 'ShipSpeed'; Laderaum = 'Cargo'
        }
        $j = Get-Content -LiteralPath $OldSettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            $id = $oldIds[$p.Name]
            if (-not $id) { continue }
            # Even older settings stored Turbo as yes/no.
            if ($id -eq 'Turbo' -and $p.Value -is [bool]) { if ($p.Value) { $saved[$id] = '8' }; continue }
            $choices = $Options[$id].Choices
            foreach ($key in $choices.Keys) { if ($choices[$key].De -ceq [string]$p.Value) { $saved[$id] = $key } }
        }
    }
}
catch { $saved = @{} }

# Complete choice (option id -> value key): the given values where valid, otherwise the defaults.
function Complete-Choice($values) {
    $choice = [ordered]@{}
    foreach ($name in $Options.Keys) {
        $o = $Options[$name]
        $choice[$name] = if ($values.ContainsKey($name) -and $o.Choices.Contains([string]$values[$name])) { [string]$values[$name] } else { $o.Default }
    }
    $choice
}

# Arguments for anno-patcher.ps1 from a complete choice.
function Get-PatcherArgs($choice) {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($name in $Options.Keys) {
        foreach ($a in $Options[$name].Choices[[string]$choice[$name]].Args) { $list.Add($a) }
    }
    , $list
}

if ($PrintArgs) {
    'default: ' + ((Get-PatcherArgs (Complete-Choice @{})) -join ' ')
    'everything-big: ' + ((Get-PatcherArgs (Complete-Choice $EverythingBig)) -join ' ')
    'campaigns: ' + ((Get-PatcherArgs (Complete-Choice $ForCampaigns)) -join ' ')
    'saved: ' + ((Get-PatcherArgs (Complete-Choice $saved)) -join ' ')
    return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace AnnoStarter -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][AnnoStarter.Dpi]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()

$font = New-Object Drawing.Font('Segoe UI', 10)
$form = New-Object Windows.Forms.Form
$form.Text = Txt 'Anno 1602 – Extensions' 'Anno 1602 – Erweiterungen'
$form.Font = $font
$form.AutoScaleMode = 'Dpi'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Padding = New-Object Windows.Forms.Padding(16)
# Icon from the game exe (folder from Ubisoft Connect, as in anno-patcher.ps1).
try {
    $gameExe = $null
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $gameExe = Join-Path (($d -replace '/', '\').TrimEnd('\')) 'Anno1602.exe'; break } } catch { }
    }
    if ($gameExe -and (Test-Path -LiteralPath $gameExe)) { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($gameExe) }
}
catch { }

$main = New-Object Windows.Forms.TableLayoutPanel
$main.AutoSize = $true
$main.ColumnCount = 1
$main.Dock = 'Fill'
$form.Controls.Add($main)

$title = New-Object Windows.Forms.Label
$title.Text = Txt 'Set up a new game' 'Neues Spiel einstellen'
$title.Font = New-Object Drawing.Font('Segoe UI Semibold', 14)
$title.AutoSize = $true
$main.Controls.Add($title)

$hint = New-Object Windows.Forms.Label
$hint.Text = Txt ('Then choose “New Game” in the game: the endless game, or at the very bottom under “Own Scenarios”' + [Environment]::NewLine + 'the campaigns “Smaragdinseln” and “Wettlauf der Häuser” and three challenges (“Herausforderung”).') `
    ('Danach im Spiel „Neues Spiel“ wählen: das Endlosspiel oder ganz unten unter „Eigene Szenarien“' + [Environment]::NewLine + 'die Kampagnen „Smaragdinseln“ und „Wettlauf der Häuser“ sowie drei Herausforderungen.')
$hint.ForeColor = [Drawing.Color]::DimGray
$hint.AutoSize = $true
$hint.Margin = New-Object Windows.Forms.Padding(3, 0, 3, 12)
$main.Controls.Add($hint)

$grid = New-Object Windows.Forms.TableLayoutPanel
$grid.AutoSize = $true
# Two columns, each with label and drop-down list, so that the window does not get too tall.
$grid.ColumnCount = 4
foreach ($i in 1..4) { [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
$main.Controls.Add($grid)

$combos = @{}
$nr = 0
foreach ($name in $Options.Keys) {
    $o = $Options[$name]
    $l = New-Object Windows.Forms.Label
    $l.Text = $o.Label
    $l.AutoSize = $true
    $l.Anchor = 'Left'
    $left = if ($nr % 2 -eq 1) { 28 } else { 3 }   # gap to the left column
    $l.Margin = New-Object Windows.Forms.Padding($left, 6, 16, 6)
    $nr++
    $c = New-Object Windows.Forms.ComboBox
    $c.Name = "choice$name"
    $c.DropDownStyle = 'DropDownList'
    $c.Width = 260
    $c.Margin = New-Object Windows.Forms.Padding(3, 3, 3, 3)
    foreach ($key in $o.Choices.Keys) { [void]$c.Items.Add($o.Choices[$key].Text) }
    $grid.Controls.Add($l)
    $grid.Controls.Add($c)
    $combos[$name] = $c
}

# Select a complete choice (option id -> value key) in the drop-down lists.
function Set-Selection($choice) {
    foreach ($name in $Options.Keys) { $combos[$name].SelectedIndex = [array]::IndexOf(@($Options[$name].Choices.Keys), [string]$choice[$name]) }
}
# Current selection as option id -> value key.
function Get-Selection {
    $choice = [ordered]@{}
    foreach ($name in $Options.Keys) { $choice[$name] = [string]@($Options[$name].Choices.Keys)[$combos[$name].SelectedIndex] }
    $choice
}
Set-Selection (Complete-Choice $saved)

$warning = New-Object Windows.Forms.Label
# Single quotes: inside double quotes PowerShell reads „ and “ as the end of the string.
$warning.Text = Txt ('Load saved games from the big world only with “Play with extensions” and' + [Environment]::NewLine + 'the same map size. Single player only.') `
    ('Spielstände aus der grossen Welt nur mit „Mit Erweiterungen spielen“ und' + [Environment]::NewLine + 'derselben Kartengrösse laden. Nur für das Einzelspiel.')
$warning.ForeColor = [Drawing.Color]::DimGray
$warning.AutoSize = $true
$warning.Margin = New-Object Windows.Forms.Padding(3, 12, 3, 12)
$main.Controls.Add($warning)

$buttons = New-Object Windows.Forms.FlowLayoutPanel
$buttons.AutoSize = $true
$buttons.FlowDirection = 'LeftToRight'
$buttons.WrapContents = $false
$main.Controls.Add($buttons)

function New-Button([string]$text) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.AutoSize = $true
    $b.Padding = New-Object Windows.Forms.Padding(10, 4, 10, 4)
    $b.Margin = New-Object Windows.Forms.Padding(3, 3, 8, 3)
    $buttons.Controls.Add($b)
    $b
}
$buttonStart = New-Button (Txt 'Play with extensions' 'Mit Erweiterungen spielen')
$buttonOriginal = New-Button (Txt 'Start original' 'Original starten')
$buttonBig = New-Button (Txt 'Everything big' 'Alles gross')
$buttonCampaigns = New-Button (Txt 'For campaigns' 'Für Kampagnen')
$buttonDefaults = New-Button (Txt 'Reset to defaults' 'Alles auf Standard')
$form.AcceptButton = $buttonStart

$buttonBig.Add_Click({ Set-Selection (Complete-Choice $EverythingBig) })
$buttonCampaigns.Add_Click({ Set-Selection (Complete-Choice $ForCampaigns) })
$buttonDefaults.Add_Click({ Set-Selection (Complete-Choice @{}) })

function Save-Choice {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $SettingsFile) | Out-Null
        Get-Selection | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
    }
    catch { }
}

$buttonOriginal.Add_Click({
        Save-Choice
        Start-Process $GameStart
        $form.Close()
    })

$buttonStart.Add_Click({
        Save-Choice
        $patcherArgs = Get-PatcherArgs (Get-Selection)
        # The patcher runs in its own window until the game has ended.
        $ps = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$Patcher`"") + $patcherArgs
        Start-Process powershell -ArgumentList $ps
        Start-Sleep -Seconds 3
        Start-Process $GameStart
        $form.Close()
    })

if ($PreviewImage) {
    $form.StartPosition = 'Manual'
    $form.Location = New-Object Drawing.Point(-10000, -10000)
    $form.ShowInTaskbar = $false
    $form.Add_Shown({
            $image = New-Object Drawing.Bitmap($form.Width, $form.Height)
            $form.DrawToBitmap($image, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
            $image.Save($PreviewImage, [Drawing.Imaging.ImageFormat]::Png)
            $form.Close()
        })
}
[void]$form.ShowDialog()
