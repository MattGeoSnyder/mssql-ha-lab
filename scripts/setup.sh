#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/host.sh"
source "$SCRIPT_DIR/lib/packer.sh"
source "$SCRIPT_DIR/lib/terraform.sh"

run_all() {
  install_deps
  fetch_isos
  extract_drivers
  write_secrets
  build_golden
  verify_golden
  provision_vms
  verify_vms
}

case "${1:-all}" in
all) run_all ;;
deps) install_deps ;;
fetch) fetch_isos ;;
extract) extract_drivers ;;
secret) write_secrets ;;
build) build_golden ;;
verify_image) verify_golden ;;
libvirt) setup_libvirt ;;
provision) provision_vms ;;
verify_vms) verify_vms ;;
*) die "Unknown step: '$1' (use: deps|fetch|extract|secret|build|verify_image|provision|verify_vms|all)" ;;
esac
