# Maranet Zero — Gateway Service

High-performance WireGuard VPN gateway written in Go. Manages VPN tunnels, NAT, and peer lifecycle.

## Quick Start

### Prerequisites

- Go 1.21+
- WireGuard tools (`wg`, `wg-quick`)
- Docker (optional, for containerized deployment)

### Development Setup

1. **Install dependencies**
   ```bash
   cd gateway-service
   go mod download
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

3. **Build**
   ```bash
   go build -o bin/gateway ./cmd/gateway
   ```

4. **Run (requires root for WireGuard)**
   ```bash
   sudo ./bin/gateway
   ```

### Production Deployment

1. **Build optimized binary**
   ```bash
   CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/gateway ./cmd/gateway
   ```

2. **Configure environment** (production values)

3. **Run as systemd service**
   ```bash
   sudo cp deploy/systemd/gateway.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable maranet-gateway
   sudo systemctl start maranet-gateway
   ```

### Docker Deployment

```bash
# Build image
docker build -t maranet-gateway .

# Run container (requires NET_ADMIN capability)
docker run -d \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -p 51820:51820/udp \
  -p 50052:50052 \
  --env-file .env \
  maranet-gateway
```

Or use Docker Compose from the root directory:
```bash
docker-compose up -d gateway
```

## Available Commands

| Command | Description |
|---------|-------------|
| `go build -o bin/gateway ./cmd/gateway` | Build gateway binary |
| `go test ./...` | Run tests |
| `go vet ./...` | Run static analysis |
| `go fmt ./...` | Format code |

## Configuration

All configuration is managed through environment variables. See [`.env.example`](.env.example) for all available options.

### Required Variables

- `WG_PRIVATE_KEY` — WireGuard private key (generate with `wg genkey`)
- `WG_INTERFACE` — WireGuard interface name (default: `wg0`)
- `WG_LISTEN_PORT` — UDP port for WireGuard (default: 51820)
- `WG_ADDRESS` — Gateway VPN IP and subnet (default: `10.0.0.1/16`)

### Optional Variables

- `GRPC_HOST` — gRPC server host (default: `0.0.0.0`)
- `GRPC_PORT` — gRPC server port (default: 50052)
- `NAT_EXTERNAL_INTERFACE` — External network interface for NAT (default: `eth0`)
- `NAT_INTERNAL_SUBNET` — Internal VPN subnet (default: `10.0.0.0/16`)
- `METRICS_PORT` — Prometheus metrics port (default: `9091`)

## WireGuard Key Generation

```bash
# Generate private key
wg genkey | tee privatekey | wg pubkey > publickey

# Use the private key as WG_PRIVATE_KEY
export WG_PRIVATE_KEY=$(cat privatekey)
```

## gRPC API

The gateway exposes a gRPC API for managing VPN peers. See [proto/maranet.proto](../proto/maranet.proto) for the service definition.

### Key Methods

- `CreatePeer` — Create a new VPN peer
- `DeletePeer` — Remove a VPN peer
- `UpdatePeer` — Update peer configuration
- `ListPeers` — List all active peers
- `CommandStream` — Bidirectional stream for real-time commands

## Metrics

Prometheus metrics are available at `http://localhost:9091/metrics`.

### Key Metrics

- `maranet_gateway_active_tunnels` — Number of active VPN tunnels
- `maranet_gateway_peers_total` — Total number of configured peers
- `maranet_gateway_bytes_sent` — Total bytes sent through VPN
- `maranet_gateway_bytes_received` — Total bytes received through VPN
- `maranet_gateway_handshake_errors` — WireGuard handshake errors

## Network Configuration

### Default Network Layout

| Component | IP Range | Description |
|-----------|----------|-------------|
| Gateway | 10.0.0.1/16 | WireGuard gateway |
| Peers | 10.0.1.0/16 | VPN client IPs |
| External | eth0 | Outgoing internet interface |

### NAT Configuration

The gateway automatically configures iptables for NAT:

```bash
# Outgoing traffic is masqueraded
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Forward traffic from VPN to internet
iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## Systemd Service

Example systemd unit file:

```ini
[Unit]
Description=Maranet Zero Gateway Service
After=network.target

[Service]
Type=simple
User=maranet
Group=maranet
ExecStart=/usr/local/bin/gateway
Restart=always
RestartSec=5
EnvironmentFile=/etc/maranet/gateway.env

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
CapabilityBoundingSet=CAP_NET_ADMIN CAP_SYS_MODULE
AmbientCapabilities=CAP_NET_ADMIN CAP_SYS_MODULE

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

### WireGuard Interface Issues

```bash
# Check if WireGuard module is loaded
lsmod | grep wireguard

# Check interface status
wg show wg0

# View interface configuration
ip addr show wg0
```

### NAT/Firewall Issues

```bash
# Check iptables rules
sudo iptables -t nat -L -n -v

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward
```

### gRPC Connection Issues

```bash
# Test gRPC connection (requires grpcurl)
grpcurl -plaintext localhost:50052 list
```

## License

Proprietary — Maranet Zero