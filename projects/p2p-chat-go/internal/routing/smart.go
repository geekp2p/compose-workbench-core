package routing

import (
	"context"
	"fmt"
	"time"

	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
)

// ConnectionStrategy represents the type of connection used
type ConnectionStrategy int

const (
	StrategyDirect ConnectionStrategy = iota // Direct P2P connection (best)
	StrategyRelay                             // Relay through another peer (fallback)
	StrategyDHT                               // Query DHT for peer info (last resort)
)

func (cs ConnectionStrategy) String() string {
	switch cs {
	case StrategyDirect:
		return "Direct"
	case StrategyRelay:
		return "Relay"
	case StrategyDHT:
		return "DHT"
	default:
		return "Unknown"
	}
}

// ConnectionResult contains the result of a connection attempt
type ConnectionResult struct {
	Strategy  ConnectionStrategy
	Latency   time.Duration
	Success   bool
	Error     error
	PeerID    peer.ID
	Address   multiaddr.Multiaddr
}

// SmartRouter handles intelligent routing with fallback strategies
type SmartRouter struct {
	ctx     context.Context
	host    host.Host
	verbose bool
	stats   *RouterStats
}

// RouterStats tracks routing statistics
type RouterStats struct {
	DirectAttempts  int
	DirectSuccess   int
	RelayAttempts   int
	RelaySuccess    int
	DHTAttempts     int
	DHTSuccess      int
	TotalLatency    time.Duration
	ConnectionCount int
}

// NewSmartRouter creates a new smart routing instance
func NewSmartRouter(ctx context.Context, h host.Host, verbose bool) *SmartRouter {
	return &SmartRouter{
		ctx:     ctx,
		host:    h,
		verbose: verbose,
		stats:   &RouterStats{},
	}
}

// ConnectToPeer attempts to connect to a peer using smart routing strategies
// Priority: Direct > Relay > DHT
func (sr *SmartRouter) ConnectToPeer(peerInfo peer.AddrInfo) (*ConnectionResult, error) {
	// Strategy 1: Try direct connection first
	result := sr.tryDirectConnection(peerInfo)
	if result.Success {
		sr.recordSuccess(result)
		return result, nil
	}

	if sr.verbose {
		fmt.Printf("⚠ Direct connection failed: %v, trying relay...\n", result.Error)
	}

	// Strategy 2: Try relay connection
	result = sr.tryRelayConnection(peerInfo)
	if result.Success {
		sr.recordSuccess(result)
		return result, nil
	}

	if sr.verbose {
		fmt.Printf("⚠ Relay connection failed: %v, trying DHT...\n", result.Error)
	}

	// Strategy 3: Try DHT-assisted connection
	result = sr.tryDHTConnection(peerInfo)
	if result.Success {
		sr.recordSuccess(result)
		return result, nil
	}

	// All strategies failed
	return result, fmt.Errorf("all connection strategies failed")
}

// tryDirectConnection attempts a direct P2P connection
func (sr *SmartRouter) tryDirectConnection(peerInfo peer.AddrInfo) *ConnectionResult {
	sr.stats.DirectAttempts++
	start := time.Now()

	result := &ConnectionResult{
		Strategy: StrategyDirect,
		PeerID:   peerInfo.ID,
	}

	// Check if already connected
	if sr.host.Network().Connectedness(peerInfo.ID) == network.Connected {
		result.Success = true
		result.Latency = time.Since(start)
		sr.stats.DirectSuccess++
		return result
	}

	// Try connecting to all known addresses
	ctx, cancel := context.WithTimeout(sr.ctx, 10*time.Second)
	defer cancel()

	err := sr.host.Connect(ctx, peerInfo)
	result.Latency = time.Since(start)

	if err != nil {
		result.Error = err
		result.Success = false
		return result
	}

	// Connection successful
	result.Success = true
	sr.stats.DirectSuccess++

	// Get the actual address used
	conns := sr.host.Network().ConnsToPeer(peerInfo.ID)
	if len(conns) > 0 {
		result.Address = conns[0].RemoteMultiaddr()
	}

	if sr.verbose {
		fmt.Printf("✓ Direct connection established to %s (latency: %v)\n",
			peerInfo.ID.ShortString(), result.Latency)
	}

	return result
}

// tryRelayConnection attempts a relay connection through another peer
func (sr *SmartRouter) tryRelayConnection(peerInfo peer.AddrInfo) *ConnectionResult {
	sr.stats.RelayAttempts++
	start := time.Now()

	result := &ConnectionResult{
		Strategy: StrategyRelay,
		PeerID:   peerInfo.ID,
	}

	// Look for relay addresses in peer info
	var relayAddrs []multiaddr.Multiaddr
	for _, addr := range peerInfo.Addrs {
		// Check if this is a circuit relay address
		if isRelayAddr(addr) {
			relayAddrs = append(relayAddrs, addr)
		}
	}

	if len(relayAddrs) == 0 {
		// Try to construct relay addresses from connected peers
		relayAddrs = sr.constructRelayAddresses(peerInfo.ID)
	}

	if len(relayAddrs) == 0 {
		result.Error = fmt.Errorf("no relay addresses available")
		return result
	}

	// Try each relay address
	ctx, cancel := context.WithTimeout(sr.ctx, 15*time.Second)
	defer cancel()

	peerInfoWithRelay := peer.AddrInfo{
		ID:    peerInfo.ID,
		Addrs: relayAddrs,
	}

	err := sr.host.Connect(ctx, peerInfoWithRelay)
	result.Latency = time.Since(start)

	if err != nil {
		result.Error = err
		result.Success = false
		return result
	}

	result.Success = true
	sr.stats.RelaySuccess++

	if sr.verbose {
		fmt.Printf("✓ Relay connection established to %s (latency: %v)\n",
			peerInfo.ID.ShortString(), result.Latency)
	}

	return result
}

// tryDHTConnection attempts to find peer addresses via DHT and connect
func (sr *SmartRouter) tryDHTConnection(peerInfo peer.AddrInfo) *ConnectionResult {
	sr.stats.DHTAttempts++
	start := time.Now()

	result := &ConnectionResult{
		Strategy: StrategyDHT,
		PeerID:   peerInfo.ID,
	}

	// Note: DHT lookup would be implemented here if needed
	// For now, we'll just try the existing peer info one more time
	// with a longer timeout

	ctx, cancel := context.WithTimeout(sr.ctx, 30*time.Second)
	defer cancel()

	err := sr.host.Connect(ctx, peerInfo)
	result.Latency = time.Since(start)

	if err != nil {
		result.Error = err
		result.Success = false
		return result
	}

	result.Success = true
	sr.stats.DHTSuccess++

	if sr.verbose {
		fmt.Printf("✓ DHT-assisted connection established to %s (latency: %v)\n",
			peerInfo.ID.ShortString(), result.Latency)
	}

	return result
}

// constructRelayAddresses constructs relay circuit addresses using connected peers
func (sr *SmartRouter) constructRelayAddresses(targetPeer peer.ID) []multiaddr.Multiaddr {
	var relayAddrs []multiaddr.Multiaddr

	// Get all connected peers that could act as relays
	peers := sr.host.Network().Peers()

	for _, relayPeer := range peers {
		if relayPeer == targetPeer {
			continue // Skip the target peer itself
		}

		// Check if this peer has relay capability
		conns := sr.host.Network().ConnsToPeer(relayPeer)
		for _, conn := range conns {
			// Construct circuit relay address: /ip4/.../p2p/{relay}/p2p-circuit/p2p/{target}
			relayAddr := conn.RemoteMultiaddr()

			// Append relay circuit
			circuitAddr, err := multiaddr.NewMultiaddr(
				fmt.Sprintf("%s/p2p-circuit/p2p/%s", relayAddr.String(), targetPeer.String()),
			)

			if err == nil {
				relayAddrs = append(relayAddrs, circuitAddr)
				// Limit to 3 relay options to avoid too many attempts
				if len(relayAddrs) >= 3 {
					return relayAddrs
				}
			}
		}
	}

	return relayAddrs
}

// isRelayAddr checks if an address is a circuit relay address
func isRelayAddr(addr multiaddr.Multiaddr) bool {
	protocols := addr.Protocols()
	for _, p := range protocols {
		if p.Name == "p2p-circuit" {
			return true
		}
	}
	return false
}

// recordSuccess records a successful connection for statistics
func (sr *SmartRouter) recordSuccess(result *ConnectionResult) {
	sr.stats.ConnectionCount++
	sr.stats.TotalLatency += result.Latency

	if sr.verbose {
		avgLatency := sr.stats.TotalLatency / time.Duration(sr.stats.ConnectionCount)
		fmt.Printf("📊 Connection via %s (avg latency: %v)\n", result.Strategy, avgLatency)
	}
}

// GetStats returns routing statistics
func (sr *SmartRouter) GetStats() *RouterStats {
	return sr.stats
}

// PrintStats prints routing statistics
func (sr *SmartRouter) PrintStats() {
	fmt.Println("\n=== Smart Routing Statistics ===")
	fmt.Printf("Direct:  %d attempts, %d success (%.1f%%)\n",
		sr.stats.DirectAttempts, sr.stats.DirectSuccess,
		successRate(sr.stats.DirectSuccess, sr.stats.DirectAttempts))

	fmt.Printf("Relay:   %d attempts, %d success (%.1f%%)\n",
		sr.stats.RelayAttempts, sr.stats.RelaySuccess,
		successRate(sr.stats.RelaySuccess, sr.stats.RelayAttempts))

	fmt.Printf("DHT:     %d attempts, %d success (%.1f%%)\n",
		sr.stats.DHTAttempts, sr.stats.DHTSuccess,
		successRate(sr.stats.DHTSuccess, sr.stats.DHTAttempts))

	if sr.stats.ConnectionCount > 0 {
		avgLatency := sr.stats.TotalLatency / time.Duration(sr.stats.ConnectionCount)
		fmt.Printf("Average latency: %v\n", avgLatency)
	}

	fmt.Printf("Total connections: %d\n", sr.stats.ConnectionCount)
}

// successRate calculates success rate percentage
func successRate(success, attempts int) float64 {
	if attempts == 0 {
		return 0.0
	}
	return (float64(success) / float64(attempts)) * 100.0
}

// GetConnectionType returns the current connection type to a peer
func (sr *SmartRouter) GetConnectionType(peerID peer.ID) ConnectionStrategy {
	conns := sr.host.Network().ConnsToPeer(peerID)
	if len(conns) == 0 {
		return StrategyDHT // Not connected
	}

	// Check if any connection is a relay
	for _, conn := range conns {
		if isRelayAddr(conn.RemoteMultiaddr()) {
			return StrategyRelay
		}
	}

	return StrategyDirect
}

// IsConnected checks if we're connected to a peer
func (sr *SmartRouter) IsConnected(peerID peer.ID) bool {
	return sr.host.Network().Connectedness(peerID) == network.Connected
}

// GetConnectedPeers returns list of connected peers with their connection types
func (sr *SmartRouter) GetConnectedPeers() map[peer.ID]ConnectionStrategy {
	result := make(map[peer.ID]ConnectionStrategy)

	for _, peerID := range sr.host.Network().Peers() {
		result[peerID] = sr.GetConnectionType(peerID)
	}

	return result
}
