// Gibt Maschinenbefehle ab einer Adresse aus (Adresse, Bytes, Befehl).
// Argumente: <outdir> <name> <adresse> <anzahl>
//@category Anno1602

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;

public class AnnoAsm extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        File out = new File(args[0], args[1] + ".txt");
        Address a = toAddr(args[2]);
        int n = Integer.parseInt(args[3]);
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            Instruction ins = getInstructionAt(a);
            if (ins == null) { ins = getInstructionAfter(a); }
            for (int i = 0; i < n && ins != null; i++) {
                StringBuilder hex = new StringBuilder();
                for (byte b : ins.getBytes()) { hex.append(String.format("%02X ", b)); }
                pw.printf("%s  %-30s %s%n", ins.getAddress(), hex.toString().trim(), ins.toString());
                ins = ins.getNext();
            }
        }
    }
}
