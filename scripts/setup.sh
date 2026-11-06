#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

run_all() {
  install_deps
  fetch_isos
  extract_drivers
  write_secrets
  build_golden
  verify_golden
}

case "${1:-all}" in
all) run_all ;;
deps) install_deps ;;
fetch) fetch_isos ;;
extract) extract_drivers ;;
secret) write_secrets ;;
build) build_golden ;;
verify) verify_golden ;;
*) die "Unknown step: '$1' (use: deps|fetch|extract|secret|build|verify|all)" ;;
esac
