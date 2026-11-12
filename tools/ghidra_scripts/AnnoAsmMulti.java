// Gibt Maschinenbefehle fuer mehrere Bereiche aus und dazu jede Stelle, die eine Adresse liest
// oder schreibt (mit Umgebung). Argumente:
//   <outdir> <name> ref.<adresse>:<davor>:<danach> ... <adresse>:<anzahl> ...
//@category Anno1602

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;

public class AnnoAsmMulti extends GhidraScript {

    private void line(PrintWriter pw, Instruction ins) throws Exception {
        StringBuilder hex = new StringBuilder();
        for (byte b : ins.getBytes()) { hex.append(String.format("%02X ", b)); }
        pw.printf("%s  %-36s %s%n", ins.getAddress(), hex.toString().trim(), ins.toString());
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        File out = new File(args[0], args[1] + ".txt");
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            for (int i = 2; i < args.length; i++) {
                String a = args[i];
                if (a.startsWith("ref.")) {
                    String[] p = a.substring(4).split(":");
                    Address t = toAddr(p[0]);
                    int vor = Integer.parseInt(p[1]), nach = Integer.parseInt(p[2]);
                    for (Reference r : getReferencesTo(t)) {
                        Instruction ins = getInstructionAt(r.getFromAddress());
                        if (ins == null) { continue; }
                        Function f = getFunctionContaining(ins.getAddress());
                        pw.printf("== Zugriff %s auf %s in %s (%s)%n", r.getFromAddress(), t,
                                f == null ? "?" : f.getName(), r.getReferenceType());
                        Instruction s = ins;
                        for (int k = 0; k < vor && s.getPrevious() != null; k++) { s = s.getPrevious(); }
                        for (int k = 0; k < vor + nach + 1 && s != null; k++) { line(pw, s); s = s.getNext(); }
                    }
                } else {
                    String[] p = a.split(":");
                    Address s0 = toAddr(p[0]);
                    int n = Integer.parseInt(p[1]);
                    pw.printf("== Bereich %s (%d Befehle)%n", s0, n);
                    Instruction ins = getInstructionAt(s0);
                    if (ins == null) { ins = getInstructionAfter(s0); }
                    for (int k = 0; k < n && ins != null; k++) { line(pw, ins); ins = ins.getNext(); }
                }
            }
        }
    }
}
