package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"
	log "github.com/sirupsen/logrus"

	"github.com/maranet/reseller-agent/internal/api"
	"github.com/maranet/reseller-agent/internal/config"
	"github.com/maranet/reseller-agent/internal/grpcclient"
	"github.com/maranet/reseller-agent/internal/health"
	"github.com/maranet/reseller-agent/internal/store"
	"github.com/maranet/reseller-agent/internal/wireguard"
)

func main() {
	// Load environment
	_ = godotenv.Load()

	// Load config
	cfg := config.Load()

	// Initialize logger
	log.SetFormatter(&log.JSONFormatter{})
	if cfg.DeveloperMode {
		log.SetLevel(log.DebugLevel)
		log.Debug("🛠️  Developer mode enabled: Debug logging active")
	} else {
		log.SetLevel(log.InfoLevel)
	}

	// Initialize SQLite store
	db, err := store.NewStore(cfg.Database.Path)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()
	log.Info("✅ SQLite database initialized")

	// Initialize WireGuard manager
	wgManager, err := wireguard.NewManager(cfg.WireGuard)
	if err != nil {
		log.Fatalf("Failed to initialize WireGuard: %v", err)
	}
	defer wgManager.Close()
	log.Info("✅ WireGuard manager initialized")

	// Initialize health monitor
	healthMonitor := health.NewMonitor(cfg.Health)

	// Context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Connect to main server via gRPC
	client, err := grpcclient.NewClient(cfg.Server, wgManager, db)
	offlineMode := false
	if err != nil {
		log.Warnf("Failed to connect to main server: %v - Entering OFFLINE mode", err)
		offlineMode = true
	} else {
		defer client.Close()
		log.Info("✅ Connected to main server")

		// Register node
		if err := client.RegisterNode(ctx, cfg); err != nil {
			log.Warnf("Failed to register node: %v - Entering OFFLINE mode", err)
			offlineMode = true
		} else {
			log.Info("✅ Node registered with main server")
		}
	}

	// Start local API for offline decentralized provisioning
	localAPI := api.NewServer(cfg.LocalAPI, wgManager, db)
	go func() {
		if err := localAPI.Start(); err != nil && err != http.ErrServerClosed {
			log.Errorf("Local API error: %v", err)
		}
	}()
	defer localAPI.Stop(context.Background())

	// Start heartbeat loop
	go func() {
		if offlineMode || client == nil {
			return
		}
		ticker := time.NewTicker(time.Duration(cfg.Health.HeartbeatInterval) * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				metrics := healthMonitor.CollectMetrics()
				peerCount := wgManager.GetPeerCount()
				metrics.ActivePeers = peerCount

				if err := client.SendHeartbeat(ctx, metrics); err != nil {
					log.Warnf("Failed to send heartbeat: %v", err)
				}
			}
		}
	}()

	// Start peer expiry checker
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				expired := db.GetExpiredPeers()
				for _, peer := range expired {
					log.Infof("⏰ Removing expired peer: %s (user: %s)", peer.PublicKey, peer.UserID)
					if err := wgManager.RemovePeer(peer.PublicKey); err != nil {
						log.Errorf("Failed to remove expired peer: %v", err)
						continue
					}
					db.RemovePeer(peer.PublicKey)
				}
			}
		}
	}()

	// Start command stream (bidirectional gRPC)
	go func() {
		if offlineMode || client == nil {
			return
		}
		for {
			select {
			case <-ctx.Done():
				return
			default:
				if err := client.StartCommandStream(ctx); err != nil {
					log.Errorf("Command stream error: %v, reconnecting in 5s...", err)
					time.Sleep(5 * time.Second)
				}
			}
		}
	}()

	statusLabel := "🟢 ONLINE"
	if offlineMode {
		statusLabel = "🟠 OFFLINE (Local API only)"
	}

	log.Info(fmt.Sprintf(`
╔══════════════════════════════════════════════════════╗
║                                                      ║
║        📡 Maranet Reseller Agent                     ║
║                                                      ║
║   Device ID:     %-33s  ║
║   Status:        %-33s  ║
║   Server:        %-33s  ║
║   WG Interface:  %-33s  ║
║   Platform:      %-33s  ║
║                                                      ║
╚══════════════════════════════════════════════════════╝`,
		cfg.DeviceID, statusLabel, cfg.Server.Address, cfg.WireGuard.InterfaceName, cfg.Platform))

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)
	<-sigChan

	log.Info("Shutting down reseller agent...")
	cancel()
	time.Sleep(2 * time.Second)
	log.Info("✅ Reseller agent shut down gracefully")
}
