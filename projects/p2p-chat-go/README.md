# P2P Chat (Golang Edition) 🚀

**Zero-config decentralized messaging with libp2p and GossipSub**

A fully decentralized peer-to-peer chat application built with **Go** and **libp2p**. This is a Golang rewrite of the Node.js P2P Chat, offering better performance, smaller Docker images, and improved reliability.

---

## 🎯 Features

### Core P2P Capabilities
- **Zero Configuration**: No central server, no setup - just run and chat
- **Automatic Peer Discovery**: Finds other peers using Kademlia DHT
- **GossipSub Messaging**: Efficient pub/sub messaging with message deduplication
- **Message Persistence**: BadgerDB stores chat history locally
- **Self-Healing Network**: Automatically reconnects to peers

### User Experience
- **Interactive CLI**: Simple, colorful terminal interface
- **Random Anonymous Usernames**: "user_1234" generated for each session
- **Message History**: View last 10 messages when joining
- **Peer Count**: See connected peer count in real-time
- **Commands**: `/help`, `/peers`, `/history`, `/quit`

### Technical Features
- **Multi-stage Docker Build**: Final image ~30MB (vs ~200MB Node.js)
- **BadgerDB Storage**: Fast, embedded key-value store
- **Graceful Shutdown**: Cleanup on CTRL+C
- **go-libp2p**: Reference implementation with best performance
- **NAT Traversal**: Circuit Relay v2, AutoNAT, and Hole Punching for cross-network connectivity
- **Multi-Transport**: TCP and QUIC support for better connectivity

---

## 🏗️ Architecture

```
p2p-chat-go/
├── cmd/p2p-chat/           # Main entry point
│   └── main.go             # Application bootstrap
│
├── internal/
│   ├── node/               # P2P Node management
│   │   └── p2p.go          # libp2p host, DHT, discovery
│   │
│   ├── messaging/          # Messaging layer
│   │   └── pubsub.go       # GossipSub pub/sub
│   │
│   ├── storage/            # Message persistence
│   │   └── store.go        # BadgerDB operations
│   │
│   └── cli/                # User interface
│       └── chat.go         # Interactive CLI
│
├── compose.yml             # Docker Compose config
├── Dockerfile              # Multi-stage build
└── README.md               # This file
```

### Components

#### 1. **P2P Node** (`internal/node/p2p.go`)
- Creates libp2p host with random identity
- Initializes Kademlia DHT for peer routing
- Implements peer discovery via DHT
- Listens on `/ip4/0.0.0.0/tcp/0` (random TCP port) and `/ip4/0.0.0.0/udp/0/quic-v1` (QUIC)
- **NAT Traversal Features**:
  - **Circuit Relay v2**: Enables connection through relay servers when direct connection fails
  - **AutoNAT**: Automatically detects if behind NAT and helps other peers
  - **Hole Punching**: Attempts direct connections through NAT when possible
  - **UPnP/NAT-PMP**: Automatic port mapping for compatible routers
  - **Public Relay Servers**: Connects to community relay nodes for NAT traversal

#### 2. **Messaging** (`internal/messaging/pubsub.go`)
- GossipSub protocol for efficient message propagation
- Topic-based rooms (default: `p2p-chat-default`)
- Message serialization (JSON)
- Subscription management

#### 3. **Storage** (`internal/storage/store.go`)
- BadgerDB for persistent message storage
- Timestamped message keys for chronological ordering
- CRUD operations: Save, Get, GetRecent, Clear
- Automatic cleanup on shutdown

#### 4. **CLI** (`internal/cli/chat.go`)
- Interactive terminal interface
- Real-time message display
- Command processing (`/help`, `/peers`, etc.)
- Input handling with bufio

---

## 📦 Docker Setup

### Quick Start

```bash
# Start P2P Chat
cd /home/user/compose-workbench-core
.\up.ps1 p2p-chat-go -Build

# Connect to interactive terminal
docker attach compose-workbench-core-chat-node-1
```

### Multiple Peers

```bash
# Terminal 1: Start first peer
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1

# Terminal 2: Start second peer
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Terminal 3: Start third peer
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

All peers will automatically discover each other via DHT!

### Configuration

Create `.env` file:
```bash
CHAT_TOPIC=my-private-room    # Default: p2p-chat-default
DATA_DIR=/app/data             # Message storage location
```

---

## 🎮 Usage

### Starting the Chat

```bash
# Build and run with docker-compose
docker compose -f projects/p2p-chat-go/compose.yml up --build

# Or use PowerShell wrapper
.\up.ps1 p2p-chat-go -Build
```

### Interactive Commands

Once connected, you'll see:
```
=== P2P Chat Started ===
Your Peer ID: 12D3KooWABC...
Listening on: /ip4/127.0.0.1/tcp/12345
Username: user_8532

Connected peers: 0
Type /help for commands
>
```

**Available Commands:**
- `/help` - Show available commands
- `/peers` - List connected peers with full IDs
- `/history` - Show last 10 messages
- `/verbose` - Toggle verbose mode (show/hide connection logs for debugging)
- `/quit` - Exit gracefully
- Just type text to send messages!

### Example Session

```
> Hello P2P World!
[user_8532] Hello P2P World!

> /peers
Connected Peers (2):
- 12D3KooWXYZ... (2m ago)
- 12D3KooWABC... (5m ago)

> /history
Recent messages:
[user_1234] Hey everyone! (2m ago)
[user_5678] Welcome to the network (3m ago)
[user_8532] Hello P2P World! (just now)
```

### Verbose Mode (Debug Logs)

By default, connection logs are **hidden** to keep the chat interface clean. If you need to see detailed connection logs for debugging:

```
> /verbose
✓ Verbose mode enabled (connection logs will be shown)

✓ Connection established: <peer.ID 12*9gd4bc>
✓ Connection established: <peer.ID 12*1DJinx>
✗ Connection lost: <peer.ID 12*foaRiZ>

> /verbose
✓ Verbose mode disabled (connection logs hidden)
```

**When to use verbose mode:**
- Debugging connection issues
- Monitoring peer discovery
- Understanding NAT traversal behavior
- Troubleshooting relay connections

**Default behavior:** Verbose mode is OFF - you only see chat messages and command outputs

---

## 🔧 Local Development

### Prerequisites
- Go 1.21+
- Docker & Docker Compose

### Build Locally

```bash
# Install dependencies
cd projects/p2p-chat-go
go mod download

# Run locally (development)
go run cmd/p2p-chat/main.go

# Build binary
go build -o p2p-chat cmd/p2p-chat/main.go
./p2p-chat
```

### Docker Build

```bash
# Build image
docker build -t p2p-chat-go:latest .

# Run container
docker run -it --rm p2p-chat-go:latest
```

---

## 🆚 Golang vs Node.js Comparison

| Feature | Golang | Node.js |
|---------|--------|---------|
| **Image Size** | ~30MB (alpine) | ~200MB |
| **Memory Usage** | ~20MB | ~80MB |
| **Startup Time** | <1s | ~2s |
| **libp2p** | Reference impl | Port of Go version |
| **Concurrency** | Native goroutines | Event loop |
| **Type Safety** | Compile-time | Runtime |
| **Binary** | Single executable | Requires Node runtime |

### Why Golang?

1. **Performance**: Compiled binary runs faster than interpreted JS
2. **Smaller Footprint**: Alpine-based images save disk/bandwidth
3. **Reference Implementation**: go-libp2p is the original libp2p
4. **Better Concurrency**: Goroutines handle P2P connections efficiently
5. **Type Safety**: Catch errors at compile time, not runtime
6. **Single Binary**: No `node_modules` bloat

---

## 🧪 Testing

### Test Multiple Peers

```bash
# Terminal 1
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1

# Terminal 2
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Terminal 3
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

**Expected behavior:**
1. All peers show "Connected peers: 2" (or more)
2. Messages sent from one appear in all terminals
3. `/peers` shows other peer IDs
4. `/history` persists across restarts

### Test Message Persistence

```bash
# Start peer, send messages, then quit
> Hello World
> Testing persistence
> /quit

# Start same peer again (reuse volume)
docker compose -f projects/p2p-chat-go/compose.yml up

# Run /history - should see previous messages!
> /history
```

---

## 📝 Message Format

Messages are JSON-encoded:

```json
{
  "type": "message",
  "content": "Hello World",
  "username": "user_8532",
  "timestamp": 1642345678,
  "from": "12D3KooWABC..."
}
```

### Message Types
- `message` - Regular chat message
- `join` - User joined notification
- `leave` - User left notification

---

## 🔒 Security & Privacy

### Decentralization
- **No central server** - all peers are equal
- **No single point of failure** - network continues if peers leave
- **No data collection** - messages stay in the network

### Privacy Considerations
- Messages are **NOT encrypted** by default (plaintext over P2P)
- Peer IDs are derived from keypairs (anonymous by default)
- Message history stored locally in BadgerDB (not shared)

### Production Recommendations
- Add end-to-end encryption (libp2p TLS/Noise)
- Implement authentication (signed messages)
- Rate limiting (prevent spam)
- Message size limits

---

## 🛠️ Troubleshooting

### No Peers Found

**Problem:** "Connected peers: 0" stays at zero

**Solutions:**
1. **Wait 30-60 seconds** - DHT discovery takes time
2. **Check network** - ensure Docker containers can communicate
3. **Same topic** - verify `CHAT_TOPIC` environment variable matches
4. **Bootstrap nodes** - libp2p uses public bootstrap nodes by default
5. **NAT/Firewall** - the app will attempt to use relay servers for NAT traversal

### Cross-Network Connectivity

**Understanding NAT Traversal:**

The application now supports connecting peers across different networks (e.g., home network to office network) using:

1. **Direct Connection (Best)**:
   - Works on same local network (LAN)
   - Shows in logs: `✓ Connection established`

2. **Hole Punching (Good)**:
   - Attempts direct connection through NAT
   - Both peers must support hole punching
   - May take 30-60 seconds to establish

3. **Circuit Relay (Fallback)**:
   - Connection through public relay server
   - Always works but adds latency
   - Shows in logs: `✓ Connected to relay server`

**Expected Behavior:**
- **Same network** (10.1.1.x ↔ 10.1.1.y): Direct connection ✅
- **Different networks** (10.1.1.x ↔ 192.168.0.y): Via relay or hole punching ✅
- **Behind strict NAT**: Will use relay servers (may take longer to connect)

**Logs to Look For:**
```
✓ Connected to relay server: 12D3Koo...
✓ Running as relay service (can help relay for other peers)
✓ Connection established: 12D3Koo...
Note: Not running as relay service (this is normal)
```

### Messages Not Appearing

**Problem:** Send message but others don't receive it

**Solutions:**
1. **Check peer count** - run `/peers` to verify connections
2. **Topic mismatch** - ensure all peers use same `CHAT_TOPIC`
3. **Network issues** - check Docker network connectivity

### Container Exits Immediately

**Problem:** Container starts and exits right away

**Solutions:**
1. **Missing TTY** - ensure `stdin_open: true` and `tty: true` in compose.yml
2. **Check logs** - `docker logs <container-id>`
3. **Rebuild** - `docker compose build --no-cache`

### Port Conflicts

**Problem:** "bind: address already in use"

**Solutions:**
1. **Random ports** - this app uses random ports (no conflicts)
2. **Check process** - `netstat -tulpn | grep <port>`
3. **Stop containers** - `.\down.ps1 p2p-chat-go`

---

## 🚀 Advanced Usage

### Custom Bootstrap Nodes

Modify `internal/node/p2p.go` to use your own bootstrap nodes:

```go
bootstrapPeers := []string{
    "/dnsaddr/your-bootstrap.example.com/p2p/12D3KooW...",
}
```

### Different DHT Modes

```go
// Server mode (always reachable)
kademliaDHT, err := dht.New(ctx, host, dht.Mode(dht.ModeServer))

// Client mode (only queries, doesn't serve)
kademliaDHT, err := dht.New(ctx, host, dht.Mode(dht.ModeClient))
```

### Message Encryption

Add noise or TLS transport:

```go
libp2p.New(
    libp2p.Security(noise.ID, noise.New),
    // ... other options
)
```

---

## 📚 References

- **libp2p**: https://libp2p.io/
- **go-libp2p**: https://github.com/libp2p/go-libp2p
- **GossipSub**: https://github.com/libp2p/specs/tree/master/pubsub/gossipsub
- **BadgerDB**: https://github.com/dgraph-io/badger
- **Kademlia DHT**: https://en.wikipedia.org/wiki/Kademlia

---

## 🎓 Learning Resources

- [libp2p Concepts](https://docs.libp2p.io/concepts/)
- [Building P2P Applications with libp2p](https://docs.libp2p.io/guides/)
- [GossipSub Specification](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/README.md)

---

## 📄 License

MIT License - see repository root for details

---

## 🤝 Contributing

Contributions welcome! This is a learning project for understanding P2P networking.

**Ideas for improvements:**
- Add end-to-end encryption
- Implement file sharing
- Web UI (libp2p works in browsers!)
- ✅ ~~Relay servers for NAT traversal~~ (Implemented!)
- Direct peer connections (beyond pub/sub)
- Private rooms with authentication
- Message reactions and threading

---

**Happy P2P Chatting! 🎉**
