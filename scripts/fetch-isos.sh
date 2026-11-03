#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

virtio_win_iso_dest_dir="$SCRIPT_DIR/../packer/iso/virtio-win-iso"

mkdir -p "$virtio_win_iso_dest_dir"
virtio_win_iso_link_url_base="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1"
iso_download="virtio-win.iso"

VIRTIO_SHA256="e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331"

virtio_win_iso_url="$virtio_win_iso_link_url_base/$iso_download"
virtio_win_iso_dest_path="$virtio_win_iso_dest_dir/$iso_download"
virtio_tmp_file="${virtio_win_iso_dest_path}.tmp"

if [[ -f "$virtio_win_iso_dest_path" ]]; then
  echo "virtio-win.iso is already present - skipping"
else
  trap 'echo "Download/verify failed; removing $virtio_tmp_file >&2; rm -f $virtio_tmp_file"' EXIT
  echo "Downloading $iso_download to virtio_win_iso_dest_dir"
  curl -Lf --retry 3 "$virtio_win_iso_url" -o "$virtio_tmp_file"
  echo "${VIRTIO_SHA256} $virtio_tmp_file" | sha256sum -c -
  mv "$virtio_tmp_file" "$virtio_win_iso_dest_path"
  trap - EXIT
  echo "Downloaded and verified $iso_download"
fi

win_iso_dest_dir="$SCRIPT_DIR/../packer/iso/windows"
win_iso_file_name="SERVER_EVAL_x64_en-us.iso"
win_iso_dest_path="$win_iso_dest_dir/$win_iso_file_name"

if [[ ! -f $win_iso_dest_path ]]; then
  cat <<EOF
  Windows Server 2022 ISO not found at:
    $win_iso_dest_path

  Download it (free 180-day eval) from:
    https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022

  Choose the 64-bit Version of Windows Server 2022, then save it as:
    $win_iso_file_name
  into:
    $win_iso_dest_dir
EOF
  exit 1
fi
