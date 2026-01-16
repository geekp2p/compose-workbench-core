# 🗺️ P2P DHT Network Testing Roadmap

## วิธีทดสอบอย่างเป็นขั้นตอน (Step-by-Step)

---

## 📋 Overview

คู่มือนี้จะแนะนำวิธีทดสอบระบบ P2P DHT Network แบบเป็นลำดับขั้นตอน ตั้งแต่:

1. **Level 1: Quick Start** (5 นาที) - ทดสอบพื้นฐาน
2. **Level 2: Feature Testing** (15 นาที) - ทดสอบฟีเจอร์ใหม่
3. **Level 3: Network Testing** (30 นาที) - ทดสอบข้ามเครือข่าย
4. **Level 4: Stress Testing** (45 นาที) - ทดสอบความแข็งแรง
5. **Level 5: Performance Testing** (60 นาที) - วัดประสิทธิภาพ

---

## 🎯 เป้าหมายการทดสอบแต่ละ Level

| Level | Focus | Duration | Success Criteria |
|-------|-------|----------|------------------|
| 1️⃣ Quick Start | เริ่มต้นได้ | 5 min | ✅ Peer start, connect, send message |
| 2️⃣ Feature Testing | DHT, Relay, Routing | 15 min | ✅ All CLI commands work |
| 3️⃣ Network Testing | Cross-network | 30 min | ✅ NAT traversal works |
| 4️⃣ Stress Testing | Stability | 45 min | ✅ No crashes, auto-recovery |
| 5️⃣ Performance | Metrics | 60 min | ✅ Meet performance targets |

---

## 🚀 Level 1: Quick Start (5 นาที)

### เป้าหมาย
- ✅ Start peer เดียว
- ✅ Start หลาย peers และค้นหากัน
- ✅ ส่งข้อความข้าม peers

### ขั้นตอน

#### Step 1.1: Build Project
```powershell
cd C:\compose-workbench-core
.\up.ps1 p2p-chat-go -Build
```

**Expected Output:**
```
✅ Building project...
✅ Starting compose-workbench-core-chat-node-1...
✅ Project started successfully!
```

#### Step 1.2: Start First Peer
```powershell
docker attach compose-workbench-core-chat-node-1
```

**Expected Output:**
```
🚀 P2P Chat v0.3.2
Initializing P2P node...

=== P2P Chat Started ===
Codename: Focused Turing        ← Your codename!
Username: user_4567
MAC: aa:bb:cc:dd:ee:ff
Peer ID: 12D3KooWABC...
Listening on: /ip4/0.0.0.0/tcp/4001
              /ip4/0.0.0.0/udp/4001/quic-v1

Type /help for commands
>
```

✅ **Pass Criteria:** Peer starts without errors

---

#### Step 1.3: Start Second Peer (New Terminal)
```powershell
# Open new PowerShell terminal
cd C:\compose-workbench-core
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

**Expected Output:**
```
=== P2P Chat Started ===
Codename: Admiring Lovelace     ← Different codename!
Username: user_8901
...
*** Focused Turing joined the chat    ← Discovered Peer 1!
```

✅ **Pass Criteria:**
- Peer 2 starts successfully
- Auto-discovers Peer 1 within 60 seconds
- Shows join message

---

#### Step 1.4: Send Message (From Peer 1)
```
> Hello from Focused Turing!
```

**Expected in Peer 2:**
```
[Focused Turing] Hello from Focused Turing!
```

✅ **Pass Criteria:** Message appears in both terminals

---

#### Step 1.5: Verify Codenames
```
> /peers
```

**Expected Output:**
```
Connected Peers (1):
1. Admiring Lovelace
   Peer ID: 12D3KooWXYZ...
   Connection: direct
   Latency: 45ms
```

✅ **Pass Criteria:** Shows peer codename correctly

---

### 🎉 Level 1 Complete!

If all steps passed:
- ✅ Basic peer functionality works
- ✅ Peer discovery works
- ✅ Message broadcasting works
- ✅ Codename generation works

**Next:** Continue to Level 2 to test new features!

---

## ✨ Level 2: Feature Testing (15 นาที)

### เป้าหมาย
- ✅ ทดสอบ DHT Storage
- ✅ ทดสอบ Relay Service
- ✅ ทดสอบ Smart Routing
- ✅ ทดสอบ CLI Commands ใหม่

### ขั้นตอน

#### Step 2.1: Test DHT Storage
**Run in any peer:**
```
> /dht
```

**Expected Output:**
```
📊 DHT Storage Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Records:      5
Provider Records:   2
Value Records:      3
Cache Size:         ~1.2 KB
Cleanup Interval:   5m0s
Last Cleanup:       30s ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Pass Criteria:** Command shows statistics

---

#### Step 2.2: Test Routing Statistics
```
> /routing
```

**Expected Output:**
```
🛣️ Routing Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Priority Levels:
  Direct Connections:     2 peers (67%)
  Relay Connections:      1 peer  (33%)
  DHT Fallback:           0 peers (0%)

Average Latency:          45ms
Success Rate:             98.5%
Total Routes Established: 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Pass Criteria:** Shows routing breakdown

---

#### Step 2.3: Test Relay Service Status
```
> /relay
```

**Expected Output (if public IP):**
```
🔁 Relay Service Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status:             ENABLED (Public IP detected)
Public IPs:         203.0.113.45
Relaying For:       2 peers
Bandwidth Used:     1.2 MB
Peer Score:         8.5/10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Expected Output (if behind NAT):**
```
🔁 Relay Service Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status:             DISABLED (Behind NAT/Firewall)
Using Relays:       2 peers
Connected Via:      /p2p/12D3.../p2p-circuit/...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Pass Criteria:** Shows relay status correctly

---

#### Step 2.4: Test Connection Types
```
> /conn
```

**Expected Output:**
```
🔌 Connection Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Admiring Lovelace:
  Type:      Direct
  Protocol:  /ip4/192.168.1.100/tcp/4001
  Latency:   45ms

Brave Hopper:
  Type:      Relay
  Protocol:  /p2p-circuit/...
  Latency:   120ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Pass Criteria:** Shows all peer connections

---

#### Step 2.5: Test Mesh Status
```
> /mesh
```

**Expected Output:**
```
🕸️ GossipSub Mesh Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Topic: p2p-chat
Mesh Peers:     2
Full Peers:     2
Fanout Peers:   0
Grafts:         2
Prunes:         0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **Pass Criteria:** Shows mesh topology

---

#### Step 2.6: Test Verbose Mode
```
> /verbose
```

**Expected Output:**
```
Verbose mode: ON
(Will show detailed connection logs)
```

**Send a message:**
```
> Test verbose mode
```

**Expected with verbose ON:**
```
📤 Broadcasting message...
  └─ DHT: Stored CID: bafybeiabc...
  └─ Relay: 1 hop, 120ms
  └─ Direct: 2 peers, 45ms avg
[Focused Turing] Test verbose mode
```

**Turn off verbose:**
```
> /verbose
Verbose mode: OFF
```

✅ **Pass Criteria:** Verbose mode toggles correctly

---

### 🎉 Level 2 Complete!

Tested all new features:
- ✅ `/dht` - DHT storage statistics
- ✅ `/routing` - Smart routing stats
- ✅ `/relay` - Relay service status
- ✅ `/conn` - Connection types
- ✅ `/mesh` - GossipSub mesh
- ✅ `/verbose` - Verbose mode toggle

**Next:** Continue to Level 3 for network testing!

---

## 🌐 Level 3: Network Testing (30 นาที)

### เป้าหมาย
- ✅ ทดสอบในเครือข่ายเดียวกัน (LAN)
- ✅ ทดสอบข้ามเครือข่าย (WAN)
- ✅ ทดสอบ NAT traversal

### Scenario 3.1: Same Network (LAN)

#### Setup
```powershell
# Start 3 peers on same machine
cd C:\compose-workbench-core

# Terminal 1
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1

# Terminal 2
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Terminal 3
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

#### Test
```
# In Peer 1
> /peers

# Expected: Shows 2 connected peers
> /routing

# Expected: Direct connections = 100%
```

✅ **Pass Criteria:**
- All peers discover each other within 60s
- All connections are "direct"
- Latency < 100ms

---

### Scenario 3.2: Different Networks (WAN)

#### Setup
**Machine A (Office/Home):**
```powershell
cd C:\compose-workbench-core
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1
```

**Machine B (Different Location):**
```powershell
git clone https://github.com/geekp2p/compose-workbench-core
cd compose-workbench-core
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1
```

#### Test
```
# Wait 60-120 seconds for discovery
> /peers
```

**Expected Output:**
```
Connected Peers (1):
1. Brave Hopper (from Machine B)
   Connection: relay or direct
   Latency: 50-200ms
```

#### Check Relay Usage
```
> /routing
```

**Expected:** Shows relay connections if behind NAT

✅ **Pass Criteria:**
- Peers discover each other (may take up to 2 minutes)
- Connection established via relay or direct
- Messages delivered successfully

---

### Scenario 3.3: Behind Strict NAT

#### Setup
**Test with Docker bridge network (simulates NAT):**
```yaml
# projects/p2p-chat-go/compose.yml
services:
  chat-node:
    networks:
      - nat_network  # ← Simulated NAT

networks:
  nat_network:
    driver: bridge
```

```powershell
.\up.ps1 p2p-chat-go -Build
```

#### Test
```
> /relay
```

**Expected:**
```
Status: DISABLED (Behind NAT)
Using Relays: 1-2 peers
```

```
> /routing
```

**Expected:** Shows relay connections

✅ **Pass Criteria:**
- Relay service detected
- Can connect via relay peers
- Messages delivered through relay

---

### 🎉 Level 3 Complete!

Network testing results:
- ✅ LAN: Direct connections work
- ✅ WAN: Cross-network connections work
- ✅ NAT: Relay traversal works

**Next:** Continue to Level 4 for stress testing!

---

## 💪 Level 4: Stress Testing (45 นาที)

### เป้าหมาย
- ✅ ทดสอบ connect/disconnect รวดเร็ว
- ✅ ทดสอบข้อความขนาดใหญ่
- ✅ ทดสอบ zero peers scenario
- ✅ ทดสอบ network partition recovery

### Test 4.1: Rapid Connect/Disconnect

#### Script
```powershell
# test-rapid-reconnect.ps1
for ($i = 1; $i -le 10; $i++) {
    Write-Host "Test $i/10: Starting peer..."

    # Start peer
    $job = Start-Job -ScriptBlock {
        docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
    }

    # Wait 30 seconds
    Start-Sleep 30

    # Stop peer
    Write-Host "Stopping peer..."
    Stop-Job $job
    Remove-Job $job

    # Wait 5 seconds
    Start-Sleep 5
}
```

#### Expected Result
- ✅ No crashes
- ✅ Clean startup/shutdown every time
- ✅ Resources cleaned up properly

---

### Test 4.2: Large Messages

```
# In chat, send large message (4KB+)
> /verbose
> Lorem ipsum dolor sit amet, consectetur adipiscing elit... [4000+ characters]
```

#### Check DHT Storage
```
> /dht
```

**Expected:**
```
Cache Size: ~5-10 KB  ← Increased
```

✅ **Pass Criteria:**
- Large message sent successfully
- DHT stores message
- All peers receive message

---

### Test 4.3: Zero Peers Scenario

#### Setup
```powershell
# Start single peer in isolated network
docker compose -f projects/p2p-chat-go/compose.yml run --rm --network none chat-node
```

#### Test
```
> /peers
```

**Expected:**
```
Connected Peers (0):
(Waiting for peers to join...)
```

```
> Hello?
[Focused Turing] Hello?    ← Message shown locally
```

✅ **Pass Criteria:**
- App doesn't crash
- Can send messages (stored locally)
- When peer joins later, messages sync

---

### Test 4.4: Network Partition Recovery

#### Simulate Network Split
```powershell
# Terminal 1: Start 3 peers (Group A)
# Terminal 2: Start 2 peers (Group B)

# Block communication between groups (simulate network partition)
# Using Docker network isolation
```

#### Then Reconnect Networks
```
# After 5 minutes, reconnect networks
```

#### Expected
```
> /peers

# Before: Shows only peers in same partition
# After: Shows all 5 peers
```

✅ **Pass Criteria:**
- Peers reconnect automatically
- Message history syncs
- DHT data reconciles

---

### 🎉 Level 4 Complete!

Stress testing results:
- ✅ Rapid reconnection: Stable
- ✅ Large messages: Handled
- ✅ Zero peers: No crashes
- ✅ Network partition: Auto-recovery

**Next:** Continue to Level 5 for performance testing!

---

## 📊 Level 5: Performance Testing (60 นาที)

### เป้าหมาย
- ✅ วัด Message throughput
- ✅ วัด Peer scalability
- ✅ วัด Resource usage
- ✅ วัด Network latency

### Test 5.1: Message Throughput

#### Script
```powershell
# test-throughput.ps1
# Send 100 messages rapidly

for ($i = 1; $i -le 100; $i++) {
    # Send message to peer
    "Message $i" | docker exec -i compose-workbench-core-chat-node-1 /bin/sh
    Start-Sleep -Milliseconds 100  # 10 msg/sec
}
```

#### Measure
```
> /mesh
```

**Expected:**
```
Messages Sent:     100
Success Rate:      >95%
Average Latency:   <500ms
```

✅ **Pass Criteria:**
- Throughput: >10 msg/sec
- Success rate: >95%
- Latency: <500ms

---

### Test 5.2: Peer Scalability

#### Setup
```powershell
# Start 10 peers
for ($i = 1; $i -le 10; $i++) {
    Start-Job -ScriptBlock {
        docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
    }
    Start-Sleep 5  # Stagger starts
}
```

#### Monitor
```
> /peers

# Expected: Shows 9 other peers (10 total)
```

#### Check Performance
```
> /routing
```

**Expected:**
```
Total Routes: 9
Success Rate: >90%
Avg Latency:  <200ms
```

✅ **Pass Criteria:**
- All peers connect
- Message delivery rate >95%
- Latency increases gracefully

---

### Test 5.3: Resource Usage

#### Monitor Docker Stats
```powershell
docker stats compose-workbench-core-chat-node-1
```

**Expected (Single Peer, Idle):**
```
CPU:    <5%
Memory: <50 MB
```

**Expected (10 Peers, Active):**
```
CPU:    <20%
Memory: <100 MB per peer
```

#### Check DHT Disk Usage
```
> /dht
```

**Expected:**
```
Cache Size: <10 MB (short-term)
BadgerDB:   <50 MB (with history)
```

✅ **Pass Criteria:**
- Memory: <50 MB (idle), <100 MB (active)
- CPU: <5% (idle), <20% (active)
- Disk: <50 MB total

---

### Test 5.4: Network Latency Distribution

#### Measure All Connections
```
> /conn
```

**Record latencies:**
```
Peer 1: 45ms
Peer 2: 67ms
Peer 3: 123ms (relay)
Peer 4: 52ms
...
```

#### Calculate Statistics
- **Average:** <100ms
- **P50 (Median):** <80ms
- **P95:** <200ms
- **P99:** <500ms

✅ **Pass Criteria:**
- Avg latency <100ms (direct)
- P95 <200ms (direct)
- Relay latency <500ms

---

### 🎉 Level 5 Complete!

Performance testing results:
- ✅ Throughput: >10 msg/sec
- ✅ Scalability: 10+ peers
- ✅ Memory: <50-100 MB
- ✅ Latency: <100ms avg

**Congratulations! You've completed all testing levels!** 🎊

---

## 📝 Test Results Summary Template

### Date: _________________
### Tester: _________________

| Level | Status | Notes |
|-------|--------|-------|
| 1️⃣ Quick Start | ⬜ Pass / ⬜ Fail | |
| 2️⃣ Feature Testing | ⬜ Pass / ⬜ Fail | |
| 3️⃣ Network Testing | ⬜ Pass / ⬜ Fail | |
| 4️⃣ Stress Testing | ⬜ Pass / ⬜ Fail | |
| 5️⃣ Performance Testing | ⬜ Pass / ⬜ Fail | |

### Detailed Results

#### Level 1: Quick Start
- [ ] Peer startup: ___ seconds
- [ ] Peer discovery: ___ seconds
- [ ] Message delivery: ⬜ Yes / ⬜ No
- [ ] Codename generated: ___________

#### Level 2: Feature Testing
- [ ] `/dht` command: ⬜ Pass / ⬜ Fail
- [ ] `/routing` command: ⬜ Pass / ⬜ Fail
- [ ] `/relay` command: ⬜ Pass / ⬜ Fail
- [ ] `/conn` command: ⬜ Pass / ⬜ Fail
- [ ] `/mesh` command: ⬜ Pass / ⬜ Fail
- [ ] `/verbose` toggle: ⬜ Pass / ⬜ Fail

#### Level 3: Network Testing
- [ ] LAN connections: ⬜ Pass / ⬜ Fail
- [ ] WAN connections: ⬜ Pass / ⬜ Fail
- [ ] NAT traversal: ⬜ Pass / ⬜ Fail
- [ ] Discovery time: ___ seconds

#### Level 4: Stress Testing
- [ ] Rapid reconnect: ⬜ Pass / ⬜ Fail
- [ ] Large messages: ⬜ Pass / ⬜ Fail
- [ ] Zero peers: ⬜ Pass / ⬜ Fail
- [ ] Partition recovery: ⬜ Pass / ⬜ Fail

#### Level 5: Performance Testing
- [ ] Throughput: ___ msg/sec
- [ ] Scalability: ___ peers
- [ ] Memory usage: ___ MB
- [ ] CPU usage: ___ %
- [ ] Avg latency: ___ ms

### Issues Found
1. ___________________________________________
2. ___________________________________________
3. ___________________________________________

### Recommendations
1. ___________________________________________
2. ___________________________________________
3. ___________________________________________

---

## 🔧 Troubleshooting

### Issue: Peer discovery takes too long

**Solution:**
```
# Check bootstrap peers
> /peers

# Wait up to 2 minutes
# If still no peers, check network connectivity
```

### Issue: High latency

**Solution:**
```
> /conn      # Check connection types
> /routing   # Check if using relay

# If mostly relay connections, check firewall/NAT
```

### Issue: Memory usage high

**Solution:**
```
> /dht       # Check cache size

# If cache > 50MB, restart peer to clear cache
docker restart compose-workbench-core-chat-node-1
```

---

## 📚 Related Documentation

- **[TESTING.md](TESTING.md)** - Detailed test cases (26 tests)
- **[QUICKTEST.md](QUICKTEST.md)** - 5-minute quick start guide
- **[TEST-SUMMARY.md](TEST-SUMMARY.md)** - Testing overview & workflow
- **[TEST-RESULTS-TEMPLATE.md](TEST-RESULTS-TEMPLATE.md)** - Report template
- **[CODENAME.md](CODENAME.md)** - Codename feature documentation
- **[README.md](README.md)** - Project documentation

---

## 🎯 Success Criteria Summary

| Metric | Target | Good | Acceptable | Fail |
|--------|--------|------|------------|------|
| **Discovery Time** | <60s | <30s | 60-120s | >120s |
| **Message Delivery** | >99% | >95% | 90-95% | <90% |
| **Latency (Direct)** | <50ms | <100ms | 100-200ms | >200ms |
| **Latency (Relay)** | <200ms | <300ms | 300-500ms | >500ms |
| **Memory Usage** | <50MB | <75MB | 75-100MB | >100MB |
| **CPU Usage (Idle)** | <5% | <10% | 10-20% | >20% |
| **Throughput** | >20/s | >10/s | 5-10/s | <5/s |
| **Scalability** | 20+ | 10+ | 5-10 | <5 |

---

## ✅ Quick Commands Reference

### Basic Testing
```powershell
# Start & attach
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1

# Start additional peer
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Cleanup
.\down.ps1 p2p-chat-go
.\clean.ps1 -Project p2p-chat-go
```

### Chat Commands (Inside Chat)
```
/peers      # List connected peers
/routing    # Routing statistics
/relay      # Relay service status
/dht        # DHT storage stats
/conn       # Connection details
/mesh       # GossipSub mesh status
/verbose    # Toggle verbose mode
/help       # Show all commands
/quit       # Exit chat
```

### Docker Monitoring
```powershell
# View logs
docker logs compose-workbench-core-chat-node-1

# Monitor resources
docker stats compose-workbench-core-chat-node-1

# List containers
docker ps
```

---

## 🎉 Happy Testing!

Follow this roadmap step-by-step, and you'll thoroughly test all aspects of the P2P DHT Network!

**Questions?** Check:
- 📖 [TESTING.md](TESTING.md) for detailed test cases
- 🚀 [QUICKTEST.md](QUICKTEST.md) for quick start
- 📊 [TEST-SUMMARY.md](TEST-SUMMARY.md) for overview
