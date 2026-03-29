package skyos

import (
	"context"
	"fmt"
	"sync"

	"github.com/sirupsen/logrus"
	"github.com/KilloSoftwares/MerryNet/skyos/core"
	"github.com/KilloSoftwares/MerryNet/skyos/services"
)

// Adapter bridges Maranet gateway with Sky OS architecture
type Adapter struct {
	kernel           *core.Kernel
	vpnService       *services.VPNService
	networkService   *services.NetworkService
	securityService  *services.SecurityService
	monitoringService *services.MonitoringService
	
	// Legacy managers (wrapped)
	wireguardMgr     WireguardManager
	natMgr           NATManager
	
	mu               sync.RWMutex
	ctx              context.Context
	cancel           context.CancelFunc
}

// WireguardManager interface for legacy WireGuard manager
type WireguardManager interface {
	Initialize(ctx context.Context) error
	HandlePeer(peerID string, action string) error
	GetStatus() (map[string]interface{}, error)
	Close() error
}

// NATManager interface for legacy NAT manager
type NATManager interface {
	Initialize(ctx context.Context) error
	ConfigureNAT(rules []map[string]interface{}) error
	GetActiveConnections() ([]map[string]interface{}, error)
	Close() error
}

// Config holds Sky OS adapter configuration
type Config struct {
	NodeID       string
	NetworkCIDR  string
	GatewayIP    string
	DNSServers   []string
	MTU          int
	Keepalive    int
}

// NewAdapter creates a new Sky OS adapter
func NewAdapter(cfg *Config, wireguard WireguardManager, nat NATManager) *Adapter {
	return &Adapter{
		wireguardMgr: wireguard,
		natMgr:       nat,
	}
}

// Start initializes the Sky OS adapter and all services
func (a *Adapter) Start(ctx context.Context) error {
	a.ctx, a.cancel = context.WithCancel(ctx)
	
	logrus.Info("Initializing Sky OS adapter...")
	
	// Initialize Sky OS Kernel
	a.kernel = core.NewKernel()
	
	// Initialize services and register with kernel
	if err := a.initializeServices(); err != nil {
		return fmt.Errorf("failed to initialize services: %v", err)
	}
	
	// Start the kernel
	if err := a.kernel.Start(a.ctx); err != nil {
		return fmt.Errorf("failed to start kernel: %v", err)
	}
	
	// Initialize legacy managers
	if err := a.initializeLegacyManagers(); err != nil {
		return fmt.Errorf("failed to initialize legacy managers: %v", err)
	}
	
	logrus.Info("Sky OS adapter started successfully")
	return nil
}

// Stop gracefully shuts down the adapter
func (a *Adapter) Stop() error {
	if a.cancel != nil {
		a.cancel()
	}
	
	logrus.Info("Stopping Sky OS adapter...")
	
	// Stop all services
	if a.vpnService != nil {
		a.vpnService.Stop()
	}
	if a.networkService != nil {
		a.networkService.Stop()
	}
	if a.securityService != nil {
		a.securityService.Stop()
	}
	if a.monitoringService != nil {
		a.monitoringService.Stop()
	}
	
	// Stop kernel
	if a.kernel != nil {
		a.kernel.Stop()
	}
	
	// Close legacy managers
	if a.wireguardMgr != nil {
		a.wireguardMgr.Close()
	}
	if a.natMgr != nil {
		a.natMgr.Close()
	}
	
	logrus.Info("Sky OS adapter stopped")
	return nil
}

// initializeServices initializes all Sky OS services
func (a *Adapter) initializeServices() error {
	// Initialize VPN Service
	a.vpnService = services.NewVPNService(a.kernel)
	if err := a.vpnService.Start(a.ctx); err != nil {
		return fmt.Errorf("VPN service: %v", err)
	}
	a.kernel.RegisterComponent(a.vpnService)
	
	// Initialize Network Service
	a.networkService = services.NewNetworkService(a.kernel)
	if err := a.networkService.Start(a.ctx); err != nil {
		return fmt.Errorf("Network service: %v", err)
	}
	a.kernel.RegisterComponent(a.networkService)
	
	// Initialize Security Service
	a.securityService = services.NewSecurityService(a.kernel)
	if err := a.securityService.Start(a.ctx); err != nil {
		return fmt.Errorf("Security service: %v", err)
	}
	a.kernel.RegisterComponent(a.securityService)
	
	// Initialize Monitoring Service
	a.monitoringService = services.NewMonitoringService(a.kernel)
	if err := a.monitoringService.Start(a.ctx); err != nil {
		return fmt.Errorf("Monitoring service: %v", err)
	}
	a.kernel.RegisterComponent(a.monitoringService)
	
	return nil
}

// initializeLegacyManagers initializes the legacy wireguard and NAT managers
func (a *Adapter) initializeLegacyManagers() error {
	if a.wireguardMgr != nil {
		if err := a.wireguardMgr.Initialize(a.ctx); err != nil {
			return fmt.Errorf("wireguard: %v", err)
		}
	}
	
	if a.natMgr != nil {
		if err := a.natMgr.Initialize(a.ctx); err != nil {
			return fmt.Errorf("NAT: %v", err)
		}
	}
	
	return nil
}

// GetVPNService returns the VPN service instance
func (a *Adapter) GetVPNService() *services.VPNService {
	return a.vpnService
}

// GetNetworkService returns the Network service instance
func (a *Adapter) GetNetworkService() *services.NetworkService {
	return a.networkService
}

// GetSecurityService returns the Security service instance
func (a *Adapter) GetSecurityService() *services.SecurityService {
	return a.securityService
}

// GetMonitoringService returns the Monitoring service instance
func (a *Adapter) GetMonitoringService() *services.MonitoringService {
	return a.monitoringService
}

// GetKernel returns the Sky OS Kernel instance
func (a *Adapter) GetKernel() *core.Kernel {
	return a.kernel
}

// BroadcastEvent sends an event to all services
func (a *Adapter) BroadcastEvent(eventType string, payload interface{}) error {
	msg := core.Message{
		Type:    eventType,
		From:    "maranet-gateway",
		To:      "",
		Payload: payload,
	}
	return a.kernel.BroadcastMessage(msg)
}