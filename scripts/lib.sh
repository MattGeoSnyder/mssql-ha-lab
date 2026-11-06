# lib.sh — sourced. Defines helpers + step functions

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
die() {
  err "$*"
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

install_deps() {
  command -v pacman >/dev/null 2>&1 || die "pacman is needed for Arch Linux installation"
  sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
  log "Done. Dependencies installed successfully."
}

fetch_isos() {
  local tmp="$VIRTIO_ISO_DIR/$VIRTIO_ISO_NAME.tmp"
  local dest="$VIRTIO_ISO_DIR/$VIRTIO_ISO_NAME"

  mkdir -p "$VIRTIO_ISO_DIR"

  if [[ -f "$dest" ]]; then
    log "virtio-win.iso is already present - skipping"
  else
    trap 'rm -f "$tmp"' EXIT INT TERM
    log "Downloading virtio-win ISO..."
    curl -Lf --retry 3 "$VIRTIO_URL_BASE/$VIRTIO_ISO_NAME" -o "$tmp" ||
      die "virtio-win download failed"
    echo "$VIRTIO_SHA256 $tmp" | sha256sum -c - || die "virtio-win checksum mismatch"
    mv "$tmp" "$dest"
    trap - EXIT INT TERM
    log "virtio-win ISO verified."
  fi

  [[ -f "$WINDOWS_ISO_DIR/$WINDOWS_ISO_NAME" ]] ||
    die "Windows ISO missing. See README for the download link; place it at $WINDOWS_ISO_DIR"
}

extract_drivers() {
  local dest="$VIRTIO_ISO_DIR/$VIRTIO_ISO_NAME"

  [[ -f "$dest" ]] ||
    die "virtio-win ISO not found."

  sudo mkdir -p "$VIRTIO_MNT"
  sudo mount -o loop,ro "$dest" "$VIRTIO_MNT"
  trap 'sudo umount "$VIRTIO_MNT" 2>/dev/null || true; sudo rmdir "$VIRTIO_MNT" 2>/dev/null || true' EXIT

  local driver driver_dir
  for driver in "${DRIVERS[@]}"; do
    driver_dir="$PACKER_DIR/$driver"
    mkdir -p "$driver_dir"
    cp --update=none "$VIRTIO_MNT/$driver/2k22/amd64/"* "$driver_dir"
  done

  sudo umount $VIRTIO_MNT
  sudo rmdir $VIRTIO_MNT
}

write_secrets() {
  local secrets_path="$PACKER_DIR/secrets.pkrvars.hcl"

  if [[ -f "$secrets_path" ]]; then
    log "Secrets file already exists. Skipping..."
    return
  fi

  local admin_pass pass_confirm
  while true; do

    read -rsp "Enter the administrator password for the Windows Server VM: " admin_pass
    echo ""

    read -rsp "Confirm the password: " pass_confirm
    echo ""

    if [[ -z "$admin_pass" ]]; then
      echo "Password cannot be empty"
    elif [[ "$admin_pass" != "$pass_confirm" ]]; then
      echo "Passwords do not match"
    elif [[ "$admin_pass" = *[\$\\\"]* ]]; then
      echo "Password cannot contain the characters \$, \\, \" ."
    else
      break
    fi

  done

  (
    umask 077
    echo "admin_password = \"$admin_pass\"" >"$secrets_path"
  )
  log "Success!"

}

build_golden() {
  shopt -s nullglob
  local secrets_path="$PACKER_DIR/secrets.pkrvars.hcl"

  [[ -f "$secrets_path" ]] ||
    die "Secrets file not found. Copy example.pkrvars.hcl -> secrets.pkrvars.hcl and complete"

  local driver files
  for driver in "${DRIVERS[@]}"; do
    files=("$PACKER_DIR/$driver/"*)
    [[ ${#files[@]} -gt 0 ]] ||
      die "${driver}: drivers not found."
  done

  shopt -u nullglob

  packer init "$PACKER_DIR"
  packer validate -var-file="$secrets_path" "$PACKER_DIR"
  packer build -var-file="$secrets_path" "$PACKER_DIR"
}

verify_golden() {
  [[ -f "$GOLDEN_IMAGE" ]] ||
    die "Built image not found. Check build.log for errors."

  sudo modprobe nbd
  sudo qemu-nbd --connect=/dev/nbd0 "$GOLDEN_IMAGE"
  trap 'sudo umount /mnt/win 2>/dev/null || true;
        sudo umount /mnt/efi 2>/dev/null || true; 
        sudo qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true; 
        sudo rmdir /mnt/win /mnt/efi 2>/dev/null || true;' EXIT

  sudo partprobe /dev/nbd0

  sudo mkdir -p /mnt/win
  sudo mkdir -p /mnt/efi
  sudo mount -o ro /dev/nbd0p3 /mnt/win
  sudo mount -o ro /dev/nbd0p1 /mnt/efi

  log "Checking unattend file"
  [[ -f "/mnt/win/Windows/Panther/unattend.xml" ]] ||
    die "bootstrap unattend.xml missing from image"

  log "Checking Sysprep_succeeded"
  [[ -f "/mnt/win/Windows/System32/Sysprep/Sysprep_succeeded.tag" ]] ||
    die "Sysprep_succeeded.tag missing - generalize did not complete"

  log "checking UEFI bootloader"
  [[ -f "/mnt/efi/EFI/Boot/bootx64.efi" ]] ||
    die "UEFI fallback bootloader missing"

  log "Golden image verified: bootstrap unattend, sysprep tag, and UEFI bootloader all present."

}
