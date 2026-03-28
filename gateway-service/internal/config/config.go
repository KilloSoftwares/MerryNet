package config

import (
	"os"
	"strconv"
)

type Config struct {
	WireGuard WireGuardConfig
	GRPC      GRPCConfig
	NAT       NATConfig
	Metrics   MetricsConfig
}

type WireGuardConfig struct {
	InterfaceName string
	ListenPort    int
	PrivateKey    string
	Address       string // CIDR, e.g., 10.0.0.1/16
	DNS           string
	MTU           int
}

type GRPCConfig struct {
	Host string
	Port int
}

type NATConfig struct {
	ExternalInterface string
	InternalSubnet    string
	EnableForwarding  bool
}

type MetricsConfig struct {
	Port int
}

func Load() *Config {
	return &Config{
		WireGuard: WireGuardConfig{
			InterfaceName: getEnv("WG_INTERFACE", "wg0"),
			ListenPort:    getEnvInt("WG_LISTEN_PORT", 51820),
			PrivateKey:    getEnv("WG_PRIVATE_KEY", ""),
			Address:       getEnv("WG_ADDRESS", "10.0.0.1/16"),
			DNS:           getEnv("WG_DNS", "1.1.1.1,8.8.8.8"),
			MTU:           getEnvInt("WG_MTU", 1420),
		},
		GRPC: GRPCConfig{
			Host: getEnv("GRPC_HOST", "0.0.0.0"),
			Port: getEnvInt("GRPC_PORT", 50052),
		},
		NAT: NATConfig{
			ExternalInterface: getEnv("NAT_EXTERNAL_INTERFACE", "eth0"),
			InternalSubnet:    getEnv("NAT_INTERNAL_SUBNET", "10.0.0.0/16"),
			EnableForwarding:  getEnvBool("NAT_ENABLE_FORWARDING", true),
		},
		Metrics: MetricsConfig{
			Port: getEnvInt("METRICS_PORT", 9091),
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
