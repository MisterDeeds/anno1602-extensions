Anno 1602 History Edition - Extensions
======================================

Install (also on another PC)
  1. Install Anno 1602 History Edition through Ubisoft Connect (your own Ubisoft account).
  2. Press the Windows key, type "powershell", Enter. Paste this line and press Enter:
       irm https://raw.githubusercontent.com/MisterDeeds/anno1602-extensions/main/get.ps1 | iex
     It downloads the newest version, installs everything and opens the launcher.
     (Without PowerShell: unzip the ZIP of the newest version from GitHub and double-click
     "install.cmd".)
  3. Start with "Anno 1602 - Extensions" in the Start menu or on the desktop
     (on a German Windows the shortcut is called "Anno 1602 - Erweiterungen").
  Update: happens by itself. When a new version is out, the launcher installs it at its next
  start and opens again (check box "Update automatically"; without it the button "Update now"
  appears). Settings, logbook and saves stay. Running the line above again works too.
  Uninstall: Windows Settings -> Apps -> "Anno 1602 - Extensions" -> Uninstall. The game and
  your saves stay; the scenarios of the extensions (also daily adventures and the scenarios you
  built yourself) and the folder with your settings and the logbook are removed.
  Taking your saves along: copy the folder Documents\Anno 1602 History Edition\Savegame to the
  same place on the other PC (start the game there once before).
  The extensions contain no game files; the game itself always comes from Ubisoft Connect. No
  administrator rights needed, nothing in the game folder is changed.

Playing
  The window has three tabs:
  "New game"    Choose the options, then "Play with extensions".
                In the game, start a new endless game (or a scenario, see below).
  "Continue"    Your savegames with the settings they were made with. Select one and click
                "Play with these settings", then choose "Load Game" in the game. That way a big
                world is always loaded with the right size and the same options.
  "Adventures"  Your campaigns and challenges with your progress, the random adventures, the
                daily adventure, "Build your own scenario ..." and the check box "Unlock
                chapters one by one" (see below).
  "Start original" starts the game without any changes (e.g. for old saves).
  "Open logbook" opens the logbook window (see below).
  The window shows German on a German Windows and English otherwise.

What is changed (only in memory, no game file is modified):
  Map size             up to 2000 x 1400 tiles (original 500 x 350)
  Islands              up to 50 islands spread over the whole map (the game's maximum)
  Island size          Large / Huge: many more large islands (up to 10 of the largest, 100 x 90);
                       Giant: plus up to 6 giant islands (135 x 120 to 160 x 140), larger than any
                       island of the game. They grow from the game's largest islands; no rivers.
  Rivers               None: rivers become meadow, their mouths beach and surf, the spring a slope
  Mountains            At the coast: mountains in the middle of an island move to the coast, long
                       ranges as single mountains (rivers that spring from them go too); mountains
                       that are part of a native village and the rare ranges without room at the
                       coast stay
  Volcano              None: the game's only volcano becomes a normal mountain, no eruptions
                       (Rivers, mountains, volcano and giant islands: the tool writes changed island
                       files to %LOCALAPPDATA%\Anno1602-Extensions\islands once and lets the game read
                       them from there; for new games only, savegames keep their islands.)
  Explored             All islands from the start: their ore and gold deposits are visible and the
                       natives known without sailing there (also in loaded games).
  Resources            More: ore, gold, fertility and treasures to match the island count;
                       Lots: double that
  Natives              More / Lots: 4 + 4 or 7 + 7 villages instead of 2 + 2 (north + south)
  Fertility            "Every crop on every island": in new endless games every island with
                       fertile land grows all six crops (not in the scenarios)
  Free traders         More / Lots: two or three times as many trading ships (at most 24)
  Computer rivals      Always like "Hard": the three rivals arm and expand as on the
                       highest level, even if you play an easier one (natural events stay)
  Rivals' towns        Ambitious (with supplies): the rivals never make liquor, tobacco goods and
                       spices and hardly ever have bricks, so they stop at settlers. While the game
                       runs, the tool window tops up luxury goods, bricks and tools in their towns
                       (like a trader; their gold stays), and their building plan builds before it
                       moves on: they get tavern, school, church and so on and grow to citizens
                       and beyond
  Pirates              as per difficulty / always attack / strong / none
  Pirate fleet         Large / Huge: up to 8 or 12 pirate ships instead of 4 (only if pirates attack)
  Disasters            None: no fire, plague, drought or volcano. More often: fire and plague
                       twice as likely, drought checked twice as often
  Events               Rare / Often: random events while you play (see "Events" below)
  Rivals' gold         starting gold of the three computer rivals
  Your starting gold   starting gold in new games
  Residents per house  x1.5 to x5 (original 2/6/15/25/40, at x5 up to 200)
  Production speed     x1.5 to x3 for all production buildings
  Storage per good     x2 to x5
  Building costs       x0.75, half, a quarter or free: gold, tools, wood and bricks of every
                       building (also house upgrades and the computer rivals)
  Running costs        x0.75, half, a quarter or none (buildings; ships and soldiers keep theirs)
  Tax income           x1.5 to x3 (the tax rate slider works as before; also for the rivals)
  Influence radius     x1.5 or x2 for warehouse, market and the public buildings (chapel,
                       church, cathedral, tavern, doctor, bathhouse, theatre, school,
                       university, fire brigade, gallows)
  Ore and gold mines   Inexhaustible: deposits never run dry
  Ship speed           x1.5 to x3
  Cargo holds          More holds of 50 t for the ships you can build (small trading ship 6 or 8 instead of 4, at most 8)
  Turbo (F7 key)       8x, 12x or 16x speed (F5 = normal, F6 = 2x).
  Ultra (F8 key)       New key F8: 32x, 64x or 128x speed (the game has no F8 speed).
                       Measured: 16x holds exactly, at about half of one processor core.
  Building costs, running costs, tax income, influence radius, fertility, mines and disasters
  were checked in the running game on 12 November 2026. Events (new in version 3.0.0) were
  tested in the running game with a shortened interval; the two tax events only offline.

  Button "Everything big": sets everything big with one click (1000 x 700, huge islands,
  lots of resources, 7 + 7 native villages, three times as many traders, rivals like "Hard" with
  60,000 gold, pirates attack with a double fleet, residents x5, storage x5, 8 cargo holds per ship,
  production and ships x2, turbo 16x and F8 32x, your gold 50,000). You can still change single fields
  afterwards.

  Button "For campaigns": big map (1000 x 700, more islands) and turbo 16x, F8 32x, everything else
  as in the original. That way the campaigns are as hard as intended, and the starting gold
  comes from the scenario.

  Button "Giant world": the giant world 2000 x 1400 for the campaign "The World Empire" and
  the giant challenges (see "Giant world" below), ships x2 for the long voyages, turbo 16x and F8 32x,
  everything else as the scenario intends.

  Button "Relaxed": build in peace (1000 x 700, large islands, lots of resources, every crop
  everywhere, inexhaustible mines, building costs and running costs halved, taxes x2, radius
  x1.5, no pirates, no disasters, your gold 100,000, residents x2, production x2, storage x3,
  turbo 16x and F8 32x). Meant for the endless game: in a scenario the 100,000 gold replace its gold.

  Button "Tough test": rivals like "Hard" with 100,000 gold, strong pirates with a fleet of up
  to 12 ships, more disasters, 4 + 4 native villages, more resources, turbo 16x and F8 32x.

  Button "Reset to defaults": 1000 x 700 with more islands and more resources, everything
  else as in the original.
  Every button sets "Events" to "Off" - choose "Rare" or "Often" afterwards if you want them.

Events (option "Events" in the group "Rivals and dangers": Off / Rare / Often)
  While the game runs, the tool window triggers random events: with "Rare" about every 3 game
  hours, with "Often" about every game hour. They start only once you have a town of your own,
  and they follow the game clock: a paused game has none, turbo speeds them up. The tool window
  (the black window) must stay open. The events:
    A patron               +2,000 to +10,000 gold (the more, the higher your residents have
                           risen)
    Fire in the warehouse  -5 % of your gold (only with at least 2,000 gold)
    A trader's gift        10 to 30 t tools, wood, bricks or food in your biggest town (as much
                           as its storage holds)
    Tax windfall           taxes x1.5 for one game hour
    Tax slump              taxes x0.75 for one game hour
    Bumper harvest         all farms and workshops work x1.5 as fast for one game hour
    Marsh fever            all farms and workshops work x0.75 as fast for one game hour
  Taxes and production are the same for everybody in the game: the rivals gain or lose too.
  Gold and goods are real changes and are saved with the game. A tax or production event ends
  after one game hour, when another game is loaded or started, when the game ends or when the
  tool window closes - the values are then exactly as before. Every event appears in the
  logbook.

Logbook
  A small window next to the game ("Open logbook" in the launcher, or tick "Open the logbook
  with the game"). It only READS the game's memory and changes nothing. It has two tabs:
  "Game":
    - your mission goals with live progress bars (green = met); in a race how close the
      rivals are, with a time limit the time left,
    - gold, balance and trade balance, your towns, residents per class, ships,
    - the rivals' best towns,
    - the events of this game with their effect (green = good, red = bad),
    - after a game a card "Last game": result, game time, most residents, most gold, towns,
      highest class and the achievements of that game,
    - 53 achievements, e.g. "Land Ho!" (first town), "Metropolis" (2,500 residents in one
      town), "Millionaire", "Full Speed Ahead" (turbo), "Saga Complete" (every chapter of a
      campaign won), "Hat Trick" (three wins in a row), "Regular" (ten games played).
  "History":
    - four charts: gold, residents per class, balance, towns and ships - one point per game
      minute; point at a chart to see the values,
    - the list of your played games; a click shows the charts and the card of that game.
  Click a section heading to fold the section away. "On top" keeps the window above the game,
  "Compact" makes it small. Play in window mode or put the logbook on a second monitor. The
  logbook may run before, during and after the game; it connects by itself.
  Achievements, finished missions and played games are kept in
  %APPDATA%\Anno1602-Extensions\logbook.json, the charts of the newest 30 games in the folder
  "history" next to it. The "Adventures" tab shows from logbook.json which chapters you have
  won - so keep the logbook open while you play a chapter.

Campaigns and challenges (49 own scenarios with a story and a mission)
  In the game: Single Player -> New Game -> at the very bottom of the list, "Own Scenarios"
  ("Eigene Szenarien" in the German game).
  When the mission is fulfilled, the scenario ends with the score screen.
  The scenarios are installed in the language of Windows: English titles and mission texts
  on an English Windows (German names given in brackets below), German on a German Windows.
  Not yet balance-tested in play (marked *): the campaigns "The Storm Sea" (November 2026),
  "The New World" and "The Trade League" (new in version 3.0.0), "The World Empire" (new in
  version 3.1.0) and the challenges Archipelago, Continents, Merchant Fleet, Sea Power, the six
  from Colonial Lord to The Royal Deadline and the giant ones Seven Seas and Around the World. Their difficulty is designed by analogy with the measured chapters.

  Campaign "Emerald Isles" ("Die Smaragdinseln"; play the chapters in order):
    1 Landfall            (Landung) town of 250 residents (150 settlers),
                          positive balance                                               Easy
    2 Spice Fever         (Gewuerzfieber) spice monopoly (own every spice island),
                          500 res./250 citizens                                       Average
    3 Two Colonies        (Zwei Kolonien) 800 res./300 merchants and 500 res./
                          250 citizens, balance +300                                  Average
    4 Black Sails         (Schwarze Segel) 1000 res./500 merchants, 20 t cannons and
                          40 t muskets, pirates attack; start with a small warship  Demanding
    5 The Conqueror       (Der Eroberer) defeat all three rivals, pirates attack;
                          start with a large warship                                Demanding
    6 Crown of the Isles  (Krone der Inseln) 3 towns, the largest with 2500 res./1200
                          aristocrats, balance +1000, pirates; start with a large
                          trading ship                                                   Hard

  Campaign "Race" ("Wettlauf der Haeuser", Race of the Houses): the three rivals have the
  SAME mission. Whoever fulfils it first wins - if a rival is faster, the scenario is lost.
    1 First Harbour       (Erster Hafen) 300 res./150 settlers                           Easy
    2 Civic Pride         (Buergerstolz) 700 res./350 citizens and a second town of
                          200/100 settlers                                            Average
    3 Merchant Republic   (Kaufmannsrepublik) 1000 res./400 merchants, pirates      Demanding
    4 The Crown           (Die Krone) 1500 res./600 aristocrats, balance +500,
                          pirates                                                        Hard
  Measured (rivals without any action by the player, big map, pirates only sighted, normal
  game time): the fastest rival wins chapter 3 after about 8 hours, chapter 4 after about
  20 hours. The time counts in the game, not in front of the screen: with turbo the rivals
  are faster too.
  Tip: the pirates sink a ship that lies idle at sea for a long time. Without a ship and
  without a town the game is lost - so settle early.

  Campaign "Storm Sea" ("Die Sturmsee"; play the chapters in order) *:
  A storm scatters your convoy; you rebuild the colony, win the trade of the Storm Sea,
  fight off pirates and the treacherous House Valcourt and finally unite the islands.
    1 Shipwreck           (Schiffbruch) town of 200 res./100 settlers and a second
                          settlement on another island, positive balance; only
                          10,000 gold and a half-empty ship (20 t tools, 12 t wood,
                          8 t food)                                                   Average
    2 Tobacco and Cocoa   (Tabak und Kakao) tobacco monopoly AND cocoa monopoly,
                          600 res./300 citizens; the rivals play like Demanding       Average
    3 The Free Port       (Der Freihafen) trade balance +400, 40 t tobacco goods and
                          40 t cocoa in store; a large trading ship with cloth and
                          liquor to sell                                            Demanding
    4 The Red Flag        (Die Rote Flagge) at least 3 settlements, EVERY one with
                          300 res./100 citizens, pirates attack; two small warships
                          and 10 t cannons for watchtowers                          Demanding
    5 Betrayal            (Verrat) defeat House Valcourt (rival 2, rich, flagship
                          "Valcourt Pride"; the other two rivals may stay),
                          1000 res./400 merchants; rivals like Hard; a large and a
                          small warship                                             Demanding
    6 The Golden Age      (Das Goldene Zeitalter) 2000 res./800 aristocrats and
                          1200 res./500 merchants, 4000 in total, 40 t jewellery,
                          balance +800, pirates; a large trading ship with building
                          materials and a large warship                                  Hard

  Campaign "The New World" ("Die Neue Welt"; play the chapters in order) *:
  An expedition of the Crown lands on a coast that is on no map, full of native villages (up
  to 5 + 5, on the big map 7 + 7); you explore the land, live in peace with its peoples, ship
  a treasure fleet home, stop the conquistador House Valdoro and become the first viceroy.
    1 The Crossing        (Die Ueberfahrt) town of 300 res./150 settlers, at least
                          3 settlements, positive balance; a small trading ship
                          ("Pathfinder") with tools and wood for a second outpost        Easy
    2 Sugar and Rum       (Zucker und Rum) sugar monopoly (own every island where sugar
                          cane grows), 40 t liquor in store, 500 res./200 citizens    Average
    3 Land of Many        (Land der vielen Voelker) a few huge islands shared with many
      Peoples             native villages: 800 res./300 merchants, at least
                          4 settlements, EVERY one with 200 res./80 settlers;
                          the rivals play like Demanding                              Average
    4 The Treasure Fleet  (Die Schatzflotte) 60 t spices and 40 t gold in store, trade
                          balance +300, pirates attack; a large trading ship with
                          building materials and a small warship                    Demanding
    5 The Conquistador    (Der Konquistador) defeat House Valdoro (rival 3, 70,000 gold,
                          flagship "Valdoro Wrath"; the other two rivals may stay),
                          at least 4 settlements, 2500 residents in total; rivals like
                          Hard; a large and a small warship                         Demanding
    6 The Viceroy         (Der Vizekoenig) 2000 res./800 aristocrats, 1200 res./
                          500 merchants and 600 res./250 citizens, at least
                          6 settlements, balance +800, pirates; a large trading ship
                          with building materials and a large warship                    Hard

  Campaign "The Trade League" ("Die Handelsliga"; play the chapters in order) *:
  As the youngest factor of the League of the Seven Cities you build up its trade across the
  ocean - with ledgers instead of cannons: goods, trade balance and profit in every chapter.
  The rivals play at most like Demanding.
    1 The First Warehouse (Das erste Kontor) town of 250 res./120 settlers, 30 t cloth
                          in store, trade balance +100                                   Easy
    2 Market Day          (Markttag) 500 res./200 citizens, 40 t tobacco goods and
                          40 t spices in store (two climates); a small trading ship   Average
    3 The Warehouse       (Das Kontornetz) many small islands: at least 6 settlements,
      Network             EVERY one with 150 res./60 settlers, trade balance +200;
                          extra cargo and a small trading ship                        Average
    4 The Cotton Cartel   (Das Baumwollkartell) cotton monopoly, 50 t clothes in store,
                          trade balance +300, pirates attack; a small warship       Demanding
    5 The League Bank     (Die Bank der Liga) 1200 res./600 merchants, balance +500,
                          trade balance +400                                        Demanding
    6 The Merchant Prince (Der Fuerst der Kaufleute) 2000 res./700 aristocrats,
                          50 t jewellery in store, trade balance +500, balance +800,
                          pirates; a large trading ship with building materials and
                          a large warship                                                Hard

  Campaign "The World Empire" ("Das Weltreich"; play the chapters in order; made for the
  giant world) *:
  Five island realms, weeks of open sea apart: from the Crown Sea in the north-west you reach
  out to the Mist Sea, the Spice Islands and the Coral Sea, defeat House Morvan and build the
  first world empire.
    1 The Great Voyage    (Die grosse Fahrt) town of 500 res./250 settlers, at least
                          3 settlements, 900 residents in total; a large trading ship
                          with tools, wood and food                                      Easy
    2 The Mist Sea        (Das Nebelmeer) 50 t cloth and 40 t tobacco goods in store,
                          800 res./300 citizens, at least 4 settlements                Average
    3 The Spice Route     (Die Gewuerzroute) 60 t spices in store, trade balance +250,
                          1200 res./400 merchants, pirates attack; a large trading
                          ship and a small warship                                    Average
    4 The Coral Sea       (Die Korallensee) cotton monopoly AND cocoa monopoly, at least
                          5 settlements with 3000 residents in total, pirates attack  Demanding
    5 War of the Crowns   (Krieg der Kronen) defeat House Morvan (rival 2, 80,000 gold,
                          flagship "Iron Fist"; the other two rivals may stay), at least
                          5 settlements, 4000 residents in total; rivals like Hard;
                          a large and a small warship                               Demanding
    6 The World Empire    (Das Weltreich) 3000 res./1200 aristocrats, 2000 res./
                          800 merchants and 1200 res./500 citizens, at least
                          7 settlements, 8000 in total, balance +1500, pirates; a large
                          trading ship with building materials and a large warship       Hard

  Challenges (single scenarios):
    Island Realm          (Inselreich) 8 own settlements with 3000 residents in total
    Trade Empire          (Handelsimperium) 50 t jewellery and 80 t clothes in store,
                          trade balance +300
    Gold Rush             (Goldrausch) 60 t gold and 40 t jewellery in store, pirates;
                          start with a small warship
    Archipelago *         (Archipel) dozens of small islands: at least 10 settlements, EVERY
                          one with 100 res./40 settlers (a warehouse without houses counts
                          as a settlement too); extra cargo and a small trading ship
    Continents *          (Kontinente) a few huge islands: 1500 res./400 aristocrats,
                          3000 in total, balance +300
    Merchant Fleet *      (Handelsflotte) 4 settlements, 60 t spices and 60 t cocoa in store;
                          only 15,000 gold, but two large trading ships full of goods
                          and a small warship
    Sea Power *           (Seemacht) defeat all three rivals; they are poor (10,000 gold),
                          you have 60,000 gold, two large and one small warship
    Colonial Lord *       (Kolonialherr) wine monopoly (north) AND cocoa monopoly (south),
                          at least 4 settlements, EVERY one with 250 res./80 citizens
    Monopolist *          (Monopolist) spice monopoly AND tobacco monopoly, trade balance
                          +400; rich rivals like Hard; start with a large warship
    Calm Seas *           (Ruhige See) no pirates, but barren islands and rich rivals like
                          Hard: 1200 res./500 merchants, 2500 in total, balance +300
    Shoestring *          (Habenichts) only 8,000 gold and 15 t tools, 10 t wood, 5 t food:
                          600 res./250 citizens, balance +200; rivals like Demanding
    Against the Clock *   (Gegen die Uhr) 500 res./250 settlers - TIME LIMIT 3 hours
    The Royal Deadline *  (Die Frist des Koenigs) 1000 res./400 citizens, balance +300 -
                          TIME LIMIT 6 hours; pirates attack; start with a small warship
    Seven Seas *          (Sieben Meere; giant world) at least 7 settlements, EVERY one with
                          300 res./120 settlers, 4000 in total, balance +300, pirates
    Around the World *    (Die Weltumsegelung; giant world) wine monopoly (north) AND spice
                          monopoly (south), trade balance +400, pirates attack

  Giant world: the game holds at most 50 islands (10 of the biggest kind), so the giant maps
  of "The World Empire", Seven Seas and Around the World group them into five island realms
  with open sea between them - the Crown Sea in the north-west (where all ships start), the
  Mist Sea in the north-east, the Middle Sea, the Coral Sea in the south-west and the Spice
  Islands in the south-east. Choose the button "Giant world" before you play (map 2000 x 1400).
  With a smaller map the 1000 x 700 version or the classic map applies.

  Time limits: "Against the Clock", "The Royal Deadline" and scenarios you build yourself can
  have one. When the time runs out, the mission is lost.
    - The limit applies only with the extensions: the tool sets it at every start and at every
      load of a savegame. With "Start original" the same scenario has no limit.
    - While a limit is set, the game shows its own clock at the bottom left: the elapsed game
      time as minutes:seconds. "180:00" is the end of a 3-hour limit, "360:00" of a 6-hour one.
    - The logbook shows the time left, e.g. "Time limit: 2 h 44 min left (clock 15:03 of
      180:00)".
    - It is game time: a pause stops the clock, turbo makes it run faster (and wins you no
      time). At normal speed one hour on the clock takes about 66 minutes.

  Unlock chapters one by one (check box in the "Adventures" tab, off at first): the game's list
  then holds of each campaign only the chapters up to the first one you have not won yet. The
  later ones are shown in the launcher in grey with a lock ("locked - win chapter 2 first").
  After a win the launcher adds the next chapter when it starts again ("just unlocked"). The
  wins are recorded by the logbook, so keep it open while you play a chapter. Untick the box
  and every chapter is back in the game's list. Challenges and adventures are never locked.

  Random adventures ("Adventures" tab): choose a difficulty (Easy, Average, Demanding, Hard),
  optionally a number from 0 to 999999, and click "Roll an adventure". The scenario
  "Adventure <number> <difficulty>" (e.g. "Adventure 4711 Demanding"; "Abenteuer 4711 Fordernd"
  on a German Windows) appears in "Own Scenarios".
  Every adventure has its own island world (classic, an archipelago of small islands or a
  few huge continents) and one main goal - towns, a realm of many settlements, trade, a
  monopoly or conquest - plus extras that grow with the difficulty. Starting gold, pirates,
  the rivals' strength and your start cargo follow the difficulty too.
  The same number with the same difficulty always gives the same adventure, so you can play
  a map again or give the number to a friend. The same number with another difficulty
  is an adventure of its own.

  Daily adventure (button "Daily adventure" next to "Roll an adventure"): one adventure per
  day, always Average and the same for everyone on that date - "Daily Adventure 2026-11-15"
  ("Tagesabenteuer 2026-11-15" on a German Windows) in "Own Scenarios". Earlier ones stay in
  the list.

  Build your own scenario ("Build your own scenario ..." in the "Adventures" tab): a window
  in which you put a mission together yourself.
    Scenario   name (up to 40 characters), map (Classic, Archipelago or Continents), map
               number ("New map" rolls another; the same number always gives the same map),
               difficulty, and if you like "also for the giant world 2000 x 1400" (a third map
               with five island realms)
    World      your starting gold, the rivals' gold and strength (Hesitant to Strong),
               pirates (only sighted or attacking), natives, resources, start cargo
               (Standard, Rich, Lean, Shipwreck), up to 3 extra trading ships or warships
    Mission    any mix of goals: up to 3 towns (residents, of which so many of a class or
               higher), every settlement at least ..., number of settlements, residents in
               total, balance, trade balance, up to 2 goods in store, up to 2 monopolies,
               defeat rival 1, 2 or 3 - and if you like a time limit of 1 to 50 game hours
    Story      written for you to match the map and the mission; change it as you like or
               get a new one with "New story"
  The preview shows the mission text exactly as the game will show it, and the small and the
  big map. Errors are shown in red (then nothing can be built), hints in orange. "Create
  scenario" puts it into "Own Scenarios" as "Custom - <name>" ("Eigenes - <Name>" on a German
  Windows), and the launcher selects it in its list. Your last design is remembered.

  Big maps: every scenario (also the random and daily adventures and your own) has two
  versions. With "Start original" the classic map applies (500 x 350, mostly 17-20 islands).
  With "Play with extensions", map size 1000 x 700 (or bigger) and "More islands" the big
  version applies: up to 50 islands, more resources and natives. The rival, pirate, resident,
  storage, turbo, event and the economy options work here too; "Every crop on every island"
  does not (it would break the monopoly missions). The gold options replace the starting gold
  of the scenario; for the intended balance choose "As per difficulty" (or the button "For
  campaigns").
  The files are in Documents\Anno 1602 History Edition\Own Scenarios.

  There are no more than 3 computer rivals: the game has a fixed 4 player slots (you + 3), plus
  traders, pirates and natives in fixed slots, 4 flag colours and a fixed savegame format.
  The rivals get stronger instead.

Important:
  - Load saves from the big world only with the extensions and the same map size - easiest
    through the "Continue" tab. The save itself does not store the size.
  - The black window stays open until the game has ended. Then an automatic save
    ("Continue game", "Spiel fortsetzen" in the German game) from the big world is renamed,
    so that the game without the extensions does not load it, and the options of every save
    written in this session are noted for the "Continue" tab. Do not close the window before.
    Afterwards it closes by itself; it stays open only if something went wrong.
  - Events need the black window too: it triggers them and puts taxes and production back
    afterwards. Closing it ends a running event; the game goes on.
  - Before every start the saves are backed up (Documents\Anno 1602 History Edition\
    Savegame-Backup-<date>), but only if something has changed. The first backup and the
    newest five are kept; older ones go to the recycle bin.
  - Single player only and only for the Ubisoft Connect version. After an update of the
    game the tool no longer fits and stops without changing anything.

Files (in the folder %LOCALAPPDATA%\Programs\Anno1602-Extensions):
  launcher.ps1          the window
  anno-patcher.ps1      the tool (can also be used directly, see the top of the file for options)
  logbook.ps1           the logbook window
  random-adventure.ps1  the random adventure generator (also the daily adventure)
  scenario-designer.ps1 the window for building your own scenario
  build-scenarios.ps1   builds the scenarios (used by the installer, the generator and the designer)
  scenario-lib.ps1      reading and writing scenario files
  README.txt            this guide
  README.de.txt         this guide in German
  FINDINGS.md           technical description of every patch site in the game code
  Your settings, the savegame options, the logbook with the charts of your games, the events
  and your last design: %APPDATA%\Anno1602-Extensions
