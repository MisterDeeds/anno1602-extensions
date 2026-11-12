<#
.SYNOPSIS
  Baut eigene Szenarien (.szs) fuer Anno 1602 History Edition aus einer Endlos-Vorlage.

.DESCRIPTION
  Wird per Punkt-Aufruf geladen (. .\szenario-bauer.ps1) und stellt Funktionen bereit:
    Lies-Szenario <Pfad>                 -> Liste von @{ Name; Daten } in Dateireihenfolge
    Schreibe-Szenario <Pfad> <Liste>     -> Datei schreiben (Abschnitt = 16 Byte Name, int32 Laenge, Daten)
    Neuer-Auftrag @{...}                 -> 0x8C4 Byte (AUFTRAG4-Eintrag)
    Setze-Inseln <SZENE> <Liste>         -> Inselliste (bis 50 Eintraege a 16 Byte ab +0x174)
  Die Vorlage wird nur gelesen. Herleitung der Felder: analysis\BEFUNDE.md, Abschnitt
  "Eigene Szenarien".

  AUFTRAG4-Eintrag (0x8C4 Byte; Lader FUN_1400b1780, Pruefung FUN_1400ae010):
    +0x000 int   Platz in der Auftragstabelle (Spieler verweisen per PLAYER4 +0x0C darauf)
    +0x004 int   Zielbits: 1/2/4 Stadt 1-3 (setzt der Lader selbst), 8 alle Staedte mindestens,
                 0x10 Spieler unterstuetzen, 0x20 Zahl der Staedte, 0x80 Einwohner gesamt,
                 0x100 Bilanz, 0x200 Gegner besiegt (Zahl), 0x400 bestimmte Spieler besiegen,
                 0x800 auch fuer KI, 0x1000/0x2000 Warenbestand, 0x4000/0x8000 Rohstoff-Monopol
    +0x020 byte Rohstoff 1, +0x021 byte Zahl Inseln (vom Spiel beim Start ueberschrieben: alle Inseln mit dem Rohstoff); +0x022/+0x023 Rohstoff 2
    +0x024 byte zu unterstuetzender Spieler (7 = beliebig)
    +0x02B byte Zahl besiegter Gegner, +0x02C..+0x032 je Spieler 1 = muss besiegt werden
    +0x040 int Zahl der Staedte, +0x044 int Einwohner gesamt, +0x04C int Bilanz (Taler, wie im Statusfenster:
               Steuern + Verkaeufe - Einkaeufe - Betriebs- und Heereskosten, FUN_1400ad5d0)
    +0x054 int Handelsbilanz (Verkaeufe - Einkaeufe, Zielbit 0x10000)
    +0x050 int Sprachmeldung/Film bei Erfolg (Original 84-106)
    +0x068 Text (0x800 Byte, Windows-1252)
    +0x868/+0x86C Ware: Byte 0 Ware, Bytes 2-3 Menge (x 32 = Tonnen)
    +0x870/+0x87C/+0x888 Stadt 1-3: Einwohner gesamt, Stufe (0 Pioniere ... 4 Aristokraten), davon mindestens
    +0x8AC alle Staedte mindestens (Bit 8), +0x8B8 Stadt des unterstuetzten Spielers (Bit 0x10)
#>

$Cp1252 = [Text.Encoding]::GetEncoding(1252)

function Lies-Szenario([string]$pfad) {
    $d = [IO.File]::ReadAllBytes($pfad); $o = 0
    $liste = New-Object System.Collections.Generic.List[object]
    while ($o -le $d.Length - 20) {
        $name = [Text.Encoding]::ASCII.GetString($d, $o, 16).Split([char]0)[0]
        $len = [BitConverter]::ToInt32($d, $o + 16)
        if ($len -lt 0 -or $o + 20 + $len -gt $d.Length) { throw "Abschnitt $name bei $o kaputt." }
        $daten = New-Object byte[] $len
        if ($len -gt 0) { [Array]::Copy($d, $o + 20, $daten, 0, $len) }
        $liste.Add(@{ Name = $name; Daten = $daten })
        $o += 20 + $len
    }
    , $liste
}

function Schreibe-Szenario([string]$pfad, $liste) {
    $ms = New-Object IO.MemoryStream
    foreach ($a in $liste) {
        $kopf = New-Object byte[] 20
        $n = [Text.Encoding]::ASCII.GetBytes($a.Name)
        if ($n.Length -gt 15) { throw "Abschnittsname zu lang: $($a.Name)" }
        [Array]::Copy($n, $kopf, $n.Length)
        [Array]::Copy([BitConverter]::GetBytes([int32]$a.Daten.Length), 0, $kopf, 16, 4)
        $ms.Write($kopf, 0, 20); $ms.Write($a.Daten, 0, $a.Daten.Length)
    }
    [IO.File]::WriteAllBytes($pfad, $ms.ToArray())
}

function Abschnitt($liste, [string]$name) { foreach ($a in $liste) { if ($a.Name -eq $name) { return $a } }; $null }

function Setze-I32([byte[]]$b, [int]$o, [long]$v) { [Array]::Copy([BitConverter]::GetBytes([int32]$v), 0, $b, $o, 4) }
function Setze-U16([byte[]]$b, [int]$o, [int]$v) { [Array]::Copy([BitConverter]::GetBytes([uint16]$v), 0, $b, $o, 2) }

# Stadtziel: @{ Einwohner = 500; Stufe = 3; Davon = 300 }  (Stufe 0 Pioniere ... 4 Aristokraten)
function Setze-Stadtziel([byte[]]$r, [int]$o, $z) {
    if (-not $z) { return }
    Setze-I32 $r $o $z.Einwohner; Setze-I32 $r ($o + 4) $z.Stufe; Setze-I32 $r ($o + 8) $z.Davon
}

# Neuer AUFTRAG4-Eintrag. Schluessel (alle optional):
#   Platz, Text, Erfolg, Staedte (Liste von Stadtzielen, max. 3), AlleStaedte (Stadtziel),
#   AnzahlStaedte, EinwohnerGesamt, Bilanz, Handelsbilanz, Besiegen (Liste von Spielernummern), BesiegtZahl,
#   Ware1/Ware2 = @{ Ware = Nr; Tonnen = t }, Monopol1/Monopol2 = @{ Rohstoff = Nr; Inseln = n },
#   Unterstuetzen = @{ Spieler = Nr (7 = beliebig); Stadt = Stadtziel }, AuchKI
function Neuer-Auftrag($a) {
    $r = New-Object byte[] 0x8C4
    $bits = 0
    Setze-I32 $r 0 ([int]$a.Platz)
    $st = @($a.Staedte | Where-Object { $_ })
    if ($st.Count -gt 3) { throw 'Hoechstens 3 Stadtziele.' }
    for ($i = 0; $i -lt $st.Count; $i++) { Setze-Stadtziel $r (0x870 + 12 * $i) $st[$i]; $bits = $bits -bor (1 -shl $i) }
    if ($a.AlleStaedte) { Setze-Stadtziel $r 0x8AC $a.AlleStaedte; $bits = $bits -bor 0x8 }
    if ($a.Unterstuetzen) { $r[0x24] = [byte]$a.Unterstuetzen.Spieler; Setze-Stadtziel $r 0x8B8 $a.Unterstuetzen.Stadt; $bits = $bits -bor 0x10 } else { $r[0x24] = 7 }
    if ($a.AnzahlStaedte) { Setze-I32 $r 0x40 $a.AnzahlStaedte; $bits = $bits -bor 0x20 }
    if ($a.EinwohnerGesamt) { Setze-I32 $r 0x44 $a.EinwohnerGesamt; $bits = $bits -bor 0x80 }
    if ($a.ContainsKey('Bilanz')) { Setze-I32 $r 0x4C $a.Bilanz; $bits = $bits -bor 0x100 }
    if ($a.ContainsKey('Handelsbilanz')) { Setze-I32 $r 0x54 $a.Handelsbilanz; $bits = $bits -bor 0x10000 }
    if ($a.BesiegtZahl) { $r[0x2B] = [byte]$a.BesiegtZahl; $bits = $bits -bor 0x200 }
    if ($a.Besiegen) { foreach ($s in $a.Besiegen) { $r[0x2C + $s] = 1 }; $bits = $bits -bor 0x400 }
    if ($a.AuchKI) { $bits = $bits -bor 0x800 }
    foreach ($k in 1, 2) {
        $w = $a["Ware$k"]; if ($w) { $o = 0x868 + 4 * ($k - 1); $r[$o] = [byte]$w.Ware; Setze-U16 $r ($o + 2) ([int]($w.Tonnen * 32)); $bits = $bits -bor (0x1000 -shl ($k - 1)) }
        $m = $a["Monopol$k"]; if ($m) { $o = 0x20 + 2 * ($k - 1); $r[$o] = [byte]$m.Rohstoff; $r[$o + 1] = [byte]$m.Inseln; $bits = $bits -bor (0x4000 -shl ($k - 1)) }
    }
    Setze-I32 $r 4 $bits
    Setze-I32 $r 0x50 $(if ($a.Erfolg) { $a.Erfolg } else { 85 })
    if ($a.Text) {
        $t = $Cp1252.GetBytes(($a.Text -replace "`r", ''))
        if ($t.Length -gt 0x7FF) { throw "Auftragstext zu lang ($($t.Length) Byte, hoechstens 2047)." }
        [Array]::Copy($t, 0, $r, 0x68, $t.Length)
    }
    , $r
}

# Inseln: Liste von @{ Klima = 0 Nord/1 Sued/2 nach Lage; Klasse = 0 lit .. 4 lar; X; Y; Datei = Nr oder $null (zufaellig); Dorf = $true/$false }
function Setze-Inseln([byte[]]$szene, $inseln) {
    if ($inseln.Count -gt 50) { throw 'Hoechstens 50 Inseln.' }
    [Array]::Clear($szene, 0x174, 50 * 16)
    for ($i = 0; $i -lt $inseln.Count; $i++) {
        $e = $inseln[$i]; $o = 0x174 + 16 * $i
        $szene[$o] = [byte]$e.Klima; $szene[$o + 1] = [byte]$e.Klasse; $szene[$o + 2] = [byte]$(if ($e.Dorf) { 1 } else { 0 }); $szene[$o + 3] = [byte]$i
        Setze-U16 $szene ($o + 4) $(if ($null -ne $e.Datei) { $e.Datei } else { 0xFFFF })
        Setze-I32 $szene ($o + 8) $e.X; Setze-I32 $szene ($o + 12) $e.Y
    }
    Setze-I32 $szene 0x64 $inseln.Count
}
