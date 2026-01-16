package peers

import (
	"context"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	drouting "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	dutil "github.com/libp2p/go-libp2p/p2p/discovery/util"
	ping "github.com/libp2p/go-libp2p/p2p/protocol/ping"
)

// PeerManager handles peer lifecycle, auto-reconnect, and keep-alive
type PeerManager struct {
	host      host.Host
	discovery *drouting.RoutingDiscovery
	ctx       context.Context
	cancel    context.CancelFunc
	verbose   bool

	// Known peers that we should try to reconnect to
	knownPeers     map[peer.ID]*peerState
	knownPeersLock sync.RWMutex

	// Inflight dials to prevent duplicate dial attempts
	inflightDials     map[peer.ID]struct{}
	inflightDialsLock sync.Mutex

	// Configuration
	config *ManagerConfig

	// Ping service for keep-alive
	pingService *ping.PingService

	// For limiting concurrent dials
	dialSemaphore chan struct{}
}

// peerState tracks state for reconnection backoff
type peerState struct {
	lastAttempt time.Time
	attempts    int
	lastSeen    time.Time
}

// ManagerConfig configuration for PeerManager
type ManagerConfig struct {
	// ReconnectInterval is the base interval for reconnection attempts
	ReconnectInterval time.Duration
	// DiscoveryInterval is how often to re-run discovery
	DiscoveryInterval time.Duration
	// KeepAliveInterval is how often to ping peers
	KeepAliveInterval time.Duration
	// MaxBackoff is the maximum backoff duration
	MaxBackoff time.Duration
	// MaxConcurrentDials limits concurrent dial attempts
	MaxConcurrentDials int
	// Rendezvous strings for discovery
	RendezvousStrings []string
	// Verbose logging
	Verbose bool
}

// DefaultConfig returns default manager configuration
func DefaultConfig(topic string) *ManagerConfig {
	return &ManagerConfig{
		ReconnectInterval:  30 * time.Second,
		DiscoveryInterval:  2 * time.Minute, // Re-run discovery every 2 minutes
		KeepAliveInterval:  45 * time.Second, // Ping every 45s to keep NAT mappings alive
		MaxBackoff:         5 * time.Minute,
		MaxConcurrentDials: 10,
		RendezvousStrings: []string{
			topic,                // Main topic
			topic + "-global",    // Global discovery
			topic + "-discovery", // Discovery channel
		},
		Verbose: false,
	}
}

// NewPeerManager creates a new peer manager
func NewPeerManager(ctx context.Context, h host.Host, discovery *drouting.RoutingDiscovery, config *ManagerConfig) *PeerManager {
	if config == nil {
		config = DefaultConfig("p2p-chat-default")
	}

	ctx, cancel := context.WithCancel(ctx)

	pm := &PeerManager{
		host:          h,
		discovery:     discovery,
		ctx:           ctx,
		cancel:        cancel,
		verbose:       config.Verbose,
		knownPeers:    make(map[peer.ID]*peerState),
		inflightDials: make(map[peer.ID]struct{}),
		config:        config,
		pingService:   ping.NewPingService(h),
		dialSemaphore: make(chan struct{}, config.MaxConcurrentDials),
	}

	// Setup connection event handlers
	h.Network().Notify(&network.NotifyBundle{
		ConnectedF: func(n network.Network, conn network.Conn) {
			pm.handlePeerConnected(conn.RemotePeer())
		},
		DisconnectedF: func(n network.Network, conn network.Conn) {
			pm.handlePeerDisconnected(conn.RemotePeer())
		},
	})

	// Start background tasks
	go pm.periodicDiscovery()
	go pm.autoReconnect()
	go pm.keepAlive()

	return pm
}

// handlePeerConnected updates peer state when connected
func (pm *PeerManager) handlePeerConnected(p peer.ID) {
	pm.knownPeersLock.Lock()
	defer pm.knownPeersLock.Unlock()

	if _, exists := pm.knownPeers[p]; !exists {
		pm.knownPeers[p] = &peerState{
			lastSeen: time.Now(),
			attempts: 0,
		}
	} else {
		pm.knownPeers[p].lastSeen = time.Now()
		pm.knownPeers[p].attempts = 0 // Reset attempts on successful connect
	}

	if pm.verbose {
		fmt.Printf("✓ Peer connected and tracked: %s\n", p.ShortString())
	}
}

// handlePeerDisconnected marks peer for reconnection
func (pm *PeerManager) handlePeerDisconnected(p peer.ID) {
	pm.knownPeersLock.Lock()
	defer pm.knownPeersLock.Unlock()

	if state, exists := pm.knownPeers[p]; exists {
		state.lastSeen = time.Now()
		if pm.verbose {
			fmt.Printf("⚠ Peer disconnected (will auto-reconnect): %s\n", p.ShortString())
		}
	}
}

// periodicDiscovery runs discovery periodically with DHT readiness check
func (pm *PeerManager) periodicDiscovery() {
	// Wait a bit before first discovery to let DHT bootstrap
	time.Sleep(10 * time.Second)

	ticker := time.NewTicker(pm.config.DiscoveryInterval)
	defer ticker.Stop()

	for {
		select {
		case <-pm.ctx.Done():
			return
		case <-ticker.C:
			pm.runDiscovery()
		}
	}
}

// runDiscovery performs discovery and advertise with timeout and DHT readiness check
func (pm *PeerManager) runDiscovery() {
	// Check if DHT routing table has minimum peers (indication of readiness)
	routingTableSize := pm.host.Network().Peers()
	if len(routingTableSize) < 1 {
		if pm.verbose {
			fmt.Println("⏳ DHT not ready yet (no peers in routing table), skipping discovery")
		}
		return
	}

	if pm.verbose {
		fmt.Println("🔄 Running periodic peer discovery...")
	}

	for _, rendezvous := range pm.config.RendezvousStrings {
		// Use separate context with timeout for each operation
		advertiseCtx, advertiseCancel := context.WithTimeout(pm.ctx, 30*time.Second)

		// Advertise (re-advertise periodically)
		dutil.Advertise(advertiseCtx, pm.discovery, rendezvous)
		if pm.verbose {
			fmt.Printf("✓ Advertised on '%s'\n", rendezvous)
		}
		advertiseCancel()

		// Small delay between advertise and find to avoid overwhelming DHT
		time.Sleep(1 * time.Second)

		// Find peers with timeout
		findCtx, findCancel := context.WithTimeout(pm.ctx, 30*time.Second)
		peerChan, err := pm.discovery.FindPeers(findCtx, rendezvous)
		if err != nil {
			if pm.verbose {
				fmt.Printf("⚠ Failed to find peers on '%s': %v\n", rendezvous, err)
			}
			findCancel()
			continue
		}

		// Connect to discovered peers (non-blocking)
		go pm.connectToDiscoveredPeers(peerChan, rendezvous)

		// Don't cancel findCtx immediately - let it run in background goroutine
		time.AfterFunc(30*time.Second, findCancel)
	}
}

// connectToDiscoveredPeers connects to peers from discovery channel
func (pm *PeerManager) connectToDiscoveredPeers(peerChan <-chan peer.AddrInfo, rendezvous string) {
	count := 0
	for peerInfo := range peerChan {
		if peerInfo.ID == pm.host.ID() {
			continue
		}

		count++

		// Add addresses to peerstore
		pm.host.Peerstore().AddAddrs(peerInfo.ID, peerInfo.Addrs, peerstore.TempAddrTTL)

		// Try to connect (with guard)
		go pm.dialPeer(peerInfo.ID, peerInfo.Addrs)
	}

	if pm.verbose && count > 0 {
		fmt.Printf("✓ Discovered %d peer(s) on '%s'\n", count, rendezvous)
	}
}

// autoReconnect attempts to reconnect to known disconnected peers
func (pm *PeerManager) autoReconnect() {
	ticker := time.NewTicker(pm.config.ReconnectInterval)
	defer ticker.Stop()

	for {
		select {
		case <-pm.ctx.Done():
			return
		case <-ticker.C:
			pm.reconnectDisconnectedPeers()
		}
	}
}

// reconnectDisconnectedPeers tries to reconnect to disconnected known peers
func (pm *PeerManager) reconnectDisconnectedPeers() {
	pm.knownPeersLock.RLock()
	disconnected := make(map[peer.ID]*peerState)
	for p, state := range pm.knownPeers {
		// Check if actually disconnected
		if pm.host.Network().Connectedness(p) != network.Connected {
			disconnected[p] = state
		}
	}
	pm.knownPeersLock.RUnlock()

	if len(disconnected) == 0 {
		return
	}

	if pm.verbose {
		fmt.Printf("🔁 Auto-reconnect: trying %d disconnected peer(s)...\n", len(disconnected))
	}

	for p, state := range disconnected {
		// Calculate backoff
		backoff := pm.calculateBackoff(state.attempts)
		if time.Since(state.lastAttempt) < backoff {
			continue // Too soon to retry
		}

		// Try to dial
		go pm.dialPeer(p, nil)
	}
}

// dialPeer attempts to dial a peer with guards and limits
func (pm *PeerManager) dialPeer(p peer.ID, addrs interface{}) {
	// Check connectedness first
	if pm.host.Network().Connectedness(p) == network.Connected {
		return // Already connected
	}

	// Check if already dialing
	pm.inflightDialsLock.Lock()
	if _, dialing := pm.inflightDials[p]; dialing {
		pm.inflightDialsLock.Unlock()
		return // Already dialing
	}
	pm.inflightDials[p] = struct{}{}
	pm.inflightDialsLock.Unlock()

	// Remove from inflight when done
	defer func() {
		pm.inflightDialsLock.Lock()
		delete(pm.inflightDials, p)
		pm.inflightDialsLock.Unlock()
	}()

	// Acquire semaphore to limit concurrent dials
	select {
	case pm.dialSemaphore <- struct{}{}:
		defer func() { <-pm.dialSemaphore }()
	case <-pm.ctx.Done():
		return
	}

	// Update attempt tracking
	pm.knownPeersLock.Lock()
	if state, exists := pm.knownPeers[p]; exists {
		state.lastAttempt = time.Now()
		state.attempts++
	} else {
		pm.knownPeers[p] = &peerState{
			lastAttempt: time.Now(),
			attempts:    1,
			lastSeen:    time.Now(),
		}
	}
	pm.knownPeersLock.Unlock()

	// Get peer info from peerstore
	peerInfo := pm.host.Peerstore().PeerInfo(p)

	// Use timeout for dial
	dialCtx, cancel := context.WithTimeout(pm.ctx, 15*time.Second)
	defer cancel()

	// Attempt connection
	if err := pm.host.Connect(dialCtx, peerInfo); err != nil {
		if pm.verbose {
			fmt.Printf("⚠ Dial failed for %s: %v\n", p.ShortString(), err)
		}
	} else {
		if pm.verbose {
			fmt.Printf("✓ Successfully connected to: %s\n", p.ShortString())
		}
	}
}

// keepAlive sends periodic pings to connected peers to maintain NAT mappings
func (pm *PeerManager) keepAlive() {
	ticker := time.NewTicker(pm.config.KeepAliveInterval)
	defer ticker.Stop()

	for {
		select {
		case <-pm.ctx.Done():
			return
		case <-ticker.C:
			pm.pingConnectedPeers()
		}
	}
}

// pingConnectedPeers pings connected peers to keep NAT holes open
func (pm *PeerManager) pingConnectedPeers() {
	peers := pm.host.Network().Peers()
	if len(peers) == 0 {
		return
	}

	if pm.verbose {
		fmt.Printf("💓 Keep-alive: pinging %d connected peer(s)...\n", len(peers))
	}

	for _, p := range peers {
		go pm.pingPeer(p)
	}
}

// pingPeer sends a ping to a specific peer
func (pm *PeerManager) pingPeer(p peer.ID) {
	pingCtx, cancel := context.WithTimeout(pm.ctx, 10*time.Second)
	defer cancel()

	start := time.Now()
	result := <-pm.pingService.Ping(pingCtx, p)
	if result.Error != nil {
		if pm.verbose {
			fmt.Printf("⚠ Ping failed for %s: %v\n", p.ShortString(), result.Error)
		}
		return
	}

	rtt := time.Since(start)

	// Update address TTL to keep peer in peerstore
	pm.host.Peerstore().UpdateAddrs(p, peerstore.ConnectedAddrTTL, peerstore.ConnectedAddrTTL)

	if pm.verbose {
		fmt.Printf("✓ Ping OK: %s (RTT: %dms)\n", p.ShortString(), rtt.Milliseconds())
	}
}

// calculateBackoff calculates exponential backoff duration
func (pm *PeerManager) calculateBackoff(attempts int) time.Duration {
	// Exponential backoff: 5s, 10s, 20s, 40s, 80s, max 5min
	backoff := time.Duration(math.Pow(2, float64(attempts))) * 5 * time.Second
	if backoff > pm.config.MaxBackoff {
		backoff = pm.config.MaxBackoff
	}
	return backoff
}

// GetKnownPeersCount returns the number of known peers
func (pm *PeerManager) GetKnownPeersCount() int {
	pm.knownPeersLock.RLock()
	defer pm.knownPeersLock.RUnlock()
	return len(pm.knownPeers)
}

// Close stops all background tasks
func (pm *PeerManager) Close() {
	pm.cancel()
	if pm.verbose {
		fmt.Println("✓ Peer manager stopped")
	}
}
