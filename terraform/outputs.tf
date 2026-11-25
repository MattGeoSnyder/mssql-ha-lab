output "hosts" {
  value = join(" ", [for h in var.hosts : "${h.name}=${h.ip}"])
}
