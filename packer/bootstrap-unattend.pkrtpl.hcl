<?xml version="1.0" encoding="utf-8"?>
<!--
  BOOTSTRAP unattend.xml - baked into the golden image at
  C:\Windows\Panther\unattend.xml

  This is NOT the install-time autounattend.xml. Windows processes
  THIS file automatically on the first boot AFTER sysprep /generalize
  has wiped the machine identity. Its only job: bring a freshly-cloned
  VM up in a known, reachable state (admin password set, WinRM on, a
  temporary hostname) so Ansible can connect and do the real per-VM
  work (rename, static IP via DHCP reservation, AD role, etc.).

  Deliberately generic - the SAME file is baked into the one golden
  image and serves every clone (DC01/SQL01/SQL02). No per-VM identity
  is baked in; that lives in Ansible inventory.

  Only two passes are needed here (machine is already installed):
    - specialize : temporary hostname
    - oobeSystem : admin password, skip OOBE screens, re-enable WinRM
-->
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <!-- Temporary name. Ansible renames each clone to DC01/SQL01/
           SQL02. A '*' would make Windows generate a random name;
           we use a fixed placeholder so an un-renamed VM is obvious. -->
      <ComputerName>WIN-BOOTSTRAP</ComputerName>

      <!-- Skip the "activate now" nag; this is an eval image. -->
      <ProductKey></ProductKey>
    </component>

    <!-- Keep RDP off by default; lab is CLI/WinRM-driven. Ansible can
         enable it per-host later if ever needed. -->
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

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
          <!-- SAME placeholder as the install-time file. Tech debt:
               templatize both from one Packer variable later. -->
          <Value>${admin_password}</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>

      <!-- Auto-logon ONCE so FirstLogonCommands run to completion,
           then it stops (LogonCount=1). This is what fires the WinRM
           re-enable below. -->
      <AutoLogon>
        <Enabled>true</Enabled>
        <Username>Administrator</Username>
        <Password>
          <Value>${admin_password}</Value>
          <PlainText>true</PlainText>
        </Password>
        <LogonCount>1</LogonCount>
      </AutoLogon>

      <!-- The critical part: re-enable WinRM on this freshly
           generalized clone so Ansible (and, if ever needed, Packer)
           can connect. Mirrors the install-time file's WinRM setup. -->
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>cmd.exe /c winrm quickconfig -quiet</CommandLine>
          <Description>Enable WinRM</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true"</CommandLine>
          <Description>WinRM basic auth</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true"</CommandLine>
          <Description>WinRM allow unencrypted</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>4</Order>
          <CommandLine>netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow</CommandLine>
          <Description>Open WinRM firewall port</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>5</Order>
          <CommandLine>powershell.exe -Command "Set-NetConnectionProfile -NetworkCategory Private"</CommandLine>
          <Description>Force network profile to Private so WinRM works</Description>
        </SynchronousCommand>
      </FirstLogonCommands>

    </component>
  </settings>

</unattend>
