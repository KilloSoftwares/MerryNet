package config

import (
	"os"
	"strconv"
)

type Config struct {
	DeviceID  string
	Platform  string
	Server    ServerConfig
	WireGuard WireGuardConfig
	Database  DatabaseConfig
	Health    HealthConfig
}

type ServerConfig struct {
	Address  string // main server gRPC address (host:port)
	UseTLS   bool
	CertFile string
}

type WireGuardConfig struct {
	InterfaceName string
	ListenPort    int
	PrivateKey    string
	Address       string // e.g., 10.0.1.1/24
	DNS           string
	MTU           int
}

type DatabaseConfig struct {
	Path string
}

type HealthConfig struct {
	HeartbeatInterval int // seconds
}

func Load() *Config {
	return &Config{
		DeviceID: getEnv("DEVICE_ID", "node-001"),
		Platform: getEnv("PLATFORM", "rpi"),
		Server: ServerConfig{
			Address:  getEnv("SERVER_ADDRESS", "localhost:50051"),
			UseTLS:   getEnvBool("SERVER_USE_TLS", false),
			CertFile: getEnv("SERVER_CERT_FILE", ""),
		},
		WireGuard: WireGuardConfig{
			InterfaceName: getEnv("WG_INTERFACE", "wg0"),
			ListenPort:    getEnvInt("WG_LISTEN_PORT", 51820),
			PrivateKey:    getEnv("WG_PRIVATE_KEY", ""),
			Address:       getEnv("WG_ADDRESS", "10.0.1.1/24"),
			DNS:           getEnv("WG_DNS", "1.1.1.1,8.8.8.8"),
			MTU:           getEnvInt("WG_MTU", 1420),
		},
		Database: DatabaseConfig{
			Path: getEnv("DB_PATH", "/var/lib/maranet/agent.db"),
		},
		Health: HealthConfig{
			HeartbeatInterval: getEnvInt("HEARTBEAT_INTERVAL", 30),
		},
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return fallback
}
