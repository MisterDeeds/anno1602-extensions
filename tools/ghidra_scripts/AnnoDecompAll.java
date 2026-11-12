// Decompiles all functions into a single text file (to search it with grep).
// Arguments: <outdir>
//@category Anno1602

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class AnnoDecompAll extends GhidraScript {

    @Override
    protected void run() throws Exception {
        File out = new File(getScriptArgs()[0], "all-functions.c");
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        int n = 0, failed = 0;
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
            while (it.hasNext() && !monitor.isCancelled()) {
                Function f = it.next();
                if (f.isExternal() || f.isThunk()) continue;
                DecompileResults r = decomp.decompileFunction(f, 60, monitor);
                pw.printf("%n// ===== %s @ %s (%d bytes)%n", f.getName(), f.getEntryPoint(), f.getBody().getNumAddresses());
                if (r.decompileCompleted()) pw.println(r.getDecompiledFunction().getC());
                else { pw.println("// Decompilation failed: " + r.getErrorMessage()); failed++; }
                n++;
            }
        }
        decomp.dispose();
        println("Decompiled: " + n + ", failed: " + failed);
    }
}
