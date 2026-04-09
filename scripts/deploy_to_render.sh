#!/bin/bash

# MerryNet Render Deployment Script
# This script helps deploy MerryNet to Render.com

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

print_header "MerryNet Render Deployment Guide"

echo "This script will guide you through deploying MerryNet to Render.com"
echo ""
echo "Prerequisites:"
echo "  1. Render.com account"
echo "  2. Render CLI installed (https://render.com/docs/cli)"
echo "  3. Git repository connected to Render"
echo "  4. PostgreSQL database on Render"

if ! command_exists render; then
    echo ""
    echo -e "${RED}Error: Render CLI not found${NC}"
    echo "Please install the Render CLI from: https://render.com/docs/cli"
    echo "Then run: render login"
    exit 1
fi

echo ""
echo -e "${YELLOW}Checking Render CLI login status...${NC}"
if ! render status >/dev/null 2>&1; then
    echo "Please run 'render login' to authenticate with Render.com"
    exit 1
fi

echo -e "${GREEN}✓${NC} Render CLI is authenticated"

print_step 1 "Prepare Environment Files"

echo "Creating production environment files..."

# Create production environment files
if [ ! -f "main-server/.env.production" ]; then
    echo "Creating main-server/.env.production..."
    cat > main-server/.env.production << EOF
# Production Environment
NODE_ENV=production
PORT=10000

# Database (will be replaced by Render)
DATABASE_URL="postgresql://username:password@hostname:5432/database"

# Redis (will be replaced by Render)
REDIS_URL="redis://hostname:6379"

# JWT Secret (generate a new one for production)
JWT_SECRET="your-production-jwt-secret-here"

# CORS (allow your frontend domains)
CORS_ORIGIN="https://your-frontend-domain.onrender.com"

# Frontend URL
FRONTEND_URL="https://your-frontend-domain.onrender.com"

# API URL
API_URL="https://your-api-domain.onrender.com"

# Bootstrap URL
BOOTSTRAP_URL="https://your-bootstrap-domain.onrender.com"

# gRPC Configuration
GRPC_HOST="0.0.0.0"
GRPC_PORT=50051

# Logging
LOG_LEVEL=info

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
EOF
    echo -e "${GREEN}✓${NC} Created main-server/.env.production"
else
    echo -e "${YELLOW}⚠${NC} main-server/.env.production already exists"
fi

print_step 2 "Update Render Configuration"

echo "Updating Render deployment configuration..."

# Update main-server render.yaml
cat > main-server/render.yaml << 'EOF'
services:
  - type: web
    name: maranet-api
    env: node
    plan: free
    region: oregon
    buildCommand: npm install && npm run build
    startCommand: npm start
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: DATABASE_URL
        fromDatabase:
          name: maranet-db
          property: connectionString
      - key: REDIS_URL
        fromDatabase:
          name: maranet-redis
          property: connectionString
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGIN
        value: "https://your-frontend-domain.onrender.com"
      - key: FRONTEND_URL
        value: "https://your-frontend-domain.onrender.com"
      - key: API_URL
        value: "https://maranet-api.onrender.com"
      - key: BOOTSTRAP_URL
        value: "https://maranet-bootstrap.onrender.com"
      - key: GRPC_HOST
        value: "0.0.0.0"
      - key: GRPC_PORT
        value: "50051"
      - key: LOG_LEVEL
        value: "info"
      - key: RATE_LIMIT_WINDOW_MS
        value: "900000"
      - key: RATE_LIMIT_MAX_REQUESTS
        value: "100"
EOF
    echo -e "${GREEN}✓${NC} Updated main-server/render.yaml"
else
    echo -e "${YELLOW}⚠${NC} main-server/render.yaml already exists"
fi

print_step 3 "Update Web Dashboard Render Configuration"

echo "Updating web dashboard deployment configuration..."

# Update merry-net-dashboard render.yaml
cat > merry-net-dashboard/render.yaml << 'EOF'
services:
  - type: web
    name: maranet-dashboard
    env: static
    plan: free
    region: oregon
    buildCommand: npm install && npm run build
    publishPath: ./dist
    envVars:
      - key: VITE_API_URL
        value: "https://maranet-api.onrender.com/api/v1"
      - key: VITE_BOOTSTRAP_URL
        value: "https://maranet-bootstrap.onrender.com"
      - key: VITE_GRPC_URL
        value: "maranet-api.onrender.com:50051"
      - key: VITE_APP_ENV
        value: "production"
EOF
    echo -e "${GREEN}✓${NC} Updated merry-net-dashboard/render.yaml"
else
    echo -e "${YELLOW}⚠${NC} merry-net-dashboard/render.yaml already exists"
fi

print_step 4 "Update Bootstrap API Render Configuration"

echo "Updating bootstrap API deployment configuration..."

# Update bootstrap-api render.yaml
cat > bootstrap-api/render.yaml << 'EOF'
services:
  - type: web
    name: maranet-bootstrap
    env: rust
    plan: free
    region: oregon
    buildCommand: cargo build --release
    startCommand: ./target/release/bootstrap-api
    envVars:
      - key: PORT
        value: "10000"
      - key: DATABASE_URL
        fromDatabase:
          name: maranet-db
          property: connectionString
      - key: REDIS_URL
        fromDatabase:
          name: maranet-redis
          property: connectionString
      - key: API_URL
        value: "https://maranet-api.onrender.com"
      - key: LOG_LEVEL
        value: "info"
EOF
    echo -e "${GREEN}✓${NC} Updated bootstrap-api/render.yaml"
else
    echo -e "${YELLOW}⚠${NC} bootstrap-api/render.yaml already exists"
fi

print_step 5 "Update Developer Mode Preset Servers"

echo "Updating developer mode preset servers for Render deployment..."

# Update mobile app server config
cat > mobile-app/lib/core/config/server_config.dart << 'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static final ServerConfig _instance = ServerConfig._internal();
  static const String _prefsKey = 'server_config';
  static const String _developerModeKey = 'developer_mode_enabled';

  late SharedPreferences _prefs;
  bool _developerModeEnabled = false;
  ServerMode _currentMode = ServerMode.local;
  ServerEndpoint? _customEndpoint;

  factory ServerConfig() {
    return _instance;
  }

  ServerConfig._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _developerModeEnabled = _prefs.getBool(_developerModeKey) ?? false;
    
    final savedConfig = _prefs.getString(_prefsKey);
    if (savedConfig != null) {
      final json = jsonDecode(savedConfig);
      _currentMode = ServerMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => ServerMode.local,
      );
      if (json['customEndpoint'] != null) {
        _customEndpoint = ServerEndpoint.fromJson(json['customEndpoint']);
      }
    }
  }

  bool get developerModeEnabled => _developerModeEnabled;
  ServerMode get currentMode => _currentMode;
  ServerEndpoint get currentEndpoint => _getEndpointForMode(_currentMode);

  void setDeveloperModeEnabled(bool enabled) {
    _developerModeEnabled = enabled;
    _prefs.setBool(_developerModeKey, enabled);
  }

  Future<void> setServerMode(ServerMode mode) async {
    _currentMode = mode;
    await _saveConfig();
  }

  Future<void> setCustomEndpoint(ServerEndpoint endpoint) async {
    _customEndpoint = endpoint;
    await _saveConfig();
  }

  Future<void> toggleDeveloperMode() async {
    _developerModeEnabled = !_developerModeEnabled;
    await _prefs.setBool(_developerModeKey, _developerModeEnabled);
  }

  Future<void> resetToDefaults() async {
    _currentMode = ServerMode.local;
    _customEndpoint = null;
    await _saveConfig();
  }

  ServerEndpoint _getEndpointForMode(ServerMode mode) {
    switch (mode) {
      case ServerMode.local:
        return PresetServers.local;
      case ServerMode.mainServer:
        return PresetServers.mainServer;
      case ServerMode.staging:
        return PresetServers.staging;
      case ServerMode.reseller:
        return _customEndpoint ?? PresetServers.local;
      case ServerMode.auto:
        return PresetServers.auto;
    }
  }

  Future<void> _saveConfig() async {
    final json = {
      'mode': _currentMode.name,
      'customEndpoint': _customEndpoint?.toJson(),
    };
    await _prefs.setString(_prefsKey, jsonEncode(json));
  }

  Future<ConnectionTestResult> testConnection() async {
    final endpoint = currentEndpoint;
    final stopwatch = Stopwatch()..start();
    
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse('${endpoint.apiBaseUrl}/health'));
      final response = await request.close();
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        return ConnectionTestResult(
          success: true,
          latency: stopwatch.elapsedMilliseconds,
          message: 'Connection successful',
        );
      } else {
        return ConnectionTestResult(
          success: false,
          latency: stopwatch.elapsedMilliseconds,
          message: 'Server responded with status ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        latency: stopwatch.elapsedMilliseconds,
        message: e.toString(),
      );
    }
  }
}

enum ServerMode {
  local,
  mainServer,
  staging,
  reseller,
  auto,
}

class ServerEndpoint {
  final String name;
  final String apiBaseUrl;
  final String bootstrapUrl;
  final String? grpcHost;
  final int? grpcPort;
  final bool useTls;
  final String description;

  ServerEndpoint({
    required this.name,
    required this.apiBaseUrl,
    required this.bootstrapUrl,
    this.grpcHost,
    this.grpcPort,
    required this.useTls,
    required this.description,
  });

  factory ServerEndpoint.fromJson(Map<String, dynamic> json) {
    return ServerEndpoint(
      name: json['name'],
      apiBaseUrl: json['apiBaseUrl'],
      bootstrapUrl: json['bootstrapUrl'],
      grpcHost: json['grpcHost'],
      grpcPort: json['grpcPort'],
      useTls: json['useTls'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'apiBaseUrl': apiBaseUrl,
      'bootstrapUrl': bootstrapUrl,
      'grpcHost': grpcHost,
      'grpcPort': grpcPort,
      'useTls': useTls,
      'description': description,
    };
  }
}

class PresetServers {
  static ServerEndpoint get local => ServerEndpoint(
        name: 'Local Development',
        apiBaseUrl: 'http://localhost:3000/api/v1',
        bootstrapUrl: 'http://localhost:8080',
        grpcHost: 'localhost',
        grpcPort: 50051,
        useTls: false,
        description: 'Local development server',
      );

  static ServerEndpoint get mainServer => ServerEndpoint(
        name: 'Main Server (Production)',
        apiBaseUrl: 'https://maranet-api.onrender.com/api/v1',
        bootstrapUrl: 'https://maranet-bootstrap.onrender.com',
        grpcHost: 'maranet-api.onrender.com',
        grpcPort: 50051,
        useTls: true,
        description: 'Production main server',
      );

  static ServerEndpoint get staging => ServerEndpoint(
        name: 'Main Server (Staging)',
        apiBaseUrl: 'https://staging-maranet-api.onrender.com/api/v1',
        bootstrapUrl: 'https://staging-maranet-bootstrap.onrender.com',
        grpcHost: 'staging-maranet-api.onrender.com',
        grpcPort: 50051,
        useTls: true,
        description: 'Staging environment',
      );

  static ServerEndpoint get auto => ServerEndpoint(
        name: 'Auto Detect',
        apiBaseUrl: 'http://localhost:3000/api/v1',
        bootstrapUrl: 'http://localhost:8080',
        grpcHost: 'localhost',
        grpcPort: 50051,
        useTls: false,
        description: 'Automatically detect available servers',
      );
}

class ConnectionTestResult {
  final bool success;
  final int latency;
  final String message;

  ConnectionTestResult({
    required this.success,
    required this.latency,
    required this.message,
  });
}
EOF
    echo -e "${GREEN}✓${NC} Updated mobile-app/lib/core/config/server_config.dart"
else
    echo -e "${YELLOW}⚠${NC} mobile-app/lib/core/config/server_config.dart already exists"
fi

# Update web dashboard server config
cat > merry-net-dashboard/src/config/serverConfig.ts << 'EOF'
import { ServerEndpoint, ServerMode } from './types';

class ServerConfigManager {
  private static instance: ServerConfigManager;
  private currentMode: ServerMode = ServerMode.local;
  private customEndpoint: ServerEndpoint | null = null;
  private developerModeEnabled: boolean = false;

  private constructor() {
    this.loadConfig();
  }

  static getInstance(): ServerConfigManager {
    if (!ServerConfigManager.instance) {
      ServerConfigManager.instance = new ServerConfigManager();
    }
    return ServerConfigManager.instance;
  }

  private loadConfig() {
    try {
      const savedMode = localStorage.getItem('maranet_server_mode');
      const savedCustom = localStorage.getItem('maranet_custom_endpoint');
      const savedDevMode = localStorage.getItem('maranet_dev_mode_enabled');

      if (savedMode) {
        this.currentMode = savedMode as ServerMode;
      }
      if (savedCustom) {
        this.customEndpoint = JSON.parse(savedCustom);
      }
      if (savedDevMode) {
        this.developerModeEnabled = JSON.parse(savedDevMode);
      }
    } catch (error) {
      console.warn('Failed to load server config:', error);
    }
  }

  private saveConfig() {
    localStorage.setItem('maranet_server_mode', this.currentMode);
    if (this.customEndpoint) {
      localStorage.setItem('maranet_custom_endpoint', JSON.stringify(this.customEndpoint));
    }
    localStorage.setItem('maranet_dev_mode_enabled', JSON.stringify(this.developerModeEnabled));
  }

  getCurrentEndpoint(): ServerEndpoint {
    switch (this.currentMode) {
      case ServerMode.local:
        return PresetServers.local;
      case ServerMode.mainServer:
        return PresetServers.mainServer;
      case ServerMode.staging:
        return PresetServers.staging;
      case ServerMode.reseller:
        return this.customEndpoint || PresetServers.local;
      case ServerMode.auto:
        return PresetServers.auto;
    }
  }

  setServerMode(mode: ServerMode) {
    this.currentMode = mode;
    this.saveConfig();
  }

  setCustomEndpoint(endpoint: ServerEndpoint) {
    this.customEndpoint = endpoint;
    this.saveConfig();
  }

  toggleDeveloperMode() {
    this.developerModeEnabled = !this.developerModeEnabled;
    this.saveConfig();
  }

  resetToDefaults() {
    this.currentMode = ServerMode.local;
    this.customEndpoint = null;
    this.saveConfig();
  }

  async testConnection(): Promise<ConnectionTestResult> {
    const endpoint = this.getCurrentEndpoint();
    const startTime = Date.now();

    try {
      const response = await fetch(`${endpoint.apiBaseUrl}/health`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const latency = Date.now() - startTime;

      if (response.ok) {
        return {
          success: true,
          latency,
          message: 'Connection successful',
        };
      } else {
        return {
          success: false,
          latency,
          message: `Server responded with status ${response.status}`,
        };
      }
    } catch (error) {
      const latency = Date.now() - startTime;
      return {
        success: false,
        latency,
        message: error instanceof Error ? error.message : 'Connection failed',
      };
    }
  }
}

export const serverConfig = ServerConfigManager.getInstance();

export const PresetServers = {
  local: {
    name: 'Local Development',
    apiBaseUrl: 'http://localhost:3000/api/v1',
    bootstrapUrl: 'http://localhost:8080',
    grpcHost: 'localhost',
    grpcPort: 50051,
    useTls: false,
    description: 'Local development server',
  },
  mainServer: {
    name: 'Main Server (Production)',
    apiBaseUrl: 'https://maranet-api.onrender.com/api/v1',
    bootstrapUrl: 'https://maranet-bootstrap.onrender.com',
    grpcHost: 'maranet-api.onrender.com',
    grpcPort: 50051,
    useTls: true,
    description: 'Production main server',
  },
  staging: {
    name: 'Main Server (Staging)',
    apiBaseUrl: 'https://staging-maranet-api.onrender.com/api/v1',
    bootstrapUrl: 'https://staging-maranet-bootstrap.onrender.com',
    grpcHost: 'staging-maranet-api.onrender.com',
    grpcPort: 50051,
    useTls: true,
    description: 'Staging environment',
  },
  auto: {
    name: 'Auto Detect',
    apiBaseUrl: 'http://localhost:3000/api/v1',
    bootstrapUrl: 'http://localhost:8080',
    grpcHost: 'localhost',
    grpcPort: 50051,
    useTls: false,
    description: 'Automatically detect available servers',
  },
};

export type ServerMode = 'local' | 'mainServer' | 'staging' | 'reseller' | 'auto';

export interface ServerEndpoint {
  name: string;
  apiBaseUrl: string;
  bootstrapUrl: string;
  grpcHost?: string;
  grpcPort?: number;
  useTls: boolean;
  description: string;
}

export interface ConnectionTestResult {
  success: boolean;
  latency: number;
  message: string;
}
EOF
    echo -e "${GREEN}✓${NC} Updated merry-net-dashboard/src/config/serverConfig.ts"
else
    echo -e "${YELLOW}⚠${NC} merry-net-dashboard/src/config/serverConfig.ts already exists"
fi

print_step 6 "Create Render Deployment Guide"

echo "Creating Render deployment guide..."

cat > docs/RENDER_DEPLOYMENT.md << 'EOF'
# MerryNet Render Deployment Guide

This guide covers deploying MerryNet to Render.com for production use.

## Prerequisites

1. **Render.com Account**: Sign up at [render.com](https://render.com)
2. **Git Repository**: Your MerryNet code should be in a Git repository
3. **Render CLI**: Install from [Render CLI Docs](https://render.com/docs/cli)
4. **Domain Names**: Optional, but recommended for production

## Deployment Steps

### 1. Connect Your Repository

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click "New Web Service"
3. Connect your Git repository
4. Select the repository containing your MerryNet code

### 2. Deploy Main Server API

**Service Configuration:**
- **Name**: `maranet-api`
- **Environment**: Node.js
- **Region**: Oregon (or your preferred region)
- **Branch**: main/master

**Build Settings:**
- **Build Command**: `npm install && npm run build`
- **Start Command**: `npm start`

**Environment Variables:**
- `NODE_ENV=production`
- `PORT=10000`
- `JWT_SECRET` (generate a secure secret)
- `CORS_ORIGIN=https://your-frontend-domain.onrender.com`
- `FRONTEND_URL=https://your-frontend-domain.onrender.com`
- `API_URL=https://maranet-api.onrender.com`
- `BOOTSTRAP_URL=https://maranet-bootstrap.onrender.com`
- `GRPC_HOST=0.0.0.0`
- `GRPC_PORT=50051`
- `LOG_LEVEL=info`
- `RATE_LIMIT_WINDOW_MS=900000`
- `RATE_LIMIT_MAX_REQUESTS=100`

**Database Integration:**
- Add PostgreSQL database: `maranet-db`
- Add Redis database: `maranet-redis`
- Link database connection strings to the service

### 3. Deploy Web Dashboard

**Service Configuration:**
- **Name**: `maranet-dashboard`
- **Environment**: Static Site
- **Region**: Oregon

**Build Settings:**
- **Build Command**: `npm install && npm run build`
- **Publish Directory**: `dist`

**Environment Variables:**
- `VITE_API_URL=https://maranet-api.onrender.com/api/v1`
- `VITE_BOOTSTRAP_URL=https://maranet-bootstrap.onrender.com`
- `VITE_GRPC_URL=maranet-api.onrender.com:50051`
- `VITE_APP_ENV=production`

### 4. Deploy Bootstrap API

**Service Configuration:**
- **Name**: `maranet-bootstrap`
- **Environment**: Rust
- **Region**: Oregon

**Build Settings:**
- **Build Command**: `cargo build --release`
- **Start Command**: `./target/release/bootstrap-api`

**Environment Variables:**
- `PORT=10000`
- `API_URL=https://maranet-api.onrender.com`
- `LOG_LEVEL=info`

### 5. Configure Databases

**PostgreSQL Database:**
- **Name**: `maranet-db`
- **Plan**: Free (for testing) or Standard (for production)
- **Region**: Oregon

**Redis Database:**
- **Name**: `maranet-redis`
- **Plan**: Free (for testing) or Standard (for production)
- **Region**: Oregon

### 6. Update Domain Names

1. Go to your Render dashboard
2. Navigate to each service
3. Click "Add Custom Domain"
4. Add your custom domains (optional)

## Post-Deployment Configuration

### 1. Update Developer Mode URLs

After deployment, update the preset server URLs in your apps:

**Mobile App:**
```dart
// Update these URLs in mobile-app/lib/core/config/server_config.dart
static ServerEndpoint get mainServer => ServerEndpoint(
  apiBaseUrl: 'https://your-api-domain.onrender.com/api/v1',
  bootstrapUrl: 'https://your-bootstrap-domain.onrender.com',
  // ...
);
```

**Web Dashboard:**
```typescript
// Update these URLs in merry-net-dashboard/src/config/serverConfig.ts
export const PresetServers = {
  mainServer: {
    apiBaseUrl: 'https://your-api-domain.onrender.com/api/v1',
    bootstrapUrl: 'https://your-bootstrap-domain.onrender.com',
    // ...
  },
  // ...
};
```

### 2. Configure CORS

Ensure your API allows requests from your frontend domain:

```env
CORS_ORIGIN=https://your-frontend-domain.onrender.com
```

### 3. Set Up SSL/TLS

Render automatically provides SSL certificates for `.onrender.com` domains.
For custom domains, follow Render's SSL setup guide.

## Testing Your Deployment

1. **API Health Check**: Visit `https://maranet-api.onrender.com/health`
2. **Bootstrap Health Check**: Visit `https://maranet-bootstrap.onrender.com/health`
3. **Frontend**: Visit your dashboard URL
4. **Developer Mode**: Test switching between servers in your apps

## Monitoring and Maintenance

### Health Checks

Set up health checks in Render:
- **API**: `/health`
- **Bootstrap**: `/health`

### Logs

Monitor logs through Render dashboard:
1. Go to your service
2. Click "Logs" tab
3. View real-time logs

### Backups

Set up automated backups for your PostgreSQL database in the Render dashboard.

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check database connection strings
   - Verify database is running
   - Check firewall settings

2. **CORS Errors**
   - Verify `CORS_ORIGIN` environment variable
   - Check frontend domain matches allowed origins

3. **SSL/TLS Issues**
   - Ensure HTTPS is enabled
   - Check certificate status in Render dashboard

4. **Performance Issues**
   - Monitor resource usage
   - Consider upgrading plan for production
   - Enable caching where appropriate

### Getting Help

- [Render Documentation](https://render.com/docs)
- [Render Community](https://community.render.com)
- Check service logs in Render dashboard

## Cost Considerations

### Free Tier Limitations
- Limited build minutes
- Sleep after 15 minutes of inactivity
- Limited database size

### Production Recommendations
- Upgrade to paid plans for 24/7 uptime
- Use Standard databases for production
- Consider reserved instances for predictable costs

## Security Best Practices

1. **Environment Variables**: Never commit secrets to git
2. **HTTPS**: Always use HTTPS in production
3. **JWT Secrets**: Use strong, unique secrets
4. **Rate Limiting**: Configure appropriate limits
5. **Database Security**: Use strong passwords and limited access
EOF
    echo -e "${GREEN}✓${NC} Created docs/RENDER_DEPLOYMENT.md"
else
    echo -e "${YELLOW}⚠${NC} docs/RENDER_DEPLOYMENT.md already exists"
fi

print_step 7 "Final Verification"

echo "Running final verification..."

# Check if all required files exist
echo "Checking deployment files:"
[ -f "main-server/render.yaml" ] && echo -e "${GREEN}✓${NC} main-server/render.yaml" || echo -e "${RED}✗${NC} main-server/render.yaml"
[ -f "merry-net-dashboard/render.yaml" ] && echo -e "${GREEN}✓${NC} merry-net-dashboard/render.yaml" || echo -e "${RED}✗${NC} merry-net-dashboard/render.yaml"
[ -f "bootstrap-api/render.yaml" ] && echo -e "${GREEN}✓${NC} bootstrap-api/render.yaml" || echo -e "${RED}✗${NC} bootstrap-api/render.yaml"
[ -f "docs/RENDER_DEPLOYMENT.md" ] && echo -e "${GREEN}✓${NC} docs/RENDER_DEPLOYMENT.md" || echo -e "${RED}✗${NC} docs/RENDER_DEPLOYMENT.md"

echo ""
echo -e "${GREEN}🎉 Render deployment setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Push your code to GitHub/GitLab"
echo "2. Go to https://dashboard.render.com"
echo "3. Create new web services using the render.yaml files"
echo "4. Configure databases (PostgreSQL and Redis)"
echo "5. Update domain names if using custom domains"
echo "6. Test your deployment"
echo ""
echo "For detailed instructions, see docs/RENDER_DEPLOYMENT.md"
echo "Happy deploying! 🚀"
