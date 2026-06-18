@echo off

drvload X:\virtio-win\NetKVM\2k25\amd64\netkvm.inf
drvload X:\virtio-win\viostor\2k25\amd64\viostor.inf
drvload X:\virtio-win\vioscsi\2k25\amd64\vioscsi.inf

wpeinit
wpeutil disablefirewall

ipconfig

X:\tools\pwsh\pwsh.exe -NoExit -Command "& X:\tools\listener.ps1"