package node

import (
	"context"
	"crypto/rand"
	"fmt"

	"github.com/libp2p/go-libp2p"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	drouting "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	dutil "github.com/libp2p/go-libp2p/p2p/discovery/util"
	"github.com/multiformats/go-multiaddr"
)

// P2PNode represents a libp2p node with P2P capabilities
type P2PNode struct {
	Host   host.Host
	DHT    *dht.IpfsDHT
	PubSub *pubsub.PubSub
	ctx    context.Context
}

// NewP2PNode creates a new P2P node with full capabilities:
// - NAT Traversal (Relay + AutoNAT + Hole Punching)
// - Local Discovery (mDNS)
// - Global Discovery (DHT)
// - PubSub Messaging (GossipSub)
func NewP2PNode(ctx context.Context) (*P2PNode, error) {
	// Generate a new keypair for this node
	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.RSA, 2048, rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate key pair: %w", err)
	}

	// Create libp2p host
	h, err := libp2p.New(
		libp2p.Identity(priv),
		libp2p.ListenAddrStrings(
			"/ip4/0.0.0.0/tcp/0",      // Random TCP port
			"/ip4/0.0.0.0/udp/0/quic", // QUIC transport
		),
		libp2p.NATPortMap(),        // Enable NAT port mapping
		libp2p.EnableNATService(),  // Enable NAT service
		libp2p.EnableRelay(),       // Enable circuit relay
		libp2p.EnableAutoRelayWithStaticRelays(getBootstrapPeers()), // Auto relay
		libp2p.EnableHolePunching(), // Enable hole punching
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create host: %w", err)
	}

	// Print host info
	fmt.Printf("🆔 Peer ID: %s\n", h.ID().String())
	fmt.Printf("🌐 Listening on:\n")
	for _, addr := range h.Addrs() {
		fmt.Printf("   - %s/p2p/%s\n", addr, h.ID())
	}

	// Create DHT for peer discovery
	kadDHT, err := dht.New(ctx, h, dht.Mode(dht.ModeAutoServer))
	if err != nil {
		return nil, fmt.Errorf("failed to create DHT: %w", err)
	}

	// Bootstrap the DHT
	if err = kadDHT.Bootstrap(ctx); err != nil {
		return nil, fmt.Errorf("failed to bootstrap DHT: %w", err)
	}

	// Connect to bootstrap nodes
	go connectToBootstrapPeers(ctx, h, kadDHT)

	// Create PubSub with GossipSub
	ps, err := pubsub.NewGossipSub(ctx, h)
	if err != nil {
		return nil, fmt.Errorf("failed to create pubsub: %w", err)
	}

	// Start peer discovery
	go discoverPeers(ctx, h, kadDHT)

	return &P2PNode{
		Host:   h,
		DHT:    kadDHT,
		PubSub: ps,
		ctx:    ctx,
	}, nil
}

// getBootstrapPeers returns the list of bootstrap peer addresses
func getBootstrapPeers() []peer.AddrInfo {
	// IPFS bootstrap nodes
	bootstrapPeers := []string{
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt",
	}

	var peers []peer.AddrInfo
	for _, addrStr := range bootstrapPeers {
		addr, err := multiaddr.NewMultiaddr(addrStr)
		if err != nil {
			continue
		}
		peerInfo, err := peer.AddrInfoFromP2pAddr(addr)
		if err != nil {
			continue
		}
		peers = append(peers, *peerInfo)
	}
	return peers
}

// connectToBootstrapPeers connects to bootstrap nodes
func connectToBootstrapPeers(ctx context.Context, h host.Host, kadDHT *dht.IpfsDHT) {
	bootstrapPeers := getBootstrapPeers()

	fmt.Printf("\n🔗 Connecting to %d bootstrap peers...\n", len(bootstrapPeers))

	for _, peerInfo := range bootstrapPeers {
		if peerInfo.ID == h.ID() {
			continue // Skip self
		}

		if err := h.Connect(ctx, peerInfo); err != nil {
			// fmt.Printf("⚠️  Failed to connect to %s: %v\n", peerInfo.ID, err)
		} else {
			fmt.Printf("✅ Connected to bootstrap peer: %s\n", peerInfo.ID.String()[:10]+"...")
		}
	}
}

// discoverPeers continuously discovers new peers via DHT
func discoverPeers(ctx context.Context, h host.Host, kadDHT *dht.IpfsDHT) {
	routingDiscovery := drouting.NewRoutingDiscovery(kadDHT)

	// Advertise our presence
	dutil.Advertise(ctx, routingDiscovery, "p2p-chat")

	// Look for peers
	fmt.Println("\n🔍 Discovering peers...")

	for {
		peerChan, err := routingDiscovery.FindPeers(ctx, "p2p-chat")
		if err != nil {
			continue
		}

		for peerInfo := range peerChan {
			if peerInfo.ID == h.ID() {
				continue // Skip self
			}

			// Connect to discovered peer
			if err := h.Connect(ctx, peerInfo); err != nil {
				// Connection failed, that's ok
			} else {
				fmt.Printf("🤝 Connected to peer: %s\n", peerInfo.ID.String()[:10]+"...")
			}
		}
	}
}

// Close closes the P2P node
func (n *P2PNode) Close() error {
	if err := n.DHT.Close(); err != nil {
		return err
	}
	return n.Host.Close()
}
