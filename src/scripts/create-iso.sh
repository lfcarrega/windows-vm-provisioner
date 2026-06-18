#!/usr/bin/env bash

# Exit on error, undefined vars, pipe failures
set -euo pipefail

debug_mode="${DEBUG:-0}"

[[ "$debug_mode" == 1 ]] && set -x

if (( "${#}" < 3 )); then
  printf "Usage: %s <base_iso> <output_iso> <overlay_dir>" "${0}" >&2
  exit 1
fi

if command -v tput &> /dev/null && [[ -n "$TERM" ]]; then
  red=$(tput setaf 1)
  green=$(tput setaf 2)
  yellow=$(tput setaf 3)
  normal=$(tput sgr0)
else
  red=""
  green=""
  yellow=""
  normal=""
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
base_iso="$(realpath ${1})"
output_iso="$(realpath -m ${2})"
output_dir="$(dirname ${output_iso})"
overlay_dir="$(realpath ${3})"
log_file="${script_dir}/log"

log() {
  local mode="${1:-normal}"
  case "$mode" in
    "normal") printf "%s\n" "${normal}${2}${normal}" ;;
    "success") printf "%s\n" "${green}${2}${normal}" ;;
    "error") printf "%s\n" "${red}${2}${normal}" ;;
  esac
}

die() {
  for prompt in "${@}"; do
    printf "%s\n" "$prompt" >&2
  done
  exit 1
}

detect_elevation() {
  if [[ "${EUID}" != 0 ]]; then
    die "Run this script as root or with sudo/doas"
  fi
}

check_commands() {
  local missing=()
  for cmd in mkwinpeimg xorriso; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if (( ${#missing[@]} )); then
    die "Missing required commands: ${missing[*]}"
  fi
}

detect_elevation
check_commands

exec 3>&1 1>"${log_file}" 2>&1

# Create the temporary working directory
tmp_dir="$(realpath -m ${script_dir}/../tmp)"
mkdir "${tmp_dir}" 2>/dev/null || true

# Cleanup on exit
trap "umount '${tmp_dir}/winiso' 2>/dev/null || true; \
      umount '${tmp_dir}/winpe.iso' 2>/dev/null || true; \
      rm -rf '${tmp_dir}'" EXIT

# Mount the base Windows installation ISO
log "normal" "[INFO] Mounting base iso '${base_iso}' to '${tmp_dir}/winiso'..." 1>&3
mount --mkdir "${base_iso}" "${tmp_dir}/winiso"

# Create a Windows PE ISO, add files from the overlay directory
log "normal" "[INFO] Making base WinPE ISO with the contents of 'overlay/'..." 1>&3
mkwinpeimg --iso --windows-dir="${tmp_dir}/winiso" --overlay="${overlay_dir}" "${tmp_dir}/winpe.iso"

# Mount the created winpe.iso
log "normal" "[INFO] Mounting the base WinPE iso '${tmp_dir}/winpe.iso' to '${tmp_dir}/winpe'..." 1>&3
mount --mkdir "${tmp_dir}/winpe.iso" "${tmp_dir}/winpe"

# Create a temporary directory to store the extracted WinPE
mkdir "${tmp_dir}/winpe_uefi"

# Copy WinPE files and UEFI boot files from base Windows installation ISO
log "normal" "[INFO] Copying WinPE files and UEFI boot files from base Windows installation ISO..." 1>&3
cp -r "${tmp_dir}/winpe/"* "${tmp_dir}/winpe_uefi/"
cp -r "${tmp_dir}/winiso/efi" "${tmp_dir}/winpe_uefi/"
cp -r "${tmp_dir}/winiso/boot"* "${tmp_dir}/winpe_uefi/"

# Create ISO from the "fixed" UEFI WinPE version
log "normal" "[INFO] Creating final ISO..." 1>&3
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "WinPE_UEFI" \
  -eltorito-alt-boot \
  -e efi/microsoft/boot/efisys.bin \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "${tmp_dir}/winpe_uefi.iso" \
  "${tmp_dir}/winpe_uefi"

# Copy the ISO to the provided location
log "normal" "[INFO] Moving final ISO to '${output_dir}'..." 1>&3
mkdir "${output_dir}" 2>/dev/null || true
cp "${tmp_dir}/winpe_uefi.iso" "${output_iso}"

if [[ -f "${output_iso}" ]]; then
  log "success" "[SUCCESS] ${output_iso} created successfully!" 1>&3
else
  log "error" "[ERROR] Something went wrong, check the log file '${log_file}'." 1>&3
  exit 1
fi
