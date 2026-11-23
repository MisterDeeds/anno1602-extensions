# Changelog

All versions are for Anno 1602 History Edition (Ubisoft Connect), single player. Details, addresses and test runs:
[docs/FINDINGS.md](docs/FINDINGS.md).

## 3.7.1 – 2026-11-23

- **Fix: the island map and the logbook did not appear when the launcher opened them.** The launcher starts both with
  a hidden console (no black window). Windows then applies "hidden" also to the first window the process shows, so the
  windows were created but never shown – with the buttons "Open island map" and "Open logbook" and with the check
  boxes "… with the game". Affected: the island map of 3.7.0 and the logbook (the launcher has started it this way
  since 2.0). Now the launcher also passes `-WindowStyle Hidden` to PowerShell itself, and both scripts use up a hidden
  start before their window opens, so they appear even when an older launcher starts them.
- Game test of 3.7.0 with the launcher's saved choice (2000 × 1400, giant islands, perfect home island, all islands
  explored): in a new endless game the home island has 2 ore deposits (240 t) and 2 gold deposits, byte for byte like
  the gold deposit the game itself created on another island; all 50 islands explored; the island map read the running
  game (2 islands with gold, 46 with ore), and zoom, dragging, selecting an island, the gold filter and the 2-second
  refresh worked in the real window.
- Tests: `tests/test-install.ps1` 47 checks (the installed logbook and island map really appear when started with a
  hidden console – as the launcher does now and as launchers up to 3.7.0 did; without the fix both stay hidden), new
  test switch `-TestShowSeconds` for both windows; island map `-SelfTest` 23, logbook `-SelfTest` 147.

## 3.7.0 – 2026-11-22

- **Island map** (`src/island-map.ps1`; launcher button "Open island map" and the check box "Open the island map with
  the game", on by default): a window next to the game with every island of the running game – endless games,
  scenarios and savegames. It draws each island's real outline from its tile grid, turned like the game's view
  (the camera's rotation, the game's own projection `FUN_1400c4ba0`), northern islands green, southern ones olive,
  mountains grey, buildings light and every player's territory in the player's colour from the game; a gold or grey
  marker sits on every gold and ore deposit, plus the island numbers, your ships and the spot the game shows.
  Pointing at an island lists its gold and ore (large/small, tons), the crops at 100 % and the settlements; the list
  on the right can be filtered by gold, ore, each crop, free, north and south. Mouse wheel zooms, dragging moves.
  It only reads the game's memory (every 2 seconds, on a worker thread) and checks the exe like the logbook.
- **Fix "Home island": real gold.** 3.6.0 wrote the two gold deposits as small ore deposits (80 t ore), so the home island
  had ore on all four mountains and no gold. In a deposit slot the first byte is the raw material (2 ore, 3 gold) – the
  mine looks only for its own raw material (`FUN_14009ebb0` compares it with the mine's building +0x21) – and the byte
  +4, which 3.6.0 took for "ore or gold", only tells a large deposit from a small one. Now the home island gets 2 ore
  deposits (240 t) and 2 gold deposits exactly as the game itself creates them (raw material 3, 50 t); a gold mine never
  uses them up.
- Games started with 3.6.0: when the tool window runs with "Home island: perfect" it turns the two wrong deposits into
  gold once, in the running game and after loading a savegame (only the two slots with exactly the 3.6.0 values on the
  home island's gold mountains).
- Launcher: the check boxes (logbook, island map, automatic update) moved to a second row below the buttons.
- Tests: `tests/test-patcher.ps1` 750 checks (case AY: raw materials of the deposits, repair of a 3.6.0 game, once,
  other islands untouched), `tests/test-islands.ps1` 30, `tests/test-install.ps1` 44 (island map opened with the game
  and by its button; the automatic update is expected not to start while Anno 1602 runs), new `src/island-map.ps1
  -SelfTest` 23 (reading, terrain, territory owners, colours, the projection in all four rotations, rendering, filters,
  hit test, zoom, the refresh thread, German and English). In a running 3.6.0 game the home island's memory now holds
  2 ore and 2 gold deposits, the gold ones byte for byte like the game's own gold deposit on another island; the
  island map read the same running game (2000 × 1400, 50 islands): outlines, deposits, territories and colours as in
  the game, the home island's shape and mountains matching a screenshot of the game.

## 3.6.0 – 2026-11-22

- **Perfect home island** (option "Home island: perfect, at the start ship", also in the preset "Relaxed"): new endless
  games get a giant northern island of 160 × 140 tiles only for you – flat, without river, forest and meadow, and four
  large ore mountains, one in each corner right at the coast. At the start it gets 2 ore deposits (240 t) and 2 gold
  deposits (80 t) on these mountains, every crop at 100 % (tobacco, sugar cane and wine grow in the north anyway; spices,
  cotton and cocoa too) and is explored. Your start ship begins right in front of its coast – "Build warehouse" is one
  click away.
- How: the island forge builds `Nord\lar28.scp` (from the game's large northern island, outline and coast with the
  learned rules, the game's own single mountain with rock 1110). The planner puts it where it lies farthest from the
  start ships (all four start ships of the endless templates lie within 10 tiles of each other, so the rivals would
  otherwise settle it at once) and covers the fewest islands, as a northern island (climate 0). The human's start ship
  is moved there by a small code cave in front of the ship loader (`FUN_14008e4f0`), only in new endless games (the
  island code cave sets a flag when it copies a plan); savegames and scenarios are not touched. Deposits, crops and the
  explored bit are set by the tool window in the first seconds of a new game.
- Tests: `tests/test-islands.ps1` 30 checks (new section 7: the home island), `tests/test-patcher.ps1` 748 checks (new cases AX
  (island file, plans at 2000 × 1400 and 1000 × 700, start ship, code caves) and AY (deposits, crops, explored, once,
  not in loaded games)), `tests/test-install.ps1` 43. Checked in the running game (2000 × 1400 with giant islands): the home island loaded as a
  northern island, your ship at its coast with the warehouse button, the rivals' ships far away, the four deposits on
  tiles the game itself accepts for ore.

## 3.5.0 – 2026-11-22

- **Fix "Cargo space":** since it was added (2026-11-10) this option did not raise the cargo but the hull of the ships. The value it scaled
  (figure table +0x3E) is figuren.cod "Maxenergy" (small/large trading ship 50/80, small/large warship 65/120), not
  "Maxware". Start ships come from the game's template with the normal hull, so with ×3 every start ship – yours and the
  rivals' – showed only a third of its bar (reported with a screenshot); a shipyard filled them up. Now the option
  ("Cargo holds") gives real cargo: more holds of 50 t (figuren.cod "Maxware", +0x3A): ×1.5 = small trading ship 6
  instead of 4, ×2 = 8, maximum = 8 on every ship (the ship record has 8 holds, the large warship already uses 8). The
  hull stays as in the original.
- **Ultra speed (F8):** a new key. The game's key switch ends at F7; its jump to the end now goes through a small code
  cave that sets 32×, 64× or 128× for F8 (option "Ultra (F8 key)"; the presets with turbo set 32×). F5–F7 unchanged.
  F8 alone was a shortcut of the game for the player status (found in the game test: the key never reached the
  switch); a filter in front of the game's shortcut table now passes F8 without Shift/Ctrl to the speed keys – the
  player status stays on the STATUS button, Shift/Ctrl+F8 work as before. Measured at 2000 × 1400 with giant islands:
  32×, 48×, 64×, 96× and 128× all exact at about half of one processor core.
- Ships, islands and F8 checked in the running game: every start ship (yours and the rivals') with a full hull and 8
  holds, all 50 islands explored, F8 switches to the chosen speed, Ctrl+F8 still goes to the game.
- **Explored:** "All islands from the start" – every island counts as explored by you: its ore and gold deposits are
  visible and the natives are known without sailing there (island +0x43, one bit per player, set by the game when a
  ship reaches an island; the tool window sets yours while the game runs). In the presets "Everything big" and
  "Relaxed".
- Tests: `tests/test-patcher.ps1` 727 checks (new cases AV for F8 with the key filter, AW for exploring, case O for the holds), `tests/test-install.ps1` 43, `tests/test-islands.ps1` 21.

## 3.4.1 – 2026-11-22

- Mountains "At the coast" now really leave the inland free, also on giant islands: in 3.4.0 a mountain range counted
  as "at the coast" as soon as one end touched it, so long ranges still crossed the island (reported with a giant
  island 160 × 125 whose two ranges reached 41 tiles inland). Now a mountain group must lie completely in a strip of
  at most 10 tiles along the coast. A range that does not fit there as a whole is split into single mountains – each
  one the game's own single mountain with the same rock and its ring of slopes – and every one of them goes to the
  coast on its own; if one of them finds no place at the coast, the range stays as it is. Mountains that are part of a
  native village stay; mountains that only lie near a village may now move too.
- All whole islands of the game: 96 % of the mountain groups lie completely at the coast (62 % without the option,
  3.4.0 left the long ranges); on the giant islands all of them (238 groups).
- Tests: `tests/test-islands.ps1` 21 checks (new: groups completely at the coast, rocks unchanged by number and kind,
  every mountain of the giant islands at the coast), `tests/test-patcher.ps1` 702, `tests/test-install.ps1` 43.
  Checked in the running game at 2000 × 1400 with giant islands: all 50 islands loaded, no river, all 121 mountain
  groups of the 6 giant islands completely at the coast.

## 3.4.0 – 2026-11-22

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
  towns like a trader. In the game test their capitals went from 204 settlers to citizens, merchants and aristocrats
  (up to 449) with theatre and college within about 10 game hours, and they founded new towns.
- Presets: "Everything big" with giant islands and ambitious rivals, "Relaxed" without rivers and volcano and with the
  mountains at the coast, "Tough test" with ambitious rivals.
- Tests: new `tests/test-islands.ps1` (19 checks with the real island files), `tests/test-patcher.ps1` cases AQ–AU
  (702 checks), `tests/test-install.ps1` 43 checks. Checked in the running game: all 50 islands with 6 giant islands,
  no river left, 169 of 172 mountain groups at the coast, the giant islands stored completely in the savegame.

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
