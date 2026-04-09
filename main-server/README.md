# Maranet Zero — Main API Server

Node.js/TypeScript REST API server with Prisma ORM, PostgreSQL, Redis, and gRPC client.

## Quick Start

### Prerequisites

- Node.js 20+
- PostgreSQL 16+
- Redis 7+
- npm or yarn

### Development Setup

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Generate Prisma client**
   ```bash
   npx prisma generate
   ```

3. **Configure environment**
   ```bash
   cp ../.env.example .env
   # Edit .env with your values
   ```

4. **Run database migrations**
   ```bash
   npx prisma migrate deploy
   ```

5. **Seed the database (optional)**
   ```bash
   npx prisma db seed
   ```

6. **Start development server**
   ```bash
   npm run dev
   ```

The API will be available at `http://localhost:3000`.

### Production Deployment

1. **Build**
   ```bash
   npm run build
   ```

2. **Set environment variables** (production values)

3. **Run migrations**
   ```bash
   npx prisma migrate deploy
   ```

4. **Start server**
   ```bash
   node dist/index.js
   ```

Or use PM2:
```bash
pm2 start dist/index.js --name maranet-api
```

### Docker Deployment

```bash
# Build image
docker build -t maranet-api .

# Run container
docker run -d \
  -p 3000:3000 \
  --env-file .env \
  maranet-api
```

Or use Docker Compose from the root directory:
```bash
docker-compose up -d main-server
```

## Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build for production |
| `npm start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm test` | Run tests |
| `npm run test:coverage` | Run tests with coverage |
| `npx prisma generate` | Generate Prisma client |
| `npx prisma migrate deploy` | Run database migrations |
| `npx prisma studio` | Open Prisma Studio database GUI |

## API Documentation

- **Health Check**: `GET /api/v1/health`
- **API Docs**: `GET /api/v1/`
- **Full API Documentation**: See [docs/API.md](../docs/API.md)

### Key Endpoints

- `POST /api/v1/auth/register` — User registration
- `POST /api/v1/auth/login` — User login
- `POST /api/v1/auth/refresh` — Refresh JWT token
- `GET /api/v1/users/me` — Get current user
- `POST /api/v1/payments/mpesa/initiate` — Initiate M-Pesa payment
- `POST /api/v1/payments/mpesa/callback` — M-Pesa callback (Safaricom)
- `GET /api/v1/sessions` — List user sessions
- `POST /api/v1/sessions` — Create new session (purchase internet time)

## Configuration

All configuration is managed through environment variables. See [`.env.example`](../.env.example) for all available options.

### Required Variables

- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis connection URL
- `JWT_SECRET` — Secret for JWT signing (64+ characters)
- `NODE_ENV` — Environment (development/production)

### Optional Variables

- `PORT` — Server port (default: 3000)
- `LOG_LEVEL` — Logging level (default: info)
- `MPESA_*` — M-Pesa payment configuration

## Database

The application uses PostgreSQL with Prisma ORM. The schema is defined in `prisma/schema.prisma`.

### Key Models

- **User** — User accounts with authentication
- **Session** — VPN session records
- **Payment** — Payment transaction records
- **ResellerNode** — Reseller agent nodes
- **Plan** — Internet time plans (hourly, daily, weekly, monthly)

## Monitoring

- **Metrics**: `GET /metrics` (Prometheus format)
- **Health**: `GET /api/v1/health`
- **Readiness**: `GET /api/v1/health/ready`

## Troubleshooting

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql $DATABASE_URL -c "SELECT 1"

# Run migrations again
npx prisma migrate deploy
```

### Redis Connection Issues

```bash
# Test Redis connection
redis-cli -u $REDIS_URL ping
```

### Regenerate Prisma Client

If you get Prisma client errors:
```bash
npx prisma generate
```

## License

Proprietary — Maranet Zero