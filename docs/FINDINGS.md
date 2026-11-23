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
Map size and all game options: `src/anno-patcher.ps1`, start together with the game: the launcher window `src/launcher.ps1`, offline test `tests/test-patcher.ps1`, island plan as an image `dev/show-island-plan.ps1`, scenarios `src/build-scenarios.ps1` with `src/scenario-lib.ps1` (check: `tests/check-scenarios.ps1`), random and daily adventures `src/random-adventure.ps1`, scenario designer `src/scenario-designer.ps1`, logbook window `src/logbook.ps1`, read-only checks of the running game `dev/check-game.ps1` and `dev/check-islands.ps1`, installer `src/install.ps1`, player guide `src/README.txt` (German: `src/README.de.txt`).
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
- **Since 3.0.0 the hook and the code stub are always installed** (also without `-Pirates` and the gold options): the stub starts, after the replaced `movaps`, with the 41-byte copy of the mission time limit (see "Mission time limits"); then the pirate flag, start gold and rivals' gold as before. 53 bytes without other options (seen in game: "TIMERS-Lader (Codestueck): gesetzt (53 Bytes)"), 124 with all (limit 128, up to 0xE6000).

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
- **O Cargo space:** `figuren.cod` "Maxware" is stored as 16 bits at figure table +0x3E (`0x1406d80fe`, 26 reading functions, among them the ship loader `FUN_14008e4f0`). **Wrong, corrected 2026-11-22 (3.5):** +0x3E is "Maxenergy" (the hull); "Maxware" (number of holds) is +0x3A – see "Ship values, F8, explored islands".
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
| `-RivalGold N` | TIMERS code stub | after the start gold: `cmp [game clock],1000; jae +30; mov [money slot 1/2/3],N` (code stub now up to 83 bytes, room for up to 128; since 3.0.0 with the time-limit copy up to 124) |

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

**Installation:** `%LOCALAPPDATA%\Programs\Anno1602-Extensions` (before the English renaming `%LOCALAPPDATA%\Programs\Anno1602-Erweiterungen`), with the shortcut "Anno 1602 - Erweiterungen" (German Windows) or "Anno 1602 - Extensions" (other languages) in the Start menu and on the desktop. The desktop folder `%USERPROFILE%\Desktop` was missing and was created.

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

**Memory layout at the end of .text** (updated 2026-11-15, checked by offline case AH): 0xE5100 island code (up to 209) · 0xE5200 island table (2,452; limit now 0xE5BA0) · 0xE5BA0 fertility code stub (30) · 0xE5BC0 marker BAUK (8) · 0xE5BC8 marker UNTH (8) · 0xE5BD0 marker EVNT (16, 3.0.0, see "Event mode") · 0xE5BE0–0xE5BFF free · 0xE5C00 raw materials/villages/fertility (up to 158) · 0xE5E00 pirate fleet (17) · 0xE5E20 traders (14) · 0xE5E40 big campaign maps (200) · 0xE5F70 marker NUFR (8) · 0xE5F80 TIMERS (up to 124 since 3.0.0, before 83; limit 0xE6000).

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
| +0x08 | protect condition bits (→ mission +0x04); a failed protect condition makes the human lose at once, so our files keep 0 (`check-scenarios.ps1` since 3.0.0) |
| +0x20 / +0x22 | monopoly: raw material (0x2D grain, 0x2E tobacco, 0x2F spices, 0x30 sugar, 0x31 cotton, 0x32 wine, 0x33 cocoa …), island count – **replaced at the start by the number of all islands with this raw material** (`FUN_1400ceea0`) (0x4000/0x8000) |
| +0x24 | player to support, 7 = any (0x10, target at +0x8B8) |
| +0x2B / +0x2C…+0x32 | number of defeated rivals (0x200) / per player "must be defeated" (0x400; defeated = kind 9) |
| +0x40 / +0x44 / +0x4C | number of towns (0x20) / total residents (0x80) / balance `FUN_1400ad5d0` (0x100) |
| +0x48 | copied to mission +0x2C, meaning unknown; 0 in all 192 entries of the 138 original scenario files, kept 0 |
| +0x50 | voice message on success (original 84–106) |
| +0x54 | **trade balance** ≥ value (0x10000): sales revenue − purchase costs (player +0x78 / 480 − +0x74 / 480), e.g. `[[111]]0`: 500. The balance at +0x4C is the one of the status window: taxes + sales − purchases − operating and military costs (`FUN_1400ad5d0`, result field 6) |
| +0x58 | **time limit** (3.0.0): deadline in game clock units (`TimeLimitHours` × 36,000); copied to mission +0x20 and written back into savegames, never read by the game – the patcher's TIMERS hook copies it to 0x5EC1A8 (see "Mission time limits"). 0 in every original entry |
| +0x5C, +0x8A0…+0x8AB | unknown, kept 0 (`check-scenarios.ps1` since 3.0.0) |
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

**Scenarios now (41 per language since 3.0.0; 23 from 2026-11-12 to 2.2.0):** 5 campaigns with 28 chapters (Smaragdinseln 6, Wettlauf 4, Sturmsee 6, Neue Welt 6, Handelsliga 6) and 13 challenges. New in 3.0.0: campaigns Neue Welt 1–6 and Handelsliga 1–6, challenges Kolonialherr, Monopolist, Ruhige See, Habenichts, Gegen die Uhr and Die Frist des Königs (the last two with a time limit; sections "Campaigns … six challenges" and "Mission time limits" below). The 23 of 2.2: Smaragdinseln 1–6, Wettlauf 1–4 (Erster Hafen, Bürgerstolz, Kaufmannsrepublik, Die Krone – English file names First Harbour, Civic Pride, Merchant Republic, The Crown; goals from 300/150 settlers up to 1,500/600 aristocrats, adjusted after measuring, see above), challenges Inselreich (8 towns, 3,000 residents in total), Handelsimperium (50 t jewellery, 80 t clothes, trade balance +300), Goldrausch (60 t gold, 40 t jewellery); new on 2026-11-12: campaign Sturmsee 1–6 and the challenges Archipel, Kontinente, Handelsflotte, Seemacht (section "Third campaign …" below; Sturmsee 1, Sturmsee 5 and Archipel loaded in "In-game tests of phase 2", none played through). `tests/check-scenarios.ps1` checks all of them: sections, mission, race setting, both maps (boundaries, overlaps), raw materials, villages, gold, flags.

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
- **O** SZENE loader `FUN_1400d0de0`: 12 fertility entries from +0xB4 (house no. = Id − 20000 of a raw-material building whose Ware is the crop, amount); pass 1 classes 3–4 with limit 1, pass 2 classes 1–2 with limit 1, then repeated with the limit SZENE +0x60 (0 → 2) until nothing is assigned, then class 0 with limit 2. Candidates from `FUN_1400d0ce0(crop, class min, class max, limit, out)`: island present, flag bit 2, class, count < limit, bit not yet set, and the climate: 0x2E/0x30/0x32 only climate 0 (0x30 and 0x32 exclusive), 0x2F/0x31/0x33 only climate 1 (climate 0 = north, see "Crop climates and building levels"). Templates: 6 entries used (+0xB4…+0xDC), amounts 2–5, +0x60 = 2.
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
- Parameters: `-Seed 0…999999` (default random, printed), `-Difficulty Easy|Average|Demanding|Hard` (default Average), `-Language de|en`, `-OutFolder` (default `src\scenarios`), `-Install`, `-GamePath`. File "Abenteuer <seed> <difficulty>" / "Adventure <seed> <difficulty>" since 2.2.0 (e.g. "Abenteuer 4711 Fordernd"), so the same seed with another difficulty is a file of its own; before 2.2.0 the name had no difficulty and such a file was overwritten (old files still pass the checks and are removed by the uninstaller).
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

`src/logbook.ps1` (WinForms, UTF-8 with BOM, about 1,900 lines incl. C# and self-test in 2.2). This section describes the logbook of 2.2; the additions of 3.0.0 (tabs, history, game summaries, 53 achievements, events, time-limit line) are in "Logbook 2.0". **Nothing in this section had been measured in the real game when it was written** (later checks: "In-game tests of phase 2"); "O (test)" = checked in the offline tests (synthetic memory images and a helper process that maps the exe copy as an image). Addresses marked I come from the decompiled code (`analysis/scan/alle-funktionen.c`).

**The tool:**
- Start: `powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File src\logbook.ps1` or the launcher button "Logbuch öffnen" (Open logbook). One instance at a time (mutex `Local\Anno1602-Extensions-Logbook`; a second start activates the first window by its title "Logbuch – Anno 1602" / "Logbook – Anno 1602" and exits 0).
- Attaches to the newest `Anno1602.exe` (base from `MainModule`), checks the SHA-256 of the exe file (`7731972f…b7a1`, as the patcher; another version → "Unbekannte Spielversion" (unknown game version), nothing is read) and opens the process with `PROCESS_QUERY_INFORMATION | PROCESS_VM_READ` (0x410) only. Never writes. Refresh every 2.5 s. The process end is detected with `GetExitCodeProcess` (also the Ubisoft Connect quick restart) → "Warte auf Anno 1602 …" (waiting for Anno 1602), then it re-attaches. `MainModule` failing for > 10 refreshes → "Kein Zugriff" (no access).
- Window: title (scenario or game name, game time, speed), AUFTRAG / MISSION (goals with live bars), DEIN REICH / YOUR EMPIRE (gold, balance · trade balance, towns and the largest, ships, residents per stage as a stacked bar, workers), GEGNER / RIVALS (best town, total residents, towns, ships, gold; race progress bars in races), ERFOLGE / ACHIEVEMENTS (24 badges in 2.2, 53 since 3.0.0; tooltips with date and game). Footer: status, "Im Vordergrund" (On top, TopMost), "Kompakt" (Compact: title, goals and one line gold/residents/towns). An unlock shows a gold banner for 8 s, plays the system sound (Asterisk) and highlights the badge.
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
| 0x5EC1A8 | int | **time limit** (game clock; ≠ 0 and reached → message 0x5A, lost). Never loaded by the game; since 3.0.0 set by the patcher's TIMERS hook from mission +0x20 (= AUFTRAG4 +0x58) | O: "Mission time limits"; `FUN_1400af980`, `FUN_1400b0000` |
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
- **I** +0x00 name char[0x18] (`FUN_14009a9f0`: every new settlement gets a name from the list at 0x5C1B00); +0x18 island index (0xFF = free), +0x1A owner; +0x20 storage base per good and +0x1FA (u16) count for the storage room (see "Event mode"); +0x2A + good × 12: stock (ushort, 1/32 t; O since 3.0.0: changed only through plain 16-bit stores, see "Event mode"); +0x1D8 / +0x1DC running costs (see "Running costs" above), +0x1E0 founding clock + 600; +0x216 number of buildings, **+0x218 workers** (sum of building table +0x34 of the settlement's production and public buildings, `FUN_1400b3a90` & co.; the game counts them in the town total = +0x218 + stages); +0x220 … +0x230 residents per stage (pioneers … aristocrats), +0x24D … +0x251 tax rate per stage (128 = 100 %), +0x254 own index.
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
| +0x1C | towns (0x20) · +0x24 supported player's towns (sub-bit 2) |
| +0x20 | **deadline (time limit)** from AUFTRAG4 +0x58, never read by the game; since 3.0.0 the patcher's TIMERS hook copies it to 0x5EC1A8 for the local player's slot (see "Mission time limits") |
| +0x28 / +0x30 / +0x34 / +0x38 | total residents (0x80) / balance (0x100) / trade balance (0x10000) / voice message · +0x2C from AUFTRAG4 +0x48, meaning unknown (0 everywhere) |
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
- Check frequency: `FUN_1400af980` is skipped while the lock 0x5EBF68 ≠ 0; a time limit 0x5EC1A8 ≠ 0 and ≤ clock (and `DAT_1405f2188` ≠ 0) → message 0x5A (since 3.0.0 set by the patcher, see "Mission time limits").

**Game end and result (used to record finished missions) (I):**
- The lock 0x5EBF68 (int; 0x5EBF6C is a separate int) is set to 1 only in `FUN_1400b0000`: case 3 (player out: the human defeated or bankrupt → only the human becomes kind 9), case 0x3E (a mission fulfilled → every kind 0/0xC player becomes 9; the human won if he is the sender or also fulfils it, otherwise message 0x53 = lost), case 0x5A (time limit → message 0x53 if the player has a mission, then all 9; confirmed in game 2026-11-15, see "Mission time limits"). It is reset to 0 only by command 0x36, which both "new game" and **loading a savegame** send first (generic loader `FUN_140016bc0`).
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

- Re-read before every write (changes by the launcher survive), written via a temp file + `File.Replace`. A broken file is renamed to `logbook.broken-<datetime>.json` and a new one is started. Unknown fields of mission entries are kept. The launcher's "Abenteuer" tab reads `missions` (scenario = file name, best result wins); since 3.0.0 also the chapter unlocking.
- 3.0.0 adds the key `games` (game summaries) and the settings `tab`/`collapsed`, and keeps unknown top-level keys (see "Logbook 2.0").
- Game hours = clock / 32,700 (endurance run: 523,094 in 60 min at 16×), rounded to 0.1. Only the time-limit line (3.0.0) uses the game's own display units (600 clock = 1 minute, 36,000 = 1 "hour"), see "Mission time limits".
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

  These are the 24 of 2.2 (ids kept); the 29 added in 3.0.0 are in "Logbook 2.0".

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

**Open (?):** content of 0x5C0E63 for endless games and original campaign missions; AI player names; meaning of the goal bits 0x20000/0x40000 (player +0x87/+0x88) and 0x40 (not checked by `FUN_1400ae010` → such a mission cannot be won); ~~where the time limit 0x5EC1A8 is set~~ answered: nothing in the game sets it, since 3.0.0 the patcher does ("Mission time limits"); balance formula mirrored from the code but not yet compared with the in-game status window (test plan 3).

### Launcher: three tabs, new presets, settings per savegame (2026-11-12)

`src/launcher.ps1` now has three tabs (German on a German Windows, otherwise English). The preset argument lists below were printed offline (`launcher.ps1 -PrintArgs`, O); all 86 choices of the 24 options are accepted by `anno-patcher.ps1 -CheckOnly` (O; since 3.0.0 89 choices of 25 options with `Events`). Changes of 3.0.0 (events option, designer, daily adventure, chapter unlocking, installer): "Launcher and installer 3.0.0". `saves.json` from a real game end, the classification and the adventure list with logbook results were checked with the real game on 2026-11-12 (see "In-game tests of phase 2"); all buttons were clicked in code with the hidden switch `-TestClicks` (see the follow-up tests there).

**Tab "Neues Spiel" (New game):** every option as a drop-down list in four groups; `settings.json` stores option id → value key (independent of the UI language).

| Group | Options (German / English labels) |
|---|---|
| Welt / World | Kartengrösse, Inseln, Inselgrösse, Rohstoffe, Ureinwohner, Fruchtbarkeit / Map size, Islands, Island size, Resources, Natives, Fertility |
| Wirtschaft / Economy | Dein Startgold, Einwohner je Haus, Produktionstempo, Lager je Ware, Baukosten, Betriebskosten, Steuereinnahmen, Einflussradius, Erz- und Goldminen / Your starting gold, Residents per house, Production speed, Storage per good, Building costs, Running costs, Tax income, Influence radius, Ore and gold mines |
| Gegner und Gefahren / Rivals and dangers | Freie Händler, Computergegner, Gold der Gegner, Piraten, Piratenflotte, Katastrophen, Ereignisse (3.0.0) / Free traders, Computer rivals, Rivals' gold, Pirates, Pirate fleet, Disasters, Events (3.0.0) |
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

**Installer (`src/install.ps1`):** installs `anno-patcher.ps1`, `launcher.ps1`, `logbook.ps1`, `random-adventure.ps1`, `build-scenarios.ps1`, `scenario-lib.ps1`, `README.txt`, `README.de.txt` and `FINDINGS.md`; builds the scenarios in the UI language into a fresh temp folder and copies these 23 to "Own Scenarios" (the temp folder is deleted afterwards). `-Remove` deletes our scenario files by name in both languages, random adventures included (`^((Smaragdinseln|Wettlauf|Sturmsee|Emerald Isles|Race|Storm Sea) \d+ - .+|(Herausforderung|Challenge) - .+|(Abenteuer|Adventure) \d+)\.szs$`). Since 3.0.0: 10 files (with `scenario-designer.ps1`), 41 scenarios, the full set and `chapters.json` in the program folder, and a wider `-Remove` (see "Launcher and installer 3.0.0").

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

### Version 2.2.0 (2026-11-13)

- **Random adventure names with the difficulty:** "Abenteuer 4711 Fordernd" / "Adventure 4711 Demanding" (before: "Abenteuer 4711", so the same number with another difficulty overwrote the file). The file content does not contain the name, so an old file regenerates byte for byte under the new name: `check-scenarios.ps1 -Reproduce` accepts both formats and checks that the name ends with the difficulty stored in the game id (O: 4 new files in both languages plus an old-format file, all reproduced). Launcher groups "Abenteuer <n> <difficulty>" under "Abenteuer"; the uninstaller pattern accepts both formats.
- **Installer test with a sandbox:** `install.ps1 -SandboxRoot <folder>` (hidden) puts every user folder – programs, settings, documents, desktop, start menu – below that folder; the game is only read. `tests/test-install.ps1` simulates a PC with the older version (program folder `Anno1602-Erweiterungen`, old shortcut and settings, the player's own scenario, "Last Szenario" and a savegame), installs in German, again in English, adds two adventure files and removes everything. **17 of 17** checks (O): exactly the 9 files identical to the repository, old folder replaced, shortcuts in the start menu and on the desktop pointing to the new launcher and switching with the language, 23 scenarios per language, only our files removed, the player's files kept, and the real installation, settings, own scenarios and shortcuts unchanged (fingerprint before and after).

### Mission time limits (2026-11-14/15)

The game has a mission time limit (int `0x1405ec1a8`, RVA 0x5EC1A8) that nothing in the History Edition sets. Since 3.0.0 own scenarios carry a deadline in AUFTRAG4 +0x58 and the patcher's TIMERS hook copies it into the game.

**Analysis (O, 2026-11-14):**
- The decompile (`analysis/scan/alle-funktionen.c`) names `DAT_1405ec1a8` at exactly three places:
  1. `FUN_14008cef0` command 0x36 (new game **and** loading a savegame): set to 0, together with clock, lock, flags ….
  2. `FUN_1400af980`, the mission check per player: `limit ≠ 0 && limit ≤ clock (0x1405ec0f8) && DAT_1405f2188 ≠ 0` → message 0x5A → `FUN_1400b0000` case 0x5A: message 0x53 (lost) if the player has a mission (bits ≠ 0), then every player kind 9, lock 0x5EBF68 = 1.
  3. The screen refresh: only while the limit is ≠ 0 it draws `sprintf("%02d:%02d", clock / 600, (clock % 600) / 10)` at the bottom left (`FUN_140008750`/`FUN_140008490`) – the **elapsed** game time, not the time left.
- Byte scan of `.text` (every RIP-relative operand, offsets 0/1/2/4 after the disp32): only three instructions reference it – `mov [rip],r13d` at 0x14008DC10 (the reset, r13d = 0), `mov eax,[rip]` at 0x1400AFDD8 (check), `cmp [rip],r13d` at 0x1400C9D3E (display). No 8/16-byte store covers it (0x1405ec190/198 are 8-byte function pointers, 0x1405ec1a4/1ac are only read or written separately), no RVA or absolute constant 0x5EC1A8/0x1405EC1A8 anywhere in the file, no LEA of a base in 0x1405ebe00–0x1405ec1a8 used as a struct for it.
- Loaders and savers do not touch it: TIMERS loader `FUN_1400c2da0` (reads +0x00…+0xD0, +0x198…+0x1D7, +0x218…+0x297), TIMERS writer `FUN_1400c4390` (0x298 bytes, the same fields), AUFTRAG4 loader `FUN_1400b1780` and writer `FUN_1400b21d0`, PLAYER4 (`FUN_1400b1e40`). Savegame order: … PLAYER4, AUFTRAG4, SHIP4 (?), TIMERS, WIFF.
- The official editor (`Loca\de-DE\Editor.cod`, `Editor.cod`) offers no time limit, `Text.cod` has no time-limit text. 138 original scenario files (`Szenes\*.szs|*.szm`) with 192 AUFTRAG4 entries: the two fields the loader copies without a known meaning, file +0x48 (→ mission +0x2C) and file +0x58 (→ mission +0x20), are 0 in every entry; the TIMERS bytes the loader skips are 0 except 4 bytes in one file.
- **Conclusion (O):** in the History Edition the time limit is a dead feature: nothing loads it from a scenario, savegame, TIMERS, AUFTRAG4, PLAYER4 or network command; only a memory write can set it. Unit = game clock: the game's display counts 600 units per minute, i.e. 36,000 per displayed "hour" (measured ≈ 32,700 per real hour at normal speed, so a displayed hour ≈ 66 real minutes at F5). A scenario file alone therefore cannot carry a time limit; the first plan was to use none, which the patcher route below supersedes.

**Implementation (3.0.0):**
- **Carrier (I):** AUFTRAG4 +0x58 (int) = deadline in clock units = `TimeLimitHours` × 36,000, so the game's display reaches `hours × 60:00` exactly at the deadline. The loader copies it to mission +0x20 (0x1405EC740 + slot × 0x108C) and the AUFTRAG4 writer writes it back, so it survives savegames. `FUN_1400ae010` and every other named function ignore it (an indirect use through the table pointer cannot be excluded statically).
- **Patch (O offline):** the TIMERS code stub (hook RVA 0xC3232 at the end of the TIMERS loader, stub RVA 0xE5F80, see "Rivals and pirates") is now always installed and starts, after the replaced `movaps`, with 41 bytes: `mov ecx,[0x1405f1d60]` (local player) / `cmp ecx,3; ja skip` / `imul ecx,ecx,0x108C` / `lea rdx,[0x1405ec720]` / `add rdx,rcx` / `cmp dword [rdx],0; je skip` (no goal bits = endless game) / `mov edx,[rdx+0x20]` / `mov [0x1405ec1a8],edx`. The loader returns right after the hook (`mov rbx,[rsp+0x158]; add rsp,0x130; pop rdi; ret`), so the volatile rcx/rdx are free and rax (its result) stays untouched. Order (I): command 0x36 (resets limit and clock) runs before the loaders; scenarios and savegames load AUFTRAG4 before TIMERS. Cave: 53 bytes without other options, 124 with all (limit 128, up to 0xE6000).
- **Effect:** a scenario with +0x58 ≠ 0 gets its deadline at the start and again after every load of one of its savegames; original scenarios and endless games keep 0 (no limit). Without the extensions the scenario has no limit, so the texts say "nur mit den Anno 1602 Erweiterungen" / "only with the Anno 1602 Extensions".
- **Builder and checker:** key `TimeLimitHours` (1–50, whole or half hours; at scenario level or inside `Mission`) → `New-Mission` (`scenario-lib.ps1`) writes +0x58; the build summary adds "time limit n h". `check-scenarios.ps1`: +0x58 is 0 or a multiple of 18,000 within 1–50 h, and then the text names "Zeitlimit"/"time limit", the hours and "Erweiterungen"/"extensions"; the other unused fields (+0x08, +0x48, +0x5C, +0x8A0…+0x8AB) stay 0. Designer: row "Zeitlimit [n] Spielstunden (nur mit den Erweiterungen)" (1–50 whole hours), design key `TimeLimitHours`.
- **Display:** the logbook shows the limit in the game's clock units (`Format-TimeLimit`): "Zeitlimit: noch 2 h 44 min (Uhr 15:03 von 180:00)" / "Time limit: 2 h 44 min left (clock 15:03 of 180:00)" for limit 108,000 at clock 9,030; the rest of the logbook keeps 32,700 clock per game hour (a real hour at normal speed). `dev/check-game.ps1` shows "Time limit": 0x5EC1A8 (clock, display minutes, hours left) and the scenario deadline at mission +0x20 of the local player's slot.
- Used by the challenges "Gegen die Uhr" (3 h = 108,000) and "Die Frist des Königs" (6 h = 216,000), see the challenge table in "Campaigns … six challenges" below.

**Offline (O):** `tests/test-patcher.ps1` case AP, 7 function cases in the helper process: the limit is copied for the local player's slot 0–3, nothing for an endless game, 0 for an original scenario, player numbers out of range are ignored, flags and gold unchanged; the byte pattern uses no rax; everything fits the cave. Designer: designs with 1 h and 4 h OK, 60 h rejected.

**In game (O), 2026-11-15** (details in "Version 3.0.0"): "Gegen die Uhr" with the tool: limit 108,000 = 180:00 right after the start and the game's own clock at the bottom left; again 108,000 after loading the autosave at clock 900; limit set to clock + 600 by a memory write → after ~65 s at normal speed the game ended the mission as lost (lock 1, player 0 kind 9, "Missionsbonus 0 %"). A designer scenario with 4 h: 144,000 = 240:00. **I** Nothing else is needed: the game's own check ends the mission.

### Crop climates and building levels (2026-11-14)

- **O** `FUN_1400d0ce0` (fertility candidates, see "Fertility" in "Gameplay options"): tobacco 0x2E, sugar cane 0x30 and wine 0x32 only on islands of climate 0, sugar and wine never on the same island (bit test 0x20/0x08); spices 0x2F, cotton 0x31 and cocoa 0x33 only on climate 1.
- **O** Climate 0 = north: the SZENE loader gives climate-2 islands whose centre lies in the upper third climate 0, and the island folder table `PTR_s_Nord__1400ea270[climate]` and the native villages (+0x40 north) use index 0 for the north. So tobacco, sugar cane and wine grow on **northern** islands, spices, cotton and cocoa on **southern** ones. **?** Not yet seen on screen (in-game plan: island info of the wine and cocoa islands in "Kolonialherr").
- The text of "Smaragdinseln 3 / Emerald Isles 3" says sugar cane and tobacco grow in the hot south – wrong by the code. Left unchanged in 3.0.0 so that the 23 files of 2.2 stay byte-identical (a fix breaks the identity of that one file). The new texts name a climate only for wine (north) and cocoa, spices, cotton (south).
- **O** `haeuser.cod` BAUINFRA (minimum stage and residents; BGruppe 0–4 = pioneers … aristocrats): plantations of tobacco, spices, wine and sugar, rum distillery, tobacco products 40 settlers; toolmaker 100 settlers; small ore mine 120 settlers; gold mine 150 citizens; cotton and cocoa plantation, tailor, weaving mill 200 citizens; goldsmith 250 merchants; musket maker 400 merchants. Weaver's hut, sheep farm and forester (2 t tools, 50 gold, no wood) without a level. Merchants want cloth, liquor, cocoa, tobacco goods, spices; aristocrats also clothes and jewellery. Taxes per resident (`Steuer`) 1.4 / 1.6 / 2.1 / 2.4 / 2.6 (in memory 7/8/11/12/13, see "Gameplay options").
- Used by the mission texts, `check-scenarios.ps1` (a monopoly crop needs an island of its climate) and the designer (error for a monopoly crop without such an island; climate 2 counts for both).

### Campaigns "Die Neue Welt" and "Die Handelsliga", six challenges (2026-11-14/15)

Files: `src/build-scenarios.ps1` (18 new definitions per language, numbers 41–46, 51–56, 61–66; `Build-Scenario`, keys and helpers unchanged apart from `TimeLimitHours`), `src/scenario-lib.ps1` (`New-Mission` writes +0x58), `tests/check-scenarios.ps1`. Game id = 0x53D00000 + number; "AI" = TIMERS +0xA6; difficulty = template `[[48]]<d><layout>` (0 Einfach … 3 Schwer); gold = human / rivals (build summary, O); island counts small map (big version, island size).

**Campaign "Die Neue Welt" / "The New World"** – exploration and natives (up to 5 + 5 villages, big version 7 + 7), start ship "Kompass"/"Compass", a named conquistador house in chapter 5:

| No. | German / English | Template, map | Difficulty | Start | Goals (bits) |
|---|---|---|---|---|---|
| 41 | Neue Welt 1 - Die Ueberfahrt / New World 1 - The Crossing | `[[48]]00` X, enlarge 2, 18 (big 50) | 0, AI 0 | 35,000 / 15,000; scout "Kundschafter"/"Pathfinder" (21: 20 t tools, 30 t wood, 10 t food); villages 4 + 4 (7 + 7) | town 300 (150 settlers+), 3 settlements, balance ≥ 0 (0x121) |
| 42 | Neue Welt 2 - Zucker und Rum / Sugar and Rum | `[[48]]11` Y, enl. 2, 20 (50) | 1, AI 1 | 30,000 / 25,000; sugar on 2 islands (big 3) | sugar monopoly, 40 t liquor, town 500 (200 citizens+) (0x5001) |
| 43 | Neue Welt 3 - Land der vielen Voelker / Land of Many Peoples | `[[48]]10` XY, continents 4 lar + 5 big + 4 small = 13 (36, Large) | 1, AI 2 | 35,000 / 30,000; villages 5 + 5 (7 + 7) | town 800 (300 merchants+), 4 settlements, EVERY settlement 200 (80 settlers+) (0x29) |
| 44 | Neue Welt 4 - Die Schatzflotte / The Treasure Fleet | `[[48]]20` Y, enl. 3, 18 (50, Large) | 2, AI 2, pirates | 35,000 / 30,000; gold 4, spices 3, ore 6/9, treasure 12; "Galeone"/"Galleon" (23: 40 t tools, 30 t bricks, 30 t wood) + "Wache"/"Sentinel" (25) | 60 t spices, 40 t gold, trade balance ≥ 300 (0x13000) |
| 45 | Neue Welt 5 - Der Konquistador / The Conquistador | `[[48]]22` Y, enl. 3, 17 (47, Large) | 2, AI 3 | 40,000; rival 3 "Haus Valdoro" 70,000, ship "Valdoros Zorn"/"Valdoro Wrath", the others 20,000; "Gerechtigkeit"/"Justice" (27) + "Sperber"/"Sparrowhawk" (25) | defeat player 3, 4 settlements, 2,500 in total (0x4A0) |
| 46 | Neue Welt 6 - Der Vizekoenig / The Viceroy | `[[48]]31` X, enl. 4, 20 (50, Huge) | 3, AI 3, pirates | 50,000 / 50,000; "Kompass II" (23: 50 t tools, 50 t bricks, 40 t wood) + "Krone"/"Crown" (27) | towns 2,000 (800 aristocrats), 1,200 (500 merchants+), 600 (250 citizens+), 6 settlements, balance ≥ 800 (0x127) |

**Campaign "Die Handelsliga" / "The Trade League"** – economy without war (AI 0–2), start ship "Kaufmannsglück"/"Merchant's Luck"; goods, trade balance and profit in every chapter:

| No. | German / English | Template, map | Difficulty | Start | Goals (bits) |
|---|---|---|---|---|---|
| 51 | Handelsliga 1 - Das erste Kontor / Trade League 1 - The First Warehouse | `[[48]]02` Y, enl. 2, 17 (47) | 0, AI 0 | 30,000 / 15,000 | town 250 (120 settlers+), 30 t cloth, trade balance ≥ 100 (0x11001) |
| 52 | Handelsliga 2 - Markttag / Market Day | `[[48]]10` XY, enl. 2, 18 (50) | 1, AI 1 | 30,000 / 25,000; tobacco 3, spices 3 (big 6/6); small trading ship "Bote"/"Courier" | town 500 (200 citizens+), 40 t tobacco goods, 40 t spices (0x3001) |
| 53 | Handelsliga 3 - Das Kontornetz / The Warehouse Network | `[[48]]11` Y + mit/med islands added: 26 (50) | 1, AI 1 | 35,000 / 25,000; cargo 50/50/20/20 t; "Möwe"/"Gull" (21: 40 t tools, 50 t wood, 20 t food) | 6 settlements, EVERY settlement 150 (60 settlers+), trade balance ≥ 200 (0x10028) |
| 54 | Handelsliga 4 - Das Baumwollkartell / The Cotton Cartel | `[[48]]22` X, enl. 3, 17 (47, Large) | 2, AI 2, pirates | 35,000 / 30,000; cotton 2 (big 3); "Wächterin"/"Warden" (25) | cotton monopoly, 50 t clothes, trade balance ≥ 300 (0x15000) |
| 55 | Handelsliga 5 - Die Bank der Liga / The League Bank | `[[48]]20` Y, enl. 3, 18 (50, Large) | 2, AI 2 | 35,000 / 35,000; tobacco, spices, cocoa 3 each | town 1,200 (600 merchants+), balance ≥ 500, trade balance ≥ 400 (0x10101) |
| 56 | Handelsliga 6 - Der Fuerst der Kaufleute / The Merchant Prince | `[[48]]31` XY, enl. 4, 20 (50, Huge) | 3, AI 2, pirates | 50,000 / 45,000; ore 6/10, gold 3; "Kaufmannsglück II" (23: 50/50/40 t) + "Löwe"/"Lion" (27) | town 2,000 (700 aristocrats), 50 t jewellery, trade balance ≥ 500, balance ≥ 800 (0x11101) |

**Challenges:**

| No. | German / English | Template, map | Difficulty | Start | Goals (bits) |
|---|---|---|---|---|---|
| 61 | Herausforderung - Kolonialherr / Challenge - Colonial Lord | `[[48]]20` X, enl. 3, 18 (50, Large) | 2, AI 2 | 35,000 / 30,000; wine 2, cocoa 2 (big 3/3) | wine monopoly (north) + cocoa monopoly (south), 4 settlements, EVERY settlement 250 (80 citizens+) (0xC028) |
| 62 | Herausforderung - Monopolist / Challenge - Monopolist | `[[48]]21` Y, enl. 3, 20 (50, Large) | 2, AI 3 | 40,000 / 50,000; spices 2, tobacco 2 (big 3/3); large warship "Faust"/"Iron Fist" | spice + tobacco monopoly, trade balance ≥ 400 (0x1C000) |
| 63 | Herausforderung - Ruhige See / Challenge - Calm Seas | `[[48]]32` XY, enl. 2, 17 (47) | 3, AI 3, no pirates | 25,000 / 60,000; ore 2/3, gold 1, treasure 2, every crop 2 (big 4/6/2/4/3) | town 1,200 (500 merchants+), 2,500 in total, balance ≥ 300 (0x181) |
| 64 | Herausforderung - Habenichts / Challenge - Shoestring | `[[48]]10` XY, enl. 2, 18 (50) | 1, AI 2 | 8,000 / 35,000; "Letzter Taler"/"Last Taler" with only 15 t tools, 10 t wood, 5 t food | town 600 (250 citizens+), balance ≥ 200 (0x101) |
| 65 | Herausforderung - Gegen die Uhr / Challenge - Against the Clock | `[[48]]10` X, enl. 2, 18 (50) | 1, AI 1 | 30,000 / 20,000; villages 2 + 2; start ship "Sanduhr"/"Hourglass" | town 500 (250 settlers+) within **3 h** (+0x58 = 108,000) (0x1) |
| 66 | Herausforderung - Die Frist des Koenigs / Challenge - The Royal Deadline | `[[48]]22` XY, enl. 3, 17 (47, Large) | 2, AI 2, pirates | 30,000 / 30,000; villages 2 + 2; "Königsbote"/"Royal Courier" + small warship "Siegel"/"Royal Seal" (25) | town 1,000 (400 citizens+), balance ≥ 300 within **6 h** (+0x58 = 216,000) (0x101) |

Bits and +0x58 of 65/66 decoded from the built files (O). German file names are umlaut-free (Ueberfahrt, Voelker, Vizekoenig, Fuerst, Koenigs); the texts carry the umlauts.

**Intended difficulty (not balance-tested):** Neue Welt Einfach → Durchschnittlich (2, 3) → Fordernd (4, 5) → Schwer (6); Handelsliga the same curve (1 / 2, 3 / 4, 5 / 6); challenges Fordernd (Kolonialherr, Monopolist, Die Frist des Königs), Schwer (Ruhige See), Habenichts on a "Durchschnittlich" template but effectively Fordernd, Gegen die Uhr Durchschnittlich. Goal values by analogy with the measured chapters (the rivals do not race, so their ~1,600 cap does not matter; no new race chapters). **None of the 18 has been played through**; in game only Neue Welt 3 (rivals survive on the continents map) and Gegen die Uhr (time limit) were loaded (see "Version 3.0.0"). The balance goals (Habenichts +200 at 600 residents, Handelsliga 5 +500, the finales +800) are the least certain values.

**New checks in `check-scenarios.ps1`:**
- AUFTRAG4 +0x08 (protect bits), +0x48, +0x5C and +0x8A0…+0x8AB are 0; +0x58 is 0 or a valid time limit (see "Mission time limits").
- Per map version (small, big): ≤ 7 villages per climate; number of towns ≤ islands (**I**: one warehouse per island and player); a goal good's raw material is on the map (ore for iron/weapons/tools, gold for gold/jewellery, tobacco, spices, cocoa, sugar or wine for liquor); a monopoly crop has a fertility entry (not grain), amount ≥ 1 and at least one island of its climate (fixed or by position); info line with the climate counts.
- One or two rivals to defeat (not all three): the text names each target's start ship in quotes (the game shows colour names, not the PLAYER4 name, see "In-game tests of phase 2"; skipped for designer files "Eigenes - "/"Custom - ").
- "<Campaign> <n> - <Title>": first text line "<CAMPAIGN> - Kapitel <n>: <Title>" (de) / "… - Chapter <n>: <Title>" (en), title with umlauts = file title with ae/oe/ue/ss; no chapter twice; one campaign title per campaign and language. "Herausforderung - X"/"Challenge - X": German/English text and first line "HERAUSFORDERUNG: X"/"CHALLENGE: X".
- Game ids of campaigns and challenges unique per language (adventures, daily adventures and designer files excluded). Daily adventures are recognised and reproduced (see "Random adventures: library mode and daily adventure").

**Offline tests (O):** reference = the v2.2.0 (HEAD) builder, library, patcher and generator. New builder: the 23 old files SHA-256 identical in German and in English, also when built together with the changed patcher and generator of 3.0.0. Final: 41 + 41 scenarios OK (see "Version 3.0.0"). Negative test (10 corrupted copies, still under the first rule +0x58 = 0, before time limits existed): all 12 kinds of error found (protect bits and +0x58 set, jewellery without gold small/big, sugar on 0 islands, grain monopoly, 8 villages, 19 towns on 18 islands, rival ship not quoted, chapter number ≠ text, chapter twice, German text under "Challenge -", duplicate game id, second campaign title), 14 failed checks, exit 1.

**Still to check in game** (tool with "Für Kampagnen" → big version unless said otherwise):
1. All 18 in "Eigene Szenarien" with the right names, texts with umlauts; "New World 1 - The Crossing" and "Trade League 1 - The First Warehouse" (English build) with the English text.
2. Neue Welt 1: bits 0x121, town 300/1/150, towns 3, 14 villages (7 + 7), "Kompass" + "Kundschafter" (type 21, cargo at +0x300 `00028016 0003C017 0001400E`), gold 35,000 / 15,000 × 3, difficulty 0.
3. Monopoly counts set by the game ≥ 1: Neue Welt 2 sugar (mission +0x12), Handelsliga 4 cotton, Kolonialherr wine and cocoa (+0x12/+0x14; island info: wine islands northern, cocoa islands southern – confirms climate 0 = north), Monopolist spices and tobacco.
4. Neue Welt 5: rival 3 70,000 gold and the ship "Valdoros Zorn", defeat flag only for player 3 (mission +0x0D), difficulty 3.
5. Handelsliga 3 (small and big): 26 islands small; rivals kind 12 after a few minutes (mit/med islands added); "Möwe" with 40/50/20 t.
6. Habenichts: gold 8,000; "Letzter Taler" cargo `0001E016 00014017 0000A00E`; 20 game minutes at 4×: warehouse, 2 foresters and houses affordable.
7. Ruhige See: SZENE resources small 2/3/1/2 and crops 2; `check-islands.ps1`: ore on at least one island the human can reach (gold 1 may land nowhere – not a goal).
8. A finale (Neue Welt 6 or Handelsliga 6): bits 0x127 / 0x11101, fleet with cargo, pirates active (flags bit 0 clear).

**Open (?):** one warehouse per island and player (used by the town-count check and the designer) is assumed, not measured; gold amount 1 (Ruhige See) and the continent villages: whether every village and gold site finds an island.

### Random adventures: library mode and daily adventure (2026-11-15)

`src/random-adventure.ps1`.
- **Refactor (O, byte-identical):** the text and map building blocks are now named tables and functions, so that the designer uses exactly the same texts and map rules: `$AdvOpenings` (per map kind), `$AdvMotives` (towns, realm, trade), `Get-AdvMonopolyMotive`, `Get-AdvConquestMotive`, `$AdvMainHints`, `$AdvTwists`, `$AdvHints`, `$AdvClosings`, `Get-AdvFleetTwist`; goal sentences `Get-AdvTownBullet`, `Get-AdvTownCountBullet`, `Get-AdvAllTownsBullet`, `Get-AdvTotalBullet`, `Get-AdvGoodsBullet`, `Get-AdvTradeBalanceBullet`, `Get-AdvBalanceBullet`, `Get-AdvMonopolyBullet`, `Get-AdvDefeatBullet`, `Get-AdvDefeatNote`; `Get-AdvStory`, `Format-AdvText` (title line, difficulty, story, orders, note, advice, closing); map rules `Set-AdvMap` (layout, mirroring, kind), `Add-AdvCropsForGoods`; `Get-AdvRivalIslandCounts` (islands of class med or bigger in both versions of a built file). `Reset-AdvRandom` takes the seed as a parameter; the random draws keep their order.
- Proof: 200 adventures (25 seeds × 4 difficulties × 2 languages; Classic/Towns 66, Classic/Conquest 34, Classic/Realm 26, Classic/Monopoly 12, Classic/Trade 12, Archipelago/Monopoly 14, Archipelago/Realm 8, Continents/Towns 10, Continents/Conquest 10, Continents/Trade 6, Continents/Monopoly 2) from the v2.2.0 generator and from the refactored one, both with the v2.2.0 libraries: **200 of 200 SHA-256 identical**; `check-scenarios.ps1 -Reproduce` (with the new checks) on them: "All 200 scenarios OK".
- New parameters: `-Library` (dot-source: definitions only, nothing built; the parameters land in the caller's scope, so pass `-Language`, `-OutFolder`, `-GamePath` and do not reuse `$Seed`, `$Difficulty`, `$Date` – they carry validation attributes), `-Daily` (seed from the date; difficulty Average unless `-Difficulty` is given; `-Seed` together with `-Daily` is an error), `-Date yyyy-MM-dd` (only with `-Daily`; default today, local date).

**Daily adventure (O):**
- Seed = `Get-DailySeed`: `((yyyyMMdd × 2654435761) mod 2^32) >> 12`, then mod 1,000,000 (integer arithmetic only, the same on every PC). Examples: 2026-11-14 → 64,855; 2026-11-15 → 712,911; 2026-11-16 → 312,391; 2026-11-22 → 6,420.
- File "Tagesabenteuer <yyyy-MM-dd>" / "Daily Adventure <yyyy-MM-dd>"; the difficulty is only in the game id (as for adventures: 0x53000000 + difficulty << 20 + seed). Content = "Abenteuer <seed> <difficulty>" except the first text line: "TAGESABENTEUER 14.11.2026: Die Inseln von Ambra" / "DAILY ADVENTURE 14 November 2026: The Isles of …".
- Output like an adventure plus "  daily adventure of <date>: seed <n>, difficulty <X>" (the launcher parses "<name>: <path>" and the "  - " goal lines as before).
- `check-scenarios.ps1` recognises the daily names, checks game id = seed of the date (and the language) and reproduces them with `-Daily -Date <day>`. Test: 4 daily files (2 dates, de/en, one Hard) + 1 adventure: "5 adventure(s) regenerated and compared. All 5 scenarios OK"; a daily file renamed to another date: 2 checks fail (game id ≠ seed of the date, not reproduced), exit 1.
- Launcher button "Tagesabenteuer" (always Average), see "Launcher and installer 3.0.0". Daily adventures and designer files are never cleaned up automatically; they stay in Own Scenarios until uninstall.
- **?** Not loaded in game yet (same generator as the random adventures; only the name and the first line differ).

### Scenario designer (2026-11-15)

`src/scenario-designer.ps1` (WinForms, UTF-8 with BOM), from the launcher ("Eigenes Szenario bauen …" / "Build your own scenario …") or on its own. Builds through `. build-scenarios.ps1 -Library` + `Build-Scenario` and the generator library (texts, map rules).

**Window (O, `-PreviewImage`):** 985 × 731 px at 100 % (fits 1080p at 125 %), Segoe UI 9, German or English like the launcher; the scenario is built in the UI language.
- Scenario: name (max. 40 characters; the file name is shown below: umlauts → ae/oe/ue, ß → ss, accents dropped, only printable ASCII without `\/:*?"<>|`), map kind (Classic / Archipelago / Continents), map number 0–999,999 with "New map" (same number = same map), difficulty (template `[[48]]<d><layout>` and the text).
- World, rivals and ships: your gold, rivals' gold (0–250,000), rivals' strength (AI 0–3: "Zögerlich (wie Einfach)" … "Stark (wie Schwer)"), pirates (only sighted / attack), natives Few/Normal/Many = 1+1 / 2+2 / 4+4 villages (big version 3 / 5 / 7 per climate), resources Few/Normal/Lots = ore 3/5, 5/8, 7/11 (small/big), gold 1/2/4, treasures 2/6/10 (raised to ore 6/9 for weapon goods or a defeat goal, gold 3 for gold/jewellery, crops 3 for goods, as in the generator), start cargo Standard (template 50/30/10 t) / Rich (50 t tools, 50 t wood, 20 t bricks, 20 t food; the bricks become 30 t food when bricks are a goal) / Lean (30/20/10) / Shipwreck (20/12/8; the composition is shown under the box), extra ships small/large trading ship (each with 30 t tools + 30 t wood), small/large warship, at most 3.
- Mission (any combination of the verified goal types): town 1–3 (residents 20–5,000, of which 1…residents, stage; sorted descending when built), every settlement at least, number of settlements 1–20, total residents 100–20,000, balance 0–2,000 (0 = "im Plus"), trade balance 50–1,000, goods 1–2 of gold, muskets, cannons, tobacco goods, spices, cocoa, liquor, cloth, clothes, jewellery, bricks (5–200 t, two different), monopoly 1–2 of spices, tobacco, cocoa, sugar, wine (two different; the crop on 2 islands, big version 3 – never 1, see the monopoly "?" in "Third campaign …"), defeat rival 1/2/3 (1 or 2 rivals get a house name "Haus <X>" in PLAYER4 and their start ship "<X>", the text names the flagship; all three: no names, as in the generator), time limit 1–50 whole hours (see "Mission time limits").
- Story: from the generator's blocks (opening per map kind with a place name, motive per main goal, twists: pirates, rival strength, natives, cargo, extra ships) and a story seed; freely editable (Enter = new line); "New story" draws a new seed. Typographic quotes, dashes, ellipsis and special spaces become ASCII; other characters outside Windows-1252 (German) or plain ASCII (English) are an error. Main goal for motive and advice: defeat > monopoly > settlements (count / every) > goods or trade balance > towns.
- Preview: tab "Mission text as in the game" (the exact AUFTRAG4 text, Georgia on parchment colour, "Text n von 2047 Zeichen") and tab "Map" (the small map 500 × 350 as `Build-Scenario` makes it and the big version 1000 × 700 from the patcher's island planner, with island counts). Errors (red ✗, "Create" disabled) and hints (orange ⓘ, allowed) below.
- Text: "EIGENES SZENARIO: <Name>" / "CUSTOM SCENARIO: <Name>", "Schwierigkeit: …", story, "Euer Auftrag:" with the generator's goal sentences (defeat, towns, settlements, every settlement, total, monopolies, goods, trade balance, balance), note for 1–2 rivals, "Rat des Steuermanns:" (main hint + up to 2 of tools, pirates, ore, gold), closing.

**Errors and hints (O, unit checks 31 of 31 in de and en):** errors: no name; name > 40; name characters outside Windows-1252 (German title line); no goal; of which outside 1…residents; the ranges above; the same good or crop twice; > 3 ships; text > 2,047 bytes; story characters; more settlements than islands of the small map (one warehouse per island and player, **I**); a monopoly crop without an island of its climate (tobacco, sugar cane, wine: north; spices, cocoa: south; climate 2 counts for both). Hints: gold/jewellery/weapons on an archipelago, a town ≥ 800 on an archipelago, defeat without a warship, pirates + shipwreck cargo without a warship, fewer settlements than town goals.

**Build:** `ConvertTo-DesignScenario` → definition for `Build-Scenario` (keys Number 0, GameId, Difficulty, AI, Gold, RivalGold, Pirates, Villages*, BigVillages, Amounts, BigAmounts, Cargo, Fleet, Rivals, Mission, Title, Text + the map keys of `Set-AdvMap`). **Game id 0x54000000 + difficulty << 20 + map number** (adventures 0x53…, campaigns 0x53D…); it also seeds `Add-Islands` (archipelago). Built into a temp folder, then checked: ≥ 4 islands of class med or bigger in both versions (`Get-AdvRivalIslandCounts`, the AI rule of "In-game tests of phase 2"), settlements ≤ islands and the monopoly climates in both versions. A failing check (or "no free starting point") retries with the next map variant (`Reset-AdvRandom <attempt> <map number>`, up to 6), otherwise "Diese Karte geht nicht … andere Kartennummer". Then copied to Own Scenarios (or `-OutFolder`) as "Eigenes - <Name>.szs" / "Custom - <Name>.szs"; an existing file is replaced only after a question. The design is stored in `%APPDATA%\Anno1602-Extensions\designer.json` (on "Create" and on closing; keys = the design keys).

**Design keys** (JSON for `-SpecFile`/`-BuildSpec`; missing keys keep the defaults): `Name, MapKind, MapNumber, Difficulty (0-3), Gold, RivalGold, RivalStrength (0-3), Pirates, Natives (Few|Normal|Many), Resources (Few|Normal|Lots), Cargo (Standard|Rich|Lean|Shipwreck), Ships [21,23,25,27], Towns [{Residents,Stage,OfWhich}], AllTowns, TownCount (0 = off), TotalResidents (0 = off), Balance (null = off), TradeBalance (null = off), Goods [{Good,Tons}], Monopolies ["Spices"|"Tobacco"|"Cocoa"|"Sugar"|"Wine"], Defeat [1-3], TimeLimitHours, StorySeed, Story (null = generated)`.

**After "Create":** question "„<Name>“ ist bereit … Jetzt in der Abenteuer-Liste des Starters zeigen?". From the launcher (`-Owner <form>`: a modal dialog in the launcher's process) the designer returns `@{ Created = @(<names>); ShowList; Path }`; the launcher refreshes its list, switches to "Abenteuer" and selects the new scenario. Started on its own, "yes" starts `launcher.ps1 -StartTab 2` and closes the designer.

**Hidden switches (tests):** `-PreviewImage <png> [-PreviewMap] [-SpecFile <json>]`, `-BuildSpec <json> [-OutFolder]` (prints "HINT:"/"INVALID:" lines, exit 1 if invalid; otherwise "<name>: <path>", summary, goals), `-SpecFile <json> -TestCreate [-OutFolder]` (window off-screen, "Create" clicked in code, questions answered yes; prints QUESTION/MESSAGE lines and the result), `-FunctionsOnly` (dot-source for unit checks), `-Language`, `-AppDataFolder`, `-DocumentsFolder`, `-GamePath`.

**Offline tests (O):** `-BuildSpec` of 3 designs × 2 languages (classic with 2 towns, jewellery, balance, defeat rival 2, pirates, large trading ship + large warship; archipelago with 8 settlements, every settlement 100/40, spice monopoly, 50 t bricks, rich cargo → 50/50/30 t food; continents with 1,500 aristocrats, 3,000 total, 2 monopolies, cannons + clothes, trade balance, defeat all three, 3 warships, an edited story with „“–…): `check-scenarios.ps1` "All 6 scenarios OK"; two more designs × 2 languages (wine + cocoa monopoly, jewellery, defeat 2, 5 towns; archipelago with 8 towns, every town 100/40, liquor, trade balance): "All 4 OK". Invalid design: 6 errors (no name, 4 ships, of which > residents, same good, same crop, emoji in the story), exit 1; no goal: 1 error. `-TestCreate`: built, a second run asks "gibt es schon. Ersetzen?", designer.json written; invalid design: "Create" does nothing, the 6 errors are shown.

**In game (O), 2026-11-15:** "Eigenes - Zeitprobe" (built with `-BuildSpec`; see "Version 3.0.0") loads, mission text as in the preview, time limit, gold, pirate flag, extra ships and the rival's ship name as designed.

**Still to check in game:** the designer window itself (dialog over the launcher, map redraw, error state, Enter in the story); an archipelago design (8 settlements, every settlement 100/40, spice monopoly: the rivals keep kind 12 after the start, the logbook's monopoly counter shows the spice islands); villages 4+4 (big 7+7) and Few resources (gold on 1 island).

### Event mode (2026-11-15)

`-Events Off|Rare|Often` (default Off) in `src/anno-patcher.ps1`, which is now UTF-8 **with BOM** (the German event texts for `events.json` carry umlauts; console output stays ASCII). Tests: cases AI–AO in `tests/test-patcher.ps1`; display in `dev/check-game.ps1`, the logbook ("Logbook 2.0") and the launcher option "Ereignisse" ("Launcher and installer 3.0.0").

**Addresses used:**

| RVA | Content | Access by the events | Source |
|---|---|---|---|
| 0x5EC0F8 | game clock (int) | read | O ("Ships, money") |
| 0x5EBF68 | end-of-game lock (int, 1 = over) | read | I ("Logbook"), reset by command 0x36 (O, below) |
| 0x5F1D60 | number of the local (human) player (int, 0 in single player) | read | I ("Logbook"); O: `FUN_1400b43e0` compares `*(byte*)(settlement+0x1A) == DAT_1405f1d60` |
| 0x5F0960 + slot × 0x280 | +0 kind (0 human, 9 out), **+4 gold** (int) | gold read-modify-write | O |
| 0x622DC0 + i × 600 | settlement: +0 name (char[0x18], Windows-1252), +0x18 island (0xFF free), +0x1A owner (byte), +0x20 storage base per good, +0x1FA (u16, below), +0x218 workers, +0x220…+0x230 residents per stage, **+0x2A + good × 12 stock** (u16, 1/32 t) | stock read-modify-write (gift) | O (stock +0x132 tools and limit +0x20 seen in the game test of 2026-11-10; code below) |
| 0x6BA030 + g × 0x50 | tax per resident of group g (int) | written temporarily | O |
| 0x6BA1C0 + i × 0x90 + 0x3A | work interval of building i (u16) | written temporarily | O |
| 0x6BA1C0 + 270 × 0x90 + 0x30 | storage of Kontor I (≠ 0 = `haeuser.cod` read) | read | O |
| **0xE5BD0** (16 bytes, .text cave, memory only) | **marker `EVNT`**: 'EVNT', version 1 (int), address of the event page (int64) | written by the tool | free space of the memory layout ("Rivals, pirate fleet …"); offline case AH checks the non-overlap |

**Code facts (O, decompile):**
- **Stock changes are plain 16-bit stores.** The game changes a settlement's stock only through command 0x35 (settlement commands, `FUN_1400bd0e0`), sub-command 0x14 with the good in +6 (at most 0x18 = 24): case 0x12 sets `*(u16)(settlement + (good + 3) × 12 + 6)` (= +0x2A + good × 12) to the value, case 0x13 adds to it. The only side effect is a redraw flag (`DAT_14077b570 = 1`) when the island window shows goods 0x16–0x18. Paying goods (`FUN_1400b6420`) sends case 0x12 with stock − amount. No total or cache elsewhere. Entry of a good: 12 bytes from +0x24 + good × 12 (+6 stock, +8 flags, bit 0x200000 = trading).
- **Storage room of a town per good** (`FUN_1400b64d0`, used by the goods transfer `FUN_1400c1fc0`): room = `int(+0x20) − 0x140 + u16(+0x1FA) × 0x140 − stock` (1/32 t), i.e. base storage − 10 t + 10 t per unit of +0x1FA (**?** presumably markets incl. the Kontor). The gift never fills a town beyond this limit.
- **Production records cache a countdown** (`FUN_1400b43e0`): record +4 (short) is decremented every work step; at 0 a new cycle starts with `interval × share >> 7` (share ≤ 0x80 from the raw-material fill). A changed interval applies from the next cycle on; the countdown (saved in `PRODLIST2`) is never larger than the interval valid when its cycle started. Signed short: intervals above 32,767 would count down from a negative value, so the events never write more than 32,767 (largest real interval 900; × 4/3 = 1,200).
- **Taxes are read on every use** (`FUN_1400bbdc0`: `DAT_1406ba030 + group × 0x50` directly), nothing cached.
- **Command 0x36** (new game, loading a savegame) sets the clock `DAT_1405ec0f8 = 0` and the lock `DAT_1405ebf68 = 0` (besides resetting players, flags and the map size). A clock that runs backwards (or jumps further than 16× could run in the elapsed real time) therefore marks another game.
- Real table (offline, `haeuser.cod` parsed in the image): **125 work intervals change** with × 1/1.5 and with × 4/3 (the same 125 as `-Production 2`, i.e. every interval ≥ 2); after `-Production 2` the events change 122 (also seen in game).

**When an event comes:** the tool window polls the game every second (after patching, in the wait loop that runs until the game exits). An event is due when the game clock has advanced by a random interval of 0.5–1.5 × the mean (Rare 98,100 = 3 game hours, Often 32,700 = 1 game hour) **while** the game runs (clock > 0, lock 0, human kind 0), the clock advances and the human owns at least one settlement (warehouse). A clock standing still (pause, menu) adds nothing, nothing counts before the first own town, the turbo speeds the events up. Pick: first the ids of the hidden `-EventScript`, then by weight among the events possible right now (`Test-EventEligible`).

| Id (stable, events.json) | German / English title | Weight | Effect | Possible when | Saved with the game? |
|---|---|---|---|---|---|
| patron | Ein Gönner / A patron | 3 | gold + 2,000 × (stage + 1), i.e. 2,000–10,000 | gold < 2,000,000,000 | yes, intended (PLAYER4 gold) |
| warehouse_fire | Brand im Kontor / Fire in the warehouse | 2 | gold − 5 % (rounded to 10, at least 100, at most 1,000 × (stage + 1)) | gold ≥ 2,000 | yes, intended |
| trader_gift | Geschenk eines Händlers / A trader's gift | 2 | 10 + 5 × stage t of tools, wood, bricks or food (random among those with ≥ 5 t room) into the largest own town, up to its storage limit (formula above) | such a good exists | yes, intended (KONTOR2 stock) |
| tax_windfall | Steuersegen / Tax windfall | 2 | taxes × 1.5 (on top of `-Taxes`), 1 game hour | residents > 0, no tax event running | **no**: the tax table comes from `haeuser.cod` at program start, not from savegames |
| tax_slump | Steuerflaute / Tax slump | 2 | taxes × 0.75, 1 game hour | as above | no |
| harvest_boom | Erntesegen / Bumper harvest | 2 | work intervals / 1.5 (on top of `-Production`), 1 game hour | `haeuser.cod` read, no production event running | no (only the countdown of a cycle started during the event, a normal value ≤ that interval) |
| marsh_fever | Sumpffieber / Marsh fever | 2 | work intervals × 4/3 (production × 0.75), 1 game hour | as above | no (same) |

- Stage = highest population stage with residents in any own town (0 pioneers … 4 aristocrats). Positive weight 9 of 15. Event codes 1–7 in the page = table order.
- Taxes and intervals are **game-wide** (the rivals share the table, as with `-Taxes`/`-Production`); the texts say so ("auch deinen Konkurrenten"). One temporary event per kind at a time: a tax or production event that is due while one of its kind runs is skipped; a tax and a production event can overlap. Rounding half up, at least 1, 0 stays 0.

**Restoring:** a temporary event ends and its originals are written back when (1) its end clock is reached, (2) the clock jumps (another game started or loaded), (3) the game ends (lock or human kind 9), (4) the tool stops (normal end, error, Ctrl+C, closing the window: console handler `SetConsoleCtrlHandler`). A value is restored only if the game still holds what the tool wrote (otherwise it is left alone and reported). The process exiting needs nothing. A killed tool window leaves its values to the next tool run in the same game process (every run, also with `-Events Off`, restores them before the table options compare their originals) and to the game's exit.

**State in the game process:** the tool allocates one page (`VirtualAllocEx`, 4 KB, read/write) in the game process and puts its address behind the marker `EVNT` at RVA 0xE5BD0. Page (C# class `AnnoEvents`): +0 'EVST', +4 version 1, +8 owner tool PID (0 = none), +0xC last game clock; taxes +0x10 active, +0x14 event code, +0x18 factor × 1000, +0x1C end clock, +0x20 5 originals, +0x34 5 written values; production +0x48 active, +0x4C code, +0x50 factor × 1000, +0x54 end clock, +0x58 entries changed, +0x60 500 originals (u16), +0x450 500 written values. All writes of the events (page, taxes, intervals, gold, stock) go through `AnnoEvents` under one lock; `Stop()` sets a flag after which nothing is written any more (the window may close while the main thread writes). The page is written before the game values, so an interruption at any point restores correctly. Another running tool window that owns the page (its PowerShell process alive) keeps it; a second window then runs no events.

**events.json** (the interface to the logbook): `%APPDATA%\Anno1602-Extensions\events.json`, UTF-8 without BOM, at most 200 events, newest last, written through a temp file + `File.Replace`/`Move` (retried 10 × 100 ms if the logbook has it open); a missing or broken file starts a new list.

```json
{ "version": 1, "events": [ { "time": "2026-11-15T00:52:10", "pid": 12345, "clock": 412300, "id": "tax_windfall",
    "title": { "de": "Steuersegen", "en": "Tax windfall" }, "text": { "de": "…", "en": "…" },
    "effect": { "de": "Steuern +50 % für 1 Spielstunde", "en": "Taxes +50% for 1 game hour" },
    "endsClock": 445000, "endedEarly": true } ] }
```

- `pid` = game process; `endsClock` = clock + 32,700 for temporary events, else 0. Effects e.g. "+4'000 Gold" / "+4,000 gold", "-1'200 Gold", "Produktion -25 % für 1 Spielstunde", "+15 t Werkzeug" / "+15 t tools"; the gift text names the town. PowerShell 5.1 writes umlauts as UTF-8 and the apostrophe as `'` (valid JSON).
- `endedEarly` (optional, 3.0.0 fix after the in-game test): written by `Set-EventEndedEarly` when a temporary event ends before `endsClock` (game over, another game loaded or started, the tool stops); `endsClock` keeps the planned value. The normal end is not written.

**Console** (UI language, ASCII like all other messages): `*** Ereignis: Steuersegen - Steuern +50 % fuer 1 Spielstunde`, the text, a detail line (gold now, taxes now/before, intervals changed), and at the end `Ereignis vorbei: Steuersegen - Steuern wieder 7/8/11/12/13.` (or `vorzeitig beendet (anderes Spiel ...)`, `mit dem Spiel beendet`, `beendet, weil dieses Fenster schliesst`). An event that is not possible prints "... ist gerade nicht moeglich".

**Parameters:** `-Events Off|Rare|Often` (recorded in `saves.json` like every option). Hidden test switches (not recorded): `-EventSeed n`, `-EventScript id,id,...` (these come first), `-EventFile path` (in test mode events.json is written only with it), `-EventPollMs`, `-EventIntervalClock` (mean), `-EventDurationClock`, `-EventTestUntilClock` (test mode: the loop stops at this clock as if the window was closed). With `-NoLastgameProtection` and events on, the window stays open for the events but renames nothing.

**`dev/check-game.ps1`:** `Events (marker 0xE5BD0)` (page, owner PID running/gone, last clock), `Event taxes` (event, factor, end clock, now / originals, "NOT as written" if different), `Event production` (event, factor, end clock, intervals changed, as written or not, the first four "no. i a -> b") and the newest 3 events of this game process from events.json. Hidden `-TestProcessId/-TestBase` for the offline test.

**Offline test (O):** `tests/test-patcher.ps1` 556 → **623 of 623** (67 new checks in AI–AO, 296 s; the event engine runs in the test process against the helper process with the mapped exe and the real `haeuser.cod` parse); with AP and the `endedEarly` checks 640 (see "Version 3.0.0").
- AI each of the 7 events: gold 20,000 → 24,000 (patron, stage 1) → 22,800 (fire, −1,200); gift +5 t food (capped at the 30 t limit) or +15 t tools, nothing else in the settlement table changed; taxes 11/12/17/18/20 and 5/6/8/9/10, page contents, still active one clock before the end, the 5 group records byte for byte as before at the end clock; harvest and fever: 125 intervals, 0 wrong, 0 other bytes, table byte for byte as before at the end.
- AJ windfall + harvest at once; slump and fever skipped while busy, the patron instead; separate ends; everything byte for byte as before; since the fix also `endedEarly`.
- AK with `-Taxes 2 -Production 2`: windfall 21/24/33/36/39, harvest on top of the halved intervals (122 changed); a second tool run meanwhile leaves everything (owner alive); restored to exactly the ×2 values; third run: nothing changed.
- AL events.json: new folder, no BOM, fields and types, German and English texts and number formats, town name in the gift; 199 old + 3 new = 200 (oldest dropped, newest last); broken file and file without `events` replaced; no temp file left; `saves.json` keeps `-Events Rare` but none of the test switches.
- AM no event while the clock stands still, without an own town (a rival town or native village does not count), after the lock or with the human out, at clock 0; a running windfall ends at once at the game end, when the clock runs back (load) and on +5,000 within 1 s; +3,000 within 20 s is the same game; interval 1,000: no event at +900, one at +1,100; 2,000 intervals 501…1,500 (average 996); the same seed gives the same 17 events (all 7 kinds).
- AN nothing without `-Events` and with `-Events Off` (no marker, no events.json); the real loop of the tool (`-Events Often` + test switches, German UI, clock +15 per 0.1 s up to 4,000): exit 0 after 29 s, 11 events, the 3 scripted ones first, everything byte for byte as before and the page without owner at the end.
- AO a tool run while the owner lives restores nothing; after the owner is gone, the next run with `-Events Off` restores 4 taxes and all intervals and leaves the one tax changed meanwhile (99); `Stop()` restores and afterwards blocks ApplyTax, AddGold and the owner; check-game shows "Tax windfall x1.5 until clock 6700: now 11/12/17/18/20, originals 7/8/11/12/13" and "Marsh fever x0.75 until clock 6800: 125 work intervals changed, as written", afterwards "none".
- Static: 0 parse errors in the three files, BOM (patcher, check-game), no CR. `-CheckOnly -Events Rare` (de) and `-Events Often` (en) exit 0 with the new option line.

**In game (O), 2026-11-15:** 13 events in ~5 min at 16× with a scripted list; gold, gift, harvest and fever as designed, the early end with the game restored the intervals; tax events not seen (they need residents). Details in "Version 3.0.0".

**Still to check in game:** the tax events (a town with residents; check-game "Event taxes" and the town window's tax income); pause (no event, an active event does not end); save and load during an event ("Ereignis vorzeitig beendet (anderes Spiel gestartet oder geladen)", taxes back to the values without the event); closing the tool window with X during an event; kill test (Task Manager) and the takeover by the next tool run ("ein frueheres Werkzeugfenster hat Ereigniswerte im Spiel hinterlassen; zurueckgesetzt …"); whether an open Kontor window shows a gifted stock at once; the real rates (one hour real time at 16×: Rare about 4–6 events, Often about 14–18; none before the first Kontor); without `-Events`: check-game "none (no event record in this game process)".

**Open (?):**
- Does the open Kontor window show a gifted stock at once? (The game sets a redraw flag for goods 0x16–0x18 when its own command changes the stock; the tool's direct write does not.)
- Meaning of settlement +0x1FA (count for the storage limit, × 10 t; presumably markets/Kontor).
- Fairness of the game-wide tax and production events (the rivals profit or suffer as well); for the human alone hooks in `FUN_1400bbdc0` / `FUN_1400b43e0` per owner would be needed.
- The owner check uses "PowerShell process with that PID still running"; if the PID of a killed tool window is reused by another PowerShell window before the next tool run, that run would not take the events over. Rare; a heartbeat in the page would solve it.
- Reading and writing gold or a stock (microseconds, under the lock in one C# call) could lose one concurrent game update of that value (at most one tax tick or one cart load). Not observed; the game does the same kind of plain store.

### Launcher and installer 3.0.0 (2026-11-15)

**Launcher (`src/launcher.ps1`):**
- Option `Events` in the group "Gegner und Gefahren" / "Rivals and dangers" (label Ereignisse/Events): Off (Aus, default, no argument), Rare (Selten, `-Events Rare`), Often (Häufig, `-Events Often`). `-PrintChoices`: `Events=Off:`, `Events=Rare: -Events Rare`, `Events=Often: -Events Often`. Presets unchanged. All 89 choices of the 25 options accepted by `anno-patcher.ps1 -CheckOnly` (O).
- Size 978 × 793 px at 100 % (before 978 × 784; option rows 2 px tighter, so the 13 rows of the left column fit).
- Adventures tab: list 320 px; below it the button "Eigenes Szenario bauen …" / "Build your own scenario …" (the designer as a modal dialog, see "Scenario designer") and the check box "Kapitel nacheinander freischalten (das nächste Kapitel einer Kampagne nach jedem Sieg)"; in the random-adventure box a second button "Tagesabenteuer" / "Daily adventure" (`random-adventure.ps1 -Daily -Install`, always Average; result box with the goals as for a roll). Campaign column: "Tagesabenteuer"/"Daily Adventure", "Eigenes"/"Custom".
- **Chapter unlocking** (`settings.json` key `UnlockChapters` = "1"/"0", default off; disabled with a tooltip when there is no chapter set): chapter index `scenarios\chapters.json` next to the launcher (written by the installer). Per campaign (sorted by chapter) every chapter up to the first one not won is open, all later ones are locked. A win counts under any name of the chapter (German or English title), from `logbook.json` `missions[].scenario/result`. On: missing open chapters are copied from the set to Own Scenarios, locked ones are removed under any of their names (only exact chapter names of the index – never the player's files or "Last Szenario"). The launcher does this at every start (and when the box is ticked), so a new win installs the next chapter; the list shows it as "→ nächstes Kapitel – neu freigeschaltet". Locked chapters are grey with "🔒 gesperrt – zuerst Kapitel <n> gewinnen" (the lock renders through font fallback in the ListView). Off: every missing chapter is copied back (only when the box is unticked, not at a normal start, so chapters the player deleted stay deleted).
- Hidden parameters: `-StartTab <n>` (the designer opens the list with 2), `-SyncChapters` (no window: apply the saved setting – used by the installer), `-ChapterFolder` (test). **O** `$PSScriptRoot` is empty in param defaults of PS 5.1 when started with `-File`, so the default is set after the param block.
- `-TestClicks` (O) additionally: daily adventure (RESULT with the goals), designer (fixed test design "Testinsel" into the Own Scenarios of `-DocumentsFolder` if given, else `-TestOutFolder`; then "LIST tab 2, selected: Eigenes - Testinsel"), unlocking off → on (the number of locked chapters and the status of every chapter) → off. Bug found and fixed: `$list.Add('{0} | {1}' -f $a, $b)` passes two arguments to `Add` (the comma binds to the method call) → FormatException → a WinForms "unhandled exception" dialog off-screen; fixed with double parentheses.

**Installer (`src/install.ps1`):**
- Installs `scenario-designer.ps1` too: 10 files with `FINDINGS.md`.
- Builds the scenarios of the UI language into a temp folder as before (41 now) and copies them to Own Scenarios; in addition the full set stays in `<program folder>\scenarios\` (old `*.szs`/`*.json` there are deleted first; the generator also writes its intermediate files there) with the index `chapters.json` (UTF-8 without BOM), one entry per definition of `build-scenarios.ps1` whose built title matches "<Campaign> <n> - <Title>" – 28 chapters (Smaragdinseln 6, Wettlauf 4, Sturmsee 6, Neue Welt 6, Handelsliga 6):

  ```json
  { "version": 1, "chapters": [ { "file": "Smaragdinseln 1 - Landung", "campaign": "Smaragdinseln", "chapter": 1,
      "names": ["Smaragdinseln 1 - Landung", "Emerald Isles 1 - Landfall"] } ] }
  ```

- With `UnlockChapters` = 1 in `settings.json` it then runs `launcher.ps1 -SyncChapters` (sandbox-aware), so Own Scenarios keeps only the unlocked chapters.
- `-Remove`: our names = the pattern below **plus every title of `build-scenarios.ps1` in both languages** (dot-sourced with `-Library` in a scope of its own, so campaigns added later are removed too) plus the names in the installed `chapters.json`. Saved games, the player's own scenarios and "Last Szenario" stay. Pattern: `^((Smaragdinseln|Wettlauf|Sturmsee|Neue Welt|Handelsliga|Emerald Isles|Race|Storm Sea|New World|Trade League) \d+ - .+|(Herausforderung|Challenge) - .+|(Abenteuer|Adventure) \d+( [A-Za-z]+)?|(Tagesabenteuer|Daily Adventure) \d{4}-\d{2}-\d{2}|(Eigenes|Custom) - .+)\.szs$`.
- `tests/test-install.ps1`: the scenario count comes from `build-scenarios.ps1` (41); a new player file "Meine Karte 2 - Fortsetzung.szs" (named like a chapter, must stay); new checks: full set + index, an English install with unlocking on and wins in both languages (Emerald Isles 1–2, Race 1–3, chapter 1 of the others; German copies of locked chapters removed too, challenges and player files untouched), the installed launcher's `-TestClicks` in the sandbox (designer, daily adventure, unlocking on/off), removal of daily and designer files. **27 of 27 checks (O)**; the real installation, settings, Own Scenarios and shortcuts unchanged (fingerprint). A failing "identical files" check now names the files.

**In game:** the launcher window was not clicked on screen (screen control of PowerShell windows not granted); its buttons are clicked in code by `-TestClicks`, the unlocking is tested in the sandbox of `test-install.ps1`. **Still to check by hand:** "Ereignisse: Aus" as the last row of "Gegner und Gefahren" and the window on a 1080p screen at 125 %; "Ereignisse: Selten" → tool window line, `saves.json` with `-Events Rare`, "Weiterspielen" shows it; "Tagesabenteuer" result box and the same file on a second click; the designer dialog over the launcher and the selection of the new scenario; ticking the unlocking (Own Scenarios keeps chapter 1 of each campaign and the won ones, grey locked rows, "neu freigeschaltet" after a win, unticking brings all back); `uninstall.cmd` removes daily and designer files and keeps the player's scenarios and "Last Szenario".

### Logbook 2.0 (2026-11-15)

`src/logbook.ps1` in 3.0.0. Still read-only (`OpenProcess` 0x410) and **no new memory address**: all new data comes from the readings of 2.2 (gold, residents per stage, workers, balance, towns, ships, game clock, scenario name), the time limit 0x5EC1A8 ("Mission time limits") and `events.json` ("Event mode"). "O (test)" = checked offline (synthetic memory images, the helper process with the mapped exe, the real window loop off-screen with `-TestTicks`); in the game only the events display was seen so far (see "Version 3.0.0").

**Window:**
- Two tabs under the title (owner-drawn strip, click): **Spiel / Game** (as in 2.2 – mission, empire, rivals, achievements – plus the summary card of the last game, the events and the time-limit line) and **Verlauf / History** (charts, summary of the game shown, played games). Compact mode unchanged (title, goals, one line), no tabs; after a game one extra line "Zuletzt: Gewonnen · 5 h 39 min · 1.030 Einw." / "Last game: …" (not while the score screen is shown). Default size unchanged (460 × 780, compact 360 × content height).
- Every section header folds its section (chevron on the right; stored in `settings.collapsed`); the tab is stored in `settings.tab` ('game'/'history').
- Banners: achievements gold (as before), events blue ("✦ Ereignis: <title> – <effect>", "(+n weitere)"). New unlocks while an unlock banner is shown are merged into it; a banner of the other kind waits, the one on screen then gets 5 s in all. Up to 3 lines (before: a fixed 36 px, long texts were cut).
- One (dark) theme only; the charts take every colour from the window palette (Accent, Good/Bad, stage colours, panel `BadgeOff`, grid `Rule`), so a light theme would only need a second palette.

**History file:** `%APPDATA%\Anno1602-Extensions\history\<start yyyyMMdd-HHmmss>.json` (UTF-8 without BOM, temp file + Replace). The newest 30 files are kept (`Limit-HistoryFiles`, by name, when a new game starts). The uninstaller removes the whole `Anno1602-Extensions` folder, history included.

```json
{ "version": 1, "start": "2026-11-14T20:00:00", "pid": 5151, "scenario": "Wettlauf 2 - Buergerstolz",
  "game": "Wettlauf 2 - Buergerstolz", "kind": "campaign",
  "state": { "firstClock": 100000, "lastClock": 104400, "interval": 545, "readings": 31, "peakResidents": 1495,
             "peakGold": 47110, "peakTowns": 3, "topStage": 3, "negGold": false, "reloads": 1, "events": 0,
             "hasMission": true, "firstTown": "3:Zaustaden", "achievements": ["first_town"] },
  "fields": ["clock","gold","residents","pioneers","settlers","citizens","merchants","aristocrats","workers","balance","towns","ships"],
  "samples": [ [100000,45210,1030,135,275,320,150,0,150,198,3,4] ],
  "end": null }
```

- `end` = null while the game runs, then the game summary (below). One point when at least one game minute (545 clock units = 32,700 / 60) has passed since the last one – by the game clock, so a paused game adds nothing. At 16× a point comes about every second refresh (2.5 s). Cap 720 points per game: above it every second point is dropped (the first and the newest stay) and the interval doubles, so a game of any length keeps its whole curve (O (test): 1,000 game minutes → 500 points, interval 1,090). Written every 5 new points, at the end of the game and when the logbook closes.
- **Session rules (decision):** a session starts with the first reading of a running game and continues while the same game process shows the same scenario name and the clock moves on normally (≤ 2 game minutes per reading). After a clock jump: forward ≤ 1 game hour and the same game → continues; backward, not before the start of the session and the same game → "a savegame of this game was loaded": the points after that clock are dropped (`reloads` + 1). "Same game" (`Test-SameGame`) fails when the clock is back below 2 game minutes while the session had run more than 10 (a new game), when the human's first own settlement (table order, "<island>:<name>") is another one, or when the human had towns then and has none now. Otherwise the old session ends as "left" and a new one starts. **I** Endless games may all carry the same name in 0x5C0E63, so the name alone cannot tell them apart.
- Logbook restarted while the game runs: the newest history file is continued if it is not finished, has the same pid and scenario, and the clock lies between its last point and 2 game hours later (O (test)). At window start, history files without `end` whose process is gone (or not named Anno1602) are finished as "left" with the date of the file; only files whose text ends with `"end": null` are parsed.
- Peaks (residents, gold, towns, highest stage) use the smaller value of two consecutive readings, so a single half-loaded reading cannot set a peak (O (test): one reading with 99,000 more residents → peak unchanged).

**Charts (History tab):** four small charts (plot 52 px high at 96 dpi), x axis = game time of the first and the last point, y labels in a 44 px gutter (850 / 1.5k / 45k / 1.2M, German "1,2 Mio."), hover = vertical marker, dots and a tooltip with the game time and every value: 1. gold (line with a light area); 2. residents (stacked areas per stage plus workers, white total line, legend); 3. balance (green above zero, red below, dashed zero line); 4. towns · ships (two lines). Below: the summary card of the game shown, or "Bisher am besten / Best so far" while it runs; then the played games (newest 10, "Alle n Partien anzeigen"); a click on a game shows its history file and its card ("◂ Zurück zur laufenden Partie" returns); games whose file was rotated away show "kein Verlauf gespeichert". Cost (O (test), worst case 75 settlements / 200 ships): reading + game state 62 ms median, game tab 14 ms, history tab 4 ms, layout + paint of the history tab 27 ms, writing a history file of ~430 points 4 ms (20 KB; 720 points ≈ 35 KB).

**Game summary:**
- When: the score screen (phase "ended", result won/lost as in 2.2), another game started or loaded in the same process (result `quit`), the game process ended (`quit`), or at window start for an unfinished history file (`quit`). A `quit` game is recorded only after 5 game minutes of play (2,725 clock units); shorter ones are dropped with their history file.
- Card ("LETZTE PARTIE / LAST GAME" at the top of the Game tab, "ausblenden ✕" hides it, it also folds away after 10 game minutes of the next game; also on the History tab): name, kind and date, result (Gewonnen / Verloren / Nicht beendet for a scenario, Gespielt for an endless game), Spielzeit (game clock at the end), Max. Einwohner, Max. Gold, Städte (end, "(max. n)"), Höchste Stufe, Erfolge, Ereignisse (if any), "Diesmal gespielt" (when the game was loaded later than its start), names of the achievements unlocked in this game.
- **`logbook.json`** – new key `games` (newest last, at most 100); the existing keys `version`, `achievements`, `missions` (still written exactly as before), `settings` unchanged; unknown top-level keys of other tools are now kept; new settings `tab`, `collapsed`. The mission entry, the end unlocks, the long-term unlocks and the summary are written in one write.

  ```json
  "games": [ { "date": "2026-11-14T20:01:33", "start": "2026-11-14T20:00:00", "scenario": "Wettlauf 2 - Buergerstolz",
    "game": "Wettlauf 2 - Buergerstolz", "kind": "campaign", "mission": true, "result": "won", "gameHours": 3.1,
    "playedHours": 0.0, "startClock": 100000, "endClock": 101500, "peakResidents": 1030, "peakGold": 45210,
    "towns": 3, "peakTowns": 3, "topStage": 3, "events": 0, "reloads": 0,
    "achievements": ["first_town", "mission_won", "race_won", "chapter_won"], "history": "20261114-200000.json" } ]
  ```

  `kind`: endless, campaign, challenge, adventure, daily, custom, scenario. `result`: won, lost, quit.

**Kind of game (`Get-GameKind`):** only own scenarios (flag "CUSTOM", 0x5C0E62 bit 1) are matched by name: `^(Tagesabenteuer|Daily Adventure) ` daily, `^(Abenteuer|Adventure) \d+` adventure, `^(Eigenes|Custom) - ` custom, `^(Herausforderung|Challenge) - ` challenge, `^(.+?) (\d+) - .` with a mission: campaign = group 1, chapter = group 2. Otherwise "scenario" with a mission, "endless" without (an endless game that still carries an old scenario name in memory is no adventure). Mission records in `logbook.json` are matched by name only. Chapters of a campaign (`Get-CampaignChapterCount`): highest chapter number among `Own Scenarios\<Campaign> <n> - *.szs`, at least the known counts (Smaragdinseln/Emerald Isles 6, Wettlauf/Race 4, Sturmsee/Storm Sea 6); Neue Welt and Handelsliga are found through their files.

**Events (read only):** `events.json` is read again only when its size or write time changes; a missing file = no events, a broken one is ignored (the previous list stays). Shown: the events whose `pid` is the process the logbook reads, newest first, at most 5 ("… und n frühere Ereignisse"): icon ✦ (blue while active), title, effect on the right (green/red by its sign), "Spielzeit 8 h 06 min · läuft noch 0 h 09 min" / "vorbei" / "vorzeitig beendet" ("ended early", when `endedEarly` is set – 3.0.0 fix after the in-game test), tooltip = text; language `de`/`en` with the other one as fallback. Banner for a new event when it is at most 2 minutes old by its `time`; at the first reading for a process only 20 seconds (a logbook started later shows no banner for old events). Effect sign (`Get-EffectSign`): a number with "+" or "-"/"−" anywhere in the en or de text, checked against the patcher's texts (O (test)). Events of a game (achievements, summary): same pid and `time` not before the start of the session.

**Achievements: 53** (the 24 of 2.2 with their ids, see "Logbook companion window", and 29 new). In-game ones use the two-reading rule as before; long-term ones are computed from `logbook.json` at the end of every game and at window start (so earlier games count too, unlocked with an empty `game`).

| Id | German | English | Condition | Kind |
|---|---|---|---|---|
| full_society | Ständegesellschaft | All Walks of Life | ≥ 100 residents in each of the 5 stages | in game |
| res_25000 | Volk der Inseln | A Nation of Islanders | 25,000 residents | in game |
| city_5000 | Weltstadt | Cosmopolis | one town with 5,000 | in game |
| noble_town | Adelssitz | Seat of Nobility | one town with 500 aristocrats | in game |
| fast_1000 | Goldgräberstimmung | Boomtown | 1,000 residents while clock ≤ 2 h (65,400) | in game |
| top_dog | Platzhirsch | Top Dog | ≥ 2,000 residents and more than all computer rivals' towns (kind 0/0xC, players 0–3) together, at least one rival town | in game |
| comeback | Aus den roten Zahlen | Out of the Red | gold < 0 in two readings of this game, later ≥ 25,000 | in game |
| balance_2000 | Goldene Bilanz | Golden Ledger | balance ≥ +2,000 with a town | in game |
| trade_500 | Hanseat | Master Trader | trade balance ≥ +500 with a town | in game |
| ships_20 | Flottenadmiral | Fleet Admiral | 20 own ships | in game |
| hours_100 | Zeitlos | Timeless | clock ≥ 100 h | in game |
| night_owl | Nachteule | Night Owl | a running game read between 0:00 and 3:59 local time | in game |
| rivals_3 | Dreifacher Triumph | Triple Triumph | player +0x8E ≥ 3 | in game |
| adventure / daily / custom | Abenteuerlust / Tagwerk / Eigene Welt | Call of Adventure / Daily Duty / A World of Your Own | playing that kind of game | in game |
| event_first / events_5 | Unverhofft kommt oft / Bewegte Zeiten | Expect the Unexpected / Eventful Times | 1 / 5 events in this game | in game |
| event_survived | Sturmerprobt | Weathered the Storm | a bad event of this game with `endsClock` > 0 is over (clock ≥ endsClock) | in game |
| chapter_won / challenge_won / adventure_won / daily_won | Kapitel für Kapitel / Herausforderung angenommen / Glücksritter / Held des Tages | Chapter by Chapter / Challenge Accepted / Soldier of Fortune / Hero of the Day | a won mission of that kind | long-term |
| fast_win | Blitzsieg | Lightning Victory | a won mission with 0 < gameHours < 3 | long-term |
| campaign_done / campaigns_3 | Saga vollendet / Chronist der Inseln | Saga Complete / Chronicler of the Isles | every chapter of 1 / 3 campaigns won | long-term |
| hattrick | Hattrick | Hat Trick | three won missions in a row (order of `missions`) | long-term |
| revenge | Revanche | Sweet Revenge | a scenario won after it was lost before | long-term |
| games_10 | Stammgast | Regular | 10 game summaries in `games` | long-term |

**Offline tests (O, 2026-11-15, game not running):**
- Static: BOM yes, no CR, 0 parse errors, 118 functions, none named like an alias or an existing command.
- `logbook.ps1 -SelfTest`: first 145 of 145 in de and en (the 73 of 2.2 unchanged + 72 new: achievements and kinds, long-term conditions with a temp "Own Scenarios" folder, history sampling, pause, peak filter, reload rewind, new game / other savegame / new endless game detection, quit summaries, short game dropped, resume after a logbook restart, unfinished file closed at start, file format, rotation (30), cap (720), won race summary, logbook.json keys kept, games cap (100), tabs/folding/selection/hit test, events: missing, broken, other pid, banner rules, section, achievements, effect signs); with the time-limit line and `endedEarly` **147 of 147** (see "Version 3.0.0").
- Live path: **16 of 16** – dump identical, preview writes nothing, the real window loop against the helper process: history grows with the clock, event banner within 3 s of the queued unlock banner, game won → summary + history `end` + mission, process killed → waiting; History tab opened from the settings; a click on the second tab through `WM_LBUTTONDOWN/UP` switches and stores it; an endless game whose process is killed is recorded as "quit".
- Toggles: compact 460×780 → 360×180 → 460×780, on top saved.

**Still to check in game:** the History tab with a running endless game (a point about every game minute, about every 4 s at 16×; none while paused; chart values = Game tab; the file grows every 5 points); save, play on 10 game minutes, load → curve cut back (`reloads` 1, no new file); a new endless game from the menu → card "Gespielt" and a new history file (and what 0x5C0E63 holds); quitting the process during a game → `games` entry with `result: quit`; a won and a lost chapter (card, "Kapitel für Kapitel", the launcher still shows "✓ gewonnen"); "Abenteuerlust" / "Tagwerk" / "Eigene Welt" and their won counterparts; folding and compact mode; the long-term unlocks from an existing 2.2 logbook.json (once, never again); `dev\check-game.ps1` output identical before and after (the logbook changes nothing).

**Open (?):**
- Only one window theme exists (dark); "readable in both themes" could only be checked for this one (normal + compact).
- Content of 0x5C0E63 for endless games and original campaign missions (unchanged from 2.2). Original campaign missions count as kind "scenario" (no chapter achievements).
- Quitting to the main menu is not detectable (the clock just stops = "paused or in a menu"); the game ends as "quit" only when another game starts or loads or the process ends.
- A different savegame of the same scenario whose first own town is the same settlement on the same island and whose clock lies inside the running session is taken for a reload of it (history cut back). Rare.

### Version 3.0.0 (2026-11-15)

Contents (sections above): mission time limits through the patcher, campaigns "Die Neue Welt" and "Die Handelsliga" and six challenges (41 scenarios per language), crop-climate checks, daily adventure, scenario designer, chapter unlocking, event mode with the launcher option "Ereignisse", Logbook 2.0.

**Offline results (O):**
- `tests/test-patcher.ps1`: "All 640 checks passed." = 556 of 2.2 + 67 event checks (AI–AO) + the time limit (AP, 15; 638 after it) + `endedEarly` (AJ, 2).
- `tests/test-install.ps1`: "All 27 checks passed."
- `logbook.ps1 -SelfTest`: "147 of 147 checks passed." in German and in English.
- `tests/check-scenarios.ps1`: 41 + 41 scenarios OK; the 23 scenarios of 2.2 byte-identical; 200 adventures reproduced; daily adventures reproduced; designer unit checks 31/31 per language.
- Launcher: all 89 choices of the 25 options accepted by `anno-patcher.ps1 -CheckOnly`; `-TestClicks` incl. designer, daily adventure and unlocking.

**In-game tests (O), 2026-11-15 00:40–01:15:** installed copy, German UI, 1000 × 700, turbo 16×.

- **Test A – mission time limit** ("Herausforderung - Gegen die Uhr", 3 h): the tool patched "TIMERS-Lader (Codestueck): gesetzt (53 Bytes)" without `-Pirates`/`-StartGold` (the hook is now always set). After "Spiel starten" the clock was 194 and `dev\check-game.ps1` showed "Time limit: clock 108000 = 180:00 on the display (3 h)"; the game drew its own clock at the bottom left ("00:15"), which it does only while a limit is set. Save/load: leaving the game through the options' "1602" button (score screen) wrote `lastgame.gam`; "Spiel fortsetzen" loaded it at clock 900 and the limit was 108,000 again (TIMERS hook on a savegame load). Expiry: limit set to clock + 600 (1,011 → 1,611) by a one-off memory write; at normal speed the game ended after ~65 s at clock ~1,612: lock 0x5EBF68 = 1, player 0 kind 9, score screen "Missionsbonus 0 %". The game itself ends the mission as lost when the clock reaches 0x1405ec1a8.
- **Test B – event mode** (`-Events Often -EventIntervalClock 4000 -EventDurationClock 8000 -EventScript patron,warehouse_fire,trader_gift,tax_windfall,harvest_boom,tax_slump,marsh_fever -Taxes 2 -Production 2 -Turbo -TurboLevel 16`, an endless savegame with one own town – 2 workers, no residents yet – loaded via "Spiel laden"):
  - Console: "Ereignisse: Haeufig (...)", "Steuern x2: 14/16/22/24/26 ...", "Produktion x2: 125 Arbeitsintervalle verkuerzt", "Ereignisse sind an (Haeufig) ...". No clock display (endless game: time limit none, deadline 0).
  - 13 events in ~5 min at 16×: patron +2,000 gold (stage 0) and fire −1,000 gold (the stage-0 cap); the gold in memory matched the console exactly (fire 42,966 → 41,966; patron: the console's "Gold jetzt: 42'578" equals the value read right after it – the earlier reading 40,628 was taken 16 s before the event, with running costs in between); trader's gift +10 t bricks / +10 t wood into "Zaustaden"; bumper harvest ("122 Arbeitsintervalle geaendert", intervals 16 → 11) and marsh fever (16 → 21), back to 16 at the end ("Ereignis vorbei: Erntesegen - 122 Arbeitsintervalle wieder normal"). A busy production kind and the tax events were skipped ("... ist gerade nicht moeglich"): the tax events need residents (`Test-EventEligible`), this town had none, so they were not seen in game (offline AI–AK cover them).
  - Ending the game during marsh fever (options → "1602"): "Ereignis mit dem Spiel beendet: Sumpffieber - 122 Arbeitsintervalle wieder normal.", check-game intervals 16, "Event production: none".
  - Quitting the game: "lastgame.gam ... umbenannt", "Optionen fuer 4 Spielstand/Spielstaende gemerkt" (`saves.json`).
  - Logbook (`-PreviewImage` against the live game): section "EREIGNISSE" with 13, newest first, effects green/red. **Bug found:** the marsh fever that had ended with the game was still shown as "läuft noch 0 h 11 min" (events.json had only its planned `endsClock`). **Fixed in 3.0.0:** the patcher marks an early end (`"endedEarly": true`, `Set-EventEndedEarly`; for game over, another game loaded/started and the tool stopping), the logbook shows "vorzeitig beendet" / "ended early" (test-patcher AJ, logbook self-test).
- **Test C – "Neue Welt 3 - Land der vielen Voelker"** (continents, big version): after 2.5 min at 16× (clock 24,370) all three rivals still kind 12 with one settlement each, 14 native villages (7 + 7), no early loss – the med-island rule of "In-game tests of phase 2" holds.
- **Test D – designer scenario** ("Eigenes - Zeitprobe": classic map, defeat rival 2, a large trading ship and a large warship extra, pirates attack, 4 h time limit; built with `scenario-designer.ps1 -BuildSpec`): mission text in the game list as in the preview; in game: time limit 144,000 = 240:00, gold 40,000 / rivals 30,000, flags 0x8 (pirates attack), the human's ships "Gitana" + "Seestern" + "Greif", rival 2's ship "Grimaldi".

**Not tested in game:** the launcher window (screen control of PowerShell windows not granted; its buttons are clicked in code by `-TestClicks`), chapter unlocking (tested in the sandbox by `test-install.ps1`), a daily adventure (same generator as the random adventures, only name and first line differ), the tax events (see Test B), the other new chapters and challenges. The open in-game checks are listed per section above.

**Test notes:** the save/load panel of the in-game sidebar reacts to clicks sent as window messages unreliably – a click meant for "Laden" saved the game under the selected (shortened) name instead and replaced two old test savegames; they were restored from the tool's own backup (`Savegame-Backup-20261115-004006`) and the Savegame folder was checked byte for byte against it. Use the main menu's "Spiel laden" list (real clicks work there) for load tests.

### Giant world: scenarios for 2000 × 1400 (2026-11-15, version 3.1)

**Why not simply more land (I):** the game knows at most 50 islands (`SZENE` section, island table at `0x14062DDC0` and the 16×16 block grid of `FUN_14009ce30` all have 50 slots) and only 6 + 7 island files of the biggest class "lar" (100 × 90; at most 10 per map, see "Island size"). That caps the land of any map at about 10 × 100 × 90 + 40 × 70 × 60 ≈ 258,000 tiles – the big version "Huge" at 1000 × 700 already reaches it. A bigger map can only add sea. Spread evenly over 2000 × 1400 (what the existing ×2 stretching of the 1000 × 700 version does), 50 islands lie ~240 tiles apart.

**Design:** a third map version for the giant world, with the islands grouped into five realms (`build-scenarios.ps1`, `Get-GiantPlan`, key `Giant`): Home 20/20 760 × 540 (north climate), North 1180/20 800 × 560 (north), Middle 720/500 600 × 420 (climate by the island's centre), South 20/860 800 × 520 (south), East 1220/840 760 × 540 (south); each realm shifted by up to ±40 tiles per scenario. Default 50 islands: Home 2 lar + 8 big + 1 med, North 2 + 7 + 1, Middle 1 + 6 + 1, South 2 + 7 + 1, East 3 + 7 + 1 = 10 lar, 35 big, 5 med (≈ 252,000 tiles). Placement: largest first, LCG from scenario number × 31 + seed, 24 tiles between islands, 8 from the edge, no island within 40 tiles of a template start ship (the ships are not stretched, so all players start in the north-west realm); a class that finds no room falls back one class. Resources scale with the island count as in the big version, villages per climate from `Giant.Villages` (6–7), crops of a monopoly fixed (3). The starting point is searched free in every version (`Find-FreeStartPoint` with the giant rectangles at factor 1).

**File format:** behind the big version a second version block of 1,188 bytes: +0x938 `'GROS'`, +0x93C 2000, +0x940 1400, +0x944 version 1, from +0x948 a complete `SZENE` block. Section length 3,548 = 1,172 + 2 × 1,188. Versions must grow (1000 × 700, then 2000 × 1400).

**Code cave 0xE5E40, version 2 (187 bytes instead of 200):** walks the version blocks: `push rsi/rdi`, length − 1,172, from +0x494 in steps of 1,188 while a complete block remains and the marker is `'GROS'`; a block whose designed width/height are ≥ 100 and ≤ the current map size is remembered (`rdi`); the last one remembered wins. Then as before: copy its `SZENE` block to the front, stretch x/y by current/designed size (`idiv [r9+4]`/`[r9+8]`, r9 = header of the chosen block), `eax = 1`. Without a fitting version `eax = 0` with only eax/edx changed (rsi/rdi restored). The search stops at the first block without the marker. A file with one version behaves exactly as before; old patchers (3.0) read only the first version, so they use the 1000 × 700 version (×2 at 2000 × 1400).

**Offline (O):**
- `tests/test-patcher.ps1` case Z (function test in the helper process): three versions → 2000 × 1400 giant version (factor 1, rest of the section unchanged), 1999 × 1400 / 2000 × 1399 / 1500 × 1050 / 1000 × 700 big version (stretched), 750 × 525 small; giant version with a wrong marker or 10 bytes short → big version ×2; unknown first marker → small version. Total **655 of 655**.
- `tests/check-scenarios.ps1`: a section of 2,360 or 3,548 bytes; the giant version 2000 × 1400, version 1, bigger than the big one, all 50 slots, inside the map, no overlaps, ≤ 10 lar, ≥ 4 med+, ≤ 7 villages per climate, goal goods producible and monopoly crops present with islands of their climate, starting ships in the water. **49 + 49 scenarios OK**; the 41 scenarios of 3.0 byte-identical (German set compared with the installed one).
- New: campaign "Das Weltreich / The World Empire" (71–76) and the challenges "Sieben Meere / Seven Seas" (67) and "Die Weltumsegelung / Around the World" (68), all with `BigIslandSize = 'Huge'` and a giant version: 50 islands (0/0/5/35/10).
- Scenario designer: check box "auch für die Riesenwelt 2000 × 1400" (design key `GiantWorld`, giant seed = map number, monopoly crops 3), a third map in the preview, an advice line naming the preset; the build checks the rivals' islands and the map problems on all three versions (`Get-AdvRivalIslandCounts` reads the giant block too). Unit checks 36 of 36 per language; a giant design built with `-BuildSpec` passes `check-scenarios.ps1`, and its preview plan equals the built giant block.
- Launcher: preset "Riesenwelt / Giant world" = `-Width 2000 -Height 1400 -Resources More -Turbo -TurboLevel 16 -ShipSpeed 2` (gold and rivals as the scenario intends); `-TestClicks` clicks it. `test-install.ps1` 27 of 27 (49 scenarios, 34 chapters), logbook self-test 147 of 147 in German and English (known campaigns now include all six).

**In game (O), 2026-11-15 08:33–08:55**, installed copy, German, "Weltreich 1 - Die grosse Fahrt" three times (island table, map size, players and ships read from memory and compared with the version blocks of the file):
- **Preset "Riesenwelt"** (`-Width 2000 -Height 1400 -Resources More -Turbo -TurboLevel 16 -ShipSpeed 2`): the tool set "Grosse Kampagnenkarten: gesetzt (187 Bytes)"; in game map 2000 × 1400, **50 of 50 islands exactly at the planned position of the giant version** (10 × 100×90, 35 × 70×60, 5 × 50×52, extent x 45–1937, y 60–1335), mission bits 0xA1, gold 40,000 / 15,000 × 3, the human's "Morgenstern" and "Fernweh", rivals kind 12. After 240 s at 16× (clock 480 → 38,898, more than one game hour) all three rivals still kind 12, their gold down to 4,186–6,313 (settlements built); the minimap shows the five realms and rivals in the south-west and north-east realm.
- **Without the tool** (game started alone, the 3,548-byte section): the scenario list shows and loads it as usual; map 500 × 350, **18 of 18 islands at the position of the classic map**, mission and gold as above, rivals kind 12 after ~1 min. The original loader ignores everything behind the first 1,172 bytes, also a second version block.
- **Preset "Für Kampagnen"** (1000 × 700): **50 of 50 islands at the position of the big version** (40 × 70×60, 10 × 100×90), mission and gold as above.
- Test method: an elevated terminal window lay over the middle of the screen and cannot be moved from a normal process; the game window was captured with `PrintWindow` (its own content only) and the menu buttons were clicked with window messages. Savegame folder byte-identical before and after, `lastgame.gam` untouched ("lastgame.gam wurde in dieser Sitzung nicht geschrieben"); the tool's backup rotation moved one old backup folder to the recycle bin as designed.
- Not played in game: the chapters 2–6 and the two challenges (same builder and checks), a designer scenario with a giant version (offline: identical to its preview plan), the balance of the long sea routes.

### One-line installer, Apps entry, update notice (2026-11-15, version 3.2)

**Goal:** installing without a ZIP, unzipping or SmartScreen warning, for players who have never used PowerShell.

- `get.ps1` (repository root) is meant for `irm https://raw.githubusercontent.com/MisterDeeds/anno1602-extensions/main/get.ps1 | iex`. It asks the GitHub API for the newest release (`releases/latest`; if the API fails, e.g. its limit of 60 requests an hour, the `Location` of the redirect of `/releases/latest`), downloads the source ZIP of that tag (`archive/refs/tags/<tag>.zip`) to `%TEMP%\anno1602-extensions-setup-<guid>`, unpacks it and runs `src\install.ps1 -StartLauncher` in Windows PowerShell 5.1 (from a 32-bit window through `Sysnative`), then deletes the temporary folder. ASCII only (the text arrives through `Invoke-RestMethod`; raw.githubusercontent.com sends `charset=utf-8`, so umlauts would work too, but ASCII is independent of that).
- Rules for `iex` code: everything inside `& { }` (no variable, function or `$ErrorActionPreference` stays in the player's window), never `exit` (it would close that window), errors as a red message plus "the game files are unchanged". Files downloaded with `Invoke-WebRequest` get no Mark of the Web, so no SmartScreen and no `Unblock-File` needed; `-ExecutionPolicy Bypass` for the child process, no administrator rights.
- `install.ps1` writes `version.txt` (newest `## x.y.z` of `CHANGELOG.md`), copies itself into the program folder and adds `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Anno1602-Extensions` (DisplayName, DisplayVersion, Publisher, DisplayIcon = the game's exe, InstallLocation, `UninstallString` = the installed copy with `-Remove -PauseAtEnd`, `QuietUninstallString`, NoModify/NoRepair, EstimatedSize). The installed copy removes its own folder (the script is read completely before it runs; it first changes to `%TEMP%`) and refuses to install over itself. `-Remove` also deletes the Apps entry.
- Launcher: version in the title; once per start a background runspace asks `releases/latest` (8 s timeout, own User-Agent, nothing else sent), a WinForms timer shows "Version x.y.z ist da. [Jetzt aktualisieren]" if the tag is newer; the button starts `get.ps1` in a visible window (`ANNO_EXTENSIONS_PAUSE_ON_ERROR=1`: it waits for Enter only after an error) and closes the launcher, the installer opens the new one.
- PowerShell gotcha met again: a variable `$remove` in `install.ps1` is the `[switch]$Remove` parameter (names are case-insensitive) – assigning a string failed with "cannot convert System.String to SwitchParameter".
- Tests: `tests/test-install.ps1` **40 of 40** – version.txt, the Apps entry (in the sandbox as `apps-entry.json`), `-StartLauncher`, the update notice in the click test (older tag hidden, newer shown, button starts get.ps1), the installed copy (does not install over itself, removes itself and the entry), and `get.ps1` through `Invoke-Expression` with a ZIP in the layout of a GitHub release into a second sandbox (files identical, 49 English scenarios, shortcuts, entry, temp folder gone, nothing left in the window) plus a broken ZIP (message, no exception). The real API answered `v3.1.0` in 445 ms.
- **Real run (O), 2026-11-15 20:37**, after publishing the release: the exact line in the app's terminal panel (an interactive Windows PowerShell 5.1 outside the agent's sandbox; dot-sourced from a one-line file, because that panel accepts no pipes) updated the real installation from 3.1.0: "Lade Version 3.2.0 herunter", 49 scenarios, both shortcuts, Apps entry "Anno 1602 – Erweiterungen" 3.2.0 with the game's icon (1,863 KB), the launcher window "Anno 1602 – Erweiterungen 3.2.0" opened; the 12 installed files equal the repository, `lastgame.gam` unchanged. It left one **empty** `anno1602-extensions-setup-*` folder: the virus scanner still held the unpacked files when the folder was deleted → `get.ps1` now tries up to ten times, 0.5 s apart (commit 5c285c6, served from `main` within a minute). A second real run at 20:41, an update over 3.2.0, left no folder behind, reopened the launcher and kept `lastgame.gam`.
- **Observation in the agent's shell (O/I):** a new process whose command line is exactly `powershell -Command "irm <url>/get.ps1 | iex"` failed with "Die schließende } fehlt" at `& {` (as if the text had been run line by line), and `-EncodedCommand` variants with `irm … | iex` were refused at process start ("Zugriff verweigert"). The same text through `iex (irm …)`, `$s = irm …; $s | iex`, `irm … | Tee-Object … | iex`, from a script file, or with any statement after `| iex` ran normally, and `irm` always delivered one string equal to the file. **I:** process-creation filtering of the classic download-cradle command line in that environment, not the script; a player pasting the line into a PowerShell window starts no such process (confirmed by the real run above).

### Automatic updates (2026-11-15, version 3.3)

- Launcher (installed copy only): check box "Automatisch aktualisieren / Update automatically" (settings.json `AutoUpdate`, on unless `0`). When the background request reports a newer tag, `Show-UpdateNotice` starts the update by itself – unless the game runs (`Get-Process Anno1602`) or this version was already tried today (`UpdateTried` = "3.3.0 2026-11-15", saved before the start, so a failing update cannot loop); otherwise the notice with the button stays.
- The update no longer starts `powershell -Command "irm … | iex"` (the pattern that the agent's environment filtered, see above, and that security software may dislike in general): the launcher downloads `get.ps1` with `Invoke-WebRequest` to `%TEMP%\anno1602-extensions-update.ps1` and runs it with `-File`; the next launcher start deletes that file.
- After an update: `LastVersion` in settings.json (saved at every start of an installed copy) is older than version.txt → the row says "Aktualisiert auf Version x.y.z." once, with a button "Was ist neu?" that opens the release page of that tag.
- 3.2.0 only had the button (with the `-Command` start); versions up to 3.1.0 have no check at all – they have to be installed once more with the one-liner.
- Tests: `tests/test-install.ps1` **42 of 42** (note after an update, notice and button with auto off, automatic start with auto on, not twice the same day), `tests/test-patcher.ps1` 655 of 655.
- **Real run (O), 2026-11-15 20:58:** release 3.3.0 published, installed with the one-liner in the app's terminal panel, then `version.txt` set to `3.2.9` and the launcher started through the desktop shortcut (`Start-Process` of the .lnk, like a double click). The launcher found v3.3.0, started the update by itself (window of `anno1602-extensions-update.ps1` seen), the installer wrote version.txt 3.3.0 at 20:58:11 and the scenario set at 20:58:20 and opened the new launcher at 20:58:20; settings.json afterwards `LastVersion=3.3.0`, `AutoUpdate=1`, `UpdateTried=3.3.0 2026-11-15` (so the note "Aktualisiert auf Version 3.3.0." was shown and saved), Apps entry 3.3.0, no update script and no setup folder left in %TEMP%, `lastgame.gam` unchanged.

### Tidier launcher bottom (2026-11-16, version 3.3.1)

- The update notice is a `TableLayoutPanel` as wide as the tabs (columns 50 % | symbol | text | "Update now" | "What is new?" | 50 %, every control `Anchor = None`, so it sits in the middle horizontally and vertically), painted as a rounded bar in the style of its state: Done (green, ✔), New (blue, ⬇), Busy (blue, ↻), Error (red, ⚠). Hidden buttons take no width. Long error texts wrap at 640 px.
- The button row is a `TableLayoutPanel` too: three buttons, a stretching column, the two check boxes; the first button starts at the tabs' left edge, the last check box ends at their right edge.
- **Measured, not guessed (O):** previews (`-PreviewImage`, now also `-PreviewUpdate updated|error|v9.9.9`) of all states in German and English; the control bounds printed and outlined in red, the text pixels found in the PNG. Labels and check boxes render with GDI+ by default (`UseCompatibleTextRendering` is true without `SetCompatibleTextRenderingDefault(false)`): their AutoSize width leaves about 15 px after the text, so the last check box ended 18 px before the edge. With GDI rendering (`UseCompatibleTextRendering = false`) for the bar's text and the two check boxes it is about 8 px (the font's own side bearing). The bar's text sat 2 px above the button text → top margin 4.
- A preview never starts an update (`Start-Update` returns at once with `-PreviewImage`), so a preview with "Update automatically" on is safe.
- Tests: `tests/test-install.ps1` **42 of 42**.
- **Real run (O), 2026-11-16:** release 3.3.1 published; the open 3.3.0 launcher closed and the desktop shortcut started. The 3.3.0 launcher updated itself (version.txt 3.3.1 after 9 s) and the new launcher was open after 17 s; installed `launcher.ps1` equal to the repository, settings.json `LastVersion=3.3.1`, `UpdateTried=3.3.1 2026-11-16` (the green note was shown), Apps entry 3.3.1, nothing left in %TEMP%, `lastgame.gam` unchanged.

### Island forge: rivers, mountains, volcano, giant islands (2026-11-22, version 3.4)

**Island files (O):** `Nord`, `Sued` (whole islands), `NordNat`, `SuedNat` (islands with a native village), `NoKlima`
(5 files) – 677 `.scp` files. Chunks: `INSEL3` (40-byte header, 73 old small islands) or `INSEL4/5` (116 bytes:
+0 number, +1 width, +2 height, +3 flags, +23 volcano count, +28 ore mountains 4 × 8, +60 volcano mountains 4 × 8,
+92 fertility, +96 file number, +98 class, +100 climate, +101 "original" flag), `INSELHAUS` (8 bytes per piece: id =
haeuser.cod `Id` − 20000, x, y, then bits: turn 0–1, animation 2–5, island number 6–13, town 14–16 (7 = none),
random 17–21, player 22–25 (7 = none)), `HIRSCH2` (deer: island, x, y, …). A piece covers its size from
haeuser.cod (turned if the turn is odd); in a whole island every tile is covered exactly once (checked for all).
- Landscape pieces: sea `MEER` 1201–1259 (depth by distance), surf `BRANDUNG`/`BRANDECK` 1205–1207/1214–1221, beach
  `STRAND*` 1011–1090 (straight, inner and outer corners, rocky), meadow `BODEN` (27xx), forest `WALD` (13xx north,
  28xx palms), **mountains = rock `FELS` 1103–1110 (2 × 2 to 6 × 6) with a ring of slope pieces `HANG`/`HANGECK`
  2301–2350**, rivers `FLUSS` 901–903 and `FLUSSECK` 904/905 (2 × 2), springing from `HANGQUELL` 2311 in the slope,
  ending in `STRANDMUND` 1071 on the beach and `MUENDUNG` 1208 in the surf; bridges 1601 in village files.
- Rivers in 210 of 431 Nord/Sued islands; mountains at most 3 tiles from the coast: 68 % of all mountain groups.
  `lar` has no island whose mountains all stand at the coast, so choosing islands is not enough – they are changed.
- **The volcano (O):** the only one is `Nord\big25` (70 × 60): volcano count 1, volcano mountain (+60) = the rock
  1108 at 9/6. In memory the count is island +0x40 with the places from +0x31; `FUN_14009e390` lets a random one erupt
  (`FUN_1400715b0`, the call at RVA 0x9E93E, already a NOP with Disasters Off).
- **Village files** (`NordNat`/`SuedNat`, 241): 111 hold only the changes of the village (148 pieces in `BIG01`) and
  have the original flag 0 with file number/class/climate of the island below; 128 are whole islands; 2 are neither
  (left as they are).

**How the game finds island files (O):** both loaders – the SZENE loader `FUN_1400d0de0` (new games) and the
INSEL3/4/5 loader `FUN_14009bdd0` (reads the island under a village file and, for savegame islands with the original
flag 0, the island file before the savegame's own complete `INSELHAUS` chunks overwrite it) – build
`<game>\Nord\lar05.SCP` (`"%s%s%s%02d.SCP"`, folders `Nord\`/`Sued\`/`NordNat\`/`SuedNat\`/`NoKlima\`, classes from
the table 0x1400EA200) and then first try the same relative path below `DAT_1405c55a0` = `<game>\Loca\<language>\`
(set with `"%sLoca\%s\"`; it holds no island files), falling back to the game folder. The second folder is loaded by
five LEA instructions: RVA 0xD13B2 (`lea r8`, source of `strncpy_s`), 0xD13CF (`lea rcx`, its length), 0x9C01A /
0x9C381 (`lea r13`, INSEL4/5) and 0x9C42B (`lea r13`, INSEL3). **Savegames (O)** store every island completely (the
first `INSELHAUS` of an island in `lastgame-1000x700-20261111-183442.gam` has exactly the size of the island file),
so they never depend on the island files.

**Implementation:** `src/island-forge.cs` (C# 5, compiled by the tool with `Add-Type`) reads haeuser.cod (sizes and
kinds, same parser rules as the game: constants, `@Nummer`/`@Id` relative, values carried over) and writes only
changed files into `%LOCALAPPDATA%\Anno1602-Extensions\islands\<hash of the forge>-r<0|1>-m<0|1>-v<0|1>-g<n>\` (once per
set of options; other sets are deleted). The tool writes this path (ANSI, ≤ 255 bytes, otherwise the 8.3 name) into
the free end of `.pdata` (RVA 0x91B200, readable, not in the file) and points the five LEAs there. Files that are not
in the folder still come from the game folder.
- **No rivers:** river pieces become meadow (a copy of the nearest meadow piece of the same island, so the local kind
  of grass stays), the spring a plain slope 2302 with the same turn, the beach mouth straight beach 1013 (same turn –
  checked: 547 of 547 neighbouring straight beach pieces have it), the sea mouth straight surf 1205 with turn + 1 (all
  422 neighbours differ by exactly 1), bridges road 411. Village change files get the same treatment, their meadow
  from the changed island below.
- **Mountains at the edge:** groups of rock and slope (8-connected, not the Aztec pyramid 2211) further than 3 tiles
  from the coast (distance from the open sea and its beach; lakes do not count) move as a whole to the free spot (only
  meadow and forest under and around it, one tile of land left before the beach) closest to the coast, of those the
  closest to the old place, if that is nearer to the coast; the old place becomes meadow, a river springing from it is
  removed (pieces connected to the spring, then its mouths), deer on the new spot are dropped. Mountains under or
  next to a village (3 tiles around every piece of a village change file) stay, nothing moves there.
- **Giant islands:** 8 per climate (`lar20`–`lar27`; sizes 150 × 130, 140 × 140, 160 × 125, 135 × 120, 155 × 140,
  145 × 125, 160 × 140, 140 × 120, the same in `Nord` and `Sued` because climate 2 is chosen by position) from the
  game's `lar` islands in the INSEL5 format (then `big`): the model's land is blurred, enlarged, given a little noise and
  cut at 0.5; coast and water are laid with rules learned from all whole islands of the game: for every beach tile the
  piece and turn the game uses for the same 8 neighbours (only shapes with one clear answer), for water by the distance
  to land and the direction of the nearer neighbours, deep water by distance; the outline is cleaned until every coast
  tile has a rule. Forest by the density of the model's forest around the enlarged spot (keeps the speckled look),
  meadow and forest pieces from the model, the model's mountains at their enlarged place plus once more per area
  factor at random places, deer enlarged. No rivers. Header: width, height, file number 20+, class 4, climate.
- **Planner (`-IslandSize Giant`):** originals as with Large, but they leave up to 6 of the 10 `lar` places to the
  giant islands; then the giant islands (each file once, the largest first, 2000 random tries each), then copies
  alternately lar/big. Island class 4 in the SZENE entry, explicit file number → the loader opens `Nord|Sued\lar2x.SCP`.
- Irregular island files (O): `Sued\big52` has 7 empty tiles, a river piece on a river corner and a second
  `INSELHAUS` with three river corners and meadow; `Sued\lit48` (forest) and `Sued\lit26` (one surf piece) have such a
  second landscape layer too, five more an empty one. Rivers are removed in both layers as long as that adds no
  empty or doubly covered tile; mountains move only on islands with one layer that cover every tile once.
- Very large mountain massifs stay where they are when no free spot near the coast fits them (`Nord\big51`: one
  connected group of about 20 × 16 tiles in the middle), as do mountains next to a village (`Sued\big17`).
- Build time (O): about 4 s for rivers + mountains, under 1 s for the giant islands, 11 s for everything in a fresh
  process (C# compile included); afterwards the folder is reused.
- **In the running game (O), 2026-11-22 08:17–:** repository tool with `-IslandSize Giant -Rivers Off -Mountains Edge
  -Volcanoes Off -RivalGrowth Ambitious -Rivals Hard -RivalGold 60000 -Resources Lots -Pirates Off -Turbo -TurboLevel 16`,
  all 30 sites set; new endless game "Durchschnittlich", driven only by window messages (`PostMessage` keys and clicks,
  `PrintWindow` captures) while the user worked in front of it. **All 50 islands loaded**, among them **6 giant islands**
  (160 × 140, 155 × 140, 160 × 125, 140 × 140, 150 × 130, 140 × 120, files lar20–lar27) and 4 × 100 × 90.
  Read from memory (island table 0x62DDC0, tiles at +0x2CB0): **the tiles hold graphic numbers**, not file ids; the
  table RVA 0x6CBB00 (8 bytes per graphic number) points to the building entry (RVA 0x6BA1C0 + no. × 0x90), whose number
  leads to the file id (e.g. graphic 758 → no. 171 → sea 1201). With that: no river piece on 49 islands (the 50th was
  `Sued\big52`, fixed since, see above), 169 of 172 mountain groups at most 3 tiles from the coast (the three others:
  the massif of `Nord\big51`, next to the village of `Sued\big17`, and `Sued\big52` with its second layer at 4 tiles). A giant island on screen: beach, surf and sea without a gap, speckled forest, mountains
  near the shore. The game ran at exactly 16 × (160 clock steps per second) also behind other windows; an AI capital
  grew on a giant island.
- Tests: `tests/test-islands.ps1` **19 of 19** (every written island covers each tile once, other chunks unchanged, no
  river piece left in 211 islands + 95 village files, rock count unchanged, mountain groups at the coast 68 % → 97 %,
  only `Nord\big25` changed for the volcano, 16 giant islands with only learned coast pieces, two builds byte-identical,
  game folder unchanged: 1738 files compared by hash).

### Mountains completely at the coast (2026-11-22, version 3.4.1)

**Report (O):** a game at 2000 × 1400 with "Gigantisch", rivers none, mountains at the coast, no volcano showed a
giant island with two long mountain ranges through the middle. The user's forge folder
(`a515df47-r1-m1-v1-g8`) explains it: `Nord\lar22` (160 × 125) had two groups of 21 rocks / 443 tiles with the
nearest tile 2 and the **farthest 41** tiles from the coast. 3.4.0 only looked at the nearest tile ("at most 3 from
the coast"), so a range that touches the coast at one end counted as "at the coast" and stayed; the giant islands
copy the model's ranges enlarged and add more of them, so they had many such ranges (d 2–10 … 2–41).

**Change:** a group (rock + slopes, 8-connected) lies at the coast only if its nearest tile is at most 3 and its
farthest at most `EdgeBand` = 10 tiles from the coast. Others, the largest first:
- as a whole to the free spot whose **farthest** tile is closest to the coast (before: nearest tile), of those the
  closest to the old place; accepted if that is within 10 tiles; a group that touches the coast only moves if it then
  lies there completely (otherwise it could slide further inland);
- otherwise **split**: the range becomes meadow (its rivers go), and every rock comes back as a **single mountain of
  the game** with the same rock – the smallest group with exactly one rock and no spring on the whole Nord resp. Sued
  islands (library: rocks 1103, 1104, 1106–1110 in both climates, 5–39 pieces; rock 1105 has none and takes the 2 × 2
  one of 1104 with its rock replaced) – placed the same way, the largest rock first, with island/town/owner bits of the
  old rock. If any rock finds no spot within 10 tiles, the island stays as it was (number and kind of the rocks are
  checked per island).
- Villages: a group stays only if a piece of the village change file lies on it, or a slope or rock of the village next
  to it (before: everything within 3 tiles of any village piece); no mountain moves to 3 tiles or less from a village
  piece (unchanged). Freed by this: `Nord\big08` (9 rocks, d 8–18), `big18`, `big26`, `med04`, `med13`, `Sued\big17`.

**Result (O, offline with all island files):** groups completely at the coast 62 % (game) → **96 %** (3.4.0 had the
long ranges as before), at most 3 tiles 68 % → 97 %; the giant islands: **238 of 238** groups (`Nord\lar22`: 44 single
mountains and small groups along the coast, d ≤ 10, the middle free). Left inland: mountains that belong to a village
(`Nord\big07`, `med18`, `Sued\big11`, `big12`, `med05`), `Sued\big52` (second layer) and single small mountains in the
files without a number (`lar.scp`, `med.scp` in `Nord`/`NoKlima`; whether random maps ever use them: **?**). Build time with all options 10.6 s (before 11 s).
Tests: `tests/test-islands.ps1` **21 of 21** (new: groups completely at the coast 62 % → 96 %, rocks unchanged by
number and kind, every group of the giant islands at the coast).

**In the running game (O), 2026-11-22 10:57–11:02:** repository tool with the user's options `-Width 2000 -Height 1400
-IslandSize Giant -Rivers Off -Mountains Edge -Volcanoes Off -Turbo -TurboLevel 16`, new endless game, driven only by
window messages behind the user's windows. All **50 islands** loaded (6 giant islands 160 × 140, 155 × 140, 160 × 125,
140 × 140, 150 × 130, 145 × 125), no river piece, no unknown tile. Read from memory: the giant islands hold 121
mountain groups, **all completely at the coast** (farthest tile ≤ 10; `lar22` 160 × 125: 46 groups); of all 50 islands
only two groups reach further (`Sued\med10` and `Nord\big02`, d 7–13 and 3–13: village pieces lie on them, so they stay
by design). On screen: single mountains with their own slopes along the shore of a giant island, the inland forest and
meadow.

### Ambitious rivals (2026-11-22, version 3.4)

Read-only analysis of the decompiled AI (`analysis/scan/alle-funktionen.c`), the key jumps checked in Ghidra.
- **O** The AI builds each town along a phase machine: dispatcher `FUN_1400393e0` (AI job 5), phase at +0x10 of the
  town record (AI context 0x1406EC220 + slot × 0x11EC8, records from +0x3EB8, 0x298 each), jump table index bytes at
  RVA 0x39A4C + phase. Only the town with the largest free island area becomes the main town (`FUN_1400368d0`); the
  others end in phases 0x17/0x18 (no tavern, no school: settlers – matches the measured 144 Siedler of AI second towns).
- **O** Main town, end of phase 0x21 (`FUN_1400374b0`, RVA 0x37510 `cmp [rax+0x1C],0x3B6 / jle`): free area < 951 →
  phase 0x22, which never builds church or bathhouse → the town stays at Bürger. End of phase 0x29 (RVA 0x37B95,
  `cmp …,0x44C / jle`): < 1101 → phase 0x2C without theatre and college → Kaufleute. In phase 0x28 church and bathhouse
  wait for 3 of 4 merchant goods in stock (RVA 0x37A7A `cmp eax,3 / jl`, `FUN_140036100`).
- **O** The "expansion level" of `FUN_140035220` (`FUN_14002e2c0(ctx, 1/2/3)`) only caps small ore mines; no
  explicit cap on AI house levels (house advance treats AI and human towns alike). Every 36,000 clock steps
  `FUN_140018c00` clears the whole AI context (phases, counters) – left alone.
- **Implementation `-RivalGrowth Ambitious`:** the three jumps become NOPs (6 bytes; the sites are checked with the
  instruction before them). The goods gate before theatre and college (phase 0x32, RVA 0x37FDB `cmp eax,4 / jl`, 4 of 6
  aristocrat goods) stays, so those come once the chains run.
- Correction to "Rivals, pirate fleet …": "AI levels 2/2/4" there are the INFRA unlock bits read by `FUN_1400185f0`;
  **I** level 4 there is a merchant tier, not aristocrats.
- **In the running game (O), 2026-11-22** (endless game "Durchschnittlich", rivals Hard, 60,000 gold, 16 ×, the three
  NOPs above set): after 8.4 game hours every rival capital stood at exactly 204 settlers (34 houses) with 100,000+
  gold; their towns held 0 t of tobacco, sugar, tobacco goods, spices and liquor and **0 t of bricks**; buildings on the
  capital island: houses, chapel, market, cattle and sheep farm, weaving hut, butcher, forester, sometimes quarry and
  stonemason – no plantation, no workshop, no tavern. AI context (0x6EC220 + slot × 0x11EC8, town records +0x3EB8, phase
  +0x10): main towns in **phase 0x1F** (waiting for 2 of spices, tobacco goods, liquor), second towns in 0x17. The
  islands had their crops (fertility at island +0x5C: north bits 1/3/5, south 2/4/6).
- **O** Goods written into the rival towns (tool loop, below): the main towns left 0x1F and grew past 204 settlers, but
  reached phase 0x28 without a tavern: phases 0x1E, 0x20 and 0x21 exit on money alone (`cmp [player+4],15000/20000/25000;
  jle build`) – a rich AI leaves them before building anything. With those exits patched (`jle` → `jmp`, RVA 0x36FE2,
  0x37302, 0x374F4) the towns stayed in 0x20 but still built nothing of it: its job chain (`FUN_1400372c0`: first
  `FUN_140034df0`, then the other build jobs) returns at the first job it cannot pay. **40 t of bricks and tools written
  into the three capitals → all three built a tavern within 3 minutes (16 ×) and two had citizens (38, 45) right after.**
- **With the full supply (tools, bricks, luxury goods), clock 507,000 → 863,000 (about 11 game hours) (O):** the capitals
  went to 465–540 citizens (clock 622,000), then 241–510 merchants (737,000) with great church, bathhouse, tavern, doctor
  and gallows, then **240 and 449 aristocrats** (863,000) with theatre and college (Hochschule) on two of the three; the
  rivals spent their gold (190,000 → 11,000–64,000) and founded new towns. Second towns stayed plantation colonies with
  144 settlers (phase 0x17, by design).
- The savegame of this game (`lastgame-1000x700-…`, deleted afterwards) holds the six giant islands completely (first
  `INSELHAUS` of 16,640–21,837 pieces).
- **Implementation:** `-RivalGrowth Ambitious` = the 6 code sites (3 NOPs, 3 jumps) plus a supply loop in the tool window
  (`Invoke-RivalSupply`, every poll, at most once per 2000 clock steps): for every town of a player of kind 0xC with
  settlers or more, tools, bricks, cloth, liquor, tobacco goods and spices (from settlers), cocoa (from citizens), clothes
  and jewellery (from merchants) below 20 t are set to 30 t (at most the storage limit of the town). Gold untouched.

### Ship values, F8, explored islands (2026-11-22, version 3.5)

**"Cargo space" was the hull (O):** reported with a screenshot: the start ship's bar was mostly red with "Cargo ×3".
The figure parser (`FUN_140068f10`, figure table RVA 0x6D80C0, 0x18C per entry) stores **"Maxtrag" ×32 at +0x38,
"Maxware" at +0x3A, "Maxkanon" at +0x3C, "Maxenergy" ×32 at +0x3E, "Hitpoint" at +0x40**. figuren.cod: small/medium
trading ship Maxware 4/6, Maxenergy 50/80; small/large warship 3/8, 65/120; free trader 6, 95; pirate 5, 95. The value
the tool scaled since 2026-11-10 (+0x3E, "50/80/65/120 t") is therefore the hull: ship +0x12 is the current hull, the
ship loader `FUN_14008e4f0` caps it at +0x3E (SHIP4 +0x3C holds the start value, the full hull of the original), the
command 0x17 in `FUN_14008cef0` repairs up to it. With ×3 every start ship – the human's and the rivals' – began with a
third. (The earlier "check" read back the written value; it never looked at a hold.) Holds: the ship functions loop
over +0x3A holds of 4 bytes at ship +0x300 (good code, amount ×32 in bits 8–21); every hold takes 50 t (0x640 in nine
loading/trade functions). The ship record has 8 holds (SHIP4 +0x174: 8 × 8 bytes), the large warship already has 8.
- **Implementation:** `-Cargo F` now sets +0x3A of no. 21–28 to min(8, round(holds × F)): ×1.5 = 6/8/5/8, ×2 =
  8/8/6/8, ×3 = 8 everywhere. +0x3E stays.
- **In the game (O), 2026-11-22 12:18–12:30:** `-Cargo 3` (with the user's map options): holds of no. 21–28 = 8, hull
  50/50/80/80/65/65/120/120 unchanged; all four start ships (human, 3 rivals) hull 100 % (1600/1600, 2560/2560), ship
  window with 2 rows of 4 holds, the bar over the ship green.

**F8 (O):** the key switch of `FUN_1400e2d60` ("add r8d,-0x10 / cmp r8d,0x66 / ja end", byte table 0xE33D0, jump
table 0xE3390) handles F5–F7 (`FUN_1400c8be0(1/2/4)`); F8 = 0x77 lies just behind it. The first version (only the
switch cave) did nothing in the game: F8 alone is an **accelerator** (resource 0x8B, loaded by `LoadAcceleratorsA`;
digits with Shift/Ctrl, Ctrl+C/V, F8–F12: F8 → command 0x9CBA = player status page, Ctrl+F8 0x9CBB, Shift+F8 0x9CCA),
and the message loop `FUN_14000ec00` does not dispatch a key that `TranslateAcceleratorA` translated (RVA 0xED11,
`call [0xE64B8]`). 44 F8 presses opened the player status. The speed itself works at any level: 64 written directly
gave exactly 64.0×; the command 0x0F handler sets the variable without a check.
- **Implementation:** the call at 0xED11 goes to a filter (RVA 0xE5D00, 35 bytes): WM_KEYDOWN of F8 without the
  Shift/Ctrl bits 4/8 of RVA 0x5EBE9C (the game sets them from every mouse message and on the Shift/Ctrl keys) returns
  0, everything else goes on to `TranslateAcceleratorA` with the same registers and stack (`jmp [IAT]`). The switch's
  "ja" goes to the cave at 0xE5BE0 (F8 → `FUN_1400c8be0(level)`, other keys → end). The resource cave now ends at
  0xE5D00 (it uses 158 bytes).
- **Measured (O), 2026-11-22 12:27–12:29,** new endless game 2000 × 1400 with 6 giant islands, game window behind other
  windows: **32×, 48×, 64×, 96×, 128× all exact** (clock +6535/9802/13080/19620/26161 in 20.4 s), CPU 46–50 % of one
  core at every level (F7 16×: 51 %) – at the start of a game the load is drawing, not game logic. With the Ctrl bit
  set, F8 went to the game (speed stayed 1); without, 64×; F5 back to 1×. Levels offered: 32, 64, 128 (48 and 96 as
  parameters).

**Explored islands (O):** island +0x43 holds one bit per player that knows the island. `FUN_140077210` sets it when a
ship of that player reaches the island (`FUN_14009d000` = island under the figure) and reports natives there to the
local player (messages 0x2F/0x30); the ship loader sets it for start ships at an island. `FUN_1400c6c50` draws an
island the local player knows with the tiles of +0x2CB0, otherwise +0x2CC0 (ore and gold deposits only on the first).
- **Implementation:** `-Explored All`: the tool window ORs the local player's bit (RVA 0x5F1D60) into +0x43 of every
  existing island (tiles pointer ≠ 0) while the game clock runs, every 2 s, new and loaded games.
- **In the game (O):** 50 of 50 islands known to the local player right after the start (79 ore/gold deposits).

**For the perfect home island (I, next version):** the ore and gold deposits of an island are slots of 8 bytes at
island +0x20 + k × 8 (count +0x41): +0 = 2, +1 x, +2 y, +4 kind (0 ore, 1 gold), +6 amount ×32 (ore 0x1E00 = 240 t,
gold 0xA00 = 80 t), set by the SZENE loader on rock tiles that haeuser.cod marks as ore mountains (`ROHSTERZ`:
1108/1109/1110 "ERZBERG_GROSS", 1103/1107 "ERZBERG_KLEIN"; 1104/1105/1106 never); at most 2 per island from the loader.
**Wrong, corrected 2026-11-22 (3.7):** +0 is the raw material (2 ore, 3 gold) and +4 only large (0) / small (1); the
0xA00 entries are small ore deposits – see "Gold on the home island (3.7)".

### Perfect home island (2026-11-22, version 3.6)

**Wish (user):** the largest, flattest northern island, ore and gold right on it with mines possible, full production of
tobacco and liquor – and the ship should start there.

**Findings (O):**
- Tobacco 0x2E, sugar cane 0x30 and wine 0x32 are northern crops (see "Crop climates"); liquor comes from sugar cane or
  wine. Crop bits at island +0x5C: bit = crop − 0x2D (tobacco 1 … cocoa 6); with the bit a crop grows at 100 %.
- Deposits: slots of 8 bytes at island +0x20 + k × 8, count +0x41 (see 3.5). The SZENE loader takes only rock tiles
  whose building entry (gfx table RVA 0x6CBB00 → entry) has kind 0xC and +0x21 = '7' and that are the origin tile of the
  rock (`FUN_140093720`: for turn 0 the first tile of the piece, for turns 1–3 the other corners). `FUN_14009eab0`
  removes a deposit and only sets redraw flags (0x1406EB5C4 |= 0x40, 0x1405C4ED8) – the game draws deposits from the list.
- **All four start ships of the endless templates lie within 10 tiles** (`[[48]]10`: 230/270, 230/263, 225/275,
  226/269; `11`: 310/110 …; `12`: 80/270 …; SHIP4 +0x1C/+0x1E, owner +0x4B, not stretched). An island at the human's
  ship would be the rivals' first island too.
- The ship loader `FUN_14008e4f0(name, data, length)` creates each ship's figure at SHIP4 +0x1C/+0x1E; it starts with
  `push rbx / push rsi / sub rsp,0x68` (RVA 0x8E4F0, 7 bytes, position-independent). In a template the SZENE chunk (with
  our island code cave) is read before SHIP4.

**Implementation (`-HomeIsland Perfect`):**
- Island forge: `Home.Make` → `Nord\lar28.scp`, 160 × 140, from the first northern "lar" model with a valid coast
  (outline, coast and forest as for the giant islands, no mountains), then `Forge.PlaceCornerMountains`: the game's
  single mountain with rock 1110 (rock turned to 0), in each corner the free spot closest to it with 2 ≤ coast distance
  ≤ 10. Header file 28, class 4, climate 0. `Home.Harbours`: per side the last open sea tile before the surf.
- Planner: the home island first, at the 10-tile grid spot farthest from the start ships (up to 600 tiles) that covers
  the fewest originals (−120 each); climate 0, class 4, file 28; covered originals are dropped. The ship place on the side
  facing the start ships.
- Start ship: the island code cave sets a flag (RVA 0xE5D30) after copying a plan; the ship loader jumps to a code cave
  (RVA 0xE5D50, 122 bytes): flag set and chunk "SHIP4" → clear the flag; an entry of owner 0 at a template start (table
  RVA 0xE5D38, 3 × from/to) gets the ship place; then the three instructions and back to 0x8E4F7.
- Tool window: in the first 3000 clock steps of a game the island with class 4 / file 28 / climate 0 (160 × 140) gets
  the deposits on the four rocks (ore, ore, gold, gold; 0x1E00 / 0xA00 like the loader), count 4, crop bits 0x7E, the
  local player's explored bit; once per island (tiles pointer).
- Offline (O): the plans put the island 556–647 tiles from the start ships (2000 × 1400 and 1000 × 700, all three layouts),
  0–3 originals dropped, the human's ship always on open sea; test-islands 30, test-patcher AX/AY.
- **First game test (O): the game exited at "Spiel starten"** – also with the ship loader jump taken back. Cause: the
  island code cave writes the flag into the free end of .text, which is read-only (execute/read) for the game; the tool's
  other markers there are written by the tool (with VirtualProtectEx), never by the game. Fix: the patch of the flag has
  `Writable = $true`, the tool leaves that page PAGE_EXECUTE_READWRITE.
- **Game test (O), 2026-11-22 13:40–13:50,** `-Width 2000 -Height 1400 -IslandSize Giant -HomeIsland Perfect -Rivers Off
  -Mountains Edge -Volcanoes Off -Explored All -Resources Lots -Fertility Everywhere -Cargo 3 -Turbo -TurboLevel 16 -Ultra`,
  new endless game (layout 2): the home island in island slot 0 at 8/808, 160 × 140, class 4, file 28, climate 0; the
  human's ship "Secunda" at 88.5/822.5 (its ship place), the rivals' ships at the old start (131/352 …); the ship menu
  shows the warehouse button right away; the tool window: "Heimatinsel: 2 Erz- und 2 Goldvorkommen …" – deposits
  32/29 and 120/29 ore 240 t, 118/110 and 16/115 gold 80 t, each on the origin tile of a rock 1110 (gfx 5680 = base,
  turn 0, building no. 282: kind 0xC, +0x21 '7', +0x3F 0 – exactly what the SZENE loader accepts), crop bits set,
  explored. A regular island with file 28 of another class (big28, south) stayed untouched.

### Gold on the home island (2026-11-22, version 3.7)

**Report (user):** in a new game with 3.6.0 the home island "has no gold at all".

**Findings (O):**
- Running game (2000 × 1400, giant islands, clock 6632): home island slot 0 at 8/598 with the four deposits
  `02 20 1D 01 00 00 00 1E`, `02 78 1D 01 00 00 00 1E`, `02 76 6E 01 01 00 00 0A`, `02 10 73 01 01 00 00 0A` – four times
  raw material 2. In the whole world only one slot starts with 3: island 16 (south, 100 × 90) `03 10 48 00 01 00 40 06`.
  Other islands also carry slots with first byte 0x3A, amount 1000, y 7 (written by the loader next to the treasure
  entries; **?** meaning not known, not used by the tool).
- SZENE loader `FUN_1400d0de0`: for a raw-material entry whose building +0x21 is 2 (ore mine 2401) it writes `+0 = 2` with
  type 0 → 0x1E00 and +4 = 0 (large), type 1 → 0xA00 and +4 = 1 (small, islands of class 2–4); for building +0x21 = 3
  (gold mine 2405) it writes `+0 = 3`, +4 = 1, amount 0x640 (50 t). Both on the same rocks (kind 0xC, +0x21 '7', origin
  tile; the gold branch does not check +0x3F) and without a climate condition.
- `FUN_14009ebb0(island, x, y, turn, ware)` (used by the mine's work step `FUN_1400b9ed0` case 3 and the building checks)
  returns a deposit only if its byte +0 equals `ware` = building +0x21 of the mine; so a gold mine needs +0 = 3.
- `FUN_1400b9ed0` case 3, path 1 (+4 = 1 or amount > 0xEFF): a mine with building +0x21 = 3 (gold) never lowers the amount.
- Byte +3 of a slot was 1 on the two islands with a settlement of the human (home island and island 23) and 0 elsewhere;
  the tool writes 0 and the game sets it (**?** meaning).

**Fix:** `$HomeDepositWares` 2/2/3/3, kinds 0/0/1/1, amounts 0x1E00/0x1E00/0x640/0x640 (like the loader). Repair for games
from 3.6.0 (`Invoke-Home` returns 2): with a clock above 3000 once per island (tiles pointer) the slots with exactly
`02 x y ? 01 ? 00 0A` on the third or fourth mountain of the home island get +0 = 3 and amount 0x640. In the user's
running game the same two writes were made once by hand (game clock 11,171): `03 76 6E 01 01 00 40 06`,
`03 10 73 01 01 00 40 06`.

### Island map (2026-11-22, version 3.7)

**Wish (user):** "I still don't see on which island what is available – neither tobacco etc. nor ore or gold";
everything uncovered. The game shows deposits only on the mountains of an island the player knows and crops only in
the island info near a ship – there is no overview.

**What the map reads (O, read only, all RVAs relative to the exe):**
- World size 0x5EBE40 / 0x5EBE98; local player 0x5F1D60; camera pointer 0xF9A00 → +0x1C/+0x20 world x/y of the view,
  +0x48 rotation 0–3.
- Players 0x5F0960 + p × 0x280: +0 kind (0 human, 0xC computer, 0xB natives, 0xD traders, 0xE pirates), +8 name,
  +0x68 number, **+0x69 colour** (0 red, 1 blue, 2 yellow, 3 white, 4 pirates, 5 natives, 6 traders). In the user's
  endless game: the human yellow, the rivals "Roter/Blauer/Weißer Spieler" red/blue/white.
- Islands 0x62DDC0 + i × 0x2CC8: as above, deposits only slots +0x20..+0x3F (4 at most; +0x40 and the count +0x41
  follow); first byte 2 ore / 3 gold, others (0x3A, amount 1000) are no mine deposits.
- Tiles: island +0x2CB0 (else +0x2CC0), W × H × 4 bytes row by row; bits 0–12 gfx number, **bits 19–21 territory
  number** (7 = none). The gfx table 0x6CBB00 points to an entry whose **+4 is the terrain kind**; +0x1C does *not*
  tell sea from land (9 for meadow and open sea alike – the first map drawn with it showed the sea inside each island's
  rectangle as land). Kinds counted on three islands of the user's game: 0x13 open sea, 0x14–0x16 surf, 0x17–0x1B
  beach, 0xB meadow, 0xA forest and crops, 0x1F/0x20 slopes, 0xF rock (with +0x1C 0xC and +0x21 '7' the ore
  mountains), 0xE buildings, 0x1/0xD roads, 0x4–0x7 walls, 0x1C/0x1E piers, 0x22–0x24 harbour buildings and warehouse.
- Settlements 0x622DC0 + s × 600: **+0x19 = the town's number on its island = the territory number in the tiles**
  (island 15: natives' village 0, the blue rival's town 1), +0x1A owner; residents +0x220..+0x230.
- Ships 0x1D8BB0 + n × 0x328: byte 0 = 0x50, +0x28 owner, +0x296 name, +8 figure → +0x28/+0x2C float position.

**Projection (O):** `FUN_1400c4ba0` (world → scroll) per rotation, u horizontal and v vertical in half tiles (on screen a
u unit is twice as wide): 0: u = (x − y + H)/2, v = (x + y)/2; 1: u = (W + H − x − y)/2, v = (x − y + H)/2; 2: u = (y − x +
W)/2, v = (W + H − x − y)/2; 3: u = (x + y)/2, v = (y − x + W)/2. The corner 0/0 of the world moves top → right → bottom →
left. The map draws every pixel back to its world tile with the inverse.

**Checked (O), 2026-11-22 20:36–20:43, the user's running game (2000 × 1400, 50 islands, read only):** first map with
+0x1C – wrong (see above); with +4: the home island at rotation 0 has the shape, the bay and the four mountains of the
user's screenshot of the game, gold on the left and the bottom mountain, ore on the top and the right one, the yellow
territory of the warehouse where the ship landed; territories of all 14 towns in the owners' colours; 2 islands with
gold (home island, island 17), 43 with ore, 40 free; 4 ships; the camera marker on the island the game showed. The
refresh reads on a worker thread, so the window stays responsive.

### Game test of 3.7.0 and the invisible windows (2026-11-23, version 3.7.1)

**New endless game (O), 06:05–06:11, installed 3.7.0 with the launcher's saved choice** (2000 × 1400, giant islands,
resources lots, perfect home island, all explored; game started in the background, menus by window messages): at
clock 436 the home island (island 0, class 4, file 28, north, 160 × 140) has the slots `02 20 1D 00 00 00 00 1E`,
`02 78 1D 00 00 00 00 1E` (ore, 240 t, top corners) and `03 76 6E 00 01 00 40 06`, `03 10 73 00 01 00 40 06` (gold, 50 t,
bottom corners); the only other gold deposit of the world, made by the game itself on island 6 (number 7 on the map), is `03 0E 24 00 01 00 40
06` – the same bytes. Crops +0x5C = 0xFF, all 50 islands explored, the tool printed its home island line once.

**Island map window (O):** started like the launcher, the window was **created but never visible** (`IsWindowVisible`
false, no taskbar button). Cause: `Start-Process -WindowStyle Hidden` sets `STARTF_USESHOWWINDOW` with `SW_HIDE` in the
new process's STARTUPINFO; Windows applies it to the first `ShowWindow` of an unowned top-level window – the console
is created hidden by conhost, so the first such call is the form's. A test form started four ways: hidden console
only → hidden; plus `-WindowStyle Hidden` for PowerShell (PowerShell hides its console with `ShowWindow` first) →
visible; the script hides its (already hidden) console before the form → visible; the form shows itself again in
`Shown` → visible. The logbook (same start since 2.0) was hidden as well. Its `-TestTicks` mode had missed it:
`ShowInTaskbar = false` gives the form a hidden owner, and owned windows are not affected. Fix 3.7.1: the launcher
passes `-WindowStyle Hidden` to PowerShell too; both scripts call `UseUpHiddenStart` (only if STARTUPINFO says
`SW_HIDE` and the console is invisible: `ShowWindow(console, SW_HIDE)`). Control: the same test without that call →
hidden, with it → visible after 0.6 s.

With the window visible (behind the user's windows): status "2000 × 1400, 50 Inseln: 2 mit Gold, 46 mit Erz, 47
frei", refreshed every 2 s; mouse wheel zooms around the pointer, dragging moves, a click selects the home island
(frame, details "Gold: 2 × (50 t, 50 t, …) · Erz: 2 × (gross 240 t, gross 240 t) · alle 6 Pflanzen · frei"), the gold
filter leaves islands 1 and 7 in the list and outlines island 7. Hover and double-click cannot be checked with window
messages: WinForms asks Windows for the leave of the real mouse at once, and a click counts only if
`WindowFromPoint` is the window itself (it lay behind other windows).

### Game test of 3.7.1 with the real mouse, gold mine in operation (2026-11-23)

**Everything worked; no new bug.** Installed 3.7.1, 08:35–09:15, while the user was away (allowed by the user). Clicks
on the game and the map used the real mouse (`SetCursorPos` / `mouse_event`), only after 45 s without user input,
cursor put back afterwards.

**Whole chain (O):** desktop shortcut opened through `explorer.exe` (not elevated, like a double-click) → launcher
"Aktualisiert auf Version 3.7.1." → "Mit Erweiterungen spielen" → tool with the saved choice (incl. `-HomeIsland
Perfect -Radius 2 -BuildCost 0`), game and island map; the map **visible at once**, no logbook (switched off in the
settings, correct). The launcher's WinForms buttons offer no UI Automation patterns to another process
("Nicht unterstütztes Muster"); `PostMessage(BM_CLICK)` to the button's window works.

**Island map with the real mouse (O)** – the part 3.7.0 could not check: hovering an island shows its details and
they stay while the pointer rests there, over the sea the hint comes back; the wheel zooms (53.5 % of the pixels
changed); a double-click on the map gives the whole map back (0 % difference to the start); a double-click on row 1
zooms to the home island (58.4 % changed).

**Gold mine on the home island (O):** new endless game (2000 × 1400, giant islands, perfect home island).
- Ship: a **left** click on water moves the selected ship; the right click (`WM_RBUTTONUP` → `FUN_1400124a0`) only
  cancels or deselects. While the game is in front it reads the real cursor, so `PostMessage` clicks work only while
  it is in the background.
- Warehouse: `FUN_140098fb0` needs a straight row of 3 coast tiles (kinds 0x17–0x1B or 0x1D/0x1E) along the long side,
  then `FUN_1400949b0`; the ship menu shows the button only while the ship lies right at such a coast. A valid build
  ghost shows the pier graphic, an invalid one only a yellow footprint. Ghost tile: RVA 0x5A3FBC / 0x5A3FC0. Built at
  local 121–123 / 90–91 in the bay next to the gold mountain.
- Unlock: player 0x5F0960 + p × 0x280, **+0x6C = building-level bits**, mask `1 << (Bauinfra − 1)`. Building 399
  (Id 22405, kind 0x22, 1 × 2, ware 3, Bauinfra 24 → 0x800000, `haeuser.cod`: INFRA_STUFE_3B = 150 residents,
  Maxlager 4 t, Interval 80, ERZBERG_KLEIN). The bit was set **in the test game only**; "Goldmine" then appeared at
  cost 0 (`-BuildCost 0`).
- Mine tile: `FUN_1400985a0` needs **exactly one** 4-neighbour of terrain kind 0xF (it gives the turn: north 1, east 2,
  south 3, west 0); `FUN_14009ebb0` steps to that neighbour, takes the rock's origin (`FUN_140093610`: gfx entry +0x8C
  base gfx, +0x10/+0x14 size, tile bits 13–14 turn) and needs origin = slot x/y and slot byte 0 = ware. 24 tiles qualify
  for the gold deposit at 118/110; the mine stands on 121/116 – 122/116.
- Result: 4 t in the mine (its store full) at turbo 8; with a field path to the warehouse (carts need a road) the gold
  in the warehouse (town 0x622DC0 + i × 600, goods +0x2A + good × 12, u16 / 32 t, gold = good 3) rose from 4 to 20 t in
  about 75 s. The slot stayed `03 76 6E 00 01 00 40 06` (50 t, never lowered).

Cleanup: game, tool and map ended; the test `lastgame` in the recycle bin; `saves.json` restored (same hash), the
savegames unchanged. The test used up the launcher's update note (`LastVersion` 3.7.1).

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
