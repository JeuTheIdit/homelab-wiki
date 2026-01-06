# Brocade ICX switch series tips
Compilation of Brocade's ICX series switch tips and tricks to share.

## Table of contents
- [Setting up and firmware](#setting-up-and-firmware)
- [Shortcuts and commands](#shortcuts-and-commands)
- [Enable and configure terminal](#enable-and-configure-terminal)
- [L3 routing](#l3-routing)
  - [L3 setup with Pfsense or Opnsense](#l3-setup-with-pfsense-or-opnsense)
- [DHCP helper-address](#dhcp-helper-address)
- [Dual-mode](#dual-mode)

## Setting up and firmware
See [Fohdeesha Docs](https://fohdeesha.com/docs/) for setup, hardware/firmware hacking and reverse engineering guides.

## Shortcuts and commands
- [Diagnostic commands](https://github.com/Sayeh-1337/switch-cheat-sheets/blob/master/cheat-sheets/Ruckus-Brocade-ICX-FastIron-switch-debug-nad-diagnostics-commands-cheat-sheet.adoc)
- `configure terminal` = `conf t`
- `write memory` = `write mem`
- `tagged` = `tag`
- `untagged` = `unt`

## Enable and configure terminal

Immediately after logging in, the switch will be in User EXEC mode, which is read-only and has limited diagnostic commands available (ping, traceroute). To access more commands, enter into Privileged EXEC mode with `enable`. The prompt will change from `>` to `#` to indicate this state change.

```bash
ICX6450-24P Router>enable
ICX6450-24P Router#
```

Global Configuration Mode is needed to actually make changes to the switch's ports and overall system settings. This can be done after running `enable` by following up with `conf t`. The prompt will change to include `(config)` to indicate the state change.

```bash
ICX6450-24P Router#conf t
ICX6450-24P Router(config)#
```

## L3 routing
See below for official Brocade documentation.
- <https://images10.newegg.com/UploadFilesForNewegg/itemintelligence/Brocade/ICX6650_07500_Routing_ConfigGuide1400511787577.pdf>
- <https://support.ruckuswireless.com/documents/3458-fastiron-08-0-95-ga-layer-3-routing-configuration-guide>

### L3 setup with Pfsense or Opnsense
Follow [this guide](https://www.michaelstinkerings.org/how-to-setup-l3-switch-to-work-with-pfsense/) to setup layer 3 routing in conjunction with pPfsense or Opnsense.

The `ip default-network {router ip address}` did not work for me as listed in the guide to create a default route to the firewall. Use `ip route 0.0.0.0 0.0.0.0 {router ip address}` instead as listed in [this guide](https://greigmitchell.co.uk/2019/08/configuring-intervlan-routing-with-a-layer-3-switch-and-pfsense/).

## DHCP helper-address

If the switch itself is not used as a DHCP server, you will need to set up IP helper-address(s) to each virtual interface to point to your dns servers IP address(s).

An example is below with virtual interface 2 already set up on the switch, where `{dhcp server ip address}` is the IP address of your DHCP server.

```bash
ICX6450-24P Router>enable
ICX6450-24P Router#conf t
ICX6450-24P Router(config)#interface ve 2
ICX6450-24P Router(config-int-ve-2)#ip helper-address {dhcp server ip address}
ICX6450-24P Router(config-int-ve-2)#exit
```

You can add multiple DHCP servers on the same virtual interface.

Do this for all required virtual interfaces, then write to memory and exit.

```bash
ICX6450-24P Router(config)#write memory
ICX6450-24P Router(config)#exit
```

## Dual-mode

To set up a port with an untagged (native) vlan with one or multiple tagged vlans, the `dual-mode` command is used.

An example is below where we want port 1/1/1 to have untagged vlan 10 and tagged vlan 20 and vlan 30.

First, each vlan needs to be set as **tagged** for port 1/1/1.

```bash
ICX6450-24P Router>enable
ICX6450-24P Router#conf t
ICX6450-24P Router(config)#vlan 10
ICX6450-24P Router(config-vlan-10)#tag eth 1/1/1
ICX6450-24P Router(config-vlan-10)#vlan 20
ICX6450-24P Router(config-vlan-20)#tag eth 1/1/1
ICX6450-24P Router(config-vlan-20)#vlan 30
ICX6450-24P Router(config-vlan-30)#tag eth 1/1/1
ICX6450-24P Router(config-vlan-30)#exit
```

Now set `dual-mode` for vlan 10.

```bash
ICX6450-24P Router(config)#interface ethernet 1/1/1
ICX6450-24P Router(config-if-e1000-1/1/1)#dual-mode 10
ICX6450-24P Router(config-if-e1000-1/1/1)#exit
```

Write to memory and exit.

```bash
ICX6450-24P Router(config)#write mem
ICX6450-24P Router(config)#exit
```

Check configuration.

```bash
ICX6450-24P Router#show vlan br eth 1/1/1
```

> Port 1/1/1 is a member of 3 VLANs<br/>
> VLANs 10 20 30<br/>
> Untagged VLAN : 10<br/>
> Tagged VLANs : 20 30

Now port 1/1/1 has untagged vlan 10 with tagged vlan 20 and vlan 30!

## Defualt vlan error when setting untagged vlan on port

If you try and set the untagged (native) vlan on a port and get `error – port eth x/x/x are not member of default vlan`, the typical reason is that other vlans are attached to the port as either untagged or tagged. To put a port into a vlan other than default as untagged, no other vlans can be bound to that port.

An example is below where the default vlan is vlan 999 and we want port 1/1/3 to have untagged vlan 16.

> [!NOTE]
> The default vlan would be vlan 1 on a switch that it was not manually changed on.

First, check what vlans are attached to the port.

```bash
ICX6450-24P Router>show vlan br eth 1/1/3
```

> Port 1/1/3 is a member of 3 VLANs<br/>
> VLANs 32 48 999<br/>
> Untagged VLAN : 999<br/>
> Tagged VLANs : 32 48

So now we know its untagged vlan 999 (default) but tagged vlan 32 and vlan 48. We need to remove the tags of vlan 32 and vlan 48 on this port before we can add vlan 16 as untagged.

```bash
ICX6450-24P Router>enable
ICX6450-24P Router#conf t
ICX6450-24P Router(config)#vlan 32
ICX6450-24P Router(config-vlan-32)#no tag eth 1/1/3
ICX6450-24P Router(config-vlan-32)#exit
ICX6450-24P Router(config)#vlan 48
ICX6450-24P Router(config-vlan-48)#no tag eth 1/1/3
ICX6450-24P Router(config-vlan-48)#exit
```

Add untagged vlan 16.

```bash
ICX6450-24P Router(config)#vlan 16
ICX6450-24P Router(config-vlan-16)#unt eth 1/1/3
ICX6450-24P Router(config-vlan-16)#exit
````

Write to memory and exit.

```bash
ICX6450-24P Router(config)#write mem
ICX6450-24P Router(config)#exit
```

Check configuration.

```bash
ICX6450-24P Router>show vlan br eth 1/1/3
```

> Port 1/1/3 is a member of 1 VLANs<br/>
> VLANs 16<br/>
> Untagged VLAN : 16<br/>
> Tagged VLANs :

Now port 1/1/3 has untagged vlan 16!
