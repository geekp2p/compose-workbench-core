package relay

import (
	"context"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay"
	ma "github.com/multiformats/go-multiaddr"
)

// RelayService manages automatic relay service enablement
type RelayService struct {
	ctx         context.Context
	host        host.Host
	relay       *relay.Relay
	isPublic    bool
	publicAddrs []ma.Multiaddr
	peerScores  map[peer.ID]*PeerScore
	scoreMutex  sync.RWMutex
	bandwidth   *BandwidthMonitor
	verbose     bool
}

// PeerScore tracks peer reputation for relay selection
type PeerScore struct {
	PeerID           peer.ID
	SuccessfulRelays int
	FailedRelays     int
	LastSeen         time.Time
	Latency          time.Duration
	IsPublic         bool
}

// BandwidthMonitor tracks bandwidth usage
type BandwidthMonitor struct {
	totalIn      int64
	totalOut     int64
	limitMbps    int64 // Bandwidth limit in Mbps (0 = unlimited)
	mutex        sync.RWMutex
	lastReset    time.Time
	relayedBytes int64
}

// NewRelayService creates a new relay service manager
func NewRelayService(ctx context.Context, h host.Host, verbose bool) *RelayService {
	rs := &RelayService{
		ctx:        ctx,
		host:       h,
		peerScores: make(map[peer.ID]*PeerScore),
		bandwidth: &BandwidthMonitor{
			limitMbps: 100, // 100 Mbps default limit for relay service
			lastReset: time.Now(),
		},
		verbose: verbose,
	}

	// Detect public IP addresses
	rs.detectPublicAddresses()

	// Start monitoring
	go rs.monitorConnections()
	go rs.updatePeerScores()

	return rs
}

// detectPublicAddresses detects if this node has public IP addresses
func (rs *RelayService) detectPublicAddresses() {
	var publicAddrs []ma.Multiaddr

	for _, addr := range rs.host.Addrs() {
		// Check if address is public
		if isPublicAddr(addr) {
			publicAddrs = append(publicAddrs, addr)
			rs.isPublic = true
		}
	}

	rs.publicAddrs = publicAddrs

	if rs.isPublic {
		fmt.Printf("✓ Public IP detected: This node can act as a relay\n")
		if rs.verbose {
			fmt.Println("Public addresses:")
			for _, addr := range publicAddrs {
				fmt.Printf("  - %s\n", addr)
			}
		}
	} else {
		fmt.Println("ℹ️  No public IP detected: Using relay service from other peers")
	}
}

// EnableRelayService enables relay service if this node has public IP
func (rs *RelayService) EnableRelayService() error {
	if !rs.isPublic {
		return fmt.Errorf("cannot enable relay: no public IP address")
	}

	// Create relay service with resource limits
	relayOpts := []relay.Option{
		relay.WithResources(relay.Resources{
			MaxReservations: 512,
			MaxCircuits:     128,
			BufferSize:      4096,
		}),
	}

	relayService, err := relay.New(rs.host, relayOpts...)
	if err != nil {
		return fmt.Errorf("failed to create relay service: %w", err)
	}

	rs.relay = relayService
	fmt.Println("✓ Relay service enabled - helping peers behind NAT/firewall")

	return nil
}

// isPublicAddr checks if a multiaddr contains a public IP
func isPublicAddr(addr ma.Multiaddr) bool {
	// Extract IP from multiaddr
	ipStr, err := addr.ValueForProtocol(ma.P_IP4)
	if err != nil {
		// Try IPv6
		ipStr, err = addr.ValueForProtocol(ma.P_IP6)
		if err != nil {
			return false
		}
	}

	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false
	}

	// Check if IP is public (not private, loopback, or link-local)
	return !ip.IsPrivate() && !ip.IsLoopback() && !ip.IsLinkLocalUnicast() && !ip.IsLinkLocalMulticast()
}

// SelectBestRelay selects the best relay peer based on scores
func (rs *RelayService) SelectBestRelay(candidates []peer.ID) (peer.ID, error) {
	rs.scoreMutex.RLock()
	defer rs.scoreMutex.RUnlock()

	if len(candidates) == 0 {
		return "", fmt.Errorf("no relay candidates available")
	}

	var bestPeer peer.ID
	bestScore := -1.0

	for _, peerID := range candidates {
		score := rs.calculatePeerScore(peerID)
		if score > bestScore {
			bestScore = score
			bestPeer = peerID
		}
	}

	if bestPeer == "" {
		return candidates[0], nil // Fallback to first candidate
	}

	return bestPeer, nil
}

// calculatePeerScore calculates a score for relay selection
// Higher score = better relay candidate
func (rs *RelayService) calculatePeerScore(peerID peer.ID) float64 {
	score, exists := rs.peerScores[peerID]
	if !exists {
		return 0.0
	}

	// Calculate score based on:
	// 1. Success rate (0-50 points)
	// 2. Latency (0-30 points)
	// 3. Public IP bonus (20 points)
	// 4. Recent activity (0-10 points)

	total := score.SuccessfulRelays + score.FailedRelays
	successRate := 0.0
	if total > 0 {
		successRate = float64(score.SuccessfulRelays) / float64(total)
	}

	// Success rate score
	scoreValue := successRate * 50

	// Latency score (lower latency = higher score)
	if score.Latency > 0 && score.Latency < 1*time.Second {
		latencyScore := 30.0 * (1.0 - float64(score.Latency)/float64(time.Second))
		scoreValue += latencyScore
	}

	// Public IP bonus
	if score.IsPublic {
		scoreValue += 20.0
	}

	// Recent activity bonus (seen in last 5 minutes)
	if time.Since(score.LastSeen) < 5*time.Minute {
		scoreValue += 10.0
	}

	return scoreValue
}

// UpdatePeerScore updates the score for a peer after a relay attempt
func (rs *RelayService) UpdatePeerScore(peerID peer.ID, success bool, latency time.Duration) {
	rs.scoreMutex.Lock()
	defer rs.scoreMutex.Unlock()

	score, exists := rs.peerScores[peerID]
	if !exists {
		score = &PeerScore{
			PeerID:   peerID,
			LastSeen: time.Now(),
		}
		rs.peerScores[peerID] = score
	}

	if success {
		score.SuccessfulRelays++
	} else {
		score.FailedRelays++
	}

	score.LastSeen = time.Now()
	score.Latency = latency
}

// monitorConnections monitors network connections and updates peer scores
func (rs *RelayService) monitorConnections() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// Update scores for connected peers
			peers := rs.host.Network().Peers()
			for _, peerID := range peers {
				rs.scoreMutex.Lock()
				if score, exists := rs.peerScores[peerID]; exists {
					score.LastSeen = time.Now()

					// Check if peer has public IP
					conns := rs.host.Network().ConnsToPeer(peerID)
					for _, conn := range conns {
						if isPublicAddr(conn.RemoteMultiaddr()) {
							score.IsPublic = true
							break
						}
					}
				}
				rs.scoreMutex.Unlock()
			}

		case <-rs.ctx.Done():
			return
		}
	}
}

// updatePeerScores periodically cleans up old peer scores
func (rs *RelayService) updatePeerScores() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rs.scoreMutex.Lock()
			// Remove scores for peers not seen in 30 minutes
			for peerID, score := range rs.peerScores {
				if time.Since(score.LastSeen) > 30*time.Minute {
					delete(rs.peerScores, peerID)
				}
			}
			rs.scoreMutex.Unlock()

			if rs.verbose {
				rs.printPeerScores()
			}

		case <-rs.ctx.Done():
			return
		}
	}
}

// printPeerScores prints current peer scores (for debugging)
func (rs *RelayService) printPeerScores() {
	rs.scoreMutex.RLock()
	defer rs.scoreMutex.RUnlock()

	fmt.Println("\n=== Relay Peer Scores ===")
	for peerID, score := range rs.peerScores {
		scoreValue := rs.calculatePeerScore(peerID)
		fmt.Printf("  %s: %.1f (success: %d, failed: %d, public: %v)\n",
			peerID.ShortString(), scoreValue, score.SuccessfulRelays, score.FailedRelays, score.IsPublic)
	}
}

// GetBandwidthStats returns current bandwidth statistics
func (rs *RelayService) GetBandwidthStats() map[string]interface{} {
	rs.bandwidth.mutex.RLock()
	defer rs.bandwidth.mutex.RUnlock()

	return map[string]interface{}{
		"totalIn":      rs.bandwidth.totalIn,
		"totalOut":     rs.bandwidth.totalOut,
		"relayedBytes": rs.bandwidth.relayedBytes,
		"limitMbps":    rs.bandwidth.limitMbps,
		"uptime":       time.Since(rs.bandwidth.lastReset).String(),
	}
}

// GetRelayInfo returns information about relay status
func (rs *RelayService) GetRelayInfo() map[string]interface{} {
	info := map[string]interface{}{
		"isPublic":      rs.isPublic,
		"relayEnabled":  rs.relay != nil,
		"publicAddrs":   len(rs.publicAddrs),
		"trackedPeers":  len(rs.peerScores),
	}

	// Add connection type breakdown
	conns := rs.host.Network().Conns()
	direct := 0
	relayed := 0
	for _, conn := range conns {
		if strings.Contains(conn.RemoteMultiaddr().String(), "/p2p-circuit") {
			relayed++
		} else {
			direct++
		}
	}

	info["directConns"] = direct
	info["relayedConns"] = relayed

	return info
}

// IsPublic returns whether this node has a public IP
func (rs *RelayService) IsPublic() bool {
	return rs.isPublic
}

// GetPeerScores returns current peer scores (for debugging)
func (rs *RelayService) GetPeerScores() map[peer.ID]*PeerScore {
	rs.scoreMutex.RLock()
	defer rs.scoreMutex.RUnlock()

	// Return a copy
	scores := make(map[peer.ID]*PeerScore)
	for k, v := range rs.peerScores {
		scores[k] = v
	}
	return scores
}

// Close cleans up relay service resources
func (rs *RelayService) Close() error {
	if rs.relay != nil {
		return rs.relay.Close()
	}
	return nil
}

// SetBandwidthLimit sets the bandwidth limit for relay service (Mbps)
func (rs *RelayService) SetBandwidthLimit(mbps int64) {
	rs.bandwidth.mutex.Lock()
	defer rs.bandwidth.mutex.Unlock()
	rs.bandwidth.limitMbps = mbps
}

// ConnectionCallback should be called when a relay connection succeeds/fails
// This updates peer scores for better relay selection
func (rs *RelayService) ConnectionCallback(peerID peer.ID, success bool, latency time.Duration) {
	rs.UpdatePeerScore(peerID, success, latency)
}
