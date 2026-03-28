package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/joho/godotenv"
	log "github.com/sirupsen/logrus"

	"github.com/maranet/gateway-service/internal/config"
	grpcserver "github.com/maranet/gateway-service/internal/grpc"
	"github.com/maranet/gateway-service/internal/metrics"
	"github.com/maranet/gateway-service/internal/nat"
	"github.com/maranet/gateway-service/internal/wireguard"
)

func main() {
	// Load environment
	_ = godotenv.Load()

	// Initialize logger
	log.SetFormatter(&log.JSONFormatter{})
	log.SetLevel(log.DebugLevel)

	log.Info("🚀 Starting Maranet Gateway Service...")

	// Load config
	cfg := config.Load()

	// Initialize WireGuard manager
	wgManager, err := wireguard.NewManager(cfg.WireGuard)
	if err != nil {
		log.Fatalf("Failed to initialize WireGuard manager: %v", err)
	}
	defer wgManager.Close()
	log.Info("✅ WireGuard manager initialized")

	// Initialize NAT manager
	natManager, err := nat.NewManager(cfg.NAT)
	if err != nil {
		log.Fatalf("Failed to initialize NAT manager: %v", err)
	}
	log.Info("✅ NAT manager initialized")

	// Setup initial NAT rules
	if err := natManager.SetupMasquerade(); err != nil {
		log.Warnf("Failed to setup NAT masquerade: %v", err)
	}

	// Initialize metrics server
	metricsServer := metrics.NewServer(cfg.Metrics.Port)
	go func() {
		if err := metricsServer.Start(); err != nil {
			log.Warnf("Metrics server error: %v", err)
		}
	}()
	log.Infof("📊 Metrics server listening on :%d", cfg.Metrics.Port)

	// Start gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf("%s:%d", cfg.GRPC.Host, cfg.GRPC.Port))
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcSrv := grpcserver.NewServer(wgManager, natManager)
	go func() {
		log.Infof("🔌 gRPC server listening on %s:%d", cfg.GRPC.Host, cfg.GRPC.Port)
		if err := grpcSrv.Serve(lis); err != nil {
			log.Fatalf("gRPC server error: %v", err)
		}
	}()

	log.Info(`
╔══════════════════════════════════════════════════════╗
║                                                      ║
║        🛡️  Maranet Gateway Service                   ║
║                                                      ║
║   WireGuard Interface: ` + cfg.WireGuard.InterfaceName + `                       ║
║   gRPC Port:           ` + fmt.Sprintf("%-27d", cfg.GRPC.Port) + ` ║
║   Metrics Port:        ` + fmt.Sprintf("%-27d", cfg.Metrics.Port) + ` ║
║                                                      ║
╚══════════════════════════════════════════════════════╝`)

	// Wait for shutdown signal
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	select {
	case sig := <-sigChan:
		log.Infof("Received signal %v, shutting down...", sig)
	case <-ctx.Done():
	}

	// Graceful shutdown
	grpcSrv.GracefulStop()
	natManager.Cleanup()
	log.Info("✅ Gateway service shut down gracefully")
}
