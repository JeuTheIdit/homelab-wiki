# Windows and Office tips
Compilation of Microsoft Windows and Office tips and tricks to share.

## Table of contents
- [Downloads and activation](#downloads-and-activation)
- [Transferring AD FSMO roles](#transferring-ad-fsmo-roles)
  - [Checking FSMO role placement](#checking-fsmo-role-placement)
  - [Option 1 - GUI](#option-1---gui)
  - [Option 2 - Powershell](#option-2---powershell)
- [AD time synchronization](#ad-time-synchronization)
  - [Network time protocol](#network-time-protocol)
  - [Architecture](#architecture)
  - [Checking configuration](#checking-configuration)
  - [External time source](#external-time-source)
- [Fix DC booting to private or public network](#fix-DC-booting-to-private-or-public-network)
- [Configure DNS dynamic updates on Windows DHCP servers](#configure-dns-dynamic-updates-on-windows-dhcp-servers)

## Downloads and activation
Use the open-source [massgrave scripts (MAS)](https://massgrave.dev/) to activate Windows and Office, including Windows Server 2008 and newer. Official Windows and Office download links are compiled [by massgrave](https://massgrave.dev/genuine-installation-media). See below for which activation method to choose.
- Windows Vista: TSforge
- Windows 7: TSforge
- Windows 8: TSforge
- Windows 8.1: TSforge
- Windows 10: HWID (Digital License)
- Windows 11: HWID (Digital License)
- Windows Server 2008+: TSforge

## Transferring AD FSMO roles

[Here](https://9to5it.com/active-directory-fsmo-roles/) is a good article that provides a summary of each FSMO role, their purpose and some considerations around their placement. You can also read [Microsofts official documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/fsmo-roles).

If you have multiple DCs and need to change the primary domain controller (PDC) to another, moving the FSMO roles are how you do it. Below is a list of the roles that need to be transferred.
- Relative ID master
- PDC emulator
- Infrastructure master
- Domain naming master
- Schema master

### Checking FSMO role placement

To determine the current location of each FSMO role:

1. Log into any DC as a Domain Administrator.
2. Launch powershell, `Start >> Run >> powershell`.
3. Run the following.

```bash
netdom query fsmo
```

This will list all of the FSMO roles and on what domain controller they are currently running on. In my case, all roles are on my primary DC `dc-01`.

![](https://gist.github.com/user-attachments/assets/293e7011-9bc3-4611-a15e-d795f298f3fc)

### Option 1 - GUI
#### Relative ID master, PDC emulator, and infrastructure master roles
1. Log into the DC you want to transfer the role(s) to as a Domain Administrator.
2. Launch Active Directory Users and Computers.
3. Connect to the DC you want to transfer the role to.
   - From the left-hand pane navigation, right-click the root entry (Active Directory Users and Computers).
   - Click Change Domain Controller.
   - Select the appropriate DC from the list.
   - Click OK.
4. From the left-hand pane navigation, right-click on the domain and select Operations Master.
5. This will display the Operations Master window.
6. From here, select the appropriate tab of the role you want to transfer (i.e. RID, PDC, Infrastructure Master).
7. Click on the Change button.
8. Click Yes to confirm the transfer of the FSMO role.

#### Domain naming master role
1. Log into the DC you want to transfer the role to as an Enterprise Administrator.
2. Launch Active Directory Domains and Trusts.
3. Connect to the DC you want to transfer the role to.
   - From the left-hand pane navigation, right-click the root entry (Active Directory Domain and Trusts).
   - Click on Change Active Directory Domain Controller.
   - Select the appropriate DC from the list.
   - Click OK.
4. From the left-hand pane navigation, right-click the root entry (Active Directory Domain and Trusts) and click Operations Master.
5. This will display the Operations Master window.
6. From here, click the Change button.
7. Click Yes to confirm the transfer of the FSMO role.

#### Schema master role
1. Log into the DC you want to transfer the role to as an Enterprise Administrator.
2. To transfer the Schema Master role, you use the Schema Master MMC tool. To do this, you need to first register the corresponding DDL.
   - `Start >> Run >> cmd`.
   - Run the commmand `regsvr32 schmmgmt.dll`.
   - A success message should appear. Click OK.
3. `Start >> Run >> MMC`.
4. From the File menu, click on Add/Remove Snap-Ins.
5. From the window that appears, select Active Directory Schema and click Add.
6. Click OK.
7. Connect to the DC you want to transfer the role to.
   - From the left-hand pane navigation, right-click Active Directory Schema.
   - Select the appropriate DC from the list.
   - Click OK.
8. From the left-hand pane menu, right-click Active Directory Schema and click Operations Master.
9. From the window that appears, click on the Change button.
10. Click Yes to confirm the transfer of the FSMO role.

### Option 2 - Powershell
To move AD FSMO roles using powershell, run the following cmdlet, replacing `{server_name}` with the domain controller you want to transfer the role(s) to. This changes all of the roles at once. If you want to transfer a specific role (or only a few of them), then list the roles you want to move as the value for the `-OperationMasterRole` parameter of the cmdlet.

```bash
Move-ADDirectoryServerOperationMasterRole -Identity {server_name} -OperationMasterRole SchemaMaster, RIDMaster, InfrastructureMaster, DomainNamingMaster, PDCEmulator
```

## AD time synchronization
[Microsoft official documentation](https://learn.microsoft.com/en-us/archive/technet-wiki/50924.active-directory-time-synchronization).

### Network time protocol

Network time protocol (NTP) is the default time synchronization protocol used by the windows time service (WTS) in Windows servers and workstations.

NTP is implemented via UDP over port 123 and can operate in broadcast and multicast modes, or by direct queries.

### Architecture

In active directory deployment, the only computer configured with an NTP time server explicitly should be the computer holding the PDC emulator FSMO role in the forest root domain.

It is possible to override this configuration and bypass PDC emulator, but the default (and recommend) configuration is the following:
- All domain controllers in the forest root domain synchronize time with the PDC Emulator FSMO role-holder.
- All domain controllers in child domains synchronize time with any domain controller with parent domain or with PDC emulator of its own domain.
- All PDC emulator FSMO role-holders in child domains synchronize their time with domain controllers in their parent domain (including, potentially, the PDC emulator FSMO role-holder in the forest root domain).
- All domain member computers (servers, workstations and any other devices) synchronize time with domain controller computers in their respective domains.

### Checking configuration

To determine if a domain member is configured for domain time sync, examine the REG_SZ value at `HKLM\System\CurrentControlSet\Services\W32Time\Parameters\Type`.
- If it is set to `Nt5DS` then the computer is synchronizing time with the active directory time hierarchy.
- If it is set to `NTP` then the computer is synchronizing time with the NTP server specified in the `NtpServer` REG_SZ value in the same registry key.

![](https://learn.microsoft.com/en-us/archive/technet-wiki/a/resources/7140.capture.png)

By default, the primary domain controller should have `NTP` configured and the rest of the computers added to the domain should have `Nt5DS` configured.

### External time source

Since PDC emulator of the forest root domain is the main time source of the entire forest, it is important that the system clock of this computer is accurate.

To maintain the accuracy, the forest root domain PDC emulator must be configured to synchronize its time with an external time source which is reliable (time.nist.gov, us.pool.ntp.org, time.windows.com, time.google.com).

For my own home network, which may not be the best setup.
- My opnsense firewall is my main network NTP server, pulling from time.nist.gov and us.pool.ntp.org.
- My domain controller with the PDC emulator role has the `NTP` REG_SZ value pointing to my firewall IP.

## Fix DC booting to private or public network

If you have a single DC network, they may fail to recognize the local subnet as a domain network upon reboot. Restarting the network location awareness (NLA) service typically fixes the problem until the next reboot. Setting the NLA service to delayed start may not fix the problem.

This should not be an issue with multiple DC networks.

To fix this problem, add `DNS` as a dependant to the NLA service. By default, the NLA service has the following dependencies.
- NSI
- RpcSs
- TcpIp
- Dhcp
- Eventlog

So execute the following from powershell when logged into the DC as a Domain Administrator.

```bash
sc config nlasvc depend=NSI/RpcSs/TcpIp/Dhcp/Eventlog/DNS
```

**Do not just add DNS to this command, or else all of the other default dependencies will be deleted.**

## Configure DNS dynamic updates on Windows DHCP servers

[Microsoft official documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-dns-dynamic-updates-windows-server-2003).
