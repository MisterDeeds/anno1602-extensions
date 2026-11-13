# Changelog

All versions are for Anno 1602 History Edition (Ubisoft Connect), single player. Details, addresses and test runs:
[docs/FINDINGS.md](docs/FINDINGS.md).

## 2.2.0 – 2026-11-13

- Random adventures carry the difficulty in their name ("Abenteuer 4711 Fordernd" / "Adventure 4711 Demanding"):
  the same number with another difficulty no longer replaces the earlier adventure.
- New test `tests/test-install.ps1`: installs and removes for real in a sandbox (an older version present, a language
  switch, the player's own files) and checks that nothing outside the sandbox changes – 17 checks.

## 2.1.0 – 2026-11-13

- Repository tidied up: `src/` (everything that gets installed), `tests/`, `dev/` (helpers for development),
  `docs/` (findings, handbook, screenshots). The old starter `start-big-world.cmd` is gone – the launcher replaces it.
- The offline test also runs from a fresh clone: without a local copy of the exe it maps the exe of the installed game.
- Savegame backups no longer grow without end: the first backup and the newest five stay, older ones go to the
  recycle bin.
- Started from the launcher, the tool's window closes by itself after the game; it stays open only on an error.
- Launcher: check box "Open the logbook with the game"; taller scenario list.
- README with screenshots of the launcher and the logbook.

## 2.0.0 – 2026-11-12

- Seven new options: building costs, running costs, tax income, influence radius, fertility everywhere,
  inexhaustible mines, disasters off or more often.
- Third campaign "Die Sturmsee / The Storm Sea" (6 chapters) and four new challenges (Archipelago, Continents,
  Merchant Fleet, Sea Power); ships can start with cargo; all 23 scenarios also in English.
- Random adventures: a new, fair scenario from a number and a difficulty – the same number always gives the same map.
- Logbook: a companion window with mission progress, your empire, the rivals and 24 achievements; it records won
  and lost missions.
- Launcher with three tabs: new game (four groups, presets "Relaxed" and "Tough test"), continue (every savegame
  with the options it was made with), adventures (campaign progress and the adventure roller).
- Fixed after the game test: with only small islands the computer rivals dropped out at once and the scenario was
  lost after a minute; archipelago maps now include 50 × 52 islands.

## 1.1.0 – 2026-11-12

- Whole project in English (file names, code, documentation); launcher, installer and tool messages in German on a
  German Windows and in English otherwise.

## 1.0.0 – 2026-11-12

- First public version: world up to 2000 × 1400 with up to 50 islands, island size, resources, natives, traders,
  stronger rivals, pirates and pirate fleet, gold, residents, production, storage, ship speed, cargo space, turbo up
  to 16×; 13 own scenarios (campaigns "Die Smaragdinseln" and "Wettlauf der Häuser", three challenges); launcher
  window and installer.
