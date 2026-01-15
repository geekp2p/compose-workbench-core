package node

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	drouting "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	dutil "github.com/libp2p/go-libp2p/p2p/discovery/util"
)

// PeerManager handles peer lifecycle, reconnection, and keep-alive
type PeerManager struct {
	host      host.Host
	discovery *drouting.RoutingDiscovery
	verbose   bool

	// Known peers that we want to maintain connections with
	knownPeers     map[peer.ID]peer.AddrInfo
	knownPeersLock sync.RWMutex

	// Context for lifecycle management
	ctx    context.Context
	cancel context.CancelFunc

	// Configuration
	reconnectInterval time.Duration
	discoveryInterval time.Duration
	keepAliveInterval time.Duration
	rendezvousStrings []string
}

// PeerManagerConfig holds configuration for PeerManager
type PeerManagerConfig struct {
	ReconnectInterval time.Duration // How often to retry disconnected peers
	DiscoveryInterval time.Duration // How often to re-trigger discovery
	KeepAliveInterval time.Duration // How often to ping peers to keep connections alive
	RendezvousStrings []string      // Multiple rendezvous points for discovery
	Verbose           bool
}

// DefaultPeerManagerConfig returns sensible defaults
func DefaultPeerManagerConfig(baseRendezvous string) PeerManagerConfig {
	return PeerManagerConfig{
		ReconnectInterval: 30 * time.Second,  // Try to reconnect every 30s
		DiscoveryInterval: 60 * time.Second,  // Re-discover every 60s
		KeepAliveInterval: 120 * time.Second, // Keep-alive ping every 2 minutes
		RendezvousStrings: []string{
			baseRendezvous,                // Main rendezvous
			baseRendezvous + "-global",    // Global channel
			baseRendezvous + "-discovery", // Discovery channel
			baseRendezvous + "-v1",        // Versioned channel
		},
		Verbose: false,
	}
}

// NewPeerManager creates a new peer manager
func NewPeerManager(ctx context.Context, h host.Host, discovery *drouting.RoutingDiscovery, config PeerManagerConfig) *PeerManager {
	pmCtx, cancel := context.WithCancel(ctx)

	pm := &PeerManager{
		host:              h,
		discovery:         discovery,
		verbose:           config.Verbose,
		knownPeers:        make(map[peer.ID]peer.AddrInfo),
		ctx:               pmCtx,
		cancel:            cancel,
		reconnectInterval: config.ReconnectInterval,
		discoveryInterval: config.DiscoveryInterval,
		keepAliveInterval: config.KeepAliveInterval,
		rendezvousStrings: config.RendezvousStrings,
	}

	// Start background tasks
	go pm.periodicDiscovery()
	go pm.autoReconnect()
	go pm.keepAlive()

	// Setup connection notifications
	pm.setupNotifications()

	return pm
}

// setupNotifications sets up connection/disconnection handlers
func (pm *PeerManager) setupNotifications() {
	pm.host.Network().Notify(&network.NotifyBundle{
		ConnectedF: func(n network.Network, conn network.Conn) {
			remotePeer := conn.RemotePeer()

			// Add to known peers
			pm.knownPeersLock.Lock()
			if _, exists := pm.knownPeers[remotePeer]; !exists {
				pm.knownPeers[remotePeer] = peer.AddrInfo{
					ID:    remotePeer,
					Addrs: pm.host.Peerstore().Addrs(remotePeer),
				}
			}
			pm.knownPeersLock.Unlock()

			if pm.verbose {
				fmt.Printf("✓ Peer connected and tracked: %s\n", remotePeer.ShortString())
			}
		},
		DisconnectedF: func(n network.Network, conn network.Conn) {
			remotePeer := conn.RemotePeer()

			// Keep in known peers for auto-reconnect
			pm.knownPeersLock.RLock()
			_, wasKnown := pm.knownPeers[remotePeer]
			pm.knownPeersLock.RUnlock()

			if pm.verbose && wasKnown {
				fmt.Printf("⚠ Peer disconnected (will try to reconnect): %s\n", remotePeer.ShortString())
			}
		},
	})
}

// periodicDiscovery re-triggers peer discovery at regular intervals
func (pm *PeerManager) periodicDiscovery() {
	ticker := time.NewTicker(pm.discoveryInterval)
	defer ticker.Stop()

	// Do initial discovery immediately
	pm.runDiscovery()

	for {
		select {
		case <-ticker.C:
			if pm.verbose {
				fmt.Println("🔄 Running periodic peer discovery...")
			}
			pm.runDiscovery()
		case <-pm.ctx.Done():
			return
		}
	}
}

// runDiscovery performs discovery on all rendezvous points
func (pm *PeerManager) runDiscovery() {
	for _, rendezvous := range pm.rendezvousStrings {
		// Advertise ourselves
		go func(rdv string) {
			// Use a timeout context for advertising
			advCtx, cancel := context.WithTimeout(pm.ctx, 30*time.Second)
			defer cancel()

			ttl, err := dutil.Advertise(advCtx, pm.discovery, rdv)
			if err != nil {
				if pm.verbose {
					fmt.Printf("Failed to advertise on %s: %v\n", rdv, err)
				}
				return
			}

			if pm.verbose {
				fmt.Printf("Advertising ourselves with namespace: %s (TTL: %v)\n", rdv, ttl)
			}
		}(rendezvous)

		// Find peers
		go func(rdv string) {
			// Use a timeout context for finding peers
			findCtx, cancel := context.WithTimeout(pm.ctx, 30*time.Second)
			defer cancel()

			peerChan, err := pm.discovery.FindPeers(findCtx, rdv)
			if err != nil {
				if pm.verbose {
					fmt.Printf("Failed to find peers on %s: %v\n", rdv, err)
				}
				return
			}

			// Connect to discovered peers
			for peerInfo := range peerChan {
				if peerInfo.ID == pm.host.ID() {
					continue // Skip ourselves
				}

				// Try to connect if not already connected
				if pm.host.Network().Connectedness(peerInfo.ID) != network.Connected {
					connectCtx, cancel := context.WithTimeout(pm.ctx, 10*time.Second)
					if err := pm.host.Connect(connectCtx, peerInfo); err != nil {
						if pm.verbose {
							fmt.Printf("Failed to connect to peer %s (from %s): %v\n",
								peerInfo.ID.ShortString(), rdv, err)
						}
					} else {
						if pm.verbose {
							fmt.Printf("✓ Connected to peer %s (via %s)\n",
								peerInfo.ID.ShortString(), rdv)
						}
					}
					cancel()
				}
			}
		}(rendezvous)
	}
}

// autoReconnect attempts to reconnect to known peers that are disconnected
func (pm *PeerManager) autoReconnect() {
	ticker := time.NewTicker(pm.reconnectInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			pm.knownPeersLock.RLock()
			peers := make([]peer.AddrInfo, 0, len(pm.knownPeers))
			for _, p := range pm.knownPeers {
				peers = append(peers, p)
			}
			pm.knownPeersLock.RUnlock()

			// Try to reconnect to disconnected peers
			reconnected := 0
			for _, peerInfo := range peers {
				if pm.host.Network().Connectedness(peerInfo.ID) != network.Connected {
					// Update addresses from peerstore
					peerInfo.Addrs = pm.host.Peerstore().Addrs(peerInfo.ID)

					if len(peerInfo.Addrs) == 0 {
						continue // No known addresses
					}

					connectCtx, cancel := context.WithTimeout(pm.ctx, 10*time.Second)
					if err := pm.host.Connect(connectCtx, peerInfo); err != nil {
						if pm.verbose {
							fmt.Printf("Reconnect attempt failed for %s: %v\n",
								peerInfo.ID.ShortString(), err)
						}
					} else {
						reconnected++
						if pm.verbose {
							fmt.Printf("✓ Reconnected to peer: %s\n", peerInfo.ID.ShortString())
						}
					}
					cancel()
				}
			}

			if pm.verbose && reconnected > 0 {
				fmt.Printf("✓ Reconnected to %d peer(s)\n", reconnected)
			}

		case <-pm.ctx.Done():
			return
		}
	}
}

// keepAlive maintains active connections by pinging peers and updating address TTLs
func (pm *PeerManager) keepAlive() {
	ticker := time.NewTicker(pm.keepAliveInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			pm.knownPeersLock.RLock()
			peers := make([]peer.ID, 0, len(pm.knownPeers))
			for id := range pm.knownPeers {
				peers = append(peers, id)
			}
			pm.knownPeersLock.RUnlock()

			for _, peerID := range peers {
				if pm.host.Network().Connectedness(peerID) == network.Connected {
					// Update address TTL to prevent expiration
					addrs := pm.host.Peerstore().Addrs(peerID)
					if len(addrs) > 0 {
						pm.host.Peerstore().AddAddrs(peerID, addrs, peerstore.ConnectedAddrTTL)
					}

					// Ping to keep NAT mappings alive
					go func(pid peer.ID) {
						pingCtx, cancel := context.WithTimeout(pm.ctx, 10*time.Second)
						defer cancel()

						// Use libp2p's ping protocol
						result := <-pm.host.Pings(pingCtx, pid)
						if result.Error != nil {
							if pm.verbose {
								fmt.Printf("Ping failed for %s: %v\n", pid.ShortString(), result.Error)
							}
						} else if pm.verbose {
							fmt.Printf("✓ Ping successful for %s (RTT: %v)\n",
								pid.ShortString(), result.RTT)
						}
					}(peerID)
				}
			}

		case <-pm.ctx.Done():
			return
		}
	}
}

// GetKnownPeerCount returns the number of known peers
func (pm *PeerManager) GetKnownPeerCount() int {
	pm.knownPeersLock.RLock()
	defer pm.knownPeersLock.RUnlock()
	return len(pm.knownPeers)
}

// GetConnectedPeerCount returns the number of currently connected peers
func (pm *PeerManager) GetConnectedPeerCount() int {
	pm.knownPeersLock.RLock()
	defer pm.knownPeersLock.RUnlock()

	connected := 0
	for peerID := range pm.knownPeers {
		if pm.host.Network().Connectedness(peerID) == network.Connected {
			connected++
		}
	}
	return connected
}

// Close stops all peer manager background tasks
func (pm *PeerManager) Close() {
	pm.cancel()
}
