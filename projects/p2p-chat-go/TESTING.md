# 🧪 คู่มือการทดสอบ P2P DHT Network

คู่มือนี้ครอบคลุมการทดสอบทุกฟีเจอร์ของระบบ P2P รวมถึงฟีเจอร์ใหม่:
- ✨ Distributed Storage (DHT-based)
- ✨ Auto Relay Service
- ✨ Smart Routing
- ✨ Enhanced CLI Commands

---

## 📦 เตรียมพร้อมก่อนทดสอบ

### ข้อกำหนด
- Docker และ Docker Compose ติดตั้งแล้ว
- Terminal อย่างน้อย 3 หน้าต่าง
- เครือข่ายเสถียร (สำหรับทดสอบ cross-network)

### Build โปรเจค
```powershell
# จาก root directory
cd /home/user/compose-workbench-core
.\up.ps1 p2p-chat-go -Build
```

---

## 1️⃣ การทดสอบพื้นฐาน (Basic Functionality Tests)

### Test 1.1: Single Peer Startup
**วัตถุประสงค์:** ตรวจสอบว่า peer เดียวสามารถ start ได้สมบูรณ์

```powershell
# Terminal 1
.\up.ps1 p2p-chat-go -Build
docker attach compose-workbench-core-chat-node-1
```

**ผลลัพธ์ที่คาดหวัง:**
```
🚀 P2P Chat v0.3.2
Initializing P2P node...
✓ P2P node started
  Peer ID: 12D3KooW...
  Addresses:
    - /ip4/127.0.0.1/tcp/xxxxx
    - /ip4/172.x.x.x/tcp/xxxxx

Initializing smart routing...
Checking for public IP and relay capabilities...
Initializing distributed storage (DHT-based)...
Initializing message store at: /app/data
Joining chat topic: p2p-chat-default
Starting peer discovery...

=== P2P Chat Started ===
Username: user_xxxx
Type /help for commands
>
```

✅ **Pass:** แสดงข้อความทั้งหมดโดยไม่มี error
❌ **Fail:** มี error หรือ crash

---

### Test 1.2: Multiple Peers Discovery
**วัตถุประสงค์:** ทดสอบการค้นหา peers อัตโนมัติ

```powershell
# Terminal 1
docker attach compose-workbench-core-chat-node-1

# Terminal 2
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Terminal 3
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

**รอ 30-60 วินาที แล้วรันคำสั่งในแต่ละ terminal:**
```
> /peers
```

**ผลลัพธ์ที่คาดหวัง:**
```
Connected Peers (2):
- 12D3KooWXYZ... (connected 1m ago)
- 12D3KooWABC... (connected 2m ago)
```

✅ **Pass:** แต่ละ peer เห็นอีก 2 peers
⚠️ **Warning:** หาก peers น้อยกว่า 2 รอ 1-2 นาทีเพิ่มเติม
❌ **Fail:** ยังไม่เห็น peers หลังรอ 3 นาที

---

### Test 1.3: Message Broadcasting
**วัตถุประสงค์:** ทดสอบการส่งข้อความระหว่าง peers

```powershell
# Terminal 1
> Hello from Peer 1

# Terminal 2
> Hello from Peer 2

# Terminal 3
> Hello from Peer 3
```

**ผลลัพธ์ที่คาดหวัง:**
- ทุก terminal เห็นข้อความจากทุก peers
- ข้อความมี username และ timestamp

✅ **Pass:** ข้อความปรากฏในทุก terminal ภายใน 2 วินาที
❌ **Fail:** ข้อความไม่ปรากฏหรือปรากฏเฉพาะบาง terminals

---

## 2️⃣ การทดสอบ DHT Storage (Distributed Storage Tests)

### Test 2.1: DHT Storage Statistics
**วัตถุประสงค์:** ตรวจสอบสถานะ DHT storage

```powershell
# รันในแต่ละ peer
> /dht
```

**ผลลัพธ์ที่คาดหวัง:**
```
=== DHT Storage Statistics ===
Stored items: X
Provider records: Y
Total size: Z bytes

Top 5 stored items:
1. CID: bafybeiabc... (Size: 123 bytes, TTL: 59m)
2. CID: bafybeifgh... (Size: 456 bytes, TTL: 58m)
...

Cache cleanup: Last run 5m ago
```

✅ **Pass:** แสดงข้อมูล DHT storage
❌ **Fail:** Error หรือไม่มีข้อมูล

---

### Test 2.2: DHT Message Persistence
**วัตถุประสงค์:** ทดสอบว่าข้อความถูกเก็บใน DHT และเรียกคืนได้

**ขั้นตอน:**
1. ส่งข้อความหลายๆ ข้อความจาก Peer 1:
```
> Test message 1
> Test message 2
> Test message 3
```

2. Stop Peer 1:
```
> /quit
```

3. Start Peer 4 ใหม่:
```powershell
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

4. ตรวจสอบว่า Peer 4 เห็นข้อความเก่า:
```
> /history
```

**ผลลัพธ์ที่คาดหวัง:**
- Peer 4 เห็นข้อความจาก DHT (อายุไม่เกิน TTL)
- ข้อความเรียงตาม timestamp

✅ **Pass:** เห็นข้อความเก่าจาก DHT
⚠️ **Warning:** เห็นบางข้อความ (อาจเกิน TTL)
❌ **Fail:** ไม่เห็นข้อความเลย

---

### Test 2.3: TTL Expiration
**วัตถุประสงค์:** ทดสอบว่าข้อความหมดอายุตาม TTL (1 ชั่วโมง default)

**ขั้นตอน:**
1. เช็ค TTL ของข้อความ:
```
> /dht
```

2. รอจนข้อความใกล้หมดอายุ (หรือปรับ TTL ให้สั้นลงในโค้ด)

3. เช็คอีกครั้ง:
```
> /dht
```

**ผลลัพธ์ที่คาดหวัง:**
- ข้อความที่หมดอายุถูกลบออกจาก cache
- `Cache cleanup` ทำงานอัตโนมัติ

✅ **Pass:** ข้อความหมดอายุถูกลบ
❌ **Fail:** ข้อความยังอยู่หลังหมดอายุ

---

## 3️⃣ การทดสอบ Relay Service (Auto Relay Tests)

### Test 3.1: Public IP Detection
**วัตถุประสงค์:** ตรวจสอบว่า node สามารถตรวจจับ public IP ได้

```powershell
# รันใน peer ที่มี public IP (หรือ simulate)
> /relay
```

**ผลลัพธ์ที่คาดหวัง (Node ที่มี public IP):**
```
=== Relay Service Status ===
Status: Running as relay service ✓
Public IP: Yes (x.x.x.x)

Relay Statistics:
- Active relays: 3
- Bandwidth used: 1.2 MB
- Connections relayed: 15

Top relay nodes:
1. 12D3KooW... (Score: 95, Bandwidth: 500 KB)
2. 12D3KooW... (Score: 87, Bandwidth: 400 KB)
```

**ผลลัพธ์ที่คาดหวัง (Node ที่ไม่มี public IP):**
```
=== Relay Service Status ===
Status: Not running as relay service
Public IP: No (behind NAT)

Available relay servers:
1. 12D3KooW... (Score: 95)
2. 12D3KooW... (Score: 87)
```

✅ **Pass:** ตรวจจับ public IP ถูกต้อง
❌ **Fail:** ตรวจจับผิดพลาด

---

### Test 3.2: Relay Connection (NAT Traversal)
**วัตถุประสงค์:** ทดสอบการเชื่อมต่อผ่าน relay สำหรับ nodes ที่อยู่หลัง NAT

**Setup สถานการณ์:**
- Peer A: Behind NAT (no public IP)
- Peer B: Behind NAT (no public IP)
- Peer C: Public IP (relay node)

**ขั้นตอน:**
1. Start Peer C (จำลอง public node):
```powershell
# Terminal 1
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

2. Start Peer A และ B (NAT nodes):
```powershell
# Terminal 2
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node

# Terminal 3
docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
```

3. เช็คการเชื่อมต่อ:
```
> /conn
```

**ผลลัพธ์ที่คาดหวัง:**
```
=== Connection Types ===
Direct connections: 1
Relay connections: 2
DHT connections: 0

Connection details:
- 12D3KooW... → Direct (latency: 5ms)
- 12D3KooW... → Relay via 12D3Koo... (latency: 50ms)
- 12D3KooW... → Relay via 12D3Koo... (latency: 45ms)
```

✅ **Pass:** Peer A และ B เชื่อมต่อกันผ่าน relay
⚠️ **Warning:** ใช้เวลานานกว่าปกติ (>60 วินาที)
❌ **Fail:** ไม่สามารถเชื่อมต่อผ่าน relay

---

### Test 3.3: Relay Failover
**วัตถุประสงค์:** ทดสอบว่าระบบสามารถสลับไปใช้ relay อื่นเมื่อ relay หลักล้มเหลว

**ขั้นตอน:**
1. Setup 2 relay nodes (C และ D) + 2 NAT nodes (A และ B)

2. เช็คว่า A และ B ใช้ relay ใด:
```
> /conn
```

3. Stop relay node ที่ A หรือ B ใช้อยู่:
```powershell
# หา container name
docker ps | grep chat-node

# Stop relay node
docker stop <relay-container-id>
```

4. เช็คการเชื่อมต่อใหม่:
```
> /conn
```

**ผลลัพธ์ที่คาดหวัง:**
- A และ B ยังคงเชื่อมต่อกันผ่าน relay อื่น
- แสดงข้อความ: `⚠ Relay connection lost, reconnecting...`
- หลังจาก 10-30 วินาที: `✓ Connected via new relay`

✅ **Pass:** Failover สำเร็จภายใน 30 วินาที
⚠️ **Warning:** Failover ช้า (30-60 วินาที)
❌ **Fail:** เชื่อมต่อขาด

---

## 4️⃣ การทดสอบ Smart Routing (Priority-based Connection Tests)

### Test 4.1: Connection Priority
**วัตถุประสงค์:** ตรวจสอบว่าระบบเลือกเส้นทางตาม priority: Direct > Relay > DHT

```powershell
# เช็ควิธีการเชื่อมต่อ
> /routing
```

**ผลลัพธ์ที่คาดหวัง:**
```
=== Smart Routing Statistics ===

Connection Strategy Priority:
1. Direct connection (preferred)
2. Circuit relay (fallback)
3. DHT-based routing (last resort)

Current Connections:
Total: 5 peers
├─ Direct: 2 peers (40%)
├─ Relay: 2 peers (40%)
└─ DHT: 1 peer (20%)

Performance:
- Average latency (direct): 5ms
- Average latency (relay): 45ms
- Average latency (DHT): 120ms
- Connection success rate: 95%

Recent activity:
✓ Direct connection to 12D3Koo... (2m ago)
✓ Relay connection via 12D3Koo... (5m ago)
✗ Direct connection failed to 12D3Koo... → using relay (8m ago)
```

✅ **Pass:** Direct connections มีค่า latency ต่ำที่สุด
⚠️ **Warning:** Relay มี latency สูงเกินไป (>100ms)
❌ **Fail:** DHT latency ต่ำกว่า Direct (ไม่สมเหตุสมผล)

---

### Test 4.2: Automatic Route Optimization
**วัตถุประสงค์:** ทดสอบว่าระบบพยายามหาเส้นทางที่ดีที่สุดอัตโนมัติ

**ขั้นตอน:**
1. Start 3 peers (A, B, C) โดย A และ B อยู่คนละ network

2. เช็ค routing ของ A:
```
> /routing
```

3. ทำให้ A และ B สามารถเชื่อมต่อ direct ได้ (เช่น เอา container ไปไว้ network เดียวกัน)

4. รอ 1-2 นาที แล้วเช็คอีกครั้ง:
```
> /routing
```

**ผลลัพธ์ที่คาดหวัง:**
- ตอนแรก A-B ใช้ relay connection
- หลังจาก optimize A-B เปลี่ยนเป็น direct connection
- แสดงข้อความ: `✓ Optimized route to 12D3Koo...: relay → direct`

✅ **Pass:** Route ถูก optimize อัตโนมัติ
⚠️ **Warning:** ใช้เวลานานในการ optimize (>5 นาที)
❌ **Fail:** ยังคงใช้ relay แม้ direct connection พร้อมใช้งาน

---

### Test 4.3: Latency Monitoring
**วัตถุประสงค์:** ตรวจสอบว่าระบบติดตาม latency และเลือก route ที่เร็วที่สุด

**ขั้นตอน:**
1. Setup network ที่มีหลาย routes:
   - Route 1: Direct (expected: <10ms)
   - Route 2: Relay via Node C (expected: 30-50ms)
   - Route 3: Relay via Node D (expected: 60-80ms)

2. ส่งข้อความหลายๆ ครั้ง:
```
> Test 1
> Test 2
> Test 3
```

3. เช็ค routing stats:
```
> /routing
```

**ผลลัพธ์ที่คาดหวัง:**
- ระบบเลือก route ที่มี latency ต่ำที่สุด
- Average latency ตรงกับ route ที่เลือก

✅ **Pass:** เลือก route ที่มี latency ต่ำที่สุด
❌ **Fail:** เลือก route ที่ช้ากว่า

---

## 5️⃣ การทดสอบ Cross-Network (Real-World Scenarios)

### Test 5.1: Same Network (LAN)
**วัตถุประสงค์:** ทดสอบการเชื่อมต่อภายใน network เดียวกัน

**Setup:**
- 3 peers ใน network เดียวกัน (เช่น 192.168.1.x)

**ผลลัพธ์ที่คาดหวัง:**
```
> /conn
Connection types:
- Direct: 100%
- Relay: 0%
```

✅ **Pass:** ทุกการเชื่อมต่อเป็น direct
❌ **Fail:** มี relay connection ใน LAN (ไม่จำเป็น)

---

### Test 5.2: Different Networks (WAN)
**วัตถุประสงค์:** ทดสอบการเชื่อมต่อข้าม networks (เช่น บ้าน → ออฟฟิศ)

**Setup:**
- Peer A: Network 1 (เช่น 10.0.1.x)
- Peer B: Network 2 (เช่น 192.168.0.x)
- Peer C: Public relay (มี public IP)

**ผลลัพธ์ที่คาดหวัง:**
```
> /conn
Connection to 12D3Koo... (different network):
- Type: Relay via 12D3KooC...
- Latency: 40-80ms
- Status: Connected ✓
```

✅ **Pass:** เชื่อมต่อผ่าน relay สำเร็จ
⚠️ **Warning:** Latency สูง (>100ms)
❌ **Fail:** ไม่สามารถเชื่อมต่อ

---

### Test 5.3: Behind Strict NAT
**วัตถุประสงค์:** ทดสอบการทำงานเมื่ออยู่หลัง NAT ที่เข้มงวด (Symmetric NAT)

**Setup:**
- Peer A: Behind strict NAT (ไม่มี UPnP)
- Peer B: Behind strict NAT (ไม่มี UPnP)
- Peer C: Public relay node

**ผลลัพธ์ที่คาดหวัง:**
- A และ B เชื่อมต่อผ่าน relay C
- **ไม่** สามารถทำ hole punching ได้ (strict NAT)
- แสดงข้อความ: `Note: Behind strict NAT, using relay service`

✅ **Pass:** เชื่อมต่อผ่าน relay สำเร็จ
❌ **Fail:** ไม่สามารถเชื่อมต่อ

---

## 6️⃣ การทดสอบ Performance & Scalability

### Test 6.1: Message Throughput
**วัตถุประสงค์:** วัดความเร็วในการส่งข้อความ

**ขั้นตอน:**
1. Start 5 peers

2. ส่งข้อความจาก Peer 1 อย่างต่อเนื่อง:
```bash
# สร้างสคริปต์ส่งข้อความอัตโนมัติ
for i in {1..100}; do
  echo "Test message $i"
  sleep 0.1
done
```

3. เช็คว่าทุก peers ได้รับข้อความครบ

**ผลลัพธ์ที่คาดหวัง:**
- Message delivery rate: >95%
- Average delivery time: <500ms
- No duplicate messages

✅ **Pass:** >95% delivery rate, <500ms latency
⚠️ **Warning:** 90-95% delivery rate หรือ 500-1000ms latency
❌ **Fail:** <90% delivery rate หรือ >1000ms latency

---

### Test 6.2: Peer Scalability
**วัตถุประสงค์:** ทดสอบการทำงานกับ peers จำนวนมาก

**ขั้นตอน:**
1. Start 10-20 peers พร้อมกัน:
```powershell
# PowerShell script
1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node
    }
}
```

2. รอ peers discover กัน (2-3 นาที)

3. เช็ค peer count ในแต่ละ node:
```
> /peers
```

**ผลลัพธ์ที่คาดหวัง:**
- แต่ละ peer เห็น >70% ของ total peers
- Memory usage ไม่เกิน 100MB ต่อ peer
- CPU usage <10%

✅ **Pass:** เห็น >70% peers, resource usage ต่ำ
⚠️ **Warning:** เห็น 50-70% peers หรือ resource usage สูง
❌ **Fail:** เห็น <50% peers หรือ crash

---

### Test 6.3: Network Partition Recovery
**วัตถุประสงค์:** ทดสอบการฟื้นตัวหลังจาก network partition

**ขั้นตอน:**
1. Start 4 peers (A, B, C, D)

2. Simulate network partition (แบ่งเป็น 2 กลุ่ม):
   - Group 1: A, B
   - Group 2: C, D

3. รอ 2-3 นาที

4. Restore network

5. เช็คว่า peers reconnect กันได้

**ผลลัพธ์ที่คาดหวัง:**
- หลัง partition: แต่ละกลุ่มเห็นเฉพาะ peer ในกลุ่ม
- หลัง restore: ทุก peers เห็นกันทั้งหมดภายใน 60 วินาที
- ข้อความจากทั้ง 2 กลุ่มถูก sync กัน (ผ่าน DHT)

✅ **Pass:** Reconnect ภายใน 60 วินาที และ sync ข้อความ
⚠️ **Warning:** Reconnect ช้า (1-3 นาที)
❌ **Fail:** ไม่ reconnect หรือข้อความหาย

---

## 7️⃣ การทดสอบ CLI Commands (Enhanced Commands)

### Test 7.1: All New Commands
**วัตถุประสงค์:** ทดสอบว่าคำสั่งใหม่ทำงานถูกต้อง

```powershell
# ทดสอบคำสั่งทั้งหมด
> /help           # ดูรายการคำสั่ง
> /peers          # ดู connected peers
> /routing        # ดู routing statistics
> /relay          # ดู relay service status
> /dht            # ดู DHT storage stats
> /conn           # ดู connection types
> /history        # ดู message history
> /verbose        # Toggle verbose mode
> /mesh           # ดู GossipSub mesh status
```

**ผลลัพธ์ที่คาดหวัง:**
- ทุกคำสั่งแสดงผลโดยไม่มี error
- ข้อมูลที่แสดงตรงกับสถานะจริง
- Format อ่านง่าย มี color highlights

✅ **Pass:** ทุกคำสั่งทำงานถูกต้อง
❌ **Fail:** มีคำสั่งที่ error หรือแสดงข้อมูลผิด

---

### Test 7.2: Verbose Mode Toggle
**วัตถุประสงค์:** ทดสอบการเปิด/ปิด verbose mode

```powershell
# เปิด verbose mode
> /verbose
✓ Verbose mode enabled (connection logs will be shown)

# ส่งข้อความ (ควรเห็น connection logs)
> Hello

# ปิด verbose mode
> /verbose
✓ Verbose mode disabled (connection logs hidden)

# ส่งข้อความ (ไม่เห็น connection logs)
> Hello again
```

**ผลลัพธ์ที่คาดหวัง:**
- Verbose ON: เห็น connection logs (✓ Connection established, ✗ Connection lost)
- Verbose OFF: ไม่เห็น connection logs (เห็นแค่ chat messages)

✅ **Pass:** Toggle ทำงานถูกต้อง
❌ **Fail:** Verbose mode ไม่เปลี่ยน

---

## 8️⃣ การทดสอบ Stress & Edge Cases

### Test 8.1: Rapid Connect/Disconnect
**วัตถุประสงค์:** ทดสอบเมื่อ peers เข้า-ออกบ่อย

**ขั้นตอน:**
1. Start 3 peers (A, B, C)

2. Loop: Start และ Stop peer D ทุก 10 วินาที:
```powershell
for ($i=1; $i -le 10; $i++) {
    docker compose -f projects/p2p-chat-go/compose.yml run --rm chat-node &
    Start-Sleep 10
    docker compose -f projects/p2p-chat-go/compose.yml down
}
```

3. เช็คว่า peers A, B, C ยังทำงานปกติ

**ผลลัพธ์ที่คาดหวัง:**
- A, B, C ไม่ crash
- แสดงข้อความ: `⚠ Peer disconnected: 12D3Koo...`
- Mesh recover อัตโนมัติ

✅ **Pass:** Stable ไม่ crash
❌ **Fail:** Crash หรือ mesh ไม่ recover

---

### Test 8.2: Large Messages
**วัตถุประสงค์:** ทดสอบการส่งข้อความขนาดใหญ่

```powershell
# ส่งข้อความ ~1KB
> Lorem ipsum dolor sit amet, consectetur adipiscing elit... (1000 characters)
```

**ผลลัพธ์ที่คาดหวัง:**
- ข้อความถูกส่งสำเร็จ
- ไม่มี truncation หรือ corruption
- DHT เก็บได้ (ตรวจสอบด้วย `/dht`)

✅ **Pass:** ส่งสำเร็จ ไม่มีปัญหา
⚠️ **Warning:** ช้า หรือ fragmented
❌ **Fail:** ส่งไม่สำเร็จ หรือ corrupted

---

### Test 8.3: Zero Peers (First Node)
**วัตถุประสงค์:** ทดสอบเมื่อเป็น peer แรกใน network

```powershell
# Start peer เดียว
docker compose -f projects/p2p-chat-go/compose.yml up --build
```

**ผลลัพธ์ที่คาดหวัง:**
```
Connected peers: 0
⚠ No mesh peers found yet
  This is normal if you're the first peer.
  Messages will be delivered as other peers join.
```

✅ **Pass:** แสดงข้อความที่เหมาะสม ไม่ crash
❌ **Fail:** Error หรือ crash

---

## 9️⃣ การทดสอบ Resource Usage (Performance Metrics)

### Test 9.1: Memory Usage
**วัตถุประสงค์:** วัดการใช้ memory

```powershell
# เช็ค memory usage
docker stats --no-stream | grep chat-node
```

**ผลลัพธ์ที่คาดหวัง:**
- Idle: <30MB
- 10 peers: <50MB
- 100 messages: <60MB

✅ **Pass:** Memory usage ตามเป้า
⚠️ **Warning:** 50-100MB
❌ **Fail:** >100MB

---

### Test 9.2: CPU Usage
**วัตถุประสงค์:** วัดการใช้ CPU

```powershell
docker stats --no-stream | grep chat-node
```

**ผลลัพธ์ที่คาดหวัง:**
- Idle: <5% CPU
- Sending messages: <20% CPU
- Peak: <50% CPU

✅ **Pass:** CPU usage ต่ำ
⚠️ **Warning:** 50-80% CPU
❌ **Fail:** >80% CPU sustained

---

### Test 9.3: Disk Usage (DHT + BadgerDB)
**วัตถุประสงค์:** วัดการใช้ disk space

```powershell
# เช็ค disk usage
docker exec <container-id> du -sh /app/data
```

**ผลลัพธ์ที่คาดหวัง:**
- 100 messages: <5MB
- 1000 messages: <20MB
- DHT cache: <10MB

✅ **Pass:** Disk usage เหมาะสม
⚠️ **Warning:** เติบโตเร็วมาก (>1MB/100 messages)
❌ **Fail:** Disk full

---

## 🔟 Checklist สรุปการทดสอบ

### ✅ Basic Functionality
- [ ] Test 1.1: Single Peer Startup
- [ ] Test 1.2: Multiple Peers Discovery
- [ ] Test 1.3: Message Broadcasting

### ✅ DHT Storage
- [ ] Test 2.1: DHT Storage Statistics
- [ ] Test 2.2: DHT Message Persistence
- [ ] Test 2.3: TTL Expiration

### ✅ Relay Service
- [ ] Test 3.1: Public IP Detection
- [ ] Test 3.2: Relay Connection (NAT Traversal)
- [ ] Test 3.3: Relay Failover

### ✅ Smart Routing
- [ ] Test 4.1: Connection Priority
- [ ] Test 4.2: Automatic Route Optimization
- [ ] Test 4.3: Latency Monitoring

### ✅ Cross-Network
- [ ] Test 5.1: Same Network (LAN)
- [ ] Test 5.2: Different Networks (WAN)
- [ ] Test 5.3: Behind Strict NAT

### ✅ Performance & Scalability
- [ ] Test 6.1: Message Throughput
- [ ] Test 6.2: Peer Scalability
- [ ] Test 6.3: Network Partition Recovery

### ✅ CLI Commands
- [ ] Test 7.1: All New Commands
- [ ] Test 7.2: Verbose Mode Toggle

### ✅ Stress & Edge Cases
- [ ] Test 8.1: Rapid Connect/Disconnect
- [ ] Test 8.2: Large Messages
- [ ] Test 8.3: Zero Peers (First Node)

### ✅ Resource Usage
- [ ] Test 9.1: Memory Usage
- [ ] Test 9.2: CPU Usage
- [ ] Test 9.3: Disk Usage

---

## 📈 Expected Results Summary

### ฟีเจอร์ที่ควรทำงาน 100%
- ✅ Single peer startup
- ✅ Multiple peers discovery (same network)
- ✅ Message broadcasting
- ✅ DHT storage statistics
- ✅ All CLI commands
- ✅ Graceful shutdown

### ฟีเจอร์ที่ควรทำงาน 80-90%
- ⚠️ Cross-network connectivity (ขึ้นกับ NAT type)
- ⚠️ Relay connection establishment (ต้องมี public relay)
- ⚠️ Automatic route optimization (ใช้เวลา)

### ฟีเจอร์ที่อาจมีปัญหา
- ⚠️ Strict NAT traversal (ต้องพึ่ง relay)
- ⚠️ Large-scale peer discovery (>50 peers)
- ⚠️ DHT TTL expiration (ต้องรอนาน)

---

## 🐛 Common Issues & Solutions

### Issue: Peers ไม่เจอกัน
**Solutions:**
1. รอ 60 วินาที (DHT discovery ช้า)
2. เช็ค network connectivity: `docker network ls`
3. เช็ค CHAT_TOPIC ต้องเหมือนกัน
4. ดู logs: `docker logs <container-id>`

### Issue: Relay ไม่ทำงาน
**Solutions:**
1. เช็คว่ามี peer ที่มี public IP: `/relay`
2. เช็ค AutoNAT: ดู logs หา "AutoNAT"
3. ลอง restart peers

### Issue: DHT storage ว่างเปล่า
**Solutions:**
1. รอ peers เชื่อมต่อ (DHT ต้องมี peers)
2. ส่งข้อความก่อน (ถึงจะมีข้อมูลใน DHT)
3. เช็ค DHT mode (ควรเป็น ModeAuto)

### Issue: High latency
**Solutions:**
1. เช็ค connection type: `/conn` (prefer direct over relay)
2. ดู routing stats: `/routing`
3. เช็ค network congestion

---

## 📝 Test Report Template

หลังจากทดสอบเสร็จ ให้บันทึกผลดังนี้:

```markdown
## Test Report - [วันที่]

### Environment
- OS: Windows/Linux/macOS
- Docker version: x.x.x
- Number of peers: X

### Test Results

#### ✅ Passed Tests
- Test 1.1: Single Peer Startup
- Test 2.1: DHT Storage Statistics
- ...

#### ⚠️ Warnings
- Test 5.2: WAN connectivity - latency สูง (120ms)
- ...

#### ❌ Failed Tests
- Test 3.3: Relay Failover - ใช้เวลานาน (>60s)
- ...

### Performance Metrics
- Average message delivery time: Xms
- Memory usage: XMB
- CPU usage: X%
- Peer discovery time: Xs

### Recommendations
- ...
```

---

**Happy Testing! 🎉**
