terraform {
  required_version = ">= 1.15"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.9.0"
    }
  }
}


provider "libvirt" {
  uri = "qemu:///system"
}



