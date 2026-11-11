variable "hosts" {
  type = list(object({
    ip   = string
    mac  = string
    name = string
  }))
  description = "VMs: name, static IP, and Mac for DHCP reservation"
}

