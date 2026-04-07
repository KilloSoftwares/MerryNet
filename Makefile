# ============================================================
# Maranet Zero — System Makefile
# ============================================================

.PHONY: all setup build run clean test

# Default target
all: build

# ============================================================
# 1. Setup & Dependencies
# ============================================================
setup:
	@echo "=> Running setup script..."
	chmod +x scripts/setup.sh
	./scripts/setup.sh

# ============================================================
# 2. Build Targets
# ============================================================
build: build-api build-gateway build-agent build-bootstrap

build-api:
	@echo "=> Building Main Server (Node.js)..."
	cd main-server && npm install && npm run build

build-gateway:
	@echo "=> Building Gateway Service (Go)..."
	cd gateway-service && go build -o bin/gateway cmd/gateway/main.go

build-agent:
	@echo "=> Building Reseller Agent (Go)..."
	cd reseller-agent && go build -o bin/agent cmd/agent/main.go

build-bootstrap:
	@echo "=> Building Bootstrap API (Rust)..."
	cd bootstrap-api && cargo build --release

# ============================================================
# 2.2 Mobile App Build Targets
# ============================================================
build-mobile:
	@echo "=> Building Mobile App (Flutter APK)..."
	cd mobile-app && flutter build apk

build-mobile-ios:
	@echo "=> Building Mobile App (Flutter iOS)..."
	cd mobile-app && flutter build ios

build-mobile-web:
	@echo "=> Building Mobile App (Flutter Web)..."
	cd mobile-app && flutter build web

# ============================================================
# 3. Sky OS Build Targets
# ============================================================
build-os: build-os-core build-os-services

build-os-core:
	@echo "=> Building Sky OS Core Kernel..."
	cd skyos/core && go build -o ../../bin/skyos-kernel .

build-os-services:
	@echo "=> Building Sky OS Services..."
	cd skyos/services && go build -o ../../bin/skyos-services .

# ============================================================
# 4. Android SDK Build Targets
# ============================================================
build-sdk:
	@echo "=> Setting up Android SDK..."
	@echo "Android SDK cmdline-tools already present in android-sdk/"
	@echo "To install additional SDK packages, run:"
	@echo "  ./android-sdk/cmdline-tools/latest/bin/sdkmanager --list"

build-sdk-accept-licenses:
	@echo "=> Accepting Android SDK licenses..."
	yes | ./android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses || true

# ============================================================
# 5. Build All Components Separately
# ============================================================
build-all: build-os build-sdk build-mobile
	@echo "=> All components built successfully!"
	@echo "  - Sky OS: bin/skyos-kernel, bin/skyos-services"
	@echo "  - Android SDK: android-sdk/cmdline-tools/"
	@echo "  - Mobile App: mobile-app/build/outputs/apk/"

# ============================================================
# 6. Development / Run Targets
# ============================================================
run: run-infra generate-db run-api

run-infra:
	@echo "=> Starting Infrastructure (PostgreSQL, Redis, Monitoring)..."
	cd deploy && sudo docker compose up -d postgres redis prometheus grafana

run-api:
	@echo "=> Starting Main Server Locally..."
	cd main-server && npm run dev

run-bootstrap:
	@echo "=> Starting Bootstrap API Locally..."
	cd bootstrap-api && cargo run

run-all-docker:
	@echo "=> Starting Full Stack via Docker Compose..."
	cd deploy && sudo docker compose up --build -d

# ============================================================
# 7. Database Tools
# ============================================================
generate-db:
	@echo "=> Generating Prisma Client & Pushing Schema..."
	cd main-server && npx prisma generate && npx prisma db push

seed-db:
	@echo "=> Seeding Database..."
	cd main-server && npm run db:seed

studio:
	@echo "=> Opening Prisma Studio..."
	cd main-server && npm run db:studio

# ============================================================
# 8. Utilities
# ============================================================
logs:
	@echo "=> Tailing Docker logs..."
	cd deploy && sudo docker compose logs -f

clean:
	@echo "=> Cleaning up build artifacts..."
	rm -rf main-server/dist
	rm -rf main-server/node_modules
	rm -rf gateway-service/bin
	rm -rf reseller-agent/bin
	cd bootstrap-api && cargo clean
	cd mobile-app && flutter clean
	cd deploy && sudo docker compose down -v
