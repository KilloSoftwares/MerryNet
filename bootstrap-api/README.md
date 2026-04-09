# Maranet Zero — Bootstrap API

Minimal Rust API server for zero-rated access. Provides free connectivity for users to download the Maranet app and purchase internet time.

## Quick Start

### Prerequisites

- Rust 1.76+
- Cargo
- Docker (optional, for containerized deployment)

### Development Setup

1. **Install dependencies**
   ```bash
   cd bootstrap-api
   cargo build
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

3. **Run development server**
   ```bash
   cargo run
   ```

The API will be available at `http://localhost:8080`.

### Production Deployment

1. **Build optimized binary**
   ```bash
   cargo build --release
   ```

2. **Configure environment** (production values)

3. **Run server**
   ```bash
   ./target/release/bootstrap-api
   ```

Or use Docker:
```bash
docker build -t maranet-bootstrap .
docker run -d -p 8080:8080 maranet-bootstrap
```

Or use Docker Compose from the root directory:
```bash
docker-compose up -d bootstrap-api
```

## Available Commands

| Command | Description |
|---------|-------------|
| `cargo build` | Build debug binary |
| `cargo build --release` | Build optimized release binary |
| `cargo run` | Run development server |
| `cargo test` | Run tests |
| `cargo check` | Check code without building |
| `cargo fmt` | Format code |
| `cargo clippy` | Run linter |

## Configuration

All configuration is managed through environment variables. See [`.env.example`](.env.example) for all available options.

### Required Variables

- `HOST` — Server host (default: `0.0.0.0`)
- `PORT` — Server port (default: `8080`)
- `MAIN_SERVER_URL` — URL of the main API server (default: `http://localhost:3000`)

### Optional Variables

- `RUST_LOG` — Log level (default: `info`)
- `REQUEST_TIMEOUT` — Timeout for upstream requests in seconds (default: `30`)

## API Endpoints

### Health Check
```
GET /health
```

Response:
```json
{
  "status": "healthy",
  "service": "maranet-bootstrap",
  "version": "1.0.0"
}
```

### Get Free Session
```
POST /api/v1/bootstrap/session
```

Request:
```json
{
  "device_id": "unique-device-identifier",
  "phone_number": "254712345678"
}
```

Response:
```json
{
  "session_id": "uuid",
  "expires_at": "2024-01-01T12:00:00Z",
  "download_limit_mb": 50
}
```

### Check Session Status
```
GET /api/v1/bootstrap/session/{session_id}
```

Response:
```json
{
  "session_id": "uuid",
  "active": true,
  "data_used_mb": 12.5,
  "data_remaining_mb": 37.5,
  "expires_at": "2024-01-01T12:00:00Z"
}
```

## Architecture

The Bootstrap API is designed to be:

1. **Minimal** — Tiny memory footprint, fast startup
2. **Stateless** — No local state, all data from main server
3. **Fast** — Async I/O with Tokio runtime
4. **Safe** — Memory safety guarantees from Rust

### Request Flow

```
Client → Bootstrap API → Main API Server
                ↓
         (Proxy/Cache)
```

## Performance

- **Memory usage**: < 5MB
- **Startup time**: < 100ms
- **Request latency**: < 10ms (p99)
- **Concurrent connections**: 10,000+

## Monitoring

Prometheus metrics are available at `http://localhost:8080/metrics`.

### Key Metrics

- `bootstrap_requests_total` — Total HTTP requests
- `bootstrap_requests_duration_seconds` — Request duration histogram
- `bootstrap_active_sessions` — Current active bootstrap sessions
- `bootstrap_upstream_errors` — Errors from main server

## Security

- **Rate limiting** — Prevents abuse of free sessions
- **Input validation** — All inputs validated and sanitized
- **HTTPS support** — TLS termination at reverse proxy
- **CORS** — Configurable CORS policy

## Docker

### Build Image
```bash
docker build -t maranet-bootstrap .
```

### Run Container
```bash
docker run -d \
  -p 8080:8080 \
  -e MAIN_SERVER_URL=http://main-server:3000 \
  maranet-bootstrap
```

### Multi-stage Build
The Dockerfile uses a multi-stage build to minimize image size:

1. **Build stage** — Compiles Rust binary
2. **Runtime stage** — Minimal Alpine image with just the binary

Final image size: ~15MB

## Zero-Rated Access

The Bootstrap API enables zero-rated access by:

1. **Whitelisting** — Domain can be whitelisted by mobile operators
2. **Free sessions** — Users get limited free data to download the app
3. **Proxy mode** — Proxies only essential requests to main server
4. **Data limits** — Enforces strict data usage limits

### Supported Domains

- `zero.maranet.app` — Primary zero-rated domain
- `free.facebook.com.maranet.app` — Facebook Free Basics integration

## Troubleshooting

### Build Errors

```bash
# Update Rust toolchain
rustup update

# Clean build cache
cargo clean
cargo build
```

### Connection Issues

```bash
# Test main server connectivity
curl $MAIN_SERVER_URL/api/v1/health

# Check if port is available
netstat -tlnp | grep :8080
```

### Performance Issues

```bash
# Check memory usage
ps aux | grep bootstrap-api

# Monitor request latency
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8080/health
```

## Development

### Project Structure

```
bootstrap-api/
├── src/
│   ├── main.rs          # Application entry point
│   ├── config.rs        # Configuration management
│   ├── routes.rs        # HTTP routes
│   ├── handlers.rs      # Request handlers
│   ├── models.rs        # Data models
│   └── client.rs        # Main server HTTP client
├── Cargo.toml           # Rust dependencies
└── Dockerfile           # Container image
```

### Adding New Endpoints

1. Add route in `src/routes.rs`
2. Add handler in `src/handlers.rs`
3. Add model in `src/models.rs` if needed
4. Test with `cargo test`

## License

Proprietary — Maranet Zero