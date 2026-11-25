log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
die() {
  err "$*"
  exit 1
}
