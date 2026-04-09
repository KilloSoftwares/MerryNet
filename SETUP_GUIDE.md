# Maranet Zero — Complete Setup Guide

This guide covers setting up all three core services: Main API Server, Gateway Service, and Bootstrap API.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start (Docker)](#quick-start-docker)
3. [Manual Setup](#manual-setup)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Docker | 24+ | Container runtime |
| Docker Compose | 2.20+ | Multi-container orchestration |
| Node.js | 20+ | Main API Server |
| Go | 1.21+ | Gateway Service |
| Rust | 1.76+ | Bootstrap API |
| PostgreSQL | 16+ | Database (or use Docker) |
| Redis | 7+ | Cache (or use Docker) |

### System Requirements

| Component | CPU | RAM | Storage |
|-----------|-----|-----|---------|
| Development | 2 cores | 4GB | 10GB |
| Production | 4 cores | 8GB | 50GB |

---

## Quick Start (Docker)

The fastest way to get all services running is with Docker Compose.

### 1. Clone and Configure

```bash
# Clone repository
git clone https://github.com/KilloSoftwares/MerryNet.git
cd MerryNet

# Copy environment template
cp .env.example .env

# Generate secrets
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
echo "JWT_SECRET=$(openssl rand -base64 64)" >> .env
echo "REDIS_PASSWORD=$(openssl rand -base64 24)" >> .env
echo "GATEWAY_WG_PRIVATE_KEY=$(wg genkey)" >> .env
echo "GRAFANA_PASSWORD=$(openssl rand -base64 24)" >> .env

# Edit .env with your production values
nano .env
```

### 2. Start all services

```bash
docker-compose up -d
```

### 3. Verify deployment

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f

# Run verification script
./scripts/verify-production.sh
```

### 4. Access services

| Service | URL | Port |
|---------|-----|------|
| API Server | http://localhost:3000 | 3000 |
| Bootstrap API | http://localhost:8080 | 8080 |
| Gateway (gRPC) | localhost:50052 | 50052 |
| Gateway (WireGuard) | localhost:51820/udp | 51820 |
| Grafana | http://localhost:3001 | 3001 |
| Prometheus | Internal only | 9090 |

---

## Manual Setup

### Main API Server (Node.js)

```bash
# Navigate to main-server
cd main-server

# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Copy environment
cp ../.env.example .env
# Edit .env with your values

# Run database migrations
npx prisma migrate deploy

# Build for production
npm run build

# Start server
npm start
```

### Gateway Service (Go)

```bash
# Navigate to gateway-service
cd gateway-service

# Download dependencies
go mod download

# Copy environment
cp .env.example .env
# Edit .env with your values (especially WG_PRIVATE_KEY)

# Build binary
go build -o bin/gateway ./cmd/gateway

# Run (requires root for WireGuard)
sudo ./bin/gateway
```

### Bootstrap API (Rust)

```bash
# Navigate to bootstrap-api
cd bootstrap-api

# Build
cargo build --release

# Copy environment
cp .env.example .env
# Edit .env with your values

# Run
./target/release/bootstrap-api
```

---

## Configuration

### Environment Variables

All services use environment variables for configuration. See each service's README for details:

- [Main Server Configuration](main-server/README.md#configuration)
- [Gateway Configuration](gateway-service/README.md#configuration)
- [Bootstrap API Configuration](bootstrap-api/README.md#configuration)

### Required Variables (All Services)

```bash
# Database
POSTGRES_DB=maranet
POSTGRES_USER=maranet
POSTGRES_PASSWORD=<strong-password>

# JWT
JWT_SECRET=<64-character-random-string>

# Redis
REDIS_PASSWORD=<strong-password>

# WireGuard
GATEWAY_WG_PRIVATE_KEY=<wireguard-private-key>

# Grafana
GRAFANA_PASSWORD=<strong-password>

# M-Pesa (Production)
MPESA_CONSUMER_KEY=<your-consumer-key>
MPESA_CONSUMER_SECRET=<your-consumer-secret>
MPESA_PASS_KEY=<your-pass-key>
MPESA_ENVIRONMENT=production
```

### Generating Secrets

```bash
# Strong password (32 chars)
openssl rand -base64 32

# JWT secret (64 chars)
openssl rand -base64 64

# WireGuard private key
wg genkey
```

---

## Verification

### Health Checks

```bash
# Main API Server
curl http://localhost:3000/api/v1/health

# Bootstrap API
curl http://localhost:8080/health

# Gateway (gRPC)
grpcurl -plaintext localhost:50052 list
```

### Database Check

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U maranet -d maranet -c "SELECT 1"

# Check migrations
docker-compose exec main-server npx prisma migrate status
```

### Redis Check

```bash
# Test Redis connection
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

### Full Verification

```bash
# Run comprehensive verification script
./scripts/verify-production.sh
```

---

## Troubleshooting

### Common Issues

#### Port Already in Use

```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 <PID>
```

#### Database Connection Failed

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# View PostgreSQL logs
docker-compose logs postgres

# Test connection
psql postgresql://maranet:password@localhost:5432/maranet
```

#### WireGuard Interface Issues

```bash
# Check if WireGuard module is loaded
lsmod | grep wireguard

# Load module if needed
sudo modprobe wireguard

# Check interface
wg show
```

#### Permission Denied

```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Fix file permissions
sudo chown -R $USER:$USER .
```

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f main-server
docker-compose logs -f gateway
docker-compose logs -f bootstrap-api

# Last 100 lines
docker-compose logs --tail=100 main-server
```

### Reset Everything

```bash
# Stop all containers
docker-compose down

# Remove volumes (WARNING: deletes all data!)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Start fresh
docker-compose up -d
```

---

## Next Steps

1. **Configure M-Pesa** — Get production credentials from [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
2. **Set up SSL** — Configure Let's Encrypt certificates
3. **Deploy monitoring** — Access Grafana at http://localhost:3001
4. **Configure alerts** — Set up Slack/email notifications in Alertmanager
5. **Review security** — Follow the [SECURITY.md](SECURITY.md) guidelines

## Additional Resources

- [API Documentation](docs/API.md)
- [Production Readiness Report](docs/PRODUCTION_READINESS_REPORT.md)
- [Security Policy](SECURITY.md)
- [Reseller Setup Guide](docs/RESELLER_SETUP.md)

---

*For service-specific documentation, see the README in each service directory.*