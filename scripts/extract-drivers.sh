#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
virtio_win_iso_dest_dir="$SCRIPT_DIR/../packer/iso/virtio-win-iso"
iso_download="virtio-win.iso"
virtio_win_iso_dest_path="$virtio_win_iso_dest_dir/$iso_download"

virtio_mnt="/mnt/virtio"

if [[ ! -f "$virtio_win_iso_dest_path" ]]; then
  echo "virtio-win ISO not found. Run fetch-isos.sh first." >&2
  exit 1
fi

sudo mkdir -p "$virtio_mnt"
sudo mount -o loop,ro "$virtio_win_iso_dest_path" "$virtio_mnt"
trap 'sudo umount "$virtio_mnt" 2>/dev/null || true; sudo rmdir "$virtio_mnt" 2>/dev/null || true' EXIT

packer_dir="$SCRIPT_DIR/../packer"

drivers=("vioscsi" "NetKVM" "Balloon")

for driver in "${drivers[@]}"; do
  driver_dir="$packer_dir/$driver"
  mkdir -p "$driver_dir"
  cp "/mnt/virtio/$driver/2k22/amd64/"* "$driver_dir"
done
