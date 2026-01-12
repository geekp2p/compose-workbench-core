package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/geekp2p/p2p-chat-go/internal/cli"
	"github.com/geekp2p/p2p-chat-go/internal/messaging"
	"github.com/geekp2p/p2p-chat-go/internal/node"
	"github.com/geekp2p/p2p-chat-go/internal/storage"
)

func main() {
	// Create context that can be canceled
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	fmt.Println("🚀 Starting P2P Chat...\n")

	// 1. Initialize message store
	fmt.Println("💾 Initializing message store...")
	dataDir := os.Getenv("DATA_DIR")
	if dataDir == "" {
		dataDir = "./data"
	}

	messageStore, err := storage.NewMessageStore(dataDir)
	if err != nil {
		fmt.Printf("❌ Failed to initialize message store: %v\n", err)
		os.Exit(1)
	}
	defer messageStore.Close()

	// 2. Create P2P node
	fmt.Println("🌐 Creating P2P node...")
	p2pNode, err := node.NewP2PNode(ctx)
	if err != nil {
		fmt.Printf("❌ Failed to create P2P node: %v\n", err)
		os.Exit(1)
	}
	defer p2pNode.Close()

	// 3. Get chat topic from environment or use default
	topic := os.Getenv("CHAT_TOPIC")
	if topic == "" {
		topic = "p2p-chat-default"
	}

	// 4. Initialize messaging
	fmt.Printf("📡 Initializing messaging (topic: %s)...\n", topic)
	msg, err := messaging.NewP2PMessaging(ctx, p2pNode.PubSub, topic)
	if err != nil {
		fmt.Printf("❌ Failed to initialize messaging: %v\n", err)
		os.Exit(1)
	}
	defer msg.Close()

	// Handle graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigCh
		fmt.Println("\n\n🛑 Shutting down...")
		cancel()
		messageStore.Close()
		msg.Close()
		p2pNode.Close()
		os.Exit(0)
	}()

	// 5. Start CLI
	fmt.Println("🖥️  Starting CLI...\n")
	chatCLI := cli.NewChatCLI(p2pNode.Host, msg, messageStore)
	chatCLI.Start()
}
