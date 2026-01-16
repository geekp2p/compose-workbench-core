package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/geekp2p/p2p-chat-go/internal/cli"
	dhtstorage "github.com/geekp2p/p2p-chat-go/internal/dht"
	"github.com/geekp2p/p2p-chat-go/internal/messaging"
	"github.com/geekp2p/p2p-chat-go/internal/node"
	relayservice "github.com/geekp2p/p2p-chat-go/internal/relay"
	"github.com/geekp2p/p2p-chat-go/internal/routing"
	"github.com/geekp2p/p2p-chat-go/internal/storage"
	"github.com/geekp2p/p2p-chat-go/internal/updater"
)

func main() {
	// Parse command-line flags
	versionFlag := flag.Bool("version", false, "Show version information")
	flag.Parse()

	// Handle --version flag
	if *versionFlag {
		fmt.Println(updater.GetVersionInfo())
		os.Exit(0)
	}

	// Print version on startup
	fmt.Printf("🚀 %s\n", updater.GetVersionInfo())
	fmt.Println()

	// Get configuration from environment variables
	chatTopic := os.Getenv("CHAT_TOPIC")
	if chatTopic == "" {
		chatTopic = "p2p-chat-default"
	}

	dataDir := os.Getenv("DATA_DIR")
	if dataDir == "" {
		dataDir = "./data"
	}

	// Create context that can be cancelled
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Println("\nShutting down gracefully...")
		cancel()
	}()

	// Initialize P2P node (verbose mode off by default)
	fmt.Println("Initializing P2P node...")
	p2pNode, err := node.NewP2PNode(ctx, false)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create P2P node: %v\n", err)
		os.Exit(1)
	}
	defer p2pNode.Close()

	// Initialize smart routing
	fmt.Println("Initializing smart routing...")
	router := routing.NewSmartRouter(ctx, p2pNode.Host, p2pNode.Verbose)
	p2pNode.Router = router

	// Initialize relay service
	fmt.Println("Checking for public IP and relay capabilities...")
	relaySvc := relayservice.NewRelayService(ctx, p2pNode.Host, p2pNode.Verbose)
	p2pNode.RelayService = relaySvc

	// Try to enable relay service if we have public IP
	if relaySvc.IsPublic() {
		if err := relaySvc.EnableRelayService(); err != nil {
			fmt.Printf("Note: Could not enable relay service: %v\n", err)
		}
	}

	// Initialize distributed storage
	fmt.Println("Initializing distributed storage (DHT-based)...")
	dhtStorage := dhtstorage.NewDistributedStorage(ctx, p2pNode.Host, p2pNode.DHT, p2pNode.Verbose)
	defer dhtStorage.Close()

	// Initialize message store
	fmt.Printf("Initializing message store at: %s\n", dataDir)
	store, err := storage.NewMessageStore(dataDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create message store: %v\n", err)
		os.Exit(1)
	}
	defer store.Close()

	// Initialize messaging
	fmt.Printf("Joining chat topic: %s\n", chatTopic)
	msg, err := messaging.NewP2PMessaging(ctx, p2pNode.PubSub, chatTopic, p2pNode.Host.ID())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create messaging: %v\n", err)
		os.Exit(1)
	}
	defer msg.Close()

	// Start peer discovery
	fmt.Println("Starting peer discovery...")
	if err := p2pNode.DiscoverPeers(ctx, chatTopic); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: peer discovery failed: %v\n", err)
	}

	// Wait for peers to connect and mesh to stabilize
	fmt.Println("Waiting for GossipSub mesh to form...")
	waitForMesh(msg, 30) // Wait up to 30 seconds for mesh to form

	// Start background mesh monitor to continuously improve connectivity
	go monitorMesh(ctx, msg, p2pNode)

	// Start CLI (pass verbose flag pointer so it can be toggled)
	chatCLI := cli.NewChatCLI(p2pNode.Host, msg, store, &p2pNode.Verbose)

	// Set additional services for CLI commands
	chatCLI.SetRouter(router)
	chatCLI.SetRelayService(relaySvc)
	chatCLI.SetDHTStorage(dhtStorage)

	if err := chatCLI.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "CLI error: %v\n", err)
		os.Exit(1)
	}
}

// waitForMesh waits for the GossipSub mesh to form (with timeout)
func waitForMesh(msg *messaging.P2PMessaging, maxSeconds int) {
	startTime := time.Now()
	lastMeshCount := 0

	for i := 0; i < maxSeconds; i++ {
		time.Sleep(1 * time.Second)

		// Check the actual GossipSub mesh peers
		meshPeers := msg.GetTopicPeers()
		meshCount := len(meshPeers)

		if meshCount > lastMeshCount {
			fmt.Printf("  Mesh peers: %d...\n", meshCount)
			lastMeshCount = meshCount
		}

		// If we have mesh peers and the count is stable, we're ready
		if meshCount > 0 && i >= 3 {
			elapsed := time.Since(startTime)
			fmt.Printf("✓ GossipSub mesh ready with %d peer(s) (took %v)\n", meshCount, elapsed.Round(time.Millisecond))
			return
		}
	}

	// Timeout reached
	meshPeers := msg.GetTopicPeers()
	meshCount := len(meshPeers)

	if meshCount > 0 {
		fmt.Printf("✓ Starting with %d mesh peer(s)\n", meshCount)
	} else {
		fmt.Println("⚠ No mesh peers found yet")
		fmt.Println("  This is normal if you're the first peer.")
		fmt.Println("  Messages will be delivered as other peers join.")
		fmt.Println("  Use /mesh to check mesh status.")
	}
}

// monitorMesh periodically checks mesh status and reports changes
func monitorMesh(ctx context.Context, msg *messaging.P2PMessaging, p2pNode *node.P2PNode) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	lastMeshCount := 0

	for {
		select {
		case <-ticker.C:
			meshPeers := msg.GetTopicPeers()
			meshCount := len(meshPeers)

			// Only report if mesh count changed
			if meshCount != lastMeshCount {
				if meshCount > lastMeshCount {
					fmt.Printf("\n✓ Mesh expanded: %d → %d peers\n", lastMeshCount, meshCount)
					if p2pNode.Verbose {
						for _, peerID := range meshPeers {
							fmt.Printf("  - %s\n", peerID.ShortString())
						}
					}
				} else if meshCount < lastMeshCount && meshCount > 0 {
					fmt.Printf("\n⚠ Mesh shrunk: %d → %d peers\n", lastMeshCount, meshCount)
				} else if meshCount == 0 && lastMeshCount > 0 {
					fmt.Printf("\n⚠ All mesh peers disconnected (was %d peers)\n", lastMeshCount)
				}
				lastMeshCount = meshCount
			}

		case <-ctx.Done():
			return
		}
	}
}
