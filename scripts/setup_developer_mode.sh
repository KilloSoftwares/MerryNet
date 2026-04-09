#!/bin/bash

# MerryNet Developer Mode Setup Script
# This script guides you through setting up developer mode for remote testing

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to print step headers
print_step() {
    echo ""
    echo -e "${GREEN}Step $1: $2${NC}"
    echo "----------------------------------------"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press Enter when ready to continue...${NC}"
    read -r
}

print_header "MerryNet Developer Mode Setup Guide"

echo "This script will guide you through setting up developer mode for remote testing."
echo "Developer mode allows your mobile app and web dashboard to connect to remote servers."
echo ""
echo "Estimated time: 10-15 minutes"
echo "Prerequisites: Internet connection, access to remote servers"

wait_for_user

# Step 1: Verify Implementation
print_step 1 "Verify Developer Mode Implementation"

echo "Checking if developer mode files are properly implemented..."

if [ -f "mobile-app/lib/core/config/server_config.dart" ]; then
    echo -e "${GREEN}✓${NC} Mobile app server configuration found"
else
    echo -e "${RED}✗${NC} Mobile app server configuration missing"
    exit 1
fi

if [ -f "merry-net-dashboard/src/config/serverConfig.ts" ]; then
    echo -e "${GREEN}✓${NC} Web dashboard server configuration found"
else
    echo -e "${RED}✗${NC} Web dashboard server configuration missing"
    exit 1
fi

if [ -f "docs/DEVELOPER_MODE.md" ]; then
    echo -e "${GREEN}✓${NC} Developer mode documentation found"
else
    echo -e "${RED}✗${NC} Developer mode documentation missing"
    exit 1
fi

echo -e "${GREEN}✓${NC} All developer mode files are properly implemented"

wait_for_user

# Step 2: Mobile App Setup
print_step 2 "Mobile App Setup"

echo "For the mobile app, you need to add a route to access the developer mode screen."
echo ""
echo "1. Open your app router file (usually mobile-app/lib/core/router/app_router.dart)"
echo "2. Add this route:"
echo ""
echo -e "${BLUE}GoRoute(${NC}"
echo -e "${BLUE}  path: '/developer-mode',${NC}"
echo -e "${BLUE}  name: 'developer-mode',${NC}"
echo -e "${BLUE}  builder: (context, state) => const DeveloperModeScreen(),${NC}"
echo -e "${BLUE}),${NC}"
echo ""
echo "3. Add a button in your app to navigate to developer mode:"
echo ""
echo -e "${BLUE}context.pushNamed('developer-mode');${NC}"
echo ""
echo "4. Rebuild your Flutter app"

if command_exists flutter; then
    echo ""
    echo "Flutter is installed. You can rebuild your app with:"
    echo -e "${BLUE}cd mobile-app${NC}"
    echo -e "${BLUE}flutter pub get${NC}"
    echo -e "${BLUE}flutter run${NC}"
else
    echo ""
    echo -e "${YELLOW}Flutter not found. Please install Flutter or use your preferred build method.${NC}"
fi

wait_for_user

# Step 3: Web Dashboard Setup
print_step 3 "Web Dashboard Setup"

echo "For the web dashboard, you need to integrate the DeveloperModeSettings component."
echo ""
echo "1. Open merry-net-dashboard/src/App.tsx"
echo "2. Add these imports at the top:"
echo ""
echo -e "${BLUE}import { useState } from 'react';${NC}"
echo -e "${BLUE}import DeveloperModeSettings from './components/DeveloperModeSettings';${NC}"
echo ""
echo "3. Add state for showing the settings:"
echo ""
echo -e "${BLUE}const [showDevSettings, setShowDevSettings] = useState(false);${NC}"
echo ""
echo "4. Add a button to your header or navigation:"
echo ""
echo -e "${BLUE}<button${NC}"
echo -e "${BLUE}  onClick={() => setShowDevSettings(true)}${NC}"
echo -e "${BLUE}  style={{${NC}"
echo -e "${BLUE}    background: '#3b82f6',${NC}"
echo -e "${BLUE}    color: 'white',${NC}"
echo -e "${BLUE}    border: 'none',${NC}"
echo -e "${BLUE}    padding: '8px 16px',${NC}"
echo -e "${BLUE}    borderRadius: '6px',${NC}"
echo -e "${BLUE}    cursor: 'pointer'${NC}"
echo -e "${BLUE}  }}${NC}"
echo -e "${BLUE}>${NC}"
echo -e "${BLUE}  🔧 Dev Mode${NC}"
echo -e "${BLUE}</button>${NC}"
echo ""
echo "5. Add the component at the end of your return statement:"
echo ""
echo -e "${BLUE}<DeveloperModeSettings${NC}"
echo -e "${BLUE}  isOpen={showDevSettings}${NC}"
echo -e "${BLUE}  onClose={() => setShowDevSettings(false)}${NC}"
echo -e "${BLUE}/>}${NC}"
echo ""
echo "6. Rebuild your web dashboard"

if command_exists npm; then
    echo ""
    echo "npm is available. You can rebuild your dashboard with:"
    echo -e "${BLUE}cd merry-net-dashboard${NC}"
    echo -e "${BLUE}npm install${NC}"
    echo -e "${BLUE}npm run dev${NC}"
else
    echo ""
    echo -e "${YELLOW}npm not found. Please use your preferred build method.${NC}"
fi

wait_for_user

# Step 4: Server Configuration
print_step 4 "Server Configuration"

echo "Now you can configure your app to connect to remote servers:"
echo ""
echo "Available server modes:"
echo "  1. Local Development - Connects to localhost:3000"
echo "  2. Main Server (Production) - Connects to https://api.maranet.app"
echo "  3. Main Server (Staging) - Connects to https://staging-api.maranet.app"
echo "  4. Reseller Agent - Connects to custom server"
echo ""
echo "To connect to a remote server:"
echo "1. Enable Developer Mode in your app"
echo "2. Select your desired server mode"
echo "3. For custom reseller servers, enter:"
echo "   - Host: Your server's public IP or domain"
echo "   - API Port: Your server's API port (usually 3000)"
echo "   - Bootstrap Port: Your server's bootstrap port (usually 8080)"
echo "   - Use TLS: Enable if using HTTPS"
echo ""
echo "Example for a remote reseller server:"
echo "  Host: reseller.example.com"
echo "  API Port: 3000"
echo "  Bootstrap Port: 8080"
echo "  Use TLS: true"

wait_for_user

# Step 5: Testing Connection
print_step 5 "Testing Remote Connection"

echo "To test your remote connection:"
echo ""
echo "1. Configure your desired server in developer mode"
echo "2. Click the 'Test Connection' button"
echo "3. Check the results:"
echo "   - Green ✓: Connection successful"
echo "   - Red ✗: Connection failed"
echo ""
echo "If connection fails, check:"
echo "  - Server is running and accessible"
echo "  - Firewall allows connections on specified ports"
echo "  - Correct IP address/domain and port numbers"
echo "  - Internet connectivity on your device"
echo ""
echo "Common issues and solutions:"
echo "  'Connection refused': Server not running or wrong port"
echo "  'Network unreachable': No internet connection"
echo "  'Timeout': Server too slow or firewall blocking"

wait_for_user

# Step 6: Production Considerations
print_step 6 "Production Considerations"

echo "⚠️  Important Security Notes:"
echo ""
echo "1. Developer mode is for development and testing only"
echo "2. Never enable developer mode in production builds"
echo "3. Always use TLS/HTTPS for remote connections"
echo "4. Don't save production credentials in custom endpoints"
echo "5. Reset settings before releasing to production"
echo ""
echo "For production deployment:"
echo "1. Disable developer mode"
echo "2. Use only the main server endpoints"
echo "3. Ensure proper SSL certificates"
echo "4. Configure proper firewall rules"

wait_for_user

# Step 7: Troubleshooting
print_step 7 "Troubleshooting"

echo "If you encounter issues:"
echo ""
echo "Mobile App Issues:"
echo "  - Clear app data and restart"
echo "  - Check Flutter version compatibility"
echo "  - Verify route is properly added"
echo ""
echo "Web Dashboard Issues:"
echo "  - Clear browser cache"
echo "  - Check TypeScript compilation"
echo "  - Verify component integration"
echo ""
echo "Connection Issues:"
echo "  - Test server accessibility with ping/curl"
echo "  - Check server logs for errors"
echo "  - Verify network connectivity"
echo "  - Check firewall settings"
echo ""
echo "For detailed troubleshooting, see docs/DEVELOPER_MODE.md"

wait_for_user

# Step 8: Final Verification
print_step 8 "Final Verification"

echo "Let's verify everything is set up correctly:"
echo ""

# Run the test script
if [ -f "scripts/test_developer_mode.sh" ]; then
    echo "Running implementation verification..."
    bash scripts/test_developer_mode.sh
else
    echo -e "${YELLOW}Test script not found, skipping automated verification${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Developer mode setup complete!${NC}"
echo ""
echo "You can now:"
echo "  ✅ Connect your mobile app to remote servers"
echo "  ✅ Connect your web dashboard to remote servers"
echo "  ✅ Test the entire MerryNet system remotely"
echo "  ✅ Switch between different server environments"
echo ""
echo "Next steps:"
echo "  1. Build and run your mobile app"
echo "  2. Build and run your web dashboard"
echo "  3. Enable developer mode"
echo "  4. Configure your remote server"
echo "  5. Test the connection"
echo ""
echo "For detailed instructions, refer to docs/DEVELOPER_MODE.md"
echo "Happy testing! 🚀"