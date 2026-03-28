#!/bin/bash
# ============================================================
# Maranet Zero — Setup Script
# Initializes the development environment
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║        🚀 Maranet Zero — Development Setup           ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# Check prerequisites
# ============================================================
echo "📋 Checking prerequisites..."

check_command() {
    if command -v "$1" &>/dev/null; then
        echo "  ✅ $1 found: $($1 --version 2>/dev/null | head -1)"
    else
        echo "  ❌ $1 not found! Please install it."
        return 1
    fi
}

check_command node || exit 1
check_command npm || exit 1

# Optional checks
check_command go 2>/dev/null || echo "  ⚠️  Go not found (needed for gateway/agent)"
check_command rustc 2>/dev/null || echo "  ⚠️  Rust not found (needed for bootstrap-api)"
check_command docker 2>/dev/null || echo "  ⚠️  Docker not found (needed for full stack)"
check_command flutter 2>/dev/null || echo "  ⚠️  Flutter not found (needed for mobile app)"

echo ""

# ============================================================
# Main Server Setup
# ============================================================
echo "📦 Setting up Main Server..."
cd "$ROOT_DIR/main-server"

# Copy env file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "  📝 Created .env from .env.example"
fi

# Install dependencies
echo "  📥 Installing Node.js dependencies..."
npm install

# Generate Prisma client
echo "  🔄 Generating Prisma client..."
npx prisma generate

echo "  ✅ Main server setup complete"
echo ""

# ============================================================
# Go Services (if Go is installed)
# ============================================================
if command -v go &>/dev/null; then
    echo "📦 Setting up Go services..."

    if [ -d "$ROOT_DIR/gateway-service" ]; then
        cd "$ROOT_DIR/gateway-service"
        go mod tidy 2>/dev/null || echo "  ⚠️  gateway-service mod tidy skipped"
        echo "  ✅ Gateway service ready"
    fi

    if [ -d "$ROOT_DIR/reseller-agent" ]; then
        cd "$ROOT_DIR/reseller-agent"
        go mod tidy 2>/dev/null || echo "  ⚠️  reseller-agent mod tidy skipped"
        echo "  ✅ Reseller agent ready"
    fi
    echo ""
fi

# ============================================================
# Rust Bootstrap API (if Rust is installed)
# ============================================================
if command -v cargo &>/dev/null; then
    echo "📦 Setting up Bootstrap API..."
    cd "$ROOT_DIR/bootstrap-api"
    cargo check 2>/dev/null || echo "  ⚠️  Bootstrap API cargo check skipped"
    echo "  ✅ Bootstrap API ready"
    echo ""
fi

# ============================================================
# Flutter Mobile App (if Flutter is installed)
# ============================================================
if command -v flutter &>/dev/null; then
    echo "📦 Setting up Mobile App..."
    cd "$ROOT_DIR/mobile-app"
    flutter pub get 2>/dev/null || echo "  ⚠️  Flutter pub get skipped"
    echo "  ✅ Mobile app ready"
    echo ""
fi

# ============================================================
# Done
# ============================================================
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║        ✅ Setup Complete!                             ║"
echo "║                                                      ║"
echo "║  Next steps:                                         ║"
echo "║  1. Start PostgreSQL & Redis (or docker compose)     ║"
echo "║  2. Run migrations: cd main-server && npm run db:push║"
echo "║  3. Seed data: npm run db:seed                       ║"
echo "║  4. Start server: npm run dev                        ║"
echo "║                                                      ║"
echo "║  Or start everything with Docker:                    ║"
echo "║  cd deploy && docker compose up -d                   ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
