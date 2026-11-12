# Anno 1602 – Extensions

*[Deutsche Fassung](README.de.md)*

A fan project for **Anno 1602 History Edition** (Ubisoft Connect): a bigger world, more islands,
tougher rivals, up to 16× game speed and 13 new scenarios with a story and a mission.

The tool **does not change any game file**. It only patches the memory of the running game.
Quit the game and everything is back to the original. Single player only.

The launcher, the scenarios and the in-game texts are in German, like the game itself.

## Features

| Option | Effect |
|---|---|
| Map size | up to 2000 × 1400 tiles (original 500 × 350) |
| Islands | up to 50 islands spread over the whole map (the game's maximum) |
| Island size | Large / Huge: many more large islands (up to 10 of the biggest, 100 × 90) |
| Resources | More: ore, gold, fertility and treasures scaled to the island count; Lots: double that |
| Natives | 4 + 4 or 7 + 7 villages instead of 2 + 2 |
| Free traders | two or three times as many trading ships (24 at most) |
| Computer rivals | always play like on "Hard", even if you pick an easier level |
| Pirates | as per difficulty / always attack / strong / none; fleet of up to 12 ships instead of 4 |
| Gold | starting gold for you and for the rivals |
| Residents per house | ×1.5 to ×5 |
| Production, ship speed, cargo space | ×1.5 to ×3 |
| Storage per good | ×2 to ×5 |
| Turbo (F7) | 8×, 12× or 16× game speed |

A launcher window offers every option as a click, plus the buttons **"Alles gross"** (everything
big) and **"Für Kampagnen"** (big map and turbo, everything else original).

## Campaigns and challenges

13 new scenarios, in game under *Einzelspieler → Neues Spiel → Eigene Szenarien*. Each one has a
classic map (500 × 350) and a big version (1000 × 700, up to 50 islands).

| Scenario | Mission |
|---|---|
| **Die Smaragdinseln** (The Emerald Isles) 1 Landung | a town of 250 residents (150 settlers), positive balance |
| 2 Gewürzfieber | spice monopoly, 500 residents (250 citizens) |
| 3 Zwei Kolonien | 800 residents (300 merchants) and 500 residents (250 citizens), balance +300 |
| 4 Schwarze Segel | 1000 residents (500 merchants), 20 t cannons, 40 t muskets, pirates |
| 5 Der Eroberer | defeat all three rivals, pirates |
| 6 Krone der Inseln | 3 towns, the biggest with 2500 residents (1200 aristocrats), balance +1000 |
| **Wettlauf der Häuser** (Race of the Houses) 1 Erster Hafen | 300 residents (150 settlers) – the rivals have the same mission |
| 2 Bürgerstolz | 700 residents (350 citizens) and a second town of 200 (100 settlers) |
| 3 Kaufmannsrepublik | 1000 residents (400 merchants), pirates |
| 4 Die Krone | 1500 residents (600 aristocrats), balance +500, pirates |
| **Challenge** Inselreich | 8 own settlements with 3000 residents in total |
| Handelsimperium | 50 t jewellery and 80 t clothes in store, trade balance +300 |
| Goldrausch | 60 t gold and 40 t jewellery in store, pirates |

In the race, whoever fulfils the mission first wins. Measured without any player action, the rivals
finish chapter 1 after about 5, chapter 2 after about 7½, chapter 3 after about 8 and chapter 4 after
about 20 hours of game time.

The scenarios are not part of this repository. The installer builds them from the endless-game
templates of your own copy of the game (`tools/kampagne-bauen.ps1`).

## Install

Requirements: Windows 10 or 11 and Anno 1602 History Edition from Ubisoft Connect.

1. Click **Code → Download ZIP** at the top and unzip it.
2. Double-click `installieren.cmd`. If Windows shows "Windows protected your PC":
   *More info → Run anyway*.
3. Start with **"Anno 1602 - Erweiterungen"** in the Start menu or on the desktop.

Uninstall: double-click `deinstallieren.cmd`. The game and your saves stay as they are.

## Good to know

- Load saves from a big world only with "Mit Erweiterungen spielen" and the same map size.
  The save itself does not store the size.
- After the game ends, the tool renames the autosave ("Spiel fortsetzen") of a big world, so the
  game cannot load it without the extensions.
- Before every start, the tool backs up `Documents\Anno 1602 History Edition\Savegame`.
- Tested with exactly one game version (SHA-256 of `Anno1602.exe` starts with `7731972f`).
  After a game update, the tool stops without changing anything.

## Layout

| Path | Contents |
|---|---|
| `tools/weltgroesse.ps1` | the tool: checks the game version and patches memory |
| `tools/anno-starter.ps1` | the launcher window |
| `tools/kampagne-bauen.ps1`, `tools/szenario-bauer.ps1` | build the 13 scenarios (decoded AUFTRAG4 mission format) |
| `tools/test-weltgroesse.ps1` | offline test: loads the exe as an image and checks every patch site |
| `tools/pruefe-*.ps1` | checks for the running game, islands and scenarios |
| `tools/ghidra_scripts/`, `tools/ghidra-scan.cmd` | Ghidra analysis (needs your own copy of the exe in `analysis/bin`) |
| `tools/paket/` | installer |
| `analysis/BEFUNDE.md` | every patch site in the game code, file formats and measurements (German) |
| `docs/handbuch.html` | campaign handbook (German) |

## Legal

An unofficial fan project, not affiliated with Ubisoft. "Anno" is a trademark of Ubisoft.
This repository contains no game files. You need your own copy of the game.
Use at your own risk. The code is released under the [MIT License](LICENSE).
