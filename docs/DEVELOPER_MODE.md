# Developer Mode Guide

Developer mode is a feature that allows you to connect the MerryNet apps (mobile and web dashboard) to different server endpoints for testing and development purposes. This is useful for testing the entire system remotely, including connections to the main server or reseller agents.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Mobile App Setup](#mobile-app-setup)
- [Web Dashboard Setup](#web-dashboard-setup)
- [Server Modes](#server-modes)
- [Custom Endpoint Configuration](#custom-endpoint-configuration)
- [Testing Connections](#testing-connections)
- [Troubleshooting](#troubleshooting)

## Overview

Developer mode provides:

- **Server Switching**: Easily switch between local development, production main server, staging, and custom reseller endpoints
- **Connection Testing**: Test connectivity to verify server availability
- **Custom Endpoints**: Configure any server address for testing
- **Persistent Settings**: Settings are saved and restored automatically

## Features

### Mobile App (Flutter)
- Toggle developer mode on/off
- Select server mode (Local, Main Server, Reseller, Auto)
- Configure custom endpoints with full control over host, ports, and TLS
- Test connection with latency measurement
- Reset to default settings

### Web Dashboard (React/TypeScript)
- All mobile app features
- Modal-based settings UI
- Real-time endpoint information display
- Connection test with detailed results

## Mobile App Setup

### Enabling Developer Mode

1. Open the MerryNet mobile app
2. Navigate to Settings (if available) or access the developer mode screen directly
3. Toggle "Developer Mode" to enable it

### Accessing Developer Mode Screen

The developer mode screen can be accessed by:
- Adding a route to your app router
- Or navigating directly to the settings page

### Adding the Route

In your app router configuration (`mobile-app/lib/core/router/app_router.dart`):

```dart
GoRoute(
  path: '/developer-mode',
  name: 'developer-mode',
  builder: (context, state) => const DeveloperModeScreen(),
),
```

Then navigate using:
```dart
context.pushNamed('developer-mode');
```

## Web Dashboard Setup

### Adding Developer Mode to App.tsx

Update `merry-net-dashboard/src/App.tsx`:

```tsx
import { useState } from 'react';
import Chatbot from './components/Chatbot';
import DeveloperModeSettings from './components/DeveloperModeSettings';
import './App.css';

function App() {
  const [showDevSettings, setShowDevSettings] = useState(false);

  return (
    <div className="app">
      <header className="app-header">
        <h1>🌐 MerryNet Dashboard</h1>
        <p>Intelligent Network Management Platform</p>
        <button 
          onClick={() => setShowDevSettings(true)}
          style={{ 
            background: '#3b82f6', 
            color: 'white', 
            border: 'none', 
            padding: '8px 16px', 
            borderRadius: '6px',
            cursor: 'pointer'
          }}
        >
          🔧 Dev Mode
        </button>
      </header>
      <main className="app-main">
        <Chatbot />
      </main>
      <footer className="app-footer">
        <p>Powered by animal-inspired AI algorithms • © 2026 MerryNet</p>
      </footer>
      
      <DeveloperModeSettings 
        isOpen={showDevSettings}
        onClose={() => setShowDevSettings(false)}
      />
    </div>
  );
}

export default App;
```

## Server Modes

### Local Development
- **API URL**: `http://localhost:3000/api/v1`
- **Bootstrap URL**: `http://localhost:8080`
- **gRPC**: `localhost:50051`
- Use this when running the main-server locally

### Main Server (Production)
- **API URL**: `https://api.maranet.app/api/v1`
- **Bootstrap URL**: `https://free.facebook.com.maranet.app`
- **gRPC**: `api.maranet.app:50051`
- Use this for production testing

### Main Server (Staging)
- **API URL**: `https://staging-api.maranet.app/api/v1`
- **Bootstrap URL**: `https://staging.maranet.app`
- **gRPC**: `staging-api.maranet.app:50051`
- Use this for staging environment testing

### Reseller Agent
- Connect to a custom reseller server
- Configure host, ports, and TLS settings manually
- Use this for testing reseller deployments

### Auto Detect
- Automatically detects available servers on the network
- Currently defaults to local development

## Custom Endpoint Configuration

When using "Reseller Agent" mode, you can configure a custom endpoint:

1. **Host**: IP address or domain name of the server
   - Example: `192.168.1.100` or `reseller.example.com`

2. **API Port**: Port for the main API server
   - Default: `3000`

3. **Bootstrap Port**: Port for the bootstrap service
   - Default: `8080`

4. **API Path**: Path to the API endpoints
   - Default: `/api/v1`

5. **Use TLS/HTTPS**: Enable secure connections
   - Check this if your server uses HTTPS

### Example Configuration

For a reseller server at `192.168.1.100`:
- Host: `192.168.1.100`
- API Port: `3000`
- Bootstrap Port: `8080`
- API Path: `/api/v1`
- Use TLS: `false` (for local network)

## Testing Connections

Use the "Test Connection" button to verify server connectivity:

1. Select your desired server mode or configure a custom endpoint
2. Click "Test Connection"
3. Wait for the result

### Test Results

- **Success**: Server is reachable and responding
  - Shows latency in milliseconds
  - Green indicator

- **Failure**: Server is not reachable or not responding
  - Shows error message
  - Red indicator
  - Common errors:
    - `Connection refused`: Server is not running or wrong port
    - `Network unreachable`: No network connection
    - `Timeout`: Server is too slow or firewall blocking

## Troubleshooting

### Connection Refused

If you get "Connection refused":
1. Verify the server is running
2. Check the port number is correct
3. Ensure the server is listening on the correct interface (0.0.0.0 for remote access)

### CORS Errors (Web Dashboard)

If you get CORS errors when connecting to a remote server:
1. Ensure the server has CORS headers configured
2. Add your dashboard domain to the server's CORS allowlist
3. For development, you can use a browser extension to disable CORS

### Authentication Failures

If you get 401 errors after switching servers:
1. Clear app data/storage
2. Log in again with your credentials
3. Ensure the server has your user account

### TLS/SSL Errors

If you get SSL errors:
1. Verify the server has a valid certificate
2. For self-signed certificates, you may need to trust the certificate
3. Consider using HTTP for local network testing

### Network Discovery

For auto-detection to work:
1. Ensure devices are on the same network
2. Server must advertise its presence (mDNS/Bonjour)
3. Firewall must allow discovery packets

## Environment Variables

### Mobile App

The mobile app uses `shared_preferences` to store settings locally:
- `developer_mode_enabled`: Boolean flag
- `server_mode`: Current server mode
- `custom_endpoint`: JSON-encoded custom endpoint

### Web Dashboard

The web dashboard uses `localStorage`:
- `maranet_dev_mode_enabled`: Boolean flag
- `maranet_server_mode`: Current server mode
- `maranet_custom_endpoint`: JSON-encoded custom endpoint

## Security Considerations

⚠️ **Important**: Developer mode is intended for development and testing only.

- Never enable developer mode in production builds
- Do not save production credentials in custom endpoints
- Always use TLS/HTTPS for remote connections
- Reset settings before releasing to production

## API Reference

### ServerConfig (TypeScript)

```typescript
import { serverConfig } from './config/serverConfig';

// Get current endpoint
const endpoint = serverConfig.getCurrentEndpoint();

// Set server mode
serverConfig.setServerMode('reseller');

// Set custom endpoint
serverConfig.setCustomEndpoint({
  name: 'My Server',
  apiBaseUrl: 'http://192.168.1.100:3000/api/v1',
  bootstrapUrl: 'http://192.168.1.100:8080',
  useTls: false,
});

// Test connection
const result = await serverConfig.testConnection();
console.log(result.success, result.latency);

// Toggle developer mode
serverConfig.toggleDeveloperMode();

// Reset to defaults
serverConfig.resetToDefaults();
```

### ServerConfig (Dart/Flutter)

```dart
import 'package:your_app/core/config/server_config.dart';

final config = ServerConfig();

// Initialize
await config.initialize();

// Get current endpoint
final endpoint = config.currentEndpoint;

// Set server mode
await config.setServerMode(ServerMode.reseller);

// Set custom endpoint
await config.setCustomEndpoint(ServerEndpoint(
  name: 'My Server',
  apiBaseUrl: 'http://192.168.1.100:3000/api/v1',
  bootstrapUrl: 'http://192.168.1.100:8080',
  useTls: false,
));

// Test connection
final result = await config.testConnection();
print(result.success);

// Toggle developer mode
await config.toggleDeveloperMode();

// Reset to defaults
await config.resetToDefaults();