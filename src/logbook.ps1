<#
.SYNOPSIS
  Logbook: a small companion window for Anno 1602 History Edition that shows the current mission,
  your empire, the rivals and your achievements while you play.

.DESCRIPTION
  The window attaches to the running Anno1602.exe and only READS its memory (OpenProcess with
  PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, never a write). It refreshes every 2.5 seconds and
  survives the game not running yet, being closed or being restarted.

  Shown:
    - the human's mission goals with live progress (the check mirrors the game's own mission
      check FUN_1400ae010, so "met" here means met for the game),
    - gold, towns, residents per population stage, ships, balance,
    - one line per computer rival (best town, total residents, gold; race progress in races),
    - game time (game clock converted to hours at normal speed) and the current speed,
    - 24 achievements, stored in %APPDATA%\Anno1602-Extensions\logbook.json with date and game.
  Finished missions (scenario, won/lost, date, game hours) are also stored in logbook.json.

  Memory layout: see docs\FINDINGS.md (sections "Big campaign maps, race, challenges",
  "Own scenarios", "Rivals and pirates", "Players and parties") and the notes of the logbook.
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
    # For testing only: run the window off-screen for this many refreshes (1 per second) and log each one.
    [Parameter(DontShow)][int]$TestTicks = 0,
    [Parameter(DontShow)][string]$TestLog
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

# ---------------------------------------------------------------------------------------------
# Native access, memory sources and the drawing canvas (C#).
# ---------------------------------------------------------------------------------------------
if (-not ('AnnoLogbook.Canvas' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
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

    public enum Kind { Title, Header, Row, Stack, Badge, Note, Space }

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
            Relayout();
            Invalidate();
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
            int ty = r.Y + S(14), rw = TextWidth(it.Right, fSmall);
            DrawLine(g, it.Text, fHeader, new Rectangle(r.X, ty, r.Width - rw - (rw > 0 ? S(10) : 0), fHeader.Height), Pick(it.TextColor, Accent), TextFormatFlags.Left);
            if (rw > 0) DrawLine(g, it.Right, fSmall, new Rectangle(r.Right - rw, ty, rw, fHeader.Height), Pick(it.RightColor, DimColor), TextFormatFlags.Right);
            using (Pen p = new Pen(Rule)) g.DrawLine(p, r.X, r.Bottom - 1, r.Right, r.Bottom - 1);
        }

        private void PaintRow(Graphics g, Item it, Rectangle r)
        {
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
            foreach (Item it in items) if (!string.IsNullOrEmpty(it.Tip) && it.Bounds.Contains(e.Location)) { t = it.Tip; break; }
            if (t != tipText) { tipText = t; tip.SetToolTip(this, t ?? ""); }
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            tipText = null;
            tip.SetToolTip(this, "");
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
$Achievements = @(
    @{ Id = 'first_town'; De = 'Land in Sicht'; En = 'Land Ho!'; DescDe = 'Gründe deine erste Stadt.'; DescEn = 'Found your first town.' }
    @{ Id = 'settlers'; De = 'Erste Siedler'; En = 'First Settlers'; DescDe = 'Die ersten Siedler ziehen ein.'; DescEn = 'Your first settlers move in.' }
    @{ Id = 'citizens'; De = 'Bürgerstolz'; En = 'Civic Pride'; DescDe = 'Die ersten Bürger in deinem Reich.'; DescEn = 'The first citizens in your realm.' }
    @{ Id = 'merchants'; De = 'Pfeffersäcke'; En = 'Merchant Princes'; DescDe = 'Die ersten Kaufleute.'; DescEn = 'Your first merchants.' }
    @{ Id = 'aristocrats'; De = 'Blaues Blut'; En = 'Blue Blood'; DescDe = 'Die ersten Aristokraten.'; DescEn = 'Your first aristocrats.' }
    @{ Id = 'res_1000'; De = 'Tausend Seelen'; En = 'A Thousand Souls'; DescDe = '1.000 Einwohner insgesamt.'; DescEn = '1,000 residents in total.' }
    @{ Id = 'res_5000'; De = 'Blühendes Inselreich'; En = 'Thriving Realm'; DescDe = '5.000 Einwohner insgesamt.'; DescEn = '5,000 residents in total.' }
    @{ Id = 'res_10000'; De = 'Zehntausend Untertanen'; En = 'Ten Thousand Subjects'; DescDe = '10.000 Einwohner insgesamt.'; DescEn = '10,000 residents in total.' }
    @{ Id = 'city_2500'; De = 'Metropole'; En = 'Metropolis'; DescDe = 'Eine Stadt mit 2.500 Einwohnern.'; DescEn = 'One town with 2,500 residents.' }
    @{ Id = 'aristo_1000'; De = 'Hofstaat'; En = 'Royal Court'; DescDe = '1.000 Aristokraten.'; DescEn = '1,000 aristocrats.' }
    @{ Id = 'towns_3'; De = 'Inselhüpfer'; En = 'Island Hopper'; DescDe = '3 eigene Städte.'; DescEn = '3 towns of your own.' }
    @{ Id = 'towns_5'; De = 'Kolonialmacht'; En = 'Colonial Power'; DescDe = '5 eigene Städte.'; DescEn = '5 towns of your own.' }
    @{ Id = 'towns_10'; De = 'Herr der Inseln'; En = 'Lord of the Isles'; DescDe = '10 eigene Städte.'; DescEn = '10 towns of your own.' }
    @{ Id = 'gold_250k'; De = 'Volle Truhen'; En = 'Full Coffers'; DescDe = '250.000 Gold in der Kasse.'; DescEn = '250,000 gold in the treasury.' }
    @{ Id = 'gold_1m'; De = 'Millionär'; En = 'Millionaire'; DescDe = '1.000.000 Gold in der Kasse.'; DescEn = '1,000,000 gold in the treasury.' }
    @{ Id = 'ships_5'; De = 'Kleine Flotte'; En = 'Small Fleet'; DescDe = '5 eigene Schiffe.'; DescEn = '5 ships of your own.' }
    @{ Id = 'ships_10'; De = 'Armada'; En = 'Armada'; DescDe = '10 eigene Schiffe.'; DescEn = '10 ships of your own.' }
    @{ Id = 'balance_500'; De = 'Schwarze Zahlen'; En = 'In the Black'; DescDe = 'Eine Bilanz von mindestens +500.'; DescEn = 'A balance of at least +500.' }
    @{ Id = 'hours_10'; De = 'Sitzleder'; En = 'Staying Power'; DescDe = '10 Spielstunden in einer Partie.'; DescEn = '10 game hours in one game.' }
    @{ Id = 'hours_50'; De = 'Ewiger Regent'; En = 'Eternal Ruler'; DescDe = '50 Spielstunden in einer Partie.'; DescEn = '50 game hours in one game.' }
    @{ Id = 'turbo'; De = 'Volle Fahrt voraus'; En = 'Full Speed Ahead'; DescDe = 'Spiele im Turbo (8-fach oder schneller).'; DescEn = 'Play in turbo (8x or faster).' }
    @{ Id = 'rival_defeated'; De = 'Bezwinger'; En = 'Conqueror'; DescDe = 'Besiege einen Gegner.'; DescEn = 'Defeat a rival.' }
    @{ Id = 'mission_won'; De = 'Auftrag erfüllt'; En = 'Mission Accomplished'; DescDe = 'Gewinne ein Szenario.'; DescEn = 'Win a scenario.' }
    @{ Id = 'race_won'; De = 'Erster im Ziel'; En = 'First Past the Post'; DescDe = 'Gewinne einen Wettlauf gegen die Computergegner.'; DescEn = 'Win a race against the computer rivals.' }
)
function Get-AchievementName($a) { if ($script:UiGerman) { $a.De } else { $a.En } }

# Achievements whose condition holds now (mission_won and race_won are set at the end of a game).
function Get-AchievementConditions($snap, $me, $money) {
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
    $c
}

# ---------------------------------------------------------------------------------------------
# logbook.json: achievements (once ever), finished missions, window settings.
# ---------------------------------------------------------------------------------------------
function Get-LogbookFile { Join-Path $script:AppDataFolder 'Anno1602-Extensions\logbook.json' }

function Read-LogbookData {
    $d = @{ achievements = (New-Object Collections.ArrayList); missions = (New-Object Collections.ArrayList); settings = @{} }
    $file = Get-LogbookFile
    if (-not (Test-Path -LiteralPath $file)) { return $d }
    try {
        $j = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($a in @($j.achievements)) { if ($a -and $a.id) { [void]$d.achievements.Add([ordered]@{ id = [string]$a.id; date = [string]$a.date; game = [string]$a.game }) } }
        foreach ($x in @($j.missions)) { if ($x) { $h = [ordered]@{}; foreach ($pp in $x.PSObject.Properties) { $h[$pp.Name] = $pp.Value }; [void]$d.missions.Add($h) } }
        if ($j.settings) { foreach ($pp in $j.settings.PSObject.Properties) { $d.settings[$pp.Name] = $pp.Value } }
    }
    catch {
        # A broken file is kept aside (never deleted) and the logbook starts a new one.
        try { Move-Item -LiteralPath $file -Destination ($file -replace '\.json$', ('.broken-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')) -Force } catch { }
    }
    $d
}

function Save-LogbookData($d) {
    $file = Get-LogbookFile
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    $settings = [ordered]@{}; foreach ($k in ($d.settings.Keys | Sort-Object)) { $settings[$k] = $d.settings[$k] }
    $obj = [ordered]@{ version = 1; achievements = @($d.achievements); missions = @($d.missions); settings = $settings }
    $json = ConvertTo-Json $obj -Depth 5
    $tmp = "$file.tmp"
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $file) {
        try { [IO.File]::Replace($tmp, $file, $null) } catch { Copy-Item -LiteralPath $tmp -Destination $file -Force; Remove-Item -LiteralPath $tmp -Force }
    }
    else { Move-Item -LiteralPath $tmp -Destination $file }
}

# Re-reads the file before every change, so that changes by others (launcher) are kept.
function Add-LogbookEntries([object[]]$achievements, [object[]]$missions) {
    $d = Read-LogbookData
    $have = @{}; foreach ($a in $d.achievements) { $have[$a.id] = 1 }
    foreach ($a in $achievements) { if ($a -and -not $have.ContainsKey($a.id)) { [void]$d.achievements.Add($a); $have[$a.id] = 1 } }
    foreach ($x in $missions) { if ($x) { [void]$d.missions.Add($x) } }
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
    @{
        Conn = @{ Status = 'waiting'; Handle = [IntPtr]::Zero; Pid = 0; Source = $null; HashByPid = @{}; StartFails = @{}; Detail = '' }
        Unlocked = $u; Pending = @{}; Fresh = @{}
        Track = @{ SawRunning = $false; Scenario = ''; Title = ''; HasMission = $false; Race = $false }
        LastClock = [long]-1; SameClockTicks = 0
        Settings = $d.settings
    }
}

function Close-Attachment($lb) {
    if ($lb.Conn.Handle -ne [IntPtr]::Zero) { [void][AnnoLogbook.Native]::CloseHandle($lb.Conn.Handle) }
    $lb.Conn.Handle = [IntPtr]::Zero; $lb.Conn.Source = $null; $lb.Conn.Pid = 0
    $lb.Track.SawRunning = $false; $lb.LastClock = -1; $lb.SameClockTicks = 0
}

# Finds the game and opens it read-only; detects the end of the process (also the quick restart
# of Ubisoft Connect, where the first process exits right away).
function Update-Attachment($lb) {
    $c = $lb.Conn
    if ($c.Handle -ne [IntPtr]::Zero) {
        if ([AnnoLogbook.Native]::IsRunning($c.Handle)) { return }
        Close-Attachment $lb
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

# One step with a new snapshot (or $null): determines the phase, records a finished mission once,
# unlocks achievements (condition must hold in two consecutive readings). $now for tests.
function Update-GameState($lb, $snap, [datetime]$now) {
    $st = @{ Phase = $lb.Conn.Status; Snap = $snap; NewUnlocks = @(); Result = '' }
    $lb.Fresh = @{}
    if ($lb.Conn.Status -ne 'attached') { return $st }
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
        $cond = Get-AchievementConditions $snap $st.Me $st.Money
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
            if ($missionEntry -or $newOnes.Count) {
                try { [void](Add-LogbookEntries @($newOnes) @($missionEntry)) } catch { $st.SaveError = $_.Exception.Message }
                foreach ($a in $newOnes) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
                $st.NewUnlocks = @($newOnes)
            }
            return $st
        }
    }
    if ($newOnes.Count) {
        try { [void](Add-LogbookEntries @($newOnes) @()) } catch { $st.SaveError = $_.Exception.Message }
        foreach ($a in $newOnes) { $lb.Unlocked[$a.id] = $a; $lb.Fresh[$a.id] = 1 }
        $st.NewUnlocks = @($newOnes)
    }
    $st
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
    if ($st.Phase -eq 'running' -or $st.Phase -eq 'ended') {
        $snap = $st.Snap; $me = $st.Me; $ev = $st.Mission
        $sub = Get-SpeedText $snap.Speed
        $subColor = $null
        if ($st.Phase -eq 'ended') {
            if ($st.Result -eq 'won' -and $ev) { $sub = Txt 'Mission accomplished – victory!' 'Auftrag erfüllt – gewonnen!'; $subColor = $good }
            else { $sub = Txt 'Game over.' 'Spiel beendet.'; if ($ev) { $sub = Txt 'Game over – lost this time.' 'Spiel beendet – diesmal verloren.'; $subColor = $bad } }
        }
        elseif ($st.Paused) { $sub += ' · ' + (Txt 'paused or in a menu' 'pausiert oder im Menü') }
        $list.Add((New-ViewItem -Kind Title -Text $st.GameName -Right (Format-GameTime $snap.Clock) -Sub $sub -SubColor $subColor -Tip ((Txt 'Game time at normal speed (game clock {0})' 'Spielzeit bei normalem Tempo (Spieluhr {0})') -f (Format-Num $snap.Clock))))

        # Mission
        if ($ev) {
            $tip = $ev.Mission.Text; if ($tip.Length -gt 1500) { $tip = $tip.Substring(0, 1500) + ' …' }
            $right = if ($ev.Fulfilled) { Txt 'accomplished' 'erfüllt' } else { (Txt '{0} of {1} met' '{0} von {1} erfüllt') -f $ev.Met, $ev.Count }
            if (-not $compact) { $list.Add((New-ViewItem -Kind Header -Text (Txt 'MISSION' 'AUFTRAG') -Right $right -RightColor $(if ($ev.Fulfilled) { $good } else { $null }) -Tip $tip)) }
            if ($ev.Race -and -not $compact) { $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'Race: whoever completes the mission first wins – the rivals have the same goals.' 'Wettlauf: Wer den Auftrag zuerst erfüllt, gewinnt – die Gegner haben dieselben Ziele.'))) }
            if ($snap.TimeLimit -gt 0 -and $st.Phase -eq 'running') {
                $left = [Math]::Max(0, $snap.TimeLimit - $snap.Clock)
                $list.Add((New-ViewItem -Text ((Txt 'Time limit: {0} left' 'Zeitlimit: noch {0}') -f (Format-GameTime $left)) -Icon '!' -IconColor $bad -TextColor $bad))
            }
            Add-GoalItems $list $ev
            if ($ev.SubBits -band 3) {
                $who = if ($ev.Mission.SupportPlayer -eq 7) { Txt 'the other players' 'die Mitspieler' } else { Get-PlayerName $snap $ev.Mission.SupportPlayer }
                $okSub = -not ($ev.SubFailing -band 3)
                $list.Add((New-ViewItem -Text ((Txt 'Condition: protect {0}' 'Bedingung: {0} beschützen') -f $who) -Icon $(if ($okSub) { [string][char]0x2713 } else { '!' }) -Done:$okSub -Right $(if ($okSub) { 'ok' } else { Txt 'at risk' 'in Gefahr' }) -RightColor $(if ($okSub) { $good } else { $bad }) -Sub (Txt 'If this fails, the game is lost.' 'Wenn das scheitert, ist das Spiel verloren.')))
            }
        }
        else {
            if (-not $compact) { $list.Add((New-ViewItem -Kind Header -Text (Txt 'MISSION' 'AUFTRAG'))) }
            $list.Add((New-ViewItem -Kind Note -Dim -Text (Txt 'No mission – free play. The achievements still count.' 'Kein Auftrag – freies Spiel. Die Erfolge zählen trotzdem.')))
        }

        if ($compact) {
            $list.Add((New-ViewItem -Kind Space))
            $list.Add((New-ViewItem -Text ('{0} {1} · {2} {3} · {4} {5}' -f (Txt 'Gold' 'Gold'), (Format-Num $snap.Players[$st.HumanSlot].Gold), (Format-Num $me.Total), (Txt 'res.' 'Einw.'), $me.TownCount, (Txt 'towns' 'Städte')) -Dim))
            return , $list
        }

        # Your empire
        $list.Add((New-ViewItem -Kind Header -Text (Txt 'YOUR EMPIRE' 'DEIN REICH') -Right $snap.Players[$st.HumanSlot].Name))
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

        # Rivals
        $rivals = @($st.Rivals)
        if ($rivals.Count) {
            $list.Add((New-ViewItem -Kind Header -Text (Txt 'RIVALS' 'GEGNER')))
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
    }
    if ($compact) { return , $list }

    # Achievements (also while waiting)
    $n = @($Achievements | Where-Object { $lb.Unlocked.ContainsKey($_.Id) }).Count
    $list.Add((New-ViewItem -Kind Header -Text (Txt 'ACHIEVEMENTS' 'ERFOLGE') -Right ('{0} / {1}' -f $n, $Achievements.Count)))
    foreach ($a in $Achievements) {
        $u = $lb.Unlocked[$a.Id]
        $desc = if ($script:UiGerman) { $a.DescDe } else { $a.DescEn }
        if ($u) {
            $when = $u.date; try { $when = ([datetime]$u.date).ToString('g', (Get-Culture2)) } catch { }
            $desc += "`n" + ((Txt 'Unlocked {0} – {1}' 'Freigeschaltet {0} – {1}') -f $when, $u.game)
        }
        $list.Add((New-ViewItem -Kind Badge -Text (Get-AchievementName $a) -Done:([bool]$u) -Highlight:($lb.Fresh.ContainsKey($a.Id)) -Tip $desc))
    }
    , $list
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
    $ui.Banner.Text = if ($names.Count -eq 1) { '{0} {1}: {2}' -f $star, (Txt 'Achievement unlocked' 'Erfolg freigeschaltet'), $names[0] } else { '{0} {1}: {2}' -f $star, ((Txt '{0} achievements unlocked' '{0} Erfolge freigeschaltet') -f $names.Count), ($names -join ', ') }
    $ui.Banner.Visible = $true
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

    $script:UiGerman = $langBefore
    Write-Host ''
    Write-Host ("{0} of {1} checks passed. PNG files in {2}" -f ($script:checks - $script:failed), $script:checks, $folder)
    $script:failed -eq 0
}

# Builds the window invisibly with the given state and saves its content as a PNG: banner, the whole
# canvas (also the part that would need scrolling) and the footer.
function Save-WindowImage($lb, $st, [bool]$compact, [string]$file, $unlocks = @()) {
    $ui = New-LogbookForm $lb
    $f = $ui.Form
    $f.ShowInTaskbar = $false
    $f.Location = New-Object Drawing.Point(-10000, -10000)
    $f.Size = New-Object Drawing.Size((& $ui.Px $(if ($compact) { 360 } else { 460 })), (& $ui.Px 700))
    $ui.CompactBox.Checked = $compact; $ui.TopBox.Checked = $true
    # The Shown handler runs while ShowDialog below waits, so it sees the variables of this function.
    $f.Add_Shown({
            if ($unlocks.Count) { Show-Unlocks $ui $unlocks }
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
    Update-Attachment $lb
    $snap = if ($lb.Conn.Status -eq 'attached') { Get-LogbookSnapshot $lb.Conn.Source } else { $null }
    $st = Update-GameState $lb $snap (Get-Date)
    $lb.Fresh = @{}
    Save-WindowImage $lb $st $false $PreviewImage
    Close-Attachment $lb
    exit 0
}

# Only one logbook at a time; a second start brings the first one to the front.
$mutex = New-Object Threading.Mutex($false, 'Local\Anno1602-Extensions-Logbook')
$owned = $false
try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
if (-not $owned) {
    try { Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.Interaction]::AppActivate((Txt 'Logbook – Anno 1602' 'Logbuch – Anno 1602')) } catch { }
    exit 0
}

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

function Invoke-Refresh([bool]$read) {
    try {
        $now = Get-Date
        if ($read) {
            Update-Attachment $script:LB
            $snap = if ($script:LB.Conn.Status -eq 'attached') { Get-LogbookSnapshot $script:LB.Conn.Source } else { $null }
            $script:LastState = Update-GameState $script:LB $snap $now
            if ($script:LastState.NewUnlocks.Count) {
                Show-Unlocks $script:UI $script:LastState.NewUnlocks
                $script:BannerTimer.Stop(); $script:BannerTimer.Start()
                try { [Media.SystemSounds]::Asterisk.Play() } catch { }
            }
        }
        $script:LastItems = Get-ViewItems $script:LB $script:LastState $script:Compact
        Show-ViewItems $script:UI $script:LastItems $script:Compact
        $txt = Get-StatusText $script:LB $script:LastState $now $script:Compact
        if ($script:LastState.SaveError) { $txt += ' · ' + (Txt 'logbook.json not saved' 'logbook.json nicht gespeichert') }
        $script:UI.Status.Text = $txt
    }
    catch { $script:UI.Status.Text = (Txt 'Error: {0}' 'Fehler: {0}') -f $_.Exception.Message }
}

$BannerTimer = New-Object Windows.Forms.Timer
$BannerTimer.Interval = 8000
$BannerTimer.Add_Tick({ $script:BannerTimer.Stop(); $script:UI.Banner.Visible = $false; $script:LB.Fresh = @{}; Invoke-Refresh $false })
$Timer = New-Object Windows.Forms.Timer
$Timer.Interval = 2500
$script:TickCount = 0
$Timer.Add_Tick({
        Invoke-Refresh $true
        if ($TestTicks -gt 0) {
            $script:TickCount++
            if ($TestLog) {
                $title = if ($script:LastItems -and $script:LastItems.Count) { $script:LastItems[0].Text } else { '' }
                Add-Content -LiteralPath $TestLog -Encoding UTF8 -Value ('{0}|{1}|{2}|{3}|{4}|compact={5}|{6}x{7}|top={8}' -f $script:TickCount, $script:LastState.Phase, $script:UI.Status.Text, $title, $script:LB.Conn.Pid, $script:Compact, $script:UI.Form.Width, $script:UI.Form.Height, $script:UI.Form.TopMost)
            }
            if ($script:TickCount -ge $TestTicks) { $script:UI.Form.Close() }
        }
    })
if ($TestTicks -gt 0) {
    $Timer.Interval = 1000
    $UI.Form.ShowInTaskbar = $false
    $UI.Form.Location = New-Object Drawing.Point(-10000, -10000)
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
$script:NormalSize = $normalSize
$UI.Scroll.Add_Resize({ if ($script:UI.Canvas.ItemCount) { Invoke-Refresh $false } })
$UI.Form.Add_Shown({ Invoke-Refresh $true; $script:Timer.Start() })
$UI.Form.Add_FormClosing({
        $script:Timer.Stop()
        $size = if ($script:Compact) { $script:NormalSize } else { $script:UI.Form.Size }
        try { Save-LogbookSettings @{ alwaysOnTop = $script:UI.TopBox.Checked; compact = $script:Compact; left = $script:UI.Form.Left; top = $script:UI.Form.Top; width = $size.Width; height = $size.Height } } catch { }
        Close-Attachment $script:LB
    })
[Windows.Forms.Application]::Run($UI.Form)
$mutex.ReleaseMutex()
