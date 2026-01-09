# Virtio-FS Homelab Setup Summary

This document summarizes the implementation of **virtio-fs** in a home lab environment with **Proxmox**, **Ubuntu VM**, **TrueNAS NFS storage**, and **Docker containers** (e.g., Plex). It also includes a diagram of the storage flow.

---

## 1. Overview

* **Storage backend:** TrueNAS NFS export `/mnt/media` with `mapall` for Plex/media containers
* **Proxmox host:** Mounts NFS at `/mnt/media` and exposes it to VMs using virtio-fs
* **VM:** Ubuntu server mounts virtio-fs share at `/media`
* **Docker containers:** Use `/media` inside VM for shared access, UID/GID differences handled by mapall or host permissions

---

## 2. Proxmox Configuration

**VM configuration file** `/etc/pve/qemu-server/<VMID>.conf`:

```ini
boot: order=scsi0
cores: 4
memory: 8192
sockets: 1
net0: virtio=DE:AD:BE:EF:01:02,bridge=vmbr0

# Virtio-FS device
virtiofs0: /mnt/media,tag=media-share
```

**Notes:**

* `virtiofs0` is the first virtio-fs device
* `tag` must match the VM mount command
* Host directory `/mnt/media` contains NFS mount from TrueNAS

---

## 3. Ubuntu VM Configuration

1. **Install guest tools:**

```bash
sudo apt update
sudo apt install qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

2. **Create mount point:**

```bash
sudo mkdir -p /media
```

3. **Temporary mount:**

```bash
sudo mount -t virtiofs media-share /media
```

4. **Auto-mount via `/etc/fstab`:**

```fstab
media-share  /media  virtiofs  defaults  0  0
```

---

## 4. Docker Container Usage

```bash
docker run -v /media:/data plex
```

* Multiple containers with different UIDs can access `/media`
* Host permissions and/or TrueNAS `mapall` handle UID/GID mapping

---

## 5. Traffic Flow Diagram

```text
TrueNAS NFS (/mnt/media)
          │  NFS mount (mapall)
          ▼
Proxmox Host (/mnt/media)
          │  Virtio-FS (tag: media-share)
          ▼
Ubuntu VM (/media)
          │  Docker containers
          ▼
Plex / Sonarr / Radarr
```

**Highlights:**

* Red arrows: storage traffic (high-speed, direct-attach / 25G)
* Blue arrows: management / VLAN / internet traffic (1G via ICX L3 switch)
* VM sees storage as local filesystem
* Fully migration-safe; no storage network exposure to VM

---

## 6. Benefits

* High-performance, low-overhead access to storage
* Migration-safe VMs
* Multi-UID container compatibility
* Host controls storage network isolation
* TrueNAS `mapall` ensures consistent access
* Optional: jumbo frames and multipath for future scalability

---

## 7. Notes / Best Practices

* Host directory permissions should match intended VM access
* Use virtio-fs for many small files or metadata-heavy workloads
* Bind mounts are simpler but slightly slower; virtio-fs recommended for optimal performance
* Mapall on TrueNAS ensures UID conflicts don’t break container access

---

**Summary:**
Virtio-FS allows the VM and its containers to see TrueNAS storage mounted on Proxmox as a **local filesystem**, providing a **migration-safe, high-performance, and multi-UID compatible storage solution** for your homelab.
