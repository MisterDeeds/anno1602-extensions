<#
.SYNOPSIS
  Island map: a window next to Anno 1602 History Edition that shows every island of the running game at a glance -
  where the ore and gold deposits are, which crops grow at 100 %, who has settled where, your ships and where you look.

.DESCRIPTION
  The window attaches to the running Anno1602.exe and only READS its memory (OpenProcess with
  PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, never a write). It refreshes every 2 seconds and survives the game not
  running yet, being closed or being restarted. It works for every game: endless games, scenarios and savegames.

  The map is drawn like the game's own view: as a diamond, turned the same way as the game (the camera's rotation),
  with the real outline of every island (tile grid of each island), northern islands green and southern islands
  olive, the mountains grey, the territory of every player tinted in its colour, a gold or grey marker on every gold
  and ore deposit (exactly on its mountain), the island number, your ships and the spot the game shows right now.
  Mouse wheel: zoom; drag: move; double-click: whole map. Hovering an island shows everything about it; the list on
  the right shows every island and can be filtered (gold, ore, a crop, free islands, north, south).

  Memory layout: see docs\FINDINGS.md, section "Island map (3.7)". The text is German on a German Windows and English
  otherwise ($env:ANNO_EXTENSIONS_LANG = 'de'/'en').

.PARAMETER SelfTest
  Offline test without the game: builds a memory image of a small world, checks reading, projection in all four
  rotations, filters and the window, writes PNG files (German and English) and exits with 0 (all passed) or 1.
#>
param(
    [switch]$SelfTest,
    # Folder for the PNG files of -SelfTest (default: %TEMP%\anno-islandmap-selftest).
    [string]$SelfTestFolder,
    # For testing only: read the game once, render the window (off-screen) to this PNG and exit.
    [Parameter(DontShow)][string]$Snapshot,
    # For testing only: size of the -Snapshot window, rotation override (0-3) and zoom on one island (number 1-50).
    [Parameter(DontShow)][int]$SnapshotWidth = 1500,
    [Parameter(DontShow)][int]$SnapshotHeight = 860,
    [Parameter(DontShow)][int]$SnapshotRotation = -1,
    [Parameter(DontShow)][int]$SnapshotIsland = 0,
    # For testing only: -SnapshotIsland only selects (no zoom); tick the filter with this text.
    [Parameter(DontShow)][switch]$SnapshotNoZoom,
    [Parameter(DontShow)][string]$SnapshotFilter,
    # For testing only: print what the map reads (islands, deposits, towns, ships) and exit.
    [Parameter(DontShow)][switch]$Dump,
    # For testing only: attach to this process (an exe image loaded by a test) instead of Anno1602.exe.
    [Parameter(DontShow)][int]$TestProcessId = 0,
    [Parameter(DontShow)][long]$TestBase = 0,
    # For testing only: the normal window (own single-instance lock), off-screen, closes itself after this many seconds.
    [Parameter(DontShow)][int]$TestShowSeconds = 0
)
$ErrorActionPreference = 'Stop'

$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
$ExpectedHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'   # same exe as anno-patcher.ps1

if (-not ('AnnoIslandMap.MapForm' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

namespace AnnoIslandMap
{
    public static class L
    {
        public static bool German;
        public static string T(string en, string de) { return German ? de : en; }
        public static string Num(int n) { return n.ToString("N0", CultureInfo.GetCultureInfo(German ? "de-CH" : "en-US")); }
    }

    public static class Native
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr done);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr h);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr h, out uint code);
        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr h, int cmd);
        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr h);
        [StructLayout(LayoutKind.Sequential)]
        private struct STARTUPINFO
        {
            public int cb; public IntPtr lpReserved, lpDesktop, lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern void GetStartupInfo(ref STARTUPINFO si);

        // Started hidden (the launcher starts the map with a hidden console): Windows applies that "hidden" to the first
        // window the process shows, so the map would never appear. Hiding the console (hidden anyway) uses it up, as
        // "powershell -WindowStyle Hidden" does. True if it was needed.
        public static bool UseUpHiddenStart()
        {
            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            GetStartupInfo(ref si);
            if ((si.dwFlags & 1) == 0 || si.wShowWindow != 0) return false;
            IntPtr console = GetConsoleWindow();
            if (console == IntPtr.Zero || IsWindowVisible(console)) return false;
            ShowWindow(console, 0);
            return true;
        }

        public static byte[] Read(IntPtr h, long address, int size)
        {
            if (size <= 0) return new byte[0];
            byte[] buf = new byte[size];
            IntPtr done;
            if (!ReadProcessMemory(h, new IntPtr(address), buf, new IntPtr(size), out done)) return null;
            return done.ToInt64() == size ? buf : null;
        }

        public static bool IsRunning(IntPtr h)
        {
            uint code;
            return GetExitCodeProcess(h, out code) && code == 259;
        }
    }

    // Where the bytes come from: the running game or a test image. Rva = relative to the exe, Abs = a pointer value.
    public abstract class Source
    {
        public abstract byte[] Read(long rva, int size);
        public abstract byte[] ReadAbs(long address, int size);
    }

    public sealed class ProcessSource : Source
    {
        public readonly IntPtr Handle;
        public readonly long Base;
        public ProcessSource(IntPtr handle, long imageBase) { Handle = handle; Base = imageBase; }
        public override byte[] Read(long rva, int size) { return Native.Read(Handle, Base + rva, size); }
        public override byte[] ReadAbs(long address, int size) { return Native.Read(Handle, address, size); }
    }

    // Test image: written byte blocks (later writes win), unwritten bytes read as 0; pointers are Base + rva.
    public sealed class ImageSource : Source
    {
        public const long Base = 0x140000000L;
        private readonly List<KeyValuePair<long, byte[]>> parts = new List<KeyValuePair<long, byte[]>>();
        public void Write(long rva, byte[] data) { parts.Add(new KeyValuePair<long, byte[]>(rva, (byte[])data.Clone())); }
        public override byte[] Read(long rva, int size)
        {
            byte[] r = new byte[size];
            foreach (KeyValuePair<long, byte[]> p in parts)
            {
                long s = Math.Max(rva, p.Key), e = Math.Min(rva + size, p.Key + p.Value.Length);
                if (s < e) Array.Copy(p.Value, s - p.Key, r, s - rva, e - s);
            }
            return r;
        }
        public override byte[] ReadAbs(long address, int size) { return Read(address - Base, size); }
    }

    public sealed class Deposit
    {
        public int Ware, X, Y, Size, Amount;   // ware 2 ore, 3 gold; size 0 large, 1 small; amount in 1/32 t
        public int Tons { get { return Amount / 32; } }
    }

    public sealed class Town { public string Name = ""; public int Island, Owner, Residents; }
    public sealed class Ship { public string Name = ""; public int Owner; public float X, Y; }

    public sealed class Island
    {
        public int Index, X, Y, W, H, Class, File, Climate, Crops;
        public bool Explored, Home;
        public readonly List<Deposit> Deposits = new List<Deposit>();
        public readonly List<Town> Towns = new List<Town>();
        public int Number { get { return Index + 1; } }
        public bool South { get { return Climate == 1; } }
        public int Count(int ware) { int n = 0; foreach (Deposit d in Deposits) if (d.Ware == ware) n++; return n; }
        public int Tons(int ware) { int n = 0; foreach (Deposit d in Deposits) if (d.Ware == ware) n += d.Tons; return n; }
        public bool HasCrop(int crop) { return (Crops & (1 << (crop - World.CropFirst))) != 0; }
        public bool Contains(double x, double y) { return x >= X && y >= Y && x < X + W && y < Y + H; }
        public bool SettledByPlayer { get { foreach (Town t in Towns) if (t.Owner <= 3) return true; return false; } }
    }

    public sealed class World
    {
        public const int CropFirst = 0x2D;
        // Crops in the order of the island bits 1-6 (crop code 0x2E..0x33).
        public static readonly int[] Crops = { 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33 };
        public int W, H, Rotation, Local, Clock;
        public float CamX, CamY;
        public bool HasCamera;
        public readonly List<Island> Islands = new List<Island>();
        public readonly List<Town> Towns = new List<Town>();
        public readonly List<Ship> Ships = new List<Ship>();
        public readonly int[] PlayerKinds = new int[7];
        public readonly string[] PlayerNames = new string[7];
        // The game's colour of each player (player +0x69: 0 red, 1 blue, 2 yellow, 3 white, 4 pirates, 5 natives, 6 traders).
        public readonly int[] PlayerColors = { 0, 1, 2, 3, 6, 4, 5 };
        // Per world tile: bits 0-1 terrain (0 sea, 1 land, 2 mountain, 3 built), bit 3 southern island,
        // bits 4-6 owner of the territory (player 0-6, 7 = none).
        public byte[] Grid;
        public uint GridHash;

        public static string CropName(int crop)
        {
            switch (crop)
            {
                case 0x2E: return L.T("Tobacco", "Tabak");
                case 0x2F: return L.T("Spices", "Gewürze");
                case 0x30: return L.T("Sugar cane", "Zuckerrohr");
                case 0x31: return L.T("Cotton", "Baumwolle");
                case 0x32: return L.T("Wine", "Wein");
                case 0x33: return L.T("Cocoa", "Kakao");
            }
            return "?";
        }
        public static string CropShort(int crop)
        {
            switch (crop)
            {
                case 0x2E: return L.T("To", "Ta");
                case 0x2F: return L.T("Sp", "Ge");
                case 0x30: return L.T("Su", "Zu");
                case 0x31: return L.T("Co", "Ba");
                case 0x32: return L.T("Wi", "We");
                case 0x33: return L.T("Ca", "Ka");
            }
            return "?";
        }

        public string OwnerName(int owner)
        {
            if (owner == Local) return L.T("You", "Du");
            if (owner >= 0 && owner <= 3)
            {
                string n = PlayerNames[owner];
                if (!string.IsNullOrEmpty(n) && n != PlayerNames[Local]) return n;
                return string.Format(L.T("Rival {0}", "Gegner {0}"), owner);
            }
            if (owner == 6) return L.T("Natives", "Ureinwohner");
            if (owner == 5) return L.T("Pirates", "Piraten");
            if (owner == 4) return L.T("Traders", "Händler");
            return "?";
        }

        public Color OwnerColor(int owner)
        {
            if (owner < 0 || owner > 6) return Color.FromArgb(150, 150, 150);
            switch (PlayerColors[owner])
            {
                case 0: return Color.FromArgb(226, 38, 34);
                case 1: return Color.FromArgb(46, 104, 226);
                case 2: return Color.FromArgb(246, 206, 30);
                case 3: return Color.FromArgb(244, 244, 244);
                case 4: return Color.FromArgb(40, 40, 40);
                case 5: return Color.FromArgb(156, 84, 206);
            }
            return Color.FromArgb(150, 150, 150);
        }
    }

    // Reads one snapshot of the game. All addresses: docs\FINDINGS.md "Island map (3.7)".
    public static class Reader
    {
        public const long RvaWorldW = 0x5EBE40, RvaWorldH = 0x5EBE98, RvaCamera = 0xF9A00, RvaLocal = 0x5F1D60;
        public const long RvaPlayers = 0x5F0960, RvaClock = 0x5EC0F8, RvaIslands = 0x62DDC0, RvaTowns = 0x622DC0;
        public const long RvaShips = 0x1D8BB0, RvaGfx = 0x6CBB00;
        public const int PlayerSize = 0x280, IslandSize = 0x2CC8, IslandCount = 50, TownSize = 600, TownCount = 75;
        public const int ShipSize = 0x328, ShipCount = 200, GfxCount = 0x2000;
        public const int TilesOffset = 0x2CB0, TilesUnexplored = 0x2CC0, TerrainOffset = 4;
        public const int HomeFile = 28;
        static readonly Encoding Enc = Encoding.GetEncoding(1252);

        static string Text(byte[] b, int o, int max)
        {
            int n = 0;
            while (n < max && o + n < b.Length && b[o + n] != 0) n++;
            return Enc.GetString(b, o, n).Trim();
        }

        // Terrain class of a tile from the terrain kind at +4 of its gfx entry (0x6CBB00[gfx]): 0x13-0x16 sea and surf,
        // 0xF rock, 0x1F/0x20 mountain slope, buildings 0xE, roads 0x1/0xD, walls 0x4-0x7, piers 0x1C/0x1E, harbour
        // and warehouse 0x22-0x24; everything else (meadow 0xB, forest 0xA, beach 0x17-0x1B ...) is land.
        public static int TerrainClass(int kind)
        {
            if (kind >= 0x13 && kind <= 0x16) return 0;
            if (kind == 0xF || kind == 0x1F || kind == 0x20) return 2;
            if (kind == 0xE || kind == 0x1 || kind == 0xD || (kind >= 0x4 && kind <= 0x7) || kind == 0x1C || kind == 0x1E || (kind >= 0x22 && kind <= 0x24)) return 3;
            return 1;
        }

        // kinds: cache entry pointer -> terrain kind (+4 of the gfx entry; a missing entry counts as sea).
        public static World Read(Source s, Dictionary<long, int> kinds)
        {
            byte[] a = s.Read(RvaWorldW, 4), b = s.Read(RvaWorldH, 4);
            if (a == null || b == null) return null;
            World w = new World();
            w.W = BitConverter.ToInt32(a, 0); w.H = BitConverter.ToInt32(b, 0);
            if (w.W < 50 || w.H < 50 || w.W > 4096 || w.H > 4096) return null;
            byte[] c = s.Read(RvaClock, 4); if (c != null) w.Clock = BitConverter.ToInt32(c, 0);
            byte[] lp = s.Read(RvaLocal, 4); if (lp != null) w.Local = BitConverter.ToInt32(lp, 0);
            if (w.Local < 0 || w.Local > 3) w.Local = 0;
            byte[] cp = s.Read(RvaCamera, 8);
            if (cp != null)
            {
                long ptr = BitConverter.ToInt64(cp, 0);
                byte[] cam = ptr != 0 ? s.ReadAbs(ptr, 0x4C) : null;
                if (cam != null)
                {
                    w.CamX = BitConverter.ToInt32(cam, 0x1C); w.CamY = BitConverter.ToInt32(cam, 0x20);
                    w.Rotation = BitConverter.ToInt32(cam, 0x48) & 3; w.HasCamera = true;
                }
            }
            byte[] pl = s.Read(RvaPlayers, 7 * PlayerSize);
            if (pl != null)
                for (int i = 0; i < 7; i++)
                {
                    w.PlayerKinds[i] = BitConverter.ToInt32(pl, i * PlayerSize); w.PlayerNames[i] = Text(pl, i * PlayerSize + 8, 0x40);
                    int col = pl[i * PlayerSize + 0x69];
                    if (col <= 6 && (i == 0 || pl[i * PlayerSize + 0x68] == i)) w.PlayerColors[i] = col;
                }

            // Towns first: the territory number in a tile (bits 19-21) is the town's number on its island (+0x19).
            int[] terrOwner = new int[IslandCount * 8];
            for (int i = 0; i < terrOwner.Length; i++) terrOwner[i] = 7;
            byte[] tb = s.Read(RvaTowns, TownCount * TownSize);
            if (tb != null)
                for (int i = 0; i < TownCount; i++)
                {
                    int o = i * TownSize;
                    if (tb[o + 0x18] == 0xFF || tb[o] == 0) continue;
                    Town t = new Town();
                    t.Name = Text(tb, o, 0x18); t.Island = tb[o + 0x18]; t.Owner = tb[o + 0x1A];
                    for (int k = 0; k < 5; k++) t.Residents += BitConverter.ToInt32(tb, o + 0x220 + 4 * k);
                    w.Towns.Add(t);
                    if (t.Island < IslandCount && tb[o + 0x19] < 7 && t.Owner <= 6) terrOwner[t.Island * 8 + tb[o + 0x19]] = t.Owner;
                }

            byte[] isl = s.Read(RvaIslands, IslandCount * IslandSize);
            if (isl == null) return null;
            byte[] gfx = s.Read(RvaGfx, GfxCount * 8);
            int[] byGfx = new int[GfxCount];
            for (int i = 0; i < GfxCount; i++) byGfx[i] = int.MinValue;
            w.Grid = new byte[w.W * w.H];
            for (int i = 0; i < IslandCount; i++)
            {
                int o = i * IslandSize;
                long tiles = BitConverter.ToInt64(isl, o + TilesOffset);
                if (tiles == 0) tiles = BitConverter.ToInt64(isl, o + TilesUnexplored);
                if (tiles == 0) continue;
                Island it = new Island();
                it.Index = i;
                it.X = BitConverter.ToInt32(isl, o + 4); it.Y = BitConverter.ToInt32(isl, o + 8);
                it.W = BitConverter.ToInt32(isl, o + 0xC); it.H = BitConverter.ToInt32(isl, o + 0x10);
                it.Class = BitConverter.ToUInt16(isl, o + 0x18); it.File = BitConverter.ToUInt16(isl, o + 0x1A);
                it.Climate = isl[o + 0x1C];
                it.Explored = ((isl[o + 0x43] >> w.Local) & 1) != 0;
                it.Crops = BitConverter.ToInt32(isl, o + 0x5C);
                it.Home = it.Class == 4 && it.File == HomeFile && it.Climate == 0 && it.W == 160 && it.H == 140;
                if (it.W <= 0 || it.H <= 0 || it.W > 512 || it.H > 512) continue;
                int n = Math.Min((int)isl[o + 0x41], 4);   // slots +0x20..+0x3F, count +0x41
                for (int k = 0; k < n; k++)
                {
                    int so = o + 0x20 + 8 * k;
                    int ware = isl[so];
                    if (ware != 2 && ware != 3) continue;   // 2 ore, 3 gold (other entries: not deposits of a mine)
                    Deposit d = new Deposit();
                    d.Ware = ware; d.X = isl[so + 1]; d.Y = isl[so + 2]; d.Size = isl[so + 4]; d.Amount = BitConverter.ToUInt16(isl, so + 6);
                    it.Deposits.Add(d);
                }
                w.Islands.Add(it);
                if (gfx == null) continue;
                byte[] t = s.ReadAbs(tiles, it.W * it.H * 4);
                if (t == null) continue;
                byte south = (byte)(it.South ? 8 : 0);
                for (int y = 0; y < it.H; y++)
                {
                    int gy = it.Y + y;
                    if (gy < 0 || gy >= w.H) continue;
                    for (int x = 0; x < it.W; x++)
                    {
                        int gx = it.X + x;
                        if (gx < 0 || gx >= w.W) continue;
                        uint v = BitConverter.ToUInt32(t, (y * it.W + x) * 4);
                        int gi = (int)(v & 0x1FFF);
                        int kind = byGfx[gi];
                        if (kind == int.MinValue)
                        {
                            long entry = BitConverter.ToInt64(gfx, gi * 8);
                            if (!kinds.TryGetValue(entry, out kind))
                            {
                                byte[] e = entry != 0 ? s.ReadAbs(entry + TerrainOffset, 4) : null;
                                kind = e != null ? BitConverter.ToInt32(e, 0) : 0x13;
                                kinds[entry] = kind;
                            }
                            byGfx[gi] = kind;
                        }
                        int cls = TerrainClass(kind);
                        if (cls == 0) continue;
                        int terr = (int)((v >> 19) & 7);
                        int owner = terr == 7 ? 7 : terrOwner[i * 8 + terr];
                        w.Grid[gy * w.W + gx] = (byte)(cls | south | (owner << 4));
                    }
                }
            }
            uint hsh = 2166136261;
            for (int i = 0; i < w.Grid.Length; i += 1) { hsh = (hsh ^ w.Grid[i]) * 16777619; }
            for (int i = 0; i < 7; i++) hsh = (hsh ^ (uint)w.PlayerColors[i]) * 16777619;
            w.GridHash = hsh;
            foreach (Town t in w.Towns) foreach (Island it in w.Islands) if (it.Index == t.Island) it.Towns.Add(t);

            byte[] sb = s.Read(RvaShips, ShipCount * ShipSize);
            if (sb != null)
                for (int i = 0; i < ShipCount; i++)
                {
                    int o = i * ShipSize;
                    if (sb[o] != 0x50 || sb[o + 0x28] != w.Local) continue;
                    long fig = BitConverter.ToInt64(sb, o + 8);
                    byte[] f = fig != 0 ? s.ReadAbs(fig + 0x28, 8) : null;
                    if (f == null) continue;
                    Ship sh = new Ship();
                    sh.Owner = sb[o + 0x28]; sh.Name = Text(sb, o + 0x296, 0x20);
                    sh.X = BitConverter.ToSingle(f, 0); sh.Y = BitConverter.ToSingle(f, 4);
                    w.Ships.Add(sh);
                }
            return w;
        }
    }

    // The game's projection (FUN_1400c4ba0): world x/y -> u (horizontal) / v (vertical) in half tiles, per rotation.
    // On screen one u unit is twice as wide as one v unit (tiles are twice as wide as high).
    public sealed class View
    {
        public int W = 1, H = 1, Rotation;
        public double Zoom = 1, CenterU, CenterV, Scale = 1, OffX, OffY;
        public bool Custom;
        public Size Size;

        public double Span { get { return (W + H) / 2.0; } }

        public void Project(double x, double y, out double u, out double v)
        {
            switch (Rotation)
            {
                case 1: u = (W + H - x - y) / 2.0; v = (x - y + H) / 2.0; break;
                case 2: u = (y - x + W) / 2.0; v = (W + H - x - y) / 2.0; break;
                case 3: u = (x + y) / 2.0; v = (y - x + W) / 2.0; break;
                default: u = (x - y + H) / 2.0; v = (x + y) / 2.0; break;
            }
        }

        public void Unproject(double u, double v, out double x, out double y)
        {
            switch (Rotation)
            {
                case 1: x = W / 2.0 - u + v; y = W / 2.0 + H - u - v; break;
                case 2: x = W + H / 2.0 - u - v; y = u + H / 2.0 - v; break;
                case 3: x = u - v + W / 2.0; y = u + v - W / 2.0; break;
                default: x = v + u - H / 2.0; y = v - u + H / 2.0; break;
            }
        }

        public void Update(Size size)
        {
            Size = size;
            double fit = Math.Min(Math.Max(1, size.Width) / (2 * Span), Math.Max(1, size.Height) / Span) * 0.97;
            Scale = fit * Zoom;
            if (!Custom) { CenterU = Span / 2; CenterV = Span / 2; }
            OffX = size.Width / 2.0 - 2 * CenterU * Scale;
            OffY = size.Height / 2.0 - CenterV * Scale;
        }

        public PointF ToScreen(double x, double y)
        {
            double u, v; Project(x, y, out u, out v);
            return new PointF((float)(OffX + 2 * u * Scale), (float)(OffY + v * Scale));
        }

        public void ToWorld(double px, double py, out double x, out double y)
        {
            Unproject((px - OffX) / (2 * Scale), (py - OffY) / Scale, out x, out y);
        }

        // Zoom by a factor and keep the world point under the screen point where it is.
        public void ZoomAt(double factor, double px, double py)
        {
            double nz = Math.Max(1, Math.Min(16, Zoom * factor));
            if (nz == Zoom) return;
            double u = (px - OffX) / (2 * Scale), v = (py - OffY) / Scale;
            Zoom = nz; Custom = true;

            Update(Size);
            // after Update the scale changed: move the centre so that (u, v) stays under (px, py)
            CenterU = u - (px - Size.Width / 2.0) / (2 * Scale);
            CenterV = v - (py - Size.Height / 2.0) / Scale;
            Update(Size);
        }

        public void Pan(double dx, double dy)
        {
            Custom = true;
            CenterU -= dx / (2 * Scale); CenterV -= dy / Scale;
            Update(Size);
        }

        public void Reset() { Zoom = 1; Custom = false; Update(Size); }

        public void FocusIsland(Island it, double zoom)
        {
            double u, v; Project(it.X + it.W / 2.0, it.Y + it.H / 2.0, out u, out v);
            Zoom = zoom; Custom = true; CenterU = u; CenterV = v; Update(Size);
        }
    }

    public static class Painter
    {
        public static readonly Color Back = Color.FromArgb(24, 30, 40);
        public static readonly Color Sea = Color.FromArgb(36, 84, 128);
        public static readonly Color LandNorth = Color.FromArgb(104, 150, 70);
        public static readonly Color LandSouth = Color.FromArgb(164, 162, 82);
        public static readonly Color Rock = Color.FromArgb(132, 130, 124);
        public static readonly Color Built = Color.FromArgb(214, 200, 168);
        public static readonly Color Gold = Color.FromArgb(246, 196, 40);
        public static readonly Color Ore = Color.FromArgb(178, 190, 204);

        static int Mix(Color a, Color b, double t)
        {
            int r = (int)(a.R + (b.R - a.R) * t), g = (int)(a.G + (b.G - a.G) * t), bl = (int)(a.B + (b.B - a.B) * t);
            return (255 << 24) | (r << 16) | (g << 8) | bl;
        }

        // The map without markers: every screen pixel back to its world tile.
        public static Bitmap RenderBase(World w, View view)
        {
            int pw = Math.Max(1, view.Size.Width), ph = Math.Max(1, view.Size.Height);
            int[] px = new int[pw * ph];
            int back = Back.ToArgb(), sea = Sea.ToArgb();
            int[] land = new int[256];
            for (int g = 0; g < 256; g++)
            {
                int terrain = g & 3; bool south = (g & 8) != 0; int owner = (g >> 4) & 7;
                Color baseCol = terrain == 2 ? Rock : terrain == 3 ? Built : (south ? LandSouth : LandNorth);
                if (owner == 7 || terrain == 0) land[g] = baseCol.ToArgb();
                else land[g] = Mix(baseCol, w.OwnerColor(owner), terrain == 3 ? 0.8 : terrain == 2 ? 0.25 : 0.42);
            }
            for (int y = 0; y < ph; y++)
            {
                for (int x = 0; x < pw; x++)
                {
                    double wx, wy; view.ToWorld(x + 0.5, y + 0.5, out wx, out wy);
                    int c;
                    if (wx < 0 || wy < 0 || wx >= w.W || wy >= w.H) c = back;
                    else
                    {
                        byte g = w.Grid[(int)wy * w.W + (int)wx];
                        c = (g & 3) == 0 ? sea : land[g];
                    }
                    px[y * pw + x] = c;
                }
            }
            Bitmap bmp = new Bitmap(pw, ph, PixelFormat.Format32bppArgb);
            BitmapData bd = bmp.LockBits(new Rectangle(0, 0, pw, ph), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            for (int y = 0; y < ph; y++) Marshal.Copy(px, y * pw, new IntPtr(bd.Scan0.ToInt64() + (long)y * bd.Stride), pw);
            bmp.UnlockBits(bd);
            return bmp;
        }

        public static PointF[] Outline(View view, Island it, double grow)
        {
            return new PointF[] {
                view.ToScreen(it.X - grow, it.Y - grow), view.ToScreen(it.X + it.W + grow, it.Y - grow),
                view.ToScreen(it.X + it.W + grow, it.Y + it.H + grow), view.ToScreen(it.X - grow, it.Y + it.H + grow) };
        }
    }

    public delegate bool IslandFilter(Island it);

    public sealed class MapPanel : Panel
    {
        public World World;
        public readonly View View = new View();
        public Island Hover, Selected;
        public List<Island> Marked = new List<Island>();
        public bool FilterActive;
        public float Ui = 1;
        public int RotationOverride = -1;
        Bitmap baseImage;
        uint baseHash; int baseRot = -1; Size baseSize; double baseScale, baseOffX, baseOffY;
        Point dragFrom; bool dragging, dragged;
        public event EventHandler HoverChanged, SelectedChanged;

        public MapPanel()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Painter.Back;
        }

        public void SetWorld(World w)
        {
            World = w;
            if (w != null)
            {
                int rot = RotationOverride >= 0 ? RotationOverride : w.Rotation;
                if (View.W != w.W || View.H != w.H || View.Rotation != rot) { View.W = w.W; View.H = w.H; View.Rotation = rot; View.Reset(); }
                if (Hover != null) Hover = Find(Hover.Index); if (Selected != null) Selected = Find(Selected.Index);
            }
            View.Update(ClientSize);
            Invalidate();
        }

        public Island Find(int index) { if (World == null) return null; foreach (Island it in World.Islands) if (it.Index == index) return it; return null; }

        public Island IslandAt(Point p)
        {
            if (World == null) return null;
            double x, y; View.ToWorld(p.X, p.Y, out x, out y);
            foreach (Island it in World.Islands) if (it.Contains(x, y)) return it;
            return null;
        }

        protected override void OnResize(EventArgs e) { base.OnResize(e); View.Update(ClientSize); Invalidate(); }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); if (!Focused) Focus(); }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            base.OnMouseWheel(e);
            if (World == null) return;
            View.ZoomAt(e.Delta > 0 ? 1.25 : 0.8, e.X, e.Y);
            Invalidate();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button == MouseButtons.Left) { dragFrom = e.Location; dragging = true; dragged = false; }
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (dragging && (Math.Abs(e.X - dragFrom.X) + Math.Abs(e.Y - dragFrom.Y) > 3 || dragged))
            {
                View.Pan(e.X - dragFrom.X, e.Y - dragFrom.Y); dragFrom = e.Location; dragged = true; Invalidate(); return;
            }
            Island h = IslandAt(e.Location);
            if (h != Hover) { Hover = h; Invalidate(); if (HoverChanged != null) HoverChanged(this, EventArgs.Empty); }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            if (e.Button == MouseButtons.Left && dragging && !dragged)
            {
                Selected = IslandAt(e.Location); Invalidate();
                if (SelectedChanged != null) SelectedChanged(this, EventArgs.Empty);
            }
            dragging = false;
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            if (Hover != null) { Hover = null; Invalidate(); if (HoverChanged != null) HoverChanged(this, EventArgs.Empty); }
        }

        protected override void OnMouseDoubleClick(MouseEventArgs e) { base.OnMouseDoubleClick(e); View.Reset(); Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Painter.Back);
            if (World == null || World.Grid == null) return;
            if (baseImage == null || baseHash != World.GridHash || baseRot != View.Rotation || baseSize != ClientSize || baseScale != View.Scale || baseOffX != View.OffX || baseOffY != View.OffY)
            {
                if (baseImage != null) baseImage.Dispose();
                baseImage = Painter.RenderBase(World, View);
                baseHash = World.GridHash; baseRot = View.Rotation; baseSize = ClientSize; baseScale = View.Scale; baseOffX = View.OffX; baseOffY = View.OffY;
            }
            g.DrawImageUnscaled(baseImage, 0, 0);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

            // Marked (filter) and highlighted islands: the island's square as a diamond around it.
            if (FilterActive)
                using (Pen p = new Pen(Color.FromArgb(230, 255, 214, 64), 2 * Ui) { DashStyle = DashStyle.Dash })
                    foreach (Island it in Marked) g.DrawPolygon(p, Painter.Outline(View, it, 1));
            if (Selected != null) using (Pen p = new Pen(Color.FromArgb(255, 255, 150, 40), 3 * Ui)) g.DrawPolygon(p, Painter.Outline(View, Selected, 2));
            if (Hover != null && Hover != Selected) using (Pen p = new Pen(Color.FromArgb(220, 255, 255, 255), 2 * Ui)) g.DrawPolygon(p, Painter.Outline(View, Hover, 2));

            // Deposits: a marker on the mountain (origin tile of the rock + 1).
            float r = (float)Math.Max(3.5 * Ui, Math.Min(9 * Ui, 1.6 * View.Scale * 2));
            using (Pen outline = new Pen(Color.FromArgb(200, 20, 20, 20), 1.2f * Ui))
            using (SolidBrush gold = new SolidBrush(Painter.Gold))
            using (SolidBrush ore = new SolidBrush(Painter.Ore))
                foreach (Island it in World.Islands)
                    foreach (Deposit d in it.Deposits)
                    {
                        PointF c = View.ToScreen(it.X + d.X + 1.5, it.Y + d.Y + 1.5);
                        float rr = d.Size == 0 || d.Ware == 3 ? r : r * 0.75f;
                        RectangleF rc = new RectangleF(c.X - rr, c.Y - rr, 2 * rr, 2 * rr);
                        g.FillEllipse(d.Ware == 3 ? gold : ore, rc); g.DrawEllipse(outline, rc);
                    }

            // Island numbers (and "home").
            using (Font f = new Font("Segoe UI", 8f, FontStyle.Bold))
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(200, 0, 0, 0)))
            using (SolidBrush white = new SolidBrush(Color.White))
                foreach (Island it in World.Islands)
                {
                    PointF c = View.ToScreen(it.X + it.W / 2.0, it.Y + it.H / 2.0);
                    string s = it.Home ? it.Number + " " + L.T("home", "Heimat") : it.Number.ToString();
                    SizeF sz = g.MeasureString(s, f);
                    float x = c.X - sz.Width / 2, y = c.Y - sz.Height / 2;
                    g.DrawString(s, f, shadow, x + 1, y + 1); g.DrawString(s, f, white, x, y);
                }

            // Your ships.
            using (SolidBrush b = new SolidBrush(Color.White))
            using (Pen p = new Pen(Color.Black, 1.2f * Ui))
                foreach (Ship s in World.Ships)
                {
                    PointF c = View.ToScreen(s.X, s.Y);
                    float k = 5 * Ui;
                    PointF[] tri = { new PointF(c.X, c.Y - k), new PointF(c.X + k * 0.8f, c.Y + k * 0.6f), new PointF(c.X - k * 0.8f, c.Y + k * 0.6f) };
                    g.FillPolygon(b, tri); g.DrawPolygon(p, tri);
                }

            // The spot the game shows.
            if (World.HasCamera)
            {
                PointF c = View.ToScreen(World.CamX, World.CamY);
                float k = 9 * Ui;
                using (Pen p = new Pen(Color.FromArgb(230, 255, 80, 200), 2 * Ui))
                {
                    g.DrawEllipse(p, c.X - k, c.Y - k, 2 * k, 2 * k);
                    g.DrawLine(p, c.X - 1.6f * k, c.Y, c.X - 0.5f * k, c.Y); g.DrawLine(p, c.X + 0.5f * k, c.Y, c.X + 1.6f * k, c.Y);
                    g.DrawLine(p, c.X, c.Y - 1.6f * k, c.X, c.Y - 0.5f * k); g.DrawLine(p, c.X, c.Y + 0.5f * k, c.X, c.Y + 1.6f * k);
                }
            }
        }
    }

    // A small legend drawn with the same markers as the map.
    public sealed class LegendPanel : Panel
    {
        public World World;
        public float Ui = 1;
        public LegendPanel() { DoubleBuffered = true; }
        public int Rows { get { return 3; } }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
            using (Font f = new Font("Segoe UI", 9f))
            using (Pen outline = new Pen(Color.FromArgb(200, 20, 20, 20), 1.2f * Ui))
            {
                float x = 2 * Ui, y = 3 * Ui, lh = 21 * Ui, r = 6 * Ui;
                float cx = x;
                // Row 1: deposits and markers.
                DrawDot(g, outline, Painter.Gold, cx + r, y + lh / 2, r); cx += 2 * r + 4 * Ui; cx = DrawText(g, f, L.T("Gold", "Gold"), cx, y, lh) + 12 * Ui;
                DrawDot(g, outline, Painter.Ore, cx + r, y + lh / 2, r); cx += 2 * r + 4 * Ui; cx = DrawText(g, f, L.T("Ore", "Erz"), cx, y, lh) + 12 * Ui;
                using (SolidBrush w = new SolidBrush(Color.White))
                using (Pen p = new Pen(Color.Black, 1.2f * Ui))
                {
                    float k = 5 * Ui, mx = cx + k, my = y + lh / 2;
                    PointF[] tri = { new PointF(mx, my - k), new PointF(mx + k * 0.8f, my + k * 0.6f), new PointF(mx - k * 0.8f, my + k * 0.6f) };
                    g.FillPolygon(w, tri); g.DrawPolygon(p, tri);
                }
                cx += 2 * r + 4 * Ui; cx = DrawText(g, f, L.T("your ships", "deine Schiffe"), cx, y, lh) + 12 * Ui;
                using (Pen p = new Pen(Color.FromArgb(230, 255, 80, 200), 2 * Ui)) g.DrawEllipse(p, cx, y + lh / 2 - r, 2 * r, 2 * r);
                cx += 2 * r + 4 * Ui; DrawText(g, f, L.T("view", "Sicht"), cx, y, lh);
                // Row 2: land.
                y += lh; cx = x;
                cx = Swatch(g, f, Painter.LandNorth, L.T("north", "Nord"), cx, ref y, lh);
                cx = Swatch(g, f, Painter.LandSouth, L.T("south", "Süd"), cx, ref y, lh);
                cx = Swatch(g, f, Painter.Rock, L.T("mountain", "Berg"), cx, ref y, lh);
                cx = Swatch(g, f, Painter.Built, L.T("buildings", "Gebäude"), cx, ref y, lh);
                // Row 3 (and 4): territory of the players in their colours in the game.
                y += lh; cx = x;
                if (World != null)
                {
                    for (int o = 0; o <= 3; o++)
                    {
                        if (o != World.Local && World.PlayerKinds[o] != 0xC) continue;
                        cx = Swatch(g, f, World.OwnerColor(o), World.OwnerName(o), cx, ref y, lh);
                    }
                    Swatch(g, f, World.OwnerColor(6), World.OwnerName(6), cx, ref y, lh);
                }
            }
        }
        void DrawDot(Graphics g, Pen outline, Color c, float x, float y, float r)
        {
            using (SolidBrush b = new SolidBrush(c)) { RectangleF rc = new RectangleF(x - r, y - r, 2 * r, 2 * r); g.FillEllipse(b, rc); g.DrawEllipse(outline, rc); }
        }
        float DrawText(Graphics g, Font f, string s, float x, float y, float lh)
        {
            SizeF sz = g.MeasureString(s, f);
            using (SolidBrush b = new SolidBrush(ForeColor)) g.DrawString(s, f, b, x, y + (lh - sz.Height) / 2);
            return x + sz.Width;
        }
        // A colour square with its name; wraps to the next row when it would not fit.
        float Swatch(Graphics g, Font f, Color c, string s, float x, ref float y, float lh)
        {
            float k = 12 * Ui;
            if (x > 2 * Ui && x + k + 4 * Ui + g.MeasureString(s, f).Width > ClientSize.Width) { x = 2 * Ui; y += lh; }
            using (SolidBrush b = new SolidBrush(c)) g.FillRectangle(b, x, y + (lh - k) / 2, k, k);
            using (Pen p = new Pen(Color.FromArgb(120, 0, 0, 0))) g.DrawRectangle(p, x, y + (lh - k) / 2, k, k);
            return DrawText(g, f, s, x + k + 4 * Ui, y, lh) + 12 * Ui;
        }
    }

    // Finds the game, checks the exe and keeps the read handle.
    public sealed class Connection
    {
        public string ExpectedHash = "";
        public int TestPid; public long TestBase;
        public Source Src;
        public string Status = "waiting";
        public readonly Dictionary<long, int> Kinds = new Dictionary<long, int>();
        IntPtr handle = IntPtr.Zero;
        readonly Dictionary<int, string> hashes = new Dictionary<int, string>();
        readonly Dictionary<int, int> fails = new Dictionary<int, int>();

        public void Update()
        {
            if (handle != IntPtr.Zero)
            {
                if (Native.IsRunning(handle)) return;
                Native.CloseHandle(handle); handle = IntPtr.Zero; Src = null; Kinds.Clear();
            }
            Process p = null;
            if (TestPid != 0) { try { p = Process.GetProcessById(TestPid); } catch { } }
            else
            {
                DateTime best = DateTime.MinValue;
                foreach (Process q in Process.GetProcessesByName("Anno1602"))
                {
                    DateTime st = DateTime.MinValue; try { st = q.StartTime; } catch { }
                    if (p == null || st > best) { p = q; best = st; }
                }
            }
            if (p == null) { Status = "waiting"; return; }
            long b;
            try
            {
                b = TestPid != 0 ? TestBase : p.MainModule.BaseAddress.ToInt64();
                if (TestPid == 0)
                {
                    string hsh;
                    if (!hashes.TryGetValue(p.Id, out hsh))
                    {
                        using (SHA256 sha = SHA256.Create())
                        using (FileStream fs = File.OpenRead(p.MainModule.FileName))
                        {
                            StringBuilder sb = new StringBuilder();
                            foreach (byte x in sha.ComputeHash(fs)) sb.Append(x.ToString("x2"));
                            hsh = sb.ToString();
                        }
                        hashes[p.Id] = hsh;
                    }
                    if (hsh != ExpectedHash) { Status = "version"; return; }
                }
            }
            catch
            {
                int n; fails.TryGetValue(p.Id, out n); fails[p.Id] = n + 1;
                Status = n + 1 > 10 ? "denied" : "starting"; return;
            }
            handle = Native.OpenProcess(0x0400 | 0x0010, false, p.Id);
            if (handle == IntPtr.Zero) { Status = "denied"; return; }
            Src = new ProcessSource(handle, b); Status = "attached";
        }
    }

    public sealed class MapForm : Form
    {
        public readonly MapPanel Map = new MapPanel();
        public readonly LegendPanel Legend = new LegendPanel();
        public readonly ListView IslandList = new ListView();
        public readonly Label Status = new Label(), Details = new Label();
        public readonly CheckBox TopBox = new CheckBox();
        public readonly List<KeyValuePair<CheckBox, IslandFilter>> Filters = new List<KeyValuePair<CheckBox, IslandFilter>>();
        public readonly Connection Conn = new Connection();
        public readonly Timer Clock = new Timer();
        public World World;
        public Source FixedSource;   // tests: read this instead of the game
        string listKey = "";
        bool updatingList;
        public float Ui = 1;

        public MapForm(float ui)
        {
            Ui = ui;
            Text = L.T("Island map - Anno 1602", "Inselkarte - Anno 1602");
            BackColor = Color.FromArgb(32, 38, 48); ForeColor = Color.FromArgb(230, 232, 236);
            Font = new Font("Segoe UI", 9f);
            ClientSize = new Size((int)(1400 * ui), (int)(820 * ui));
            MinimumSize = new Size((int)(800 * ui), (int)(500 * ui));
            StartPosition = FormStartPosition.CenterScreen;

            Map.Dock = DockStyle.Fill; Map.Ui = ui;
            Panel side = new Panel(); side.Dock = DockStyle.Right; side.Width = (int)(430 * ui); side.Padding = new Padding((int)(10 * ui));
            TableLayoutPanel t = new TableLayoutPanel(); t.Dock = DockStyle.Fill; t.ColumnCount = 1; t.RowCount = 7;
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            t.RowStyles.Add(new RowStyle(SizeType.Absolute, 92 * ui));
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            t.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            t.RowStyles.Add(new RowStyle(SizeType.Absolute, 150 * ui));
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            Status.AutoSize = true; Status.MaximumSize = new Size((int)(405 * ui), 0); Status.Margin = new Padding(0, 0, 0, (int)(6 * ui));
            Legend.Dock = DockStyle.Fill; Legend.Ui = ui; Legend.ForeColor = ForeColor; Legend.Margin = new Padding(0);

            Label fl = new Label(); fl.AutoSize = true; fl.Text = L.T("Show islands with:", "Inseln zeigen mit:"); fl.Margin = new Padding(0, (int)(8 * ui), 0, (int)(2 * ui));
            FlowLayoutPanel flow = new FlowLayoutPanel(); flow.AutoSize = true; flow.Dock = DockStyle.Fill; flow.Margin = new Padding(0, 0, 0, (int)(6 * ui));
            AddFilter(flow, L.T("Gold", "Gold"), delegate(Island i) { return i.Count(3) > 0; });
            AddFilter(flow, L.T("Ore", "Erz"), delegate(Island i) { return i.Count(2) > 0; });
            foreach (int crop in World.Crops) { int c = crop; AddFilter(flow, World.CropName(c), delegate(Island i) { return i.HasCrop(c); }); }
            AddFilter(flow, L.T("Free (no player)", "Frei (kein Spieler)"), delegate(Island i) { return !i.SettledByPlayer; });
            AddFilter(flow, L.T("North", "Nord"), delegate(Island i) { return !i.South; });
            AddFilter(flow, L.T("South", "Süd"), delegate(Island i) { return i.South; });

            IslandList.Dock = DockStyle.Fill; IslandList.View = System.Windows.Forms.View.Details; IslandList.FullRowSelect = true; IslandList.HideSelection = false;
            IslandList.MultiSelect = false; IslandList.BackColor = Color.FromArgb(40, 47, 58); IslandList.ForeColor = ForeColor; IslandList.BorderStyle = BorderStyle.FixedSingle;
            IslandList.Columns.Add(L.T("No.", "Nr."), (int)(42 * ui), HorizontalAlignment.Right);
            IslandList.Columns.Add(L.T("Zone", "Zone"), (int)(42 * ui));
            IslandList.Columns.Add(L.T("Size", "Grösse"), (int)(68 * ui));
            IslandList.Columns.Add(L.T("Ore", "Erz"), (int)(36 * ui), HorizontalAlignment.Right);
            IslandList.Columns.Add(L.T("Gold", "Gold"), (int)(40 * ui), HorizontalAlignment.Right);
            IslandList.Columns.Add(L.T("Crops", "Pflanzen"), (int)(62 * ui));
            IslandList.Columns.Add(L.T("Owner", "Besitz"), (int)(96 * ui));
            IslandList.SelectedIndexChanged += delegate { if (updatingList) return; Island it = SelectedListIsland(); if (it != null) { Map.Selected = it; Map.Invalidate(); ShowDetails(); } };
            IslandList.DoubleClick += delegate { Island it = SelectedListIsland(); if (it != null) { Map.View.FocusIsland(it, 5); Map.Invalidate(); } };

            Details.Dock = DockStyle.Fill; Details.Margin = new Padding(0, (int)(8 * ui), 0, 0); Details.Padding = new Padding((int)(6 * ui));
            Details.BackColor = Color.FromArgb(40, 47, 58);

            TopBox.AutoSize = true; TopBox.Text = L.T("Always on top", "Immer im Vordergrund"); TopBox.Margin = new Padding(0, (int)(6 * ui), 0, 0);
            TopBox.CheckedChanged += delegate { TopMost = TopBox.Checked; };

            t.Controls.Add(Status, 0, 0); t.Controls.Add(Legend, 0, 1); t.Controls.Add(fl, 0, 2); t.Controls.Add(flow, 0, 3);
            t.Controls.Add(IslandList, 0, 4); t.Controls.Add(Details, 0, 5); t.Controls.Add(TopBox, 0, 6);
            side.Controls.Add(t);
            Controls.Add(Map); Controls.Add(side);

            Map.HoverChanged += delegate { ShowDetails(); };
            Map.SelectedChanged += delegate { SelectListIsland(Map.Selected); ShowDetails(); };
            Clock.Interval = 2000;
            Clock.Tick += delegate { Tick(); };
            ShowDetails();
        }

        void AddFilter(FlowLayoutPanel flow, string text, IslandFilter f)
        {
            CheckBox cb = new CheckBox(); cb.Text = text; cb.AutoSize = true; cb.Margin = new Padding(0, 0, (int)(10 * Ui), (int)(2 * Ui));
            cb.CheckedChanged += delegate { ApplyFilter(true); };
            flow.Controls.Add(cb);
            Filters.Add(new KeyValuePair<CheckBox, IslandFilter>(cb, f));
        }

        public bool Matches(Island it)
        {
            foreach (KeyValuePair<CheckBox, IslandFilter> f in Filters) if (f.Key.Checked && !f.Value(it)) return false;
            return true;
        }

        // force: a filter changed (rebuild the list); otherwise only when the islands' contents changed.
        public void ApplyFilter(bool force)
        {
            bool any = false; foreach (KeyValuePair<CheckBox, IslandFilter> f in Filters) if (f.Key.Checked) any = true;
            Map.FilterActive = any;
            Map.Marked = new List<Island>();
            if (World != null) foreach (Island it in World.Islands) if (Matches(it)) Map.Marked.Add(it);
            if (force) listKey = "";
            FillList();
            Map.Invalidate();
        }

        Island SelectedListIsland()
        {
            if (IslandList.SelectedItems.Count == 0) return null;
            return Map.Find((int)IslandList.SelectedItems[0].Tag);
        }

        void SelectListIsland(Island it)
        {
            updatingList = true;
            foreach (ListViewItem li in IslandList.Items) li.Selected = it != null && (int)li.Tag == it.Index;
            if (it != null) foreach (ListViewItem li in IslandList.Items) if (li.Selected) li.EnsureVisible();
            updatingList = false;
        }

        public string Owners(Island it)
        {
            List<string> names = new List<string>();
            foreach (Town t in it.Towns) { string n = World.OwnerName(t.Owner); if (!names.Contains(n)) names.Add(n); }
            return names.Count == 0 ? "–" : string.Join(", ", names.ToArray());
        }

        public static string Crops(Island it)
        {
            List<string> s = new List<string>();
            foreach (int c in World.Crops) if (it.HasCrop(c)) s.Add(World.CropShort(c));
            return s.Count == 0 ? "–" : string.Join(" ", s.ToArray());
        }

        // For the list: "all 6" when every crop grows at 100 %.
        public static string CropsCell(Island it)
        {
            int n = 0; foreach (int c in World.Crops) if (it.HasCrop(c)) n++;
            return n == World.Crops.Length ? L.T("all 6", "alle 6") : Crops(it);
        }

        public void FillList()
        {
            if (World == null) { IslandList.Items.Clear(); listKey = ""; return; }
            StringBuilder key = new StringBuilder();
            List<Island> rows = new List<Island>();
            foreach (Island it in World.Islands) if (!Map.FilterActive || Matches(it)) rows.Add(it);
            foreach (Island it in rows) key.Append(it.Index).Append(':').Append(it.Count(2)).Append(it.Count(3)).Append(it.Crops).Append(Owners(it)).Append('|');
            if (key.ToString() == listKey) return;
            listKey = key.ToString();
            updatingList = true;
            IslandList.BeginUpdate();
            IslandList.Items.Clear();
            foreach (Island it in rows)
            {
                ListViewItem li = new ListViewItem(it.Number.ToString());
                li.Tag = it.Index;
                li.SubItems.Add(it.South ? L.T("S", "Süd") : L.T("N", "Nord"));
                li.SubItems.Add(it.W + "×" + it.H);
                li.SubItems.Add(it.Count(2) > 0 ? it.Count(2).ToString() : "–");
                li.SubItems.Add(it.Count(3) > 0 ? it.Count(3).ToString() : "–");
                li.SubItems.Add(CropsCell(it));
                li.SubItems.Add(Owners(it));
                if (it.Count(3) > 0) li.ForeColor = Painter.Gold;
                if (it.Home) li.Font = new Font(IslandList.Font, FontStyle.Bold);
                if (Map.Selected != null && Map.Selected.Index == it.Index) li.Selected = true;
                IslandList.Items.Add(li);
            }
            IslandList.EndUpdate();
            updatingList = false;
        }

        public string DetailsText(Island it)
        {
            StringBuilder s = new StringBuilder();
            s.Append(string.Format(L.T("Island {0}", "Insel {0}"), it.Number));
            if (it.Home) s.Append(L.T(" (home island)", " (Heimatinsel)"));
            s.Append(" · ").Append(it.South ? L.T("south", "Süden") : L.T("north", "Norden")).Append(" · ").Append(it.W).Append(" × ").Append(it.H);
            if (!it.Explored) s.Append(L.T(" · not explored yet", " · noch nicht erkundet"));
            s.AppendLine();
            List<string> ore = new List<string>(), gold = new List<string>();
            foreach (Deposit d in it.Deposits)
            {
                string t = (d.Size == 0 ? L.T("large ", "gross ") : L.T("small ", "klein ")) + L.Num(d.Tons) + " t";
                if (d.Ware == 3) gold.Add(L.Num(d.Tons) + " t"); else ore.Add(t);
            }
            s.Append(L.T("Gold: ", "Gold: ")).AppendLine(gold.Count == 0 ? "–" : gold.Count + " × (" + string.Join(", ", gold.ToArray()) + L.T(", a gold mine never uses it up)", ", eine Goldmine braucht es nie auf)"));
            s.Append(L.T("Ore: ", "Erz: ")).AppendLine(ore.Count == 0 ? "–" : ore.Count + " × (" + string.Join(", ", ore.ToArray()) + ")");
            List<string> crops = new List<string>();
            foreach (int c in World.Crops) if (it.HasCrop(c)) crops.Add(World.CropName(c));
            s.Append(L.T("Crops at 100 %: ", "Pflanzen zu 100 %: ")).AppendLine(crops.Count == 0 ? L.T("none", "keine") : string.Join(", ", crops.ToArray()));
            if (it.Towns.Count == 0) s.Append(L.T("Settlements: none - free", "Siedlungen: keine - frei"));
            else
            {
                List<string> towns = new List<string>();
                foreach (Town t in it.Towns) towns.Add(t.Name + " (" + World.OwnerName(t.Owner) + (t.Owner <= 3 ? ", " + L.Num(t.Residents) + L.T(" residents", " Einw.") : "") + ")");
                s.Append(L.T("Settlements: ", "Siedlungen: ")).Append(string.Join(", ", towns.ToArray()));
            }
            return s.ToString();
        }

        public void ShowDetails()
        {
            Island it = Map.Hover ?? Map.Selected;
            if (World == null) { Details.Text = ""; return; }
            Details.Text = it == null ? L.T("Point at an island for details. Mouse wheel: zoom, drag: move, double-click: whole map. Double-click a row: zoom to that island.",
                "Zeige auf eine Insel für Einzelheiten. Mausrad: zoomen, ziehen: verschieben, Doppelklick: ganze Karte. Doppelklick auf eine Zeile: zu dieser Insel zoomen.") : DetailsText(it);
        }

        // Reads the game and shows the result (tests and the first picture).
        public void RefreshNow()
        {
            string status;
            World w = ReadWorld(out status);
            Apply(w, status);
        }

        // Every 2 seconds: read on a worker thread (several MB on a big map), show on the window's thread.
        bool reading;
        public void Tick()
        {
            if (reading || IsDisposed) return;
            reading = true;
            System.Threading.ThreadPool.QueueUserWorkItem(delegate
            {
                string status;
                World w = ReadWorld(out status);
                try
                {
                    if (IsDisposed || !IsHandleCreated) return;
                    BeginInvoke((MethodInvoker)delegate { reading = false; if (!IsDisposed) Apply(w, status); });
                }
                catch (InvalidOperationException) { }
            });
        }

        public World ReadWorld(out string status)
        {
            World w = null;
            try
            {
                Source src = FixedSource;
                if (src == null) { Conn.Update(); src = Conn.Src; }
                if (src != null) w = Reader.Read(src, Conn.Kinds);
                if (src == null)
                {
                    if (Conn.Status == "version") status = L.T("This game version is not supported by the island map.", "Diese Spielversion kennt die Inselkarte nicht.");
                    else if (Conn.Status == "denied") status = L.T("No access to the game (run both the same way, e.g. not as administrator).", "Kein Zugriff auf das Spiel (beides gleich starten, z. B. nicht als Administrator).");
                    else status = L.T("Waiting for Anno 1602 - the map appears as soon as a game runs.", "Warte auf Anno 1602 - die Karte erscheint, sobald ein Spiel läuft.");
                }
                else if (w == null || w.Islands.Count == 0) { w = null; status = L.T("No game loaded yet.", "Noch kein Spiel geladen."); }
                else
                {
                    int gold = 0, ore = 0, free = 0;
                    foreach (Island it in w.Islands) { if (it.Count(3) > 0) gold++; if (it.Count(2) > 0) ore++; if (!it.SettledByPlayer) free++; }
                    status = string.Format(L.T("{0} × {1}, {2} islands: {3} with gold, {4} with ore, {5} free. Turned like the game. {7:HH:mm:ss}",
                        "{0} × {1}, {2} Inseln: {3} mit Gold, {4} mit Erz, {5} frei. Gedreht wie im Spiel. {7:HH:mm:ss}"),
                        w.W, w.H, w.Islands.Count, gold, ore, free, w.Rotation + 1, DateTime.Now);
                }
            }
            catch (Exception ex) { w = null; status = L.T("Error: ", "Fehler: ") + ex.Message; }
            return w;
        }

        public void Apply(World w, string status)
        {
            World = w;
            Status.Text = status;
            Legend.World = w; Legend.Invalidate();
            Map.SetWorld(w);
            ApplyFilter(false);
            ShowDetails();
        }

        protected override void OnShown(EventArgs e) { base.OnShown(e); RefreshNow(); Clock.Start(); }
    }
}
'@
}

[AnnoIslandMap.L]::German = $UiGerman

function Get-UiScale {
    $g = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    try { [float]($g.DpiX / 96.0) } finally { $g.Dispose() }
}

function New-MapForm {
    [void][AnnoIslandMap.Native]::SetProcessDPIAware()
    [Windows.Forms.Application]::EnableVisualStyles()
    $f = New-Object AnnoIslandMap.MapForm ([float](Get-UiScale))
    $f.Conn.ExpectedHash = $ExpectedHash
    $f.Conn.TestPid = $TestProcessId; $f.Conn.TestBase = $TestBase
    $f
}

# Renders the form off-screen (nothing appears on the screen) and saves it as PNG.
function Save-FormImage($form, [string]$path) {
    $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false
    $form.Location = New-Object Drawing.Point(-32000, -32000)
    $form.Show(); [Windows.Forms.Application]::DoEvents()
    $form.Clock.Stop()
    [Windows.Forms.Application]::DoEvents()
    $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
    $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
    $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $form.Close()
}

function Write-WorldDump($w) {
    if (-not $w) { 'no world'; return }
    'world {0} x {1}, rotation {2}, camera {3}/{4}, local player {5}, clock {6}, {7} islands, {8} towns, {9} ships' -f $w.W, $w.H, $w.Rotation, $w.CamX, $w.CamY, $w.Local, $w.Clock, $w.Islands.Count, $w.Towns.Count, $w.Ships.Count
    foreach ($it in $w.Islands) {
        $deps = @($it.Deposits | ForEach-Object { '{0} {1}/{2} {3} {4} t' -f $(if ($_.Ware -eq 3) { 'gold' } else { 'ore' }), $_.X, $_.Y, $(if ($_.Size -eq 0) { 'large' } else { 'small' }), $_.Tons })
        $n = @(0, 0, 0, 0); $own = @{}
        for ($y = [Math]::Max(0, $it.Y); $y -lt [Math]::Min($w.H, $it.Y + $it.H); $y++) {
            $row = $y * $w.W
            for ($x = [Math]::Max(0, $it.X); $x -lt [Math]::Min($w.W, $it.X + $it.W); $x++) {
                $g = $w.Grid[$row + $x]; $n[$g -band 3]++; if (($g -band 3) -eq 0) { continue }
                $o = ($g -shr 4) -band 7; if ($o -ne 7) { $own[$o] = 1 + [int]$own[$o] }
            }
        }
        $towns = @($it.Towns | ForEach-Object { '{0} ({1}, {2})' -f $_.Name, $w.OwnerName($_.Owner), $_.Residents })
        'island {0,2} at {1}/{2} {3}x{4} {5}{6}{7}: sea {8}, land {9}, mountain {10}, built {11}, territory {12}; deposits {13}; crops {14}; towns {15}' -f $it.Number, $it.X, $it.Y, $it.W, $it.H, $(if ($it.South) { 'south' } else { 'north' }), $(if ($it.Home) { ' HOME' } else { '' }), $(if ($it.Explored) { '' } else { ' unexplored' }), $n[0], $n[1], $n[2], $n[3], (($own.Keys | Sort-Object | ForEach-Object { "$_=$($own[$_])" }) -join ','), ($deps -join ', '), [AnnoIslandMap.MapForm]::Crops($it), ($towns -join ', ')
    }
    foreach ($s in $w.Ships) { 'ship {0} at {1:0.0}/{2:0.0}' -f $s.Name, $s.X, $s.Y }
}

# ---------------------------------------------------------------------------------------------------------------------
# Self-test: a small world in a memory image.
# ---------------------------------------------------------------------------------------------------------------------
function Invoke-SelfTest {
    $script:fails = 0; $script:checks = 0
    [AnnoIslandMap.L]::German = $true
    function Test-That([string]$name, [bool]$ok) { $script:checks++; if ($ok) { "  OK    $name" } else { $script:fails++; "  FAIL  $name" } }
    $dir = if ($SelfTestFolder) { $SelfTestFolder } else { Join-Path $env:TEMP 'anno-islandmap-selftest' }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $B = [AnnoIslandMap.ImageSource]::Base
    $img = New-Object AnnoIslandMap.ImageSource
    $i32 = { param($v) [BitConverter]::GetBytes([int]$v) }
    $img.Write(0x5EBE40, (& $i32 600)); $img.Write(0x5EBE98, (& $i32 400)); $img.Write(0x5EC0F8, (& $i32 5000)); $img.Write(0x5F1D60, (& $i32 0))
    # Camera at 0x2100000 (pointer at 0xF9A00): world 150/120, rotation 0.
    $img.Write(0xF9A00, [BitConverter]::GetBytes([long]($B + 0x2100000)))
    $cam = New-Object byte[] 0x4C; [Array]::Copy((& $i32 150), 0, $cam, 0x1C, 4); [Array]::Copy((& $i32 120), 0, $cam, 0x20, 4); $img.Write(0x2100000, $cam)
    # Players: 0 human (number 0, colour 2 = yellow), 1 computer rival (kind 0xC, number 1, colour 0 = red).
    $img.Write(0x5F0960, (& $i32 0)); $img.Write(0x5F0960 + 0x68, [byte[]]@(0, 2))
    $img.Write(0x5F0960 + 0x280, (& $i32 0xC)); $img.Write(0x5F0960 + 0x280 + 0x68, [byte[]]@(1, 0))
    # Gfx table: 100 = sea (terrain 0x13), 200 = meadow (0xB), 300 = rock (0xF), 400 = building (0xE); entries at 0x2000000,
    # terrain kind at +4 (+0x1C = 9 for all as in the game, where it does not tell sea from land).
    foreach ($k in @(@(100, 0x13), @(200, 0xB), @(300, 0xF), @(400, 0xE))) {
        $entry = 0x2000000 + $k[0] * 0x40
        $img.Write(0x6CBB00 + $k[0] * 8, [BitConverter]::GetBytes([long]($B + $entry)))
        $e = New-Object byte[] 0x40; [Array]::Copy((& $i32 $k[1]), 0, $e, 4, 4); [Array]::Copy((& $i32 9), 0, $e, 0x1C, 4); $img.Write($entry, $e)
    }
    # Islands: tiles at 0x3000000 + i * 0x100000. Land = ellipse, rock 3x3 at the deposit, territory owner per island.
    $isl = @(
        @{ No = 0; X = 40; Y = 40; W = 60; H = 50; Climate = 0; Class = 2; File = 3; Crops = 0x2A; Deps = @(, @(2, 20, 15, 0, 0x1E00)); Terr = 0; Expl = 1 }
        @{ No = 1; X = 300; Y = 60; W = 80; H = 70; Climate = 1; Class = 3; File = 5; Crops = 0x54; Deps = @(@(3, 30, 30, 1, 0x640), @(2, 50, 20, 1, 0xA00), @(0x3A, 10, 7, 0, 1000)); Terr = 0; Expl = 1 }
        @{ No = 4; X = 380; Y = 220; W = 160; H = 140; Climate = 0; Class = 4; File = 28; Crops = 0x7E; Deps = @(@(2, 32, 29, 0, 0x1E00), @(2, 120, 29, 0, 0x1E00), @(3, 118, 110, 1, 0x640), @(3, 16, 115, 1, 0x640)); Terr = 7; Expl = 0 }
    )
    $landTotal = @{}; $rockTotal = @{}; $builtTotal = @{}
    foreach ($d in $isl) {
        $rec = 0x62DDC0 + $d.No * 0x2CC8
        $r = New-Object byte[] 0x60
        [Array]::Copy((& $i32 $d.X), 0, $r, 4, 4); [Array]::Copy((& $i32 $d.Y), 0, $r, 8, 4); [Array]::Copy((& $i32 $d.W), 0, $r, 0xC, 4); [Array]::Copy((& $i32 $d.H), 0, $r, 0x10, 4)
        [Array]::Copy([BitConverter]::GetBytes([uint16]$d.Class), 0, $r, 0x18, 2); [Array]::Copy([BitConverter]::GetBytes([uint16]$d.File), 0, $r, 0x1A, 2); $r[0x1C] = [byte]$d.Climate
        for ($k = 0; $k -lt $d.Deps.Count; $k++) { $q = $d.Deps[$k]; $r[0x20 + 8 * $k] = [byte]$q[0]; $r[0x21 + 8 * $k] = [byte]$q[1]; $r[0x22 + 8 * $k] = [byte]$q[2]; $r[0x24 + 8 * $k] = [byte]$q[3]; [Array]::Copy([BitConverter]::GetBytes([uint16]$q[4]), 0, $r, 0x26 + 8 * $k, 2) }
        $r[0x41] = [byte]$d.Deps.Count; $r[0x43] = [byte]$d.Expl
        [Array]::Copy((& $i32 $d.Crops), 0, $r, 0x5C, 4)
        $img.Write($rec, $r)
        $tilesRva = 0x3000000 + $d.No * 0x100000
        $img.Write($rec + 0x2CB0, [BitConverter]::GetBytes([long]($B + $tilesRva)))
        $t = New-Object byte[] ($d.W * $d.H * 4); $land = 0; $rock = 0; $built = 0
        for ($y = 0; $y -lt $d.H; $y++) {
            for ($x = 0; $x -lt $d.W; $x++) {
                $nx = ($x - $d.W / 2 + 0.5) / ($d.W / 2 - 3); $ny = ($y - $d.H / 2 + 0.5) / ($d.H / 2 - 3)
                $gfx = 100
                if ($nx * $nx + $ny * $ny -le 1) {
                    $gfx = 200
                    foreach ($q in $d.Deps) { if ($x -ge $q[1] -and $x -lt $q[1] + 3 -and $y -ge $q[2] -and $y -lt $q[2] + 3) { $gfx = 300 } }
                    if ($d.No -eq 0 -and $x -ge 30 -and $x -lt 32 -and $y -ge 25 -and $y -lt 28) { $gfx = 400 }
                }
                switch ($gfx) { 200 { $land++ } 300 { $rock++ } 400 { $built++ } }
                $v = [uint32]$gfx -bor ([uint32]$d.Terr -shl 19)
                [Array]::Copy([BitConverter]::GetBytes($v), 0, $t, ($y * $d.W + $x) * 4, 4)
            }
        }
        $img.Write($tilesRva, $t); $landTotal[$d.No] = $land; $rockTotal[$d.No] = $rock; $builtTotal[$d.No] = $built
    }
    # Towns: "Testhafen" (player 0) on island 1, natives on island 2, a rival town on island 2.
    # +0x19 = the town's number on its island = the territory number in the tiles.
    $town = { param($slot, $name, $island, $no, $owner, $res)
        $b = New-Object byte[] 600; $n = [Text.Encoding]::GetEncoding(1252).GetBytes($name); [Array]::Copy($n, 0, $b, 0, $n.Length)
        $b[0x18] = [byte]$island; $b[0x19] = [byte]$no; $b[0x1A] = [byte]$owner; [Array]::Copy((& $i32 $res), 0, $b, 0x220, 4)
        $img.Write(0x622DC0 + $slot * 600, $b) }
    for ($s = 0; $s -lt 75; $s++) { $img.Write(0x622DC0 + $s * 600 + 0x18, [byte[]]@(0xFF)) }
    & $town 0 'Testhafen' 0 0 0 120; & $town 1 'Dorf' 1 0 6 0; & $town 2 'Rivalia' 1 1 1 300
    # Ship of player 0 at 70.5/100.5 (figure at 0x2200000).
    $sh = New-Object byte[] 0x328; $sh[0] = 0x50; $sh[0x28] = 0; [Array]::Copy([BitConverter]::GetBytes([long]($B + 0x2200000)), 0, $sh, 8, 8)
    $nm = [Text.Encoding]::ASCII.GetBytes('Secunda'); [Array]::Copy($nm, 0, $sh, 0x296, $nm.Length); $img.Write(0x1D8BB0, $sh)
    $fig = New-Object byte[] 0x30; [Array]::Copy([BitConverter]::GetBytes([single]70.5), 0, $fig, 0x28, 4); [Array]::Copy([BitConverter]::GetBytes([single]100.5), 0, $fig, 0x2C, 4); $img.Write(0x2200000, $fig)

    'Reading'
    $kinds = New-Object 'System.Collections.Generic.Dictionary[long,int]'
    $w = [AnnoIslandMap.Reader]::Read($img, $kinds)
    Test-That ("world 600 x 400, 3 islands, local player 0, camera 150/120 rotation 0 ({0} x {1}, {2}, {3}/{4}, {5})" -f $w.W, $w.H, $w.Islands.Count, $w.CamX, $w.CamY, $w.Rotation) ($w.W -eq 600 -and $w.H -eq 400 -and $w.Islands.Count -eq 3 -and $w.Local -eq 0 -and $w.CamX -eq 150 -and $w.CamY -eq 120 -and $w.Rotation -eq 0 -and $w.HasCamera)
    $a = $w.Islands[0]; $b2 = $w.Islands[1]; $c = $w.Islands[2]
    Test-That ("island 1: north, 1 large ore deposit 240 t, no gold, crops tobacco/sugar cane/wine, explored ({0} {1} {2} {3})" -f $a.Count(2), $a.Tons(2), $a.Count(3), [AnnoIslandMap.MapForm]::Crops($a)) ($a.Number -eq 1 -and -not $a.South -and $a.Count(2) -eq 1 -and $a.Tons(2) -eq 240 -and $a.Count(3) -eq 0 -and $a.HasCrop(0x2E) -and $a.HasCrop(0x30) -and $a.HasCrop(0x32) -and -not $a.HasCrop(0x2F) -and $a.Explored)
    Test-That ("island 2: south, gold 50 t + small ore 80 t, the 0x3A entry ignored, crops spices/cotton/cocoa ({0} deposits)" -f $b2.Deposits.Count) ($b2.Number -eq 2 -and $b2.South -and $b2.Deposits.Count -eq 2 -and $b2.Count(3) -eq 1 -and $b2.Tons(3) -eq 50 -and $b2.Count(2) -eq 1 -and $b2.Tons(2) -eq 80 -and $b2.Deposits[1].Size -eq 1 -and $b2.HasCrop(0x2F) -and $b2.HasCrop(0x31) -and $b2.HasCrop(0x33) -and -not $b2.HasCrop(0x2E))
    Test-That ("island 5 is the home island: 2 ore + 2 gold, all six crops, not explored ({0}, {1}/{2})" -f $c.Home, $c.Count(2), $c.Count(3)) ($c.Number -eq 5 -and $c.Home -and $c.Count(2) -eq 2 -and $c.Count(3) -eq 2 -and [AnnoIslandMap.MapForm]::Crops($c) -eq 'Ta Ge Zu Ba We Ka' -and -not $c.Explored -and -not $a.Home)
    Test-That ("towns on their islands, owners named ({0}; {1})" -f (($a.Towns | ForEach-Object { $_.Name }) -join ','), (($b2.Towns | ForEach-Object { $w.OwnerName($_.Owner) }) -join ',')) ($a.Towns.Count -eq 1 -and $a.Towns[0].Name -eq 'Testhafen' -and $a.Towns[0].Residents -eq 120 -and $b2.Towns.Count -eq 2 -and $w.OwnerName(6) -eq 'Ureinwohner' -and $w.OwnerName(0) -eq 'Du' -and $w.OwnerName(1) -eq 'Gegner 1' -and $a.SettledByPlayer -and $b2.SettledByPlayer -and -not $c.SettledByPlayer)
    Test-That ("your ship 'Secunda' at 70.5/100.5 ({0})" -f (($w.Ships | ForEach-Object { '{0} {1}/{2}' -f $_.Name, $_.X, $_.Y }) -join ',')) ($w.Ships.Count -eq 1 -and $w.Ships[0].Name -eq 'Secunda' -and $w.Ships[0].X -eq 70.5 -and $w.Ships[0].Y -eq 100.5)
    $cnt = @{}; $terr = @{}
    foreach ($d in $isl) {
        $land = 0; $rock = 0; $built = 0; $tw = @{}
        for ($y = $d.Y; $y -lt $d.Y + $d.H; $y++) { for ($x = $d.X; $x -lt $d.X + $d.W; $x++) { $g = $w.Grid[$y * 600 + $x]; switch ($g -band 3) { 1 { $land++ } 2 { $rock++ } 3 { $built++ } }; if (($g -band 3) -ne 0) { $tw[($g -shr 4) -band 7] = 1 } } }
        $cnt[$d.No] = '{0}/{1}/{2}' -f $land, $rock, $built; $terr[$d.No] = ($tw.Keys | Sort-Object) -join ','
    }
    Test-That ("grid: land/mountain/building tiles of every island as written ({0}); territory owners from the towns' number on the island: you / natives / none ({1})" -f (($isl | ForEach-Object { $cnt[$_.No] }) -join ' '), (($isl | ForEach-Object { $terr[$_.No] }) -join ' ')) (@($isl | Where-Object { $cnt[$_.No] -ne ('{0}/{1}/{2}' -f $landTotal[$_.No], $rockTotal[$_.No], $builtTotal[$_.No]) }).Count -eq 0 -and $builtTotal[0] -eq 6 -and $terr[0] -eq '0' -and $terr[1] -eq '6' -and $terr[4] -eq '7')
    $south = ($w.Grid[(60 + 35) * 600 + 300 + 40] -band 8) -ne 0; $north = ($w.Grid[(40 + 25) * 600 + 40 + 30] -band 8) -eq 0
    Test-That 'grid: southern island marked south, northern not' ($south -and $north)
    Test-That ("terrain kinds read once per gfx entry ({0} entries cached); terrain classes: sea 0x13-0x16, mountain 0xF/0x1F/0x20, built 0xE/0x1/0x23, land 0xA/0xB/0x17" -f $kinds.Count) ($kinds.Count -eq 4 -and (@(0x13, 0x14, 0x15, 0x16 | Where-Object { [AnnoIslandMap.Reader]::TerrainClass($_) -ne 0 }).Count -eq 0) -and (@(0xF, 0x1F, 0x20 | Where-Object { [AnnoIslandMap.Reader]::TerrainClass($_) -ne 2 }).Count -eq 0) -and (@(0xE, 0x1, 0x23 | Where-Object { [AnnoIslandMap.Reader]::TerrainClass($_) -ne 3 }).Count -eq 0) -and (@(0xA, 0xB, 0x17 | Where-Object { [AnnoIslandMap.Reader]::TerrainClass($_) -ne 1 }).Count -eq 0))
    Test-That ("players' colours from the game (+0x69): you yellow, rival 1 red ({0}/{1})" -f $w.PlayerColors[0], $w.PlayerColors[1]) ($w.PlayerColors[0] -eq 2 -and $w.PlayerColors[1] -eq 0 -and $w.OwnerColor(0).ToArgb() -eq [Drawing.Color]::FromArgb(246, 206, 30).ToArgb())

    'Projection (the game''s FUN_1400c4ba0 in all four rotations)'
    $v = New-Object AnnoIslandMap.View; $v.W = 600; $v.H = 400
    $worst = 0.0; $rotOk = $true
    foreach ($rot in 0..3) {
        $v.Rotation = $rot; $v.Update((New-Object Drawing.Size(1000, 520)))
        foreach ($p in @(@(0, 0), @(600, 0), @(0, 400), @(600, 400), @(123.5, 77.25), @(300, 200))) {
            $s = $v.ToScreen($p[0], $p[1]); $x = 0.0; $y = 0.0; $v.ToWorld($s.X, $s.Y, [ref]$x, [ref]$y)
            $worst = [Math]::Max($worst, [Math]::Abs($x - $p[0]) + [Math]::Abs($y - $p[1]))
            if ($s.X -lt -1 -or $s.Y -lt -1 -or $s.X -gt 1001 -or $s.Y -gt 521) { $rotOk = $false }
        }
    }
    Test-That ("world -> screen -> world round trip in all rotations (worst {0:0.0000} tiles), the whole world inside the panel" -f $worst) ($worst -lt 0.01 -and $rotOk)
    # Rotation 0 as in the game: +x goes right and down, +y left and down (FINDINGS: x tile = (+9.05, +4.48), y tile = (-9.05, +4.48)).
    $v.Rotation = 0; $v.Update((New-Object Drawing.Size(1000, 520)))
    $o = $v.ToScreen(300, 200); $px = $v.ToScreen(310, 200); $py = $v.ToScreen(300, 210)
    Test-That ("rotation 0: +x right/down, +y left/down, a tile twice as wide as high (dx {0:0.0}/{1:0.0}, dy {2:0.0}/{3:0.0})" -f ($px.X - $o.X), ($px.Y - $o.Y), ($py.X - $o.X), ($py.Y - $o.Y)) ($px.X -gt $o.X -and $px.Y -gt $o.Y -and $py.X -lt $o.X -and $py.Y -gt $o.Y -and [Math]::Abs(($px.X - $o.X) - 2 * ($px.Y - $o.Y)) -lt 0.01)
    # Each rotation turns the picture by 90 degrees: the corners of the world move one place on.
    $corner = { param($rot) $v.Rotation = $rot; $v.Update((New-Object Drawing.Size(1000, 520))); $s = $v.ToScreen(0, 0); $c2 = $v.ToScreen(300, 200); $du = ($s.X - $c2.X) / 2; $dv = $s.Y - $c2.Y; if ([Math]::Abs($dv) -gt [Math]::Abs($du)) { if ($dv -lt 0) { 'top' } else { 'bottom' } } elseif ($du -lt 0) { 'left' } else { 'right' } }
    $cs = @(0..3 | ForEach-Object { & $corner $_ })
    Test-That ("world corner 0/0 per rotation (turns by a quarter each): {0}" -f ($cs -join ', ')) (($cs -join ',') -eq 'top,right,bottom,left')

    'Rendering'
    $okPix = $true; $detail = @()
    foreach ($rot in 0..3) {
        $v.Rotation = $rot; $v.Update((New-Object Drawing.Size(900, 470)))
        $bmp = [AnnoIslandMap.Painter]::RenderBase($w, $v)
        foreach ($d in $isl) {
            $s = $v.ToScreen($d.X + $d.W / 2 - 0.5, $d.Y + $d.H / 2 + 0.5); $col = $bmp.GetPixel([int]$s.X, [int]$s.Y)
            if ($col.ToArgb() -eq [AnnoIslandMap.Painter]::Sea.ToArgb() -or $col.ToArgb() -eq [AnnoIslandMap.Painter]::Back.ToArgb()) { $okPix = $false; $detail += "rot $rot island $($d.No)" }
        }
        $s = $v.ToScreen(250, 300); $col = $bmp.GetPixel([int]$s.X, [int]$s.Y)
        if ($col.ToArgb() -ne [AnnoIslandMap.Painter]::Sea.ToArgb()) { $okPix = $false; $detail += "rot $rot sea" }
        $bmp.Save((Join-Path $dir "base-rot$rot.png")); $bmp.Dispose()
    }
    Test-That ("in all rotations the island centres are land and open sea is sea ({0})" -f $(if ($detail) { $detail -join ', ' } else { 'ok' })) $okPix

    'Window'
    $form = New-MapForm
    $form.FixedSource = $img
    $form.RefreshNow()
    $gold = $form.Filters | Where-Object { $_.Key.Text -eq 'Gold' } | Select-Object -First 1
    $gold.Key.Checked = $true
    $rows = @($form.IslandList.Items | ForEach-Object { $_.Text })
    Test-That ("filter gold: islands 2 and 5 in the list and marked ({0}; marked {1})" -f ($rows -join ','), $form.Map.Marked.Count) (($rows -join ',') -eq '2,5' -and $form.Map.Marked.Count -eq 2 -and $form.Map.FilterActive)
    $tab = $form.Filters | Where-Object { $_.Key.Text -eq 'Tabak' } | Select-Object -First 1
    $tab.Key.Checked = $true
    $rows2 = @($form.IslandList.Items | ForEach-Object { $_.Text })
    $free = $form.Filters | Where-Object { $_.Key.Text -like 'Frei*' } | Select-Object -First 1
    $free.Key.Checked = $true
    $rows3 = @($form.IslandList.Items | ForEach-Object { $_.Text })
    $gold.Key.Checked = $false; $tab.Key.Checked = $false; $free.Key.Checked = $false
    $rows4 = @($form.IslandList.Items | ForEach-Object { $_.Text })
    Test-That ("filters combine: gold + tobacco = {0}; + free = {1}; none = {2}" -f ($rows2 -join ','), ($rows3 -join ','), ($rows4 -join ',')) (($rows2 -join ',') -eq '5' -and ($rows3 -join ',') -eq '5' -and ($rows4 -join ',') -eq '1,2,5' -and -not $form.Map.FilterActive)
    $form.Map.Selected = $form.Map.Find(1); $txt = $form.DetailsText($form.Map.Selected)
    Test-That ("details of island 2 name gold, ore, crops and towns") ($txt -match 'Insel 2' -and $txt -match 'Gold: 1 × \(50 t' -and $txt -match 'Erz: 1 × \(klein 80 t\)' -and $txt -match 'Gewürze, Baumwolle, Kakao' -and $txt -match 'Dorf \(Ureinwohner\)' -and $txt -match 'Rivalia \(Gegner 1, 300 Einw.\)')
    $pngDe = Join-Path $dir 'window-de.png'
    $form.Map.Selected = $form.Map.Find(4)
    Save-FormImage $form $pngDe
    # Hit test in the real panel layout: the screen point of island 2's centre finds island 2.
    $form2 = New-MapForm; $form2.FixedSource = $img; $form2.StartPosition = 'Manual'; $form2.ShowInTaskbar = $false; $form2.Location = New-Object Drawing.Point(-32000, -32000)
    $form2.Show(); [Windows.Forms.Application]::DoEvents(); $form2.Clock.Stop(); $form2.RefreshNow()
    $pt = $form2.Map.View.ToScreen(340, 95); $hit = $form2.Map.IslandAt((New-Object Drawing.Point([int]$pt.X, [int]$pt.Y)))
    $form2.Map.View.ZoomAt(2.0, $pt.X, $pt.Y); $pt2 = $form2.Map.View.ToScreen(340, 95)
    Test-That ("hit test finds island 2 under its centre; zoom keeps the point under the mouse ({0}; {1:0.0}/{2:0.0} -> {3:0.0}/{4:0.0})" -f $(if ($hit) { $hit.Number } else { 'none' }), $pt.X, $pt.Y, $pt2.X, $pt2.Y) ($hit -and $hit.Number -eq 2 -and [Math]::Abs($pt2.X - $pt.X) -lt 0.5 -and [Math]::Abs($pt2.Y - $pt.Y) -lt 0.5)
    # The 2-second refresh reads on a worker thread and shows the result on the window's thread.
    $form2.Apply($null, 'leer'); $form2.Tick(); $waited = 0
    while ($null -eq $form2.World -and $waited -lt 100) { Start-Sleep -Milliseconds 50; [Windows.Forms.Application]::DoEvents(); $waited++ }
    Test-That ("refresh on a worker thread: world shown again after {0} ms ('{1}')" -f ($waited * 50), $form2.Status.Text) ($null -ne $form2.World -and $form2.World.Islands.Count -eq 3 -and $form2.Status.Text -match '3 Inseln: 2 mit Gold')
    $cells = @($form2.IslandList.Items | ForEach-Object { $_.SubItems[5].Text })
    Test-That ("list: crops 'alle 6' when all six grow ({0})" -f ($cells -join ' | ')) (($cells -join '|') -eq 'Ta Zu We|Ge Ba Ka|alle 6')
    $form2.Close()
    [AnnoIslandMap.L]::German = $false
    $form3 = New-MapForm; $form3.FixedSource = $img; $form3.RefreshNow()
    $txtEn = $form3.DetailsText($form3.Map.Find(1))
    $pngEn = Join-Path $dir 'window-en.png'; Save-FormImage $form3 $pngEn
    [AnnoIslandMap.L]::German = $true
    Test-That ("English texts ({0})" -f ($txtEn -split "`r?`n")[0]) ($txtEn -match '^Island 2 · south' -and $txtEn -match 'Crops at 100 %: Spices, Cotton, Cocoa' -and $txtEn -match 'Rivalia \(Rival 1, 300 residents\)')
    $sizes = @($pngDe, $pngEn | ForEach-Object { if (Test-Path $_) { (Get-Item $_).Length } else { 0 } })
    Test-That ("window rendered off-screen to PNG, German and English ({0} / {1} bytes, in {2})" -f $sizes[0], $sizes[1], $dir) ($sizes[0] -gt 20000 -and $sizes[1] -gt 20000)

    'Missing game'
    $empty = New-Object AnnoIslandMap.ImageSource
    $none = [AnnoIslandMap.Reader]::Read($empty, $kinds)
    $form4 = New-MapForm; $form4.FixedSource = $empty; $form4.RefreshNow()
    Test-That ("no world in an empty image, the window says so ('{0}')" -f $form4.Status.Text) ($null -eq $none -and $null -eq $form4.World -and $form4.IslandList.Items.Count -eq 0 -and $form4.Status.Text -match 'Spiel')
    $form4.Dispose()

    if ($script:fails) { "Island map self-test: $($script:fails) of $($script:checks) checks FAILED." ; exit 1 }
    "Island map self-test: all $($script:checks) checks passed."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }

if ($Dump -or $Snapshot) {
    $form = New-MapForm
    $form.Conn.Update()
    if (-not $form.Conn.Src) { "Game not attached: $($form.Conn.Status)"; exit 1 }
    if ($SnapshotRotation -ge 0) { $form.Map.RotationOverride = $SnapshotRotation }
    $form.RefreshNow()
    if ($Dump) { Write-WorldDump $form.World }
    if ($Snapshot) {
        $form.ClientSize = New-Object Drawing.Size($SnapshotWidth, $SnapshotHeight)
        $form.StartPosition = 'Manual'; $form.ShowInTaskbar = $false; $form.Location = New-Object Drawing.Point(-32000, -32000)
        $form.Show(); [Windows.Forms.Application]::DoEvents(); $form.Clock.Stop(); $form.RefreshNow()
        if ($SnapshotFilter) { foreach ($f in $form.Filters) { if ($f.Key.Text -eq $SnapshotFilter) { $f.Key.Checked = $true } } }
        if ($SnapshotIsland -gt 0) { $it = $form.Map.Find($SnapshotIsland - 1); if ($it) { $form.Map.Selected = $it; if (-not $SnapshotNoZoom) { $form.Map.View.FocusIsland($it, [Math]::Max(1, 1200.0 / [Math]::Max($it.W, $it.H))) }; $form.ShowDetails() } }
        [Windows.Forms.Application]::DoEvents()
        $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
        $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
        $bmp.Save($Snapshot, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $form.Close()
        "Snapshot: $Snapshot"
    }
    exit 0
}

# Normal start: one window only.
$created = $false
$mutex = New-Object Threading.Mutex($true, $(if ($TestShowSeconds -gt 0) { 'Local\AnnoIslandMapTest' } else { 'Local\AnnoIslandMap' }), [ref]$created)
if (-not $created) { exit 0 }
try {
    # The launcher starts the map with a hidden console; without this the window stays invisible (see UseUpHiddenStart).
    [void][AnnoIslandMap.Native]::UseUpHiddenStart()
    $form = New-MapForm
    if ($TestShowSeconds -gt 0) {
        $form.StartPosition = 'Manual'; $form.Location = New-Object Drawing.Point(-10000, -10000)
        $closer = New-Object Windows.Forms.Timer; $closer.Interval = 1000 * $TestShowSeconds
        $closer.Add_Tick({ $closer.Stop(); $form.Close() }); $closer.Start()
    }
    [Windows.Forms.Application]::Run($form)
}
finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
