source "${BASH_SOURCE[0]%/*}/../config.sh"

in_libvirt_group() { id -nG | grep -qw libvirt; }

provision_vms() {
  if ! in_libvirt_group; then
    sudo -u "$USER" "$SCRIPT_DIR/setup.sh" provision
    return
  fi

  terraform -chdir="$TERRAFORM_DIR" init
  terraform -chdir="$TERRAFORM_DIR" apply
}

wait_for_winrm() {
  if (($# != 3)); then
    err "Usage: wait_for_winrm hostname ip timeout"
    return 2
  fi

  local hostname=$1
  local ip=$2
  local timeout=$3

  local start_time=$SECONDS
  local deadline=$((start_time + timeout))

  until curl -m 3 -s -o /dev/null "http://$ip:5985/wsman"; do
    if ((SECONDS >= deadline)); then
      err "WinRM on $hostname (${ip}) was not reachable after ${timeout}s"
      return 1
    fi
    sleep 10
  done

  log "$hostname is up ($((SECONDS - start_time))s elapsed)"
}

retry() {
  true
}

verify_vms() {
  if ! in_libvirt_group; then
    sudo -u "$USER" "$SCRIPT_DIR/setup.sh" verify_vms
    return
  fi

  declare -A hosts

  local pairs
  read -ra pairs <<<"$(terraform -chdir="$TERRAFORM_DIR" output -raw hosts)"

  local pair
  for pair in "${pairs[@]}"; do
    hosts["${pair%%=*}"]="${pair#*=}"
  done

  local host
  for host in "${!hosts[@]}"; do
    local state
    state=$(virsh -c "$LIBVIRT_URI" domstate "$host")
    [[ $state == running ]] || die "VM $host is not running (state: $state)"
  done

  for host in "${!hosts[@]}"; do
    local ip="${hosts[$host]}"
    log "Waiting for WinRM on $host ($ip)"
    wait_for_winrm "$host" "$ip" "$VM_BOOT_TIMEOUT" ||
      die "verify_vms: WinRM check failed for $host"

  done
}
