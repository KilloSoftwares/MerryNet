package wireguard

import (
	"encoding/base64"
	"fmt"
	"net"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
	"golang.zx2c4.com/wireguard/wgctrl"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"

	"github.com/maranet/reseller-agent/internal/config"
)

// Manager manages the local WireGuard interface for end-user peers
type Manager struct {
	client *wgctrl.Client
	config config.WireGuardConfig
	mu     sync.RWMutex
	peers  map[string]*PeerEntry // keyed by public key base64
}

// PeerEntry tracks a connected user peer
type PeerEntry struct {
	PublicKey      string
	UserID         string
	SubscriptionID string
	AllowedIP      string
	ExpiresAt      time.Time
	AddedAt        time.Time
}

// NewManager creates a new WireGuard manager for the reseller node
func NewManager(cfg config.WireGuardConfig) (*Manager, error) {
	client, err := wgctrl.New()
	if err != nil {
		return nil, fmt.Errorf("failed to create wgctrl client: %w", err)
	}

	m := &Manager{
		client: client,
		config: cfg,
		peers:  make(map[string]*PeerEntry),
	}

	// Check if interface exists
	_, err = client.Device(cfg.InterfaceName)
	if err != nil {
		log.Warnf("WireGuard interface '%s' not found. Create it before starting.", cfg.InterfaceName)
	}

	return m, nil
}

// Close closes the WireGuard client
func (m *Manager) Close() {
	m.client.Close()
}

// AddPeer adds a new user peer to the WireGuard interface
func (m *Manager) AddPeer(publicKeyB64, allowedIP, userID, subscriptionID string, expiresAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Parse public key
	keyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return fmt.Errorf("invalid public key: %w", err)
	}
	var pubKey wgtypes.Key
	copy(pubKey[:], keyBytes)

	// Parse allowed IP
	_, ipNet, err := net.ParseCIDR(allowedIP + "/32")
	if err != nil {
		return fmt.Errorf("invalid allowed IP: %w", err)
	}

	// Configure peer
	keepalive := 25 * time.Second
	peerCfg := wgtypes.PeerConfig{
		PublicKey:                   pubKey,
		AllowedIPs:                 []net.IPNet{*ipNet},
		ReplaceAllowedIPs:          true,
		PersistentKeepaliveInterval: &keepalive,
	}

	err = m.client.ConfigureDevice(m.config.InterfaceName, wgtypes.Config{
		Peers: []wgtypes.PeerConfig{peerCfg},
	})
	if err != nil {
		return fmt.Errorf("failed to add peer: %w", err)
	}

	m.peers[publicKeyB64] = &PeerEntry{
		PublicKey:      publicKeyB64,
		UserID:         userID,
		SubscriptionID: subscriptionID,
		AllowedIP:      allowedIP,
		ExpiresAt:      expiresAt,
		AddedAt:        time.Now(),
	}

	log.Infof("✅ Peer added: user=%s, ip=%s, expires=%s", userID, allowedIP, expiresAt.Format(time.RFC3339))
	return nil
}

// RemovePeer removes a user peer from the WireGuard interface
func (m *Manager) RemovePeer(publicKeyB64 string) error {
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
				Remove:   true,
			},
		},
	})
	if err != nil {
		return fmt.Errorf("failed to remove peer: %w", err)
	}

	if peer, ok := m.peers[publicKeyB64]; ok {
		log.Infof("🗑️ Peer removed: user=%s, ip=%s", peer.UserID, peer.AllowedIP)
	}
	delete(m.peers, publicKeyB64)

	return nil
}

// UpdatePeerExpiry updates the expiration time for a peer
func (m *Manager) UpdatePeerExpiry(publicKeyB64 string, newExpiresAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	peer, ok := m.peers[publicKeyB64]
	if !ok {
		return fmt.Errorf("peer not found: %s", publicKeyB64)
	}

	peer.ExpiresAt = newExpiresAt
	log.Infof("🔄 Peer expiry updated: user=%s, new_expires=%s", peer.UserID, newExpiresAt.Format(time.RFC3339))
	return nil
}

// GetPeerCount returns the number of active peers
func (m *Manager) GetPeerCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.peers)
}

// GetExpiredPeers returns peers that have expired
func (m *Manager) GetExpiredPeers() []*PeerEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var expired []*PeerEntry
	now := time.Now()
	for _, peer := range m.peers {
		if now.After(peer.ExpiresAt) {
			expired = append(expired, peer)
		}
	}
	return expired
}

// ListPeers returns all active peers with their stats
func (m *Manager) ListPeers() ([]*PeerEntry, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	peers := make([]*PeerEntry, 0, len(m.peers))
	for _, p := range m.peers {
		peers = append(peers, p)
	}
	return peers, nil
}

// GetPublicKey returns this node's WireGuard public key
func (m *Manager) GetPublicKey() (string, error) {
	dev, err := m.client.Device(m.config.InterfaceName)
	if err != nil {
		return "", err
	}
	return dev.PublicKey.String(), nil
}
