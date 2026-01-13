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
)

func main() {
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
	fmt.Println("Waiting for peer connections to establish...")
	waitForPeers(p2pNode, 5) // Wait up to 5 seconds for initial peers

	// Start CLI (pass verbose flag pointer so it can be toggled)
	chatCLI := cli.NewChatCLI(p2pNode.Host, msg, store, &p2pNode.Verbose)
	if err := chatCLI.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "CLI error: %v\n", err)
		os.Exit(1)
	}
}

// waitForPeers waits for peers to connect (with timeout)
func waitForPeers(node *node.P2PNode, maxSeconds int) {
	startTime := time.Now()
	lastPeerCount := 0

	for i := 0; i < maxSeconds; i++ {
		time.Sleep(1 * time.Second)
		peerCount := len(node.Host.Network().Peers())

		if peerCount > lastPeerCount {
			fmt.Printf("  Connected to %d peer(s)...\n", peerCount)
			lastPeerCount = peerCount
		}

		// If we have peers and count is stable, we can start
		if peerCount > 0 && i >= 2 {
			elapsed := time.Since(startTime)
			fmt.Printf("✓ Mesh ready with %d peer(s) (took %v)\n", peerCount, elapsed.Round(time.Millisecond))
			return
		}
	}

	// Timeout reached
	peerCount := len(node.Host.Network().Peers())
	if peerCount > 0 {
		fmt.Printf("✓ Starting with %d peer(s)\n", peerCount)
	} else {
		fmt.Println("⚠ No peers found yet - you can still send messages as new peers join")
	}
}
