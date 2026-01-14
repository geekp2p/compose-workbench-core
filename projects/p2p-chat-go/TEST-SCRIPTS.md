# 🧪 Test Scripts Usage Guide

## Overview

This directory contains automated test scripts for P2P DHT Network. All scripts are PowerShell-based and work on Windows, Linux (with PowerShell Core), and macOS (with PowerShell Core).

---

## 📋 Available Scripts

| Script | Purpose | Duration | Automation |
|--------|---------|----------|------------|
| **test-all.ps1** | Run all tests | 15-60 min | ✅ Fully automated |
| **test-level1.ps1** | Quick start test | 5 min | ✅ Fully automated |
| **test-level2.ps1** | Feature testing | 10 min | ⚠️ Semi-automated |
| **test-peers.ps1** | Manage multiple peers | - | ✅ Helper tool |
| **test-stress.ps1** | Stress testing | 20-45 min | ✅ Fully automated |
| **test-performance.ps1** | Performance metrics | 15-30 min | ✅ Fully automated |

---

## 🚀 Quick Start

### Option 1: Run All Tests (Recommended)

```powershell
# Quick test (Levels 1-2, ~10 minutes)
.\test-all.ps1 -Level quick

# Full test (Levels 1-2, 4-5, ~30 minutes)
.\test-all.ps1 -Level full

# All tests with verbose output
.\test-all.ps1 -Level all -Verbose
```

### Option 2: Run Individual Level

```powershell
# Level 1: Quick Start (5 min)
.\test-level1.ps1

# Level 2: Feature Testing (10 min)
.\test-level2.ps1

# Level 4: Stress Testing (20 min)
.\test-stress.ps1

# Level 5: Performance Testing (15 min)
.\test-performance.ps1
```

### Option 3: Interactive Testing

```powershell
# Start 3 peers for manual testing
.\test-peers.ps1 -Action start -Count 3

# Check status
.\test-peers.ps1 -Action status

# Attach to peer 1
.\test-peers.ps1 -Action attach -PeerId 1

# View logs from peer 2
.\test-peers.ps1 -Action logs -PeerId 2 -Follow

# Cleanup when done
.\test-peers.ps1 -Action cleanup
```

---

## 📖 Detailed Script Documentation

### 1. test-all.ps1 - Master Test Suite

**Purpose:** Run multiple test levels in sequence

**Usage:**
```powershell
.\test-all.ps1 [options]
```

**Parameters:**
- `-Level <string>` - Which tests to run
  - `"1"` - Only Level 1
  - `"2"` - Only Level 2
  - `"4"` - Only Level 4 (stress)
  - `"5"` - Only Level 5 (performance)
  - `"quick"` - Levels 1-2 (~10 min)
  - `"full"` - Levels 1-2, 4-5 (~30 min)
  - `"all"` - All levels (default)
- `-SkipCleanup` - Don't cleanup containers after tests
- `-StopOnFailure` - Stop if any test fails
- `-Verbose` - Show detailed output

**Examples:**
```powershell
# Quick validation
.\test-all.ps1 -Level quick

# Full test suite
.\test-all.ps1 -Level full -Verbose

# Run only stress tests
.\test-all.ps1 -Level 4

# Run all, keep containers for inspection
.\test-all.ps1 -SkipCleanup
```

**Expected Output:**
```
╔════════════════════════════════════════╗
║   P2P DHT NETWORK - TEST SUITE         ║
╚════════════════════════════════════════╝

Test Plan:
  - Level 1
  - Level 2
  - Level 4
  - Level 5

Continue? (Y/n)

...

════════════════════════════════════════
 TEST SUITE SUMMARY
════════════════════════════════════════

✅ PASS - Level 1: Quick Start (45.2s)
✅ PASS - Level 2: Feature Testing (12.1s)
✅ PASS - Level 4: Stress Testing (156.7s)
✅ PASS - Level 5: Performance Testing (89.3s)

Total Tests:    4
Passed:         4
Failed:         0
Pass Rate:      100%
Total Duration: 303.3s

🎉 ALL TESTS PASSED! 🎉
```

---

### 2. test-level1.ps1 - Quick Start Test

**Purpose:** Test basic peer functionality, discovery, and messaging

**Usage:**
```powershell
.\test-level1.ps1 [options]
```

**Parameters:**
- `-SkipBuild` - Use existing containers (skip build)
- `-Verbose` - Show detailed logs
- `-PeerCount <int>` - Number of peers (default: 2)

**Tests Performed:**
1. ✅ Peer Startup - Can start a peer
2. ✅ Codename Generation - Generates unique codename
3. ✅ Peer Discovery - Peers find each other (<60s)
4. ✅ Message Broadcasting - Messages delivered

**Examples:**
```powershell
# Basic test
.\test-level1.ps1

# Test with 3 peers
.\test-level1.ps1 -PeerCount 3

# Skip build (faster re-runs)
.\test-level1.ps1 -SkipBuild -Verbose
```

**Expected Output:**
```
========================================
  LEVEL 1: QUICK START TEST
========================================

>>> Step 1.1: Building project...
[PASS] Peer Startup

>>> Step 1.2: Verifying first peer...
[PASS] Peer Startup
  Container: compose-workbench-core-chat-node-1

>>> Step 1.3: Checking peer logs for codename...
[PASS] Codename Generation
  Peer 1 Codename: Focused Turing

>>> Step 1.4: Starting second peer...
  Peer 2 Container: p2p-chat-go-chat-node-run-abc123
  Peer 2 Codename: Admiring Lovelace

>>> Step 1.5: Waiting for peer discovery (max 60s)...
[PASS] Peer Discovery
  Discovery time: 23.4 seconds

>>> Step 1.6: Testing message broadcasting...
[PASS] Message Broadcasting

========================================
  TEST RESULTS SUMMARY
========================================
[PASS] Peer Startup
[PASS] Codename Generation
[PASS] Peer Discovery
[PASS] Message Broadcasting

Total Tests: 4
Passed:      4
Failed:      0
Pass Rate:   100%

Level 1 Test: PASSED! ✅
```

---

### 3. test-level2.ps1 - Feature Testing

**Purpose:** Verify new CLI commands work

**Usage:**
```powershell
.\test-level2.ps1 [options]
```

**Parameters:**
- `-SkipSetup` - Don't run Level 1 first
- `-Verbose` - Show detailed output

**Tests Performed:**
1. ✅ `/dht` - DHT storage statistics
2. ✅ `/routing` - Smart routing stats
3. ✅ `/relay` - Relay service status
4. ✅ `/conn` - Connection details
5. ✅ `/mesh` - GossipSub mesh status
6. ✅ `/verbose` - Verbose mode toggle

**Note:** This script verifies commands exist in source code. Manual testing recommended for full verification.

**Examples:**
```powershell
# Auto-setup and test
.\test-level2.ps1

# Skip setup (use existing peers)
.\test-level2.ps1 -SkipSetup
```

**Expected Output:**
```
========================================
  LEVEL 2: FEATURE TESTING
========================================

>>> Step 2.2: Checking /dht command implementation...
[PASS] /dht Command
  ✓ /dht command implemented in source code

>>> Step 2.3: Checking /routing command implementation...
[PASS] /routing Command
  ✓ /routing command implemented in source code

... (continued for all commands)

========================================
  MANUAL TESTING REQUIRED
========================================

To fully test these features, please run these commands manually:

1. Attach to the container:
   docker attach compose-workbench-core-chat-node-1

2. Test each command:
   > /dht       # DHT storage statistics
   > /routing   # Smart routing stats
   > /relay     # Relay service status
   > /conn      # Connection details
   > /mesh      # GossipSub mesh status
   > /verbose   # Toggle verbose mode

Level 2 Test: PASSED! ✅
(Manual verification recommended)
```

---

### 4. test-peers.ps1 - Multi-Peer Helper

**Purpose:** Manage multiple peers for testing

**Usage:**
```powershell
.\test-peers.ps1 -Action <action> [options]
```

**Actions:**
- `start` - Start multiple peers
- `stop` - Stop all peers
- `status` - Show peer status
- `attach` - Attach to a peer's console
- `logs` - View peer logs
- `cleanup` - Stop and remove all containers

**Parameters:**
- `-Count <int>` - Number of peers to start (default: 3)
- `-PeerId <int>` - Which peer to attach/view logs
- `-Follow` - Follow logs in real-time

**Examples:**
```powershell
# Start 5 peers
.\test-peers.ps1 -Action start -Count 5

# Check status
.\test-peers.ps1 -Action status

# Attach to peer 1
.\test-peers.ps1 -Action attach -PeerId 1

# View logs from peer 3
.\test-peers.ps1 -Action logs -PeerId 3

# Follow logs from peer 2
.\test-peers.ps1 -Action logs -PeerId 2 -Follow

# Stop all peers
.\test-peers.ps1 -Action stop

# Cleanup everything
.\test-peers.ps1 -Action cleanup
```

**Expected Output (status):**
```
========================================
  PEER STATUS
========================================

Running Peers: 3

NAMES                               STATUS              PORTS
compose-workbench-core-chat-node-1  Up 2 minutes        0.0.0.0:4001->4001/tcp
p2p-chat-go-chat-node-run-abc123    Up About a minute   4001/tcp
p2p-chat-go-chat-node-run-def456    Up About a minute   4001/tcp

To attach to a peer:
  .\test-peers.ps1 -Action attach -PeerId 1

To view logs:
  .\test-peers.ps1 -Action logs -PeerId 1
```

---

### 5. test-stress.ps1 - Stress Testing

**Purpose:** Test system stability under stress

**Usage:**
```powershell
.\test-stress.ps1 [options]
```

**Parameters:**
- `-Test <string>` - Which test to run
  - `"all"` - All stress tests (default)
  - `"reconnect"` - Rapid connect/disconnect
  - `"largemsg"` - Large message handling
  - `"zeropeers"` - Zero peers scenario
- `-Iterations <int>` - For reconnect test (default: 10)
- `-Verbose` - Show detailed output

**Tests Performed:**
1. ✅ Rapid Reconnect - 10 connect/disconnect cycles
2. ✅ Large Messages - Handle 4KB+ messages
3. ✅ Zero Peers - Run without any peers

**Examples:**
```powershell
# Run all stress tests
.\test-stress.ps1

# Only rapid reconnect (20 iterations)
.\test-stress.ps1 -Test reconnect -Iterations 20

# Only zero peers test
.\test-stress.ps1 -Test zeropeers -Verbose
```

**Expected Output:**
```
========================================
  LEVEL 4: STRESS TESTING
========================================

>>> Test 4.1: Rapid Connect/Disconnect (10 iterations)
  Iteration 1/10...
    ✓ Started cleanly
  Iteration 2/10...
    ✓ Started cleanly
  ...

  Results:
    Total iterations: 10
    Failures:         0
    Success rate:     100%
    Duration:         156.7s

[PASS] Rapid Reconnect (100% success rate)

>>> Test 4.2: Large Message Handling
  Starting peer...
  Message size: 4096 bytes
  Memory before: 42.5MiB / 7.677GiB
  Checking DHT capacity...
  Memory after:  43.1MiB / 7.677GiB
  ✓ Peer still running
[PASS] Large Messages (Peer stable with large data)

>>> Test 4.3: Zero Peers Scenario
  Starting isolated peer (no network)...
  ✓ Peer running in isolation
  ✓ No critical errors
[PASS] Zero Peers (Stable with zero peers)

========================================
  STRESS TEST RESULTS
========================================
[PASS] Rapid Reconnect
[PASS] Large Messages
[PASS] Zero Peers

Total Tests: 3
Passed:      3
Failed:      0
Pass Rate:   100%

Level 4 Test: PASSED! ✅
```

---

### 6. test-performance.ps1 - Performance Testing

**Purpose:** Measure resource usage and scalability

**Usage:**
```powershell
.\test-performance.ps1 [options]
```

**Parameters:**
- `-Test <string>` - Which test to run
  - `"all"` - All performance tests (default)
  - `"resources"` - Resource usage only
  - `"scalability"` - Scalability only
- `-PeerCount <int>` - For scalability test (default: 5)
- `-Duration <int>` - Monitoring duration in seconds (default: 60)
- `-Verbose` - Show detailed metrics

**Tests Performed:**
1. ✅ Resource Usage - Memory & CPU monitoring
2. ✅ Scalability - Multi-peer performance

**Examples:**
```powershell
# Run all performance tests
.\test-performance.ps1

# Only resource usage (30s monitoring)
.\test-performance.ps1 -Test resources -Duration 30

# Scalability with 10 peers
.\test-performance.ps1 -Test scalability -PeerCount 10 -Verbose
```

**Expected Output:**
```
========================================
  LEVEL 5: PERFORMANCE TESTING
========================================

>>> Test 5.1: Resource Usage Monitoring
  Starting single peer...
  Collecting metrics for 60 seconds...

  Results:
    Memory (avg): 42.3 MB
    Memory (max): 48.7 MB
    CPU (avg):    3.2%
    CPU (max):    8.5%

[PASS] Resource Usage (Mem: 42.3MB, CPU: 3.2%)

>>> Test 5.2: Peer Scalability (5 peers)
  Starting 5 peers...
  (This may take a few minutes)

  Peers started: 5/5
  Waiting for peer discovery (60 seconds)...
  Checking peer connections...

  Results:
    Target peers:      5
    Started peers:     5
    Avg connections:   4.2
    Total memory:      215.6 MB
    Total CPU:         12.4%

[PASS] Scalability (5 peers, avg 4.2 connections)

========================================
  PERFORMANCE TEST RESULTS
========================================
[PASS] Resource Usage
[PASS] Scalability

Total Tests: 2
Passed:      2
Failed:      0
Pass Rate:   100%

========================================
  PERFORMANCE METRICS
========================================
AvgMemory : 42.3
MaxMemory : 48.7
AvgCPU : 3.2
MaxCPU : 8.5
TotalMemory : 215.6
TotalCPU : 12.4
PeerCount : 5

Level 5 Test: PASSED! ✅
```

---

## 📊 Pass Criteria

### Level 1: Quick Start
- ✅ Peer starts without errors
- ✅ Codename generated
- ✅ Peer discovery < 60s
- ✅ Messages delivered

### Level 2: Feature Testing
- ✅ All commands implemented in source code
- ⚠️ Manual verification recommended

### Level 4: Stress Testing
- ✅ Reconnect success rate > 90%
- ✅ No crashes with large messages
- ✅ Stable with zero peers

### Level 5: Performance Testing
- ✅ Memory (avg) < 100 MB per peer
- ✅ CPU (avg) < 20% per peer
- ✅ All peers connect successfully

---

## 🔧 Troubleshooting

### Issue: Script fails with "docker not found"

**Solution:**
```powershell
# Make sure Docker Desktop is running
# Check Docker is available
docker --version

# If not found, restart Docker Desktop
```

### Issue: "Permission denied" on Linux/macOS

**Solution:**
```bash
# Make scripts executable
chmod +x *.ps1

# Run with pwsh (PowerShell Core)
pwsh ./test-all.ps1
```

### Issue: Tests timeout or hang

**Solution:**
```powershell
# Cleanup and try again
.\test-peers.ps1 -Action cleanup
.\test-all.ps1 -Level quick
```

### Issue: Peers don't discover each other

**Solution:**
```powershell
# Check Docker network
docker network ls

# Ensure containers are on same network
docker network inspect bridge

# Wait longer (discovery can take up to 2 minutes)
```

### Issue: High resource usage

**Solution:**
```powershell
# Cleanup old containers
docker system prune -f

# Reduce peer count
.\test-performance.ps1 -Test scalability -PeerCount 3
```

---

## 📈 Interpreting Results

### Good Results ✅
```
Memory (avg): 35-50 MB per peer
CPU (avg):    2-5%
Discovery:    10-30 seconds
Pass Rate:    100%
```

### Acceptable Results ⚠️
```
Memory (avg): 50-80 MB per peer
CPU (avg):    5-15%
Discovery:    30-90 seconds
Pass Rate:    75-99%
```

### Poor Results ❌
```
Memory (avg): >100 MB per peer
CPU (avg):    >20%
Discovery:    >2 minutes
Pass Rate:    <75%
```

---

## 🎯 Testing Workflow

### 1. First Time Testing
```powershell
# Start with quick test
.\test-all.ps1 -Level quick -Verbose

# If passes, run full test
.\test-all.ps1 -Level full
```

### 2. After Code Changes
```powershell
# Run affected level
.\test-level1.ps1  # If changed startup code
.\test-level2.ps1  # If changed CLI commands
.\test-stress.ps1  # If changed stability code
```

### 3. Before Release
```powershell
# Full test suite
.\test-all.ps1 -Level all -Verbose

# Manual feature verification
.\test-peers.ps1 -Action start -Count 3
.\test-peers.ps1 -Action attach -PeerId 1
# Test all CLI commands manually
```

### 4. Continuous Integration
```powershell
# Quick validation
.\test-all.ps1 -Level quick -StopOnFailure
```

---

## 📝 Best Practices

1. **Always cleanup between test runs**
   ```powershell
   .\test-peers.ps1 -Action cleanup
   ```

2. **Use `-Verbose` for debugging**
   ```powershell
   .\test-all.ps1 -Level 1 -Verbose
   ```

3. **Monitor resources during tests**
   ```powershell
   # In separate terminal
   docker stats
   ```

4. **Check logs if tests fail**
   ```powershell
   .\test-peers.ps1 -Action logs -PeerId 1
   ```

5. **Start small, scale up**
   ```powershell
   # Start with 2 peers
   # Then try 5 peers
   # Then try 10+ peers
   ```

---

## 🔗 Related Documentation

- **[TESTING-ROADMAP.md](TESTING-ROADMAP.md)** - Step-by-step testing guide
- **[TESTING.md](TESTING.md)** - Detailed 26 test cases
- **[QUICKTEST.md](QUICKTEST.md)** - 5-minute quick start
- **[TEST-SUMMARY.md](TEST-SUMMARY.md)** - Testing overview
- **[README.md](README.md)** - Project documentation

---

## ❓ Need Help?

If tests fail or you encounter issues:

1. Check [TESTING-ROADMAP.md](TESTING-ROADMAP.md) for troubleshooting
2. Review logs: `.\test-peers.ps1 -Action logs -PeerId 1`
3. Try manual testing: `.\test-peers.ps1 -Action start`
4. Cleanup and retry: `.\test-peers.ps1 -Action cleanup`

---

## 🎉 Happy Testing!

These scripts automate most testing tasks. Use them frequently to ensure P2P DHT Network stability!
