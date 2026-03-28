FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git gcc musl-dev linux-headers

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /gateway ./cmd/gateway

FROM alpine:3.19

RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    ip6tables \
    iproute2 \
    ca-certificates

COPY --from=builder /gateway /usr/local/bin/gateway

# WireGuard and gRPC ports
EXPOSE 51820/udp 50052

# Needs NET_ADMIN for WireGuard and iptables
# Run with: --cap-add=NET_ADMIN --cap-add=SYS_MODULE

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9091/health || exit 1

CMD ["gateway"]
