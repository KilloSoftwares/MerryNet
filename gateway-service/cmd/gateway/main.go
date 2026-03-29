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

	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/config"
	grpcserver "github.com/KilloSoftwares/MerryNet/gateway-service/internal/grpc"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/metrics"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/nat"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/skyos"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/wireguard"
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

	// Initialize Sky OS Adapter (bridges legacy managers with Sky OS architecture)
	skyosConfig := &skyos.Config{
		NodeID:       cfg.NodeID,
		NetworkCIDR:  cfg.WireGuard.Address,
		GatewayIP:    cfg.WireGuard.Address,
		DNSServers:   cfg.WireGuard.DNS,
		MTU:          cfg.WireGuard.MTU,
		Keepalive:    cfg.WireGuard.PersistentKeepalive,
	}

	// Initialize legacy managers first
	wgManager, err := wireguard.NewManager(cfg.WireGuard)
	if err != nil {
		log.Fatalf("Failed to initialize WireGuard manager: %v", err)
	}
	defer wgManager.Close()
	log.Info("✅ WireGuard manager initialized")

	natManager, err := nat.NewManager(cfg.NAT)
	if err != nil {
		log.Fatalf("Failed to initialize NAT manager: %v", err)
	}
	log.Info("✅ NAT manager initialized")

	// Create Sky OS adapter wrapping legacy managers
	adapter := skyos.NewAdapter(skyosConfig, wgManager, natManager)

	// Start Sky OS adapter
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := adapter.Start(ctx); err != nil {
		log.Fatalf("Failed to start Sky OS adapter: %v", err)
	}
	log.Info("✅ Sky OS adapter initialized")

	// Setup initial NAT rules (through legacy manager)
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
║   Sky OS Adapter:      ✅ Enabled                    ║
║   gRPC Port:           ` + fmt.Sprintf("%-27d", cfg.GRPC.Port) + ` ║
║   Metrics Port:        ` + fmt.Sprintf("%-27d", cfg.Metrics.Port) + ` ║
║                                                      ║
╚══════════════════════════════════════════════════════╝`)

	// Wait for shutdown signal
	shutdownCtx, shutdownCancel := context.WithCancel(context.Background())
	defer shutdownCancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	select {
	case sig := <-sigChan:
		log.Infof("Received signal %v, shutting down...", sig)
	case <-shutdownCtx.Done():
	}

	// Graceful shutdown
	grpcSrv.GracefulStop()
	natManager.Cleanup()
	log.Info("✅ Gateway service shut down gracefully")

	// Stop Sky OS adapter
	adapter.Stop()
	log.Info("✅ Sky OS adapter stopped")
}
