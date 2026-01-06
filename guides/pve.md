# Proxmox VE guides

Compilation of [Proxmox VE](https://proxmox.com/en/products/proxmox-virtual-environment/overview) (PVE) guides to share.   

> [!NOTE]
> Any guides being done within PVE CTs or VMs were created for Ubuntu, and even though they contain specific Ubuntu/Debian instructions, the concepts are generic enough and can be applied on most Linux distributions, even on those not based on Debian (for example, CentOS and OpenSUSE).
>
> Unless you see a shebang `(#!/...)`, these code blocks are usually meant to be copy & pasted directly into the shell. Some of the steps will not work if you run part of them in a script and copy paste other ones as they rely on variables set before.  
>
> The `{` and `}` surrounding some scripts are meant to avoid poisoning your bash history with individual commands, etc. You can ignore them if you manually copy paste the individual commands.

## Table of contents
- [Install](#install)
  - [PVE initial setup](#pve-initial-setup)
  - [Guest initial setup](#guest-initial-setup)

## Install
## PVE initial setup
Below are instructions that I personally use for initial setup of Proxmox.

### Prepare the BIOS
Before installing Proxmox, enable virtualization (VT-x, VT-d, SVM, ACS, IOMMU or whatever it's called for you), sr-iov, and resizeable bar support.

### No-subscription repositories
[Enable no-subscription repositories](#enable-no-subscription-repositories).

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

![](https://gist.github.com/user-attachments/assets/7cef63af-ab1a-44d2-8a6c-611ab131e43f)

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

![](https://gist.github.com/user-attachments/assets/1aa9b7ee-32ac-4d27-b986-0f579e56dc64)

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
> If you are using grub with an ext4 file system and get the message `No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.`, [follow these instructions to fix](#fix-boot-uuids-not-found-message-with-initial-ram-filesystem).

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

![](https://gist.github.com/user-attachments/assets/e2c2f4f1-633b-4a1a-828e-536a92f30942)

If you have that, you are likely in good shape. Sometimes even this does not show up though.

### Bind PCIe devices
For any devices that are being fully passed through to VMs, [follow these instructions](#binding-pcie-devices-to-vfio) to bind those devices to VFIO drivers so that Proxmox does not have to switch drivers upon VM boot.

For any devices you are planning to split with SR-IOV, **do not** bind to VFIO drivers.

### Disable Cluster Daemons
[Follow these instructions](#disable-pve-cluster-daemons) to disable cluster daemons.

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
ssh-keygen
```

That generates an ssh key pair and will ask you for the location to store the keys. Keep the default which should be `/root/.ssh` if you are using a Debian based system as root, `/home/{user}/.ssh` if you are using a Debian based system as a user other than root, or the home directory `{user}\.ssh\` for Windows.

> [!IMPORTANT]
> When asked for a passphrase for the keys, I would highly recommend you set one.

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
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh {server_user}@{server_ip_address} "cat >>
.ssh/authorized_keys"

# ED25519 key
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh {server_user}@{server_ip_address} "cat >>
.ssh/authorized_keys"
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
