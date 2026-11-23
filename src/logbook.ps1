<#
.SYNOPSIS
  Logbook: a small companion window for Anno 1602 History Edition that shows the current mission,
  your empire, the rivals and your achievements while you play.

.DESCRIPTION
  The window attaches to the running Anno1602.exe and only READS its memory (OpenProcess with
  PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, never a write). It refreshes every 2.5 seconds and
  survives the game not running yet, being closed or being restarted.

  Tab "Game" (Spiel):
    - the human's mission goals with live progress (the check mirrors the game's own mission
      check FUN_1400ae010, so "met" here means met for the game),
    - gold, towns, residents per population stage, ships, balance,
    - one line per computer rival (best town, total residents, gold; race progress in races),
    - game time (game clock converted to hours at normal speed) and the current speed,
    - the random events of the running game (written by anno-patcher.ps1 -Events into events.json),
    - 53 achievements, stored in %APPDATA%\Anno1602-Extensions\logbook.json with date and game,
    - a summary card when a game ends (won, lost, or left when the game closes or another game starts).
  Tab "History" (Verlauf): charts of gold, residents per stage, balance, towns and ships (one point
  about every game minute, by the game clock), the summary of the game shown and the list of played games.
  Each game's history is kept in %APPDATA%\Anno1602-Extensions\history\<start>.json (newest 30 files).
  Finished missions (scenario, won/lost, date, game hours) and the game summaries are stored in logbook.json.
  Section headers can be clicked to fold a section away.

  Memory layout: see docs\FINDINGS.md (sections "Big campaign maps, race, challenges",
  "Own scenarios", "Rivals and pirates", "Players and parties", "Logbook companion window").
  The text is German on a German Windows and English otherwise ($env:ANNO_EXTENSIONS_LANG = 'de'/'en').

.PARAMETER SelfTest
  Offline test without the game: builds memory images from the documented layouts, checks the
  reading and mission logic, renders the window to PNG files (German and English) and exits
  with exit code 0 (all checks passed) or 1.
#>
param(
    [switch]$SelfTest,
    # Folder for the PNG files of -SelfTest (default: %TEMP%\anno-logbook-selftest).
    [string]$SelfTestFolder,
    # For testing only: load the functions and return (dot-source the script with this switch).
    [Parameter(DontShow)][switch]$FunctionsOnly,
    # For testing only: read one snapshot, print it as JSON and exit.
    [Parameter(DontShow)][switch]$Dump,
    # For testing only: read the game once, render the window to this PNG and exit.
    [Parameter(DontShow)][string]$PreviewImage,
    # For testing only: attach to this process (an exe image loaded by the test) instead of Anno1602.exe.
    [Parameter(DontShow)][int]$TestProcessId = 0,
    [Parameter(DontShow)][long]$TestBase = 0,
    # For testing only: folder used instead of %APPDATA%.
    [Parameter(DontShow)][string]$AppDataFolder = $env:APPDATA,
    # For testing only: folder used instead of the Documents folder (own scenarios: chapters per campaign).
    [Parameter(DontShow)][string]$DocumentsFolder = [Environment]::GetFolderPath('MyDocuments'),
    # For testing only: run the window off-screen for this many refreshes (1 per second) and log each one.
    [Parameter(DontShow)][int]$TestTicks = 0,
    [Parameter(DontShow)][string]$TestLog,
    # For testing only: the normal window (own single-instance lock), off-screen, closes itself after this many seconds.
    [Parameter(DontShow)][int]$TestShowSeconds = 0
)
$ErrorActionPreference = 'Stop'

# UI language: German on a German Windows, English otherwise. Override: $env:ANNO_EXTENSIONS_LANG = 'de' or 'en'.
$UiGerman = if ($env:ANNO_EXTENSIONS_LANG) { $env:ANNO_EXTENSIONS_LANG -eq 'de' } else { (Get-UICulture).TwoLetterISOLanguageName -eq 'de' }
function Txt([string]$en, [string]$de) { if ($script:UiGerman) { $de } else { $en } }
function Get-Culture2 { if ($script:UiGerman) { [Globalization.CultureInfo]::GetCultureInfo('de-DE') } else { [Globalization.CultureInfo]::GetCultureInfo('en-US') } }
function Format-Num([double]$n) { $n.ToString('N0', (Get-Culture2)) }
function Format-Signed([double]$n) { if ($n -gt 0) { '+' + (Format-Num $n) } else { Format-Num $n } }

$Enc1252 = [Text.Encoding]::GetEncoding(1252)
$ExpectedHash = '7731972f696204faf6929b592ddedbf621b03426f85f9dd595c0c35904bdb7a1'   # same exe as anno-patcher.ps1

# ---------------------------------------------------------------------------------------------
# Memory layout (RVA = address - 0x140000000; all inside .data, RVA 0xF9000-0x913D28).
# ---------------------------------------------------------------------------------------------
$RvaSpeed = 0xF99F8             # int: 1 (F5), 2 (F6), 4 (F7; 8/12/16 with the patcher's turbo). Command 0x0F.
$RvaShips = 0x1D8BB0            # 200 ships x 0x328: byte 0 = 0x50 in use, +0x28 owner
$ShipSize = 0x328
$RvaScenario = 0x5C0E50         # "new game" parameter block: +0x12 flags (bit 1 = own scenario), +0x13 name (64 chars)
$RvaTimers = 0x5EBF68           # block 0x5EBF68..0x5EC1C3: lock (+0), game clock 0x5EC0F8, time limit 0x5EC1A8, difficulty 0x5EC1C0
$TimersLength = 0x25C
$RvaMissions = 0x5EC720         # 4 missions x 0x108C
$MissionSize = 0x108C
$RvaPlayers = 0x5F0960          # 7 players x 0x280
$PlayerSize = 0x280
$RvaLocalPlayer = 0x5F1D60      # int: number of the local (human) player
$RvaSettlements = 0x622DC0      # 75 settlements x 600 bytes
$SettlementSize = 600
$RvaIslands = 0x62DDC0          # 50 islands x 0x2CC8 (only read for monopoly goals)
$IslandSize = 0x2CC8
$RvaPopulation = 0x6BA02C       # 5 population groups x 0x50: +0 Maxwohn x 64, +4 tax
$RvaUnitCosts = 0x6D7E60        # 0x6D7E60 and 0x6D80A4/A8/AC/B0: upkeep per unit kind (balance, FUN_1400ad5d0)
$UnitCostsLength = 0x254
$ClockPerHour = 32700           # game clock units per hour at normal speed (FINDINGS: 523,094 in 60 min at 16x)

# History and game summaries.
$SampleClocks = [long]($ClockPerHour / 60)   # 545 = one game minute between two history points (game clock, not wall time)
$HistoryMaxSamples = 720        # cap per game: above it every second point is dropped and the interval doubles
$HistoryKeepFiles = 30          # history files kept (the newest ones)
$GamesKeep = 100                # game summaries kept in logbook.json
$QuitMinClocks = 5 * $SampleClocks   # a game left without a result is recorded only after 5 game minutes of play
$HistoryFields = @('clock', 'gold', 'residents', 'pioneers', 'settlers', 'citizens', 'merchants', 'aristocrats', 'workers', 'balance', 'towns', 'ships')

# ---------------------------------------------------------------------------------------------
# Native access, memory sources and the drawing canvas (C#).
# ---------------------------------------------------------------------------------------------
if (-not ('AnnoLogbook.Canvas' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace AnnoLogbook
{
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

        // Started hidden (the launcher starts the logbook with a hidden console): Windows applies that "hidden" to the
        // first window the process shows, so the logbook would never appear. Hiding the console (hidden anyway) uses it
        // up, as "powershell -WindowStyle Hidden" does. True if it was needed.
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

        // Reads size bytes at the address; null if the read fails or is incomplete.
        public static byte[] Read(IntPtr h, long address, int size)
        {
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

    // Where the bytes come from: the running game or a test image.
    public abstract class Source
    {
        public abstract byte[] Read(long rva, int size);
    }

    public sealed class ProcessSource : Source
    {
        public readonly IntPtr Handle;
        public readonly long Base;
        public ProcessSource(IntPtr handle, long imageBase) { Handle = handle; Base = imageBase; }
        public override byte[] Read(long rva, int size) { return Native.Read(Handle, Base + rva, size); }
    }

    // Test image: a list of written byte blocks, later writes win; unwritten bytes read as 0.
    public sealed class ImageSource : Source
    {
        private readonly List<KeyValuePair<long, byte[]>> parts = new List<KeyValuePair<long, byte[]>>();
        public void Write(long rva, byte[] data) { parts.Add(new KeyValuePair<long, byte[]>(rva, (byte[])data.Clone())); }
        public IList<KeyValuePair<long, byte[]>> Parts { get { return parts; } }
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
    }

    // Small helpers for the history (fast loops that would be slow in PowerShell).
    public static class Util
    {
        // One column of the history samples as doubles (chart data).
        public static double[] Column(List<long[]> rows, int col)
        {
            double[] r = new double[rows == null ? 0 : rows.Count];
            for (int i = 0; i < r.Length; i++) { long[] a = rows[i]; r[i] = (a != null && col < a.Length) ? a[col] : 0; }
            return r;
        }

        // One sample as a JSON array with invariant numbers.
        public static string JoinRow(long[] a)
        {
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < a.Length; i++) { if (i > 0) sb.Append(','); sb.Append(a[i].ToString(CultureInfo.InvariantCulture)); }
            return sb.Append(']').ToString();
        }
    }

    public enum Kind { Title, Header, Row, Stack, Badge, Note, Space, Tabs, Chart, Card }

    public sealed class Item
    {
        public Kind Kind = Kind.Row;
        public string Text = "", Right = "", Sub = "", Icon = "", Meter1 = "", Meter2 = "";
        public string Tip;
        public double Value1 = -1, Value2 = -1;
        public bool Bold, Done, Dim, Highlight;
        public Color TextColor = Color.Empty, RightColor = Color.Empty, IconColor = Color.Empty, BarColor = Color.Empty, SubColor = Color.Empty;
        public int[] Values;
        public Color[] Colors;
        public string[] Legend;
        public Rectangle Bounds;
        // Clickable item: a click raises Canvas.ItemClicked with this key (tabs: key + ":" + tab index).
        public string Key;
        // Header that folds its section away (chevron on the right).
        public bool Collapsible, Collapsed;
        // Card: label/value pairs (label, value, label, value ...) and a wrapped text below them.
        public string[] Cells;
        public string Body;
        // Chart: game clock per point, one value array per series; stacked areas or lines (green above zero, red below).
        public double[] X;
        public double[][] Series;
        public string[] SeriesNames;
        public string TotalName, EmptyText;
        public bool Stacked, ZeroSplit;
        public string Culture = "en-US";
        public double ClockPerHour = 32700;
        // Set by the layout: the tabs (Tabs) or the plot area (Chart).
        public Rectangle[] Parts;
    }

    public sealed class ClickArgs : EventArgs
    {
        public readonly string Key;
        public ClickArgs(string key) { Key = key; }
    }

    // Draws the whole content from a list of items (owner drawn: same look on every Windows).
    public sealed class Canvas : Control
    {
        public static readonly Color Back = Color.FromArgb(27, 31, 39);
        public static readonly Color Fore = Color.FromArgb(232, 226, 208);
        public static readonly Color DimColor = Color.FromArgb(150, 158, 172);
        public static readonly Color Accent = Color.FromArgb(217, 169, 58);
        public static readonly Color Good = Color.FromArgb(93, 187, 99);
        public static readonly Color Bad = Color.FromArgb(226, 112, 96);
        public static readonly Color Track = Color.FromArgb(52, 60, 74);
        public static readonly Color Rule = Color.FromArgb(58, 66, 80);
        public static readonly Color BadgeOn = Color.FromArgb(58, 48, 24);
        public static readonly Color BadgeOff = Color.FromArgb(35, 40, 50);
        private const TextFormatFlags Flags = TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.VerticalCenter;

        private List<Item> items = new List<Item>();
        private readonly ToolTip tip = new ToolTip();
        private string tipText;
        private bool inLayout;
        private Item hoverItem;
        private int hoverIndex = -1;
        private const int CardColumns = 3;

        // A clickable item (Item.Key) was clicked.
        public event EventHandler<ClickArgs> ItemClicked;
        private readonly Font fBase, fBold, fTitle, fSmall, fHeader;
        private readonly float dpiScale;

        public Canvas()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Back;
            fBase = new Font("Segoe UI", 9.5f);
            fBold = new Font("Segoe UI Semibold", 9.5f);
            fTitle = new Font("Segoe UI Semibold", 13f);
            fSmall = new Font("Segoe UI", 8.25f);
            fHeader = new Font("Segoe UI Semibold", 9f);
            using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) { dpiScale = g.DpiY / 96f; }
            tip.InitialDelay = 300; tip.ReshowDelay = 100; tip.AutoPopDelay = 30000;
        }

        public float DpiScale { get { return dpiScale; } }
        public int S(double v) { return (int)Math.Round(v * dpiScale); }
        public int ItemCount { get { return items.Count; } }

        public void SetItems(List<Item> list)
        {
            items = list ?? new List<Item>();
            hoverItem = null; hoverIndex = -1;
            Relayout();
            Invalidate();
        }

        // Key of the clickable item at this point (tabs: "key:index"), or null.
        public string KeyAt(Point p)
        {
            foreach (Item it in items)
            {
                if (string.IsNullOrEmpty(it.Key) || !it.Bounds.Contains(p)) continue;
                if (it.Kind == Kind.Tabs)
                {
                    if (it.Parts != null) for (int i = 0; i < it.Parts.Length; i++) if (it.Parts[i].Contains(p)) return it.Key + ":" + i;
                    return null;
                }
                return it.Key;
            }
            return null;
        }

        public void RaiseItemClick(string key)
        {
            EventHandler<ClickArgs> h = ItemClicked;
            if (h != null && !string.IsNullOrEmpty(key)) h(this, new ClickArgs(key));
        }

        protected override void OnMouseClick(MouseEventArgs e)
        {
            base.OnMouseClick(e);
            if (e.Button == MouseButtons.Left) RaiseItemClick(KeyAt(e.Location));
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (!inLayout) Relayout();
        }

        private int TextWidth(string s, Font f)
        {
            if (string.IsNullOrEmpty(s)) return 0;
            return TextRenderer.MeasureText(s, f, new Size(int.MaxValue, int.MaxValue), TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine).Width;
        }

        private static string BadgeText(Item it) { return (it.Done ? "★ " : "☆ ") + it.Text; }

        private int RowHeight(Item it)
        {
            int h = S(4) + fBold.Height;
            if (it.Value1 >= 0) h += S(3) + fSmall.Height + S(2) + S(7);
            if (!string.IsNullOrEmpty(it.Sub)) h += S(2) + fSmall.Height;
            return h + S(6);
        }

        private void Relayout()
        {
            inLayout = true;
            try
            {
                int x0 = S(14), w = Math.Max(S(120), Width - 2 * x0), y = S(8);
                int badgeH = fSmall.Height + S(8), bx = 0;
                bool flow = false;
                foreach (Item it in items)
                {
                    if (it.Kind != Kind.Badge && flow) { y += badgeH + S(6); flow = false; }
                    int h;
                    switch (it.Kind)
                    {
                        case Kind.Title:
                            h = fTitle.Height + (string.IsNullOrEmpty(it.Sub) ? 0 : S(2) + fBase.Height) + S(6);
                            it.Bounds = new Rectangle(x0, y, w, h); y += h; break;
                        case Kind.Header:
                            h = S(14) + fHeader.Height + S(6);
                            it.Bounds = new Rectangle(x0, y, w, h); y += h + S(4); break;
                        case Kind.Row:
                            h = RowHeight(it); it.Bounds = new Rectangle(x0, y, w, h); y += h; break;
                        case Kind.Stack:
                            h = S(4) + fBold.Height + S(4) + S(10) + S(6) + Legend(null, it, x0, 0, w) * (fSmall.Height + S(3)) + S(6);
                            it.Bounds = new Rectangle(x0, y, w, h); y += h; break;
                        case Kind.Badge:
                            int bw = Math.Min(w, TextWidth(BadgeText(it), fSmall) + S(18));
                            if (!flow) { flow = true; bx = x0; }
                            else if (bx + bw > x0 + w) { y += badgeH + S(6); bx = x0; }
                            it.Bounds = new Rectangle(bx, y, bw, badgeH); bx += bw + S(6); break;
                        case Kind.Note:
                            Font nf = it.Dim ? fSmall : fBase;
                            h = TextRenderer.MeasureText(it.Text ?? "", nf, new Size(w, int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding).Height + S(8);
                            it.Bounds = new Rectangle(x0, y, w, h); y += h; break;
                        case Kind.Tabs:
                            h = fBold.Height + S(12);
                            it.Bounds = new Rectangle(x0, y, w, h);
                            int nTabs = it.Legend == null ? 0 : it.Legend.Length, tx = x0;
                            it.Parts = new Rectangle[nTabs];
                            for (int i = 0; i < nTabs; i++) { int tw = TextWidth(it.Legend[i], fBold) + S(24); it.Parts[i] = new Rectangle(tx, y, tw, h); tx += tw; }
                            y += h + S(2); break;
                        case Kind.Chart:
                            h = ChartHeight(it, w);
                            it.Bounds = new Rectangle(x0, y, w, h);
                            it.Parts = new Rectangle[] { PlotRect(it.Bounds) };
                            y += h; break;
                        case Kind.Card:
                            h = CardHeight(it, w);
                            it.Bounds = new Rectangle(x0, y, w, h); y += h + S(6); break;
                        default:
                            it.Bounds = new Rectangle(x0, y, w, S(8)); y += S(8); break;
                    }
                }
                if (flow) y += badgeH + S(6);
                y += S(8);
                if (Height != y) Height = y;
            }
            finally { inLayout = false; }
        }

        private int Legend(Graphics g, Item it, int x0, int y0, int w)
        {
            if (it.Legend == null || it.Legend.Length == 0) return 0;
            int x = x0, y = y0, rows = 1, lh = fSmall.Height + S(3);
            for (int i = 0; i < it.Legend.Length; i++)
            {
                int cw = S(9) + S(5) + TextWidth(it.Legend[i], fSmall);
                if (x > x0 && x + cw > x0 + w) { x = x0; y += lh; rows++; }
                if (g != null)
                {
                    Color c = (it.Colors != null && i < it.Colors.Length) ? it.Colors[i] : DimColor;
                    using (SolidBrush b = new SolidBrush(c)) g.FillRectangle(b, x, y + (fSmall.Height - S(9)) / 2, S(9), S(9));
                    DrawLine(g, it.Legend[i], fSmall, new Rectangle(x + S(14), y, cw, fSmall.Height), Fore, TextFormatFlags.Left);
                }
                x += cw + S(14);
            }
            return rows;
        }

        private static Color Pick(Color c, Color fallback) { return c.IsEmpty ? fallback : c; }

        private void DrawLine(Graphics g, string s, Font f, Rectangle r, Color c, TextFormatFlags align)
        {
            if (string.IsNullOrEmpty(s) || r.Width <= 0) return;
            TextRenderer.DrawText(g, s, f, r, c, Flags | align);
        }

        private static GraphicsPath Round(Rectangle r, int rad)
        {
            GraphicsPath p = new GraphicsPath();
            int d = rad * 2;
            if (rad <= 0 || r.Width < d || r.Height < d) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        private void Bar(Graphics g, Rectangle r, double v, Color fill)
        {
            using (GraphicsPath p = Round(r, r.Height / 2)) using (SolidBrush b = new SolidBrush(Track)) g.FillPath(b, p);
            if (v <= 0) return;
            if (v > 1) v = 1;
            int w = Math.Max(r.Height, (int)Math.Round(r.Width * v));
            using (GraphicsPath p = Round(new Rectangle(r.X, r.Y, w, r.Height), r.Height / 2)) using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
        }

        private void Meter(Graphics g, string label, double v, Color color, int x, int y, int w)
        {
            DrawLine(g, label, fSmall, new Rectangle(x, y, w, fSmall.Height), DimColor, TextFormatFlags.Left);
            Bar(g, new Rectangle(x, y + fSmall.Height + S(2), w, S(7)), v, v >= 1 ? Good : Pick(color, Accent));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Back);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            foreach (Item it in items)
            {
                Rectangle r = it.Bounds;
                if (r.Height == 0 || !r.IntersectsWith(e.ClipRectangle)) continue;
                switch (it.Kind)
                {
                    case Kind.Title: PaintTitle(g, it, r); break;
                    case Kind.Header: PaintHeader(g, it, r); break;
                    case Kind.Row: PaintRow(g, it, r); break;
                    case Kind.Stack: PaintStack(g, it, r); break;
                    case Kind.Badge: PaintBadge(g, it, r); break;
                    case Kind.Tabs: PaintTabs(g, it, r); break;
                    case Kind.Chart: PaintChart(g, it, r); break;
                    case Kind.Card: PaintCard(g, it, r); break;
                    case Kind.Note:
                        TextRenderer.DrawText(g, it.Text, it.Dim ? fSmall : fBase, new Rectangle(r.X, r.Y + S(3), r.Width, r.Height), Pick(it.TextColor, it.Dim ? DimColor : Fore), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
                        break;
                }
            }
        }

        private void PaintTitle(Graphics g, Item it, Rectangle r)
        {
            int rw = TextWidth(it.Right, fBase);
            DrawLine(g, it.Text, fTitle, new Rectangle(r.X, r.Y, r.Width - rw - (rw > 0 ? S(10) : 0), fTitle.Height), Pick(it.TextColor, Accent), TextFormatFlags.Left);
            if (rw > 0) DrawLine(g, it.Right, fBase, new Rectangle(r.Right - rw, r.Y, rw, fTitle.Height), Pick(it.RightColor, Fore), TextFormatFlags.Right);
            if (!string.IsNullOrEmpty(it.Sub)) DrawLine(g, it.Sub, fBase, new Rectangle(r.X, r.Y + fTitle.Height + S(2), r.Width, fBase.Height), Pick(it.SubColor, DimColor), TextFormatFlags.Left);
        }

        private void PaintHeader(Graphics g, Item it, Rectangle r)
        {
            int ty = r.Y + S(14), rw = TextWidth(it.Right, fSmall), cw = it.Collapsible ? S(16) : 0;
            DrawLine(g, it.Text, fHeader, new Rectangle(r.X, ty, r.Width - rw - cw - (rw > 0 ? S(10) : 0), fHeader.Height), Pick(it.TextColor, Accent), TextFormatFlags.Left);
            if (rw > 0) DrawLine(g, it.Right, fSmall, new Rectangle(r.Right - cw - rw, ty, rw, fHeader.Height), Pick(it.RightColor, DimColor), TextFormatFlags.Right);
            if (it.Collapsible) Chevron(g, new Rectangle(r.Right - S(10), ty, S(10), fHeader.Height), it.Collapsed);
            using (Pen p = new Pen(Rule)) g.DrawLine(p, r.X, r.Bottom - 1, r.Right, r.Bottom - 1);
        }

        // Small triangle: pointing down (section open) or right (folded away).
        private void Chevron(Graphics g, Rectangle r, bool collapsed)
        {
            float cx = r.X + r.Width / 2f, cy = r.Y + r.Height / 2f, s = S(4);
            PointF[] pts = collapsed
                ? new PointF[] { new PointF(cx - s / 2, cy - s), new PointF(cx + s / 2 + 1, cy), new PointF(cx - s / 2, cy + s) }
                : new PointF[] { new PointF(cx - s, cy - s / 2), new PointF(cx + s, cy - s / 2), new PointF(cx, cy + s / 2 + 1) };
            using (SolidBrush b = new SolidBrush(DimColor)) g.FillPolygon(b, pts);
        }

        private void PaintTabs(Graphics g, Item it, Rectangle r)
        {
            using (Pen p = new Pen(Rule)) g.DrawLine(p, r.X, r.Bottom - 1, r.Right, r.Bottom - 1);
            if (it.Parts == null || it.Legend == null) return;
            int sel = (int)it.Value1;
            for (int i = 0; i < it.Parts.Length && i < it.Legend.Length; i++)
            {
                Rectangle t = it.Parts[i];
                bool on = i == sel;
                DrawLine(g, it.Legend[i], fBold, new Rectangle(t.X, t.Y, t.Width, t.Height - S(3)), on ? Accent : DimColor, TextFormatFlags.HorizontalCenter);
                if (on) using (SolidBrush b = new SolidBrush(Accent)) g.FillRectangle(b, t.X + S(6), t.Bottom - S(3), t.Width - S(12), S(3));
            }
        }

        private int CardRowHeight { get { return S(8) + fSmall.Height + S(1) + fBold.Height; } }

        private int CardHeight(Item it, int w)
        {
            int pad = S(10), inner = Math.Max(S(60), w - 2 * pad);
            int h = pad + fBold.Height;
            if (!string.IsNullOrEmpty(it.Sub)) h += S(2) + fSmall.Height;
            int n = it.Cells == null ? 0 : it.Cells.Length / 2;
            h += (n + CardColumns - 1) / CardColumns * CardRowHeight;
            if (!string.IsNullOrEmpty(it.Body)) h += S(8) + TextRenderer.MeasureText(it.Body, fSmall, new Size(inner, int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding).Height;
            return h + pad;
        }

        private void PaintCard(Graphics g, Item it, Rectangle r)
        {
            Rectangle rr = new Rectangle(r.X, r.Y, r.Width - 1, r.Height - 1);
            using (GraphicsPath p = Round(rr, S(8)))
            {
                using (SolidBrush b = new SolidBrush(BadgeOff)) g.FillPath(b, p);
                using (Pen pen = new Pen(Pick(it.BarColor, Accent))) g.DrawPath(pen, p);
            }
            int pad = S(10), x = r.X + pad, w = r.Width - 2 * pad, y = r.Y + pad;
            int rw = TextWidth(it.Right, fBold);
            if (rw > 0) DrawLine(g, it.Right, fBold, new Rectangle(x + w - rw, y, rw, fBold.Height), Pick(it.RightColor, Accent), TextFormatFlags.Right);
            DrawLine(g, it.Text, fBold, new Rectangle(x, y, w - rw - (rw > 0 ? S(10) : 0), fBold.Height), Pick(it.TextColor, Fore), TextFormatFlags.Left);
            y += fBold.Height;
            if (!string.IsNullOrEmpty(it.Sub)) { y += S(2); DrawLine(g, it.Sub, fSmall, new Rectangle(x, y, w, fSmall.Height), Pick(it.SubColor, DimColor), TextFormatFlags.Left); y += fSmall.Height; }
            int n = it.Cells == null ? 0 : it.Cells.Length / 2, cw = w / CardColumns;
            for (int i = 0; i < n; i++)
            {
                int cx = x + (i % CardColumns) * cw, cy = y + (i / CardColumns) * CardRowHeight + S(8);
                DrawLine(g, it.Cells[2 * i], fSmall, new Rectangle(cx, cy, cw - S(6), fSmall.Height), DimColor, TextFormatFlags.Left);
                DrawLine(g, it.Cells[2 * i + 1], fBold, new Rectangle(cx, cy + fSmall.Height + S(1), cw - S(6), fBold.Height), Fore, TextFormatFlags.Left);
            }
            y += (n + CardColumns - 1) / CardColumns * CardRowHeight;
            if (!string.IsNullOrEmpty(it.Body))
            {
                y += S(8);
                TextRenderer.DrawText(g, it.Body, fSmall, new Rectangle(x, y, w, Math.Max(1, r.Bottom - y)), DimColor, TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
            }
        }

        // ---- charts ----
        private int PlotHeight { get { return S(52); } }

        private int ChartHeight(Item it, int w)
        {
            int h = S(2) + fBase.Height + S(3) + PlotHeight + S(2) + fSmall.Height + S(8);
            if (it.Legend != null && it.Legend.Length > 0) h += S(3) + Legend(null, it, 0, 0, w) * (fSmall.Height + S(3));
            return h;
        }

        private Rectangle PlotRect(Rectangle r)
        {
            int gutter = S(44);
            return new Rectangle(r.X + gutter, r.Y + S(2) + fBase.Height + S(3), Math.Max(S(40), r.Width - gutter), PlotHeight);
        }

        private static CultureInfo CultureOf(Item it)
        {
            try { return CultureInfo.GetCultureInfo(string.IsNullOrEmpty(it.Culture) ? "en-US" : it.Culture); }
            catch (Exception) { return CultureInfo.InvariantCulture; }
        }

        // Short axis label: 850, 1.5k, 45k, 1.2M (German: 1,2 Mio.).
        private static string Short(double v, Item it)
        {
            CultureInfo ci = CultureOf(it);
            double a = Math.Abs(v);
            if (a >= 1000000) return (v / 1000000).ToString(a >= 10000000 ? "0" : "0.#", ci) + (ci.TwoLetterISOLanguageName == "de" ? " Mio." : "M");
            if (a >= 10000) return (v / 1000).ToString("0", ci) + "k";
            if (a >= 1000) return (v / 1000).ToString("0.#", ci) + "k";
            return v.ToString("0", ci);
        }

        private static double NiceUp(double v)
        {
            if (v <= 0) return 0;
            double e = Math.Pow(10, Math.Floor(Math.Log10(v)));
            double[] steps = { 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10 };
            foreach (double m in steps) if (m * e >= v - 1e-9) return m * e;
            return 10 * e;
        }

        private static string TimeText(Item it, double clock)
        {
            double cph = it.ClockPerHour > 0 ? it.ClockPerHour : 32700;
            long min = (long)Math.Floor(Math.Max(0, clock) * 60.0 / cph);
            return string.Format("{0} h {1:00} min", min / 60, min % 60);
        }

        private static Color SeriesColor(Item it, int k) { return (it.Colors != null && k < it.Colors.Length) ? it.Colors[k] : Accent; }

        private static double ValueAt(Item it, int k, int i) { double[] s = it.Series[k]; return (s != null && i < s.Length) ? s[i] : 0; }

        // Top edge of every series per point (stacked: running sum).
        private static double[][] Tops(Item it, int n)
        {
            double[][] tops = new double[it.Series.Length][];
            for (int k = 0; k < it.Series.Length; k++)
            {
                tops[k] = new double[n];
                for (int i = 0; i < n; i++) tops[k][i] = (it.Stacked && k > 0 ? tops[k - 1][i] : 0) + ValueAt(it, k, i);
            }
            return tops;
        }

        private int NearestIndex(Item it, Rectangle plot, int mx)
        {
            int n = it.X.Length;
            double x0 = it.X[0], x1 = it.X[n - 1];
            if (x1 <= x0) return n - 1;
            double v = x0 + (double)(mx - plot.X) / Math.Max(1, plot.Width - 1) * (x1 - x0);
            int best = 0; double bd = double.MaxValue;
            for (int i = 0; i < n; i++) { double d = Math.Abs(it.X[i] - v); if (d < bd) { bd = d; best = i; } }
            return best;
        }

        private static string ChartTip(Item it, int i)
        {
            CultureInfo ci = CultureOf(it);
            StringBuilder sb = new StringBuilder(TimeText(it, it.X[i]));
            double sum = 0;
            for (int k = 0; k < it.Series.Length; k++)
            {
                double v = ValueAt(it, k, i); sum += v;
                string name = (it.SeriesNames != null && k < it.SeriesNames.Length) ? it.SeriesNames[k] : "";
                sb.Append('\n').Append(name).Append(name.Length > 0 ? ": " : "").Append(v.ToString("N0", ci));
            }
            if (it.Stacked && it.Series.Length > 1 && !string.IsNullOrEmpty(it.TotalName)) sb.Append('\n').Append(it.TotalName).Append(": ").Append(sum.ToString("N0", ci));
            return sb.ToString();
        }

        private void PaintChart(Graphics g, Item it, Rectangle r)
        {
            int ty = r.Y + S(2), rw = TextWidth(it.Right, fBold);
            if (rw > 0) DrawLine(g, it.Right, fBold, new Rectangle(r.Right - rw, ty, rw, fBase.Height), Pick(it.RightColor, Fore), TextFormatFlags.Right);
            DrawLine(g, it.Text, fBase, new Rectangle(r.X, ty, r.Width - rw - (rw > 0 ? S(10) : 0), fBase.Height), Pick(it.TextColor, Fore), TextFormatFlags.Left);
            Rectangle plot = PlotRect(r);
            using (GraphicsPath p = Round(plot, S(4))) using (SolidBrush b = new SolidBrush(BadgeOff)) g.FillPath(b, p);
            int n = it.X == null ? 0 : it.X.Length;
            int ly = plot.Bottom + S(2);
            if (n < 2 || it.Series == null || it.Series.Length == 0)
            {
                TextRenderer.DrawText(g, it.EmptyText ?? "", fSmall, plot, DimColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
                if (it.Legend != null && it.Legend.Length > 0) Legend(g, it, r.X, ly + fSmall.Height + S(3), r.Width);
                return;
            }
            double[][] tops = Tops(it, n);
            double lo = 0, hi = 0;
            foreach (double[] t in tops) foreach (double v in t) { if (v < lo) lo = v; if (v > hi) hi = v; }
            hi = NiceUp(hi);
            lo = lo < 0 ? -NiceUp(-lo) : 0;
            if (hi <= lo) hi = lo + 1;
            double x0 = it.X[0], x1 = it.X[n - 1];
            if (x1 <= x0) x1 = x0 + 1;
            float pw = plot.Width - 1, ph = plot.Height - 1;
            Func<double, float> px = v => plot.X + (float)((v - x0) / (x1 - x0) * pw);
            Func<double, float> py = v => plot.Bottom - 1 - (float)((v - lo) / (hi - lo) * ph);

            // Grid: middle line, zero line; labels in the gutter on the left.
            using (Pen grid = new Pen(Rule)) g.DrawLine(grid, plot.X + S(3), (plot.Y + plot.Bottom) / 2f, plot.Right - S(3), (plot.Y + plot.Bottom) / 2f);
            int gw = plot.X - r.X - S(6);
            DrawLine(g, Short(hi, it), fSmall, new Rectangle(r.X, plot.Y - S(1), gw, fSmall.Height), DimColor, TextFormatFlags.Right);
            DrawLine(g, Short(lo, it), fSmall, new Rectangle(r.X, plot.Bottom - fSmall.Height + S(1), gw, fSmall.Height), DimColor, TextFormatFlags.Right);
            float zy = py(0);
            if (lo < 0)
            {
                using (Pen z = new Pen(DimColor)) { z.DashStyle = DashStyle.Dash; g.DrawLine(z, plot.X, zy, plot.Right, zy); }
                if (zy - plot.Y > fSmall.Height && plot.Bottom - zy > fSmall.Height)
                    DrawLine(g, "0", fSmall, new Rectangle(r.X, (int)zy - fSmall.Height / 2, gw, fSmall.Height), DimColor, TextFormatFlags.Right);
            }

            Region oldClip = g.Clip;
            g.SetClip(plot, CombineMode.Intersect);
            if (it.Stacked)
            {
                for (int k = 0; k < tops.Length; k++)
                {
                    PointF[] poly = new PointF[2 * n];
                    for (int i = 0; i < n; i++)
                    {
                        poly[i] = new PointF(px(it.X[i]), py(tops[k][i]));
                        poly[2 * n - 1 - i] = new PointF(px(it.X[i]), py(k > 0 ? tops[k - 1][i] : 0));
                    }
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(225, SeriesColor(it, k)))) g.FillPolygon(b, poly);
                }
                PointF[] top = new PointF[n];
                for (int i = 0; i < n; i++) top[i] = new PointF(px(it.X[i]), py(tops[tops.Length - 1][i]));
                using (Pen pen = new Pen(Fore, Math.Max(1f, S(1.5)))) { pen.LineJoin = LineJoin.Round; g.DrawLines(pen, top); }
            }
            else
            {
                for (int k = 0; k < tops.Length; k++)
                {
                    PointF[] pts = new PointF[n];
                    for (int i = 0; i < n; i++) pts[i] = new PointF(px(it.X[i]), py(tops[k][i]));
                    float baseY = it.ZeroSplit ? zy : py(lo);
                    PointF[] area = new PointF[n + 2];
                    Array.Copy(pts, area, n);
                    area[n] = new PointF(pts[n - 1].X, baseY); area[n + 1] = new PointF(pts[0].X, baseY);
                    if (it.ZeroSplit)
                    {
                        RectangleF above = new RectangleF(plot.X, plot.Y, plot.Width, Math.Max(0, zy - plot.Y));
                        RectangleF below = new RectangleF(plot.X, zy, plot.Width, Math.Max(0, plot.Bottom - zy));
                        foreach (bool up in new bool[] { true, false })
                        {
                            g.SetClip(plot); g.SetClip(up ? above : below, CombineMode.Intersect);
                            Color c = up ? Good : Bad;
                            using (SolidBrush b = new SolidBrush(Color.FromArgb(60, c))) g.FillPolygon(b, area);
                            using (Pen pen = new Pen(c, Math.Max(1f, S(2)))) { pen.LineJoin = LineJoin.Round; g.DrawLines(pen, pts); }
                        }
                        g.SetClip(plot);
                    }
                    else
                    {
                        Color c = SeriesColor(it, k);
                        if (tops.Length == 1) using (SolidBrush b = new SolidBrush(Color.FromArgb(55, c))) g.FillPolygon(b, area);
                        using (Pen pen = new Pen(c, Math.Max(1f, S(2)))) { pen.LineJoin = LineJoin.Round; g.DrawLines(pen, pts); }
                    }
                }
            }
            if (hoverItem == it && hoverIndex >= 0 && hoverIndex < n)
            {
                float hx = px(it.X[hoverIndex]);
                using (Pen hp = new Pen(Fore)) g.DrawLine(hp, hx, plot.Y, hx, plot.Bottom);
                for (int k = 0; k < tops.Length; k++)
                {
                    float hy = py(tops[k][hoverIndex]), d = S(5);
                    Color c = it.ZeroSplit ? (tops[k][hoverIndex] < 0 ? Bad : Good) : (it.Stacked ? Fore : SeriesColor(it, k));
                    using (SolidBrush b = new SolidBrush(c)) g.FillEllipse(b, hx - d / 2, hy - d / 2, d, d);
                }
            }
            g.Clip = oldClip;
            DrawLine(g, TimeText(it, it.X[0]), fSmall, new Rectangle(plot.X, ly, plot.Width / 2, fSmall.Height), DimColor, TextFormatFlags.Left);
            DrawLine(g, TimeText(it, it.X[n - 1]), fSmall, new Rectangle(plot.X + plot.Width / 2, ly, plot.Width - plot.Width / 2, fSmall.Height), DimColor, TextFormatFlags.Right);
            if (it.Legend != null && it.Legend.Length > 0) Legend(g, it, r.X, ly + fSmall.Height + S(3), r.Width);
        }

        private void PaintRow(Graphics g, Item it, Rectangle r)
        {
            if (it.Highlight)
            {
                using (GraphicsPath p = Round(new Rectangle(r.X - S(6), r.Y, r.Width + S(12), r.Height), S(6)))
                using (SolidBrush b = new SolidBrush(BadgeOn)) g.FillPath(b, p);
            }
            int y = r.Y + S(4), lh = fBold.Height;
            int indent = string.IsNullOrEmpty(it.Icon) ? 0 : S(20);
            if (indent > 0) DrawLine(g, it.Icon, fBold, new Rectangle(r.X, y, indent, lh), Pick(it.IconColor, it.Done ? Good : DimColor), TextFormatFlags.Left);
            int rw = TextWidth(it.Right, fBold);
            if (rw > 0) DrawLine(g, it.Right, fBold, new Rectangle(r.Right - rw, y, rw, lh), Pick(it.RightColor, it.Done ? Good : Fore), TextFormatFlags.Right);
            DrawLine(g, it.Text, it.Bold ? fBold : fBase, new Rectangle(r.X + indent, y, r.Width - indent - rw - (rw > 0 ? S(10) : 0), lh), Pick(it.TextColor, it.Dim ? DimColor : Fore), TextFormatFlags.Left);
            y += lh;
            int mx = r.X + indent, mw = r.Width - indent;
            if (it.Value1 >= 0)
            {
                y += S(3);
                if (it.Value2 >= 0)
                {
                    int half = (mw - S(14)) / 2;
                    Meter(g, it.Meter1, it.Value1, it.BarColor, mx, y, half);
                    Meter(g, it.Meter2, it.Value2, it.BarColor, mx + half + S(14), y, half);
                }
                else Meter(g, it.Meter1, it.Value1, it.BarColor, mx, y, mw);
                y += fSmall.Height + S(2) + S(7);
            }
            if (!string.IsNullOrEmpty(it.Sub))
            {
                y += S(2);
                DrawLine(g, it.Sub, fSmall, new Rectangle(mx, y, mw, fSmall.Height), Pick(it.SubColor, DimColor), TextFormatFlags.Left);
            }
        }

        private void PaintStack(Graphics g, Item it, Rectangle r)
        {
            int y = r.Y + S(4), lh = fBold.Height, rw = TextWidth(it.Right, fBold);
            if (rw > 0) DrawLine(g, it.Right, fBold, new Rectangle(r.Right - rw, y, rw, lh), Pick(it.RightColor, Fore), TextFormatFlags.Right);
            DrawLine(g, it.Text, it.Bold ? fBold : fBase, new Rectangle(r.X, y, r.Width - rw - (rw > 0 ? S(10) : 0), lh), Pick(it.TextColor, Fore), TextFormatFlags.Left);
            y += lh + S(4);
            Rectangle bar = new Rectangle(r.X, y, r.Width, S(10));
            using (GraphicsPath p = Round(bar, bar.Height / 2))
            {
                using (SolidBrush b = new SolidBrush(Track)) g.FillPath(b, p);
                long sum = 0;
                if (it.Values != null) foreach (int v in it.Values) if (v > 0) sum += v;
                if (sum > 0)
                {
                    Region old = g.Clip;
                    g.SetClip(p, CombineMode.Intersect);
                    double x = bar.X;
                    for (int i = 0; i < it.Values.Length; i++)
                    {
                        if (it.Values[i] <= 0) continue;
                        double sw = bar.Width * (double)it.Values[i] / sum;
                        Color c = (it.Colors != null && i < it.Colors.Length) ? it.Colors[i] : Accent;
                        using (SolidBrush b = new SolidBrush(c)) g.FillRectangle(b, (float)x, bar.Y, (float)sw + 0.6f, bar.Height);
                        x += sw;
                    }
                    g.Clip = old;
                }
            }
            Legend(g, it, r.X, y + S(10) + S(6), r.Width);
        }

        private void PaintBadge(Graphics g, Item it, Rectangle r)
        {
            Rectangle rr = new Rectangle(r.X, r.Y, r.Width - 1, r.Height - 1);
            Color fill = it.Highlight ? Accent : (it.Done ? BadgeOn : BadgeOff);
            Color text = it.Highlight ? Back : (it.Done ? Accent : DimColor);
            using (GraphicsPath p = Round(rr, S(8)))
            {
                using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
                using (Pen pen = new Pen(it.Done ? Accent : Rule)) g.DrawPath(pen, p);
            }
            DrawLine(g, BadgeText(it), fSmall, r, text, TextFormatFlags.HorizontalCenter);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            string t = null;
            Item hc = null; int hi = -1;
            foreach (Item it in items)
            {
                if (!it.Bounds.Contains(e.Location)) continue;
                if (it.Kind == Kind.Chart && it.X != null && it.X.Length >= 2 && it.Series != null && it.Series.Length > 0 && it.Parts != null && it.Parts.Length > 0 && it.Parts[0].Contains(e.Location))
                {
                    hc = it; hi = NearestIndex(it, it.Parts[0], e.X); t = ChartTip(it, hi); break;
                }
                if (!string.IsNullOrEmpty(it.Tip)) { t = it.Tip; break; }
            }
            if (hc != hoverItem || hi != hoverIndex)
            {
                if (hoverItem != null) Invalidate(hoverItem.Bounds);
                hoverItem = hc; hoverIndex = hi;
                if (hc != null) Invalidate(hc.Bounds);
            }
            if (t != tipText) { tipText = t; tip.SetToolTip(this, t ?? ""); }
            Cursor = KeyAt(e.Location) != null ? Cursors.Hand : Cursors.Default;
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            tipText = null;
            tip.SetToolTip(this, "");
            if (hoverItem != null) { Invalidate(hoverItem.Bounds); hoverItem = null; hoverIndex = -1; }
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            ScrollableControl p = Parent as ScrollableControl;
            if (p != null && p.VerticalScroll.Visible)
            {
                int y = Math.Max(0, -p.AutoScrollPosition.Y - e.Delta / 120 * S(48));
                p.AutoScrollPosition = new Point(0, y);
                HandledMouseEventArgs he = e as HandledMouseEventArgs;
                if (he != null) he.Handled = true;
                return;
            }
            base.OnMouseWheel(e);
        }
    }
}
'@
}

# ---------------------------------------------------------------------------------------------
# Reading: everything below works on byte arrays from a Source (game or test image).
# ---------------------------------------------------------------------------------------------
function Get-Text([byte[]]$b, [int]$o, [int]$max, [switch]$Multiline) {
    $end = [Array]::IndexOf($b, [byte]0, $o, $max)
    $n = if ($end -lt 0) { $max } else { $end - $o }
    if ($n -le 0) { return '' }
    $s = $Enc1252.GetString($b, $o, $n)
    if ($Multiline) { return ($s -replace "`r`n", "`n" -replace "`r", "`n" -replace '[\x00-\x09\x0B-\x1F]', ' ').Trim() }
    ($s -replace '[\x00-\x1F]', ' ').Trim()
}

# Integer division as in C (rounds toward zero).
function Divide-Trunc([long]$a, [long]$b) { if ($a -ge 0) { [long][Math]::Floor($a / $b) } else { - [long][Math]::Floor((-$a) / $b) } }

# One mission entry (0x108C bytes, layout of the loader FUN_1400b1780 / check FUN_1400ae010).
function ConvertFrom-MissionBytes([byte[]]$m, [int]$o = 0) {
    $town = foreach ($k in 0..2) { $t = $o + 0x1044 + 12 * $k; @{ Total = [BitConverter]::ToInt32($m, $t); Level = [BitConverter]::ToInt32($m, $t + 4); OfWhich = [long][BitConverter]::ToUInt32($m, $t + 8) } }
    $tri = { param($t) @{ Total = [BitConverter]::ToInt32($m, $t); Level = [BitConverter]::ToInt32($m, $t + 4); OfWhich = [long][BitConverter]::ToUInt32($m, $t + 8) } }
    $text = Get-Text $m ($o + 0x83C) 0x800 -Multiline          # text with [[n]] tags replaced by the game
    if (-not $text) { $text = Get-Text $m ($o + 0x3C) 0x800 -Multiline }
    @{
        Bits          = [long][BitConverter]::ToUInt32($m, $o)
        SubBits       = [long][BitConverter]::ToUInt32($m, $o + 4)
        SupportPlayer = [int]$m[$o + 8]
        DefeatCount   = [int]$m[$o + 9]
        MustDefeat    = [int[]]@(0..6 | ForEach-Object { $m[$o + 0x0A + $_] })
        Mono          = @(@{ Mat = [int]$m[$o + 0x11]; Count = [int]$m[$o + 0x12] }, @{ Mat = [int]$m[$o + 0x13]; Count = [int]$m[$o + 0x14] })
        Towns         = [BitConverter]::ToInt32($m, $o + 0x1C)
        SupportTowns  = [BitConverter]::ToInt32($m, $o + 0x24)
        Residents     = [BitConverter]::ToInt32($m, $o + 0x28)
        Balance       = [BitConverter]::ToInt32($m, $o + 0x30)
        TradeBalance  = [BitConverter]::ToInt32($m, $o + 0x34)
        Text          = $text
        Goods         = @(@{ Good = [int]$m[$o + 0x103C]; Qty = [int][BitConverter]::ToUInt16($m, $o + 0x103E) }, @{ Good = [int]$m[$o + 0x1040]; Qty = [int][BitConverter]::ToUInt16($m, $o + 0x1042) })
        Town          = @($town)
        AllTowns      = & $tri ($o + 0x1068)
        Support       = & $tri ($o + 0x1074)
        SupportSub    = & $tri ($o + 0x1080)
    }
}

# Reads everything the logbook needs. Returns $null if a read fails (game starting or exiting).
function Get-LogbookSnapshot($Source) {
    $pl = $Source.Read($RvaPlayers, $PlayerSize * 7); if ($null -eq $pl) { return $null }
    $tm = $Source.Read($RvaTimers, $TimersLength); if ($null -eq $tm) { return $null }
    $ms = $Source.Read($RvaMissions, $MissionSize * 4); if ($null -eq $ms) { return $null }
    $sb = $Source.Read($RvaSettlements, $SettlementSize * 75); if ($null -eq $sb) { return $null }
    $sh = $Source.Read($RvaShips, $ShipSize * 200); if ($null -eq $sh) { return $null }
    $sp = $Source.Read($RvaSpeed, 4); $lp = $Source.Read($RvaLocalPlayer, 4)
    $pop = $Source.Read($RvaPopulation, 5 * 0x50); $uc = $Source.Read($RvaUnitCosts, $UnitCostsLength)
    $sc = $Source.Read($RvaScenario, 0x54)
    if ($null -eq $sp -or $null -eq $lp -or $null -eq $pop -or $null -eq $uc -or $null -eq $sc) { return $null }

    $players = foreach ($i in 0..6) {
        $o = $i * $PlayerSize
        @{
            Slot = $i; Kind = [BitConverter]::ToInt32($pl, $o); Gold = [BitConverter]::ToInt32($pl, $o + 4)
            Name = Get-Text $pl ($o + 8) 0x40; No = [int]$pl[$o + 0x68]; CivFlags = [BitConverter]::ToInt32($pl, $o + 0x6C)
            Purchases = [long][BitConverter]::ToUInt32($pl, $o + 0x74); Sales = [long][BitConverter]::ToUInt32($pl, $o + 0x78)
            MissionSlot = [int]$pl[$o + 0x7C]; NativeAlly = [int]$pl[$o + 0x81]; Fulfilled = $pl[$o + 0x84] -ne 0
            SettlementByte = [int]$pl[$o + 0x86]; Special1 = [int]$pl[$o + 0x87]; Special2 = [int]$pl[$o + 0x88]
            Defeated = [int][BitConverter]::ToUInt16($pl, $o + 0x8E)
            Units = [long[]]@([BitConverter]::ToUInt16($pl, $o + 0xA4), [BitConverter]::ToUInt16($pl, $o + 0xA8), [BitConverter]::ToUInt16($pl, $o + 0xAA), [BitConverter]::ToUInt16($pl, $o + 0xAC), [BitConverter]::ToUInt16($pl, $o + 0xAE))
        }
    }

    # Settlements in table order (the order matters for the town goals). A slot counts if it is in use
    # (+0x18 island != 0xFF, as in the game) and has a name: the game names every new settlement
    # (FUN_14009a9f0), an all-zero table before the first game therefore counts as empty.
    $towns = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt 75; $i++) {
        $o = $i * $SettlementSize
        if ($sb[$o + 0x18] -eq 0xFF -or $sb[$o] -eq 0) { continue }
        $st = [long[]]@([BitConverter]::ToInt32($sb, $o + 0x220), [BitConverter]::ToInt32($sb, $o + 0x224), [BitConverter]::ToInt32($sb, $o + 0x228), [BitConverter]::ToInt32($sb, $o + 0x22C), [BitConverter]::ToInt32($sb, $o + 0x230))
        $cum = New-Object long[] 5; $acc = 0L
        for ($k = 4; $k -ge 0; $k--) { $acc += $st[$k]; $cum[$k] = $acc }   # local_58: this stage and all higher ones
        $workers = [long][BitConverter]::ToInt32($sb, $o + 0x218)
        $towns.Add(@{
                Index = $i; Offset = $o; Name = Get-Text $sb $o 0x18; Island = [int]$sb[$o + 0x18]; Owner = [int]$sb[$o + 0x1A]
                Workers = $workers; Stages = $st; Cum = $cum; Total = $workers + $acc
                Costs = [long][BitConverter]::ToInt32($sb, $o + 0x1D8); MilCosts = [long][BitConverter]::ToInt32($sb, $o + 0x1DC)
                TaxRates = [long[]]@($sb[$o + 0x24D], $sb[$o + 0x24E], $sb[$o + 0x24F], $sb[$o + 0x250], $sb[$o + 0x251])
            })
    }

    $ships = New-Object int[] 256
    for ($i = 0; $i -lt 200; $i++) { $o = $i * $ShipSize; if ($sh[$o] -eq 0x50) { $ships[$sh[$o + 0x28]]++ } }

    $missions = foreach ($k in 0..3) { ConvertFrom-MissionBytes $ms ($k * $MissionSize) }

    $snap = @{
        Lock = [BitConverter]::ToInt32($tm, 0); Clock = [long][BitConverter]::ToInt32($tm, 0x190)
        TimeLimit = [long][BitConverter]::ToInt32($tm, 0x240); Difficulty = [BitConverter]::ToInt32($tm, 0x258)
        Speed = [BitConverter]::ToInt32($sp, 0); LocalNo = [BitConverter]::ToInt32($lp, 0)
        Players = @($players); Settlements = $towns; SettlementBytes = $sb; ShipsByOwner = $ships
        Missions = @($missions)
        Taxes = [long[]]@(0..4 | ForEach-Object { [BitConverter]::ToInt32($pop, $_ * 0x50 + 4) })
        UnitCosts = [long[]]@([BitConverter]::ToInt32($uc, 0), [BitConverter]::ToInt32($uc, 0x244), [BitConverter]::ToInt32($uc, 0x248), [BitConverter]::ToInt32($uc, 0x24C), [BitConverter]::ToInt32($uc, 0x250))
        ScenarioName = Get-Text $sc 0x13 0x40; ScenarioCustom = ($sc[0x12] -band 2) -ne 0
        Islands = $null
    }
    # Islands only when a mission of a human or computer player has a monopoly goal (0x4000/0x8000).
    foreach ($p in $snap.Players) {
        if (($p.Kind -eq 0 -or $p.Kind -eq 0xC) -and $p.MissionSlot -le 3 -and ($snap.Missions[$p.MissionSlot].Bits -band 0xC000)) {
            $snap.Islands = $Source.Read($RvaIslands, $IslandSize * 50); break
        }
    }
    $snap
}

function Get-HumanSlot($snap) { if ($snap.LocalNo -ge 0 -and $snap.LocalNo -le 3) { [int]$snap.LocalNo } else { 0 } }
function Get-PlayerKind($snap, [int]$no) { if ($no -ge 0 -and $no -le 6) { $snap.Players[$no].Kind } else { -1 } }

# Goods stock of a settlement in 1/32 t (+0x2A + good x 12, as read by FUN_1400ae010).
function Get-Stock($snap, $s, [int]$good) {
    $at = $s.Offset + 0x2A + 12 * $good
    if ($good -lt 0 -or 0x2A + 12 * $good + 2 -gt $SettlementSize) { return 0 }
    [long][BitConverter]::ToUInt16($snap.SettlementBytes, $at)
}

# FUN_14009dbe0: does the island carry this raw material? 0x2D-0x3A = fertility bits (+0x5C),
# otherwise a deposit (+0x20 + i x 8 material, +0x26 + i x 8 quantity > 0x1F, count +0x41).
function Test-IslandMaterial([byte[]]$isl, [int]$island, [int]$mat) {
    if ($null -eq $isl -or $island -lt 0 -or $island -ge 50) { return $false }
    $o = $island * $IslandSize
    if ($mat -ge 0x2D -and $mat -lt 0x3B) { return ((([long][BitConverter]::ToUInt32($isl, $o + 0x5C)) -shr ($mat - 0x2D)) -band 1) -eq 1 }
    for ($i = [int]$isl[$o + 0x41] - 1; $i -ge 0; $i--) {
        if ($o + 0x28 + 8 * $i -gt $isl.Length) { continue }
        if ($isl[$o + 0x20 + 8 * $i] -eq $mat -and [BitConverter]::ToUInt16($isl, $o + 0x26 + 8 * $i) -gt 0x1F) { return $true }
    }
    $false
}

# FUN_1400bbdc0: taxes of one settlement.
function Get-SettlementTax($snap, $s) {
    $sum = 0L
    for ($k = 0; $k -lt 5; $k++) {
        $v = Divide-Trunc ($s.Stages[$k] * $snap.Taxes[$k] * 6) 32
        $sum += Divide-Trunc ($v * $s.TaxRates[$k]) 128
    }
    $sum
}

# FUN_1400ad5d0: the balance of the status window (field 6), as checked by the mission goal 0x100.
function Get-Balance($snap, [int]$no) {
    $taxes = 0L; $costs = 0L
    foreach ($s in $snap.Settlements) {
        if ($s.Owner -ne $no) { continue }
        $taxes += Get-SettlementTax $snap $s
        $c = $s.Costs
        if ((Get-PlayerKind $snap $s.Owner) -eq 0) { $c += $s.MilCosts }
        $costs += $c
    }
    $mil = 0L
    if ((Get-PlayerKind $snap $no) -eq 0) { for ($k = 0; $k -lt 5; $k++) { $mil += $snap.Players[$no].Units[$k] * $snap.UnitCosts[$k] } }
    $sales = 0L; $purchases = 0L
    if ($no -ge 0 -and $no -le 6) { $sales = Divide-Trunc $snap.Players[$no].Sales 480; $purchases = Divide-Trunc $snap.Players[$no].Purchases 480 }
    @{ Taxes = $taxes; Costs = $costs; Military = $mil; Sales = $sales; Purchases = $purchases; Balance = $taxes + ((($sales - $purchases) - $costs) - $mil); Trade = $sales - $purchases }
}

function Test-TownGoal($s, $g) {
    if ($g.Level -lt 0 -or $g.Level -gt 4) { return $false }
    ($g.OfWhich -le $s.Cum[$g.Level]) -and ($g.Total -le $s.Total)
}

# ---------------------------------------------------------------------------------------------
# Names and labels.
# ---------------------------------------------------------------------------------------------
function Get-StageName([int]$k) {
    switch ($k) {
        0 { Txt 'Pioneers' 'Pioniere' }; 1 { Txt 'Settlers' 'Siedler' }; 2 { Txt 'Citizens' 'Bürger' }
        3 { Txt 'Merchants' 'Kaufleute' }; 4 { Txt 'Aristocrats' 'Aristokraten' }; default { "?$k" }
    }
}
# Goods list of the exe (NOWARE = 0, ALLWARE = 1, EISENERZ = 2 ... ZIEGEL = 24).
$GoodsDe = @('–', 'alle Waren', 'Eisenerz', 'Gold', 'Wolle', 'Zucker', 'Tabak', 'Fleisch', 'Korn', 'Mehl', 'Eisen', 'Schwerter', 'Musketen', 'Kanonen', 'Nahrung', 'Tabakwaren', 'Gewürze', 'Kakao', 'Alkohol', 'Stoffe', 'Kleidung', 'Schmuck', 'Werkzeug', 'Holz', 'Ziegel')
$GoodsEn = @('–', 'all goods', 'iron ore', 'gold', 'wool', 'sugar', 'tobacco', 'cattle', 'grain', 'flour', 'iron', 'swords', 'muskets', 'cannons', 'food', 'tobacco products', 'spices', 'cocoa', 'liquor', 'cloth', 'clothes', 'jewellery', 'tools', 'wood', 'bricks')
# Raw materials from GETREIDE = 0x2D (monopoly goals).
$RawDe = @('Getreide', 'Tabak', 'Gewürze', 'Zuckerrohr', 'Baumwolle', 'Wein', 'Kakao', 'Gras', 'Bäume', 'Steine', 'Erz', 'Wild', 'Fische', 'Schätze')
$RawEn = @('grain', 'tobacco', 'spices', 'sugar cane', 'cotton', 'wine', 'cocoa', 'grass', 'trees', 'stone', 'ore', 'game', 'fish', 'treasure')
function Get-GoodName([int]$g) {
    $list = if ($script:UiGerman) { $GoodsDe } else { $GoodsEn }
    if ($g -ge 0 -and $g -lt $list.Count) { $list[$g] } else { (Txt 'good {0}' 'Ware {0}') -f $g }
}
function Get-MaterialName([int]$m) {
    $list = if ($script:UiGerman) { $RawDe } else { $RawEn }
    if ($m -ge 0x2D -and $m -lt 0x2D + $list.Count) { return $list[$m - 0x2D] }
    Get-GoodName $m
}
function Get-PlayerName($snap, [int]$slot) {
    if ($slot -lt 0 -or $slot -gt 6) { return '?' }
    $p = $snap.Players[$slot]
    if ($p.Name) {
        # Several players with the same (default) name: add the slot number.
        $same = @(0..3 | Where-Object { $_ -ne $slot -and $snap.Players[$_].Name -eq $p.Name }).Count
        if ($same) { return '{0} ({1})' -f $p.Name, $slot }
        return $p.Name
    }
    if ($slot -eq (Get-HumanSlot $snap)) { return (Txt 'You' 'Du') }
    (Txt 'Rival {0}' 'Gegner {0}') -f $slot
}
function Format-GameTime([long]$clock) {
    $min = [long][Math]::Floor([Math]::Max(0, $clock) * 60.0 / $ClockPerHour)
    '{0} h {1:00} min' -f [long][Math]::Floor($min / 60), ($min % 60)
}
# Mission time limit (0x5EC1A8, set by the patcher's TIMERS hook from the scenario) in the units of the game's own clock,
# which it draws while a limit is set: clock / 600 minutes, (clock % 600) / 10 seconds ("%02d:%02d"). The mission texts
# use the same units ("3 Stunden ... bei 180:00").
function Format-TimeLimit([long]$limit, [long]$clock) {
    $leftMin = [long][Math]::Floor([Math]::Max(0, $limit - $clock) / 600.0)
    $now = '{0:00}:{1:00}' -f [long][Math]::Floor([Math]::Max(0, $clock) / 600.0), [long][Math]::Floor(([Math]::Max(0, $clock) % 600) / 10.0)
    (Txt 'Time limit: {0} h {1:00} min left (clock {2} of {3}:00)' 'Zeitlimit: noch {0} h {1:00} min (Uhr {2} von {3}:00)') -f [long][Math]::Floor($leftMin / 60), ($leftMin % 60), $now, [long][Math]::Floor($limit / 600.0)
}
function Get-SpeedText([int]$speed) {
    $name = switch ($speed) {
        1 { Txt 'normal' 'normal' }; 2 { Txt 'fast' 'schnell' }; 4 { Txt 'very fast' 'sehr schnell' }
        default { if ($speed -gt 4) { 'Turbo' } else { '?' } }
    }
    (Txt 'Speed ×{0} ({1})' 'Tempo ×{0} ({1})') -f $speed, $name
}
function Get-Ratio([double]$cur, [double]$target) {
    if ($target -le 0) { if ($cur -ge $target) { return 1.0 } else { return 0.0 } }
    [Math]::Max(0.0, [Math]::Min(1.0, $cur / $target))
}

# ---------------------------------------------------------------------------------------------
# Mission check: mirror of FUN_1400ae010 (game check per player) plus the values for the display.
# Returns $null if the player has no mission the game would check. -AnyKind: also when the player is
# no longer kind 0 (the human after the end of the game is kind 9).
# ---------------------------------------------------------------------------------------------
function Get-MissionEvaluation($snap, [int]$slot, [switch]$AnyKind) {
    $p = $snap.Players[$slot]
    if ($p.MissionSlot -gt 3) { return $null }
    $m = $snap.Missions[$p.MissionSlot]
    $bits = $m.Bits
    if ($bits -eq 0 -or -not ($AnyKind -or $p.Kind -eq 0 -or ($bits -band 0x800))) { return $null }
    $no = $p.No
    $got = [long]0xCD08     # start value of the game: 0x8, 0x100, 0x400, 0x800, 0x4000, 0x8000 are "met until disproved"
    $sub = $m.SubBits
    $townBy = @{}; $supportBy = $null
    $goods = [long[]]@(0, 0); $mono = [int[]]@(0, 0); $monoBlock = @((New-Object Collections.ArrayList), (New-Object Collections.ArrayList))
    $own = New-Object Collections.ArrayList
    $ownTotal = 0L; $supportCount = 0; $allOk = 0
    foreach ($s in $snap.Settlements) {
        if ($s.Owner -eq $no) {
            [void]$own.Add($s)
            if ($bits -band 1) {
                if (-not ($got -band 1) -and (Test-TownGoal $s $m.Town[0])) { $got = $got -bor 1; $townBy[0] = $s }
                elseif ($bits -band 2) {
                    if (-not ($got -band 2) -and (Test-TownGoal $s $m.Town[1])) { $got = $got -bor 2; $townBy[1] = $s }
                    elseif (($bits -band 4) -and -not ($got -band 4) -and (Test-TownGoal $s $m.Town[2])) { $got = $got -bor 4; $townBy[2] = $s }
                }
            }
            if (Test-TownGoal $s $m.AllTowns) { $allOk++ } else { $got = $got -band (-bnot [long]8) }
            if ($bits -band 0x1000) { $goods[0] += Get-Stock $snap $s $m.Goods[0].Good }
            if ($bits -band 0x2000) { $goods[1] += Get-Stock $snap $s $m.Goods[1].Good }
            if (($bits -band 0x4000) -and (Test-IslandMaterial $snap.Islands $s.Island $m.Mono[0].Mat)) { $mono[0]++ }
            if (($bits -band 0x8000) -and (Test-IslandMaterial $snap.Islands $s.Island $m.Mono[1].Mat)) { $mono[1]++ }
            $ownTotal += $s.Total
        }
        else {
            $match = ($m.SupportPlayer -eq 7 -or $m.SupportPlayer -eq $s.Owner)
            if (($bits -band 0x10) -and $match) {
                if (Test-TownGoal $s $m.Support) { $got = $got -bor 0x10; if (-not $supportBy) { $supportBy = $s } }
            }
            if (($sub -band 1) -and $match -and (Test-TownGoal $s $m.SupportSub)) { $sub = $sub -band (-bnot [long]1) }
            if (($sub -band 2) -and $match) { $supportCount++ }
            $k = Get-PlayerKind $snap $s.Owner
            if ($k -eq 0 -or $k -eq 0xC) {
                foreach ($j in 0, 1) {
                    $bit = 0x4000 -shl $j
                    if (($bits -band $bit) -and (Test-IslandMaterial $snap.Islands $s.Island $m.Mono[$j].Mat)) { $got = $got -band (-bnot [long]$bit); [void]$monoBlock[$j].Add($s) }
                }
            }
        }
    }
    foreach ($j in 0, 1) { if (($bits -band (0x4000 -shl $j)) -and $mono[$j] -lt $m.Mono[$j].Count) { $got = $got -band (-bnot [long](0x4000 -shl $j)) } }
    if (($bits -band 0x80) -and $m.Residents -le $ownTotal) { $got = $got -bor 0x80 }
    if (($bits -band 0x20) -and $m.Towns -le $own.Count) { $got = $got -bor 0x20 }
    if (($sub -band 2) -and $m.SupportTowns -le $supportCount) { $sub = $sub -band (-bnot [long]2) }
    if (($bits -band 0x20000) -and $p.Special1 -ne 0) { $got = $got -bor 0x20000 }
    if (($bits -band 0x40000) -and $p.Special2 -ne 0) { $got = $got -bor 0x40000 }
    if (($bits -band 0x1000) -and $m.Goods[0].Qty -le $goods[0]) { $got = $got -bor 0x1000 }
    if (($bits -band 0x2000) -and $m.Goods[1].Qty -le $goods[1]) { $got = $got -bor 0x2000 }
    if (($bits -band 0x200) -and $m.DefeatCount -le $p.Defeated) { $got = $got -bor 0x200 }
    $mustList = New-Object Collections.ArrayList; $mustOut = 0
    for ($i = 0; $i -lt 7; $i++) {
        if ($m.MustDefeat[$i] -eq 0) { continue }
        $q = $snap.Players[$i]
        $out = ($q.Kind -eq 9) -or ($q.Kind -eq 0xB -and $q.SettlementByte -eq 0 -and $q.NativeAlly -eq $slot)
        [void]$mustList.Add(@{ Slot = $i; Out = $out })
        if ($out) { $mustOut++ } elseif ($bits -band 0x400) { $got = $got -band (-bnot [long]0x400) }
    }
    $money = Get-Balance $snap $no
    if (($bits -band 0x10000) -and $m.TradeBalance -le $money.Trade) { $got = $got -bor 0x10000 }
    $fulfilled = $false
    if (($bits -band $got) -eq $bits) {
        if (($bits -band 0x100) -and $money.Balance -lt $m.Balance) { $got = $got -band (-bnot [long]0x100) }
        $fulfilled = ($bits -band $got) -eq $bits
    }
    elseif (($bits -band 0x100) -and $money.Balance -lt $m.Balance) { $got = $got -band (-bnot [long]0x100) }   # display only

    # ---- display values ----
    $goals = New-Object Collections.ArrayList
    $add = { param($id, $done, $title, $meters, $subText) [void]$goals.Add(@{ Id = $id; Done = [bool]$done; Title = $title; Meters = @($meters); Sub = $subText }) }
    $meter = { param($label, $cur, $target) @{ Label = $label; Value = (Get-Ratio $cur $target) } }
    $used = @{}; foreach ($t in $townBy.Values) { $used[$t.Index] = 1 }
    foreach ($k in 0..2) {
        if (-not ($bits -band (1 -shl $k)) -or -not ($bits -band 1)) { continue }
        $g = $m.Town[$k]; $lvl = [Math]::Max(0, [Math]::Min(4, $g.Level))
        $t = $townBy[$k]
        if (-not $t) {
            $best = $null; $bestScore = -1.0
            foreach ($s in $own) {
                if ($used.ContainsKey($s.Index)) { continue }
                $score = (Get-Ratio $s.Total $g.Total) + (Get-Ratio $s.Cum[$lvl] $g.OfWhich)
                if ($score -gt $bestScore) { $best = $s; $bestScore = $score }
            }
            $t = $best
        }
        $tot = if ($t) { $t.Total } else { 0 }; $ofw = if ($t) { $t.Cum[$lvl] } else { 0 }
        $title = (Txt 'Town {0}: {1} residents, {2} {3}+' 'Stadt {0}: {1} Einw., {2} {3}+') -f ($k + 1), (Format-Num $g.Total), (Format-Num $g.OfWhich), (Get-StageName $lvl)
        $ms2 = @((& $meter ((Txt 'Residents {0} / {1}' 'Einwohner {0} / {1}') -f (Format-Num $tot), (Format-Num $g.Total)) $tot $g.Total),
            (& $meter ('{0}+ {1} / {2}' -f (Get-StageName $lvl), (Format-Num $ofw), (Format-Num $g.OfWhich)) $ofw $g.OfWhich))
        $subText = if ($townBy[$k]) { (Txt 'met by {0}' 'erfüllt von {0}') -f $t.Name } elseif ($t) { (Txt 'best candidate: {0}' 'bester Kandidat: {0}') -f $t.Name } else { Txt 'no town yet' 'noch keine Stadt' }
        & $add "town$k" ($got -band (1 -shl $k)) $title $ms2 $subText
    }
    if ($bits -band 8) {
        $g = $m.AllTowns; $lvl = [Math]::Max(0, [Math]::Min(4, $g.Level))
        $title = (Txt 'Every town: {0} residents, {1} {2}+' 'Jede Stadt: {0} Einw., {1} {2}+') -f (Format-Num $g.Total), (Format-Num $g.OfWhich), (Get-StageName $lvl)
        & $add 'alltowns' ($got -band 8) $title @(& $meter ((Txt '{0} of {1} towns qualify' '{0} von {1} Städten erfüllen das') -f $allOk, $own.Count) $allOk ([Math]::Max(1, $own.Count))) ''
    }
    if ($bits -band 0x20) { & $add 'towns' ($got -band 0x20) ((Txt 'At least {0} towns' 'Mindestens {0} Städte') -f $m.Towns) @(& $meter ('{0} / {1}' -f $own.Count, $m.Towns) $own.Count $m.Towns) '' }
    if ($bits -band 0x80) { & $add 'residents' ($got -band 0x80) ((Txt '{0} residents in total' '{0} Einwohner insgesamt') -f (Format-Num $m.Residents)) @(& $meter ('{0} / {1}' -f (Format-Num $ownTotal), (Format-Num $m.Residents)) $ownTotal $m.Residents) '' }
    foreach ($j in 0, 1) {
        if (-not ($bits -band (0x1000 -shl $j))) { continue }
        $gd = $m.Goods[$j]; $need = $gd.Qty / 32.0; $have = $goods[$j] / 32.0
        & $add "goods$j" ($got -band (0x1000 -shl $j)) ((Txt '{0} t of {1} in stock' '{0} t {1} auf Lager') -f (Format-Num $need), (Get-GoodName $gd.Good)) @(& $meter ('{0} t / {1} t' -f (Format-Num ([Math]::Floor($have))), (Format-Num $need)) $have $need) ''
    }
    foreach ($j in 0, 1) {
        if (-not ($bits -band (0x4000 -shl $j))) { continue }
        $mo = $m.Mono[$j]
        $blockers = @($monoBlock[$j] | ForEach-Object { Get-PlayerName $snap $_.Owner } | Select-Object -Unique)
        $subText = if ($blockers.Count) { (Txt 'blocked: {0} settled on such an island' 'blockiert: {0} siedelt auf so einer Insel') -f ($blockers -join ', ') } else { '' }
        $islands = if ($mo.Count -eq 1) { Txt '1 island' '1 Insel' } else { (Txt '{0} islands' '{0} Inseln') -f $mo.Count }
        & $add "mono$j" ($got -band (0x4000 -shl $j)) ((Txt 'Monopoly on {0}: {1}' 'Monopol {0}: {1}') -f (Get-MaterialName $mo.Mat), $islands) @(& $meter ((Txt 'your islands {0} / {1}' 'eigene Inseln {0} / {1}') -f $mono[$j], $mo.Count) $mono[$j] $mo.Count) $subText
    }
    if ($bits -band 0x100) { & $add 'balance' ($money.Balance -ge $m.Balance) ((Txt 'Balance at least {0}' 'Bilanz mindestens {0}') -f (Format-Signed $m.Balance)) @(& $meter ('{0} / {1}' -f (Format-Signed $money.Balance), (Format-Signed $m.Balance)) $money.Balance $m.Balance) '' }
    if ($bits -band 0x10000) { & $add 'trade' ($got -band 0x10000) ((Txt 'Trade balance at least {0}' 'Handelsbilanz mindestens {0}') -f (Format-Signed $m.TradeBalance)) @(& $meter ('{0} / {1}' -f (Format-Signed $money.Trade), (Format-Signed $m.TradeBalance)) $money.Trade $m.TradeBalance) '' }
    if ($bits -band 0x200) { & $add 'defeatcount' ($got -band 0x200) ($(if ($m.DefeatCount -eq 1) { Txt 'Defeat 1 rival' 'Besiege 1 Gegner' } else { (Txt 'Defeat {0} rivals' 'Besiege {0} Gegner') -f $m.DefeatCount })) @(& $meter ('{0} / {1}' -f $p.Defeated, $m.DefeatCount) $p.Defeated $m.DefeatCount) '' }
    if ($bits -band 0x400) {
        $names = ($mustList | ForEach-Object { Get-PlayerName $snap $_.Slot }) -join ', '
        $left = ($mustList | Where-Object { -not $_.Out } | ForEach-Object { Get-PlayerName $snap $_.Slot }) -join ', '
        & $add 'defeat' ($got -band 0x400) ((Txt 'Defeat: {0}' 'Besiege: {0}') -f $names) @(& $meter ((Txt 'defeated {0} / {1}' 'besiegt {0} / {1}') -f $mustOut, $mustList.Count) $mustOut ([Math]::Max(1, $mustList.Count))) $(if ($left) { (Txt 'still in the game: {0}' 'noch im Spiel: {0}') -f $left } else { '' })
    }
    if ($bits -band 0x10) {
        $g = $m.Support; $lvl = [Math]::Max(0, [Math]::Min(4, $g.Level))
        $who = if ($m.SupportPlayer -eq 7) { Txt 'any player' 'irgendeinen Mitspieler' } else { Get-PlayerName $snap $m.SupportPlayer }
        $t = $supportBy
        if (-not $t) {
            $bestScore = -1.0
            foreach ($s in $snap.Settlements) {
                if ($s.Owner -eq $no -or -not ($m.SupportPlayer -eq 7 -or $m.SupportPlayer -eq $s.Owner)) { continue }
                $score = (Get-Ratio $s.Total $g.Total) + (Get-Ratio $s.Cum[$lvl] $g.OfWhich)
                if ($score -gt $bestScore) { $t = $s; $bestScore = $score }
            }
        }
        $tot = if ($t) { $t.Total } else { 0 }; $ofw = if ($t) { $t.Cum[$lvl] } else { 0 }
        & $add 'support' ($got -band 0x10) ((Txt 'Support {0}: a town of {1}, {2} {3}+' 'Unterstütze {0}: Stadt mit {1}, {2} {3}+') -f $who, (Format-Num $g.Total), (Format-Num $g.OfWhich), (Get-StageName $lvl)) @(
            (& $meter ((Txt 'Residents {0} / {1}' 'Einwohner {0} / {1}') -f (Format-Num $tot), (Format-Num $g.Total)) $tot $g.Total),
            (& $meter ('{0}+ {1} / {2}' -f (Get-StageName $lvl), (Format-Num $ofw), (Format-Num $g.OfWhich)) $ofw $g.OfWhich)) $(if ($t) { $t.Name } else { '' })
    }
    foreach ($j in 0, 1) { $bit = 0x20000 -shl $j; if ($bits -band $bit) { & $add "special$j" ($got -band $bit) ((Txt 'Special goal {0}' 'Sonderziel {0}') -f ($j + 1)) @() '' } }
    $known = [long]0x7F7BF   # every goal bit FUN_1400ae010 knows; 0x800 (race) is a mode, not a goal
    $unknown = $bits -band (-bnot $known) -band (-bnot [long]0x800)
    if ($unknown) { & $add 'unknown' $false ((Txt 'Unknown goal 0x{0:X}' 'Unbekanntes Ziel 0x{0:X}') -f $unknown) @() '' }

    $sum = 0.0
    foreach ($g in $goals) {
        $v = if ($g.Done) { 1.0 } elseif ($g.Meters.Count) { ($g.Meters | ForEach-Object { $_.Value } | Measure-Object -Minimum).Minimum } else { 0.0 }
        $g.Progress = $v; $sum += $v
    }
    @{
        Slot = $slot; Mission = $m; Bits = $bits; Got = $got; Fulfilled = $fulfilled; Race = ($bits -band 0x800) -ne 0
        Goals = $goals; Met = @($goals | Where-Object { $_.Done }).Count; Count = $goals.Count
        Progress = $(if ($goals.Count) { $sum / $goals.Count } else { 0.0 })
        SubBits = $m.SubBits; SubFailing = $sub; Money = $money; OwnTotal = $ownTotal; OwnCount = $own.Count
    }
}

# Towns, residents, gold and ships of one player.
function Get-PlayerStats($snap, [int]$slot) {
    $p = $snap.Players[$slot]
    $st = New-Object long[] 5; $workers = 0L; $total = 0L; $best = $null; $n = 0
    foreach ($s in $snap.Settlements) {
        if ($s.Owner -ne $p.No) { continue }
        $n++; $workers += $s.Workers; $total += $s.Total
        for ($k = 0; $k -lt 5; $k++) { $st[$k] += $s.Stages[$k] }
        if (-not $best -or $s.Total -gt $best.Total) { $best = $s }
    }
    $top = -1; for ($k = 4; $k -ge 0; $k--) { if ($st[$k] -gt 0) { $top = $k; break } }
    @{
        Slot = $slot; Name = Get-PlayerName $snap $slot; Kind = $p.Kind; Gold = $p.Gold; TownCount = $n; Total = $total
        Stages = $st; Workers = $workers; Best = $best; TopStage = $top; Ships = $snap.ShipsByOwner[$p.No]
    }
}

# ---------------------------------------------------------------------------------------------
# Achievements (ids are stored in logbook.json and must stay stable).
# ---------------------------------------------------------------------------------------------
# Kinds: in-game conditions (two consecutive readings), set at the end of a game (mission_won, race_won),
# and long-term ones computed from logbook.json (missions and game summaries, also for earlier games).
$Achievements = @(
    # Rise of the population
    @{ Id = 'first_town'; De = 'Land in Sicht'; En = 'Land Ho!'; DescDe = 'Gründe deine erste Stadt.'; DescEn = 'Found your first town.' }
    @{ Id = 'settlers'; De = 'Erste Siedler'; En = 'First Settlers'; DescDe = 'Die ersten Siedler ziehen ein.'; DescEn = 'Your first settlers move in.' }
    @{ Id = 'citizens'; De = 'Bürgerstolz'; En = 'Civic Pride'; DescDe = 'Die ersten Bürger in deinem Reich.'; DescEn = 'The first citizens in your realm.' }
    @{ Id = 'merchants'; De = 'Pfeffersäcke'; En = 'Merchant Princes'; DescDe = 'Die ersten Kaufleute.'; DescEn = 'Your first merchants.' }
    @{ Id = 'aristocrats'; De = 'Blaues Blut'; En = 'Blue Blood'; DescDe = 'Die ersten Aristokraten.'; DescEn = 'Your first aristocrats.' }
    @{ Id = 'full_society'; De = 'Ständegesellschaft'; En = 'All Walks of Life'; DescDe = 'Je 100 Einwohner in allen fünf Bevölkerungsstufen.'; DescEn = '100 residents in each of the five population stages.' }
    @{ Id = 'res_1000'; De = 'Tausend Seelen'; En = 'A Thousand Souls'; DescDe = '1.000 Einwohner insgesamt.'; DescEn = '1,000 residents in total.' }
    @{ Id = 'res_5000'; De = 'Blühendes Inselreich'; En = 'Thriving Realm'; DescDe = '5.000 Einwohner insgesamt.'; DescEn = '5,000 residents in total.' }
    @{ Id = 'res_10000'; De = 'Zehntausend Untertanen'; En = 'Ten Thousand Subjects'; DescDe = '10.000 Einwohner insgesamt.'; DescEn = '10,000 residents in total.' }
    @{ Id = 'res_25000'; De = 'Volk der Inseln'; En = 'A Nation of Islanders'; DescDe = '25.000 Einwohner insgesamt.'; DescEn = '25,000 residents in total.' }
    @{ Id = 'city_2500'; De = 'Metropole'; En = 'Metropolis'; DescDe = 'Eine Stadt mit 2.500 Einwohnern.'; DescEn = 'One town with 2,500 residents.' }
    @{ Id = 'city_5000'; De = 'Weltstadt'; En = 'Cosmopolis'; DescDe = 'Eine Stadt mit 5.000 Einwohnern.'; DescEn = 'One town with 5,000 residents.' }
    @{ Id = 'aristo_1000'; De = 'Hofstaat'; En = 'Royal Court'; DescDe = '1.000 Aristokraten.'; DescEn = '1,000 aristocrats.' }
    @{ Id = 'noble_town'; De = 'Adelssitz'; En = 'Seat of Nobility'; DescDe = 'Eine Stadt mit 500 Aristokraten.'; DescEn = 'One town with 500 aristocrats.' }
    @{ Id = 'fast_1000'; De = 'Goldgräberstimmung'; En = 'Boomtown'; DescDe = '1.000 Einwohner in den ersten 2 Spielstunden.'; DescEn = '1,000 residents within the first 2 game hours.' }
    @{ Id = 'top_dog'; De = 'Platzhirsch'; En = 'Top Dog'; DescDe = 'Mehr Einwohner als alle Gegner zusammen (mindestens 2.000).'; DescEn = 'More residents than all rivals together (at least 2,000).' }
    # Towns, money, ships
    @{ Id = 'towns_3'; De = 'Inselhüpfer'; En = 'Island Hopper'; DescDe = '3 eigene Städte.'; DescEn = '3 towns of your own.' }
    @{ Id = 'towns_5'; De = 'Kolonialmacht'; En = 'Colonial Power'; DescDe = '5 eigene Städte.'; DescEn = '5 towns of your own.' }
    @{ Id = 'towns_10'; De = 'Herr der Inseln'; En = 'Lord of the Isles'; DescDe = '10 eigene Städte.'; DescEn = '10 towns of your own.' }
    @{ Id = 'gold_250k'; De = 'Volle Truhen'; En = 'Full Coffers'; DescDe = '250.000 Gold in der Kasse.'; DescEn = '250,000 gold in the treasury.' }
    @{ Id = 'gold_1m'; De = 'Millionär'; En = 'Millionaire'; DescDe = '1.000.000 Gold in der Kasse.'; DescEn = '1,000,000 gold in the treasury.' }
    @{ Id = 'comeback'; De = 'Aus den roten Zahlen'; En = 'Out of the Red'; DescDe = 'Die Kasse war im Minus – und hat wieder 25.000 Gold.'; DescEn = 'Your treasury was in the red – and is back at 25,000 gold.' }
    @{ Id = 'balance_500'; De = 'Schwarze Zahlen'; En = 'In the Black'; DescDe = 'Eine Bilanz von mindestens +500.'; DescEn = 'A balance of at least +500.' }
    @{ Id = 'balance_2000'; De = 'Goldene Bilanz'; En = 'Golden Ledger'; DescDe = 'Eine Bilanz von mindestens +2.000.'; DescEn = 'A balance of at least +2,000.' }
    @{ Id = 'trade_500'; De = 'Hanseat'; En = 'Master Trader'; DescDe = 'Eine Handelsbilanz von mindestens +500.'; DescEn = 'A trade balance of at least +500.' }
    @{ Id = 'ships_5'; De = 'Kleine Flotte'; En = 'Small Fleet'; DescDe = '5 eigene Schiffe.'; DescEn = '5 ships of your own.' }
    @{ Id = 'ships_10'; De = 'Armada'; En = 'Armada'; DescDe = '10 eigene Schiffe.'; DescEn = '10 ships of your own.' }
    @{ Id = 'ships_20'; De = 'Flottenadmiral'; En = 'Fleet Admiral'; DescDe = '20 eigene Schiffe.'; DescEn = '20 ships of your own.' }
    # Time and pace
    @{ Id = 'hours_10'; De = 'Sitzleder'; En = 'Staying Power'; DescDe = '10 Spielstunden in einer Partie.'; DescEn = '10 game hours in one game.' }
    @{ Id = 'hours_50'; De = 'Ewiger Regent'; En = 'Eternal Ruler'; DescDe = '50 Spielstunden in einer Partie.'; DescEn = '50 game hours in one game.' }
    @{ Id = 'hours_100'; De = 'Zeitlos'; En = 'Timeless'; DescDe = '100 Spielstunden in einer Partie.'; DescEn = '100 game hours in one game.' }
    @{ Id = 'turbo'; De = 'Volle Fahrt voraus'; En = 'Full Speed Ahead'; DescDe = 'Spiele im Turbo (8-fach oder schneller).'; DescEn = 'Play in turbo (8x or faster).' }
    @{ Id = 'night_owl'; De = 'Nachteule'; En = 'Night Owl'; DescDe = 'Spiele zwischen Mitternacht und vier Uhr früh.'; DescEn = 'Play between midnight and four in the morning.' }
    # Rivals
    @{ Id = 'rival_defeated'; De = 'Bezwinger'; En = 'Conqueror'; DescDe = 'Besiege einen Gegner.'; DescEn = 'Defeat a rival.' }
    @{ Id = 'rivals_3'; De = 'Dreifacher Triumph'; En = 'Triple Triumph'; DescDe = 'Besiege drei Gegner in einer Partie.'; DescEn = 'Defeat three rivals in one game.' }
    # Missions, campaigns, adventures
    @{ Id = 'mission_won'; De = 'Auftrag erfüllt'; En = 'Mission Accomplished'; DescDe = 'Gewinne ein Szenario.'; DescEn = 'Win a scenario.' }
    @{ Id = 'race_won'; De = 'Erster im Ziel'; En = 'First Past the Post'; DescDe = 'Gewinne einen Wettlauf gegen die Computergegner.'; DescEn = 'Win a race against the computer rivals.' }
    @{ Id = 'fast_win'; De = 'Blitzsieg'; En = 'Lightning Victory'; DescDe = 'Gewinne ein Szenario in weniger als 3 Spielstunden.'; DescEn = 'Win a scenario in less than 3 game hours.' }
    @{ Id = 'chapter_won'; De = 'Kapitel für Kapitel'; En = 'Chapter by Chapter'; DescDe = 'Gewinne ein Kampagnenkapitel.'; DescEn = 'Win a campaign chapter.' }
    @{ Id = 'campaign_done'; De = 'Saga vollendet'; En = 'Saga Complete'; DescDe = 'Gewinne alle Kapitel einer Kampagne.'; DescEn = 'Win every chapter of a campaign.' }
    @{ Id = 'campaigns_3'; De = 'Chronist der Inseln'; En = 'Chronicler of the Isles'; DescDe = 'Schliesse drei Kampagnen ab.'; DescEn = 'Complete three campaigns.' }
    @{ Id = 'challenge_won'; De = 'Herausforderung angenommen'; En = 'Challenge Accepted'; DescDe = 'Gewinne eine Herausforderung.'; DescEn = 'Win a challenge.' }
    @{ Id = 'adventure'; De = 'Abenteuerlust'; En = 'Call of Adventure'; DescDe = 'Spiele ein Zufallsabenteuer.'; DescEn = 'Play a random adventure.' }
    @{ Id = 'adventure_won'; De = 'Glücksritter'; En = 'Soldier of Fortune'; DescDe = 'Gewinne ein Zufallsabenteuer.'; DescEn = 'Win a random adventure.' }
    @{ Id = 'daily'; De = 'Tagwerk'; En = 'Daily Duty'; DescDe = 'Spiele ein Tagesabenteuer.'; DescEn = 'Play a daily adventure.' }
    @{ Id = 'daily_won'; De = 'Held des Tages'; En = 'Hero of the Day'; DescDe = 'Gewinne ein Tagesabenteuer.'; DescEn = 'Win a daily adventure.' }
    @{ Id = 'custom'; De = 'Eigene Welt'; En = 'A World of Your Own'; DescDe = 'Spiele ein selbst entworfenes Szenario.'; DescEn = 'Play a scenario you designed yourself.' }
    @{ Id = 'hattrick'; De = 'Hattrick'; En = 'Hat Trick'; DescDe = 'Gewinne drei Szenarien hintereinander.'; DescEn = 'Win three scenarios in a row.' }
    @{ Id = 'revenge'; De = 'Revanche'; En = 'Sweet Revenge'; DescDe = 'Gewinne ein Szenario, das du vorher verloren hast.'; DescEn = 'Win a scenario you lost before.' }
    @{ Id = 'games_10'; De = 'Stammgast'; En = 'Regular'; DescDe = 'Spiele zehn Partien (mit dem Logbuch).'; DescEn = 'Play ten games (with the logbook).' }
    # Events (anno-patcher.ps1 -Events)
    @{ Id = 'event_first'; De = 'Unverhofft kommt oft'; En = 'Expect the Unexpected'; DescDe = 'Erlebe dein erstes Ereignis.'; DescEn = 'Experience your first event.' }
    @{ Id = 'events_5'; De = 'Bewegte Zeiten'; En = 'Eventful Times'; DescDe = 'Fünf Ereignisse in einer Partie.'; DescEn = 'Five events in one game.' }
    @{ Id = 'event_survived'; De = 'Sturmerprobt'; En = 'Weathered the Storm'; DescDe = 'Überstehe ein schlechtes Ereignis bis zu seinem Ende.'; DescEn = 'Weather a bad event until it is over.' }
)
function Get-AchievementName($a) { if ($script:UiGerman) { $a.De } else { $a.En } }

# Achievements whose condition holds now (mission_won and race_won are set at the end of a game, the
# long-term ones by Get-LongTermConditions). $ctx (optional): the game session, its events, the time
# of the reading and the kind of game.
function Get-AchievementConditions($snap, $me, $money, $ctx = $null) {
    $c = @{}
    $p = $snap.Players[$me.Slot]
    if ($me.TownCount -ge 1) { $c.first_town = 1 }
    if ($me.Stages[1] + $me.Stages[2] + $me.Stages[3] + $me.Stages[4] -gt 0) { $c.settlers = 1 }
    if ($me.Stages[2] + $me.Stages[3] + $me.Stages[4] -gt 0) { $c.citizens = 1 }
    if ($me.Stages[3] + $me.Stages[4] -gt 0) { $c.merchants = 1 }
    if ($me.Stages[4] -gt 0) { $c.aristocrats = 1 }
    if ($me.Total -ge 1000) { $c.res_1000 = 1 }
    if ($me.Total -ge 5000) { $c.res_5000 = 1 }
    if ($me.Total -ge 10000) { $c.res_10000 = 1 }
    if ($me.Best -and $me.Best.Total -ge 2500) { $c.city_2500 = 1 }
    if ($me.Stages[4] -ge 1000) { $c.aristo_1000 = 1 }
    if ($me.TownCount -ge 3) { $c.towns_3 = 1 }
    if ($me.TownCount -ge 5) { $c.towns_5 = 1 }
    if ($me.TownCount -ge 10) { $c.towns_10 = 1 }
    if ($p.Gold -ge 250000) { $c.gold_250k = 1 }
    if ($p.Gold -ge 1000000) { $c.gold_1m = 1 }
    if ($me.Ships -ge 5) { $c.ships_5 = 1 }
    if ($me.Ships -ge 10) { $c.ships_10 = 1 }
    if ($me.TownCount -ge 1 -and $money.Balance -ge 500) { $c.balance_500 = 1 }
    if ($snap.Clock -ge 10 * $ClockPerHour) { $c.hours_10 = 1 }
    if ($snap.Clock -ge 50 * $ClockPerHour) { $c.hours_50 = 1 }
    if ($snap.Speed -ge 8 -and $snap.Speed -le 64) { $c.turbo = 1 }
    if ($p.Defeated -ge 1) { $c.rival_defeated = 1 }
    # Logbook 2.0
    if ($me.Stages[0] -ge 100 -and $me.Stages[1] -ge 100 -and $me.Stages[2] -ge 100 -and $me.Stages[3] -ge 100 -and $me.Stages[4] -ge 100) { $c.full_society = 1 }
    if ($me.Total -ge 25000) { $c.res_25000 = 1 }
    if ($me.Best -and $me.Best.Total -ge 5000) { $c.city_5000 = 1 }
    $rivalTotal = 0L; $rivalTowns = 0
    foreach ($s in $snap.Settlements) {
        if ($s.Owner -eq $p.No) { if ($s.Stages[4] -ge 500) { $c.noble_town = 1 }; continue }
        $k = Get-PlayerKind $snap $s.Owner
        if ($s.Owner -le 3 -and ($k -eq 0xC -or $k -eq 0)) { $rivalTotal += $s.Total; $rivalTowns++ }   # computer rivals (not natives)
    }
    if ($me.Total -ge 1000 -and $snap.Clock -le 2 * $ClockPerHour) { $c.fast_1000 = 1 }
    if ($rivalTowns -gt 0 -and $me.Total -ge 2000 -and $me.Total -gt $rivalTotal) { $c.top_dog = 1 }
    if ($me.TownCount -ge 1 -and $money.Balance -ge 2000) { $c.balance_2000 = 1 }
    if ($me.TownCount -ge 1 -and $money.Trade -ge 500) { $c.trade_500 = 1 }
    if ($me.Ships -ge 20) { $c.ships_20 = 1 }
    if ($snap.Clock -ge 100 * $ClockPerHour) { $c.hours_100 = 1 }
    if ($p.Defeated -ge 3) { $c.rivals_3 = 1 }
    if ($ctx) {
        if ($ctx.Session -and $ctx.Session.NegGold -and $p.Gold -ge 25000) { $c.comeback = 1 }
        if ($ctx.Now -and ([datetime]$ctx.Now).Hour -lt 4) { $c.night_owl = 1 }
        switch ([string]$ctx.Kind) { 'adventure' { $c.adventure = 1 }; 'daily' { $c.daily = 1 }; 'custom' { $c.custom = 1 } }
        $evs = @($ctx.Events)
        if ($evs.Count -ge 1) { $c.event_first = 1 }
        if ($evs.Count -ge 5) { $c.events_5 = 1 }
        foreach ($e in $evs) { if ($e.EndsClock -gt 0 -and -not $e.EndedEarly -and $snap.Clock -ge $e.EndsClock -and (Get-EffectSign $e.Effect) -lt 0) { $c.event_survived = 1; break } }
    }
    $c
}

# ---------------------------------------------------------------------------------------------
# Kind of game from the scenario name (file names: see the shared conventions of the extensions).
# Only own scenarios (flag "CUSTOM" of the parameter block) are matched by name; without a mission it
# is an endless game (the name in memory may still be the one of an earlier scenario).
# ---------------------------------------------------------------------------------------------
function Get-GameKind([string]$name, [bool]$hasMission, [bool]$ownScenario = $true) {
    if ($ownScenario -and $name) {
        if ($name -match '^(Tagesabenteuer|Daily Adventure) ') { return @{ Kind = 'daily' } }
        if ($name -match '^(Abenteuer|Adventure) \d+') { return @{ Kind = 'adventure' } }
        if ($name -match '^(Eigenes|Custom) - ') { return @{ Kind = 'custom' } }
        if ($name -match '^(Herausforderung|Challenge) - ') { return @{ Kind = 'challenge' } }
        if ($hasMission -and $name -match '^(.+?) (\d+) - .') { return @{ Kind = 'campaign'; Campaign = $Matches[1]; Chapter = [int]$Matches[2] } }
    }
    if ($hasMission) { return @{ Kind = 'scenario' } }
    @{ Kind = 'endless' }
}

function Get-GameKindName([string]$kind) {
    switch ($kind) {
        'endless' { Txt 'Endless game' 'Endlosspiel' }; 'campaign' { Txt 'Campaign' 'Kampagne' }; 'challenge' { Txt 'Challenge' 'Herausforderung' }
        'adventure' { Txt 'Random adventure' 'Zufallsabenteuer' }; 'daily' { Txt 'Daily adventure' 'Tagesabenteuer' }
        'custom' { Txt 'Own scenario' 'Eigenes Szenario' }; default { Txt 'Scenario' 'Szenario' }
    }
}

# Chapters of a campaign: the highest chapter number among the scenario files in "Own Scenarios",
# at least the number of chapters known for the campaigns of the extensions.
$KnownCampaigns = @{ 'Smaragdinseln' = 6; 'Emerald Isles' = 6; 'Wettlauf' = 4; 'Race' = 4; 'Sturmsee' = 6; 'Storm Sea' = 6; 'Neue Welt' = 6; 'New World' = 6; 'Handelsliga' = 6; 'Trade League' = 6; 'Weltreich' = 6; 'World Empire' = 6 }
function Get-OwnScenariosFolder { Join-Path $script:DocumentsFolder 'Anno 1602 History Edition\Own Scenarios' }
function Get-CampaignChapterCount([string]$campaign) {
    $n = 0
    try {
        $dir = Get-OwnScenariosFolder
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            $re = '^' + [regex]::Escape($campaign) + ' (\d+) - '
            foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.szs' -File)) { if ($f.BaseName -match $re) { $n = [Math]::Max($n, [int]$Matches[1]) } }
        }
    }
    catch { }
    if ($KnownCampaigns.ContainsKey($campaign)) { $n = [Math]::Max($n, [int]$KnownCampaigns[$campaign]) }
    $n
}

# Campaigns with every chapter won (names, from the missions in logbook.json).
function Get-FinishedCampaigns($missions) {
    $won = @{}
    foreach ($m in @($missions)) {
        if (-not $m -or $m.result -ne 'won') { continue }
        $k = Get-GameKind ([string]$m.scenario) $true
        if ($k.Kind -ne 'campaign') { continue }
        if (-not $won.ContainsKey($k.Campaign)) { $won[$k.Campaign] = @{} }
        $won[$k.Campaign][$k.Chapter] = 1
    }
    foreach ($c in @($won.Keys | Sort-Object)) {
        $n = Get-CampaignChapterCount $c
        if ($n -le 0) { continue }
        $all = $true
        for ($i = 1; $i -le $n; $i++) { if (-not $won[$c].ContainsKey($i)) { $all = $false; break } }
        if ($all) { $c }
    }
}

# Long-term achievements from logbook.json ($data: missions and games as read by Read-LogbookData).
function Get-LongTermConditions($data) {
    $c = @{}
    $missions = @($data.missions | Where-Object { $_ })
    $run = 0; $lost = @{}
    foreach ($m in $missions) {
        $scen = [string]$m.scenario
        if ($m.result -eq 'won') {
            switch ((Get-GameKind $scen $true).Kind) {
                'campaign' { $c.chapter_won = 1 }; 'challenge' { $c.challenge_won = 1 }; 'adventure' { $c.adventure_won = 1 }; 'daily' { $c.daily_won = 1 }
            }
            $h = 0.0; try { $h = [double]$m.gameHours } catch { }
            if ($h -gt 0 -and $h -lt 3) { $c.fast_win = 1 }
            $run++; if ($run -ge 3) { $c.hattrick = 1 }
            if ($scen -and $lost.ContainsKey($scen)) { $c.revenge = 1 }
        }
        else {
            $run = 0
            if ($m.result -eq 'lost' -and $scen) { $lost[$scen] = 1 }
        }
    }
    $done = @(Get-FinishedCampaigns $missions)
    if ($done.Count -ge 1) { $c.campaign_done = 1 }
    if ($done.Count -ge 3) { $c.campaigns_3 = 1 }
    if (@($data.games | Where-Object { $_ }).Count -ge 10) { $c.games_10 = 1 }
    $c
}

# ---------------------------------------------------------------------------------------------
# logbook.json: achievements (once ever), finished missions, window settings.
# ---------------------------------------------------------------------------------------------
function Get-LogbookFile { Join-Path $script:AppDataFolder 'Anno1602-Extensions\logbook.json' }

function ConvertTo-OrderedTable($o) {
    $h = [ordered]@{}
    if ($o -is [Collections.IDictionary]) { foreach ($k in $o.Keys) { $h[[string]$k] = $o[$k] } }
    elseif ($o) { foreach ($pp in $o.PSObject.Properties) { $h[$pp.Name] = $pp.Value } }
    $h
}

function Read-LogbookData {
    $d = @{ achievements = (New-Object Collections.ArrayList); missions = (New-Object Collections.ArrayList); games = (New-Object Collections.ArrayList); settings = @{}; extra = [ordered]@{} }
    $file = Get-LogbookFile
    if (-not (Test-Path -LiteralPath $file)) { return $d }
    try {
        $j = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($a in @($j.achievements)) { if ($a -and $a.id) { [void]$d.achievements.Add([ordered]@{ id = [string]$a.id; date = [string]$a.date; game = [string]$a.game }) } }
        foreach ($x in @($j.missions)) { if ($x) { $h = [ordered]@{}; foreach ($pp in $x.PSObject.Properties) { $h[$pp.Name] = $pp.Value }; [void]$d.missions.Add($h) } }
        foreach ($x in @($j.games)) { if ($x) { [void]$d.games.Add((ConvertTo-OrderedTable $x)) } }
        if ($j.settings) { foreach ($pp in $j.settings.PSObject.Properties) { $d.settings[$pp.Name] = $pp.Value } }
        # Keys of other tools or later versions are kept as they are.
        foreach ($pp in $j.PSObject.Properties) { if (@('version', 'achievements', 'missions', 'games', 'settings') -notcontains $pp.Name) { $d.extra[$pp.Name] = $pp.Value } }
    }
    catch {
        # A broken file is kept aside (never deleted) and the logbook starts a new one.
        try { Move-Item -LiteralPath $file -Destination ($file -replace '\.json$', ('.broken-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')) -Force } catch { }
    }
    $d
}

# Writes a text file (UTF-8 without BOM) through a temp file, so that a reader never sees half a file.
function Write-TextFileAtomic([string]$file, [string]$text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    $tmp = "$file.tmp"
    [IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $file) {
        try { [IO.File]::Replace($tmp, $file, $null) } catch { Copy-Item -LiteralPath $tmp -Destination $file -Force; Remove-Item -LiteralPath $tmp -Force }
    }
    else { Move-Item -LiteralPath $tmp -Destination $file }
}

function Save-LogbookData($d) {
    $file = Get-LogbookFile
    $settings = [ordered]@{}; foreach ($k in ($d.settings.Keys | Sort-Object)) { $settings[$k] = $d.settings[$k] }
    $obj = [ordered]@{ version = 1; achievements = @($d.achievements); missions = @($d.missions); games = @($d.games | Where-Object { $_ }); settings = $settings }
    if ($d.extra) { foreach ($k in $d.extra.Keys) { $obj[$k] = $d.extra[$k] } }
    Write-TextFileAtomic $file (ConvertTo-Json $obj -Depth 8)
}

# Re-reads the file before every change, so that changes by others (launcher) are kept.
function Add-LogbookEntries([object[]]$achievements, [object[]]$missions, [object[]]$games = @()) {
    $d = Read-LogbookData
    $have = @{}; foreach ($a in $d.achievements) { $have[$a.id] = 1 }
    foreach ($a in $achievements) { if ($a -and -not $have.ContainsKey($a.id)) { [void]$d.achievements.Add($a); $have[$a.id] = 1 } }
    foreach ($x in $missions) { if ($x) { [void]$d.missions.Add($x) } }
    foreach ($x in $games) { if ($x) { [void]$d.games.Add($x) } }
    while ($d.games.Count -gt $GamesKeep) { $d.games.RemoveAt(0) }
    Save-LogbookData $d
    $d
}

function Save-LogbookSettings($settings) {
    $d = Read-LogbookData
    foreach ($k in $settings.Keys) { $d.settings[$k] = $settings[$k] }
    Save-LogbookData $d
}

# ---------------------------------------------------------------------------------------------
# Session state: connection, game phase, finished missions, achievement unlocks.
# ---------------------------------------------------------------------------------------------
function New-LogbookState {
    $d = Read-LogbookData
    $u = @{}; foreach ($a in $d.achievements) { $u[$a.id] = $a }
    $collapsed = @{}; foreach ($c in @($d.settings['collapsed'])) { if ($c) { $collapsed[[string]$c] = 1 } }
    @{
        Conn = @{ Status = 'waiting'; Handle = [IntPtr]::Zero; Pid = 0; Source = $null; HashByPid = @{}; StartFails = @{}; Detail = '' }
        Unlocked = $u; Pending = @{}; Fresh = @{}
        Track = @{ SawRunning = $false; Scenario = ''; Title = ''; HasMission = $false; Race = $false }
        LastClock = [long]-1; SameClockTicks = 0
        Settings = $d.settings
        # Logbook 2.0: game session with its history, game summaries, events, view state.
        Session = $null; PendingEnd = $null; LastSummary = $null; ShowSummary = $false; SummaryFrom = ''
        Games = $d.games
        Events = @{ Pid = 0; List = @(); Seen = @{}; Stamp = ''; First = $true; New = @() }
        Tab = $(if ($d.settings['tab'] -eq 'history') { 'history' } else { 'game' }); Collapsed = $collapsed
        SelectedGame = $null; ShowAllGames = $false; HistoryCache = @{}; LastHistory = $null; LastHistoryLoaded = $false
        NoSave = $false; Errors = (New-Object Collections.ArrayList)
    }
}

function Close-Attachment($lb) {
    if ($lb.Conn.Handle -ne [IntPtr]::Zero) { [void][AnnoLogbook.Native]::CloseHandle($lb.Conn.Handle) }
    $lb.Conn.Handle = [IntPtr]::Zero; $lb.Conn.Source = $null; $lb.Conn.Pid = 0
    $lb.Track.SawRunning = $false; $lb.LastClock = -1; $lb.SameClockTicks = 0
}

# The game process has ended (or was closed): the running game ends as "left" (summary when it was long
# enough), then the attachment is closed. Returns the result of Complete-Session or $null.
function Close-GameProcess($lb, [datetime]$now) {
    $r = $null
    if ($lb.Session -and -not $lb.Session.Done) {
        try { $r = Complete-Session $lb 'quit' $now } catch { [void]$lb.Errors.Add("end: $($_.Exception.Message)") }
    }
    Close-Attachment $lb
    $r
}

# Finds the game and opens it read-only; detects the end of the process (also the quick restart
# of Ubisoft Connect, where the first process exits right away).
function Update-Attachment($lb) {
    $c = $lb.Conn
    if ($c.Handle -ne [IntPtr]::Zero) {
        if ([AnnoLogbook.Native]::IsRunning($c.Handle)) { return }
        $lb.PendingEnd = Close-GameProcess $lb (Get-Date)
    }
    $p = $null
    if ($TestProcessId) { $p = Get-Process -Id $TestProcessId -ErrorAction SilentlyContinue }
    else {
        $all = @(Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue)
        if ($all.Count -gt 1) { $all = @($all | Sort-Object { try { $_.StartTime } catch { [datetime]::MinValue } } -Descending) }
        if ($all.Count) { $p = $all[0] }
    }
    if (-not $p) { $c.Status = 'waiting'; $c.Detail = ''; return }
    try {
        $base = if ($TestProcessId) { $TestBase } else { $p.MainModule.BaseAddress.ToInt64() }
        if (-not $TestProcessId) {
            if (-not $c.HashByPid.ContainsKey($p.Id)) { $c.HashByPid[$p.Id] = (Get-FileHash -LiteralPath $p.MainModule.FileName -Algorithm SHA256).Hash.ToLower() }
            if ($c.HashByPid[$p.Id] -ne $ExpectedHash) { $c.Status = 'version'; $c.Detail = $c.HashByPid[$p.Id]; return }
        }
    }
    catch {
        # Process still starting (module list not ready). If that lasts (about 25 s), it is a permission problem.
        $c.StartFails[$p.Id] = 1 + [int]$c.StartFails[$p.Id]
        if ($c.StartFails[$p.Id] -gt 10) { $c.Status = 'denied'; $c.Detail = $_.Exception.Message } else { $c.Status = 'starting'; $c.Detail = '' }
        return
    }
    $h = [AnnoLogbook.Native]::OpenProcess(0x0400 -bor 0x0010, $false, $p.Id)   # PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
    if ($h -eq [IntPtr]::Zero) { $c.Status = 'denied'; $c.Detail = [Runtime.InteropServices.Marshal]::GetLastWin32Error(); return }
    $c.Handle = $h; $c.Pid = $p.Id; $c.Source = New-Object AnnoLogbook.ProcessSource($h, $base); $c.Status = 'attached'; $c.Detail = ''
}

function Get-GameName($snap, $mission) {
    $n = $snap.ScenarioName
    if ($n -and $n -notmatch '^\[\[') { return $n }
    if ($mission) { $t = Get-MissionTitle $mission.Mission; if ($t) { return $t }; return (Txt 'Scenario' 'Szenario') }
    Txt 'Endless game' 'Endlosspiel'
}
function Get-MissionTitle($m) {
    if (-not $m -or -not $m.Text) { return '' }
    $line = @($m.Text -split "`n" | Where-Object { $_.Trim() })[0]
    if ($line) { $line.Trim() } else { '' }
}

function Convert-IsoDate($v) {
    if ($v -is [datetime]) { return $v }
    try { [datetime]::ParseExact([string]$v, 's', [Globalization.CultureInfo]::InvariantCulture) } catch { [datetime]::MinValue }
}

# ---------------------------------------------------------------------------------------------
# Game session and its history. A session is one game as the logbook sees it: it starts with the first
# reading of a running game and continues while the same game process shows the same scenario and the
# game clock moves on. Loading an earlier savegame of the same game (clock back, not before the start of
# the session) rewinds the history; another scenario, a clock before the start or a jump of more than
# one game hour start a new session (the old one ends as "left"). One history point about every game
# minute (by the game clock: a paused game adds nothing), at most 720 points per game.
# History file: %APPDATA%\Anno1602-Extensions\history\<start yyyyMMdd-HHmmss>.json, the newest 30 are kept.
# ---------------------------------------------------------------------------------------------
function Get-HistoryFolder { Join-Path $script:AppDataFolder 'Anno1602-Extensions\history' }

# One history point: clock, gold, residents, the five stages, workers, balance, towns, ships ($HistoryFields).
function New-SampleValues($snap, $st) {
    $me = $st.Me
    [long[]]@($snap.Clock, $snap.Players[$st.HumanSlot].Gold, $me.Total, $me.Stages[0], $me.Stages[1], $me.Stages[2], $me.Stages[3], $me.Stages[4], $me.Workers, $st.Money.Balance, $me.TownCount, $me.Ships)
}

function New-Session($lb, $snap, $st, [datetime]$now) {
    $hasMission = $null -ne $st.Mission -and $snap.Players[$st.HumanSlot].MissionSlot -le 3
    @{
        Id = $now.ToString('yyyyMMdd-HHmmss'); File = ''; Start = $now; Pid = [int]$lb.Conn.Pid
        Scenario = [string]$snap.ScenarioName; Game = [string]$st.GameName; Kind = (Get-GameKind $snap.ScenarioName $hasMission $snap.ScenarioCustom).Kind; HasMission = $hasMission
        FirstClock = [long]$snap.Clock; LastClock = [long]$snap.Clock; Interval = $SampleClocks
        Samples = (New-Object 'System.Collections.Generic.List[long[]]'); Unsaved = 0; Prev = $null; Readings = 0
        PeakResidents = 0L; PeakGold = [long]::MinValue; PeakTowns = 0L; TopStage = -1; NegGold = $false; Reloads = 0; EventCount = 0; FirstTown = ''
        Achievements = (New-Object Collections.ArrayList); Done = $false; Result = ''; End = $null
    }
}

# Adds a point if a game minute (the current interval) has passed since the last one. Above the cap every
# second point is dropped (the first and the newest stay) and the interval doubles.
function Add-SessionSample($s, [long[]]$vals) {
    $n = $s.Samples.Count
    if ($n -gt 0 -and $vals[0] - $s.Samples[$n - 1][0] -lt $s.Interval) { return $false }
    $s.Samples.Add($vals); $s.Unsaved++
    if ($s.Samples.Count -gt $HistoryMaxSamples) {
        $keep = New-Object 'System.Collections.Generic.List[long[]]'
        $count = $s.Samples.Count
        for ($i = 0; $i -lt $count - 1; $i += 2) { $keep.Add($s.Samples[$i]) }
        $keep.Add($s.Samples[$count - 1])
        $s.Samples = $keep; $s.Interval = 2 * $s.Interval
    }
    $true
}

function Save-HistoryFile($lb, $s) {
    if ($lb.NoSave -or -not $s -or -not $s.File) { return }
    $state = [ordered]@{
        firstClock = $s.FirstClock; lastClock = $s.LastClock; interval = $s.Interval; readings = $s.Readings
        peakResidents = $s.PeakResidents; peakGold = $(if ($s.PeakGold -eq [long]::MinValue) { $null } else { $s.PeakGold }); peakTowns = $s.PeakTowns; topStage = $s.TopStage
        negGold = [bool]$s.NegGold; reloads = $s.Reloads; events = $s.EventCount; hasMission = [bool]$s.HasMission; firstTown = [string]$s.FirstTown; achievements = @($s.Achievements)
    }
    $head = [ordered]@{ version = 1; start = $s.Start.ToString('s'); pid = $s.Pid; scenario = $s.Scenario; game = $s.Game; kind = $s.Kind; state = $state; fields = $HistoryFields; samples = '@@SAMPLES@@'; end = $s.End }
    $json = ConvertTo-Json $head -Depth 6
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('[')
    for ($i = 0; $i -lt $s.Samples.Count; $i++) { if ($i) { [void]$sb.Append(',') }; [void]$sb.Append("`n    ").Append([AnnoLogbook.Util]::JoinRow($s.Samples[$i])) }
    [void]$sb.Append("`n  ]")
    Write-TextFileAtomic $s.File ($json.Replace('"@@SAMPLES@@"', $sb.ToString()))
    $s.Unsaved = 0
}

# Reads a history file back into a session (or $null if it is missing or broken).
function Read-HistoryFile([string]$path) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        $j = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $samples = New-Object 'System.Collections.Generic.List[long[]]'
        foreach ($row in @($j.samples)) { if ($row) { $samples.Add([long[]]@($row)) } }
        $t = $j.state
        $s = @{
            Id = [IO.Path]::GetFileNameWithoutExtension($path); File = $path; Start = (Convert-IsoDate $j.start); Pid = [int]$j.pid
            Scenario = [string]$j.scenario; Game = [string]$j.game; Kind = [string]$j.kind; HasMission = [bool]$t.hasMission
            FirstClock = [long]$t.firstClock; LastClock = [long]$t.lastClock; Interval = [long]$t.interval
            Samples = $samples; Unsaved = 0; Prev = $null; Readings = [int]$t.readings
            PeakResidents = [long]$t.peakResidents; PeakGold = $(if ($null -eq $t.peakGold) { [long]::MinValue } else { [long]$t.peakGold }); PeakTowns = [long]$t.peakTowns
            TopStage = $(if ($null -eq $t.topStage) { -1 } else { [int]$t.topStage }); NegGold = [bool]$t.negGold; Reloads = [int]$t.reloads; EventCount = [int]$t.events; FirstTown = [string]$t.firstTown
            Achievements = (New-Object Collections.ArrayList); Done = $false; Result = ''; End = $null
        }
        foreach ($a in @($t.achievements)) { if ($a) { [void]$s.Achievements.Add([string]$a) } }
        if ($j.end) { $s.End = ConvertTo-OrderedTable $j.end; $s.Done = $true; $s.Result = [string]$j.end.result }
        if ($s.Interval -le 0) { $s.Interval = $SampleClocks }
        $s
    }
    catch { $null }
}

# Keeps the newest $keep history files.
function Limit-HistoryFiles([string]$dir, [int]$keep) {
    $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    foreach ($f in @($files | Select-Object -Skip ([Math]::Max(0, $keep)))) { try { Remove-Item -LiteralPath $f.FullName -Force } catch { } }
}

# The logbook was restarted while the game kept running: the newest history file of this game process
# and scenario (not finished, clock not before its end, at most 2 game hours later) is continued.
function Find-ResumableHistory($lb, $s) {
    if ($lb.NoSave) { return $null }
    $dir = Get-HistoryFolder
    if (-not (Test-Path -LiteralPath $dir)) { return $null }
    $f = Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $f) { return $null }
    $h = Read-HistoryFile $f.FullName
    if (-not $h -or $h.Done -or $h.Pid -ne $s.Pid -or $h.Scenario -ne $s.Scenario) { return $null }
    if ($s.FirstClock -lt $h.LastClock -or $s.FirstClock -gt $h.LastClock + 2 * $ClockPerHour) { return $null }
    $h.Game = $s.Game; $h.HasMission = $s.HasMission; $h.Kind = $s.Kind
    $h
}

function Start-Session($lb, $snap, $st, [datetime]$now) {
    $s = New-Session $lb $snap $st $now
    $resumed = Find-ResumableHistory $lb $s
    if ($resumed) { $s = $resumed }
    elseif (-not $lb.NoSave) {
        $dir = Get-HistoryFolder
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $name = $s.Id; $n = 1
        while (Test-Path -LiteralPath (Join-Path $dir "$name.json")) { $n++; $name = '{0}-{1}' -f $s.Id, $n }
        $s.Id = $name; $s.File = Join-Path $dir "$name.json"
        Limit-HistoryFiles $dir ($HistoryKeepFiles - 1)
    }
    $lb.Session = $s
    $s
}

# A savegame of the same game was loaded: the points after its clock are dropped.
function Undo-SessionSamples($s, [long]$clock) {
    while ($s.Samples.Count -gt 0 -and $s.Samples[$s.Samples.Count - 1][0] -gt $clock) { $s.Samples.RemoveAt($s.Samples.Count - 1) }
    $s.LastClock = $clock; $s.Prev = $null; $s.Reloads++; $s.Unsaved++
}

# "<island>:<name>" of the human's first own settlement (table order), '' without a town.
function Get-FirstTownKey($snap, $st) {
    $no = $snap.Players[$st.HumanSlot].No
    foreach ($t in $snap.Settlements) { if ($t.Owner -eq $no) { return '{0}:{1}' -f $t.Island, $t.Name } }
    ''
}

# After a jump of the game clock: is this still the same game (a savegame of it was loaded)?
# Not when the clock is back near zero (a new game), when the first own town is another one, or when
# the human had towns at that time and has none now.
function Test-SameGame($s, $snap, $st) {
    if ($snap.Clock -lt 2 * $SampleClocks -and ($s.LastClock - $snap.Clock) -gt 10 * $SampleClocks) { return $false }
    $key = Get-FirstTownKey $snap $st
    if ($s.FirstTown -and $key -and $key -ne $s.FirstTown) { return $false }
    $before = $null
    foreach ($row in $s.Samples) { if ($row[0] -le $snap.Clock) { $before = $row } else { break } }
    if ($before -and $before[10] -gt 0 -and $st.Me.TownCount -eq 0) { return $false }
    $true
}

# Called for every reading of a running game: continues, rewinds or replaces the session.
# Returns the result of Complete-Session when an earlier game ended because of this, otherwise $null.
function Sync-Session($lb, $snap, $st, [datetime]$now) {
    $s = $lb.Session
    $ended = $null
    if ($s -and -not $s.Done) {
        if ($s.Pid -eq [int]$lb.Conn.Pid -and $s.Scenario -eq [string]$snap.ScenarioName) {
            $forward = $snap.Clock -ge $s.LastClock
            if ($forward -and $snap.Clock -le $s.LastClock + 2 * $SampleClocks) { return $null }   # normal progress
            if ($forward -and $snap.Clock -le $s.LastClock + $ClockPerHour -and (Test-SameGame $s $snap $st)) { return $null }
            if (-not $forward -and $snap.Clock -ge $s.FirstClock -and (Test-SameGame $s $snap $st)) { Undo-SessionSamples $s $snap.Clock; return $null }
        }
        $ended = Complete-Session $lb 'quit' $now
    }
    [void](Start-Session $lb $snap $st $now)
    $ended
}

# Peaks use the smaller value of two consecutive readings (a single half-loaded reading cannot set a peak).
function Update-SessionReading($lb, $snap, $st) {
    $s = $lb.Session
    if (-not $s -or $s.Done) { return }
    $vals = New-SampleValues $snap $st
    $s.Readings++
    $p = $s.Prev
    if ($p) {
        $v = [Math]::Min($p[2], $vals[2]); if ($v -gt $s.PeakResidents) { $s.PeakResidents = $v }
        $v = [Math]::Min($p[1], $vals[1]); if ($v -gt $s.PeakGold) { $s.PeakGold = $v }
        $v = [Math]::Min($p[10], $vals[10]); if ($v -gt $s.PeakTowns) { $s.PeakTowns = $v }
        for ($k = 4; $k -gt $s.TopStage; $k--) { if ([Math]::Min($p[3 + $k], $vals[3 + $k]) -gt 0) { $s.TopStage = $k; break } }
        if ($p[1] -lt 0 -and $vals[1] -lt 0) { $s.NegGold = $true }
    }
    $s.Prev = $vals
    $s.LastClock = [long]$snap.Clock
    if (-not $s.FirstTown) { $s.FirstTown = Get-FirstTownKey $snap $st }
    [void](Add-SessionSample $s $vals)
    if ($s.Unsaved -ge 5) { Save-HistoryFile $lb $s }
}

# Summary of a session (stored in logbook.json "games" and in the history file as "end").
function New-SessionSummary($s, [string]$result, [datetime]$now, [long]$endClock) {
    $last = if ($s.Samples.Count) { $s.Samples[$s.Samples.Count - 1] } else { $null }
    $few = $s.Readings -lt 2 -and $last
    $top = $s.TopStage
    if ($few) { for ($k = 4; $k -ge 0; $k--) { if ($last[3 + $k] -gt 0) { $top = [Math]::Max($top, $k); break } } }
    [ordered]@{
        date = $now.ToString('s'); start = $s.Start.ToString('s')
        scenario = $s.Scenario; game = $s.Game; kind = $s.Kind; mission = [bool]$s.HasMission; result = $result
        gameHours = [Math]::Round($endClock / $ClockPerHour, 1); playedHours = [Math]::Round([Math]::Max(0, [Math]::Max($s.LastClock, $endClock) - $s.FirstClock) / $ClockPerHour, 1)
        startClock = $s.FirstClock; endClock = $endClock
        peakResidents = [long]$(if ($few) { [Math]::Max($s.PeakResidents, $last[2]) } else { $s.PeakResidents })
        peakGold = [long]$(if ($s.PeakGold -ne [long]::MinValue) { $s.PeakGold } elseif ($last) { $last[1] } else { 0 })
        towns = [long]$(if ($last) { $last[10] } else { 0 }); peakTowns = [long]$(if ($few) { [Math]::Max($s.PeakTowns, $last[10]) } else { $s.PeakTowns })
        topStage = $top; events = $s.EventCount; reloads = $s.Reloads
        achievements = @($s.Achievements)
        history = $(if ($s.File) { Split-Path -Leaf $s.File } else { '' })
    }
}

# Ends the session: summary, long-term achievements, one write of logbook.json (end unlocks, the finished
# mission and the summary), history file with "end". A game left without a result after less than 5 game
# minutes is not recorded (its history file is removed). Returns @{ Summary; NewUnlocks; SaveError }.
function Complete-Session($lb, [string]$result, [datetime]$now, $snap = $null, $endUnlocks = @(), $missionEntry = $null) {
    $out = @{ Summary = $null; NewUnlocks = @(); SaveError = $null }
    $endUnlocks = @($endUnlocks | Where-Object { $_ })
    $s = $lb.Session
    if (-not $s -or $s.Done) {
        if (($missionEntry -or $endUnlocks.Count) -and -not $lb.NoSave) {
            try { [void](Add-LogbookEntries $endUnlocks @($missionEntry)) } catch { $out.SaveError = $_.Exception.Message }
        }
        foreach ($a in $endUnlocks) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
        $out.NewUnlocks = $endUnlocks
        return $out
    }
    $s.Done = $true; $s.Result = $result
    $endClock = if ($snap) { [long]$snap.Clock } else { [long]$s.LastClock }
    if ($s.Prev -and ($s.Samples.Count -eq 0 -or $s.Prev[0] -gt $s.Samples[$s.Samples.Count - 1][0])) { $s.Samples.Add($s.Prev) }
    $worthy = $result -ne 'quit' -or ($s.LastClock - $s.FirstClock) -ge $QuitMinClocks
    if (-not $worthy) {
        if ($s.File -and -not $lb.NoSave) { try { if (Test-Path -LiteralPath $s.File) { Remove-Item -LiteralPath $s.File -Force } } catch { } }
        $s.File = ''
        return $out
    }
    foreach ($a in $endUnlocks) { if (-not $s.Achievements.Contains($a.id)) { [void]$s.Achievements.Add($a.id) } }
    $summary = New-SessionSummary $s $result $now $endClock
    $all = New-Object Collections.ArrayList
    foreach ($a in $endUnlocks) { [void]$all.Add($a) }
    if (-not $lb.NoSave) {
        try {
            $d = Read-LogbookData
            if ($missionEntry) { [void]$d.missions.Add($missionEntry) }
            $cond = Get-LongTermConditions @{ missions = $d.missions; games = @(@($d.games) + @($summary)) }
            foreach ($id in @($cond.Keys | Sort-Object)) {
                if ($lb.Unlocked.ContainsKey($id) -or @($all | Where-Object { $_.id -eq $id }).Count) { continue }
                [void]$all.Add([ordered]@{ id = $id; date = $now.ToString('s'); game = $s.Game })
            }
            foreach ($a in $all) { if (-not $s.Achievements.Contains($a.id)) { [void]$s.Achievements.Add($a.id) } }
            $summary.achievements = @($s.Achievements)
            $have = @{}; foreach ($a in $d.achievements) { $have[$a.id] = 1 }
            foreach ($a in $all) { if (-not $have.ContainsKey($a.id)) { [void]$d.achievements.Add($a); $have[$a.id] = 1 } }
            [void]$d.games.Add($summary)
            while ($d.games.Count -gt $GamesKeep) { $d.games.RemoveAt(0) }
            Save-LogbookData $d
            $lb.Games = $d.games
        }
        catch { $out.SaveError = $_.Exception.Message }
        $s.End = $summary
        try { Save-HistoryFile $lb $s } catch { [void]$lb.Errors.Add("history: $($_.Exception.Message)") }
    }
    else { $s.End = $summary }
    foreach ($a in $all) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
    $lb.LastSummary = $summary; $lb.ShowSummary = $true; $lb.SummaryFrom = $s.Id
    $out.Summary = $summary; $out.NewUnlocks = @($all)
    $out
}

# Start of the window: history files of games whose process is gone (the logbook was closed before the
# game) are finished as "left" now.
function Close-UnfinishedHistory($lb) {
    $results = New-Object Collections.ArrayList
    if ($lb.NoSave) { return , @($results) }
    $dir = Get-HistoryFolder
    if (-not (Test-Path -LiteralPath $dir)) { return , @($results) }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | Sort-Object Name)) {
        # Quick look first: "end" is written last and is null only while the game is open.
        try { if ([IO.File]::ReadAllText($f.FullName) -notmatch '"end":\s*null\s*\}\s*$') { continue } } catch { continue }
        $h = Read-HistoryFile $f.FullName
        if (-not $h -or $h.Done) { continue }
        $p = if ($h.Pid) { Get-Process -Id $h.Pid -ErrorAction SilentlyContinue } else { $null }
        if ($p -and ($p.ProcessName -eq 'Anno1602' -or $h.Pid -eq $TestProcessId)) { continue }   # still running: continued later
        $keep = $lb.Session
        $lb.Session = $h
        try { $r = Complete-Session $lb 'quit' $f.LastWriteTime; if ($r.Summary) { [void]$results.Add($r) } }
        finally { $lb.Session = $keep }
    }
    , @($results)
}

# Long-term achievements from logbook.json that are not unlocked yet (also for games played before
# this version). Returns the new unlock entries.
function Update-LongTermAchievements($lb, [datetime]$now) {
    if ($lb.NoSave) { return @() }
    $d = Read-LogbookData
    $cond = Get-LongTermConditions $d
    $new = @(foreach ($id in @($cond.Keys | Sort-Object)) { if (-not $lb.Unlocked.ContainsKey($id)) { [ordered]@{ id = $id; date = $now.ToString('s'); game = '' } } })
    if ($new.Count) {
        [void](Add-LogbookEntries $new @())
        foreach ($a in $new) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
    }
    $new
}

# ---------------------------------------------------------------------------------------------
# Events (written by anno-patcher.ps1 -Events into %APPDATA%\Anno1602-Extensions\events.json):
# { "version": 1, "events": [ { "time", "pid", "clock", "id", "title": {de, en}, "text": {de, en},
#   "effect": {de, en}, "endsClock", optional "endedEarly": true } ] } - newest last. The logbook shows those of
# the game process it reads (same pid) and a banner for each new one. endedEarly: a temporary event that the
# patcher ended before endsClock (game over, another game loaded or started, its window closed).
# ---------------------------------------------------------------------------------------------
function Get-EventsFile { Join-Path $script:AppDataFolder 'Anno1602-Extensions\events.json' }

# Sign of an event effect ("+5'000 Gold", "Taxes -25% for 1 game hour"): 1 good, -1 bad, 0 unknown.
function Get-EffectSign($effect) {
    $t = '{0} {1}' -f $(if ($effect -is [string]) { $effect } elseif ($effect) { $effect.en } else { '' }), $(if ($effect -and $effect -isnot [string]) { $effect.de } else { '' })
    if ($t -match '(^|\s)[-−]\s?\d') { return -1 }
    if ($t -match '(^|\s)\+\s?\d') { return 1 }
    0
}

function Get-LangText($o) {
    if ($null -eq $o) { return '' }
    if ($o -is [string]) { return $o }
    $a = if ($script:UiGerman) { $o.de } else { $o.en }
    if (-not $a) { $a = if ($script:UiGerman) { $o.en } else { $o.de } }
    [string]$a
}

# All events of the file, or $null when the file is broken (a missing file is an empty list).
function Read-EventsFile {
    $file = Get-EventsFile
    if (-not (Test-Path -LiteralPath $file)) { return , @() }
    try { $j = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { return $null }
    if (-not $j) { return $null }
    $list = New-Object Collections.ArrayList
    foreach ($e in @($j.events)) {
        if (-not $e) { continue }
        try {
            [void]$list.Add(@{
                    Time = (Convert-IsoDate $e.time); Pid = [int]$e.pid; Clock = [long]$e.clock; EndsClock = [long]$e.endsClock; Id = [string]$e.id; EndedEarly = [bool]$e.endedEarly
                    Title = $e.title; Text = $e.text; Effect = $e.effect; Key = ('{0}|{1}|{2}' -f $e.time, $e.id, $e.clock)
                })
        }
        catch { }
    }
    , @($list)
}

# Re-reads events.json when it changed. New events of this process go to Events.New (banner) when they
# are recent: at most 2 minutes old, at the first reading for a process at most 20 seconds.
function Update-Events($lb, [datetime]$now) {
    $ev = $lb.Events
    $ev.New = @()
    $procId = [int]$lb.Conn.Pid
    if ($ev.Pid -ne $procId) { $ev.Pid = $procId; $ev.List = @(); $ev.Seen = @{}; $ev.Stamp = ''; $ev.First = $true }
    if (-not $procId) { return }
    $stamp = 'none'
    try { $fi = Get-Item -LiteralPath (Get-EventsFile) -ErrorAction Stop; $stamp = '{0}|{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks } catch { }
    if ($stamp -eq $ev.Stamp) { return }
    $all = Read-EventsFile
    if ($null -eq $all) { return }   # broken: keep the list, read again next time
    $mine = @($all | Where-Object { $_.Pid -eq $procId })
    $new = New-Object Collections.ArrayList
    foreach ($e in $mine) {
        if ($ev.Seen.ContainsKey($e.Key)) { continue }
        $ev.Seen[$e.Key] = 1
        $limit = if ($ev.First) { 20 } else { 120 }
        $recent = $e.Time -eq [datetime]::MinValue -or [Math]::Abs(($now - $e.Time).TotalSeconds) -le $limit
        if ($recent -and -not ($ev.First -and $e.Time -eq [datetime]::MinValue)) { [void]$new.Add($e) }
    }
    $ev.List = $mine; $ev.New = @($new); $ev.First = $false; $ev.Stamp = $stamp
}

# Events that belong to the session: same process, not before the start of the session.
function Get-SessionEvents($lb, $s) {
    if (-not $s -or $lb.Events.Pid -ne $s.Pid) { return @() }
    @($lb.Events.List | Where-Object { if ($_.Time -ne [datetime]::MinValue) { $_.Time -ge $s.Start.AddSeconds(-2) } else { $_.Clock -ge $s.FirstClock } })
}

# One step with a new snapshot (or $null): determines the phase, records a finished mission once,
# unlocks achievements (condition must hold in two consecutive readings). $now for tests.
function Update-GameState($lb, $snap, [datetime]$now) {
    $st = @{ Phase = $lb.Conn.Status; Snap = $snap; NewUnlocks = @(); Result = ''; NewEvents = @() }
    $lb.Fresh = @{}
    # The game process ended since the last reading (Update-Attachment): its game was summarised.
    $pendingEnd = $lb.PendingEnd; $lb.PendingEnd = $null
    if ($pendingEnd) {
        $st.NewUnlocks = @($pendingEnd.NewUnlocks); $st.Summary = $pendingEnd.Summary
        foreach ($a in $st.NewUnlocks) { $lb.Fresh[$a.id] = 1 }
        if ($pendingEnd.SaveError) { $st.SaveError = $pendingEnd.SaveError }
    }
    if ($lb.Conn.Status -ne 'attached') { return $st }
    try { Update-Events $lb $now; $st.NewEvents = @($lb.Events.New) } catch { Add-LogbookError $lb "events: $($_.Exception.Message)" }
    if ($null -eq $snap) { $st.Phase = 'starting'; return $st }
    $hs = Get-HumanSlot $snap; $hp = $snap.Players[$hs]
    $paused = $false
    if ($snap.Clock -eq $lb.LastClock) { $lb.SameClockTicks++ } else { $lb.SameClockTicks = 0 }
    $lb.LastClock = $snap.Clock
    if ($snap.Clock -le 0) { $st.Phase = 'nogame' }
    elseif ($snap.Lock -ne 0 -or $hp.Kind -eq 9) { $st.Phase = 'ended' }
    elseif ($hp.Kind -eq 0) { $st.Phase = 'running'; $paused = $lb.SameClockTicks -ge 1 }
    else { $st.Phase = 'nogame' }
    $st.Paused = $paused
    if ($st.Phase -eq 'nogame') { $lb.Pending = @{}; return $st }

    $st.HumanSlot = $hs
    $st.Me = Get-PlayerStats $snap $hs
    $st.Mission = Get-MissionEvaluation $snap $hs -AnyKind
    $st.Money = Get-Balance $snap $hp.No
    $st.GameName = Get-GameName $snap $st.Mission
    $st.Rivals = foreach ($i in 0..3) {
        if ($i -eq $hs) { continue }
        $q = $snap.Players[$i]
        if ($q.Kind -ne 0xC -and $q.Kind -ne 9 -and $q.Kind -ne 0) { continue }
        $r = Get-PlayerStats $snap $i
        if ($q.Kind -eq 9 -and $r.TownCount -eq 0 -and $r.Ships -eq 0) { continue }   # slot not in this game
        $r.Race = if ($q.Kind -eq 0xC) { Get-MissionEvaluation $snap $i } else { $null }
        $r
    }
    $newOnes = New-Object Collections.ArrayList
    $game = $st.GameName

    if ($st.Phase -eq 'running') {
        $lb.Track.SawRunning = $true
        $lb.Track.Scenario = $snap.ScenarioName
        $lb.Track.Title = if ($st.Mission) { Get-MissionTitle $st.Mission.Mission } else { '' }
        $lb.Track.HasMission = $null -ne $st.Mission -and $hp.MissionSlot -le 3
        $lb.Track.Race = $st.Mission -and $st.Mission.Race
        $lb.Track.Game = $game
        # History: session, one point per game minute, peaks.
        $ctx = @{ Session = $null; Events = @(); Now = $now; Kind = '' }
        try {
            $ended = Sync-Session $lb $snap $st $now
            if ($ended) {
                $st.NewUnlocks = @($st.NewUnlocks) + @($ended.NewUnlocks); $st.Summary = $ended.Summary
                if ($ended.SaveError) { $st.SaveError = $ended.SaveError }
            }
            Update-SessionReading $lb $snap $st
            $s = $lb.Session
            $s.Game = $game
            $ctx.Session = $s; $ctx.Kind = $s.Kind; $ctx.Events = @(Get-SessionEvents $lb $s); $s.EventCount = $ctx.Events.Count
            # The card of the previous game folds away after 10 game minutes of the next one.
            if ($lb.ShowSummary -and $lb.SummaryFrom -ne $s.Id -and ($s.LastClock - $s.FirstClock) -ge 10 * $SampleClocks) { $lb.ShowSummary = $false }
        }
        catch { Add-LogbookError $lb "history: $($_.Exception.Message)" }
        $cond = Get-AchievementConditions $snap $st.Me $st.Money $ctx
        foreach ($id in $cond.Keys) {
            if ($lb.Unlocked.ContainsKey($id)) { continue }
            if ($lb.Pending.ContainsKey($id)) { [void]$newOnes.Add([ordered]@{ id = $id; date = $now.ToString('s'); game = $game }) }
        }
        $lb.Pending = $cond
    }
    else {
        # ended: the human's mission flag (player +0x84, the "mission bonus" of the score screen) decides.
        $st.Result = if ($hp.Fulfilled) { 'won' } else { 'lost' }
        $lb.Pending = @{}
        if ($lb.Track.SawRunning) {
            $lb.Track.SawRunning = $false
            $missionEntry = $null
            if ($lb.Track.HasMission) {
                $missionEntry = [ordered]@{ scenario = [string]$lb.Track.Scenario; title = [string]$lb.Track.Title; result = $st.Result; date = $now.ToString('s'); gameHours = [Math]::Round($snap.Clock / $ClockPerHour, 1) }
                $st.RecordedMission = $missionEntry
                if ($hp.Fulfilled) {
                    foreach ($id in @('mission_won') + $(if ($lb.Track.Race) { @('race_won') } else { @() })) {
                        if (-not $lb.Unlocked.ContainsKey($id)) { [void]$newOnes.Add([ordered]@{ id = $id; date = $now.ToString('s'); game = $lb.Track.Game }) }
                    }
                }
            }
            # One write: end unlocks, the mission, the game summary and the long-term achievements.
            $done = Complete-Session $lb $st.Result $now $snap @($newOnes) $missionEntry
            if ($done.SaveError) { $st.SaveError = $done.SaveError }
            $st.NewUnlocks = @($st.NewUnlocks) + @($done.NewUnlocks)
            $st.Summary = $done.Summary
            return $st
        }
    }
    if ($newOnes.Count) {
        try { [void](Add-LogbookEntries @($newOnes) @()) } catch { $st.SaveError = $_.Exception.Message }
        foreach ($a in $newOnes) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
        if ($lb.Session -and -not $lb.Session.Done) { foreach ($a in $newOnes) { if (-not $lb.Session.Achievements.Contains($a.id)) { [void]$lb.Session.Achievements.Add($a.id) } } }
        $st.NewUnlocks = @($st.NewUnlocks) + @($newOnes)
    }
    $st
}

function Add-LogbookError($lb, [string]$text) {
    [void]$lb.Errors.Add($text)
    while ($lb.Errors.Count -gt 20) { $lb.Errors.RemoveAt(0) }
}

# ---------------------------------------------------------------------------------------------
# View: list of items for the canvas.
# ---------------------------------------------------------------------------------------------
$StageColors = @(
    [Drawing.Color]::FromArgb(161, 122, 96), [Drawing.Color]::FromArgb(201, 174, 112), [Drawing.Color]::FromArgb(86, 156, 214),
    [Drawing.Color]::FromArgb(163, 118, 214), [Drawing.Color]::FromArgb(232, 190, 70), [Drawing.Color]::FromArgb(104, 116, 134))

function New-ViewItem {
    param([string]$Kind = 'Row', [string]$Text = '', [string]$Right = '', [string]$Sub = '', [string]$Icon = '',
        [string]$Meter1 = '', [double]$Value1 = -1, [string]$Meter2 = '', [double]$Value2 = -1,
        [switch]$Bold, [switch]$Done, [switch]$Dim, [switch]$Highlight, $TextColor, $RightColor, $IconColor, $SubColor, [string]$Tip)
    $i = New-Object AnnoLogbook.Item
    $i.Kind = [AnnoLogbook.Kind]$Kind; $i.Text = $Text; $i.Right = $Right; $i.Sub = $Sub; $i.Icon = $Icon
    $i.Meter1 = $Meter1; $i.Value1 = $Value1; $i.Meter2 = $Meter2; $i.Value2 = $Value2
    $i.Bold = $Bold; $i.Done = $Done; $i.Dim = $Dim; $i.Highlight = $Highlight
    if ($TextColor) { $i.TextColor = $TextColor }; if ($RightColor) { $i.RightColor = $RightColor }
    if ($IconColor) { $i.IconColor = $IconColor }; if ($SubColor) { $i.SubColor = $SubColor }
    if ($Tip) { $i.Tip = $Tip }
    $i
}

function Add-GoalItems($list, $ev) {
    foreach ($g in $ev.Goals) {
        $icon = if ($g.Done) { [string][char]0x2713 } else { [string][char]0x25CB }
        $right = if ($g.Done) { Txt 'done' 'erfüllt' } else { '{0:0} %' -f [Math]::Floor($g.Progress * 100) }
        $prm = @{ Text = $g.Title; Icon = $icon; Right = $right; Done = [bool]$g.Done; Sub = $g.Sub }
        if ($g.Meters.Count -ge 1) { $prm.Meter1 = $g.Meters[0].Label; $prm.Value1 = $g.Meters[0].Value }
        if ($g.Meters.Count -ge 2) { $prm.Meter2 = $g.Meters[1].Label; $prm.Value2 = $g.Meters[1].Value }
        $list.Add((New-ViewItem @prm))
    }
}

$EventColor = [Drawing.Color]::FromArgb(104, 160, 222)
$TownColor = [Drawing.Color]::FromArgb(86, 156, 214)

# Section header that can be clicked to fold the section away; returns $true when the section is open.
function Add-SectionHeader($list, $lb, [string]$id, [string]$text, [string]$right = '', $rightColor = $null, [string]$tip = '') {
    $collapsed = $lb.Collapsed.ContainsKey($id)
    $h = New-ViewItem -Kind Header -Text $text -Right $right -RightColor $rightColor -Tip $tip
    $h.Key = "section:$id"; $h.Collapsible = $true; $h.Collapsed = $collapsed
    $list.Add($h)
    -not $collapsed
}

function Add-TabItems($list, $lb) {
    $t = New-ViewItem -Kind Tabs
    $t.Legend = [string[]]@((Txt 'Game' 'Spiel'), (Txt 'History' 'Verlauf'))
    $t.Value1 = $(if ($lb.Tab -eq 'history') { 1 } else { 0 })
    $t.Key = 'tabs'
    $list.Add($t)
}

# Result of a game summary as text and colour.
function Get-ResultLook($g) {
    $good = [AnnoLogbook.Canvas]::Good; $bad = [AnnoLogbook.Canvas]::Bad; $dim = [AnnoLogbook.Canvas]::DimColor
    switch ([string]$g.result) {
        'won' { @{ Text = (Txt 'Won' 'Gewonnen'); Color = $good; Border = $good } }
        'lost' { @{ Text = (Txt 'Lost' 'Verloren'); Color = $bad; Border = $bad } }
        default {
            if ($g.mission) { @{ Text = (Txt 'Not finished' 'Nicht beendet'); Color = $dim; Border = [AnnoLogbook.Canvas]::Rule } }
            else { @{ Text = (Txt 'Played' 'Gespielt'); Color = [AnnoLogbook.Canvas]::Accent; Border = [AnnoLogbook.Canvas]::Rule } }
        }
    }
}

function Get-SummaryName($g) {
    if ([string]$g.kind -eq 'endless') { return (Txt 'Endless game' 'Endlosspiel') }
    if ($g.game) { return [string]$g.game }
    if ($g.scenario) { return [string]$g.scenario }
    Txt 'Scenario' 'Szenario'
}

function Format-SummaryDate($v) {
    $d = Convert-IsoDate $v
    if ($d -eq [datetime]::MinValue) { return [string]$v }
    $d.ToString('g', (Get-Culture2))
}

function Get-SummaryClock($g) {
    if ($null -ne $g.endClock) { return [long]$g.endClock }
    [long]([double]$g.gameHours * $ClockPerHour)
}

# The summary card of a finished game.
function New-SummaryCard($g) {
    $look = Get-ResultLook $g
    $sub = if ([string]$g.kind -eq 'endless') { Format-SummaryDate $g.date } else { '{0} · {1}' -f (Get-GameKindName ([string]$g.kind)), (Format-SummaryDate $g.date) }
    $card = New-ViewItem -Kind Card -Text (Get-SummaryName $g) -Right $look.Text -RightColor $look.Color -Sub $sub
    $card.BarColor = $look.Border
    $towns = [string]$g.towns
    if ([long]$g.peakTowns -gt [long]$g.towns) { $towns += ' ' + ((Txt '(max. {0})' '(max. {0})') -f $g.peakTowns) }
    $top = [int]$(if ($null -ne $g.topStage) { $g.topStage } else { -1 })
    $ids = @($g.achievements | Where-Object { $_ })
    $cells = @(
        (Txt 'Game time' 'Spielzeit'), (Format-GameTime (Get-SummaryClock $g)),
        (Txt 'Most residents' 'Max. Einwohner'), (Format-Num ([double]$g.peakResidents)),
        (Txt 'Most gold' 'Max. Gold'), (Format-Num ([double]$g.peakGold)),
        (Txt 'Towns' 'Städte'), $towns,
        (Txt 'Highest stage' 'Höchste Stufe'), $(if ($top -ge 0) { Get-StageName $top } else { '–' }),
        (Txt 'Achievements' 'Erfolge'), [string]$ids.Count)
    if ([int]$g.events -gt 0) { $cells += @((Txt 'Events' 'Ereignisse'), [string]$g.events) }
    if ([double]$g.playedHours -gt 0 -and [Math]::Abs([double]$g.playedHours - [double]$g.gameHours) -ge 0.2) { $cells += @((Txt 'Played this time' 'Diesmal gespielt'), (Format-GameTime ([double]$g.playedHours * $ClockPerHour))) }
    $card.Cells = [string[]]$cells
    $names = @(foreach ($id in $ids) { $a = $Achievements | Where-Object { $_.Id -eq $id }; if ($a) { Get-AchievementName $a } })
    $card.Body = if ($names.Count) { (Txt 'Unlocked in this game: {0}' 'In dieser Partie freigeschaltet: {0}') -f ($names -join ', ') } else { Txt 'No new achievements in this game.' 'Keine neuen Erfolge in dieser Partie.' }
    $card
}

# Events of the running game process: newest first (at most 5), active ones highlighted.
function Add-EventItems($list, $lb, $st) {
    $evs = @($lb.Events.List)
    if (-not $evs.Count -or $lb.Events.Pid -ne $lb.Conn.Pid -or -not $lb.Conn.Pid) { return }
    $clock = if ($st.Snap) { [long]$st.Snap.Clock } else { 0L }
    if (-not (Add-SectionHeader $list $lb 'events' (Txt 'EVENTS' 'EREIGNISSE') ([string]$evs.Count))) { return }
    $shown = 0
    for ($i = $evs.Count - 1; $i -ge 0 -and $shown -lt 5; $i--) {
        $e = $evs[$i]; $shown++
        $title = Get-LangText $e.Title; if (-not $title) { $title = $e.Id }
        $effect = Get-LangText $e.Effect
        # endedEarly (set by the patcher): ended with the game, by loading another game or when its window closed.
        $active = $e.EndsClock -gt 0 -and $clock -lt $e.EndsClock -and -not $e.EndedEarly
        $sub = (Txt 'game time {0}' 'Spielzeit {0}') -f (Format-GameTime $e.Clock)
        if ($active) { $sub += ' · ' + ((Txt 'active, {0} left' 'läuft noch {0}') -f (Format-GameTime ($e.EndsClock - $clock))) }
        elseif ($e.EndedEarly) { $sub += ' · ' + (Txt 'ended early' 'vorzeitig beendet') }
        elseif ($e.EndsClock -gt 0) { $sub += ' · ' + (Txt 'over' 'vorbei') }
        $sign = Get-EffectSign $e.Effect
        $color = if ($sign -gt 0) { [AnnoLogbook.Canvas]::Good } elseif ($sign -lt 0) { [AnnoLogbook.Canvas]::Bad } else { [AnnoLogbook.Canvas]::Accent }
        $iconColor = if ($active) { $EventColor } else { [AnnoLogbook.Canvas]::DimColor }
        $list.Add((New-ViewItem -Text $title -Right $effect -RightColor $color -Sub $sub -Icon ([string][char]0x2726) -IconColor $iconColor -Tip (Get-LangText $e.Text)))
    }
    if ($evs.Count -gt $shown) { $list.Add((New-ViewItem -Kind Note -Dim -Text ((Txt '… and {0} earlier events' '… und {0} frühere Ereignisse') -f ($evs.Count - $shown)))) }
}

# What the History tab shows: a game picked in the list, else the current (or last) session, else the
# newest history file. Returns @{ Session; Summary; Live; Selected }.
function Get-CachedHistory($lb, [string]$name) {
    if (-not $name) { return $null }
    if (-not $lb.HistoryCache.ContainsKey($name)) { $lb.HistoryCache[$name] = Read-HistoryFile (Join-Path (Get-HistoryFolder) $name) }
    $lb.HistoryCache[$name]
}
function Get-HistorySource($lb) {
    if ($lb.SelectedGame) {
        $g = $lb.SelectedGame
        return @{ Session = (Get-CachedHistory $lb ([string]$g.history)); Summary = $g; Live = $false; Selected = $true }
    }
    if ($lb.Session) { return @{ Session = $lb.Session; Summary = $(if ($lb.Session.Done) { $lb.Session.End } else { $null }); Live = -not $lb.Session.Done; Selected = $false } }
    if (-not $lb.LastHistoryLoaded) {
        $lb.LastHistoryLoaded = $true
        try {
            $f = Get-ChildItem -LiteralPath (Get-HistoryFolder) -Filter '*.json' -File -ErrorAction Stop | Sort-Object Name -Descending | Select-Object -First 1
            if ($f) { $lb.LastHistory = Read-HistoryFile $f.FullName }
        }
        catch { }
    }
    if ($lb.LastHistory) { return @{ Session = $lb.LastHistory; Summary = $lb.LastHistory.End; Live = $false; Selected = $false } }
    @{ Session = $null; Summary = $null; Live = $false; Selected = $false }
}

function New-ChartItem([string]$title, [string]$right, $rightColor, $x, $series, [string[]]$names, $colors) {
    $c = New-ViewItem -Kind Chart -Text $title -Right $right -RightColor $rightColor
    $c.X = [double[]]$x; $c.Series = [double[][]]$series; $c.SeriesNames = $names; $c.Colors = [Drawing.Color[]]$colors
    $c.Culture = if ($script:UiGerman) { 'de-DE' } else { 'en-US' }
    $c.ClockPerHour = $ClockPerHour
    $c.EmptyText = Txt 'No history yet – the first point comes after one game minute.' 'Noch kein Verlauf – der erste Punkt folgt nach einer Spielminute.'
    $c
}

# Four small charts: gold, residents per stage (stacked), balance (green above zero, red below), towns and ships.
function Add-ChartItems($list, $s) {
    $rows = $s.Samples
    $x = [AnnoLogbook.Util]::Column($rows, 0)
    $col = { param($i) , ([AnnoLogbook.Util]::Column($rows, $i)) }
    $last = $rows[$rows.Count - 1]
    $acc = [AnnoLogbook.Canvas]::Accent
    $list.Add((New-ChartItem (Txt 'Gold' 'Gold') (Format-Num $last[1]) $acc $x @(, (& $col 1)) @((Txt 'Gold' 'Gold')) @($acc)))
    $names = [string[]]@((0..4 | ForEach-Object { Get-StageName $_ }) + @((Txt 'Workers' 'Arbeiter')))
    $res = New-ChartItem (Txt 'Residents' 'Einwohner') (Format-Num $last[2]) $null $x @((& $col 3), (& $col 4), (& $col 5), (& $col 6), (& $col 7), (& $col 8)) $names $StageColors
    $res.Stacked = $true; $res.TotalName = Txt 'Total' 'Gesamt'; $res.Legend = $names
    $list.Add($res)
    $bal = New-ChartItem (Txt 'Balance' 'Bilanz') (Format-Signed $last[9]) $(if ($last[9] -lt 0) { [AnnoLogbook.Canvas]::Bad } else { [AnnoLogbook.Canvas]::Good }) $x @(, (& $col 9)) @((Txt 'Balance' 'Bilanz')) @([AnnoLogbook.Canvas]::Good)
    $bal.ZeroSplit = $true
    $list.Add($bal)
    $tn = [string[]]@((Txt 'Towns' 'Städte'), (Txt 'Ships' 'Schiffe'))
    $tw = New-ChartItem (Txt 'Towns · ships' 'Städte · Schiffe') ('{0} · {1}' -f $last[10], $last[11]) $null $x @((& $col 10), (& $col 11)) $tn @($TownColor, [AnnoLogbook.Canvas]::DimColor)
    $tw.Legend = $tn
    $list.Add($tw)
}

function Add-GameListItems($list, $lb) {
    $games = @($lb.Games | Where-Object { $_ })
    $n = $games.Count
    if (-not (Add-SectionHeader $list $lb 'games' (Txt 'PLAYED GAMES' 'GESPIELTE PARTIEN') $(if ($n) { [string]$n } else { '' }))) { return }
    if (-not $n) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'No finished game yet – every game appears here when it ends.' 'Noch keine beendete Partie – jede Partie erscheint hier, sobald sie endet.'))); return }
    $won = @($games | Where-Object { $_.result -eq 'won' }).Count; $lost = @($games | Where-Object { $_.result -eq 'lost' }).Count
    $hours = 0.0; foreach ($g in $games) { try { $hours += [double]$g.playedHours } catch { } }
    $list.Add((New-ViewItem -Kind Note -Dim -Text ((Txt '{0} won · {1} lost · {2} game hours played' '{0} gewonnen · {1} verloren · {2} Spielstunden gespielt') -f $won, $lost, (Format-Num ([Math]::Round($hours))))))
    $max = if ($lb.ShowAllGames) { $n } else { [Math]::Min($n, 10) }
    for ($i = $n - 1; $i -ge $n - $max; $i--) {
        $g = $games[$i]
        $look = Get-ResultLook $g
        $sub = '{0} · {1} · {2} {3}' -f (Format-SummaryDate $g.date), (Format-GameTime (Get-SummaryClock $g)), (Format-Num ([double]$g.peakResidents)), (Txt 'residents max.' 'Einw. max.')
        $row = New-ViewItem -Text (Get-SummaryName $g) -Right $look.Text -RightColor $look.Color -Sub $sub -Tip (Txt 'Click: show the history of this game' 'Klick: Verlauf dieser Partie zeigen')
        $row.Key = "game:$i"
        $row.Highlight = [object]::ReferenceEquals($g, $lb.SelectedGame)
        $list.Add($row)
    }
    if ($n -gt 10) {
        $more = New-ViewItem -Kind Note -Dim -Text $(if ($lb.ShowAllGames) { Txt '▴ Show fewer' '▴ Weniger anzeigen' } else { (Txt '▾ Show all {0} games' '▾ Alle {0} Partien anzeigen') -f $n })
        $more.Key = 'games:more'; $more.TextColor = [AnnoLogbook.Canvas]::Accent
        $list.Add($more)
    }
}

function Add-HistoryItems($list, $lb, $st) {
    $src = Get-HistorySource $lb
    $s = $src.Session
    $right = if ($src.Live) { Txt 'current game' 'laufende Partie' } elseif ($src.Summary) { Format-SummaryDate $src.Summary.date } elseif ($s) { Format-SummaryDate $s.Start.ToString('s') } else { '' }
    if (Add-SectionHeader $list $lb 'charts' (Txt 'HISTORY' 'VERLAUF') $right) {
        if ($src.Selected) {
            $back = New-ViewItem -Kind Note -Dim -Text ((Txt '◂ Back to {0}' '◂ Zurück zur {0}') -f $(if ($lb.Session -and -not $lb.Session.Done) { Txt 'the current game' 'laufenden Partie' } else { Txt 'the last game' 'letzten Partie' }))
            $back.Key = 'history:live'; $back.TextColor = [AnnoLogbook.Canvas]::Accent
            $list.Add($back)
        }
        if ($s -and $s.Samples.Count -ge 2) {
            if (-not $src.Live -and -not $src.Summary) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Get-SummaryName @{ kind = $s.Kind; game = $s.Game; scenario = $s.Scenario }))) }
            Add-ChartItems $list $s
        }
        elseif ($src.Selected) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'No history saved for this game (only the newest 30 games keep theirs).' 'Für diese Partie ist kein Verlauf gespeichert (nur die neuesten 30 Partien behalten ihn).'))) }
        else { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'No history yet – the logbook draws one point about every game minute while a game runs.' 'Noch kein Verlauf – das Logbuch zeichnet etwa jede Spielminute einen Punkt auf, solange ein Spiel läuft.'))) }
        if ($src.Summary) { $list.Add((New-SummaryCard $src.Summary)) }
        elseif ($src.Live -and $s.Readings -ge 2) {
            $peakGold = if ($s.PeakGold -eq [long]::MinValue) { 0 } else { $s.PeakGold }
            $list.Add((New-ViewItem -Kind Note -Dim -Text ((Txt 'Best so far: {0} residents · {1} gold · {2} towns' 'Bisher am besten: {0} Einwohner · {1} Gold · {2} Städte') -f (Format-Num $s.PeakResidents), (Format-Num $peakGold), $s.PeakTowns)))
        }
    }
    Add-GameListItems $list $lb
}

function Get-ViewItems($lb, $st, [bool]$compact) {
    $list = New-Object 'System.Collections.Generic.List[AnnoLogbook.Item]'
    $good = [AnnoLogbook.Canvas]::Good; $bad = [AnnoLogbook.Canvas]::Bad
    switch ($st.Phase) {
        'waiting' { $list.Add((New-ViewItem -Kind Title -Text (Txt 'Waiting for Anno 1602 …' 'Warte auf Anno 1602 …') -Sub (Txt 'Start the game – the logbook connects by itself.' 'Starte das Spiel – das Logbuch verbindet sich von selbst.'))) }
        'starting' { $list.Add((New-ViewItem -Kind Title -Text (Txt 'Anno 1602 is starting …' 'Anno 1602 startet …') -Sub (Txt 'Connecting to the game.' 'Verbinde mit dem Spiel.'))) }
        'version' { $list.Add((New-ViewItem -Kind Title -Text (Txt 'Unknown game version' 'Unbekannte Spielversion') -Sub (Txt 'The logbook only fits the tested version.' 'Das Logbuch passt nur zur getesteten Version.')))
            $list.Add((New-ViewItem -Kind Note -Dim -Text ((Txt 'SHA-256 of Anno1602.exe: {0}. Nothing is read.' 'SHA-256 von Anno1602.exe: {0}. Es wird nichts gelesen.') -f $lb.Conn.Detail))) }
        'denied' { $list.Add((New-ViewItem -Kind Title -Text (Txt 'No access to the game' 'Kein Zugriff auf das Spiel') -Sub ((Txt 'Windows refused access ({0}).' 'Windows verweigert den Zugriff ({0}).') -f $lb.Conn.Detail))) }
        'nogame' { $list.Add((New-ViewItem -Kind Title -Text (Txt 'Anno 1602 is running' 'Anno 1602 läuft') -Sub (Txt 'Start or load a game.' 'Starte oder lade ein Spiel.'))) }
    }
    $inGame = $st.Phase -eq 'running' -or $st.Phase -eq 'ended'
    if ($inGame) {
        $snap = $st.Snap; $me = $st.Me; $ev = $st.Mission
        $sub = Get-SpeedText $snap.Speed
        $subColor = $null
        if ($st.Phase -eq 'ended') {
            if ($st.Result -eq 'won' -and $ev) { $sub = Txt 'Mission accomplished – victory!' 'Auftrag erfüllt – gewonnen!'; $subColor = $good }
            else { $sub = Txt 'Game over.' 'Spiel beendet.'; if ($ev) { $sub = Txt 'Game over – lost this time.' 'Spiel beendet – diesmal verloren.'; $subColor = $bad } }
        }
        elseif ($st.Paused) { $sub += ' · ' + (Txt 'paused or in a menu' 'pausiert oder im Menü') }
        $list.Add((New-ViewItem -Kind Title -Text $st.GameName -Right (Format-GameTime $snap.Clock) -Sub $sub -SubColor $subColor -Tip ((Txt 'Game time at normal speed (game clock {0})' 'Spielzeit bei normalem Tempo (Spieluhr {0})') -f (Format-Num $snap.Clock))))
    }
    if (-not $compact) {
        Add-TabItems $list $lb
        if ($lb.Tab -eq 'history') { Add-HistoryItems $list $lb $st; return , $list }
        if ($lb.ShowSummary -and $lb.LastSummary) {
            $h = New-ViewItem -Kind Header -Text (Txt 'LAST GAME' 'LETZTE PARTIE') -Right (Txt 'hide ✕' 'ausblenden ✕') -Tip (Txt 'Click to hide; the History tab keeps every game.' 'Klicken zum Ausblenden; der Verlauf behält jede Partie.')
            $h.Key = 'summary:hide'
            $list.Add($h)
            $list.Add((New-SummaryCard $lb.LastSummary))
        }
    }
    if ($inGame) {
        # Mission
        $open = $true
        if ($ev) {
            $tip = $ev.Mission.Text; if ($tip.Length -gt 1500) { $tip = $tip.Substring(0, 1500) + ' …' }
            $right = if ($ev.Fulfilled) { Txt 'accomplished' 'erfüllt' } else { (Txt '{0} of {1} met' '{0} von {1} erfüllt') -f $ev.Met, $ev.Count }
            if (-not $compact) { $open = Add-SectionHeader $list $lb 'mission' (Txt 'MISSION' 'AUFTRAG') $right $(if ($ev.Fulfilled) { $good } else { $null }) $tip }
            if ($open) {
                if ($ev.Race -and -not $compact) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'Race: whoever completes the mission first wins – the rivals have the same goals.' 'Wettlauf: Wer den Auftrag zuerst erfüllt, gewinnt – die Gegner haben dieselben Ziele.'))) }
                if ($snap.TimeLimit -gt 0 -and $st.Phase -eq 'running') {
                    $list.Add((New-ViewItem -Text (Format-TimeLimit $snap.TimeLimit $snap.Clock) -Icon '!' -IconColor $bad -TextColor $bad))
                }
                Add-GoalItems $list $ev
                if ($ev.SubBits -band 3) {
                    $who = if ($ev.Mission.SupportPlayer -eq 7) { Txt 'the other players' 'die Mitspieler' } else { Get-PlayerName $snap $ev.Mission.SupportPlayer }
                    $okSub = -not ($ev.SubFailing -band 3)
                    $list.Add((New-ViewItem -Text ((Txt 'Condition: protect {0}' 'Bedingung: {0} beschützen') -f $who) -Icon $(if ($okSub) { [string][char]0x2713 } else { '!' }) -Done:$okSub -Right $(if ($okSub) { 'ok' } else { Txt 'at risk' 'in Gefahr' }) -RightColor $(if ($okSub) { $good } else { $bad }) -Sub (Txt 'If this fails, the game is lost.' 'Wenn das scheitert, ist das Spiel verloren.')))
                }
            }
        }
        else {
            if (-not $compact) { $open = Add-SectionHeader $list $lb 'mission' (Txt 'MISSION' 'AUFTRAG') }
            if ($open) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'No mission – free play. The achievements still count.' 'Kein Auftrag – freies Spiel. Die Erfolge zählen trotzdem.'))) }
        }

        if ($compact) {
            $list.Add((New-ViewItem -Kind Space))
            $list.Add((New-ViewItem -Text ('{0} {1} · {2} {3} · {4} {5}' -f (Txt 'Gold' 'Gold'), (Format-Num $snap.Players[$st.HumanSlot].Gold), (Format-Num $me.Total), (Txt 'res.' 'Einw.'), $me.TownCount, (Txt 'towns' 'Städte')) -Dim))
            Add-CompactSummary $list $lb $st
            return , $list
        }

        # Your empire
        if (Add-SectionHeader $list $lb 'empire' (Txt 'YOUR EMPIRE' 'DEIN REICH') $snap.Players[$st.HumanSlot].Name) {
            $gold = $snap.Players[$st.HumanSlot].Gold
            $list.Add((New-ViewItem -Text (Txt 'Gold' 'Gold') -Right (Format-Num $gold) -RightColor $(if ($gold -lt 0) { $bad } else { [AnnoLogbook.Canvas]::Accent })))
            $mo = $st.Money
            $list.Add((New-ViewItem -Text (Txt 'Balance · trade balance' 'Bilanz · Handelsbilanz') -Right ('{0} · {1}' -f (Format-Signed $mo.Balance), (Format-Signed $mo.Trade)) -RightColor $(if ($mo.Balance -lt 0) { $bad } else { $null }) -Tip ((Txt 'Taxes {0}, sales {1}, purchases {2}, operating costs {3}, military {4}' 'Steuern {0}, Verkauf {1}, Einkauf {2}, Betriebskosten {3}, Militär {4}') -f (Format-Num $mo.Taxes), (Format-Num $mo.Sales), (Format-Num $mo.Purchases), (Format-Num $mo.Costs), (Format-Num $mo.Military))))
            $bestText = if ($me.Best) { (Txt 'largest: {0} ({1})' 'grösste: {0} ({1})') -f $me.Best.Name, (Format-Num $me.Best.Total) } else { '' }
            $list.Add((New-ViewItem -Text (Txt 'Towns' 'Städte') -Right ([string]$me.TownCount) -Sub $bestText))
            $list.Add((New-ViewItem -Text (Txt 'Ships' 'Schiffe') -Right ([string]$me.Ships)))
            $stack = New-ViewItem -Kind Stack -Text (Txt 'Residents' 'Einwohner') -Right (Format-Num $me.Total) -Tip (Txt 'Workers: residents working in production and public buildings; the game counts them in the total.' 'Arbeiter: Einwohner in Betrieben und öffentlichen Gebäuden; das Spiel zählt sie zur Gesamtzahl.')
            $stack.Values = [int[]]@($me.Stages[0], $me.Stages[1], $me.Stages[2], $me.Stages[3], $me.Stages[4], $me.Workers)
            $stack.Colors = [Drawing.Color[]]$StageColors
            $stack.Legend = [string[]]@((0..4 | ForEach-Object { '{0} {1}' -f (Get-StageName $_), (Format-Num $me.Stages[$_]) }) + @('{0} {1}' -f (Txt 'Workers' 'Arbeiter'), (Format-Num $me.Workers)))
            $list.Add($stack)
        }

        # Rivals
        $rivals = @($st.Rivals)
        if ($rivals.Count -and (Add-SectionHeader $list $lb 'rivals' (Txt 'RIVALS' 'GEGNER'))) {
            foreach ($r in $rivals) {
                $out = $r.Kind -eq 9 -and $st.Phase -ne 'ended'
                $ships = if ($r.Ships -eq 1) { Txt '1 ship' '1 Schiff' } else { (Txt '{0} ships' '{0} Schiffe') -f $r.Ships }
                $line = if ($r.Best) {
                    $towns = if ($r.TownCount -eq 1) { Txt '1 town' '1 Stadt' } else { (Txt '{0} towns' '{0} Städten') -f $r.TownCount }
                    (Txt 'best town {0} ({1}) · {2} res. in {3} · {4}' 'beste Stadt {0} ({1}) · {2} Einw. in {3} · {4}') -f $r.Best.Name, (Format-Num $r.Best.Total), (Format-Num $r.Total), $towns, $ships
                }
                else { (Txt 'no town yet · {0}' 'noch keine Stadt · {0}') -f $ships }
                $prm = @{ Text = $r.Name; Bold = $true; Right = ('{0} {1}' -f (Format-Num $r.Gold), (Txt 'gold' 'Gold')); Sub = $line; Icon = [string][char]0x25C6; IconColor = $StageColors[[Math]::Max(0, $r.TopStage)] }
                if ($out) { $prm.Right = Txt 'defeated' 'besiegt'; $prm.Dim = $true; $prm.IconColor = $bad }
                if ($r.Race -and -not $out) {
                    $prm.Meter1 = (Txt 'race: {0} of {1} goals · {2:0} %' 'Wettlauf: {0} von {1} Zielen · {2:0} %') -f $r.Race.Met, $r.Race.Count, [Math]::Floor($r.Race.Progress * 100)
                    $prm.Value1 = $r.Race.Progress
                }
                $list.Add((New-ViewItem @prm))
            }
        }

        # Events of this game process
        Add-EventItems $list $lb $st
    }
    if ($compact) { Add-CompactSummary $list $lb $st; return , $list }

    # Achievements (also while waiting)
    $n = @($Achievements | Where-Object { $lb.Unlocked.ContainsKey($_.Id) }).Count
    if (Add-SectionHeader $list $lb 'achievements' (Txt 'ACHIEVEMENTS' 'ERFOLGE') ('{0} / {1}' -f $n, $Achievements.Count)) {
        foreach ($a in $Achievements) {
            $u = $lb.Unlocked[$a.Id]
            $desc = if ($script:UiGerman) { $a.DescDe } else { $a.DescEn }
            if ($u) {
                $when = $u.date; try { $when = ([datetime]$u.date).ToString('g', (Get-Culture2)) } catch { }
                $desc += "`n" + $(if ($u.game) { (Txt 'Unlocked {0} – {1}' 'Freigeschaltet {0} – {1}') -f $when, $u.game } else { (Txt 'Unlocked {0}' 'Freigeschaltet {0}') -f $when })
            }
            $list.Add((New-ViewItem -Kind Badge -Text (Get-AchievementName $a) -Done:([bool]$u) -Highlight:($lb.Fresh.ContainsKey($a.Id)) -Tip $desc))
        }
    }
    , $list
}

# Compact mode: one line about the game that just ended (click hides it).
function Add-CompactSummary($list, $lb, $st) {
    if (-not $lb.ShowSummary -or -not $lb.LastSummary -or $st.Phase -eq 'ended') { return }   # ended: the title says it
    $g = $lb.LastSummary
    $look = Get-ResultLook $g
    $row = New-ViewItem -Text ((Txt 'Last game: {0} · {1} · {2} res.' 'Zuletzt: {0} · {1} · {2} Einw.') -f $look.Text, (Format-GameTime (Get-SummaryClock $g)), (Format-Num ([double]$g.peakResidents))) -Dim -Tip ((Txt '{0} – click to hide' '{0} – klicken zum Ausblenden') -f (Get-SummaryName $g))
    $row.Key = 'summary:hide'
    $list.Add($row)
}

# A click on the canvas (Item.Key). Returns 'settings' (tab or folded sections changed: save them),
# 'view' (only the view changed) or '' (nothing).
function Invoke-ViewClick($lb, [string]$key) {
    if ($key -match '^tabs:(\d+)$') { $lb.Tab = $(if ([int]$Matches[1] -eq 1) { 'history' } else { 'game' }); return 'settings' }
    if ($key -match '^section:(.+)$') { $id = $Matches[1]; if ($lb.Collapsed.ContainsKey($id)) { $lb.Collapsed.Remove($id) } else { $lb.Collapsed[$id] = 1 }; return 'settings' }
    if ($key -eq 'summary:hide') { $lb.ShowSummary = $false; return 'view' }
    if ($key -match '^game:(\d+)$') {
        $g = @($lb.Games | Where-Object { $_ })[[int]$Matches[1]]
        $lb.SelectedGame = if ($g -and -not [object]::ReferenceEquals($g, $lb.SelectedGame)) { $g } else { $null }
        return 'view'
    }
    if ($key -eq 'history:live') { $lb.SelectedGame = $null; return 'view' }
    if ($key -eq 'games:more') { $lb.ShowAllGames = -not $lb.ShowAllGames; return 'view' }
    ''
}

# ---------------------------------------------------------------------------------------------
# Window.
# ---------------------------------------------------------------------------------------------
function New-LogbookForm($lb) {
    if (-not $script:DpiScale) {
        $script:DpiScale = 1.0
        try { $g0 = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:DpiScale = $g0.DpiY / 96.0; $g0.Dispose() } catch { }
    }
    $px = { param($v) [int][Math]::Round($v * $script:DpiScale) }
    $f = New-Object Windows.Forms.Form
    $f.Text = Txt 'Logbook – Anno 1602' 'Logbuch – Anno 1602'
    $f.BackColor = [AnnoLogbook.Canvas]::Back
    $f.ForeColor = [AnnoLogbook.Canvas]::Fore
    $f.Font = New-Object Drawing.Font('Segoe UI', 9)
    $f.AutoScaleMode = 'None'
    $f.StartPosition = 'Manual'
    $f.MinimumSize = New-Object Drawing.Size((& $px 300), (& $px 180))
    try {
        foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\16236', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\16236') {
            try { $d = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallDir; if ($d) { $exe = Join-Path (($d -replace '/', '\').TrimEnd('\')) 'Anno1602.exe'; if (Test-Path -LiteralPath $exe) { $f.Icon = [Drawing.Icon]::ExtractAssociatedIcon($exe) }; break } } catch { }
        }
    }
    catch { }

    $banner = New-Object Windows.Forms.Label
    $banner.Dock = 'Top'; $banner.Height = & $px 36; $banner.Visible = $false
    $banner.BackColor = [AnnoLogbook.Canvas]::Accent; $banner.ForeColor = [AnnoLogbook.Canvas]::Back
    $banner.Font = New-Object Drawing.Font('Segoe UI Semibold', 10); $banner.TextAlign = 'MiddleCenter'; $banner.AutoEllipsis = $true

    $footer = New-Object Windows.Forms.Panel
    $footer.Dock = 'Bottom'; $footer.Height = & $px 32; $footer.BackColor = [Drawing.Color]::FromArgb(21, 24, 31)
    $footer.Padding = New-Object Windows.Forms.Padding((& $px 10), 0, (& $px 4), 0)
    $status = New-Object Windows.Forms.Label
    $status.Dock = 'Fill'; $status.TextAlign = 'MiddleLeft'; $status.ForeColor = [AnnoLogbook.Canvas]::DimColor; $status.AutoEllipsis = $true
    $opts = New-Object Windows.Forms.FlowLayoutPanel
    $opts.Dock = 'Right'; $opts.AutoSize = $true; $opts.WrapContents = $false; $opts.BackColor = $footer.BackColor
    $opts.Padding = New-Object Windows.Forms.Padding(0, (& $px 6), 0, 0)
    $newCheck = {
        param($text)
        $c = New-Object Windows.Forms.CheckBox
        $c.Text = $text; $c.AutoSize = $true; $c.FlatStyle = 'Flat'; $c.ForeColor = [AnnoLogbook.Canvas]::Fore
        $c.FlatAppearance.BorderColor = [AnnoLogbook.Canvas]::Rule; $c.Margin = New-Object Windows.Forms.Padding((& $px 6), 0, 0, 0)
        $c
    }
    $cbTop = & $newCheck (Txt 'On top' 'Im Vordergrund')
    $cbCompact = & $newCheck (Txt 'Compact' 'Kompakt')
    $opts.Controls.Add($cbTop); $opts.Controls.Add($cbCompact)
    $footer.Controls.Add($status); $footer.Controls.Add($opts); $status.BringToFront()

    $scroll = New-Object Windows.Forms.Panel
    $scroll.Dock = 'Fill'; $scroll.AutoScroll = $true; $scroll.BackColor = [AnnoLogbook.Canvas]::Back
    $canvas = New-Object AnnoLogbook.Canvas
    $canvas.Location = New-Object Drawing.Point(0, 0)
    $scroll.Controls.Add($canvas)

    $f.Controls.Add($scroll); $f.Controls.Add($banner); $f.Controls.Add($footer); $scroll.BringToFront()
    @{ Form = $f; Banner = $banner; Footer = $footer; Status = $status; TopBox = $cbTop; CompactBox = $cbCompact; Scroll = $scroll; Canvas = $canvas; Px = $px }
}

function Show-ViewItems($ui, $items, [bool]$compact) {
    $w = if ($compact) { $ui.Scroll.ClientSize.Width } else { $ui.Scroll.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
    if ($w -gt 50 -and $ui.Canvas.Width -ne $w) { $ui.Canvas.Width = $w }
    $ui.Canvas.SetItems($items)
    if ($compact) {
        $wa = [Windows.Forms.Screen]::FromControl($ui.Form).WorkingArea
        $want = $ui.Canvas.Height + $ui.Footer.Height + $(if ($ui.Banner.Visible) { $ui.Banner.Height } else { 0 })
        $want = [Math]::Min($want, $wa.Height - 40)
        if ($ui.Form.ClientSize.Height -ne $want) { $ui.Form.ClientSize = New-Object Drawing.Size($ui.Form.ClientSize.Width, $want) }
    }
}

function Get-StatusText($lb, $st, [datetime]$now, [bool]$compact = $false) {
    switch ($st.Phase) {
        'waiting' { Txt 'Waiting for Anno 1602 …' 'Warte auf Anno 1602 …' }
        'version' { Txt 'Unknown game version' 'Unbekannte Spielversion' }
        'denied' { Txt 'No access to the game' 'Kein Zugriff auf das Spiel' }
        'starting' { Txt 'Game is starting …' 'Spiel startet …' }
        default { if ($compact) { (Txt 'Connected · {0}' 'Verbunden · {0}') -f $now.ToString('t', (Get-Culture2)) } else { (Txt 'Connected · PID {0} · {1}' 'Verbunden · PID {0} · {1}') -f $lb.Conn.Pid, $now.ToString('T', (Get-Culture2)) } }
    }
}

function Show-Unlocks($ui, $unlocks) {
    if (-not $unlocks -or $unlocks.Count -eq 0) { return }
    $names = @(foreach ($u in $unlocks) { $a = $Achievements | Where-Object { $_.Id -eq $u.id }; if ($a) { Get-AchievementName $a } else { $u.id } })
    $star = [string][char]0x2605
    $text = if ($names.Count -eq 1) { '{0} {1}: {2}' -f $star, (Txt 'Achievement unlocked' 'Erfolg freigeschaltet'), $names[0] } else { '{0} {1}: {2}' -f $star, ((Txt '{0} achievements unlocked' '{0} Erfolge freigeschaltet') -f $names.Count), ($names -join ', ') }
    Set-BannerText $ui $text ([AnnoLogbook.Canvas]::Accent)
}

# Banner text and colour; the banner grows to show up to three lines (several unlocks at once).
function Set-BannerText($ui, [string]$text, $back) {
    $b = $ui.Banner
    $b.Text = $text
    $b.BackColor = $back; $b.ForeColor = [AnnoLogbook.Canvas]::Back
    $scale = if ($script:DpiScale) { $script:DpiScale } else { 1.0 }
    $w = [Math]::Max(100, $(if ($b.Parent) { $b.Parent.ClientSize.Width } else { $b.Width }) - [int](16 * $scale))
    $need = [Windows.Forms.TextRenderer]::MeasureText($text, $b.Font, (New-Object Drawing.Size($w, 1000)), [Windows.Forms.TextFormatFlags]::WordBreak).Height + [int](14 * $scale)
    $b.Height = [Math]::Max([int](36 * $scale), [Math]::Min([int](76 * $scale), $need))
    $b.Visible = $true
}

# Banner for new events (blue): the newest one with its effect, plus how many more came at once.
function Get-EventBannerText($events) {
    $evs = @($events)
    if (-not $evs.Count) { return '' }
    $e = $evs[$evs.Count - 1]
    $title = Get-LangText $e.Title; if (-not $title) { $title = $e.Id }
    $text = '{0} {1}: {2}' -f [string][char]0x2726, (Txt 'Event' 'Ereignis'), $title
    $effect = Get-LangText $e.Effect
    if ($effect) { $text += ' – ' + $effect }
    if ($evs.Count -gt 1) { $text += ' ' + ((Txt '(+{0} more)' '(+{0} weitere)') -f ($evs.Count - 1)) }
    $text
}
function Show-EventBanner($ui, $events) {
    if (-not @($events).Count) { return }
    Set-BannerText $ui (Get-EventBannerText $events) $EventColor
}

# ---------------------------------------------------------------------------------------------
# Self-test: memory images built from the documented layouts.
# ---------------------------------------------------------------------------------------------
function Set-ImgI32($img, [long]$rva, [long]$v) { $img.Write($rva, [BitConverter]::GetBytes([int]$v)) }
function Set-ImgU32($img, [long]$rva, [long]$v) { $img.Write($rva, [BitConverter]::GetBytes([uint32]$v)) }
function Set-ImgU16($img, [long]$rva, [int]$v) { $img.Write($rva, [BitConverter]::GetBytes([uint16]$v)) }
function Set-ImgByte($img, [long]$rva, [int]$v) { $img.Write($rva, [byte[]]@([byte]$v)) }
function Set-ImgText($img, [long]$rva, [string]$s, [int]$max) {
    $b = New-Object byte[] $max; $t = $Enc1252.GetBytes($s)
    [Array]::Copy($t, $b, [Math]::Min($t.Length, $max - 1)); $img.Write($rva, $b)
}

function Set-TestPlayer($img, [int]$slot, [int]$kind, [long]$gold, [string]$name = '', [int]$missionSlot = 0xFF) {
    $o = $RvaPlayers + $slot * $PlayerSize
    Set-ImgI32 $img $o $kind; Set-ImgI32 $img ($o + 4) $gold; Set-ImgText $img ($o + 8) $name 0x40
    Set-ImgByte $img ($o + 0x68) $slot; Set-ImgByte $img ($o + 0x7C) $missionSlot; Set-ImgByte $img ($o + 0x81) 7
}

function Add-TestTown($img, [int]$index, [string]$name, [int]$island, [int]$owner, [long[]]$stages, [long]$workers = 0, $goods = @{}, [int[]]$taxRates = @(128, 128, 128, 128, 128), [long]$costs = 0, [long]$milCosts = 0) {
    $o = $RvaSettlements + $index * $SettlementSize
    $b = New-Object byte[] $SettlementSize
    $t = $Enc1252.GetBytes($name); [Array]::Copy($t, $b, [Math]::Min($t.Length, 0x17))
    $b[0x18] = [byte]$island; $b[0x1A] = [byte]$owner
    foreach ($g in $goods.Keys) { [Array]::Copy([BitConverter]::GetBytes([uint16]($goods[$g] * 32)), 0, $b, 0x2A + 12 * $g, 2) }
    [Array]::Copy([BitConverter]::GetBytes([int]$costs), 0, $b, 0x1D8, 4); [Array]::Copy([BitConverter]::GetBytes([int]$milCosts), 0, $b, 0x1DC, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]$workers), 0, $b, 0x218, 4)
    for ($k = 0; $k -lt 5; $k++) { [Array]::Copy([BitConverter]::GetBytes([int]$stages[$k]), 0, $b, 0x220 + 4 * $k, 4); $b[0x24D + $k] = [byte]$taxRates[$k] }
    $img.Write($o, $b)
}

function Set-TestMission($img, [int]$slot, [long]$bits, $towns = @(), [int]$residents = 0, [int]$townCount = 0, [int]$balance = 0, [int]$trade = 0, $goods = @(), $mono = @(), [int[]]$mustDefeat = @(), [int]$defeatCount = 0, [string]$text = '') {
    $o = $RvaMissions + $slot * $MissionSize
    $b = New-Object byte[] $MissionSize
    [Array]::Copy([BitConverter]::GetBytes([uint32]$bits), 0, $b, 0, 4)
    $b[8] = 7; $b[9] = [byte]$defeatCount
    foreach ($i in $mustDefeat) { $b[0x0A + $i] = 1 }
    for ($j = 0; $j -lt $mono.Count; $j++) { $b[0x11 + 2 * $j] = [byte]$mono[$j][0]; $b[0x12 + 2 * $j] = [byte]$mono[$j][1] }
    [Array]::Copy([BitConverter]::GetBytes([int]$townCount), 0, $b, 0x1C, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]$residents), 0, $b, 0x28, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]$balance), 0, $b, 0x30, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]$trade), 0, $b, 0x34, 4)
    $t = $Enc1252.GetBytes($text); [Array]::Copy($t, 0, $b, 0x83C, [Math]::Min($t.Length, 0x7FF))
    for ($j = 0; $j -lt $goods.Count; $j++) { $b[0x103C + 4 * $j] = [byte]$goods[$j][0]; [Array]::Copy([BitConverter]::GetBytes([uint16]($goods[$j][1] * 32)), 0, $b, 0x103E + 4 * $j, 2) }
    for ($k = 0; $k -lt $towns.Count; $k++) { for ($q = 0; $q -lt 3; $q++) { [Array]::Copy([BitConverter]::GetBytes([int]$towns[$k][$q]), 0, $b, 0x1044 + 12 * $k + 4 * $q, 4) } }
    $img.Write($o, $b)
}

# A running game: human in slot 0 with three towns, three computer rivals, traders, pirates, natives.
function New-TestImage([string]$variant = 'race') {
    $img = New-Object AnnoLogbook.ImageSource
    $free = New-Object byte[] ($SettlementSize * 75); for ($i = 0; $i -lt 75; $i++) { $free[$i * $SettlementSize + 0x18] = 0xFF }
    $img.Write($RvaSettlements, $free)
    Set-ImgI32 $img $RvaSpeed 4
    Set-ImgI32 $img ($RvaTimers + 0x190) 265000         # game clock (8.1 h)
    Set-ImgI32 $img ($RvaTimers + 0x258) 2              # difficulty
    for ($k = 0; $k -lt 5; $k++) { Set-ImgI32 $img ($RvaPopulation + $k * 0x50) ((2, 6, 15, 25, 40)[$k] * 64); Set-ImgI32 $img ($RvaPopulation + $k * 0x50 + 4) ((1, 2, 3, 4, 5)[$k]) }
    $slotM = if ($variant -eq 'endless') { 0xFF } else { 0 }
    Set-TestPlayer $img 0 0 45210 'Kapitänin Ada' $slotM
    Set-TestPlayer $img 1 0xC 7408 '' $(if ($variant -eq 'race') { 0 } else { 0xFF })
    Set-TestPlayer $img 2 0xC 16812 '' $(if ($variant -eq 'race') { 0 } else { 0xFF })
    Set-TestPlayer $img 3 0xC 4291 '' $(if ($variant -eq 'race') { 0 } else { 0xFF })
    Set-TestPlayer $img 4 0xD 1000000 'Trader4'; Set-TestPlayer $img 5 0xE 50000 'Pirat5'; Set-TestPlayer $img 6 0xB 5000 'Native6'
    Set-ImgU32 $img ($RvaPlayers + 0x78) (480 * 905); Set-ImgU32 $img ($RvaPlayers + 0x74) (480 * 780)   # sales / purchases -> trade +125
    # Human towns (table order matters), rivals' towns, a native village.
    Add-TestTown $img 0 'Zaustaden' 3 0 @(40, 180, 320, 150, 0) 120 @{ 22 = 35; 21 = 20; 20 = 45 } -costs 260
    Add-TestTown $img 1 'Barlin' 7 1 @(0, 0, 150, 125, 1120) 214
    Add-TestTown $img 2 'Neu-Brandt' 11 0 @(60, 95, 0, 0, 0) 30 @{ 21 = 12; 20 = 30 } -costs 70
    Add-TestTown $img 3 'Kalmar' 15 2 @(0, 18, 285, 498, 0) 195
    Add-TestTown $img 4 'Argenhall' 19 6 @(80, 0, 0, 0, 0) 0
    Add-TestTown $img 5 'Ostwacht' 21 3 @(0, 84, 270, 138, 0) 168
    Add-TestTown $img 6 'Fischerhude' 23 0 @(35, 0, 0, 0, 0) 0 -costs 15
    Add-TestTown $img 7 'Südhafen' 25 1 @(0, 144, 0, 0, 0) 111
    # Ships: human 4, rivals 2/3/1, traders 3.
    $owners = @(0, 0, 0, 0, 1, 1, 2, 2, 2, 3, 4, 4, 4)
    for ($i = 0; $i -lt $owners.Count; $i++) { Set-ImgByte $img ($RvaShips + $i * $ShipSize) 0x50; Set-ImgByte $img ($RvaShips + $i * $ShipSize + 0x28) $owners[$i] }
    switch ($variant) {
        'race' {
            Set-ImgText $img ($RvaScenario + 0x13) 'Wettlauf 2 - Buergerstolz' 0x40; Set-ImgByte $img ($RvaScenario + 0x12) 2
            Set-TestMission $img 0 0x803 -towns @(@(700, 2, 350), @(200, 1, 100)) -text "WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz`r`n`r`nDas Handelsprivileg war nur der Anfang."
        }
        'trade' {
            Set-ImgText $img ($RvaScenario + 0x13) 'Herausforderung - Handelsimperium' 0x40; Set-ImgByte $img ($RvaScenario + 0x12) 2
            Set-TestMission $img 0 0x13000 -trade 300 -goods @(@(21, 50), @(20, 80)) -text "HERAUSFORDERUNG - Handelsimperium`r`n`r`nSchmuck und Kleider für die Krone."
        }
    }
    $img
}

# Test events file (interface of anno-patcher.ps1 -Events).
function New-TestEvent([int]$procId, [datetime]$time, [long]$clock, [string]$id, [string]$de, [string]$en, [string]$effDe, [string]$effEn, [long]$ends = 0) {
    [ordered]@{ time = $time.ToString('s'); pid = $procId; clock = $clock; id = $id; title = [ordered]@{ de = $de; en = $en }
        text = [ordered]@{ de = "$de – Text"; en = "$en – text" }; effect = [ordered]@{ de = $effDe; en = $effEn }; endsClock = $ends }
}
function Write-TestEvents($events) {
    Write-TextFileAtomic (Get-EventsFile) (ConvertTo-Json ([ordered]@{ version = 1; events = @($events) }) -Depth 5)
}

# A made-up game history (smooth curves) for the PNG files of the History tab.
function New-DemoHistory($lb, [datetime]$start, [int]$points, [string]$scenario, [string]$kind) {
    $s = @{
        Id = $start.ToString('yyyyMMdd-HHmmss'); File = ''; Start = $start; Pid = 4711; Scenario = $scenario; Game = $scenario; Kind = $kind; HasMission = $kind -ne 'endless'
        FirstClock = 5000L; LastClock = 0L; Interval = $SampleClocks; Samples = (New-Object 'System.Collections.Generic.List[long[]]'); Unsaved = 0; Prev = $null; Readings = $points
        PeakResidents = 0L; PeakGold = [long]::MinValue; PeakTowns = 0L; TopStage = -1; NegGold = $false; Reloads = 0; EventCount = 2
        Achievements = (New-Object Collections.ArrayList); Done = $false; Result = ''; End = $null
    }
    for ($i = 0; $i -lt $points; $i++) {
        $t = $i / [double]$points
        $total = 2600 / (1 + [Math]::Exp(-9 * ($t - 0.45)))
        $st = @((0.30 - 0.18 * $t), (0.36 - 0.12 * $t), (0.22 + 0.06 * $t), [Math]::Max(0, 0.06 + 0.16 * ($t - 0.3)), [Math]::Max(0, 0.08 * ($t - 0.6)))
        $stages = @($st | ForEach-Object { [long]($total * $_) })
        $workers = [long]($total * 0.12)
        $gold = [long](30000 + 18000 * [Math]::Sin($t * 9) * (1 - $t) + 95000 * $t * $t - 12000 * [Math]::Exp(-30 * [Math]::Pow($t - 0.2, 2)))
        $bal = [long](-180 + 760 * $t + 90 * [Math]::Sin($t * 23))
        $vals = [long[]]@((5000 + $SampleClocks * $i), $gold, ($workers + ($stages | Measure-Object -Sum).Sum), $stages[0], $stages[1], $stages[2], $stages[3], $stages[4], $workers, $bal, (1 + [Math]::Floor($t * 4.6)), (1 + [Math]::Floor($t * 7.5)))
        [void](Add-SessionSample $s $vals)
        $s.LastClock = $vals[0]
        if ($vals[2] -gt $s.PeakResidents) { $s.PeakResidents = $vals[2] }; if ($gold -gt $s.PeakGold) { $s.PeakGold = $gold }; if ($vals[10] -gt $s.PeakTowns) { $s.PeakTowns = $vals[10] }
    }
    $s.TopStage = 4
    $s
}

# Made-up played games for the list (names as the scenario files are called in the UI language).
function New-DemoGames {
    $de = $script:UiGerman
    $rows = @(
        @(@('Sturmsee 1 - Schiffbruch', 'Storm Sea 1 - Shipwreck'), 'campaign', 'won', 3.4, 1240, 28000, 2, 2),
        @(@('Endlosspiel', 'Endless game'), 'endless', 'quit', 14.2, 6800, 310000, 6, 4),
        @(@('Sturmsee 2 - Tabak und Kakao', 'Storm Sea 2 - Tobacco and Cocoa'), 'campaign', 'lost', 5.0, 1810, 9000, 3, 3),
        @(@('Sturmsee 2 - Tabak und Kakao', 'Storm Sea 2 - Tobacco and Cocoa'), 'campaign', 'won', 6.1, 2390, 41000, 3, 3),
        @(@('Herausforderung - Goldrausch', 'Challenge - Gold Rush'), 'challenge', 'won', 2.7, 960, 128000, 2, 2),
        @(@('Abenteuer 4711 Fordernd', 'Adventure 4711 Demanding'), 'adventure', 'lost', 7.9, 2110, 18500, 3, 3),
        @(@('Tagesabenteuer 2026-11-13', 'Daily Adventure 2026-11-13'), 'daily', 'won', 4.2, 1530, 52000, 2, 3),
        @(@('Eigenes - Piratenbucht', 'Custom - Pirate Bay'), 'custom', 'quit', 1.6, 410, 22000, 1, 1),
        @(@('Wettlauf 1 - Erster Hafen', 'Race 1 - First Harbour'), 'campaign', 'won', 3.0, 1120, 35000, 2, 2),
        @(@('Wettlauf 2 - Buergerstolz', 'Race 2 - Civic Pride'), 'campaign', 'lost', 5.1, 1490, 26000, 3, 2),
        @(@('Endlosspiel', 'Endless game'), 'endless', 'quit', 22.5, 9100, 640000, 8, 4),
        @(@('Sturmsee 3 - Der Freihafen', 'Storm Sea 3 - The Free Port'), 'campaign', 'won', 8.3, 3350, 87000, 4, 4))
    $list = New-Object Collections.ArrayList
    $day = [datetime]'2026-11-02T19:30:00'
    foreach ($r in $rows) {
        $name = if ($de) { $r[0][0] } else { $r[0][1] }
        [void]$list.Add([ordered]@{
                date = $day.AddHours($r[3] / 4 + 1).ToString('s'); start = $day.ToString('s'); scenario = $(if ($r[1] -eq 'endless') { '' } else { $name }); game = $name; kind = $r[1]
                mission = $r[1] -ne 'endless'; result = $r[2]; gameHours = $r[3]; playedHours = $r[3]; startClock = 0; endClock = [long]($r[3] * $ClockPerHour)
                peakResidents = $r[4]; peakGold = $r[5]; towns = $r[6]; peakTowns = $r[6]; topStage = $r[7]; events = 0; reloads = 0; achievements = @(); history = ''
            })
        $day = $day.AddDays(1)
    }
    $list
}

function Invoke-SelfTest {
    $script:failed = 0; $script:checks = 0
    $check = {
        param([string]$what, [bool]$ok)
        $script:checks++
        if ($ok) { Write-Host "  OK     $what" -ForegroundColor Green } else { Write-Host "  FAILED $what" -ForegroundColor Red; $script:failed++ }
    }
    $folder = if ($SelfTestFolder) { $SelfTestFolder } else { Join-Path ([IO.Path]::GetTempPath()) 'anno-logbook-selftest' }
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $script:AppDataFolder = Join-Path $folder 'appdata'
    if (Test-Path -LiteralPath $script:AppDataFolder) { Remove-Item -LiteralPath $script:AppDataFolder -Recurse -Force }
    $script:DocumentsFolder = Join-Path $folder 'documents'   # chapters per campaign: never the player's own scenarios
    if (Test-Path -LiteralPath $script:DocumentsFolder) { Remove-Item -LiteralPath $script:DocumentsFolder -Recurse -Force }
    $langBefore = $script:UiGerman
    $script:UiGerman = $false

    Write-Host 'Snapshot'
    $img = New-TestImage 'race'
    $s = Get-LogbookSnapshot $img
    & $check 'snapshot read' ($null -ne $s)
    & $check "clock 265000 ($($s.Clock)), speed 4 ($($s.Speed)), lock 0" ($s.Clock -eq 265000 -and $s.Speed -eq 4 -and $s.Lock -eq 0)
    & $check "human gold 45210, kind 0, name ($($s.Players[0].Name))" ($s.Players[0].Gold -eq 45210 -and $s.Players[0].Kind -eq 0 -and $s.Players[0].Name -eq 'Kapitänin Ada')
    & $check "kinds 0/12/12/12/13/14/11 ($(($s.Players | ForEach-Object { $_.Kind }) -join '/'))" ((($s.Players | ForEach-Object { $_.Kind }) -join '/') -eq '0/12/12/12/13/14/11')
    & $check "8 settlements in use ($($s.Settlements.Count)), free slots skipped" ($s.Settlements.Count -eq 8)
    $z = $s.Settlements[0]
    & $check "Zaustaden: total 810 = workers 120 + 690 ($($z.Total)), of which citizens+ 470 ($($z.Cum[2]))" ($z.Total -eq 810 -and $z.Cum[2] -eq 470 -and $z.Owner -eq 0 -and $z.Island -eq 3)
    & $check "ships per owner 4/2/3/1 ($($s.ShipsByOwner[0])/$($s.ShipsByOwner[1])/$($s.ShipsByOwner[2])/$($s.ShipsByOwner[3]))" ($s.ShipsByOwner[0] -eq 4 -and $s.ShipsByOwner[1] -eq 2 -and $s.ShipsByOwner[2] -eq 3 -and $s.ShipsByOwner[3] -eq 1)
    & $check "scenario name and own-scenario flag ($($s.ScenarioName))" ($s.ScenarioName -eq 'Wettlauf 2 - Buergerstolz' -and $s.ScenarioCustom)
    & $check "mission bits 0x803, town 1 700/2/350, town 2 200/1/100" ($s.Missions[0].Bits -eq 0x803 -and $s.Missions[0].Town[0].Total -eq 700 -and $s.Missions[0].Town[0].Level -eq 2 -and $s.Missions[0].Town[1].OfWhich -eq 100)
    & $check "mission title ($(Get-MissionTitle $s.Missions[0]))" ((Get-MissionTitle $s.Missions[0]) -eq 'WETTLAUF DER HÄUSER - Kapitel 2: Bürgerstolz')
    & $check 'islands not read without a monopoly goal' ($null -eq $s.Islands)
    $zero = Get-LogbookSnapshot (New-Object AnnoLogbook.ImageSource)
    & $check "all-zero image (before the first game): no settlement counted ($($zero.Settlements.Count))" ($zero.Settlements.Count -eq 0)
    $me = Get-PlayerStats $s 0
    & $check "human stats: 3 towns, 1030 residents, best Zaustaden, 4 ships ($($me.TownCount)/$($me.Total)/$($me.Best.Name)/$($me.Ships))" ($me.TownCount -eq 3 -and $me.Total -eq 1030 -and $me.Best.Name -eq 'Zaustaden' -and $me.Ships -eq 4)

    Write-Host 'Mission check (mirror of FUN_1400ae010)'
    $ev = Get-MissionEvaluation $s 0
    & $check "race mission: town 1 met by Zaustaden (810, 470 citizens+)" ($ev.Goals[0].Done -and $ev.Goals[0].Sub -match 'Zaustaden')
    & $check "town 2 (200, 100 settlers+): Neu-Brandt has 185 -> not met, Fischerhude not either" (-not $ev.Goals[1].Done -and $ev.Goals[1].Sub -match 'Neu-Brandt')
    & $check "not fulfilled, 1 of 2 met ($($ev.Met)/$($ev.Count))" (-not $ev.Fulfilled -and $ev.Met -eq 1 -and $ev.Count -eq 2)
    Add-TestTown $img 2 'Neu-Brandt' 11 0 @(60, 115, 0, 0, 0) 30 @{ 21 = 12; 20 = 30 } -costs 70
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $img) 0
    & $check "Neu-Brandt grows to 205 (115 settlers+) -> both towns met, fulfilled" ($ev.Goals[1].Done -and $ev.Fulfilled)
    $r1 = Get-MissionEvaluation (Get-LogbookSnapshot $img) 1
    & $check "race: rival 1 checked too (Barlin 1609 -> town 1; Südhafen 255, 144 settlers+ -> town 2), fulfilled" ($r1 -and $r1.Fulfilled)
    $r3 = Get-MissionEvaluation (Get-LogbookSnapshot $img) 3
    & $check "race: rival 3 has only one town -> town 2 not met" ($r3 -and -not $r3.Fulfilled -and $r3.Met -eq 1)
    # One settlement counts for one town goal only: a single big town does not meet two goals.
    $img2 = New-TestImage 'race'
    Add-TestTown $img2 2 'Neu-Brandt' 11 5 @(60, 95, 0, 0, 0) 30; Add-TestTown $img2 6 'Fischerhude' 23 5 @(35, 0, 0, 0, 0) 0
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $img2) 0
    & $check 'one big town cannot meet town 1 and town 2 at once' ($ev.Goals[0].Done -and -not $ev.Goals[1].Done -and -not $ev.Fulfilled)
    # "of which" counts the stage and all higher stages: 0 citizens but 400 merchants meets 350 citizens+.
    Add-TestTown $img2 0 'Zaustaden' 3 0 @(100, 120, 0, 400, 0) 100
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $img2) 0
    & $check 'of which: merchants count for "citizens or higher"' ($ev.Goals[0].Done)
    # Without the race bit computer players are not checked.
    $img3 = New-TestImage 'race'; Set-TestMission $img3 0 0x3 -towns @(@(700, 2, 350), @(200, 1, 100))
    & $check 'no race bit: rival not checked' ($null -eq (Get-MissionEvaluation (Get-LogbookSnapshot $img3) 1))
    & $check 'endless game (mission slot 0xFF): no mission' ($null -eq (Get-MissionEvaluation (Get-LogbookSnapshot (New-TestImage 'endless')) 0))

    Write-Host 'Balance, trade, goods'
    $t = New-TestImage 'trade'; $s = Get-LogbookSnapshot $t
    # Taxes (FUN_1400bbdc0), rates 128: Zaustaden 40*1*6/32=7, 180*2*6/32=67, 320*3*6/32=180, 150*4*6/32=112 -> 366;
    # Neu-Brandt 60*6/32=11, 95*2*6/32=35 -> 46; Fischerhude 35*6/32=6 -> 418. Costs 260+70+15 = 345. Trade 905-780 = 125.
    $mo = Get-Balance $s 0
    & $check "taxes 418 ($($mo.Taxes)), costs 345 ($($mo.Costs)), trade +125 ($($mo.Trade)), balance 198 ($($mo.Balance))" ($mo.Taxes -eq 418 -and $mo.Costs -eq 345 -and $mo.Trade -eq 125 -and $mo.Balance -eq 198)
    Add-TestTown $t 0 'Zaustaden' 3 0 @(40, 180, 320, 150, 0) 120 @{ 22 = 35; 21 = 20; 20 = 45 } -taxRates @(64, 64, 64, 64, 64) -costs 260 -milCosts 40
    Set-ImgU16 $t ($RvaPlayers + 0xA4) 3; Set-ImgI32 $t $RvaUnitCosts 10; Set-ImgU16 $t ($RvaPlayers + 0xAE) 2; Set-ImgI32 $t ($RvaUnitCosts + 0x250) 7
    $mo = Get-Balance (Get-LogbookSnapshot $t) 0
    # Half tax rate: (7*64/128=3) + (67*64/128=33) + (180/2=90) + (112/2=56) = 182 + 46 + 6 = 234; costs 345 + 40 (human: +0x1DC); military 3*10 + 2*7 = 44.
    & $check "half tax rate 234 ($($mo.Taxes)), costs incl. military buildings 385 ($($mo.Costs)), units 44 ($($mo.Military)), balance -70 ($($mo.Balance))" ($mo.Taxes -eq 234 -and $mo.Costs -eq 385 -and $mo.Military -eq 44 -and $mo.Balance -eq -70)
    $ev = Get-MissionEvaluation $s 0
    & $check "goods: jewellery 32 t of 50 (own towns only, $([Math]::Floor($ev.Goals[0].Meters[0].Value * 50)) t), clothes 75 t of 80 -> not met" (-not $ev.Goals[0].Done -and -not $ev.Goals[1].Done -and $ev.Goals[0].Title -match 'jewellery')
    & $check 'trade balance +125 < +300 -> not met' (-not $ev.Goals[2].Done)
    Add-TestTown $t 6 'Fischerhude' 23 0 @(35, 0, 0, 0, 0) 0 @{ 21 = 18; 20 = 5 } -costs 15
    Add-TestTown $t 1 'Barlin' 7 1 @(0, 0, 150, 125, 1120) 214 @{ 21 = 99 }
    Set-ImgU32 $t ($RvaPlayers + 0x78) (480 * 1100)
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $t) 0
    & $check "50 t jewellery, 80 t clothes, trade +320 -> fulfilled ($($ev.Met)/$($ev.Count))" ($ev.Fulfilled -and $ev.Met -eq 3)
    Set-TestMission $t 0 0x13100 -trade 300 -balance 500 -goods @(@(21, 50), @(20, 80))
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $t) 0
    & $check "balance goal +500 with a balance of $($ev.Money.Balance): everything else met, still not fulfilled" (-not $ev.Fulfilled -and $ev.Met -eq 3 -and -not ($ev.Goals | Where-Object { $_.Id -eq 'balance' }).Done)

    Write-Host 'Monopoly, towns, residents, defeat'
    $mimg = New-TestImage 'endless'
    Set-TestPlayer $mimg 0 0 45210 'Kapitänin Ada' 1
    Set-TestMission $mimg 1 (0x4000 -bor 0x8000 -bor 0x20 -bor 0x80) -townCount 3 -residents 1200 -mono @(@(0x2F, 2), @(3, 1))
    $isl = New-Object byte[] ($IslandSize * 50)
    foreach ($n in 3, 11, 15) { [Array]::Copy([BitConverter]::GetBytes([uint32](1 -shl (0x2F - 0x2D))), 0, $isl, $n * $IslandSize + 0x5C, 4) }   # spices on islands 3, 11, 15
    $isl[23 * $IslandSize + 0x41] = 1; $isl[23 * $IslandSize + 0x20] = 3; [Array]::Copy([BitConverter]::GetBytes([uint16]0x40), 0, $isl, 23 * $IslandSize + 0x26, 2)   # gold deposit on island 23
    $mimg.Write($RvaIslands, $isl)
    $s = Get-LogbookSnapshot $mimg
    & $check 'islands read for a monopoly goal' ($null -ne $s.Islands)
    $ev = Get-MissionEvaluation $s 0
    $g = @{}; foreach ($x in $ev.Goals) { $g[$x.Id] = $x }
    & $check 'spice monopoly blocked: rival 2 (Kalmar) settles on spice island 15' (-not $g.mono0.Done -and $g.mono0.Sub -match 'Rival 2')
    & $check 'gold deposit (island 23, Fischerhude): monopoly 2 met' ($g.mono1.Done)
    & $check "3 towns met, 1200 residents not (1030)" ($g.towns.Done -and -not $g.residents.Done)
    Add-TestTown $mimg 3 'Kalmar' 16 2 @(0, 18, 285, 498, 0) 195
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $mimg) 0; $g = @{}; foreach ($x in $ev.Goals) { $g[$x.Id] = $x }
    & $check 'Kalmar on an island without spices: spice monopoly met (2 own spice islands)' ($g.mono0.Done)
    Add-TestTown $mimg 4 'Argenhall' 15 6 @(80, 0, 0, 0, 0) 0
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $mimg) 0; $g = @{}; foreach ($x in $ev.Goals) { $g[$x.Id] = $x }
    & $check 'a native village on a spice island does not block the monopoly' ($g.mono0.Done)
    $dimg = New-TestImage 'endless'
    Set-TestPlayer $dimg 0 0 45210 'Kapitänin Ada' 2
    Set-TestMission $dimg 2 0x400 -mustDefeat @(1, 2, 3)
    Set-ImgI32 $dimg ($RvaPlayers + 1 * $PlayerSize) 9; Set-ImgI32 $dimg ($RvaPlayers + 2 * $PlayerSize) 9
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $dimg) 0
    & $check "defeat 1-3: two of three out -> not met ($($ev.Goals[0].Meters[0].Label))" (-not $ev.Fulfilled -and $ev.Goals[0].Sub -match 'Rival 3')
    Set-ImgI32 $dimg ($RvaPlayers + 3 * $PlayerSize) 9
    & $check 'all three defeated -> fulfilled' ((Get-MissionEvaluation (Get-LogbookSnapshot $dimg) 0).Fulfilled)

    Write-Host 'Game end, logbook.json, achievements'
    $lb = New-LogbookState
    $lb.Conn.Status = 'attached'
    $img = New-TestImage 'race'
    $t0 = [datetime]'2026-11-12T10:00:00'
    $st = Update-GameState $lb (Get-LogbookSnapshot $img) $t0
    & $check "phase running, no unlock in the first reading ($($st.Phase), $($st.NewUnlocks.Count))" ($st.Phase -eq 'running' -and $st.NewUnlocks.Count -eq 0)
    Set-ImgI32 $img ($RvaTimers + 0x190) 265030
    $st = Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(3)
    $ids = (@($st.NewUnlocks | ForEach-Object { $_.id }) | Sort-Object) -join ','
    & $check "second reading unlocks citizens, first_town, merchants, res_1000, settlers, towns_3 ($ids)" ($ids -eq 'citizens,first_town,merchants,res_1000,settlers,towns_3')
    $d = Read-LogbookData
    & $check "logbook.json: 6 achievements with date and game ($($d.achievements[0].game), $($d.achievements[0].date))" ($d.achievements.Count -eq 6 -and $d.achievements[0].game -eq 'Wettlauf 2 - Buergerstolz' -and $d.achievements[0].date -eq '2026-11-12T10:00:03')
    $st = Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(6)
    & $check "same clock: paused, nothing new ($($st.Paused), $($st.NewUnlocks.Count))" ($st.Paused -and $st.NewUnlocks.Count -eq 0)
    # The human wins: player +0x84 = 1, all players kind 9, lock 1.
    Set-ImgByte $img ($RvaPlayers + 0x84) 1; Set-ImgI32 $img $RvaTimers 1
    foreach ($i in 0..3) { Set-ImgI32 $img ($RvaPlayers + $i * $PlayerSize) 9 }
    Set-ImgI32 $img ($RvaTimers + 0x190) 166644
    $st = Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(9)
    $d = Read-LogbookData
    $mi = $d.missions[0]
    & $check "won: mission recorded ($($mi.scenario) / $($mi.result) / $($mi.gameHours) h / $($mi.title))" ($st.Phase -eq 'ended' -and $d.missions.Count -eq 1 -and $mi.scenario -eq 'Wettlauf 2 - Buergerstolz' -and $mi.result -eq 'won' -and $mi.gameHours -eq 5.1 -and $mi.title -match 'Kapitel 2')
    & $check "won a race: mission_won and race_won unlocked ($((@($st.NewUnlocks | ForEach-Object { $_.id })) -join ','))" ($lb.Unlocked.ContainsKey('mission_won') -and $lb.Unlocked.ContainsKey('race_won'))
    [void](Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(12))
    & $check 'the same end is recorded only once' ((Read-LogbookData).missions.Count -eq 1)
    # A lost race: new game running, then the rival wins (human +0x84 stays 0).
    $img = New-TestImage 'race'
    [void](Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(20))
    Set-ImgI32 $img $RvaTimers 1; foreach ($i in 0..3) { Set-ImgI32 $img ($RvaPlayers + $i * $PlayerSize) 9 }; Set-ImgByte $img ($RvaPlayers + 1 * $PlayerSize + 0x84) 1
    $st = Update-GameState $lb (Get-LogbookSnapshot $img) $t0.AddSeconds(23)
    $d = Read-LogbookData
    & $check "lost: second entry result lost ($($d.missions[1].result))" ($d.missions.Count -eq 2 -and $d.missions[1].result -eq 'lost' -and $st.Result -eq 'lost')
    # Started while the score screen is shown: nothing recorded.
    $lb2 = New-LogbookState; $lb2.Conn.Status = 'attached'
    [void](Update-GameState $lb2 (Get-LogbookSnapshot $img) $t0.AddSeconds(30))
    & $check 'logbook started after the end: nothing recorded' ((Read-LogbookData).missions.Count -eq 2)
    # Endless game end: no mission entry.
    $img = New-TestImage 'endless'
    [void](Update-GameState $lb2 (Get-LogbookSnapshot $img) $t0.AddSeconds(40))
    Set-ImgI32 $img ($RvaPlayers) 9; Set-ImgI32 $img $RvaTimers 1
    [void](Update-GameState $lb2 (Get-LogbookSnapshot $img) $t0.AddSeconds(43))
    & $check 'endless game over: no mission entry' ((Read-LogbookData).missions.Count -eq 2)
    # No game yet (clock 0): no achievements.
    $lb3 = New-LogbookState; $lb3.Conn.Status = 'attached'; $lb3.Unlocked = @{}
    $img = New-TestImage 'race'; Set-ImgI32 $img ($RvaTimers + 0x190) 0
    $st1 = Update-GameState $lb3 (Get-LogbookSnapshot $img) $t0; $st2 = Update-GameState $lb3 (Get-LogbookSnapshot $img) $t0
    & $check "clock 0: phase nogame, no unlocks ($($st2.Phase))" ($st2.Phase -eq 'nogame' -and $st2.NewUnlocks.Count -eq 0)
    # Settings survive, a broken file is kept aside.
    Save-LogbookSettings @{ compact = $true; alwaysOnTop = $true; left = 10 }
    $d = Read-LogbookData
    & $check "settings stored next to the achievements ($($d.settings.compact), $($d.achievements.Count) achievements)" ($d.settings.compact -eq $true -and $d.achievements.Count -ge 7)
    [IO.File]::WriteAllText((Get-LogbookFile), '{ broken')
    $d = Read-LogbookData
    & $check 'broken logbook.json: kept as logbook.broken-*.json, fresh start' ($d.achievements.Count -eq 0 -and @(Get-ChildItem -LiteralPath (Split-Path (Get-LogbookFile)) -Filter 'logbook.broken-*.json').Count -eq 1)
    & $check "game time 32,700 = 1 h 00 min ($(Format-GameTime 32700)), 265,000 = 8 h 06 min ($(Format-GameTime 265000))" ((Format-GameTime 32700) -eq '1 h 00 min' -and (Format-GameTime 265000) -eq '8 h 06 min')
    $nimg = New-TestImage 'race'; Set-ImgText $nimg ($RvaPlayers + 1 * $PlayerSize + 8) 'Computer' 0x40; Set-ImgText $nimg ($RvaPlayers + 2 * $PlayerSize + 8) 'Computer' 0x40; Set-ImgText $nimg ($RvaPlayers + 3 * $PlayerSize + 8) 'Hanse' 0x40
    $ns = Get-LogbookSnapshot $nimg
    $names = (1..3 | ForEach-Object { Get-PlayerName $ns $_ }) -join ' / '
    & $check "player names: same default name gets the slot number ($names)" ($names -eq 'Computer (1) / Computer (2) / Hanse')
    $fake = @{ Banner = New-Object Windows.Forms.Label }
    Show-Unlocks $fake @(@{ id = 'ships_5' })
    $one = $fake.Banner.Text
    Show-Unlocks $fake @(@{ id = 'ships_5' }, @{ id = 'citizens' })
    & $check "banner: one unlock '$one', two unlocks '$($fake.Banner.Text)'" ($one -match 'Small Fleet$' -and $fake.Banner.Text -match '2 achievements unlocked: Small Fleet, Civic Pride')
    $script:UiGerman = $true
    & $check "German numbers and texts: $(Format-Num 45210) / $(Format-Signed 125) / $(Get-StageName 2) / $(Get-GoodName 21)" ((Format-Num 45210) -eq '45.210' -and (Format-Signed 125) -eq '+125' -and (Get-StageName 2) -eq 'Bürger' -and (Get-GoodName 21) -eq 'Schmuck')
    $script:UiGerman = $false

    Write-Host 'Window (PNG files)'
    $pngs = @()
    foreach ($lang in 'de', 'en') {
        $script:UiGerman = $lang -eq 'de'
        foreach ($v in @(@{ Name = 'race'; Compact = $false; Variant = 'race' }, @{ Name = 'race-compact'; Compact = $true; Variant = 'race' }, @{ Name = 'trade'; Compact = $false; Variant = 'trade' }, @{ Name = 'endless-banner'; Compact = $false; Variant = 'endless' }, @{ Name = 'waiting'; Compact = $false; Variant = '' })) {
            $lbv = New-LogbookState
            $lbv.Unlocked = @{}
            foreach ($id in 'first_town', 'settlers', 'citizens', 'merchants', 'res_1000', 'towns_3', 'turbo') { $lbv.Unlocked[$id] = [ordered]@{ id = $id; date = '2026-11-12T10:00:03'; game = 'Wettlauf 2 - Buergerstolz' } }
            if ($v.Variant) {
                $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4711
                $img = New-TestImage $v.Variant
                if ($v.Variant -eq 'trade') { Set-ImgI32 $img ($RvaTimers + 0x240) 400000 }
                $st = Update-GameState $lbv (Get-LogbookSnapshot $img) $t0
                if ($v.Variant -eq 'endless') { $lbv.Fresh['ships_5'] = 1; $lbv.Unlocked['ships_5'] = [ordered]@{ id = 'ships_5'; date = '2026-11-12T10:00:03'; game = 'Endlosspiel' } }
            }
            else { $st = @{ Phase = 'waiting'; NewUnlocks = @() } }
            $file = Join-Path $folder "logbook-$lang-$($v.Name).png"
            Save-WindowImage $lbv $st $v.Compact $file $(if ($v.Variant -eq 'endless') { @(@{ id = 'ships_5' }) } else { @() })
            $pngs += $file
            & $check "PNG $file" ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 3000)
        }
    }
    # Every goal kind at once (plus an unknown bit and the support conditions), end of game, no game.
    $script:UiGerman = $false
    $all = New-TestImage 'endless'
    Set-TestPlayer $all 0 0 45210 'Kapitänin Ada' 3
    $allBits = 0x1 -bor 0x2 -bor 0x4 -bor 0x8 -bor 0x10 -bor 0x20 -bor 0x40 -bor 0x80 -bor 0x100 -bor 0x200 -bor 0x400 -bor 0x1000 -bor 0x2000 -bor 0x4000 -bor 0x8000 -bor 0x10000 -bor 0x20000 -bor 0x40000
    Set-TestMission $all 3 $allBits -towns @(@(800, 3, 100), @(150, 1, 100), @(30, 0, 30)) -residents 2000 -townCount 4 -balance 100 -trade 50 -goods @(@(22, 30), @(13, 20)) -mono @(@(0x31, 1), @(2, 1)) -mustDefeat @(2) -defeatCount 1 -text 'ALL GOALS'
    $mo = $RvaMissions + 3 * $MissionSize
    Set-ImgI32 $all ($mo + 4) 3; Set-ImgByte $all ($mo + 8) 1; Set-ImgI32 $all ($mo + 0x24) 2
    foreach ($q in @(@(0x1068, 30), @(0x106C, 0), @(0x1070, 10), @(0x1074, 1000), @(0x1078, 4), @(0x107C, 500), @(0x1080, 200), @(0x1084, 1), @(0x1088, 100))) { Set-ImgI32 $all ($mo + $q[0]) $q[1] }
    $all.Write($RvaIslands, (New-Object byte[] 16))
    $ev = Get-MissionEvaluation (Get-LogbookSnapshot $all) 0
    $ids = ($ev.Goals | ForEach-Object { $_.Id }) -join ','
    & $check "all goal kinds listed ($ids)" ($ids -eq 'town0,town1,town2,alltowns,towns,residents,goods0,goods1,mono0,mono1,balance,trade,defeatcount,defeat,support,special0,special1,unknown')
    & $check "support town met by Barlin, protect condition holds, unknown bit 0x40 not met" (($ev.Goals | Where-Object { $_.Id -eq 'support' }).Done -and $ev.SubFailing -eq 0 -and -not ($ev.Goals | Where-Object { $_.Id -eq 'unknown' }).Done -and -not $ev.Fulfilled)
    $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4711
    $st = Update-GameState $lbv (Get-LogbookSnapshot $all) $t0
    $file = Join-Path $folder 'logbook-en-all-goals.png'; Save-WindowImage $lbv $st $false $file; $pngs += $file
    & $check "PNG $file" ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 3000)
    $script:UiGerman = $true
    foreach ($case in 'won', 'lost') {
        $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4711
        $img = New-TestImage 'race'
        [void](Update-GameState $lbv (Get-LogbookSnapshot $img) $t0)
        Set-ImgI32 $img $RvaTimers 1; foreach ($i in 0..3) { Set-ImgI32 $img ($RvaPlayers + $i * $PlayerSize) 9 }
        Set-ImgByte $img ($RvaPlayers + $(if ($case -eq 'won') { 0 } else { $PlayerSize }) + 0x84) 1
        $st = Update-GameState $lbv (Get-LogbookSnapshot $img) $t0.AddSeconds(3)
        $file = Join-Path $folder "logbook-de-ended-$case.png"; Save-WindowImage $lbv $st $false $file $st.NewUnlocks; $pngs += $file
        & $check "PNG $file (result $($st.Result))" ((Test-Path -LiteralPath $file) -and $st.Result -eq $case)
    }
    $script:UiGerman = $false
    $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'
    $st = Update-GameState $lbv (Get-LogbookSnapshot (New-Object AnnoLogbook.ImageSource)) $t0
    $file = Join-Path $folder 'logbook-en-nogame.png'; Save-WindowImage $lbv $st $true $file; $pngs += $file
    & $check "PNG $file ($($st.Phase))" ((Test-Path -LiteralPath $file) -and $st.Phase -eq 'nogame')
    foreach ($ph in 'version', 'denied', 'starting') {
        $lbv = New-LogbookState; $lbv.Conn.Status = $ph; $lbv.Conn.Detail = 'abc'
        $items = Get-ViewItems $lbv (Update-GameState $lbv $null $t0) $false
        & $check "view for '$ph': $($items[0].Text)" ($items.Count -ge 2 -and $items[0].Text)
    }


    # ==========================================================================================
    # Logbook 2.0: achievements, history, game summaries, played games, events, tabs.
    # ==========================================================================================
    $script:UiGerman = $false
    $useFolder = {
        param([string]$name)
        $script:AppDataFolder = Join-Path $folder $name
        if (Test-Path -LiteralPath $script:AppDataFolder) { Remove-Item -LiteralPath $script:AppDataFolder -Recurse -Force }
    }
    & $useFolder 'appdata2'
    $script:DocumentsFolder = Join-Path $folder 'documents'
    if (Test-Path -LiteralPath $script:DocumentsFolder) { Remove-Item -LiteralPath $script:DocumentsFolder -Recurse -Force }
    $t1 = [datetime]'2026-11-14T20:00:00'
    $isKind = { param($it, [string]$k) $it.Kind -eq [AnnoLogbook.Kind]$k }

    Write-Host 'Achievements 2.0, kinds of game'
    $ids = @($Achievements | ForEach-Object { $_.Id })
    $oldIds = 'first_town settlers citizens merchants aristocrats res_1000 res_5000 res_10000 city_2500 aristo_1000 towns_3 towns_5 towns_10 gold_250k gold_1m ships_5 ships_10 balance_500 hours_10 hours_50 turbo rival_defeated mission_won race_won' -split ' '
    & $check "$($ids.Count) achievements, ids unique, the 24 ids of version 2 kept" ($ids.Count -eq 53 -and @($ids | Select-Object -Unique).Count -eq $ids.Count -and @($oldIds | Where-Object { $ids -notcontains $_ }).Count -eq 0)
    & $check 'every achievement has German and English names and descriptions; names unique in each language' (@($Achievements | Where-Object { -not ($_.De -and $_.En -and $_.DescDe -and $_.DescEn) }).Count -eq 0 -and @($Achievements.De | Select-Object -Unique).Count -eq 53 -and @($Achievements.En | Select-Object -Unique).Count -eq 53)
    $kinds = @(@('Tagesabenteuer 2026-11-14', 'daily'), @('Daily Adventure 2026-11-14', 'daily'), @('Abenteuer 4711 Fordernd', 'adventure'), @('Adventure 12 Hard', 'adventure'), @('Abenteuer 4711', 'adventure'),
        @('Eigenes - Meine Insel', 'custom'), @('Custom - Pirate Bay', 'custom'), @('Herausforderung - Goldrausch', 'challenge'), @('Challenge - Gold Rush', 'challenge'),
        @('Sturmsee 3 - Der Freihafen', 'campaign'), @('Storm Sea 6 - The Golden Age', 'campaign'), @('Last Szenario', 'scenario'))
    $wrong = @($kinds | Where-Object { (Get-GameKind $_[0] $true).Kind -ne $_[1] } | ForEach-Object { $_[0] })
    & $check "kind of game from the scenario name ($($kinds.Count) names, wrong: $($wrong -join ', '))" ($wrong.Count -eq 0)
    $k = Get-GameKind 'Sturmsee 3 - Der Freihafen' $true
    & $check "campaign '$($k.Campaign)', chapter $($k.Chapter)" ($k.Campaign -eq 'Sturmsee' -and $k.Chapter -eq 3)
    & $check 'no mission: endless game even with an old scenario name in memory; [[..]] with a mission: scenario' ((Get-GameKind 'Abenteuer 4711 Fordernd' $false $false).Kind -eq 'endless' -and (Get-GameKind '[[123]]' $true $false).Kind -eq 'scenario' -and (Get-GameKind '' $false).Kind -eq 'endless' -and (Get-GameKind 'Eigenes - Ohne Ziel' $false $true).Kind -eq 'custom')

    $rich = New-TestImage 'endless'
    Set-TestPlayer $rich 0 0 2500000 'Kapitänin Ada'
    Add-TestTown $rich 0 'Zaustaden' 3 0 @(2000, 4000, 4000, 2500, 900) 1200
    Add-TestTown $rich 2 'Neu-Brandt' 11 0 @(1500, 3000, 3000, 2000, 300) 800
    Set-ImgU32 $rich ($RvaPlayers + 0x78) (480 * 2000); Set-ImgU32 $rich ($RvaPlayers + 0x74) (480 * 1000)
    Set-ImgU16 $rich ($RvaPlayers + 0x8E) 3
    for ($i = 20; $i -lt 36; $i++) { Set-ImgByte $rich ($RvaShips + $i * $ShipSize) 0x50; Set-ImgByte $rich ($RvaShips + $i * $ShipSize + 0x28) 0 }
    Set-ImgI32 $rich ($RvaTimers + 0x190) (101 * $ClockPerHour)
    $rs = Get-LogbookSnapshot $rich; $rme = Get-PlayerStats $rs 0; $rmo = Get-Balance $rs 0
    $c = Get-AchievementConditions $rs $rme $rmo @{ Session = $null; Events = @(); Now = $t1; Kind = 'endless' }
    $want = 'res_25000 city_5000 noble_town full_society balance_2000 trade_500 ships_20 hours_100 rivals_3 top_dog' -split ' '
    $miss = @($want | Where-Object { -not $c.ContainsKey($_) })
    $extra = @('fast_1000', 'night_owl', 'comeback', 'adventure', 'daily', 'custom', 'event_first' | Where-Object { $c.ContainsKey($_) })
    & $check "big empire ($($rme.Total) res., $($rme.Ships) ships, balance $($rmo.Balance)): 10 new conditions hold (missing: $($miss -join ',')), no time/kind/event one ($($extra -join ','))" ($miss.Count -eq 0 -and $extra.Count -eq 0)
    $rc = Get-AchievementConditions (Get-LogbookSnapshot (New-TestImage 'race')) (Get-PlayerStats (Get-LogbookSnapshot (New-TestImage 'race')) 0) (Get-Balance (Get-LogbookSnapshot (New-TestImage 'race')) 0) @{ Now = $t1; Kind = 'campaign'; Events = @() }
    & $check "race image: the new conditions do not hold (top dog needs 2,000 and more than all rivals)" (@($want | Where-Object { $rc.ContainsKey($_) }).Count -eq 0)
    $fimg = New-TestImage 'race'; Set-ImgI32 $fimg ($RvaTimers + 0x190) 60000
    $fs = Get-LogbookSnapshot $fimg
    $c1 = Get-AchievementConditions $fs (Get-PlayerStats $fs 0) (Get-Balance $fs 0) @{ Now = [datetime]'2026-11-15T02:30:00'; Kind = 'adventure'; Events = @() }
    Set-ImgI32 $fimg ($RvaTimers + 0x190) 70000
    $fs = Get-LogbookSnapshot $fimg
    $c2 = Get-AchievementConditions $fs (Get-PlayerStats $fs 0) (Get-Balance $fs 0) @{ Now = $t1; Kind = 'daily'; Events = @() }
    & $check "1,030 residents at 1 h 50 min: Boomtown; at 2 h 08 min: not" ($c1.fast_1000 -and -not $c2.fast_1000)
    & $check 'night owl at 02:30, not at 20:00; random/daily adventure from the kind of the session' ($c1.night_owl -and -not $c2.night_owl -and $c1.adventure -and $c2.daily -and -not $c1.daily)

    Write-Host 'Long-term achievements (logbook.json)'
    $own = Get-OwnScenariosFolder
    New-Item -ItemType Directory -Force -Path $own | Out-Null
    foreach ($n in @((1..6 | ForEach-Object { "Sturmsee $_ - Kapitel" }) + @('Inselsaga 1 - Ankunft', 'Inselsaga 2 - Ernte', 'Inselsaga 3 - Krone', 'Herausforderung - Goldrausch'))) { [IO.File]::WriteAllBytes((Join-Path $own "$n.szs"), [byte[]]@(0)) }
    & $check "chapters per campaign: Sturmsee $(Get-CampaignChapterCount 'Sturmsee'), Inselsaga $(Get-CampaignChapterCount 'Inselsaga') (files), Weltreich $(Get-CampaignChapterCount 'Weltreich') (known), Wettlauf $(Get-CampaignChapterCount 'Wettlauf') (known), unknown $(Get-CampaignChapterCount 'Gibtsnicht')" ((Get-CampaignChapterCount 'Sturmsee') -eq 6 -and (Get-CampaignChapterCount 'Inselsaga') -eq 3 -and (Get-CampaignChapterCount 'Weltreich') -eq 6 -and (Get-CampaignChapterCount 'Wettlauf') -eq 4 -and (Get-CampaignChapterCount 'Gibtsnicht') -eq 0)
    $mk = { param($scen, $res, $h = 5.0) [ordered]@{ scenario = $scen; title = ''; result = $res; date = '2026-11-13T10:00:00'; gameHours = $h } }
    $ms = New-Object Collections.ArrayList
    foreach ($i in 1..6) { [void]$ms.Add((& $mk "Sturmsee $i - Kapitel" 'won')) }
    foreach ($i in 1..4) { [void]$ms.Add((& $mk "Wettlauf $i - Kapitel" 'won')) }
    foreach ($i in 1..5) { [void]$ms.Add((& $mk "Smaragdinseln $i - Kapitel" 'won')) }
    [void]$ms.Add((& $mk 'Inselsaga 1 - Ankunft' 'lost')); [void]$ms.Add((& $mk 'Inselsaga 1 - Ankunft' 'won')); [void]$ms.Add((& $mk 'Inselsaga 2 - Ernte' 'won')); [void]$ms.Add((& $mk 'Inselsaga 3 - Krone' 'won'))
    [void]$ms.Add((& $mk 'Herausforderung - Goldrausch' 'won' 2.4)); [void]$ms.Add((& $mk 'Abenteuer 4711 Fordernd' 'won')); [void]$ms.Add((& $mk 'Tagesabenteuer 2026-11-14' 'won'))
    $fin = @(Get-FinishedCampaigns $ms)
    & $check "finished campaigns: $($fin -join ', ') (Smaragdinseln has 5 of 6)" (($fin -join ',') -eq 'Inselsaga,Sturmsee,Wettlauf')
    $lt = Get-LongTermConditions @{ missions = $ms; games = @(1..10 | ForEach-Object { @{ result = 'quit' } }) }
    $wantLt = 'chapter_won challenge_won adventure_won daily_won fast_win hattrick revenge campaign_done campaigns_3 games_10' -split ' '
    & $check "long-term conditions: $((@($lt.Keys) | Sort-Object) -join ',')" (@($wantLt | Where-Object { -not $lt.ContainsKey($_) }).Count -eq 0 -and $lt.Count -eq $wantLt.Count)
    $lt2 = Get-LongTermConditions @{ missions = @((& $mk 'Wettlauf 1 - A' 'won'), (& $mk 'Wettlauf 2 - B' 'lost'), (& $mk 'Wettlauf 1 - A' 'won'), (& $mk 'Wettlauf 3 - C' 'won' 0.0)); games = @(1..9) }
    & $check 'won-lost-won-won is no hat trick, no revenge without an earlier loss of that scenario, 9 games are not 10, 0.0 h is no lightning victory' (-not $lt2.hattrick -and -not $lt2.revenge -and -not $lt2.games_10 -and -not $lt2.fast_win -and $lt2.chapter_won -and -not $lt2.campaign_done)
    $d = Read-LogbookData; foreach ($m in $ms) { [void]$d.missions.Add($m) }; Save-LogbookData $d
    $lbl = New-LogbookState
    $new = @(Update-LongTermAchievements $lbl $t1)
    $again = @(Update-LongTermAchievements $lbl $t1)
    $saved = @((Read-LogbookData).achievements | ForEach-Object { $_.id })
    & $check "earlier games unlock retroactively: $($new.Count) new and stored, a second call adds nothing" ($new.Count -eq 9 -and $again.Count -eq 0 -and @($wantLt | Where-Object { $_ -ne 'games_10' -and $saved -notcontains $_ }).Count -eq 0)

    Write-Host 'History (one point per game minute)'
    & $useFolder 'appdata3'
    $histDir = Get-HistoryFolder
    $lbh = New-LogbookState; $lbh.Conn.Status = 'attached'; $lbh.Conn.Pid = 5151
    $himg = New-TestImage 'race'
    $setClock = { param($img, [long]$v) Set-ImgI32 $img ($RvaTimers + 0x190) $v }
    $read = { param($lbx, $img, [long]$clock) & $setClock $img $clock; $script:tickTime = $t1.AddSeconds(3 * $script:tickNo); $script:tickNo++; Update-GameState $lbx (Get-LogbookSnapshot $img) $script:tickTime }
    $script:tickNo = 0
    for ($i = 0; $i -lt 20; $i++) { Set-ImgI32 $himg ($RvaPlayers + 4) (45210 + 100 * $i); $st = & $read $lbh $himg (100000 + 300 * $i) }
    $hs = $lbh.Session
    $clocks = @($hs.Samples | ForEach-Object { $_[0] })
    & $check "20 readings 300 clock units apart: $($clocks.Count) points (every >= 545 = one game minute), $($clocks[0]) .. $($clocks[-1])" ($clocks.Count -eq 10 -and $clocks[1] -eq 100600 -and $clocks[-1] -eq 105400 -and $hs.Kind -eq 'campaign')
    & $check "history file $(Split-Path -Leaf $hs.File) written (every 5 points) and readable" ((Split-Path -Leaf $hs.File) -eq '20261114-200000.json' -and (Read-HistoryFile $hs.File).Samples.Count -eq 10)
    foreach ($i in 1..3) { $st = & $read $lbh $himg 105700 }
    & $check "paused (same clock): no new point ($($hs.Samples.Count)), paused $($st.Paused)" ($hs.Samples.Count -eq 10 -and $st.Paused)
    Add-TestTown $himg 6 'Fischerhude' 23 0 @(99000, 0, 0, 0, 0) 0
    $st = & $read $lbh $himg 106000
    Add-TestTown $himg 6 'Fischerhude' 23 0 @(35, 0, 0, 0, 0) 0
    $st = & $read $lbh $himg 106300
    & $check "a single reading with 99,000 more residents is no peak ($($hs.PeakResidents))" ($hs.PeakResidents -eq 1030)
    Add-TestTown $himg 6 'Fischerhude' 23 0 @(500, 0, 0, 0, 0) 0
    $st = & $read $lbh $himg 106600; $st = & $read $lbh $himg 106900
    & $check "two readings with 1,495 residents: peak $($hs.PeakResidents), top stage $($hs.TopStage) (merchants)" ($hs.PeakResidents -eq 1495 -and $hs.TopStage -eq 3)
    $id0 = $hs.Id; $n0 = $hs.Samples.Count
    $st = & $read $lbh $himg 102000
    & $check "savegame of the same game loaded (clock back to 102,000): same session, later points dropped ($n0 -> $($lbh.Session.Samples.Count)), reloads $($lbh.Session.Reloads)" ($lbh.Session.Id -eq $id0 -and $lbh.Session.Samples.Count -eq 4 -and $lbh.Session.Reloads -eq 1)
    foreach ($v in 102600, 103200, 103800, 104400) { $st = & $read $lbh $himg $v }
    Set-ImgText $himg ($RvaScenario + 0x13) 'Abenteuer 4711 Fordernd' 0x40
    $st = & $read $lbh $himg 1000
    $g = @($lbh.Games)[-1]
    & $check "another scenario started: the old game ends as 'left' ($($g.result), $($g.game), $($g.playedHours) h, max. $($g.peakResidents) res.)" ($g.result -eq 'quit' -and $g.scenario -eq 'Wettlauf 2 - Buergerstolz' -and $g.peakResidents -eq 1495 -and $lbh.ShowSummary -and $st.Summary)
    $oldFile = Read-HistoryFile (Join-Path $histDir "$id0.json")
    & $check "new session '$($lbh.Session.Kind)', the old history file has its end ($($oldFile.Result))" ($lbh.Session.Kind -eq 'adventure' -and $lbh.Session.Id -ne $id0 -and $oldFile.Done -and $oldFile.Result -eq 'quit')
    $st = & $read $lbh $himg 1300
    & $check "a random adventure unlocks 'Call of Adventure' after two readings" ($lbh.Unlocked.ContainsKey('adventure') -and $lbh.Session.Achievements -contains 'adventure')
    foreach ($v in 2000, 3000, 4000, 5000, 6000, 7000) { $st = & $read $lbh $himg $v }
    & $check 'the card of the previous game folds away after 10 game minutes of the next one' (-not $lbh.ShowSummary)
    $r = Close-GameProcess $lbh $t1.AddMinutes(30)
    $g = @($lbh.Games)[-1]
    & $check "game process ended: the adventure ends as 'left' ($($g.kind), $($g.gameHours) h) with its achievements, card shown" ($r.Summary -and $g.kind -eq 'adventure' -and $g.result -eq 'quit' -and $lbh.ShowSummary -and @($g.achievements) -contains 'adventure')
    $lbh.Conn.Status = 'waiting'; $lbh.PendingEnd = $r
    $st = Update-GameState $lbh $null $t1.AddMinutes(30)
    $items = Get-ViewItems $lbh $st $false
    $card = @($items | Where-Object { & $isKind $_ 'Card' })
    & $check "waiting after the game: summary card '$($card[0].Text)' with $($card[0].Cells.Length / 2) values" ($card.Count -eq 1 -and $card[0].Cells.Length -ge 12 -and $st.Summary)
    $citems = Get-ViewItems $lbh $st $true
    & $check "compact mode: one line about the last game ('$(@($citems)[-1].Text)'), no tabs" (@($citems)[-1].Key -eq 'summary:hide' -and @($citems | Where-Object { & $isKind $_ 'Tabs' }).Count -eq 0)
    $lbh.Conn.Status = 'attached'; $lbh.Conn.Pid = 5152
    Set-ImgText $himg ($RvaScenario + 0x13) 'Eigenes - Testinsel' 0x40
    $st = & $read $lbh $himg 500; $st = & $read $lbh $himg 900
    $sid = $lbh.Session.Id; $nGames = @($lbh.Games).Count
    $r = Close-GameProcess $lbh $t1.AddMinutes(40)
    & $check "a game left after less than 5 game minutes is not recorded, its history file is removed; own scenario played ('A World of Your Own')" (-not $r.Summary -and @($lbh.Games).Count -eq $nGames -and -not (Test-Path -LiteralPath (Join-Path $histDir "$sid.json")) -and $lbh.Unlocked.ContainsKey('custom'))
    $lbh.Conn.Status = 'attached'; $lbh.Conn.Pid = 5153
    Set-ImgText $himg ($RvaScenario + 0x13) 'Wettlauf 2 - Buergerstolz' 0x40
    foreach ($v in 200000, 200600, 201200, 201800, 202400, 203000) { $st = & $read $lbh $himg $v }
    Save-HistoryFile $lbh $lbh.Session
    $rid = $lbh.Session.Id; $rn = $lbh.Session.Samples.Count
    $lbr = New-LogbookState; $lbr.Conn.Status = 'attached'; $lbr.Conn.Pid = 5153
    $st = & $read $lbr $himg 203700
    & $check "logbook restarted while the game runs: the history continues in the same file ($rid, $rn -> $($lbr.Session.Samples.Count) points)" ($lbr.Session.Id -eq $rid -and $lbr.Session.Samples.Count -eq $rn + 1)
    Save-HistoryFile $lbr $lbr.Session
    $lbh.Session = $null
    $lbu = New-LogbookState
    $closed = @(Close-UnfinishedHistory $lbu)
    & $check "start of the window: the unfinished history of a game process that is gone is closed ($($closed.Count), $($closed[0].Summary.result), $($closed[0].Summary.game))" ($closed.Count -eq 1 -and $closed[0].Summary.result -eq 'quit' -and (Read-HistoryFile (Join-Path $histDir "$rid.json")).Done -and $lbu.ShowSummary)
    $j = [IO.File]::ReadAllText((Join-Path $histDir "$id0.json")) | ConvertFrom-Json
    & $check "history file format: $(@($j.fields).Count) fields, rows of $(@(@($j.samples)[0]).Count) numbers, pid $($j.pid), end '$($j.end.result)'" (@($j.fields).Count -eq 12 -and @(@($j.samples)[0]).Count -eq 12 -and $j.pid -eq 5151 -and $j.scenario -eq 'Wettlauf 2 - Buergerstolz' -and $j.end.result -eq 'quit' -and $j.state.peakResidents -eq 1495)
    $pre = @(Get-ChildItem -LiteralPath $histDir -Filter '*.json' -File).Count
    for ($i = 0; $i -lt 35; $i++) { [IO.File]::WriteAllText((Join-Path $histDir ('20250101-{0:D6}.json' -f $i)), '{}') }
    $lbh.Conn.Pid = 5154
    Set-ImgText $himg ($RvaScenario + 0x13) 'Sturmsee 1 - Schiffbruch' 0x40
    $st = & $read $lbh $himg 50000
    Save-HistoryFile $lbh $lbh.Session
    $files = @(Get-ChildItem -LiteralPath $histDir -Filter '*.json' -File | Sort-Object Name)
    & $check "rotation: $($files.Count) history files kept (newest 30), oldest '$($files[0].Name)', the new one present" ($files.Count -eq 30 -and $files[0].Name -eq ('20250101-{0:D6}.json' -f ($pre + 35 - 29)) -and (Test-Path -LiteralPath $lbh.Session.File))
    $ts = @{ Samples = (New-Object 'System.Collections.Generic.List[long[]]'); Interval = $SampleClocks; Unsaved = 0 }
    for ($i = 0; $i -lt 1000; $i++) { [void](Add-SessionSample $ts ([long[]]@(($SampleClocks * $i), $i, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))) }
    & $check "cap: 1,000 game minutes -> $($ts.Samples.Count) points (max. 720), interval $($ts.Interval), first $($ts.Samples[0][0]), last $($ts.Samples[$ts.Samples.Count - 1][0])" ($ts.Samples.Count -eq 500 -and $ts.Interval -eq 2 * $SampleClocks -and $ts.Samples[0][0] -eq 0 -and $ts.Samples[$ts.Samples.Count - 1][0] -eq 998 * $SampleClocks)

    # Same process, same (empty) scenario name: a new endless game or another savegame is a new game, not a reload.
    $lbn = New-LogbookState; $lbn.Conn.Status = 'attached'; $lbn.Conn.Pid = 5160
    $nimg = New-TestImage 'endless'
    $script:tickNo = 200
    $st = & $read $lbn $nimg 300; $st = & $read $lbn $nimg 20000
    $first = $lbn.Session.Id
    & $check "a jump of 19,700 forward with the same towns (a later savegame): same session ($($lbn.Session.FirstTown))" ($lbn.Session.Id -eq $first -and $lbn.Session.FirstTown -eq '3:Zaustaden' -and $lbn.Session.Samples.Count -eq 2)
    $st = & $read $lbn $nimg 900
    & $check "clock back to 900 (a new game starts near zero): new session, the old one recorded as a game ($(@($lbn.Games)[-1].result), $(@($lbn.Games)[-1].kind))" ($lbn.Session.Id -ne $first -and $lbn.Session.FirstClock -eq 900 -and @($lbn.Games)[-1].result -eq 'quit' -and @($lbn.Games)[-1].kind -eq 'endless')
    $second = $lbn.Session.Id
    foreach ($v in 1500, 2000, 2500, 3000, 3500, 4000) { $st = & $read $lbn $nimg $v }
    Add-TestTown $nimg 0 'Zaustaden' 9 0 @(40, 180, 320, 150, 0) 120
    $st = & $read $lbn $nimg 2000
    & $check "clock back to 2,000 with the first town on another island (another savegame): new session ($($lbn.Session.FirstTown))" ($lbn.Session.Id -ne $second -and $lbn.Session.FirstTown -eq '9:Zaustaden')
    $third = $lbn.Session.Id
    foreach ($v in 2600, 3200, 3800) { $st = & $read $lbn $nimg $v }
    foreach ($ti in 0, 2, 6) { $nimg.Write($RvaSettlements + $ti * $SettlementSize + 0x18, [byte[]]@(0xFF)) }
    $st = & $read $lbn $nimg 3000
    & $check 'clock back, the towns of that time are gone: new session' ($lbn.Session.Id -ne $third -and $lbn.Errors.Count -eq 0)

    Write-Host 'Game summary, logbook.json'
    & $useFolder 'appdata4'
    $lbw = New-LogbookState; $lbw.Conn.Status = 'attached'; $lbw.Conn.Pid = 6000
    $wimg = New-TestImage 'race'
    foreach ($v in 100000, 100600, 101200) { $st = & $read $lbw $wimg $v }
    Set-ImgByte $wimg ($RvaPlayers + 0x84) 1; Set-ImgI32 $wimg $RvaTimers 1
    foreach ($i in 0..3) { Set-ImgI32 $wimg ($RvaPlayers + $i * $PlayerSize) 9 }
    $stWon = & $read $lbw $wimg 101500
    $g = @($lbw.Games)[-1]
    & $check "won race: summary ($($g.result), $($g.gameHours) h, max. $($g.peakResidents) res., max. $($g.peakGold) gold, $($g.towns) towns, stage $($g.topStage), $(@($g.achievements) -join ','))" ($g.result -eq 'won' -and $g.gameHours -eq 3.1 -and $g.peakResidents -eq 1030 -and $g.peakGold -eq 45210 -and $g.towns -eq 3 -and $g.topStage -eq 3 -and $g.kind -eq 'campaign' -and $g.mission -and (@('mission_won', 'race_won', 'chapter_won', 'first_town') | Where-Object { @($g.achievements) -notcontains $_ }).Count -eq 0)
    $d = Read-LogbookData
    & $check "logbook.json: mission, achievements and the game written together; history '$($g.history)' has the end" ($d.missions.Count -eq 1 -and $d.games.Count -eq 1 -and @($d.achievements | Where-Object { $_.id -eq 'chapter_won' }).Count -eq 1 -and (Read-HistoryFile (Join-Path (Get-HistoryFolder) $g.history)).End.result -eq 'won' -and @($stWon.NewUnlocks | ForEach-Object { $_.id }) -contains 'chapter_won')
    $d.extra['otherTool'] = 'keep me'; Save-LogbookData $d
    [void](Add-LogbookEntries @() @() @())
    $raw = [IO.File]::ReadAllText((Get-LogbookFile)) | ConvertFrom-Json
    $keys = @($raw.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    & $check "logbook.json keys ($keys): the old ones, 'games', and an unknown key of another tool kept" ($keys -eq 'version,achievements,missions,games,settings,otherTool' -and $raw.otherTool -eq 'keep me' -and @($raw.missions)[0].scenario -eq 'Wettlauf 2 - Buergerstolz')
    $many = @(1..105 | ForEach-Object { [ordered]@{ date = '2026-11-14T10:00:00'; result = 'quit'; game = "G$_"; kind = 'endless' } })
    [void](Add-LogbookEntries @() @() $many)
    $d = Read-LogbookData
    & $check "game summaries capped at $GamesKeep, the newest kept ($($d.games.Count), last $($d.games[$d.games.Count - 1].game))" ($d.games.Count -eq 100 -and $d.games[99].game -eq 'G105' -and $d.games[0].game -eq 'G6')

    Write-Host 'Window: tabs, folding, history view, clicks'
    $lbw.Games = New-Object Collections.ArrayList; [void]$lbw.Games.Add($g)
    $items = Get-ViewItems $lbw $stWon $false
    $tabs = @($items | Where-Object { & $isKind $_ 'Tabs' })
    & $check "game tab: tab strip ($($tabs[0].Legend -join '/')), 'LAST GAME' card above the mission, 53 badges" ($tabs.Count -eq 1 -and $tabs[0].Value1 -eq 0 -and $items[2].Key -eq 'summary:hide' -and (& $isKind $items[3] 'Card') -and @($items | Where-Object { & $isKind $_ 'Badge' }).Count -eq 53)
    & $check "click on the second tab -> '$(Invoke-ViewClick $lbw 'tabs:1')', History tab" ($lbw.Tab -eq 'history')
    $items = Get-ViewItems $lbw $stWon $false
    $charts = @($items | Where-Object { & $isKind $_ 'Chart' })
    & $check "History tab: $($charts.Count) charts ($(($charts | ForEach-Object { $_.Text }) -join ' / ')) with $($charts[0].X.Length) points; residents stacked (6 series), balance split at zero" ($charts.Count -eq 4 -and $charts[0].X.Length -eq 3 -and $charts[1].Stacked -and $charts[1].Series.Length -eq 6 -and $charts[2].ZeroSplit -and $charts[3].Series.Length -eq 2)
    & $check 'History tab: summary card and the played game in the list, no badges' (@($items | Where-Object { & $isKind $_ 'Card' }).Count -eq 1 -and @($items | Where-Object { $_.Key -eq 'game:0' }).Count -eq 1 -and @($items | Where-Object { & $isKind $_ 'Badge' }).Count -eq 0)
    [void](Invoke-ViewClick $lbw 'section:charts')
    $vi = Get-ViewItems $lbw $stWon $false; $n1 = @($vi | Where-Object { & $isKind $_ 'Chart' }).Count
    [void](Invoke-ViewClick $lbw 'section:charts')
    $vi = Get-ViewItems $lbw $stWon $false; $n2 = @($vi | Where-Object { & $isKind $_ 'Chart' }).Count
    & $check "fold the charts away and back ($n1 / $n2)" ($n1 -eq 0 -and $n2 -eq 4)
    [void](Invoke-ViewClick $lbw 'tabs:0'); [void](Invoke-ViewClick $lbw 'section:achievements')
    $vi = Get-ViewItems $lbw $stWon $false; $b1 = @($vi | Where-Object { & $isKind $_ 'Badge' }).Count
    [void](Invoke-ViewClick $lbw 'section:achievements'); [void](Invoke-ViewClick $lbw 'summary:hide')
    $vi = Get-ViewItems $lbw $stWon $false
    & $check "fold the achievements away ($b1 badges), back ($(@($vi | Where-Object { & $isKind $_ 'Badge' }).Count)); hide the card" ($b1 -eq 0 -and @($vi | Where-Object { & $isKind $_ 'Badge' }).Count -eq 53 -and @($vi | Where-Object { & $isKind $_ 'Card' }).Count -eq 0)
    Save-LogbookSettings @{ tab = 'history'; collapsed = @('rivals', 'events') }
    $lbs = New-LogbookState
    & $check "tab and folded sections are restored from the settings ($($lbs.Tab); $(@($lbs.Collapsed.Keys | Sort-Object) -join ','))" ($lbs.Tab -eq 'history' -and $lbs.Collapsed.ContainsKey('rivals') -and $lbs.Collapsed.ContainsKey('events'))
    # A game picked in the list: its history file and its summary.
    $lbw.Session = $null; $lbw.Tab = 'history'
    [void](Invoke-ViewClick $lbw 'game:0')
    $items = Get-ViewItems $lbw $stWon $false
    & $check "picked game: charts from its history file ($(@($items | Where-Object { & $isKind $_ 'Chart' }).Count)), its card, 'back' link, row highlighted" (@($items | Where-Object { & $isKind $_ 'Chart' }).Count -eq 4 -and @($items | Where-Object { $_.Key -eq 'history:live' }).Count -eq 1 -and @($items | Where-Object { $_.Key -eq 'game:0' -and $_.Highlight }).Count -eq 1)
    [void](Invoke-ViewClick $lbw 'history:live')
    & $check 'back to the current game' ($null -eq $lbw.SelectedGame)
    $cv = New-Object AnnoLogbook.Canvas; $cv.Width = 444
    $lbw.Tab = 'game'
    $its = Get-ViewItems $lbw $stWon $false
    $cv.SetItems($its)
    $tab = @($its | Where-Object { & $isKind $_ 'Tabs' })[0]
    $hdr = @($its | Where-Object { $_.Key -eq 'section:achievements' })[0]
    $p1 = New-Object Drawing.Point(($tab.Parts[1].X + 5), ($tab.Parts[1].Y + 5))
    $script:clickKey = $null
    $cv.Add_ItemClicked({ param($source, $click) $script:clickKey = $click.Key })
    $cv.RaiseItemClick($cv.KeyAt($p1))
    & $check "canvas: hit test of the second tab '$($cv.KeyAt($p1))' raises ItemClicked ('$($script:clickKey)'), header -> '$($cv.KeyAt((New-Object Drawing.Point(($hdr.Bounds.X + 10), ($hdr.Bounds.Y + 20)))))'" ($script:clickKey -eq 'tabs:1' -and $cv.KeyAt((New-Object Drawing.Point(($hdr.Bounds.X + 10), ($hdr.Bounds.Y + 20)))) -eq 'section:achievements')
    $cv.Dispose()

    Write-Host 'Events (events.json of anno-patcher.ps1 -Events)'
    & $useFolder 'appdata5'
    $lbe = New-LogbookState; $lbe.Conn.Status = 'attached'; $lbe.Conn.Pid = 6161
    $eimg = New-TestImage 'race'
    $script:tickNo = 0
    $st = & $read $lbe $eimg 100000
    & $check 'no events.json: no events, no error' (@($lbe.Events.List).Count -eq 0 -and @($st.NewEvents).Count -eq 0 -and $lbe.Errors.Count -eq 0)
    New-Item -ItemType Directory -Force -Path (Split-Path (Get-EventsFile)) | Out-Null
    [IO.File]::WriteAllText((Get-EventsFile), '{ "version": 1, "events": [ {')
    $st = & $read $lbe $eimg 100300
    & $check 'broken events.json: ignored, no error' (@($lbe.Events.List).Count -eq 0 -and $lbe.Errors.Count -eq 0)
    $evs = New-Object Collections.ArrayList
    [void]$evs.Add((New-TestEvent 6161 $t1.AddMinutes(-10) 90000 'fire' 'Feuer im Lager' 'Fire in the Warehouse' '-10 t Holz' '-10 t wood'))
    [void]$evs.Add((New-TestEvent 6161 $t1.AddMinutes(-5) 95000 'trader' 'Fliegender Händler' 'Travelling Trader' '+5''000 Gold' '+5,000 gold' 99000))
    [void]$evs.Add((New-TestEvent 9999 $t1.AddMinutes(-1) 95000 'other' 'Anderes Spiel' 'Other Game' '' ''))
    Write-TestEvents $evs
    $st = & $read $lbe $eimg 100600
    & $check "file appears: 2 events of this process (not the other one), no banner for events older than 2 minutes" (@($lbe.Events.List).Count -eq 2 -and @($st.NewEvents).Count -eq 0)
    [void]$evs.Add((New-TestEvent 6161 $t1.AddSeconds(8) 100700 'storm' 'Sturmflut' 'Storm Surge' '-20 t Holz' '-20 t wood' 101500))
    Write-TestEvents $evs
    $st = & $read $lbe $eimg 100900
    $bt = Get-EventBannerText $st.NewEvents
    $script:UiGerman = $true; $btDe = Get-EventBannerText $st.NewEvents; $script:UiGerman = $false
    & $check "a new event of this process: banner '$bt' / '$btDe'" (@($st.NewEvents).Count -eq 1 -and $bt -match 'Event: Storm Surge – -20 t wood$' -and $btDe -match 'Ereignis: Sturmflut – -20 t Holz$')
    # A temporary event that the patcher ended early ("endedEarly": true) is not shown as running.
    $early = New-TestEvent 6161 $t1.AddSeconds(4) 100650 'early' 'Frühes Ende' 'Early End' 'Steuern +50 % für 1 Spielstunde' 'Taxes +50% for 1 game hour' 140000
    $early.endedEarly = $true
    $evsEarly = New-Object Collections.ArrayList; foreach ($x in $evs) { [void]$evsEarly.Add($x) }; [void]$evsEarly.Insert($evsEarly.Count - 1, $early)
    Write-TestEvents $evsEarly
    $lbx = New-LogbookState; $lbx.Conn.Status = 'attached'; $lbx.Conn.Pid = 6161
    $stx = & $read $lbx $eimg 100900
    $xitems = Get-ViewItems $lbx $stx $false
    $xrow = @($xitems | Where-Object { [string]$_.Text -eq 'Early End' })
    $srow = @($xitems | Where-Object { [string]$_.Text -eq 'Storm Surge' })
    & $check "ended early: '$($xrow[0].Sub)' (not running); a running one: '$($srow[0].Sub)'" ($xrow.Count -eq 1 -and $xrow[0].Sub -match 'ended early$' -and $xrow[0].Sub -notmatch 'left' -and $srow.Count -eq 1 -and $srow[0].Sub -match 'left$')
    Write-TestEvents $evs
    $items = Get-ViewItems $lbe $st $false
    $rows = @($items | Where-Object { & $isKind $_ 'Row' } | Where-Object { $_.Icon -eq [string][char]0x2726 })
    & $check "events section: $($rows.Count) rows, newest first ('$($rows[0].Text)', '$($rows[0].Right)' red, '$($rows[0].Sub)'), gain in green" ($rows.Count -eq 3 -and $rows[0].Text -eq 'Storm Surge' -and $rows[0].RightColor -eq [AnnoLogbook.Canvas]::Bad -and $rows[0].Sub -match 'left' -and $rows[1].RightColor -eq [AnnoLogbook.Canvas]::Good -and @($items | Where-Object { $_.Key -eq 'section:events' }).Count -eq 1)
    $st = & $read $lbe $eimg 101200
    & $check "first event of the game: 'Expect the Unexpected' after two readings; older events of the process before the session do not count ($($lbe.Session.EventCount))" ($lbe.Unlocked.ContainsKey('event_first') -and $lbe.Session.EventCount -eq 1 -and -not $lbe.Unlocked.ContainsKey('event_survived'))
    $st = & $read $lbe $eimg 101600; $st = & $read $lbe $eimg 101900
    & $check "the storm surge is over (clock >= 101,500): 'Weathered the Storm'" ($lbe.Unlocked.ContainsKey('event_survived'))
    foreach ($i in 1..4) { [void]$evs.Add((New-TestEvent 6161 $t1.AddSeconds(30 + $i) (102000 + $i) "e$i" "Ereignis $i" "Event $i" '' '')) }
    Write-TestEvents $evs
    $st = & $read $lbe $eimg 102300
    & $check "four more at once: one banner '$(Get-EventBannerText $st.NewEvents)'" (@($st.NewEvents).Count -eq 4 -and (Get-EventBannerText $st.NewEvents) -match '\(\+3 more\)$')
    $st = & $read $lbe $eimg 102600
    & $check "five events in this game: 'Eventful Times'" ($lbe.Unlocked.ContainsKey('events_5'))
    $signs = @(@{ de = "+5'000 Gold"; en = '+5,000 gold' }, @{ de = '-1.000 Gold'; en = '-1,000 gold' }, @{ de = 'Steuern -25 % für 1 Spielstunde'; en = 'Taxes -25% for 1 game hour' },
        @{ de = 'Produktion +50 % für 1 Spielstunde'; en = 'Production +50% for 1 game hour' }, @{ de = '+12 t Werkzeug'; en = '+12 t tools' }, @{ de = 'Sturm'; en = 'Storm' }, '−20 t wood') | ForEach-Object { Get-EffectSign $_ }
    & $check "effect signs of the patcher's texts: $($signs -join ' ')" (($signs -join ' ') -eq '1 -1 -1 1 1 0 -1')
    # Mission time limit (3.0: the patcher's TIMERS hook sets 0x5EC1A8 from the scenario), in the game's clock units.
    $timg = New-TestImage 'race'; Set-ImgI32 $timg ($RvaTimers + 0x240) 108000
    $lbt = New-LogbookState; $lbt.Conn.Status = 'attached'; $lbt.Conn.Pid = 7272
    $null = & $read $lbt $timg 9000; $stt = & $read $lbt $timg 9030
    $uiWas = $script:UiGerman; $script:UiGerman = $false
    $titems = Get-ViewItems $lbt $stt $false
    $trow = @($titems | Where-Object { [string]$_.Text -match '^Time limit' })
    $script:UiGerman = $true; $tde = Format-TimeLimit 108000 9030; $script:UiGerman = $uiWas
    & $check "time limit 108,000 at clock 9,030: '$($trow[0].Text)' / '$tde'" ($trow.Count -eq 1 -and $trow[0].Text -eq 'Time limit: 2 h 44 min left (clock 15:03 of 180:00)' -and $tde -eq 'Zeitlimit: noch 2 h 44 min (Uhr 15:03 von 180:00)')
    $lbe2 = New-LogbookState; $lbe2.Conn.Status = 'attached'; $lbe2.Conn.Pid = 6161
    $st = Update-GameState $lbe2 (Get-LogbookSnapshot $eimg) $t1.AddSeconds(40)
    & $check "logbook started a few seconds after an event: banner for the recent ones only ($(@($st.NewEvents).Count))" (@($st.NewEvents).Count -eq 4 -and $lbe2.Errors.Count -eq 0 -and $lbe.Errors.Count -eq 0)

    Write-Host 'Window with the new parts (PNG files)'
    foreach ($lang in 'de', 'en') {
        $script:UiGerman = $lang -eq 'de'
        & $useFolder "appdata-png-$lang"
        # History tab: a long made-up game and twelve played games.
        $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4711
        $img = New-TestImage 'race'
        $st = Update-GameState $lbv (Get-LogbookSnapshot $img) $t1
        $lbv.Session = New-DemoHistory $lbv $t1 380 $st.GameName 'campaign'
        $lbv.Games = New-DemoGames
        $lbv.Tab = 'history'
        $file = Join-Path $folder "logbook-$lang-history.png"
        Save-WindowImage $lbv $st $false $file; $pngs += $file
        & $check "PNG $file" ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 3000)
        # A game picked in the list (its own history file) with its summary card.
        $old = New-DemoHistory $lbv ([datetime]'2026-11-13T19:00:00') 200 (Txt 'Endless game' 'Endlosspiel') 'endless'
        $old.File = Join-Path (Get-HistoryFolder) 'demo-endless.json'; Save-HistoryFile $lbv $old
        $lbv.Games[10].history = 'demo-endless.json'
        [void](Invoke-ViewClick $lbv 'game:10')
        $file = Join-Path $folder "logbook-$lang-history-picked.png"
        Save-WindowImage $lbv $st $false $file; $pngs += $file
        & $check "PNG $file" ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 3000)
        # Game tab with events and the event banner.
        $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4711
        $evs = @(
            (New-TestEvent 4711 $t1.AddMinutes(-20) 251000 'trader' 'Fliegender Händler' 'Travelling Trader' '+5''000 Gold' '+5,000 gold'),
            (New-TestEvent 4711 $t1.AddMinutes(-8) 258000 'drought' 'Dürre auf Kalmar' 'Drought on Kalmar' '-50 % Ernte' '-50 % harvest' 280000),
            (New-TestEvent 4711 $t1 264900 'storm' 'Sturmflut' 'Storm Surge' '-20 t Holz' '-20 t wood' 270000))
        Write-TestEvents $evs
        $st = Update-GameState $lbv (Get-LogbookSnapshot $img) $t1
        $file = Join-Path $folder "logbook-$lang-events.png"
        Save-WindowImage $lbv $st $false $file @() $st.NewEvents; $pngs += $file
        & $check "PNG $file (banner for $(@($st.NewEvents).Count) new event)" ((Test-Path -LiteralPath $file) -and @($st.NewEvents).Count -eq 1)
        # Game tab right after a won game: summary card.
        $lbv = New-LogbookState; $lbv.Conn.Status = 'attached'; $lbv.Conn.Pid = 4712
        $img = New-TestImage 'race'
        $script:tickNo = 0
        foreach ($v in 100000, 120000, 140000, 160000, 180000) { $st = & $read $lbv $img $v }
        Set-ImgByte $img ($RvaPlayers + 0x84) 1; Set-ImgI32 $img $RvaTimers 1
        foreach ($i in 0..3) { Set-ImgI32 $img ($RvaPlayers + $i * $PlayerSize) 9 }
        $st = & $read $lbv $img 185000
        $file = Join-Path $folder "logbook-$lang-summary.png"
        Save-WindowImage $lbv $st $false $file $st.NewUnlocks; $pngs += $file
        & $check "PNG $file ($($st.Result))" ((Test-Path -LiteralPath $file) -and $st.Result -eq 'won' -and $lbv.ShowSummary)
        # The game was closed afterwards: compact window with the line about the last game.
        $lbv.Conn.Status = 'waiting'
        $stw = Update-GameState $lbv $null $t1
        $file = Join-Path $folder "logbook-$lang-summary-compact.png"
        Save-WindowImage $lbv $stw $true $file; $pngs += $file
        $ci = Get-ViewItems $lbv $stw $true
        & $check "PNG $file ('$(@($ci)[-1].Text)')" ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 2000 -and @($ci)[-1].Key -eq 'summary:hide')
    }

    $script:UiGerman = $langBefore
    Write-Host ''
    Write-Host ("{0} of {1} checks passed. PNG files in {2}" -f ($script:checks - $script:failed), $script:checks, $folder)
    $script:failed -eq 0
}

# Builds the window invisibly with the given state and saves its content as a PNG: banner, the whole
# canvas (also the part that would need scrolling) and the footer.
function Save-WindowImage($lb, $st, [bool]$compact, [string]$file, $unlocks = @(), $events = @()) {
    $ui = New-LogbookForm $lb
    $f = $ui.Form
    $f.ShowInTaskbar = $false
    $f.Location = New-Object Drawing.Point(-10000, -10000)
    $f.Size = New-Object Drawing.Size((& $ui.Px $(if ($compact) { 360 } else { 460 })), (& $ui.Px 700))
    $ui.CompactBox.Checked = $compact; $ui.TopBox.Checked = $true
    # The Shown handler runs while ShowDialog below waits, so it sees the variables of this function.
    $f.Add_Shown({
            if (@($events).Count) { Show-EventBanner $ui $events }
            elseif ($unlocks.Count) { Show-Unlocks $ui $unlocks }
            Show-ViewItems $ui (Get-ViewItems $lb $st $compact) $compact
            $ui.Status.Text = Get-StatusText $lb $st ([datetime]'2026-11-12T10:00:03') $compact
            [Windows.Forms.Application]::DoEvents()
            $w = $f.ClientSize.Width
            $parts = @(); if ($ui.Banner.Visible) { $parts += $ui.Banner }; $parts += $ui.Canvas; $parts += $ui.Footer
            $h = 0; foreach ($c in $parts) { $h += $c.Height }
            $bmp = New-Object Drawing.Bitmap($w, $h, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([AnnoLogbook.Canvas]::Back)
            $y = 0
            foreach ($c in $parts) {
                $one = New-Object Drawing.Bitmap($c.Width, $c.Height, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
                $c.DrawToBitmap($one, (New-Object Drawing.Rectangle(0, 0, $c.Width, $c.Height)))
                $g.DrawImageUnscaled($one, 0, $y); $one.Dispose(); $y += $c.Height
            }
            $g.Dispose()
            $bmp.Save($file, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
            $f.Close()
        })
    [void]$f.ShowDialog()
    $f.Dispose()
}

# A reduced snapshot for -Dump (tests compare it with the test image).
function ConvertTo-DumpObject($snap) {
    if ($null -eq $snap) { return $null }
    $ev = Get-MissionEvaluation $snap (Get-HumanSlot $snap) -AnyKind
    [ordered]@{
        clock = $snap.Clock; speed = $snap.Speed; lock = $snap.Lock; timeLimit = $snap.TimeLimit; difficulty = $snap.Difficulty; localPlayer = $snap.LocalNo
        scenario = $snap.ScenarioName; customScenario = $snap.ScenarioCustom
        players = @($snap.Players | ForEach-Object { [ordered]@{ slot = $_.Slot; kind = $_.Kind; gold = $_.Gold; name = $_.Name; no = $_.No; missionSlot = $_.MissionSlot; fulfilled = $_.Fulfilled; ships = $snap.ShipsByOwner[$_.No] } })
        settlements = @($snap.Settlements | ForEach-Object { [ordered]@{ index = $_.Index; name = $_.Name; island = $_.Island; owner = $_.Owner; total = $_.Total; workers = $_.Workers; stages = @($_.Stages) } })
        mission = $(if ($ev) { [ordered]@{ bits = $ev.Bits; fulfilled = $ev.Fulfilled; met = $ev.Met; count = $ev.Count; goals = @($ev.Goals | ForEach-Object { '{0}:{1}' -f $_.Id, $_.Done }) } } else { $null })
        balance = (Get-Balance $snap $snap.Players[(Get-HumanSlot $snap)].No).Balance
    }
}

# ---------------------------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------------------------
if ($FunctionsOnly) { return }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[void][AnnoLogbook.Native]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()
$script:DpiScale = 1.0
try { $g0 = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:DpiScale = $g0.DpiY / 96.0; $g0.Dispose() } catch { }

if ($SelfTest) {
    $ok = Invoke-SelfTest
    exit $(if ($ok) { 0 } else { 1 })
}

if ($Dump) {
    $lb = New-LogbookState
    Update-Attachment $lb
    if ($lb.Conn.Status -ne 'attached') { Write-Output (ConvertTo-Json @{ status = $lb.Conn.Status; detail = [string]$lb.Conn.Detail }); exit 2 }
    $snap = Get-LogbookSnapshot $lb.Conn.Source
    Close-Attachment $lb
    Write-Output (ConvertTo-Json (ConvertTo-DumpObject $snap) -Depth 6)
    exit $(if ($snap) { 0 } else { 3 })
}

if ($PreviewImage) {
    $lb = New-LogbookState
    $lb.NoSave = $true   # a preview writes nothing (no history file, no logbook.json change)
    Update-Attachment $lb
    $snap = if ($lb.Conn.Status -eq 'attached') { Get-LogbookSnapshot $lb.Conn.Source } else { $null }
    $st = Update-GameState $lb $snap (Get-Date)
    $lb.Fresh = @{}
    Save-WindowImage $lb $st $false $PreviewImage
    Close-Attachment $lb
    exit 0
}

# Only one logbook at a time; a second start brings the first one to the front.
$mutex = New-Object Threading.Mutex($false, $(if ($TestShowSeconds -gt 0) { 'Local\Anno1602-Extensions-LogbookTest' } else { 'Local\Anno1602-Extensions-Logbook' }))
$owned = $false
try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
if (-not $owned) {
    try { Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.Interaction]::AppActivate((Txt 'Logbook – Anno 1602' 'Logbuch – Anno 1602')) } catch { }
    exit 0
}
# The launcher starts the logbook with a hidden console; without this the window stays invisible (see UseUpHiddenStart).
[void][AnnoLogbook.Native]::UseUpHiddenStart()

$LB = New-LogbookState
$UI = New-LogbookForm $LB
$set = $LB.Settings
$normalSize = New-Object Drawing.Size((& $UI.Px 460), (& $UI.Px 780))
if ($set.width -and $set.height) { $normalSize = New-Object Drawing.Size([int]$set.width, [int]$set.height) }
$UI.Form.Size = $normalSize
$wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$loc = New-Object Drawing.Point(($wa.Right - $normalSize.Width - 24), ($wa.Top + 80))
if ($null -ne $set.left -and $null -ne $set.top) {
    $p = New-Object Drawing.Point([int]$set.left, [int]$set.top)
    if (@([Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.Contains((New-Object Drawing.Point(($p.X + 60), ($p.Y + 20)))) }).Count) { $loc = $p }
}
$UI.Form.Location = $loc
$UI.TopBox.Checked = [bool]$set.alwaysOnTop
$UI.Form.TopMost = $UI.TopBox.Checked
$UI.CompactBox.Checked = [bool]$set.compact
$script:Compact = $UI.CompactBox.Checked
if ($script:Compact) { $UI.Form.Width = & $UI.Px 360 }
$script:LastState = @{ Phase = 'waiting'; NewUnlocks = @() }

$script:BannerQueue = New-Object Collections.Queue
$script:BannerCurrent = $null; $script:BannerShownAt = Get-Date; $script:BannerDueAt = Get-Date

# Banners (achievements gold, events blue), 8 seconds each (5 when another one waits). New items of the
# kind shown are merged into the banner at once; the other kind waits (merged with a waiting one).
function Request-Banner($item) {
    $cur = $script:BannerCurrent
    if (-not ($script:UI.Banner.Visible -and $script:BannerTimer.Enabled) -or -not $cur) { Show-BannerItem $item; return }
    # Same kind: one banner for all; the time starts again only when nothing else waits.
    if ($cur.Kind -eq $item.Kind) { Show-BannerItem @{ Kind = $item.Kind; Data = @(@($cur.Data) + @($item.Data)) } -KeepTimer:($script:BannerQueue.Count -gt 0); return }
    foreach ($q in $script:BannerQueue) { if ($q.Kind -eq $item.Kind) { $q.Data = @(@($q.Data) + @($item.Data)); return } }
    $script:BannerQueue.Enqueue($item)
    # The banner on screen gets 5 seconds in all, then the waiting one follows.
    $now = Get-Date
    $want = $script:BannerShownAt.AddSeconds(5); if ($want -lt $now.AddMilliseconds(500)) { $want = $now.AddMilliseconds(500) }
    if ($script:BannerDueAt -gt $want) {
        $script:BannerTimer.Stop(); $script:BannerTimer.Interval = [int][Math]::Max(100, ($want - $now).TotalMilliseconds); $script:BannerTimer.Start()
        $script:BannerDueAt = $want
    }
}
function Show-BannerItem($item, [switch]$KeepTimer) {
    if ($item.Kind -eq 'event') { Show-EventBanner $script:UI $item.Data }
    else {
        Show-Unlocks $script:UI $item.Data
        try { [Media.SystemSounds]::Asterisk.Play() } catch { }
    }
    $script:BannerCurrent = $item
    if ($KeepTimer) { return }
    $script:BannerTimer.Stop()
    $script:BannerTimer.Interval = $(if ($script:BannerQueue.Count) { 5000 } else { 8000 })
    $script:BannerShownAt = Get-Date; $script:BannerDueAt = $script:BannerShownAt.AddMilliseconds($script:BannerTimer.Interval)
    $script:BannerTimer.Start()
}

function Invoke-Refresh([bool]$read) {
    try {
        $now = Get-Date
        if ($read) {
            Update-Attachment $script:LB
            $snap = if ($script:LB.Conn.Status -eq 'attached') { Get-LogbookSnapshot $script:LB.Conn.Source } else { $null }
            $script:LastState = Update-GameState $script:LB $snap $now
            if (@($script:LastState.NewUnlocks).Count) { Request-Banner @{ Kind = 'unlock'; Data = @($script:LastState.NewUnlocks) } }
            if (@($script:LastState.NewEvents).Count) { Request-Banner @{ Kind = 'event'; Data = @($script:LastState.NewEvents) } }
        }
        $script:LastItems = Get-ViewItems $script:LB $script:LastState $script:Compact
        Show-ViewItems $script:UI $script:LastItems $script:Compact
        $txt = Get-StatusText $script:LB $script:LastState $now $script:Compact
        if ($script:LastState.SaveError) { $txt += ' · ' + (Txt 'logbook.json not saved' 'logbook.json nicht gespeichert') }
        $script:UI.Status.Text = $txt
    }
    catch { $script:UI.Status.Text = (Txt 'Error: {0}' 'Fehler: {0}') -f $_.Exception.Message }
}

function Save-ViewSettings {
    try { Save-LogbookSettings @{ tab = $script:LB.Tab; collapsed = @($script:LB.Collapsed.Keys | Sort-Object) } } catch { }
}

$BannerTimer = New-Object Windows.Forms.Timer
$BannerTimer.Interval = 8000
$BannerTimer.Add_Tick({
        $script:BannerTimer.Stop()
        if ($script:BannerQueue.Count) { Show-BannerItem ($script:BannerQueue.Dequeue()) }
        else { $script:UI.Banner.Visible = $false; $script:BannerCurrent = $null; $script:LB.Fresh = @{} }
        Invoke-Refresh $false
    })
$Timer = New-Object Windows.Forms.Timer
$Timer.Interval = 2500
$script:TickCount = 0
$Timer.Add_Tick({
        Invoke-Refresh $true
        if ($TestTicks -gt 0) {
            $script:TickCount++
            if ($TestLog) {
                $title = if ($script:LastItems -and $script:LastItems.Count) { $script:LastItems[0].Text } else { '' }
                $s = $script:LB.Session
                $hist = if ($s) { '{0}:{1}:{2}' -f $s.Id, $s.Samples.Count, $(if ($s.Done) { $s.Result } else { 'open' }) } else { '-' }
                $banner = if ($script:UI.Banner.Visible) { $script:UI.Banner.Text } else { '' }
                Add-Content -LiteralPath $TestLog -Encoding UTF8 -Value ('{0}|{1}|{2}|{3}|{4}|compact={5}|{6}x{7}|top={8}|tab={9}|session={10}|games={11}|events={12}|banner={13}' -f $script:TickCount, $script:LastState.Phase, $script:UI.Status.Text, $title, $script:LB.Conn.Pid, $script:Compact, $script:UI.Form.Width, $script:UI.Form.Height, $script:UI.Form.TopMost, $script:LB.Tab, $hist, @($script:LB.Games).Count, @($script:LB.Events.List).Count, $banner)
            }
            if ($script:TickCount -ge $TestTicks) { $script:UI.Form.Close() }
        }
    })
if ($TestTicks -gt 0) {
    $Timer.Interval = 1000
    $UI.Form.ShowInTaskbar = $false
    $UI.Form.Location = New-Object Drawing.Point(-10000, -10000)
}
if ($TestShowSeconds -gt 0) {
    # Unlike -TestTicks the window stays a normal one: without a taskbar button the form gets a hidden owner, and owned
    # windows escape the rule that hid the logbook when the launcher started it (UseUpHiddenStart).
    $UI.Form.Location = New-Object Drawing.Point(-10000, -10000)
    $Closer = New-Object Windows.Forms.Timer; $Closer.Interval = 1000 * $TestShowSeconds
    $Closer.Add_Tick({ $script:Closer.Stop(); $script:UI.Form.Close() }); $Closer.Start()
}

$UI.TopBox.Add_CheckedChanged({ $script:UI.Form.TopMost = $script:UI.TopBox.Checked })
$UI.CompactBox.Add_CheckedChanged({
        $now = $script:UI.CompactBox.Checked
        if ($now -eq $script:Compact) { return }
        # Switch the mode first: resizing the window re-renders it (Resize handler) in the current mode.
        $script:Compact = $now
        if ($now) { $script:NormalSize = $script:UI.Form.Size; $script:UI.Form.Width = & $script:UI.Px 360 }
        else { if ($script:NormalSize) { $script:UI.Form.Size = $script:NormalSize } else { $script:UI.Form.Size = New-Object Drawing.Size((& $script:UI.Px 460), (& $script:UI.Px 780)) } }
        $script:UI.Scroll.AutoScrollPosition = New-Object Drawing.Point(0, 0)
        Invoke-Refresh $false
    })
# Clicks on tabs, section headers, the summary card and the list of played games.
$UI.Canvas.Add_ItemClicked({
        param($source, $click)
        $what = Invoke-ViewClick $script:LB $click.Key
        if (-not $what) { return }
        if ($what -eq 'settings') { Save-ViewSettings }
        if ($click.Key -like 'tabs:*') { $script:UI.Scroll.AutoScrollPosition = New-Object Drawing.Point(0, 0) }
        Invoke-Refresh $false
    })
$script:NormalSize = $normalSize
$UI.Scroll.Add_Resize({ if ($script:UI.Canvas.ItemCount) { Invoke-Refresh $false } })
$UI.Form.Add_Shown({
        # Games whose process ended while the logbook was closed, and long-term achievements of earlier games.
        try {
            $unlocks = New-Object Collections.ArrayList
            foreach ($r in @(Close-UnfinishedHistory $script:LB)) { foreach ($a in @($r.NewUnlocks)) { [void]$unlocks.Add($a) } }
            foreach ($a in @(Update-LongTermAchievements $script:LB (Get-Date))) { [void]$unlocks.Add($a) }
            if ($unlocks.Count) { Request-Banner @{ Kind = 'unlock'; Data = @($unlocks) } }
        }
        catch { }
        Invoke-Refresh $true; $script:Timer.Start()
    })
$UI.Form.Add_FormClosing({
        $script:Timer.Stop()
        $size = if ($script:Compact) { $script:NormalSize } else { $script:UI.Form.Size }
        try { Save-LogbookSettings @{ alwaysOnTop = $script:UI.TopBox.Checked; compact = $script:Compact; left = $script:UI.Form.Left; top = $script:UI.Form.Top; width = $size.Width; height = $size.Height; tab = $script:LB.Tab; collapsed = @($script:LB.Collapsed.Keys | Sort-Object) } } catch { }
        # The game may go on: keep its history so that a restarted logbook continues it.
        try { if ($script:LB.Session -and -not $script:LB.Session.Done) { Save-HistoryFile $script:LB $script:LB.Session } } catch { }
        Close-Attachment $script:LB
    })

[Windows.Forms.Application]::Run($UI.Form)
$mutex.ReleaseMutex()
