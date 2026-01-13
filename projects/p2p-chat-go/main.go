package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/geekp2p/p2p-chat-go/internal/cli"
	"github.com/geekp2p/p2p-chat-go/internal/messaging"
	"github.com/geekp2p/p2p-chat-go/internal/node"
	"github.com/geekp2p/p2p-chat-go/internal/storage"
	"github.com/geekp2p/p2p-chat-go/internal/updater"
)

func main() {
	// Print version info
	fmt.Printf("P2P Chat v%s\n", updater.Version)

	// Check for updates in background (non-blocking)
	go checkForUpdatesAsync()

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
	waitForMesh(msg, 10) // Wait up to 10 seconds for mesh to form

	// Start CLI (pass verbose flag pointer so it can be toggled)
	chatCLI := cli.NewChatCLI(p2pNode.Host, msg, store, &p2pNode.Verbose)
	if err := chatCLI.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "CLI error: %v\n", err)
		os.Exit(1)
	}
}

// checkForUpdatesAsync checks for updates in the background without blocking startup
func checkForUpdatesAsync() {
	// Give the app some time to start up before checking
	time.Sleep(2 * time.Second)

	release, hasUpdate, err := updater.CheckForUpdate(updater.Version)
	if err != nil {
		// Silently fail - don't interrupt user experience
		return
	}

	if hasUpdate && release != nil {
		fmt.Println()
		fmt.Printf("🎉 New version available: %s (current: %s)\n", release.TagName, updater.Version)
		fmt.Println("Run /update command to upgrade automatically")
		fmt.Println()
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
