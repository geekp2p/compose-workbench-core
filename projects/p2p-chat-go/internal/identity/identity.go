package identity

import (
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"

	"github.com/libp2p/go-libp2p/core/crypto"
)

const (
	// DefaultIdentityFile is the default filename for storing peer identity
	DefaultIdentityFile = "peer-identity.key"
	// DefaultDataDir is the default directory for storing data
	DefaultDataDir = "./data"
)

// GetOrCreateIdentity loads an existing identity from disk or creates a new one
// This ensures the peer ID remains consistent across restarts
func GetOrCreateIdentity(dataDir string) (crypto.PrivKey, error) {
	if dataDir == "" {
		dataDir = DefaultDataDir
	}

	// Ensure data directory exists
	if err := os.MkdirAll(dataDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	identityPath := filepath.Join(dataDir, DefaultIdentityFile)

	// Try to load existing identity
	if _, err := os.Stat(identityPath); err == nil {
		// File exists, load it
		return loadIdentity(identityPath)
	}

	// File doesn't exist, create new identity
	fmt.Println("🔑 Creating new peer identity...")
	priv, err := createIdentity(identityPath)
	if err != nil {
		return nil, err
	}
	fmt.Println("✓ Peer identity created and saved")
	return priv, nil
}

// loadIdentity loads a private key from disk
func loadIdentity(path string) (crypto.PrivKey, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read identity file: %w", err)
	}

	priv, err := crypto.UnmarshalPrivateKey(data)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal private key: %w", err)
	}

	fmt.Println("✓ Loaded existing peer identity")
	return priv, nil
}

// createIdentity creates a new private key and saves it to disk
func createIdentity(path string) (crypto.PrivKey, error) {
	// Generate new Ed25519 key pair
	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.Ed25519, 2048, rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate keypair: %w", err)
	}

	// Marshal private key to bytes
	data, err := crypto.MarshalPrivateKey(priv)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal private key: %w", err)
	}

	// Write to file with restricted permissions (owner read/write only)
	if err := os.WriteFile(path, data, 0600); err != nil {
		return nil, fmt.Errorf("failed to write identity file: %w", err)
	}

	return priv, nil
}
