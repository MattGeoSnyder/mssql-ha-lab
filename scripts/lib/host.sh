source "${BASH_SOURCE[0]%/*}/../config.sh"

install_deps() {
  command -v pacman >/dev/null 2>&1 || die "pacman is needed for Arch Linux installation"
  sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
  log "Done. Dependencies installed successfully."
}

setup_libvirt() {
  sudo usermod -aG libvirt "$USER"
  sudo systemctl enable --now virt{qemu,network,storage,nodedev,proxy}d.socket
}
