package identity

import (
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"io"
	"net"
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
// It will try to use MAC address as seed first, falling back to random if MAC is unavailable
func createIdentity(path string) (crypto.PrivKey, error) {
	// Try to get MAC address first
	macAddr, err := getPrimaryMACAddress()
	if err == nil && macAddr != "" {
		fmt.Printf("📍 Using MAC address (%s) as seed for consistent Peer ID\n", macAddr)
		priv, err := createIdentityFromMAC(macAddr)
		if err == nil {
			// Save to file
			data, err := crypto.MarshalPrivateKey(priv)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal private key: %w", err)
			}

			if err := os.WriteFile(path, data, 0600); err != nil {
				return nil, fmt.Errorf("failed to write identity file: %w", err)
			}

			return priv, nil
		}
		fmt.Printf("⚠️  Failed to generate key from MAC: %v, falling back to random\n", err)
	} else {
		fmt.Printf("⚠️  MAC address not available: %v, using random key\n", err)
	}

	// Fallback: Generate new Ed25519 key pair with random seed
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

// getPrimaryMACAddress returns the MAC address of the primary network interface
func getPrimaryMACAddress() (string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", fmt.Errorf("failed to get network interfaces: %w", err)
	}

	// Look for the first non-loopback interface with a valid MAC address
	for _, iface := range interfaces {
		// Skip loopback, down interfaces, and those without MAC addresses
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 || len(iface.HardwareAddr) == 0 {
			continue
		}

		// Return the MAC address of the first suitable interface
		return iface.HardwareAddr.String(), nil
	}

	return "", fmt.Errorf("no suitable network interface found")
}

// createIdentityFromMAC creates a deterministic private key from MAC address
func createIdentityFromMAC(macAddr string) (crypto.PrivKey, error) {
	// Create a deterministic seed from MAC address using SHA-256
	// This ensures the same MAC address always generates the same peer ID
	hash := sha256.New()
	hash.Write([]byte(macAddr))
	hash.Write([]byte("p2p-chat-identity-seed-v1")) // Add salt for domain separation
	seed := hash.Sum(nil)

	// Use the hash as a deterministic random source
	seedReader := &deterministicReader{seed: seed}

	// Generate Ed25519 key pair from deterministic seed
	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.Ed25519, 2048, seedReader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate keypair from MAC: %w", err)
	}

	return priv, nil
}

// deterministicReader provides deterministic random bytes from a seed
type deterministicReader struct {
	seed  []byte
	index int
}

func (r *deterministicReader) Read(p []byte) (n int, err error) {
	// Generate bytes by repeatedly hashing seed with counter
	for i := range p {
		if r.index%32 == 0 {
			// Create new hash with seed and counter
			hash := sha256.New()
			hash.Write(r.seed)
			hash.Write([]byte{byte(r.index / 32)})
			r.seed = hash.Sum(nil)
		}
		p[i] = r.seed[r.index%32]
		r.index++
	}
	return len(p), nil
}
