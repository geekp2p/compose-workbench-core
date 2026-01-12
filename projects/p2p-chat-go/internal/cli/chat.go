package cli

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/geekp2p/p2p-chat-go/internal/messaging"
	"github.com/geekp2p/p2p-chat-go/internal/storage"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
)

// ChatCLI handles the interactive CLI interface
type ChatCLI struct {
	host         host.Host
	messaging    *messaging.P2PMessaging
	messageStore *storage.MessageStore
	username     string
	reader       *bufio.Reader
}

// NewChatCLI creates a new CLI instance
func NewChatCLI(h host.Host, msg *messaging.P2PMessaging, store *storage.MessageStore) *ChatCLI {
	// Generate random username
	username := fmt.Sprintf("user-%s", randomString(5))

	return &ChatCLI{
		host:         h,
		messaging:    msg,
		messageStore: store,
		username:     username,
		reader:       bufio.NewReader(os.Stdin),
	}
}

// Start starts the CLI
func (c *ChatCLI) Start() {
	c.showWelcome()
	c.showHelp()

	// Listen for incoming messages
	c.messaging.ReceiveMessages(c.handleIncomingMessage)

	// Handle user input
	for {
		fmt.Print(c.username + "> ")

		input, err := c.reader.ReadString('\n')
		if err != nil {
			fmt.Printf("❌ Error reading input: %v\n", err)
			continue
		}

		input = strings.TrimSpace(input)
		if input == "" {
			continue
		}

		c.handleCommand(input)
	}
}

// showWelcome displays the welcome message
func (c *ChatCLI) showWelcome() {
	fmt.Println()
	fmt.Println("╔═══════════════════════════════════════════════════╗")
	fmt.Println("║         P2P Chat - Decentralized Messaging        ║")
	fmt.Println("║     No servers • NAT Traversal • Offline Support  ║")
	fmt.Println("╚═══════════════════════════════════════════════════╝")
	fmt.Println()

	peerId := c.host.ID().String()
	fmt.Printf("🆔 Your Peer ID: %s...\n", peerId[:10])
	fmt.Printf("👤 Username: %s\n", c.username)
	fmt.Printf("🌐 Listening on %d address(es)\n", len(c.host.Addrs()))
	fmt.Println()
}

// showHelp displays available commands
func (c *ChatCLI) showHelp() {
	fmt.Println("Commands:")
	fmt.Println("  /help          - Show this help")
	fmt.Println("  /peers         - List connected peers")
	fmt.Println("  /name <name>   - Change your username")
	fmt.Println("  /history       - Show message history")
	fmt.Println("  /info          - Show node information")
	fmt.Println("  /quit or /exit - Exit the chat")
	fmt.Println("  <message>      - Send a broadcast message")
	fmt.Println()
}

// handleIncomingMessage handles incoming messages
func (c *ChatCLI) handleIncomingMessage(msg *messaging.Message) {
	if msg.Type == "broadcast" {
		t := time.UnixMilli(msg.Timestamp)
		timeStr := t.Format("15:04:05")
		fromShort := msg.From[:10] + "..."

		fmt.Printf("\n[%s] %s (%s): %s\n", timeStr, msg.Username, fromShort, msg.Content)
		fmt.Print(c.username + "> ")

		// Store the message
		storeMsg := &storage.Message{
			Type:      msg.Type,
			Content:   msg.Content,
			Username:  msg.Username,
			Timestamp: msg.Timestamp,
			From:      msg.From,
		}
		c.messageStore.StoreMessage(storeMsg)
	}
}

// handleCommand processes user commands
func (c *ChatCLI) handleCommand(input string) {
	if strings.HasPrefix(input, "/") {
		parts := strings.Fields(input)
		cmd := parts[0]

		switch cmd {
		case "/help":
			c.showHelp()

		case "/peers":
			c.showPeers()

		case "/name":
			if len(parts) > 1 {
				c.username = strings.Join(parts[1:], " ")
				fmt.Printf("✅ Username changed to: %s\n", c.username)
			} else {
				fmt.Println("❌ Usage: /name <username>")
			}

		case "/history":
			c.showHistory()

		case "/info":
			c.showInfo()

		case "/quit", "/exit":
			fmt.Println("\n👋 Goodbye!")
			os.Exit(0)

		default:
			fmt.Printf("❌ Unknown command: %s\n", cmd)
			fmt.Println("   Type /help for available commands")
		}
	} else {
		// Send broadcast message
		if err := c.messaging.SendBroadcast(input, c.username); err != nil {
			fmt.Printf("❌ Failed to send message: %v\n", err)
		} else {
			// Store own message
			msg := &storage.Message{
				Type:      "broadcast",
				Content:   input,
				Username:  c.username,
				Timestamp: time.Now().UnixMilli(),
				From:      c.host.ID().String(),
			}
			c.messageStore.StoreMessage(msg)
		}
	}
}

// showPeers displays connected peers
func (c *ChatCLI) showPeers() {
	connections := c.host.Network().Conns()
	pubsubPeers := c.messaging.GetPeers()

	fmt.Println("\n📊 Peer Information:")
	fmt.Printf("   Connected peers: %d\n", len(connections))
	fmt.Printf("   Topic subscribers: %d\n", len(pubsubPeers))

	if len(connections) > 0 {
		fmt.Println("\n   Connected:")
		// Get unique peer IDs
		peerSet := make(map[peer.ID]bool)
		for _, conn := range connections {
			peerSet[conn.RemotePeer()] = true
		}
		i := 1
		for peerID := range peerSet {
			fmt.Printf("   %d. %s...\n", i, peerID.String()[:10])
			i++
		}
	}

	if len(pubsubPeers) > 0 {
		fmt.Println("\n   In chat room:")
		for i, peerID := range pubsubPeers {
			fmt.Printf("   %d. %s...\n", i+1, peerID.String()[:10])
		}
	}

	if len(connections) == 0 && len(pubsubPeers) == 0 {
		fmt.Println("   No peers connected yet. Waiting for discovery...")
	}
	fmt.Println()
}

// showHistory displays message history
func (c *ChatCLI) showHistory() {
	fmt.Println("\n📜 Message History (last 50 messages):")

	messages, err := c.messageStore.GetAllMessages(50)
	if err != nil {
		fmt.Printf("❌ Failed to get messages: %v\n", err)
		return
	}

	if len(messages) == 0 {
		fmt.Println("   No messages yet.")
	} else {
		for _, msg := range messages {
			t := time.UnixMilli(msg.Timestamp)
			timeStr := t.Format("15:04:05")
			fromShort := msg.From[:10] + "..."
			fmt.Printf("   [%s] %s (%s): %s\n", timeStr, msg.Username, fromShort, msg.Content)
		}
	}
	fmt.Println()
}

// showInfo displays node information
func (c *ChatCLI) showInfo() {
	fmt.Println("\n🔍 Node Information:")
	fmt.Printf("   Peer ID: %s\n", c.host.ID().String())
	fmt.Printf("   Connections: %d\n", len(c.host.Network().Conns()))
	fmt.Println("\n   Listening addresses:")
	for _, addr := range c.host.Addrs() {
		fmt.Printf("   - %s/p2p/%s\n", addr, c.host.ID())
	}
	fmt.Println()
}

// randomString generates a random string of specified length
func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
