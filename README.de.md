# Anno 1602 – Erweiterungen

*[English version](README.md)*

Ein Fan-Projekt für **Anno 1602 History Edition** (Ubisoft Connect): grössere Welt, mehr Inseln,
stärkere Gegner, Turbo bis 16-fach und 13 eigene Szenarien mit Geschichte und Auftrag.

Das Werkzeug ändert **keine Datei des Spiels**. Es passt nur den Arbeitsspeicher des laufenden
Spiels an. Wird das Spiel beendet, ist alles wieder wie im Original. Nur für das Einzelspiel.

## Was es kann

| Option | Wirkung |
|---|---|
| Kartengrösse | bis 2000 × 1400 Felder (Original 500 × 350) |
| Inseln | bis 50 Inseln über die ganze Karte verteilt (das Maximum des Spiels) |
| Inselgrösse | Gross / Riesig: viel mehr grosse Inseln (bis 10 der grössten, 100 × 90) |
| Rohstoffe | Mehr: Erz, Gold, Fruchtbarkeit und Schätze passend zur Inselzahl; Viele: doppelt |
| Ureinwohner | 4 + 4 oder 7 + 7 Dörfer statt 2 + 2 |
| Freie Händler | doppelt oder dreimal so viele Händlerschiffe (höchstens 24) |
| Computergegner | immer wie „Schwer“, auch wenn du leichter spielst |
| Piraten | wie Schwierigkeit / greifen immer an / stark / keine; Flotte bis 12 Schiffe statt 4 |
| Gold | Startgold für dich und für die Gegner |
| Einwohner je Haus | ×1,5 bis ×5 |
| Produktion, Schiffstempo, Laderaum | ×1,5 bis ×3 |
| Lager je Ware | ×2 bis ×5 |
| Turbo (F7) | 8-, 12- oder 16-fache Geschwindigkeit |

Ein Startfenster bietet alle Optionen zum Anklicken, dazu die Knöpfe **„Alles gross“** und
**„Für Kampagnen“** (grosse Karte und Turbo, sonst wie im Original).

## Kampagnen und Herausforderungen

13 eigene Szenarien, im Spiel unter *Einzelspieler → Neues Spiel → Eigene Szenarien*. Jedes hat
eine klassische Karte (500 × 350) und eine grosse Fassung (1000 × 700, bis 50 Inseln).

| Szenario | Auftrag |
|---|---|
| **Die Smaragdinseln** 1 Landung | Stadt mit 250 Einwohnern (150 Siedler), Bilanz im Plus |
| 2 Gewürzfieber | Gewürzmonopol, 500 Einwohner (250 Bürger) |
| 3 Zwei Kolonien | 800 Einw. (300 Kaufleute) und 500 Einw. (250 Bürger), Bilanz +300 |
| 4 Schwarze Segel | 1000 Einw. (500 Kaufleute), 20 t Kanonen, 40 t Musketen, Piraten |
| 5 Der Eroberer | alle drei Rivalen besiegen, Piraten |
| 6 Krone der Inseln | 3 Städte, die grösste 2500 Einw. (1200 Aristokraten), Bilanz +1000 |
| **Wettlauf der Häuser** 1 Erster Hafen | 300 Einw. (150 Siedler) – die Rivalen haben denselben Auftrag |
| 2 Bürgerstolz | 700 Einw. (350 Bürger) und eine zweite Stadt mit 200 Einw. (100 Siedler) |
| 3 Kaufmannsrepublik | 1000 Einw. (400 Kaufleute), Piraten |
| 4 Die Krone | 1500 Einw. (600 Aristokraten), Bilanz +500, Piraten |
| **Herausforderung** Inselreich | 8 eigene Siedlungen mit zusammen 3000 Einwohnern |
| Handelsimperium | 50 t Schmuck und 80 t Kleidung im Lager, Handelsbilanz +300 |
| Goldrausch | 60 t Gold und 40 t Schmuck im Lager, Piraten |

Im Wettlauf gewinnt, wer den Auftrag zuerst erfüllt. Gemessen ohne Zutun des Spielers: Die Rivalen
schaffen Kapitel 1 nach rund 5, Kapitel 2 nach rund 7½, Kapitel 3 nach rund 8 und Kapitel 4 nach
rund 20 Stunden Spielzeit.

Die Szenarien liegen nicht in diesem Repository. Der Installer baut sie aus den Endlos-Vorlagen
deines eigenen Spiels (`tools/kampagne-bauen.ps1`).

## Installieren

Voraussetzungen: Windows 10 oder 11 und Anno 1602 History Edition aus Ubisoft Connect.

1. Oben auf **Code → Download ZIP** klicken und das ZIP entpacken.
2. `installieren.cmd` doppelklicken. Zeigt Windows „Der Computer wurde durch Windows geschützt“:
   *Weitere Informationen → Trotzdem ausführen*.
3. Starten über **„Anno 1602 – Erweiterungen“** im Startmenü oder auf dem Desktop.

Entfernen: `deinstallieren.cmd` doppelklicken. Spiel und Spielstände bleiben.

## Wichtig

- Spielstände aus der grossen Welt nur mit „Mit Erweiterungen spielen“ und derselben Kartengrösse
  laden. Der Spielstand selbst speichert die Grösse nicht.
- Das Werkzeug benennt den automatischen Spielstand („Spiel fortsetzen“) einer grossen Welt nach
  dem Spielende um, damit ihn das Spiel ohne Erweiterungen nicht lädt.
- Vor jedem Start sichert das Werkzeug den Ordner `Dokumente\Anno 1602 History Edition\Savegame`.
- Getestet mit genau einer Spielversion (SHA-256 von `Anno1602.exe` beginnt mit `7731972f`).
  Nach einem Update des Spiels bricht das Werkzeug ab, ohne etwas zu ändern.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `tools/weltgroesse.ps1` | das Werkzeug: prüft die Spielversion und patcht den Speicher |
| `tools/anno-starter.ps1` | das Startfenster |
| `tools/kampagne-bauen.ps1`, `tools/szenario-bauer.ps1` | bauen die 13 Szenarien (Format AUFTRAG4 entschlüsselt) |
| `tools/test-weltgroesse.ps1` | Prüfung ohne Spiel: lädt die exe als Abbild und prüft jede Patchstelle |
| `tools/pruefe-*.ps1` | Prüfungen für laufendes Spiel, Inseln und Szenarien |
| `tools/ghidra_scripts/`, `tools/ghidra-scan.cmd` | Ghidra-Auswertung (braucht eine eigene Kopie der exe in `analysis/bin`) |
| `tools/paket/` | Installer |
| `analysis/BEFUNDE.md` | alle Fundstellen im Spielcode, Formate und Messungen |
| `docs/handbuch.html` | Handbuch zu den Kampagnen |

## Rechtliches

Ein inoffizielles Fan-Projekt, nicht mit Ubisoft verbunden. „Anno“ ist eine Marke von Ubisoft.
Das Repository enthält keine Dateien des Spiels. Du brauchst eine eigene, gekaufte Kopie.
Benutzung auf eigene Gefahr. Der Code steht unter der [MIT-Lizenz](LICENSE).
