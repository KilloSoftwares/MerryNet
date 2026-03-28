package grpcclient

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"

	"github.com/maranet/reseller-agent/internal/config"
	"github.com/maranet/reseller-agent/internal/health"
	"github.com/maranet/reseller-agent/internal/store"
	"github.com/maranet/reseller-agent/internal/wireguard"
)

// Client is the gRPC client that communicates with the main server
type Client struct {
	conn      *grpc.ClientConn
	wgManager *wireguard.Manager
	store     *store.Store
	nodeID    string
}

// NewClient creates a new gRPC client
func NewClient(cfg config.ServerConfig, wg *wireguard.Manager, db *store.Store) (*Client, error) {
	// Setup connection options
	opts := []grpc.DialOption{
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                30 * time.Second,
			Timeout:             10 * time.Second,
			PermitWithoutStream: true,
		}),
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(10 * 1024 * 1024),
		),
	}

	if cfg.UseTLS {
		// Load standard system TLS profiles to connect securely to the main gateway
		creds := credentials.NewTLS(&tls.Config{
			InsecureSkipVerify: false,
		})
		log.Info("🔒 TLS Enabled: Establishing secure gRPC connection")
		opts = append(opts, grpc.WithTransportCredentials(creds))
	} else {
		opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	// Connect
	conn, err := grpc.Dial(cfg.Address, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %w", err)
	}

	return &Client{
		conn:      conn,
		wgManager: wg,
		store:     db,
	}, nil
}

// Close closes the gRPC connection
func (c *Client) Close() error {
	return c.conn.Close()
}

// RegisterNode registers this node with the main server
func (c *Client) RegisterNode(ctx context.Context, cfg *config.Config) error {
	// In production, this would call the RegisterNode RPC
	// For now, we store the node ID locally
	c.nodeID = cfg.DeviceID

	// Get WireGuard public key
	pubKey, err := c.wgManager.GetPublicKey()
	if err != nil {
		log.Warnf("Could not get WireGuard public key: %v", err)
		pubKey = "unknown"
	}

	// Store registration state
	c.store.SetState("node_id", cfg.DeviceID)
	c.store.SetState("registered_at", time.Now().Format(time.RFC3339))
	c.store.SetState("public_key", pubKey)

	log.Infof("Node registered: id=%s, pubkey=%s", cfg.DeviceID, pubKey[:20]+"...")

	return nil
}

// SendHeartbeat sends health metrics to the main server
func (c *Client) SendHeartbeat(ctx context.Context, metrics *health.Metrics) error {
	// In production, this would call the Heartbeat streaming RPC
	log.Debugf("💓 Heartbeat: peers=%d, cpu=%.1f%%, mem=%.1f%%, uptime=%.0fs",
		metrics.ActivePeers, metrics.CPUUsage, metrics.MemoryUsage, metrics.Uptime)

	return nil
}

// StartCommandStream starts the bidirectional command stream with the server
func (c *Client) StartCommandStream(ctx context.Context) error {
	// In production, this would open the CommandStream bidirectional RPC
	// and process incoming commands (CreatePeer, RemovePeer, UpdatePeer)

	log.Debug("Command stream: waiting for commands from server...")

	// Simulate waiting for commands
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(60 * time.Second):
		return nil
	}
}

// HandleCreatePeer processes a CreatePeer command from the server
func (c *Client) HandleCreatePeer(publicKey, userID, subscriptionID, allowedIP string, expiresAt time.Time) error {
	// Add to WireGuard
	if err := c.wgManager.AddPeer(publicKey, allowedIP, userID, subscriptionID, expiresAt); err != nil {
		return fmt.Errorf("failed to add WireGuard peer: %w", err)
	}

	// Store in database
	if err := c.store.AddPeer(&store.PeerRecord{
		PublicKey:      publicKey,
		UserID:         userID,
		SubscriptionID: subscriptionID,
		AllowedIP:      allowedIP,
		ExpiresAt:      expiresAt,
	}); err != nil {
		return fmt.Errorf("failed to store peer: %w", err)
	}

	log.Infof("✅ Created peer: user=%s, ip=%s, expires=%s", userID, allowedIP, expiresAt.Format(time.RFC3339))
	return nil
}

// HandleRemovePeer processes a RemovePeer command from the server
func (c *Client) HandleRemovePeer(publicKey string) error {
	if err := c.wgManager.RemovePeer(publicKey); err != nil {
		return fmt.Errorf("failed to remove WireGuard peer: %w", err)
	}
	c.store.RemovePeer(publicKey)
	log.Infof("🗑️ Removed peer: %s", publicKey)
	return nil
}

// HandleUpdatePeer processes an UpdatePeer command from the server
func (c *Client) HandleUpdatePeer(publicKey string, newExpiresAt time.Time) error {
	if err := c.wgManager.UpdatePeerExpiry(publicKey, newExpiresAt); err != nil {
		return fmt.Errorf("failed to update peer expiry: %w", err)
	}
	c.store.UpdatePeerExpiry(publicKey, newExpiresAt)
	log.Infof("🔄 Updated peer: %s, new_expires=%s", publicKey, newExpiresAt.Format(time.RFC3339))
	return nil
}
