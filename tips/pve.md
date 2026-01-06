# Proxmox VE tips

Compilation of [Proxmox VE](https://proxmox.com/en/products/proxmox-virtual-environment/overview) (PVE) tips and tricks to share.    

> [!NOTE]
> Any tips and tricks being done within PVE CTs or VMs were created for Ubuntu, and even though they contain specific Ubuntu/Debian instructions, the concepts are generic enough and can be applied on most Linux distributions, even on those not based on Debian (for example, CentOS and OpenSUSE).
>
> Unless you see a shebang `(#!/...)`, these code blocks are usually meant to be copy & pasted directly into the shell. Some of the steps will not work if you run part of them in a script and copy paste other ones as they rely on variables set before.  
>
> The `{` and `}` surrounding some scripts are meant to avoid poisoning your bash history with individual commands, etc. You can ignore them if you manually copy paste the individual commands.

## Table of contents
- [Helper-scripts](#helper-scripts)
- [Install](#install)
  - [Installer shortcuts](#installer-shortcuts)
- [Storage](#storage)
  - [Discard](#discard)
    - [CT](#ct)
    - [VM](#vm)
  - [Preventing full storage](#preventing-full-storage)
  - [Rescanning disks/volumes](#rescanning-disksvolumes)
  - [Importing disk images](#importing-disk-images)
  - [ZFS](#zfs)
    - [Check space usage and ratios](#check-space-usage-and-ratios)
    - [Find old ZFS snapshots](#find-old-zfs-snapshots)
    - [Shrink a CT's disk](#shrink-a-cts-disk)
    - [Update ZFS ARC size](#update-zfs-arc-size)
  - [Find unused disks/volumes](#find-unused-disksvolumes)
  - [Monitor disk SMART information](#monitor-disk-smart-information)
  - [Check which PCI(e) device a disk belongs to](#check-which-pcie-device-a-disk-belongs-to)
- [Passthrough](#passthrough)
  - [Passthrough recovery](#passthrough-recovery)
  - [Checking IOMMU groups](#checking-iommu-groups)
    - [CLI](#cli)
    - [GUI](#gui)
  - [Binding PCIe devices to VFIO](#binding-pcie-devices-to-vfio)
  - [GPU passthrough](#gpu-passthrough)
    - [VM](#vm-1)
    - [CT](#ct-1)
      - [Nvidia specific](#nvidia-specific)
      - [Generic](#generic)
  - [SR-IOV](#sr-iov)
    - [NICs](#nics)
    - [Intel Arc Pro B-Series](#intel-arc-pro-b-series)
  - [Install intel drivers and modules](#install-intel-drivers-and-modules)
  - [Install nvidia drivers and modules](#install-nvidia-drivers-and-modules)
    - [Via apt](#via-apt)
      - [Prerequisites](#prerequisites)
      - [Node and VM](#node-and-vm)
      - [CT](#ct-2)
      - [Verify installation](#verify-installation)
      - [Post install](#post-install)
    - [Via .run file](#via-run-file)
      - [Links and release notes](#links-and-release-notes)
      - [Download and install the .run file](#download-and-install-the-run-file)
        - [CT](#ct-3)
        - [VM](#vm-2)
        - [Node](#node)
        - [Create and enable persistence daemon](#create-and-enable-persistence-daemon)
  - [Install and configure NVIDIA Container Toolkit](#install-and-configure-nvidia-container-toolkit)
  - [Check which PCI(e) device a drm device belongs to](#check-which-pcie-device-a-drm-device-belongs-to)
- [Networking](#networking)
  - [Prevent NIC name changes](#prevent-nic-name-changes)
  - [Network testing](#network-testing)
    - [Temporary DHCP](#temporary-dhcp)
    - [Find NIC port](#find-nic-port)
  - [Updating ip](#updating-ip)
  - [Find old network configs](#find-old-network-configs)
- [Debugging and Recovery](#debugging-and-recovery)
  - [Temporary kernel arguments](#temporary-kernel-arguments)
  - [Monitor swap usage](#monitor-swap-usage)
  - [IO debugging](#io-debugging)
    - [General](#general)
      - [IO Delay](#io-delay)
      - [iotop-c](#iotop-c)
      - [iostat](#iostat)
      - [fatrace](#fatrace)
    - [ZFS related](#zfs-related)
      - [Checking ZFS latency stats](#checking-zfs-latency-stats)
      - [Checking ZFS queue stats](#checking-zfs-queue-stats)
      - [Checking ZFS request sizes](#checking-zfs-request-sizes)
  - [Filter journal messages](#filter-journal-messages)
- [Miscellaneous](#miscellaneous)
  - [Enable no-subscription repositories](#enable-no-subscription-repositories)
  - [Windows guest best practices](#windows-guest-best-practices)
  - [Making KSM start sooner](#making-ksm-start-sooner)
  - [Enabling a VM's serial console](#enabling-a-vms-serial-console)
  - [Restore guest configs](#restore-guest-configs)
  - [Credentials](#credentials)
  - [Fix locales](#fix-locales)
  - [Enable package notifications](#enable-package-notifications)
  - [Fix boot UUIDs not found message with initial ram filesystem](#fix-boot-uuids-not-found-message-with-initial-ram-filesystem)
  - [Disable PVE cluster daemons](#disable-pve-cluster-daemons)
  - [Why not use `local` for guest disks?](#why-not-use-local-for-guest-disks)
- [Reference](#reference)

## Helper-scripts
If you are a fan of scripts, see [Proxmox VE helper-scripts](https://community-scripts.github.io/ProxmoxVE/) for a compiled list of all types of helpful scripts.

## Install
## Installer shortcuts
Inside the PVE/PBS installer you can use the following shortcuts. The terminal is particularily useful in case you need a live environment or do some pre-install customizations.

| Shortcut      | Info           |
| ------------- | -------------- |
| `CTRL+ALT+F1` | Installer      |
| `CTRL+ALT+F2` | Logs           |
| `CTRL+ALT+F3` | Terminal/Shell |
| `CTRL+ALT+F4` | Installer GUI  |

If you press `E` you can add args that will be persisted into the installed system.

## Storage
## Discard
Using trim/discard with thinly allocated disks (which is the default) gives space back to the storage. This saves space, makes backups faster and is needed for thin provisioning to work as expected. This is not related to the PVE storage being backed by a SSD. Use it whenever the storage is thin provisioned.

[For ZFS, this still counts even if thin provision (see note below) is not enabled](https://www.reddit.com/r/Proxmox/comments/1kr98iv/server_2022_disk_discard_option_on_zfs/mtdi7cg/), however you may still want to enable `Thin Provisioning` in `Datacenter > Storage` for your ZFS storage.

![image](https://gist.github.com/user-attachments/assets/04330006-1a4b-4aa3-aff4-33f1e9be3471).   

This will only affect newly created disks, but [you can apply the setting for already existing disks](https://forum.proxmox.com/threads/storage-usage.167052/#post-776013).

Check `lvs`'s `Data%` column and `zfs list`'s `USED`/`REFER`. You might find it to go down when triggering a trim as explained below.

Documentation:    
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_trim_discard>
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#qm_hard_disk_discard>
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_thin_provisioning>
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_storage_types>
- [And this arch Wiki article](https://wiki.archlinux.org/title/Solid_state_drive#TRIM). This is more about the hardware side though.   

### CT
Containers usually cannot call [`fstrim`](https://man.archlinux.org/man/fstrim.8.en) themselves. You can trigger a one time immediate trim via `pct fstrim IDOFCTHERE` on the node.

I [use a cronjob calling `pct fstrim`](https://forum.proxmox.com/threads/fstrim-doesnt-work-in-containers-any-os-workarounds.54421/#post-278310), added using `crontab -e`.    

```bash
30 0 * * 0 pct list | awk '/^[0-9]/ {print $1}' | while read ct; do pct fstrim ${ct}; done
```

You can also run the command after `30 0 * * 0 ` manually on the node, of course.    

Alternatively you can select `discard` (PVE 8.3+) as amount option so this happens immediately and continuously.

> [!NOTE]
> You do not need to enable this for `pct fstrim` to work.

![image](https://gist.github.com/user-attachments/assets/1de6263c-28d2-4ab3-92c6-324d3c5f310d)

### VM
You can trigger a one time immediate trim (as root) using `fstrim -av` from inside a VM.  

You can also trigger it from the node side using `qm guest exec` if the VM has the guest agent enabled and configured.    

```bash
qm list | grep "running" | awk '/[0-9]/ {print $1}' | while read vm; do echo "Trimming ${vm}"; qm guest exec ${vm} -- fstrim -av; done
```

Most OSs come with a `fstrim.timer` which, by default, does a weekly `fstrim` call.  

You can check with `systemctl status fstrim.timer`. If disabled run `systemctl enable fstrim.timer`.  

To edit it to happen more frequently run `systemctl edit fstrim.timer` and add the following.    

```bash
[Timer]
OnCalendar=daily
```

> [!NOTE]
> Some guest operating systems may also require the `SSD emulation` flag to be set. If you would like a drive to be presented to the guest as a solid-state drive rather than a rotational hard disk, you can set the `SSD emulation` option on that drive. There is no requirement that the underlying storage actually be backed by SSDs; this feature can be used with physical media of any type.

For trim/discard to properly work the disk(s) should have the `discard` flag set.

![image](https://gist.github.com/user-attachments/assets/6a7fd22f-b848-49ec-b535-bf0e7713b8a4)

If you use the Guest Agent (which you really should), it is also recommend to enable the following under `Options > QEMU Guest Agent`.

![image](https://gist.github.com/user-attachments/assets/1357a9ad-e22e-46f4-8bf7-a6a449ad13a3)

## Preventing full storage
When using thin allocation it can be problematic when a storage reaches 100%. For ZFS you may also want to stay below a certain threshold.

If your storage is already full, [see this forum post specific to ZFS](https://forum.proxmox.com/threads/protect-a-pbs-datastore-on-zfs-so-that-it-does-not-become-completely-full.166768/#post-774198).   
 
I use [a modified version of this snippet](https://forum.proxmox.com/threads/solved-you-have-not-turned-on-protection-against-thin-pools-running-out-of-space.91055/#post-547417) to send me mail if any of my storages reach 75% usage.

```bash
# Storage running out of storage. Percentage escaped due to crontab.
*/15 * * * * /usr/sbin/pvesm status 2>&1 | /usr/bin/grep -Ev "disabled|error" | tr -d '\%' | awk '$7 >=75 {print $1,$2,$7}' | column -t
```

Or to check a specific type of storage, LVM-Thin in this case.

```bash
*/15 * * * * /usr/sbin/pvesm status 2>&1 | /usr/bin/grep "lvmthin" | grep -Ev "disabled|error" | tr -d '\%' | awk '$7 >=75 {print $1,$2,$7}' | column -t
```

A similar method can be used to check the file system directly for, in this example, at least 100G~ of free space.

```bash
*/15 * * * * df /mnt/backupdirectory | tail -n1 | awk '$4 <=100000000 {print $1,$4,$5}' | column -t
```

> [!TIP]
> It's generally advised to use the full path to executables in cronjobs (like `/usr/sbin/pvesm`) as `PATH` is different.
>
> I use this at the top of mine so I don't have to care about that and the job is cleaner.
> 
> ```bash
> SHELL=/bin/bash
> PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
> ```

## Rescanning disks/volumes
`pct rescan` and `qm rescan` can be useful to find missing volumes and add them to their respective VM or CT.  

You can find them as unused disks in `Hardware > Resources`.

## Importing disk images
You don't have to use the CLI via `qm disk import`, you can also use the GUI to import disk images or whole machines.    

This assumes you use the `local` storage. Replace with whatever directory storage you want to use.

Go to `Datacenter > Storage` and modify `local` to have the `Import` content type.  

![image](https://gist.github.com/user-attachments/assets/1c9150af-7ab5-4025-8ee2-eb7e8c21a89b)

Go to `local > Import` and use the buttons at the top to upload/download/import your OVA/QCOW2/RAW/VMDK/IMG.  

![image](https://gist.github.com/user-attachments/assets/abdda5c9-fcd3-4dbd-87e9-427b9a4f99e7)

Select your file and click the `Import` button at the top.

If you already have a VM you can import the disk using `Hardware > Add > Import Hard Disk`.    

![](https://gist.github.com/user-attachments/assets/8e3e5f51-cb00-402a-952c-93826c2bec67)

When creating a new VM (from a OVA in this example) you can delete the existing disk and select `Import` to use it.

![](https://gist.github.com/user-attachments/assets/e202abd1-b52f-4540-8daf-8a30074c60d4)

![](https://gist.github.com/user-attachments/assets/f26fd87b-8d57-42fd-a25b-20312bed5337)

> [!TIP]
> When importing, I recommend to change the following settings for linux guests.
> - `OS Type > Linux`
> - `Advanced > Disks > SCSI Controller > VirtIO SCSI single`
> - `Advanced > Network Interfaces > Model > VirtIO (paravirtualized)`
>
> [Follow this](#windows-guest-best-practices) for Windows guests. 

## ZFS
### Check space usage and ratios
This sorts by compression ratio.

```bash
zfs list -ospace,logicalused,compression,compressratio -rS compressratio
```

This sorts by used size.

```bash
zfs list -ospace,logicalused,compression,compressratio -rS used
```

### Find old ZFS snapshots
If above shows `USEDSNAP` being very high and you already deleted snapshots or have none it might be from a old or broken migration task.    

It might make sense to add a ` | less` at the end if you have lots of snapshots.

```bash
zfs list -ospace,logicalused,compression,compressratio,creation -rs creation -t snap
```

### Shrink a CT's disk
Since CTs use datasets this is very trivial and should be reasonably safe but make sure to take backups.    

First grab some information about the CT you want to modify (ID 120 in this example).

```bash
zfs list -ospace,logicalused,refquota | grep -E "NAME|120"
```

```bash
NAME                       AVAIL   USED  USEDSNAP  USEDDS  USEDREFRESERV  USEDCHILD  LUSED  REFQUOTA
nvmezfs/subvol-120-disk-0  7.02G  23.0G      160K   23.0G             0B         0B  28.3G       30G
```

Take note of `USED` and then simply set the `refquota` to what you want. Don't set the quota too low or lower than `USED`.      
```bash
zfs set refquota=29G nvmezfs/subvol-120-disk-0
```

Lastly run a `pct rescan`.

```bash
pct rescan
```

> rescan volumes...<br/>
> CT 120: updated volume size of 'nvmezfs:subvol-120-disk-0' in config.


This works for growing it too, but the GUI already provides that option.

### Update ZFS ARC size
Adapted from [the official documentation](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_zfs_limit_memory_usage).

> [!NOTE]
> PVE uses 10% of the host's memory by default but it only configures the system like that if the OS was installed on ZFS. If you configure a ZFS storage after installation, the defaults of 50% will be used which you probably don't want.
> 
> [This is fixed in PVE 9 (ZFS 2.3+)](https://github.com/openzfs/zfs/pull/15437).    

#### Validate
Check the current ARC size.

```bash
arc_summary -s arc

# Also helpful
arcstat

# To check hit ratios
arc_summary -s archits
```

Check the config file (which might not exist).

```bash
cat /etc/modprobe.d/zfs.conf
```

#### Adapt config
To calculate a percentage of your total memory in G you can use the following. It will try to not replace your file, only update it.

```bash
PERCENTAGE=10
grep MemTotal /proc/meminfo | awk -v percentage=$PERCENTAGE '{print int(($2 / 1024^2) / 100 * percentage)}'
```

Set the size in G to adapt.

```bash
ARC_SIZE_G=32
```

Then enter the following to do the rest.

```bash
{
MEMTOTAL_BYTES="$(($(awk '/MemTotal/ {print $2}' /proc/meminfo) * 1024))"

ARC_SIZE_BYTES_MIN="$(( MEMTOTAL_BYTES / 32 ))"
ARC_SIZE_BYTES_MAX=$(( ARC_SIZE_G * 1024*1024*1024 ))

if [ "$ARC_SIZE_BYTES_MAX" -lt "$ARC_SIZE_BYTES_MIN" ]; then
    echo "Error: Given ARC Size of ${ARC_SIZE_BYTES_MAX} is lower than the current default minimum of ${ARC_SIZE_BYTES_MIN}. Please increase it."
    :
elif [ "$ARC_SIZE_BYTES_MAX" -gt "$MEMTOTAL_BYTES" ]; then
    echo "Error: Given ARC Size of ${ARC_SIZE_BYTES_MAX} is greater than the total memory of ${MEMTOTAL_BYTES}. Please decrease it."
    :
fi

echo "$ARC_SIZE_BYTES_MAX" > /sys/module/zfs/parameters/zfs_arc_max

if grep -q "options zfs zfs_arc_max" "/etc/modprobe.d/zfs.conf" 2> /dev/null; then
    sed -ri "s/.*options zfs zfs_arc_max.*/options zfs zfs_arc_max=$ARC_SIZE_BYTES_MAX # ${ARC_SIZE_G}G/gm" /etc/modprobe.d/zfs.conf
else
    echo -e "options zfs zfs_arc_max=$ARC_SIZE_BYTES_MAX # ${ARC_SIZE_G}G" >> /etc/modprobe.d/zfs.conf
fi
}
```

#### Final steps
Check the config and ARC again to see if everything looks alright, then finally update the initramfs. This is needed so the settings are persisted.

```bash
# -k all might not be needed and omitting it speeds up the process
update-initramfs -u -k all
```

There is no reboot necessary.

## Find unused disks/volumes
> [!WARNING]
> Be careful here. I trust you have backups.

First rescan.

```bash
qm rescan
pct rescan
```

Now find unused disks in the configs.

```bash
grep -sR "^unused[0-9]+: " /etc/pve/
```

> /etc/pve/nodes/pve/qemu-server/500.conf:unused0: nvmezfs:vm-500-disk-1

Investigate their source.

```bash
pvesm path nvmezfs:vm-500-disk-1
```

/dev/zvol/nvmezfs/vm-500-disk-1

Show all of their paths.

```bash
grep -sR "^unused[0-9]+: " /etc/pve/ | awk -F': ' '{print $2}' | xargs -I{} pvesm path {}
```

Then delete if needed.

```bash
qm set 500 --delete unused0
```

Below is a script to do all of this for you. It only tells you the commands, not run them.  

```bash
{
find /etc/pve/ -name '[0-9]*.conf' | while read -r config; do
    [[ "$config" == *"/lxc/"* ]] && CMD="pct" || CMD="qm"

    guest=$(basename "$config" .conf)
    unused_lines=$(grep -E '^unused[0-9]+: ' "$config") || continue

    echo "$unused_lines" | while read -r line; do
        echo "# $line"
        disk=$(echo "$line" | awk -F':' '{print $1}')
        echo -e  "$CMD set $guest --delete $disk\n"
    done
done
}
```

## Monitor disk SMART information
Below shows how you can monitor the SMART info of disks. This creates a nice "table" and highlights changes.

Temperature.

```bash
watch -x -c -d -n1 bash -c 'for i in /dev/{nvme[0-9]n1,sd[a-z]}; do echo -e "\n[$i]"; smartctl -a $i | grep -Ei "Device Model|Model Number|Serial|temperature"; done'
```

Errors.

```bash

watch -x -c -d -n1 bash -c 'for i in /dev/{nvme[0-9]n1,sd[a-z]}; do echo -e "\n[$i]"; smartctl -a $i | grep -Ei "Device Model|Model Number|Serial|error"; done'

```

Temperature and writes.

```bash
watch -x -c -d -n1 bash -c 'for i in /dev/{nvme[0-9]n1,sd[a-z]}; do echo -e "\n[$i]"; smartctl -a $i | grep -Ei "Device Model|Model Number|Serial|temperature|writ"; done'
```

...and so on.

## Check which PCI(e) device a disk belongs to
This is useful if you want to know to which controller a disk is connected to.    

Note the values before and after the `->`. In this example, `02:00.1` and `08:00.0`,          

```bash
ls -l /dev/disk/by-path/
```

> lrwxrwxrwx 1 root root  9 Jul  1 18:05 pci-0000:02:00.1-ata-2 -> ../../sda<br/>
> lrwxrwxrwx 1 root root 13 Jul  1 18:05 pci-0000:08:00.0-nvme-1 -> ../../nvme0n1

You can then cross-reference them with the first column of `lspci`.

```bash
lspci
```

> 02:00.1 SATA controller: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset SATA Controller<br/>
> 00:08.0 Host bridge: Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge

> [!NOTE]
> You can't necessarily rely on the name to always refer to the same device. 

## Passthrough
## Passthrough recovery
When passing through devices it can sometimes happen that your device shares an IOMMU group with something else that's important.  

It's also possible that groups shift if you exchange a device. All of this can cause a system to become unbootable.  

If [editing the boot arguments](#temporary-kernel-arguments) doesn't help, the simplest fix is to go into the UEFI/BIOS and disable every virtualization related thing (VT-x, VT-d, SVM, ACS, IOMMU or whatever it's called for you).

## Checking IOMMU groups
[I like this script for checking IOMMU groups](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Ensuring_that_the_groups_are_valid). You can also get device ID from this as well.

For your convenience.

```bash
{
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
}
```

To check the `hostpci` settings of existing VMs (to find which ones use passthrough).  

```bash
grep -sR "hostpci" /etc/pve
```

### CLI
To check the IOMMU groups in the CLI.

```bash
lspci -vv | grep -P "\d:\d.*|IOMMU"
```

If you want to use PVE tooling to check the IOMMU groups instead.  

```bash
pvesh get /nodes/$(hostname)/hardware/pci --pci-class-blacklist ""
```

### GUI
To check the IOMMU groups in the GUI you can use the `Hardware` tab of the VM when adding a PCI(e) device.

![image](https://gist.github.com/user-attachments/assets/23d54674-59bb-4eea-be98-cd6e45874740)

Or you can check in `Datacenter > Resource Mappings` which I think is easier to read because of its tree structure.    

> [!TIP]
> `Resource Mappings` also warns about IOMMU groups PVE is unable to locate. This usually happens when installing additonal or new hardware and the IOMMU group location changes.

![image](https://gist.github.com/user-attachments/assets/aa5b8d15-ec2d-4ad0-ba90-691f0a71f988)

## Binding PCIe devices to VFIO

If you want to passthrough an entire device to a VM, I recommend binding that device to VFIO drivers so that PVE does not have to switch drivers upon VM boot.

> [!NOTE]
> PVE 9 is fairly good at automatically switching between drivers, so this is not usually required. I still do this as best practice.

Get device vendor, device ID, and driver from `lspci -nnk` or [checking IOMMU groups above](#checking-iommu-groups).

Create `vfio.conf` file and edit.

```bash
touch /etc/modprobe.d/vfio.conf
nano /etc/modprobe.d/vfio.conf
```

Add the following, where `1234:5678` is the vendor and device ID you looked up. Add as many IDs as needed with a `,` in between.

```bash
options vfio-pci ids=1234:5678,1234:5678
```

Even with IDs mapped to vfio-pci, the vfio-pci drivers may still not be loaded on boot because the actual driver of the device loads beforehand. To ensure the vfio-pci driver loads before the actual driver of device, create `softdep.conf` file and edit.

```bash
touch /etc/modprobe.d/softdep.conf
nano /etc/modprobe.d/softdep.conf
```

Add the following, where `{driver_name}` is the driver name of the device that you looked up. Add as many lines as needed.

```bash
softdep {driver_name} pre: vfio-pci
softdep {driver_name} pre: vfio-pci
```

Update initramfs.

```bash
update-initramfs -u -k all
```

Reboot Proxmox and check that the drivers being used by the devices are now `vfio-pci` from `lspci -nnk` or [checking IOMMU groups above](#checking-iommu-groups).

## GPU passthrough
This will likely never be a complete tutorial, just some often shared commands, tips and scripts.  

Documentation:
- <https://pve.proxmox.com/wiki/PCI(e)_Passthrough>
- <https://pve.proxmox.com/wiki/PCI_Passthrough>
- <https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF>

### VM
For VMs, [add VFIO modules](#add-vfio-modules), [bind the GPU to VFIO drivers](#binding-pcie-devices-to-vfio) and verify that the `vfio-pci` driver is in use.

```bash
lspci -vnnk | awk '/VGA/{print $0}' RS= | grep -Pi --color "^|(?<=Kernel driver in use: |Kernel modules: )[^ ]+"
```

[Check the IOMMU groups](#passthrough-tips) and passthrough the GPU [using `Resource Mapping`](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#resource_mapping) (PVE 8+).

> [!TIP]
> Make sure `PCI-Express` is checked when adding the mapped device to the VM. `ROM-Bar` should also be checked, but is by default.

![](https://gist.github.com/user-attachments/assets/8b788ffe-67ce-48e4-908c-7e705fc2fc32)

Once the GPU is passed to a VM, install drivers within the VM like normal.
- [Intel](#install-intel-drivers-and-modules).
- [Nvidia](#install-nvidia-drivers-and-modules).
- AMD (coming soon).

### CT
Unlike VMs, we do not bind drivers to VFIO for CTs.

Make sure you can see the device in PVE and that it uses the expected driver (`nvidia`, `amdgpu`, `i915`, `xe`, etc).

```bash
lspci -vnnk | awk '/VGA/{print $0}' RS= | grep -Pi --color "^|(?<=Kernel driver in use: |Kernel modules: )[^ ]+"
```

If nvidia devices are not available when the system boots you can work around it by adding this to your crontab via `crontab -e`

```bash
@reboot /usr/bin/nvidia-smi > /dev/null
```

#### Nvidia specific
For Nvidia you can use the [Nvidia Container Toolkit](#install-and-configure-nvidia-container-toolkit). The benefits of this are that you do not have to install drivers inside the CT, don't have to add `dev`ices or check groups, it helps with changing render device names (multi GPU) and you will also not have the problem of different driver version conflicts on upgrades.

It's very simple and my recommended way to do this for NVIDIA GPUs.

Install the NVIDIA drivers [via `apt`](#via-apt) (recommended) or [via `.run` file](#via-run-file) and the [Nvidia Container Toolkit](#install-and-configure-nvidia-container-toolkit) on the node.

Set a variable with a list of your CT IDs you want to configure. `pct list` shows them. In this example, it's CTs 400 and 55.

```bash
CTIDS=(400 55)
```

Then run the following into the node's CLI. This will prepend the needed lines into the CT's config file and reboot it.

```bash
{
for ct in $(pct list | awk '/^[0-9]/ {print $1}'); do
    if [[ ! "${CTIDS[@]}" =~ "$ct" ]]; then
      continue
    fi

    echo "# $ct"
  
    if grep -q "/usr/share/lxc/hooks/nvidia" "/etc/pve/lxc/${ct}.conf"; then
         echo "Already configured"
    else
        {
            echo "lxc.hook.pre-start: sh -c '[ ! -f /dev/nvidia0 ] && /usr/bin/nvidia-modprobe -c0 -u'"
            echo "lxc.environment: NVIDIA_VISIBLE_DEVICES=all"
            echo "lxc.environment: NVIDIA_DRIVER_CAPABILITIES=all"
            echo "lxc.hook.mount: /usr/share/lxc/hooks/nvidia"
            cat /etc/pve/lxc/${ct}.conf
        } > /etc/pve/lxc/${ct}.conf.new && mv /etc/pve/lxc/${ct}.conf.new /etc/pve/lxc/${ct}.conf

        echo "Configured"

        echo "pct reboot $ct"
        pct reboot "$ct"
    fi
done
}
```

If everything was done correctly, running `nvidia-smi` inside the CT should work.

#### Generic
Check the video and render group IDs inside the CT (from the node side). This is important later. The default ones below should work for Debian.

Define which CT IDs we want to work with.

```bash
# CT IDs to check the groups for
CTIDS=(5555 2222 55)
```

Check the video and render groups of the CTs with those IDs.

```bash
for id in ${CTIDS[@]}; do
    echo "# $id"
    pct exec $id getent group video render | awk -F: '{print $1,$3}'
    echo ""
done
```

This procedure simply calls `pct set IDOFCTHERE --devX /givenpath` for all the given paths and reboots the CT. It handles the optional GIDs (for the video and render groups) when given. Modify it to add more devices and change the GIDs. Invalid paths and CTs will be skipped so there's no need to remove anything you don't have.

Define which CT IDs we want to work with and which devices to pass to them.

```bash
# CT IDs to add the devices to
CTIDS=(5555 2222 55)
```

Also see [Check which PCI(e) device a drm device belongs to](#check-which-pcie-device-a-drm-device-belongs-to).    

```bash
# Devices to add to the CT(s)
DEVICES=(
  "/dev/dri/renderD128,gid=104"
  "/dev/dri/renderD129,gid=104"
  "/dev/dri/renderD130,gid=104"
  "/dev/dri/renderD131,gid=104"
  "/dev/dri/card0,gid=44"
  "/dev/dri/card1,gid=44"
  "/dev/dri/card2,gid=44"
  "/dev/dri/card3,gid=44"
  "/dev/kfd,gid=104"
  "/dev/nvidia0"
  "/dev/nvidia1"
  "/dev/nvidia2"
  "/dev/nvidia3"
  "/dev/nvidiactl"
  "/dev/nvidia-uvm"
  "/invalid"
  "/dev/nvidia-uvm-tools"
)
```

Verify and show the group and user IDs for the devices on the node. The IDs/GIDs should match with the CT side above. If not modify them.    

> [!NOTE]
> You can run this inside the CT too.    

```bash
{
function showDeviceInfo() {
  echo "user userName group groupName device"
  for device in "${DEVICES[@]}"; do
        trimmedDevice=${device%%,*}

        if [ -e "$trimmedDevice" ]; then
          echo "$(stat -c '%u %U %g %G %n' "$trimmedDevice") $device"
        fi
  done
}

showDeviceInfo | column -t
}
```

Run the rest of the script.

```bash
{
for ct in $(pct list | awk '/^[0-9]/ {print $1}'); do
  if [[ ! "${CTIDS[@]}" =~ "$ct" ]]; then
    continue
  fi

  echo "# $ct"

  index=0
  for device in "${DEVICES[@]}"; do
      trimmedDevice=${device%%,*}

      if [ -e "$trimmedDevice" ]; then
        echo "pct set $ct --dev${index} $device"
        pct set "$ct" --dev${index} "$device"
        ((index++))
      fi
  done

  echo "pct reboot $ct"
  pct reboot "$ct"
done
}
```

## SR-IOV
### NICs
Coming soon.

### Intel Arc Pro B-Series
These instructions may apply to other Intel GPUs, like the other [Battlemage GPUs](https://hmc-tech.com/lists/gpu/intel/arch/battlemage), but have not been tested.

> [!WARNING]
> SR-IOV with Intel B50 pro and B60 pro GPUs requires the following:
> - Up-to-date firmware ([instructions below](#firmware)).
> - Kernel 6.17 or newer on the node (PVE 9.1 or later).
> - Kernel 6.17 or newer on the VM that the GPU function is being passed through to (I used Ubuntu 25.10).
> 
> It is possible to enable SR-IOV on earlier PVE releases if you [download the Proxmox patches to the kernel and make adjustments, including to apparmor](https://forum.level1techs.com/t/proxmox-9-0-intel-b50-sr-iov-finally-its-almost-here-early-adopters-guide/238107). I do not recommend this though.

#### BIOS settings
Ensure that `SR-IOV` and `Resizeable BAR` is enabled in the BIOS, which is [required for Intel GPUs](https://www.reddit.com/r/IntelArc/comments/15vpxm1/is_arc_supposed_to_be_unusable_without_rebar/).

Documentation:
- <https://www.intel.com/content/www/us/en/support/articles/000090831/graphics.html>

#### Firmware
The firmware on the GPU needs to be up-to-date, which may not be the case depending on when you bought it.

The easiest way to update the firmware is by installing the latest drivers on Windows, which the firmware updates are packaged with. Either install it in a standalone Windows 11 machine, or [create a Windows 11 VM](#windows-guest-best-practices) and [passthrough the GPU](#gpu-passthrough).

Download and install the [latest Intel drivers](https://www.intel.com/content/www/us/en/ark/products/series/242616/intel-arc-pro-b-series-graphics.html).

#### Check for SR-IOV functionality
> [!IMPORTANT]
> Do not [bind the GPU to VFIO](#binding-pcie-devices-to-vfio) when using SR-IOV functions. The `xe` driver must be in use.

With the correct BIOS settings enabled and the firmware updated, the GPU should now have SR-IOV functions enabled.

To check, [look up the GPU device ID](#checking-iommu-groups) and run the following.

```
lspci -vvv
```

Find the GPU using the device ID. In my case it was `c4:00`.

![](https://gist.github.com/user-attachments/assets/1c572435-6b86-4c9b-b4e9-95c7c332a4ef)

More specifically.

![](https://gist.github.com/user-attachments/assets/cf310f77-6312-4193-a0a7-36ccad669769)

> [!NOTE]
> Save the device ID for the next section.

#### Add SR-IOV functions
Find the GPU device under `/sys/devices`, where `xx:xx` is the device ID that you found above.

```bash
find /sys/devices -name "*xx:xx*" -type d
```

![](https://gist.github.com/user-attachments/assets/92636372-5ec7-4b17-ac4e-a6cae84e828a)

Go to that directory and look for `sriov_numvfs` and run the following, where `x` is the number of functions you want, in multiples of 2.

```bash
echo x > sriov_numvfs
```

Now you should have `x` additional devices using `lspci` or when [checking IOMMU groups](#checking-iommu-groups). In my case, 4 additional.

![](https://gist.github.com/user-attachments/assets/f55b80b0-7f9d-49fb-9816-b74051a44522)

#### Passthrough GPU function to VM
Now, just passthrough one of the GPU functions to a VM [like normal](#gpu-passthrough) and [install drivers and modules](#install-intel-drivers-and-modules).

#### Function persist
When rebooting the node, functions do not persist in the `sriov_numvfs` folder unless you add a cronjob or systemd service. Below are instructions for a cronjob.

```bash
crontab -e
```

Add the following, where `x` is the number of functions you want and `{path_to_sriov_numvfs_folder}` was the path we found above.

```bash
@reboot echo x > {path_to_sriov_numvfs_folder}
```

## Install intel drivers and modules

By default, Intel GPU drivers are already baked into the kernel as long as you have the appropriate kernel version or later.

To install compute and media related modules that may be needed for certain apps (plex, jellyfin, frigate, etc.), see [Intel's official documentation](https://dgpu-docs.intel.com/driver/client/overview.html).

For your convenience.

```bash
# Refresh the local package index and install the package for managing software repositories
sudo apt update
sudo apt install -y software-properties-common

# Add the intel graphics PPA
sudo add-apt-repository -y ppa:kobuk-team/intel-graphics

# Compute related packages
sudo apt install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc

# Media related packages
sudo apt install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo
```

Install these for both VMs and CTs.

Validate with `vainfo`.

## Install nvidia drivers and modules
### Via apt
It's a simpler method as it uses packages straight from repos. They might be a bit older but this should be fine and it makes installation simpler. Most guides use nvidia's `.run` files but then you have to update the drivers manually. Instead you can use the drivers/libs from the debian apt repository and update them like any other package.  

> [!NOTE]
> This has the disadvantage that you, at least by default unless you pin versions, have less control over updates and thus might need to reboot more often. For example, when the version of the running driver doesn't match the libraries and tools any more.

For Ubuntu, [follow the official documentation](https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/).

For Debian, continue below which are based on the [official debian documentation](https://wiki.debian.org/NvidiaGraphicsDrivers), modified for easy copy/pasting.

> [!NOTE]
> These commands should work for nodes, VMs and CTs as long as they are based on Debian.
>
> This assumes you use the `root` user.

> [!CAUTION]
> These command are to be run on the node/VM/CT. Copy & paste.

#### Prerequisites
We need the `non-free` component. You should be able to run this to add the component to your [`/etc/apt/sources.list.d/debian.sources`](https://wiki.debian.org/SourcesList) file and update the lists

```bash
# Rewrites apt *.list files to *.sources in DEB822 format
apt modernize-sources

# Optional to delete the backup files of the modernize tool above
find /etc/apt/sources.list.d/ -type f -name "*.bak" -delete

# Rewrites the "Components:" line to add non-free and non-free-firmware
sed -i 's/^Components: .*/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources

# Updates the lists
apt update
```

> [!IMPORTANT]
> If your node/VM uses Secure Boot (check with `mokutil --sb-state`), follow this section.
> 
> Make sure to monitor the next boot process via noVNC. You will be asked for the password when importing the key.    
>
> ```bash
> apt install dkms && dkms generate_mok
>
> dpkg -s proxmox-ve 2>&1 > /dev/null && apt install proxmox-default-headers || apt install linux-headers-generic
>
> # Set a simple password (a-z keys)
> mokutil --import /var/lib/dkms/mok.pub
>
> # If you followed this section after you already installed the driver run this and reboot
> # dpkg-reconfigure nvidia-kernel-dkms
> ```

#### Node and VM
```bash
apt install nvidia-detect

# Will likely recommend "nvidia-driver"
nvidia-detect

# "nvidia-smi" and "nvtop" are optional but recommended
apt install nvidia-driver nvidia-smi nvtop
```

#### CT
For CTs we just need the libraries so `nvidia-driver` is replaced with `nvidia-driver-libs`.

```bash
# "nvidia-smi" and "nvtop" are optional but recommended
apt install nvidia-driver-libs nvidia-smi nvtop
```

#### Verify installation
Now see if `nvidia-smi` works. A reboot might be necessary for the node or VM.

#### Post install
You can enable Persistence Daemon, which may help save power and decrease access delays. See [official Nvidia documentation](https://download.nvidia.com/XFree86/Linux-x86_64/396.51/README/nvidia-persistenced.html).   

> [!CAUTION]
> These commands are to be run on the node or VM. Copy & paste.

Enable and start it.

```bash
systemctl enable --now nvidia-persistenced.service
```

You can see the status in `nvidia-smi`.   

![image](https://gist.github.com/user-attachments/assets/e92eb823-470b-43f4-8e02-d962e749b27c)

### Via .run file
This alternative to the apt installation method gives you more control over the version but you have to update yourself.   

> [!NOTE]
> These commands should work for both the nodes, VMs and CTs as long as they are based on debian/ubuntu.
>
> This assumes you use the `root` user.

> [!CAUTION]
> These command are to be run on the node/VM/CT. Copy & paste.

#### Links and release notes
For datacenter (Some links are broken but you can google for the version).
- <https://developer.nvidia.com/datacenter-driver-archive>
- <https://docs.nvidia.com/datacenter/tesla/index.html>

For linux/unix.
- <https://www.nvidia.com/en-us/drivers/unix/linux-amd64-display-archive/>
- <https://www.nvidia.com/en-us/drivers/unix/>

#### Download and install the .run file
> [!IMPORTANT]
> `{link_from_above}` below means the link you grabbed from above.

##### CT
```bash
wget {link_from_above}
chmod +x NVIDIA*.run
# Adjust if necessary. Add -q to skip questions
./$(ls -t NVIDIA*.run | head -n 1) --no-kernel-modules
```

##### VM
```bash
apt install -y linux-headers-generic gcc make dkms 
wget {link_from_above}
chmod +x NVIDIA*.run
# Adjust if necessary. Add -q to skip questions
./$(ls -t NVIDIA*.run | head -n 1) --dkms
```

##### Node
```bash
apt install -y proxmox-default-headers gcc make dkms
wget {link_from_above}
chmod +x NVIDIA*.run
# Adjust if necessary. Add -q to skip questions
./$(ls -t NVIDIA*.run | head -n 1) --dkms --disable-nouveau --kernel-module-type proprietary --no-install-libglvnd
```

##### Create and enable persistence daemon
Also [see above](#enable-persistence-daemon).

```bash
cat <<EOF > /etc/systemd/system/nvidia-persistenced.service
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user nvpd
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable --now nvidia-persistenced.service
```

## Install and configure NVIDIA Container Toolkit

> [!CAUTION]
> These commands are to be run inside a CT or on the node. Copy & paste.

See the table below for where to install for your specific situation.

| Reason                                          | Install Location |
| ----------------------------------------------- | ---------------- |
| Pass through an Nvidia GPU to a CT              | Node             |
| Give a passed through GPU to a docker container | CT               |
| Give a passed through GPU to a docker container | VM               |

Adapted from the [official Nvidia documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

```bash
{
apt update && apt install -y gpg curl --no-install-recommends
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor > /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
cat <<EOF > /etc/apt/sources.list.d/nvidia-container-toolkit.sources
Types: deb
URIs: http://nvidia.github.io/libnvidia-container/stable/deb/amd64/
Suites: /
Components:
Signed-By: /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
EOF

apt update && apt install -y nvidia-container-toolkit

systemctl status docker.service >/dev/null 2>&1 && nvidia-ctk runtime configure --runtime=docker

# This is needed for LXC or you might get an error like
# nvidia-container-cli: mount error: failed to add device rules: unable to find any existing
# device filters attached to the cgroup: # bpf_prog_query(BPF_CGROUP_DEVICE) failed: operation
# not permitted: unknown
if [[ $(systemd-detect-virt) == "lxc" ]]; then
  nvidia-ctk config -i --set nvidia-container-cli.no-cgroups=true
fi

systemctl status docker.service >/dev/null 2>&1 && systemctl restart docker.service
}
```

If you installed this to run docker containers you can verify if it worked by runing the following.

```bash
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

## Check which PCI(e) device a drm device belongs to
If you have multiple GPUs you will likely have multiple `/dev/dri/card*` and `/dev/dri/renderD*` devices.    

Note the values before and after the `->`. In this example, `01:00.0`, `05:00.0` and `09:00.0`.

```bash
ls -l /sys/class/drm/*/device
```

```bash
lrwxrwxrwx 1 root root 0 May 17 07:54 /sys/class/drm/card0/device -> ../../../0000:05:00.0
lrwxrwxrwx 1 root root 0 May 17 07:54 /sys/class/drm/card1/device -> ../../../0000:09:00.0
lrwxrwxrwx 1 root root 0 May 17 07:54 /sys/class/drm/card2/device -> ../../../0000:01:00.0
lrwxrwxrwx 1 root root 0 May 17 07:54 /sys/class/drm/renderD128/device -> ../../../0000:09:00.0
lrwxrwxrwx 1 root root 0 May 17 07:54 /sys/class/drm/renderD129/device -> ../../../0000:01:00.0
```

You can then cross-reference them with the first column of `lspci | grep -i "VGA"`.

```bash
lspci | grep -i "VGA"
```

```bash
01:00.0 VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)
05:00.0 VGA compatible controller: ASPEED Technology, Inc. ASPEED Graphics Family (rev 41)
09:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Cezanne [Radeon Vega Series / Radeon Vega Mobile Series] (rev c8)
```

## Networking
## Prevent NIC name changes
[A NIC's name is hardware dependent](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#systemd_network_interface_names) and can change when you add or remove PCI(e) devices. Sometimes, major kernel upgrades can also cause this.  

Since the `/etc/network/interfaces` file which handles networking uses these names to configure your network, changes to the name will break it.  

To prevent those changes you can [use a systemd `.link` file to permanently override the name](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#network_override_device_names).    

[PVE 9 comes with the `pve-network-interface-pinning` pinning tool](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_using_the_pve_network_interface_pinning_tool).

## Network testing
You can show your NICs and assigned ips with `ip a`/`ip l`.  

If you have a PCI(e) NIC you can use the following to show the device(s) and their modules/drivers.

```bash
lspci -vnnk | awk '/Ethernet/{print $0}' RS= | grep -Pi --color "^|(?<=Kernel driver in use: |Kernel modules: )[^ ]+"
```

If you have a USB NIC you can use the following.

```bash
lsusb -vt | grep -Pi --color "^|(?<=Driver=)[^,]+"
```

Just skip the `| grep ...` with the poor regexes if you don't need to color the output.

The following shows the driver used for each NIC, which is useful because it shows the actual name like `eno1`.    

```bash
ls -l /sys/class/net/*/device/driver
```

```bash
lrwxrwxrwx 1 root root 0 May 15 12:58 /sys/class/net/enp6s0/device/driver -> ../../../../../../bus/pci/drivers/igb
lrwxrwxrwx 1 root root 0 May 15 12:58 /sys/class/net/enp7s0/device/driver -> ../../../../../../bus/pci/drivers/igb
lrwxrwxrwx 1 root root 0 May 15 12:58 /sys/class/net/enx00e04c680085/device/driver -> ../../../../../../../bus/usb/drivers/r8152
```

This shows the device path it belongs to.

Save the values before and after the `->`. In this example, `06:00.0` and and `07:00.0`. `enx00e889680195` is a USB device.      

You can then cross-reference them with the first column of the `lspci | grep -i "Ethernet"` or `lsusb -vt` output.    

```bash
ls -l /sys/class/net/*/device
```

```bash
lrwxrwxrwx 1 root root 0 Jun 24 12:32 /sys/class/net/enp6s0/device -> ../../../0000:06:00.0
lrwxrwxrwx 1 root root 0 Jun 24 12:32 /sys/class/net/enp7s0/device -> ../../../0000:07:00.0
lrwxrwxrwx 1 root root 0 Jun 24 12:32 /sys/class/net/enx00e889680195/device -> ../../../4-1:1.0
```
   
### Temporary DHCP
To temporarily use DHCP, use the following.

```bash
# PVE 8 / Debian 12
ifdown vmbr0; dhclient -v

# When done testing
dhclient -r; ifup vmbr0

# PVE 9 / Debian 13
ifdown vmbr0; dhcpcd -d

# When done testing
dhcpcd -k; ifup vmbr0
```

Optionally, pass the NIC name as argument to `dhclient`/`dhcpcd` to test a specific one. This is useful to check general router connectivity or what the subnet/gateway is. It also allows you to check if your DHCP reservation is properly set up.

### Find NIC port
To see which port a network cable is plugged into you can unplug it, run `dmesg -Tw` to follow the kernel logs and then plug it in again.

Use `CTRL+C` to stop following the kernel log.

The classic to make the LED blink.

```bash
# NIC from "DHCPREQUEST for x.x.x.x on {nic_name} to x.x.x.yx port 67"
ethtool --identify {nic_name}
```

Not really helpful if you have no network though as `ethtool` is not pre-installed.

## Updating ip
There's multiple ways (GUI or CLI) and multiple files to edit.  

You need to edit the following files.
- `/etc/network/interfaces` (`node > System > Network` in the GUI)
- `/etc/hosts` (`node > System > Hosts` in the GUI)
- `/etc/resolv.conf` (`node > System > DNS` in the GUI)
- `/etc/issue` (what you see when loggin in, just informational but still a good idea to update it)
- `/etc/pve/corosync.conf` (when in a cluster, `config_version ` needs to be incremented when you change things)

> [!TIP]
> I recommend using `grep -sR "{old_ip}" /etc` to check if you missed something, where `{old_ip}` is the old IP address.

Calling `pvebanner`, restarting the `pvebanner` service or rebooting should update the `/etc/issue` as well. Do this last.  

To reload `/etc/network/interfaces` and apply the new IP, you can use `ifreload -av` or simply reboot.

## Find old network configs
`ifupdown2` keeps old `interfaces` files in `/var/log/ifupdown2/`. You can find them by using the following.    

```bash
find /var/log/ifupdown2/ -name "interfaces"
```

## Debugging and Recovery
## Temporary kernel arguments
Pressing `E` during boot/install when the OS/kernel selection shows up allows you to temporarily edit the kernel arguments. This is useful to debug things or disable passthrough if you run into an issue.

| Argument                          | Info                                                          |
| --------------------------------- | ------------------------------------------------------------- |
| `nomodeset`                       | Helps with hangs during boot/install. Nvidia often needs that |
| `debug`                           | Debugging messages                                            |
| `fsck.mode=force`                 | Triggers a file system check                                  |
| `systemd.mask=pve-guests.service` | Prevents guests from starting up                              |

Documentation:
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#nomodeset_kernel_param>

Below are examples of how that selection can look like for PVE with grub/systemd and PBS installer.

![image](https://gist.github.com/user-attachments/assets/814c82fb-94d4-4973-8e1a-c3dae689c137)  

![image](https://gist.github.com/user-attachments/assets/03dfb8eb-2a67-4a18-91ee-1edac76b2a84)

![image](https://gist.github.com/user-attachments/assets/8046d78b-36c5-4347-ba13-5c62a06b2cb0)

![image](https://gist.github.com/user-attachments/assets/4e803185-64a1-4f6e-a84c-76d4a7d0941f)

![image](https://gist.github.com/user-attachments/assets/7e3b3c9b-c92f-476c-9a93-781f79c23345)

![image](https://gist.github.com/user-attachments/assets/e3da6df8-62d6-4062-b453-e882aa536393)

![image](https://gist.github.com/user-attachments/assets/3565fdf6-84d1-4315-9ee4-bca123167219)

## Monitor swap usage
```bash
apt install smem --no-install-suggests --no-install-recommends
# -a, --autosize        size columns to fit terminal size
# -t, --totals          show totals
# -k, --abbreviate      show unit suffixes
# -r, --reverse         reverse sort
# -s SORT, --sort=SORT  field to sort on
watch -n1 'smem -atkr -s swap'
```

## IO debugging
This  section is about how to check what process and disk causes wait (IO Delay), how fast it reads/writes and so on.    

Documentation:
- https://www.site24x7.com/learn/linux/troubleshoot-high-io-wait.html
- https://linuxblog.io/what-is-iowait-and-linux-performance/
- https://serverfault.com/questions/367431/what-creates-cpu-i-o-wait-but-no-disk-operations

### General
Install the dependencies first.

```bash
apt install -y sysstat iotop-c fatrace
```

#### IO Delay
IO delay or IO Wait is shown in the PVE `Summary` and good ol' `top` can also be used to check the IO wait via its `wa` in the CPU column.

![image](https://gist.github.com/user-attachments/assets/fc4757e1-7fa8-423f-a641-5affcb341ccd)    

![image](https://gist.github.com/user-attachments/assets/65c9620b-002b-4c7f-9cc3-39f7f8ca2540)

#### iotop-c 
`iotop-c` can show per process statistics. For it to properly work (see why below) you should [add the `delayacct` kernel arg](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysboot_edit_kernel_cmdline) and reboot.    

Alternatively, use `sysctl kernel.task_delayacct` to switch the state at runtime.    

> [!NOTE]
> Only tasks started after enabling it will have delayacct information.  

Documentation:
- <https://docs.kernel.org/accounting/delay-accounting.html#usage>

Run this and check the column (select it via arrow keys) you're interested in.      

```bash
# -c, --fullcmdline      show full command line
# -P, --processes        only show processes, not all threads
# -a, --accumulated      show accumulated I/O instead of bandwidt
iotop-c -cP
```    

Also try `iotop-c -cPa` or press `a` to toggle cumulative mode and let it run for a while.    

![image](https://gist.github.com/user-attachments/assets/d2995763-1bdb-4cfb-98ca-9b87ae279b8d)

#### iostat   
`iostat` can show per device statistics. Run the following and check the `%util` for the disk(s).    

```bash
# -x         Display extended statistics.
# -y         Omit first report with statistics since system boot.
# -z         Omit output for devices for which there was no activity during the sample period
# -t         Print the time for each report displayed.
# -s         Display a short (narrow) version of the report up to 80 characters.
# --compact  Don't break the Device Utilization Report into sub-reports.
# --human    Print sizes in human readable format (e.g. 1.0k, 1.2M, etc.).
iostat -xyzts --compact --human 1
```    

![image](https://gist.github.com/user-attachments/assets/9759939f-bad1-467e-b61a-dc9cd1d8aa68)

#### fatrace
`fatrace` can be used to check file events such as read, write, create and so on. It can help you identify which processes are modifying files and when. Below is an example to listen for file writes.

```bash
# -f TYPES, --filter=TYPES      Show only the given event types; C, R, O, or W, e. g. --filter=OC
fatrace -f W
```    

![image](https://gist.github.com/user-attachments/assets/fa5c8a3d-4917-4e4a-85d9-00ba2ed6dab9)

### ZFS related
#### Checking ZFS latency stats
```bash
# -y      Normally the first line of output reports the statistics since boot: suppress it.
# -l      Include average latency statistics:
watch -cd -n1 "zpool iostat -yl 1 1"
```

![image](https://gist.github.com/user-attachments/assets/7e67c7de-5576-4ae2-a543-252894b6ba1e)

#### Checking ZFS queue stats
```bash
# -q      Include  active  queue  statistics.
watch -cd -n1 "zpool iostat -yq 1 1"
```

![image](https://gist.github.com/user-attachments/assets/53213bbe-e135-418b-b52e-d9d7b68126c5)

#### Checking ZFS request sizes
```bash
# -r      Print request size histograms for the leaf vdev's I/O
watch -cd -n1 "zpool iostat -yr 1 1"
```

![image](https://gist.github.com/user-attachments/assets/97c0de6c-a541-4941-944a-bd9f549f3bc3)

## Filter journal messages
This is only mildly related to PVE but I show it with a relevant feature - The QEMU Guest Agent.

It very often logs messages like these.

```bash
info: guest-ping called
info: guest-fsthaw called
info: guest-fsfreeze called
```

If you want to prevent that you can use a service override using the following.

```bash
systemctl edit qemu-guest-agent.service
```

To filter use the following.

```bash
[Service]
LogFilterPatterns=~guest-ping
```

You can also filter for more things.

```bash
[Service]
LogFilterPatterns=~guest-ping
LogFilterPatterns=~guest-fs(freeze|thaw)
```

I chose not to do that though as this happens rarely and might be useful for debugging issues.

You might have to reload the daemon.

```bash
systemctl daemon-reload
```

## Miscellaneous
Just some miscellaneous tips and scripts which don't have a good place yet or are better to be linked from above to keep things structured and organized.

## Enable no-subscription repositories
With PVE 9 (based on Debian 13), the file suffix can now also be `.sources` so don't get confused by that.

Official PVE documentation:    
 - <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_no_subscription_repo>    
 - <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#repos_secure_apt>

Go to `node > Updates > Repositories` and add the `no-subscription` repository.    

![image](https://gist.github.com/user-attachments/assets/f6386651-f457-4f48-a22f-4bcd245ba899)

![image](https://gist.github.com/user-attachments/assets/51a83cb5-4c57-4bef-869f-5cee21382cc0)  

Disable the enterprise repositories.
  
![image](https://gist.github.com/user-attachments/assets/1a29b310-c14e-4d6f-bc18-2ca6d05bbdd3)    

![image](https://gist.github.com/user-attachments/assets/1e355401-ce2e-41ed-ae7f-2fa90e1ce4a0)    

At the end it should look like this.

![image](https://gist.github.com/user-attachments/assets/79883dcb-7d75-4efa-b3a6-3dda631581a9)    

Go to `node > Updates > Refresh` and see if everything works as expected.    

## Windows guest best practices
Follow PVE's documentation on how to install windows as a VM. I have never had an issue following these instructions.
- [Windows server 2022](https://pve.proxmox.com/wiki/Windows_2022_guest_best_practices)
- [Windows server 2025](https://pve.proxmox.com/wiki/Windows_2025_guest_best_practices)
- [Windows 10](https://pve.proxmox.com/wiki/Windows_10_guest_best_practices)
- [Windows 11](https://pve.proxmox.com/wiki/Windows_11_guest_best_practices)

## Making KSM start sooner
KSM and ballooning both start when the host reaches 80% memory usage by default.    

> [!NOTE]
> Ballooning was hardcoded before PVE 8.4 but it is now configurable via `node > System > Options > RAM usage target for ballooning`.

To make KSM start sooner and give it a chance to "free" some memory before ballooning starts you can modify `/etc/ksmtuned.conf`.  

For example, to let it start at 70% you can configure it using the following.    

```bash
KSM_THRES_COEF=30
```

You can also make it more "aggressive".

```bash
KSM_NPAGES_MAX=5000
```

Official PVE documentation:    
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#ballooning-target>
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#qm_memory>
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#kernel_samepage_merging>
- <https://pve.proxmox.com/wiki/Dynamic_Memory_Management>
- <https://pve.proxmox.com/wiki/Kernel_Samepage_Merging_(KSM)>

## Enabling a VM's serial console
This allows you to use xterm.js (used for CTs by default) which allows copy & pasting. Tested for Debian and Ubuntu.  

> [!IMPORTANT]
> All commands are to be run inside the VM and this might also work for other OSs. Please let me know if it does.

### Add serial port
Go to the `Hardware` tab of your VM and add a `Serial Port`.  

![image](https://gist.github.com/user-attachments/assets/0d632c47-789f-4200-a47c-8670a8258b25)

### Enable TTY
> [!NOTE]
> Some distributions are already set up for this, or can be configured via their own UI. This step can be skipped for them.    
>
> For example, Home Assistant's HAOS is already set up for this and [TrueNAS can be configured for it via UI](https://www.truenas.com/docs/scale/scaletutorials/systemsettings/advanced/manageconsolescale/).    

Either one of these commands can help finding the right tty.  

```bash
dmesg -T | grep "tty"
journalctl -b0 -kg "tty"
```

For example, it's `ttyS0` for me.

```
Aug 18 02:17:16 nodename kernel: 00:04: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
```

To enable the TTY edit `/etc/default/grub`.

```bash
nano /etc/default/grub
```

Find the line starting with `GRUB_CMDLINE_LINUX_DEFAULT` and add `console=ttyS0 console=tty0` at the end (replace `ttyS0` with yours from above).

It can look like this, for example.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0 console=tty0"
```

Save via `CTRL+X` and exit, then run the following.

```bash
update-grub
```

Documentation:
 - <https://0pointer.de/blog/projects/serial-console.html>
 - <https://docs.kernel.org/admin-guide/serial-console.html>
 - <https://www.kernel.org/doc/html/v4.14/admin-guide/kernel-parameters.html>

### Hard reboot
Reboot the VM via the PVE button or power it off and on again to apply the `Hardware` and bootloader config change. This is so the VM is cold booted. A normal `reboot` command from within the VM will not do the same.

You can see if a `Hardware` change was applied by the color. If it's orange it's still to be applied.    

Once that's done, your VM should have a functioning `xterm.js` button under `Console`. Click the arrow beside it.  

![image](https://gist.github.com/user-attachments/assets/ebc4a15d-0980-4a5d-9401-367088873331)

## Restore guest configs
A script that can extract the `.conf` file out of [`pmxcfs`](<https://pve.proxmox.com/wiki/Proxmox_Cluster_File_System_(pmxcfs)>)'s `config.db`.

> [!WARNING]
> Only lightly tested and written without a lot of checks so be careful. Make a backup of the file and install `sqlite3` with `apt install sqlite3`.

```bash
#!/usr/bin/env bash
# Attempts to restore .conf files from a PMXCFS config.db file.
set -euo pipefail

# Usually at /var/lib/pve-cluster/config.db
# You can do "cd /var/lib/pve-cluster/" and leave CONFIG_FILE as is
CONFIG_FILE="config.db"

# Using these paths can be convenient but dangerous!
# /etc/pve/nodes/$(hostname)/qemu-server/
VM_RESTORE_PATH="vms"

# /etc/pve/nodes/$(hostname)/lxc/
CT_RESTORE_PATH="cts"

[ -d "$VM_RESTORE_PATH" ] || mkdir "$VM_RESTORE_PATH"
[ -d "$CT_RESTORE_PATH" ] || mkdir "$CT_RESTORE_PATH"

GUESTIDS=$(sqlite3 $CONFIG_FILE "select name from tree where name like '%.conf' and name != 'corosync.conf';")

for guest in $GUESTIDS; do
    sqlite3 $CONFIG_FILE "select data from tree where name like '$guest';" >"$guest"

    if grep -q "rootfs" "$guest"; then
        mv "$guest" "$CT_RESTORE_PATH"
        echo "Restored CT config $guest to $VM_RESTORE_PATH/$guest"
    else
        mv "$guest" "$VM_RESTORE_PATH"
        echo "Restored VM config $guest to $CT_RESTORE_PATH/$guest"
    fi
done
```

## Credentials
PVE keeps credentials like CIFS passwords in `/etc/pve/priv/storage`.

## Fix locales
Do you have strange characters in your CLI tools rather than unicode symbols? The default `C` locale might be the cause.    

This is mostly useful for CTs. For VMs you generally set this up during install.

To interactively change it you can use the following.

```bash
dpkg-reconfigure locales
```

To non-interactively change it.

```bash
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
ln -sf /etc/locale.conf /etc/default/locale
source /etc/locale.conf
locale-gen
```

Verify using the following.

```bash
locale
localectl
```

## Enable package notifications
PVE is able to send you notifications about updates which look something like the following.

```bash
The following updates are available:

Package Name    Installed Version     Available Version     
libxslt1.1      1.1.35-1.2+deb13u1    1.1.35-1.2+deb13u2    
xsltproc        1.1.35-1.2+deb13u1    1.1.35-1.2+deb13u2    
```

To enable them.

```bash
pvesh set /cluster/options --notify package-updates=always
```

I also like to install `apticron` which gives a lot more details.

```bash
apt install apticron
```

## Fix boot UUIDs not found message with initial ram filesystem
On two clean PVE 9 installs, I got a message similar to `No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.` after running `update-initramfs -u -k` for the first time.

This is on an ext4 file system with EFI using GRUB.

To fix this, check the partition name using `/boot/efi` with vfat format.

```bash
lsblk -o +FSTYPE
```

For example, below it is `nvme0n1p2`.

![](https://gist.github.com/user-attachments/assets/bd9f4589-9fe9-4713-873d-fdbf6f78b3f0)

To initialize ESP sync first unmount boot partition.

```bash
umount /boot/efi
```

Then link the vfat partiton with `proxmox-boot-tool`, where `{partition_name}` is the name of vfat partiton found earlier.

```bash
proxmox-boot-tool init /dev/{partition_name}
```

Now mount again.

```bash
mount -a
```

And update file system.

```bash
update-initramfs -u -k all
```

You should no longer recieve an error.

## Disable PVE cluster daemons

If you have installed Proxmox on a consumer drive and do not plan to use clustering, disable the `pve-ha-crm` and `pve-ha-lrm` daemons as they can be [responsible for low end drive death](https://www.reddit.com/r/Proxmox/comments/12gftf7/comment/jfkgcbp/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button).

```bash
systemctl disable pve-ha-crm
systemctl disable pve-ha-lrm
```

## Why not use `local` for guest disks?
File based disks (stored on `Directory` type storages) such as `.qcow2`, `.raw` and so on can have some issues.    

PVE does not enable the [`Content Type`s](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#storage_directory) of the `local` storage to store such files by default.    
- [They can be slow and inefficient](https://bugzilla.proxmox.com/show_bug.cgi?id=6140).
- CTs only support `.raw` files [which provide no snapshot ability](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_storage_types).
- Thin provisioning doesn't necessarily work
- Uses the same storage as the OS/system
- No replication possible

## Reference
This was originally forked from [Impact123/Proxmox VE Tips.md](https://gist.github.com/Impact123/3dbd7e0ddaf47c5539708a9cbcaab9e3) with modified, removed, and added content that is tailored for my personal use.
