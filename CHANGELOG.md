# Changelog

All versions are for Anno 1602 History Edition (Ubisoft Connect), single player. Details, addresses and test runs:
[docs/FINDINGS.md](docs/FINDINGS.md).

## Unreleased

- Island forge: the tool writes changed copies of the game's island files into its own folder (once per set of
  options) and lets the game read them from there; the game files stay untouched, savegames keep their islands.
  New options in the launcher group "Landschaft der Inseln / Landscape of the islands":
  - Rivers "None": rivers become meadow, mouths become beach and surf, the spring a slope.
  - Mountains "At the coast": mountains in the middle of an island move to the coast, the inland stays free
    (mountains next to native villages stay).
  - Volcano "None": the game's only volcano (Nord\big25) becomes a normal mountain, no eruptions.
- Island size "Giant": up to 6 giant islands of 135 × 120 to 160 × 140 tiles – larger than the largest islands of
  the game (100 × 90). They grow from the game's large islands; coast, beach and surf are laid with the pieces the game
  itself uses for each shape.
- Rivals' towns "Ambitious (with supplies)": measured in the game, the rivals stop at 34 settler houses because they
  never make liquor, tobacco goods and spices and hardly ever have bricks; rich rivals also skip the building steps of
  their plan. Now their building plan builds before it moves on (no money shortcuts, no dead ends before church/
  bathhouse and theatre/college), and while the game runs the tool window tops up tools, bricks and luxury goods in their
  towns like a trader. In the game test their capitals built taverns and got citizens within minutes.
- Presets: "Everything big" with giant islands and ambitious rivals, "Relaxed" without rivers and volcano and with the
  mountains at the coast, "Tough test" with ambitious rivals.
- Tests: new `tests/test-islands.ps1` (19 checks with the real island files), `tests/test-patcher.ps1` cases AQ–AT.

## 3.3.1 – 2026-11-16

- Launcher: the update notice is a coloured bar as wide as the tabs, with symbol, text and button in the middle –
  green after an update, blue for a new version, red when the download failed.
- The buttons below the tabs start flush with the tabs, the check boxes end flush on the right, all on one line.
- The installer's closing lines say that updates come by themselves.

## 3.3.0 – 2026-11-15

- Automatic updates: when GitHub has a newer release, the launcher installs it by itself and opens again –
  settings, logbook and saves stay. Check box "Automatisch aktualisieren / Update automatically" (on by default);
  without it the button "Update now" remains. At most one try per version and day, never while the game runs.
- After an update the launcher says "Updated to version x.y.z" once, with a button "What is new?" for the release
  notes.
- The update now downloads `get.ps1` and runs it as a file (3.2.0 started `irm … | iex` in a new window).
- Versions up to 3.1.0 have no update check; 3.2.0 shows the button. Install those once with the line from the
  README, after that the extensions keep themselves up to date.

## 3.2.0 – 2026-11-15

- Install with one line: `irm https://raw.githubusercontent.com/MisterDeeds/anno1602-extensions/main/get.ps1 | iex`
  in PowerShell downloads the newest release, installs it and opens the launcher. No ZIP, no unzipping, no
  "Windows protected your PC", no administrator rights. The same line updates.
- The extensions are listed in Windows Settings → Apps and can be uninstalled there like any other program
  (the installer keeps a copy of itself in the program folder for that).
- The launcher shows its version in the title and checks GitHub in the background for a newer release; if there
  is one, a button "Update now" runs the one-line installer and reopens the launcher.
- `install.cmd` opens the launcher when it is done.
- Tests: `tests/test-install.ps1` also installs through `get.ps1` from a local ZIP in the GitHub layout, checks
  the Apps entry, the update notice and the removal by the installed copy.

## 3.1.0 – 2026-11-15

- Giant world: scenarios can carry a third map version for 2000 × 1400. The game holds at most 50 islands
  (10 of the biggest kind), so instead of spreading them thinly the giant maps group them into five island
  realms with open sea between them – home in the north-west, northern crops near home, spices, cocoa and
  cotton only after a long voyage. The tool takes the biggest version that fits the map size.
- New campaign "Das Weltreich / The World Empire" (six chapters, made for the giant world, up to 7
  settlements and 8000 residents) and two giant challenges, "Sieben Meere / Seven Seas" and "Die
  Weltumsegelung / Around the World": 49 scenarios per language.
- Launcher preset "Riesenwelt / Giant world": 2000 × 1400, ships ×2, turbo 16×, everything else as the
  scenario intends.
- Scenario designer: check box "also for the giant world" with a third map in the preview.
- Tests: `tests/test-patcher.ps1` 655 checks (three map versions), `tests/check-scenarios.ps1` checks the
  giant version, the 41 earlier scenarios are byte-identical.
- Checked in the running game: "Weltreich 1" with the preset Giant world (all 50 islands in place, the rivals
  settle across the realms), at 1000 × 700 (big version) and in the original game without the extensions (classic map).

## 3.0.0 – 2026-11-15

- Two new campaigns with six chapters each: "Die Neue Welt / The New World" (exploration, native
  villages, monopolies of southern and northern crops, a conquistador) and "Die Handelsliga / The Trade
  League" (goods, trade balance and banking, no war) – plus six new challenges: Colonial Lord,
  Monopolist, Calm Seas, Shoestring, and two against the clock. 41 scenarios per language in total.
- Mission time limits: the game had a time limit that nothing ever set. The tool now sets it from the
  scenario at every start and every load; the game shows its own clock and ends the mission as lost
  when the time is up. Scenario key `TimeLimitHours`; only with the extensions.
- Events (option "Ereignisse / Events": Rare or Often): a patron, a fire in the warehouse, a trader's
  gift, a tax windfall or slump and a bumper harvest or marsh fever for one game hour. Temporary values
  are restored after the hour, when another game is loaded or started, with the game's end and when
  the tool stops; savegames never contain them.
- Scenario designer: click a scenario together – map, world, rivals, ships and any combination of
  mission goals, with an optional time limit and an editable story – and see the mission text as the
  game will show it.
- Daily adventure: a new random adventure every day, the same for everyone on that date.
- Campaign chapters can be unlocked one by one (launcher check box, off by default).
- Logbook 2.0: a History tab with charts (gold, residents per class, balance, towns and ships), a
  summary card at the end of every game, the list of played games, an events section, 53 achievements
  instead of 24, sections that fold; the time limit shown in the game's own clock units.
- The launcher fits the new option and buttons; the installer installs the designer and keeps a full
  set of chapters for the unlocking; the uninstaller knows every new scenario name.
- Tests: `tests/test-patcher.ps1` 640 checks (events, time limit), `tests/test-install.ps1` 27 checks,
  `src/logbook.ps1 -SelfTest` 147 checks, `tests/check-scenarios.ps1` checks time limits, crop climates,
  goods that can be produced, title lines and daily adventures.

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
