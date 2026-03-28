FROM rust:1.76-alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
# Create dummy main to cache dependencies
RUN mkdir src && echo 'fn main() {}' > src/main.rs
RUN cargo build --release 2>/dev/null || true
RUN rm -rf src

COPY src ./src
RUN cargo build --release

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/target/release/maranet-bootstrap /usr/local/bin/bootstrap

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["bootstrap"]
