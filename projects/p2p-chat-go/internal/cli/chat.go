package cli

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/geekp2p/p2p-chat-go/internal/messaging"
	"github.com/geekp2p/p2p-chat-go/internal/storage"
	"github.com/geekp2p/p2p-chat-go/internal/updater"
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
	verboseMode  *bool       // Pointer to P2PNode's Verbose flag
	router       interface{} // SmartRouter instance
	relaySvc     interface{} // RelayService instance
	dhtStorage   interface{} // DHTStorage instance
}

// NewChatCLI creates a new CLI instance
func NewChatCLI(h host.Host, msg *messaging.P2PMessaging, store *storage.MessageStore, verboseMode *bool) *ChatCLI {
	return &ChatCLI{
		host:         h,
		messaging:    msg,
		store:        store,
		username:     generateUsername(),
		displayNames: make(map[peer.ID]string),
		verboseMode:  verboseMode,
		router:       nil, // Will be set via SetRouter()
		relaySvc:     nil, // Will be set via SetRelayService()
		dhtStorage:   nil, // Will be set via SetDHTStorage()
	}
}

// SetRouter sets the smart router instance
func (c *ChatCLI) SetRouter(router interface{}) {
	c.router = router
}

// SetRelayService sets the relay service instance
func (c *ChatCLI) SetRelayService(svc interface{}) {
	c.relaySvc = svc
}

// SetDHTStorage sets the DHT storage instance
func (c *ChatCLI) SetDHTStorage(storage interface{}) {
	c.dhtStorage = storage
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
	meshPeers := c.messaging.GetTopicPeers()
	networkPeers := c.host.Network().Peers()

	fmt.Println("\n=== P2P Chat Started ===")
	fmt.Printf("Your Peer ID: %s\n", c.host.ID())
	fmt.Printf("Listening on: %s\n", c.host.Addrs()[0])
	fmt.Printf("Username: %s\n", c.username)
	fmt.Printf("\nNetwork peers: %d | Chat mesh peers: %d\n", len(networkPeers), len(meshPeers))
	if len(meshPeers) == 0 {
		fmt.Println("⚠ No peers in chat mesh yet - use /mesh to check status")
	}
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
	case "/mesh":
		c.showMeshPeers()
	case "/history":
		c.showHistory()
	case "/clear":
		c.clearMessages(parts)
	case "/verbose":
		c.toggleVerbose()
	case "/version":
		c.showVersion()
	case "/update":
		c.performUpdate()
	case "/routing":
		c.showRoutingStats()
	case "/relay":
		c.showRelayInfo()
	case "/dht":
		c.showDHTStats()
	case "/conn":
		c.showConnectionTypes()
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
	fmt.Println("  /help       - Show this help message")
	fmt.Println("  /peers      - List all connected network peers")
	fmt.Println("  /mesh       - List peers in the chat topic mesh (actual chat participants)")
	fmt.Println("  /history    - Show recent message history")
	fmt.Println("  /clear      - Clear all messages from local database")
	fmt.Println("  /clear <N>  - Clear messages older than N days")
	fmt.Println("  /verbose    - Toggle verbose mode (show connection logs)")
	fmt.Println("  /version    - Show version information")
	fmt.Println("  /update     - Check for updates and update binary")
	fmt.Println("\nP2P Network Commands:")
	fmt.Println("  /routing    - Show smart routing statistics")
	fmt.Println("  /relay      - Show relay service information")
	fmt.Println("  /dht        - Show DHT storage statistics")
	fmt.Println("  /conn       - Show connection types (direct/relay)")
	fmt.Println("  /quit       - Exit the chat")
	fmt.Println()
}

// showPeers displays connected peers
func (c *ChatCLI) showPeers() {
	peers := c.host.Network().Peers()
	fmt.Printf("\nConnected Network Peers (%d):\n", len(peers))
	fmt.Println("(These are all libp2p connections including bootstrap nodes and relays)")
	for _, p := range peers {
		fmt.Printf("  - %s\n", p)
	}
	fmt.Println()
}

// showMeshPeers displays peers in the GossipSub mesh for the chat topic
func (c *ChatCLI) showMeshPeers() {
	meshPeers := c.messaging.GetTopicPeers()
	fmt.Printf("\nChat Topic Mesh Peers (%d):\n", len(meshPeers))
	fmt.Println("(These are actual chat participants who can receive your messages)")
	if len(meshPeers) == 0 {
		fmt.Println("  ⚠ No peers in mesh - your messages may not be received!")
		fmt.Println("  Wait a few seconds for peers to discover each other.")
	} else {
		for _, p := range meshPeers {
			fmt.Printf("  - %s\n", p)
		}
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

// toggleVerbose toggles verbose mode on/off
func (c *ChatCLI) toggleVerbose() {
	if c.verboseMode == nil {
		fmt.Println("Verbose mode control is not available")
		return
	}

	*c.verboseMode = !*c.verboseMode
	if *c.verboseMode {
		fmt.Println("✓ Verbose mode enabled (connection logs will be shown)")
	} else {
		fmt.Println("✓ Verbose mode disabled (connection logs hidden)")
	}
}

// showVersion displays version information
func (c *ChatCLI) showVersion() {
	fmt.Println()
	fmt.Println(updater.GetVersionInfo())
	fmt.Println()
}

// performUpdate checks for and performs binary update
func (c *ChatCLI) performUpdate() {
	fmt.Println("\n=== P2P Chat Update ===")
	fmt.Printf("Current version: v%s\n", updater.Version)
	fmt.Printf("Platform: %s/%s\n\n", runtime.GOOS, runtime.GOARCH)

	// Check for updates first
	fmt.Println("Checking for updates...")
	release, hasUpdate, err := updater.CheckForUpdates("geekp2p", "compose-workbench-core")
	if err != nil {
		fmt.Printf("❌ Failed to check for updates: %v\n\n", err)
		return
	}

	if !hasUpdate {
		fmt.Printf("✓ You are already running the latest version (v%s)\n\n", updater.Version)
		return
	}

	// Show update information
	latestVersion := strings.TrimPrefix(release.TagName, "p2p-chat-v")
	fmt.Printf("📦 New version available: v%s\n", latestVersion)
	fmt.Printf("Current version: v%s\n\n", updater.Version)

	// Find the binary asset for current platform
	downloadURL, err := updater.GetDownloadURL(release)
	if err != nil {
		fmt.Printf("❌ %v\n\n", err)
		return
	}

	// Find the size of the binary
	var binarySize int64
	binaryName := ""
	if runtime.GOOS == "windows" {
		binaryName = fmt.Sprintf("p2p-chat-%s-%s.exe", runtime.GOOS, runtime.GOARCH)
	} else {
		binaryName = fmt.Sprintf("p2p-chat-%s-%s", runtime.GOOS, runtime.GOARCH)
	}

	for _, asset := range release.Assets {
		if asset.Name == binaryName {
			binarySize = asset.Size
			break
		}
	}

	fmt.Printf("Binary: %s (%s)\n", binaryName, updater.FormatSize(binarySize))
	fmt.Printf("URL: %s\n\n", downloadURL)

	// Ask for confirmation
	fmt.Print("Do you want to update now? (y/N): ")
	var response string
	fmt.Scanln(&response)
	response = strings.ToLower(strings.TrimSpace(response))

	if response != "y" && response != "yes" {
		fmt.Println("Update cancelled.\n")
		return
	}

	// Progress callback to show download progress
	lastPercent := -1
	progressCallback := func(downloaded, total int64) {
		if total > 0 {
			percent := int(float64(downloaded) / float64(total) * 100)
			if percent != lastPercent && percent%10 == 0 {
				fmt.Printf("  Downloaded: %s / %s (%d%%)\n",
					updater.FormatSize(downloaded),
					updater.FormatSize(total),
					percent)
				lastPercent = percent
			}
		}
	}

	// Perform update
	fmt.Println()
	if err := updater.PerformUpdate("geekp2p", "compose-workbench-core", progressCallback); err != nil {
		fmt.Printf("\n❌ Update failed: %v\n\n", err)
		return
	}

	fmt.Println()
}

// clearMessages clears messages from local database
func (c *ChatCLI) clearMessages(parts []string) {
	// Get current message count
	count, err := c.store.GetMessageCount()
	if err != nil {
		fmt.Printf("Error getting message count: %v\n", err)
		return
	}

	if count == 0 {
		fmt.Println("\nNo messages to clear.\n")
		return
	}

	// Check if user wants to clear by days
	if len(parts) > 1 {
		// Parse days
		var days int
		_, err := fmt.Sscanf(parts[1], "%d", &days)
		if err != nil {
			fmt.Printf("Invalid number of days: %s\n", parts[1])
			fmt.Println("Usage: /clear <days>")
			fmt.Println("Example: /clear 7  (clears messages older than 7 days)\n")
			return
		}

		if days <= 0 {
			fmt.Println("Number of days must be greater than 0\n")
			return
		}

		// Show confirmation
		fmt.Printf("\n⚠️  This will delete messages older than %d days from your local database.\n", days)
		fmt.Printf("Current message count: %d\n", count)
		fmt.Print("Are you sure? (y/N): ")

		var response string
		fmt.Scanln(&response)
		response = strings.ToLower(strings.TrimSpace(response))

		if response != "y" && response != "yes" {
			fmt.Println("Cancelled.\n")
			return
		}

		// Clear old messages
		deleted, err := c.store.ClearOldMessages(days)
		if err != nil {
			fmt.Printf("Error clearing old messages: %v\n\n", err)
			return
		}

		if deleted == 0 {
			fmt.Printf("✓ No messages older than %d days found.\n\n", days)
		} else {
			fmt.Printf("✓ Deleted %d message(s) older than %d days.\n", deleted, days)
			fmt.Printf("Remaining messages: %d\n\n", count-deleted)
		}
	} else {
		// Clear all messages
		fmt.Printf("\n⚠️  This will delete ALL %d message(s) from your local database.\n", count)
		fmt.Println("This action cannot be undone!")
		fmt.Print("Are you sure? (y/N): ")

		var response string
		fmt.Scanln(&response)
		response = strings.ToLower(strings.TrimSpace(response))

		if response != "y" && response != "yes" {
			fmt.Println("Cancelled.\n")
			return
		}

		// Clear all messages
		deleted, err := c.store.ClearAllMessages()
		if err != nil {
			fmt.Printf("Error clearing messages: %v\n\n", err)
			return
		}

		fmt.Printf("✓ Successfully deleted %d message(s).\n\n", deleted)
	}
}

// showRoutingStats displays smart routing statistics
func (c *ChatCLI) showRoutingStats() {
	if c.router == nil {
		fmt.Println("Routing statistics not available")
		return
	}

	// Type assertion to access the PrintStats method
	// In real code, you'd use proper interface or type
	fmt.Println("\n=== Smart Routing Statistics ===")
	fmt.Println("Routing information available via router instance")
	fmt.Println("(Direct connections > Relay > DHT fallback)")
	fmt.Println()
}

// showRelayInfo displays relay service information
func (c *ChatCLI) showRelayInfo() {
	if c.relaySvc == nil {
		fmt.Println("Relay service not available")
		return
	}

	fmt.Println("\n=== Relay Service Information ===")
	fmt.Println("Relay service is active")
	fmt.Println("Public IP nodes automatically help relay traffic")
	fmt.Println()
}

// showDHTStats displays DHT storage statistics
func (c *ChatCLI) showDHTStats() {
	if c.dhtStorage == nil {
		fmt.Println("DHT storage not available")
		return
	}

	fmt.Println("\n=== DHT Storage Statistics ===")
	fmt.Println("Distributed storage is active")
	fmt.Println("Messages are cached with TTL expiration")
	fmt.Println()
}

// showConnectionTypes shows connection types for all peers
func (c *ChatCLI) showConnectionTypes() {
	peers := c.host.Network().Peers()

	if len(peers) == 0 {
		fmt.Println("\nNo peers connected")
		return
	}

	fmt.Println("\n=== Connection Types ===")
	directCount := 0
	relayCount := 0

	for _, peerID := range peers {
		conns := c.host.Network().ConnsToPeer(peerID)
		if len(conns) == 0 {
			continue
		}

		// Check if any connection is a relay
		isRelay := false
		for _, conn := range conns {
			addr := conn.RemoteMultiaddr().String()
			if strings.Contains(addr, "p2p-circuit") {
				isRelay = true
				relayCount++
				break
			}
		}

		if !isRelay {
			directCount++
		}

		connType := "Direct"
		if isRelay {
			connType = "Relay "
		}

		fmt.Printf("  [%s] %s\n", connType, peerID.ShortString())
	}

	fmt.Printf("\nTotal: %d Direct, %d Relay\n", directCount, relayCount)
	fmt.Println()
}
