# windows-vm-provisioner

Pipeline completo para provisionamento automatizado de VMs Windows via QEMU/KVM no Linux.
Cria uma ISO WinPE customizada com suporte UEFI, sobe a VM com hardware emulado e realiza
a instalação desassistida do Windows com drivers VirtIO e particionamento automático.

## Visão geral
build_winpe.sh → winpe_uefi.iso  
↓  
win.sh [drive] [os_iso] [virtio_iso] [unattend_iso]  
↓  
Windows instalado e configurado  

## Pré-requisitos

- `qemu` / `qemu-system-x86_64`  
- `swtpm` (TPM emulado)  
- `mkwinpeimg` (do pacote `wimlib`)  
- `xorriso`  
- `edk2-ovmf` (firmware UEFI)  
- ISO do Windows (testado com Windows Server 2025 Eval)  
- ISO do [VirtIO drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/)  
- Samba configurado com compartilhamento `winpe` acessível em `\\10.0.2.2\winpe`  
  - Usuário: `winpe` / Senha: `winpe` (ou ajuste em `startnet.cmd`)  
  - O compartilhamento deve conter: `install.ps1`, `diskpart.txt`, `unattend.xml`,  
    `setup_system.ps1`, `win2k25.wim` e os drivers VirtIO extraídos  

## Estrutura
```
.  
├── recreate_winpe_uefi.sh       # Gera a ISO WinPE customizada com suporte UEFI  
├── win.sh                # Sobe a VM via QEMU com TPM, UEFI e modo spoof opcional  
├── overlay/  
│   └── Windows/System32/startnet.cmd  # Inicialização do WinPE: carrega drivers, monta Samba e inicia PowerShell 7
│   └── tools/pwsh       # PowerShell 7 que vai ser usado no ambiente do WinPE
├── samba/
│   └── install.ps1          # Script PowerShell executado no WinPE para aplicar a imagem
│   └── diskpart.txt         # Particionamento GPT (EFI + Windows)  
│   └── unattend.xml         # Instalação desassistida (OOBE, autologon, first logon)  
└── └── setup_system.ps1     # Configurações pós-instalação (executado no primeiro boot)  

```

## Uso

### 1. Gerar a ISO WinPE
```bash
./build_winpe.sh
# Gera: winpe_uefi.iso
```

Necessário ter a ISO do Windows no mesmo diretório como `win2025-eval.iso` e os arquivos
do diretório `overlay/` prontos.

### 2. Configurar a senha

Antes de usar, defina a senha do Administrator em `unattend.xml` e `setup_system.ps1`:
```xml
<!-- unattend.xml -->
<Value><ADMINISTRATOR_PASSWORD></Value>
```
```powershell
# setup_system.ps1
net user Administrator "<ADMINISTRATOR_PASSWORD>"
```

### 3. Subir a VM
```bash
./vm.sh /dev/sdX win2025-eval.iso virtio-win.iso unattend.iso
```

**Modo spoof** — emula hardware Dell OptiPlex com SMBIOS, MAC e serial aleatórios:
```bash
SPOOF=1 ./vm.sh /dev/sdX win2025-eval.iso virtio-win.iso unattend.iso
```

## O que acontece durante a instalação

1. WinPE inicializa via UEFI
2. `install.ps1` executa automaticamente:
   - Particiona o disco via `diskpart`
   - Aplica a imagem Windows via DISM
   - Injeta drivers VirtIO (vioscsi, viostor, NetKVM)
   - Configura boot UEFI via `bcdboot`
   - Registra `setup_system.ps1` pra rodar no primeiro boot
3. VM reinicia no Windows instalado
4. `setup_system.ps1` finaliza a configuração e se auto-remove

## Notas

- O firmware UEFI (`OVMF_CODE.fd` / `OVMF_VARS.fd`) é copiado pra um diretório temporário
  por execução — a VM não modifica o arquivo original
- O TPM é emulado via `swtpm` e encerrado automaticamente ao fim da sessão
- Modo spoof (`SPOOF=1`) usa VGA padrão + e1000e; modo normal usa VirtIO + SPICE
- O WinPE monta automaticamente o compartilhamento Samba do host (`10.0.2.2` é o gateway padrão da rede NAT do QEMU) — todos os scripts e a imagem `.wim` são lidos de lá, sem precisar embutir na ISO
- O compartilhamento Samba usa `10.0.2.2` (gateway NAT padrão do QEMU). Para usar fora do QEMU ou com rede diferente, ajuste o endereço em `overlay/Windows/System32/startnet.cmd`
