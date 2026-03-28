package store

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "github.com/mattn/go-sqlite3"
	log "github.com/sirupsen/logrus"
)

// Store is the SQLite database for the reseller agent
type Store struct {
	db *sql.DB
}

// PeerRecord represents a peer stored in the database
type PeerRecord struct {
	PublicKey      string
	UserID         string
	SubscriptionID string
	AllowedIP      string
	ExpiresAt      time.Time
	CreatedAt      time.Time
}

// NewStore creates a new SQLite store
func NewStore(dbPath string) (*Store, error) {
	// Create directory if needed
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create database directory: %w", err)
	}

	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	store := &Store{db: db}
	if err := store.migrate(); err != nil {
		return nil, fmt.Errorf("failed to migrate database: %w", err)
	}

	return store, nil
}

// migrate creates the database schema
func (s *Store) migrate() error {
	schema := `
	CREATE TABLE IF NOT EXISTS peers (
		public_key TEXT PRIMARY KEY,
		user_id TEXT NOT NULL,
		subscription_id TEXT NOT NULL,
		allowed_ip TEXT NOT NULL,
		expires_at DATETIME NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_peers_expires_at ON peers(expires_at);
	CREATE INDEX IF NOT EXISTS idx_peers_user_id ON peers(user_id);

	CREATE TABLE IF NOT EXISTS node_state (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS command_log (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		command_id TEXT NOT NULL,
		command_type TEXT NOT NULL,
		payload TEXT,
		status TEXT DEFAULT 'pending',
		result TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		completed_at DATETIME
	);

	CREATE INDEX IF NOT EXISTS idx_command_log_status ON command_log(status);
	`

	_, err := s.db.Exec(schema)
	return err
}

// Close closes the database
func (s *Store) Close() error {
	return s.db.Close()
}

// AddPeer stores a peer record
func (s *Store) AddPeer(peer *PeerRecord) error {
	_, err := s.db.Exec(
		`INSERT OR REPLACE INTO peers (public_key, user_id, subscription_id, allowed_ip, expires_at)
		 VALUES (?, ?, ?, ?, ?)`,
		peer.PublicKey, peer.UserID, peer.SubscriptionID, peer.AllowedIP, peer.ExpiresAt,
	)
	return err
}

// RemovePeer deletes a peer record
func (s *Store) RemovePeer(publicKey string) error {
	_, err := s.db.Exec(`DELETE FROM peers WHERE public_key = ?`, publicKey)
	return err
}

// GetPeer retrieves a peer by public key
func (s *Store) GetPeer(publicKey string) (*PeerRecord, error) {
	row := s.db.QueryRow(
		`SELECT public_key, user_id, subscription_id, allowed_ip, expires_at, created_at
		 FROM peers WHERE public_key = ?`, publicKey,
	)

	var p PeerRecord
	err := row.Scan(&p.PublicKey, &p.UserID, &p.SubscriptionID, &p.AllowedIP, &p.ExpiresAt, &p.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// GetExpiredPeers returns all peers whose subscription has expired
func (s *Store) GetExpiredPeers() []*PeerRecord {
	rows, err := s.db.Query(
		`SELECT public_key, user_id, subscription_id, allowed_ip, expires_at, created_at
		 FROM peers WHERE expires_at <= ?`, time.Now(),
	)
	if err != nil {
		log.Errorf("Failed to query expired peers: %v", err)
		return nil
	}
	defer rows.Close()

	var peers []*PeerRecord
	for rows.Next() {
		var p PeerRecord
		if err := rows.Scan(&p.PublicKey, &p.UserID, &p.SubscriptionID, &p.AllowedIP, &p.ExpiresAt, &p.CreatedAt); err != nil {
			log.Errorf("Failed to scan peer: %v", err)
			continue
		}
		peers = append(peers, &p)
	}
	return peers
}

// GetAllPeers returns all active peers
func (s *Store) GetAllPeers() []*PeerRecord {
	rows, err := s.db.Query(
		`SELECT public_key, user_id, subscription_id, allowed_ip, expires_at, created_at
		 FROM peers WHERE expires_at > ?`, time.Now(),
	)
	if err != nil {
		log.Errorf("Failed to query peers: %v", err)
		return nil
	}
	defer rows.Close()

	var peers []*PeerRecord
	for rows.Next() {
		var p PeerRecord
		if err := rows.Scan(&p.PublicKey, &p.UserID, &p.SubscriptionID, &p.AllowedIP, &p.ExpiresAt, &p.CreatedAt); err != nil {
			continue
		}
		peers = append(peers, &p)
	}
	return peers
}

// UpdatePeerExpiry updates a peer's expiration time
func (s *Store) UpdatePeerExpiry(publicKey string, newExpiry time.Time) error {
	_, err := s.db.Exec(
		`UPDATE peers SET expires_at = ? WHERE public_key = ?`,
		newExpiry, publicKey,
	)
	return err
}

// GetPeerCount returns the total number of active peers
func (s *Store) GetPeerCount() (int, error) {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM peers WHERE expires_at > ?`, time.Now()).Scan(&count)
	return count, err
}

// SetState stores a key-value pair in the node state table
func (s *Store) SetState(key, value string) error {
	_, err := s.db.Exec(
		`INSERT OR REPLACE INTO node_state (key, value, updated_at) VALUES (?, ?, ?)`,
		key, value, time.Now(),
	)
	return err
}

// GetState retrieves a value from the node state table
func (s *Store) GetState(key string) (string, error) {
	var value string
	err := s.db.QueryRow(`SELECT value FROM node_state WHERE key = ?`, key).Scan(&value)
	return value, err
}

// LogCommand records a command execution
func (s *Store) LogCommand(commandID, commandType, payload, status, result string) error {
	_, err := s.db.Exec(
		`INSERT INTO command_log (command_id, command_type, payload, status, result, completed_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		commandID, commandType, payload, status, result, time.Now(),
	)
	return err
}
