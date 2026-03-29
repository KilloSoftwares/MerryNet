package grpc

import (
	"context"
	"fmt"
	"net"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/nat"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/wireguard"
)

// Server implements the GatewayService gRPC server
type Server struct {
	grpcServer *grpc.Server
	wgManager  *wireguard.Manager
	natManager *nat.Manager
}

// NewServer creates a new gRPC server
func NewServer(wg *wireguard.Manager, natMgr *nat.Manager) *Server {
	s := &Server{
		wgManager:  wg,
		natManager: natMgr,
	}

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(loggingInterceptor),
	)

	// Register the gateway service
	// Note: In production, register the generated protobuf service here
	// pb.RegisterGatewayServiceServer(grpcServer, s)

	s.grpcServer = grpcServer
	return s
}

// Serve starts the gRPC server
func (s *Server) Serve(lis net.Listener) error {
	return s.grpcServer.Serve(lis)
}

// GracefulStop gracefully stops the gRPC server
func (s *Server) GracefulStop() {
	s.grpcServer.GracefulStop()
}

// AddTunnel handles adding a new node tunnel
func (s *Server) AddTunnel(ctx context.Context, nodeID, publicKey, endpoint, subnet string) error {
	// Add WireGuard tunnel
	if err := s.wgManager.AddTunnel(nodeID, publicKey, endpoint, subnet); err != nil {
		return fmt.Errorf("failed to add WireGuard tunnel: %w", err)
	}

	// Add NAT forwarding
	if err := s.natManager.AddNodeForwarding(subnet); err != nil {
		log.Warnf("Failed to add NAT forwarding for %s: %v", subnet, err)
	}

	return nil
}

// RemoveTunnel handles removing a node tunnel
func (s *Server) RemoveTunnel(ctx context.Context, nodeID, publicKey string) error {
	// Get tunnel info for subnet
	tunnel, ok := s.wgManager.GetTunnel(nodeID)
	if ok {
		s.natManager.RemoveNodeForwarding(tunnel.Subnet)
	}

	return s.wgManager.RemoveTunnel(nodeID, publicKey)
}

// GetStatus returns current gateway status
func (s *Server) GetStatus(ctx context.Context) (map[string]interface{}, error) {
	dev, err := s.wgManager.GetDeviceInfo()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get device info: %v", err)
	}

	var totalRx, totalTx int64
	for _, peer := range dev.Peers {
		totalRx += peer.ReceiveBytes
		totalTx += peer.TransmitBytes
	}

	return map[string]interface{}{
		"active_tunnels": s.wgManager.GetTunnelCount(),
		"total_peers":    len(dev.Peers),
		"total_rx":       totalRx,
		"total_tx":       totalTx,
		"listen_port":    dev.ListenPort,
		"public_key":     dev.PublicKey.String(),
	}, nil
}

// loggingInterceptor logs all gRPC requests
func loggingInterceptor(
	ctx context.Context,
	req interface{},
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (interface{}, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	duration := time.Since(start)

	if err != nil {
		log.WithFields(log.Fields{
			"method":   info.FullMethod,
			"duration": duration,
			"error":    err.Error(),
		}).Error("gRPC request failed")
	} else {
		log.WithFields(log.Fields{
			"method":   info.FullMethod,
			"duration": duration,
		}).Debug("gRPC request completed")
	}

	return resp, err
}

// Helper to create a timestamp proto
func nowTimestamp() *timestamppb.Timestamp {
	return timestamppb.Now()
}
