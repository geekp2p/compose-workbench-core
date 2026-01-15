# 🚀 เริ่มต้นทดสอบใน 5 นาที

คู่มือฉบับย่อสำหรับทดสอบ P2P DHT Network อย่างรวดเร็ว

---

## วิธีที่ 1: ทดสอบอัตโนมัติ (แนะนำ) ⚡

### ขั้นตอนที่ 1: รันสคริปต์ทดสอบ

```powershell
cd /home/user/compose-workbench-core

# Quick test (2 peers, 30 seconds)
.\projects\p2p-chat-go\test-basic.ps1 -Quick

# Full test (3 peers, 60 seconds)
.\projects\p2p-chat-go\test-basic.ps1 -Full
```

### ขั้นตอนที่ 2: ตรวจสอบผลลัพธ์

สคริปต์จะทดสอบ:
- ✅ Test 1.1: Single Peer Startup
- ✅ Test 1.2: Multiple Peers Discovery
- ⚠️ Test 1.3: Message Broadcasting (manual)

### ขั้นตอนที่ 3: Cleanup

```powershell
.\projects\p2p-chat-go\test-basic.ps1 -Cleanup
```

---

## วิธีที่ 2: ทดสอบแบบ Interactive (มีปฏิสัมพันธ์) 🎮

### ขั้นตอนที่ 1: Start Peers

```powershell
cd /home/user/compose-workbench-core

# Start 3 peers พร้อมกัน
.\projects\p2p-chat-go\test-interactive.ps1 -Action start -PeerCount 3
```

**Output:**
```
================================================
Starting 3 Peers
================================================
✓ Build complete
✓ Peer 1 started
✓ Peer 2 started
✓ Peer 3 started

✓ All 3 peers started!
Waiting 30 seconds for peer discovery...
```

### ขั้นตอนที่ 2: ตรวจสอบสถานะ

```powershell
.\projects\p2p-chat-go\test-interactive.ps1 -Action status
```

**Output:**
```
================================================
Peer Status
================================================
Running peers: 3

Peer #1 (abc123def456):
  Status: running
  Peer ID: 12D3KooWABC...
  Mesh peers: 2 ✓

Peer #2 (def789ghi012):
  Status: running
  Peer ID: 12D3KooWDEF...
  Mesh peers: 2 ✓

Peer #3 (ghi345jkl678):
  Status: running
  Peer ID: 12D3KooWGHI...
  Mesh peers: 2 ✓
```

### ขั้นตอนที่ 3: เข้าใช้งาน Chat

```powershell
# เลือก peer ที่ต้องการ (1, 2, หรือ 3)
.\projects\p2p-chat-go\test-interactive.ps1 -Action attach -PeerId 1
```

**Output:**
```
🔌 Connected! Try these commands:
  /peers    - Show connected peers
  /routing  - Show routing info
  /relay    - Show relay status
  /dht      - Show DHT storage
  /conn     - Show connection types
  /mesh     - Show mesh status
  /help     - Show all commands

⚠ To detach without stopping: Ctrl+P, then Ctrl+Q

=== P2P Chat Started ===
Username: user_xxxx
Type /help for commands
>
```

### ขั้นตอนที่ 4: ทดสอบฟีเจอร์

#### Test 1.2: Peer Discovery ✅
```
> /peers
Connected Peers (2):
- 12D3KooWDEF... (connected 2m ago)
- 12D3KooWGHI... (connected 2m ago)
```

#### Test 1.3: Message Broadcasting ✅
```
# ใน Peer 1
> Hello from Peer 1!

# Switch to Peer 2 (Ctrl+P, Ctrl+Q → attach to peer 2)
# คุณควรเห็น:
[user_1234] Hello from Peer 1!
```

#### Test New Features 🆕

**DHT Storage:**
```
> /dht
=== DHT Storage Statistics ===
Stored items: 5
Provider records: 3
Total size: 1.2 KB

Top 5 stored items:
1. CID: bafybeiabc... (Size: 256 bytes, TTL: 59m)
```

**Smart Routing:**
```
> /routing
=== Smart Routing Statistics ===

Connection Strategy Priority:
1. Direct connection (preferred)
2. Circuit relay (fallback)
3. DHT-based routing (last resort)

Current Connections:
Total: 2 peers
├─ Direct: 2 peers (100%)
├─ Relay: 0 peers (0%)
└─ DHT: 0 peer (0%)

Performance:
- Average latency (direct): 3ms
- Connection success rate: 100%
```

**Relay Service:**
```
> /relay
=== Relay Service Status ===
Status: Not running as relay service
Public IP: No (behind NAT)

Available relay servers:
1. 12D3KooW... (Score: 95)
```

**Connection Types:**
```
> /conn
=== Connection Types ===
Direct connections: 2
Relay connections: 0
DHT connections: 0

Connection details:
- 12D3KooWDEF... → Direct (latency: 3ms)
- 12D3KooWGHI... → Direct (latency: 2ms)
```

### ขั้นตอนที่ 5: Cleanup

```powershell
# Stop all peers
.\projects\p2p-chat-go\test-interactive.ps1 -Action stop

# หรือ Clean everything
.\projects\p2p-chat-go\test-interactive.ps1 -Action clean
```

---

## วิธีที่ 3: ทดสอบด้วยตนเอง (Manual) 🔧

### Terminal 1: Start First Peer

```powershell
cd /home/user/compose-workbench-core
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1
```

### Terminal 2: Start Second Peer

```powershell
cd /home/user/compose-workbench-core
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

### Terminal 3: Start Third Peer

```powershell
cd /home/user/compose-workbench-core
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

### รอ 30-60 วินาที แล้วทดสอบ

ใน Terminal 1:
```
> /peers
> /routing
> /relay
> /dht
> Hello from Peer 1!
```

ใน Terminal 2 และ 3:
- ควรเห็นข้อความ "Hello from Peer 1!"

---

## 📊 Expected Results (ผลลัพธ์ที่คาดหวัง)

### ✅ PASS Criteria

#### Test 1.1: Single Peer Startup
- Container starts successfully (no crash)
- Logs show:
  - ✅ "Initializing P2P node"
  - ✅ "Peer ID: 12D3KooW..."
  - ✅ "Initializing smart routing"
  - ✅ "Initializing distributed storage"
  - ✅ "P2P Chat Started"

#### Test 1.2: Multiple Peers Discovery
- All peers show "Connected peers: N" (where N > 0)
- `/peers` command lists other peer IDs
- Mesh forms within 60 seconds
- Success rate: **≥80%**

#### Test 1.3: Message Broadcasting
- Messages sent from one peer appear in all other peers
- No duplicate messages
- Delivery time: **<2 seconds**

### ⚠️ WARNING Criteria

- Peer discovery takes >60 seconds
- Success rate: 50-80%
- Some messages delayed (2-5 seconds)

### ❌ FAIL Criteria

- Container crashes or exits
- No peers discovered after 3 minutes
- Messages not delivered
- Success rate: <50%

---

## 🐛 Troubleshooting

### Problem: "Peers not found"
```powershell
# Solution 1: Wait longer (DHT takes time)
# Wait 1-2 minutes, then check again
> /peers

# Solution 2: Check containers are running
docker ps | grep chat-node

# Solution 3: Check logs
docker logs <container-id>
```

### Problem: "Messages not delivered"
```powershell
# Check mesh status
> /mesh

# Check connection types
> /conn

# Restart peers
.\projects\p2p-chat-go\test-interactive.ps1 -Action stop
.\projects\p2p-chat-go\test-interactive.ps1 -Action start -PeerCount 3
```

### Problem: "Container exits immediately"
```powershell
# Check logs
docker logs <container-id>

# Rebuild
docker compose -f projects/p2p-chat-go/compose.yml build --no-cache
```

---

## 📝 Quick Reference Card

| Command | Description |
|---------|-------------|
| `test-basic.ps1 -Quick` | Automated quick test (30s) |
| `test-basic.ps1 -Full` | Automated full test (60s) |
| `test-interactive.ps1 -Action start` | Start 3 peers |
| `test-interactive.ps1 -Action status` | Show peer status |
| `test-interactive.ps1 -Action attach -PeerId 1` | Attach to peer 1 |
| `test-interactive.ps1 -Action logs` | Show all logs |
| `test-interactive.ps1 -Action stop` | Stop all peers |
| `test-interactive.ps1 -Action clean` | Clean everything |

| Chat Command | Description |
|--------------|-------------|
| `/peers` | Show connected peers |
| `/routing` | Show routing statistics ✨ |
| `/relay` | Show relay service status ✨ |
| `/dht` | Show DHT storage stats ✨ |
| `/conn` | Show connection types ✨ |
| `/mesh` | Show GossipSub mesh status |
| `/history` | Show message history |
| `/verbose` | Toggle verbose mode |
| `/help` | Show all commands |
| `/quit` | Exit |

✨ = New feature

---

## 🎯 Next Steps

1. **After Basic Tests Pass** → Run advanced tests:
   ```powershell
   # Test DHT, Relay, Routing in detail
   See: TESTING.md (sections 2-4)
   ```

2. **For Cross-Network Testing** → See: TESTING.md (section 5)

3. **For Performance Testing** → See: TESTING.md (sections 6, 9)

4. **For Stress Testing** → See: TESTING.md (section 8)

---

**Happy Testing! 🚀**

Need help? Check:
- 📖 Full testing guide: [TESTING.md](TESTING.md)
- 📘 README: [README.md](README.md)
- 💬 Or open an issue on GitHub
