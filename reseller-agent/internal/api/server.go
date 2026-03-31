package api

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	log "github.com/sirupsen/logrus"

	"github.com/maranet/reseller-agent/internal/config"
	"github.com/maranet/reseller-agent/internal/store"
	"github.com/maranet/reseller-agent/internal/wireguard"
)

type Server struct {
	cfg       config.LocalAPIConfig
	wgManager *wireguard.Manager
	db        *store.Store
	httpSrv   *http.Server
}

func NewServer(cfg config.LocalAPIConfig, wgManager *wireguard.Manager, db *store.Store) *Server {
	return &Server{
		cfg:       cfg,
		wgManager: wgManager,
		db:        db,
	}
}

func (s *Server) Start() error {
	if !s.cfg.Enabled {
		return nil
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/offline/connect", s.handleConnect)

	// Support basic health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	addr := fmt.Sprintf(":%d", s.cfg.Port)
	s.httpSrv = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	log.Infof("🌐 Local Offline API (Reseller Target) listening on %s", addr)
	return s.httpSrv.ListenAndServe()
}

func (s *Server) Stop(ctx context.Context) error {
	if s.httpSrv != nil {
		return s.httpSrv.Shutdown(ctx)
	}
	return nil
}

type ConnectRequest struct {
	Token          string `json:"token"`
	PublicKey      string `json:"public_key"`
	AllowedIP      string `json:"allowed_ip"`
	UserID         string `json:"user_id,omitempty"`         // Only respected if OpenMode is true
	SubscriptionID string `json:"subscription_id,omitempty"` // Only respected if OpenMode is true
}

func (s *Server) handleConnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ConnectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	var userID, subID string

	if s.cfg.OpenMode {
		log.Warnf("⚠️ OPEN MODE ENABLED: Bypassing JWT verification for client %s", req.AllowedIP)
		userID = req.UserID
		if userID == "" {
			userID = "guest-open-mode"
		}
		subID = req.SubscriptionID
		if subID == "" {
			subID = "open-sub"
		}
	} else {
		if s.cfg.PublicKey == "" {
			http.Error(w, "Offline mode not configured (missing public key)", http.StatusInternalServerError)
			return
		}

		// Parse EdDSA public key (base64 encoded)
		pubKeyBytes, err := base64.StdEncoding.DecodeString(s.cfg.PublicKey)
		if err != nil {
			http.Error(w, "Invalid configured public key", http.StatusInternalServerError)
			return
		}

		if len(pubKeyBytes) != ed25519.PublicKeySize {
			http.Error(w, "Invalid public key length", http.StatusInternalServerError)
			return
		}
		edKey := ed25519.PublicKey(pubKeyBytes)

		// Verify JWT using EdDSA
		token, err := jwt.Parse(req.Token, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodEd25519); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return edKey, nil
		})

		if err != nil || !token.Valid {
			log.Warnf("Invalid token received in offline mode: %v", err)
			http.Error(w, "Unauthorized: invalid signature or expired token", http.StatusUnauthorized)
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			http.Error(w, "Invalid token claims", http.StatusBadRequest)
			return
		}

		userID, _ = claims["user_id"].(string)
		subID, _ = claims["subscription_id"].(string)
	}
	
	// Add peer using JWT authorized access
	expiresAt := time.Now().Add(24 * time.Hour) // Default offline session length
	if err := s.wgManager.AddPeer(req.PublicKey, req.AllowedIP, userID, subID, expiresAt); err != nil {
		log.Errorf("Failed to add offline peer to WG: %v", err)
		http.Error(w, "Failed to provision wireguard interface", http.StatusInternalServerError)
		return
	}

	if err := s.db.AddPeer(&store.PeerRecord{
		PublicKey:      req.PublicKey,
		UserID:         userID,
		SubscriptionID: subID,
		AllowedIP:      req.AllowedIP,
		ExpiresAt:      expiresAt,
	}); err != nil {
		log.Errorf("Failed to store offline peer: %v", err)
	}

	log.Infof("🚀 Offline peer connected autonomously: %s (IP: %s)", userID, req.AllowedIP)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "connected"})
}
