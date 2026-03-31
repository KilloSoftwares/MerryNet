package services

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/KilloSoftwares/MerryNet/skyos/core"
)

// NetworkService handles network operations for Maranet
type NetworkService struct {
	name       string
	kernel     *core.Kernel
	interfaces map[string]*NetworkInterface
	mu         sync.RWMutex
	ctx        context.Context
	cancel     context.CancelFunc
}

// NetworkInterface represents a network interface
type NetworkInterface struct {
	Name       string
	IP         net.IP
	Subnet     *net.IPNet
	Gateway    net.IP
	DNS        []net.IP
	Status     string
	LastUpdate time.Time
}

// NewNetworkService creates a new network service
func NewNetworkService(kernel *core.Kernel) *NetworkService {
	return &NetworkService{
		name:       "network-service",
		kernel:     kernel,
		interfaces: make(map[string]*NetworkInterface),
	}
}

// Name returns the service name
func (ns *NetworkService) Name() string {
	return ns.name
}

// Start initializes the network service
func (ns *NetworkService) Start(ctx context.Context) error {
	ns.ctx, ns.cancel = context.WithCancel(ctx)
	logrus.Info("Starting Network Service...")

	// Initialize network interfaces
	if err := ns.initializeInterfaces(); err != nil {
		return fmt.Errorf("failed to initialize interfaces: %v", err)
	}

	// Start network monitoring
	go ns.monitorNetwork()

	logrus.Info("Network Service started successfully")
	return nil
}

// Stop gracefully shuts down the network service
func (ns *NetworkService) Stop() error {
	if ns.cancel != nil {
		ns.cancel()
	}
	logrus.Info("Network Service stopped")
	return nil
}

// HandleMessage processes incoming messages
func (ns *NetworkService) HandleMessage(msg core.Message) error {
	switch msg.Type {
	case "network.configure":
		return ns.handleConfigure(msg)
	case "network.status":
		return ns.handleStatusRequest(msg)
	case "network.interface.add":
		return ns.handleInterfaceAdd(msg)
	case "network.interface.remove":
		return ns.handleInterfaceRemove(msg)
	default:
		return fmt.Errorf("unknown message type: %s", msg.Type)
	}
}

// initializeInterfaces sets up initial network interfaces
func (ns *NetworkService) initializeInterfaces() error {
	// Get system network interfaces
	interfaces, err := net.Interfaces()
	if err != nil {
		return err
	}

	for _, iface := range interfaces {
		// Skip loopback interfaces
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		// Get interface addresses
		addrs, err := iface.Addrs()
		if err != nil {
			logrus.Warnf("Failed to get addresses for interface %s: %v", iface.Name, err)
			continue
		}

		networkIface := &NetworkInterface{
			Name:       iface.Name,
			Status:     "active",
			LastUpdate: time.Now(),
		}

		// Parse IP addresses
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok {
				if ipnet.IP.To4() != nil {
					networkIface.IP = ipnet.IP
					networkIface.Subnet = ipnet
					break
				}
			}
		}

		ns.mu.Lock()
		ns.interfaces[iface.Name] = networkIface
		ns.mu.Unlock()

		logrus.Infof("Initialized network interface: %s", iface.Name)
	}

	return nil
}

// monitorNetwork continuously monitors network status
func (ns *NetworkService) monitorNetwork() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ns.ctx.Done():
			return
		case <-ticker.C:
			ns.checkNetworkHealth()
		}
	}
}

// checkNetworkHealth performs network health checks
func (ns *NetworkService) checkNetworkHealth() {
	ns.mu.RLock()
	defer ns.mu.RUnlock()

	for name, iface := range ns.interfaces {
		// Check if interface is still active
		if _, err := net.InterfaceByName(name); err != nil {
			iface.Status = "inactive"
			logrus.Warnf("Network interface %s is inactive", name)
		} else {
			iface.Status = "active"
			iface.LastUpdate = time.Now()
		}
	}
}

// handleConfigure handles network configuration messages
func (ns *NetworkService) handleConfigure(msg core.Message) error {
	config, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid configuration payload")
	}

	// Apply network configuration
	if ifaceName, ok := config["interface"].(string); ok {
		return ns.configureInterface(ifaceName, config)
	}

	return nil
}

// handleStatusRequest handles network status requests
func (ns *NetworkService) handleStatusRequest(msg core.Message) error {
	status := ns.getNetworkStatus()

	response := core.Message{
		Type:    "network.status.response",
		From:    ns.name,
		To:      msg.From,
		Payload: status,
	}

	return ns.kernel.SendMessage(response)
}

// handleInterfaceAdd handles interface addition
func (ns *NetworkService) handleInterfaceAdd(msg core.Message) error {
	ifaceConfig, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid interface configuration")
	}

	ifaceName, ok := ifaceConfig["name"].(string)
	if !ok {
		return fmt.Errorf("interface name required")
	}

	ns.mu.Lock()
	defer ns.mu.Unlock()

	if _, exists := ns.interfaces[ifaceName]; exists {
		return fmt.Errorf("interface %s already exists", ifaceName)
	}

	iface := &NetworkInterface{
		Name:       ifaceName,
		Status:     "configured",
		LastUpdate: time.Now(),
	}

	ns.interfaces[ifaceName] = iface
	logrus.Infof("Added network interface: %s", ifaceName)

	return nil
}

// handleInterfaceRemove handles interface removal
func (ns *NetworkService) handleInterfaceRemove(msg core.Message) error {
	ifaceName, ok := msg.Payload.(string)
	if !ok {
		return fmt.Errorf("interface name required")
	}

	ns.mu.Lock()
	defer ns.mu.Unlock()

	if _, exists := ns.interfaces[ifaceName]; !exists {
		return fmt.Errorf("interface %s not found", ifaceName)
	}

	delete(ns.interfaces, ifaceName)
	logrus.Infof("Removed network interface: %s", ifaceName)

	return nil
}

// configureInterface applies configuration to a network interface
func (ns *NetworkService) configureInterface(ifaceName string, config map[string]interface{}) error {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	iface, exists := ns.interfaces[ifaceName]
	if !exists {
		return fmt.Errorf("interface %s not found", ifaceName)
	}

	// Apply IP configuration
	if ipStr, ok := config["ip"].(string); ok {
		if ip := net.ParseIP(ipStr); ip != nil {
			iface.IP = ip
		}
	}

	// Apply gateway configuration
	if gatewayStr, ok := config["gateway"].(string); ok {
		if gateway := net.ParseIP(gatewayStr); gateway != nil {
			iface.Gateway = gateway
		}
	}

	// Apply DNS configuration
	if dnsList, ok := config["dns"].([]interface{}); ok {
		iface.DNS = make([]net.IP, 0, len(dnsList))
		for _, dns := range dnsList {
			if dnsStr, ok := dns.(string); ok {
				if ip := net.ParseIP(dnsStr); ip != nil {
					iface.DNS = append(iface.DNS, ip)
				}
			}
		}
	}

	iface.LastUpdate = time.Now()
	logrus.Infof("Configured network interface: %s", ifaceName)

	return nil
}

// getNetworkStatus returns current network status
func (ns *NetworkService) getNetworkStatus() map[string]interface{} {
	ns.mu.RLock()
	defer ns.mu.RUnlock()

	status := make(map[string]interface{})
	interfaces := make([]map[string]interface{}, 0, len(ns.interfaces))

	for name, iface := range ns.interfaces {
		ipStr := ""
		if iface.IP != nil {
			ipStr = iface.IP.String()
		}
		gatewayStr := ""
		if iface.Gateway != nil {
			gatewayStr = iface.Gateway.String()
		}
		ifaceStatus := map[string]interface{}{
			"name":    name,
			"status":  iface.Status,
			"ip":      ipStr,
			"gateway": gatewayStr,
		}

		dnsList := make([]string, 0, len(iface.DNS))
		for _, dns := range iface.DNS {
			dnsList = append(dnsList, dns.String())
		}
		ifaceStatus["dns"] = dnsList

		interfaces = append(interfaces, ifaceStatus)
	}

	status["interfaces"] = interfaces
	status["timestamp"] = time.Now()

	return status
}

// GetInterface returns a network interface by name
func (ns *NetworkService) GetInterface(name string) (*NetworkInterface, bool) {
	ns.mu.RLock()
	defer ns.mu.RUnlock()
	iface, exists := ns.interfaces[name]
	return iface, exists
}

// ListInterfaces returns all network interface names
func (ns *NetworkService) ListInterfaces() []string {
	ns.mu.RLock()
	defer ns.mu.RUnlock()
	names := make([]string, 0, len(ns.interfaces))
	for name := range ns.interfaces {
		names = append(names, name)
	}
	return names
}