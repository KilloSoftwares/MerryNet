# Maranet Zero — Reseller Node Setup Guide

## Overview

As a reseller, your device acts as a **VPN entry node** for Maranet users. Users connect to your node via WireGuard, and their traffic is forwarded through the main server to the internet.

**Compensation options:**
- **20% Commission**: Earn 20% of every payment from users connecting through your node
- **Free Internet**: Get free unlimited internet instead of cash

---

## Supported Platforms

| Platform | Device | Image Type |
|----------|--------|------------|
| **Raspberry Pi** | RPi 3B+, 4, 5 | `.img` SD card image |
| **VPS** | Any cloud VPS | Docker container |
| **Android** | Any rooted phone | Termux package |

---

## Quick Setup: Raspberry Pi

### 1. Download the Gateway OS image

```bash
wget https://releases.maranet.app/gateway-os/latest/maranet-rpi.img.gz
gunzip maranet-rpi.img.gz
```

### 2. Flash to SD card

```bash
sudo dd if=maranet-rpi.img of=/dev/sdX bs=4M status=progress
sync
```

### 3. First boot configuration

Insert the SD card, connect ethernet, and power on. The node will:
1. Generate WireGuard keys
2. Connect to the main server
3. Register itself automatically

### 4. Check status

SSH into your Pi (default: `pi@maranet-node.local`):
```bash
ssh pi@maranet-node.local
# password: maranet

# Check agent status
sudo systemctl status maranet-agent

# View logs
sudo journalctl -u maranet-agent -f
```

---

## Quick Setup: VPS (Docker)

### 1. Install Docker
```bash
curl -fsSL https://get.docker.com | sh
```

### 2. Run the reseller agent
```bash
docker run -d \
  --name maranet-agent \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  -e DEVICE_ID="my-vps-node-01" \
  -e SERVER_ADDRESS="grpc.maranet.app:50051" \
  -e PLATFORM="vps" \
  -p 51820:51820/udp \
  maranet/reseller-agent:latest
```

### 3. Verify
```bash
docker logs -f maranet-agent
```

---

## Quick Setup: Android (Termux)

### 1. Install Termux from F-Droid

### 2. Install the agent
```bash
pkg update && pkg install wget
wget https://releases.maranet.app/agent/android/maranet-agent
chmod +x maranet-agent
```

### 3. Run
```bash
DEVICE_ID="my-phone-01" \
SERVER_ADDRESS="grpc.maranet.app:50051" \
PLATFORM="android" \
./maranet-agent
```

---

## Configuration

Environment variables for the agent:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE_ID` | `node-001` | Unique identifier for your node |
| `SERVER_ADDRESS` | `localhost:50051` | Main server gRPC address |
| `PLATFORM` | `rpi` | Platform type: rpi, vps, android |
| `WG_INTERFACE` | `wg0` | WireGuard interface name |
| `WG_LISTEN_PORT` | `51820` | WireGuard listen port |
| `WG_ADDRESS` | `10.0.1.1/24` | WireGuard address (assigned by server) |
| `DB_PATH` | `/var/lib/maranet/agent.db` | SQLite database path |
| `HEARTBEAT_INTERVAL` | `30` | Heartbeat interval in seconds |

---

## Monitoring Your Node

Check your earnings and node status on the Maranet app:
1. Open the app → Profile → **Reseller Dashboard**
2. View active connections, bandwidth usage, and earnings

---

## Network Requirements

| Direction | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| Inbound | 51820 | UDP | WireGuard (users connect here) |
| Outbound | 50051 | TCP | gRPC (to main server) |
| Outbound | 51820 | UDP | WireGuard (tunnel to gateway) |

**Minimum bandwidth:** 10 Mbps recommended
**Static IP:** Recommended but not required (dynamic DNS supported)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agent won't start | Check WireGuard module: `sudo modprobe wireguard` |
| Can't connect to server | Verify `SERVER_ADDRESS` and firewall rules |
| Users can't connect | Ensure port 51820/UDP is open |
| High CPU usage | Check `HEARTBEAT_INTERVAL`, reduce if too frequent |
| Agent keeps restarting | Check logs: `journalctl -u maranet-agent` |
