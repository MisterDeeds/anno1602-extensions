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

Decrypt/encrypt `.cod` files: `tools/cod.ps1` (every byte negated).
Map size: `tools/anno-patcher.ps1`, start together with the game: `tools/start-big-world.cmd`, offline test `tools/test-patcher.ps1`, island plan as an image `tools/show-island-plan.ps1`, player guide `tools/README.txt` (German: `tools/README.de.txt`).
Ghidra helper scripts: `AnnoAsm.java` (instructions from an address), `AnnoPatchDis.java` (put bytes into Ghidra's in-memory program only and disassemble them).
Note: `tools/ghidra-scan.cmd` needs `GHIDRA_INSTALL_DIR` and `JAVA_HOME` in the process environment. If the shell was started before the variables were set, they are missing ("Das System kann den angegebenen Pfad nicht finden", the system cannot find the path specified); in that case take them over from the user or system variables first.

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
(`tools/ghidra-scan.cmd`, scripts in `tools/ghidra_scripts/`, results in `analysis/scan/`).
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
- **O** Replacement at `0x1400D0E29`: `E9 D2 42 01 00 66 90` (`JMP 0x1400E5100`, 2-byte NOP). Code stub at `0x1400E5100` (103 bytes), disassembled by Ghidra (`tools/ghidra_scripts/AnnoPatchDis.java`):

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

**Offline test (O):** `tools/test-patcher.ps1`, **128 of 128** passed. New: case G (`-NoIslandSpread` leaves the jump and the code stub untouched) and case I, a functional test: in the helper process the real code stub runs at its real address in the image, called through a thread with the real `SZENE` section from `[[48]]10.szs` (the return path replaced by `pop r15; ret` only in the helper process's image). Result: all 1,172 bytes as expected for 1000 × 700 (island 0: (280, 90) → (560, 180)), 750 × 525, 2000 × 1400 and 500 × 350 (unchanged). With island count 60 nothing changes; the helper process keeps running afterwards.

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
- **Maps of the plans:** `analysis/test/inselplan-1000x700-anordnung-{0,1,2}.png` (historic file names; `tools/show-island-plan.ps1` now writes `island-plan-<w>x<h>-layout-<n>.png`).
- **In game (O), 21:50:** started via `tools/start-big-world.cmd`, new endless game "Durchschnittlich". The game chose layout 1. Island table in memory: **48 islands, all 48 exactly at the planned position**, all at most as large as their class, extent x 47–985, y 24–686. No crash while generating. Evidence: `analysis/test/17-mehr-inseln-start*.png`.
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

**Implementation in `tools/anno-patcher.ps1`:**

| Option | Location | Method |
|---|---|---|
| `-Residents F` (1–3) | `0x6BA02C + no. × 0x50`, int | like storage: wait until loaded, check original (128/384/960/1600/2560) or target, set all |
| `-Cargo F` (1–3) | figure no. 21–28 +0x3E, 16 bits | like storage, originals 1600/2560/2080/3840 (2 entries each) |
| `-Production F` (1–3) | building 0–499 +0x3A, 16 bits | after `haeuser.cod` has been read (storage value of Kontor I ≠ 0) and the table is stable: every interval ≠ 0 → max(1, round(v / F)); marker `NUFR` + F × 100 at RVA `0xE5F70` against dividing twice |
| `-Turbo` | RVA `0xE3376` | `B9 04 00 00 00` → `B9 08 00 00 00` (code place, all or nothing) |
| `-RivalGold N` | TIMERS code stub | after the start gold: `cmp [game clock],1000; jae +30; mov [money slot 1/2/3],N` (code stub now up to 83 bytes, room for up to 128) |

**Offline test (O):** `tools/test-patcher.ps1`, new cases N–R, total **284 of 284** passed. Case R executes the real code stub: player 50,000, rivals 3 × 30,000, trader (slot 4) unchanged; with a savegame clock nothing changed.

**In the real game (O), 2026-11-10 19:00:** installed tool with `-Pirates Strong -RivalGold 60000 -StartGold 50000 -Residents 2 -Production 2 -Storage 3 -ShipSpeed 2 -Cargo 2 -Turbo`, game via Ubisoft Connect (restart caught again, PID 5344 → 14268).
- All 15 code places set.
- The resident and cargo originals matched exactly (no abort).
- 125 work intervals halved.
- Checked read-only in the main menu (`tools/check-game.ps1`): world 1000 × 700, F7 `B9 08 …`, residents 4/12/30/50/80, cargo space 100/160/130/240 t, ship speed 0.1, storage Kontor I 90 t, marker `NUFR x2`.
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

**Launcher window:** `tools/launcher.ps1` (WinForms). All options as drop-down lists, the last choice in `%APPDATA%\Anno1602-Extensions\settings.json` (before the English renaming `%APPDATA%\Anno1602-Erweiterungen\einstellungen.json`, migrated once). "Mit Erweiterungen spielen" (Play with extensions) starts the tool in its own window and after 3 s `uplay://launch/16236/0`; "Original starten" (Start original) starts only the game. The launcher shows German on a German Windows and English otherwise.

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
- Island code stub with the call: 204 instead of 199 bytes; the island table may now extend up to `0xE5C00`.

**Island size (O):**
- Island files of class lar: `NORD` 6, `SUED` 7, `NORDNAT`/`SUEDNAT` 0 (big: 68/64/37/40).
- First game test with `-IslandSize Huge` (plan layout 2: 17 big, 23 lar): **only 32 of 40 islands loaded** (17 big, 15 lar). 8 lar islands were missing.
- **Implementation:**
  - At most 10 lar per map, otherwise big. Large = originals one class bigger (where there is room), extra islands alternately lar/big; Huge = everything lar/big.
  - Changed originals get a random island file (0xFFFF).
  - Area of the island rectangles at 1000 × 700: Normal 108–122 thousand (15–17 %), Large 201–229 thousand (29–33 %), Huge 216–246 thousand (31–35 %).
- **Second game test (O), 2026-11-11 16:40:** `-IslandSize Huge -Resources Lots -Residents 5 -Production 2 -Storage 3 -Turbo`, layout 2. **40 of 40 islands loaded** (30 × 70×60, 10 × 100×90). In addition 69 ore deposits on all 40 islands and 254 fertilities (`tools/check-islands.ps1`). World generation ran through without hanging.

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

**Memory layout at the end of .text:** 0xE5100 island code (204) · 0xE5200 island table (2,452) · 0xE5C00 raw materials/villages (up to 118) · 0xE5E00 pirate fleet (17) · 0xE5E20 traders (14) · 0xE5F70 marker NUFR (8) · 0xE5F80 TIMERS (up to 83).

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

**Package:** `Documents\Anno1602-Erweiterungen.zip` rebuilt and installed with the installer of that time (`installieren.ps1`); the installed files match the sources by hash. The installed version finds all 25 places with the "Alles gross" values (`-CheckOnly`). (The ZIP package mode has since been dropped; `install.cmd` now installs from the repository layout with `tools/install.ps1`.)

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

**Tools:** `tools/scenario-lib.ps1` (reading/writing .szs, `New-Mission`, `Set-Islands`), `tools/build-scenarios.ps1` (6 chapters from the endless templates: mirrored layout, single islands one class bigger, raw-material quantities, villages, gold, difficulty, pirate flag, mission and text; check for map boundaries and overlaps). Output `tools/scenarios/`, with `-Install` into "Own Scenarios".

**Campaign:** Landung (Landfall, Einfach) · Gewürzfieber (Spice Fever, monopoly) · Zwei Kolonien (Two Colonies) · Schwarze Segel (Black Sails; weapons store, pirates) · Der Eroberer (The Conqueror; defeat players 1–3) · Krone der Inseln (Crown of the Isles; 3 towns, 1,200 aristocrats, Schwer). All 6 decoded offline and checked (goals, geometry, texts, player data, flags).
- **In game (O):** all 6 chapters in the list. Chapter 2 loaded: 18 islands, spices on 4 islands, 4 villages, gold 25,000 × 4, mission monopoly 0x2F (island count set to 4 by the game) + town 500/2/250, text with umlauts. Afterwards the spice quantity was lowered to 2 and the text changed to "jede Gewürzinsel" (every spice island).
- Chapter 1 loaded in game (2026-11-11 21:50, without the tool): 20 islands, 6 villages, gold 30,000/15,000 × 3, difficulty 0, flags 0x9, mission 250/1/150 + balance. Chapters 3–5 not loaded individually (same build path, `tools/check-scenarios.ps1` checks all of them). The difficulty balance has not been played through.

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

**Start fleet:** extra ships for the human = copy of his SHIP4 entry with a new name, slot (+0x46 = next one), figure type (+0x48: 23 large trading ship, 25/27 small/large warship), cargo space (+0x3C: 2,560/2,080/3,840) and full number of cannons (+0x42: 10/8/14; cannons = ship +0x2AE, cf. message 0x19), without cargo, 7–9 tiles next to the start point (for this the start point is 14 tiles from every island). Schwarze Segel and Goldrausch: small warship; Eroberer: large warship; Krone: large trading ship.

**Launcher:** button "Für Kampagnen" (For campaigns) (1000 × 700, more islands, turbo 16-fold, gold "Wie Schwierigkeit" (as per difficulty), everything else default). A note on the own scenarios at the top of the window.

**Endurance run (O), 2026-11-11 21:57–22:57:** savegame `lastgame-1000x700-20261111-183442` with all "Alles gross" options (among others rivals Hard, pirates Active, fleet Large, traders Lots, turbo 16), F7; at speed 1 the measuring script sends F7 via `PostMessage` (`WM_KEYDOWN` 0x76, works). 60 of 60 measurements responsive, 429–491 MB without growth, game clock 464,523 → 987,617 = **14.5 game hours**, F7 ten times automatically. The rivals expand their 2–4 towns (2,201/1,604/2,606 residents, gold up to 2.3 million), but found no new ones; pirates 9 ships, traders 15.

**In game after the corrections (O):** "Der Eroberer" (big version): own large warship "Königsadler" in slot 4, figure type 27, 14 cannons, next to the start ship; 50 islands. "Wettlauf 4" (big version, ships previously inside a 100×90 island): all ships in open water.

**Scenarios now (13):** Smaragdinseln 1–6, Wettlauf 1–4 (Erster Hafen, Bürgerstolz, Kaufmannsrepublik, Die Krone – First Harbour, Citizens' Pride, Merchant Republic, The Crown; goals from 300/150 settlers up to 1,500/600 aristocrats, adjusted after measuring, see above), challenges Inselreich (8 towns, 3,000 residents in total), Handelsimperium (50 t jewellery, 80 t clothes, trade balance +300), Goldrausch (60 t gold, 40 t jewellery). `tools/check-scenarios.ps1` checks all of them: sections, mission, race setting, both maps (boundaries, overlaps), raw materials, villages, gold, flags.

### Long run with all options (O), 2026-11-09 08:52 – about 19:00, evaluated 2026-11-10

- Tool with `-Pirates Strong -ShipSpeed 2 -StartGold 50000 -Storage 3`, 1000 × 700, layout 0 (43 islands). The test session then broke off with a connection error of the Claude app; the tool ended with exit 4 without renaming `lastgame.gam`.
- **The images `30-alle-optionen-langlauf-030min` … `210min` are byte-identical** (same SHA-256). That is a capture error (window in the background, `PrintWindow` returns the old image), not a hang: the game kept writing autosaves, the last one `lastgame.gam` at 18:53:29.
- This last savegame (now `lastgame-1000x700-20261109-185329.gam`): game clock 440,208 (for comparison 38,543 in the options test at 08:22), 43 islands up to x 947 / y 628.
- Growth compared with 08:22 (section sizes in the savegame): `SHIP4` 3,052 → 10,900 bytes, `KONTOR2` 7,028 → 13,052 (7 → 13 warehouses), `PRODLIST2` 1,512 → 7,392, `SIEDLER` 1,152 → 3,168. **No crash in about 10 hours.**
- **Pool `ROHWACHS2`:** 2,032 of 262,512 slots occupied (0.8 %).
- **I** The fixed pools are not expected to fill up at 1000 × 700, even over many hours.
- **Storage:** `KONTOR2` = per warehouse a 4-byte header + 50 goods of 20 bytes each (structure like mdcii-engine `KontorGood`, stock `lager` uint32 in 1/32 t at +12).
  - Stocks above 30 t also occur in normal savegames without the tool (`savegame-17.gam` up to 350 t), because market buildings and warehouse levels raise the town's limit.
  - **I** The storage option therefore cannot be proven from savegames. What remains proven: the limit of a newly built warehouse is 2,880 (90 t) in memory instead of 960 (see "Game test with all options").
- **Clean-up 2026-11-10:**
  - `lastgame.gam` (test, 18:53) renamed to `lastgame-1000x700-20261109-185329.gam`.
  - The state before all tests (2023-04-10, SHA-256 `B7C4BFB9…62FE`) copied back from `Savegame-Sicherung-20261108-191850` and verified by hash.
  - Backup folders: 13 of them, 174 MB in total.

### Long run "Schwer" (O), 2026-11-09 07:45–08:10

- 1000 × 700, layout 0 (43 islands), game in the foreground (the monitoring brings it to the front every minute), fourfold.
- 25 minutes: always responsive, 433–494 MB, autosaves 07:55:58 and 08:05:58. All three AIs settle in the **new** area (yellow bottom left, blue bottom right, white top right). Flags 0x8, no pirate ships yet. Evidence `25-schwer-langlauf-30min*.png`.
- Aborted in favour of the game test of the options; afterwards the long run with options (see "Long run with all options").

### Experiment: `tools/anno-patcher.ps1`

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
- Start file `tools/start-big-world.cmd`: starts the tool in its own window (stays open) and then the game via `uplay://launch/16236/0`; further arguments such as `-Width 750 -Height 525` are passed through. Pause via `ping` instead of `timeout` (which aborts without console input).
- Tested in game (O): start file used three times, each time the restart was caught and the values set. Protection for "Spiel fortsetzen" triggered twice: `lastgame.gam` (written by the game at 21:45:26 and 21:59:11) renamed after the end of the game to `lastgame-1000x700-20261108-214721.gam` and `…-220145.gam`.
- Restart of the game (added after the game test): the first `Anno1602.exe` process exits again immediately after a start via Ubisoft Connect, and a second one starts. The previous version patched the first one, then failed with "Lesen bei RVA 0x5EBC80 fehlgeschlagen (Fehler 299)" (read at RVA 0x5EBC80 failed (error 299)), and the second one ran unpatched. Now the tool detects the exit (`GetExitCodeProcess`) and waits for the next process.

### Test run 2026-11-08

**Resolution (O):** 3 monitors, all 2560 × 1440 (main monitor `DISPLAY5`, RTX 4090, 143 Hz). Registry `HKCU\Software\Ubisoft\Anno1602HistoryEdition` before: `SCREENMODE` = 2560, `SCREENMODEY` = 1440, `WINDOW_MODE` = 2, `UI_SCALE` = 1000, `MONITOR_INDEX` = 0, `VSYNC` = 1. So the game is already set to WQHD, matching the monitor; in game it ran at 2560 × 1440 in full screen. Nothing changed (after = before).

**Offline test (O):** `tools/test-patcher.ps1` loads the exe copy `analysis/bin/Anno1602.exe` in a helper process only as an image (`LoadLibraryEx` with `DONT_RESOLVE_DLL_REFERENCES`: sections at load address + RVA with the real memory protections, no game code runs, no DLL is loaded) and runs the tool against it. Result with the final version: **93 of 93 checks passed.**

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
| Save to a new slot | yes: icon "neuer Spielstand", name `Welt1000x700` → `Welt1000x700.gam` (395,966 bytes). No existing slot overwritten (`savegame-10.gam` checked after a misclick: unchanged). | `09-gespeichert-Welt1000x700.png` |
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
