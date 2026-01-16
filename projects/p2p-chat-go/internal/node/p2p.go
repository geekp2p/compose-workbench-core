package node

import (
	"context"
	"fmt"
	"time"

	"github.com/geekp2p/p2p-chat-go/internal/identity"
	"github.com/geekp2p/p2p-chat-go/internal/peers"

	"github.com/libp2p/go-libp2p"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns"
	drouting "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	"github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay"
	"github.com/multiformats/go-multiaddr"
)

// P2PNode represents a libp2p node with P2P capabilities
type P2PNode struct {
	Host        host.Host
	DHT         *dht.IpfsDHT
	PubSub      *pubsub.PubSub
	Relay       *relay.Relay
	PeerManager *peers.PeerManager // Manages peer lifecycle and reconnection
	Verbose     bool               // Enable verbose logging for debugging
}

// discoveryNotifee implements mdns.Notifee for local peer discovery
type discoveryNotifee struct {
	h       host.Host
	verbose bool
}

// HandlePeerFound handles discovered peers from mDNS
func (n *discoveryNotifee) HandlePeerFound(pi peer.AddrInfo) {
	if n.verbose {
		fmt.Printf("✓ Discovered local peer via mDNS: %s\n", pi.ID.ShortString())
	}
	// Connect to discovered peer
	if err := n.h.Connect(context.Background(), pi); err != nil {
		if n.verbose {
			fmt.Printf("Failed to connect to mDNS peer %s: %v\n", pi.ID.ShortString(), err)
		}
	}
}

// NewP2PNode creates a new P2P node with DHT and PubSub
func NewP2PNode(ctx context.Context, verbose bool) (*P2PNode, error) {
	// Load or create persistent identity (ensures consistent peer ID across restarts)
	priv, err := identity.GetOrCreateIdentity("./data")
	if err != nil {
		return nil, fmt.Errorf("failed to get/create identity: %w", err)
	}

	// Create a new libp2p Host with enhanced NAT traversal capabilities
	h, err := libp2p.New(
		libp2p.Identity(priv),
		// Listen on TCP and QUIC for better connectivity
		libp2p.ListenAddrStrings(
			"/ip4/0.0.0.0/tcp/0",
			"/ip4/0.0.0.0/udp/0/quic-v1",
		),
		// Enable NAT traversal features
		libp2p.NATPortMap(),       // UPnP and NAT-PMP port mapping
		libp2p.EnableNATService(), // Help other peers detect their NAT status
		libp2p.EnableAutoRelayWithStaticRelays( // Enable circuit relay v2 client
			[]peer.AddrInfo{},
		),
		libp2p.EnableHolePunching(), // Enable hole punching
		libp2p.EnableRelay(),        // Allow being relayed through other peers
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create host: %w", err)
	}

	// Print host information
	fmt.Printf("Host created with ID: %s\n", h.ID())
	fmt.Printf("Listening on:\n")
	for _, addr := range h.Addrs() {
		fmt.Printf("  %s/p2p/%s\n", addr, h.ID())
	}

	// Create a new Kademlia DHT
	kadDHT, err := dht.New(ctx, h, dht.Mode(dht.ModeAuto))
	if err != nil {
		return nil, fmt.Errorf("failed to create DHT: %w", err)
	}

	// Bootstrap the DHT
	if err = kadDHT.Bootstrap(ctx); err != nil {
		return nil, fmt.Errorf("failed to bootstrap DHT: %w", err)
	}

	// Connect to bootstrap peers
	if err := connectToBootstrapPeers(ctx, h, verbose); err != nil {
		fmt.Printf("Warning: failed to connect to some bootstrap peers: %v\n", err)
	}

	// Try to enable relay service (optional, for nodes that can be public relays)
	var relayService *relay.Relay
	relayService, err = relay.New(h)
	if err != nil {
		fmt.Printf("Note: Not running as relay service (this is normal): %v\n", err)
		relayService = nil
	} else {
		fmt.Println("✓ Running as relay service (can help relay for other peers)")
	}

	// Connect to public relay servers for NAT traversal
	if err := connectToRelayServers(ctx, h, verbose); err != nil {
		fmt.Printf("Warning: failed to connect to relay servers: %v\n", err)
	}

	// Create a P2PNode instance to pass verbose flag to connection handlers
	node := &P2PNode{
		Host:    h,
		DHT:     nil, // Will be set later
		PubSub:  nil, // Will be set later
		Relay:   nil, // Will be set later
		Verbose: verbose,
	}

	// Set up connection notifications (only show in verbose mode)
	h.Network().Notify(&network.NotifyBundle{
		ConnectedF: func(n network.Network, conn network.Conn) {
			if node.Verbose {
				fmt.Printf("✓ Connection established: %s\n", conn.RemotePeer().ShortString())
			}
		},
		DisconnectedF: func(n network.Network, conn network.Conn) {
			if node.Verbose {
				fmt.Printf("✗ Connection lost: %s\n", conn.RemotePeer().ShortString())
			}
		},
	})

	// Create a new PubSub service using GossipSub with optimized configuration
	// These parameters are tuned for reliable mesh formation and message delivery
	// especially for peers behind NAT/firewalls
	// Start with default params to avoid divide-by-zero errors from missing fields
	gossipParams := pubsub.DefaultGossipSubParams()
	// Override specific parameters for better NAT traversal and smaller networks
	gossipParams.D = 4                                    // Desired mesh size (slightly higher for reliability)
	gossipParams.Dlo = 3                                  // Lower bound (maintain more connections)
	gossipParams.Dhi = 6                                  // Upper bound (allow more peers)
	gossipParams.Dlazy = 4                                // Lazy propagation factor (more backup routes)
	gossipParams.HeartbeatInterval = 700 * time.Millisecond // More frequent heartbeats for faster mesh formation
	gossipParams.FanoutTTL = 90 * time.Second             // Longer fanout TTL for unreliable connections
	gossipParams.GossipFactor = 0.25
	gossipParams.GossipRetransmission = 3
	gossipParams.HistoryLength = 6 // Keep more history for message recovery
	gossipParams.HistoryGossip = 3 // Gossip more history

	ps, err := pubsub.NewGossipSub(ctx, h,
		// Enable message signing for security
		pubsub.WithMessageSigning(true),
		// Enable strict signature verification
		pubsub.WithStrictSignatureVerification(true),
		// Enable peer exchange to help discover more peers
		pubsub.WithPeerExchange(true),
		// Set flood publishing to ensure message delivery even with small mesh
		pubsub.WithFloodPublish(true),
		// Apply our customized gossipsub parameters
		pubsub.WithGossipSubParams(gossipParams),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create pubsub: %w", err)
	}

	// Setup mDNS for local peer discovery
	if err := setupMDNS(h, verbose); err != nil {
		fmt.Printf("Warning: mDNS discovery not available: %v\n", err)
	} else if verbose {
		fmt.Println("✓ mDNS local peer discovery enabled")
	}

	// Update the node with DHT, PubSub, and Relay
	node.DHT = kadDHT
	node.PubSub = ps
	node.Relay = relayService
	// PeerManager will be set later by calling StartPeerManager

	return node, nil
}

// StartPeerManager initializes and starts the peer manager with auto-reconnect
func (n *P2PNode) StartPeerManager(ctx context.Context, topic string) error {
	fmt.Println("Starting peer discovery with auto-reconnect...")

	// Create routing discovery
	routingDiscovery := drouting.NewRoutingDiscovery(n.DHT)

	// Configure peer manager
	config := peers.DefaultConfig(topic)
	config.Verbose = n.Verbose

	// Create and start peer manager
	n.PeerManager = peers.NewPeerManager(ctx, n.Host, routingDiscovery, config)

	return nil
}

// connectToBootstrapPeers connects to well-known bootstrap peers
func connectToBootstrapPeers(ctx context.Context, h host.Host, verbose bool) error {
	// These are IPFS bootstrap nodes
	bootstrapPeers := []string{
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt",
	}

	connected := 0
	for _, peerAddr := range bootstrapPeers {
		addr, err := multiaddr.NewMultiaddr(peerAddr)
		if err != nil {
			continue
		}

		peerInfo, err := peer.AddrInfoFromP2pAddr(addr)
		if err != nil {
			continue
		}

		if err := h.Connect(ctx, *peerInfo); err != nil {
			if verbose {
				fmt.Printf("Failed to connect to %s: %v\n", peerInfo.ID, err)
			}
		} else {
			connected++
			if verbose {
				fmt.Printf("Connected to bootstrap peer: %s\n", peerInfo.ID)
			}
		}
	}

	if connected == 0 {
		return fmt.Errorf("failed to connect to any bootstrap peers")
	}

	return nil
}

// connectToRelayServers connects to public relay servers for NAT traversal
func connectToRelayServers(ctx context.Context, h host.Host, verbose bool) error {
	// Public relay servers (libp2p community relays)
	relayServers := []string{
		// Official libp2p relay servers
		"/ip4/147.75.83.83/tcp/4001/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb",
		"/ip4/147.75.77.187/tcp/4001/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa",
		// Add more public relays as available
	}

	connected := 0
	for _, relayAddr := range relayServers {
		addr, err := multiaddr.NewMultiaddr(relayAddr)
		if err != nil {
			if verbose {
				fmt.Printf("Invalid relay address %s: %v\n", relayAddr, err)
			}
			continue
		}

		relayInfo, err := peer.AddrInfoFromP2pAddr(addr)
		if err != nil {
			if verbose {
				fmt.Printf("Failed to parse relay address %s: %v\n", relayAddr, err)
			}
			continue
		}

		if err := h.Connect(ctx, *relayInfo); err != nil {
			if verbose {
				fmt.Printf("Failed to connect to relay %s: %v\n", relayInfo.ID.ShortString(), err)
			}
		} else {
			connected++
			if verbose {
				fmt.Printf("✓ Connected to relay server: %s\n", relayInfo.ID.ShortString())
			}

			// Reserve a slot on the relay for circuit connections
			// This allows other peers to dial us through this relay
		}
	}

	if connected > 0 {
		fmt.Printf("✓ Connected to %d relay server(s) for NAT traversal\n", connected)
	} else {
		if verbose {
			fmt.Println("Note: No relay servers connected (direct connections only)")
		}
	}

	return nil
}


// setupMDNS initializes mDNS discovery for local network peers
func setupMDNS(h host.Host, verbose bool) error {
	// Create a new mDNS service
	notifee := &discoveryNotifee{h: h, verbose: verbose}
	ser := mdns.NewMdnsService(h, "p2p-chat-mdns", notifee)
	if ser == nil {
		return fmt.Errorf("failed to create mDNS service")
	}
	return nil
}

// Close shuts down the P2P node
func (n *P2PNode) Close() error {
	if n.Relay != nil {
		if err := n.Relay.Close(); err != nil {
			fmt.Printf("Warning: failed to close relay: %v\n", err)
		}
	}
	if err := n.DHT.Close(); err != nil {
		return err
	}
	return n.Host.Close()
}
