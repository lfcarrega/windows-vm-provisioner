@echo off
drvload X:\Windows\System32\drivers\netkvm.inf
drvload X:\Windows\System32\drivers\viostor.inf
drvload X:\Windows\System32\drivers\vioscsi.inf
wpeinit
net use Z: \\10.0.2.2\winpe /user:winpe winpe
X:\tools\pwsh\pwsh.exe -NoExit -Command "Write-Host 'Windows PE with PowerShell 7' -ForegroundColor Green; Z:"
