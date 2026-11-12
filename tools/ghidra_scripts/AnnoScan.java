// Searches Anno1602.exe for map size constants, large static tables in .data
// and functions that use certain strings (chunk names, .cod keywords).
// Writes reports and pseudocode to <outdir>.
//@category Anno1602

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.*;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.lang.OperandType;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.Reference;

public class AnnoScan extends GhidraScript {

    private static final long[] WIDTH = { 500, 499, 1000 };
    private static final long[] HEIGHT = { 350, 349, 700 };
    private static final String[] STRINGS = {
        "MAXHAUS", "MAXFIGUR", "Maxlager", "PLAYER4", "PLAYER3", "INSEL5", "SHIP4",
        "KONTOR2", "SZENE_PLAYERMAX", "Pirat%d", "Native%d", "Trader%d", "haeuser.cod", "figuren.cod"
    };

    private File outDir;
    private DecompInterface decomp;
    private final Set<Function> decompiled = new HashSet<>();

    @Override
    protected void run() throws Exception {
        outDir = new File(getScriptArgs()[0]);
        new File(outDir, "decomp").mkdirs();
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        scanConstants();
        scanDataTables();
        scanStrings();

        decomp.dispose();
    }

    private static boolean in(long v, long[] set) {
        for (long s : set) if (s == v) return true;
        return false;
    }

    /** Immediate values (no address offsets) 500/350 and relatives, grouped by function. */
    private void scanConstants() throws Exception {
        Map<Function, List<String>> hits = new LinkedHashMap<>();
        Map<Function, int[]> kinds = new HashMap<>();
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext() && !monitor.isCancelled()) {
            Instruction ins = it.next();
            for (int op = 0; op < ins.getNumOperands(); op++) {
                if (!OperandType.isScalar(ins.getOperandType(op))) continue;
                Scalar s = ins.getScalar(op);
                if (s == null) continue;
                long v = s.getUnsignedValue();
                boolean w = in(v, WIDTH), h = in(v, HEIGHT);
                if (!w && !h) continue;
                Function f = getFunctionContaining(ins.getAddress());
                if (f == null) continue;
                hits.computeIfAbsent(f, k -> new ArrayList<>()).add(ins.getAddress() + "  " + ins);
                int[] k = kinds.computeIfAbsent(f, x -> new int[2]);
                if (w) k[0]++;
                if (h) k[1]++;
            }
        }
        List<Function> both = new ArrayList<>();
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(outDir, "constants.txt")))) {
            pw.println("Functions with immediate values 500/499/1000 (width) or 350/349/700 (height)");
            pw.println("Format: function  [width hits/height hits]");
            for (Map.Entry<Function, List<String>> e : hits.entrySet()) {
                int[] k = kinds.get(e.getKey());
                if (k[0] > 0 && k[1] > 0) both.add(e.getKey());
                pw.printf("%n%s @ %s  [%d/%d]%s%n", e.getKey().getName(), e.getKey().getEntryPoint(), k[0], k[1],
                    (k[0] > 0 && k[1] > 0) ? "  <-- both" : "");
                for (String line : e.getValue()) pw.println("    " + line);
            }
            pw.printf("%nFunctions with hits: %d, of these with width AND height: %d%n", hits.size(), both.size());
        }
        both.sort(Comparator.comparingInt(f -> -(kinds.get(f)[0] + kinds.get(f)[1])));
        for (Function f : both.subList(0, Math.min(30, both.size()))) writeDecomp(f, "size");
    }

    /** Referenced addresses in .data; distance to the next reference = upper bound of the object size. */
    private void scanDataTables() throws Exception {
        MemoryBlock data = currentProgram.getMemory().getBlock(".data");
        Address start = data.getStart();
        long initEnd = start.getOffset() + 14336; // raw part in the file
        TreeMap<Long, Set<Function>> refs = new TreeMap<>();
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext() && !monitor.isCancelled()) {
            Instruction ins = it.next();
            for (Reference r : ins.getReferencesFrom()) {
                Address to = r.getToAddress();
                if (!data.contains(to)) continue;
                Function f = getFunctionContaining(ins.getAddress());
                refs.computeIfAbsent(to.getOffset(), k -> new HashSet<>());
                if (f != null) refs.get(to.getOffset()).add(f);
            }
        }
        List<long[]> objs = new ArrayList<>();
        Long prev = null;
        for (Long a : refs.keySet()) {
            if (prev != null) objs.add(new long[] { prev, a - prev });
            prev = a;
        }
        if (prev != null) objs.add(new long[] { prev, data.getEnd().getOffset() + 1 - prev });
        objs.sort((x, y) -> Long.compare(y[1], x[1]));
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(outDir, "data-tables.txt")))) {
            pw.printf("Referenced addresses in .data: %d%n", refs.size());
            pw.println("Largest gaps to the next referenced address (upper bound of the table size):");
            pw.println("Address         Bytes       Init  Functions   Examples");
            for (long[] o : objs.subList(0, Math.min(60, objs.size()))) {
                Set<Function> fs = refs.get(o[0]);
                StringBuilder ex = new StringBuilder();
                int n = 0;
                for (Function f : fs) { if (n++ == 4) break; ex.append(f.getName()).append(' '); }
                pw.printf("0x%x  %10d  %-4s  %10d  %s%n", o[0], o[1], o[0] < initEnd ? "yes" : "no", fs.size(), ex);
            }
        }
    }

    /** Decompile the functions that reference certain strings. */
    private void scanStrings() throws Exception {
        try (PrintWriter pw = new PrintWriter(new FileWriter(new File(outDir, "strings.txt")))) {
            DataIterator di = currentProgram.getListing().getDefinedData(true);
            while (di.hasNext() && !monitor.isCancelled()) {
                Data d = di.next();
                if (!d.hasStringValue()) continue;
                Object v = d.getValue();
                if (v == null) continue;
                String s = v.toString();
                for (String want : STRINGS) {
                    if (!s.equals(want)) continue;
                    pw.printf("%n\"%s\" @ %s%n", s, d.getAddress());
                    for (Reference r : getReferencesTo(d.getAddress())) {
                        Function f = getFunctionContaining(r.getFromAddress());
                        pw.printf("    from %s in %s%n", r.getFromAddress(), f == null ? "?" : f.getName() + " @ " + f.getEntryPoint());
                        if (f != null) writeDecomp(f, "text_" + want.replaceAll("[^A-Za-z0-9]", ""));
                    }
                }
            }
        }
    }

    private void writeDecomp(Function f, String tag) throws Exception {
        if (!decompiled.add(f)) return;
        DecompileResults r = decomp.decompileFunction(f, 120, monitor);
        File out = new File(outDir, "decomp/" + tag + "_" + f.getEntryPoint() + ".c");
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            pw.printf("// %s @ %s  (%d bytes)%n", f.getName(), f.getEntryPoint(), f.getBody().getNumAddresses());
            pw.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// Decompilation failed: " + r.getErrorMessage());
        }
    }
}
