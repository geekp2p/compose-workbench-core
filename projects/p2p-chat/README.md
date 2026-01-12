# P2P Chat - Decentralized Messaging

**Fully decentralized chat application** ที่ไม่ต้องพึ่ง central server - ใช้ libp2p สื่อสารแบบ P2P โดยตรง

## ✨ Features

### 🌐 True P2P Communication
- **ไม่ต้องมี Server** - ทุก peer เท่าเทียมกัน
- **ไม่ต้อง Public IP** - ใช้ Circuit Relay ทะลุ NAT/Firewall
- **Local Network Support** - หา peers ใน LAN อัตโนมัติด้วย mDNS

### 🔒 Security & Privacy
- **End-to-End Encryption** - ใช้ Noise Protocol
- **Peer Authentication** - ยืนยันตัวตนด้วย PeerId cryptographic
- **No Data Tracking** - ไม่มี central server เก็บข้อมูล

### 💾 Offline Message Support
- **Message Persistence** - เก็บข้อความไว้ใน LevelDB
- **Store & Forward** - Peer ที่ออนไลน์เก็บข้อความให้ peer ที่ออฟไลน์
- **Message History** - ดูประวัติการสนทนาย้อนหลังได้

### 📈 Scalability
- **GossipSub Protocol** - เหมือนที่ IPFS ใช้
- **Efficient Routing** - ไม่ broadcast ไปทุก peer
- **DHT Discovery** - หา peers แบบกระจาย

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│            P2P Chat Application                     │
├─────────────────────────────────────────────────────┤
│  CLI Interface (Interactive)                        │
│  └─ Commands: /help, /peers, /history, etc.       │
├─────────────────────────────────────────────────────┤
│  Messaging Layer                                    │
│  ├─ GossipSub: Broadcast messages                  │
│  ├─ Direct Messages: 1-on-1 streams (future)       │
│  └─ Message Store: LevelDB persistence             │
├─────────────────────────────────────────────────────┤
│  libp2p Core                                        │
│  ├─ Transport: TCP + WebSockets                    │
│  ├─ Security: Noise Protocol                       │
│  ├─ Muxer: Mplex                                    │
│  └─ Discovery: mDNS + DHT + Bootstrap              │
├─────────────────────────────────────────────────────┤
│  NAT Traversal                                      │
│  ├─ Circuit Relay v2: Relay through other peers    │
│  ├─ DCUtR: Direct Connection Upgrade               │
│  └─ AutoNAT: Auto detect NAT status                │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Method 1: Using Docker Compose (แนะนำ)

```bash
# 1. Build และรัน
docker compose up --build

# 2. เข้า container เพื่อใช้งาน chat
docker compose exec -it chat-node sh

# 3. Chat จะเริ่มอัตโนมัติ
```

### Method 2: Using Project Scripts

```powershell
# Windows PowerShell

# 1. Build และ start
.\up.ps1 p2p-chat -Build

# 2. Attach to the interactive container
docker compose -f projects/p2p-chat/compose.yml exec -it chat-node sh

# 3. Stop
.\down.ps1 p2p-chat
```

### Method 3: Local Development (ไม่ใช้ Docker)

```bash
# 1. Install dependencies
cd projects/p2p-chat
npm install

# 2. Run
npm start

# หรือใช้ watch mode (auto-reload)
npm run dev
```

---

## 🎮 How to Use

### Starting a Chat

เมื่อรันโปรแกรม คุณจะเห็นหน้าจอแบบนี้:

```
🚀 Starting P2P Chat...

💾 Initializing message store...
🌐 Creating P2P node...
▶️  Starting node...
📡 Initializing messaging (topic: p2p-chat-default)...
🖥️  Starting CLI...

╔═══════════════════════════════════════════════════╗
║         P2P Chat - Decentralized Messaging        ║
║     No servers • NAT Traversal • Offline Support  ║
╚═══════════════════════════════════════════════════╝

🆔 Your Peer ID: QmXsW3Y...
👤 Username: user-a3f9k
🌐 Listening on 4 address(es)

Commands:
  /help          - Show this help
  /peers         - List connected peers
  /name <name>   - Change your username
  /history       - Show message history
  /info          - Show node information
  /quit or /exit - Exit the chat
  <message>      - Send a broadcast message

user-a3f9k>
```

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/help` | แสดงคำสั่งทั้งหมด | `/help` |
| `/peers` | แสดง peers ที่เชื่อมต่ออยู่ | `/peers` |
| `/name <name>` | เปลี่ยนชื่อผู้ใช้ | `/name Alice` |
| `/history` | แสดงประวัติข้อความ (50 ข้อความล่าสุด) | `/history` |
| `/info` | แสดงข้อมูล node (PeerId, addresses) | `/info` |
| `/quit` หรือ `/exit` | ออกจากโปรแกรม | `/quit` |
| `<message>` | ส่งข้อความไปยังทุกคน | `Hello everyone!` |

### Example Session

```
user-a3f9k> /name Alice
✅ Username changed to: Alice

Alice> /peers
📊 Peer Information:
   Connected peers: 2
   Topic subscribers: 2

   Connected:
   1. QmXsW3Y...
   2. QmPq7Z8...

Alice> Hello everyone!

🔍 Discovered peer: QmRt5Nn...
🤝 Connected to: QmRt5Nn...

[14:23:15] Bob (QmXsW3Y...): Hi Alice!
[14:23:20] Charlie (QmPq7Z8...): Welcome!

Alice> Great to be here!

Alice> /history
📜 Message History (last 50 messages):
   [14:23:10] Alice (QmMe1Ab...): Hello everyone!
   [14:23:15] Bob (QmXsW3Y...): Hi Alice!
   [14:23:20] Charlie (QmPq7Z8...): Welcome!
   [14:23:25] Alice (QmMe1Ab...): Great to be here!
```

---

## 🔧 Configuration

### Environment Variables

สร้างไฟล์ `.env` (หรือ copy จาก `.env.example`):

```bash
# Chat topic/room - peers ที่ใช้ topic เดียวกันจะเจอกัน
CHAT_TOPIC=p2p-chat-default

# Node environment
NODE_ENV=production
```

### Custom Topics (Chat Rooms)

สร้างห้องแชทแยกได้โดยใช้ topic ต่างกัน:

```bash
# Terminal 1 - Room A
CHAT_TOPIC=room-a npm start

# Terminal 2 - Room B
CHAT_TOPIC=room-b npm start

# Terminal 3 - Room A (จะเจอกับ Terminal 1)
CHAT_TOPIC=room-a npm start
```

---

## 🧪 Testing Multi-Peer Communication

### Test 1: Local Network (2 Peers on Same Machine)

```bash
# Terminal 1
docker compose up --build

# Terminal 2 (ใน container อื่น)
docker compose run --rm chat-node

# Peers จะหากันอัตโนมัติผ่าน mDNS
```

### Test 2: Different Machines (NAT Traversal)

```bash
# Machine 1
docker compose up --build

# Machine 2 (คนละเครือข่าย)
docker compose up --build

# Peers จะหากันผ่าน:
# 1. Bootstrap nodes
# 2. DHT
# 3. Circuit Relay (ถ้าอยู่หลัง NAT)
```

### Test 3: Multiple Containers

```bash
# Scale to 3 peers
docker compose up --build --scale chat-node=3

# หรือใช้ Docker Compose v2
docker compose up --build --scale chat-node=3 -d
docker compose logs -f
```

---

## 🌐 How NAT Traversal Works

### Problem: Peers Behind Firewall/NAT

```
[Peer A]   <-- NAT/Firewall -->   Internet   <-- NAT/Firewall -->   [Peer B]
(Private IP)                                                        (Private IP)
```

Cannot connect directly ❌

### Solution: Circuit Relay + DCUtR

```
                         [Relay Node]
                              ^
                             / \
                            /   \
                           /     \
[Peer A] ----------------->     <----------------- [Peer B]
 (Step 1: Connect via Relay)

[Peer A] <----------------------------------------> [Peer B]
 (Step 2: Upgrade to direct connection using DCUtR)
```

**Steps:**
1. **Peer A** และ **Peer B** หากันผ่าน DHT หรือ Bootstrap nodes
2. เชื่อมต่อผ่าน **Relay Node** (peer อื่นที่ช่วย relay)
3. ใช้ **DCUtR** (Direct Connection Upgrade through Relay) เพื่อ hole-punch
4. สร้าง **direct connection** ถ้าได้ (ประหยัด bandwidth)
5. ถ้าไม่ได้ ใช้ relay ต่อไป (fallback)

---

## 📊 Message Flow

### Broadcast Message Flow

```
[Peer A] --publish--> [GossipSub Network] --propagate--> [Peer B, C, D]
                           |
                           v
                     [Message Store]
                     (ทุก peer เก็บ)
```

### Offline Message Retrieval (Future Feature)

```
[Peer A] --online--> [Request messages since timestamp]
                           |
                           v
                     [Peer B, C, D]
                     (ส่งข้อความที่พลาดกลับมา)
```

---

## 🗂️ Project Structure

```
projects/p2p-chat/
├── src/
│   ├── network/
│   │   └── p2p-node.js          # libp2p node creation & config
│   ├── messaging/
│   │   └── pubsub.js            # GossipSub messaging
│   ├── storage/
│   │   └── message-store.js     # LevelDB message persistence
│   ├── cli/
│   │   └── chat-cli.js          # Interactive CLI interface
│   └── index.js                 # Main entry point
├── data/                        # Message database (auto-created)
├── Dockerfile                   # Container definition
├── compose.yml                  # Docker Compose config
├── package.json                 # Node.js dependencies
├── .env.example                 # Example environment variables
├── .gitignore                   # Git ignore rules
└── README.md                    # This file
```

---

## 📦 Dependencies

### Core Libraries

- **libp2p** - P2P networking framework
- **@libp2p/tcp** - TCP transport
- **@libp2p/websockets** - WebSocket transport
- **@chainsafe/libp2p-noise** - Noise Protocol encryption
- **@libp2p/mplex** - Stream multiplexing
- **@chainsafe/libp2p-gossipsub** - PubSub messaging
- **@libp2p/kad-dht** - Distributed Hash Table
- **@libp2p/mdns** - Local network discovery
- **@libp2p/circuit-relay-v2** - NAT traversal relay
- **@libp2p/dcutr** - Direct connection upgrade

### Storage & Utilities

- **level** - LevelDB for message persistence
- **uint8arrays** - Uint8Array utilities
- **readline** - CLI interface

---

## 🔍 Troubleshooting

### Issue: No peers connecting

**Symptoms:**
```
user-abc> /peers
📊 Peer Information:
   Connected peers: 0
   Topic subscribers: 0
   No peers connected yet. Waiting for discovery...
```

**Solutions:**
1. **Check network connectivity**
   ```bash
   # Test internet connection
   curl https://bootstrap.libp2p.io
   ```

2. **Use same CHAT_TOPIC**
   ```bash
   # Peers ต้องใช้ topic เดียวกัน
   CHAT_TOPIC=my-room npm start
   ```

3. **Wait longer** - Discovery อาจใช้เวลา 30-60 วินาที

4. **Check firewall** - อาจบล็อก connections

### Issue: Messages not sending

**Symptoms:**
```
Alice> Hello
❌ Failed to send message (no peers connected?)
```

**Solutions:**
1. **ต้องมี peers เชื่อมต่อก่อน** - รัน `/peers` เช็ค
2. **Restart node** - บางครั้งต้อง reconnect

### Issue: Container exits immediately

**Symptoms:**
```
docker compose up
p2p-chat-chat-node-1 exited with code 0
```

**Solutions:**
```bash
# ใช้ -it flag เพื่อ interactive mode
docker compose run --rm -it chat-node

# หรือ attach to running container
docker compose up -d
docker compose exec -it chat-node sh
```

---

## 🚧 Future Enhancements

### Short Term
- [ ] Direct (1-on-1) messages
- [ ] File sharing (small files)
- [ ] Message encryption (additional layer)
- [ ] Peer reputation system

### Medium Term
- [ ] WebRTC transport (browser support)
- [ ] Voice chat (audio streams)
- [ ] Mobile app (React Native + libp2p)

### Long Term
- [ ] Video chat
- [ ] Group calls
- [ ] Distributed file storage (IPFS integration)
- [ ] Smart contract integration (Web3)

---

## 🤝 Contributing

ต้องการปรับปรุง? Welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

---

## 📚 Resources

- [libp2p Documentation](https://docs.libp2p.io/)
- [IPFS & libp2p](https://docs.ipfs.tech/concepts/libp2p/)
- [GossipSub Spec](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/README.md)
- [Circuit Relay v2](https://github.com/libp2p/specs/blob/master/relay/circuit-v2.md)

---

## 📜 License

MIT License - ดู LICENSE file

---

## 💬 Questions?

- Open an issue on GitHub
- Check documentation: [TEMPLATES.md](../../TEMPLATES.md)
- Review main README: [README.md](../../README.md)

---

**Built with ❤️ using libp2p - The P2P networking stack powering IPFS and Ethereum**
