packer {
  required_plugins {
    qemu = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

locals {
  windows_iso = "${path.root}/iso/windows/SERVER_EVAL_x64FRE_en-us.iso"
}

source "qemu" "win2022_core" {

  # --- Install media ---
  iso_url      = local.windows_iso
  iso_checksum = "none"

  # --- Disk ---
  disk_size      = "60000M"          # 60GB - room for SQL Server + data later
  format         = "qcow2"
  disk_interface = "virtio-scsi"     # matches the vioscsi driver we're loading

  # --- Networking ---
  net_device = "virtio-net"          # matches the NetKVM driver

  # --- Boot: Windows UEFI install media shows "Press any key to boot
  #     from CD or DVD" and will NOT boot without a keypress within a
  #     few seconds. Without this, the VM silently sits at that prompt
  #     forever (which is what was actually happening during the
  #     "waiting for WinRM" retries - no OS was ever running). ---
  boot_wait          = "1s"
  boot_key_interval  = "100ms"
  # Press Enter every second for 60s. The Windows UEFI CD prompt is
  # only open ~5s and appears at a variable point after POST, so
  # widely-spaced presses can straddle it and miss. Dense presses
  # can't. Extra presses are harmless before (OVMF ignores Enter
  # during POST) and after (Setup is fully unattended).
  boot_command       = [for i in range(60) : "<enter><wait1>"]

  # --- CPU / memory for the BUILD VM (not the final lab VM sizing -
  #     this is just what Packer uses while building the image) ---
  cpus   = 2
  memory = 4096

  accelerator  = "kvm"
  machine_type = "q35"               # required for UEFI/efi_boot

  # --- UEFI boot (matches the GPT/EFI partition layout in autounattend.xml) ---
  efi_boot           = true
  efi_firmware_code  = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  efi_firmware_vars  = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"

  # --- The answer-file disc: autounattend.xml + extracted VirtIO drivers,
  #     bundled onto ONE Packer-generated CD so we control its contents
  #     and stop depending on virtio-win.iso's own drive letter ---
  cd_files = [
    "./vioscsi",
    "./NetKVM",
    "./Balloon",
  ]
  cd_content = {
    "autounattend.xml" = templatefile("${path.root}/autounattend.pkrtpl.hcl", {
      admin_password = var.admin_password
    })
  }
  cd_label = "ANSWER"

  # --- How Packer connects once WinRM is up (see FirstLogonCommands
  #     in autounattend.xml) ---
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.admin_password
  winrm_timeout  = "1h"              # Windows installs can be slow; generous timeout

  # --- Build VM identity / output ---
  vm_name          = var.vm_name
  output_directory = "output-${var.vm_name}"

  # --- Running headless because this host's qemu build doesn't have
  #     working GTK UI support ("Display 'gtk' is not available"), and
  #     setting display="none" alone wasn't enough to avoid that code
  #     path when headless=false. Packer still stands up a VNC server
  #     regardless of headless - connect manually with any VNC client
  #     to watch the install (address/port printed in build output). ---
  headless         = true
  vnc_bind_address = "127.0.0.1"

  # --- Sysprep (launched as a scheduled task in the build block)
  #     powers the VM off itself via /shutdown. Packer only needs to
  #     wait for the machine to disappear, so shutdown_command is a
  #     harmless no-op that returns immediately - the real shutdown is
  #     already in flight. shutdown_timeout covers the generalize
  #     duration before the VM actually powers off. ---
  shutdown_command = "cmd /c echo sysprep is handling shutdown"
  shutdown_timeout = "20m"
}

build {
  sources = ["source.qemu.win2022_core"]

  # --- NOTE: no VirtIO guest tools MSI install here, on purpose.
  #     The drivers that matter (vioscsi, NetKVM, Balloon) are already
  #     injected during the windowsPE pass via DriverPaths in
  #     autounattend.xml - that's why the VM has a disk and network at
  #     all. The MSI would only add the user-mode balloon service and
  #     QEMU guest agent, neither of which this lab needs (fixed
  #     memory, static IPs). It also reinstalls the NIC mid-install,
  #     which kills the WinRM session Packer is running over and hangs
  #     the build. Not worth it. ---

  # Sanity check: confirm the boot-critical drivers really did land,
  # so a silent driver failure shows up here rather than later in
  # Terraform.
  provisioner "powershell" {
    inline = [
      "Write-Host 'Verifying VirtIO drivers...'",
      "Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'VirtIO|Red Hat' } | Select-Object DeviceName, DriverVersion | Format-Table -AutoSize",
      "if (-not (Get-NetAdapter | Where-Object Status -eq 'Up')) { throw 'No network adapter is up' }",
      "Write-Host 'Driver verification complete.'"
    ]
  }

  # --- UEFI fallback bootloader.
  #     Windows records its boot entry in firmware NVRAM. Our
  #     efi_firmware_vars points at a read-only system template, so
  #     those writes never persist past this QEMU process - meaning a
  #     clone booted later by Terraform would find no boot entry and
  #     drop to the EFI shell. Copying bootmgfw.efi to the UEFI
  #     fallback path makes the disk self-bootable without NVRAM. ---
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing UEFI fallback bootloader...'",
      "mountvol S: /S",
      "if (-not (Test-Path 'S:\\EFI\\Boot')) { New-Item -ItemType Directory -Path 'S:\\EFI\\Boot' -Force | Out-Null }",
      "Copy-Item 'S:\\EFI\\Microsoft\\Boot\\bootmgfw.efi' 'S:\\EFI\\Boot\\bootx64.efi' -Force",
      "if (-not (Test-Path 'S:\\EFI\\Boot\\bootx64.efi')) { throw 'Fallback bootloader was not created' }",
      "Write-Host 'Fallback bootloader in place.'",
      "mountvol S: /D"
    ]
  }

  # --- Bootstrap unattend.xml.
  #     Placed at C:\Windows\Panther\unattend.xml so Windows processes
  #     it automatically on the FIRST boot after sysprep generalizes.
  #     It re-enables WinRM and sets a temporary hostname, so each
  #     Terraform-cloned VM comes up reachable for Ansible. MUST be
  #     copied in before the sysprep step below, since sysprep is what
  #     arms Windows to look for this file on next boot.
  #     The Panther dir usually exists post-install, but we create it
  #     defensively so a missing-path error can't fail the build. ---
  provisioner "powershell" {
    inline = [
      "New-Item -ItemType Directory -Force -Path 'C:\\Windows\\Panther' | Out-Null",
      "Write-Host 'Panther directory ready for bootstrap unattend.'"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.root}/bootstrap-unattend.pkrtpl.hcl", {
      admin_password = var.admin_password
    })
    destination = "C:/Windows/Panther/unattend.xml"
  }

  provisioner "powershell" {
    inline = [
      "if (-not (Test-Path 'C:\\Windows\\Panther\\unattend.xml')) { throw 'Bootstrap unattend.xml was not copied' }",
      "Write-Host 'Bootstrap unattend.xml in place.'"
    ]
  }

  # --- Sysprep /generalize.
  #     Launched as a one-shot scheduled task rather than inline: once
  #     generalize runs it tears down machine state, so an inline
  #     WinRM call hangs waiting for a session that's being pulled out
  #     from under it. The scheduled task detaches sysprep from the
  #     WinRM session; sysprep's own /shutdown powers the VM off, and
  #     Packer treats that shutdown as the expected end of the build.
  #
  #     /quiet suppresses the GUI progress dialog (which has no
  #     interactive desktop under WinRM and would hang forever).
  #     /generalize strips the machine SID for unique clone identities.
  #     NOTE: setuperr.log will show BiUpdateEfiEntry / "export to
  #     firmware" errors - those are sysprep failing to write UEFI
  #     NVRAM (our OVMF_VARS is a read-only template) and are NOT
  #     fatal; the fallback bootloader above makes the disk boot
  #     without an NVRAM entry. Sysprep still writes
  #     Sysprep_succeeded.tag and completes. ---
  provisioner "powershell" {
    inline = [
      "Write-Host 'Scheduling sysprep /generalize /shutdown...'",
      "$cmd = 'C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quiet /shutdown'",
      "schtasks /create /tn PackerSysprep /sc once /st 00:00 /ru SYSTEM /rl HIGHEST /f /tr $cmd | Out-Null",
      "schtasks /run /tn PackerSysprep | Out-Null",
      "Write-Host 'Sysprep task launched; VM will generalize and power off.'"
    ]
  }
}

