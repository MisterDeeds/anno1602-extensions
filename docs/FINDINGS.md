# Anno 1602 History Edition – Findings

Goal: bigger worlds, more rivals, more possibilities.
Target file: `Anno1602.exe` from
`C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Anno 1602 - History Edition`.

Legend: **O** = observed (measured directly), **I** = inferred, **?** = open.

Note: the evidence files referenced below (screenshots in `analysis/test/`, Ghidra output in `analysis/scan/`,
the exe copy in `analysis/bin/`, helper scripts used only during testing) are not part of the repository
(see `.gitignore`). The references are kept as a record of what was measured. German game texts (menu items,
difficulty levels, scenario and building names) are quoted as the German game shows them, with an English
gloss in parentheses on first use.

## Tools

| Tool | Version | Location |
|---|---|---|
| Ghidra | 12.1.4 (version verified by REA) | `%LOCALAPPDATA%\Programs\Ghidra\ghidra_12.1.4_PUBLIC` |
| JDK | Temurin 21.0.13 | `C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot` |
| Node.js | 26.13.0 | winget |
| REA | 6.8.0 | `npm -g rea-agents`, MCP registered in `~/.claude.json` |
| Git | 2.56.0 | winget |

Decrypt/encrypt `.cod` files: `dev/cod.ps1` (every byte negated).
Map size and all game options: `src/anno-patcher.ps1`, start together with the game: the launcher window `src/launcher.ps1`, offline test `tests/test-patcher.ps1`, island plan as an image `dev/show-island-plan.ps1`, scenarios `src/build-scenarios.ps1` with `src/scenario-lib.ps1` (check: `tests/check-scenarios.ps1`), random adventures `src/random-adventure.ps1`, logbook window `src/logbook.ps1`, read-only checks of the running game `dev/check-game.ps1` and `dev/check-islands.ps1`, installer `src/install.ps1`, player guide `src/README.txt` (German: `src/README.de.txt`).
Ghidra helper scripts: `AnnoAsm.java` (instructions from an address), `AnnoPatchDis.java` (put bytes into Ghidra's in-memory program only and disassemble them).
Note: `dev/ghidra-scan.cmd` needs `GHIDRA_INSTALL_DIR` and `JAVA_HOME` in the process environment. If the shell was started before the variables were set, they are missing ("Das System kann den angegebenen Pfad nicht finden", the system cannot find the path specified); in that case take them over from the user or system variables first.

## Structure of the exe

- **O** x64 PE, built 2020-08-05 with MSVC linker 14.16 (Visual Studio 2017), file/product version 1.0.0.0, signed by Ubisoft Blue Byte GmbH.
- **O** Not packed: normal sections `.text` (934 KB code), `.rdata`, `.data`, `.pdata`, `.rsrc`, `.reloc`.
- **O** `.pdata` has 29,100 bytes → about 2,400 function entries (start/end of every function known).
- **O** `.data`: 8.5 MB in memory, but only 14 KB in the file → about 8.5 MB of fixed, reserved data areas that are empty at startup.
- **I** These hold the game-world tables of fixed size (typical of code from 1998). A bigger world means: move these areas and adapt every place that accesses them.
- **O** Graphics via Direct3D 11 (`d3d11.dll`, `dxgi.dll`), videos via Bink 2.
- **O** Ubisoft Connect (`uplay_r1_loader64.dll`) is imported only by `MaxNet.dll`, not by `Anno1602.exe`. Multiplayer, online overlay and tracking go through the 35 `Maxnet*` functions.
- **O** Settings in the registry under `HKCU\Software\Ubisoft\Anno1602HistoryEdition` (among others `UI_SCALE`, `WINDOW_MODE`, `NEW_UNIT_CONTROLS`, `RIGHT_CLICK_SCROLLING`).
- **O** Start option `-nointro`.

## Data and formats

- **O** Savegame chunks as in the original: `INSEL3/4/5`, `INSELHAUS`, `KONTOR/KONTOR2`, `SHIP4`, `SHIPS`, `PLAYER2/3/4`, `SZENE*`, `TIMERS`, `AUFTRAG*`, `HANDLER`, `SOLDAT1-4` etc.
- **O** Buildings, figures and texts are in `haeuser.cod`, `figuren.cod`, `Editor.cod`, `text.cod` (or `Loca\de-DE\…`).
- **O** The `.cod` parser knows these keywords (excerpt): `Maxlager`, `Maxprodcnt`, `Maxwohn`, `Interval`, `Radius`, `Rohmenge`, `Arbeiter`, `Kosten`, `Steuer`, `Maxtrag`, `Maxkanon`, `Maxware`, `Maxenergy`, `Hitpoint`, `Speed`, `Shotradius`, `Preis`, `MAXHAUS`, `MAXFIGUR`.
- **O** The goods names are a fixed list in the exe: `EISENERZ, GOLD, WOLLE, ZUCKER, TABAK, FLEISCH, KORN, MEHL, EISEN, SCHWERTER, MUSKETEN, KANONEN, NAHRUNG, TABAKWAREN, GEWUERZE, KAKAO, ALKOHOL, STOFFE, KLEIDUNG, SCHMUCK, WERKZEUG, HOLZ, ZIEGEL`.
- **I** New goods need changes in the exe; new values for existing goods and buildings go through `.cod`.
- **O** Building kinds are fixed keywords as well (`HANDWERK`, `PLANTAGE`, `BERGWERK`, `WOHNUNG`, `KONTOR`, `MARKT`, …).

## Ghidra analysis

Ghidra 12.1.4 via REA (`rea analyze`, evidence `ev_390cb815…`) and own headless scripts
(`dev/ghidra-scan.cmd`, scripts in `dev/ghidra_scripts/`, results in `analysis/scan/`).
The analysed file is the copy `analysis/bin/Anno1602.exe`, SHA-256 `7731972f…b7a1` (identical to the original).

- **O** 1,546 functions, 1,278 strings. A PDB `anno1602.pdb` is referenced but not shipped → no original names.

## Map size 500 × 350

- **O** Width and height are stored in two global variables: `DAT_1405ebe40` (width) and `DAT_1405ebe98` (height).
- **O** Three more variables depend on the size and are set at the same two places (found on 2026-11-08, see below):
  `DAT_1405eb840` = scroll range = width/2 + height/2 (425), `DAT_1405ebc7c` = 1/width (float 0.002), `DAT_1405ebc80` = 1/height (float 1/350).
- **O** All places that set them (10 bytes each, `C7 05 <rel32> <imm32>`, the value starts at byte 6; file offset = RVA − 0xC00):

  | VA | Original bytes | Instruction | Function |
  |---|---|---|---|
  | `0x1400DC7E5` | `C7 05 51 F6 50 00 F4 01 00 00` | width = 500 | `FUN_1400dbc60` (program start) |
  | `0x1400DC7EF` | `C7 05 9F F6 50 00 5E 01 00 00` | height = 350 | `FUN_1400dbc60` |
  | `0x1400DC7F9` | `C7 05 3D F0 50 00 A9 01 00 00` | scroll range = 425 | `FUN_1400dbc60` |
  | `0x14008DC90` | `C7 05 A6 E1 55 00 F4 01 00 00` | width = 500 | `FUN_14008cef0` command `0x36` (new game) |
  | `0x14008DC9A` | `C7 05 F4 E1 55 00 5E 01 00 00` | height = 350 | `FUN_14008cef0` |
  | `0x14008DCA4` | `C7 05 92 DB 55 00 A9 01 00 00` | scroll range = 425 | `FUN_14008cef0` |
  | `0x14008DCAE` | `C7 05 C4 DF 55 00 6F 12 03 3B` | 1/width = 0.002f | `FUN_14008cef0` |
  | `0x14008DCB8` | `C7 05 BE DF 55 00 E7 3E 3B 3B` | 1/height = 1/350f | `FUN_14008cef0` |

- **O** At program start `FUN_1400dbc60` does not set 1/width and 1/height as immediates but with `MOVSS` from `.rdata` `0x1400EB8F4`/`0x1400EB8F8` (at `0x1400DC7D5` and `0x1400DC80A`). `0x1400DC812` (1/height) is the last of the five assignments. No other code uses these two `.rdata` constants (RIP-relative search over all of `.text`).
- **O** Width/height are read by 22 functions: bounds checks (`0 <= x < width`), camera/minimap, random placement (`FUN_140077210` with `rand()`), and two grids that are allocated with `VirtualAlloc` to match the size (`FUN_14009ce30`: grid of 16×16-tile blocks, max. 50 islands; `FUN_140043690`: only a temporary buffer for drawing the minimap, freed again right away).
- **O** `FUN_14009ce30` is called among others by command `0x36` (via `FUN_14009b400`) and by loading (`FUN_1400d0de0`), so the grid is recreated for every new game and every load.
- **O** Raw count in the machine code: the value 500 appears 124 times in the code, but most of them are other limits (e.g. max. 500 UI elements in `FUN_14000d3b0`). The values 700/350 in `FUN_1400bc030` are game-logic thresholds (random events), not the map size. `500.0f` (`0x1400EBA80`) is only the knots display of the ships (`FUN_14004ffc0`).
- **I** In the remaster the world size is largely implemented as a variable. A test with bigger values is realistic.

### Camera and scroll bars (analysis 2026-11-08)

- **O** The camera (`PTR_DAT_1400f9a00`) has two coordinate sets: field `+0x1c/+0x20` (world position x/y) and `+0x24/+0x28` (rotated scroll coordinates), rotation in `+0x48` (0–3). `FUN_1400c4ba0` (world → scroll) and `FUN_1400c4ca0` (scroll → world) calculate with width/2 and height/2, e.g. at rotation 0: `s = H/2 − (y−x)/2`, `t = (x+y)/2`.
- **I** It follows that both scroll coordinates run from 0 to width/2 + height/2. That is exactly `DAT_1405eb840` (500/2 + 350/2 = 425).
- **O** Edge scrolling (`FUN_1400dd190`) and the arrow keys (`FUN_1400e2d60`, cases `0x27/0x28`) clamp the scroll coordinates to `DAT_1405eb840` (`CMP`/`CMOVG` at `0x1400DD2E4`, `0x1400DD419`, `0x1400E2E7F`, `0x1400E2F93`). `FUN_1400c4dc0` (scroll bar commands) does the same.
- **I** With the first version of the tool (width/height only) the camera at 1000 × 700 would have been limited to `x + y ≤ 850`, i.e. roughly the old area plus a margin. A click on the minimap could have jumped further, but the next edge scroll would have reset the camera. **That was a bug in the tool; fixed.**
- **O** The 21 `IMUL …, 0x1f4` compute `scroll coordinate × 500 / DAT_1405eb840`. The 500 is the resolution of the scroll bar (0–500), not the map width. There is no conversion in the opposite direction with `DAT_1405eb840` (all reads checked).
- **I** The fixed multiplications by 500 do not need a patch. With scroll range 850 the bar still moves proportionally, only somewhat coarser.
- **O** `DAT_1405ebc7c`/`DAT_1405ebc80` (1/width, 1/height) are read only in `FUN_14008ba70` and `FUN_14008bc50` (called from `FUN_14005ff70`, the minimap): world position × 1/width × map width in pixels → marker dot on the minimap (table with 200 entries from `0x1401d8bb8`).
- **I** Without adjustment these markers would be twice as far from the origin at 1000 × 700 (outside the minimap from the middle of the map on). **Also added to the tool.**
- **O** Large fixed data areas are pools with a fixed capacity, not arranged by coordinates. Example: raw-material growth (`ROHWACHS2`) 262,512 entries × 8 bytes from `0x14034d530` (`FUN_1400c42d0`); 750 entries × 2,224 bytes from `0x14077b744` (`FUN_140002c00`).
- **I** In a much bigger world with more islands these pools can fill up.
- **O** `FUN_14008cef0` is the game's command processor (113 callers). Command `0x36` resets the world ("new game"): among others it calls `FUN_14009b400` (recreates the 16×16 grid via `FUN_14009ce30`) and `FUN_1400a87f0` (player table). After that it sets width = 500, height = 350 and `DAT_1405eb840` = 425.
- **O** Apart from these 4 places nothing writes width/height, not even loading a savegame (`FUN_1400d0de0` only reads).
- **I** A savegame does not store the world size. Load savegames from a bigger world only with the same setting.
- ~~`DAT_1405eb840` = 425 is the range of the scroll bars … edge scrolling and minimap read the variables.~~ Corrected, see "Camera and scroll bars": `DAT_1405eb840` is the camera range, and edge scrolling and the arrow keys are clamped to it.

### Islands in the endless game (analysis 2026-11-08, after the game test)

- **O** In a game at 1000 × 700 all islands are in the old area at the top left (`analysis/test/02-minikarte-start.png`).
- **O** The endless-game templates are `Szenes\[[48]]00.szs` … `[[48]]32.szs` (12 files of 14,540 bytes each; probably 4 difficulty levels × 3 variants). They contain no `INSEL` sections, only `SZENE_*`, `RANDTAB` (1,024 bytes of random numbers), `AUFTRAG4`, `SZENE`, `PLAYER4`, `SHIP4`, `TIMERS`.
- **O** In the `SZENE` section (1,172 bytes) the island count is at +0x64, and from +0x174 there are up to 50 entries of 16 bytes each: climate (0 north, 1 south, 2 by position), size class (index into `lit/mit/med/big/lar`, table `0x1400EA200`), flags (bit 0: natives), slot, file number (`0xFFFF` = random), x (int32 at +8), y (int32 at +0xC).
- **O** `[[48]]10.szs` has 18 islands, x 50–440, y 20–280: all positions are fixed and lie within 500 × 350. Only the choice of the island file within the size class is random (`"%s%s%s%02d.SCP"` in `FUN_1400d0de0`).
- **O** For climate 2 the `SZENE` loader `FUN_1400d0de0` sets the climate from the centre of the island: upper third of the height north, lower third south, in between random (via `DAT_1405c4940`). It uses the height variable for this.
- **I** With height 700 the boundaries are at 233 and 466 instead of 116 and 233. Template islands with climate 2 in the band y ≈ 250–280 therefore no longer become south for sure, but random. The four islands marked as fixed south stay south. Result: on average slightly fewer southern islands than in the original.
- **O** `FUN_140068650` (place an island at the mouse position, editor) and `FUN_140077210` (random point ±90 tiles around a position, coordinates packed into 12 bits) respect the variables.
- **I** To fill the new area, own island positions are needed: either own scenarios (separate folder "Own Scenarios", no game file) or a patch that stretches the positions by width/500 and height/350 when an endless template is loaded (only for templates, not for savegames). Implemented as a patch, see the next section.

### Spreading the islands (implemented 2026-11-08)

- **O** Savegames (`.gam`) contain no `SZENE` section (checked on `Welt1000x700.gam`: `AUFTRAG4, HANDLER, HIRSCH2, INSEL5, INSELHAUS, KONTOR2, MARKT2, MILITAR, NAME, PLAYER4, PRODLIST2, ROHWACHS2, SHIP4, SIEDLER, SOLDAT3, STADT4, TIMERS, TURM, WERFT, WIFF`). A change in the `SZENE` loader therefore only affects scenario templates.
- **O** Entry point in `FUN_1400d0de0` after the name check "SZENE" at `0x1400D0E29`: `4C 8D 1D D0 F1 F2 FF` = `LEA R11,[0x140000000]` (7 bytes). There `R15` points to the section data (`MOV R15,RDX` at `0x1400D0DFC`). The flags are not live (the next flag reader is `CMP [R15+0x64],R13D` at `0x1400D0E65`); `R8` is live (`LEA R10D,[R8-5]`) and is saved. No jump targets the replaced bytes.
- **O** Free space: `.text` has VirtualSize `0xE40F3` and is mapped in memory up to RVA `0xE5FFF`; RVA `0xE5100`–`0xE51FF` is all `00` in the file and in the image.
- **O** Replacement at `0x1400D0E29`: `E9 D2 42 01 00 66 90` (`JMP 0x1400E5100`, 2-byte NOP). Code stub at `0x1400E5100` (103 bytes), disassembled by Ghidra (`dev/ghidra_scripts/AnnoPatchDis.java`):

  ```
  1400e5100  PUSH RAX / PUSH RCX / PUSH RDX / PUSH R8 / PUSH R9
  1400e5107  MOV R8D,dword ptr [R15 + 0x64]        ; island count
  1400e510b  LEA R9,[R15 + 0x174]                  ; first entry
  1400e5112  CMP R8D,0x32 / JA 0x1400e5154         ; more than 50: do nothing
  1400e5118  TEST R8D,R8D / JLE 0x1400e5154        ; loop
  1400e511d  MOV EAX,[R9 + 0x8] / IMUL EAX,[0x1405ebe40] / CDQ / MOV ECX,500 / IDIV ECX / MOV [R9 + 0x8],EAX
  1400e5134  MOV EAX,[R9 + 0xc] / IMUL EAX,[0x1405ebe98] / CDQ / MOV ECX,350 / IDIV ECX / MOV [R9 + 0xc],EAX
  1400e514b  ADD R9,0x10 / DEC R8D / JMP 0x1400e5118
  1400e5154  POP R9 / POP R8 / POP RDX / POP RCX / POP RAX
  1400e515b  LEA R11,[0x140000000]                 ; replaced original instruction
  1400e5162  JMP 0x1400d0e30
  ```
- **I** The islands keep their size; only the corner is stretched. Because the factor is ≥ 1, every island still fits into the world (x' + width ≤ x + 500 ≤ world), and the distances between islands only grow, so no overlaps arise. The climate thirds (top north, bottom south) match the original again because y grows as well.
- **I** Affects every scenario template, so also campaign scenarios (where fixed ships and missions may no longer be near the islands). The tool is meant only for the endless game. Can be switched off with `-NoIslandSpread`. Start ships from `SHIP4` are not moved (that section is also in savegames).

**Offline test (O):** `tests/test-patcher.ps1`, **128 of 128** passed. New: case G (`-NoIslandSpread` leaves the jump and the code stub untouched) and case I, a functional test: in the helper process the real code stub runs at its real address in the image, called through a thread with the real `SZENE` section from `[[48]]10.szs` (the return path replaced by `pop r15; ret` only in the helper process's image). Result: all 1,172 bytes as expected for 1000 × 700 (island 0: (280, 90) → (560, 180)), 750 × 525, 2000 × 1400 and 500 × 350 (unchanged). With island count 60 nothing changes; the helper process keeps running afterwards.

**Game test (O), 20:13–20:35:** tool with island spreading, restart of the game caught again (PID 44220 → 16160), new endless game "Durchschnittlich" (average difficulty).

| Check | Result | Evidence |
|---|---|---|
| Islands spread over the whole world | yes: 18 islands over the whole minimap, also right and bottom | `analysis/test/12-inselverteilung-start-minikarte.png` |
| Island in the new area, close up | yes: island at world ≈ (790, 542) | `13-insel-im-neuen-bereich-790-542.png` |
| AI settles the new area | yes: blue AI with warehouse, houses, roads and farms at world (730, 396) after about 10 minutes; grey AI top left | `14-minikarte-ki-im-neuen-bereich.png`, `15-ki-siedlung-mit-kontor-730-396.png` |
| Own ship sails about 650 tiles across the map to an island in the new area | yes | – |
| No crash | yes, about 20 minutes of play | – |
| Save to a new slot | yes: the icon "neuer Spielstand" (new savegame) saves immediately as `game20.gam` (411,766 bytes, 21:13:37) | – |
| Islands in the savegame | 17 `INSEL5` sections; header: byte 0 number, byte 1 width, word 1 height, word 2 x, word 3 y. All 17 positions are exactly the ×2 positions of template variant 2 (`[[48]]02/12/22/32.szs`, 17 islands; the second digit is the layout, the first one the difficulty) | – |
| Quit the game without the score screen, restart with the tool, load `game20` | yes; island table in memory (50 slots of 0x2CC8 bytes from `0x14062DDC0`, x/y/width/height at +4/+8/+0xC/+0x10, occupied if the pointer at +0x2CB0 ≠ 0) read only: **17 of 17 islands at the same position as in the savegame**, so no second stretching. Extent x 100–850, y 40–600. | `16-geladen-game20-inseln-unveraendert*.png` |
| Own warehouse | **not achieved, independent of the world size**: build menu → harbour → "Kontor I" (warehouse I) shows a yellow footprint at the coast (half on the water), but a click places nothing (gold stays 15,000). Exactly the same at island 15 in the **old** area (420, 220). Rotating with "." and "Insel erkunden" (explore island) beforehand do not help either. Cause open (way of operating or game rule). The AI builds normally in the new area. | – |

**Observation on the test method (O):** The floating window of the Claude app (compact view of this conversation, always on top, not click-through) lies over the right game sidebar during computer use (pixels x 2012–2548, y 20–748) and intercepted clicks on the minimap, build, options and save menu. Solution: clicks on the sidebar are sent as window messages (`WM_MOUSEMOVE`/`WM_LBUTTONDOWN`/`WM_LBUTTONUP`) directly to the game window; the game evaluates them for buttons, tooltips appear in the status line. Clicks on the map (placing buildings, ships), on the other hand, use the real mouse position. The Remote Desktop Connection took the foreground in between; the game was then brought back with `SetForegroundWindow`. In the computer-use screenshots the floating window is hidden. A capture with `CopyFromScreen` had included it; these two images were deleted, and since then the helper script captures only the game's window content (`PrintWindow`). All other captures were checked for large white areas (≈ 0 % everywhere).

### More islands (implemented 2026-11-08, night)

- **O** Sizes per island class (`.rdata` `0x1400EA1E0` width, `0x1400EA1C0` height): lit 30×30, mit 40×40, med 50×52, big 70×60, lar 100×90.
- **O** Number of island files per climate × class (`0x1400EA280`, matches the folders `NORD`/`SUED`): north 51/48/36(39 files)/67/5, south 49/45/48/63/6. The templates never use "lar".
- **O** Random file choice in the `SZENE` loader: it collects the still unused file numbers of the class; if all are taken, it takes any of them (repetition, no endless loop).
- **O** The loader places the natives itself: `SZENE`+0x40/+0x44 = 2 villages per climate, on islands whose file has a village site (table up to `0x1400F98A1`), flag bit 0.
- **O** The three endless layouts (`[[48]]x0/x1/x2.szs`, 18/20/17 islands) are identical in all four difficulty levels (climate, class, flags, slot, file, position).
- **Implementation:** The tool reads the three templates (read only), plans a list per layout and writes it as a table at RVA `0xE5200` (empty rest of the last `.text` page, mapped in memory; 4 + 3 × 816 = 2,452 bytes). Plan: the originals stretched first (as before), then copies of the template islands (largest classes first, climate 2 = by position, flags 0, file random) at random positions with a fixed seed, at least 14 tiles from every island and 8 from the edge, until the target = min(48, island count × area factor × 0.6) is reached. 1000 × 700: 43/48/40 islands; 750 × 525: 24/27/22.
- **Code stub (199 bytes, checked with Ghidra):** looks up the template in the table (island count and x/y of the first island); on a match it copies the island count and 800 bytes of entries (`rep movsb`) into the section; otherwise it stretches as before. Registers `rax, rcx, rdx, r8, r9, rsi, rdi` are saved.
- **Offline (O):** 151/151; functional test with the real templates: exactly the planned lists, no overlap, everything inside the world; an unknown template is only stretched.
- **Maps of the plans:** `analysis/test/inselplan-1000x700-anordnung-{0,1,2}.png` (historic file names; `dev/show-island-plan.ps1` now writes `island-plan-<w>x<h>-layout-<n>.png`).
- **In game (O), 21:50:** started via `start-big-world.cmd` (removed on 2026-11-13; the launcher replaces it), new endless game "Durchschnittlich". The game chose layout 1. Island table in memory: **48 islands, all 48 exactly at the planned position**, all at most as large as their class, extent x 47–985, y 24–686. No crash while generating. Evidence: `analysis/test/17-mehr-inseln-start*.png`.
- **Endurance run (O):** 21:50–22:01 at fourfold speed (F7, about 40 game minutes), checked every 30 s: responsive, 48 islands, 1000 × 700, 443–451 MB. Three AI players spread over the whole map, one at the very bottom right in the new area. Islands in the new area are drawn cleanly. Evidence: `18-mehr-inseln-neuer-bereich.png`, `19-mehr-inseln-nach-40-spielminuten*.png`.
- **Save/load (O):** new slot → `game22.gam` (1,050,674 bytes; 48 `INSEL5`, up to x 985 / y 686). Game ended (process end, no score screen), restarted via `start-big-world.cmd`, `game22` loaded: **48 of 48 islands at the same position as in the savegame and as in the plan**. Evidence: `20-geladen-game22-48-inseln*.png`.
- **Test operation note:** At fourfold speed the game did not accept the clicks on the sidebar sent as window messages; after F5 (normal) it accepted them immediately.

### Long run 1000 × 700 with 48 islands (O), 22:20–23:20

- Started via `start-big-world.cmd`, new endless game, F7 (fourfold), 60 minutes, checked read-only every minute.
- Result: always responsive, 48 islands, width 1000, memory 432–493 MB without growth (sawtooth around the autosaves every 10 minutes: 22:30, 22:40, …, 23:20). No crash.
- The AI settled second islands (grey 2, blue 2, one of them bottom right in the new area, orange 1). Evidence `24-langlauf-60min-ende*.png`.
- Limitation: from about 22:26 a terminal window was in the foreground; the game's CPU time dropped from about 30 to 8 CPU seconds per minute. The game kept running (autosaves, AI grew), but probably slower than fourfold. The time played is therefore more like 1–2 game hours than 4.
- **I** The fixed pools (e.g. `ROHWACHS2`) did not fill up in this time; for games over many hours this remains open.
- The protection for "Spiel fortsetzen" (continue game) then renamed `lastgame.gam` (23:20:27) to `lastgame-1000x700-20261108-232148.gam`.

### Limit test 2000 × 1400 (O), 22:06–22:18

- Started via `start-big-world.cmd -Width 2000 -Height 1400`: values 2000 / 1400 / scroll range 1700 set.
- New endless game: layout 0, **48 islands, all 48 at the planned position**, extent x 67–1953, y 24–1366. No crash.
- Camera moved with the arrow keys to world (1832, 1300), scroll t = 1566: the island there is drawn cleanly. Evidence `22-welt-2000x1400-ecke-unten-rechts*.png`.
- Endurance run of about 8 minutes at fourfold speed: responsive, 434–462 MB, autosave written normally (22:16:16) and renamed by the protection to `lastgame-2000x1400-20261108-221745.gam`. Three AI players spread out, one in the new area (x ≈ 1440). Evidence `23-welt-2000x1400-nach-dauerlauf*.png`.
- **I** The maximum size of 2000 per direction is stable in the short test. With at most 48 islands this world is very sparsely populated, though; 1000 × 700 remains the sensible default.
- **?** Not checked: own ships over very long distances, save/load at 2000 × 1400, games over hours.

### Own warehouse (2026-11-09)

- **O** The first warehouse (Kontor) is built via the **ship menu**, not via build menu → harbour: `Loca\de-DE\Text.cod` (bytes negated) contains, among the ship menu texts, "Kontor errichten, um neue Stadt zu gründen" (build a warehouse to found a new town). The button (warehouse icon, sidebar pixel 2365/577) appears only when the ship lies directly at the coast, together with "Insel erkunden" (2350/475). Tooltips checked by moving the mouse.
- **O** Cost of Kontor I: 3 tools, 6 wood, 100 gold (`haeuser.cod`). Start ship in the endless game: 50 t tools, 30 t wood, 10 t food.
- **O** Build mode: around the ship the allowed area lights up, a yellow footprint (2 × 3 tiles) follows the mouse. At a valid coastal spot the dotted line of the catchment area appears as well.
- **O** A click places no warehouse (gold unchanged), whether single click, double click, button held or click as a window message, also at spots with the catchment line. Checked: 1000 × 700, island 10 in the new area (world 140/380); **without the tool** in the endless game 500 × 350; **without the tool** in the tutorial "Entdecken" (Discover).
- **O** Code: building-site check `FUN_14000ef50`. Coastal buildings (kind 0x23 with beach flag: building table `0x1406ba1c0` + i × 0x90, byte +0x72 bit 5) are oriented by `FUN_140098fb0` itself; rotating with "." is not needed for that.
- **O** Input: for mouse and keyboard `Anno1602.exe` imports only `PeekMessageA`/`GetMessageA`/`PostThreadMessageA` (no `GetAsyncKeyState`, no DirectInput, no Raw Input). Synthetic clicks therefore arrive like real ones.
- **O** Rule for coastal buildings (`FUN_140098fb0`, then `FUN_1400949b0`): the footprint (2 × 3) needs **a straight row of 3 coast tiles along one long side** (tile kind via table `0x1406cbb00`, value +4 = 0x17–0x1B, 0x1D or 0x1E); this gives the orientation 0–3, otherwise 0xF = invalid. Then all tiles of the footprint must belong to the same territory as this coast (bits 19–21 of the tile; 7 = free, in which case the building must have byte +0x72 bit 2), be buildable (`FUN_140094630`), and no figure (e.g. an animal) may stand on them. In addition it checks the island (+0x1A ≠ −1 or flag at +0x44 bit 0).
- **I** The earlier failed attempts had nothing to do with the world size (same behaviour without the tool): I had not hit a spot that meets all conditions. The dotted catchment line does not indicate this; at a valid spot, however, the preview shows **the building itself** instead of just the yellow area.
- **O Solved (2026-11-09, 08:28–08:35, savegame `game22` with the tool, 1000 × 700):** valid spots calculated from the island data (helper script `kontorplatz.ps1`: tile grid island +0x2CB0, kind via `0x1406cbb00`, territory bits 19–21; footprint only on land 0xA/0xB/0xF/0x1F/0x20) and clicked with a calibrated world → pixel conversion (at this zoom level: x tile = (+9.05, +4.48), y tile = (−9.05, +4.48), camera centre at pixel 674/415).
  - **Island 35 (old area)**, world 349–350 / 88–90: the warehouse stands, gold 15,000 → 14,898, ship 50 → 47 t tools, 30 → 24 t wood. Evidence `27-eigener-kontor-insel35-alter-bereich.png`.
  - **Island 12 (new area, x 620–670)**, world 627–628 / 66–68: the warehouse stands, gold 14,864 → 14,758, ship 47 → 44 t tools, 24 → 18 t wood; afterwards the island grid has 513 tiles of territory 0 (player) and 6 tiles of kind 0x23 (warehouse). Evidence `28-eigener-kontor-insel12-neuer-bereich*.png`.
- **I** This confirms the own warehouse in the new area; the building rules apply there as in the old one.

### Rivals and pirates (2026-11-09)

- **O** Player kinds (first int per slot, table 7 × 640 bytes from `0x1405f0960`, read in the running game): slot 0 human (0), 1–3 AI (0xC), 4 trader (0xD), 5 pirates (0xE), 6 natives (0xB).
- **I** More than 3 AI rivals is not feasible: 4 fixed player slots, traders/pirates/natives fixed at 4/5/6, 4 flag colours, fixed loops (see "Players and parties"). The endless game already uses all 3 AI slots.
- **O** The endless templates differ per difficulty (first digit 0–3) only in: start money `PLAYER4` (20,000 / 15,000 / 10,000 / 10,000), `SZENE` +0x96…+0xDE and +0x116 (values decrease with the difficulty, probably raw materials/fertility), `TIMERS` +0xA6 (difficulty 0–3), +0xA8 (flags 9/9/8/8) and further timer values.
- **O** The difficulty `0x1405ec1c0` (from `TIMERS`, `FUN_1400c2da0`) controls among others: cannons of the pirate ships in `FUN_14003b7e0` ((n+1)/2, n+2, 2n+4; at most the maximum of the ship type), AI thresholds in `FUN_140017840` (−25 % … +50 %), natural events in `FUN_14009e390` (drought from "Fordernd" (demanding) on).
- **O** Flags `0x1405ec188` **bit 0** = pirates only "gelegentliche Sichtungen" (occasional sightings): `FUN_14003dc40` lets the pirate player (kind 0xE) act only if bit 0 is cleared. Set at Einfach/Durchschnittlich (easy/average), cleared at Fordernd/Schwer (demanding/hard) (read in game at "Schwer": 0x8).
- **O** `0x1405ebf1c` (pause after a pirate move, × 1000) is used only there and when loading/saving.
- **O** Ship table: 200 slots from `0x1401d8bb0`, 0x328 bytes each, name +0x296, owner +0x28 (loader `FUN_14008e4f0`). At the start of an endless game there are 7 ships: 1 each for the human and the AIs, 3 traders. 200 slots are enough for the big world too.
- **Implementation** of `-Pirates Active|Strong|Off` in the tool: hook at the end of the `TIMERS` loader (RVA `0xC3232`, `MOVAPS` 7 bytes → `JMP`), code stub at RVA `0xE5F80` (19 bytes: replaced instruction, `AND`/`OR dword [0x1405ec188]`, return jump `0x1400c3239`). "Strong" additionally RVA `0x3B94B`: `MOV ESI,0x100; JMP 0x14003b98d` → pirate ships always with the full number of cannons. Ghidra disassembly checked, no jump targets the replaced bytes. Offline test case J: bit 0 is set/cleared, other bits stay. Confirmed in game (section "Ships, money", game test of the options).

### Ships, money (2026-11-09)

- **O** Figure table (from `figuren.cod`, parser `FUN_140068f10`): from `0x1406d80c0`, 0x18C bytes each. "Speed" as a floating-point number Speed/10,000 at +0x10 (parser `0x14006A4D7`), read continuously (e.g. `FUN_1400b9760` divides by this value). Ship types no. 21–32 (two entries each), read in game:

  | No. | Ship | Speed | Cannons (+0x3C) | Holds (+0x3A) | per hold (+0x3E, /32) |
  |---|---|---|---|---|---|
  | 21/22 | small trading ship | 0.05 | 6 | 4 | 50 t |
  | 23/24 | large trading ship | 0.04 | 10 | 6 | 80 t |
  | 25/26 | small warship | 0.055 | 8 | 3 | 65 t |
  | 27/28 | large warship | 0.06 | 14 | 8 | 120 t |
  | 29/30 | trader | 0.048 | 12 | 6 | 95 t |
  | 31/32 | pirate | 0.045 | 10 | 5 | 95 t |

- **O** Ship (ship table) +8 points to its figure; there the position is stored as floats at +0x28/+0x2C (start ship in game: 230.5/270.5), the figure type at +4.
- **O** Measured (game "Schwer", normal speed F5): small trading ship **2.1 tiles/s** (42 tiles in 20 s, `schiffsmessung.ps1`).
- **O** Money: player table +4 (int). Game clock `0x1405ec0f8` (from `TIMERS` +0xA0): templates 10–24, savegames 20,000–85,000, runs at about 10 per second (40/s at fourfold).
- **Implementation** `-ShipSpeed F` (1–3): the tool waits until the 12 ship values are loaded (the original values are stored in the tool) and sets original × F. `-StartGold N`: in the same code stub as the pirates, `CMP [game clock],1000; JAE; MOV [money slot 0],N` (checked with Ghidra) → new games only. Offline: cases K and L, total **233/233**.

- **O** Storage: building table (`0x1406ba1c0`, 0x90 bytes each), "Maxlager" × 32 as a 16-bit value at +0x30. Read in game: no. 270–273 = Kontor I–IV (960/1,600/2,400/3,200 = 30/50/75/100 t, kind 0x23, 2 × 3), 274–277 destroyed warehouse (20 t), 401/467/468 market (10 t, kind 0xE). A newly built warehouse takes over the value as its storage limit: own warehouse on island 12, warehouse record (pointer at island +0xB0) +0x20 = 960.
- **Implementation** `-Storage F` (1–5): like ship speed, the 7 values × F (Kontor IV at most 500 t = 16,000, fits into 16 bits). Offline case M, total **245/245**.

**Game test of the options (O), 2026-11-09 08:11–08:25:** tool with `-Pirates Active -ShipSpeed 2 -StartGold 50000`, game via Ubisoft Connect (restart caught again, PID 2812 → 34060).

| Check | Result |
|---|---|
| Tool at startup | all 13 places set; "Schiffstempo x2: kleines Handelsschiff 0.1 statt 0.05" (ship speed x2: small trading ship 0.1 instead of 0.05) |
| New endless game "Durchschnittlich" | difficulty 1, **flags 0x8** (template 0x9 → pirates active), **gold 50,000** (display top left, otherwise 15,000), ship values still doubled after the game start, 48 islands |
| Ship speed measured (normal speed F5) | small trading ship **4.19 tiles/s** (86 tiles in 20.5 s) compared with 2.10 without the option → factor 2.0 |
| Load `game22.gam` (savegame: clock 26,696, flags 0x9, gold 15,000) | **gold stays 15,000** (start gold only for new games), **flags 0x8** (the hook also works when loading), speed 0.1, 48/48 islands as in the savegame |

**Game test with all options (O), 2026-11-09 08:40–08:52:** tool with `-Pirates Strong -ShipSpeed 2 -StartGold 50000 -Storage 3` (all 14 places set, restart caught), new endless game "Durchschnittlich" (layout 0, 43 islands).

| Check | Result |
|---|---|
| Memory after the game start | gold 50,000, flags 0x8, cannon place `BE 00 01 00 00 EB 3B`, Kontor I in the building table 2,880 (90 t), ship speed 0.1 |
| Warehouse built (island 16, world 242–243 / 289–291, spot calculated as above; conversion checked on the ship first: ship exactly at the calculated pixel) | stands, gold 50,000 → 49,900; new town "Zaustaden" (warehouse record +0x1A = 0 = player): **storage limit +0x20 = 2,880 = 90 t**. The native village "Argenhall" on the same island (+0x1A = 6) keeps 960 = 30 t (different building). Evidence `29-alle-optionen-kontor-lager-90t.png` |
| Goods from the ship into the warehouse (more than 30 t) | **not checked**: the quantity and arrow buttons in the transfer window do not accept clicks as window messages, and real clicks there are intercepted by the Claude window |

### Extensions: residents, production, cargo space, turbo, rivals' gold (2026-11-10)

Found with REA/Ghidra (`analysis/scan/all-functions.c`: all 1,275 functions decompiled, script `AnnoDecompAll.java`; the file from this run still has its old name `alle-funktionen.c`).

- **O Residents:** the parser `FUN_140090660` stores `haeuser.cod` "Maxwohn" of the 5 population groups (`BGRUPPE` no. 0–4) as `value << 6` (int) at `0x1406ba02c + no. × 0x50` (tax +4, hiscore +8).
  - Houses store their residents × 64 as 16 bits (house +6).
  - `FUN_1400b7c60` compares the number of residents with Maxwohn of the level and uses it to advance the level; `FUN_1400b7770`, `FUN_1400b7360` and `FUN_1400b5450` use Maxwohn/2 as a threshold.
  - **I** Multiplying all five values by the same factor keeps the ratios.
- **O Production:** `haeuser.cod` "Interval" is stored as 16 bits at building table +0x3A (`DAT_1406ba1fa`). It is read at every work step, in `FUN_1400b43e0` (`*(ushort*)(type + 0x3a) × share / 128`) and in `FUN_1400b9ed0` (the same), each time through the pointer to the building entry (hence no direct cross-reference list).
  - `MAXHAUS` = 500 (`FUN_140002ae0("MAXHAUS",500)`).
  - **I** Smaller intervals take effect immediately on all production buildings, also in loaded savegames.
- **O Cargo space:** `figuren.cod` "Maxware" is stored as 16 bits at figure table +0x3E (`0x1406d80fe`, 26 reading functions, among them the ship loader `FUN_14008e4f0`).
- **O Game speed:** keyboard `FUN_1400e2d60`: F5/F6/F7 → `FUN_1400c8be0(1/2/4)` (command 0x0F, variable `0x1400f99f8`).
  - The game loop `FUN_1400c8e20` computes `speed × time` in steps of 200 (upper limit only when speed × time > 2,999). `FUN_140060560` already has a branch for speed ≥ 5.
  - F7 at `0x1400E3376`: `B9 04 00 00 00` (`mov ecx,4`).
- **O Rivals:** the AI difficulty comes only from the game difficulty `0x1405ec1c0` (`FUN_140017840`, `FUN_140017b30`, `FUN_140032090`, `FUN_140035220`, `FUN_14003b7e0`). There is no separate control for the AI strength.
  - **I** The simplest way to make the rivals stronger is their start gold: player table slot 1–3, money +4, stride 0x280.

**Implementation in `src/anno-patcher.ps1`:**

| Option | Location | Method |
|---|---|---|
| `-Residents F` (1–3) | `0x6BA02C + no. × 0x50`, int | like storage: wait until loaded, check original (128/384/960/1600/2560) or target, set all |
| `-Cargo F` (1–3) | figure no. 21–28 +0x3E, 16 bits | like storage, originals 1600/2560/2080/3840 (2 entries each) |
| `-Production F` (1–3) | building 0–499 +0x3A, 16 bits | after `haeuser.cod` has been read (storage value of Kontor I ≠ 0) and the table is stable: every interval ≠ 0 → max(1, round(v / F)); marker `NUFR` + F × 100 at RVA `0xE5F70` against dividing twice |
| `-Turbo` | RVA `0xE3376` | `B9 04 00 00 00` → `B9 08 00 00 00` (code place, all or nothing) |
| `-RivalGold N` | TIMERS code stub | after the start gold: `cmp [game clock],1000; jae +30; mov [money slot 1/2/3],N` (code stub now up to 83 bytes, room for up to 128) |

**Offline test (O):** `tests/test-patcher.ps1`, new cases N–R, total **284 of 284** passed. Case R executes the real code stub: player 50,000, rivals 3 × 30,000, trader (slot 4) unchanged; with a savegame clock nothing changed.

**In the real game (O), 2026-11-10 19:00:** installed tool with `-Pirates Strong -RivalGold 60000 -StartGold 50000 -Residents 2 -Production 2 -Storage 3 -ShipSpeed 2 -Cargo 2 -Turbo`, game via Ubisoft Connect (restart caught again, PID 5344 → 14268).
- All 15 code places set.
- The resident and cargo originals matched exactly (no abort).
- 125 work intervals halved.
- Checked read-only in the main menu (`dev/check-game.ps1`): world 1000 × 700, F7 `B9 08 …`, residents 4/12/30/50/80, cargo space 100/160/130/240 t, ship speed 0.1, storage Kontor I 90 t, marker `NUFR x2`.
- Then the game was quit. The tool reported "lastgame.gam nicht geschrieben" (lastgame.gam not written); `lastgame.gam` is unchanged.
- The check in the running game was pending at first (permission for computer use declined); done on 2026-11-11, see below.

**Game test with computer use (O), 2026-11-10 20:10 and 2026-11-11 15:10.** Same options, endless game "Durchschnittlich", flag red.

| Check | Result |
|---|---|
| New game: gold | player **50,000**, rivals slot 1–3 **60,000** each, trader 1,000,000 (checked twice) |
| Pirates | flags 0x8 (bit 0 cleared → they attack, although "Durchschnittlich") |
| Islands | 48 and 43 (layout 1 and 0) |
| F7 | game speed variable **8**; game clock +837 in about 11 s (normally about 110) |
| Storage above 30 t | warehouse built on island 16 (world 233–235 / 286–287), gold 50,000 → 49,898. Transfer window: 50 t tools from the ship → warehouse. Ship empty afterwards; warehouse record: limit +0x20 = **2,880 (90 t)**, stock of tools +0x132 = **1,504 (47 t)** |
| Edge scrolling with the mouse | **not testable**: with a simulated mouse at the bottom and left edge the camera does not move at all, not even towards the old area. `FUN_1400dd190` only scrolls when an input object (`DAT_1400fa708`, vtable +0x58) reports "active"; after that the same limit `DAT_1405eb840` applies as for the arrow keys. To be checked by hand. |
| "Spiel fortsetzen" | `lastgame.gam` unchanged at the end (B7C4BFB9…) |

**Test method (O):**
- `open_application` of computer use starts **a second, unpatched game instance** (2026-11-10, PID 21728 next to the patched 21964); the first new game ran in it with original values. After that the game window was only brought to the front with `SetForegroundWindow`.
- Clicks on the sidebar (right) did not arrive as real clicks. As window messages to the game window, "Kontor errichten" (build warehouse), the transfer window, the quantity "50" and the arrow worked.
- The Remote Desktop Connection took the foreground once.
- **Interruption 2026-11-10:** the tool started from the session was terminated together with it; the game then wrote `lastgame.gam` (20:24) without renaming. On 2026-11-11 it was renamed to `lastgame-1000x700-20261110-202424.gam` and the original copied back. For the second test the tool ran as a separate process (`Win32_Process.Create`).

**Launcher window:** `src/launcher.ps1` (WinForms). All options as drop-down lists, the last choice in `%APPDATA%\Anno1602-Extensions\settings.json` (before the English renaming `%APPDATA%\Anno1602-Erweiterungen\einstellungen.json`, migrated once). "Mit Erweiterungen spielen" (Play with extensions) starts the tool in its own window and after 3 s `uplay://launch/16236/0`; "Original starten" (Start original) starts only the game. The launcher shows German on a German Windows and English otherwise.

**Installation:** `%LOCALAPPDATA%\Programs\Anno1602-Extensions` (before the English renaming `%LOCALAPPDATA%\Programs\Anno1602-Erweiterungen`), with the shortcut "Anno 1602 - Erweiterungen" (German Windows) or "Anno 1602 - Extensions" (other languages) in the Start menu and on the desktop. The desktop folder `C:\Users\User\Desktop` was missing and was created.

**Side effect:** the game test created the backup `Savegame-Sicherung-20261110-190036`, because the Savegame folder had changed since the first backup (test savegames). (The tool now names its backups `Savegame-Backup-<datetime>`; the folders listed in this document were made under the old name.)

### Raw materials, island size, residents ×5, performance (2026-11-11)

**Raw materials (O):** `SZENE` section of the endless templates, entries of 8 bytes from +0x94 (house no. 16 bits, quantity 16 bits, int), compared across the four difficulty levels (`[[48]]00/10/20/30.szs`):

| Offset | House no. | Meaning | Einfach → Schwer (easy → hard) |
|---|---|---|---|
| +0x94 | 2401 | ore (type +0x98 = 0) | 6 / 5 / 4 / 2 |
| +0x9C | 2401 | ore (type 1) | 8 / 8 / 7 / 9 |
| +0xA4 | 2405 | gold (type 2) | 3 / 2 / 2 / 2 |
| +0xB4 … +0xDC | 1336, 1342, 1340, 1332, 1344, 1338 | fertility of the 6 plantations (12 places) | 5 → 2–3 |
| +0x114 | 533 | treasure | 10 / 8 / 6 / 4 |
| +0x40 / +0x44 | – | native villages | 2 / 2 |
| +0x60 | – | max. raw materials per island | 2 |

- Loader `FUN_1400d0de0` (excerpt `analysis/scan/szene-lader.c`): it distributes the fertility in three passes (first classes big/lar, then lit/mit, then all); every successful assignment lowers the quantity. The last loop ends as soon as a pass assigns nothing more.
- Ore: only islands with counter +0x41 < 2 and a suitable mountain; without candidates it stops (`goto LAB_1400d3260`).
- **I** Quantities that are too high do not lead to an endless loop; whatever does not fit is dropped.

**Implementation `-Resources More|Lots`:** code stub at RVA `0xE5C00` (102 bytes), called with `call` from the island spreading directly after the island list has been copied (endless templates only).
- For the 17 quantities +0x96 … +0x116: `min(new, quantity × new × percent / (old × 100))`, with percent = 100 or 200.
- Island code stub with the call: 204 instead of 199 bytes; the island table may now extend up to `0xE5C00` (since 2026-11-12 only up to `0xE5BA0`, see the memory layout in "Rivals, pirate fleet, natives, traders, 50 islands").

**Island size (O):**
- Island files of class lar: `NORD` 6, `SUED` 7, `NORDNAT`/`SUEDNAT` 0 (big: 68/64/37/40).
- First game test with `-IslandSize Huge` (plan layout 2: 17 big, 23 lar): **only 32 of 40 islands loaded** (17 big, 15 lar). 8 lar islands were missing.
- **Implementation:**
  - At most 10 lar per map, otherwise big. Large = originals one class bigger (where there is room), extra islands alternately lar/big; Huge = everything lar/big.
  - Changed originals get a random island file (0xFFFF).
  - Area of the island rectangles at 1000 × 700: Normal 108–122 thousand (15–17 %), Large 201–229 thousand (29–33 %), Huge 216–246 thousand (31–35 %).
- **Second game test (O), 2026-11-11 16:40:** `-IslandSize Huge -Resources Lots -Residents 5 -Production 2 -Storage 3 -Turbo`, layout 2. **40 of 40 islands loaded** (30 × 70×60, 10 × 100×90). In addition 69 ore deposits on all 40 islands and 254 fertilities (`dev/check-islands.ps1`). World generation ran through without hanging.

**Residents up to ×5:** 10/30/75/125/200 per house; read in game. The house stores ×64 as 16 bits, so at most 1,023.

**Performance (O), 2026-11-11, same savegame, F7 (8-fold), game window in the foreground, 500 s:**
- Game clock 504 → 40,531, i.e. **exactly 8.0-fold** in every 20-s measurement (80 clock steps/s).
- CPU **52–56 % of one core**, memory 430–494 MB without growth; a dip at 300–320 s during an internal save.
- **I** At 8-fold the game still has headroom; the game logic runs on one core.
- **?** Not yet measured with strongly grown towns over hours.

**Turbo 16-fold (O), 2026-11-11 17:10:** `-TurboLevel 8|12|16` (F7 `mov ecx,<level>`). Measured with the settings of the launcher button "Alles gross" (Everything big): `-IslandSize Huge -Resources Lots -RivalGold 60000 -StartGold 50000 -Residents 5 -Turbo -TurboLevel 16 -Production 2 -Storage 5 -ShipSpeed 2 -Cargo 3`. Result:
- New endless game: 43 islands (33 × 70×60, 10 × 100×90), 70 ore deposits on 40 islands, 268 fertilities; gold 50,000 / 60,000 × 3.
- 500 s on F7: game clock 467 → 80,490 = **16.0-fold** in every measurement (160 clock steps/s), about 2.2 game hours.
- CPU 52–56 % of one core (as at 8-fold), in the last 60 s 14–15 % without loss of speed; memory 430–493 MB.
- **I** The game logic is not the bottleneck; the load comes mostly from rendering.

**Launcher:** turbo as a selection (off/8/12/16-fold) instead of a checkbox; an older saved setting "Turbo = yes" becomes 8-fold. New button **"Alles gross"** (Everything big) with the values above (1000 × 700 instead of 2000 × 1400, because the game knows at most 48 islands).

**Offline test:** new cases S (functional test of the raw-material code and the island code with the real templates `[[48]]00/11/32.szs`, Huge) and T (geometry and at most 10 lar for Large/Huge at 1000×700, 2000×1400, 750×525). Total **332 of 332**.

### Rivals, pirate fleet, natives, traders, 50 islands (2026-11-11)

Assembler excerpts: `analysis/scan/schwierigkeit.txt`, `haendler.txt`, `neue-patches.txt` (disassembly of the new bytes, code stubs at the substitute address 0x140001000).

**AI strength (O):** the AI reads the difficulty `0x1405ec1c0` (0 Einfach, 1 Durchschnittlich, 2 Fordernd, 3 Schwer; from `TIMERS` +0xA6) at four places, each with `mov eax,[rip+rel32]` (`8B 05 …`):

| RVA | Function | Effect of level 3 |
|---|---|---|
| 0x17A8E | `FUN_140017840` | threshold for its own strength compared with the strongest player: +50 % (level 0: −25 %) |
| 0x17EA1 | `FUN_140017b30` | targets for four unit/ship kinds derived from the players' strength: ×2 (1: ×1.25, 2: ×1.5) |
| 0x321C9 | `FUN_140032090` | another military value: ×2 (0: −25 %, 2: +50 %) |
| 0x35344 | `FUN_140035220` | expansion level for `FUN_14002e2c0(…, 1/2/3)` |

- Other readers: natural events `FUN_14009e390` (drought from level 2), pirate cannons `FUN_14003b7e0`, savegame writer `FUN_1400c4390`. These stay unchanged.
- **Implementation `-Rivals Hard`:** the four places → `mov eax,3; nop` (`B8 03 00 00 00 90`).

**Pirate fleet (O):** `FUN_14003dc40` calls `FUN_14003b7e0` for the pirates (player kind 0xE, only if bit 0 of the flags is cleared) every 10,000 time units, as soon as `FUN_1400185f0` > 1.
- `FUN_1400185f0` = highest civilisation level (0–4) of the human and the AIs over all settlements (player flags +0x6C, bits 18/24/29/30).
- `FUN_14003b7e0`: if the pirate control (+0x1076c) has fewer ships than this level and the waiting time (+0x14) has expired, a pirate ship appears at a random spot (`FUN_140070d80(3)`). Then waiting time = `0x1405ebf1c` (1,500) × 1000. The original therefore has at most 4 pirate ships.
- Ship creation (`FUN_14008be30`, case 3): limited only by the ship table (200 slots).
- **Implementation `-PirateFleet Large|Huge`:** RVA 0x3B7F1 `call FUN_1400185f0` → `call 0xE5E00`. Code stub (17 bytes): `sub rsp,0x28 / call FUN_1400185f0 / add rsp,0x28 / imul eax,eax,F / ret` (shadow space needed: `FUN_1400185f0` saves rbx/rdi at [rsp+8]/[rsp+0x10]). The two waiting times (RVA 0x3B8D2, 0x3B9CE, `imul eax,[0x1405ebf1c],1000`) → 1000/F. Result: up to 8 or 12 pirate ships.

**Traders (O):** `FUN_1400bc030` counts the settlements (`0x1405bd228`, including those of the natives) and keeps `(count + 2) / 3` free traders (counter `0x1406d7e68`, never decreased); otherwise `FUN_140070d80(2)`.
- Trader records: 30 (`0x1405a8450`, 0xD0 each); `FUN_14008be30` case 2 stops from no. 30 on (`cmp al,0x1e`), after the ship has already been created.
- **Implementation `-Traders More|Lots`:** RVA 0xBC140 `shr eax,31; add edx,eax` (sign correction, always 0; eax is not read afterwards) → `call 0xE5E20`. Code stub (14 bytes): `imul edx,edx,F / cmp edx,24 / jle / mov edx,24 / ret`. At most 24 traders.

**Natives (O):** per climate zone the SZENE loader distributes `+0x40` (north) or `+0x44` (south) villages on islands whose island file has a village site (table `0x1400F94E4`–`0x1400F98A3`, 240 entries climate/class/file: north lit/mit/med/big 10/25/25/36, south 31/41/33/39, no lar) and sets flag bit 0 (file from `NORDNAT`/`SUEDNAT`). Too few candidates: fewer villages, no error.
- Settlement slots: 75 of 600 bytes each from `0x140622DC0` (`FUN_14009a9f0`); every village occupies one. If all are full, a new warehouse fails cleanly (return value 7).
- **Implementation `-Natives More|Lots`:** in the raw-material code stub `mov dword [r15+0x40],n` and `[r15+0x44],n` with n = 4 or 7 (at most 14 of the 75 slots). Without `-Resources` the code stub consists of these two instructions only.

**50 islands (O):** SZENE section, island table and grid have 50 slots; 48 was only caution. `0x31` appears in the code as a goods ID, not as "no island"; islands are not created anew at runtime. Density of the extra islands 0.7 instead of 0.6: at 1000 × 700 now 50/50/47 instead of 43/48/40.

**Memory layout at the end of .text** (updated 2026-11-12, checked by offline case AH): 0xE5100 island code (up to 209) · 0xE5200 island table (2,452; limit now 0xE5BA0) · 0xE5BA0 fertility code stub (30) · 0xE5BC0 marker BAUK (8) · 0xE5BC8 marker UNTH (8) · 0xE5BD0–0xE5BFF free · 0xE5C00 raw materials/villages/fertility (up to 158) · 0xE5E00 pirate fleet (17) · 0xE5E20 traders (14) · 0xE5E40 big campaign maps (200) · 0xE5F70 marker NUFR (8) · 0xE5F80 TIMERS (up to 83).

**Offline test:** new cases U (four AI places; natural events and pirate cannons untouched), V (the pirate fleet code stub calls the real `FUN_1400185f0` in the image; levels 0–4 set through the player flags → 0/2/4/6/8 or 0/3/6/9/12; waiting times 500/333), W (traders: 0, 1, 4, 5, 8, 12, 13, 30 → ×2 or ×3, at most 24), X (villages 4/4 or 7/7 with the real templates, with and without raw materials), Y (50 islands; all options together, code stubs do not overlap). Total **415 of 415**.

**Game test 1 (O), 2026-11-11 18:05–18:13:** tool (started via WMI) with `-IslandSize Normal -Resources Lots -Natives Lots -Rivals Hard -PirateFleet Huge -Traders Lots -Pirates Strong -StartGold 50000 -RivalGold 60000 -Residents 5 -Turbo -TurboLevel 16 -Production 2 -Storage 5 -ShipSpeed 2 -Cargo 3`; all 26 places set. New endless game "Durchschnittlich" (difficulty 1), 16-fold:
- **50 islands** occupied, **14 native villages** (7 + 7, original 2 + 2), gold 50,000 / 60,000 × 3.
- Traders: 2 → 15 (15 settlements) → 18 (17) → 21 (19), each time exactly `(n + 2) / 3 × 3`.
- First AI at level 2 after about 6 minutes; immediately the first pirate ship.
- Shortly afterwards the pirates (Strong) sank my only ship. Without a settlement the game is lost at that point (score screen, "Schiffe gesunken 1" (ships sunk 1)). Game over, no crash. CPU 55–57 %, 437–493 MB.

**Game test 2 (O), 2026-11-11 18:24–18:34:** `lastgame-1000x700-20261109-185329` loaded in the same process (clock 440,383, own settlement, AI levels 2/2/4, 3 pirate and 8 trader ships), 16-fold:
- Pirate ships 3 → 4 → 6 → 8 → 9 → 10 → **12** (= level 4 × 3; original at most 4) in about 5 minutes.
- Traders 8 → 12 → **15** (13 settlements: 5 × 3).
- 12 pirate ships, then unchanged for 5 minutes: the limit holds.
- On attack messages the game itself switches back to speed 1 (press F7 again).
- Always responsive, 421–435 MB, CPU 54–58 % of one core. No crash.
- Ended by terminating the process; the tool renamed the autosave to `lastgame-1000x700-20261111-183442.gam`. `lastgame.gam` copied back from `Savegame-Sicherung-20261108-191850`, hash `B7C4BFB912C36597…` checked.
- Side effect: the lost game from game test 1 changed the endless high-score list `Highscore\[[48]].hss` (18:23, 1,000 points), as already on 2026-11-08.

**Package:** `Documents\Anno1602-Erweiterungen.zip` rebuilt and installed with the installer of that time (`installieren.ps1`); the installed files match the sources by hash. The installed version finds all 25 places with the "Alles gross" values (`-CheckOnly`). (The ZIP package mode has since been dropped; `install.cmd` now installs from the repository layout with `src/install.ps1`.)

### Own scenarios and the campaign "Die Smaragdinseln" (The Emerald Isles) (2026-11-11)

**Location and list (O):** the History Edition reads own scenarios from `Documents\Anno 1602 History Edition\Own Scenarios\*.szs` and shows them in "Neues Spiel" (new game) under "Eigene Szenarien" (own scenarios) (file name = title, three stars). The game folder also contains the official editor `Anno1602Editor.exe` (texts `Loca\de-DE\Editor.cod`: mission goals, population goals for up to 3 towns, defeat players, overall/trade balance, monopoly, support players, mission text). No game file has to be changed.

**Structure (O):** sections `SZENE_PLAYERMIN`, `SZENE_PLAYERMAX`, `SZENE_GAMEID`, `SZENE_RANKING`, `RANDTAB`, `AUFTRAG4`, `SZENE`, `PLAYER4`, `SHIP4`, `TIMERS`. Without `INSEL5` the SZENE loader generates the islands from the island list, as for the endless templates. Original missions additionally have `SZENE_MISSNR` (campaign progress, high-score list).
- `PLAYER4`: 7 entries of 0x430 bytes each (loader `FUN_1400b1020`): +0 gold, +4 kind (0 human, 12 AI, 13 trader, 14 pirates, 11 natives), +5 number, **+0x0C mission slot** (0xFF = none) → player table +0x7C.
- `AUFTRAG4`: entries of 0x8C4 bytes each (loader `FUN_1400b1780` → table `0x1405ec720`, 0x108C each). Check `FUN_1400ae010` (from `FUN_1400af980`); fulfilled → message 0x3E → `FUN_1400b0000`: voice message/film from +0x50, all players to kind 9, score screen ("Missionsbonus 100 %", mission bonus).

| File offset | Meaning (goal bit) |
|---|---|
| +0x00 | slot in the mission table |
| +0x04 | goal bits (1/2/4 town 1–3 are set by the loader itself) |
| +0x20 / +0x22 | monopoly: raw material (0x2D grain, 0x2E tobacco, 0x2F spices, 0x30 sugar, 0x31 cotton, 0x32 wine, 0x33 cocoa …), island count – **replaced at the start by the number of all islands with this raw material** (`FUN_1400ceea0`) (0x4000/0x8000) |
| +0x24 | player to support, 7 = any (0x10, target at +0x8B8) |
| +0x2B / +0x2C…+0x32 | number of defeated rivals (0x200) / per player "must be defeated" (0x400; defeated = kind 9) |
| +0x40 / +0x44 / +0x4C | number of towns (0x20) / total residents (0x80) / balance `FUN_1400ad5d0` (0x100) |
| +0x50 | voice message on success (original 84–106) |
| +0x54 | **trade balance** ≥ value (0x10000): sales revenue − purchase costs (player +0x78 / 480 − +0x74 / 480), e.g. `[[111]]0`: 500. The balance at +0x4C is the one of the status window: taxes + sales − purchases − operating and military costs (`FUN_1400ad5d0`, result field 6) |
| +0x68 | mission text, 0x800 bytes Windows-1252; `[[n]]` = placeholder for game texts, otherwise plain text with line breaks |
| +0x868 / +0x86C | goods stock: byte 0 good (list `[WARE]`: 12 muskets, 13 cannons, 16 spices, 21 jewellery, 22 tools …), bytes 2–3 quantity × 32 t (0x1000/0x2000) |
| +0x870 / +0x87C / +0x888 | town 1–3: total residents, level (0 pioneers … 4 aristocrats), of which at least (number at this level or higher) |
| +0x8AC | all own towns at least (0x08) |

- Consistent with all 44 original missions (e.g. `[[121]]` "Einführung" (introduction): 60 residents, 40 of them settlers, balance ≥ 0; `[[130]]0`: defeat players 1–3).
- SZENE fertility: house no. = `Id` − 20000 from `haeuser.cod`: 1332 cotton, 1336 tobacco, 1338 cocoa, 1340 sugar, 1342 spices, 1344 wine; raw-material code = byte +0x21 of the building (name list in the exe from `GETREIDE` = 0x2D).

**Prototype (O), 2026-11-11 without the tool:** "ZZ Test Stadt" appeared in the list; the mission text was displayed with line break and umlauts; in memory mission slot 0, goal bits 0x101, town 150/1/100. "ZZ Test Sofortsieg" (instant win; balance ≥ −1,000,000) ended immediately with the score screen, mission bonus 100 %. Test files deleted afterwards.

**Tools:** `src/scenario-lib.ps1` (reading/writing .szs, `New-Mission`, `Set-Islands`), `src/build-scenarios.ps1` (6 chapters from the endless templates: mirrored layout, single islands one class bigger, raw-material quantities, villages, gold, difficulty, pirate flag, mission and text; check for map boundaries and overlaps). Output `src/scenarios/`, with `-Install` into "Own Scenarios".

**Campaign:** Landung (Landfall, Einfach) · Gewürzfieber (Spice Fever, monopoly) · Zwei Kolonien (Two Colonies) · Schwarze Segel (Black Sails; weapons store, pirates) · Der Eroberer (The Conqueror; defeat players 1–3) · Krone der Inseln (Crown of the Isles; 3 towns, 1,200 aristocrats, Schwer). All 6 decoded offline and checked (goals, geometry, texts, player data, flags).
- **In game (O):** all 6 chapters in the list. Chapter 2 loaded: 18 islands, spices on 4 islands, 4 villages, gold 25,000 × 4, mission monopoly 0x2F (island count set to 4 by the game) + town 500/2/250, text with umlauts. Afterwards the spice quantity was lowered to 2 and the text changed to "jede Gewürzinsel" (every spice island).
- Chapter 1 loaded in game (2026-11-11 21:50, without the tool): 20 islands, 6 villages, gold 30,000/15,000 × 3, difficulty 0, flags 0x9, mission 250/1/150 + balance. Chapters 3–5 not loaded individually (same build path, `tests/check-scenarios.ps1` checks all of them). The difficulty balance has not been played through.

### Big campaign maps, race, challenges (2026-11-11, night)

**Longer SZENE section (O):** a SZENE section with 2,360 instead of 1,172 bytes (test file "ZZ Test Lang") loads normally without the tool; the loader (`FUN_1400169e0` → `FUN_1400d0de0`) reads the whole length but evaluates only the fixed offsets.

**Big version (implementation):** behind the normal block: +0x494 `'GROS'`, +0x498 width, +0x49C height of the design size, +0x4A0 version, from +0x4A4 a complete second SZENE block. At the hook of the SZENE loader RCX = section header (name, +0x10 length). The island-spreading code stub first calls a new code stub at RVA `0xE5E40` (200 bytes): length ≥ 2,360, marker, design size ≥ 100 and map size ≥ design size → copy the big block to the front, stretch the positions by width/design size, `eax = 1` → done. Otherwise the normal path (table, stretching). Not with `-StretchOnly` and `-NoIslandSpread`.
- Offline case Z: 1000 × 700 → big version (50 islands, villages 5); 2000 × 1400 → the same, × 2; 750 × 525 and 500 × 350 → small version stretched; wrong marker or 10 bytes too short → small version. Total **429 of 429**.
- `build-scenarios.ps1` generates the big version with the tool's island planner (`Get-IslandPlan`, per chapter Normal/Large/Huge), raw materials × island count, 5–6 villages per climate zone.
- **In game (O):** chapter 6 with the tool ("Alles gross"): world 1000 × 700, **47 islands** (37 × 70×60, 10 × 100×90), 12 villages, 53 ore deposits on 45 islands, 228 fertilities, mission unchanged. The tool's gold options (clock < 1000) also overwrite the start gold of the scenarios.

**Race (O):** if the computer rivals have the same mission slot (PLAYER4 +0x0C) and the goal bit 0x800, `FUN_1400af980` checks them too. If a rival fulfils the mission, the game sends message 0x3E; `FUN_1400b0000` shows the human message 0x53 and ends the game.
- In game: "Wettlauf 2" (race 2) with the tool: mission slot 0/0/0/0, player kind 0/12/12/12, goal bits 0x803, 50 islands, 10 villages.
- Test scenario with its own, instantly fulfilled mission for the rivals only (slot 1, balance ≥ −1,000,000, 0x800): the game ends immediately with the score screen, mission bonus 0 %, no crash. Test file deleted.
- **When the check happens:** `FUN_1400af980` counts the game time (`DAT_1405aa338`, threshold 5,000) and then increments a period (`DAT_1405a5075`, 0–7). Each player is checked once per period (player table +0x6A remembers the last period), computer rivals (kind 11–14) only if `DAT_1405f2188` ≠ 0 (1 in single player). Town goal in `FUN_1400ae010`: total residents = town +0x218 + 0x220…0x230; "of which at least" counts the level and all higher ones (+0x220 pioneers, +0x224 settlers, +0x228 citizens, +0x22C merchants, +0x230 aristocrats).
- **Natural race (O), 2026-11-11 23:06–23:45:** "Wettlauf 1 – Erster Hafen" (race 1 – First Harbour; big version, tool with turbo 16, the human builds nothing). The rivals (difficulty 0, 20,000 gold) found 2 towns each and stay at the settler level for a long time; their gold drops to 4,000–6,500. Rival 1 reaches 301 residents in Barlin (201 settlers and higher, 42 of them citizens) at game clock 351,398 (≈ 39 min at 16-fold, ≈ 10 hours at normal speed). After that all players are kind 9, lock `DAT_1405ebf68` = 1, the clock stops; after a click the score screen with mission bonus 0 %, total 0. "Hauptmenü" (main menu) works. A human reaches 300 residents in one town much faster; chapter 1 is therefore "Einfach" as intended.
- **Measurement race 3 (O), 2026-11-12 00:14–00:43:** first attempt aborted: in "Wettlauf 3" (pirates active) the pirates sank the only ship of the idle human after about 4 game hours → human kind 9, score screen "Gesunken 1" (sunk 1) (normal game behaviour, not a scenario bug). Second attempt with a test copy, pirates only sighted (TIMERS +0xA8 bit 0), difficulty 2, rivals' gold 35,000, big version (47 islands). Conversion: about 32,700 clock units per hour at normal speed (endurance run: 523,094 in 60 min at 16-fold).

  | Goal (one town) | reached by | game clock | ≈ normal play time |
  |---|---|---|---|
  | 300 res., 150 settlers+ | rival 1, after 13 min | 119,376 | 3.7 h |
  | 500 res. | rival 1, after 15 min | 138,616 | 4.2 h |
  | 700 res., 350 citizens+ (first merchants) | rival 1, after 26 min | 236,754 | 7.2 h |
  | 1,000 res., 400 merchants+ → **race lost** | rival 3 (1,000, 750 of them merchants), after 29 min | 265,261 | 8.1 h |

  The rivals' second towns hardly grow (200–290 residents after 8 h). The jump from citizens to merchants is very fast for the rivals (rival 3: 592/405 citizens → 1,000/750 merchants in 10 min). The game then ended correctly (all kind 9, score screen 0 %).
- **Measurement race 4 (O), 2026-11-12 00:45–02:15:** test copy, pirates only sighted, difficulty 3, rivals' gold 45,000, big version (50 islands). Best town (rival 2): 4.2 h 628 (450 citizens) · 8.7 h 999 (600 merchants) · 14.2 h 1,240 (875 merchants) · **19.8 h 1,504 (947 aristocrats)** · 22.6 h 1,602 (1,115 aristocrats) · 25.3 h 1,609. After that it oscillates between 1,533 and 1,609 for 6 game hours; rivals' gold 4,000–12,000. No rival reaches the old goal 2,000/600. The second towns stall at 245–281 residents with exactly 144 settlers; from ~8 h on the rivals found small third settlements (< 130).
- **Rival balance checked (O):** autosave of the run (game clock 799,622) copied, only the town goal in the AUFTRAG4 section changed from 2,000 to 1,500 (2 bytes), loaded with the tool: the game ended immediately, all kind 9, score screen 0 % → rival 2 fulfils 1,500/600 aristocrats **and** balance ≥ 500. Test savegame deleted afterwards.
- **Adjustments afterwards (`build-scenarios.ps1`):** the new key `AI` sets only TIMERS +0xA6 (= difficulty, in game `0x1405ec1c0`; otherwise the endless templates differ only in random timers and flags), the map stays the same. Race 1: AI 1 (before 0; checked in game: difficulty 1). Race 2: AI 2, second town 250/100 settlers instead of 300/150 (otherwise out of reach for the rivals). Race 4: 1,500/600 aristocrats + balance 500 instead of 2,000/600. The other 10 scenarios unchanged byte for byte; `check-scenarios.ps1`: all OK.
- **Re-measurement of the new race 1 (O), 02:21–02:40:** installed file, difficulty 1 confirmed in memory. Rival 1 reaches 300 residents (156 settlers, 42 citizens) after 17–18 min at 16-fold, game clock ≤ 166,644 ≈ **5 h** (before 10.7 h); the game ends correctly.
- **New race 2 (O), 02:41–03:18:** difficulty 2, goal bits 0x803, town 1 700/2/350, town 2 in memory 250/1/100 (table +0x1050). Rival 3 wins after 37 min at 16-fold (game clock ≤ 312,366 ≈ 9.6 h), when its second town reaches 251 residents (its capital long since at 1,117, 925 of them merchants). Because the rivals' second towns stall at 187–290 residents, 250 is too tight: **second town now 200/100** (with this value rival 3 would have won after ≈ 7.6 h: 737 res./564 citizens+ and second town 207). Rebuilt, checked, installed.
- **Load check of the scenarios not loaded so far (O), 03:15–03:40, big version with the tool:** Smaragdinseln 3 (47 islands, bits 0x103, town 800/3/300 + 500/2/250, balance 300, rivals without mission 255), Smaragdinseln 4 (50 islands, bits 0x3001, town 1,000/3/500, 20 t cannons + 40 t muskets, pirates active, escort ship "Wehrhaft" with 8 cannons), Goldrausch (Gold Rush; 47 islands, bits 0x3000, 60 t gold + 40 t jewellery, pirates active, "Goldwächter" with 8 cannons, name correct in memory in Windows-1252), Handelsimperium (Trade Empire; 50 islands, bits 0x13000, trade balance 300, 50 t jewellery + 80 t clothes), Inselreich (Island Realm; 50 islands, bits 0xA0, 8 towns, 3,000 residents in total, gold 40,000/25,000). All with mission slot 0 for the human. With this, all 13 scenarios have been loaded in game at least once.
  - Mission table in memory (0x108C each): +0 goal bits, +0x08 supporter, **+0x1C towns (`param_2[7]`), +0x28 total residents (`param_2[10]`)**, **+0x30 balance (`param_2[0xc]`), +0x34 trade balance (`param_2[0xd]`), +0x38 voice message**, text from +0x3C, +0x103C/+0x1040 goods (byte good, quantity ×32 from +2), +0x1044/+0x1050/+0x105C town 1–3.
- **Race summary (rivals without the human's involvement, big version):** chapter 1 ≈ 5 h · chapter 2 ≈ 7.6 h · chapter 3 ≈ 8 h (without pirate attacks) · chapter 4 ≈ 20 h. All four races can therefore be lost, but a brisk player can win them well.

**Start ships (O, bug found and fixed):** the start positions of the ships (SHIP4, entries of 0x1B4 bytes each: name, +0x1C/+0x1E x/y as int16, +0x3C cargo space ×32, +0x42 cannons, +0x46 slot, +0x48 figure type, +0x4B owner, cargo from +0x174; loader `FUN_14008e4f0`) are **not** stretched by the tool, but the islands are.
- Endless world: with layout 2 and 1000 × 700 (Normal, Huge) an island (50×52 at 80/267) lay over the start point 80/270; at 750 × 525 Large/Huge similarly in all three layouts. A first check had missed this (list without the comma operator, hence no hits).
- Implementation: `Get-IslandPlan` receives the start points (read from the SHIP4 section of `[[48]]1<layout>.szs`) and neither enlarges nor places an island closer than 2 tiles to them. The plans for 1000 × 700 layout 0/1 and all plans for 2000 × 1400 stay the same byte for byte; layout 2 (1000 × 700 Normal/Huge) and some 750 × 525 plans change. Offline case T now checks all 27 plans (3 sizes × 3 island sizes × 3 layouts): **456 of 456**.
- Campaigns: the islands are mirrored or newly planned, the ships are not. In 10 of 13 scenarios at least one version had ships inside an island. `build-scenarios.ps1` now looks, per scenario, for a water point that is 10 tiles away from every island in all six versions (small × 1/1.5/2/4, big × 1/2), as close as possible to the start point of the template, and moves all four ships there. `check-scenarios.ps1` checks this for all 13: clear.

**Start fleet:** extra ships for the human = copy of his SHIP4 entry with a new name, slot (+0x46 = next one), figure type (+0x48: 23 large trading ship, 25/27 small/large warship), cargo space (+0x3C: 2,560/2,080/3,840) and full number of cannons (+0x42: 10/8/14; cannons = ship +0x2AE, cf. message 0x19), without cargo (since 2026-11-12 optionally with cargo, see "Ship cargo" below), 7–9 tiles next to the start point (for this the start point is 14 tiles from every island). Schwarze Segel and Goldrausch: small warship; Eroberer: large warship; Krone: large trading ship.

**Launcher:** button "Für Kampagnen" (For campaigns) (1000 × 700, more islands, turbo 16-fold, gold "Wie Schwierigkeit" (as per difficulty), everything else default). A note on the own scenarios at the top of the window.

**Endurance run (O), 2026-11-11 21:57–22:57:** savegame `lastgame-1000x700-20261111-183442` with all "Alles gross" options (among others rivals Hard, pirates Active, fleet Large, traders Lots, turbo 16), F7; at speed 1 the measuring script sends F7 via `PostMessage` (`WM_KEYDOWN` 0x76, works). 60 of 60 measurements responsive, 429–491 MB without growth, game clock 464,523 → 987,617 = **14.5 game hours**, F7 ten times automatically. The rivals expand their 2–4 towns (2,201/1,604/2,606 residents, gold up to 2.3 million), but found no new ones; pirates 9 ships, traders 15.

**In game after the corrections (O):** "Der Eroberer" (big version): own large warship "Königsadler" in slot 4, figure type 27, 14 cannons, next to the start ship; 50 islands. "Wettlauf 4" (big version, ships previously inside a 100×90 island): all ships in open water.

**Scenarios now (23 per language, since 2026-11-12):** Smaragdinseln 1–6, Wettlauf 1–4 (Erster Hafen, Bürgerstolz, Kaufmannsrepublik, Die Krone – English file names First Harbour, Civic Pride, Merchant Republic, The Crown; goals from 300/150 settlers up to 1,500/600 aristocrats, adjusted after measuring, see above), challenges Inselreich (8 towns, 3,000 residents in total), Handelsimperium (50 t jewellery, 80 t clothes, trade balance +300), Goldrausch (60 t gold, 40 t jewellery); new on 2026-11-12: campaign Sturmsee 1–6 and the challenges Archipel, Kontinente, Handelsflotte, Seemacht (section "Third campaign …" below; not yet played in game). `tests/check-scenarios.ps1` checks all of them: sections, mission, race setting, both maps (boundaries, overlaps), raw materials, villages, gold, flags.

### Gameplay options: building costs, running costs, taxes, radius, fertility, mines, disasters (2026-11-12)

Seven new options in `src/anno-patcher.ps1` (changed as well: `tests/test-patcher.ps1`, `dev/check-game.ps1`). Evidence outside the repository (parser prototype, dumps, Ghidra listings, a copy of the Ghidra project). **Not yet checked in the running game**: everything below comes from the code and the offline tests; the in-game test plan is at the end of this section.

**Method: the game's own `haeuser.cod` parser in the image (O).**
- `FUN_140090660` (parser) and `FUN_140092e00` (follow-up at program start) run in the test helper process (exe loaded with `LoadLibraryEx(DONT_RESOLVE_DLL_REFERENCES)`) once the 103 imports of `api-ms-win-crt-*`, `VCRUNTIME140` and `KERNEL32` are written into the IAT by hand and the process runs in the game folder (`fopen("haeuser.cod")` is relative). Return value 1.
- The result matches every value read in the running game so far: storage Kontor I 960, Maxwohn 128/384/960/1600/2560, Kontor I costs 100 gold / 3 t tools / 6 t wood (paid in game on 2026-11-09), and `-Production 2` shortens exactly **125** intervals (the number the tool reported in game on 2026-11-10).
- **I** The table in the image therefore equals the table in the game. `FUN_140092e00` only rewrites the interval of PRODTYP kind 10 (growth level) and the group fields +4/+8, none of the fields used below.
- Test helpers: `Start-ImageProcess -Crt`, `Invoke-HaeuserParser` in `tests/test-patcher.ps1`.

**Building table (O, parser `FUN_140090660`):** 500 entries of 0x90 bytes from `0x1406ba1c0`; object `HAUS` (index = Nummer) and its sub-objects `HAUS_PRODTYP` / `HAUS_BAUKOST` (index = parent Nummer).

| Offset | Size | Keyword | Note |
|---|---|---|---|
| +0x00 | int | Id | 2xxxx; `0x1405b9e80[Id − 20000]` = table index |
| +0x04 | int | kind (HAUS) | 0x23 Kontor, 0x24 shipyard, 0xE building … |
| +0x1C | int | kind (PRODTYP) | 1 HANDWERK, 2 PLANTAGE, 3 BERGWERK, 7 MARKT, 8 KONTOR, 0xD WOHNUNG, 0x11 tavern, 0x12 chapel, 0x13 church, 0x14 bathhouse, 0x15 theatre, 0x16 doctor, 0x17 school, 0x18 university, 0x19 gallows, 0x1A fire brigade ("BRUNNEN"), 0x1B castle |
| +0x20 | byte | Radius | |
| +0x21 | byte | Ware | |
| +0x22 / +0x23 | byte | Rohstoff / Workstoff | |
| +0x24 / +0x26 / +0x28 | short | Prodmenge / Rohmenge / Workmenge | × 32 |
| +0x2A / +0x2C | short | Kosten | +0x2A paused (`KOST_*_SLP`), +0x2C active |
| +0x2E / +0x2F | byte | BGruppe / Bauinfra | |
| +0x30 | short | Maxlager | × 32 |
| +0x32 … +0x3A | short | Maxprodcnt / Arbeiter / Maxnorohst / Erntesmp / Interval | |
| +0x50 / +0x52 / +0x54 / +0x56 | short | BAUKOST Werkzeug / Holz / Ziegel / Kanon | tons × 32 |
| +0x58 | int | BAUKOST Money | |
| +0x72 | byte | flags | PlaceFlg 4, NoShot 0x10, Strand 0x20, Ausbau 0x40, Destroy 0x80 |

Population groups (`BGRUPPE`, 5 × 0x50 bytes from `0x1406ba020`): +0x00 Prozent, +0x04 number of goods, +0x08 Prozent × number, +0x0C Maxwohn × 64 (= `0x1406ba02c`, see "Extensions"), **+0x10 Steuer** = (int)(value × 5.3333) (double at `0x1400eb9b0`) = 7/8/11/12/13, +0x14 Hiscore, +0x18 … consumption of 8 goods.

**Implementation** (the usual pattern: wait until the table is loaded, check the originals, a marker against applying twice, clean abort on unexpected bytes):

| Option (launcher values) | Location | Method |
|---|---|---|
| `-BuildCost F` (1, 0.75, 0.5, 0.25, 0) | building table +0x50/+0x52/+0x54 (16 bits) and +0x58 (int), 500 entries | SHA-256 of the original fields must match; every value × F; marker `BAUK` + F × 100 at RVA `0xE5BC0` |
| `-Upkeep F` (1, 0.75, 0.5, 0.25, 0) | building table +0x2A/+0x2C | the same; marker `UNTH` + F × 100 at RVA `0xE5BC8` |
| `-Taxes F` (1, 1.5, 2, 3) | population groups +0x10 (5 ints) | originals 7/8/11/12/13 or the target values |
| `-Radius F` (1, 1.5, 2) | building table +0x20 (8 bits), 17 entries | originals known, at most 48 |
| `-Fertility Everywhere` | resource code stub (RVA `0xE5C00`) + hook RVA `0xD0D56` → code stub RVA `0xE5BA0` | new endless games with island spreading only |
| `-Mines Infinite` | RVA `0xBA429`, `0xBA495` | two subtractions → NOPs |
| `-Disasters Off` / `More` | 5 calls (Off) or 10 limits (More) | code sites, all or nothing |

Pass decimals with a dot (`-BuildCost 0.5`). The patcher accepts any value in the ranges `[0, 1]` (build cost, upkeep), `[1, 3]` (taxes), `[1, 2]` (radius); the launcher offers the values above.

**Building costs (`-BuildCost`):**
- **O** Readers: building-site check `FUN_14000ef50` (sums the costs of the placed buildings and compares them with the warehouse stock +0x132 tools, +0x13E wood, +0x14A bricks, +0xC6 cannons; gold only `if cost != 0`), payment `FUN_140010390` (gold) and `FUN_1400b6420` (goods: stock − amount), house upgrade `FUN_1400b7c60` (tools/wood/bricks of the next house type), AI `FUN_14002a300`/`FUN_14002a360` and the AI planners (`cost × 64 + cost < gold`). No division by a cost field.
- **I** 0 is safe: all checks are `<=`/`<`, the gold check skips 0 explicitly, and many original buildings already cost 0 of some material. Free building therefore needs no minimum.
- **O** Real table: 174 entries with gold, 252 material values (all multiples of 32).
- Values: factor 0 → 0; otherwise round(v × F) half up, at least 1 gold; materials in whole tons, at least 1 t (the display shows whole tons). Cannons (+0x56) unchanged. Before writing, the SHA-256 over +0x50…+0x55 and +0x58…+0x5B of all 500 entries must be `01bbc1ab…4e6d` (checksum of the real parse). ×0.5 changes 408 values (1 t stays 1 t), ×0 sets all 426 to 0.
- **I** Applies to the computer rivals (same table) and to house upgrades.

**Running costs (`-Upkeep`):**
- **O** `Kosten: a, b` = active / paused running costs (constants `KOST_*` and `KOST_*_SLP` in `haeuser.cod`). A town (75 records of 600 bytes from `0x140622dc0`) keeps running sums: production buildings at +0x1D8 (`FUN_1400b9160` when a production record is created; switching active/paused adjusts by +0x2A/+0x2C), +0x1DC from `FUN_1400b4b60` (houses and public buildings according to this analysis; the logbook notes call +0x1DC the costs of military buildings – **?**), workers at +0x218.
- **O** Economy tick `FUN_1400bc030`: gold += (taxes (`FUN_1400bbdc0`) − (+0x1D8 [+ +0x1DC for the human])) / 6. The AI pays no +0x1DC.
- **O** The town saver `FUN_1400c3250` does not write +0x1D8/+0x1DC; the `PRODLIST2` loader `FUN_1400c0960` rebuilds +0x1D8 from the current table. **I** The sums are recomputed on load, so a savegame loaded with another factor gets consistent sums (no drift, no negative costs). **?** Not yet confirmed in game (test plan 7).
- Values as for the building costs; SHA-256 over +0x2A…+0x2D must be `d8b34943…9f8f`; 107 values (×0.5 changes all non-zero ones). Ships and soldiers keep their costs.

**Taxes (`-Taxes`):**
- **O** `FUN_1400bbdc0` (income of a town) = Σ over the 5 groups of residents (+0x220 + 4g) × Steuer × 6 >> 5 × tax rate (byte +0x24D + g) >> 7; the same formula in the town window (`FUN_140057980`). No other reader.
- **I** The factor multiplies the income linearly at any tax rate. Overflow: with ×3 (39) and 500,000 residents of one group in one town still below 2^31.
- Values (round half up): ×1.5 11/12/17/18/20, ×2 14/16/22/24/26, ×3 21/24/33/36/39. Applies to the AI too; balance goals become easier.

**Influence radius (`-Radius`):**
- **O** Readers: territory `FUN_140095560` (PRODTYP 8 Kontor, radius at least 8; PRODTYP 7 market) → `FUN_14009d730` (circle from the profile table `0x1405ec300`, built for radius 0–127 in `FUN_1400b2550`; clipped at the island edge; only free land (owner 7) changes owner); supply of the houses `FUN_1400bea30` (house flags tavern 0x10, chapel 4, church 8, bathhouse 0x40, theatre 0x80, doctor 0x200, school 0x20, university 0x100, gallows 0x800, fire brigade 0x1000); placement helpers `FUN_1400c04d0`, `FUN_1400a3080`; overlays `FUN_1400149b0`, `FUN_1400c6500`/`FUN_1400c5670` (all via the profile table).
- **O** Limit: the AI copies the circle profile (radius + 1 bytes, `FUN_140007c60`) into its 0xA0-byte task block at +0x1D94 (`FUN_1400203f0`/`FUN_140020490`, memset 0x1D28…0x1DC7); nothing else in 0x1D95…0x1DC7 is accessed → radius ≤ 51. Largest original radius 24 (cathedral) → factor at most 2, hard cap 48.
- 17 entries with known originals: 270–273 Kontor I–IV (16), 461 cathedral (24), 462 chapel (8), 463 church (21), 464 tavern (12), 465 theatre (20), 466 bathhouse (20), 467/468 market (16), 469 doctor (16), 470 university (15), 471 school (12), 472 fire brigade (15), 474 gallows (16). Not changed: military (castle 15, towers 8), production buildings (catchment area), natives, ruins 274–277.
- **I** Territory is assigned when a Kontor or market is built (stored in the island tiles of a savegame); the supply of the houses is computed all the time, so larger radii of public buildings also work in loaded games.
- **?** Do market carts follow the larger market radius over longer roads (path finding)?

**Fertility (`-Fertility Everywhere`):**
- **O** Crops 0x2E TABAKBAUM, 0x2F GEWUERZBAUM, 0x30 ZUCKERROHR, 0x31 BAUMWOLLE, 0x32 WEINTRAUBEN, 0x33 KAKAOBAUM. Island record (`0x14062ddc0` + i × 0x2CC8): +0x00 number, +0x18 class, +0x1C climate, +0x20 deposits (8 bytes each, count +0x41), +0x44 flags (bit 2 = can get fertility), +0x45 drought level, +0x47 number of crops, +0x5C crop bits (bit = ware − 0x2D).
- **O** SZENE loader `FUN_1400d0de0`: 12 fertility entries from +0xB4 (house no. = Id − 20000 of a raw-material building whose Ware is the crop, amount); pass 1 classes 3–4 with limit 1, pass 2 classes 1–2 with limit 1, then repeated with the limit SZENE +0x60 (0 → 2) until nothing is assigned, then class 0 with limit 2. Candidates from `FUN_1400d0ce0(crop, class min, class max, limit, out)`: island present, flag bit 2, class, count < limit, bit not yet set, and the climate: 0x2E/0x30/0x32 only climate 0 (0x30 and 0x32 exclusive), 0x2F/0x31/0x33 only climate 1. Templates: 6 entries used (+0xB4…+0xDC), amounts 2–5, +0x60 = 2.
- **O** Growth: `FUN_14009db40` gives 0x80 (100 %) with the crop bit, 0x40 for a crop of the island's climate without the bit, 0 otherwise; field growth `FUN_1400998b0` uses it, minus the drought level (+0x45).
- Implementation: in the resource code stub (endless templates, after the island list) every fertility amount with a house no. → 50 and SZENE +0x60 → `FERT` (0x54524546). Hook at RVA `0xD0D56` (16 bytes `48 63 C9 41 8B 94 8F C4 0D 0D 00 49 03 D7 FF E2`: movsxd/mov/add/jmp of the jump-table dispatch, r15 = load address) → `jmp 0xE5BA0` (`E9 45 4E 01 00` …); code stub (30 bytes): `cmp r9d,'FERT'; je accept; <original dispatch>; accept: jmp 0xD0D8A`. All calls with the limits 1–3 or another +0x60 run unchanged (offline case AE: identical results before/after with test islands).
- **I** Every island with flag bit 2 ends with all six bits set (+0x47 = 6) → 100 % for every crop; the AI sees the bits too. The town window shows the 6 crop icons in fixed slots (`FUN_14005a3c0`), no overflow.
- Scope: new endless games with island spreading only (the resource code stub runs only for the three endless layouts). Not with `-StretchOnly`/`-NoIslandSpread`, not for own scenarios and random adventures (monopoly goals such as "Gewürzfieber" would break) and not for savegames (the bits are stored in the island data; a world generated with the option keeps its fertility even without the tool).

**Mines (`-Mines Infinite`):**
- **O** `FUN_1400b9ed0` case 3 (BERGWERK): deposit from `FUN_14009ebb0` (island +0x20 entry: ware, x, y, –, kind +4, amount +6 in tons × 32). Missing deposit or amount < Rohmenge → message 0x2D "mine exhausted" (human only). Path 1 (kind 1 or amount > 0xEFF): produce; gold never decreases; for the AI only above 0x4FF; otherwise `sub r8w,[rdi+0x26]` (RVA `0xBA495`), and below 0x20 `FUN_14009eab0` removes the deposit. Path 2: only with Erzbergnr (+0x3F) 0; decreases (`sub word [rdx+6],ax`, RVA `0xBA429`) only when flag `0x1405ec188` bit 3 is clear (the endless templates set it: TIMERS +0xA8 = 9/9/8/8).
- Implementation: `0xBA495` `66 44 2B 47 26` → `0F 1F 44 00 00`, `0xBA429` `66 29 42 06` → `0F 1F 40 00`. The amount never changes, the "< 1 t" branch never fires. Savegames untouched (amounts stay as they are).

**Disasters (`-Disasters Off|More`):**
- **O** Messages (`Text.cod` `[MELDUNG]`): 1 "Die Pest …" (plague), 2 "Ein Feuer ist ausgebrochen!" (a fire has broken out), 3 "Die Trockenheit …" (drought), "Ein Vulkan ist ausgebrochen!" (volcano). `FUN_1400b5120(…, kind 1 = plague / 2 = fire, duration)`.
- **O** `FUN_1400bc030` per town and economy cycle: plague `FUN_1400b7360` (citizens ≥ 200: rand % 400/250/180 ≤ 12, then table `0x1400ea3a0` by doctor/bathhouse cover), fire through a figure `FUN_1400b71f0` (merchants ≥ 300: rand % 400/250/180 ≤ 150, gallows cover lowers it to 2/8), fire in pioneer/settler houses `FUN_1400b7040` (rand % 100/150/200 ≤ 30, % 100/180/250 ≤ 15, rand & 0xFF ≤ 7; wooden houses more often). `FUN_14009e390` per island: drought `FUN_14009e320` (only difficulty ≥ 2 and flag bit 2 clear, every (27–34) × 600 clock steps, table `0x1400ea230`), volcano `FUN_1400715b0` (islands with volcano spots +0x40, flag bit 8 clear).
- **O** Flags `0x1405ec188` (TIMERS +0xA8, stored in savegames): bit 0 pirates only sighted, bit 1 skips the party loop `FUN_14003dc40` (AI and pirates), bit 2 no drought, bit 3 path-2 deposits do not run out, bit 6 no new traders, bit 8 no volcano. **?** bit 4 (set by `FUN_1400bdb00`, read by `FUN_140077210`), bit 5 (`FUN_14003b7e0`, `FUN_1400af980`), bit 9 (AI functions).

  | RVA | Original | Off | More |
  |---|---|---|---|
  | 0xBCAC3 | `E8 98 A8 FF FF` call plague | `0F 1F 44 00 00` | – |
  | 0xBCB07 | `E8 E4 A6 FF FF` call fire (figure) | `0F 1F 44 00 00` | – |
  | 0xBCBBB | `E8 80 A4 FF FF` call fire (houses) | `0F 1F 44 00 00` | – |
  | 0x9E860 | `E8 BB FA FF FF` call drought | `0F 1F 44 00 00` | – |
  | 0x9E93E | `E8 6D 2C FD FF` call volcano | `0F 1F 44 00 00` | – |
  | 0xBCABB | `83 FA 0C` plague ≤ 12 | – | `83 FA 19` (≤ 25) |
  | 0xBCAD8 / 0xBCAE5 / 0xBCAEA | fire figure divisors 180 / 400 / 250 | – | 90 / 200 / 125 |
  | 0xBCB2E, 0xBCB4A | `83 FA 1E` house fire ≤ 30 | – | `83 FA 3D` (≤ 61) |
  | 0xBCB76, 0xBCB94 | `83 FA 0F` house fire ≤ 15 | – | `83 FA 1F` (≤ 31) |
  | 0xBCBB3 | `83 F8 07` rand & 0xFF ≤ 7 | – | `83 F8 0F` (≤ 15) |
  | 0x9E875 | `83 C0 1B` next drought check (27–34) × 600 | – | `83 C0 0D` ((13–20) × 600) |

- eax is not used after the 5 calls (checked in the listing). The fire-figure limit 150 sits in eax and is reused after the call, so More changes the divisors instead. Each mode also checks the sites of the other mode for the original bytes, so Off and More cannot be mixed in one game process. Code patches only, nothing is stored in savegames (unlike the flag bits).
- **?** Is `FUN_1400b71f0` (figure 0x5C via `FUN_140080da0`, protected by the gallows) really an arsonist? The fire itself is started by the figure (`FUN_140070fd0` → `FUN_1400b5120(…, 2, …)`).

**Savegames:** building costs, running costs, taxes, radius, mines and disasters act on the running process only (nothing stored; the running-cost sums are recomputed on load, I). Fertility changes only newly generated worlds (stored in their islands). The territory of Kontore and markets built with a larger radius stays in the island tiles.

**Offline test (O):** `tests/test-patcher.ps1` 461 checks before the change, afterwards **556 of 556** (95 new checks in the cases AA–AH; the table cases use the real parse): AA building costs (checksum, every field scaled, marker, second run, other factor, wrong original, 0 = free), AB running costs, AC taxes, AD radius (17 radii, all other radius bytes unchanged), AE fertility (code stub and hook; function test of the resource code stub with the real templates and of the patched `FUN_1400d0ce0` with test islands; `-StretchOnly`/`-NoIslandSpread`: nothing), AF mines (falsified site → abort), AG disasters (other mode in the same process → abort), AH everything together (code stubs, tables and markers do not overlap; production ×2 shortens exactly the 125 intervals counted in the game). The `-CheckOnly` output of the old and the new patcher is identical for 5 combinations of the old options. Every new byte sequence disassembled with Ghidra (`AnnoPatchDis`): hook `JMP 0x1400e5ba0`, code stubs and NOPs decode as intended.

**In-game test plan (not yet done):** start with `-BuildCost 0.5 -Upkeep 0.5 -Taxes 2 -Radius 2 -Fertility Everywhere -Mines Infinite -Disasters Off` (plus the size options), German UI.
1. Console: every site set; "Baukosten x0.5: 408 Werte geaendert" and "Kontor I jetzt: 50 Gold, 2 t Werkzeug, 3 t Holz"; "Betriebskosten x0.5: 107 Werte geaendert" and "Kontor I jetzt: 8 (original 15), Kirche 25"; "Steuern x2: 14/16/22/24/26"; "Radius x2: Kontor und Markt 32, Kirche 42, Arzt 32 (17 Werte gesetzt)". No yellow "unerwartete Werte" line (that would mean the table in the game differs from the parse in the image).
2. Main menu, `dev/check-game.ps1 -Short`: markers `BAUK x0.5` and `UNTH x0.5`, Kontor I 50 gold / 2 t / 3 t, running costs 8 and 25, taxes 14/16/22/24/26, radius 32/32/42/32, fertility jump `E9 45 4E 01 00`, mines `0F 1F 40 00` / `0F 1F 44 00 00`, disasters Off.
3. New endless game: "islands with all six crops" in `check-game.ps1` = almost every island (all with flag bit 2). "Insel erkunden": six crop icons at 100 %, also those of the other climate; a cotton plantation on a northern island grows.
4. First Kontor from the ship: gold −50 (not −100), ship −2 t tools, −3 t wood; the dotted building area is about twice as wide (radius 32); market radius 32.
5. Chapel: houses up to 16 tiles away (original 8) count as supplied (faith need met).
6. Town window: running costs about half; taxes of player 0 doubled compared with a run without `-Taxes` at the same tax rate and population.
7. Save, quit, restart with the same options, load: running costs equal before/after; loaded without `-Upkeep`: back to the original sums.
8. Ore mine on a deposit, 30+ minutes at F7: the deposit amount stays constant (without the option it falls for kind-1 or > 119 t deposits).
9. Disasters Off: a town with > 300 citizens/merchants for an hour at 16×: no plague or fire; on Fordernd/Schwer no drought. Disasters More (separate start): more plague and fire messages than normal.
10. The rivals keep building and growing; no crash at 16× with all options for 30 minutes. `-BuildCost 0`: building with an empty warehouse works.
11. `-BuildCost 0 -Upkeep 0`: construction free, running costs 0, balance = taxes.

**Open (?):** market cart range with radius ×2; identity of `FUN_1400b71f0`; running-cost sums rebuilt on load (plan 7). Fertility is deliberately not applied to own scenarios (monopoly goals); it could be offered for random adventures later (SZENE +0x60 = `FERT` and amounts 50 in the generated file, hook active).

### Third campaign "Die Sturmsee", four challenges, English scenarios, ship cargo, random adventures (2026-11-12)

Files: `src/build-scenarios.ps1`, `src/scenario-lib.ps1`, `tests/check-scenarios.ps1`, new `src/random-adventure.ps1`. **None of the 10 new scenarios and no random adventure has been loaded or played in game yet**; their difficulty is designed by analogy with the measured chapters.

**Ship cargo (SHIP4 +0x174) (O, loader `FUN_14008e4f0`, cargo loop from `param_2 + 0x184`, 2 × 4 entries):** 8 holds of 8 bytes from the SHIP4 entry +0x174.
- dword A: bits 0–15 = **house no. of the producing building** (`Id` − 20000 in `haeuser.cod`), bits 16–29 = amount × 32, rounded down to whole tons (`amount − (amount & 0x1F)`).
- dword B: flags (10 bits, end up in bits 22–31 of the memory dword); 0 in every original file.
- The house no. goes through the table `0x1405b9e80` (id < 0xDAD → building index) to the building table; the good is the building's byte +0x21 (`0x1406ba1e1`, its `Ware`). The trader loader `FUN_14008e1f0` (`HANDLER`) uses the same scheme.
- Ids 9901–9950 are soldiers (good code 0x19 + id − 9901 = wSOLDAT1 …); in the originals 9901 + 4 × kind + owner, amount always 1,600. Not used by us.
- **O Evidence:** start ship of the endless templates = 515 (tool smithy) 1,600 = 50 t tools, 2001 (forester) 960 = 30 t wood, 1075 (fishery) 320 = 10 t food – the start cargo seen in game. The AI start ships carry 50/50/10 t.
- **O All 131 original scenarios with SHIP4** (`Szenes\*.szs|*.szm`) use the house numbers 507 cloth, 513 bricks, 515 tools, 517 swords, 519 liquor, 521 iron, 525 tobacco goods, 527 cannons, 1075 food, 1501 spices, 1505 wool (cotton plantation), 1507 tobacco, 1509 cocoa, 2001 wood, 2401 ore, 2405 gold, 9901–9916 soldiers. Highest used hold per ship type 21: 3, 23: 5, 25: 2, 27: 7 (= 4/6/3/8 holds, matches `figuren.cod`). Never more than 50 t per hold (although the holds of 23/25/27 take 80/65/120 t); whole tons except one entry; flags always 0.
- **O Goods and raw-material codes** (string list in the exe at file offset 0xE7920, from `NOWARE` = 0; consistent with `GETREIDE` = 0x2D and the AUFTRAG4 goods): NOWARE 0, ALLWARE 1, EISENERZ 2, GOLD 3, WOLLE 4, ZUCKER 5, TABAK 6, FLEISCH 7, KORN 8, MEHL 9, EISEN 10, SCHWERTER 11, MUSKETEN 12, KANONEN 13, NAHRUNG 14, TABAKWAREN 15, GEWUERZE 16, KAKAO 17, ALKOHOL 18, STOFFE 19, KLEIDUNG 20, SCHMUCK 21, WERKZEUG 22, HOLZ 23, ZIEGEL 24, wSOLDAT1 … (25–44), GETREIDE 0x2D, TABAKBAUM 0x2E, GEWUERZBAUM 0x2F, ZUCKERROHR 0x30, BAUMWOLLE 0x31, WEINTRAUBEN 0x32, KAKAOBAUM 0x33, GRAS 0x34, BAUM 0x35, STEINE 0x36, ERZE 0x37, WILD 0x38, FISCHE 0x39, SCHATZ 0x3A.
- **I Memory:** ship record `0x1401d8bb0` + slot × 0x328, cargo at +0x300 + 4 × hold: byte 0 = good code, bits 8–21 = amount × 32, bits 22–31 = flags; e.g. 20 t tools = `0x00028016`. **?** Not yet read in game.
- Implementation: `scenario-lib.ps1` `$CargoHouse` (only the 16 house numbers the originals use), `$ShipTypes` (holds, tons per hold, cannons), `New-CargoBytes` (checks holds and capacity). Scenario keys `Cargo` (the human's start ship; replaces the template's 50/30/10 t) and `Fleet[].Cargo`. `check-scenarios.ps1` decodes the written files: same 8-byte layout as the templates, e.g. Sturmsee 1 `03 02 80 02 00 00 00 00 | D1 07 80 01 … | 33 04 00 01 …` = 20 t tools, 12 t wood, 8 t food.
- Not used (not seen in the originals, so not verified): 529 muskets, 505 clothes, 533 jewellery, 1511 sugar, 1513 cattle, 1503 grain, 501 flour, 1515 wool from sheep.

**Player names, rival ships (O):**
- PLAYER4 entry (0x430 bytes) +0x3C0: player name (0x40 bytes), copied with `strcpy_s` to the player table +8 (`0x1405f0968`); +0x400: a second string (0x20 bytes) → player table +0x48 (loader `FUN_1400b1020`; its branch for the older 0xAC-byte entries reads +0x3C/+0x7C instead). +7 colour index.
- The templates differ: `[[48]]1x` has the rivals "Roter / Gelber / Weißer Spieler" (red / yellow / white player), `[[48]]2x` "Roter / Blauer / Gelber Spieler". The colour of a slot is therefore not fixed across templates.
- Scenario key `Rivals = @(@{ Player = 1–3; Gold; Name; Ship })` sets gold, PLAYER4 name and the name of the rival's start ship (SHIP4 entry with owner +0x4B = player); `ShipName` renames the human's start ship.
- **?** Whether and where the game shows the name of a computer rival (diplomacy, status, warehouse info). The texts therefore also name the rival's start ship, which is visible for sure (SHIP4 name → ship +0x296).

**Rules for the goal design (O, `FUN_1400ae010` / `FUN_1400ceea0`; the complete mission entry is in "Logbook" below):**
- Town goals 1–3 are assigned greedily per settlement in slot order (goal 1, else 2, else 3); one settlement satisfies only one town goal. Keep them in descending order (`check-scenarios.ps1` checks this; the loader sorts them anyway).
- "Every own town at least" (bit 8, file +0x8AC): every own settlement must meet it, including warehouse-only outposts; with no settlement at all it is trivially true. The texts warn about outposts. **?** Outpost case not checked in game.
- Monopoly 1 and 2: at the start `FUN_1400ceea0` replaces the island count of **both** (bits 0x4000/0x8000) with the number of islands that carry the crop. Check: own settlements on such islands ≥ count, and no settlement of a human or AI player (kind 0/0xC) on such an island; native villages do not matter. Codes 0x2D–0x3A test the island's fertility bit (code − 0x2D), other codes its deposits. **I** A crop that lands on no island gives count 0, so the goal is met at once.
- Goods: sum over the own settlements of settlement +0x2A + good × 0xC (× 32). Cargo on ships does not count, unloading it does, so `check-scenarios.ps1` rejects goal goods in the human's start cargo.
- Defeat: player kind 9. Defeating more rivals than required does no harm.

**Scenario builder:**
- `build-scenarios.ps1 -Language de|en` (default: `$env:ANNO_EXTENSIONS_LANG`, otherwise the UI culture), `-OutFolder`, `-Library` (or plain dot-sourcing: functions and `$Scenarios` only, nothing is built); `-Install` copies only the files of this run.
- Every definition is bilingual (`Title`, `Text`, fleet `Name` as `@{ de; en }`). German output of the 13 old scenarios at the time of the change: SHA-256 identical to `analysis\reference-scenarios-v1` (13/13). Afterwards the German "Smaragdinseln 2" text was changed on purpose: "Es ist nur eine Handvoll." instead of "drei oder vier" (spices on 2 islands since 2026-11-11, big version 3); this one file no longer equals the build of 2026-11-11.
- English file names: Emerald Isles 1–6 (Landfall, Spice Fever, Two Colonies, Black Sails, The Conqueror, Crown of the Isles), Race 1–4 (First Harbour, Civic Pride, Merchant Republic, The Crown), Challenge - Island Realm / Trade Empire / Gold Rush / Archipelago / Continents / Merchant Fleet / Sea Power, Storm Sea 1–6 (Shipwreck, Tobacco and Cocoa, The Free Port, The Red Flag, Betrayal, The Golden Age). English texts are plain ASCII.
- New map keys: `MaxClass` (shrink the islands), `AddIslands` (fill the gaps up to n islands, 14 tiles apart, deterministic LCG from Number + GameId), `Continents = @{ Lar; Big; Small }` (template positions become 100×90 / 70×60 islands around their centre, at most 10 lar), `GameId` (overrides 0x53D00000 + Number).
- Start point: 14 tiles from every island in all 6 map versions as before; only if none exists 12, then 10 (extra ships then 5 tiles from the start instead of 7–9). All 23 scenarios found 14.

**New scenarios (10 per language):**

| No. | German / English | Template, map | Difficulty | Start | Goals |
|---|---|---|---|---|---|
| 31 | Sturmsee 1 - Schiffbruch / Storm Sea 1 - Shipwreck | `[[48]]12` X, 17 islands (big 47) | 1 | 10,000 gold (rivals 20,000); "Morgenstern" with only 20 t tools, 12 t wood, 8 t food; 3 + 3 villages | town 200 (100 settlers+), 2 own settlements, balance ≥ 0 |
| 32 | Sturmsee 2 - Tabak und Kakao / Tobacco and Cocoa | `[[48]]10` XY, 18 (50) | 1, AI 2 | 30,000 / 25,000; tobacco 2, cocoa 2 islands (big 3/3) | tobacco monopoly + cocoa monopoly, town 600 (300 citizens+) |
| 33 | Sturmsee 3 - Der Freihafen / The Free Port | `[[48]]21` XY, 20 (50, Large) | 2 | large trading ship "Hoffnung" with 50 t cloth, 50 t liquor | trade only: trade balance ≥ +400, 40 t tobacco goods, 40 t cocoa |
| 34 | Sturmsee 4 - Die Rote Flagge / The Red Flag | `[[48]]22` Y, 17 (47, Large) | 2, pirates | cargo 50 t tools, 40 t wood, 30 t bricks, 10 t cannons; 2 small warships | ≥ 3 settlements, EVERY settlement ≥ 300 (100 citizens+) |
| 35 | Sturmsee 5 - Verrat / Betrayal | `[[48]]20` Y, 18 (50, Large) | 2, AI 3 | rival 2 = "Haus Valcourt", 60,000 gold, ship "Valcourts Stolz"; the others 20,000; large + small warship | defeat player 2 only, town 1,000 (400 merchants+) |
| 36 | Sturmsee 6 - Das Goldene Zeitalter / The Golden Age | `[[48]]31` Y, 20 (50, Huge) | 3, pirates | 50,000 / 50,000; large trading ship (50 t tools, 50 t bricks, 40 t wood) + large warship | town 2,000 (800 aristocrats), town 1,200 (500 merchants+), 4,000 in total, 40 t jewellery, balance ≥ +800 |
| 24 | Herausforderung - Archipel / Challenge - Archipelago | `[[48]]11` X, max. class med (was mit until the game test, see "In-game tests of phase 2") + filled: 30 islands, big 50 (20 med / 16 mit / 14 lit) | 1 | cargo 50 t tools, 50 t wood, 20 t food, 20 t bricks + small trading ship "Inselspringer" | ≥ 10 settlements, EVERY settlement ≥ 100 (40 settlers+) |
| 25 | Herausforderung - Kontinente / Challenge - Continents | `[[48]]20` Y, 5 lar + 4 big + 3 lit = 12 (big 33: 10 lar, 23 big) | 2, AI 2 | 35,000 / 35,000 | town 1,500 (400 aristocrats), 3,000 in total, balance ≥ +300 |
| 26 | Herausforderung - Handelsflotte / Challenge - Merchant Fleet | `[[48]]12` XY, 17 (47, Large) | 1 | 15,000 gold; 2 large trading ships (cloth/liquor/tobacco goods; tools/wood/bricks) + small warship | ≥ 4 settlements, 60 t spices, 60 t cocoa |
| 27 | Herausforderung - Seemacht / Challenge - Sea Power | `[[48]]21` XY, 20 (50) | 2, AI 1 | 60,000 gold, rivals 10,000; 2 large warships (cannons, swords) + small warship | defeat all three rivals (quickly; the rivals are weak) |

Difficulty = template (0 Einfach … 3 Schwer); "AI n" = rival strength set separately (TIMERS +0xA6). Every goal type known to be verified is used at least once: towns with stage, number of towns, every town at least, total residents, balance, trade balance, 2 goods, 2 monopolies, defeat specific rivals, start fleet, start cargo, pirates, natives, AI key, gold. No new race chapters.

**Random adventures (`src/random-adventure.ps1`):**
- Parameters: `-Seed 0…999999` (default random, printed), `-Difficulty Easy|Average|Demanding|Hard` (default Average), `-Language de|en`, `-OutFolder` (default `src\scenarios`), `-Install`, `-GamePath`. File "Abenteuer <seed>" / "Adventure <seed>". The same seed with another difficulty gives the same file name and overwrites the file.
- `SZENE_GAMEID` = 0x53000000 + difficulty << 20 + seed; `check-scenarios.ps1 -Reproduce` regenerates the file from it.
- Random numbers: Park-Miller (48271, 2^31 − 1), seeded from the seed (and the attempt number, 0 unless a build fails). Both languages draw the same numbers, so de and en give the same map and mission.
- Map: layout 0–2 × mirroring (X / Y / XY). Classic: enlarge 1–4, big version Normal/Large/Huge. Archipelago: max. class 2 (med; class 1 made the rivals drop out, see "In-game tests of phase 2"), 26–30 islands, big Normal. Continents: 4–5 lar, 3–4 big, 2–3 small, big Large/Huge.
- World: ore 4–6 / 7–10, gold 2–3, treasure 4–12; at least 6/9 ore for weapon goods or conquest, 3 gold for jewellery/gold goods. Crops at least 3 for goods goals; monopoly crop 1–2 (big +1). Villages 1–4 per climate, big 4–6. Gold: Easy 40–50k, Average 30–40k, Demanding 25–35k, Hard 20–30k (+5k realm, +10/15k conquest); rivals 10–20k / 20–30k / 30–40k / 40–50k. AI 0–1 / 1–2 / 2–3 / 3. Pirates 0 / 35 / 70 / 100 %.
- Ships: Easy rich cargo (50 t tools, 50 t wood, 20 t bricks, 20 t food); Hard 50 % lean cargo (30/20/10); extra ship for realm/trade (Easy, Average), warships for conquest, 50 % escort with pirates from Demanding on.
- Main goal weights (Easy/Average/Demanding/Hard): towns 40/30/25/25, realm 25/20/20/15, trade 20 each, monopoly 15 each, conquest 0/15/20/25. The map kind follows the goal: no big towns, trade or conquest on archipelagos; no realm on continents.
- Main goal values: towns 250–400 settlers … 1,500–2,500 aristocrats, second/third town from Average on; realm 3–8 settlements with 600–3,500 in total, or 5–6 settlements with "every settlement 150/60 settlers" or "250/80 citizens"; trade 2 goods 30–80 t + trade balance 100–400; monopoly 1–2 crops of spices/tobacco/cocoa/sugar/wine + a town; conquest: Average 1 poor named rival + town 400, Demanding 2 named rivals or 1 rich one + town 800, Hard all three.
- Add-ons: 0 / 1 / 1–2 / 2 (one fewer for conquest, and for monopoly from Demanding on): balance 0–1,000, trade balance 100–500, one good (thematic for monopolies), total residents, a town.
- Text blocks: opening per map kind (2–3 variants), motive per goal (1–2), twists (pirates, rival strength, natives, cargo, extra ships), goals, the helmsman's advice per goal plus pirates/cargo/ore/gold, closing line.

**Offline tests (O, 2026-11-12):**
- German build: 13/13 old files SHA-256 identical to `analysis\reference-scenarios-v1` (before the Smaragdinseln 2 text change above); 23 files de + 23 files en built.
- New checks in `check-scenarios.ps1`: goal bits known; town goals descending; every goal number written in the text; language recognised; English texts and file names ASCII; no CR; goods/monopoly codes valid, defeat only players 1–3; ship type, cargo space, cannons; cargo house no. known, whole tons, holds ≤ type, flags 0; goal good not in the human's start cargo; adventure game id = seed/difficulty; `-Reproduce`.
- Results: all 13 (`analysis\reference-scenarios-v1`) OK; all 23 de and all 23 en OK; 128 adventures (16 seeds × 4 difficulties × 2 languages, all 5 goal types and 3 map kinds) all OK; `-Reproduce` in a separate process 128 of 128 byte-identical; 20 random seeds generated twice: 20 of 20 identical; combined folder "All 174 scenarios OK", exit 0.
- Negative test (corrupted copy): all 5 errors found (non-ASCII in the English text, goal number missing in the text, 645/32 t, goal good cocoa in the start cargo, game id), exit 1.
- Not tested by the agent: `-Install` (writing to Documents was off-limits).

**Open (?):**
- **?** In game: cargo of non-default goods (cannons, swords, cloth, liquor, tobacco goods, bricks) appears in the ship window and can be unloaded.
- **?** Whether the PLAYER4 name of a rival is shown anywhere in the game.
- **?** "Every town at least" with a warehouse-only outpost (from the code: it fails the goal).
- **?** Monopoly crop amount 1 (Demanding adventures): the crop might land on no island, and then the goal is met at once.
- **?** Ore mountains on lit/mit islands (archipelago); the generator avoids ore and gold goods there.
- ~~`install.ps1` copies every `*.szs` in `src\scenarios` (both languages and adventures after a language switch).~~ Fixed: the installer builds into a fresh temp folder (see "Launcher" below).
- `build-scenarios.ps1` takes `Get-IslandPlan` from `anno-patcher.ps1` through the syntax tree; the planner itself is unchanged.

### Logbook companion window (2026-11-12)

`src/logbook.ps1` (WinForms, UTF-8 with BOM, about 1,900 lines incl. C# and self-test). **Nothing in this section has been measured in the real game yet**; "O (test)" = checked in the offline tests (synthetic memory images and a helper process that maps the exe copy as an image). Addresses marked I come from the decompiled code (`analysis/scan/alle-funktionen.c`).

**The tool:**
- Start: `powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File src\logbook.ps1` or the launcher button "Logbuch öffnen" (Open logbook). One instance at a time (mutex `Local\Anno1602-Extensions-Logbook`; a second start activates the first window by its title "Logbuch – Anno 1602" / "Logbook – Anno 1602" and exits 0).
- Attaches to the newest `Anno1602.exe` (base from `MainModule`), checks the SHA-256 of the exe file (`7731972f…b7a1`, as the patcher; another version → "Unbekannte Spielversion" (unknown game version), nothing is read) and opens the process with `PROCESS_QUERY_INFORMATION | PROCESS_VM_READ` (0x410) only. Never writes. Refresh every 2.5 s. The process end is detected with `GetExitCodeProcess` (also the Ubisoft Connect quick restart) → "Warte auf Anno 1602 …" (waiting for Anno 1602), then it re-attaches. `MainModule` failing for > 10 refreshes → "Kein Zugriff" (no access).
- Window: title (scenario or game name, game time, speed), AUFTRAG / MISSION (goals with live bars), DEIN REICH / YOUR EMPIRE (gold, balance · trade balance, towns and the largest, ships, residents per stage as a stacked bar, workers), GEGNER / RIVALS (best town, total residents, towns, ships, gold; race progress bars in races), ERFOLGE / ACHIEVEMENTS (24 badges, tooltips with date and game). Footer: status, "Im Vordergrund" (On top, TopMost), "Kompakt" (Compact: title, goals and one line gold/residents/towns). An unlock shows a gold banner for 8 s, plays the system sound (Asterisk) and highlights the badge.
- Parameters: `-SelfTest [-SelfTestFolder]`; hidden for tests: `-FunctionsOnly`, `-Dump`, `-PreviewImage <png>`, `-TestProcessId`/`-TestBase`, `-AppDataFolder`, `-TestTicks n -TestLog file`.
- Refresh cost (O, test): about 128 ms in the worst case (75 settlements, 200 ships, monopoly goal → 573,600-byte island read), the snapshot alone about 10 ms.

**Memory read** (RVA = VA − 0x140000000, all in `.data` RVA 0xF9000–0x913D28, O: PE section table):

| RVA | Size | Content | Source |
|---|---|---|---|
| 0xF99F8 | int | game speed 1/2/4 (8/12/16 with turbo); command 0x0F | "Extensions", I: `FUN_14008cef0` |
| 0x1D8BB0 | 200 × 0x328 | ships: byte 0 = 0x50 in use, +0x28 owner | "Rivals and pirates" |
| 0x5C0E50 | 0x54 | "new game" parameter block, see "Scenario name" | I |
| 0x5EBF68 | int | **end-of-game lock** (1 = game over) | I, see below |
| 0x5EC0F8 | int | game clock | "Ships, money" |
| 0x5EC1A8 | int | **time limit** (game clock); reached → message 0x5A (lost) | I: `FUN_1400af980`, `FUN_1400b0000` |
| 0x5EC1C0 | int | difficulty | "Rivals and pirates" |
| 0x5EC720 | 4 × 0x108C | missions | below |
| 0x5F0960 | 7 × 0x280 | players | "Players and parties" + below |
| 0x5F1D60 | int | number of the local (human) player (0 in single player) | I: `FUN_14000ef40`, `FUN_1400af980` |
| 0x622DC0 | 75 × 600 | settlements | below |
| 0x62DDC0 | 50 × 0x2CC8 | islands (only for monopoly goals) | below |
| 0x6BA02C | 5 × 0x50 | population groups: +4 tax per resident | I: `FUN_1400bbdc0` |
| 0x6D7E60, 0x6D80A4/A8/AC/B0 | int | upkeep per unit kind (balance) | I: `FUN_1400ad5d0` |

**Player record (0x280), additions to "Players and parties" (I):**
- +0x08 name, char[0x40] (`FUN_1400a87f0`; the PLAYER4 loader copies it from the file, see "Player names" above); +0x48 second string (0x20).
- +0x68 player number = slot index (the PLAYER4 loader indexes the table by it); settlements and ships store this number as owner.
- +0x74 purchases, +0x78 sales (uint, × 480); each check period both decay × 179/180 (`FUN_1400af980`). Trade balance = +0x78/480 − +0x74/480.
- +0x81 byte (natives: player they are allied with?), +0x86 byte (number of settlements?; with +0x9A ships = 0 the human loses).
- **+0x84 = mission fulfilled flag**: set in `FUN_1400b0000` case 0x3E for the sender and for every other player whose mission check also passes; the score screen's mission bonus is `+0x84 ? 100 : 0` (`FUN_1400ad760`). Cleared by the player-table reset of command 0x36.
- +0x87 / +0x88 bytes: flags for the goal bits 0x20000 / 0x40000 (meaning **?**).
- +0x8E ushort: number of defeated rivals (goal bit 0x200; incremented in `FUN_1400b0000` case 0x57).
- +0xA4, +0xA8, +0xAA, +0xAC, +0xAE ushort: unit counts, × upkeep 0x6D7E60 / 0x6D80A4 / 0x6D80A8 / 0x6D80AC / 0x6D80B0 (only for kind 0).

**Settlement record (600 bytes):**
- **I** +0x00 name char[0x18] (`FUN_14009a9f0`: every new settlement gets a name from the list at 0x5C1B00); +0x18 island index (0xFF = free), +0x1A owner; +0x2A + good × 12: stock (ushort, 1/32 t); +0x1D8 / +0x1DC running costs (see "Running costs" above), +0x1E0 founding clock + 600; +0x216 number of buildings, **+0x218 workers** (sum of building table +0x34 of the settlement's production and public buildings, `FUN_1400b3a90` & co.; the game counts them in the town total = +0x218 + stages); +0x220 … +0x230 residents per stage (pioneers … aristocrats), +0x24D … +0x251 tax rate per stage (128 = 100 %), +0x254 own index.
- **O** (race logs of 2026-11-12) rival towns with stages `[0/0/0/0/0]` still had 63–124 residents → that is +0x218.
- Logbook rule (decision): a slot counts if +0x18 ≠ 0xFF **and** the name is not empty (before the first game the table is all zeros, and +0x18 = 0 would look "in use" for owner 0). The game itself only checks +0x18.

**Island record (0x2CC8) (I):** `FUN_14009dbe0` (island has raw material m): m 0x2D–0x3A → bit (m − 0x2D) of the uint +0x5C (fertility); otherwise deposits: count byte +0x41, entry i: material byte +0x20 + 8i, quantity ushort +0x26 + 8i, must be > 0x1F.

**Mission entry in memory (0x108C) (I: loader `FUN_1400b1780` AUFTRAG4 branch, check `FUN_1400ae010`):**

| Offset | Content |
|---|---|
| +0x00 | goal bits |
| +0x04 | "protect" condition bits (1: the supported player keeps a town ≥ the +0x1080 triple, 2: keeps ≥ +0x24 towns) |
| +0x08 | supported player (7 = any) |
| +0x09 | number of rivals to defeat (bit 0x200, compared with player +0x8E) |
| +0x0A … +0x10 | must-defeat flag per player 0–6 (bit 0x400) |
| +0x11/+0x12, +0x13/+0x14 | monopoly 1/2: raw material, island count (bits 0x4000/0x8000) |
| +0x1C | towns (0x20) · +0x20 ? · +0x24 supported player's towns (sub-bit 2) |
| +0x28 / +0x30 / +0x34 / +0x38 | total residents (0x80) / balance (0x100) / trade balance (0x10000) / voice message |
| +0x3C | mission text, 0x800 bytes as in the file · **+0x83C the same text with the `[[n]]` tags replaced** (`MaxnetOnlineOverlayReplaceTextTags`) |
| +0x103C/+0x103E, +0x1040/+0x1042 | goods 1/2: good byte, quantity ushort × 32 (0x1000/0x2000) |
| +0x1044 / +0x1050 / +0x105C | town 1–3: total, level, of which (bits 1/2/4; **the loader sorts the three by total, descending**, and sets bits 1/2/4 for non-zero totals) |
| +0x1068 | every own town at least: total, level, of which (bit 0x08) |
| +0x1074 | a town of the supported player: total, level, of which (bit 0x10) |
| +0x1080 | protect condition (sub-bit 1): total, level, of which |

**How the game checks a mission (`FUN_1400ae010(player, mission, &protectFailed)`), mirrored 1:1 by the logbook (I):**
- Only for kind 0, or for any kind if bit 0x800 (race). Start value of the result bits 0xCD08: 0x08, 0x100, 0x400, 0x4000, 0x8000 (and 0x800) are "met until disproved".
- Settlements in table order; own ones (owner = player +0x68): a settlement can satisfy **only one** town goal: `if (!met1 && fits1) met1 else if (bit2) { if (!met2 && fits2) met2 else if (bit4 && !met4 && fits4) met4 }`. "fits": of which (uint) ≤ residents of the level **and all higher levels**, and total ≤ town total (incl. workers).
- 0x08 is cleared by any own town that misses the "every town" triple (no towns → stays met).
- Goods: sum of the stock of all own settlements. Monopoly: count own settlements on islands with the material; cleared if a settlement of a kind-0 or kind-0xC player (not natives) sits on such an island; count < required → cleared.
- 0x400: every must-defeat player must be kind 9, or natives (kind 0xB) with +0x86 = 0 and +0x81 = this player.
- 0x100 (balance) is only evaluated when all other bits are met: `FUN_1400ad5d0` field 6 = taxes + (sales/480 − purchases/480 − costs − unit upkeep). Taxes per settlement (`FUN_1400bbdc0`): Σ trunc(trunc(residents_k × tax_k × 6 / 32) × rate_k / 128). Costs: +0x1D8, plus +0x1DC if the owner is kind 0.
- Protect conditions (+0x04) not satisfied → `FUN_1400af980` makes the human lose at once.
- Check frequency: `FUN_1400af980` is skipped while the lock 0x5EBF68 ≠ 0; a time limit 0x5EC1A8 ≠ 0 and ≤ clock → message 0x5A.

**Game end and result (used to record finished missions) (I):**
- The lock 0x5EBF68 (int; 0x5EBF6C is a separate int) is set to 1 only in `FUN_1400b0000`: case 3 (player out: the human defeated or bankrupt → only the human becomes kind 9), case 0x3E (a mission fulfilled → every kind 0/0xC player becomes 9; the human won if he is the sender or also fulfils it, otherwise message 0x53 = lost), case 0x5A (time limit → all 9, message 0x53). It is reset to 0 only by command 0x36, which both "new game" and **loading a savegame** send first (generic loader `FUN_140016bc0`).
- Logbook rule: phase "ended" = lock ≠ 0 or human kind 9 (with clock > 0); result = human +0x84 ? won : lost. A finished mission is recorded only if the logbook saw the same session running before (no duplicates when started at the score screen) and the human had a mission (mission slot ≤ 3, bits ≠ 0); endless games are not recorded.

**Scenario name (I):**
- 0x5C0E50 is the parameter block of a new game (copied into command 0x36): +0x08 campaign index (0xFF none), +0x0F mission index in the campaign, **+0x12 flags (bit 1 = own scenario, "CUSTOM")**, **+0x13 name, char[0x40]**.
- Path of the scenario: `FUN_1400d3d00`/`FUN_1400d3c50` build `"%s%s\\%s%s"` = Documents path (0x5C56C0) + folder (pointer 0x5C1A40) + **name** + extension (".szs" or other per 0x5C4D44), or for original campaigns from the table at 0x5C1720[campaign × 5 + mission]. For own scenarios the name is therefore the **file name without .szs**.
- The savegame writer stores the name as chunk `NAME` (and `CUSTOM` if bit 1); `FUN_1400d38b0` restores both when loading (64 bytes cleared, name copied, then matched against the scenario list with `MaxnetOnlineOverlayFindTextAllLanguages`). A saved and reloaded own scenario keeps its name.
- **?** Content for an endless game and for original campaign missions (the endless savegame `Welt1000x700.gam` has a `NAME` chunk). The logbook shows names starting with `[[` as "Endlosspiel"/"Szenario"; each mission record also stores `title` = first line of the mission text (+0x83C) as a fallback.

**logbook.json** (`%APPDATA%\Anno1602-Extensions\logbook.json`, UTF-8 without BOM):

```json
{
  "version": 1,
  "achievements": [ { "id": "citizens", "date": "2026-11-12T10:00:03", "game": "Wettlauf 2 - Buergerstolz" } ],
  "missions": [ { "scenario": "Wettlauf 2 - Buergerstolz", "title": "WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz",
                  "result": "won", "date": "2026-11-12T12:01:44", "gameHours": 5.1 } ],
  "settings": { "alwaysOnTop": true, "compact": false, "height": 780, "left": 1800, "top": 80, "width": 460 }
}
```

- Re-read before every write (changes by the launcher survive), written via a temp file + `File.Replace`. A broken file is renamed to `logbook.broken-<datetime>.json` and a new one is started. Unknown fields of mission entries are kept. The launcher's "Abenteuer" tab reads `missions` (scenario = file name, best result wins).
- Game hours = clock / 32,700 (endurance run: 523,094 in 60 min at 16×), rounded to 0.1.
- A condition must hold in two consecutive readings of a running game (clock > 0, lock 0, human kind 0) before an achievement unlocks (protection against half-loaded data); `mission_won` and `race_won` are set at the end of the game.

  | Id (stable) | German | English | Condition |
  |---|---|---|---|
  | first_town | Land in Sicht | Land Ho! | first own town |
  | settlers / citizens / merchants / aristocrats | Erste Siedler / Bürgerstolz / Pfeffersäcke / Blaues Blut | First Settlers / Civic Pride / Merchant Princes / Blue Blood | first resident of that stage |
  | res_1000 / res_5000 / res_10000 | Tausend Seelen / Blühendes Inselreich / Zehntausend Untertanen | A Thousand Souls / Thriving Realm / Ten Thousand Subjects | 1,000 / 5,000 / 10,000 residents in total |
  | city_2500 | Metropole | Metropolis | one town with 2,500 residents |
  | aristo_1000 | Hofstaat | Royal Court | 1,000 aristocrats |
  | towns_3 / towns_5 / towns_10 | Inselhüpfer / Kolonialmacht / Herr der Inseln | Island Hopper / Colonial Power / Lord of the Isles | 3 / 5 / 10 own towns |
  | gold_250k / gold_1m | Volle Truhen / Millionär | Full Coffers / Millionaire | 250,000 / 1,000,000 gold |
  | ships_5 / ships_10 | Kleine Flotte / Armada | Small Fleet / Armada | 5 / 10 own ships |
  | balance_500 | Schwarze Zahlen | In the Black | balance ≥ +500 (with a town) |
  | hours_10 / hours_50 | Sitzleder / Ewiger Regent | Staying Power / Eternal Ruler | 10 / 50 game hours in one game |
  | turbo | Volle Fahrt voraus | Full Speed Ahead | game speed 8× or faster |
  | rival_defeated | Bezwinger | Conqueror | a rival defeated (player +0x8E ≥ 1) |
  | mission_won | Auftrag erfüllt | Mission Accomplished | a scenario won |
  | race_won | Erster im Ziel | First Past the Post | a race won |

**Offline tests (O, 2026-11-12, game not running):**
- Static: BOM yes, no CR, parse errors 0, no function named like an alias or an existing command.
- `logbook.ps1 -SelfTest`: **73 of 73** (UI language de and en), synthetic images from the layouts above: the greedy one-town-per-goal rule, "or higher", race rivals, monopoly blocked by an AI but not by natives, gold deposits, taxes at 50 % rate, unit upkeep, trade.
- Live path: a helper process maps `analysis\bin\Anno1602.exe` with `LoadLibraryEx`, the test writes a race state into its `.data`, the logbook reads it via `ReadProcessMemory`: **14 of 14** – dump identical to the image snapshot; real window loop: running → game won written into the process → "ended" → helper killed → "waiting", exit 0 after 10 refreshes; `logbook.json`: mission `won`, 9.2 h, achievements incl. `mission_won`/`race_won`, settings saved on close; a second instance exits at once; a renamed `PING.EXE` as "Anno1602.exe" → "Unknown game version", nothing read; no process → waiting.
- Toggles (BM_CLICK on the off-screen window): compact 460×780 → 360×180 → back to 460×780; on top → TopMost; settings saved. (Bug found and fixed: leaving compact mode kept the small height.)

**In-game test plan (not yet done):**
1. Start the logbook before the game: "Warte auf Anno 1602 …"; start the game via the launcher (Ubisoft quick restart): within 2–3 s "Anno 1602 läuft – Starte oder lade ein Spiel", footer "Verbunden · PID …" (the second PID).
2. New endless game: title "Endlosspiel" (note what 0x5C0E63 holds), "Kein Auftrag", gold equals the in-game display, ships 1, speed text follows F5/F6/F7. Game time: about 1 h per 32,700 clock units; at F5, 10 real minutes ≈ 0 h 10 min (± 1 min).
3. Found a town: "Land in Sicht" unlocks after about 5 s with banner and sound; residents and stages equal the game's town window; "Bilanz" and trade balance equal the game's status window exactly.
4. Rival lines: names (empty → "Gegner 1–3"; same names → "(1)/(2)"), towns and residents plausible against the game's statistics.
5. "Wettlauf 1 - Erster Hafen": title = file name, mission 300 residents / 150 settlers+, race note, rival race bars. Goal reached → row green "erfüllt" before the game's victory; game ends → "Auftrag erfüllt – gewonnen!", `logbook.json` mission `won`.
6. A lost race (or a test copy with a lower goal so that a rival wins): entry `lost`, title "Spiel beendet – diesmal verloren".
7. Save, quit to the main menu, load: the title keeps the scenario name (`NAME` chunk), phase back to running (lock reset by command 0x36).
8. Handelsimperium / Goldrausch: goods bars equal the warehouse stock; Smaragdinseln 2: own spice islands counter and the blocking message when an AI settles there; Der Eroberer: "Besiege: Gegner 1, Gegner 2, Gegner 3" counter and rival line "besiegt".
9. Close the game while the logbook runs → waiting; restart → reconnects. "Im Vordergrund" and "Kompakt" survive a restart. Window over the game in window mode (WINDOW_MODE 2); in exclusive full screen use a second monitor.
10. The logbook must not change anything: `dev\check-game.ps1` output identical before and after.

**Open (?):** content of 0x5C0E63 for endless games and original campaign missions; AI player names; meaning of the goal bits 0x20000/0x40000 (player +0x87/+0x88) and 0x40 (not checked by `FUN_1400ae010` → such a mission cannot be won); where the time limit 0x5EC1A8 is set (only the reset and the checks were found; shown only when ≠ 0); balance formula mirrored from the code but not yet compared with the in-game status window (test plan 3).

### Launcher: three tabs, new presets, settings per savegame (2026-11-12)

`src/launcher.ps1` now has three tabs (German on a German Windows, otherwise English). The preset argument lists below were printed offline (`launcher.ps1 -PrintArgs`, O); all 86 choices of the 24 options are accepted by `anno-patcher.ps1 -CheckOnly` (O). `saves.json` from a real game end, the classification and the adventure list with logbook results were checked with the real game on 2026-11-12 (see "In-game tests of phase 2"); all buttons were clicked in code with the hidden switch `-TestClicks` (see the follow-up tests there).

**Tab "Neues Spiel" (New game):** every option as a drop-down list in four groups; `settings.json` stores option id → value key (independent of the UI language).

| Group | Options (German / English labels) |
|---|---|
| Welt / World | Kartengrösse, Inseln, Inselgrösse, Rohstoffe, Ureinwohner, Fruchtbarkeit / Map size, Islands, Island size, Resources, Natives, Fertility |
| Wirtschaft / Economy | Dein Startgold, Einwohner je Haus, Produktionstempo, Lager je Ware, Baukosten, Betriebskosten, Steuereinnahmen, Einflussradius, Erz- und Goldminen / Your starting gold, Residents per house, Production speed, Storage per good, Building costs, Running costs, Tax income, Influence radius, Ore and gold mines |
| Gegner und Gefahren / Rivals and dangers | Freie Händler, Computergegner, Gold der Gegner, Piraten, Piratenflotte, Katastrophen / Free traders, Computer rivals, Rivals' gold, Pirates, Pirate fleet, Disasters |
| Schiffe und Tempo / Ships and speed | Turbo (Taste F7), Schiffstempo, Laderaum der Schiffe / Turbo (F7 key), Ship speed, Cargo space |

Presets (map 1000 × 700 with more islands is the default and gives no argument):

| Button | Arguments for `anno-patcher.ps1` (O, `-PrintArgs`) |
|---|---|
| "Alles gross" (Everything big) | `-IslandSize Huge -Resources Lots -Natives Lots -Traders Lots -Rivals Hard -RivalGold 60000 -Pirates Active -PirateFleet Large -StartGold 50000 -Residents 5 -Turbo -TurboLevel 16 -Production 2 -Storage 5 -ShipSpeed 2 -Cargo 3` |
| "Für Kampagnen" (For campaigns) | `-Resources More -Turbo -TurboLevel 16` |
| "Gemütlich" (Relaxed, new) | `-IslandSize Large -Resources Lots -Pirates Off -StartGold 100000 -Residents 2 -Turbo -TurboLevel 16 -Production 2 -Storage 3 -BuildCost 0.5 -Upkeep 0.5 -Taxes 2 -Radius 1.5 -Fertility Everywhere -Mines Infinite -Disasters Off` |
| "Harte Probe" (Tough test, new) | `-Resources More -Natives More -Rivals Hard -RivalGold 100000 -Pirates Strong -PirateFleet Huge -Turbo -TurboLevel 16 -Disasters More` |
| "Alles auf Standard" (Reset to defaults) | `-Resources More` |

**Tab "Weiterspielen" (Continue):** lists every `.gam` of the Savegame folder, newest first, with map size and the options it was made with; "Mit diesen Einstellungen spielen" (Play with these settings) starts patcher and game with exactly those options, then the player loads the savegame in the game.
- Source: at the end of the game `anno-patcher.ps1` writes `%APPDATA%\Anno1602-Extensions\saves.json` (with the "Continue game" protection on, after renaming `lastgame.gam`, so the renamed autosave is recorded under its new name): one entry per `.gam` written during the session `{ File, Written (local time, ISO format 's'), Width, Height, Args }`; `Args` = the argument list of the run with numbers in invariant culture (dot), always with `-Width`/`-Height`, without `-CheckOnly`, `-WaitMinutes`, `-GameAlreadyRunning`, `-GamePath`, `-NoLastgameProtection`. At most 500 entries; the same file version (name + write time) is replaced.
- Classification in the launcher:

  | Kind | Rule | Button |
  |---|---|---|
  | known | entry with the same file name and a write time within 3 s | patcher + game with exactly the recorded arguments |
  | size | renamed autosave `lastgame-<W>x<H>-*` without a record | this map size plus the current options of the "New game" tab |
  | original | written before the oldest `Savegame-Backup-`/`Savegame-Sicherung-` folder (first use of the tool) | original game without changes |
  | unknown | everything else | disabled (grey line) |

**Tab "Abenteuer" (Adventures):** every `*.szs` in `Own Scenarios` (except the game's own "Last Szenario"), grouped by campaign (name before the chapter number or before " - "), sorted by chapter, with the progress from `logbook.json`: "✓ gewonnen <date>" (won), "verloren – nochmals versuchen" (lost), "→ nächstes Kapitel" (next chapter) at the first chapter of each campaign that is not won yet. Below the random-adventure panel: difficulty (Einfach / Durchschnittlich / Fordernd / Schwer), optional number (= seed), button "Abenteuer würfeln" (Roll an adventure) → `random-adventure.ps1 -Difficulty <X> [-Seed N] -Install`; the result box shows the name and the goals.
- The number field takes at most 6 digits (0–999,999, like `random-adventure.ps1`); a different input gives a short message instead of a parameter error.

**Buttons below the tabs:** "Mit Erweiterungen spielen" (Play with extensions), "Original starten" (Start original), "Logbuch öffnen" (Open logbook; starts `logbook.ps1` hidden, shown only if the file exists). On the "Continue" tab the two play buttons are disabled.

**Installer (`src/install.ps1`):** installs `anno-patcher.ps1`, `launcher.ps1`, `logbook.ps1`, `random-adventure.ps1`, `build-scenarios.ps1`, `scenario-lib.ps1`, `README.txt`, `README.de.txt` and `FINDINGS.md`; builds the scenarios in the UI language into a fresh temp folder and copies these 23 to "Own Scenarios" (the temp folder is deleted afterwards). `-Remove` deletes our scenario files by name in both languages, random adventures included (`^((Smaragdinseln|Wettlauf|Sturmsee|Emerald Isles|Race|Storm Sea) \d+ - .+|(Herausforderung|Challenge) - .+|(Abenteuer|Adventure) \d+)\.szs$`).

### In-game tests of phase 2 (O), 2026-11-12 08:56–09:44

Installed version (`install.ps1` from the repository), tool started detached via WMI, game via Ubisoft Connect, German UI. Read-only checks with `check-game.ps1`, `check-islands.ps1`, `logbook.ps1 -Dump/-PreviewImage` and a mission/ship reader.

**Options** (`-Resources More -BuildCost 0.5 -Upkeep 0.5 -Taxes 2 -Radius 2 -Fertility Everywhere -Mines Infinite -Disasters Off -Turbo -TurboLevel 16`):
- Console exactly as planned: all 33 sites set; "Baukosten x0.5: 408 Werte geaendert" (trading post I 50 gold, 2 t tools, 3 t wood), "Betriebskosten x0.5: 107 Werte geaendert" (8 / church 25), taxes 14/16/22/24/26, radius 32/32/42/32 (17 values). No "unexpected values" line, so the in-game building table matches the image parse.
- New endless game "Durchschnittlich": 50 islands, **50 of 50 with all six crops**, 500 fertilities, 57 ore deposits on 39 islands.
- 16-fold for about 1.5 game hours (clock 0 → 51,199): stable; rivals 222/374/222 residents in 2 settlements each; **rivals' gold 15,000 → 19,955 / 21,821 / 21,659** (normally it falls in the first hours); taxes/running costs per tick e.g. 881/197; ore and gold in the deposits **constant 4,880 t / 250 t**; no drought, no plague or fire.
- Game ended by terminating the process after the autosave: the tool renamed `lastgame.gam` to `lastgame-1000x700-20261112-090843.gam` and wrote **`saves.json` with all 10 options**; `launcher.ps1 -PrintSaves` shows it as `known` with exactly these arguments.

**Scenarios** (tool with "Für Kampagnen", big versions):
- Sturmsee 1: gold 10,000, mission bits 0x121 (town 200/1/100, 2 towns, balance ≥ 0); **cargo of "Morgenstern" in memory (+0x300): `00028016 00018017 0001000E`** = 20 t tools, 12 t wood, 8 t food (the rivals keep 50/50/30 t). Mission text with umlauts in the list.
- Sturmsee 5: bits 0x401, town 1,000/3/400, defeat flag only for player 2; gold 40,000 / 20,000 / 60,000 / 20,000; own ships "Morgenstern", "Vergeltung" (14 cannons), "Falke" (8); rival 2's ship is called "Valcourts Stolz". **The player name from PLAYER4 (+0x3C0, "Haus Valcourt") is not used**: the game shows the colour names ("Gelber Spieler"). The mission text identifies the rival by its flagship, which works.
- Random adventure 4711 (Fordernd), installed by the generator from the installed folder: bits 0x501 (town 800/3/300, balance 300, defeat), 47 islands (37 × 70×60, 10 × 100×90), pirates active, extra warship "Hai".
- **Bug found and fixed – Archipel:** with only lit/mit islands (MaxClass 1, 30×30 and 40×40) the three computer rivals have kind 9 from the first second (their start ships end up with the traders, owner 4); at clock 700 the game ends as lost (all kind 9, lock 1, score screen "Schiffe gesunken 2", mission bonus 0 %). A test copy with MaxClass 2 (twenty 50×52 islands in the big version) keeps all three rivals (kind 12, one ship each). **I: the AI needs an island of class med (50×52) or bigger.** Fix: Archipel and the archipelago maps of the generator now use MaxClass 2; `check-scenarios.ps1` requires at least 4 islands of class med or bigger in every map version (the old file fails this check in both versions). Fixed Archipel in game: rivals kind 12 past clock 1,094, at 4× all three found settlements (clock 8,622: 26/22/8 residents).
- Logbook: live values match (gold, rivals, towns, speed); the scenario name comes from the parameter block (also "Abenteuer 4711"). Test scenario "ZZ Test Sofortsieg" (balance ≥ −1,000,000): game ended at clock 50, mission flag set, **logbook.json got `{"scenario": "ZZ Test Sofortsieg", "result": "won"}`**; the launcher's Adventures tab shows "verloren – nochmals versuchen" for the three lost Archipel runs. Test data removed afterwards (`logbook.json`, `saves.json`, test scenario, test autosave moved to `Savegame-Testlaeufe-20261112`); `lastgame.gam` restored (B7C4BFB9…).
- Not tested in this round: building with the cheaper costs, the bigger radius on screen, "Disasters More", the English scenario files, clicking the launcher buttons (done in the follow-up below).

**Follow-up tests (O), 2026-11-12 20:20–21:20** (user away; the user declined computer-use access to the PowerShell windows, so the launcher was not clicked on screen):
- **Launcher buttons in code:** hidden switch `launcher.ps1 -TestClicks` builds the window off-screen, clicks the buttons through their `OnClick` and records instead of starting (`Start-Process`/`Start-Sleep` replaced by script functions; random adventures go to `-TestOutFolder`). Result: "Gemütlich" + play → patcher with exactly the Relaxed arguments, then `uplay://launch/16236/0`; "Harte Probe" + start original → only the uplay URL, `settings.json` holds the Tough choice; open logbook → `logbook.ps1`; Continue: known savegame → exactly the recorded arguments, autosave of a big world → current options + `-Width 1000 -Height 700`, original savegame → only the uplay URL; roll Fordernd/4711 → "Abenteuer 4711.szs" with the readable goal list; number `12345678` → message instead of a parameter error. Note: the Continue list only reports a selection once its tab has been shown (the test switches to the tab first, as a player does).
- **Building costs (`-BuildCost 0.5 -Radius 2`, savegame `lastgame-1000x700-20261109-185329` with an own warehouse):** the build menu shows the halved costs – Jagdhütte (hunting lodge) 25 gold, 1 t tools, 1 t wood (haeuser.cod: 50/2/2), Feldweg (dirt road) 3 gold (5; rounded up), Webstube (weaving hut) 100 gold, Marktplatz (market) 100 gold, 2 t tools, 5 t wood. One dirt road tile placed: **gold 41,084 → 41,081 within 2 s (−3)**. (The warehouse had no tools/wood, so nothing else could be built.)
- **Radius:** the placement preview of the market shows its catchment circle with radius 32 – it spans most of the island, far beyond the territory of the existing warehouse (built with radius 16).
- **Disasters:** active-disaster table **RVA 0x54E240**, 0x120 entries of 8 bytes (written by `FUN_1400b5120`): [0] island (0xFF = free), [1] x, [2] y, [3] & 0x1F kind (1 plague, 2 fire), [6] parameter, [7] territory bits of the tile. Sampled every 0.7 s (new island/x/y/kind = one new event; F7 pressed again by window message whenever the game dropped to speed 1). Same savegame (rivals with 966/901/1,851 residents), 16-fold, about 2.9 game hours each (clock 441,500 → 536,000):

  | Run | new plague | new fire | max. at once |
  |---|---|---|---|
  | `-Disasters Off` | 0 | 0 | 0 |
  | default | 26 | 8 | 4 |
  | `-Disasters More` | 60 | 29 | 5 |

  (The default run of the evening without the radius option; the radius would widen doctor/bathhouse cover and lower the plague.)
- **English scenario:** "Storm Sea 1 - Shipwreck.szs" (built with `-Language en`) appears in the list of own scenarios; mission text "THE STORM SEA - Chapter 1: Shipwreck … Morning Star …" shown correctly. File removed afterwards.
- `saves.json` recorded all four autosaves of these runs with their arguments (removed afterwards with the test autosaves; `lastgame.gam` restored, B7C4BFB9…).

### Polish after the tests (2026-11-12, late evening)

- **Backup rotation:** every start with changed savegames made a full copy of the Savegame folder (about 20 MB); after four days there were 13 copies with 278 MB, growing without limit. `Limit-Backups` in `anno-patcher.ps1` now keeps the oldest backup (the state before the first use of the tool) and the newest 5 (`Savegame-Backup-*` and the older `Savegame-Sicherung-*`, sorted by their time stamp) and moves the others to the recycle bin (`Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory … SendToRecycleBin`, so they can be restored). Runs only right after a new backup. Unit test with 9 backup folders + `Savegame` + `Savegame-Testlaeufe`: the 3 middle ones moved, the others untouched, a second call moves nothing (O).
- **Tool window:** the launcher no longer starts the tool with `-NoExit`; it passes `-PauseOnError` instead. A script-level `trap` in `anno-patcher.ps1` then shows "Fehler: …" and waits for Enter before the window closes; without the switch every error stops the tool exactly as before (`break`). After a normal game end the window says "Alles erledigt" and closes after 10 s. `-PauseOnError` is not recorded in `saves.json`. Checked (O): with the switch and an error the window was still waiting after 6 s, without it the process had ended; `-CheckOnly -PauseOnError` returns at once with exit code 0.
- **Logbook with the game:** launcher check box "Logbuch mit dem Spiel öffnen" (Open the logbook with the game), stored as `LogbookWithGame` = `1`/`0` in `settings.json`; it starts `logbook.ps1` after the game for "play", "start original" and "continue" (the logbook allows only one window anyway). `-TestClicks` shows the logbook start after the game and the stored value.
- **Launcher layout:** the scenario list of the Adventures tab is taller (330 px) and its status column wider, so that "→ nächstes Kapitel (verloren – nochmals versuchen)" fits.
- **README screenshots:** `docs/images/` with the three launcher tabs (German and English, rendered with `-PreviewImage` from demo savegames and demo progress, no real savegame names) and the logbook (self-test images with fake data).
- Checked again: the logbook already resets its game tracking when the game process ends (`Close-Attachment` clears `Track.SawRunning`), so a new process starts clean; no change needed.

### Long run with all options (O), 2026-11-09 08:52 – about 19:00, evaluated 2026-11-10

- Tool with `-Pirates Strong -ShipSpeed 2 -StartGold 50000 -Storage 3`, 1000 × 700, layout 0 (43 islands). The test session then broke off with a connection error of the Claude app; the tool ended with exit 4 without renaming `lastgame.gam`.
- **The images `30-alle-optionen-langlauf-030min` … `210min` are byte-identical** (same SHA-256). That is a capture error (window in the background, `PrintWindow` returns the old image), not a hang: the game kept writing autosaves, the last one `lastgame.gam` at 18:53:29.
- This last savegame (now `lastgame-1000x700-20261109-185329.gam`): game clock 440,208 (for comparison 38,543 in the options test at 08:22), 43 islands up to x 947 / y 628.
- Growth compared with 08:22 (section sizes in the savegame): `SHIP4` 3,052 → 10,900 bytes, `KONTOR2` 7,028 → 13,052 (7 → 13 warehouses), `PRODLIST2` 1,512 → 7,392, `SIEDLER` 1,152 → 3,168. **No crash in about 10 hours.**
- **Pool `ROHWACHS2`:** 2,032 of 262,512 slots occupied (0.8 %).
- **I** The fixed pools are not expected to fill up at 1000 × 700, even over many hours.
- **Storage:** `KONTOR2` = per warehouse a 4-byte header + 50 goods of 20 bytes each (structure like mdcii-engine `KontorGood`, stock `lager` uint32 in 1/32 t at +12).
  - Stocks above 30 t also occur in normal savegames without the tool (an older savegame of the original game: up to 350 t), because market buildings and warehouse levels raise the town's limit.
  - **I** The storage option therefore cannot be proven from savegames. What remains proven: the limit of a newly built warehouse is 2,880 (90 t) in memory instead of 960 (see "Game test with all options").
- **Clean-up 2026-11-10:**
  - `lastgame.gam` (test, 18:53) renamed to `lastgame-1000x700-20261109-185329.gam`.
  - The state before all tests (2023-04-10, SHA-256 `B7C4BFB9…62FE`) copied back from `Savegame-Sicherung-20261108-191850` and verified by hash.
  - Backup folders: 13 of them, 174 MB in total.

### Long run "Schwer" (O), 2026-11-09 07:45–08:10

- 1000 × 700, layout 0 (43 islands), game in the foreground (the monitoring brings it to the front every minute), fourfold.
- 25 minutes: always responsive, 433–494 MB, autosaves 07:55:58 and 08:05:58. All three AIs settle in the **new** area (yellow bottom left, blue bottom right, white top right). Flags 0x8, no pirate ships yet. Evidence `25-schwer-langlauf-30min*.png`.
- Aborted in favour of the game test of the options; afterwards the long run with options (see "Long run with all options").

### Experiment: `src/anno-patcher.ps1`

Sets the map size in the memory of the running game (default 1000 × 700). It does not change any files.
Version of 2026-11-08: 8 code places and 5 variables (width, height, scroll range, 1/width, 1/height; table above).

Procedure: check the exe (SHA-256, original bytes at all 8 places) → back up the Savegame folder → wait for `Anno1602.exe` → check all 8 places and 5 variables in memory (a variable must be 0, the original or the target value) → write the code places and read each one back; on an error undo the ones already written → wait until the game has set its start values (1/height ≠ 0), then set the 5 variables and read them back.

New compared with the first version:
- Scroll range and 1/width, 1/height are set as well (bug above, section on the camera).
- Start order: the first version set the variables immediately. If it found the game before `FUN_1400dbc60` had run, the game afterwards overwrote 1/width and 1/height again with 1/500 and 1/350 (they come from `.rdata`, not from an immediate). Now the tool waits for the last start assignment.
- Self-test: at 500 × 350 the formulas must give exactly the original bytes, otherwise abort.
- Protection: if the game has already been running for more than 2 minutes with a different width, the tool aborts (in a 500 × 350 map that is already loaded, grid and size would no longer match). Can be overridden with `-GameAlreadyRunning` if the game is certainly in the main menu.
- A different size in the same, already patched game process is refused ("unerwartete Bytes", unexpected bytes); restart the game for that.
- Island spreading (jump + code stub, see "Spreading the islands"), can be switched off with `-NoIslandSpread`.
- Backup without duplicates: the Savegame folder is backed up only if it has changed since the last backup (comparison of path, size and modification time of all files). Tested: the first run made a backup, the second reported "unverändert" (unchanged). The backups are named `Savegame-Backup-<datetime>`; when looking for the latest backup, older `Savegame-Sicherung-<datetime>` folders count as well.
- Protection for "Spiel fortsetzen": the tool stays open until the game ends. If the game wrote `lastgame.gam` during the session, it is renamed to `lastgame-<width>x<height>-<time>.gam` (still visible in the load list). Can be switched off with `-NoLastgameProtection`. Reason: the game overwrites `lastgame.gam` automatically (in the test at 19:43, 20:26, 21:06, 21:26) and when quitting via "Ende" (end).
- Start file `start-big-world.cmd` (removed on 2026-11-13; the launcher replaces it): starts the tool in its own window (stays open) and then the game via `uplay://launch/16236/0`; further arguments such as `-Width 750 -Height 525` are passed through. Pause via `ping` instead of `timeout` (which aborts without console input).
- Tested in game (O): start file used three times, each time the restart was caught and the values set. Protection for "Spiel fortsetzen" triggered twice: `lastgame.gam` (written by the game at 21:45:26 and 21:59:11) renamed after the end of the game to `lastgame-1000x700-20261108-214721.gam` and `…-220145.gam`.
- Restart of the game (added after the game test): the first `Anno1602.exe` process exits again immediately after a start via Ubisoft Connect, and a second one starts. The previous version patched the first one, then failed with "Lesen bei RVA 0x5EBC80 fehlgeschlagen (Fehler 299)" (read at RVA 0x5EBC80 failed (error 299)), and the second one ran unpatched. Now the tool detects the exit (`GetExitCodeProcess`) and waits for the next process.

### Test run 2026-11-08

**Resolution (O):** 3 monitors, all 2560 × 1440 (main monitor `DISPLAY5`, RTX 4090, 143 Hz). Registry `HKCU\Software\Ubisoft\Anno1602HistoryEdition` before: `SCREENMODE` = 2560, `SCREENMODEY` = 1440, `WINDOW_MODE` = 2, `UI_SCALE` = 1000, `MONITOR_INDEX` = 0, `VSYNC` = 1. So the game is already set to WQHD, matching the monitor; in game it ran at 2560 × 1440 in full screen. Nothing changed (after = before).

**Offline test (O):** `tests/test-patcher.ps1` loads the exe copy `analysis/bin/Anno1602.exe` in a helper process only as an image (`LoadLibraryEx` with `DONT_RESOLVE_DLL_REFERENCES`: sections at load address + RVA with the real memory protections, no game code runs, no DLL is loaded) and runs the tool against it. Result with the final version: **93 of 93 checks passed.**

| Case | Expected | Result |
|---|---|---|
| before | all 8 places original, `.rdata` 1/500 and 1/350, variables 0 | ok |
| A: game still starting | the tool patches the code and waits; after a simulated program start all 5 variables are 1000 / 700 / 850 / 1/1000 / 1/700 | ok, exit 0 |
| B: second run, same size | runs through, nothing changes | ok, exit 0 |
| C: 750 × 525 against an already patched process | abort "unerwartete Bytes", nothing changed | ok, exit 1 |
| D: one code place corrupted | abort, the 7 other places and all variables unchanged | ok, exit 1 |
| E: 750 × 525, game already started | code and variables 750 / 525 / 637 / 1/750 / 1/525 | ok, exit 0 |
| F: process ends while the tool waits | the tool detects the end instead of aborting with a read error | ok, exit 1 ("Testprozess hat sich beendet", test process has exited) |

**Game test (O), 19:18–19:52.** Permission for computer use granted on the third attempt (declined twice before). Procedure: tool in the background, game via `uplay://launch/16236/0`, endless game "Durchschnittlich" (occasional pirates), player name preset, flag red. Evidence in `analysis/test/` (captures of the game window only, 2560 × 1440). Camera and world size were additionally read from memory, read-only (camera structure via `PTR_DAT_1400f9a00`).

| Check | Result | Evidence |
|---|---|---|
| Tool takes effect at the real game start | At first **no**: the first process exited after patching, the second ran unpatched (error 299 while waiting). Fixed (see above), after that twice **yes**: "Aktuelle Kartengroesse im Spiel: 1000 x 700" (current map size in game), scroll range 850. Read back from memory after the game start: 1000 / 700 / 850 / 1/1000 / 1/700. | output of the tool |
| New endless game starts, no crash | yes | `01-start-1000x700.png` |
| Minimap shows the bigger world | yes: view frame correspondingly smaller, map reaches to 1000 × 700 | `02-minikarte-start.png` |
| Islands also in the new area | **no**: all 18 islands in the old area (fixed positions of the template, see "Islands in the endless game") | `02-minikarte-start.png` |
| Click in the minimap reaches the new area | yes: camera world (784, 590), scroll t = 687 > 425 | `03-minikarte-klick-neuer-bereich.png` |
| Arrow keys beyond the old limit | yes: s kept rising from 447 (with the old limit the camera would have jumped back to 425) and stopped only at s = 849, camera at the right world edge x = 998 | `04-pfeiltasten-anschlag-rechts.png` |
| Edge scrolling with the mouse | **not checked**: the synthetic mouse movement to the screen edge did not trigger scrolling (not even into the old area). Probably the setting `RIGHT_CLICK_SCROLLING` = 1 or the kind of input; the code for it (`FUN_1400dd190`) uses the same limit as the arrow keys. | – |
| Ship sails into the new area | yes: own ship at world ≈ (446, 586), destination reached | `06-…`, `07-schiff-am-ziel-446-586.png` |
| Minimap marker of the ship | yes: the dot is at the right place in the view frame (scale 1/width, 1/height correct) | `05b-…`, `08b-minikarte-nach-7-minuten.png` |
| Warehouse in the new area | **not possible**: there is no island there | – |
| AI and pirates, about 7 minutes | the AI settled three islands (markers orange, white, blue); a foreign ship sailed in the new area. No crash, the game responded. No pirate attacks seen in this short time. | `08-fremdes-schiff-im-neuen-bereich.png`, `08b-…` |
| Save to a new slot | yes: icon "neuer Spielstand", name `Welt1000x700` → `Welt1000x700.gam` (395,966 bytes). No existing slot overwritten (an existing savegame checked after a misclick: unchanged). | `09-gespeichert-Welt1000x700.png` |
| Quit the game, restart with the tool, load | yes: restart caught again (PID 49004 → 15116), savegame loaded, islands, AI markers and ship (world 468, 580) as saved; the ship accepts new commands. | `10-geladen-nach-neustart.png`, `10b-…`, `11-…` |

**Side effects (O):**
- Backup folders in `Documents\Anno 1602 History Edition` (as of 23:22): `Savegame-Sicherung-20261108-191850` (**untouched state before all tests**), `-193116`, `-194810`, `-201331`, `-211505`, `-213348`, `-214753`, `-220202`, `-220500`, `-221910` (together a good 100 MB). Except for the first one, all can be deleted. New ones are created only if the folder has changed (during the tests that was the case every time, because I copied `lastgame.gam` back).
- Test savegames in the Savegame folder: `Welt1000x700.gam` (big world without island spreading), `game20.gam` (17 islands stretched), `game22.gam` (48 islands), autosaves renamed by the protection `lastgame-1000x700-20261108-214721.gam`, `…-220145.gam`, `…-232148.gam` and `lastgame-2000x1400-20261108-221745.gam` (load only with `-Width 2000 -Height 1400`). Load all of them only with the tool active.
- While playing, the game overwrites `lastgame.gam` ("Spiel fortsetzen"). After every test run I copied back the state from before the test (2023-04-10, 621,498 bytes, hash `B7C4BFB9…`) from the first backup and verified it by hash (last at 23:22).
- High-score list `Highscore\[[48]].hss`: changed once at 19:51 by quitting via "Ende" (entry with 0 points, difficulty "Durchschnittlich"); after that the game was only ended by terminating the process, no further change.
- The first start attempt launched a second game instance directly through "App öffnen" (open app) of computer use; both instances (without a loaded game) were terminated. To start the game, therefore use only `uplay://launch/16236/0`.

**Inferred (I):**
- The tool works in the real game: size, camera limit and minimap scale take effect, saving and loading in the big world work, no crash in a good 10 minutes of play.
- In practice the bigger world did not yet bring anything in the endless game, because the new area remained empty sea. Fixed with the island spreading (section "Spreading the islands").

**Open (?):**
- ~~Islands in the new area~~ done (island spreading). Open: more islands than the 18 of the template (up to 50 slots in the `SZENE` section and in the island table).
- ~~Saving and loading a game with spread islands~~ done (`game20.gam`, 17/17 islands the same).
- Building an own warehouse: fails in the old and in the new area alike, so not a world-size problem; the way to operate it is open.
- Longer game: pools with fixed capacity (e.g. `ROHWACHS2`), pathfinding over long distances, AI expansion, pirate attacks.
- Check edge scrolling with the mouse by hand.
- Undoing after a write error in the middle of patching is programmed but has never been triggered.

## Players and parties

- **O** `FUN_1400a87f0` initialises a table with **7 slots of 640 bytes each** from `0x1405f0960`:
  - Slots 0–3: players (start money 10,000)
  - Slot 4: free trader `Trader%d` (1,000,000)
  - Slot 5: pirates `Pirat%d` (50,000)
  - Slot 6: natives `Native%d` (5,000)
- **O** In addition a second table with **4 entries of 4,236 bytes each** from `0x1405ec720` (only for the 4 players).
- **O** The loops have fixed counts (4 or 7).
- **I** More than 4 players means: enlarge both tables and move the fixed numbers 4/5/6 for traders, pirates and natives. That probably affects many places (colours, diplomacy, statistics, savegame).
- **O** Scenario header: `SZENE_PLAYERMAX` is 1 by default (single player) or 4 (multiplayer) (`FUN_1400d36f0`).

## .cod parser

- **O** `haeuser.cod` is read in `FUN_140090660` (knows `MAXHAUS`, `Maxlager` …), `figuren.cod` in `FUN_140068f10` (knows `MAXFIGUR`).
- **?** What exactly do `MAXHAUS` and `MAXFIGUR` limit (size of the building/figure tables)?

## Open questions

- ~~Where are the AI decisions made?~~ Partly: loop over the parties `FUN_14003dc40` (AI kind 0xC, pirates kind 0xE), fleet/cannons `FUN_14003b7e0` (section "Rivals and pirates").
- ~~Island count limit and island table.~~ 50 slots (section "Islands in the endless game").
- **?** Storage size: "Maxlager" is stored as a 16-bit value × 32 at building table +0x30 (parser `0x140091999`), but is not read directly by address; where the game computes the storage limit of a town is open. Cannot be checked without an own warehouse in game.
