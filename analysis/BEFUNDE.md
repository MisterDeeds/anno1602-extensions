# Anno 1602 History Edition – Befunde

Ziel: grössere Welten, mehr Gegner, mehr Möglichkeiten.
Ziel-Datei: `Anno1602.exe` aus
`C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition`.

Legende: **B** = beobachtet (direkt gemessen), **F** = gefolgert, **?** = offen.

## Werkzeuge

| Werkzeug | Version | Ort |
|---|---|---|
| Ghidra | 12.1.4 (von REA verifizierte Version) | `%LOCALAPPDATA%\Programs\Ghidra\ghidra_12.1.4_PUBLIC` |
| JDK | Temurin 21.0.13 | `C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot` |
| Node.js | 26.13.0 | winget |
| REA | 6.8.0 | `npm -g rea-agents`, MCP in `~/.claude.json` registriert |
| Git | 2.56.0 | winget |

`.cod`-Dateien ent-/verschlüsseln: `tools/cod.ps1` (jedes Byte negiert).
Kartengrösse: `tools/weltgroesse.ps1`, Start mit Spiel `tools/anno-grosse-welt.cmd`, Offline-Test `tools/test-weltgroesse.ps1`, Inselplan als Bild `tools/inselplan-zeigen.ps1`, Kurzanleitung `LIESMICH.md`.
Ghidra-Hilfsskripte: `AnnoAsm.java` (Befehle ab Adresse), `AnnoPatchDis.java` (Bytes nur in Ghidras Arbeitsspeicher einsetzen und zurückübersetzen).
Hinweis: `tools/ghidra-scan.cmd` braucht `GHIDRA_INSTALL_DIR` und `JAVA_HOME` im Prozess. Wurde die Shell vor dem Setzen der Variablen gestartet, fehlen sie („Das System kann den angegebenen Pfad nicht finden“); dann vorher aus den Benutzer- bzw. System-Variablen übernehmen.

## Aufbau der exe

- **B** x64-PE, gebaut 2020-08-05 mit MSVC-Linker 14.16 (Visual Studio 2017), File-/Product-Version 1.0.0.0, signiert von Ubisoft Blue Byte GmbH.
- **B** Nicht gepackt: normale Sektionen `.text` (934 KB Code), `.rdata`, `.data`, `.pdata`, `.rsrc`, `.reloc`.
- **B** `.pdata` hat 29'100 Bytes → rund 2'400 Funktionseinträge (Anfang/Ende jeder Funktion bekannt).
- **B** `.data`: 8,5 MB im Speicher, aber nur 14 KB in der Datei → rund 8,5 MB fest reservierte, beim Start leere Datenbereiche.
- **F** Darin liegen die Spielwelt-Tabellen mit fester Grösse (typisch für den Code von 1998). Eine grössere Welt heisst: diese Bereiche verschieben und jede Stelle anpassen, die darauf zugreift.
- **B** Grafik über Direct3D 11 (`d3d11.dll`, `dxgi.dll`), Videos über Bink 2.
- **B** Ubisoft Connect (`uplay_r1_loader64.dll`) wird nur von `MaxNet.dll` importiert, nicht von `Anno1602.exe`. Mehrspieler, Online-Overlay und Tracking laufen über die 35 `Maxnet*`-Funktionen.
- **B** Einstellungen in der Registry unter `HKCU\Software\Ubisoft\Anno1602HistoryEdition` (u. a. `UI_SCALE`, `WINDOW_MODE`, `NEW_UNIT_CONTROLS`, `RIGHT_CLICK_SCROLLING`).
- **B** Startoption `-nointro`.

## Daten und Formate

- **B** Spielstand-Chunks wie im Original: `INSEL3/4/5`, `INSELHAUS`, `KONTOR/KONTOR2`, `SHIP4`, `SHIPS`, `PLAYER2/3/4`, `SZENE*`, `TIMERS`, `AUFTRAG*`, `HANDLER`, `SOLDAT1-4` usw.
- **B** Gebäude, Figuren und Texte stehen in `haeuser.cod`, `figuren.cod`, `Editor.cod`, `text.cod` (bzw. `Loca\de-DE\…`).
- **B** Der `.cod`-Parser kennt diese Schlüsselwörter (Auszug): `Maxlager`, `Maxprodcnt`, `Maxwohn`, `Interval`, `Radius`, `Rohmenge`, `Arbeiter`, `Kosten`, `Steuer`, `Maxtrag`, `Maxkanon`, `Maxware`, `Maxenergy`, `Hitpoint`, `Speed`, `Shotradius`, `Preis`, `MAXHAUS`, `MAXFIGUR`.
- **B** Die Warennamen sind als feste Liste in der exe: `EISENERZ, GOLD, WOLLE, ZUCKER, TABAK, FLEISCH, KORN, MEHL, EISEN, SCHWERTER, MUSKETEN, KANONEN, NAHRUNG, TABAKWAREN, GEWUERZE, KAKAO, ALKOHOL, STOFFE, KLEIDUNG, SCHMUCK, WERKZEUG, HOLZ, ZIEGEL`.
- **F** Neue Waren brauchen Änderungen in der exe; neue Werte für bestehende Waren und Gebäude gehen über `.cod`.
- **B** Gebäudearten sind ebenfalls feste Schlüsselwörter (`HANDWERK`, `PLANTAGE`, `BERGWERK`, `WOHNUNG`, `KONTOR`, `MARKT`, …).

## Ghidra-Analyse

Ghidra 12.1.4 über REA (`rea analyze`, Evidence `ev_390cb815…`) und eigene Headless-Skripte
(`tools/ghidra-scan.cmd`, Skripte in `tools/ghidra_scripts/`, Ergebnisse in `analysis/scan/`).
Analysiert wird die Kopie `analysis/bin/Anno1602.exe`, SHA-256 `7731972f…b7a1` (identisch mit dem Original).

- **B** 1'546 Funktionen, 1'278 Texte. Ein PDB `anno1602.pdb` wird referenziert, liegt aber nicht bei → keine Originalnamen.

## Kartengrösse 500 × 350

- **B** Breite und Höhe stehen in zwei globalen Variablen: `DAT_1405ebe40` (Breite) und `DAT_1405ebe98` (Höhe).
- **B** Drei weitere Variablen hängen an der Grösse und werden an denselben zwei Orten gesetzt (gefunden am 2026-11-08, siehe unten):
  `DAT_1405eb840` = Scrollbereich = Breite/2 + Höhe/2 (425), `DAT_1405ebc7c` = 1/Breite (float 0.002), `DAT_1405ebc80` = 1/Höhe (float 1/350).
- **B** Alle Setz-Stellen (je 10 Byte `C7 05 <rel32> <imm32>`, der Wert steht ab Byte 6; Datei-Offset = RVA − 0xC00):

  | VA | Original-Bytes | Befehl | Funktion |
  |---|---|---|---|
  | `0x1400DC7E5` | `C7 05 51 F6 50 00 F4 01 00 00` | Breite = 500 | `FUN_1400dbc60` (Programmstart) |
  | `0x1400DC7EF` | `C7 05 9F F6 50 00 5E 01 00 00` | Höhe = 350 | `FUN_1400dbc60` |
  | `0x1400DC7F9` | `C7 05 3D F0 50 00 A9 01 00 00` | Scrollbereich = 425 | `FUN_1400dbc60` |
  | `0x14008DC90` | `C7 05 A6 E1 55 00 F4 01 00 00` | Breite = 500 | `FUN_14008cef0` Befehl `0x36` (neues Spiel) |
  | `0x14008DC9A` | `C7 05 F4 E1 55 00 5E 01 00 00` | Höhe = 350 | `FUN_14008cef0` |
  | `0x14008DCA4` | `C7 05 92 DB 55 00 A9 01 00 00` | Scrollbereich = 425 | `FUN_14008cef0` |
  | `0x14008DCAE` | `C7 05 C4 DF 55 00 6F 12 03 3B` | 1/Breite = 0.002f | `FUN_14008cef0` |
  | `0x14008DCB8` | `C7 05 BE DF 55 00 E7 3E 3B 3B` | 1/Höhe = 1/350f | `FUN_14008cef0` |

- **B** Beim Programmstart setzt `FUN_1400dbc60` 1/Breite und 1/Höhe nicht als Sofortwert, sondern per `MOVSS` aus `.rdata` `0x1400EB8F4`/`0x1400EB8F8` (bei `0x1400DC7D5` bzw. `0x1400DC80A`). `0x1400DC812` (1/Höhe) ist die letzte der fünf Zuweisungen. Diese beiden `.rdata`-Konstanten nutzt sonst kein Code (RIP-relative Suche über ganz `.text`).
- **B** Gelesen werden Breite/Höhe von 22 Funktionen: Grenzprüfungen (`0 <= x < Breite`), Kamera/Minikarte, Zufallsplatzierung (`FUN_140077210` mit `rand()`), sowie zwei Raster, die per `VirtualAlloc` passend zur Grösse angelegt werden (`FUN_14009ce30`: Raster aus 16×16-Feld-Blöcken, max. 50 Inseln; `FUN_140043690`: nur ein Zwischenpuffer zum Zeichnen der Minikarte, wird gleich wieder freigegeben).
- **B** `FUN_14009ce30` wird u. a. von Befehl `0x36` (über `FUN_14009b400`) und vom Laden (`FUN_1400d0de0`) aufgerufen, das Raster wird also bei jedem neuen Spiel und jedem Laden neu angelegt.
- **B** Rohzählung im Maschinencode: der Wert 500 steht 124-mal im Code, aber die meisten sind andere Grenzen (z. B. max. 500 Bedienelemente in `FUN_14000d3b0`). Die Werte 700/350 in `FUN_1400bc030` sind Schwellen der Spiellogik (Zufallsereignisse), keine Kartengrösse. `500.0f` (`0x1400EBA80`) ist nur die Knoten-Anzeige der Schiffe (`FUN_14004ffc0`).
- **F** Die Weltgrösse ist im Remaster weitgehend als Variable umgesetzt. Ein Test mit grösseren Werten ist realistisch.

### Kamera und Scrollleisten (Analyse 2026-11-08)

- **B** Die Kamera (`PTR_DAT_1400f9a00`) hat zwei Koordinatensätze: Feld `+0x1c/+0x20` (Weltposition x/y) und `+0x24/+0x28` (gedrehte Scroll-Koordinaten), Drehung in `+0x48` (0–3). `FUN_1400c4ba0` (Welt → Scroll) und `FUN_1400c4ca0` (Scroll → Welt) rechnen mit Breite/2 und Höhe/2, z. B. bei Drehung 0: `s = H/2 − (y−x)/2`, `t = (x+y)/2`.
- **F** Daraus folgt: beide Scroll-Koordinaten laufen von 0 bis Breite/2 + Höhe/2. Das ist genau `DAT_1405eb840` (500/2 + 350/2 = 425).
- **B** Rand-Scrollen (`FUN_1400dd190`) und Pfeiltasten (`FUN_1400e2d60`, Fälle `0x27/0x28`) begrenzen die Scroll-Koordinaten auf `DAT_1405eb840` (`CMP`/`CMOVG` bei `0x1400DD2E4`, `0x1400DD419`, `0x1400E2E7F`, `0x1400E2F93`). `FUN_1400c4dc0` (Scrollleisten-Befehle) ebenso.
- **F** Mit der ersten Fassung des Werkzeugs (nur Breite/Höhe) wäre die Kamera bei 1000 × 700 auf `x + y ≤ 850` beschränkt gewesen, also etwa auf den alten Bereich plus Rand. Ein Klick in die Minikarte hätte weiter springen können, aber das nächste Rand-Scrollen hätte die Kamera zurückgesetzt. **Das war ein Fehler im Werkzeug; behoben.**
- **B** Die 21 `IMUL …, 0x1f4` rechnen `Scroll-Koordinate × 500 / DAT_1405eb840`. Die 500 ist die Auflösung der Scrollleiste (0–500), nicht die Kartenbreite. Eine Umrechnung in die Gegenrichtung mit `DAT_1405eb840` gibt es nicht (alle Lesezugriffe geprüft).
- **F** Die festen 500er-Multiplikationen müssen nicht gepatcht werden. Mit Scrollbereich 850 bewegt sich die Leiste weiter proportional, nur etwas gröber.
- **B** `DAT_1405ebc7c`/`DAT_1405ebc80` (1/Breite, 1/Höhe) werden nur in `FUN_14008ba70` und `FUN_14008bc50` gelesen (aufgerufen aus `FUN_14005ff70`, der Minikarte): Weltposition × 1/Breite × Kartenbreite in Pixeln → Markierungspunkt auf der Minikarte (Tabelle mit 200 Einträgen ab `0x1401d8bb8`).
- **F** Ohne Anpassung lägen diese Markierungen bei 1000 × 700 doppelt so weit vom Ursprung (ab der Kartenmitte ausserhalb der Minikarte). **Ebenfalls im Werkzeug ergänzt.**
- **B** Grosse feste Datenbereiche sind Pools mit fester Kapazität, nicht nach Koordinaten angeordnet. Beispiel: Rohstoff-Wachstum (`ROHWACHS2`) 262'512 Einträge × 8 Byte ab `0x14034d530` (`FUN_1400c42d0`); 750 Einträge × 2'224 Byte ab `0x14077b744` (`FUN_140002c00`).
- **F** Bei einer viel grösseren Welt mit mehr Inseln können diese Pools voll laufen.
- **B** `FUN_14008cef0` ist der Befehlsverarbeiter des Spiels (113 Aufrufer). Befehl `0x36` setzt die Welt zurück („neues Spiel“): Er ruft u. a. `FUN_14009b400` (legt das 16×16-Raster über `FUN_14009ce30` neu an) und `FUN_1400a87f0` (Spielertabelle) auf. Danach setzt er Breite = 500, Höhe = 350 und `DAT_1405eb840` = 425.
- **B** Ausser diesen 4 Stellen schreibt nichts in Breite/Höhe, auch nicht das Laden eines Spielstands (`FUN_1400d0de0` liest nur).
- **F** Ein Spielstand speichert die Weltgrösse nicht. Spielstände aus einer grösseren Welt nur mit derselben Einstellung laden.
- ~~`DAT_1405eb840` = 425 ist der Bereich der Scrollleisten … Rand-Scrollen und Minikarte lesen die Variablen.~~ Korrigiert, siehe „Kamera und Scrollleisten“: `DAT_1405eb840` ist der Kamerabereich, und Rand-Scrollen sowie Pfeiltasten werden darauf begrenzt.

### Inseln im Endlosspiel (Analyse 2026-11-08, nach dem Spieltest)

- **B** Im Spiel mit 1000 × 700 liegen alle Inseln im alten Bereich oben links (`analysis/test/02-minikarte-start.png`).
- **B** Die Endlosspiel-Vorlagen sind `Szenes\[[48]]00.szs` … `[[48]]32.szs` (12 Dateien à 14'540 Byte; vermutlich 4 Schwierigkeitsgrade × 3 Varianten). Sie enthalten keine `INSEL`-Abschnitte, nur `SZENE_*`, `RANDTAB` (1'024 Byte Zufallszahlen), `AUFTRAG4`, `SZENE`, `PLAYER4`, `SHIP4`, `TIMERS`.
- **B** Im Abschnitt `SZENE` (1'172 Byte) steht bei +0x64 die Inselzahl, ab +0x174 bis zu 50 Einträge à 16 Byte: Klima (0 Nord, 1 Süd, 2 nach Lage), Grössenklasse (Index in `lit/mit/med/big/lar`, Tabelle `0x1400EA200`), Flags (Bit 0: Eingeborene), Platz, Dateinummer (`0xFFFF` = zufällig), x (int32 bei +8), y (int32 bei +0xC).
- **B** `[[48]]10.szs` hat 18 Inseln, x 50–440, y 20–280: alle Positionen sind fest und liegen im Bereich 500 × 350. Zufällig ist nur, welche Inseldatei der Grössenklasse geladen wird (`"%s%s%s%02d.SCP"` in `FUN_1400d0de0`).
- **B** Der `SZENE`-Lader `FUN_1400d0de0` setzt bei Klima 2 das Klima nach der Inselmitte: oberes Drittel der Höhe Nord, unteres Drittel Süd, dazwischen zufällig (über `DAT_1405c4940`). Er rechnet dabei mit der Variablen Höhe.
- **F** Mit Höhe 700 liegen die Grenzen bei 233 und 466 statt bei 116 und 233. Inseln der Vorlage mit Klima 2 im Band y ≈ 250–280 werden damit nicht mehr sicher Süd, sondern zufällig. Die vier fest als Süd markierten Inseln bleiben Süd. Folge: im Mittel etwas weniger Südinseln als im Original.
- **B** `FUN_140068650` (Insel an Mausposition setzen, Editor) und `FUN_140077210` (Zufallspunkt ±90 Felder um eine Position, Koordinaten 12 Bit gepackt) halten sich an die Variablen.
- **F** Um den neuen Bereich zu füllen, braucht es eigene Inselpositionen: entweder eigene Szenarien (eigener Ordner „Own Scenarios“, keine Spieldatei) oder einen Patch, der die Positionen beim Laden einer Endlos-Vorlage mit Breite/500 und Höhe/350 streckt (nur für Vorlagen, nicht für Spielstände). Umgesetzt als Patch, siehe nächster Abschnitt.

### Inseln verteilen (umgesetzt 2026-11-08)

- **B** Spielstände (`.gam`) enthalten keinen `SZENE`-Abschnitt (geprüft an `Welt1000x700.gam`: `AUFTRAG4, HANDLER, HIRSCH2, INSEL5, INSELHAUS, KONTOR2, MARKT2, MILITAR, NAME, PLAYER4, PRODLIST2, ROHWACHS2, SHIP4, SIEDLER, SOLDAT3, STADT4, TIMERS, TURM, WERFT, WIFF`). Ein Eingriff im `SZENE`-Lader trifft also nur Szenario-Vorlagen.
- **B** Einsprung in `FUN_1400d0de0` nach der Namensprüfung „SZENE“ bei `0x1400D0E29`: `4C 8D 1D D0 F1 F2 FF` = `LEA R11,[0x140000000]` (7 Byte). Dort zeigt `R15` auf die Abschnittsdaten (`MOV R15,RDX` bei `0x1400D0DFC`). Die Flags sind nicht in Gebrauch (der nächste Flag-Leser ist `CMP [R15+0x64],R13D` bei `0x1400D0E65`); `R8` ist in Gebrauch (`LEA R10D,[R8-5]`) und wird gesichert. Kein Sprung zielt in die ersetzten Bytes.
- **B** Freier Platz: `.text` hat VirtualSize `0xE40F3`, im Speicher bis RVA `0xE5FFF` gemappt; RVA `0xE5100`–`0xE51FF` ist in Datei und Abbild nur `00`.
- **B** Ersatz an `0x1400D0E29`: `E9 D2 42 01 00 66 90` (`JMP 0x1400E5100`, 2-Byte-NOP). Codestück an `0x1400E5100` (103 Byte), von Ghidra zurückübersetzt (`tools/ghidra_scripts/AnnoPatchDis.java`):

  ```
  1400e5100  PUSH RAX / PUSH RCX / PUSH RDX / PUSH R8 / PUSH R9
  1400e5107  MOV R8D,dword ptr [R15 + 0x64]        ; Inselzahl
  1400e510b  LEA R9,[R15 + 0x174]                  ; erster Eintrag
  1400e5112  CMP R8D,0x32 / JA 0x1400e5154         ; mehr als 50: nichts tun
  1400e5118  TEST R8D,R8D / JLE 0x1400e5154        ; Schleife
  1400e511d  MOV EAX,[R9 + 0x8] / IMUL EAX,[0x1405ebe40] / CDQ / MOV ECX,500 / IDIV ECX / MOV [R9 + 0x8],EAX
  1400e5134  MOV EAX,[R9 + 0xc] / IMUL EAX,[0x1405ebe98] / CDQ / MOV ECX,350 / IDIV ECX / MOV [R9 + 0xc],EAX
  1400e514b  ADD R9,0x10 / DEC R8D / JMP 0x1400e5118
  1400e5154  POP R9 / POP R8 / POP RDX / POP RCX / POP RAX
  1400e515b  LEA R11,[0x140000000]                 ; ersetzter Originalbefehl
  1400e5162  JMP 0x1400d0e30
  ```
- **F** Die Inseln behalten ihre Grösse; nur die Ecke wird gestreckt. Weil der Faktor ≥ 1 ist, passt jede Insel weiter in die Welt (x' + Breite ≤ x + 500 ≤ Welt) und Abstände zwischen Inseln wachsen nur, es entstehen keine Überschneidungen. Die Klima-Drittel (oben Nord, unten Süd) stimmen wieder wie im Original, weil y mitwächst.
- **F** Wirkt auf jede Szenario-Vorlage, also auch Kampagnen-Szenarien (dort liegen eventuell feste Schiffe und Aufträge nicht mehr bei den Inseln). Das Werkzeug ist nur für das Endlosspiel gedacht. Mit `-OhneInselVerteilung` abschaltbar. Start-Schiffe aus `SHIP4` werden nicht verschoben (der Abschnitt steht auch in Spielständen).

**Offline-Test (B):** `tools/test-weltgroesse.ps1`, **128 von 128** bestanden. Neu: Fall G (`-OhneInselVerteilung` lässt Sprung und Codestück unberührt) und Fall I, ein Funktionstest: Im Hilfsprozess läuft das echte Codestück an seiner echten Adresse im Abbild, aufgerufen über einen Thread mit dem echten `SZENE`-Abschnitt aus `[[48]]10.szs` (Rückweg nur im Abbild des Hilfsprozesses durch `pop r15; ret` ersetzt). Ergebnis: Alle 1'172 Byte sind wie erwartet für 1000 × 700 (Insel 0: (280, 90) → (560, 180)), 750 × 525, 2000 × 1400 und 500 × 350 (unverändert). Bei Inselzahl 60 ändert sich nichts; der Hilfsprozess läuft danach weiter.

**Spieltest (B), 20:13–20:35:** Werkzeug mit Inselverteilung, Neustart des Spiels wieder abgefangen (PID 44220 → 16160), neues Endlosspiel „Durchschnittlich“.

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Inseln über die ganze Welt verteilt | ja: 18 Inseln über die ganze Minikarte, auch rechts und unten | `analysis/test/12-inselverteilung-start-minikarte.png` |
| Insel im neuen Bereich aus der Nähe | ja: Insel bei Welt ≈ (790, 542) | `13-insel-im-neuen-bereich-790-542.png` |
| KI besiedelt den neuen Bereich | ja: blaue KI mit Kontor, Häusern, Wegen und Höfen bei Welt (730, 396) nach ca. 10 Minuten; graue KI oben links | `14-minikarte-ki-im-neuen-bereich.png`, `15-ki-siedlung-mit-kontor-730-396.png` |
| Eigenes Schiff fährt ca. 650 Felder quer über die Karte bis vor eine Insel im neuen Bereich | ja | – |
| Kein Absturz | ja, ca. 20 Minuten Spielzeit | – |
| Speichern in neuen Platz | ja: Symbol „neuer Spielstand“ speichert sofort als `game20.gam` (411'766 Byte, 21:13:37) | – |
| Inseln im Spielstand | 17 `INSEL5`-Abschnitte; Kopf: Byte 0 Nr., Byte 1 Breite, Wort 1 Höhe, Wort 2 x, Wort 3 y. Alle 17 Positionen sind genau die ×2-Positionen der Vorlagen-Variante 2 (`[[48]]02/12/22/32.szs`, 17 Inseln; die zweite Ziffer ist die Anordnung, die erste der Schwierigkeitsgrad) | – |
| Spiel ohne Bewertung beenden, mit Werkzeug neu starten, `game20` laden | ja; Inseltabelle im Speicher (50 Plätze à 0x2CC8 Byte ab `0x14062DDC0`, x/y/Breite/Höhe bei +4/+8/+0xC/+0x10, belegt wenn Zeiger bei +0x2CB0 ≠ 0) nur lesend ausgelesen: **17 von 17 Inseln an derselben Position wie im Spielstand**, also keine zweite Streckung. Ausdehnung x 100–850, y 40–600. | `16-geladen-game20-inseln-unveraendert*.png` |
| Eigener Kontor | **nicht geschafft, unabhängig von der Weltgrösse**: Baumenü → Hafen → „Kontor I“ zeigt an der Küste eine gelbe Grundfläche (halb auf dem Wasser), ein Klick setzt aber nichts (Gold bleibt 15'000). Genau gleich an Insel 15 im **alten** Bereich (420, 220). Auch Drehen mit „.“ und vorheriges „Insel erkunden“ helfen nicht. Ursache offen (Bedienweg oder Spielregel). Die KI baut im neuen Bereich normal. | – |

**Beobachtung zur Testmethode (B):** Das schwebende Fenster der Claude-App (Kompaktansicht dieses Gesprächs, immer im Vordergrund, nicht durchklickbar) liegt während der Bildschirmsteuerung über der rechten Spielleiste (Bildpunkte x 2012–2548, y 20–748) und fing Klicks auf Minikarte, Bauen, Optionen und Speichermenü ab. Lösung: Klicks auf die Spielleiste als Fensternachricht (`WM_MOUSEMOVE`/`WM_LBUTTONDOWN`/`WM_LBUTTONUP`) direkt an das Spielfenster; das Spiel wertet sie für Knöpfe aus, Hinweistexte erscheinen in der Statuszeile. Klicks auf die Karte (Gebäude setzen, Schiffe) nehmen dagegen die echte Mausposition. Die Remotedesktopverbindung holte sich zwischendurch den Vordergrund; das Spiel wurde dann per `SetForegroundWindow` zurückgeholt. In den Screenshots der Bildschirmsteuerung ist es ausgeblendet. Eine Aufnahme mit `CopyFromScreen` hatte es mit aufgenommen; diese zwei Bilder wurden gelöscht, seither nimmt das Hilfsskript nur den Fensterinhalt des Spiels auf (`PrintWindow`). Alle übrigen Aufnahmen wurden auf grosse weisse Flächen geprüft (überall ≈ 0 %).

### Mehr Inseln (umgesetzt 2026-11-08, Nacht)

- **B** Grössen je Inselklasse (`.rdata` `0x1400EA1E0` Breite, `0x1400EA1C0` Höhe): lit 30×30, mit 40×40, med 50×52, big 70×60, lar 100×90.
- **B** Anzahl Inseldateien je Klima × Klasse (`0x1400EA280`, deckt sich mit den Ordnern `NORD`/`SUED`): Nord 51/48/36(39 Dateien)/67/5, Süd 49/45/48/63/6. Die Vorlagen nutzen „lar“ nie.
- **B** Zufällige Dateiwahl im `SZENE`-Lader: Er sammelt die noch unbenutzten Dateinummern der Klasse; sind alle vergeben, nimmt er eine beliebige (Wiederholung, keine Endlosschleife).
- **B** Eingeborene verteilt der Lader selbst: `SZENE`+0x40/+0x44 = 2 Dörfer je Klima, auf Inseln, deren Datei einen Dorfplatz hat (Tabelle bis `0x1400F98A1`), Flag-Bit 0.
- **B** Die drei Endlos-Anordnungen (`[[48]]x0/x1/x2.szs`, 18/20/17 Inseln) sind in allen vier Schwierigkeitsgraden identisch (Klima, Klasse, Flags, Platz, Datei, Position).
- **Umsetzung:** Das Werkzeug liest die drei Vorlagen (nur lesend), plant je Anordnung eine Liste und schreibt sie als Tabelle an RVA `0xE5200` (im Speicher gemappter, leerer Rest der letzten `.text`-Seite; 4 + 3 × 816 = 2'452 Byte). Plan: Originale gestreckt vorne (wie bisher), dann Kopien der Vorlageninseln (grösste Klassen zuerst, Klima 2 = nach Lage, Flags 0, Datei zufällig) an Zufallspositionen mit festem Startwert, mindestens 14 Felder Abstand zu jeder Insel und 8 zum Rand, bis Ziel = min(48, Inselzahl × Flächenfaktor × 0,6) erreicht ist. 1000 × 700: 43/48/40 Inseln; 750 × 525: 24/27/22.
- **Codestück (199 Byte, Ghidra-geprüft):** sucht die Vorlage in der Tabelle (Inselzahl und x/y der ersten Insel), kopiert bei Treffer Inselzahl und 800 Byte Einträge (`rep movsb`) in den Abschnitt; sonst strecken wie bisher. Register `rax, rcx, rdx, r8, r9, rsi, rdi` werden gesichert.
- **Offline (B):** 151/151; Funktionstest mit den echten Vorlagen: genau die geplanten Listen, keine Überschneidung, alles in der Welt; unbekannte Vorlage nur gestreckt.
- **Karten der Pläne:** `analysis/test/inselplan-1000x700-anordnung-{0,1,2}.png` (erzeugt mit `tools/inselplan-zeigen.ps1`).
- **Im Spiel (B), 21:50:** Start über `tools/anno-grosse-welt.cmd`, neues Endlosspiel „Durchschnittlich“. Das Spiel wählte Anordnung 1. Inseltabelle im Speicher: **48 Inseln, alle 48 genau an der geplanten Position**, alle höchstens so gross wie ihre Klasse, Ausdehnung x 47–985, y 24–686. Kein Absturz beim Erzeugen. Beleg: `analysis/test/17-mehr-inseln-start*.png`.
- **Dauerlauf (B):** 21:50–22:01 auf vierfacher Geschwindigkeit (F7, ca. 40 Spielminuten), alle 30 s geprüft: reagiert, 48 Inseln, 1000 × 700, 443–451 MB. Drei KI-Spieler verteilt über die ganze Karte, einer ganz unten rechts im neuen Bereich. Inseln im neuen Bereich werden sauber gezeichnet. Belege: `18-mehr-inseln-neuer-bereich.png`, `19-mehr-inseln-nach-40-spielminuten*.png`.
- **Speichern/Laden (B):** neuer Platz → `game22.gam` (1'050'674 Byte; 48 `INSEL5`, bis x 985 / y 686). Spiel beendet (Prozessende, keine Bewertung), über `anno-grosse-welt.cmd` neu gestartet, `game22` geladen: **48 von 48 Inseln an derselben Position wie im Spielstand und wie im Plan**. Beleg: `20-geladen-game22-48-inseln*.png`.
- **Bedienhinweis Test:** Auf vierfacher Geschwindigkeit nahm das Spiel die per Fensternachricht gesendeten Klicks auf die Spielleiste nicht an; nach F5 (normal) sofort.

### Langlauf 1000 × 700 mit 48 Inseln (B), 22:20–23:20

- Start über `anno-grosse-welt.cmd`, neues Endlosspiel, F7 (vierfach), 60 Minuten jede Minute nur lesend geprüft.
- Ergebnis: immer reagierend, 48 Inseln, Breite 1000, Arbeitsspeicher 432–493 MB ohne Anstieg (Sägezahn um die automatischen Spielstände alle 10 Minuten: 22:30, 22:40, …, 23:20). Kein Absturz.
- KI hat zweite Inseln besiedelt (grau 2, blau 2, davon eine unten rechts im neuen Bereich, orange 1). Beleg `24-langlauf-60min-ende*.png`.
- Einschränkung: Ab etwa 22:26 lag ein Terminalfenster im Vordergrund; die Rechenzeit des Spiels sank von ca. 30 auf 8 CPU-Sekunden pro Minute. Das Spiel lief weiter (automatische Spielstände, KI wuchs), vermutlich aber langsamer als vierfach. Die gespielte Zeit ist daher eher 1–2 Spielstunden als 4.
- **F** Ein Volllaufen der festen Pools (z. B. `ROHWACHS2`) zeigte sich in dieser Zeit nicht; für Spiele über viele Stunden bleibt das offen.
- Der Schutz für „Spiel fortsetzen“ benannte danach `lastgame.gam` (23:20:27) in `lastgame-1000x700-20261108-232148.gam` um.

### Grenztest 2000 × 1400 (B), 22:06–22:18

- Start über `anno-grosse-welt.cmd -Breite 2000 -Hoehe 1400`: Werte 2000 / 1400 / Scrollbereich 1700 gesetzt.
- Neues Endlosspiel: Anordnung 0, **48 Inseln, alle 48 an der geplanten Position**, Ausdehnung x 67–1953, y 24–1366. Kein Absturz.
- Kamera per Pfeiltasten bis Welt (1832, 1300), Scroll t = 1566: Insel dort sauber gezeichnet. Beleg `22-welt-2000x1400-ecke-unten-rechts*.png`.
- Dauerlauf ca. 8 Minuten auf vierfacher Geschwindigkeit: reagiert, 434–462 MB, automatischer Spielstand normal geschrieben (22:16:16) und vom Schutz in `lastgame-2000x1400-20261108-221745.gam` umbenannt. Drei KI-Spieler verteilt, einer im neuen Bereich (x ≈ 1440). Beleg `23-welt-2000x1400-nach-dauerlauf*.png`.
- **F** Die Höchstgrösse 2000 je Richtung ist im Kurztest stabil. Mit höchstens 48 Inseln ist diese Welt aber sehr dünn besiedelt; 1000 × 700 bleibt der sinnvolle Standard.
- **?** Nicht geprüft: eigene Schiffe über sehr weite Strecken, Speichern/Laden bei 2000 × 1400, Spiele über Stunden.

### Eigener Kontor (2026-11-09)

- **B** Der erste Kontor wird über das **Schiffsmenü** gebaut, nicht über Baumenü → Hafen: `Loca\de-DE\Text.cod` (Bytes negiert) enthält zwischen den Schiffsmenü-Texten „Kontor errichten, um neue Stadt zu gründen“. Der Knopf (Lagerhaus-Symbol, Spielleiste Bildpunkt 2365/577) erscheint erst, wenn das Schiff direkt an der Küste liegt, zusammen mit „Insel erkunden“ (2350/475). Hinweistexte per Mausbewegung geprüft.
- **B** Kosten Kontor I: 3 Werkzeug, 6 Holz, 100 Gold (`haeuser.cod`). Startschiff im Endlosspiel: 50 t Werkzeug, 30 t Holz, 10 t Nahrung.
- **B** Baumodus: Um das Schiff wird der erlaubte Bereich hell, eine gelbe Grundfläche (2 × 3 Felder) folgt der Maus. An einer gültigen Küstenstelle erscheint zusätzlich die gepunktete Linie des Einzugsbereichs.
- **B** Ein Klick setzt keinen Kontor (Gold bleibt), egal ob einfacher Klick, Doppelklick, Taste gehalten oder Klick als Fensternachricht, auch an Stellen mit Einzugsbereich-Linie. Geprüft: 1000 × 700, Insel 10 im neuen Bereich (Welt 140/380); **ohne Werkzeug** im Endlosspiel 500 × 350; **ohne Werkzeug** in der Einführung „Entdecken“.
- **B** Code: Bauplatz-Prüfung `FUN_14000ef50`. Küstengebäude (Art 0x23 mit Strandflag: Gebäudetabelle `0x1406ba1c0` + i × 0x90, Byte +0x72 Bit 5) richtet `FUN_140098fb0` selbst aus; Drehen mit „.“ ist dafür nicht nötig.
- **B** Eingabe: `Anno1602.exe` importiert für Maus und Tastatur nur `PeekMessageA`/`GetMessageA`/`PostThreadMessageA` (kein `GetAsyncKeyState`, kein DirectInput, kein Raw Input). Künstliche Klicks kommen also wie echte an.
- **B** Regel für Küstengebäude (`FUN_140098fb0`, dann `FUN_1400949b0`): Die Grundfläche (2 × 3) braucht an **einer Längsseite eine gerade Reihe von 3 Küstenfeldern** (Feldart über Tabelle `0x1406cbb00`, Wert +4 = 0x17–0x1B, 0x1D oder 0x1E); daraus folgt die Ausrichtung 0–3, sonst 0xF = ungültig. Dann müssen alle Felder der Fläche zum selben Gebiet gehören wie diese Küste (Bits 19–21 des Feldes; 7 = frei, dann muss das Gebäude Byte +0x72 Bit 2 haben), baubar sein (`FUN_140094630`), und es darf keine Figur (z. B. Tier) darauf stehen. Zusätzlich prüft es die Insel (+0x1A ≠ −1 oder Flag bei +0x44 Bit 0).
- **F** Die früheren Fehlversuche hatten nichts mit der Weltgrösse zu tun (gleiches Verhalten ohne Werkzeug): Ich hatte keine Stelle getroffen, die alle Bedingungen erfüllt. Die gepunktete Linie des Einzugsbereichs zeigt das nicht an; an einer gültigen Stelle zeigt die Vorschau dagegen **das Gebäude selbst** statt nur der gelben Fläche.
- **B Gelöst (2026-11-09, 08:28–08:35, Spielstand `game22` mit Werkzeug, 1000 × 700):** Gültige Stellen aus den Inseldaten berechnet (Hilfsskript `kontorplatz.ps1`: Feldraster Insel +0x2CB0, Art über `0x1406cbb00`, Gebiet Bits 19–21; Grundfläche nur auf Land 0xA/0xB/0xF/0x1F/0x20) und mit geeichter Umrechnung Welt → Bildpunkt angeklickt (bei dieser Zoomstufe: x-Feld = (+9,05, +4,48), y-Feld = (−9,05, +4,48), Kameramitte bei Bildpunkt 674/415).
  - **Insel 35 (alter Bereich)**, Welt 349–350 / 88–90: Kontor steht, Gold 15'000 → 14'898, Schiff 50 → 47 t Werkzeug, 30 → 24 t Holz. Beleg `27-eigener-kontor-insel35-alter-bereich.png`.
  - **Insel 12 (neuer Bereich, x 620–670)**, Welt 627–628 / 66–68: Kontor steht, Gold 14'864 → 14'758, Schiff 47 → 44 t Werkzeug, 24 → 18 t Holz; im Inselraster danach 513 Felder Gebiet 0 (Spieler) und 6 Felder Art 0x23 (Kontor). Beleg `28-eigener-kontor-insel12-neuer-bereich*.png`.
- **F** Damit ist der eigene Kontor im neuen Bereich bestätigt; die Bauregeln wirken dort wie im alten.

### Gegner und Piraten (2026-11-09)

- **B** Spielerarten (erstes int je Platz, Tabelle 7 × 640 Byte ab `0x1405f0960`, im laufenden Spiel gelesen): Platz 0 Mensch (0), 1–3 KI (0xC), 4 Händler (0xD), 5 Piraten (0xE), 6 Eingeborene (0xB).
- **F** Mehr als 3 KI-Gegner ist nicht machbar: 4 feste Spielerplätze, Händler/Piraten/Eingeborene fest auf 4/5/6, 4 Flaggenfarben, feste Schleifen (siehe „Spieler und Parteien“). Das Endlosspiel nutzt schon alle 3 KI-Plätze.
- **B** Die Endlos-Vorlagen unterscheiden sich je Schwierigkeit (erste Ziffer 0–3) nur in: Startgeld `PLAYER4` (20'000 / 15'000 / 10'000 / 10'000), `SZENE` +0x96…+0xDE und +0x116 (Werte sinken mit der Schwierigkeit, vermutlich Rohstoffe/Fruchtbarkeit), `TIMERS` +0xA6 (Schwierigkeit 0–3), +0xA8 (Flags 9/9/8/8) und weitere Zeitwerte.
- **B** Schwierigkeit `0x1405ec1c0` (aus `TIMERS`, `FUN_1400c2da0`) steuert u. a.: Kanonen der Piratenschiffe in `FUN_14003b7e0` ((n+1)/2, n+2, 2n+4; höchstens Maximum des Schiffstyps), Schwellen der KI in `FUN_140017840` (−25 % … +50 %), Naturereignisse in `FUN_14009e390` (Dürre ab „Fordernd“).
- **B** Flags `0x1405ec188` **Bit 0** = Piraten nur „gelegentliche Sichtungen“: `FUN_14003dc40` lässt den Piratenspieler (Art 0xE) nur handeln, wenn Bit 0 gelöscht ist. Gesetzt bei Einfach/Durchschnittlich, gelöscht bei Fordernd/Schwer (im Spiel „Schwer“ gelesen: 0x8).
- **B** `0x1405ebf1c` (Pause nach einem Piratenzug, × 1000) wird nur dort und beim Laden/Speichern benutzt.
- **B** Schiffstabelle: 200 Plätze ab `0x1401d8bb0`, je 0x328 Byte, Name +0x296, Besitzer +0x28 (Lader `FUN_14008e4f0`). Am Start eines Endlosspiels 7 Schiffe: je 1 für Mensch und KI, 3 Händler. 200 Plätze reichen auch für die grosse Welt.
- **Umsetzung** `-Piraten Aktiv|Stark|Aus` im Werkzeug: Haken am Ende des `TIMERS`-Laders (RVA `0xC3232`, `MOVAPS` 7 Byte → `JMP`), Codestück bei RVA `0xE5F80` (19 Byte: ersetzter Befehl, `AND`/`OR dword [0x1405ec188]`, Rücksprung `0x1400c3239`). „Stark“ zusätzlich RVA `0x3B94B`: `MOV ESI,0x100; JMP 0x14003b98d` → Piratenschiffe immer mit voller Kanonenzahl. Ghidra-Rückübersetzung geprüft, kein Sprung zielt in die ersetzten Bytes. Offline-Test Fall J: Bit 0 wird gesetzt/gelöscht, andere Bits bleiben. Im Spiel bestätigt (Abschnitt „Schiffe, Geld“, Spieltest der Optionen).

### Schiffe, Geld (2026-11-09)

- **B** Figurentabelle (aus `figuren.cod`, Parser `FUN_140068f10`): ab `0x1406d80c0`, je 0x18C Byte. „Speed“ als Kommazahl Speed/10'000 bei +0x10 (Parser `0x14006A4D7`), wird laufend gelesen (z. B. `FUN_1400b9760` teilt durch diesen Wert). Schiffstypen Nr. 21–32 (je zwei Einträge), im Spiel gelesen:

  | Nr. | Schiff | Tempo | Kanonen (+0x3C) | Laderäume (+0x3A) | je Laderaum (+0x3E, /32) |
  |---|---|---|---|---|---|
  | 21/22 | kleines Handelsschiff | 0.05 | 6 | 4 | 50 t |
  | 23/24 | grosses Handelsschiff | 0.04 | 10 | 6 | 80 t |
  | 25/26 | kleines Kriegsschiff | 0.055 | 8 | 3 | 65 t |
  | 27/28 | grosses Kriegsschiff | 0.06 | 14 | 8 | 120 t |
  | 29/30 | Händler | 0.048 | 12 | 6 | 95 t |
  | 31/32 | Pirat | 0.045 | 10 | 5 | 95 t |

- **B** Schiff (Schiffstabelle) +8 zeigt auf seine Figur; dort Position als Kommazahlen bei +0x28/+0x2C (Startschiff im Spiel: 230.5/270.5), Figurtyp bei +4.
- **B** Gemessen (Spiel „Schwer“, normales Tempo F5): kleines Handelsschiff **2,1 Felder/s** (42 Felder in 20 s, `schiffsmessung.ps1`).
- **B** Geld: Spielertabelle +4 (int). Spieluhr `0x1405ec0f8` (aus `TIMERS` +0xA0): Vorlagen 10–24, Spielstände 20'000–85'000, läuft ca. 10 pro Sekunde (bei vierfach 40/s).
- **Umsetzung** `-Schiffstempo F` (1–3): das Werkzeug wartet, bis die 12 Schiffswerte geladen sind (Originalwerte fest hinterlegt), und setzt Original × F. `-Startgeld N`: im selben Codestück wie die Piraten, `CMP [Spieluhr],1000; JAE; MOV [Geld Platz 0],N` (Ghidra-geprüft) → nur neue Spiele. Offline: Fälle K und L, gesamt **233/233**.

- **B** Lager: Gebäudetabelle (`0x1406ba1c0`, je 0x90 Byte), „Maxlager“ × 32 als 16-Bit-Wert bei +0x30. Im Spiel gelesen: Nr. 270–273 = Kontor I–IV (960/1'600/2'400/3'200 = 30/50/75/100 t, Art 0x23, 2 × 3), 274–277 zerstörter Kontor (20 t), 401/467/468 Markt (10 t, Art 0xE). Ein neu gebauter Kontor übernimmt den Wert als Lagergrenze: eigener Kontor auf Insel 12, Kontor-Datensatz (Zeiger bei Insel +0xB0) +0x20 = 960.
- **Umsetzung** `-Lager F` (1–5): wie Schiffstempo, die 7 Werte × F (Kontor IV höchstens 500 t = 16'000, passt in 16 Bit). Offline Fall M, gesamt **245/245**.

**Spieltest der Optionen (B), 2026-11-09 08:11–08:25:** Werkzeug mit `-Piraten Aktiv -Schiffstempo 2 -Startgeld 50000`, Spiel über Ubisoft Connect (Neustart wieder abgefangen, PID 2812 → 34060).

| Prüfung | Ergebnis |
|---|---|
| Werkzeug beim Start | alle 13 Stellen gesetzt; „Schiffstempo x2: kleines Handelsschiff 0.1 statt 0.05“ |
| Neues Endlosspiel „Durchschnittlich“ | Schwierigkeit 1, **Flags 0x8** (Vorlage 0x9 → Piraten aktiv), **Gold 50'000** (Anzeige oben links, sonst 15'000), Schiffswerte nach dem Spielstart weiter verdoppelt, 48 Inseln |
| Schiffstempo gemessen (normales Tempo F5) | kleines Handelsschiff **4,19 Felder/s** (86 Felder in 20,5 s) gegenüber 2,10 ohne Option → Faktor 2,0 |
| `game22.gam` laden (Spielstand: Uhr 26'696, Flags 0x9, Gold 15'000) | **Gold bleibt 15'000** (Startgeld nur bei neuen Spielen), **Flags 0x8** (Haken wirkt auch beim Laden), Tempo 0.1, 48/48 Inseln wie im Spielstand |

**Spieltest alle Optionen (B), 2026-11-09 08:40–08:52:** Werkzeug mit `-Piraten Stark -Schiffstempo 2 -Startgeld 50000 -Lager 3` (alle 14 Stellen gesetzt, Neustart abgefangen), neues Endlosspiel „Durchschnittlich“ (Anordnung 0, 43 Inseln).

| Prüfung | Ergebnis |
|---|---|
| Speicher nach Spielstart | Gold 50'000, Flags 0x8, Kanonen-Stelle `BE 00 01 00 00 EB 3B`, Kontor I in der Gebäudetabelle 2'880 (90 t), Schiffstempo 0.1 |
| Kontor gebaut (Insel 16, Welt 242–243 / 289–291, Stelle wie oben berechnet; Umrechnung vorher am Schiff geprüft: Schiff genau beim berechneten Bildpunkt) | steht, Gold 50'000 → 49'900; neue Stadt „Zaustaden“ (Kontor-Datensatz +0x1A = 0 = Spieler): **Lagergrenze +0x20 = 2'880 = 90 t**. Das Eingeborenendorf „Argenhall“ auf derselben Insel (+0x1A = 6) behält 960 = 30 t (anderes Gebäude). Beleg `29-alle-optionen-kontor-lager-90t.png` |
| Waren vom Schiff in den Kontor (mehr als 30 t) | **nicht geprüft**: Die Mengen- und Pfeilknöpfe im Austauschfenster nehmen keine Klicks als Fensternachricht an, echte Klicks fängt dort das Claude-Fenster ab |

### Erweiterungen Einwohner, Produktion, Laderaum, Turbo, Gegnergeld (2026-11-10)

Gefunden mit REA/Ghidra (`analysis/scan/alle-funktionen.c`: alle 1'275 Funktionen dekompiliert, Skript `AnnoDecompAll.java`).

- **B Einwohner:** `haeuser.cod` „Maxwohn“ der 5 Bevölkerungsgruppen (`BGRUPPE` Nr. 0–4) legt der Parser `FUN_140090660` als `Wert << 6` (int) bei `0x1406ba02c + Nr. × 0x50` ab (Steuer +4, Hiscore +8).
  - Häuser speichern ihre Einwohner × 64 als 16 Bit (Haus +6).
  - `FUN_1400b7c60` vergleicht die Einwohnerzahl mit Maxwohn der Stufe und schaltet darüber die Stufe weiter; `FUN_1400b7770`, `FUN_1400b7360` und `FUN_1400b5450` nutzen Maxwohn/2 als Schwelle.
  - **F** Alle fünf Werte mit demselben Faktor zu multiplizieren, lässt die Verhältnisse gleich.
- **B Produktion:** `haeuser.cod` „Interval“ steht als 16 Bit bei Gebäudetabelle +0x3A (`DAT_1406ba1fa`). Er wird bei jedem Arbeitsschritt gelesen, in `FUN_1400b43e0` (`*(ushort*)(typ + 0x3a) × Anteil / 128`) und in `FUN_1400b9ed0` (gleich), jeweils über den Zeiger auf den Gebäudeeintrag (deshalb keine direkte Querverweisliste).
  - `MAXHAUS` = 500 (`FUN_140002ae0("MAXHAUS",500)`).
  - **F** Kleinere Intervalle wirken sofort auf alle Betriebe, auch in geladenen Spielständen.
- **B Laderaum:** `figuren.cod` „Maxware“ steht als 16 Bit bei Figurentabelle +0x3E (`0x1406d80fe`, 26 lesende Funktionen, u. a. Schiffslader `FUN_14008e4f0`).
- **B Spieltempo:** Tastatur `FUN_1400e2d60`: F5/F6/F7 → `FUN_1400c8be0(1/2/4)` (Befehl 0x0F, Variable `0x1400f99f8`).
  - Die Spielschleife `FUN_1400c8e20` rechnet `Tempo × Zeit` in Schritten zu 200 (Obergrenze nur bei Tempo × Zeit > 2'999). `FUN_140060560` hat schon einen Zweig für Tempo ≥ 5.
  - F7 bei `0x1400E3376`: `B9 04 00 00 00` (`mov ecx,4`).
- **B Gegner:** Die KI-Schwierigkeit kommt nur aus der Spielschwierigkeit `0x1405ec1c0` (`FUN_140017840`, `FUN_140017b30`, `FUN_140032090`, `FUN_140035220`, `FUN_14003b7e0`). Einen eigenen Regler für die KI-Stärke gibt es nicht.
  - **F** Am einfachsten macht die Gegner ihr Startgold stärker: Spielertabelle Platz 1–3, Geld +4, Abstand 0x280.

**Umsetzung in `tools/weltgroesse.ps1`:**

| Option | Ort | Verfahren |
|---|---|---|
| `-Einwohner F` (1–3) | `0x6BA02C + Nr. × 0x50`, int | wie Lager: warten bis geladen, Original (128/384/960/1600/2560) oder Ziel prüfen, alle setzen |
| `-Laderaum F` (1–3) | Figur Nr. 21–28 +0x3E, 16 Bit | wie Lager, Originale 1600/2560/2080/3840 (je 2 Einträge) |
| `-Produktion F` (1–3) | Gebäude 0–499 +0x3A, 16 Bit | nach dem Lesen von `haeuser.cod` (Lagerwert Kontor I ≠ 0) und stabiler Tabelle: jedes Intervall ≠ 0 → max(1, rund(v / F)); Marke `NUFR` + F × 100 bei RVA `0xE5F70` gegen doppeltes Teilen |
| `-Turbo` | RVA `0xE3376` | `B9 04 00 00 00` → `B9 08 00 00 00` (Code-Stelle, alles oder nichts) |
| `-GegnerGeld N` | TIMERS-Codestück | nach dem Startgeld: `cmp [Spieluhr],1000; jae +30; mov [Geld Platz 1/2/3],N` (Codestück jetzt bis 83 Byte, Platz bis 128) |

**Offline-Test (B):** `tools/test-weltgroesse.ps1`, neue Fälle N–R, gesamt **284 von 284** bestanden. Fall R führt das echte Codestück aus: Spieler 50'000, Gegner 3 × 30'000, Händler (Platz 4) unverändert; bei Spielstand-Uhr nichts geändert.

**Im echten Spiel (B), 2026-11-10 19:00:** installiertes Werkzeug mit `-Piraten Stark -GegnerGeld 60000 -Startgeld 50000 -Einwohner 2 -Produktion 2 -Lager 3 -Schiffstempo 2 -Laderaum 2 -Turbo`, Spiel über Ubisoft Connect (Neustart wieder abgefangen, PID 5344 → 14268).
- Alle 15 Code-Stellen gesetzt.
- Einwohner- und Laderaum-Originale stimmten genau (kein Abbruch).
- 125 Arbeitsintervalle halbiert.
- Im Hauptmenü nur lesend nachgeprüft (`tools/pruefe-spiel.ps1`): Welt 1000 × 700, F7 `B9 08 …`, Einwohner 4/12/30/50/80, Laderaum 100/160/130/240 t, Schiffstempo 0.1, Lager Kontor I 90 t, Marke `NUFR x2`.
- Danach Spiel beendet. Das Werkzeug meldete „lastgame.gam nicht geschrieben“; `lastgame.gam` ist unverändert.
- Die Prüfung im laufenden Spiel stand zunächst aus (Freigabe der Bildschirmsteuerung abgelehnt); nachgeholt am 2026-11-11, siehe unten.

**Spieltest mit Bildschirmsteuerung (B), 2026-11-10 20:10 und 2026-11-11 15:10.** Gleiche Optionen, Endlosspiel „Durchschnittlich“, Flagge Rot.

| Prüfung | Ergebnis |
|---|---|
| Neues Spiel: Gold | Spieler **50'000**, Gegner Platz 1–3 je **60'000**, Händler 1'000'000 (zweimal geprüft) |
| Piraten | Flags 0x8 (Bit 0 gelöscht → greifen an, obwohl „Durchschnittlich“) |
| Inseln | 48 bzw. 43 (Anordnung 1 bzw. 0) |
| F7 | Spieltempo-Variable **8**; Spieluhr +837 in ca. 11 s (normal ca. 110) |
| Lager über 30 t | Kontor auf Insel 16 gebaut (Welt 233–235 / 286–287), Gold 50'000 → 49'898. Austauschfenster: 50 t Werkzeug vom Schiff → Kontor. Schiff danach leer; Kontor-Datensatz: Grenze +0x20 = **2'880 (90 t)**, Bestand Werkzeug +0x132 = **1'504 (47 t)** |
| Rand-Scrollen mit der Maus | **nicht prüfbar**: Kamera bewegt sich bei simulierter Maus am unteren und linken Rand gar nicht, auch nicht Richtung alter Bereich. `FUN_1400dd190` scrollt nur, wenn ein Eingabe-Objekt (`DAT_1400fa708`, vtable +0x58) „aktiv“ meldet; danach dieselbe Grenze `DAT_1405eb840` wie die Pfeiltasten. Von Hand zu prüfen. |
| „Spiel fortsetzen“ | `lastgame.gam` am Ende unverändert (B7C4BFB9…) |

**Testmethode (B):**
- `open_application` der Bildschirmsteuerung startet **eine zweite, ungepatchte Spielinstanz** (2026-11-10, PID 21728 neben der gepatchten 21964); das erste neue Spiel lief darin mit Originalwerten. Danach wurde das Spielfenster nur noch per `SetForegroundWindow` nach vorne geholt.
- Klicks auf die Spielleiste (rechts) kamen als echte Klicks nicht an. Als Fensternachricht an das Spielfenster funktionierten „Kontor errichten“, das Austauschfenster, die Menge „50“ und der Pfeil.
- Die Remotedesktopverbindung holte sich einmal den Vordergrund.
- **Unterbrechung 2026-11-10:** Das aus der Sitzung gestartete Werkzeug wurde mit beendet; das Spiel schrieb danach `lastgame.gam` (20:24) ohne Umbenennung. Am 2026-11-11 in `lastgame-1000x700-20261110-202424.gam` umbenannt und das Original zurückkopiert. Für den zweiten Test lief das Werkzeug als eigener Prozess (`Win32_Process.Create`).

**Starter-Fenster:** `tools/anno-starter.ps1` (WinForms). Alle Optionen als Auswahlfelder, letzte Wahl in `%APPDATA%\Anno1602-Erweiterungen\einstellungen.json`. „Mit Erweiterungen spielen“ startet das Werkzeug in eigenem Fenster und nach 3 s `uplay://launch/16236/0`; „Original starten“ nur das Spiel.

**Installation:** `%LOCALAPPDATA%\Programs\Anno1602-Erweiterungen`, mit Verknüpfung „Anno 1602 - Erweiterungen“ im Startmenü und auf dem Desktop. Der Desktop-Ordner `C:\Users\User\Desktop` fehlte und wurde angelegt.

**Nebenwirkung:** Der Spieltest legte die Sicherung `Savegame-Sicherung-20261110-190036` an, weil sich der Savegame-Ordner seit der ersten Sicherung geändert hatte (Testspielstände).

### Rohstoffe, Inselgrösse, Einwohner ×5, Leistung (2026-11-11)

**Rohstoffe (B):** `SZENE`-Abschnitt der Endlos-Vorlagen, Einträge zu 8 Byte ab +0x94 (Haus-Nr. 16 Bit, Menge 16 Bit, int), verglichen über die vier Schwierigkeiten (`[[48]]00/10/20/30.szs`):

| Offset | Haus-Nr. | Bedeutung | Einfach → Schwer |
|---|---|---|---|
| +0x94 | 2401 | Erz (Typ +0x98 = 0) | 6 / 5 / 4 / 2 |
| +0x9C | 2401 | Erz (Typ 1) | 8 / 8 / 7 / 9 |
| +0xA4 | 2405 | Gold (Typ 2) | 3 / 2 / 2 / 2 |
| +0xB4 … +0xDC | 1336, 1342, 1340, 1332, 1344, 1338 | Fruchtbarkeit der 6 Plantagen (12 Plätze) | 5 → 2–3 |
| +0x114 | 533 | Schatz | 10 / 8 / 6 / 4 |
| +0x40 / +0x44 | – | Eingeborenendörfer | 2 / 2 |
| +0x60 | – | höchstens Rohstoffe je Insel | 2 |

- Lader `FUN_1400d0de0` (Auszug `analysis/scan/szene-lader.c`): Die Fruchtbarkeit verteilt er in drei Durchgängen (erst Klassen big/lar, dann lit/mit, dann alle); jede gelungene Vergabe senkt die Menge. Die letzte Schleife endet, sobald ein Durchgang nichts mehr vergibt.
- Erz: nur Inseln mit Zähler +0x41 < 2 und passendem Berg; ohne Kandidaten bricht er ab (`goto LAB_1400d3260`).
- **F** Zu hohe Mengen führen nicht in eine Endlosschleife; was nicht passt, entfällt.

**Umsetzung `-Rohstoffe Mehr|Viele`:** Codestück bei RVA `0xE5C00` (102 Byte), aufgerufen per `call` aus der Inselverteilung direkt nach dem Kopieren der Inselliste (nur Endlos-Vorlagen).
- Für die 17 Mengen +0x96 … +0x116: `min(neu, Menge × neu × Prozent / (alt × 100))`, dabei Prozent = 100 bzw. 200.
- Inselcodestück mit Aufruf: 204 statt 199 Byte; `TabelleMax` jetzt bis `0xE5C00`.

**Inselgrösse (B):**
- Inseldateien der Klasse lar: `NORD` 6, `SUED` 7, `NORDNAT`/`SUEDNAT` 0 (big: 68/64/37/40).
- Erster Spieltest mit `-Inselgroesse Riesig` (Plan Anordnung 2: 17 big, 23 lar): **nur 32 von 40 Inseln geladen** (17 big, 15 lar). Es fehlten 8 lar-Inseln.
- **Umsetzung:**
  - Höchstens 10 lar je Karte, sonst big. Gross = Originale eine Klasse grösser (wo Platz ist), Zusatzinseln abwechselnd lar/big; Riesig = alles lar/big.
  - Geänderte Originale bekommen eine zufällige Inseldatei (0xFFFF).
  - Fläche der Inselrechtecke bei 1000 × 700: Normal 108–122 Tsd. (15–17 %), Gross 201–229 Tsd. (29–33 %), Riesig 216–246 Tsd. (31–35 %).
- **Zweiter Spieltest (B), 2026-11-11 16:40:** `-Inselgroesse Riesig -Rohstoffe Viele -Einwohner 5 -Produktion 2 -Lager 3 -Turbo`, Anordnung 2. **40 von 40 Inseln geladen** (30 × 70×60, 10 × 100×90). Dazu 69 Erzvorkommen auf allen 40 Inseln und 254 Fruchtbarkeiten (`tools/pruefe-inseln.ps1`). Die Welterzeugung lief ohne Hänger durch.

**Einwohner bis ×5:** 10/30/75/125/200 je Haus; im Spiel gelesen. Das Haus speichert ×64 als 16 Bit, also höchstens 1'023.

**Leistung (B), 2026-11-11, gleicher Spielstand, F7 (8-fach), Spielfenster im Vordergrund, 500 s:**
- Spieluhr 504 → 40'531, also **genau 8,0-fach** in jeder 20-s-Messung (80 Uhrschritte/s).
- CPU **52–56 % eines Kerns**, Arbeitsspeicher 430–494 MB ohne Anstieg; Einbruch bei 300–320 s während eines internen Speichervorgangs.
- **F** Bei 8-fach hat das Spiel noch Reserve; die Spiellogik läuft auf einem Kern.
- **?** Mit stark gewachsenen Städten über Stunden noch nicht gemessen.

**Turbo 16-fach (B), 2026-11-11 17:10:** `-TurboStufe 8|12|16` (F7 `mov ecx,<Stufe>`). Gemessen mit den Einstellungen des Starter-Knopfs „Alles gross“: `-Inselgroesse Riesig -Rohstoffe Viele -GegnerGeld 60000 -Startgeld 50000 -Einwohner 5 -Turbo -TurboStufe 16 -Produktion 2 -Lager 5 -Schiffstempo 2 -Laderaum 3`. Ergebnis:
- Neues Endlosspiel: 43 Inseln (33 × 70×60, 10 × 100×90), 70 Erzvorkommen auf 40 Inseln, 268 Fruchtbarkeiten; Gold 50'000 / 60'000 × 3.
- 500 s auf F7: Spieluhr 467 → 80'490 = **16,0-fach** in jeder Messung (160 Uhrschritte/s), etwa 2,2 Spielstunden.
- CPU 52–56 % eines Kerns (wie bei 8-fach), in den letzten 60 s 14–15 % ohne Tempoverlust; Arbeitsspeicher 430–493 MB.
- **F** Die Spiellogik ist nicht der Engpass; die Last kommt überwiegend von der Darstellung.

**Starter:** Turbo als Auswahl (Aus/8/12/16-fach) statt Ankreuzfeld; ältere gespeicherte Einstellung „Turbo = ja“ wird zu 8-fach. Neuer Knopf **„Alles gross“** mit den obigen Werten (1000 × 700 statt 2000 × 1400, weil das Spiel höchstens 48 Inseln kennt).

**Offline-Test:** neue Fälle S (Funktionstest Rohstoffcode und Inselcode mit den echten Vorlagen `[[48]]00/11/32.szs`, Riesig) und T (Geometrie und höchstens 10 lar für Gross/Riesig bei 1000×700, 2000×1400, 750×525). Gesamt **332 von 332**.

### Gegner, Piratenflotte, Ureinwohner, Händler, 50 Inseln (2026-11-11)

Assembler-Auszüge: `analysis/scan/schwierigkeit.txt`, `haendler.txt`, `neue-patches.txt` (Rückübersetzung der neuen Bytes, Codestücke an Ersatzadresse 0x140001000).

**KI-Stärke (B):** Die Schwierigkeit `0x1405ec1c0` (0 Einfach, 1 Durchschnittlich, 2 Fordernd, 3 Schwer; aus `TIMERS` +0xA6) liest die KI an vier Stellen, jeweils mit `mov eax,[rip+rel32]` (`8B 05 …`):

| RVA | Funktion | Wirkung von Stufe 3 |
|---|---|---|
| 0x17A8E | `FUN_140017840` | Schwelle für die eigene Stärke im Vergleich zum stärksten Spieler: +50 % (Stufe 0: −25 %) |
| 0x17EA1 | `FUN_140017b30` | Ziele für vier Einheiten-/Schiffsarten aus der Stärke der Spieler: ×2 (1: ×1,25, 2: ×1,5) |
| 0x321C9 | `FUN_140032090` | weiterer Militärwert: ×2 (0: −25 %, 2: +50 %) |
| 0x35344 | `FUN_140035220` | Ausbaustufe für `FUN_14002e2c0(…, 1/2/3)` |

- Weitere Leser: Naturereignisse `FUN_14009e390` (Dürre ab Stufe 2), Piratenkanonen `FUN_14003b7e0`, Spielstand-Schreiber `FUN_1400c4390`. Diese bleiben unverändert.
- **Umsetzung `-Gegner Schwer`:** die vier Stellen → `mov eax,3; nop` (`B8 03 00 00 00 90`).

**Piratenflotte (B):** `FUN_14003dc40` ruft für die Piraten (Spielerart 0xE, nur wenn Bit 0 der Flags gelöscht) alle 10'000 Zeiteinheiten `FUN_14003b7e0` auf, sobald `FUN_1400185f0` > 1 ist.
- `FUN_1400185f0` = höchste Zivilisationsstufe (0–4) von Mensch und KI über alle Siedlungen (Spielerflags +0x6C, Bits 18/24/29/30).
- `FUN_14003b7e0`: Hat die Piraten-Steuerung (+0x1076c) weniger Schiffe als diese Stufe und ist die Wartezeit (+0x14) abgelaufen, entsteht ein Piratenschiff an einer Zufallsstelle (`FUN_140070d80(3)`). Danach Wartezeit = `0x1405ebf1c` (1'500) × 1000. Das Original hat also höchstens 4 Piratenschiffe.
- Schiffsanlage (`FUN_14008be30`, Fall 3): nur die Schiffstabelle (200 Plätze) begrenzt.
- **Umsetzung `-Piratenflotte Gross|Riesig`:** RVA 0x3B7F1 `call FUN_1400185f0` → `call 0xE5E00`. Codestück (17 Byte): `sub rsp,0x28 / call FUN_1400185f0 / add rsp,0x28 / imul eax,eax,F / ret` (Schattenbereich nötig: `FUN_1400185f0` sichert rbx/rdi bei [rsp+8]/[rsp+0x10]). Die beiden Wartezeiten (RVA 0x3B8D2, 0x3B9CE, `imul eax,[0x1405ebf1c],1000`) → 1000/F. Ergebnis bis 8 bzw. 12 Piratenschiffe.

**Händler (B):** `FUN_1400bc030` zählt die Siedlungen (`0x1405bd228`, auch die der Eingeborenen) und hält `(Zahl + 2) / 3` freie Händler (Zähler `0x1406d7e68`, wird nie gesenkt); sonst `FUN_140070d80(2)`.
- Händlerdatensätze: 30 (`0x1405a8450` à 0xD0); `FUN_14008be30` Fall 2 bricht ab Nr. 30 ab (`cmp al,0x1e`), nachdem das Schiff schon angelegt ist.
- **Umsetzung `-Haendler Mehr|Viele`:** RVA 0xBC140 `shr eax,31; add edx,eax` (Vorzeichenkorrektur, immer 0; eax wird danach nicht gelesen) → `call 0xE5E20`. Codestück (14 Byte): `imul edx,edx,F / cmp edx,24 / jle / mov edx,24 / ret`. Höchstens 24 Händler.

**Ureinwohner (B):** Der SZENE-Lader verteilt je Klimazone `+0x40` (Nord) bzw. `+0x44` (Süd) Dörfer auf Inseln, deren Inseldatei einen Dorfplatz hat (Tabelle `0x1400F94E4`–`0x1400F98A3`, 240 Einträge Klima/Klasse/Datei: Nord lit/mit/med/big 10/25/25/36, Süd 31/41/33/39, keine lar) und setzt Flag-Bit 0 (Datei aus `NORDNAT`/`SUEDNAT`). Zu wenige Kandidaten: weniger Dörfer, kein Fehler.
- Siedlungsplätze: 75 à 600 Byte ab `0x140622DC0` (`FUN_14009a9f0`); jedes Dorf belegt einen. Ist alles voll, scheitert ein neuer Kontor sauber (Rückgabe 7).
- **Umsetzung `-Ureinwohner Mehr|Viele`:** im Rohstoff-Codestück `mov dword [r15+0x40],n` und `[r15+0x44],n` mit n = 4 bzw. 7 (höchstens 14 der 75 Plätze). Ohne `-Rohstoffe` besteht das Codestück nur aus diesen zwei Befehlen.

**50 Inseln (B):** SZENE-Abschnitt, Inseltabelle und Raster haben 50 Plätze; 48 war nur Vorsicht. `0x31` kommt im Code als Warenkennung vor, nicht als „keine Insel“; Inseln werden zur Laufzeit nicht neu angelegt. Dichte der Zusatzinseln 0,7 statt 0,6: bei 1000 × 700 jetzt 50/50/47 statt 43/48/40.

**Speicher-Belegung am Ende von .text:** 0xE5100 Inselcode (204) · 0xE5200 Inseltabelle (2'452) · 0xE5C00 Rohstoffe/Dörfer (bis 118) · 0xE5E00 Piratenflotte (17) · 0xE5E20 Händler (14) · 0xE5F70 Marke NUFR (8) · 0xE5F80 TIMERS (bis 83).

**Offline-Test:** neue Fälle U (vier KI-Stellen, Naturereignisse und Piratenkanonen unberührt), V (Piratenflotten-Codestück ruft im Abbild das echte `FUN_1400185f0` auf; Stufen 0–4 über die Spielerflags gesetzt → 0/2/4/6/8 bzw. 0/3/6/9/12; Wartezeiten 500/333), W (Händler: 0, 1, 4, 5, 8, 12, 13, 30 → ×2 bzw. ×3, höchstens 24), X (Dörfer 4/4 bzw. 7/7 mit den echten Vorlagen, mit und ohne Rohstoffe), Y (50 Inseln; alle Optionen zusammen, Codestücke überlappen nicht). Gesamt **415 von 415**.

**Spieltest 1 (B), 2026-11-11 18:05–18:13:** Werkzeug (per WMI) mit `-Inselgroesse Normal -Rohstoffe Viele -Ureinwohner Viele -Gegner Schwer -Piratenflotte Riesig -Haendler Viele -Piraten Stark -Startgeld 50000 -GegnerGeld 60000 -Einwohner 5 -Turbo -TurboStufe 16 -Produktion 2 -Lager 5 -Schiffstempo 2 -Laderaum 3`; alle 26 Stellen gesetzt. Neues Endlosspiel „Durchschnittlich“ (Schwierigkeit 1), 16-fach:
- **50 Inseln** belegt, **14 Eingeborenendörfer** (7 + 7, Original 2 + 2), Gold 50'000 / 60'000 × 3.
- Händler: 2 → 15 (15 Siedlungen) → 18 (17) → 21 (19), jeweils genau `(n + 2) / 3 × 3`.
- Erste KI auf Stufe 2 nach etwa 6 Minuten; sofort erstes Piratenschiff.
- Kurz danach versenkten die Piraten (Stark) mein einziges Schiff. Ohne Siedlung ist das Spiel damit verloren (Bewertung, „Schiffe gesunken 1“). Spielende, kein Absturz. CPU 55–57 %, 437–493 MB.

**Spieltest 2 (B), 2026-11-11 18:24–18:34:** im selben Prozess `lastgame-1000x700-20261109-185329` geladen (Uhr 440'383, eigene Siedlung, KI-Stufen 2/2/4, 3 Piraten-, 8 Händlerschiffe), 16-fach:
- Piratenschiffe 3 → 4 → 6 → 8 → 9 → 10 → **12** (= Stufe 4 × 3; Original höchstens 4) in rund 5 Minuten.
- Händler 8 → 12 → **15** (13 Siedlungen: 5 × 3).
- 12 Piratenschiffe danach 5 Minuten unverändert: Die Grenze hält.
- Bei Angriffsmeldungen schaltet das Spiel selbst auf Tempo 1 zurück (F7 erneut drücken).
- Immer reagierend, 421–435 MB, CPU 54–58 % eines Kerns. Kein Absturz.
- Ende per Prozessende; das Werkzeug benannte den automatischen Spielstand in `lastgame-1000x700-20261111-183442.gam` um. `lastgame.gam` aus `Savegame-Sicherung-20261108-191850` zurückkopiert, Hash `B7C4BFB912C36597…` geprüft.
- Nebenwirkung: Die verlorene Partie aus Spieltest 1 hat die Endlos-Bestenliste `Highscore\[[48]].hss` geändert (18:23, 1'000 Punkte), wie schon am 2026-11-08.

**Paket:** `Dokumente\Anno1602-Erweiterungen.zip` neu gebaut und über `installieren.ps1` installiert; die installierten Dateien stimmen per Hash mit den Quellen überein. Die installierte Fassung findet mit den „Alles gross“-Werten alle 25 Stellen (`-NurPruefen`).

### Eigene Szenarien und Kampagne „Die Smaragdinseln“ (2026-11-11)

**Ort und Liste (B):** Die History Edition liest eigene Szenarien aus `Dokumente\Anno 1602 History Edition\Own Scenarios\*.szs` und zeigt sie in „Neues Spiel“ unter „Eigene Szenarien“ (Dateiname = Titel, drei Sterne). Im Spielordner liegt dazu der offizielle Editor `Anno1602Editor.exe` (Texte `Loca\de-DE\Editor.cod`: Missionsziele, Bevölkerungsziele für bis zu 3 Städte, Spieler besiegen, Gesamt-/Handelsbilanz, Monopol, Spieler unterstützen, Auftragstext). Keine Spieldatei muss geändert werden.

**Aufbau (B):** Abschnitte `SZENE_PLAYERMIN`, `SZENE_PLAYERMAX`, `SZENE_GAMEID`, `SZENE_RANKING`, `RANDTAB`, `AUFTRAG4`, `SZENE`, `PLAYER4`, `SHIP4`, `TIMERS`. Ohne `INSEL5` erzeugt der SZENE-Lader die Inseln aus der Inselliste, wie bei den Endlos-Vorlagen. Original-Missionen haben zusätzlich `SZENE_MISSNR` (Kampagnenfortschritt, Bestenliste).
- `PLAYER4`: 7 Einträge à 0x430 Byte (Lader `FUN_1400b1020`): +0 Gold, +4 Art (0 Mensch, 12 KI, 13 Händler, 14 Piraten, 11 Eingeborene), +5 Nummer, **+0x0C Auftragsplatz** (0xFF = keiner) → Spielertabelle +0x7C.
- `AUFTRAG4`: Einträge à 0x8C4 Byte (Lader `FUN_1400b1780` → Tabelle `0x1405ec720`, je 0x108C). Prüfung `FUN_1400ae010` (aus `FUN_1400af980`); erfüllt → Nachricht 0x3E → `FUN_1400b0000`: Sprachmeldung/Film aus +0x50, alle Spieler auf Art 9, Bewertung („Missionsbonus 100 %“).

| Datei-Offset | Bedeutung (Zielbit) |
|---|---|
| +0x00 | Platz in der Auftragstabelle |
| +0x04 | Zielbits (1/2/4 Stadt 1–3 setzt der Lader selbst) |
| +0x20 / +0x22 | Monopol: Rohstoff (0x2D Getreide, 0x2E Tabak, 0x2F Gewürze, 0x30 Zucker, 0x31 Baumwolle, 0x32 Wein, 0x33 Kakao …), Inselzahl – **wird beim Start ersetzt durch die Zahl aller Inseln mit diesem Rohstoff** (`FUN_1400ceea0`) (0x4000/0x8000) |
| +0x24 | zu unterstützender Spieler, 7 = beliebig (0x10, Ziel bei +0x8B8) |
| +0x2B / +0x2C…+0x32 | Zahl besiegter Gegner (0x200) / je Spieler „muss besiegt werden“ (0x400; besiegt = Art 9) |
| +0x40 / +0x44 / +0x4C | Zahl der Städte (0x20) / Einwohner gesamt (0x80) / Bilanz `FUN_1400ad5d0` (0x100) |
| +0x50 | Sprachmeldung bei Erfolg (Original 84–106) |
| +0x54 | **Handelsbilanz** ≥ Wert (0x10000): Verkaufserlöse − Einkaufskosten (Spieler +0x78 / 480 − +0x74 / 480), z. B. `[[111]]0`: 500. Die Bilanz bei +0x4C ist die des Statusfensters: Steuern + Verkäufe − Einkäufe − Betriebs- und Heereskosten (`FUN_1400ad5d0`, Ergebnis Feld 6) |
| +0x68 | Auftragstext, 0x800 Byte Windows-1252; `[[n]]` = Platzhalter für Spieltexte, sonst Klartext mit Zeilenumbrüchen |
| +0x868 / +0x86C | Warenbestand: Byte 0 Ware (Liste `[WARE]`: 12 Musketen, 13 Kanonen, 16 Gewürze, 21 Schmuck, 22 Werkzeug …), Bytes 2–3 Menge × 32 t (0x1000/0x2000) |
| +0x870 / +0x87C / +0x888 | Stadt 1–3: Einwohner gesamt, Stufe (0 Pioniere … 4 Aristokraten), davon mindestens (Zahl auf dieser Stufe oder höher) |
| +0x8AC | alle eigenen Städte mindestens (0x08) |

- Abgleich mit allen 44 Original-Aufträgen stimmig (z. B. `[[121]]` „Einführung“: 60 Einwohner, davon 40 Siedler, Bilanz ≥ 0; `[[130]]0`: Spieler 1–3 besiegen).
- SZENE-Fruchtbarkeit: Haus-Nr. = `Id` − 20000 aus `haeuser.cod`: 1332 Baumwolle, 1336 Tabak, 1338 Kakao, 1340 Zucker, 1342 Gewürze, 1344 Wein; Rohstoffcode = Byte +0x21 des Gebäudes (Namensliste in der exe ab `GETREIDE` = 0x2D).

**Prototyp (B), 2026-11-11 ohne Werkzeug:** „ZZ Test Stadt“ erschien in der Liste; Auftragstext mit Zeilenumbruch und Umlauten angezeigt; im Speicher Auftragsplatz 0, Zielbits 0x101, Stadt 150/1/100. „ZZ Test Sofortsieg“ (Bilanz ≥ −1'000'000) endete sofort mit der Bewertung, Missionsbonus 100 %. Testdateien danach gelöscht.

**Werkzeuge:** `tools/szenario-bauer.ps1` (Lesen/Schreiben von .szs, `Neuer-Auftrag`, `Setze-Inseln`), `tools/kampagne-bauen.ps1` (6 Kapitel aus den Endlos-Vorlagen: gespiegelte Anordnung, einzelne Inseln eine Klasse grösser, Rohstoffmengen, Dörfer, Gold, Schwierigkeit, Piraten-Flag, Auftrag und Text; Prüfung auf Kartengrenzen und Überschneidungen). Ausgabe `tools/kampagne/`, mit `-Installieren` nach „Own Scenarios“.

**Kampagne:** Landung (Einfach) · Gewürzfieber (Monopol) · Zwei Kolonien · Schwarze Segel (Waffenlager, Piraten) · Der Eroberer (Spieler 1–3 besiegen) · Krone der Inseln (3 Städte, 1'200 Aristokraten, Schwer). Alle 6 offline entschlüsselt und geprüft (Ziele, Geometrie, Texte, Spielerdaten, Flags).
- **Im Spiel (B):** Alle 6 Kapitel in der Liste. Kapitel 2 geladen: 18 Inseln, Gewürze auf 4 Inseln, 4 Dörfer, Gold 25'000 × 4, Auftrag Monopol 0x2F (Inselzahl vom Spiel auf 4 gesetzt) + Stadt 500/2/250, Text mit Umlauten. Danach Gewürzmenge auf 2 gesenkt und Text auf „jede Gewürzinsel“ angepasst.
- Kapitel 1 im Spiel geladen (2026-11-11 21:50, ohne Werkzeug): 20 Inseln, 6 Dörfer, Gold 30'000/15'000 × 3, Schwierigkeit 0, Flags 0x9, Auftrag 250/1/150 + Bilanz. Kapitel 3–5 nicht einzeln geladen (gleicher Bauweg, `tools/pruefe-szenarien.ps1` prüft alle). Die Balance ist nicht durchgespielt.

### Grosse Kampagnenkarten, Wettlauf, Herausforderungen (2026-11-11, Nacht)

**Längerer SZENE-Abschnitt (B):** Ein SZENE-Abschnitt mit 2'360 statt 1'172 Byte (Testdatei „ZZ Test Lang“) lädt ohne Werkzeug normal; der Lader (`FUN_1400169e0` → `FUN_1400d0de0`) liest die ganze Länge ein, wertet aber nur die festen Offsets aus.

**Grosse Fassung (Umsetzung):** Hinter dem normalen Block: +0x494 `'GROS'`, +0x498 Breite, +0x49C Höhe der Auslegung, +0x4A0 Version, ab +0x4A4 ein vollständiger zweiter SZENE-Block. Am Haken des SZENE-Laders ist RCX = Abschnittskopf (Name, +0x10 Länge). Das Inselverteilungs-Codestück ruft zuerst ein neues Codestück bei RVA `0xE5E40` (200 Byte) auf: Länge ≥ 2'360, Kennung, Auslegung ≥ 100 und Kartengrösse ≥ Auslegung → grossen Block nach vorne kopieren, Positionen mit Breite/Auslegung strecken, `eax = 1` → fertig. Sonst normaler Weg (Tabelle, Strecken). Nicht bei `-NurStrecken` und `-OhneInselVerteilung`.
- Offline-Fall Z: 1000 × 700 → grosse Fassung (50 Inseln, Dörfer 5); 2000 × 1400 → dieselbe, × 2; 750 × 525 und 500 × 350 → kleine Fassung gestreckt; falsche Kennung oder 10 Byte zu kurz → kleine Fassung. Gesamt **429 von 429**.
- `kampagne-bauen.ps1` erzeugt die grosse Fassung mit dem Inselplaner des Werkzeugs (`Inselplan`, je Kapitel Normal/Gross/Riesig), Rohstoffe × Inselzahl, 5–6 Dörfer je Klimazone.
- **Im Spiel (B):** Kapitel 6 mit Werkzeug („Alles gross“): Welt 1000 × 700, **47 Inseln** (37 × 70×60, 10 × 100×90), 12 Dörfer, 53 Erzvorkommen auf 45 Inseln, 228 Fruchtbarkeiten, Auftrag unverändert. Die Gold-Optionen des Werkzeugs (Uhr < 1000) überschreiben auch das Startgold der Szenarien.

**Wettlauf (B):** Haben die Computergegner denselben Auftragsplatz (PLAYER4 +0x0C) und das Zielbit 0x800, prüft `FUN_1400af980` auch sie. Erfüllt ein Gegner den Auftrag, schickt das Spiel Nachricht 0x3E; `FUN_1400b0000` zeigt dem Menschen Meldung 0x53 und beendet die Partie.
- Im Spiel: „Wettlauf 2“ mit Werkzeug: Auftragsplatz 0/0/0/0, Spielerart 0/12/12/12, Zielbits 0x803, 50 Inseln, 10 Dörfer.
- Testszenario mit eigenem, sofort erfülltem Auftrag nur für die Gegner (Platz 1, Bilanz ≥ −1'000'000, 0x800): Partie endet sofort mit der Bewertung, Missionsbonus 0 %, kein Absturz. Testdatei gelöscht.
- **Prüfzeitpunkt:** `FUN_1400af980` zählt die Spielzeit (`DAT_1405aa338`, Schwelle 5'000) und erhöht dann eine Periode (`DAT_1405a5075`, 0–7). Jeder Spieler wird einmal je Periode geprüft (Spielertabelle +0x6A merkt die letzte Periode), Computergegner (Art 11–14) nur, wenn `DAT_1405f2188` ≠ 0 (im Einzelspiel 1). Stadtziel in `FUN_1400ae010`: Einwohner gesamt = Stadt +0x218 + 0x220…0x230; „davon mindestens“ zählt die Stufe und alle höheren (+0x220 Pioniere, +0x224 Siedler, +0x228 Bürger, +0x22C Kaufleute, +0x230 Aristokraten).
- **Natürlicher Wettlauf (B), 2026-11-11 23:06–23:45:** „Wettlauf 1 – Erster Hafen“ (grosse Fassung, Werkzeug mit Turbo 16, Mensch baut nichts). Die Gegner (Schwierigkeit 0, 20'000 Gold) gründen je 2 Städte und bleiben lange auf der Siedler-Stufe; Gold fällt auf 4'000–6'500. Gegner 1 erreicht in Barlin 301 Einwohner (201 Siedler und höher, davon 42 Bürger) bei Spieluhr 351'398 (≈ 39 min mit 16-fach, ≈ 10 Stunden normales Tempo). Danach alle Spieler Art 9, Sperre `DAT_1405ebf68` = 1, Uhr steht; nach einem Klick Bewertung mit Missionsbonus 0 %, Summe 0. „Hauptmenü“ funktioniert. Ein Mensch schafft 300 Einwohner in einer Stadt deutlich schneller; Kapitel 1 ist damit wie vorgesehen „Einfach“.
- **Messung Wettlauf 3 (B), 2026-11-12 00:14–00:43:** Erster Versuch abgebrochen: In „Wettlauf 3“ (Piraten aktiv) versenkten die Piraten nach rund 4 Spielstunden das einzige Schiff des untätigen Menschen → Mensch Art 9, Bewertung „Gesunken 1“ (normales Spielverhalten, kein Szenariofehler). Zweiter Versuch mit Testkopie, Piraten nur gesichtet (TIMERS +0xA8 Bit 0), Schwierigkeit 2, Gegnergold 35'000, grosse Fassung (47 Inseln). Umrechnung: ca. 32'700 Uhr-Einheiten je Stunde bei normalem Tempo (Dauerlauf: 523'094 in 60 min mit 16-fach).

  | Ziel (eine Stadt) | erreicht von | Spieluhr | ≈ normale Spielzeit |
  |---|---|---|---|
  | 300 Einw., 150 Siedler+ | Gegner 1, nach 13 min | 119'376 | 3,7 h |
  | 500 Einw. | Gegner 1, nach 15 min | 138'616 | 4,2 h |
  | 700 Einw., 350 Bürger+ (erste Kaufleute) | Gegner 1, nach 26 min | 236'754 | 7,2 h |
  | 1'000 Einw., 400 Kaufleute+ → **Wettlauf verloren** | Gegner 3 (1'000, davon 750 Kaufleute), nach 29 min | 265'261 | 8,1 h |

  Die zweiten Städte der Gegner wachsen kaum (200–290 Einwohner nach 8 h). Der Sprung Bürger → Kaufleute geht bei den Gegnern sehr schnell (Gegner 3: 592/405 Bürger → 1'000/750 Kaufleute in 10 min). Partie danach korrekt beendet (alle Art 9, Bewertung 0 %).
- **Messung Wettlauf 4 (B), 2026-11-12 00:45–02:15:** Testkopie, Piraten nur gesichtet, Schwierigkeit 3, Gegnergold 45'000, grosse Fassung (50 Inseln). Beste Stadt (Gegner 2): 4,2 h 628 (450 Bürger) · 8,7 h 999 (600 Kaufleute) · 14,2 h 1'240 (875 Kaufleute) · **19,8 h 1'504 (947 Aristokraten)** · 22,6 h 1'602 (1'115 Aristokraten) · 25,3 h 1'609. Danach pendelt sie 6 Spielstunden lang zwischen 1'533 und 1'609; Gold der Gegner 4'000–12'000. Das alte Ziel 2'000/600 erreicht kein Gegner. Die zweiten Städte bleiben bei 245–281 Einwohnern mit genau 144 Siedlern stehen; ab ~8 h gründen die Gegner kleine dritte Siedlungen (< 130).
- **Gegner-Bilanz geprüft (B):** Autosave des Laufs (Spieluhr 799'622) kopiert, nur das Stadtziel im AUFTRAG4-Abschnitt von 2'000 auf 1'500 geändert (2 Byte), mit Werkzeug geladen: Partie sofort beendet, alle Art 9, Bewertung 0 % → Gegner 2 erfüllt 1'500/600 Aristokraten **und** Bilanz ≥ 500. Testspielstand danach gelöscht.
- **Anpassungen danach (`kampagne-bauen.ps1`):** neuer Schlüssel `KI` setzt nur TIMERS +0xA6 (= Schwierigkeit, im Spiel `0x1405ec1c0`; die Endlos-Vorlagen unterscheiden sich sonst nur in Zufalls-Timern und Flags), Karte bleibt gleich. Wettlauf 1: KI 1 (vorher 0; im Spiel geprüft: Schwierigkeit 1). Wettlauf 2: KI 2, zweite Stadt 250/100 Siedler statt 300/150 (für Gegner sonst unerreichbar). Wettlauf 4: 1'500/600 Aristokraten + Bilanz 500 statt 2'000/600. Übrige 10 Szenarien Byte für Byte unverändert; `pruefe-szenarien.ps1`: alle in Ordnung.
- **Nachmessung neuer Wettlauf 1 (B), 02:21–02:40:** installierte Datei, Schwierigkeit 1 im Speicher bestätigt. Gegner 1 erreicht 300 Einwohner (156 Siedler, 42 Bürger) nach 17–18 min mit 16-fach, Spieluhr ≤ 166'644 ≈ **5 h** (vorher 10,7 h); Partie endet korrekt.
- **Neuer Wettlauf 2 (B), 02:41–03:18:** Schwierigkeit 2, Zielbits 0x803, Stadt 1 700/2/350, Stadt 2 im Speicher 250/1/100 (Tabelle +0x1050). Gegner 3 gewinnt nach 37 min mit 16-fach (Spieluhr ≤ 312'366 ≈ 9,6 h), als seine zweite Stadt 251 Einwohner erreicht (Hauptstadt längst 1'117, davon 925 Kaufleute). Weil die zweiten Städte der Gegner bei 187–290 Einwohnern stehen bleiben, ist 250 zu knapp: **zweite Stadt jetzt 200/100** (mit diesem Wert hätte Gegner 3 nach ≈ 7,6 h gewonnen: 737 Einw./564 Bürger+ und zweite Stadt 207). Neu gebaut, geprüft, installiert.
- **Ladeprüfung bisher ungeladener Szenarien (B), 03:15–03:40, grosse Fassung mit Werkzeug:** Smaragdinseln 3 (47 Inseln, Bits 0x103, Stadt 800/3/300 + 500/2/250, Bilanz 300, Gegner ohne Auftrag 255), Smaragdinseln 4 (50 Inseln, Bits 0x3001, Stadt 1'000/3/500, 20 t Kanonen + 40 t Musketen, Piraten aktiv, Begleitschiff „Wehrhaft“ mit 8 Kanonen), Goldrausch (47 Inseln, Bits 0x3000, 60 t Gold + 40 t Schmuck, Piraten aktiv, „Goldwächter“ mit 8 Kanonen, Name im Speicher korrekt in Windows-1252), Handelsimperium (50 Inseln, Bits 0x13000, Handelsbilanz 300, 50 t Schmuck + 80 t Kleidung), Inselreich (50 Inseln, Bits 0xA0, 8 Städte, 3'000 Einwohner gesamt, Gold 40'000/25'000). Alle mit Auftragsplatz 0 für den Menschen. Damit sind alle 13 Szenarien mindestens einmal im Spiel geladen.
  - Auftragstabelle im Speicher (je 0x108C): +0 Zielbits, +0x08 Unterstützer, **+0x1C Städte (`param_2[7]`), +0x28 Einwohner gesamt (`param_2[10]`)**, **+0x30 Bilanz (`param_2[0xc]`), +0x34 Handelsbilanz (`param_2[0xd]`), +0x38 Sprachmeldung**, Text ab +0x3C, +0x103C/+0x1040 Waren (Byte Ware, ab +2 Menge ×32), +0x1044/+0x1050/+0x105C Stadt 1–3.
- **Zusammenfassung Wettlauf (Gegner ohne Zutun des Menschen, grosse Fassung):** Kapitel 1 ≈ 5 h · Kapitel 2 ≈ 7,6 h · Kapitel 3 ≈ 8 h (ohne Piratenangriffe) · Kapitel 4 ≈ 20 h. Alle vier Rennen sind damit verlierbar, aber für einen zügigen Spieler gut zu gewinnen.

**Startschiffe (B, Fehler gefunden und behoben):** Die Startpositionen der Schiffe (SHIP4, Einträge à 0x1B4 Byte: Name, +0x1C/+0x1E x/y als int16, +0x3C Laderaum ×32, +0x42 Kanonen, +0x46 Platz, +0x48 Figurtyp, +0x4B Besitzer, Ladung ab +0x174; Lader `FUN_14008e4f0`) werden vom Werkzeug **nicht** gestreckt, die Inseln schon.
- Endloswelt: Bei Anordnung 2 und 1000 × 700 (Normal, Riesig) lag eine Insel (50×52 bei 80/267) über dem Startpunkt 80/270; bei 750 × 525 Gross/Riesig in allen drei Anordnungen ähnlich. Ein erster Prüfblick hatte das übersehen (Liste ohne Komma-Operator, dadurch keine Treffer).
- Umsetzung: `Inselplan` bekommt die Startpunkte (`Lies-Schiffe`, aus `[[48]]1<Anordnung>.szs`) und vergrössert oder setzt keine Insel mit weniger als 2 Feldern Abstand dazu. Die Pläne für 1000 × 700 Anordnung 0/1 und alle für 2000 × 1400 bleiben Byte für Byte gleich; Anordnung 2 (1000 × 700 Normal/Riesig) und einige 750 × 525-Pläne ändern sich. Offline-Fall T prüft jetzt alle 27 Pläne (3 Grössen × 3 Inselgrössen × 3 Anordnungen): **456 von 456**.
- Kampagnen: Die Inseln sind gespiegelt bzw. neu geplant, die Schiffe nicht. In 10 von 13 Szenarien lag mindestens eine Fassung mit Schiffen in einer Insel. `kampagne-bauen.ps1` sucht jetzt je Szenario einen Wasserpunkt, der in allen sechs Fassungen (klein × 1/1,5/2/4, gross × 1/2) 10 Felder Abstand zu jeder Insel hat, möglichst nah am Startpunkt der Vorlage, und versetzt alle vier Schiffe dorthin. `pruefe-szenarien.ps1` prüft das für alle 13: frei.

**Startflotte:** Zusätzliche Schiffe für den Menschen = Kopie seines SHIP4-Eintrags mit neuem Namen, Platz (+0x46 = nächster), Figurtyp (+0x48: 23 grosses Handelsschiff, 25/27 kleines/grosses Kriegsschiff), Laderaum (+0x3C: 2'560/2'080/3'840) und voller Kanonenzahl (+0x42: 10/8/14; Kanonen = Schiff +0x2AE, vgl. Nachricht 0x19), ohne Ladung, 7–9 Felder neben dem Startpunkt (Startpunkt dafür 14 Felder von jeder Insel). Schwarze Segel und Goldrausch: kleines Kriegsschiff; Eroberer: grosses Kriegsschiff; Krone: grosses Handelsschiff.

**Starter:** Knopf „Für Kampagnen“ (1000 × 700, mehr Inseln, Turbo 16-fach, Gold „Wie Schwierigkeit“, sonst Standard). Hinweis auf die eigenen Szenarien im Kopf des Fensters.

**Dauerlauf (B), 2026-11-11 21:57–22:57:** Spielstand `lastgame-1000x700-20261111-183442` mit allen „Alles gross“-Optionen (u. a. Gegner Schwer, Piraten Aktiv, Flotte Gross, Händler Viele, Turbo 16), F7; Messskript sendet bei Tempo 1 per `PostMessage` F7 (`WM_KEYDOWN` 0x76, wirkt). 60 von 60 Messungen reagierend, 429–491 MB ohne Anstieg, Spieluhr 464'523 → 987'617 = **14,5 Spielstunden**, F7 zehnmal automatisch. Gegner bauen ihre 2–4 Städte aus (2'201/1'604/2'606 Einwohner, Gold bis 2,3 Mio.), gründen aber keine neuen; Piraten 9 Schiffe, Händler 15.

**Im Spiel nach den Korrekturen (B):** „Der Eroberer“ (grosse Fassung): eigenes grosses Kriegsschiff „Königsadler“ auf Platz 4, Figurtyp 27, 14 Kanonen, neben dem Startschiff; 50 Inseln. „Wettlauf 4“ (grosse Fassung, vorher Schiffe in einer 100×90-Insel): alle Schiffe im offenen Wasser.

**Szenarien jetzt (13):** Smaragdinseln 1–6, Wettlauf 1–4 (Erster Hafen, Bürgerstolz, Kaufmannsrepublik, Die Krone; Ziele 300/150 Siedler bis 1'500/600 Aristokraten, nach Messung angepasst, siehe oben), Herausforderungen Inselreich (8 Städte, 3'000 Einwohner gesamt), Handelsimperium (50 t Schmuck, 80 t Kleidung, Handelsbilanz +300), Goldrausch (60 t Gold, 40 t Schmuck). `tools/pruefe-szenarien.ps1` prüft alle: Abschnitte, Auftrag, Wettlauf-Einstellung, beide Karten (Grenzen, Überschneidungen), Rohstoffe, Dörfer, Gold, Flags.

### Langlauf alle Optionen (B), 2026-11-09 08:52 – ca. 19:00, ausgewertet 2026-11-10

- Werkzeug mit `-Piraten Stark -Schiffstempo 2 -Startgeld 50000 -Lager 3`, 1000 × 700, Anordnung 0 (43 Inseln). Die Testsitzung brach danach mit einem Verbindungsfehler der Claude-App ab; das Werkzeug endete mit Exit 4, ohne `lastgame.gam` umzubenennen.
- **Bilder `30-alle-optionen-langlauf-030min` … `210min` sind byteidentisch** (gleicher SHA-256). Das ist ein Aufnahmefehler (Fenster im Hintergrund, `PrintWindow` liefert das alte Bild), kein Hänger: Das Spiel schrieb weiter automatische Spielstände, zuletzt `lastgame.gam` um 18:53:29.
- Dieser letzte Spielstand (jetzt `lastgame-1000x700-20261109-185329.gam`): Spieluhr 440'208 (zum Vergleich 38'543 beim Optionstest um 08:22), 43 Inseln bis x 947 / y 628.
- Wachstum gegenüber 08:22 (Abschnittsgrössen im Spielstand): `SHIP4` 3'052 → 10'900 Byte, `KONTOR2` 7'028 → 13'052 (7 → 13 Kontore), `PRODLIST2` 1'512 → 7'392, `SIEDLER` 1'152 → 3'168. **Kein Absturz in rund 10 Stunden.**
- **Pool `ROHWACHS2`:** 2'032 von 262'512 Plätzen belegt (0,8 %).
- **F** Ein Volllaufen der festen Pools ist bei 1000 × 700 auch über viele Stunden nicht zu erwarten.
- **Lager:** `KONTOR2` = je Kontor 4 Byte Kopf + 50 Waren à 20 Byte (Aufbau wie mdcii-engine `KontorGood`, Bestand `lager` uint32 in 1/32 t bei +12).
  - Bestände über 30 t gibt es auch in normalen Spielständen ohne Werkzeug (`savegame-17.gam` bis 350 t), weil Markthäuser und Kontorstufen die Grenze der Stadt erhöhen.
  - **F** Aus Spielständen lässt sich die Lager-Option deshalb nicht belegen. Belegt bleibt: Der Grenzwert eines neu gebauten Kontors steht im Speicher auf 2'880 (90 t) statt 960 (siehe „Spieltest alle Optionen“).
- **Aufräumen 2026-11-10:**
  - `lastgame.gam` (Test, 18:53) umbenannt in `lastgame-1000x700-20261109-185329.gam`.
  - Den Stand vor allen Tests (10.04.2023, SHA-256 `B7C4BFB9…62FE`) aus `Savegame-Sicherung-20261108-191850` zurückkopiert und per Hash geprüft.
  - Sicherungsordner: 13 Stück, zusammen 174 MB.

### Langlauf „Schwer“ (B), 2026-11-09 07:45–08:10

- 1000 × 700, Anordnung 0 (43 Inseln), Spiel im Vordergrund (Überwachung holt es jede Minute nach vorne), vierfach.
- 25 Minuten: immer reagierend, 433–494 MB, automatische Spielstände 07:55:58 und 08:05:58. Alle drei KI siedeln im **neuen** Bereich (Gelb unten links, Blau unten rechts, Weiss oben rechts). Flags 0x8, noch keine Piratenschiffe. Beleg `25-schwer-langlauf-30min*.png`.
- Abgebrochen zugunsten des Spieltests der Optionen; danach Langlauf mit Optionen (siehe unten).

### Experiment: `tools/weltgroesse.ps1`

Setzt die Kartengrösse im Speicher des laufenden Spiels (Standard 1000 × 700). Es ändert keine Dateien.
Fassung vom 2026-11-08: 8 Code-Stellen und 5 Variablen (Breite, Höhe, Scrollbereich, 1/Breite, 1/Höhe; Tabelle oben).

Ablauf: exe prüfen (SHA-256, Original-Bytes an allen 8 Stellen) → Savegame-Ordner sichern → auf `Anno1602.exe` warten → im Speicher alle 8 Stellen und 5 Variablen prüfen (Variable muss 0, Original oder Zielwert sein) → Code-Stellen schreiben, jede nachlesen; bei einem Fehler die schon geschriebenen zurückbauen → warten, bis das Spiel seine Startwerte gesetzt hat (1/Höhe ≠ 0), dann die 5 Variablen setzen und nachlesen.

Neu gegenüber der ersten Fassung:
- Scrollbereich und 1/Breite, 1/Höhe werden mitgesetzt (Fehler oben, Abschnitt Kamera).
- Startreihenfolge: Die erste Fassung setzte die Variablen sofort. Fand sie das Spiel, bevor `FUN_1400dbc60` lief, überschrieb das Spiel danach 1/Breite und 1/Höhe wieder mit 1/500 und 1/350 (die kommen aus `.rdata`, nicht aus einem Sofortwert). Jetzt wartet das Werkzeug auf die letzte Startzuweisung.
- Selbsttest: Die Formeln müssen bei 500 × 350 genau die Original-Bytes ergeben, sonst Abbruch.
- Schutz: Läuft das Spiel schon länger als 2 Minuten mit anderer Breite, bricht das Werkzeug ab (in einer schon geladenen 500 × 350-Karte würden Raster und Grösse nicht mehr zusammenpassen). Mit `-SpielLaeuftBereits` übergehbar, wenn das Spiel sicher im Hauptmenü steht.
- Eine andere Grösse im selben, schon gepatchten Spielprozess wird abgelehnt („unerwartete Bytes“); dafür das Spiel neu starten.
- Inselverteilung (Sprung + Codestück, siehe „Inseln verteilen“), abschaltbar mit `-OhneInselVerteilung`.
- Sicherung ohne Doppel: Der Savegame-Ordner wird nur gesichert, wenn er sich seit der letzten `Savegame-Sicherung-*` geändert hat (Vergleich von Pfad, Grösse und Änderungszeit aller Dateien). Getestet: erster Lauf sicherte, zweiter meldete „unverändert“.
- Schutz für „Spiel fortsetzen“: Das Werkzeug bleibt offen, bis das Spiel endet. Hat das Spiel in der Sitzung `lastgame.gam` geschrieben, wird sie in `lastgame-<Breite>x<Hoehe>-<Zeit>.gam` umbenannt (in der Ladeliste weiter sichtbar). Abschaltbar mit `-OhneLastgameSchutz`. Grund: Das Spiel überschreibt `lastgame.gam` automatisch (im Test um 19:43, 20:26, 21:06, 21:26) und beim Beenden über „Ende“.
- Startdatei `tools/anno-grosse-welt.cmd`: startet das Werkzeug in einem eigenen Fenster (bleibt offen) und danach das Spiel über `uplay://launch/16236/0`; weitere Angaben wie `-Breite 750 -Hoehe 525` werden durchgereicht. Pause per `ping` statt `timeout` (das bricht ohne Konsoleneingabe ab).
- Getestet im Spiel (B): Startdatei dreimal benutzt, jedes Mal Neustart abgefangen und Werte gesetzt. Schutz für „Spiel fortsetzen“ zweimal ausgelöst: `lastgame.gam` (21:45:26 bzw. 21:59:11 vom Spiel geschrieben) nach Spielende in `lastgame-1000x700-20261108-214721.gam` bzw. `…-220145.gam` umbenannt.
- Neustart des Spiels (nach dem Spieltest ergänzt): Der erste `Anno1602.exe`-Prozess beendet sich nach dem Start über Ubisoft Connect sofort wieder, ein zweiter startet. Die vorige Fassung patchte den ersten, scheiterte dann mit „Lesen bei RVA 0x5EBC80 fehlgeschlagen (Fehler 299)“, und der zweite lief ungepatcht. Jetzt erkennt das Werkzeug das Ende (`GetExitCodeProcess`) und wartet auf den nächsten Prozess.

### Testlauf 2026-11-08

**Auflösung (B):** 3 Monitore, alle 2560 × 1440 (Hauptmonitor `DISPLAY5`, RTX 4090, 143 Hz). Registry `HKCU\Software\Ubisoft\Anno1602HistoryEdition` vorher: `SCREENMODE` = 2560, `SCREENMODEY` = 1440, `WINDOW_MODE` = 2, `UI_SCALE` = 1000, `MONITOR_INDEX` = 0, `VSYNC` = 1. Das Spiel steht also schon auf WQHD, passend zum Monitor; es lief im Spiel mit 2560 × 1440 im Vollbild. Nichts geändert (nachher = vorher).

**Offline-Test (B):** `tools/test-weltgroesse.ps1` lädt die exe-Kopie `analysis/bin/Anno1602.exe` in einem Hilfsprozess nur als Abbild (`LoadLibraryEx` mit `DONT_RESOLVE_DLL_REFERENCES`: Sektionen an Ladeadresse + RVA mit den echten Speicherrechten, kein Spielcode läuft, keine DLL wird geladen) und lässt das Werkzeug dagegen laufen. Ergebnis mit der Endfassung: **93 von 93 Prüfungen bestanden.**

| Fall | Erwartet | Ergebnis |
|---|---|---|
| vorher | alle 8 Stellen original, `.rdata` 1/500 und 1/350, Variablen 0 | ok |
| A: Spiel startet noch | Werkzeug patcht Code und wartet; nach nachgespieltem Programmstart stehen alle 5 Variablen auf 1000 / 700 / 850 / 1/1000 / 1/700 | ok, Exit 0 |
| B: zweiter Lauf, gleiche Grösse | läuft durch, nichts ändert sich | ok, Exit 0 |
| C: 750 × 525 gegen schon gepatchten Prozess | Abbruch „unerwartete Bytes“, nichts geändert | ok, Exit 1 |
| D: eine Code-Stelle verfälscht | Abbruch, die 7 anderen Stellen und alle Variablen unverändert | ok, Exit 1 |
| E: 750 × 525, Spiel schon gestartet | Code und Variablen 750 / 525 / 637 / 1/750 / 1/525 | ok, Exit 0 |
| F: Prozess endet, während das Werkzeug wartet | Werkzeug erkennt das Ende, statt mit Lesefehler abzubrechen | ok, Exit 1 („Testprozess hat sich beendet“) |

**Spieltest (B), 19:18–19:52.** Freigabe für die Bildschirmsteuerung im dritten Anlauf erteilt (vorher zweimal abgelehnt). Ablauf: Werkzeug im Hintergrund, Spiel über `uplay://launch/16236/0`, Endlosspiel „Durchschnittlich“ (gelegentlich Piraten), Spielername vorgegeben, Flagge Rot. Belege in `analysis/test/` (Aufnahmen nur des Spielfensters, 2560 × 1440). Kamera und Weltgrösse wurden zusätzlich nur lesend aus dem Speicher gelesen (Kamera-Struktur über `PTR_DAT_1400f9a00`).

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Werkzeug greift beim echten Spielstart | Erst **nein**: Der erste Prozess beendete sich nach dem Patchen, der zweite lief ungepatcht (Fehler 299 beim Warten). Behoben (siehe oben), danach zweimal **ja**: „Aktuelle Kartengroesse im Spiel: 1000 x 700“, Scrollbereich 850. Im Speicher nach Spielstart nachgelesen: 1000 / 700 / 850 / 1/1000 / 1/700. | Ausgabe des Werkzeugs |
| Neues Endlosspiel startet, kein Absturz | ja | `01-start-1000x700.png` |
| Minikarte zeigt grössere Welt | ja: Sichtrahmen entsprechend kleiner, Karte reicht bis 1000 × 700 | `02-minikarte-start.png` |
| Inseln auch im neuen Bereich | **nein**: alle 18 Inseln im alten Bereich (feste Positionen der Vorlage, siehe „Inseln im Endlosspiel“) | `02-minikarte-start.png` |
| Klick in die Minikarte erreicht den neuen Bereich | ja: Kamera Welt (784, 590), Scroll t = 687 > 425 | `03-minikarte-klick-neuer-bereich.png` |
| Pfeiltasten über die alte Grenze hinaus | ja: s stieg von 447 weiter (mit der alten Grenze wäre die Kamera auf 425 zurückgesprungen) und schlug erst bei s = 849 an, Kamera am rechten Weltrand x = 998 | `04-pfeiltasten-anschlag-rechts.png` |
| Rand-Scrollen mit der Maus | **nicht geprüft**: Die künstliche Mausbewegung an den Bildschirmrand löste kein Scrollen aus (auch nicht in den alten Bereich). Wahrscheinlich Einstellung `RIGHT_CLICK_SCROLLING` = 1 oder die Eingabeart; der Code dafür (`FUN_1400dd190`) nutzt dieselbe Grenze wie die Pfeiltasten. | – |
| Schiff fährt in den neuen Bereich | ja: eigenes Schiff bei Welt ≈ (446, 586), Ziel erreicht | `06-…`, `07-schiff-am-ziel-446-586.png` |
| Minikarten-Markierung des Schiffs | ja: Punkt liegt im Sichtrahmen an der richtigen Stelle (Massstab 1/Breite, 1/Höhe stimmt) | `05b-…`, `08b-minikarte-nach-7-minuten.png` |
| Kontor im neuen Bereich | **nicht möglich**: dort gibt es keine Insel | – |
| KI und Piraten, ca. 7 Minuten | KI hat drei Inseln besiedelt (Markierungen orange, weiss, blau); ein fremdes Schiff fuhr im neuen Bereich. Kein Absturz, Spiel reagierte. Piratenangriffe in der kurzen Zeit nicht gesehen. | `08-fremdes-schiff-im-neuen-bereich.png`, `08b-…` |
| Speichern in neuen Platz | ja: Symbol „neuer Spielstand“, Name `Welt1000x700` → `Welt1000x700.gam` (395'966 Byte). Kein bestehender Platz überschrieben (`savegame-10.gam` nach einem Fehlklick geprüft: unverändert). | `09-gespeichert-Welt1000x700.png` |
| Spiel beenden, mit Werkzeug neu starten, laden | ja: Neustart wieder abgefangen (PID 49004 → 15116), Spielstand geladen, Inseln, KI-Markierungen und Schiff (Welt 468, 580) wie gespeichert; Schiff nimmt neue Befehle an. | `10-geladen-nach-neustart.png`, `10b-…`, `11-…` |

**Nebenwirkungen (B):**
- Sicherungsordner in `Dokumente\Anno 1602 History Edition` (Stand 23:22): `Savegame-Sicherung-20261108-191850` (**unberührter Stand vor allen Tests**), `-193116`, `-194810`, `-201331`, `-211505`, `-213348`, `-214753`, `-220202`, `-220500`, `-221910` (zusammen gut 100 MB). Ausser dem ersten können alle gelöscht werden. Neue entstehen nur, wenn sich der Ordner geändert hat (bei den Tests war das jedes Mal der Fall, weil ich `lastgame.gam` zurückkopiert habe).
- Test-Spielstände im Savegame-Ordner: `Welt1000x700.gam` (grosse Welt ohne Inselverteilung), `game20.gam` (17 Inseln gestreckt), `game22.gam` (48 Inseln), vom Schutz umbenannte automatische Spielstände `lastgame-1000x700-20261108-214721.gam`, `…-220145.gam`, `…-232148.gam` und `lastgame-2000x1400-20261108-221745.gam` (nur mit `-Breite 2000 -Hoehe 1400` laden). Alle nur mit aktivem Werkzeug laden.
- Das Spiel überschreibt beim Spielen `lastgame.gam` („Spiel fortsetzen“). Nach jedem Testlauf habe ich den Stand von vor dem Test (10.04.2023, 621'498 Byte, Hash `B7C4BFB9…`) aus der ersten Sicherung zurückkopiert und per Hash geprüft (zuletzt 23:22).
- Bestenliste `Highscore\[[48]].hss`: einmal um 19:51 durch das Beenden über „Ende“ geändert (Eintrag mit 0 Punkten, Schwierigkeit „Durchschnittlich“); danach nur noch per Prozessende beendet, keine weitere Änderung.
- Der erste Startversuch hat über „App öffnen“ der Bildschirmsteuerung eine zweite Spielinstanz direkt gestartet; beide Instanzen (ohne geladenes Spiel) wurden beendet. Für den Start daher nur `uplay://launch/16236/0` verwenden.

**Gefolgert (F):**
- Das Werkzeug funktioniert im echten Spiel: Grösse, Kamera-Grenze und Minikarten-Massstab wirken, Speichern und Laden in der grossen Welt gehen, in gut 10 Minuten Spielzeit kein Absturz.
- Praktisch brachte die grössere Welt im Endlosspiel so noch nichts, weil der neue Bereich leeres Meer blieb. Behoben mit der Inselverteilung (Abschnitt „Inseln verteilen“).

**Offen (?):**
- ~~Inseln im neuen Bereich~~ erledigt (Inselverteilung). Offen: mehr Inseln als die 18 der Vorlage (bis 50 Plätze im `SZENE`-Abschnitt und in der Inseltabelle).
- ~~Speichern und Laden eines Spiels mit verteilten Inseln~~ erledigt (`game20.gam`, 17/17 Inseln gleich).
- Eigenen Kontor bauen: scheitert im alten wie im neuen Bereich gleich, also kein Problem der Weltgrösse; Bedienweg offen.
- Längeres Spiel: Pools mit fester Kapazität (z. B. `ROHWACHS2`), Wegfindung über weite Strecken, KI-Ausbreitung, Piratenangriffe.
- Rand-Scrollen mit der Maus von Hand prüfen.
- Rückbau nach einem Schreibfehler mitten im Patchen ist programmiert, aber nicht ausgelöst.

## Spieler und Parteien

- **B** `FUN_1400a87f0` initialisiert eine Tabelle mit **7 Plätzen à 640 Byte** ab `0x1405f0960`:
  - Plätze 0–3: Spieler (Startgeld 10'000)
  - Platz 4: freier Händler `Trader%d` (1'000'000)
  - Platz 5: Piraten `Pirat%d` (50'000)
  - Platz 6: Eingeborene `Native%d` (5'000)
- **B** Dazu eine zweite Tabelle mit **4 Einträgen à 4'236 Byte** ab `0x1405ec720` (nur für die 4 Spieler).
- **B** Die Schleifen haben feste Zählerwerte (4 bzw. 7).
- **F** Mehr als 4 Spieler heisst: beide Tabellen vergrössern und die festen Nummern 4/5/6 für Händler, Piraten und Eingeborene verschieben. Das betrifft vermutlich viele Stellen (Farben, Diplomatie, Statistik, Spielstand).
- **B** Szenario-Kopf: `SZENE_PLAYERMAX` ist standardmässig 1 (Einzelspieler) bzw. 4 (Mehrspieler) (`FUN_1400d36f0`).

## .cod-Parser

- **B** `haeuser.cod` wird in `FUN_140090660` gelesen (kennt `MAXHAUS`, `Maxlager` …), `figuren.cod` in `FUN_140068f10` (kennt `MAXFIGUR`).
- **?** Was begrenzen `MAXHAUS` und `MAXFIGUR` genau (Grösse der Gebäude-/Figurentabellen)?

## Offene Fragen

- ~~Wo sitzen die KI-Entscheidungen?~~ Teilweise: Schleife über die Parteien `FUN_14003dc40` (KI Art 0xC, Piraten Art 0xE), Flotte/Kanonen `FUN_14003b7e0` (Abschnitt „Gegner und Piraten“).
- ~~Inselzahl-Grenze und Inseltabelle.~~ 50 Plätze (Abschnitt „Inseln im Endlosspiel“).
- **?** Lagergrösse: „Maxlager“ steht als 16-Bit-Wert × 32 bei Gebäudetabelle +0x30 (Parser `0x140091999`), wird aber nicht direkt per Adresse gelesen; wo das Spiel die Lagergrenze einer Stadt rechnet, ist offen. Ohne eigenen Kontor im Spiel nicht prüfbar.
