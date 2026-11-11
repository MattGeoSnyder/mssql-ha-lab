resource "libvirt_pool" "pool" {
  name = "mssql_pool"
  type = "dir"

  target = {
    path = "/var/lib/libvirt/images/mssql"
  }
}
