// Schreibt Bytes nur im Arbeitsspeicher von Ghidra an Adressen (Projekt wird nicht gespeichert)
// und gibt die Rueckuebersetzung aus. Prueft so von Hand kodierten Maschinencode.
// Argumente: <outdir> <name> <adresse> <hexbytes ohne Leerzeichen> [<adresse> <hexbytes> ...]
//@category Anno1602

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;

public class AnnoPatchDis extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        File out = new File(args[0], args[1] + ".txt");
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            for (int i = 2; i + 1 < args.length; i += 2) {
                Address a = toAddr(args[i]);
                String hex = args[i + 1];
                byte[] b = new byte[hex.length() / 2];
                for (int k = 0; k < b.length; k++) {
                    b[k] = (byte) Integer.parseInt(hex.substring(2 * k, 2 * k + 2), 16);
                }
                clearListing(a, a.add(b.length - 1));
                setBytes(a, b);
                disassemble(a);
                pw.printf("== %s (%d Bytes)%n", a, b.length);
                Address end = a.add(b.length);
                Instruction ins = getInstructionAt(a);
                while (ins != null && ins.getAddress().compareTo(end) < 0) {
                    StringBuilder h = new StringBuilder();
                    for (byte x : ins.getBytes()) { h.append(String.format("%02X ", x)); }
                    pw.printf("%s  %-30s %s%n", ins.getAddress(), h.toString().trim(), ins.toString());
                    ins = getInstructionAt(ins.getAddress().add(ins.getLength()));
                }
            }
        }
    }
}
