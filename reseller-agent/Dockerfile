FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git gcc musl-dev linux-headers sqlite-dev

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o /agent ./cmd/agent

FROM alpine:3.19

RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    iproute2 \
    sqlite \
    ca-certificates

RUN mkdir -p /var/lib/maranet

COPY --from=builder /agent /usr/local/bin/agent

EXPOSE 51820/udp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD test -f /var/lib/maranet/agent.db || exit 1

CMD ["agent"]
