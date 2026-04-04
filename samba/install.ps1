diskpart /s diskpart.txt
dism /Apply-Image /ImageFile:"Z:\win2k25.wim" /Index:4 /ApplyDir:"C:\"
dism /image:"C:\" /Add-Driver /Driver:"Z:\virtio-extracted\vioscsi\2k25\amd64\vioscsi.inf"
dism /image:"C:\" /Add-Driver /Driver:"Z:\virtio-extracted\viostor\2k25\amd64\viostor.inf"
dism /image:"C:\" /Add-Driver /Driver:"Z:\virtio-extracted\NetKVM\2k25\amd64\netkvm.inf"
bcdboot C:\Windows /s E: /f UEFI
reg load HKLM\OFFLINE C:\Windows\System32\config\SOFTWARE

# run setup script on first boot
reg add "HKLM\OFFLINE\Microsoft\Windows\CurrentVersion\Run" /v Setup /t REG_SZ /d "powershell -ExecutionPolicy Bypass -File C:\setup_system.ps1" /f

cp z:\setup_system.ps1 c:\setup_system.ps1
cp z:\first_logon.ps1 c:\first_logon.ps1
mkdir c:\windows\panther
cp z:\unattend.xml c:\windows\panther\unattend.xml

reg unload HKLM\OFFLINE
