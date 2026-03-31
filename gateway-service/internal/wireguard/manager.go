package wireguard

import (
	"context"
	"encoding/base64"
	"fmt"
	"net"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
	"golang.zx2c4.com/wireguard/wgctrl"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"

	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/config"
)

// Manager manages WireGuard interface and peers
type Manager struct {
	client  *wgctrl.Client
	config  config.WireGuardConfig
	mu      sync.RWMutex
	peers   map[string]*PeerInfo   // keyed by public key (base64)
	tunnels map[string]*TunnelInfo // keyed by node ID
}

// PeerInfo tracks information about a WireGuard peer
type PeerInfo struct {
	PublicKey  wgtypes.Key
	AllowedIPs []net.IPNet
	Endpoint   *net.UDPAddr
	NodeID     string
	AddedAt    time.Time
}

// TunnelInfo tracks a node-to-gateway tunnel
type TunnelInfo struct {
	NodeID    string
	PublicKey wgtypes.Key
	Endpoint  *net.UDPAddr
	Subnet    string
	AddedAt   time.Time
}

// NewManager creates a new WireGuard manager
func NewManager(cfg config.WireGuardConfig) (*Manager, error) {
	client, err := wgctrl.New()
	if err != nil {
		return nil, fmt.Errorf("failed to create wgctrl client: %w", err)
	}

	m := &Manager{
		client:  client,
		config:  cfg,
		peers:   make(map[string]*PeerInfo),
		tunnels: make(map[string]*TunnelInfo),
	}

	// Verify the interface exists
	dev, err := client.Device(cfg.InterfaceName)
	if err != nil {
		log.Warnf("WireGuard interface '%s' not found. It may need to be created.", cfg.InterfaceName)
	} else {
		log.Infof("WireGuard interface '%s' found with %d peers", cfg.InterfaceName, len(dev.Peers))
		// Load existing peers
		for _, p := range dev.Peers {
			key := p.PublicKey.String()
			m.peers[key] = &PeerInfo{
				PublicKey:  p.PublicKey,
				AllowedIPs: p.AllowedIPs,
				Endpoint:   p.Endpoint,
				AddedAt:    time.Now(),
			}
		}
	}

	return m, nil
}

// Close closes the WireGuard client
func (m *Manager) Close() error {
	return m.client.Close()
}

// AddTunnel adds a reseller node tunnel to the gateway
func (m *Manager) AddTunnel(nodeID, publicKeyB64, endpointStr, subnet string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Parse public key
	keyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return fmt.Errorf("invalid public key: %w", err)
	}
	var pubKey wgtypes.Key
	copy(pubKey[:], keyBytes)

	// Parse endpoint
	endpoint, err := net.ResolveUDPAddr("udp", endpointStr)
	if err != nil {
		return fmt.Errorf("invalid endpoint: %w", err)
	}

	// Parse subnet
	_, ipNet, err := net.ParseCIDR(subnet)
	if err != nil {
		return fmt.Errorf("invalid subnet: %w", err)
	}

	// Configure peer
	keepalive := 25 * time.Second
	peerCfg := wgtypes.PeerConfig{
		PublicKey:                   pubKey,
		Endpoint:                    endpoint,
		AllowedIPs:                  []net.IPNet{*ipNet},
		PersistentKeepaliveInterval: &keepalive,
		ReplaceAllowedIPs:           true,
	}

	err = m.client.ConfigureDevice(m.config.InterfaceName, wgtypes.Config{
		Peers: []wgtypes.PeerConfig{peerCfg},
	})
	if err != nil {
		return fmt.Errorf("failed to add tunnel peer: %w", err)
	}

	m.tunnels[nodeID] = &TunnelInfo{
		NodeID:    nodeID,
		PublicKey: pubKey,
		Endpoint:  endpoint,
		Subnet:    subnet,
		AddedAt:   time.Now(),
	}

	log.Infof("✅ Tunnel added: node=%s, subnet=%s, endpoint=%s", nodeID, subnet, endpointStr)
	return nil
}

// RemoveTunnel removes a reseller node tunnel
func (m *Manager) RemoveTunnel(nodeID, publicKeyB64 string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	keyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return fmt.Errorf("invalid public key: %w", err)
	}
	var pubKey wgtypes.Key
	copy(pubKey[:], keyBytes)

	err = m.client.ConfigureDevice(m.config.InterfaceName, wgtypes.Config{
		Peers: []wgtypes.PeerConfig{
			{
				PublicKey: pubKey,
				Remove:    true,
			},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to remove tunnel peer: %w", err)
	}

	delete(m.tunnels, nodeID)
	delete(m.peers, publicKeyB64)

	log.Infof("🗑️ Tunnel removed: node=%s", nodeID)
	return nil
}

// GetDeviceInfo returns current WireGuard device information
func (m *Manager) GetDeviceInfo() (*wgtypes.Device, error) {
	return m.client.Device(m.config.InterfaceName)
}

// GetTunnelCount returns the number of active tunnels
func (m *Manager) GetTunnelCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.tunnels)
}

// GetTunnel returns info about a specific tunnel
func (m *Manager) GetTunnel(nodeID string) (*TunnelInfo, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	t, ok := m.tunnels[nodeID]
	return t, ok
}

// GetPeerStats returns stats for a specific peer by public key
func (m *Manager) GetPeerStats(publicKeyB64 string) (*wgtypes.Peer, error) {
	dev, err := m.client.Device(m.config.InterfaceName)
	if err != nil {
		return nil, err
	}

	keyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return nil, fmt.Errorf("invalid public key: %w", err)
	}
	var pubKey wgtypes.Key
	copy(pubKey[:], keyBytes)

	for _, peer := range dev.Peers {
		if peer.PublicKey == pubKey {
			return &peer, nil
		}
	}

	return nil, fmt.Errorf("peer not found")
}

// GetPublicKey returns the gateway's public key
func (m *Manager) GetPublicKey() (string, error) {
	dev, err := m.client.Device(m.config.InterfaceName)
	if err != nil {
		return "", err
	}
	return dev.PublicKey.String(), nil
}

// Initialize satisfies the skyos.WireguardManager interface
func (m *Manager) Initialize(ctx context.Context) error {
	log.Info("WireGuard manager initialized via Sky OS adapter")
	return nil
}

// HandlePeer satisfies the skyos.WireguardManager interface
func (m *Manager) HandlePeer(peerID string, action string) error {
	switch action {
	case "add":
		log.Infof("HandlePeer: add peer %s (use AddTunnel for full setup)", peerID)
	case "remove":
		log.Infof("HandlePeer: remove peer %s", peerID)
	default:
		return fmt.Errorf("unknown peer action: %s", action)
	}
	return nil
}

// GetStatus satisfies the skyos.WireguardManager interface
func (m *Manager) GetStatus() (map[string]interface{}, error) {
	dev, err := m.GetDeviceInfo()
	if err != nil {
		return nil, err
	}

	status := map[string]interface{}{
		"interface":   m.config.InterfaceName,
		"public_key":  dev.PublicKey.String(),
		"listen_port": dev.ListenPort,
		"peer_count":  len(dev.Peers),
		"tunnel_count": m.GetTunnelCount(),
	}
	return status, nil
}
