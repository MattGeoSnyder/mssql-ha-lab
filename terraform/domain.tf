resource "libvirt_domain" "VMs" {
  for_each  = { for h in var.hosts : h.name => h }
  name      = each.key
  type      = "kvm"
  autostart = true
  running   = true

  features = {
    acpi = true
    apic = {}
  }

  memory_unit = "MiB"
  vcpu        = 2
  memory      = strcontains(each.key, "SQL") ? 4096 : 2048

  os = {
    type            = "hvm"
    type_arch       = "x86_64"
    type_machine    = "q35"
    firmware        = "efi"
    loader          = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
    loader_readonly = "yes"
    loader_type     = "pflash"
    nv_ram = {
      nv_ram   = "/var/lib/libvirt/qemu/nvram/${each.key}.fd"
      template = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
    }
    boot_devices = [{
      dev = "hd"
    }]
  }

  devices = {
    controllers = [
      {
        type  = "scsi"
        model = "virtio-scsi"
      }
    ]
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        target = {
          bus = "scsi"
          dev = "sda"
        }
        source = {
          volume = {
            pool   = libvirt_pool.pool.name
            volume = libvirt_volume.VMs[each.key].name
          }
        }
      }
    ]
    interfaces = [
      {
        model = { type = "virtio" }
        source = {
          network = {
            network = libvirt_network.mssql.name
          }
        }
        mac = { address = each.value.mac }
      }
    ]
  }
}
