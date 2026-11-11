resource "libvirt_network" "mssql" {
  name      = "mssql"
  autostart = true

  forward = { mode = "nat" }

  domain = {
    name = "sqllab.local"
  }

  dns = {
    enable = "yes"
    host = [
      for host in var.hosts : {
        ip        = host.ip
        hostnames = [{ hostname = host.name }]
      }
    ]
  }

  ips = [
    {
      address = "10.10.10.1"
      prefix  = 24
      dhcp = {
        hosts = var.hosts
      }
    }
  ]
}
