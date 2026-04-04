FROM node:20-bookworm-slim AS base
WORKDIR /app

# Install dependencies
COPY main-server/package.json main-server/package-lock.json* ./
RUN npm ci --only=production && npm cache clean --force

# Build stage
FROM base AS build
RUN npm ci
COPY main-server/tsconfig.json ./
COPY main-server/prisma ./prisma
COPY main-server/src ./src
RUN npx prisma generate
RUN npm run build

# Production stage
FROM node:20-bookworm-slim AS production
WORKDIR /app

ENV NODE_ENV=production

# Copy production node_modules
COPY --from=base /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY main-server/package.json ./
COPY main-server/prisma ./prisma
COPY proto ./proto
COPY proto /proto

# Create logs directory and non-root user
RUN mkdir -p logs && \
    useradd -r -u 1001 maranet && \
    chown -R maranet:maranet /app

USER maranet

EXPOSE 3000 50051 9090

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/health || exit 1

CMD ["node", "dist/index.js"]