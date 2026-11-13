<#
.SYNOPSIS
  Reads the island table from the running Anno1602.exe (read only): count, sizes, ore deposits
  and fertility. For tests in the game.
  Island table: 50 slots from RVA 0x62DDC0, 0x2CC8 bytes each; width/height +0xC/+0x10, tile grid +0x2CB0,
  ore deposits +0x41 (byte), fertility +0x5C (bit mask, set in the SZENE loader FUN_1400d0de0).
#>
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class IslandMem { [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool i, int p); [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr a, byte[] b, IntPtr s, out IntPtr d); [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h); }'
$p = Get-Process -Name 'Anno1602' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'Game is not running.'; return }
$b = $p.MainModule.BaseAddress.ToInt64(); $h = [IslandMem]::OpenProcess(0x0410, $false, $p.Id)
try {
    $n = 0; $area = 0; $ore = 0; $oreIslands = 0; $bits = 0; $sizes = @{}
    for ($i = 0; $i -lt 50; $i++) {
        $is = New-Object byte[] 0x2CC8; $d = [IntPtr]::Zero
        [void][IslandMem]::ReadProcessMemory($h, [IntPtr]($b + 0x62DDC0 + $i * 0x2CC8), $is, [IntPtr]$is.Length, [ref]$d)
        if ([BitConverter]::ToInt64($is, 0x2CB0) -eq 0) { continue }
        $n++; $w = [BitConverter]::ToInt32($is, 12); $hh = [BitConverter]::ToInt32($is, 16); $area += $w * $hh
        $k = "${w}x${hh}"; $sizes[$k] = 1 + [int]$sizes[$k]
        $ore += $is[0x41]; if ($is[0x41] -gt 0) { $oreIslands++ }
        $m = [BitConverter]::ToUInt32($is, 0x5C); for ($j = 0; $j -lt 32; $j++) { if ($m -band (1 -shl $j)) { $bits++ } }
    }
    "Islands: $n, area of the island rectangles: $($area.ToString('N0')) tiles"
    'Sizes: ' + (($sizes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
    "Ore deposits: $ore on $oreIslands islands; fertilities: $bits"
}
finally { [void][IslandMem]::CloseHandle($h) }
