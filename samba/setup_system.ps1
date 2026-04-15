# disable password complexity
secedit /export /cfg C:\secpol.cfg
(Get-Content C:\secpol.cfg) -replace "PasswordComplexity = 1", "PasswordComplexity = 0" | Set-Content C:\secpol.cfg
secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /quiet
Remove-Item C:\secpol.cfg

# enable builtin admin
net user Administrator /active:yes
net user Administrator "<SUA_SENHA>"

# remove itself when done
Remove-Item "C:\setup_system.ps1" -Force
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v Setup /f
