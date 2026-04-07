#!/bin/bash
# ============================================================
# Build Script for OS, SDK, and App Components
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_ROOT/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# Build Sky OS (Kernel + Services)
# ============================================================
build_os() {
    print_header "Building Sky OS"
    
    mkdir -p "$BIN_DIR"
    
    # Build Core Kernel
    print_info "Building Sky OS Core Kernel..."
    if cd "$PROJECT_ROOT/skyos/core" && go build -o "$BIN_DIR/skyos-kernel" .; then
        print_success "Sky OS Core Kernel built: $BIN_DIR/skyos-kernel"
    else
        print_error "Failed to build Sky OS Core Kernel"
        return 1
    fi
    
    # Build Services
    print_info "Building Sky OS Services..."
    if cd "$PROJECT_ROOT/skyos/services" && go build -o "$BIN_DIR/skyos-services" .; then
        print_success "Sky OS Services built: $BIN_DIR/skyos-services"
    else
        print_error "Failed to build Sky OS Services"
        return 1
    fi
    
    print_success "Sky OS build complete!"
}

# ============================================================
# Build/Setup Android SDK
# ============================================================
build_sdk() {
    print_header "Setting up Android SDK"
    
    SDK_DIR="$PROJECT_ROOT/android-sdk"
    CMDLINE_TOOLS="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
    
    if [ ! -f "$CMDLINE_TOOLS" ]; then
        print_error "Android SDK cmdline-tools not found at $CMDLINE_TOOLS"
        print_info "The SDK tools should be placed in android-sdk/cmdline-tools/latest/"
        return 1
    fi
    
    print_info "Android SDK cmdline-tools found"
    
    # Make sdkmanager executable
    chmod +x "$CMDLINE_TOOLS"
    
    # List available packages
    print_info "Available SDK packages:"
    echo ""
    $CMDLINE_TOOLS --list 2>/dev/null | head -20 || print_info "Run with sudo if needed for full list"
    
    echo ""
    print_info "To install packages, run:"
    echo "  $CMDLINE_TOOLS \"platforms;android-34\" \"build-tools;34.0.0\""
    
    print_success "Android SDK setup complete!"
}

# ============================================================
# Build Mobile App (Flutter)
# ============================================================
build_app() {
    local target="${1:-apk}"
    
    print_header "Building Mobile App ($target)"
    
    if ! command_exists flutter; then
        print_error "Flutter is not installed. Please install Flutter first."
        return 1
    fi
    
    cd "$PROJECT_ROOT/mobile-app"
    
    # Get dependencies
    print_info "Getting Flutter dependencies..."
    flutter pub get
    
    case "$target" in
        apk)
            print_info "Building Android APK..."
            if flutter build apk; then
                print_success "APK built: mobile-app/build/outputs/apk/release/app-release.apk"
            else
                print_error "Failed to build APK"
                return 1
            fi
            ;;
        ios)
            print_info "Building iOS app..."
            if flutter build ios; then
                print_success "iOS app built: mobile-app/build/ios/iphoneos/Runner.app"
            else
                print_error "Failed to build iOS app"
                return 1
            fi
            ;;
        web)
            print_info "Building web app..."
            if flutter build web; then
                print_success "Web app built: mobile-app/build/web/"
            else
                print_error "Failed to build web app"
                return 1
            fi
            ;;
        *)
            print_error "Unknown target: $target. Use: apk, ios, or web"
            return 1
            ;;
    esac
    
    print_success "Mobile app build complete!"
}

# ============================================================
# Build All Components
# ============================================================
build_all() {
    print_header "Building All Components (OS, SDK, App)"
    
    build_os || return 1
    echo ""
    build_sdk || return 1
    echo ""
    build_app "apk" || return 1
    
    echo ""
    print_header "All Components Built Successfully!"
    echo -e "${GREEN}
    Summary:
    --------
    • Sky OS:       $BIN_DIR/skyos-kernel, $BIN_DIR/skyos-services
    • Android SDK:  $PROJECT_ROOT/android-sdk/cmdline-tools/
    • Mobile App:   $PROJECT_ROOT/mobile-app/build/outputs/apk/release/app-release.apk
    ${NC}"
}

# ============================================================
# Clean Build Artifacts
# ============================================================
clean() {
    print_header "Cleaning Build Artifacts"
    
    rm -rf "$BIN_DIR"
    print_success "Removed $BIN_DIR"
    
    cd "$PROJECT_ROOT/mobile-app" && flutter clean
    print_success "Cleaned mobile-app"
    
    print_success "Clean complete!"
}

# ============================================================
# Usage
# ============================================================
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  os          Build Sky OS (kernel + services)"
    echo "  sdk         Setup Android SDK"
    echo "  app [type]  Build Mobile App (apk|ios|web), default: apk"
    echo "  all         Build all components (os + sdk + app)"
    echo "  clean       Clean build artifacts"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 os              # Build only Sky OS"
    echo "  $0 sdk             # Setup Android SDK"
    echo "  $0 app apk         # Build Android APK"
    echo "  $0 app ios         # Build iOS app"
    echo "  $0 all             # Build everything"
}

# ============================================================
# Main
# ============================================================
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        os)
            build_os
            ;;
        sdk)
            build_sdk
            ;;
        app)
            build_app "${1:-apk}"
            ;;
        all)
            build_all
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"