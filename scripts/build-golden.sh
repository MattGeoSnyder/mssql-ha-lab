#!/bin/bash

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packer_dir="$SCRIPT_DIR/../packer"
secrets_path="$packer_dir/secrets.pkrvars.hcl"

if [[ ! -f "$secrets_path" ]]; then
  echo "Secrets file not found. Copy example.pkrvars.hcl -> secrets.pkrvars.hcl and complete"
  exit 1
fi

if [[ ! -f "$packer_dir/iso/virtio-win-iso/virtio-win.iso" ]]; then
  "$SCRIPT_DIR/fetch-isos.sh"
fi

drivers=("vioscsi" "NetKVM" "Balloon")
for driver in "${drivers[@]}"; do
  files=("$packer_dir/$driver/"*)
  if [[ ${#files[@]} -eq 0 ]]; then
    "$SCRIPT_DIR/extract-drivers.sh"
  fi
done

packer init "$packer_dir"
packer validate -var-file="$secrets_path" "$packer_dir"
packer build -var-file="$secrets_path" "$packer_dir"
