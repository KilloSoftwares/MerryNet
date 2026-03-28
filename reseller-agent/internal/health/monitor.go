package health

import (
	"runtime"
	"time"

	log "github.com/sirupsen/logrus"

	"github.com/maranet/reseller-agent/internal/config"
)

// Metrics contains the health metrics reported to the main server
type Metrics struct {
	ActivePeers int
	CPUUsage    float64
	MemoryUsage float64
	BytesRx     int64
	BytesTx     int64
	Uptime      float64
}

// Monitor collects system health metrics
type Monitor struct {
	config    config.HealthConfig
	startTime time.Time
}

// NewMonitor creates a new health monitor
func NewMonitor(cfg config.HealthConfig) *Monitor {
	return &Monitor{
		config:    cfg,
		startTime: time.Now(),
	}
}

// CollectMetrics gathers current system metrics
func (m *Monitor) CollectMetrics() *Metrics {
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	// Calculate memory usage percentage (using Go runtime stats as approximation)
	memUsage := float64(memStats.Alloc) / float64(memStats.Sys) * 100

	// CPU usage approximation via goroutine count
	cpuUsage := float64(runtime.NumGoroutine()) / float64(runtime.NumCPU()) * 10

	uptime := time.Since(m.startTime).Seconds()

	metrics := &Metrics{
		CPUUsage:    cpuUsage,
		MemoryUsage: memUsage,
		Uptime:      uptime,
	}

	log.Debugf("Health metrics: cpu=%.1f%%, mem=%.1f%%, uptime=%.0fs",
		metrics.CPUUsage, metrics.MemoryUsage, metrics.Uptime)

	return metrics
}
