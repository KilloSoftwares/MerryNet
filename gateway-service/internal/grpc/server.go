package grpc

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/config"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/nat"
	maranetpb "github.com/KilloSoftwares/MerryNet/gateway-service/internal/pb/proto"
	"github.com/KilloSoftwares/MerryNet/gateway-service/internal/wireguard"
)

// Server implements the GatewayService gRPC server
type Server struct {
	maranetpb.UnimplementedGatewayServiceServer
	grpcServer *grpc.Server
	wgManager  *wireguard.Manager
	natManager *nat.Manager
}

// NewServer creates a new gRPC server
func NewServer(cfg *config.GRPCConfig, wg *wireguard.Manager, natMgr *nat.Manager) (*Server, error) {
	opts := []grpc.ServerOption{
		grpc.UnaryInterceptor(loggingInterceptor),
	}

	if cfg.UseTLS {
		if cfg.CertFile == "" || cfg.KeyFile == "" {
			return nil, fmt.Errorf("GRPC_USE_TLS enabled but GRPC_TLS_CERT_FILE or GRPC_TLS_KEY_FILE is missing")
		}

		cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
		if err != nil {
			return nil, fmt.Errorf("failed to load TLS certificate: %w", err)
		}

		creds := credentials.NewServerTLSFromCert(&cert)
		opts = append(opts, grpc.Creds(creds))
		log.Info("🔒 gRPC TLS enabled for gateway service")
	}

	grpcServer := grpc.NewServer(opts...)

	s := &Server{
		grpcServer: grpcServer,
		wgManager:  wg,
		natManager: natMgr,
	}

	maranetpb.RegisterGatewayServiceServer(grpcServer, s)
	return s, nil
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
func (s *Server) AddTunnel(ctx context.Context, req *maranetpb.AddTunnelRequest) (*maranetpb.AddTunnelResponse, error) {
	if err := s.wgManager.AddTunnel(req.NodeId, req.NodePublicKey, req.NodeEndpoint, req.AssignedSubnet); err != nil {
		return &maranetpb.AddTunnelResponse{Success: false, Error: err.Error()}, nil
	}

	gatewayKey, err := s.wgManager.GetPublicKey()
	if err != nil {
		return &maranetpb.AddTunnelResponse{Success: true, GatewayEndpoint: "", Error: "tunnel added but failed to read gateway key"}, nil
	}

	return &maranetpb.AddTunnelResponse{
		Success:         true,
		GatewayPublicKey: gatewayKey,
		GatewayEndpoint:  "",
	}, nil
}

// RemoveTunnel handles removing a node tunnel
func (s *Server) RemoveTunnel(ctx context.Context, req *maranetpb.RemoveTunnelRequest) (*maranetpb.RemoveTunnelResponse, error) {
	if tunnel, ok := s.wgManager.GetTunnel(req.NodeId); ok {
		s.natManager.RemoveNodeForwarding(tunnel.Subnet)
	}

	if err := s.wgManager.RemoveTunnel(req.NodeId, req.NodePublicKey); err != nil {
		return &maranetpb.RemoveTunnelResponse{Success: false, Error: err.Error()}, nil
	}

	return &maranetpb.RemoveTunnelResponse{Success: true}, nil
}

// GetStatus returns current gateway status
func (s *Server) GetStatus(ctx context.Context, _ *emptypb.Empty) (*maranetpb.GatewayStatus, error) {
	dev, err := s.wgManager.GetDeviceInfo()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get device info: %v", err)
	}

	var totalRx, totalTx int64
	for _, peer := range dev.Peers {
		totalRx += peer.ReceiveBytes
		totalTx += peer.TransmitBytes
	}

	return &maranetpb.GatewayStatus{
		ActiveTunnels: int32(s.wgManager.GetTunnelCount()),
		TotalBytesRx:  totalRx,
		TotalBytesTx:  totalTx,
		CpuUsage:      0,
		MemoryUsage:   0,
		UptimeSince:   timestamppb.Now(),
	}, nil
}

// GetTunnelStats returns statistics for a specific tunnel
func (s *Server) GetTunnelStats(ctx context.Context, req *maranetpb.TunnelStatsRequest) (*maranetpb.TunnelStatsResponse, error) {
	tunnel, ok := s.wgManager.GetTunnel(req.NodeId)
	if !ok {
		return nil, status.Errorf(codes.NotFound, "tunnel not found for node %s", req.NodeId)
	}

	peer, err := s.wgManager.GetPeerStats(tunnel.PublicKey.String())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get peer stats: %v", err)
	}

	return &maranetpb.TunnelStatsResponse{
		NodeId:        req.NodeId,
		BytesRx:       peer.ReceiveBytes,
		BytesTx:       peer.TransmitBytes,
		LastHandshake: timestamppb.New(peer.LastHandshakeTime),
		Connected:     true,
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
