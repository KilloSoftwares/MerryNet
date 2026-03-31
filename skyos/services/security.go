package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/KilloSoftwares/MerryNet/skyos/core"
)

// SecurityService handles security operations for Maranet
type SecurityService struct {
	name          string
	kernel        *core.Kernel
	policies      map[string]*SecurityPolicy
	auditLog      []AuditEntry
	certificates  map[string]*Certificate
	mu            sync.RWMutex
	ctx           context.Context
	cancel        context.CancelFunc
}

// SecurityPolicy represents a security policy
type SecurityPolicy struct {
	ID          string
	Name        string
	Type        string // "firewall", "access", "encryption"
	Description string
	Rules       []SecurityRule
	Enabled     bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// SecurityRule represents a security rule
type SecurityRule struct {
	ID          string
	Name        string
	Action      string // "allow", "deny", "log"
	Source      string
	Destination string
	Port        int
	Protocol    string
	Enabled     bool
	Priority    int
}

// AuditEntry represents a security audit log entry
type AuditEntry struct {
	ID        string
	Timestamp time.Time
	Level     string // "info", "warning", "error", "critical"
	Event     string
	Source    string
	Target    string
	Message   string
	Metadata  map[string]interface{}
}

// Certificate represents a security certificate
type Certificate struct {
	ID          string
	Name        string
	Type        string // "client", "server", "ca"
	PublicKey   string
	PrivateKey  string
	Subject     string
	Issuer      string
	ValidFrom   time.Time
	ValidTo     time.Time
	Fingerprint string
	Status      string // "valid", "expired", "revoked"
}

// NewSecurityService creates a new security service
func NewSecurityService(kernel *core.Kernel) *SecurityService {
	return &SecurityService{
		name:         "security-service",
		kernel:       kernel,
		policies:     make(map[string]*SecurityPolicy),
		auditLog:     make([]AuditEntry, 0),
		certificates: make(map[string]*Certificate),
	}
}

// Name returns the service name
func (ss *SecurityService) Name() string {
	return ss.name
}

// Start initializes the security service
func (ss *SecurityService) Start(ctx context.Context) error {
	ss.ctx, ss.cancel = context.WithCancel(ctx)
	logrus.Info("Starting Security Service...")

	// Initialize default security policies
	if err := ss.initializeDefaultPolicies(); err != nil {
		return fmt.Errorf("failed to initialize default policies: %v", err)
	}

	// Initialize certificates
	if err := ss.initializeCertificates(); err != nil {
		return fmt.Errorf("failed to initialize certificates: %v", err)
	}

	// Start security monitoring
	go ss.monitorSecurity()

	logrus.Info("Security Service started successfully")
	return nil
}

// Stop gracefully shuts down the security service
func (ss *SecurityService) Stop() error {
	if ss.cancel != nil {
		ss.cancel()
	}
	logrus.Info("Security Service stopped")
	return nil
}

// HandleMessage processes incoming messages
func (ss *SecurityService) HandleMessage(msg core.Message) error {
	switch msg.Type {
	case "security.policy.create":
		return ss.handlePolicyCreate(msg)
	case "security.policy.update":
		return ss.handlePolicyUpdate(msg)
	case "security.policy.delete":
		return ss.handlePolicyDelete(msg)
	case "security.policy.list":
		return ss.handlePolicyList(msg)
	case "security.audit.query":
		return ss.handleAuditQuery(msg)
	case "security.certificate.generate":
		return ss.handleCertificateGenerate(msg)
	case "security.certificate.revoke":
		return ss.handleCertificateRevoke(msg)
	case "security.event":
		return ss.handleSecurityEvent(msg)
	default:
		return fmt.Errorf("unknown message type: %s", msg.Type)
	}
}

// initializeDefaultPolicies sets up default security policies
func (ss *SecurityService) initializeDefaultPolicies() error {
	// Default firewall policy
	firewallPolicy := &SecurityPolicy{
		ID:          generateSecurityID("policy"),
		Name:        "Default Firewall Policy",
		Type:        "firewall",
		Description: "Default firewall policy for Maranet",
		Enabled:     true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
		Rules: []SecurityRule{
			{
				ID:       generateSecurityID("rule"),
				Name:     "Allow SSH",
				Action:   "allow",
				Source:   "any",
				Port:     22,
				Protocol: "tcp",
				Enabled:  true,
				Priority: 100,
			},
			{
				ID:       generateSecurityID("rule"),
				Name:     "Allow VPN",
				Action:   "allow",
				Source:   "any",
				Port:     51820,
				Protocol: "udp",
				Enabled:  true,
				Priority: 90,
			},
			{
				ID:       generateSecurityID("rule"),
				Name:     "Deny All",
				Action:   "deny",
				Source:   "any",
				Port:     0,
				Protocol: "any",
				Enabled:  true,
				Priority: 1,
			},
		},
	}

	ss.mu.Lock()
	ss.policies[firewallPolicy.ID] = firewallPolicy
	ss.mu.Unlock()

	logrus.Info("Initialized default security policies")
	return nil
}

// initializeCertificates sets up initial certificates
func (ss *SecurityService) initializeCertificates() error {
	// Generate default CA certificate
	caCert := &Certificate{
		ID:          generateSecurityID("cert"),
		Name:        "Maranet Root CA",
		Type:        "ca",
		Subject:     "CN=Maranet Root CA, O=Maranet",
		Issuer:      "CN=Maranet Root CA, O=Maranet",
		ValidFrom:   time.Now(),
		ValidTo:     time.Now().AddDate(10, 0, 0), // 10 years
		Status:      "valid",
		Fingerprint: generateFingerprint("Maranet Root CA"),
	}

	ss.mu.Lock()
	ss.certificates[caCert.ID] = caCert
	ss.mu.Unlock()

	logrus.Info("Initialized security certificates")
	return nil
}

// monitorSecurity continuously monitors security status
func (ss *SecurityService) monitorSecurity() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ss.ctx.Done():
			return
		case <-ticker.C:
			ss.performSecurityChecks()
		}
	}
}

// performSecurityChecks performs periodic security checks
func (ss *SecurityService) performSecurityChecks() {
	// Check certificate expiration
	ss.checkCertificateExpiration()

	// Check policy compliance
	ss.checkPolicyCompliance()

	// Generate security status report
	ss.generateSecurityReport()
}

// handlePolicyCreate handles security policy creation
func (ss *SecurityService) handlePolicyCreate(msg core.Message) error {
	policyData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid policy data")
	}

	policy := &SecurityPolicy{
		ID:          generateSecurityID("policy"),
		Name:        policyData["name"].(string),
		Type:        policyData["type"].(string),
		Description: policyData["description"].(string),
		Enabled:     true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Parse rules if provided
	if rulesData, ok := policyData["rules"].([]interface{}); ok {
		policy.Rules = ss.parseSecurityRules(rulesData)
	}

	ss.mu.Lock()
	ss.policies[policy.ID] = policy
	ss.mu.Unlock()

	logrus.Infof("Created security policy: %s", policy.Name)

	// Log audit entry
	ss.logAuditEvent("policy.created", ss.name, policy.Name, "Security policy created", map[string]interface{}{
		"policy_id": policy.ID,
		"type":      policy.Type,
	})

	return nil
}

// handlePolicyUpdate handles security policy updates
func (ss *SecurityService) handlePolicyUpdate(msg core.Message) error {
	updateData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid update data")
	}

	policyID, ok := updateData["policy_id"].(string)
	if !ok {
		return fmt.Errorf("policy ID required")
	}

	ss.mu.Lock()
	defer ss.mu.Unlock()

	policy, exists := ss.policies[policyID]
	if !exists {
		return fmt.Errorf("policy %s not found", policyID)
	}

	// Update policy fields
	if name, ok := updateData["name"].(string); ok {
		policy.Name = name
	}
	if description, ok := updateData["description"].(string); ok {
		policy.Description = description
	}
	if enabled, ok := updateData["enabled"].(bool); ok {
		policy.Enabled = enabled
	}
	if rulesData, ok := updateData["rules"].([]interface{}); ok {
		policy.Rules = ss.parseSecurityRules(rulesData)
	}

	policy.UpdatedAt = time.Now()

	logrus.Infof("Updated security policy: %s", policy.Name)

	// Log audit entry
	ss.logAuditEvent("policy.updated", ss.name, policy.Name, "Security policy updated", map[string]interface{}{
		"policy_id": policy.ID,
	})

	return nil
}

// handlePolicyDelete handles security policy deletion
func (ss *SecurityService) handlePolicyDelete(msg core.Message) error {
	policyID, ok := msg.Payload.(string)
	if !ok {
		return fmt.Errorf("policy ID required")
	}

	ss.mu.Lock()
	defer ss.mu.Unlock()

	policy, exists := ss.policies[policyID]
	if !exists {
		return fmt.Errorf("policy %s not found", policyID)
	}

	delete(ss.policies, policyID)

	logrus.Infof("Deleted security policy: %s", policy.Name)

	// Log audit entry
	ss.logAuditEvent("policy.deleted", ss.name, policy.Name, "Security policy deleted", map[string]interface{}{
		"policy_id": policyID,
	})

	return nil
}

// handlePolicyList handles security policy list requests
func (ss *SecurityService) handlePolicyList(msg core.Message) error {
	policies := ss.getPolicyList()

	response := core.Message{
		Type:    "security.policy.list.response",
		From:    ss.name,
		To:      msg.From,
		Payload: policies,
	}

	return ss.kernel.SendMessage(response)
}

// handleAuditQuery handles audit log queries
func (ss *SecurityService) handleAuditQuery(msg core.Message) error {
	query, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid audit query")
	}

	auditEntries := ss.queryAuditLog(query)

	response := core.Message{
		Type:    "security.audit.query.response",
		From:    ss.name,
		To:      msg.From,
		Payload: auditEntries,
	}

	return ss.kernel.SendMessage(response)
}

// handleCertificateGenerate handles certificate generation
func (ss *SecurityService) handleCertificateGenerate(msg core.Message) error {
	certData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid certificate data")
	}

	certType, ok := certData["type"].(string)
	if !ok {
		return fmt.Errorf("certificate type required")
	}

	name, ok := certData["name"].(string)
	if !ok {
		return fmt.Errorf("certificate name required")
	}

	cert := &Certificate{
		ID:          generateSecurityID("cert"),
		Name:        name,
		Type:        certType,
		Subject:     fmt.Sprintf("CN=%s, O=Maranet", name),
		Issuer:      "CN=Maranet Root CA, O=Maranet",
		ValidFrom:   time.Now(),
		ValidTo:     time.Now().AddDate(1, 0, 0), // 1 year
		Status:      "valid",
		Fingerprint: generateFingerprint(name),
	}

	ss.mu.Lock()
	ss.certificates[cert.ID] = cert
	ss.mu.Unlock()

	logrus.Infof("Generated security certificate: %s", name)

	// Log audit entry
	ss.logAuditEvent("certificate.generated", ss.name, name, "Security certificate generated", map[string]interface{}{
		"certificate_id": cert.ID,
		"type":           cert.Type,
	})

	return nil
}

// handleCertificateRevoke handles certificate revocation
func (ss *SecurityService) handleCertificateRevoke(msg core.Message) error {
	certID, ok := msg.Payload.(string)
	if !ok {
		return fmt.Errorf("certificate ID required")
	}

	ss.mu.Lock()
	defer ss.mu.Unlock()

	cert, exists := ss.certificates[certID]
	if !exists {
		return fmt.Errorf("certificate %s not found", certID)
	}

	cert.Status = "revoked"

	logrus.Infof("Revoked security certificate: %s", cert.Name)

	// Log audit entry
	ss.logAuditEvent("certificate.revoked", ss.name, cert.Name, "Security certificate revoked", map[string]interface{}{
		"certificate_id": certID,
	})

	return nil
}

// handleSecurityEvent handles security events
func (ss *SecurityService) handleSecurityEvent(msg core.Message) error {
	eventData, ok := msg.Payload.(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid security event data")
	}

	level, _ := eventData["level"].(string)
	event, _ := eventData["event"].(string)
	source, _ := eventData["source"].(string)
	target, _ := eventData["target"].(string)
	message, _ := eventData["message"].(string)
	metadata, _ := eventData["metadata"].(map[string]interface{})

	ss.logAuditEvent(event, source, target, message, metadata)

	// Handle critical security events
	if level == "critical" {
		ss.handleCriticalSecurityEvent(event, source, target, message, metadata)
	}

	return nil
}

// parseSecurityRules parses security rules from interface{} data
func (ss *SecurityService) parseSecurityRules(rulesData []interface{}) []SecurityRule {
	rules := make([]SecurityRule, 0, len(rulesData))

	for _, ruleData := range rulesData {
		if ruleMap, ok := ruleData.(map[string]interface{}); ok {
			rule := SecurityRule{
				ID:       generateSecurityID("rule"),
				Name:     ruleMap["name"].(string),
				Action:   ruleMap["action"].(string),
				Source:   ruleMap["source"].(string),
				Port:     int(ruleMap["port"].(float64)),
				Protocol: ruleMap["protocol"].(string),
				Enabled:  ruleMap["enabled"].(bool),
				Priority: int(ruleMap["priority"].(float64)),
			}

			if destination, ok := ruleMap["destination"].(string); ok {
				rule.Destination = destination
			}

			rules = append(rules, rule)
		}
	}

	return rules
}

// logAuditEvent logs a security audit event
func (ss *SecurityService) logAuditEvent(event, source, target, message string, metadata map[string]interface{}) {
	entry := AuditEntry{
		ID:        generateSecurityID("audit"),
		Timestamp: time.Now(),
		Level:     "info",
		Event:     event,
		Source:    source,
		Target:    target,
		Message:   message,
		Metadata:  metadata,
	}

	ss.mu.Lock()
	ss.auditLog = append(ss.auditLog, entry)
	ss.mu.Unlock()

	// Keep audit log size manageable
	if len(ss.auditLog) > 10000 {
		ss.auditLog = ss.auditLog[len(ss.auditLog)-10000:]
	}

	logrus.WithFields(logrus.Fields{
		"event":   event,
		"source":  source,
		"target":  target,
		"message": message,
	}).Info("Security audit event")
}

// queryAuditLog queries the audit log
func (ss *SecurityService) queryAuditLog(query map[string]interface{}) []AuditEntry {
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	// Simple query implementation - could be enhanced with filters
	results := make([]AuditEntry, 0)

	// Apply filters based on query parameters
	for _, entry := range ss.auditLog {
		if level, ok := query["level"].(string); ok && entry.Level != level {
			continue
		}
		if event, ok := query["event"].(string); ok && entry.Event != event {
			continue
		}
		if source, ok := query["source"].(string); ok && entry.Source != source {
			continue
		}

		results = append(results, entry)
	}

	return results
}

// checkCertificateExpiration checks for expired certificates
func (ss *SecurityService) checkCertificateExpiration() {
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	now := time.Now()
	for _, cert := range ss.certificates {
		if cert.Status == "valid" && now.After(cert.ValidTo) {
			cert.Status = "expired"
			ss.logAuditEvent("certificate.expired", ss.name, cert.Name, "Certificate expired", map[string]interface{}{
				"certificate_id": cert.ID,
			})
		}
	}
}

// checkPolicyCompliance checks policy compliance
func (ss *SecurityService) checkPolicyCompliance() {
	// Check if all required policies are enabled
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	for _, policy := range ss.policies {
		if !policy.Enabled {
			ss.logAuditEvent("policy.disabled", ss.name, policy.Name, "Security policy is disabled", map[string]interface{}{
				"policy_id": policy.ID,
			})
		}
	}
}

// generateSecurityReport generates a security status report
func (ss *SecurityService) generateSecurityReport() {
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	totalPolicies := len(ss.policies)
	enabledPolicies := 0
	for _, policy := range ss.policies {
		if policy.Enabled {
			enabledPolicies++
		}
	}

	totalCertificates := len(ss.certificates)
	validCertificates := 0
	expiredCertificates := 0
	for _, cert := range ss.certificates {
		switch cert.Status {
		case "valid":
			validCertificates++
		case "expired":
			expiredCertificates++
		}
	}

	logrus.WithFields(logrus.Fields{
		"total_policies":       totalPolicies,
		"enabled_policies":   enabledPolicies,
		"total_certificates": totalCertificates,
		"valid_certificates": validCertificates,
		"expired_certificates": expiredCertificates,
		"audit_entries":      len(ss.auditLog),
	}).Info("Security status report")
}

// handleCriticalSecurityEvent handles critical security events
func (ss *SecurityService) handleCriticalSecurityEvent(event, source, target, message string, metadata map[string]interface{}) {
	logrus.WithFields(logrus.Fields{
		"event":    event,
		"source":   source,
		"target":   target,
		"message":  message,
		"metadata": metadata,
	}).Error("Critical security event detected")

	// Could trigger automated responses like:
	// - Block source IP
	// - Disable affected services
	// - Send alerts
	// - Initiate incident response
}

// getPolicyList returns a list of security policies
func (ss *SecurityService) getPolicyList() []map[string]interface{} {
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	policies := make([]map[string]interface{}, 0, len(ss.policies))
	for _, policy := range ss.policies {
		policyInfo := map[string]interface{}{
			"id":          policy.ID,
			"name":        policy.Name,
			"type":        policy.Type,
			"description": policy.Description,
			"enabled":     policy.Enabled,
			"created_at":  policy.CreatedAt,
			"updated_at":  policy.UpdatedAt,
			"rule_count":  len(policy.Rules),
		}
		policies = append(policies, policyInfo)
	}

	return policies
}

// generateSecurityID generates a unique security ID
func generateSecurityID(prefix string) string {
	return fmt.Sprintf("%s-%s-%d", prefix, generateRandomString(8), time.Now().UnixNano())
}

// generateRandomString generates a random string
func generateRandomString(length int) string {
	bytes := make([]byte, length/2)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

// generateFingerprint generates a certificate fingerprint
func generateFingerprint(name string) string {
	hash := sha256.Sum256([]byte(name))
	return hex.EncodeToString(hash[:])
}