# Quick Start: Environment Variables Setup

## 🚀 5-Minute Setup

### Step 1: Copy Environment Templates

```bash
# Root .env (for Docker Compose)
cp .env.example .env

# Main Server .env
cp main-server/.env.example main-server/.env
```

### Step 2: Generate Critical Secrets

```bash
# Generate JWT Secret (for authentication)
JWT_SECRET=$(openssl rand -base64 64)
echo "JWT_SECRET=$JWT_SECRET" >> .env

# Generate WireGuard Private Key (for VPN)
WG_KEY=$(wg genkey)
echo "GATEWAY_WG_PRIVATE_KEY=$WG_KEY" >> .env
```

### Step 3: Configure M-Pesa (Optional - for payments)

1. Go to https://developer.safaricom.co.ke/
2. Create an app and get your credentials
3. Edit `.env` and add:

```bash
MPESA_CONSUMER_KEY=your_consumer_key_here
MPESA_CONSUMER_SECRET=your_consumer_secret_here
MPESA_PASS_KEY=your_pass_key_here
```

### Step 4: Change Default Passwords

Edit `.env` and change:

```bash
# Database password (change from default!)
POSTGRES_PASSWORD=your_strong_password_here

# Grafana password (change from default!)
GRAFANA_PASSWORD=your_strong_password_here
```

### Step 5: Start Services

```bash
# Using Docker Compose (recommended)
cd deploy
docker-compose up -d

# Or develop locally
cd ../main-server
npm install
npm run dev
```

## 📁 Which .env File Does What?

| .env File | Used By | When to Configure |
|-----------|---------|-------------------|
| `.env` (root) | Docker Compose | Always - controls all services |
| `main-server/.env` | Node.js API | Local development only |
| `gateway-service/.env` | Go Gateway | Local development only |
| `reseller-agent/.env` | Go Agent | Local development only |
| `bootstrap-api/.env` | Rust Bootstrap | Local development only |

**For Docker deployment:** Only configure `.env` (root)
**For local development:** Configure each service's `.env`

## 🔑 Required vs Optional Variables

### Required (Must Configure)
- `JWT_SECRET` - Authentication tokens
- `GATEWAY_WG_PRIVATE_KEY` - VPN encryption
- `POSTGRES_PASSWORD` - Database security

### Optional (Can Use Defaults)
- `MPESA_*` - Only needed for M-Pesa payments
- `GRAFANA_PASSWORD` - Has default `maranet-admin`
- `POSTGRES_USER`, `POSTGRES_DB` - Have defaults

## 🆘 Troubleshooting

### "Environment variable not found"
Make sure you copied the .env file:
```bash
cp .env.example .env
```

### "JWT_SECRET not set"
Generate a new one:
```bash
openssl rand -base64 64
```
Then add it to your `.env` file.

### "Database connection failed"
Check your database credentials in `.env`:
```bash
POSTGRES_USER=maranet
POSTGRES_PASSWORD=maranet_secret  # Did you change this?
POSTGRES_DB=maranet
```

### "M-Pesa payments not working"
1. Ensure you have real M-Pesa credentials (not placeholders)
2. Check `MPESA_ENVIRONMENT` is set correctly (sandbox or production)
3. Verify `MPESA_BASE_URL` matches your environment

## 📚 Full Documentation

For detailed information, see [ENV_SETUP_GUIDE.md](ENV_SETUP_GUIDE.md)