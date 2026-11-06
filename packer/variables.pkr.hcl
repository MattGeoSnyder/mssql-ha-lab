variable "admin_password" {
  type      = string
  sensitive = true
  # No default - must be supplied via -var-file or PKR_VAR_admin_password
}

variable "vm_name" {
  type    = string
  default = "win2022-core-golden"
}
