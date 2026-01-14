# 🏷️ Codename Feature

**Deterministic human-readable nicknames generated from MAC address**

---

## 🎯 Overview

The P2P Chat now generates a **unique, memorable codename** for each peer based on their MAC address. This makes it easier to identify peers in chat logs without exposing technical identifiers.

### Key Features

✅ **Deterministic** - Same MAC address = Same codename (across restarts)
✅ **Human-readable** - Format: "Adjective + Noun" (e.g., "Swift Falcon")
✅ **Unique** - ~2,500 possible combinations (50 adjectives × 50 nouns)
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
MAC Address → SHA256 Hash → Seed → Pick Words → Codename
```

**Example:**
```
MAC: "aa:bb:cc:dd:ee:ff"
↓ SHA256
Hash: "f4c9b..."
↓ Seed (first 8 bytes)
Seed: 0x123456789abcdef0
↓ Modulo word list size
Adjective index: 15 → "Golden"
Noun index: 42 → "Phoenix"
↓
Codename: "Golden Phoenix"
```

### 3. Username Generation

Technical username is also generated from MAC:

```
MAC → SHA256 → User Number (0-9999) → "user_XXXX"
```

**Example:**
- Codename: `Golden Phoenix`
- Username: `user_5432`
- Both derived from same MAC address

---

## 🎨 Word Lists

### Adjectives (50 words)
```
Swift, Brave, Mighty, Silent, Golden,
Silver, Crimson, Azure, Jade, Amber,
Shadow, Thunder, Lightning, Storm, Frost,
Fire, Iron, Steel, Diamond, Crystal,
Noble, Royal, Ancient, Mystic, Cosmic,
Blazing, Radiant, Glowing, Shining, Bright,
Dark, Wild, Free, Bold, Fierce,
Wise, Clever, Quick, Rapid, Strong,
Tough, Solid, Steady, Calm, Serene,
Peaceful, Gentle, Kind, Pure
```

### Nouns (50 words)
```
Falcon, Eagle, Hawk, Phoenix, Dragon,
Tiger, Lion, Wolf, Bear, Panther,
Leopard, Jaguar, Cheetah, Lynx, Fox,
Raven, Owl, Sparrow, Robin, Swan,
Shark, Whale, Dolphin, Orca, Seal,
Warrior, Knight, Guardian, Sentinel, Protector,
Hunter, Scout, Ranger, Explorer, Voyager,
Star, Moon, Sun, Comet, Nova,
Mountain, River, Ocean, Forest, Desert,
Wind, Rain, Snow, Cloud, Mist
```

**Total Combinations:** 50 × 50 = **2,500 unique codenames**

---

## 💻 Usage

### Startup Output

When starting P2P Chat, you'll see:

```bash
=== P2P Chat Started ===
Your Peer ID: 12D3KooWABC...
Listening on: /ip4/127.0.0.1/tcp/12345
Codename: Swift Falcon        ← Human-readable nickname
Username: user_4567            ← Technical identifier
MAC: aa:bb:cc:dd:ee:ff         ← Source MAC address
```

### Chat Messages

Messages now display codenames instead of usernames:

```bash
# Old format
[14:30:25] user_1234: Hello everyone!

# New format with codenames
[14:30:25] Swift Falcon: Hello everyone!
[14:30:30] Brave Lion: Welcome!
[14:30:35] Golden Phoenix: Hey there!
```

### Join/Leave Notifications

```bash
*** Swift Falcon joined the chat (at 14:25:10)
*** Brave Lion joined the chat (at 14:25:15)
*** Golden Phoenix left the chat (at 14:35:20)
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
// codenameStr: "Swift Falcon"
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
Swift Falcon        Golden Phoenix      Brave Lion
Shadow Dragon       Silver Eagle        Crimson Tiger
Azure Hawk          Thunder Wolf        Lightning Bear
Storm Panther       Frost Leopard       Fire Jaguar
Diamond Raven       Crystal Owl         Iron Knight
Mystic Guardian     Cosmic Voyager      Noble Warrior
Radiant Star        Blazing Comet       Serene Moon
Wild Mountain       Free Ocean          Bold River
Ancient Forest      Calm Desert         Wise Cloud
```

### Collision Probability

With 2,500 combinations:
- **2-10 peers:** ~0% chance of collision
- **50 peers:** ~20% chance of collision
- **100 peers:** ~63% chance of collision

For networks >50 peers, consider expanding word lists.

---

## 🎯 Use Cases

### 1. Friendly Chat Interface
```
Instead of: [user_1234] Hello!
You see:    [Swift Falcon] Hello!
```

### 2. Peer Identification
```
# Quickly identify peers in logs
[14:30] Swift Falcon connected
[14:31] Brave Lion sent message
[14:32] Golden Phoenix disconnected
```

### 3. Consistent Identity
```
# Same codename across sessions
Session 1: Swift Falcon (user_4567)
Session 2: Swift Falcon (user_4567)  ← Same!
```

### 4. Debugging
```
# Track specific peer across restarts
✓ Swift Falcon (MAC: aa:bb:cc:dd:ee:ff)
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

### Custom Word Lists

To customize, edit `internal/codename/generator.go`:

```go
var adjectives = []string{
    "Your", "Custom", "Adjectives", ...
}

var nouns = []string{
    "Your", "Custom", "Nouns", ...
}
```

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
- Expand word lists for more combinations

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
Codename: Swift Falcon
Username: user_4567
MAC: aa:bb:cc:dd:ee:ff

> Hello everyone!
[14:30:25] Swift Falcon: Hello everyone!

*** Brave Lion joined the chat (at 14:30:30)
[14:30:35] Brave Lion: Hey Swift Falcon!
[14:30:40] Swift Falcon: Welcome!
```

---

**Enjoy your unique codename! 🎉**
