resource "libvirt_volume" "base" {
  name = "base.qcow2"
  pool = libvirt_pool.pool.name

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = abspath("${path.module}/../packer/output-win2022-core-golden/win2022-core-golden")
    }
  }
}

resource "libvirt_volume" "VMs" {
  for_each = { for h in var.hosts : h.name => h }
  name     = "${each.key}-image.qcow2"
  pool     = libvirt_pool.pool.name
  capacity = libvirt_volume.base.capacity
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path   = libvirt_volume.base.target.path
    format = { type = "qcow2" }
  }
}
