#!/usr/bin/env bash
[[ -n "$DEBUG" ]] && set -x

target_drive="$1"
os_iso="$2"
virtio_iso="$3"
unattend_iso="$4"

ovmf_code="/usr/share/edk2-ovmf/OVMF_CODE.fd"
ovmf_vars="/usr/share/edk2-ovmf/OVMF_VARS.fd"
tpm_dir="/tmp/qemu-$$/tpm"
tmp_dir="/tmp/qemu-$$"

cpu_model="Skylake-Client-noTSX-IBRS"
cpu_vendor="GenuineIntel"

create_lv() {
  local thin=1
  local encrypt=1
  local lv="thin_pool"
  local vg="nvme_vg25186"
  local name="winpe"
  local lv_path="/dev/mapper/${vg}-${name}"
  local size="100G"
  local keyfile="/etc/keys/${name}.key"
  local luks="/dev/mapper/luks-${name}"
  if ! "$(lvs ${vg}/${name})"; then
    lvcreate -n "${name}" -V "${size}" --thinpool "${lv}" "${vg}"
  fi
  if [[ ! -f "${keyfile}" ]]; then
    dd if=/dev/urandom of="${keyfile}" bs=1 count=4096
  fi
  if [[ -b "$(readlink -f ${lv_path})" ]]; then
    if grep "$(cryptsetup luksDump "${lv_path}")"; then
      cryptsetup luksFormat "${lv_path}" "${keyfile}"
    fi
    cryptsetup open "${lv_path}" --key-file "${keyfile}" "luks-${name}"
  fi
}

cleanup() {
  echo "Cleaning up..."
  pkill -P $$ swtpm 2>/dev/null
  rm -rf "$tmp_dir" "$tpm_dir"
}
trap cleanup EXIT

mkdir -p "$tpm_dir" "$tmp_dir"
cp "$ovmf_vars" "$tmp_dir/ovmf_vars.fd"

swtpm socket \
  --tpmstate dir="$tpm_dir" \
  --ctrl type=unixio,path="$tpm_dir/swtpm-sock" \
  --tpm2 \
  --daemon

qemu_args=(
  -enable-kvm
  -m 8192
  -smp 4
  -drive file="$target_drive",format=raw,if=none,id=disk0
  -drive file="$os_iso",media=cdrom
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code"
  -drive if=pflash,format=raw,file="$tmp_dir/ovmf_vars.fd"
  -chardev socket,id=chrtpm,path="$tpm_dir/swtpm-sock"
  -tpmdev emulator,id=tpm0,chardev=chrtpm
  -device tpm-tis,tpmdev=tpm0
  -usb
  -device usb-mouse
  -device usb-kbd
  -audio none
  -device intel-hda
  -device hda-duplex
  -rtc base=utc,clock=host,driftfix=slew
  -no-user-config
  -nodefaults
  -global kvm-pit.lost_tick_policy=delay
  -boot menu=on
)

if [[ -n "$SPOOF" ]]; then
  random_mac=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  random_serial=$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')
  random_uuid=$(uuidgen)
  random_asset_board=$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')
  random_asset_chassis=$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')

  models=("OptiPlex 7040" "OptiPlex 7050" "OptiPlex 7060" "OptiPlex 3050" "OptiPlex 5050")
  random_model="${models[$RANDOM % ${#models[@]}]}"

  dell_mobos=("0Y7WYT" "0MWXPK" "0VHWTR" "0PTTT9" "0GY6Y8")
  random_mobo="${dell_mobos[$RANDOM % ${#dell_mobos[@]}]}"

  bios_date="03/$(printf '%02d' $((RANDOM%28+1)))/20$(printf '%02d' $((RANDOM%5+17)))"

  resolutions=("1920:1080" "1600:900" "1366:768" "1440:900" "1680:1050")
  random_res="${resolutions[$RANDOM % ${#resolutions[@]}]}"
  xres=$(echo "$random_res" | cut -d':' -f1)
  yres=$(echo "$random_res" | cut -d':' -f2)

  qemu_args+=(
    -cpu "$cpu_model",vendor="$cpu_vendor",kvm=off,-hypervisor
    -device ahci,id=ahci
    -device ide-hd,drive=disk0,bus=ahci.0
    -device qemu-xhci,id=xhci
    -device e1000e,netdev=vmnic,mac="$random_mac"
    -netdev user,id=vmnic
    -vga std
    -global VGA.vgamem_mb=16
    -global VGA.xres="$xres"
    -global VGA.yres="$yres"
    -display sdl
    -smbios type=0,vendor="Dell Inc.",version="1.8.2",date="$bios_date"
    -smbios type=1,manufacturer="Dell Inc.",product="$random_model",version="1.0",serial="$random_serial",uuid="$random_uuid",sku="$random_model",family="OptiPlex"
    -smbios type=2,manufacturer="Dell Inc.",product="$random_mobo",version="A00",serial="$random_serial",asset="$random_asset_board"
    -smbios type=3,manufacturer="Dell Inc.",version="1.0",serial="$random_serial",asset="$random_asset_chassis"
  )
else
  qemu_args+=(
    -cpu host
    -device virtio-blk-pci,drive=disk0
    -device virtio-net-pci,netdev=vmnic
    -netdev user,id=vmnic
    -device virtio-vga
    -display spice-app
    -spice unix=on,addr="$tmp_dir/spice.sock",disable-ticketing=on
    -device qemu-xhci,id=xhci
  )
fi

echo "Launching QEMU (SPOOF=${SPOOF:-off})..."
exec qemu-system-x86_64 "${qemu_args[@]}"
