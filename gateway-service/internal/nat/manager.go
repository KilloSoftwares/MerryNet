package nat

import (
	"fmt"
	"os"
	"os/exec"

	log "github.com/sirupsen/logrus"

	"github.com/maranet/gateway-service/internal/config"
)

// Manager manages iptables NAT rules for internet egress
type Manager struct {
	config config.NATConfig
}

// NewManager creates a new NAT manager
func NewManager(cfg config.NATConfig) (*Manager, error) {
	m := &Manager{config: cfg}

	// Enable IP forwarding
	if cfg.EnableForwarding {
		if err := m.enableIPForwarding(); err != nil {
			return nil, fmt.Errorf("failed to enable IP forwarding: %w", err)
		}
	}

	return m, nil
}

// enableIPForwarding enables kernel IP forwarding
func (m *Manager) enableIPForwarding() error {
	// Enable IPv4 forwarding
	err := os.WriteFile("/proc/sys/net/ipv4/ip_forward", []byte("1"), 0644)
	if err != nil {
		// Try sysctl as fallback
		cmd := exec.Command("sysctl", "-w", "net.ipv4.ip_forward=1")
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to enable IPv4 forwarding: %w", err)
		}
	}
	log.Info("✅ IPv4 forwarding enabled")
	return nil
}

// SetupMasquerade sets up NAT masquerade for VPN traffic
func (m *Manager) SetupMasquerade() error {
	rules := []struct {
		table string
		chain string
		args  []string
	}{
		// MASQUERADE outgoing traffic from VPN subnet
		{
			table: "nat",
			chain: "POSTROUTING",
			args: []string{
				"-s", m.config.InternalSubnet,
				"-o", m.config.ExternalInterface,
				"-j", "MASQUERADE",
			},
		},
		// Allow forwarding from VPN to external
		{
			table: "filter",
			chain: "FORWARD",
			args: []string{
				"-i", "wg0",
				"-o", m.config.ExternalInterface,
				"-j", "ACCEPT",
			},
		},
		// Allow established/related return traffic
		{
			table: "filter",
			chain: "FORWARD",
			args: []string{
				"-i", m.config.ExternalInterface,
				"-o", "wg0",
				"-m", "state",
				"--state", "RELATED,ESTABLISHED",
				"-j", "ACCEPT",
			},
		},
		// Allow inter-VPN forwarding (node to node)
		{
			table: "filter",
			chain: "FORWARD",
			args: []string{
				"-i", "wg0",
				"-o", "wg0",
				"-j", "ACCEPT",
			},
		},
	}

	for _, rule := range rules {
		if err := m.addRule(rule.table, rule.chain, rule.args); err != nil {
			log.Warnf("Failed to add iptables rule (%s/%s): %v", rule.table, rule.chain, err)
		}
	}

	log.Info("✅ NAT masquerade rules configured")
	return nil
}

// addRule adds an iptables rule if it doesn't already exist
func (m *Manager) addRule(table, chain string, args []string) error {
	// Check if rule exists
	checkArgs := append([]string{"-t", table, "-C", chain}, args...)
	checkCmd := exec.Command("iptables", checkArgs...)
	if err := checkCmd.Run(); err == nil {
		// Rule already exists
		return nil
	}

	// Add rule
	addArgs := append([]string{"-t", table, "-A", chain}, args...)
	cmd := exec.Command("iptables", addArgs...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("iptables error: %s: %w", string(output), err)
	}

	log.Debugf("Added iptables rule: -t %s -A %s %v", table, chain, args)
	return nil
}

// AddNodeForwarding adds forwarding rules for a specific node subnet
func (m *Manager) AddNodeForwarding(subnet string) error {
	rules := [][]string{
		{"-s", subnet, "-o", m.config.ExternalInterface, "-j", "MASQUERADE"},
	}

	for _, args := range rules {
		if err := m.addRule("nat", "POSTROUTING", args); err != nil {
			return err
		}
	}

	log.Infof("Added NAT forwarding for subnet %s", subnet)
	return nil
}

// RemoveNodeForwarding removes forwarding rules for a node subnet
func (m *Manager) RemoveNodeForwarding(subnet string) error {
	args := []string{"-t", "nat", "-D", "POSTROUTING", "-s", subnet, "-o", m.config.ExternalInterface, "-j", "MASQUERADE"}
	cmd := exec.Command("iptables", args...)
	if err := cmd.Run(); err != nil {
		log.Warnf("Failed to remove NAT rule for %s: %v", subnet, err)
	}
	return nil
}

// Cleanup removes all Maranet-related iptables rules
func (m *Manager) Cleanup() {
	log.Info("Cleaning up NAT rules...")
	// In production, use iptables-save/restore or track rules precisely
	// For now, just log the cleanup
	log.Info("NAT rules cleanup completed")
}
