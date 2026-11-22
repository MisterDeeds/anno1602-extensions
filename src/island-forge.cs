// Island forge: builds changed copies of the game's island files (NORD, SUED, NORDNAT, SUEDNAT, NOKLIMA) in a folder of
// the extensions. The patcher points the island loader of the game at that folder (files that are not there come from the
// game folder as before). The game files themselves are only read.
// Options: no rivers, mountains at the edge, no volcano, giant islands (larger than the largest class "lar").
// C# 5 (compiled by Windows PowerShell 5.1 with Add-Type). Details: docs\FINDINGS.md, section "Island forge".
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace AnnoIslands
{
    public class House { public int Id; public string Kind = ""; public int W = 1, H = 1; }

    // Building table from haeuser.cod (bytes negated, as the game reads it): Id (minus 20000), kind and size.
    public static class Houses
    {
        public static Dictionary<int, House> All = new Dictionary<int, House>();

        static int? Eval(string expr, Dictionary<string, int> consts)
        {
            string e = expr.Split(';')[0].Trim();
            int total = 0, sign = 1; bool any = false;
            int i = 0;
            while (i < e.Length)
            {
                char c = e[i];
                if (c == ' ' || c == '\t') { i++; continue; }
                if (c == '+') { sign = 1; i++; continue; }
                if (c == '-') { sign = -1; i++; continue; }
                int j = i;
                if (char.IsDigit(c)) { while (j < e.Length && char.IsDigit(e[j])) j++; total += sign * int.Parse(e.Substring(i, j - i)); }
                else if (char.IsLetter(c) || c == '_')
                {
                    while (j < e.Length && (char.IsLetterOrDigit(e[j]) || e[j] == '_')) j++;
                    int v; if (!consts.TryGetValue(e.Substring(i, j - i), out v)) return null;
                    total += sign * v;
                }
                else return null;
                sign = 1; any = true; i = j;
            }
            return any ? (int?)total : null;
        }

        public static void Load(string codPath)
        {
            var b = File.ReadAllBytes(codPath);
            for (int i = 0; i < b.Length; i++) b[i] = (byte)((256 - b[i]) & 0xFF);
            var lines = Encoding.GetEncoding(1252).GetString(b).Split('\n');
            var consts = new Dictionary<string, int>();
            All.Clear();
            bool started = false; int depth = 0, id = 0;
            House cur = null; bool curHasId = false;
            foreach (var raw in lines)
            {
                string line = raw.Trim();
                if (line.Contains("AB HIER GEHTS")) started = true;
                int eq = line.IndexOf('=');
                if (eq > 0 && !line.Contains(":") && !line.StartsWith(";"))
                {
                    string name = line.Substring(0, eq).Trim();
                    if (name.Length > 0 && name.All(ch => char.IsUpper(ch) || char.IsDigit(ch) || ch == '_'))
                    {
                        var v = Eval(line.Substring(eq + 1), consts); if (v.HasValue) consts[name] = v.Value;
                    }
                    continue;
                }
                if (line.StartsWith("Objekt:") && cur != null) { depth++; continue; }
                if (line.StartsWith("EndObj")) { if (depth > 0) depth--; continue; }
                if (!started) continue;
                if (line.StartsWith("@Nummer:") || line.StartsWith("Nummer:"))
                {
                    if (cur != null && curHasId) All[cur.Id] = cur;
                    var prev = cur;
                    cur = new House(); curHasId = false; depth = 0;
                    if (prev != null) { cur.Kind = prev.Kind; cur.W = prev.W; cur.H = prev.H; }
                    continue;
                }
                if (cur == null || depth > 0) continue;
                if (line.StartsWith("@Id:"))
                {
                    var v = Eval(line.Substring(4).Replace("+", ""), consts);
                    if (v.HasValue) { id += v.Value; cur.Id = id - 20000; curHasId = true; }
                }
                else if (line.StartsWith("Id:"))
                {
                    var v = Eval(line.Substring(3), consts);
                    if (v.HasValue) { id = v.Value; cur.Id = id - 20000; curHasId = true; }
                }
                else if (line.StartsWith("Kind:")) cur.Kind = line.Substring(5).Split(';')[0].Trim();
                else if (line.StartsWith("Size:"))
                {
                    var p = line.Substring(5).Split(';')[0].Split(',');
                    int w, h; if (p.Length == 2 && int.TryParse(p[0].Trim(), out w) && int.TryParse(p[1].Trim(), out h)) { cur.W = w; cur.H = h; }
                }
            }
            if (cur != null && curHasId) All[cur.Id] = cur;
        }

        public static string Kind(int id) { House h; return All.TryGetValue(id, out h) ? h.Kind : ""; }
        public static int[] Size(int id, int rot)
        {
            House h; int w = 1, hh = 1;
            if (All.TryGetValue(id, out h)) { w = h.W; hh = h.H; }
            return (rot & 1) == 1 ? new[] { hh, w } : new[] { w, hh };
        }
    }

    public class Entry
    {
        public int Id, X, Y; public uint Bits;
        public int Rot { get { return (int)(Bits & 3); } }
        public Entry Copy() { return new Entry { Id = Id, X = X, Y = Y, Bits = Bits }; }
    }

    // One island file: all chunks in their order; the header (INSEL3/4/5) and the first INSELHAUS are decoded.
    public class Island
    {
        public List<string> Names = new List<string>();
        public List<byte[]> Data = new List<byte[]>();
        public int HeaderIndex = -1, HausIndex = -1, HausCount;
        public byte[] Header { get { return Data[HeaderIndex]; } }
        public int W, H;
        public List<Entry> E = new List<Entry>();

        public static Island Load(string path) { return Parse(File.ReadAllBytes(path)); }

        public static Island Parse(byte[] b)
        {
            var f = new Island(); int p = 0;
            while (p + 20 <= b.Length)
            {
                string name = Encoding.ASCII.GetString(b, p, 16); int z = name.IndexOf('\0'); if (z >= 0) name = name.Substring(0, z);
                int len = BitConverter.ToInt32(b, p + 16);
                if (len < 0 || p + 20 + len > b.Length) throw new InvalidDataException("chunk " + name);
                var data = new byte[len]; Array.Copy(b, p + 20, data, 0, len);
                f.Names.Add(name); f.Data.Add(data);
                if (name.StartsWith("INSEL") && name != "INSELHAUS" && f.HeaderIndex < 0) f.HeaderIndex = f.Names.Count - 1;
                if (name == "INSELHAUS") { f.HausCount++; if (f.HausIndex < 0) f.HausIndex = f.Names.Count - 1; }
                p += 20 + len;
            }
            if (f.HeaderIndex < 0 || f.HausIndex < 0) throw new InvalidDataException("no island");
            f.W = f.Header[1]; f.H = f.Header[2];
            var h = f.Data[f.HausIndex];
            for (int i = 0; i + 8 <= h.Length; i += 8)
                f.E.Add(new Entry { Id = BitConverter.ToUInt16(h, i), X = h[i + 2], Y = h[i + 3], Bits = BitConverter.ToUInt32(h, i + 4) });
            return f;
        }

        public byte[] Save()
        {
            var haus = new byte[E.Count * 8]; int o = 0;
            foreach (var e in E.OrderBy(x => x.Y).ThenBy(x => x.X))
            {
                BitConverter.GetBytes((ushort)e.Id).CopyTo(haus, o); haus[o + 2] = (byte)e.X; haus[o + 3] = (byte)e.Y;
                BitConverter.GetBytes(e.Bits).CopyTo(haus, o + 4); o += 8;
            }
            Data[HausIndex] = haus;
            var ms = new MemoryStream();
            for (int i = 0; i < Names.Count; i++)
            {
                var n = new byte[16]; Encoding.ASCII.GetBytes(Names[i]).CopyTo(n, 0);
                ms.Write(n, 0, 16); ms.Write(BitConverter.GetBytes(Data[i].Length), 0, 4); ms.Write(Data[i], 0, Data[i].Length);
            }
            return ms.ToArray();
        }

        // Pieces of another INSELHAUS chunk (a second layer) and writing them back.
        public List<Entry> ParseLayer(int chunk)
        {
            var h = Data[chunk]; var list = new List<Entry>();
            for (int i = 0; i + 8 <= h.Length; i += 8) list.Add(new Entry { Id = BitConverter.ToUInt16(h, i), X = h[i + 2], Y = h[i + 3], Bits = BitConverter.ToUInt32(h, i + 4) });
            return list;
        }
        public void SetLayer(int chunk, List<Entry> list)
        {
            var b = new byte[list.Count * 8]; int o = 0;
            foreach (var e in list.OrderBy(x => x.Y).ThenBy(x => x.X)) { BitConverter.GetBytes((ushort)e.Id).CopyTo(b, o); b[o + 2] = (byte)e.X; b[o + 3] = (byte)e.Y; BitConverter.GetBytes(e.Bits).CopyTo(b, o + 4); o += 8; }
            Data[chunk] = b;
        }

        // Number of empty tiles and of tiles covered more than once (0, 0 for a whole island).
        public int[] Defects()
        {
            var n = new int[W, H];
            foreach (var e in E)
            {
                var s = Houses.Size(e.Id, e.Rot);
                for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) { int x = e.X + dx, y = e.Y + dy; if (x < W && y < H) n[x, y]++; }
            }
            int holes = 0, twice = 0;
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) { if (n[x, y] == 0) holes++; else if (n[x, y] > 1) twice++; }
            return new[] { holes, twice };
        }

        // Index of the entry that covers each cell; throws if a cell is covered twice or not at all.
        public int[,] Cover(bool strict)
        {
            var g = new int[W, H];
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) g[x, y] = -1;
            for (int i = 0; i < E.Count; i++)
            {
                var e = E[i]; var s = Houses.Size(e.Id, e.Rot);
                for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++)
                {
                    int x = e.X + dx, y = e.Y + dy;
                    if (x >= W || y >= H) { if (strict) throw new InvalidDataException("outside"); continue; }
                    if (g[x, y] >= 0 && strict) throw new InvalidDataException("overlap at " + x + "," + y);
                    g[x, y] = i;
                }
            }
            if (strict) for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) if (g[x, y] < 0) throw new InvalidDataException("hole at " + x + "," + y);
            return g;
        }
    }

    public class Options
    {
        public bool NoRivers, EdgeMountains, NoVolcano;
        public int GiantPerClimate;       // giant islands per climate (0 = none)
        public int GiantW = 150, GiantH = 130;
    }

    public static class Forge
    {
        public const int Version = 1;
        public const int GiantFirstNumber = 20;     // giant islands are lar20, lar21, ... in Nord\ and Sued\

        static readonly HashSet<string> Water = new HashSet<string> { "MEER", "BRANDUNG", "BRANDECK", "MUENDUNG" };
        static readonly HashSet<string> Beach = new HashSet<string> { "STRAND", "STRANDVARI", "STRANDECKA", "STRANDECKI", "STRANDMUND" };
        static readonly HashSet<string> Plain = new HashSet<string> { "BODEN", "WALD" };
        static readonly HashSet<string> Plateau = new HashSet<string> { "FELS", "HANG", "HANGECK", "HANGQUELL" };
        static readonly HashSet<string> River = new HashSet<string> { "FLUSS", "FLUSSECK" };
        static readonly HashSet<string> Landscape = new HashSet<string> { "MEER", "BRANDUNG", "BRANDECK", "MUENDUNG", "STRAND", "STRANDVARI", "STRANDECKA", "STRANDECKI", "STRANDMUND", "BODEN", "WALD", "FELS", "HANG", "HANGECK", "HANGQUELL", "FLUSS", "FLUSSECK" };
        const int Pyramid = 2211, Bridge = 1601, Road = 411;
        const int Spring = 2311, Slope = 2302, BeachMouth = 1071, StraightBeach = 1013, SeaMouth = 1208, StraightSurf = 1205;
        static readonly int[][] N8 = { new[] { 1, 0 }, new[] { -1, 0 }, new[] { 0, 1 }, new[] { 0, -1 }, new[] { 1, 1 }, new[] { 1, -1 }, new[] { -1, 1 }, new[] { -1, -1 } };

        static string K(Island f, int[,] g, int x, int y) { int i = g[x, y]; return i < 0 ? "" : Houses.Kind(f.E[i].Id); }
        static bool In(Island f, int x, int y) { return x >= 0 && y >= 0 && x < f.W && y < f.H; }

        // Fills the given cells with meadow: a copy (id and bits) of the nearest 1x1 BODEN cell (of 'from', the island
        // under a village file, if that has meadow at the very cell).
        static void FillMeadow(Island f, List<int[]> cells, uint fallbackBits, Island from = null)
        {
            cells = cells.GroupBy(c => c[0] * 1000 + c[1]).Select(c => c.First()).ToList();   // a tile once, even if two pieces lay on it
            var g = f.Cover(false);
            var gf = from != null ? from.Cover(false) : null;
            var hole = new HashSet<int>(cells.Select(c => c[0] * 1000 + c[1]));
            foreach (var c in cells)
            {
                Entry src = null;
                if (gf != null && In(from, c[0], c[1]) && gf[c[0], c[1]] >= 0)
                {
                    var e = from.E[gf[c[0], c[1]]];
                    if (Houses.Kind(e.Id) == "BODEN" && Houses.Size(e.Id, 0)[0] == 1 && Houses.Size(e.Id, 0)[1] == 1) src = e;
                }
                for (int r = 1; r <= 12 && src == null; r++)
                    for (int dx = -r; dx <= r && src == null; dx++)
                        for (int dy = -r; dy <= r && src == null; dy++)
                        {
                            if (Math.Max(Math.Abs(dx), Math.Abs(dy)) != r) continue;
                            int x = c[0] + dx, y = c[1] + dy;
                            if (!In(f, x, y) || hole.Contains(x * 1000 + y) || g[x, y] < 0) continue;
                            var e = f.E[g[x, y]];
                            if (Houses.Kind(e.Id) == "BODEN" && Houses.Size(e.Id, 0)[0] == 1 && Houses.Size(e.Id, 0)[1] == 1) src = e;
                        }
                f.E.Add(src != null ? new Entry { Id = src.Id, X = c[0], Y = c[1], Bits = src.Bits } : new Entry { Id = 2722, X = c[0], Y = c[1], Bits = fallbackBits & ~3u });
            }
        }

        // Removes entries (by index) and returns the cells they covered.
        static List<int[]> RemoveEntries(Island f, IEnumerable<int> indices)
        {
            var cells = new List<int[]>();
            foreach (int i in indices.Distinct().OrderByDescending(i => i))
            {
                var e = f.E[i]; var s = Houses.Size(e.Id, e.Rot);
                for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) cells.Add(new[] { e.X + dx, e.Y + dy });
                f.E.RemoveAt(i);
            }
            return cells;
        }

        // Rivers: river pieces become meadow, bridges road, the spring a plain slope, the mouth plain beach and surf.
        public static bool RemoveRivers(Island f, Island under = null)
        {
            var rivers = Enumerable.Range(0, f.E.Count).Where(i => River.Contains(Houses.Kind(f.E[i].Id))).ToList();
            bool changed = rivers.Count > 0;
            uint bits = rivers.Count > 0 ? f.E[rivers[0]].Bits : 0;
            foreach (var e in f.E)
            {
                if (e.Id == Spring) { e.Id = Slope; changed = true; }
                else if (e.Id == BeachMouth) { e.Id = StraightBeach; changed = true; }
                else if (e.Id == SeaMouth) { e.Id = StraightSurf; e.Bits = (e.Bits & ~3u) | (uint)((e.Rot + 1) & 3); changed = true; }
                else if (e.Id == Bridge) { e.Id = Road; changed = true; }
            }
            if (rivers.Count > 0) FillMeadow(f, RemoveEntries(f, rivers), bits, under);
            return changed;
        }

        // Rivers in a second landscape layer: river pieces become meadow pieces (the meadow of the first layer at that
        // tile after its rivers are gone, otherwise the first meadow piece of the island).
        static bool RemoveRiversInLayer(Island f, int chunk)
        {
            var list = f.ParseLayer(chunk);
            var rivers = list.Where(e => River.Contains(Houses.Kind(e.Id)) || e.Id == Spring || e.Id == BeachMouth || e.Id == SeaMouth || e.Id == Bridge).ToList();
            if (rivers.Count == 0) return false;
            var g = f.Cover(false);
            var anyMeadow = f.E.FirstOrDefault(e => Houses.Kind(e.Id) == "BODEN" && Houses.Size(e.Id, 0)[0] == 1 && Houses.Size(e.Id, 0)[1] == 1);
            foreach (var r in rivers)
            {
                list.Remove(r);
                var s = Houses.Size(r.Id, r.Rot);
                for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++)
                {
                    int x = r.X + dx, y = r.Y + dy; if (!In(f, x, y)) continue;
                    Entry src = g[x, y] >= 0 && Houses.Kind(f.E[g[x, y]].Id) == "BODEN" ? f.E[g[x, y]] : anyMeadow;
                    list.Add(src != null ? new Entry { Id = src.Id, X = x, Y = y, Bits = src.Bits } : new Entry { Id = 2722, X = x, Y = y, Bits = r.Bits & ~3u });
                }
            }
            f.SetLayer(chunk, list);
            return true;
        }

        // Removes one river system: the river pieces connected to the given cell, and the mouths at its end.
        static void RemoveRiverAt(Island f, int sx, int sy)
        {
            var g = f.Cover(false);
            var seen = new HashSet<int>(); var q = new Queue<int[]>(); var remove = new HashSet<int>();
            foreach (var d in N8) { int x = sx + d[0], y = sy + d[1]; if (In(f, x, y) && River.Contains(K(f, g, x, y))) q.Enqueue(new[] { x, y }); }
            while (q.Count > 0)
            {
                var c = q.Dequeue(); if (!seen.Add(c[0] * 1000 + c[1])) continue;
                int i = g[c[0], c[1]]; string k = K(f, g, c[0], c[1]);
                if (River.Contains(k) || f.E[i].Id == Bridge) { remove.Add(i); }
                else if (f.E[i].Id == BeachMouth) { f.E[i].Id = StraightBeach; }
                else if (f.E[i].Id == SeaMouth) { f.E[i].Id = StraightSurf; f.E[i].Bits = (f.E[i].Bits & ~3u) | (uint)((f.E[i].Rot + 1) & 3); continue; }
                else continue;
                foreach (var d in N8) { int x = c[0] + d[0], y = c[1] + d[1]; if (In(f, x, y) && !seen.Contains(x * 1000 + y)) { string kk = K(f, g, x, y); int j = g[x, y]; if (River.Contains(kk) || (j >= 0 && (f.E[j].Id == Bridge || f.E[j].Id == BeachMouth || f.E[j].Id == SeaMouth))) q.Enqueue(new[] { x, y }); } }
            }
            if (remove.Count > 0)
            {
                uint bits = f.E[remove.First()].Bits;
                var cells = RemoveEntries(f, remove);
                FillMeadow(f, cells, bits);
            }
        }

        // Distance of every cell from the coast: 0 = sea connected to the border (lakes do not count) or a beach next to it.
        static int[,] CoastDistance(Island f, int[,] g)
        {
            int W = f.W, H = f.H; var outer = new bool[W, H]; var q = new Queue<int[]>();
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++)
                if ((x == 0 || y == 0 || x == W - 1 || y == H - 1) && Water.Contains(K(f, g, x, y))) { outer[x, y] = true; q.Enqueue(new[] { x, y }); }
            while (q.Count > 0)
            {
                var c = q.Dequeue();
                for (int k = 0; k < 4; k++) { int x = c[0] + N8[k][0], y = c[1] + N8[k][1]; if (In(f, x, y) && !outer[x, y] && Water.Contains(K(f, g, x, y))) { outer[x, y] = true; q.Enqueue(new[] { x, y }); } }
            }
            var dist = new int[W, H];
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++)
            {
                bool coast = outer[x, y];
                if (!coast && Beach.Contains(K(f, g, x, y))) foreach (var d in N8) { int nx = x + d[0], ny = y + d[1]; if (In(f, nx, ny) && outer[nx, ny]) coast = true; }
                dist[x, y] = coast ? 0 : int.MaxValue; if (coast) q.Enqueue(new[] { x, y });
            }
            while (q.Count > 0)
            {
                var c = q.Dequeue();
                foreach (var d in N8) { int x = c[0] + d[0], y = c[1] + d[1]; if (In(f, x, y) && dist[x, y] == int.MaxValue) { dist[x, y] = dist[c[0], c[1]] + 1; q.Enqueue(new[] { x, y }); } }
            }
            return dist;
        }

        // A mountain group lies "at the coast" when its nearest tile is at most 'edge' tiles and its farthest tile at
        // most EdgeBand tiles from the coast (3.4.1: before only the nearest tile counted, so long ranges that touch
        // the coast at one end still crossed the island).
        public const int EdgeBand = 10;

        // Single mountains of the game (one rock with its own ring of slopes, from the whole islands of a climate
        // folder), by rock id; the smallest one per id. Used to split ranges that do not fit at the coast as a whole.
        static readonly Dictionary<string, Dictionary<int, List<Entry>>> rockLibrary = new Dictionary<string, Dictionary<int, List<Entry>>>(StringComparer.OrdinalIgnoreCase);
        public static Dictionary<int, List<Entry>> RockLibrary(string gameDir, string folder)
        {
            Dictionary<int, List<Entry>> lib;
            if (rockLibrary.TryGetValue(folder, out lib)) return lib;
            lib = new Dictionary<int, List<Entry>>();
            string src = Path.Combine(gameDir, folder);
            if (Directory.Exists(src))
                foreach (var file in Directory.GetFiles(src, "*.scp").OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                {
                    Island f; try { f = Island.Load(file); } catch (Exception) { continue; }
                    if (f.HausCount != 1 || !IsWhole(f)) continue;
                    var g = f.Cover(true); var seen = new bool[f.W, f.H];
                    for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++)
                    {
                        if (seen[x, y] || !IsPlateau(f, g, x, y)) continue;
                        var idx = new HashSet<int>(); var q = new Queue<int[]>(); q.Enqueue(new[] { x, y }); seen[x, y] = true; var cells = new List<int[]>();
                        while (q.Count > 0)
                        {
                            var c = q.Dequeue(); cells.Add(c); idx.Add(g[c[0], c[1]]);
                            foreach (var d in N8) { int nx = c[0] + d[0], ny = c[1] + d[1]; if (In(f, nx, ny) && !seen[nx, ny] && IsPlateau(f, g, nx, ny)) { seen[nx, ny] = true; q.Enqueue(new[] { nx, ny }); } }
                        }
                        var ents = idx.Select(i => f.E[i]).ToList();
                        var rocks = ents.Where(e => Houses.Kind(e.Id) == "FELS").ToList();
                        if (rocks.Count != 1 || ents.Any(e => e.Id == Spring) || ents.Count < 2) continue;
                        // Every piece inside the group.
                        bool inside = ents.All(e => { var s = Houses.Size(e.Id, e.Rot); for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) { int cx = e.X + dx, cy = e.Y + dy; if (!In(f, cx, cy) || !cells.Any(c => c[0] == cx && c[1] == cy)) return false; } return true; });
                        if (!inside) continue;
                        int x0 = cells.Min(c => c[0]), y0 = cells.Min(c => c[1]);
                        var rel = ents.Select(e => new Entry { Id = e.Id, X = e.X - x0, Y = e.Y - y0, Bits = e.Bits }).ToList();
                        List<Entry> have;
                        if (!lib.TryGetValue(rocks[0].Id, out have) || CellCount(rel) < CellCount(have)) lib[rocks[0].Id] = rel;
                    }
                }
            rockLibrary[folder] = lib;
            return lib;
        }
        // The single mountain for a rock: the game's one with this rock, otherwise one with a rock of the same size
        // (its slopes fit the same way) with the rock replaced (Nord/Sued have no single mountain with rock 1105).
        static List<Entry> RockTemplate(Dictionary<int, List<Entry>> library, int rockId)
        {
            List<Entry> tpl;
            if (library.TryGetValue(rockId, out tpl)) return tpl;
            var size = Houses.Size(rockId, 0);
            foreach (var kv in library.OrderBy(kv => kv.Key))
            {
                var s = Houses.Size(kv.Key, 0);
                if (s[0] == size[0] && s[1] == size[1]) return kv.Value.Select(e => { var c = e.Copy(); if (c.Id == kv.Key) c.Id = rockId; return c; }).ToList();
            }
            return null;
        }
        static int CellCount(List<Entry> ents) { return ents.Sum(e => { var s = Houses.Size(e.Id, e.Rot); return s[0] * s[1]; }); }
        static List<int[]> CellsOf(List<Entry> ents)
        {
            var cells = new List<int[]>();
            foreach (var e in ents) { var s = Houses.Size(e.Id, e.Rot); for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) cells.Add(new[] { e.X + dx, e.Y + dy }); }
            return cells;
        }

        // Best spot for a group of cells (relative to 0/0): only meadow and forest under it and around it (the group
        // itself may lie around it), at least 2 tiles from the coast, not in 'keep'. Score = farthest tile from the
        // coast (the whole group close to the coast); ties: closest to (px, py). Returns false if there is none.
        static bool FindSpot(Island f, int[,] g, int[,] dist, List<int[]> rel, Func<int, int, bool> self, HashSet<int> keep, int px, int py, out int bestOx, out int bestOy, out int bestScore)
        {
            int bw = rel.Max(c => c[0]) + 1, bh = rel.Max(c => c[1]) + 1;
            bestOx = -1; bestOy = -1; bestScore = int.MaxValue; long bestMove = long.MaxValue;
            for (int ox = 0; ox + bw <= f.W; ox++) for (int oy = 0; oy + bh <= f.H; oy++)
            {
                int score = 0; bool ok = true;
                foreach (var c in rel)
                {
                    int x = c[0] + ox, y = c[1] + oy;
                    int i = g[x, y];
                    if (i < 0 || !Plain.Contains(Houses.Kind(f.E[i].Id)) || dist[x, y] < 2 || keep.Contains(x * 1000 + y)) { ok = false; break; }
                    foreach (var d in N8)
                    {
                        int nx = x + d[0], ny = y + d[1];
                        if (!In(f, nx, ny)) { ok = false; break; }
                        int j = g[nx, ny]; string kk = j < 0 ? "" : Houses.Kind(f.E[j].Id);
                        if (!(Plain.Contains(kk) || self(nx, ny))) { ok = false; break; }
                    }
                    if (!ok) break;
                    score = Math.Max(score, dist[x, y]);
                    if (score > bestScore) { ok = false; break; }
                }
                if (!ok) continue;
                long move = (long)(ox - px) * (ox - px) + (long)(oy - py) * (oy - py);
                if (score < bestScore || (score == bestScore && move < bestMove)) { bestScore = score; bestMove = move; bestOx = ox; bestOy = oy; }
            }
            return bestOx >= 0;
        }

        // Mountains (rock pieces with their slopes) that are not at the coast (nearest tile further than 'edge', or
        // farthest tile further than EdgeBand) move to the coast: as a whole to the free spot (only meadow and forest,
        // one tile of land left before the beach) whose farthest tile is closest to the coast, of those the one closest
        // to the old place. A range that fits nowhere at the coast as a whole is split: every rock of it becomes a single
        // mountain (a single mountain of the game with the same rock, from 'library') placed at the coast the same way.
        // The old place becomes meadow; a river that springs from a moved mountain is removed with it; deer on the new
        // spots are removed from HIRSCH2. 'keep': cells that village files change on this island (with a margin) - no
        // mountain moves there. 'block': cells that village files change, and those next to their slopes - mountains
        // there stay (default: 'keep').
        public static bool MoveMountains(Island f, int edge, HashSet<int> keep = null, Dictionary<int, List<Entry>> library = null, HashSet<int> block = null)
        {
            if (keep == null) keep = new HashSet<int>();
            if (block == null) block = keep;
            bool changed = false;
            var done = new HashSet<int>();
            for (int round = 0; round < 400; round++)
            {
                var g = f.Cover(false); var dist = CoastDistance(f, g);
                // Components of plateau cells (8-connected).
                var comp = new int[f.W, f.H]; for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++) comp[x, y] = -1;
                var comps = new List<List<int[]>>();
                for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++)
                {
                    if (comp[x, y] >= 0 || !IsPlateau(f, g, x, y)) continue;
                    var list = new List<int[]>(); var q = new Queue<int[]>(); q.Enqueue(new[] { x, y }); comp[x, y] = comps.Count;
                    while (q.Count > 0)
                    {
                        var c = q.Dequeue(); list.Add(c);
                        foreach (var d in N8) { int nx = c[0] + d[0], ny = c[1] + d[1]; if (In(f, nx, ny) && comp[nx, ny] < 0 && IsPlateau(f, g, nx, ny)) { comp[nx, ny] = comps.Count; q.Enqueue(new[] { nx, ny }); } }
                    }
                    comps.Add(list);
                }
                int pick = -1, bestKey = -1, maxDistPick = 0, minDistPick = 0;
                for (int ci = 0; ci < comps.Count; ci++)
                {
                    int key = comps[ci].Min(c => c[0] * 1000 + c[1]);
                    if (done.Contains(key)) continue;
                    int md = comps[ci].Min(c => dist[c[0], c[1]]), mx = comps[ci].Max(c => dist[c[0], c[1]]);
                    if ((md <= edge && mx <= EdgeBand) || comps[ci].Any(c => block.Contains(c[0] * 1000 + c[1]))) { done.Add(key); continue; }
                    // Every entry of the component must lie completely inside it.
                    bool whole = comps[ci].All(c => { var e = f.E[g[c[0], c[1]]]; var s = Houses.Size(e.Id, e.Rot); for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) { int x = e.X + dx, y = e.Y + dy; if (!In(f, x, y) || comp[x, y] != ci) return false; } return true; });
                    if (!whole) { done.Add(key); continue; }
                    if (pick < 0 || comps[ci].Count > comps[pick].Count) { pick = ci; bestKey = key; maxDistPick = mx; minDistPick = md; }
                }
                if (pick < 0) break;
                done.Add(bestKey);
                var cells = comps[pick];
                int bx = cells.Min(c => c[0]), by = cells.Min(c => c[1]);
                int pickId = pick;
                var rel = cells.Select(c => new[] { c[0] - bx, c[1] - by }).ToList();
                int bestOx, bestOy, bestScore;
                bool found = FindSpot(f, g, dist, rel, (x, y) => comp[x, y] == pickId, keep, bx, by, out bestOx, out bestOy, out bestScore);
                var idx = cells.Select(c => g[c[0], c[1]]).Distinct().ToList();
                var rocks = idx.Where(i => Houses.Kind(f.E[i].Id) == "FELS").ToList();
                bool improve = found && bestScore < maxDistPick, fits = improve && bestScore <= EdgeBand;
                // Too big for the coast as a whole: split into single mountains, if the game has one for every rock.
                if (!fits && maxDistPick > EdgeBand && library != null && rocks.Count > 1 && rocks.All(i => RockTemplate(library, f.E[i].Id) != null) && SplitRange(f, idx, library, keep)) { changed = true; continue; }
                // A range that touches the coast moves only if it then lies at the coast completely.
                if (!improve || (!fits && minDistPick <= edge)) continue;
                // Move: entries of the component (origin cells inside), spring -> plain slope.
                var moved = idx.Select(i => { var e = f.E[i].Copy(); e.X += bestOx - bx; e.Y += bestOy - by; return e; }).ToList();
                var springs = idx.Where(i => f.E[i].Id == Spring).Select(i => new[] { f.E[i].X, f.E[i].Y }).ToList();
                foreach (var e in moved) if (e.Id == Spring) e.Id = Slope;
                var target = new HashSet<int>(cells.Select(c => (c[0] - bx + bestOx) * 1000 + (c[1] - by + bestOy)));
                var covered = target.Select(t => g[t / 1000, t % 1000]).Distinct().ToList();
                uint bits = f.E[idx[0]].Bits;
                var old = RemoveEntries(f, idx.Concat(covered).ToList());
                f.E.AddRange(moved);
                FillMeadow(f, old.Where(c => !target.Contains(c[0] * 1000 + c[1])).ToList(), bits);
                foreach (var s in springs) RemoveRiverAt(f, s[0], s[1]);
                DropDeer(f, target);
                changed = true;
            }
            return changed;
        }

        // Splits a mountain range (entries 'idx', every piece inside it) into single mountains of the game: the range
        // becomes meadow (a river from its springs goes with it), then every rock of it, the largest first, comes back
        // as the single mountain of 'library' with the same rock, at the free spot closest to the coast (see FindSpot).
        // Bits of the new pieces: those of the game's single mountain, with island, town and owner of the old rock.
        // If a rock finds no spot within EdgeBand tiles of the coast, the island stays as it was (no mountain is lost,
        // none lands further inland).
        static bool SplitRange(Island f, List<int> idx, Dictionary<int, List<Entry>> library, HashSet<int> keep)
        {
            var backup = f.E.Select(e => e.Copy()).ToList(); var backupData = f.Data.Select(d => (byte[])d.Clone()).ToList();
            var rocks = idx.Where(i => Houses.Kind(f.E[i].Id) == "FELS").Select(i => f.E[i].Copy())
                .OrderByDescending(e => { var s = Houses.Size(e.Id, e.Rot); return s[0] * s[1]; }).ThenBy(e => e.X).ThenBy(e => e.Y).ToList();
            var springs = idx.Where(i => f.E[i].Id == Spring).Select(i => new[] { f.E[i].X, f.E[i].Y }).ToList();
            uint bits = f.E[idx[0]].Bits;
            FillMeadow(f, RemoveEntries(f, idx), bits);
            foreach (var s in springs) RemoveRiverAt(f, s[0], s[1]);
            const uint own = (0xFFu << 6) | (7u << 14) | (0xFu << 22);
            var placedAll = new HashSet<int>();
            foreach (var rock in rocks)
            {
                var tpl = RockTemplate(library, rock.Id);
                var tplRock = tpl.First(e => e.Id == rock.Id);
                var rel = CellsOf(tpl);
                var g = f.Cover(false); var dist = CoastDistance(f, g);
                int ox, oy, score;
                if (!FindSpot(f, g, dist, rel, (x, y) => false, keep, rock.X - tplRock.X, rock.Y - tplRock.Y, out ox, out oy, out score) || score > EdgeBand)
                {
                    f.E = backup; f.Data = backupData;
                    return false;
                }
                var target = new HashSet<int>(rel.Select(c => (c[0] + ox) * 1000 + (c[1] + oy)));
                var covered = target.Select(t => g[t / 1000, t % 1000]).Distinct().ToList();
                uint cb = f.E[covered[0]].Bits;
                var old = RemoveEntries(f, covered);
                f.E.AddRange(tpl.Select(e => new Entry { Id = e.Id, X = e.X + ox, Y = e.Y + oy, Bits = (e.Bits & ~own) | (rock.Bits & own) }));
                FillMeadow(f, old.Where(c => !target.Contains(c[0] * 1000 + c[1])).ToList(), cb);
                placedAll.UnionWith(target);
            }
            DropDeer(f, placedAll);
            return true;
        }

        static bool IsPlateau(Island f, int[,] g, int x, int y)
        {
            int i = g[x, y]; if (i < 0) return false;
            return f.E[i].Id != Pyramid && Plateau.Contains(Houses.Kind(f.E[i].Id));
        }

        // HIRSCH2: entries of 8 bytes, x at +1, y at +2.
        static void DropDeer(Island f, HashSet<int> cells)
        {
            int k = f.Names.IndexOf("HIRSCH2"); if (k < 0) return;
            var d = f.Data[k]; var keep = new List<byte>();
            for (int i = 0; i + 8 <= d.Length; i += 8) if (!cells.Contains(d[i + 1] * 1000 + d[i + 2])) for (int j = 0; j < 8; j++) keep.Add(d[i + j]);
            f.Data[k] = keep.ToArray();
        }

        // The only volcano of the game (Nord\big25): count +23 and volcano mountains +60..+91 of INSEL4/5.
        public static bool RemoveVolcano(Island f)
        {
            var h = f.Header; if (h.Length < 92) return false;
            bool any = h[23] != 0; for (int i = 60; i < 92; i++) if (h[i] != 0) any = true;
            if (!any) return false;
            h[23] = 0; for (int i = 60; i < 92; i++) h[i] = 0;
            return true;
        }

        public static readonly string[] Folders = { "Nord", "Sued", "NordNat", "SuedNat", "NoKlima" };
        public static readonly string[] Classes = { "lit", "mit", "med", "big", "lar" };

        // For the tests: the mountain groups (rock with slopes, 8-connected) of an island: rock pieces, tiles, nearest
        // and farthest tile from the coast.
        public static List<int[]> MountainGroups(Island f)
        {
            var res = new List<int[]>();
            var g = f.Cover(false); var dist = CoastDistance(f, g);
            var seen = new bool[f.W, f.H];
            for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++)
            {
                if (seen[x, y] || !IsPlateau(f, g, x, y)) continue;
                int md = int.MaxValue, mx = 0, n = 0; var rocks = new HashSet<int>(); var q = new Queue<int[]>(); q.Enqueue(new[] { x, y }); seen[x, y] = true;
                while (q.Count > 0)
                {
                    var c = q.Dequeue(); md = Math.Min(md, dist[c[0], c[1]]); mx = Math.Max(mx, dist[c[0], c[1]]); n++;
                    if (K(f, g, c[0], c[1]) == "FELS") rocks.Add(g[c[0], c[1]]);
                    foreach (var d in N8) { int nx = c[0] + d[0], ny = c[1] + d[1]; if (In(f, nx, ny) && !seen[nx, ny] && IsPlateau(f, g, nx, ny)) { seen[nx, ny] = true; q.Enqueue(new[] { nx, ny }); } }
                }
                res.Add(new[] { rocks.Count, n, md, mx });
            }
            return res;
        }

        // For the tests: share of the mountain groups of all whole Nord/Sued islands that lie at most 3 tiles from the
        // coast ('whole': and with their farthest tile at most EdgeBand tiles); with 'overrideDir' the files written
        // there replace the game's.
        public static double MountainShare(string gameDir, string overrideDir, bool whole = false)
        {
            if (Houses.All.Count == 0) Houses.Load(Path.Combine(gameDir, "haeuser.cod"));
            int near = 0, total = 0;
            foreach (var folder in new[] { "Nord", "Sued" })
                foreach (var file in Directory.GetFiles(Path.Combine(gameDir, folder), "*.scp"))
                {
                    string path = file;
                    if (overrideDir != null) { var o = Path.Combine(overrideDir, folder, Path.GetFileName(file)); if (File.Exists(o)) path = o; }
                    Island f; try { f = Island.Load(path); } catch (Exception) { continue; }
                    if (!IsWhole(f)) continue;
                    foreach (var gr in MountainGroups(f)) { total++; if (gr[2] <= 3 && (!whole || gr[3] <= EdgeBand)) near++; }
                }
            return total == 0 ? 0 : (double)near / total;
        }

        // True if the first INSELHAUS covers every tile (a complete island, not just the changes of a village).
        public static bool IsWhole(Island f) { try { f.Cover(true); return true; } catch (InvalidDataException) { return false; } }

        // The island file under a village file ("Nord\big01.scp"), or null.
        public static string UnderName(Island v)
        {
            var h = v.Header; if (h.Length < 102 || h[101] != 0) return null;
            int file = BitConverter.ToUInt16(h, 96), cls = BitConverter.ToUInt16(h, 98), climate = h[100];
            if (file == 0xFFFF || cls > 4 || climate > 1) return null;
            return (climate == 0 ? "Nord" : "Sued") + "\\" + Classes[cls] + file.ToString("00") + ".scp";
        }

        // Builds the folder. Returns one line per changed or new file, plus a summary line.
        public static List<string> Build(string gameDir, string outDir, Options o)
        {
            Houses.Load(Path.Combine(gameDir, "haeuser.cod"));
            var log = new List<string>(); int changedFiles = 0, giants = 0;
            // Village files (NordNat, SuedNat) only hold the changes of a village; the game loads the island under it
            // from Nord/Sued (header: file number +96, class +98, climate +100, original flag +101 = 0). Mountains under
            // a village or next to the slopes of a village stay where they are; no mountain moves to 3 tiles or less
            // from a piece of a village.
            var villages = new Dictionary<string, List<KeyValuePair<string, Island>>>(StringComparer.OrdinalIgnoreCase);
            var keep = new Dictionary<string, HashSet<int>>(StringComparer.OrdinalIgnoreCase);
            var block = new Dictionary<string, HashSet<int>>(StringComparer.OrdinalIgnoreCase);
            foreach (var folder in new[] { "NordNat", "SuedNat" })
            {
                string src = Path.Combine(gameDir, folder); if (!Directory.Exists(src)) continue;
                foreach (var file in Directory.GetFiles(src, "*.scp").OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                {
                    Island v; try { v = Island.Load(file); } catch (Exception) { continue; }
                    string under = UnderName(v); if (under == null || IsWhole(v)) continue;
                    List<KeyValuePair<string, Island>> list;
                    if (!villages.TryGetValue(under, out list)) { list = new List<KeyValuePair<string, Island>>(); villages[under] = list; keep[under] = new HashSet<int>(); block[under] = new HashSet<int>(); }
                    list.Add(new KeyValuePair<string, Island>(folder + "\\" + Path.GetFileName(file), v));
                    foreach (var e in v.E)
                    {
                        var s = Houses.Size(e.Id, e.Rot); int m = Plateau.Contains(Houses.Kind(e.Id)) ? 1 : 0;
                        for (int dx = -3; dx < s[0] + 3; dx++) for (int dy = -3; dy < s[1] + 3; dy++) keep[under].Add((e.X + dx) * 1000 + (e.Y + dy));
                        for (int dx = -m; dx < s[0] + m; dx++) for (int dy = -m; dy < s[1] + m; dy++) block[under].Add((e.X + dx) * 1000 + (e.Y + dy));
                    }
                }
            }
            var changedUnder = new Dictionary<string, Island>(StringComparer.OrdinalIgnoreCase);
            foreach (var folder in Folders)
            {
                string src = Path.Combine(gameDir, folder);
                if (!Directory.Exists(src)) continue;
                foreach (var file in Directory.GetFiles(src, "*.scp").OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                {
                    string name = folder + "\\" + Path.GetFileName(file);
                    Island f;
                    try { f = Island.Load(file); } catch (Exception) { continue; }
                    if (folder.EndsWith("Nat") && !IsWhole(f)) continue;     // village change files: below
                    bool ch = false; var what = new List<string>();
                    if (o.NoVolcano && RemoveVolcano(f)) { ch = true; what.Add("volcano"); }
                    // Islands with buildings in a second layer keep their landscape. Mountains move only on islands whose
                    // pieces cover every tile exactly once (as the building table says); rivers also go on the few
                    // islands of the game with empty or doubly covered tiles (Sued\big52: two river pieces on one tile,
                    // 7 empty tiles), as long as that adds no empty or doubly covered tile.
                    // A second layer that holds only landscape (Sued\big52: river corners and meadow, Sued\lit48: forest)
                    // is treated like the first one for rivers; mountains move only on islands with one layer.
                    var extra = Enumerable.Range(0, f.Names.Count).Where(i => f.Names[i] == "INSELHAUS" && i != f.HausIndex && f.Data[i].Length > 0).ToList();
                    bool layers = extra.All(i => f.ParseLayer(i).All(e => Landscape.Contains(Houses.Kind(e.Id))));
                    var before = f.Defects();
                    bool whole = before[0] == 0 && before[1] == 0;
                    if (layers)
                    {
                        HashSet<int> k, b; keep.TryGetValue(name, out k); block.TryGetValue(name, out b);
                        if (o.NoRivers)
                        {
                            var backup = f.E.Select(e => e.Copy()).ToList(); var backupData = f.Data.Select(d => (byte[])d.Clone()).ToList();
                            bool removed = RemoveRivers(f);
                            foreach (int li in extra) if (RemoveRiversInLayer(f, li)) removed = true;
                            if (removed)
                            {
                                var after = f.Defects();
                                if (after[0] <= before[0] && after[1] <= before[1]) { ch = true; what.Add("rivers"); }
                                else { f.E = backup; f.Data = backupData; log.Add(name + ": rivers kept (the file has empty or doubly covered tiles)"); }
                            }
                        }
                        if (o.EdgeMountains && whole && extra.Count == 0 && MoveMountains(f, 3, k, RockLibrary(gameDir, folder.StartsWith("Sued") ? "Sued" : "Nord"), b)) { ch = true; what.Add("mountains"); }
                        if (whole) f.Cover(true);
                    }
                    if (!ch) continue;
                    string dst = Path.Combine(outDir, folder); Directory.CreateDirectory(dst);
                    File.WriteAllBytes(Path.Combine(dst, Path.GetFileName(file)), f.Save());
                    changedUnder[name] = f;
                    changedFiles++; log.Add(name + ": " + string.Join(", ", what));
                }
            }
            // Village files: river pieces in them become the meadow of the changed island below, bridges road.
            if (o.NoRivers)
                foreach (var kv in villages)
                    foreach (var v in kv.Value)
                    {
                        Island under; changedUnder.TryGetValue(kv.Key, out under);
                        if (!RemoveRivers(v.Value, under)) continue;
                        string dst = Path.Combine(outDir, Path.GetDirectoryName(v.Key)); Directory.CreateDirectory(dst);
                        File.WriteAllBytes(Path.Combine(dst, Path.GetFileName(v.Key)), v.Value.Save());
                        changedFiles++; log.Add(v.Key + ": rivers (village)");
                    }
            if (o.GiantPerClimate > 0) giants = Giants.Build(gameDir, outDir, o, log);
            log.Add(string.Format("SUMMARY changed={0} giant={1}", changedFiles, giants));
            return log;
        }
    }

    // Giant islands: larger than the largest class of the game ("lar", 100 x 90). Each one grows from an island of
    // the game: its outline is smoothed and enlarged; coast, beach, surf and the depth of the sea are laid anew with
    // the rules that all whole islands of the game follow (learned from them: which piece and turn a tile gets for
    // the land and water around it); meadow, forest, mountains (rock with slopes) and deer come from the model.
    // Giant islands have no rivers. They are written as lar20, lar21, ... in Nord\ and Sued\ (same size in both,
    // because the game picks the climate by position).
    public static class Giants
    {
        public static readonly int[][] Sizes = { new[] { 150, 130 }, new[] { 140, 140 }, new[] { 160, 125 }, new[] { 135, 120 }, new[] { 155, 140 }, new[] { 145, 125 }, new[] { 160, 140 }, new[] { 140, 120 } };
        static readonly int[][] N8 = { new[] { 1, 0 }, new[] { -1, 0 }, new[] { 0, 1 }, new[] { 0, -1 }, new[] { 1, 1 }, new[] { 1, -1 }, new[] { -1, 1 }, new[] { -1, -1 } };
        static readonly HashSet<string> WaterKinds = new HashSet<string> { "MEER", "BRANDUNG", "BRANDECK", "MUENDUNG" };
        static readonly HashSet<string> PlateauKinds = new HashSet<string> { "FELS", "HANG", "HANGECK", "HANGQUELL" };

        // Learned rules: key -> samples (id, bits) of the dominant kind and turn.
        static Dictionary<string, List<Entry>> rules;

        static bool IsWater(int id)
        {
            string k = Houses.Kind(id);
            if (WaterKinds.Contains(k)) return true;
            return id >= 1231 && id <= 1240;     // small rocks in the sea in front of the coast
        }

        static bool[,] LandMask(Island f, int[,] g)
        {
            var m = new bool[f.W, f.H];
            for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++) m[x, y] = g[x, y] >= 0 && !IsWater(f.E[g[x, y]].Id);
            return m;
        }

        static int Mask8(bool[,] land, int x, int y, int W, int H)
        {
            int m = 0;
            for (int k = 0; k < 8; k++) { int nx = x + N8[k][0], ny = y + N8[k][1]; bool l = nx >= 0 && ny >= 0 && nx < W && ny < H && land[nx, ny]; if (l) m |= 1 << k; }
            return m;
        }

        // Chebyshev distance of water cells to land (capped at 9); 0 on land.
        static int[,] WaterDistance(bool[,] land, int W, int H)
        {
            var d = new int[W, H]; var q = new Queue<int>();
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) { d[x, y] = land[x, y] ? 0 : int.MaxValue; if (land[x, y]) q.Enqueue(x * 1000 + y); }
            while (q.Count > 0)
            {
                int v = q.Dequeue(), x = v / 1000, y = v % 1000;
                foreach (var n in N8) { int nx = x + n[0], ny = y + n[1]; if (nx >= 0 && ny >= 0 && nx < W && ny < H && d[nx, ny] == int.MaxValue) { d[nx, ny] = d[x, y] + 1; q.Enqueue(nx * 1000 + ny); } }
            }
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) if (d[x, y] > 9) d[x, y] = 9;
            return d;
        }

        static string Key(bool[,] land, int[,] wd, int x, int y, int W, int H)
        {
            if (land[x, y])
            {
                int m = Mask8(land, x, y, W, H);
                return m == 255 ? null : "B" + m;                  // land next to water: beach (or what lies there)
            }
            int d = wd[x, y];
            if (d >= 5) return "D" + Math.Min(d, 9);
            int closer = 0;
            for (int k = 0; k < 8; k++) { int nx = x + N8[k][0], ny = y + N8[k][1]; if (nx >= 0 && ny >= 0 && nx < W && ny < H && wd[nx, ny] < d) closer |= 1 << k; }
            return "W" + d + ":" + closer;
        }

        static void Learn(string gameDir)
        {
            var raw = new Dictionary<string, Dictionary<string, List<Entry>>>();
            foreach (var folder in new[] { "Nord", "Sued" })
            {
                string src = Path.Combine(gameDir, folder); if (!Directory.Exists(src)) continue;
                foreach (var file in Directory.GetFiles(src, "*.scp"))
                {
                    Island f; try { f = Island.Load(file); } catch (Exception) { continue; }
                    if (!Forge.IsWhole(f)) continue;
                    var g = f.Cover(true); var land = LandMask(f, g); var wd = WaterDistance(land, f.W, f.H);
                    for (int x = 1; x < f.W - 1; x++) for (int y = 1; y < f.H - 1; y++)
                    {
                        var e = f.E[g[x, y]]; if (e.X != x || e.Y != y) continue;
                        var s = Houses.Size(e.Id, e.Rot); if (s[0] != 1 || s[1] != 1) continue;
                        string key = Key(land, wd, x, y, f.W, f.H); if (key == null) continue;
                        string kind = Houses.Kind(e.Id);
                        if (key[0] == 'B' && !(kind.StartsWith("STRAND"))) continue;   // only beach pieces are rules for the coast
                        string sub = kind + "/" + e.Rot;
                        Dictionary<string, List<Entry>> byKind;
                        if (!raw.TryGetValue(key, out byKind)) { byKind = new Dictionary<string, List<Entry>>(); raw[key] = byKind; }
                        List<Entry> list; if (!byKind.TryGetValue(sub, out list)) { list = new List<Entry>(); byKind[sub] = list; }
                        list.Add(e.Copy());
                    }
                }
            }
            rules = new Dictionary<string, List<Entry>>();
            foreach (var kv in raw)
            {
                var best = kv.Value.OrderByDescending(p => p.Value.Count).First();
                int total = kv.Value.Sum(p => p.Value.Count);
                if (best.Value.Count * 2 < total && kv.Key[0] == 'B') continue;   // ambiguous coast shape: not used
                rules[kv.Key] = best.Value;
            }
        }

        // For the tests: coast and first-row water tiles of an island whose shape has no learned rule (-1: rules not
        // learned yet, they are learned by Build with giant islands).
        public static int CountTilesWithoutRule(Island f)
        {
            if (rules == null) return -1;
            var g = f.Cover(true); var land = LandMask(f, g); var wd = WaterDistance(land, f.W, f.H); int n = 0;
            for (int x = 1; x < f.W - 1; x++) for (int y = 1; y < f.H - 1; y++)
            {
                string key = Key(land, wd, x, y, f.W, f.H);
                if (key == null || key[0] == 'D' || (key[0] == 'W' && key[1] != '1')) continue;
                if (!rules.ContainsKey(key)) n++;
            }
            return n;
        }

        static double Sample(double[,] a, double x, double y, int W, int H)
        {
            x = Math.Max(0, Math.Min(W - 1.001, x)); y = Math.Max(0, Math.Min(H - 1.001, y));
            int x0 = (int)x, y0 = (int)y; double fx = x - x0, fy = y - y0;
            return a[x0, y0] * (1 - fx) * (1 - fy) + a[x0 + 1, y0] * fx * (1 - fy) + a[x0, y0 + 1] * (1 - fx) * fy + a[x0 + 1, y0 + 1] * fx * fy;
        }

        static double[,] Blur(double[,] a, int W, int H, int r)
        {
            var b = new double[W, H];
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++)
            {
                double s = 0; int n = 0;
                for (int dx = -r; dx <= r; dx++) for (int dy = -r; dy <= r; dy++) { int nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < W && ny < H) { s += a[nx, ny]; n++; } }
                b[x, y] = s / n;
            }
            return b;
        }

        static uint BitsFor(Entry sample, int rot, int islandNr)
        {
            return (sample.Bits & ~(3u | (0xFFu << 6))) | (uint)(rot & 3) | ((uint)islandNr << 6);
        }

        // Builds one giant island from the model 'src'. Returns null if no valid coast came out.
        public static Island Make(Island src, int W, int H, int seed, out string why)
        {
            why = "";
            var rnd = new Random(seed);
            var gs = src.Cover(true); var sland = LandMask(src, gs);
            // Outline: land of the model (rivers count as land), blurred, enlarged, a little noise, threshold.
            var lf = new double[src.W, src.H]; var ff = new double[src.W, src.H];
            for (int x = 0; x < src.W; x++) for (int y = 0; y < src.H; y++)
            {
                lf[x, y] = sland[x, y] ? 1 : 0;
                ff[x, y] = Houses.Kind(src.E[gs[x, y]].Id) == "WALD" ? 1 : 0;
            }
            lf = Blur(lf, src.W, src.H, 1); ff = Blur(ff, src.W, src.H, 1);
            double sx = (double)(src.W - 1) / (W - 1), sy = (double)(src.H - 1) / (H - 1);
            var land = new bool[W, H];
            var noise = new double[W, H];
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) noise[x, y] = rnd.NextDouble();
            noise = Blur(noise, W, H, 2);
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++)
                land[x, y] = x >= 3 && y >= 3 && x < W - 3 && y < H - 3 && Sample(lf, x * sx, y * sy, src.W, src.H) + (noise[x, y] - 0.5) * 0.25 > 0.5;
            // Clean the outline until every coast and water tile has a rule (at most 60 rounds).
            int[,] wd = null; int bad = 0;
            for (int round = 0; round < 60; round++)
            {
                // Smooth: a land tile needs 2 land neighbours in line (no single spikes), water likewise.
                for (int x = 1; x < W - 1; x++) for (int y = 1; y < H - 1; y++)
                {
                    int n4 = (land[x + 1, y] ? 1 : 0) + (land[x - 1, y] ? 1 : 0) + (land[x, y + 1] ? 1 : 0) + (land[x, y - 1] ? 1 : 0);
                    if (land[x, y] && n4 <= 1) land[x, y] = false;
                    else if (!land[x, y] && n4 >= 3) land[x, y] = true;
                }
                wd = WaterDistance(land, W, H); bad = 0;
                var flip = new List<int>();
                for (int x = 1; x < W - 1; x++) for (int y = 1; y < H - 1; y++)
                {
                    string key = Key(land, wd, x, y, W, H);
                    if (key == null || key[0] == 'D' || rules.ContainsKey(key)) continue;
                    if (key[0] == 'W' && key[1] != '1') continue;      // deeper water: fallback by distance below
                    bad++; flip.Add(x * 1000 + y);
                }
                if (bad == 0) break;
                foreach (int v in flip)
                {
                    int x = v / 1000, y = v % 1000;
                    int n8 = 0; foreach (var n in N8) if (land[x + n[0], y + n[1]]) n8++;
                    land[x, y] = n8 >= 4;                              // the side with more neighbours wins
                    if (land[x, y]) foreach (var n in N8) land[x + n[0], y + n[1]] = land[x + n[0], y + n[1]] || n8 >= 6;
                }
            }
            if (bad > 0) { why = bad + " coast tiles without a rule"; return null; }
            // Header from the model; size, class 4 (lar), not "original" content flags kept as the model has them.
            var f = new Island();
            for (int i = 0; i < src.Names.Count; i++)
            {
                if (src.Names[i] == "INSELHAUS" && i != src.HausIndex) continue;
                f.Names.Add(src.Names[i]); f.Data.Add((byte[])src.Data[i].Clone());
                if (i == src.HeaderIndex) f.HeaderIndex = f.Names.Count - 1;
                if (i == src.HausIndex) f.HausIndex = f.Names.Count - 1;
            }
            f.HausCount = 1; f.W = W; f.H = H;
            var h = f.Header; h[1] = (byte)W; h[2] = (byte)H;
            if (h.Length >= 102) { BitConverter.GetBytes((ushort)4).CopyTo(h, 98); h[23] = 0; for (int i = 60; i < 92; i++) h[i] = 0; }
            int nr = h[0];
            // Samples for meadow and forest from the model.
            var meadow = src.E.Where(e => Houses.Kind(e.Id) == "BODEN" && Houses.Size(e.Id, 0)[0] == 1 && Houses.Size(e.Id, 0)[1] == 1).ToList();
            var forest = src.E.Where(e => Houses.Kind(e.Id) == "WALD").ToList();
            if (meadow.Count == 0 || forest.Count == 0) { why = "model without meadow or forest"; return null; }
            // Forest: each tile by the density of the model's forest around the same (enlarged) spot, so the forest
            // keeps the model's speckled look and share.
            var forestAt = new bool[W, H];
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++) forestAt[x, y] = rnd.NextDouble() < Math.Min(1.0, Sample(ff, x * sx, y * sy, src.W, src.H) * 1.05);
            f.E = new List<Entry>();
            var occupied = new bool[W, H];
            // Mountains: the model's rock-and-slope groups, at their enlarged place (or close to it), and the same
            // groups once more at random places, so that the larger island has about as much rock per area.
            var plateaus = Plateaus(src, gs);
            double areaFactor = (double)(W * H) / (src.W * src.H);
            int copies = Math.Max(1, (int)Math.Round(areaFactor));
            for (int c = 0; c < copies; c++)
                foreach (var p in plateaus)
                {
                    int bw = p.Max(e => e.X + Houses.Size(e.Id, e.Rot)[0]) - p.Min(e => e.X), bh = p.Max(e => e.Y + Houses.Size(e.Id, e.Rot)[1]) - p.Min(e => e.Y);
                    int px0 = p.Min(e => e.X), py0 = p.Min(e => e.Y);
                    int tx = c == 0 ? (int)(px0 / sx) : rnd.Next(3, Math.Max(4, W - bw - 3)), ty = c == 0 ? (int)(py0 / sy) : rnd.Next(3, Math.Max(4, H - bh - 3));
                    PlacePlateau(f, land, occupied, p, px0, py0, tx, ty, nr);
                }
            // Every other tile: water by the rules, beach by the rules, inside meadow or forest.
            for (int x = 0; x < W; x++) for (int y = 0; y < H; y++)
            {
                if (occupied[x, y]) continue;
                Entry pickE; int rot;
                string key = Key(land, wd, x, y, W, H);
                if (key == null)
                {
                    var list = forestAt[x, y] ? forest : meadow; pickE = list[rnd.Next(list.Count)]; rot = pickE.Rot;
                }
                else
                {
                    List<Entry> list = null;
                    if (!rules.TryGetValue(key, out list) && key[0] != 'B')
                    {
                        string prefix = key[0] == 'D' ? "D" : "W" + key[1] + ":";
                        var best = rules.Where(r => r.Key.StartsWith(prefix)).OrderByDescending(r => r.Value.Count).FirstOrDefault();
                        list = best.Value;
                        if (list == null) { var d9 = rules.Where(r => r.Key.StartsWith("D")).OrderByDescending(r => r.Value.Count).FirstOrDefault(); list = d9.Value; }
                    }
                    if (list == null) { why = "no rule for " + key; return null; }
                    pickE = list[rnd.Next(list.Count)]; rot = pickE.Rot;
                }
                f.E.Add(new Entry { Id = pickE.Id, X = x, Y = y, Bits = BitsFor(pickE, rot, nr) });
            }
            // Deer: the model's places, enlarged, on meadow or forest.
            int hk = f.Names.IndexOf("HIRSCH2");
            if (hk >= 0)
            {
                var d = f.Data[hk]; var outD = new List<byte>(); var g = f.Cover(true);
                for (int i = 0; i + 8 <= d.Length; i += 8)
                {
                    int x = (int)(d[i + 1] / sx), y = (int)(d[i + 2] / sy);
                    if (x <= 0 || y <= 0 || x >= W || y >= H) continue;
                    string k = Houses.Kind(f.E[g[x, y]].Id); if (k != "WALD" && k != "BODEN") continue;
                    var e8 = new byte[8]; Array.Copy(d, i, e8, 0, 8); e8[0] = (byte)nr; e8[1] = (byte)x; e8[2] = (byte)y; outD.AddRange(e8);
                }
                f.Data[hk] = outD.ToArray();
            }
            f.Cover(true);
            return f;
        }

        // Groups of rock and slope pieces of an island (8-connected), each as its list of entries.
        static List<List<Entry>> Plateaus(Island f, int[,] g)
        {
            var seen = new bool[f.W, f.H]; var result = new List<List<Entry>>();
            Func<int, int, bool> isP = (x, y) => { var e = f.E[g[x, y]]; return e.Id != 2211 && PlateauKinds.Contains(Houses.Kind(e.Id)); };
            for (int x = 0; x < f.W; x++) for (int y = 0; y < f.H; y++)
            {
                if (seen[x, y] || !isP(x, y)) continue;
                var idx = new HashSet<int>(); var q = new Queue<int>(); q.Enqueue(x * 1000 + y); seen[x, y] = true;
                while (q.Count > 0)
                {
                    int v = q.Dequeue(), cx = v / 1000, cy = v % 1000; idx.Add(g[cx, cy]);
                    foreach (var n in N8) { int nx = cx + n[0], ny = cy + n[1]; if (nx >= 0 && ny >= 0 && nx < f.W && ny < f.H && !seen[nx, ny] && isP(nx, ny)) { seen[nx, ny] = true; q.Enqueue(nx * 1000 + ny); } }
                }
                // The spring of a river becomes a plain slope (giant islands have no rivers).
                result.Add(idx.Select(i => { var e = f.E[i].Copy(); if (e.Id == 2311) e.Id = 2302; return e; }).ToList());
            }
            return result;
        }

        // Places a group with its top left corner near (tx, ty): only on inner land (two tiles away from the
        // water), not touching another group; searches in rings up to 25 tiles around the wanted spot.
        static bool PlacePlateau(Island f, bool[,] land, bool[,] occupied, List<Entry> p, int px0, int py0, int tx, int ty, int nr)
        {
            int W = f.W, H = f.H;
            var cells = new List<int[]>();
            foreach (var e in p) { var s = Houses.Size(e.Id, e.Rot); for (int dx = 0; dx < s[0]; dx++) for (int dy = 0; dy < s[1]; dy++) cells.Add(new[] { e.X - px0 + dx, e.Y - py0 + dy }); }
            for (int r = 0; r <= 25; r++)
                for (int ox = tx - r; ox <= tx + r; ox++) for (int oy = ty - r; oy <= ty + r; oy++)
                {
                    if (Math.Max(Math.Abs(ox - tx), Math.Abs(oy - ty)) != r) continue;
                    bool ok = true;
                    foreach (var c in cells)
                    {
                        int x = ox + c[0], y = oy + c[1];
                        for (int dx = -2; dx <= 2 && ok; dx++) for (int dy = -2; dy <= 2 && ok; dy++)
                        {
                            int nx = x + dx, ny = y + dy;
                            if (nx < 0 || ny < 0 || nx >= W || ny >= H || !land[nx, ny]) ok = false;
                            else if (Math.Abs(dx) <= 1 && Math.Abs(dy) <= 1 && occupied[nx, ny]) ok = false;
                        }
                        if (!ok) break;
                    }
                    if (!ok) continue;
                    foreach (var e in p) f.E.Add(new Entry { Id = e.Id, X = e.X - px0 + ox, Y = e.Y - py0 + oy, Bits = BitsFor(e, e.Rot, nr) });
                    foreach (var c in cells) occupied[ox + c[0], oy + c[1]] = true;
                    return true;
                }
            return false;
        }

        public static int Build(string gameDir, string outDir, Options o, List<string> log)
        {
            if (rules == null) Learn(gameDir);
            int made = 0;
            foreach (var folder in new[] { "Nord", "Sued" })
            {
                string src = Path.Combine(gameDir, folder); if (!Directory.Exists(src)) continue;
                var models = Directory.GetFiles(src, "lar*.scp").Concat(Directory.GetFiles(src, "big*.scp"))
                    .Where(p => !Path.GetFileName(p).Equals("lar.scp", StringComparison.OrdinalIgnoreCase) && !Path.GetFileName(p).Equals("big.scp", StringComparison.OrdinalIgnoreCase))
                    .OrderBy(p => Path.GetFileName(p).StartsWith("lar", StringComparison.OrdinalIgnoreCase) ? 0 : 1).ThenBy(p => p, StringComparer.OrdinalIgnoreCase).ToList();
                int k = 0, m = 0;
                while (k < o.GiantPerClimate && m < models.Count)
                {
                    Island model; string mname = Path.GetFileName(models[m]); m++;
                    try { model = Island.Load(models[m - 1]); } catch (Exception) { continue; }
                    // Only whole islands in the current format (INSEL4/5, 116-byte header with file number and class).
                    if (!Forge.IsWhole(model) || model.HausCount != 1 || model.Header.Length < 102) continue;
                    var size = Sizes[k % Sizes.Length]; string why;
                    var g = Make(model, size[0], size[1], 1602 + k * 31 + (folder == "Sued" ? 7 : 0), out why);
                    if (g == null) { log.Add(folder + "\\" + mname + ": no giant (" + why + ")"); continue; }
                    if (o.EdgeMountains) Forge.MoveMountains(g, 3, null, Forge.RockLibrary(gameDir, folder));
                    var h = g.Header; if (h.Length >= 102) { BitConverter.GetBytes((ushort)(Forge.GiantFirstNumber + k)).CopyTo(h, 96); h[100] = (byte)(folder == "Sued" ? 1 : 0); }
                    string name = "lar" + (Forge.GiantFirstNumber + k) + ".scp";
                    string dst = Path.Combine(outDir, folder); Directory.CreateDirectory(dst);
                    File.WriteAllBytes(Path.Combine(dst, name), g.Save());
                    log.Add(folder + "\\" + name + ": giant " + size[0] + "x" + size[1] + " from " + mname);
                    k++; made++;
                }
            }
            return made;
        }
    }
}
