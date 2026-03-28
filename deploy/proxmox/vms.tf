# ============================================================
# Maranet Zero — Proxmox VM Configuration
# HP ProLiant ML350 G6 — 2x Xeon X5670, 48GB RAM, 4x2TB RAID10
# ============================================================

# VM 100: API & Control Plane
# Debian 12, 4 vCPU, 8GB RAM, 50GB disk
resource "proxmox_vm" "api_server" {
  name        = "maranet-api"
  vmid        = 100
  target_node = "maranet-pve"

  cores   = 4
  memory  = 8192
  balloon = 4096

  disk {
    storage = "local-lvm"
    size    = "50G"
    type    = "scsi"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 10
  }

  os_type = "l26"

  # Cloud-init
  ciuser     = "maranet"
  cipassword = "changeme"
  ipconfig0  = "ip=192.168.1.101/24,gw=192.168.1.1"
  nameserver = "1.1.1.1 8.8.8.8"

  tags = "api,production"
}

# VM 101: Gateway (WireGuard + NAT)
# Debian 12, 4 vCPU, 4GB RAM, 20GB disk
resource "proxmox_vm" "gateway" {
  name        = "maranet-gateway"
  vmid        = 101
  target_node = "maranet-pve"

  cores   = 4
  memory  = 4096
  balloon = 2048

  disk {
    storage = "local-lvm"
    size    = "20G"
    type    = "scsi"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 10
  }

  # Second NIC for WAN (if available)
  # network {
  #   model  = "virtio"
  #   bridge = "vmbr1"
  # }

  os_type = "l26"
  ciuser     = "maranet"
  ipconfig0  = "ip=192.168.1.102/24,gw=192.168.1.1"

  tags = "gateway,production"
}

# VM 102: Monitoring (Prometheus + Grafana)
# Debian 12, 2 vCPU, 4GB RAM, 100GB disk (metrics storage)
resource "proxmox_vm" "monitoring" {
  name        = "maranet-monitoring"
  vmid        = 102
  target_node = "maranet-pve"

  cores   = 2
  memory  = 4096
  balloon = 2048

  disk {
    storage = "local-lvm"
    size    = "100G"
    type    = "scsi"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 10
  }

  os_type = "l26"
  ciuser     = "maranet"
  ipconfig0  = "ip=192.168.1.103/24,gw=192.168.1.1"

  tags = "monitoring,production"
}

# VM 103: Database (PostgreSQL + Redis)
# Debian 12, 4 vCPU, 16GB RAM, 200GB disk
resource "proxmox_vm" "database" {
  name        = "maranet-db"
  vmid        = 103
  target_node = "maranet-pve"

  cores   = 4
  memory  = 16384
  balloon = 8192

  disk {
    storage = "local-lvm"
    size    = "200G"
    type    = "scsi"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 10
  }

  os_type = "l26"
  ciuser     = "maranet"
  ipconfig0  = "ip=192.168.1.104/24,gw=192.168.1.1"

  tags = "database,production"
}

# ============================================================
# Resource Allocation Summary
# ============================================================
# VM 100 (API):        4 vCPU,  8 GB RAM,  50 GB disk
# VM 101 (Gateway):    4 vCPU,  4 GB RAM,  20 GB disk
# VM 102 (Monitoring): 2 vCPU,  4 GB RAM, 100 GB disk
# VM 103 (Database):   4 vCPU, 16 GB RAM, 200 GB disk
# ────────────────────────────────────────────────────
# Total:              14 vCPU, 32 GB RAM, 370 GB disk
# Available:          12 cores (24 HT), 48 GB RAM, ~3.6 TB RAID10
# Headroom:           10 HT cores, 16 GB RAM, ~3.2 TB
