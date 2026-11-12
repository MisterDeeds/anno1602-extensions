# Anno 1602 – Erweiterungen

*[English version](README.md)*

Ein Fan-Projekt für **Anno 1602 History Edition** (Ubisoft Connect): grössere Welt, mehr Inseln,
stärkere Gegner, günstigeres Bauen und reichere Städte, Turbo bis 16-fach, 23 eigene Szenarien mit
Geschichte und Auftrag, Zufallsabenteuer und ein Logbuch-Fenster neben dem Spiel.

Das Werkzeug ändert **keine Datei des Spiels**. Es passt nur den Arbeitsspeicher des laufenden
Spiels an. Wird das Spiel beendet, ist alles wieder wie im Original. Nur für das Einzelspiel.

Das Startfenster ist auf einem deutschen Windows deutsch, sonst englisch. Die Szenarien werden in
derselben Sprache gebaut: deutsche Titel und Auftragstexte auf einem deutschen Windows, englische
auf einem englischen.

## Was es kann

| Option | Wirkung |
|---|---|
| Kartengrösse | bis 2000 × 1400 Felder (Original 500 × 350) |
| Inseln | bis 50 Inseln über die ganze Karte verteilt (das Maximum des Spiels) |
| Inselgrösse | Gross / Riesig: viel mehr grosse Inseln (bis 10 der grössten, 100 × 90) |
| Rohstoffe | Mehr: Erz, Gold, Fruchtbarkeit und Schätze passend zur Inselzahl; Viele: doppelt |
| Ureinwohner | 4 + 4 oder 7 + 7 Dörfer statt 2 + 2 |
| Fruchtbarkeit | jede Pflanze auf jeder Insel (neue Endlosspiele) |
| Freie Händler | doppelt oder dreimal so viele Händlerschiffe (höchstens 24) |
| Computergegner | immer wie „Schwer“, auch wenn du leichter spielst |
| Piraten | wie Schwierigkeit / greifen immer an / stark / keine; Flotte bis 12 Schiffe statt 4 |
| Katastrophen | keine (kein Feuer, keine Pest, Dürre oder Vulkan) oder häufiger |
| Gold | Startgold für dich und für die Gegner |
| Einwohner je Haus | ×1,5 bis ×5 |
| Produktion, Schiffstempo, Laderaum | ×1,5 bis ×3 |
| Lager je Ware | ×2 bis ×5 |
| Baukosten | ×0,75, halb, ein Viertel oder gratis (Gold, Werkzeug, Holz und Ziegel; auch für die Gegner) |
| Betriebskosten | ×0,75, halb, ein Viertel oder keine |
| Steuereinnahmen | ×1,5 bis ×3 |
| Einflussradius | ×1,5 oder ×2 für Kontor, Markt und öffentliche Bauten (Kapelle, Kirche, Wirtshaus, Arzt, Schule …) |
| Erz- und Goldminen | unerschöpflich |
| Turbo (F7) | 8-, 12- oder 16-fache Geschwindigkeit |

## Das Startfenster

Das Startfenster hat drei Registerkarten:

- **Neues Spiel**: alle Optionen zum Anklicken, in vier Gruppen (Welt, Wirtschaft, Gegner und
  Gefahren, Schiffe und Tempo), dazu fünf Vorlagen:

  | Vorlage | Einstellungen |
  |---|---|
  | **Alles gross** | 1000 × 700, riesige Inseln, viele Rohstoffe, 7 + 7 Dörfer, dreimal so viele Händler, Gegner wie „Schwer“ mit 60 000 Gold, Piraten greifen an mit bis zu 8 Schiffen, Einwohner ×5, Lager ×5, Laderaum ×3, Produktion und Schiffe ×2, Turbo 16-fach, dein Gold 50 000 |
  | **Für Kampagnen** | grosse Karte und Turbo 16-fach, alles andere wie im Szenario vorgesehen |
  | **Gemütlich** | Bau- und Betriebskosten halbiert, Steuern ×2, Radius ×1,5, jede Pflanze überall, unerschöpfliche Minen, keine Piraten, keine Katastrophen, 100 000 Gold, Einwohner ×2, Produktion ×2, Lager ×3, grosse Inseln, viele Rohstoffe, Turbo 16-fach |
  | **Harte Probe** | Gegner wie „Schwer“ mit 100 000 Gold, starke Piraten mit bis zu 12 Schiffen, mehr Katastrophen, 4 + 4 Dörfer, Turbo 16-fach |
  | **Alles auf Standard** | 1000 × 700 mit mehr Inseln und mehr Rohstoffen, sonst wie im Original |

- **Weiterspielen**: deine Spielstände mit den Einstellungen, mit denen sie entstanden sind.
  *Mit diesen Einstellungen spielen* startet das Spiel mit genau diesen Optionen, so wird eine
  grosse Welt immer mit der richtigen Grösse geladen. (Gemerkt für jeden Spielstand, der mit dieser
  Version der Erweiterungen gespeichert wird; bei älteren Autosaves einer grossen Welt kommt die
  Grösse aus dem Dateinamen.)
- **Abenteuer**: alle Kampagnen und Herausforderungen mit deinem Fortschritt (gewonnen, verloren,
  nächstes Kapitel) und der **Zufallsabenteuer**-Generator: Schwierigkeit wählen, freiwillig eine
  Nummer eingeben, *Abenteuer würfeln* klicken. Jede Nummer ergibt eine eigene Inselwelt mit eigenem
  Auftrag (eine von drei Kartenarten, und Städte, ein Inselreich, Handel, ein Monopol oder Eroberung
  als Hauptziel); dieselbe Nummer ergibt immer dasselbe Abenteuer.

Unter den Registerkarten: **Mit Erweiterungen spielen**, **Original starten** und **Logbuch öffnen**.

## Logbuch

Ein kleines Fenster neben dem Spiel. Es *liest* nur den Arbeitsspeicher des Spiels und zeigt deine
Auftragsziele mit laufenden Fortschrittsbalken, Gold, Bilanz und Handelsbilanz, deine Städte und
Einwohner je Stufe, Schiffe, die besten Städte der Gegner (und ihren Stand im Wettlauf) und 24 Erfolge –
von „Land in Sicht“ (erste Stadt) bis „Millionär“. Erfolge und beendete Aufträge stehen in
`%APPDATA%\Anno1602-Extensions\logbook.json`; daraus zeigt die Registerkarte „Abenteuer“, welche
Kapitel du gewonnen hast. Das Spiel im Fenstermodus oder einen zweiten Bildschirm nutzen, um beides
zu sehen.

Im laufenden Spiel geprüft am 12. November 2026: Alle sieben neuen Optionen werden genau wie geplant
gesetzt (alle 50 Inseln tragen alle sechs Pflanzen; bei 16-fach über 1,5 Spielstunden blieben die
Erzvorkommen gleich, es gab keine Katastrophe, und das Gold der Gegner stieg mit doppelten Steuern und
halben Betriebskosten), die Registerkarte „Weiterspielen“ (ein Spielstand wird beim Spielende mit seinen
Optionen gemerkt), Sturmsee 1 und 5, Archipel und ein Zufallsabenteuer (Ladung, Flotte und Auftrag wie
geplant) sowie das Logbuch (Live-Werte, eine gewonnene Mission wird eingetragen). Später am selben
Tag: Das Baumenü zeigt die halbierten Kosten, ein Wegstück kostete wirklich 3 statt 5 Gold; die
Bauvorschau des Marktplatzes zeigt den doppelten Radius; mit demselben Spielstand über 2,9 Spielstunden
ergaben die Katastrophen 0 / 34 / 89 neue Brände und Pestfälle für aus / normal / häufiger; ein
englisches Szenario erscheint mit englischem Text; alle Knöpfe des Startfensters wurden im Code
geklickt. Noch nicht durchgespielt: die Balance der zehn neuen Szenarien.

## Kampagnen und Herausforderungen

23 eigene Szenarien, im Spiel unter *Einzelspieler → Neues Spiel → Eigene Szenarien*. Jedes hat
eine klassische Karte (500 × 350) und eine grosse Fassung (1000 × 700, bis 50 Inseln).

| Deutscher Titel | Englischer Titel | Auftrag |
|---|---|---|
| **Die Smaragdinseln** 1 Landung | **Emerald Isles** 1 Landfall | Stadt mit 250 Einwohnern (150 Siedler), Bilanz im Plus |
| 2 Gewürzfieber | 2 Spice Fever | Gewürzmonopol, 500 Einwohner (250 Bürger) |
| 3 Zwei Kolonien | 3 Two Colonies | 800 Einw. (300 Kaufleute) und 500 Einw. (250 Bürger), Bilanz +300 |
| 4 Schwarze Segel | 4 Black Sails | 1000 Einw. (500 Kaufleute), 20 t Kanonen, 40 t Musketen, Piraten |
| 5 Der Eroberer | 5 The Conqueror | alle drei Rivalen besiegen, Piraten |
| 6 Krone der Inseln | 6 Crown of the Isles | 3 Städte, die grösste 2500 Einw. (1200 Aristokraten), Bilanz +1000 |
| **Wettlauf der Häuser** 1 Erster Hafen | **Race** 1 First Harbour | 300 Einw. (150 Siedler) – die Rivalen haben denselben Auftrag |
| 2 Bürgerstolz | 2 Civic Pride | 700 Einw. (350 Bürger) und eine zweite Stadt mit 200 Einw. (100 Siedler) |
| 3 Kaufmannsrepublik | 3 Merchant Republic | 1000 Einw. (400 Kaufleute), Piraten |
| 4 Die Krone | 4 The Crown | 1500 Einw. (600 Aristokraten), Bilanz +500, Piraten |
| **Die Sturmsee** 1 Schiffbruch † | **Storm Sea** 1 Shipwreck † | Stadt mit 200 Einw. (100 Siedler) und eine zweite Siedlung, Bilanz im Plus – mit wenig Gold und halb leerem Schiff |
| 2 Tabak und Kakao † | 2 Tobacco and Cocoa † | Tabakmonopol und Kakaomonopol, 600 Einw. (300 Bürger) |
| 3 Der Freihafen † | 3 The Free Port † | Handelsbilanz +400, 40 t Tabakwaren und 40 t Kakao im Lager |
| 4 Die Rote Flagge † | 4 The Red Flag † | mindestens 3 Siedlungen, jede mit 300 Einw. (100 Bürger), Piraten |
| 5 Verrat † | 5 Betrayal † | das Haus Valcourt besiegen (nur diesen Rivalen), 1000 Einw. (400 Kaufleute) |
| 6 Das Goldene Zeitalter † | 6 The Golden Age † | 2000 Einw. (800 Aristokraten) und 1200 (500 Kaufleute), zusammen 4000, 40 t Schmuck, Bilanz +800, Piraten |
| **Herausforderung** Inselreich | **Challenge** Island Realm | 8 eigene Siedlungen mit zusammen 3000 Einwohnern |
| Handelsimperium | Trade Empire | 50 t Schmuck und 80 t Kleidung im Lager, Handelsbilanz +300 |
| Goldrausch | Gold Rush | 60 t Gold und 40 t Schmuck im Lager, Piraten |
| Archipel † | Archipelago † | mindestens 10 Siedlungen auf kleinen Inseln, jede mit 100 Einw. (40 Siedler) |
| Kontinente † | Continents † | 1500 Einw. (400 Aristokraten), zusammen 3000, Bilanz +300 – auf wenigen riesigen Inseln |
| Handelsflotte † | Merchant Fleet † | 4 Siedlungen, 60 t Gewürze und 60 t Kakao im Lager – vier Schiffe, wenig Gold |
| Seemacht † | Sea Power † | alle drei Rivalen besiegen – sie sind arm, du startest mit drei Kriegsschiffen |

† Neu im November 2026 und noch nicht im Spiel auf die Balance geprüft: Die Schwierigkeit ist in
Anlehnung an die gemessenen Kapitel ausgelegt.

Im Wettlauf gewinnt, wer den Auftrag zuerst erfüllt. Gemessen ohne Zutun des Spielers: Die Rivalen
schaffen Kapitel 1 nach rund 5, Kapitel 2 nach rund 7½, Kapitel 3 nach rund 8 und Kapitel 4 nach
rund 20 Stunden Spielzeit.

Die Szenarien liegen nicht in diesem Repository. Der Installer baut sie aus den Endlos-Vorlagen
deines eigenen Spiels (`tools/build-scenarios.ps1`).

## Installieren

Voraussetzungen: Windows 10 oder 11 und Anno 1602 History Edition aus Ubisoft Connect.

1. Oben auf **Code → Download ZIP** klicken und das ZIP entpacken.
2. Im entpackten Ordner `install.cmd` doppelklicken. Zeigt Windows „Der Computer wurde durch Windows geschützt“:
   *Weitere Informationen → Trotzdem ausführen*.
3. Starten über **„Anno 1602 – Erweiterungen“** im Startmenü oder auf dem Desktop
   (auf einem Windows in anderer Sprache heisst die Verknüpfung „Anno 1602 – Extensions“).

Entfernen: im selben Ordner `uninstall.cmd` doppelklicken. Spiel und Spielstände bleiben.

## Wichtig

- Spielstände aus der grossen Welt nur mit den Erweiterungen und derselben Kartengrösse laden –
  am einfachsten über die Registerkarte **Weiterspielen**. Der Spielstand selbst speichert die
  Grösse nicht.
- Das Werkzeug benennt den automatischen Spielstand („Spiel fortsetzen“) einer grossen Welt nach
  dem Spielende um, damit ihn das Spiel ohne Erweiterungen nicht lädt.
- Vor jedem Start sichert das Werkzeug den Ordner `Dokumente\Anno 1602 History Edition\Savegame`.
- Getestet mit genau einer Spielversion (SHA-256 von `Anno1602.exe` beginnt mit `7731972f`).
  Nach einem Update des Spiels bricht das Werkzeug ab, ohne etwas zu ändern.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `tools/anno-patcher.ps1` | das Werkzeug: prüft die Spielversion und patcht den Speicher |
| `tools/launcher.ps1` | das Startfenster (deutsch oder englisch, je nach Sprache von Windows) |
| `tools/logbook.ps1` | das Logbuch-Fenster (liest den Speicher des Spiels nur) |
| `tools/build-scenarios.ps1`, `tools/scenario-lib.ps1` | bauen die 23 Szenarien deutsch oder englisch (Format AUFTRAG4 entschlüsselt) |
| `tools/random-adventure.ps1` | Zufallsabenteuer-Generator (Nummer und Schwierigkeit → neues Szenario) |
| `tools/test-patcher.ps1` | Prüfung ohne Spiel: lädt die exe als Abbild und prüft jede Patchstelle (556 Prüfungen) |
| `tools/check-*.ps1` | Prüfungen für laufendes Spiel, Inseln und Szenarien |
| `tools/ghidra_scripts/`, `tools/ghidra-scan.cmd` | Ghidra-Auswertung (braucht eine eigene Kopie der exe in `analysis/bin`) |
| `install.cmd`, `uninstall.cmd`, `tools/install.ps1` | Installer |
| `tools/README.de.txt`, `tools/README.txt` | Anleitung (deutsch, englisch), wird neben dem Werkzeug installiert |
| `analysis/FINDINGS.md` | alle Fundstellen im Spielcode, Formate und Messungen (englisch) |
| `docs/handbook.de.html`, `docs/handbook.html` | Handbuch zu den Kampagnen (deutsch, englisch) |

## Rechtliches

Ein inoffizielles Fan-Projekt, nicht mit Ubisoft verbunden. „Anno“ ist eine Marke von Ubisoft.
Das Repository enthält keine Dateien des Spiels. Du brauchst eine eigene, gekaufte Kopie.
Benutzung auf eigene Gefahr. Der Code steht unter der [MIT-Lizenz](LICENSE).
