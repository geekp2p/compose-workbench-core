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
}

// NewP2PNode creates a new P2P node with DHT and PubSub
func NewP2PNode(ctx context.Context) (*P2PNode, error) {
	// Generate a new keypair for this host
	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.Ed25519, 2048, rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate keypair: %w", err)
	}

	// Create a new libp2p Host that listens on a random TCP port
	h, err := libp2p.New(
		libp2p.Identity(priv),
		libp2p.ListenAddrStrings("/ip4/0.0.0.0/tcp/0"),
		libp2p.NATPortMap(), // Enable NAT port mapping
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
	if err := connectToBootstrapPeers(ctx, h); err != nil {
		fmt.Printf("Warning: failed to connect to some bootstrap peers: %v\n", err)
	}

	// Create a new PubSub service using GossipSub
	ps, err := pubsub.NewGossipSub(ctx, h)
	if err != nil {
		return nil, fmt.Errorf("failed to create pubsub: %w", err)
	}

	return &P2PNode{
		Host:   h,
		DHT:    kadDHT,
		PubSub: ps,
	}, nil
}

// connectToBootstrapPeers connects to well-known bootstrap peers
func connectToBootstrapPeers(ctx context.Context, h host.Host) error {
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
			fmt.Printf("Failed to connect to %s: %v\n", peerInfo.ID, err)
		} else {
			connected++
			fmt.Printf("Connected to bootstrap peer: %s\n", peerInfo.ID)
		}
	}

	if connected == 0 {
		return fmt.Errorf("failed to connect to any bootstrap peers")
	}

	return nil
}

// DiscoverPeers uses DHT to discover peers advertising the given namespace
func (n *P2PNode) DiscoverPeers(ctx context.Context, namespace string) error {
	// Advertise our presence
	routingDiscovery := drouting.NewRoutingDiscovery(n.DHT)
	dutil.Advertise(ctx, routingDiscovery, namespace)
	fmt.Printf("Advertising ourselves with namespace: %s\n", namespace)

	// Find other peers
	peerChan, err := routingDiscovery.FindPeers(ctx, namespace)
	if err != nil {
		return fmt.Errorf("failed to find peers: %w", err)
	}

	// Connect to discovered peers
	go func() {
		for peer := range peerChan {
			if peer.ID == n.Host.ID() {
				continue // Skip ourselves
			}

			if n.Host.Network().Connectedness(peer.ID) != 1 {
				if err := n.Host.Connect(ctx, peer); err != nil {
					fmt.Printf("Failed to connect to peer %s: %v\n", peer.ID, err)
				} else {
					fmt.Printf("Connected to peer: %s\n", peer.ID)
				}
			}
		}
	}()

	return nil
}

// Close shuts down the P2P node
func (n *P2PNode) Close() error {
	if err := n.DHT.Close(); err != nil {
		return err
	}
	return n.Host.Close()
}
