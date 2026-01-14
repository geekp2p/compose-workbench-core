# 🏷️ Codename Feature

**Deterministic human-readable nicknames generated from MAC address**

---

## 🎯 Overview

The P2P Chat now generates a **unique, memorable codename** for each peer based on their MAC address. This makes it easier to identify peers in chat logs without exposing technical identifiers.

### Key Features

✅ **Deterministic** - Same MAC address = Same codename (across restarts)
✅ **Human-readable** - Format: "Adjective Surname" (e.g., "Focused Turing", "Admiring Lovelace")
✅ **Unique** - ~8,000+ possible combinations using Docker's namesgenerator
✅ **Memorable** - Famous names in tech/science (Turing, Einstein, Hopper, Knuth)
✅ **Privacy-friendly** - MAC address never exposed, only used as seed
✅ **Fallback support** - Uses hostname if MAC unavailable (Docker, VMs)

---

## 📋 How It Works

### 1. MAC Address Detection

The system finds the first **physical network interface** (non-virtual, non-loopback):

```
Physical interfaces ✅  → eth0, en0, wlan0
Virtual interfaces  ❌  → docker0, veth*, br-*, lo
```

### 2. Deterministic Generation

```
MAC Address → SHA256 Hash → Seed → Docker namesgenerator → Codename
```

**Example:**
```
MAC: "aa:bb:cc:dd:ee:ff"
↓ SHA256
Hash: "f4c9b2a8..."
↓ Seed (first 8 bytes as int64)
Seed: 0x123456789abcdef0
↓ rand.Seed() + namesgenerator
Raw: "focused_turing"
↓ Format to title case
Codename: "Focused Turing"
```

**Uses Docker's namesgenerator:**
- Same library Docker uses for container names
- ~8,000+ combinations (adjectives × famous surnames)
- Format: `adjective_surname` → `"Adjective Surname"`

### 3. Username Generation

Technical username is also generated from MAC:

```
MAC → SHA256 → User Number (0-9999) → "user_XXXX"
```

**Example:**
- Codename: `Focused Turing`
- Username: `user_5432`
- Both derived from same MAC address

---

## 🎨 Name Examples

### Famous Surnames (from Docker namesgenerator)

The library uses famous people in science and technology:

**Scientists & Mathematicians:**
- Turing (Alan Turing - Computer Science)
- Einstein (Albert Einstein - Physics)
- Newton (Isaac Newton - Physics)
- Curie (Marie Curie - Chemistry/Physics)
- Darwin (Charles Darwin - Biology)
- Galileo (Galileo Galilei - Astronomy)
- Tesla (Nikola Tesla - Engineering)
- Fermi (Enrico Fermi - Physics)

**Computer Scientists:**
- Lovelace (Ada Lovelace - First programmer)
- Hopper (Grace Hopper - COBOL)
- Knuth (Donald Knuth - TeX, Algorithms)
- Dijkstra (Edsger Dijkstra - Algorithms)
- Ritchie (Dennis Ritchie - C language)
- Thompson (Ken Thompson - Unix)
- Torvalds (Linus Torvalds - Linux)

**Adjectives (examples):**
```
admiring, adoring, affectionate, agitated, amazing,
angry, awesome, beautiful, blissful, bold,
boring, brave, busy, charming, clever,
cool, compassionate, competent, condescending, confident,
cranky, crazy, dazzling, determined, distracted,
dreamy, eager, ecstatic, elastic, elated,
elegant, eloquent, epic, exciting, fervent,
festive, flamboyant, focused, friendly, frosty,
funny, gallant, gifted, goofy, gracious,
happy, hardcore, heuristic, hopeful, hungry...
```

**Total Combinations:** ~100 adjectives × ~80 surnames = **~8,000+ unique codenames**

---

## 💻 Usage

### Startup Output

When starting P2P Chat, you'll see:

```bash
=== P2P Chat Started ===
Your Peer ID: 12D3KooWABC...
Listening on: /ip4/127.0.0.1/tcp/12345
Codename: Focused Turing        ← Human-readable nickname
Username: user_4567              ← Technical identifier
MAC: aa:bb:cc:dd:ee:ff           ← Source MAC address
```

### Chat Messages

Messages now display codenames instead of usernames:

```bash
# Old format
[14:30:25] user_1234: Hello everyone!

# New format with codenames
[14:30:25] Focused Turing: Hello everyone!
[14:30:30] Admiring Lovelace: Welcome!
[14:30:35] Brave Hopper: Hey there!
```

### Join/Leave Notifications

```bash
*** Focused Turing joined the chat (at 14:25:10)
*** Admiring Lovelace joined the chat (at 14:25:15)
*** Brave Hopper left the chat (at 14:35:20)
```

---

## 🔄 Consistency Guarantee

**Same MAC → Same Codename (Always)**

| Scenario | Result |
|----------|--------|
| Restart chat app | ✅ Same codename |
| Rebuild Docker container | ✅ Same codename (if MAC persists) |
| Different Docker host | ❌ Different codename (different MAC) |
| Virtual machine | ⚠️ Depends on VM network config |
| Same physical machine | ✅ Same codename |

---

## 🐳 Docker Behavior

### Physical Host
- MAC detected: ✅ (uses host's physical interface)
- Codename: Consistent across restarts

### Docker Container (default bridge)
- MAC detected: ⚠️ (may use virtual interface)
- Codename: May change if container recreated
- Fallback: Uses hostname-based seed

### Docker Container (host network)
- MAC detected: ✅ (uses host's physical interface)
- Codename: Consistent (same as physical host)

### Recommendation
For **consistent codenames in Docker**, use:
```yaml
network_mode: "host"
```

Or mount `/sys/class/net` to access host interfaces:
```yaml
volumes:
  - /sys/class/net:/sys/class/net:ro
```

---

## 🔍 Fallback Mechanism

When MAC address is unavailable, the system falls back to **hostname-based generation**:

```
No Physical MAC Found
↓
Get Hostname
↓
SHA256(hostname)
↓
Generate Codename
```

**Fallback scenarios:**
- Docker containers (default networking)
- Virtual machines (some configurations)
- Systems without physical network interfaces
- Permission issues reading MAC addresses

---

## 🛠️ Technical Implementation

### File Structure

```
internal/codename/
└── generator.go       # Codename generation logic
```

### Key Functions

#### `GenerateFromMAC()`
Returns a codename based on MAC address.

```go
codename := codename.GenerateFromMAC()
// Output: "Swift Falcon"
```

#### `GenerateWithUsername()`
Returns both codename and technical username.

```go
codenameStr, usernameStr := codename.GenerateWithUsername()
// codenameStr: "Focused Turing"
// usernameStr: "user_4567"
```

#### `GetMACInfo()`
Returns MAC address info for debugging.

```go
info := codename.GetMACInfo()
// Output: "MAC: aa:bb:cc:dd:ee:ff"
```

### Integration

Modified files:
- `internal/cli/chat.go` - Uses codename in UI/messages
- `internal/codename/generator.go` - Codename generation logic

---

## 📊 Examples

### Real-World Codenames

Here are some actual examples you might see:

```
Focused Turing      Admiring Lovelace   Brave Hopper
Clever Einstein     Epic Newton         Dreamy Curie
Bold Darwin         Awesome Tesla       Happy Galileo
Elastic Fermi       Gifted Knuth        Hungry Dijkstra
Cool Ritchie        Funny Thompson      Eager Torvalds
Amazing Gates       Peaceful Jobs       Serene Wozniak
Hopeful Berners     Elegant Stallman    Vibrant Minsky
Compassionate Papert Determined McCarthy Inspiring Shannon
Brilliant Babbage   Gracious Von Neumann Eloquent Church
```

### Collision Probability

With ~8,000 combinations:
- **2-10 peers:** ~0% chance of collision
- **50 peers:** ~15% chance of collision
- **100 peers:** ~47% chance of collision
- **200 peers:** ~84% chance of collision

For networks >100 peers, collisions are possible but unlikely to affect same conversation.

---

## 🎯 Use Cases

### 1. Friendly Chat Interface
```
Instead of: [user_1234] Hello!
You see:    [Focused Turing] Hello!
```

### 2. Peer Identification
```
# Quickly identify peers in logs
[14:30] Focused Turing connected
[14:31] Admiring Lovelace sent message
[14:32] Brave Hopper disconnected
```

### 3. Consistent Identity
```
# Same codename across sessions
Session 1: Focused Turing (user_4567)
Session 2: Focused Turing (user_4567)  ← Same!
```

### 4. Debugging
```
# Track specific peer across restarts
✓ Focused Turing (MAC: aa:bb:cc:dd:ee:ff)
  - Peer ID: 12D3KooW...
  - Username: user_4567
```

---

## 🔒 Privacy Considerations

### What's Exposed?
- ✅ **Codename** - Shared with all peers (human-readable)
- ✅ **Username** - Technical ID (user_xxxx)
- ❌ **MAC Address** - Never transmitted or shared

### What's Hashed?
- MAC address → SHA256 → Used as seed only
- No way to reverse-engineer MAC from codename

### Anonymity
- Codenames don't reveal identity
- Random-looking to observers
- No personal information leaked

---

## 🚀 Future Enhancements

Potential improvements:

1. **Larger word lists** (100+ words) → More combinations
2. **Custom word lists** - Let users provide their own words
3. **Theme support** - Military, Anime, Nature, etc.
4. **Codename registry** - Optional DHT-based lookup
5. **Avatar generation** - Visual representation of codename
6. **Emoji support** - "🦅 Swift Falcon"

---

## 📝 Configuration

### Environment Variables

Currently not configurable via ENV (future enhancement):

```bash
# Planned features:
CODENAME_ADJECTIVES="/path/to/adjectives.txt"
CODENAME_NOUNS="/path/to/nouns.txt"
CODENAME_THEME="military|nature|anime"
```

### Custom Names

The codenames come from Docker's `namesgenerator` package. To add custom names:

**Option 1:** Fork Docker's namesgenerator library
- Fork: https://github.com/moby/moby/tree/master/pkg/namesgenerator
- Add your names to `names-generator.go`
- Use your fork: `go mod edit -replace=github.com/docker/docker/pkg/namesgenerator=your-fork`

**Option 2:** Create your own generator (advanced)
- Replace `namesgenerator.GetRandomName()` with custom logic
- Maintain same deterministic behavior using seed

Then rebuild:
```bash
go build -o p2p-chat .
```

---

## 🐛 Troubleshooting

### Issue: Same codename for different peers

**Cause:** Both peers have same MAC address (unlikely on physical machines)

**Solutions:**
- Check if running in Docker (may share virtual MAC)
- Use `network_mode: host` in Docker
- Note: With ~8,000 combinations, collisions are rare in normal use

### Issue: Codename changes on restart

**Cause:** MAC address not detected consistently

**Solutions:**
- Check if using virtual network interfaces
- Verify physical interface exists: `ip link show`
- Check logs for fallback to hostname-based generation

### Issue: "MAC: Not available"

**Cause:** No physical network interface found

**Solutions:**
- Normal in Docker/VMs with virtual interfaces
- Uses hostname-based fallback (still deterministic)
- Consider host networking for Docker

---

## 📖 References

- Source: `internal/codename/generator.go`
- Integration: `internal/cli/chat.go`
- Protocol: Messages use codename in `Username` field

---

**Example Session:**

```bash
$ ./p2p-chat

🚀 P2P Chat v0.3.2
Initializing P2P node...
✓ P2P node started

=== P2P Chat Started ===
Your Peer ID: 12D3KooWABC123...
Codename: Focused Turing
Username: user_4567
MAC: aa:bb:cc:dd:ee:ff

> Hello everyone!
[14:30:25] Focused Turing: Hello everyone!

*** Admiring Lovelace joined the chat (at 14:30:30)
[14:30:35] Admiring Lovelace: Hey Focused Turing!
[14:30:40] Focused Turing: Welcome!
```

---

**Enjoy your unique codename! 🎉**
