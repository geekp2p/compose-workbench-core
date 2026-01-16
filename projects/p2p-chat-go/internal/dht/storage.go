package dht

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/ipfs/go-cid"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	mh "github.com/multiformats/go-multihash"
)

// StorageMessage represents a message stored in DHT
type StorageMessage struct {
	Type      string `json:"type"`
	Content   string `json:"content"`
	Username  string `json:"username"`
	Timestamp int64  `json:"timestamp"`
	From      string `json:"from"`
	TTL       int64  `json:"ttl"` // Time-to-live in seconds
}

// DistributedStorage handles DHT-based distributed storage
type DistributedStorage struct {
	ctx     context.Context
	host    host.Host
	dht     *dht.IpfsDHT
	cache   map[string]*StorageMessage // Local cache
	maxTTL  int64                      // Maximum TTL (24 hours default)
	verbose bool
}

// NewDistributedStorage creates a new distributed storage instance
func NewDistributedStorage(ctx context.Context, h host.Host, dhtInstance *dht.IpfsDHT, verbose bool) *DistributedStorage {
	ds := &DistributedStorage{
		ctx:     ctx,
		host:    h,
		dht:     dhtInstance,
		cache:   make(map[string]*StorageMessage),
		maxTTL:  24 * 60 * 60, // 24 hours
		verbose: verbose,
	}

	// Start cache cleanup goroutine
	go ds.cleanupExpiredCache()

	return ds
}

// PutMessage stores a message in the DHT network
// The message will be replicated to multiple peers for redundancy
func (ds *DistributedStorage) PutMessage(msg *StorageMessage) error {
	// Set TTL if not already set (default: 1 hour)
	if msg.TTL == 0 {
		msg.TTL = time.Now().Unix() + 3600 // 1 hour
	}

	// Ensure TTL doesn't exceed maximum
	maxAllowed := time.Now().Unix() + ds.maxTTL
	if msg.TTL > maxAllowed {
		msg.TTL = maxAllowed
	}

	// Marshal message to JSON
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	// Create content ID for the message
	contentID, err := ds.createContentID(msg)
	if err != nil {
		return fmt.Errorf("failed to create content ID: %w", err)
	}

	// Store in local cache first
	ds.cache[contentID] = msg

	// Convert contentID string to cid.Cid for DHT operations
	c, err := cid.Decode(contentID)
	if err != nil {
		if ds.verbose {
			fmt.Printf("Warning: Failed to decode content ID: %v\n", err)
		}
		// Continue - local storage succeeded
	} else {
		// Announce to the network that we have this content
		// This uses DHT provider records - other peers can find us
		if err := ds.dht.Provide(ds.ctx, c, true); err != nil {
			if ds.verbose {
				fmt.Printf("Warning: Failed to provide content to DHT: %v\n", err)
			}
			// Don't return error - local storage succeeded
		} else if ds.verbose {
			fmt.Printf("✓ Announced message to DHT network (CID: %s)\n", contentID[:12]+"...")
		}
	}

	// Store the actual data in DHT (optional - for redundancy)
	// Note: This stores in DHT's datastore, not as provider records
	key := fmt.Sprintf("/messages/%s", contentID)
	if err := ds.dht.PutValue(ds.ctx, key, data); err != nil {
		if ds.verbose {
			fmt.Printf("Warning: Failed to store in DHT datastore: %v\n", err)
		}
	}

	return nil
}

// GetMessage retrieves a message from the DHT network
// It first checks local cache, then queries the network
func (ds *DistributedStorage) GetMessage(contentID string) (*StorageMessage, error) {
	// Check local cache first
	if msg, exists := ds.cache[contentID]; exists {
		// Check if expired
		if time.Now().Unix() > msg.TTL {
			delete(ds.cache, contentID)
		} else {
			return msg, nil
		}
	}

	// Query DHT network
	key := fmt.Sprintf("/messages/%s", contentID)
	data, err := ds.dht.GetValue(ds.ctx, key)
	if err != nil {
		return nil, fmt.Errorf("message not found in DHT: %w", err)
	}

	// Unmarshal the message
	var msg StorageMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal message: %w", err)
	}

	// Check if expired
	if time.Now().Unix() > msg.TTL {
		return nil, fmt.Errorf("message expired")
	}

	// Cache it locally
	ds.cache[contentID] = &msg

	return &msg, nil
}

// FindProviders finds peers that have a specific message
// Returns list of peers that announced they have this content
func (ds *DistributedStorage) FindProviders(contentID string, maxPeers int) ([]peer.AddrInfo, error) {
	c, err := cid.Decode(contentID)
	if err != nil {
		return nil, fmt.Errorf("invalid content ID: %w", err)
	}

	// Find providers for this content
	ctx, cancel := context.WithTimeout(ds.ctx, 30*time.Second)
	defer cancel()

	providerChan := ds.dht.FindProvidersAsync(ctx, c, maxPeers)

	var providers []peer.AddrInfo
	for provider := range providerChan {
		if provider.ID != ds.host.ID() { // Skip ourselves
			providers = append(providers, provider)
			if len(providers) >= maxPeers {
				break
			}
		}
	}

	return providers, nil
}

// QueryRecentMessages queries the network for recent messages
// This is a best-effort operation - not all messages may be found
func (ds *DistributedStorage) QueryRecentMessages(limit int) ([]*StorageMessage, error) {
	// Return messages from local cache
	// In a real implementation, you would query specific content IDs
	// or use a pub/sub topic to discover available messages

	var messages []*StorageMessage
	now := time.Now().Unix()

	for _, msg := range ds.cache {
		if now <= msg.TTL {
			messages = append(messages, msg)
			if len(messages) >= limit {
				break
			}
		}
	}

	return messages, nil
}

// createContentID creates a unique content ID for a message
// Uses multihash for content addressing (IPFS-style)
func (ds *DistributedStorage) createContentID(msg *StorageMessage) (string, error) {
	// Create a unique key from message content
	key := fmt.Sprintf("%s:%d:%s", msg.From, msg.Timestamp, msg.Content)

	// Create multihash
	hash, err := mh.Sum([]byte(key), mh.SHA2_256, -1)
	if err != nil {
		return "", err
	}

	// Create CID (Content Identifier)
	c := cid.NewCidV1(cid.Raw, hash)

	return c.String(), nil
}

// cleanupExpiredCache periodically removes expired messages from cache
func (ds *DistributedStorage) cleanupExpiredCache() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			now := time.Now().Unix()
			removed := 0

			for id, msg := range ds.cache {
				if now > msg.TTL {
					delete(ds.cache, id)
					removed++
				}
			}

			if ds.verbose && removed > 0 {
				fmt.Printf("🗑️  Cleaned up %d expired messages from cache\n", removed)
			}

		case <-ds.ctx.Done():
			return
		}
	}
}

// GetCacheStats returns statistics about the local cache
func (ds *DistributedStorage) GetCacheStats() map[string]interface{} {
	now := time.Now().Unix()
	active := 0
	expired := 0

	for _, msg := range ds.cache {
		if now <= msg.TTL {
			active++
		} else {
			expired++
		}
	}

	return map[string]interface{}{
		"total":   len(ds.cache),
		"active":  active,
		"expired": expired,
		"maxTTL":  ds.maxTTL,
	}
}

// Close cleans up resources
func (ds *DistributedStorage) Close() error {
	// Clear cache
	ds.cache = nil
	return nil
}
