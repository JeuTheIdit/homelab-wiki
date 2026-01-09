# Network topology

Below summarizes the network design for my home lab environment, including firewall (OPNsense), layer 3 switch (Brocade ICX), VLAN segmentation, and direct attached storage.

## OPNsense Firewall
- Connected to the L3 switch using default/static routes.
- Provides WAN/internet protection.
- Enforces policies for VLANs, .

## Brocade ICX layer 3 switch
- Connected to the firewall using default/static routes.
- Functions:
  - Inter-VLAN routing.
  - Enforces ACLs for traffic between VLANs.
  - Line rate speed for all ports (24 1G, 4 10G).
- Virtual interfaces:
  - VLAN 10: Management (no internet, accessible only from VLAN 20).
  - VLAN 20: Trusted (internet access, mostly full access to other VLANs).
  - VLAN 30: Guest (internet only, no access to other VLANs).
  - VLAN 40: Untrusted (IOT devices, internet access, limited access to VLAN 60).
  - VLAN 50: Cameras (no internet access, can only access NVR in VLAN 60).
  - VLAN 60: Servers (internet access, limited access to other VLANs).
  - VLAN 200: Transit (transit /30 network connecting switch and firewall).

## Proxmox VE hypervisors
- Two (2) total.
- Hardware: 2x1G ports (management/internet), 2x25G ports (direct-attach storage).
- Storage mounts:
  - Remote mounts on the hypervisor hosts:
    - Media NFS mount at `/mnt/media`.
    - Download NFS mount at `/mnt/download`.
  - Virtio-fs mounts to VMs:
    - `/mnt/media` with tag `media-share` to `/mnt/media` in VM.
    - `/mnt/download` with tag `download-share` to `/mnt/download` in VM.
- Network:
  - 1G interfaces connected to VLAN 10 on L3 switch
  - 25G interfaces connected to storage server

## Truenas storage server
- Hardware: 2x1G ports (management/internet), 2x25G ports (direct-attach storage).
- Storage protocol: NFS
- ZFS pools:
  - Slow (16x 18TB disks in 2x raidz2 with 2x 1.7TB special vdev SSD drives for metadata).
  - Download (1x 4TB NVME).
  - Backup (2x 3TB SSD mirror).

## Network segmentation
- Direct-Attach Storage Network (25G):
  - Separate /30 point-to-point subnets for each Proxmox ↔ TrueNAS link.
  - No default gateway.
  - Jumbo frames optional (MTU 9000).
  - Air-gapped from internet.
- Management & Internet Network (1G):
  - Routed via ICX L3 switch and OPNsense firewall.
  - Segmented by VLANs to enforce access control.

## Storage Access Strategy
- Hypervisor-mounted NFS is bind-mounted into VMs
- Avoids exposing storage network to VMs
- Supports live migration of VMs without breaking storage access
- `mapall` to user `media` and group `mediacenter`

## Traffic Flow Summary
```
TrueNAS 25G ports ---> Proxmox 25G storage interfaces ---> Host mount /mnt/media ---> VM bind mount /media

Proxmox 1G interfaces ---> ICX L3 Switch ---> VLANs ---> OPNsense Firewall ---> WAN/Internet
```

## Key Benefits
- Maximum storage performance via 25G direct attach
- Fully isolated storage network
- VM migration safe
- Docker multi-UID container compatibility
- Segmented VLANs for security and access control
- Centralized firewall protection via OPNsense
- Scalable. Additional PVE hypervisors can be added by connecting them via additional direct-attach 25G links or via a 25G switch if redundancy or multipath storage is needed.
