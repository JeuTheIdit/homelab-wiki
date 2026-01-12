# Proxmox VE guides

Compilation of [Proxmox VE](https://proxmox.com/en/products/proxmox-virtual-environment/overview) (PVE) guides to share.   

> [!NOTE]
> Any guides being done within PVE CTs or VMs were created for Ubuntu, and even though they contain specific Ubuntu/Debian instructions, the concepts are generic enough and can be applied on most Linux distributions, even on those not based on Debian (for example, CentOS and OpenSUSE).
>
> Unless you see a shebang `(#!/...)`, these code blocks are usually meant to be copy & pasted directly into the shell. Some of the steps will not work if you run part of them in a script and copy paste other ones as they rely on variables set before.  
>
> The `{` and `}` surrounding some scripts are meant to avoid poisoning your bash history with individual commands, etc. You can ignore them if you manually copy paste the individual commands.

## Table of contents
- [PVE initial setup](#pve-initial-setup)
- [Guest initial setup](#guest-initial-setup)
- [GPU passthrough](#gpu-passthrough)
  - [VM](#vm)
  - [CT](#ct)
- [Install Intel drivers and modules](#install-intel-drivers-and-modules)
- [Install Nvidia drivers and modules](#install-nvidia-drivers-and-modules)
  - [Via apt](#via-apt)
  - [Via .run file](#via-run-file)
- [SR-IOV](#sr-iov)
  - [NICs](#nics)
  - [Intel Arc Pro B-Series](#intel-arc-pro-b-series)

## PVE initial setup
Below are instructions that I personally use for initial setup of Proxmox.

### Prepare the BIOS
Before installing Proxmox, enable the following in the BIOS:
- Virtualization (VT-x, VT-d, SVM, ACS, IOMMU or whatever it's called for you)
- SR-IOV
- Resizeable bar
- Change all populated pcie slots to the specific gen required (3, 4, or 5)

### No-subscription repositories
[Enable no-subscription repositories](tips.md#enable-no-subscription-repositories).

### Enable IOMMU
[Determine which bootloader you are using](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysboot_determine_bootloader_used) (systemd or grub).

> [!NOTE]
> With PVE 8 and 9 in my experience, systemd is used with the boot storage as ZFS and grub is used with the boot storage as ext4.

#### Systemd
```bash
nano /etc/kernel/cmdline
```

For Intel CPUs add the following to the `root=ZFS=rpool/ROOT/pve-1 boot=zfs` line or similar.

```bash
quiet intel_iommu=on iommu=pt
```

For AMD CPUs add the following `root=ZFS=rpool/ROOT/pve-1 boot=zfs` line or similar.

```bash
quiet iommu=pt
```

> [!NOTE]
> IOMMU is enabled by default on AMD CPUs, so setting `amd_iommu=on` is not required.

Below is a screenshot of where to add this using the Intel version.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/proxmox-install-1.png)

Now refresh boot tool and reboot.

```bash
proxmox-boot-tool refresh
reboot
```

#### Grub
```bash
nano /etc/default/grub
```

For Intel CPUs add the following to the `GRUB_CMDLINE_LINUX_DEFAULT` line.

```bash
quiet intel_iommu=on iommu=pt
```

For AMD CPUs add the following to the `GRUB_CMDLINE_LINUX_DEFAULT` line.

```bash
quiet iommu=pt
```

> [!NOTE]
> IOMMU is enabled by default on AMD CPUs, so setting `amd_iommu=on` is not required.

Below is a screenshot of where to add this using the AMD version.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/proxmox-install-2.png)

Now update grub and reboot.

```bash
update-grub
reboot
```

### Add VFIO modules
```bash
nano /etc/modules
```

Add the following.

```bash
vfio
vfio_iommu_type1
vfio_pci
```

Now refresh initramfs.

```bash
update-initramfs -u -k all
```

> [!TIP]
> If you are using grub with an ext4 file system and get the message `No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.`, [follow these instructions to fix](tips.md#fix-boot-uuids-not-found-message-with-initial-ram-filesystem).

Reboot.
```bash
reboot
```
### Verify IOMMU is working
```bash
dmesg | grep -e DMAR -e IOMMU
```

Depending on the system and which options you have, a lot of the output is going to
change here. What you are looking for is the line highlighted below `DMAR: IOMMU
enabled`.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/proxmox-install-3.png)

If you have that, you are likely in good shape. Sometimes even this does not show up though.

### Bind PCIe devices
For any devices that are being fully passed through to VMs, [follow these instructions](https://github.com/JeuTheIdit/homelab-wiki/blob/main/proxmox-ve/tips.md#binding-pcie-devices-to-vfio) to bind those devices to VFIO drivers so that Proxmox does not have to switch drivers upon VM boot.

For any devices you are planning to split with SR-IOV, **do not** bind to VFIO drivers.

### Disable cluster daemons
[Follow these instructions](tips.md#disable-pve-cluster-daemons) to disable cluster daemons.

## Guest initial setup
Below are instructions that I personally use for initial set up of guests (both VM and CT), after creation in PVE and installation onto disk.

### Update and install packages
If running as root currently.

```bash
apt update && apt upgrade -y
```

If running as non root user.

```bash
sudo apt update && sudo apt upgrade -y
```

Install `qemu-guest-agent`.

```bash
sudo apt install qemu-guest-agent -y
```

### Create a new admin user
This is only needed for CTs and Debain VMs. Ubuntu VMs will set up a sudo user by default during initial installation.

```
adduser {new_user}
```

Now elevate that new user to sudo privileges.

```bash
usermod -aG sudo (new_user}
```

Log out from the root account and log into the new user account.

### Disable root account

To disable the root user (by expiring its password).

```bash
sudo passwd -l root
```

> [!NOTE]
> If you ever want to re-enable the root user again, use this and set a very strong new root password.
> 
> ```bash
> sudo passwd
> ```

### Generate ssh keys (as needed)

I use key based authentication to ssh into my servers. Make sure you have generated ssh keys **on the client computer(s) you will be remoting into the server from**.

```bash
ssh-keygen -t ed25519 -a 100
```

That generates an ssh key pair and will ask you for the location to store the keys. Keep the default which should be `/root/.ssh` if you are using a Debian based system as root, `/home/{user}/.ssh` if you are using a Debian based system as a `{user}` other than root, or the home directory `{user}\.ssh\` for Windows.

> [!NOTE]
> Why Ed25519?
>
> Ed25519 gives you maximum security per byte, fast cryptographic operations, small key material, and deterministic signatures that eliminate a class of attacks.
>
> RSA is still fine for legacy or compliance‑driven environments, but it forces you to carry larger key material and to guard against RNG failures.

### Copy public key from client to server

Before we copy the public key to our new user on the server, we will need to find our IP address of the server.

```bash
ip address show
```

Once you know the ip address, copy our public key to the new user where `{server_user}` is the new user we created, and `{server-ip-address}` is the IP address of the server we found above.

On a Debian based client.

```bash
ssh-copy-id {server_user}@{server-ip-address}
```

On a Windows client.

```bash
# RSA key
scp $env:USERPROFILE/.ssh/rsa.pub {server_user}@(server-ip-address}

# ED25519 key
scp $env:USERPROFILE/.ssh/id_ed25519.pub {server_user}@{server-ip-address}

# Or to append without overwriting existing keys
cat $env:USERPROFILE/.ssh/id_ed25519.pub | ssh {server_user}@{server-ip-address} 'cat >> ~/.ssh/authorized_keys'
```

> [!NOTE]
> If you get an error similar to `bash: /home/{user}/.ssh/authorized_keys: No such file or directory`, then we have to create the `.ssh` directory and `authorized_keys` file manually. This is usually needed when we manually create a new user in a CT or VM. With Ubuntu VMs where a sudo user is created by default during installation, the `.ssh` directory and `authorized_keys` file is automatically created.
> 
> Create the `.ssh` directory.
>
> ```bash
> mkdir ~/.ssh
> ```
>
> Set the correct permissions.
>
> ```bash
> chmod 700 ~/.ssh
> ```
>
> Create the `authorized_keys` file.
>
> ```bash
> touch ~/.ssh/authorized_keys
> ```
>
> Set the right permissions.
>
> ```bash
> chmod 600 ~/.ssh/authorized_keys
> ```
>
> Now you will be able to add the public key.

### Hardening ssh settings
Now that we have copied our public key to the server, we can harden the server ssh settings to only allow key based authentication.

```bash
sudo nano /etc/ssh/sshd_config
```

Find the following parts, uncomment them or add them as needed, where `{user}` is the user that was created on the server.

```bash
PermitRootLogin no
AllowUsers {user}
StrictModes yes
MaxAuthTries 3
PasswordAuthentication no
```

Restart the ssh or sshd service.

```bash
sudo systemctl restart ssh
```

### Enable the firewall
Now we will enable the Ubuntu ufw firewall. By default, ufw disallows all port when enabled. We start by adding and allowing the ports (`{app_port}`) we need for the applications (`{app}`) we are running, including the ssh port 22 so we can still remote manage the system.

> [!TIP]
> The `comment {app}` portion only produces a comment for when you use `ufw status`. It is not needed, but makes it easier to track which apps the ports are being allowed for.

```bash
sudo ufw allow ssh comment ssh
sudo ufw allow {app_port} comment {app}
```

Enable ufw.

```bash
sudo ufw enable
```

If all went fine you should still keep your ssh connection.

To check and see the status of ufw.

```bash
sudo ufw status
```

### Install and configure fail2ban
[Fail2ban](https://github.com/fail2ban/fail2ban) is a daemon service that automatically detects malicious behaviour and bans offenders by updating the firewall rules. Basically once fail2ban identifies a malicious user they can’t connect to the server at all, requests to connect go unanswered until the ban is lifted.

Install fail2ban.

```bash
sudo apt install fail2ban -y
```

> [!TIP]
> A full description of fail2ban configuration is beyond the scope of this. However, never edit the main configuration file `/etc/fail2ban/jail.conf` directly. Instead, add some overrides in `/etc/fail2ban/jail.local`.

```bash
sudo nano /etc/fail2ban/jail.local
```

Add the following, where `{network_address}` are your local networks where you will be logging into from and want to ignore.

```bash
[DEFAULT]
bantime = 8h
ignoreip = 127.0.0.1/8 {network_address}/24 {network_address}/24
ignoreself = true

[sshd]
enabled = true
```

Restart fail2ban.

```bash
sudo systemctl restart fail2ban
```

Enable fail2ban so it starts on boot.

```bash
sudo systemctl enable fail2ban
```

## GPU passthrough
This will likely never be a complete tutorial, just some often shared commands, tips and scripts.  

Documentation:
- <https://pve.proxmox.com/wiki/PCI(e)_Passthrough>
- <https://pve.proxmox.com/wiki/PCI_Passthrough>
- <https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF>

### VM
For VMs, [add VFIO modules](tips.md#add-vfio-modules), [bind the GPU to VFIO drivers](tips.md#binding-pcie-devices-to-vfio) and verify that the `vfio-pci` driver is in use.

```bash
lspci -vnnk | awk '/VGA/{print $0}' RS= | grep -Pi --color "^|(?<=Kernel driver in use: |Kernel modules: )[^ ]+"
```

[Check the IOMMU groups](tips.md#checking-iommu-groups) and passthrough the GPU [using `Resource Mapping`](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#resource_mapping) (PVE 8+).

> [!TIP]
> Make sure `PCI-Express` is checked when adding the mapped device to the VM. `ROM-Bar` should also be checked, but is by default.
>
> ![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/gpu-passthrough-1.png)

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

If Nvidia devices are not available when the system boots you can work around it by adding this to your crontab via `crontab -e`

```bash
@reboot /usr/bin/nvidia-smi > /dev/null
```

#### Nvidia specific
For Nvidia you can use the [Nvidia container toolkit](#install-and-configure-nvidia-container-toolkit). The benefits of this are that you do not have to install drivers inside the CT, don't have to add `dev`ices or check groups, it helps with changing render device names (multi GPU) and you will also not have the problem of different driver version conflicts on upgrades.

It's very simple and my recommended way to do this for NVIDIA GPUs.

Install the Nvidia drivers [via `apt`](#via-apt) (recommended) or [via `.run` file](#via-run-file) and the [Nvidia container toolkit](#install-and-configure-nvidia-container-toolkit) on the node.

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

Also see [Check which PCI(e) device a drm device belongs to](tips.md#check-which-pcie-device-a-drm-device-belongs-to).    

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
> SR-IOV with Intel Pro B50 and Pro B60 GPUs requires the following:
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

The easiest way to update the firmware is by installing the latest drivers on Windows, which the firmware updates are packaged with. Either install it in a standalone Windows 11 machine, or [create a Windows 11 VM](tips.md#windows-guest-best-practices) and [passthrough the GPU](#gpu-passthrough).

Download and install the [latest Intel drivers](https://www.intel.com/content/www/us/en/ark/products/series/242616/intel-arc-pro-b-series-graphics.html).

#### Check for SR-IOV functionality
> [!IMPORTANT]
> Do not [bind the GPU to VFIO](tips.md#binding-pcie-devices-to-vfio) when using SR-IOV functions. The `xe` driver must be in use.

With the correct BIOS settings enabled and the firmware updated, the GPU should now have SR-IOV functions enabled.

To check, [look up the GPU device ID](tips.md#checking-iommu-groups) and run the following.

```
lspci -vvv
```

Find the GPU using the device ID. In my case it was `c4:00`.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/sr-iov-1.png)

More specifically.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/sr-iov-2.png)

> [!NOTE]
> Save the device ID for the next section.

#### Add SR-IOV functions
Find the GPU device under `/sys/devices`, where `xx:xx` is the device ID that you found above.

```bash
find /sys/devices -name "*xx:xx*" -type d
```

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/sr-iov-3.png)

Go to that directory and look for `sriov_numvfs` and run the following, where `x` is the number of functions you want, in multiples of 2.

```bash
echo x > sriov_numvfs
```

Now you should have `x` additional devices using `lspci` or when [checking IOMMU groups](https://github.com/JeuTheIdit/homelab-wiki/blob/main/proxmox-ve/tips.md#checking-iommu-groups). In my case, 4 additional.

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/sr-iov-4.png)

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

## Install Intel drivers and modules
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

## Install Nvidia drivers and modules
### Via apt
It's a simpler method as it uses packages straight from repos. They might be a bit older but this should be fine and it makes installation simpler. Most guides use Nvidia's `.run` files but then you have to update the drivers manually. Instead you can use the drivers/libs from the debian apt repository and update them like any other package.  

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
You can enable persistence daemon, which may help save power and decrease access delays. See [official Nvidia documentation](https://download.nvidia.com/XFree86/Linux-x86_64/396.51/README/nvidia-persistenced.html).   

> [!CAUTION]
> These commands are to be run on the node or VM. Copy & paste.

Enable and start it.

```bash
systemctl enable --now nvidia-persistenced.service
```

You can see the status in `nvidia-smi`.   

![](https://github.com/JeuTheIdit/homelab-wiki/blob/main/static/install-nvidia-1.png)

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
Also [see here](tips.md#enable-persistence-daemon).

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

## Install and configure Nvidia container toolkit

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
