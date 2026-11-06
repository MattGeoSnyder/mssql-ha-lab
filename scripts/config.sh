# config.sh — sourced
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$CONFIG_DIR/.." && pwd)"

PACKER_DIR="$REPO_ROOT/packer"
ISO_DIR="$PACKER_DIR/iso"
VIRTIO_ISO_DIR="$ISO_DIR/virtio-win-iso"
WINDOWS_ISO_DIR="$ISO_DIR/windows"
VIRTIO_MNT="/mnt/virtio"

VIRTIO_VERSION="0.1.285"
VIRTIO_SHA256="e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331"
VIRTIO_URL_BASE="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-${VIRTIO_VERSION}-1"
VIRTIO_ISO_NAME="virtio-win.iso"

WINDOWS_ISO_NAME="SERVER_EVAL_x64FRE_en-us.iso"
DRIVERS=("vioscsi" "NetKVM" "Balloon")
GOLDEN_IMAGE="$PACKER_DIR/output-win2022-core-golden/win2022-core-golden"

PACKAGES=("qemu-base" "qemu-img" "libvirt" "edk2-ovmf" "wimlib" "tigervnc" "dnsmasq" "packer" "libisoburn")
