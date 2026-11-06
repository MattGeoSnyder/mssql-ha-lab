<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <!-- ============================================================
       PASS 1: windowsPE
       Runs inside the Setup environment, before Windows is installed.
       Responsible for: language/locale, loading the VirtIO storage
       driver (or Setup can't see the disk), partitioning the disk,
       and selecting which edition (WIM index) to install.
       ============================================================ -->
  <settings pass="windowsPE">

    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <!-- Load the VirtIO SCSI storage driver so Setup can see the
         virtual disk at all. Without this, Setup reports "no drives
         found."

         DELIBERATE PLAN (not yet final - resolved in the Packer HCL step):
         Rather than pointing at the virtio-win.iso directly (whose
         drive letter depends on QEMU attach order and isn't reliably
         predictable), the Packer "cd_files" option will build a
         SINGLE disc containing autounattend.xml plus only the
         vioscsi/NetKVM/Balloon 2k22/amd64 folders copied out of
         virtio-win.iso. That collapses "which of 2 discs, which
         letter" down to "one disc, one letter" - and that one
         remaining letter gets pinned to its real value on the first
         test build (verified via VNC / explicit qemu_args drive
         ordering), then hardcoded here permanently.

         Until that first test build, these entries are deliberately
         defensive - covering the range of letters Windows PE
         realistically assigns cd-rom media in this configuration.
         Unmatched paths are silently skipped by Setup, so listing
         extras is harmless. -->
    <component name="Microsoft-Windows-PnpCustomizationsWinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <DriverPaths>
        <PathAndCredentials wcm:keyValue="1" wcm:action="add">
          <Path>E:\vioscsi</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:keyValue="2" wcm:action="add">
          <Path>E:\NetKVM</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:keyValue="3" wcm:action="add">
          <Path>E:\Balloon</Path>
        </PathAndCredentials>
      </DriverPaths>
    </component>

    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">

      <!-- Accept the EULA, don't ask, run unattended -->
      <UserData>
        <AcceptEula>true</AcceptEula>
        <!-- No ProductKey block at all = Setup falls back to the
             evaluation edition matching the WIM image selected below.
             This is intentional for eval media. -->
      </UserData>

      <!-- Which edition to install, by WIM index (confirmed via wiminfo) -->
      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/INDEX</Key>
              <Value>1</Value>
            </MetaData>
          </InstallFrom>

          <!-- Disk partitioning: single-disk, UEFI/GPT layout.
               400MB EFI System Partition, 128MB MSR, remainder as OS. -->
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
        </OSImage>
      </ImageInstall>

      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>EFI</Type>
              <Size>400</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>MSR</Type>
              <Size>128</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Format>FAT32</Format>
              <Label>System</Label>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>2</Order>
              <PartitionID>2</PartitionID>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>3</Order>
              <PartitionID>3</PartitionID>
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Letter>C</Letter>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>

    </component>
  </settings>

  <!-- ============================================================
       PASS 2: specialize
       Runs after files are copied, on first boot into the new OS.
       Sets computer name. We keep this generic here; Terraform/
       provisioning will rename per-VM (DC01/SQL01/SQL02) later -
       this file just needs to produce a bootable, WinRM-reachable
       golden image, not the final per-node identity.
       ============================================================ -->
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <ComputerName>PACKER-TMP</ComputerName>
    </component>
  </settings>

  <!-- ============================================================
       PASS 3: oobeSystem
       Final pass - sets the local Administrator password, skips
       the interactive OOBE screens, and fires FirstLogonCommands
       to enable WinRM so Packer can connect and take over.
       ============================================================ -->
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">

      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>

      <UserAccounts>
        <AdministratorPassword>
          <!-- PLAINTEXT PLACEHOLDER - replace before use, and see
               the note below about not committing this to git -->
          <Value>${admin_password}</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>

      <AutoLogon>
        <Enabled>true</Enabled>
        <Username>Administrator</Username>
        <Password>
          <Value>${admin_password}</Value>
          <PlainText>true</PlainText>
        </Password>
        <LogonCount>1</LogonCount>
      </AutoLogon>

      <!-- Runs once, at first logon. This is the bridge from
           "Windows is installed" to "Packer can reach it over WinRM." -->
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>cmd.exe /c winrm quickconfig -quiet</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>4</Order>
          <CommandLine>netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>

    </component>
  </settings>

</unattend>
