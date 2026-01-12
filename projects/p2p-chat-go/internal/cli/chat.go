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
	store        *storage.MessageStore
	username     string
	displayNames map[peer.ID]string
}

// NewChatCLI creates a new CLI instance
func NewChatCLI(h host.Host, msg *messaging.P2PMessaging, store *storage.MessageStore) *ChatCLI {
	return &ChatCLI{
		host:         h,
		messaging:    msg,
		store:        store,
		username:     generateUsername(),
		displayNames: make(map[peer.ID]string),
	}
}

// generateUsername creates a random username
func generateUsername() string {
	rand.Seed(time.Now().UnixNano())
	return fmt.Sprintf("user_%d", rand.Intn(10000))
}

// Start begins the interactive CLI session
func (c *ChatCLI) Start() error {
	// Display welcome message
	c.printWelcome()

	// Show recent message history
	c.showHistory()

	// Send join notification
	if err := c.messaging.PublishMessage("join", fmt.Sprintf("%s joined the chat", c.username), c.username); err != nil {
		return fmt.Errorf("failed to send join message: %w", err)
	}

	// Start message listener
	go c.listenForMessages()

	// Start input loop
	return c.inputLoop()
}

// printWelcome displays the welcome message
func (c *ChatCLI) printWelcome() {
	fmt.Println("\n=== P2P Chat Started ===")
	fmt.Printf("Your Peer ID: %s\n", c.host.ID())
	fmt.Printf("Listening on: %s\n", c.host.Addrs()[0])
	fmt.Printf("Username: %s\n", c.username)
	fmt.Printf("\nConnected peers: %d\n", len(c.host.Network().Peers()))
	fmt.Println("Type /help for commands")
	fmt.Println()
}

// listenForMessages listens for incoming messages
func (c *ChatCLI) listenForMessages() {
	msgChan := c.messaging.ReadMessages()

	for msg := range msgChan {
		// Save message to store
		storeMsg := &storage.Message{
			Type:      msg.Type,
			Content:   msg.Content,
			Username:  msg.Username,
			Timestamp: msg.Timestamp,
			From:      msg.From,
		}
		if err := c.store.SaveMessage(storeMsg); err != nil {
			fmt.Printf("Error saving message: %v\n", err)
		}

		// Display message
		c.displayMessage(msg)
	}
}

// displayMessage displays a single message
func (c *ChatCLI) displayMessage(msg *messaging.Message) {
	timestamp := storage.FormatTimestamp(msg.Timestamp)

	switch msg.Type {
	case "message":
		fmt.Printf("[%s] %s: %s\n", timestamp, msg.Username, msg.Content)
	case "join":
		fmt.Printf("*** %s (at %s)\n", msg.Content, timestamp)
	case "leave":
		fmt.Printf("*** %s (at %s)\n", msg.Content, timestamp)
	}
	fmt.Print("> ")
}

// inputLoop handles user input
func (c *ChatCLI) inputLoop() error {
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Print("> ")

	for scanner.Scan() {
		input := strings.TrimSpace(scanner.Text())

		if input == "" {
			fmt.Print("> ")
			continue
		}

		// Handle commands
		if strings.HasPrefix(input, "/") {
			c.handleCommand(input)
		} else {
			// Send regular message
			if err := c.messaging.PublishMessage("message", input, c.username); err != nil {
				fmt.Printf("Error sending message: %v\n", err)
			} else {
				// Display own message
				fmt.Printf("[%s] %s: %s\n", storage.FormatTimestamp(time.Now().Unix()), c.username, input)

				// Save to store
				msg := &storage.Message{
					Type:      "message",
					Content:   input,
					Username:  c.username,
					Timestamp: time.Now().Unix(),
					From:      c.host.ID().String(),
				}
				if err := c.store.SaveMessage(msg); err != nil {
					fmt.Printf("Error saving message: %v\n", err)
				}
			}
		}

		fmt.Print("> ")
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("scanner error: %w", err)
	}

	return nil
}

// handleCommand processes CLI commands
func (c *ChatCLI) handleCommand(cmd string) {
	parts := strings.Fields(cmd)
	if len(parts) == 0 {
		return
	}

	switch parts[0] {
	case "/help":
		c.showHelp()
	case "/peers":
		c.showPeers()
	case "/history":
		c.showHistory()
	case "/quit", "/exit":
		fmt.Println("Goodbye!")
		os.Exit(0)
	default:
		fmt.Printf("Unknown command: %s (type /help for available commands)\n", parts[0])
	}
}

// showHelp displays available commands
func (c *ChatCLI) showHelp() {
	fmt.Println("\nAvailable Commands:")
	fmt.Println("  /help     - Show this help message")
	fmt.Println("  /peers    - List connected peers")
	fmt.Println("  /history  - Show recent message history")
	fmt.Println("  /quit     - Exit the chat")
	fmt.Println()
}

// showPeers displays connected peers
func (c *ChatCLI) showPeers() {
	peers := c.host.Network().Peers()
	fmt.Printf("\nConnected Peers (%d):\n", len(peers))
	for _, p := range peers {
		fmt.Printf("  - %s\n", p)
	}
	fmt.Println()
}

// showHistory displays recent message history
func (c *ChatCLI) showHistory() {
	messages, err := c.store.GetRecentMessages(10)
	if err != nil {
		fmt.Printf("Error retrieving history: %v\n", err)
		return
	}

	if len(messages) == 0 {
		fmt.Println("No message history yet.")
		return
	}

	fmt.Println("\nRecent messages:")
	for _, msg := range messages {
		timestamp := storage.FormatTimestamp(msg.Timestamp)
		switch msg.Type {
		case "message":
			fmt.Printf("[%s] %s: %s\n", timestamp, msg.Username, msg.Content)
		case "join", "leave":
			fmt.Printf("*** %s (at %s)\n", msg.Content, timestamp)
		}
	}
	fmt.Println()
}
