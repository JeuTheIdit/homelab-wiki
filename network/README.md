# Network topology

Below summarizes the network design for my home lab environment, including firewall (OPNsense), layer 3 switch (Brocade ICX), VLAN segmentation, and direct attached storage.

## OPNsense Firewall
- Connected to the L3 switch using default/static routes.
- Provides WAN/internet protection.
- Enforces policies for VLANs, .

## Brocade ICX layer 3 switch
- Functions:
  - Inter-VLAN routing
  - Enforces ACLs for traffic between VLANs
  - Provides segmentation for management, trusted, guest, and other VLANs
- Virtual interfaces:
  - VLAN 10: Management (no internet, accessible only from VLAN 20)
  - VLAN 20: Trusted (internet access, mostly full access to other VLANs)
  - VLAN 30: Guest (internet only, no access to other VLANs)
  - VLAN 40: Untrusted (IOT devices, internet access, limited access to VLAN 60)
  - VLAN 50: Cameras (no internet access, can only access NVR in VLAN 60)
  - VLAN 60: Servers (internet  access, limited access to other VLANs)

## Proxmox VE hypervisors
- Hardware: 2x1G ports (management/Internet), 2x25G ports (direct-attach storage)
- Storage mounts:
  - NFS mounted on the hypervisor host at `/mnt/media`
  - Bind mounted into VMs (e.g., Plex) as `/media`
- Network:
  - 1G interfaces connected to VLAN 10 on L3 switch
  - 25G interfaces connected to storage server

## Truenas storage server
- Hardware: 2x1G ports (management), 2x25G ports (direct-attach storage)
- Storage protocol: NFS
- Exported dataset: `/mnt/media`
- User mapping:
  - Mapall User: `media`
  - Mapall Group: `mediacenter`
- Direct-attached 25G links connect to each Proxmox hypervisor for storage traffic.
  - Storage interfaces use direct point-to-point links, no IP gateway required.
  - Isolated from internet and all other networks.

## Network segmentation
- Direct-Attach Storage Network (25G)
  - Separate /30 point-to-point subnets for each Proxmox ↔ TrueNAS link
  - No default gateway
  - Jumbo frames optional (MTU 9000)
  - Air-gapped from internet

- Management & Internet Network (1G)
  - Routed via ICX L3 switch and OPNsense firewall
  - Segmented by VLANs to enforce access control

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
