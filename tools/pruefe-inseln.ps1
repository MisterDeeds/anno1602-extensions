<#
.SYNOPSIS
  Liest aus dem laufenden Anno1602.exe (nur lesend) die Inseltabelle: Zahl, Groessen, Erzvorkommen
  und Fruchtbarkeit. Fuer Tests im Spiel.
  Inseltabelle: 50 Plaetze ab RVA 0x62DDC0, je 0x2CC8 Byte; Breite/Hoehe +0xC/+0x10, Feldraster +0x2CB0,
  Erzvorkommen +0x41 (Byte), Fruchtbarkeit +0x5C (Bitmaske, gesetzt im SZENE-Lader FUN_1400d0de0).
#>
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class InselMem { [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool i, int p); [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr a, byte[] b, IntPtr s, out IntPtr d); [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h); }'
$p = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'Spiel laeuft nicht.'; return }
$b = $p.MainModule.BaseAddress.ToInt64(); $h = [InselMem]::OpenProcess(0x0410, $false, $p.Id)
try {
    $n = 0; $flaeche = 0; $erz = 0; $erzInseln = 0; $bits = 0; $groessen = @{}
    for ($i = 0; $i -lt 50; $i++) {
        $is = New-Object byte[] 0x2CC8; $d = [IntPtr]::Zero
        [void][InselMem]::ReadProcessMemory($h, [IntPtr]($b + 0x62DDC0 + $i * 0x2CC8), $is, [IntPtr]$is.Length, [ref]$d)
        if ([BitConverter]::ToInt64($is, 0x2CB0) -eq 0) { continue }
        $n++; $w = [BitConverter]::ToInt32($is, 12); $hh = [BitConverter]::ToInt32($is, 16); $flaeche += $w * $hh
        $k = "${w}x${hh}"; $groessen[$k] = 1 + [int]$groessen[$k]
        $erz += $is[0x41]; if ($is[0x41] -gt 0) { $erzInseln++ }
        $m = [BitConverter]::ToUInt32($is, 0x5C); for ($j = 0; $j -lt 32; $j++) { if ($m -band (1 -shl $j)) { $bits++ } }
    }
    "Inseln: $n, Flaeche der Inselrechtecke: $($flaeche.ToString('N0')) Felder"
    'Groessen: ' + (($groessen.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
    "Erzvorkommen: $erz auf $erzInseln Inseln; Fruchtbarkeiten: $bits"
}
finally { [void][InselMem]::CloseHandle($h) }
