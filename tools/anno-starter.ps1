<#
.SYNOPSIS
  Starter-Fenster für Anno 1602 History Edition mit den Erweiterungen aus weltgroesse.ps1.

.DESCRIPTION
  Zeigt alle Optionen als Auswahlfelder, merkt sich die letzte Wahl und startet dann
  weltgroesse.ps1 (in einem eigenen Fenster, das bis zum Spielende offen bleibt) und das Spiel
  über Ubisoft Connect. "Original starten" startet nur das Spiel, ohne Änderungen.
  Die Einstellungen liegen in %APPDATA%\Anno1602-Erweiterungen\einstellungen.json.
#>
param(
    # Nur zum Pruefen: Fenster unsichtbar aufbauen, als PNG speichern und beenden.
    [string]$VorschauBild
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace AnnoStarter -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][AnnoStarter.Dpi]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()

$Werkzeug = Join-Path $PSScriptRoot 'weltgroesse.ps1'
$SpielStart = 'uplay://launch/16236/0'
$EinstellungsDatei = Join-Path $env:APPDATA 'Anno1602-Erweiterungen\einstellungen.json'

# Jede Option: Beschriftung, Auswahl (Anzeige -> Argumente für weltgroesse.ps1), Standard.
$Optionen = [ordered]@{
    Welt         = @{ Text = 'Kartengrösse'; Standard = 'Sehr gross (1000 × 700)'; Werte = [ordered]@{
            'Original (500 × 350)'    = @('-Breite', '500', '-Hoehe', '350')
            'Gross (750 × 525)'       = @('-Breite', '750', '-Hoehe', '525')
            'Sehr gross (1000 × 700)' = @()
            'Riesig (2000 × 1400)'    = @('-Breite', '2000', '-Hoehe', '1400') } }
    Inseln       = @{ Text = 'Inseln'; Standard = 'Mehr Inseln (bis 50)'; Werte = [ordered]@{
            'Mehr Inseln (bis 50)'          = @()
            'Nur über die Karte verteilt'   = @('-NurStrecken')
            'Wie im Original'               = @('-OhneInselVerteilung') } }
    Inselgroesse = @{ Text = 'Inselgrösse'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal'                        = @()
            'Gross (viele grosse Inseln)'   = @('-Inselgroesse', 'Gross')
            'Riesig (fast nur die grössten)' = @('-Inselgroesse', 'Riesig') } }
    Rohstoffe    = @{ Text = 'Rohstoffe'; Standard = 'Mehr (passend zur Inselzahl)'; Werte = [ordered]@{
            'Wie in der Vorlage'            = @()
            'Mehr (passend zur Inselzahl)'  = @('-Rohstoffe', 'Mehr')
            'Viele (doppelt so viele)'      = @('-Rohstoffe', 'Viele') } }
    Ureinwohner  = @{ Text = 'Ureinwohner'; Standard = 'Wie Vorlage (2 + 2 Dörfer)'; Werte = [ordered]@{
            'Wie Vorlage (2 + 2 Dörfer)'    = @()
            'Mehr (4 + 4 Dörfer)'           = @('-Ureinwohner', 'Mehr')
            'Viele (7 + 7 Dörfer)'          = @('-Ureinwohner', 'Viele') } }
    Haendler     = @{ Text = 'Freie Händler'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal'                        = @()
            'Mehr (doppelt so viele)'       = @('-Haendler', 'Mehr')
            'Viele (dreimal, bis 24)'       = @('-Haendler', 'Viele') } }
    Gegner       = @{ Text = 'Computergegner'; Standard = 'Wie Schwierigkeit'; Werte = [ordered]@{
            'Wie Schwierigkeit'             = @()
            'Immer wie „Schwer“'            = @('-Gegner', 'Schwer') } }
    GegnerGeld   = @{ Text = 'Gold der Gegner'; Standard = 'Wie Schwierigkeit'; Werte = [ordered]@{
            'Wie Schwierigkeit' = @()
            '30 000'            = @('-GegnerGeld', '30000')
            '60 000'            = @('-GegnerGeld', '60000')
            '100 000'           = @('-GegnerGeld', '100000') } }
    Piraten      = @{ Text = 'Piraten'; Standard = 'Wie Schwierigkeit'; Werte = [ordered]@{
            'Wie Schwierigkeit'       = @()
            'Greifen immer an'        = @('-Piraten', 'Aktiv')
            'Stark (volle Kanonen)'   = @('-Piraten', 'Stark')
            'Keine Piraten'           = @('-Piraten', 'Aus') } }
    Piratenflotte = @{ Text = 'Piratenflotte'; Standard = 'Normal (bis 4 Schiffe)'; Werte = [ordered]@{
            'Normal (bis 4 Schiffe)'        = @()
            'Gross (bis 8 Schiffe)'         = @('-Piratenflotte', 'Gross')
            'Riesig (bis 12 Schiffe)'       = @('-Piratenflotte', 'Riesig') } }
    Startgeld    = @{ Text = 'Dein Startgold'; Standard = 'Wie Schwierigkeit'; Werte = [ordered]@{
            'Wie Schwierigkeit' = @()
            '30 000'            = @('-Startgeld', '30000')
            '50 000'            = @('-Startgeld', '50000')
            '100 000'           = @('-Startgeld', '100000') } }
    Einwohner    = @{ Text = 'Einwohner je Haus'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal' = @(); '× 1,5' = @('-Einwohner', '1.5'); '× 2' = @('-Einwohner', '2'); '× 3' = @('-Einwohner', '3'); '× 4' = @('-Einwohner', '4'); '× 5' = @('-Einwohner', '5') } }
    Turbo        = @{ Text = 'Turbo (Taste F7)'; Standard = 'Aus (4-fach)'; Werte = [ordered]@{
            'Aus (4-fach)' = @(); '8-fach' = @('-Turbo'); '12-fach' = @('-Turbo', '-TurboStufe', '12'); '16-fach' = @('-Turbo', '-TurboStufe', '16') } }
    Produktion   = @{ Text = 'Produktionstempo'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal' = @(); '× 1,5' = @('-Produktion', '1.5'); '× 2' = @('-Produktion', '2'); '× 3' = @('-Produktion', '3') } }
    Lager        = @{ Text = 'Lager je Ware'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal' = @(); '× 2' = @('-Lager', '2'); '× 3' = @('-Lager', '3'); '× 5' = @('-Lager', '5') } }
    Schiffstempo = @{ Text = 'Schiffstempo'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal' = @(); '× 1,5' = @('-Schiffstempo', '1.5'); '× 2' = @('-Schiffstempo', '2'); '× 3' = @('-Schiffstempo', '3') } }
    Laderaum     = @{ Text = 'Laderaum der Schiffe'; Standard = 'Normal'; Werte = [ordered]@{
            'Normal' = @(); '× 1,5' = @('-Laderaum', '1.5'); '× 2' = @('-Laderaum', '2'); '× 3' = @('-Laderaum', '3') } }
}

# Letzte Wahl laden (fehlt die Datei oder ist sie kaputt: Standardwerte).
$gespeichert = @{}
try {
    if (Test-Path -LiteralPath $EinstellungsDatei) {
        $j = Get-Content -LiteralPath $EinstellungsDatei -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) { $gespeichert[$p.Name] = $p.Value }
    }
}
catch { $gespeichert = @{} }

$schrift = New-Object Drawing.Font('Segoe UI', 10)
$form = New-Object Windows.Forms.Form
$form.Text = 'Anno 1602 – Erweiterungen'
$form.Font = $schrift
$form.AutoScaleMode = 'Dpi'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Padding = New-Object Windows.Forms.Padding(16)
# Symbol aus der Spiel-exe (Ordner wie in weltgroesse.ps1 aus Ubisoft Connect).
try {
    $spielExe = $null
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
        try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $spielExe = Join-Path (($d -replace '/', '\').TrimEnd('\')) 'Anno1602.exe'; break } } catch { }
    }
    if ($spielExe -and (Test-Path -LiteralPath $spielExe)) { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($spielExe) }
}
catch { }

$haupt = New-Object Windows.Forms.TableLayoutPanel
$haupt.AutoSize = $true
$haupt.ColumnCount = 1
$haupt.Dock = 'Fill'
$form.Controls.Add($haupt)

$titel = New-Object Windows.Forms.Label
$titel.Text = 'Neues Spiel einstellen'
$titel.Font = New-Object Drawing.Font('Segoe UI Semibold', 14)
$titel.AutoSize = $true
$haupt.Controls.Add($titel)

$hinweis = New-Object Windows.Forms.Label
$hinweis.Text = 'Danach im Spiel „Neues Spiel“ wählen: das Endlosspiel oder ganz unten unter „Eigene Szenarien“' + [Environment]::NewLine + 'die Kampagnen „Smaragdinseln“ und „Wettlauf der Häuser“ sowie drei Herausforderungen.'
$hinweis.ForeColor = [Drawing.Color]::DimGray
$hinweis.AutoSize = $true
$hinweis.Margin = New-Object Windows.Forms.Padding(3, 0, 3, 12)
$haupt.Controls.Add($hinweis)

$raster = New-Object Windows.Forms.TableLayoutPanel
$raster.AutoSize = $true
# Zwei Spalten mit je Beschriftung und Auswahl, damit das Fenster nicht zu hoch wird.
$raster.ColumnCount = 4
foreach ($i in 1..4) { [void]$raster.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize'))) }
$haupt.Controls.Add($raster)

$auswahl = @{}
$nr = 0
foreach ($name in $Optionen.Keys) {
    $o = $Optionen[$name]
    $l = New-Object Windows.Forms.Label
    $l.Text = $o.Text
    $l.AutoSize = $true
    $l.Anchor = 'Left'
    $links = if ($nr % 2 -eq 1) { 28 } else { 3 }   # Abstand zur linken Spalte
    $l.Margin = New-Object Windows.Forms.Padding($links, 6, 16, 6)
    $nr++
    $c = New-Object Windows.Forms.ComboBox
    $c.Name = "auswahl$name"
    $c.DropDownStyle = 'DropDownList'
    $c.Width = 260
    $c.Margin = New-Object Windows.Forms.Padding(3, 3, 3, 3)
    foreach ($w in $o.Werte.Keys) { [void]$c.Items.Add($w) }
    $wahl = if ($gespeichert.ContainsKey($name) -and $o.Werte.Contains([string]$gespeichert[$name])) { [string]$gespeichert[$name] } else { $o.Standard }
    $c.SelectedItem = $wahl
    $raster.Controls.Add($l)
    $raster.Controls.Add($c)
    $auswahl[$name] = $c
}

# Aeltere Einstellungen speicherten Turbo als Ja/Nein.
if ($gespeichert['Turbo'] -is [bool] -and $gespeichert['Turbo']) { $auswahl['Turbo'].SelectedItem = '8-fach' }

$warnung = New-Object Windows.Forms.Label
# Einfache Anführungszeichen: PowerShell liest „ und “ in doppelten Anführungszeichen als Stringende.
$warnung.Text = 'Spielstände aus der grossen Welt nur mit „Mit Erweiterungen spielen“ und' + [Environment]::NewLine + 'derselben Kartengrösse laden. Nur für das Einzelspiel.'
$warnung.ForeColor = [Drawing.Color]::DimGray
$warnung.AutoSize = $true
$warnung.Margin = New-Object Windows.Forms.Padding(3, 12, 3, 12)
$haupt.Controls.Add($warnung)

$knoepfe = New-Object Windows.Forms.FlowLayoutPanel
$knoepfe.AutoSize = $true
$knoepfe.FlowDirection = 'LeftToRight'
$knoepfe.WrapContents = $false
$haupt.Controls.Add($knoepfe)

function Neuer-Knopf([string]$text) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.AutoSize = $true
    $b.Padding = New-Object Windows.Forms.Padding(10, 4, 10, 4)
    $b.Margin = New-Object Windows.Forms.Padding(3, 3, 8, 3)
    $knoepfe.Controls.Add($b)
    $b
}
$knopfStart = Neuer-Knopf 'Mit Erweiterungen spielen'
$knopfOriginal = Neuer-Knopf 'Original starten'
$knopfGross = Neuer-Knopf 'Alles gross'
$knopfKampagne = Neuer-Knopf 'Für Kampagnen'
$knopfStandard = Neuer-Knopf 'Alles auf Standard'
$form.AcceptButton = $knopfStart

# "Alles gross": grosse Welt mit riesigen Inseln, vielen Rohstoffen, grossen Staedten und schnellem Spiel.
# 1000 x 700 statt 2000 x 1400, weil das Spiel hoechstens 50 Inseln kennt; auf 2000 x 1400 waere fast alles Meer.
# Dazu mehr Leben und mehr Gegner: Ureinwohner und Haendler "Viele", KI immer "Schwer", Piraten greifen an
# und halten eine doppelt so grosse Flotte.
$AllesGross = @{
    Welt = 'Sehr gross (1000 × 700)'; Inseln = 'Mehr Inseln (bis 50)'; Inselgroesse = 'Riesig (fast nur die grössten)'
    Rohstoffe = 'Viele (doppelt so viele)'; Ureinwohner = 'Viele (7 + 7 Dörfer)'; Haendler = 'Viele (dreimal, bis 24)'
    Gegner = 'Immer wie „Schwer“'; GegnerGeld = '60 000'; Piraten = 'Greifen immer an'; Piratenflotte = 'Gross (bis 8 Schiffe)'
    Startgeld = '50 000'; Einwohner = '× 5'; Turbo = '16-fach'; Produktion = '× 2'; Lager = '× 5'; Schiffstempo = '× 2'; Laderaum = '× 3'
}
$knopfGross.Add_Click({
        foreach ($name in $Optionen.Keys) { if ($AllesGross.ContainsKey($name)) { $auswahl[$name].SelectedItem = $AllesGross[$name] } }
    })

# "Für Kampagnen": grosse Fassung der Kampagnenkarten (ab 1000 x 700 mit "Mehr Inseln"), Gold wie im
# Szenario vorgesehen (die Gold-Optionen würden es ersetzen), Turbo; Wirtschaft und Gegner wie im Original,
# damit die Aufträge so schwer sind wie geplant.
$FuerKampagnen = @{
    Welt = 'Sehr gross (1000 × 700)'; Inseln = 'Mehr Inseln (bis 50)'; GegnerGeld = 'Wie Schwierigkeit'; Startgeld = 'Wie Schwierigkeit'
    Turbo = '16-fach'
}
$knopfKampagne.Add_Click({
        foreach ($name in $Optionen.Keys) { $auswahl[$name].SelectedItem = $(if ($FuerKampagnen.ContainsKey($name)) { $FuerKampagnen[$name] } else { $Optionen[$name].Standard }) }
    })

function Speichere-Wahl {
    $daten = [ordered]@{}
    foreach ($name in $Optionen.Keys) { $daten[$name] = [string]$auswahl[$name].SelectedItem }
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $EinstellungsDatei) | Out-Null
        $daten | ConvertTo-Json | Set-Content -LiteralPath $EinstellungsDatei -Encoding UTF8
    }
    catch { }
}

$knopfStandard.Add_Click({
        foreach ($name in $Optionen.Keys) { $auswahl[$name].SelectedItem = $Optionen[$name].Standard }
    })

$knopfOriginal.Add_Click({
        Speichere-Wahl
        Start-Process $SpielStart
        $form.Close()
    })

$knopfStart.Add_Click({
        Speichere-Wahl
        $argumente = New-Object System.Collections.Generic.List[string]
        foreach ($name in $Optionen.Keys) {
            foreach ($a in $Optionen[$name].Werte[[string]$auswahl[$name].SelectedItem]) { $argumente.Add($a) }
        }
        # Das Werkzeug läuft in einem eigenen Fenster, bis das Spiel beendet ist.
        $ps = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$Werkzeug`"") + $argumente
        Start-Process powershell -ArgumentList $ps
        Start-Sleep -Seconds 3
        Start-Process $SpielStart
        $form.Close()
    })

if ($VorschauBild) {
    $form.StartPosition = 'Manual'
    $form.Location = New-Object Drawing.Point(-10000, -10000)
    $form.ShowInTaskbar = $false
    $form.Add_Shown({
            $bild = New-Object Drawing.Bitmap($form.Width, $form.Height)
            $form.DrawToBitmap($bild, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
            $bild.Save($VorschauBild, [Drawing.Imaging.ImageFormat]::Png)
            $form.Close()
        })
}
[void]$form.ShowDialog()
