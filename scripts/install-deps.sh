#!/bin/bash
set -euo pipefail

programs=("qemu-base" "qemu-img" "libvirt" "edk2-ovmf" "wimlib" "tigervnc" "dnsmasq" "packer")

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman is needed for Arch Linux installation." >&2
  exit 1
fi

sudo pacman -S --needed --noconfirm "${programs[@]}"

echo "Done. Dependencies installed successfully."
