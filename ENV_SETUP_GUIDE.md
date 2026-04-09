# Environment Variables Setup Guide

This guide explains how to configure environment variables for all Maranet services.

## 📁 Environment File Locations

| Service | .env Location | .env.example Location |
|---------|---------------|----------------------|
| Root (Docker Compose) | `./.env` | `./.env.example` |
| Main Server (Node.js) | `main-server/.env` | `main-server/.env.example` |
| Gateway Service (Go) | `gateway-service/.env` | `gateway-service/.env.example` |
| Reseller Agent (Go) | `reseller-agent/.env` | `reseller-agent/.env.example` |
| Bootstrap API (Rust) | `bootstrap-api/.env` | `bootstrap-api/.env.example` |

## 🚀 Quick Start

### 1. Docker Compose Deployment

```bash
# Copy the root .env.example
cp .env.example .env

# Generate a strong JWT secret
openssl rand -base64 64 | tr -d '\n' > /tmp/jwt_secret
echo "JWT_SECRET=$(cat /tmp/jwt_secret)" >> .env

# Generate WireGuard private key
echo "GATEWAY_WG_PRIVATE_KEY=$(wg genkey)" >> .env

# Configure M-Pesa credentials (get from https://developer.safaricom.co.ke/)
# Edit .env and set:
# MPESA_CONSUMER_KEY=your-key
# MPESA_CONSUMER_SECRET=your-secret

# Start all services
cd deploy && docker-compose up -d
```

### 2. Local Development

```bash
# Main Server
cd main-server
cp .env.example .env
# Edit .env with your values
npm install
npm run dev

# Gateway Service
cd ../gateway-service
cp .env.example .env
# Edit .env with your values
go run cmd/gateway/main.go

# Reseller Agent
cd ../reseller-agent
cp .env.example .env
# Edit .env with your values
go run cmd/agent/main.go

# Bootstrap API
cd ../bootstrap-api
cp .env.example .env
# Edit .env with your values
cargo run
```

## 🔑 Critical Credentials

### JWT Secret
- **Used by:** Main Server
- **Purpose:** Signing and verifying JWT tokens
- **Generate:** `openssl rand -base64 64`
- **Never use default in production!**

### WireGuard Private Key
- **Used by:** Gateway Service, Reseller Agent
- **Purpose:** VPN encryption
- **Generate:** `wg genkey`
- **Each instance should have a unique key**

### M-Pesa Credentials
- **Used by:** Main Server
- **Purpose:** Payment processing via Safaricom Daraja API
- **Get from:** https://developer.safaricom.co.ke/
- **Required:** Consumer Key, Consumer Secret, Pass Key, Business Short Code

### Database Credentials
- **Used by:** Main Server (PostgreSQL)
- **Default:** maranet / maranet_secret
- **Change in production!**

### Grafana Password
- **Used by:** Grafana monitoring dashboard
- **Default:** maranet-admin
- **Change in production!**

## 📋 Environment Variables Reference

### Root (.env for Docker Compose)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `JWT_SECRET` | JWT signing secret | - | ✅ Yes |
| `MPESA_CONSUMER_KEY` | M-Pesa API key | - | For payments |
| `MPESA_CONSUMER_SECRET` | M-Pesa API secret | - | For payments |
| `MPESA_BUSINESS_SHORT_CODE` | M-Pesa paybill | 174379 | For payments |
| `MPESA_PASS_KEY` | M-Pesa pass key | - | For payments |
| `MPESA_CALLBACK_URL` | Payment callback URL | https://api.maranet.app/api/v1/payments/mpesa/callback | For payments |
| `MPESA_ENVIRONMENT` | sandbox or production | sandbox | For payments |
| `MPESA_BASE_URL` | M-Pesa API URL | https://sandbox.safaricom.co.ke | For payments |
| `GATEWAY_WG_PRIVATE_KEY` | WireGuard private key | - | ✅ Yes |
| `GRAFANA_PASSWORD` | Grafana admin password | maranet-admin | Recommended |
| `POSTGRES_DB` | Database name | maranet | ✅ Yes |
| `POSTGRES_USER` | Database user | maranet | ✅ Yes |
| `POSTGRES_PASSWORD` | Database password | maranet_secret | ✅ Yes |

### Main Server (main-server/.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment | development |
| `PORT` | Server port | 3000 |
| `HOST` | Server host | 0.0.0.0 |
| `DATABASE_URL` | PostgreSQL connection | postgresql://... |
| `REDIS_URL` | Redis connection | redis://localhost:6379 |
| `JWT_SECRET` | JWT signing secret | dev-secret-change-me |
| `JWT_EXPIRES_IN` | Token expiry | 7d |
| `MPESA_*` | M-Pesa credentials | - |
| `GRPC_PORT` | gRPC server port | 50051 |
| `GRPC_USE_TLS` | Enable gRPC TLS for internal node communication | false |
| `GRPC_TLS_CERT_FILE` | TLS certificate file path | |
| `GRPC_TLS_KEY_FILE` | TLS private key file path | |
| `GATEWAY_HOST` | Gateway service host | localhost |
| `GATEWAY_GRPC_PORT` | Gateway gRPC port | 50052 |
| `GATEWAY_USE_TLS` | Enable TLS for gateway gRPC client | false |
| `GATEWAY_TLS_CA_FILE` | Root CA file for gateway TLS | |

### Gateway Service (gateway-service/.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ID` | Gateway identifier | gateway-{hostname} |
| `WG_INTERFACE` | WireGuard interface | wg0 |
| `WG_LISTEN_PORT` | WireGuard port | 51820 |
| `WG_PRIVATE_KEY` | WireGuard private key | - |
| `WG_ADDRESS` | VPN network CIDR | 10.0.0.1/16 |
| `GRPC_HOST` | gRPC bind host | 0.0.0.0 |
| `GRPC_PORT` | gRPC port | 50052 |

### Reseller Agent (reseller-agent/.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `DEVICE_ID` | Agent identifier | node-001 |
| `PLATFORM` | Platform type | rpi |
| `SERVER_ADDRESS` | Main server address | localhost:50051 |
| `WG_PRIVATE_KEY` | WireGuard private key | - |
| `WG_ADDRESS` | Agent VPN CIDR | 10.0.1.1/24 |
| `DB_PATH` | SQLite database path | /var/lib/maranet/agent.db |

### Bootstrap API (bootstrap-api/.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Server host | 0.0.0.0 |
| `PORT` | Server port | 8080 |
| `MAIN_SERVER_URL` | Main server URL | http://localhost:3000 |
| `RUST_LOG` | Log level | info |

## 🔒 Security Best Practices

1. **Never commit .env files** - They are in .gitignore for a reason
2. **Use strong random secrets** - Use `openssl rand -base64 64` for secrets
3. **Rotate credentials regularly** - Especially API keys and secrets
4. **Use different credentials per environment** - Dev, staging, production
5. **Limit .env file permissions** - `chmod 600 .env`
6. **Use secrets management in production** - Consider HashiCorp Vault, AWS Secrets Manager, etc.

## 🆘 Troubleshooting

### Environment variables not loading

**Node.js:**
```bash
# Check if dotenv is loading
node -e "require('dotenv').config({path: '.env'}); console.log(process.env.JWT_SECRET)"
```

**Go:**
```bash
# Check if godotenv is loading
# The services log startup info - look for "Loading environment" messages
```

**Rust:**
```bash
# Check if dotenv is loading
# Look for the dotenv::dotenv().ok() call in main.rs
```

### Docker Compose variables not applied

```bash
# Verify .env file exists in the same directory as docker-compose.yml
ls -la deploy/.env

# Check variable names match exactly (case-sensitive)
cat .env | grep JWT_SECRET
```

## 📚 Additional Resources

- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [dotenv (Node.js)](https://www.npmjs.com/package/dotenv)
- [godotenv (Go)](https://github.com/joho/godotenv)
- [dotenv-rust (Rust)](https://crates.io/crates/dotenv)