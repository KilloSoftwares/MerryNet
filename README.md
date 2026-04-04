# Maranet Zero

**Time-based, unlimited-data VPN service powered by M-Pesa**

Maranet Zero enables end users in Kenya to purchase affordable internet access via M-Pesa — even with zero mobile balance. Resellers earn income by hosting entry nodes on their own hardware.

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Mobile App  │────▶│ Reseller Node│────▶│   Main Server   │────▶ Internet
│  (Flutter)   │ WG  │  (Go Agent)  │ WG  │ (Node.js + Go)  │
└─────────────┘     └──────────────┘     └─────────────────┘
                                                   │
                                          ┌────────┼────────┐
                                          ▼        ▼        ▼
                                     PostgreSQL  Redis   Prometheus
                                                         + Grafana
```

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Main Server** | Node.js/TypeScript | REST API, M-Pesa, gRPC hub |
| **Gateway Service** | Go | WireGuard egress, NAT, iptables |
| **Reseller Agent** | Go | Local WireGuard peers, heartbeat |
| **Bootstrap API** | Rust/Actix | Zero-rated access endpoint |
| **Mobile App** | Flutter | User-facing VPN client |
| **Database** | PostgreSQL + Redis | Persistence + caching |
| **Monitoring** | Prometheus + Grafana | Metrics + dashboards |

---

## Quick Start

### Prerequisites
- Node.js 20+
- PostgreSQL 16+
- Redis 7+
- Go 1.21+ (gateway/agent)
- Rust 1.76+ (bootstrap API)
- Flutter 3.16+ (mobile app)
- Docker & Docker Compose (optional)

### Development Setup

> ⚠️ **Important:** Before starting, configure your environment variables. See [ENV_SETUP_GUIDE.md](ENV_SETUP_GUIDE.md) for detailed instructions.

```bash
# Clone the repo
git clone https://github.com/maranet/MerryNet.git
cd MerryNet

# Option 1: Automated setup
chmod +x scripts/setup.sh
./scripts/setup.sh

# Option 2: Manual setup
# 1. Configure environment variables (REQUIRED)
cp .env.example .env          # Root .env for Docker Compose
cp main-server/.env.example main-server/.env  # Main server .env
# Edit .env files with your credentials

# 2. Start development
cd main-server
npm install
npx prisma generate
npx prisma migrate deploy
npx tsx prisma/seed.ts
npm run dev
```

### Docker Compose (Full Stack)

```bash
cd deploy
docker compose up -d

# Services available:
# API:       http://localhost:3000
# Bootstrap: http://localhost:8080
# Grafana:   http://localhost:3001 (admin/maranet-admin)
# Prometheus: http://localhost:9090
```

---

## Project Structure

```
MerryNet/
├── proto/                    # Shared protobuf definitions
│   └── maranet.proto
├── main-server/              # Node.js API server
│   ├── prisma/               # Database schema & migrations
│   ├── src/
│   │   ├── config/           # App config, DB, Redis
│   │   ├── controllers/      # REST controllers
│   │   ├── grpc/             # gRPC server
│   │   ├── jobs/             # Bull job scheduler
│   │   ├── middleware/       # Auth, rate limiting, errors
│   │   ├── routes/           # Express routes
│   │   ├── services/         # Business logic
│   │   ├── utils/            # Helpers, validators, logger
│   │   └── index.ts          # Entry point
│   └── Dockerfile
├── gateway-service/          # Go WireGuard gateway
│   ├── cmd/gateway/          # Entry point
│   ├── internal/
│   │   ├── config/           # Configuration
│   │   ├── grpc/             # gRPC server
│   │   ├── metrics/          # Prometheus metrics
│   │   ├── nat/              # iptables NAT management
│   │   └── wireguard/        # WireGuard wgctrl
│   └── Dockerfile
├── reseller-agent/           # Go agent for reseller nodes
│   ├── cmd/agent/            # Entry point
│   ├── internal/
│   │   ├── config/           # Configuration
│   │   ├── grpcclient/       # gRPC client
│   │   ├── health/           # System health monitoring
│   │   ├── store/            # SQLite persistence
│   │   └── wireguard/        # Local peer management
│   └── Dockerfile
├── bootstrap-api/            # Rust zero-rated API
│   ├── src/main.rs           # Actix-Web server
│   ├── Cargo.toml
│   └── Dockerfile
├── mobile-app/               # Flutter mobile application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── network/      # Dio HTTP client
│   │   │   ├── router/       # GoRouter navigation
│   │   │   ├── services/     # API, VPN, carrier services
│   │   │   └── theme/        # Dark theme & colors
│   │   └── features/
│   │       ├── auth/         # Login & OTP
│   │       ├── home/         # Dashboard
│   │       ├── plans/        # Plan selection & payment
│   │       ├── vpn/          # VPN connection
│   │       ├── profile/      # User profile & settings
│   │       └── shell/        # Bottom navigation
│   └── pubspec.yaml
├── deploy/
│   ├── docker-compose.yml    # Full stack deployment
│   ├── nginx/                # Reverse proxy config
│   ├── ansible/              # Automated deployment
│   └── proxmox/              # VM configuration
├── monitoring/
│   ├── prometheus/           # Scrape config & alerts
│   └── grafana/              # Dashboard provisioning
├── docs/
│   ├── API.md                # REST API documentation
│   └── RESELLER_SETUP.md     # Reseller onboarding guide
├── scripts/
│   └── setup.sh              # Development setup
├── .github/workflows/
│   └── ci.yml                # CI/CD pipeline
└── README.md
```

---

## Business Model

| Plan | Duration | Price (KES) | Data |
|------|----------|-------------|------|
| Hourly | 1 hour | 10 | Unlimited |
| Daily | 24 hours | 30 | Unlimited |
| Weekly | 7 days | 150 | Unlimited |
| Monthly | 30 days | 500 | Unlimited |

**Revenue split:**
- 80% → Platform operator
- 20% → Reseller node operator

---

## API Endpoints

See [docs/API.md](docs/API.md) for full documentation.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/login` | ❌ | Request OTP |
| POST | `/auth/verify` | ❌ | Verify OTP |
| POST | `/auth/refresh` | ❌ | Refresh token |
| GET | `/auth/profile` | ✅ | User profile |
| GET | `/subscriptions/plans` | ❌ | List plans |
| GET | `/subscriptions/active` | ✅ | Active sub |
| POST | `/payments/initiate` | ✅ | M-Pesa STK Push |
| GET | `/payments/status/:id` | ✅ | Payment status |
| POST | `/resellers/register` | ✅ | Become reseller |
| GET | `/resellers/dashboard` | ✅ | Reseller stats |

---

## Deployment

### Proxmox (Production)

The system runs on an HP ProLiant ML350 G6 with 4 VMs:

| VM | vCPU | RAM | Disk | Purpose |
|----|------|-----|------|---------|
| 100 | 4 | 8 GB | 50 GB | API + Control Plane |
| 101 | 4 | 4 GB | 20 GB | Gateway (WireGuard) |
| 102 | 2 | 4 GB | 100 GB | Monitoring |
| 103 | 4 | 16 GB | 200 GB | Database |

```bash
# Deploy with Ansible
cd deploy/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-api.yml
ansible-playbook -i inventory/hosts.yml playbooks/deploy-gateway.yml
```

---

## License

MIT
# twin-ai
# twin-ai
