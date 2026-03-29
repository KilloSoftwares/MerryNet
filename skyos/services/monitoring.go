package services

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/KilloSoftwares/MerryNet/skyos/core"
)

// MonitoringService handles system monitoring for Maranet
type MonitoringService struct {
	name        string
	kernel      *core.Kernel
	metrics     map[string]*Metric
	alerts      []Alert
	components  map[string]*ComponentStatus
	mu          sync.RWMutex
	ctx         context.Context
	cancel      context.CancelFunc
}

// Metric represents a system metric
type Metric struct {
	Name        string
	Type        string // "counter", "gauge", "histogram"
	Value       float64
	Unit        string
	Timestamp   time.Time
	Tags        map[string]string
	Labels      map[string]string
	Description string
}

// Alert represents a monitoring alert
type Alert struct {
	ID          string
	Name        string
	Severity    string // "info", "warning", "critical"
	Status      string // "active", "resolved", "suppressed"
	Message     string
	Source      string
	Component   string
	Metric      string
	Threshold   float64
	Value       float64
	CreatedAt   time.Time
	ResolvedAt  *time.Time
	Labels      map[string]string
}

// ComponentStatus represents the status of a system component
type ComponentStatus struct {
	Name        string
	Type        string // "service", "node", "network", "storage"
	Status      string // "healthy", "degraded", "unhealthy", "unknown"
	Message     string
	LastCheck   time.Time
	Metrics     map[string]float64
	Labels      map[string]string
}

// NewMonitoringService creates a new monitoring service
func NewMonitoringService(kernel *core.Kernel) *MonitoringService {
	return &MonitoringService{
		name:       "monitoring-service",
		kernel:     kernel,
		metrics:    make(map[string]*Metric),
		alerts:     make([]Alert, 0),
		components: make(map[string]*ComponentStatus),
	}
}

// Name returns the service name
func (ms *MonitoringService) Name() string {
	return ms.name
}

// Start initializes the monitoring service
func (ms *MonitoringService) Start(ctx context.Context) error {
	ms.ctx, ms.cancel = context.WithCancel(ctx)
	logrus.Info("Starting Monitoring Service...")

	// Initialize system components
	if err := ms.initializeComponents(); err != nil {
		return fmt.Errorf("failed to initialize components: %v", err)
	}

	// Start metric collection
	go ms.collectMetrics()

	// Start alert processing
	go ms.processAlerts()

	logrus.Info("Monitoring Service started successfully")
	return nil
}

// Stop gracefully shuts down the monitoring service
func (ms *MonitoringService) Stop() error {
	if ms.cancel != nil {
		ms.cancel()
	}
	logrus.Info("Monitoring Service stopped")
	return nil
}

// HandleMessage processes incoming messages
func (ms *MonitoringService) HandleMessage(msg core.Message) error {
	switch msg.Type {
	case "monitoring.metric.record":
		return ms.handleMetricRecord(msg)
	case "monitoring.metric.query":
		return ms.handleMetricQuery(msg)
	case "monitoring.alert.create":
		return ms.handleAlertCreate(msg)
	case "monitoring.alert.resolve":
		return ms.handleAlertResolve(msg)
	case "monitoring.alert.list":
		return ms.handleAlertList(msg)
	case "monitoring.status.query":
		return ms.handleStatusQuery(msg)
	case "monitoring.component.update":
		return ms.handleComponentUpdate(msg)
	default:
		return fmt.Errorf("unknown message type: %s", msg.Type)
	}
}

// initializeComponents sets up initial system components
func (ms *MonitoringService) initializeComponents() error {
	// Initialize core system components
	components := []ComponentStatus{
		{
			Name:    "vpn-service",
			Type:    "service",
			Status:  "healthy",
			Message: "VPN service operational",
			Metrics: make(map[string]float64),
			Labels:  map[string]string{"service": "vpn", "tier": "core"},
		},
		{
			Name:    "security-service",
			Type:    "service",
			Status:  "healthy",
			Message: "Security service operational",
			Metrics: make(map[string]float64),
			Labels:  map[string]string{"service": "security", "tier": "core"},
		},
		{
			Name:    "network-service",
			Type:    "service",
			Status:  "healthy",
			Message: "Network service operational",
			Metrics: make(map[string]float64),
			Labels:  map[string]string{"service": "network", "tier": "core"},
		},
		{
			Name:    "gateway-service",
			Type:    "service",
			Status:  "healthy",
			Message: "Gateway service operational",
			Metrics: make(map[string]float64),
			Labels:  map[string]string{"service": "gateway", "tier": "infrastructure"},
		},
		{
			Name:    "main-server",
			Type:    "service",
			Status:  "healthy",
			Message: "Main server operational",
			Metrics: make(map[string]float64),
			Labels:  map[string]string{"service": "main", "tier": "application"},
		},
	}

	ms.mu.Lock()
	for _, component := range components {
		ms.components[component.Name] = &component
	}
	ms.mu.Unlock()

	logrus.Info("Initialized system components for monitoring")
	return nil
}

// collectMetrics continuously collects system metrics
func (ms *MonitoringService) collectMetrics() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ms.ctx.Done():
			return
		case <-ticker.C:
			ms.collectSystemMetrics()
		}
	}
}

// processAlerts continuously processes alerts
func (ms *MonitoringService) processAlerts() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ms.ctx.Done():
			return
		case <-ticker.C:
			ms.evaluateAlertRules()
		}
	}
}

// collectSystemMetrics collects system-wide metrics
func (ms *MonitoringService) collectSystemMetrics() {
	// Simulate system metrics collection
	// In a real implementation, this would gather actual system metrics

	// CPU usage metric
	cpuMetric := &Metric{
		Name:        "system.cpu.usage",
		Type:        "gauge",
		Value:       45.2, // Simulated CPU usage
		Unit:        "percent",
		Timestamp:   time.Now(),
		Tags:        map[string]string{"host": "maranet-node-1"},
		Description: "CPU usage percentage",
	}

	// Memory usage metric
	memoryMetric := &Metric{
		Name:        "system.memory.usage",
		Type:        "gauge",
		Value:       67.8, // Simulated memory usage
		Unit:        "percent",
		Timestamp:   time.Now(),
		Tags:        map[string]string{"host": "maranet-node-1"},
		Description: "Memory usage percentage",
	}

	// Network traffic metric
	networkMetric := &Metric{
		Name:        "system.network.bytes.total",
		Type:        "counter",
		Value:       1024 * 1024 * 100, // 100MB
		Unit:        "bytes",
		Timestamp:   time.Now(),
		Tags:        map[string]string{"host": "maranet-node-1", "interface": "eth0"},
		Description: "Total network bytes transmitted",
	}

	// VPN connections metric
	vpnMetric := &Metric{
		Name:        "vpn.connections.active",
		Type:        "gauge",
		Value:       15, // Simulated active connections
		Unit:        "count",
		Timestamp:   time.Now(),
		Tags:        map[string]string{"service": "vpn"},
		Description: "Number of active VPN connections",
	}

	ms.mu.Lock()
	ms.metrics[cpuMetric.Name] = cpuMetric
	ms.metrics[memoryMetric.Name] = memoryMetric
	ms.metrics[networkMetric.Name] = networkMetric
	ms.metrics[vpnMetric.Name] = vpnMetric
	ms.mu.Unlock()

	// Update component metrics
	ms.updateComponentMetrics()
}

// updateComponentMetrics updates component-specific metrics
func (ms *MonitoringService) updateComponentMetrics() {
	ms.mu.Lock()
	defer ms.mu.Unlock()

	// Update VPN service metrics
	if vpnComponent, exists := ms.components["vpn-service"]; exists {
		vpnComponent.Metrics["connections"] = 15
		vpnComponent.Metrics["bandwidth_usage"] = 75.5
		vpnComponent.Metrics["error_rate"] = 0.1
		vpnComponent.LastCheck = time.Now()
	}

	// Update security service metrics
	if securityComponent, exists := ms.components["security-service"]; exists {
		securityComponent.Metrics["policy_count"] = 5
		securityComponent.Metrics["certificate_count"] = 10
		securityComponent.Metrics["audit_events"] = 25
		securityComponent.LastCheck = time.Now()
	}

	// Update network service metrics
	if networkComponent, exists := ms.components["network-service"]; exists {
		networkComponent.Metrics["latency"] = 15.2
		networkComponent.Metrics["packet_loss"] = 0.05
		networkComponent.Metrics["throughput"] = 1000
		networkComponent.LastCheck = time.Now()
	}
}

// evaluateAlertRules evaluates alert rules and creates alerts
func (ms *MonitoringService) evaluateAlertRules() {
	ms.mu.Lock()
	defer ms.mu.Unlock()

	// Check CPU usage alert
	if cpuMetric, exists := ms.metrics["system.cpu.usage"]; exists {
		if cpuMetric.Value > 80 {
			alert := Alert{
				ID:        generateMonitoringID("alert"),
				Name:      "High CPU Usage",
				Severity:  "warning",
				Status:    "active",
				Message:   fmt.Sprintf("CPU usage is high: %.1f%%", cpuMetric.Value),
				Source:    "system",
				Component: "cpu",
				Metric:    "system.cpu.usage",
				Threshold: 80,
				Value:     cpuMetric.Value,
				CreatedAt: time.Now(),
				Labels:    map[string]string{"host": "maranet-node-1"},
			}
			ms.alerts = append(ms.alerts, alert)
			logrus.Warnf("Alert created: %s", alert.Message)
		}
	}

	// Check memory usage alert
	if memoryMetric, exists := ms.metrics["system.memory.usage"]; exists {
		if memoryMetric.Value > 85 {
			alert := Alert{
				ID:        generateMonitoringID("alert"),
				Name:      "High Memory Usage",
				Severity:  "critical",
				Status:    "active",
				Message:   fmt.Sprintf("Memory usage is critically high: %.1f%%", memoryMetric.Value),
				Source:    "system",
				Component: "memory",
				Metric:    "system.memory.usage",
				Threshold: 85,
				Value:     memoryMetric.Value,
				CreatedAt: time.Now(),
				Labels:    map[string]string{"host": "maranet-node-1"},
			}
			ms.alerts = append(ms.alerts, alert)
			logrus.Errorf("Critical alert created: %s", alert.Message)
		}
	}

	// Check VPN connection alerts
	if vpnMetric, exists := ms.metrics["vpn.connections.active"]; exists {
		if vpnMetric.Value < 5 {
			alert := Alert{
				ID:        generateMonitoringID("alert"),
				Name:      "Low VPN Connections",
				Severity:  "info",
				Status:    "active",
				Message:   fmt.Sprintf("VPN connections are low: %.0f active", vpnMetric.Value),
				Source:    "vpn",
				Component: "vpn-service",
				Metric:    "vpn.connections.active",
				Threshold: 5,
				Value:     vpnMetric.Value,
				CreatedAt: time.Now(),
				Labels:    map[string]string{"service": "vpn"},
			}
			ms.alerts = append(ms.alerts, alert)
			logrus.Infof("Alert created: %s", alert.Message)
		}
	}

	// Clean up old resolved alerts
	ms.cleanupOldAlerts()
}

// cleanupOldAlerts removes old resolved alerts
func (ms *MonitoringService) cleanupOldAlerts() {
	cutoff := time.Now().Add(-24 * time.Hour)
	activeAlerts := make([]Alert, 0)

	for _, alert := range ms.alerts {
		if alert.Status == "resolved" && alert.ResolvedAt != nil && alert.ResolvedAt.Before(cutoff) {
			continue // Skip old resolved alerts
		}
		activeAlerts = append(activeAlerts, alert)
	}

	ms.alerts = activeAlerts
}

// handleMetricRecord handles metric recording requests
func (ms *MonitoringService) handleMetricRecord(msg core.Message) error {
	metricData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid metric data")
	}

	metric := &Metric{
		Name:        metricData["name"].(string),
		Type:        metricData["type"].(string),
		Value:       metricData["value"].(float64),
		Unit:        metricData["unit"].(string),
		Timestamp:   time.Now(),
		Tags:        make(map[string]string),
		Description: metricData["description"].(string),
	}

	if tags, ok := metricData["tags"].(map[string]interface{}); ok {
		for k, v := range tags {
			if str, ok := v.(string); ok {
				metric.Tags[k] = str
			}
		}
	}

	ms.mu.Lock()
	ms.metrics[metric.Name] = metric
	ms.mu.Unlock()

	logrus.Infof("Recorded metric: %s = %.2f %s", metric.Name, metric.Value, metric.Unit)
	return nil
}

// handleMetricQuery handles metric query requests
func (ms *MonitoringService) handleMetricQuery(msg core.Message) error {
	query, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid query data")
	}

	metrics := ms.queryMetrics(query)

	response := core.Message{
		Type:    "monitoring.metric.query.response",
		From:    ms.name,
		To:      msg.From,
		Payload: metrics,
	}

	return ms.kernel.SendMessage(response)
}

// handleAlertCreate handles alert creation requests
func (ms *MonitoringService) handleAlertCreate(msg core.Message) error {
	alertData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid alert data")
	}

	alert := Alert{
		ID:        generateMonitoringID("alert"),
		Name:      alertData["name"].(string),
		Severity:  alertData["severity"].(string),
		Status:    "active",
		Message:   alertData["message"].(string),
		Source:    alertData["source"].(string),
		Component: alertData["component"].(string),
		Metric:    alertData["metric"].(string),
		Threshold: alertData["threshold"].(float64),
		Value:     alertData["value"].(float64),
		CreatedAt: time.Now(),
		Labels:    make(map[string]string),
	}

	if labels, ok := alertData["labels"].(map[string]interface{}); ok {
		for k, v := range labels {
			if str, ok := v.(string); ok {
				alert.Labels[k] = str
			}
		}
	}

	ms.mu.Lock()
	ms.alerts = append(ms.alerts, alert)
	ms.mu.Unlock()

	logrus.Warnf("Created alert: %s", alert.Message)
	return nil
}

// handleAlertResolve handles alert resolution requests
func (ms *MonitoringService) handleAlertResolve(msg core.Message) error {
	alertID, ok := msg.Payload.(string)
	if !ok {
		return fmt.Errorf("alert ID required")
	}

	ms.mu.Lock()
	defer ms.mu.Unlock()

	for i, alert := range ms.alerts {
		if alert.ID == alertID {
			now := time.Now()
			ms.alerts[i].Status = "resolved"
			ms.alerts[i].ResolvedAt = &now
			logrus.Infof("Resolved alert: %s", alert.Name)
			return nil
		}
	}

	return fmt.Errorf("alert %s not found", alertID)
}

// handleAlertList handles alert list requests
func (ms *MonitoringService) handleAlertList(msg core.Message) error {
	query, ok := msg.Payload.(map[string]interface{})
	if !ok {
		query = make(map[string]interface{})
	}

	alerts := ms.getAlertList(query)

	response := core.Message{
		Type:    "monitoring.alert.list.response",
		From:    ms.name,
		To:      msg.From,
		Payload: alerts,
	}

	return ms.kernel.SendMessage(response)
}

// handleStatusQuery handles status query requests
func (ms *MonitoringService) handleStatusQuery(msg core.Message) error {
	status := ms.getSystemStatus()

	response := core.Message{
		Type:    "monitoring.status.query.response",
		From:    ms.name,
		To:      msg.From,
		Payload: status,
	}

	return ms.kernel.SendMessage(response)
}

// handleComponentUpdate handles component status updates
func (ms *MonitoringService) handleComponentUpdate(msg core.Message) error {
	updateData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid component update data")
	}

	componentName, ok := updateData["component"].(string)
	if !ok {
		return fmt.Errorf("component name required")
	}

	ms.mu.Lock()
	defer ms.mu.Unlock()

	if component, exists := ms.components[componentName]; exists {
		if status, ok := updateData["status"].(string); ok {
			component.Status = status
		}
		if message, ok := updateData["message"].(string); ok {
			component.Message = message
		}
		if metrics, ok := updateData["metrics"].(map[string]interface{}); ok {
			for k, v := range metrics {
				if val, ok := v.(float64); ok {
					component.Metrics[k] = val
				}
			}
		}
		component.LastCheck = time.Now()
		logrus.Infof("Updated component %s status to %s", componentName, component.Status)
	}

	return nil
}

// queryMetrics queries metrics based on filters
func (ms *MonitoringService) queryMetrics(query map[string]interface{}) []map[string]interface{} {
	ms.mu.RLock()
	defer ms.mu.RUnlock()

	metrics := make([]map[string]interface{}, 0)

	for _, metric := range ms.metrics {
		// Apply filters
		if name, ok := query["name"].(string); ok && metric.Name != name {
			continue
		}
		if metricType, ok := query["type"].(string); ok && metric.Type != metricType {
			continue
		}

		metricData := map[string]interface{}{
			"name":        metric.Name,
			"type":        metric.Type,
			"value":       metric.Value,
			"unit":        metric.Unit,
			"timestamp":   metric.Timestamp,
			"tags":        metric.Tags,
			"description": metric.Description,
		}
		metrics = append(metrics, metricData)
	}

	return metrics
}

// getAlertList returns filtered alerts
func (ms *MonitoringService) getAlertList(query map[string]interface{}) []map[string]interface{} {
	ms.mu.RLock()
	defer ms.mu.RUnlock()

	alerts := make([]map[string]interface{}, 0)

	for _, alert := range ms.alerts {
		// Apply filters
		if severity, ok := query["severity"].(string); ok && alert.Severity != severity {
			continue
		}
		if status, ok := query["status"].(string); ok && alert.Status != status {
			continue
		}
		if source, ok := query["source"].(string); ok && alert.Source != source {
			continue
		}

		alertData := map[string]interface{}{
			"id":         alert.ID,
			"name":       alert.Name,
			"severity":   alert.Severity,
			"status":     alert.Status,
			"message":    alert.Message,
			"source":     alert.Source,
			"component":  alert.Component,
			"metric":     alert.Metric,
			"threshold":  alert.Threshold,
			"value":      alert.Value,
			"created_at": alert.CreatedAt,
			"labels":     alert.Labels,
		}
		if alert.ResolvedAt != nil {
			alertData["resolved_at"] = *alert.ResolvedAt
		}

		alerts = append(alerts, alertData)
	}

	return alerts
}

// getSystemStatus returns overall system status
func (ms *MonitoringService) getSystemStatus() map[string]interface{} {
	ms.mu.RLock()
	defer ms.mu.RUnlock()

	// Calculate overall system health
	healthyComponents := 0
	totalComponents := len(ms.components)
	for _, component := range ms.components {
		if component.Status == "healthy" {
			healthyComponents++
		}
	}

	// Count active alerts
	activeAlerts := 0
	criticalAlerts := 0
	for _, alert := range ms.alerts {
		if alert.Status == "active" {
			activeAlerts++
			if alert.Severity == "critical" {
				criticalAlerts++
			}
		}
	}

	overallStatus := "healthy"
	if criticalAlerts > 0 {
		overallStatus = "critical"
	} else if activeAlerts > 0 {
		overallStatus = "warning"
	} else if healthyComponents < totalComponents {
		overallStatus = "degraded"
	}

	status := map[string]interface{}{
		"overall_status":   overallStatus,
		"healthy_components": healthyComponents,
		"total_components": totalComponents,
		"active_alerts":    activeAlerts,
		"critical_alerts":  criticalAlerts,
		"timestamp":        time.Now(),
		"components":       ms.getComponentStatusList(),
	}

	return status
}

// getComponentStatusList returns component status list
func (ms *MonitoringService) getComponentStatusList() []map[string]interface{} {
	components := make([]map[string]interface{}, 0, len(ms.components))
	for _, component := range ms.components {
		componentData := map[string]interface{}{
			"name":       component.Name,
			"type":       component.Type,
			"status":     component.Status,
			"message":    component.Message,
			"last_check": component.LastCheck,
			"metrics":    component.Metrics,
			"labels":     component.Labels,
		}
		components = append(components, componentData)
	}
	return components
}

// generateMonitoringID generates a unique monitoring ID
func generateMonitoringID(prefix string) string {
	return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
}