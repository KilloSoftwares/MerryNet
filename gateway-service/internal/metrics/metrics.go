package metrics

import (
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

var (
	// ActiveTunnels tracks the number of active tunnels
	ActiveTunnels = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "maranet_gateway_active_tunnels",
		Help: "Number of active WireGuard tunnels to reseller nodes",
	})

	// TotalBytesReceived tracks total bytes received
	TotalBytesReceived = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "maranet_gateway_bytes_received_total",
		Help: "Total bytes received through the gateway",
	})

	// TotalBytesSent tracks total bytes sent
	TotalBytesSent = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "maranet_gateway_bytes_sent_total",
		Help: "Total bytes sent through the gateway",
	})

	// GRPCRequestsTotal tracks gRPC requests
	GRPCRequestsTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "maranet_gateway_grpc_requests_total",
		Help: "Total gRPC requests by method and status",
	}, []string{"method", "status"})

	// GRPCRequestDuration tracks gRPC request latency
	GRPCRequestDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "maranet_gateway_grpc_request_duration_seconds",
		Help:    "gRPC request duration in seconds",
		Buckets: prometheus.DefBuckets,
	}, []string{"method"})

	// TunnelAddedTotal tracks tunnels added
	TunnelAddedTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "maranet_gateway_tunnels_added_total",
		Help: "Total tunnels added since start",
	})

	// TunnelRemovedTotal tracks tunnels removed
	TunnelRemovedTotal = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "maranet_gateway_tunnels_removed_total",
		Help: "Total tunnels removed since start",
	})
)

func init() {
	prometheus.MustRegister(
		ActiveTunnels,
		TotalBytesReceived,
		TotalBytesSent,
		GRPCRequestsTotal,
		GRPCRequestDuration,
		TunnelAddedTotal,
		TunnelRemovedTotal,
	)
}

// Server serves Prometheus metrics
type Server struct {
	port int
}

// NewServer creates a new metrics server
func NewServer(port int) *Server {
	return &Server{port: port}
}

// Start starts the metrics HTTP server
func (s *Server) Start() error {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	addr := fmt.Sprintf(":%d", s.port)
	log.Infof("Metrics server starting on %s", addr)
	return http.ListenAndServe(addr, mux)
}
