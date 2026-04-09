# MerryNet Complete System Setup Guide

This comprehensive guide covers setting up the entire MerryNet system, including the main server, gateway service, reseller agent, mobile app, and web dashboard.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [System Architecture](#system-architecture)
- [Quick Start](#quick-start)
- [Environment Setup](#environment-setup)
- [Component Setup](#component-setup)
- [Developer Mode Setup](#developer-mode-setup)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview

MerryNet is a complete VPN/network management system with the following components:

1. **Main Server** - Core API and business logic (Node.js)
2. **Gateway Service** - Network gateway and VPN management (Go)
3. **Reseller Agent** - Reseller-specific operations (Go)
4. **Bootstrap API** - Initial device registration (Rust)
5. **Mobile App** - Flutter client for end users
6. **Web Dashboard** - React/TypeScript admin interface

## Prerequisites

### Required Software
- **Docker & Docker Compose** - Container runtime
- **Node.js** (v18+) - For main server and web dashboard
- **Go** (v1.21+) - For gateway service and reseller agent
- **Rust** (v1.70+) - For bootstrap API
- **Flutter** (v3.10+) - For mobile app
- **Git** - Version control

### Recommended
- **Linux/macOS** - Development environment
- **8GB+ RAM** - For running all services
- **20GB+ Storage** - For code and containers

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │  Web Dashboard  │    │ Reseller Agent  │
│   (Flutter)     │    │   (React/TS)    │    │     (Go)        │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │    Gateway Service    │
                    │        (Go)           │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │      Main Server      │
                    │      (Node.js)        │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │     Bootstrap API     │
                    │       (Rust)          │
                    └───────────────────────┘
```

## Quick Start

For a quick local development setup:

```bash
# Clone the repository
git clone git@github.com:KilloSoftwares/MerryNet.git
cd MerryNet

# Copy environment files
cp .env.example .env
cp main-server/.env.example main-server/.env
cp gateway-service/.env.example gateway-service/.env
cp reseller-agent/.env.example reseller-agent/.env
cp bootstrap-api/.env.example bootstrap-api/.env

# Start all services with Docker
docker-compose -f deploy/docker-compose.yml up -d

# Install dependencies
make install

# Run tests
make test
```

## Environment Setup

### 1. Root Environment (.env)

```bash
# Copy the example file
cp .env.example .env

# Edit with your settings
nano .env
```

Key settings:
- `APP_ENV` - Environment (development, staging, production)
- `APP_DEBUG` - Debug mode
- `APP_URL` - Main application URL

### 2. Main Server Environment (main-server/.env)

```bash
cp main-server/.env.example main-server/.env
nano main-server/.env
```

Key settings:
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret for JWT tokens
- `REDIS_URL` - Redis connection string
- `PORT` - Server port (default: 3000)

### 3. Gateway Service Environment (gateway-service/.env)

```bash
cp gateway-service/.env.example gateway-service/.env
nano gateway-service/.env
```

Key settings:
- `GRPC_PORT` - gRPC server port (default: 50051)
- `WIREGUARD_PORT` - WireGuard VPN port (default: 51820)
- `MAIN_SERVER_URL` - URL to main server

### 4. Reseller Agent Environment (reseller-agent/.env)

```bash
cp reseller-agent/.env.example reseller-agent/.env
nano reseller-agent/.env
```

Key settings:
- `AGENT_ID` - Unique agent identifier
- `MAIN_SERVER_URL` - URL to main server
- `API_PORT` - Agent API port (default: 8080)

### 5. Bootstrap API Environment (bootstrap-api/.env)

```bash
cp bootstrap-api/.env.example bootstrap-api/.env
nano bootstrap-api/.env
```

Key settings:
- `PORT` - Bootstrap server port (default: 8080)
- `MAIN_SERVER_URL` - URL to main server

## Component Setup

### Main Server (Node.js)

```bash
cd main-server

# Install dependencies
npm install

# Run database migrations
npx prisma migrate deploy
npx prisma db seed

# Start development server
npm run dev

# Or build for production
npm run build
npm start
```

### Gateway Service (Go)

```bash
cd gateway-service

# Build the service
go build -o bin/gateway ./cmd/gateway

# Run development server
go run ./cmd/gateway

# Or run the built binary
./bin/gateway
```

### Reseller Agent (Go)

```bash
cd reseller-agent

# Build the agent
go build -o bin/agent ./cmd/agent

# Run the agent
./bin/agent
```

### Bootstrap API (Rust)

```bash
cd bootstrap-api

# Build the API
cargo build --release

# Run the API
cargo run
```

### Mobile App (Flutter)

```bash
cd mobile-app

# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Web Dashboard (React/TypeScript)

```bash
cd merry-net-dashboard

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

## Developer Mode Setup

Developer mode allows your apps to connect to remote servers for testing.

### Quick Setup

```bash
# Run the interactive setup script
./scripts/setup_developer_mode.sh
```

### Manual Setup

#### 1. Mobile App

Add the developer mode route to your app router (`mobile-app/lib/core/router/app_router.dart`):

```dart
GoRoute(
  path: '/developer-mode',
  name: 'developer-mode',
  builder: (context, state) => const DeveloperModeScreen(),
),
```

#### 2. Web Dashboard

Update `merry-net-dashboard/src/App.tsx`:

```tsx
import { useState } from 'react';
import DeveloperModeSettings from './components/DeveloperModeSettings';

function App() {
  const [showDevSettings, setShowDevSettings] = useState(false);

  return (
    <div className="app">
      {/* Your existing code */}
      <button onClick={() => setShowDevSettings(true)}>🔧 Dev Mode</button>
      <DeveloperModeSettings 
        isOpen={showDevSettings}
        onClose={() => setShowDevSettings(false)}
      />
    </div>
  );
}
```

#### 3. Configure Remote Server

1. Enable Developer Mode in your app
2. Select server mode:
   - **Local Development**: `http://localhost:3000/api/v1`
   - **Main Server (Production)**: `https://api.maranet.app/api/v1`
   - **Main Server (Staging)**: `https://staging-api.maranet.app/api/v1`
   - **Reseller Agent**: Custom configuration

3. For custom reseller servers, enter:
   - Host: Your server's public IP or domain
   - API Port: Your server's API port (usually 3000)
   - Bootstrap Port: Your server's bootstrap port (usually 8080)
   - Use TLS: Enable if using HTTPS

### Testing Remote Connection

1. Configure your desired server in developer mode
2. Click "Test Connection"
3. Check results:
   - ✓ Green: Connection successful
   - ✗ Red: Connection failed

## Testing

### Run All Tests

```bash
make test
```

### Component-Specific Tests

```bash
# Main Server
cd main-server && npm test

# Gateway Service
cd gateway-service && go test ./...

# Reseller Agent
cd reseller-agent && go test ./...

# Bootstrap API
cd bootstrap-api && cargo test

# Mobile App
cd mobile-app && flutter test

# Web Dashboard
cd merry-net-dashboard && npm test
```

### Integration Testing

```bash
# Start all services
docker-compose -f deploy/docker-compose.yml up -d

# Run integration tests
make test-integration
```

## Troubleshooting

### Common Issues

#### Database Connection Failed
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Verify connection string in .env
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1"
```

#### Port Already in Use
```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 <PID>

# Or change port in .env
```

#### Docker Build Failed
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache
```

#### Mobile App Build Failed
```bash
# Clean Flutter build
flutter clean
flutter pub get

# Rebuild
flutter build apk
```

#### Web Dashboard Build Failed
```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

### Developer Mode Issues

#### Connection Refused
- Verify server is running
- Check port numbers
- Ensure server is listening on correct interface (0.0.0.0 for remote)

#### CORS Errors (Web)
- Ensure server has CORS headers configured
- Add your domain to server's CORS allowlist

#### TLS/SSL Errors
- Verify server has valid certificate
- Use HTTP for local network testing

### Getting Help

1. Check logs:
   ```bash
   docker-compose logs <service-name>
   ```

2. View documentation:
   - `docs/DEVELOPER_MODE.md` - Developer mode guide
   - `docs/API.md` - API documentation
   - `docs/RESELLER_SETUP.md` - Reseller setup guide

3. Run diagnostics:
   ```bash
   ./scripts/test_developer_mode.sh
   ```

## Production Deployment

For production deployment:

1. Set `APP_ENV=production` in all .env files
2. Disable developer mode
3. Use proper SSL certificates
4. Configure firewall rules
5. Set up monitoring and logging
6. Follow the production deployment checklist in `docs/PRODUCTION_DEPLOYMENT_CHECKLIST.md`

## Maintenance

### Regular Updates

```bash
# Pull latest changes
git pull origin main

# Update dependencies
make update

# Run migrations
make migrate

# Restart services
docker-compose restart
```

### Backup Database

```bash
docker exec postgres pg_dump -U maranet maranet > backup.sql
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f main-server
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## License

See LICENSE file for details.