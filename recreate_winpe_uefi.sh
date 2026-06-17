#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Create temporary working directory
tmp_dir="$(mktemp -d)"  # -d creates a directory, not a file
trap "sudo umount '${tmp_dir}/winiso' 2>/dev/null || true; \
      sudo umount '${tmp_dir}/winpe.iso' 2>/dev/null || true; \
      sudo rm -rf '${tmp_dir}'" EXIT  # Cleanup on exit

# Mount the base Windows installation ISO
sudo mount --mkdir win2025-eval.iso "${tmp_dir}/winiso"

# Create a Windows PE ISO, add files from the overlay directory
mkwinpeimg --iso --windows-dir="${tmp_dir}/winiso" --overlay=overlay "${tmp_dir}/winpe.iso"

# Mount the created winpe.iso
sudo mount --mkdir "${tmp_dir}/winpe.iso" "${tmp_dir}/winpe"

# Create a temporary directory to store the extracted WinPE
sudo mkdir "${tmp_dir}/winpe_uefi"

# Copy WinPE files and UEFI boot files from base Windows installation ISO
sudo cp -r "${tmp_dir}/winpe/"* "${tmp_dir}/winpe_uefi/"
sudo cp -r "${tmp_dir}/winiso/efi" "${tmp_dir}/winpe_uefi/"
sudo cp -r "${tmp_dir}/winiso/boot"* "${tmp_dir}/winpe_uefi/"

# Create ISO from the "fixed" UEFI WinPE version
sudo xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "WinPE_UEFI" \
  -eltorito-alt-boot \
  -e efi/microsoft/boot/efisys.bin \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "${tmp_dir}/winpe_uefi.iso" \
  "${tmp_dir}/winpe_uefi"

# Copy the ISO to current directory
cp "${tmp_dir}/winpe_uefi.iso" .

echo "✓ winpe_uefi.iso created successfully!"
