# 🧪 P2P DHT Network - Test Scripts Guide

Complete guide for using automated test scripts to validate the P2P DHT Network implementation.

---

## 📚 Overview

This test suite provides **automated PowerShell scripts** for comprehensive testing across 5 levels, from basic connectivity to performance benchmarking.

### Test Scripts

| Script | Level | Duration | Focus | Type |
|--------|-------|----------|-------|------|
| `test-level1-quickstart.ps1` | 1 | ~5 min | Basic connectivity | Automated |
| `test-level2-features.ps1` | 2 | ~15 min | DHT, Relay, Routing | Semi-automated |
| `test-level3-network.ps1` | 3 | ~30 min | LAN, WAN, NAT | Semi-automated |
| `test-level4-stress.ps1` | 4 | ~45 min | Stability, Recovery | Automated |
| `test-level5-performance.ps1` | 5 | ~60 min | Throughput, Resources | Semi-automated |
| `test-run-all.ps1` | All | ~2-3 hrs | Complete suite | Automated |

---

## 🚀 Quick Start

### Run All Tests (Complete Suite)

```powershell
# Navigate to project directory
cd projects/p2p-chat-go

# Run complete test suite (all levels)
.\test-run-all.ps1

# Run with automatic cleanup
.\test-run-all.ps1 -Cleanup

# Quick mode (faster, less thorough)
.\test-run-all.ps1 -QuickMode

# Generate HTML report
.\test-run-all.ps1 -GenerateReport -Cleanup
```

### Run Individual Test Levels

```powershell
# Level 1: Quick Start (5 min)
.\test-level1-quickstart.ps1

# Level 2: Features (15 min)
.\test-level2-features.ps1

# Level 3: Network (30 min)
.\test-level3-network.ps1

# Level 4: Stress (45 min)
.\test-level4-stress.ps1

# Level 5: Performance (60 min)
.\test-level5-performance.ps1
```

---

## 📖 Test Scripts Reference

### Level 1: Quick Start (`test-level1-quickstart.ps1`)

**Purpose:** Validate basic peer functionality and connectivity.

**What it tests:**
- ✅ Docker image builds successfully
- ✅ Single peer starts without errors
- ✅ Multiple peers discover each other
- ✅ Codename generation works
- ✅ Message broadcasting (manual verification)

**Usage:**

```powershell
# Basic usage
.\test-level1-quickstart.ps1

# Skip build (use existing image)
.\test-level1-quickstart.ps1 -SkipBuild

# With cleanup after test
.\test-level1-quickstart.ps1 -Cleanup

# Show detailed logs
.\test-level1-quickstart.ps1 -Verbose
```

**Parameters:**
- `-SkipBuild` - Skip Docker build step
- `-Cleanup` - Remove containers after test
- `-Verbose` - Show detailed Docker logs

**Expected Output:**
```
✓ Build successful
✓ Peer 1 started successfully
✓ Peer 2 started successfully
✓ Peer discovery successful (100%)
✓ All codenames unique
⊙ Message broadcasting requires manual verification
```

**Exit Codes:**
- `0` - All automated tests passed
- `1` - Critical failure (build or startup)

---

### Level 2: Feature Testing (`test-level2-features.ps1`)

**Purpose:** Test new P2P DHT features.

**What it tests:**
- ✅ DHT storage initialization
- ✅ Smart routing system
- ✅ Relay service detection
- ✅ Connection type tracking
- ✅ GossipSub mesh formation
- ⊙ CLI commands (manual)

**Usage:**

```powershell
# Basic usage
.\test-level2-features.ps1

# Skip peer setup (use existing)
.\test-level2-features.ps1 -SkipSetup

# With cleanup
.\test-level2-features.ps1 -Cleanup

# Verbose mode
.\test-level2-features.ps1 -Verbose
```

**Parameters:**
- `-SkipSetup` - Use existing running peers
- `-Cleanup` - Remove containers after test
- `-Verbose` - Show detailed logs

**Manual Verification Required:**

After running the script, you'll need to manually test CLI commands:

1. Attach to a container:
   ```powershell
   docker attach <container-id>
   ```

2. Test commands:
   ```
   /dht      # DHT storage stats
   /routing  # Routing statistics
   /relay    # Relay service status
   /conn     # Connection details
   /mesh     # GossipSub mesh status
   /verbose  # Toggle verbose mode
   ```

3. Verify expected outputs (documented in script)

**Expected Output:**
```
✓ DHT storage is initialized
✓ Routing system operational
✓ Relay service configured
✓ Connection system working
✓ GossipSub mesh operational
⊙ CLI Commands require manual verification
```

---

### Level 3: Network Testing (`test-level3-network.ps1`)

**Purpose:** Test network connectivity across different scenarios.

**What it tests:**
- ✅ LAN direct connections
- ✅ Discovery time measurement
- ⊙ WAN cross-network (manual)
- ⊙ NAT traversal (manual)

**Usage:**

```powershell
# Basic usage (includes LAN only)
.\test-level3-network.ps1

# LAN testing only
.\test-level3-network.ps1 -LANOnly

# Skip setup (use existing peers)
.\test-level3-network.ps1 -SkipSetup

# With cleanup
.\test-level3-network.ps1 -Cleanup

# Verbose mode
.\test-level3-network.ps1 -Verbose
```

**Parameters:**
- `-LANOnly` - Skip WAN scenarios (faster)
- `-SkipSetup` - Use existing peers
- `-Cleanup` - Remove containers after test
- `-Verbose` - Show detailed logs

**Manual WAN Testing:**

For real cross-network testing:

1. **Machine A:**
   ```powershell
   cd compose-workbench-core
   .\up.ps1 p2p-chat-go -Build
   docker attach compose-workbench-core-chat-node-1
   ```

2. **Machine B (different network):**
   ```powershell
   git clone <repo-url>
   cd compose-workbench-core
   .\up.ps1 p2p-chat-go -Build
   docker attach compose-workbench-core-chat-node-1
   ```

3. Wait 60-120 seconds, then run `/peers` on both

**Expected Output:**
```
✓ LAN Direct Connections: 100% direct
✓ Discovery Time: 45 seconds
⊙ WAN Cross-Network requires multiple machines
⊙ NAT Traversal requires manual testing
```

---

### Level 4: Stress Testing (`test-level4-stress.ps1`)

**Purpose:** Test system stability under stress.

**What it tests:**
- ✅ Rapid connect/disconnect cycles
- ⊙ Large message handling
- ✅ Zero peers scenario
- ✅ Network partition recovery
- ✅ Memory leak detection

**Usage:**

```powershell
# Basic usage
.\test-level4-stress.ps1

# Custom rapid test cycles
.\test-level4-stress.ps1 -RapidTestCycles 20

# Custom large message size
.\test-level4-stress.ps1 -LargeMessageSize 8000

# Skip specific tests
.\test-level4-stress.ps1 -SkipRapidTest
.\test-level4-stress.ps1 -SkipLargeMessage

# With cleanup
.\test-level4-stress.ps1 -Cleanup

# Verbose mode
.\test-level4-stress.ps1 -Verbose
```

**Parameters:**
- `-RapidTestCycles` - Number of reconnect cycles (default: 10)
- `-LargeMessageSize` - Size of large message in chars (default: 4000)
- `-SkipRapidTest` - Skip rapid reconnect test
- `-SkipLargeMessage` - Skip large message test
- `-Cleanup` - Remove containers after test
- `-Verbose` - Show detailed logs

**Expected Output:**
```
✓ Rapid Reconnect: 10/10 cycles successful
⊙ Large Messages: Manual test ready
✓ Zero Peers Scenario: Peer stable in isolation
✓ Partition Recovery: Peer recovered after partition
✓ Memory Leak Detection: Memory stable
```

**Manual Large Message Test:**

1. Check temp file location from script output
2. Copy message from: `C:\Users\...\Temp\p2p-large-message.txt`
3. Attach to container and paste
4. Run `/dht` to verify cache size increased

---

### Level 5: Performance Testing (`test-level5-performance.ps1`)

**Purpose:** Measure system performance and resource usage.

**What it tests:**
- ⊙ Message throughput
- ✅ Peer scalability
- ✅ Resource usage monitoring
- ⊙ Latency distribution

**Usage:**

```powershell
# Basic usage
.\test-level5-performance.ps1

# Custom peer count for scalability
.\test-level5-performance.ps1 -PeerCount 10

# Custom message count for throughput
.\test-level5-performance.ps1 -MessageCount 200

# Custom monitor duration (seconds)
.\test-level5-performance.ps1 -MonitorDuration 600

# Skip specific tests
.\test-level5-performance.ps1 -SkipThroughput
.\test-level5-performance.ps1 -SkipScalability
.\test-level5-performance.ps1 -SkipResourceTest

# With cleanup
.\test-level5-performance.ps1 -Cleanup

# Verbose mode
.\test-level5-performance.ps1 -Verbose
```

**Parameters:**
- `-PeerCount` - Number of peers for scalability test (default: 5)
- `-MessageCount` - Number of messages for throughput test (default: 100)
- `-MonitorDuration` - Duration for resource monitoring in seconds (default: 300)
- `-SkipThroughput` - Skip throughput test
- `-SkipScalability` - Skip scalability test
- `-SkipResourceTest` - Skip resource monitoring
- `-Cleanup` - Remove containers after test
- `-Verbose` - Show detailed logs

**Performance Targets:**

| Metric | Target | Good | Acceptable |
|--------|--------|------|------------|
| Discovery Time | <60s | <30s | <120s |
| Message Delivery | >99% | >95% | >90% |
| Latency (Direct) | <50ms | <100ms | <200ms |
| Latency (Relay) | <200ms | <300ms | <500ms |
| Memory Usage | <50MB | <75MB | <100MB |
| CPU (Idle) | <5% | <10% | <20% |
| Throughput | >20/s | >10/s | >5/s |
| Scalability | 20+ peers | 10+ peers | 5+ peers |

**Expected Output:**
```
⊙ Message Throughput: Manual test required
✓ Peer Scalability: 5/5 peers connected
✓ Resource Usage: Memory stable at 45MB
⊙ Latency Distribution: Manual measurement required
```

---

### Master Script: Run All Tests (`test-run-all.ps1`)

**Purpose:** Execute complete test suite (all 5 levels).

**Usage:**

```powershell
# Run all tests
.\test-run-all.ps1

# Quick mode (faster)
.\test-run-all.ps1 -QuickMode

# Skip specific levels
.\test-run-all.ps1 -SkipLevel1
.\test-run-all.ps1 -SkipLevel2 -SkipLevel3

# Stop on first failure
.\test-run-all.ps1 -StopOnFailure

# Generate HTML report
.\test-run-all.ps1 -GenerateReport

# With cleanup
.\test-run-all.ps1 -Cleanup

# All options combined
.\test-run-all.ps1 -QuickMode -GenerateReport -Cleanup
```

**Parameters:**
- `-QuickMode` - Run faster, less thorough tests
- `-SkipLevel1` through `-SkipLevel5` - Skip specific test levels
- `-StopOnFailure` - Stop execution if any test fails
- `-GenerateReport` - Create HTML report at end
- `-Cleanup` - Remove all containers after testing

**Quick Mode Changes:**
- Level 3: LAN testing only (no WAN)
- Level 4: 5 rapid cycles instead of 10
- Level 5: 3 peers instead of 5, 120s monitoring instead of 300s

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Results Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Level 1: Quick Start - 5.2 min
  ✓ Level 2: Feature Testing - 16.1 min
  ✓ Level 3: Network Testing - 32.5 min
  ✓ Level 4: Stress Testing - 47.3 min
  ✓ Level 5: Performance Testing - 63.8 min
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Overall Results:
  Total tests: 5
  Passed: 5
  Partial: 0
  Failed: 0

Total Duration: 2.75 hours

🎉 ALL TESTS PASSED!
P2P DHT Network is production-ready!
```

---

## 🔍 Understanding Test Results

### Status Indicators

- ✅ **PASS** - Test passed all criteria
- ⚠️ **PARTIAL** - Test passed but needs manual verification or has warnings
- ❌ **FAIL** - Test failed critical checks
- ⊙ **MANUAL** - Requires manual testing/verification

### Reading Script Output

```powershell
[Step 1.2] Start First Peer          # Current test step
----------------------------------------
Starting first peer...                 # Action being performed
✓ Peer 1 container running            # Success
✓ Peer ID Generation                  # Sub-check passed
⚠ Relay Service - not found           # Warning (non-critical)

✓ Step 1.2 PASSED                     # Overall step result
```

### Exit Codes

- `0` - All tests passed or partial (no critical failures)
- `1` - Critical failure occurred

---

## 📊 Common Usage Scenarios

### Scenario 1: Quick Validation (Before PR)

```powershell
# Run Level 1 only (5 minutes)
.\test-level1-quickstart.ps1 -Cleanup

# Expected time: 5 minutes
# Validates: Basic functionality works
```

### Scenario 2: Feature Verification (After Changes)

```powershell
# Run Level 1 + 2 (20 minutes)
.\test-level1-quickstart.ps1 -Cleanup
.\test-level2-features.ps1 -Cleanup

# Expected time: 20 minutes
# Validates: Core features working
```

### Scenario 3: Pre-Release Testing

```powershell
# Run all tests with report
.\test-run-all.ps1 -GenerateReport -Cleanup

# Expected time: 2-3 hours
# Validates: Complete system
# Output: HTML report
```

### Scenario 4: Quick Smoke Test

```powershell
# Run quick mode
.\test-run-all.ps1 -QuickMode -Cleanup

# Expected time: 1-1.5 hours
# Validates: Major functionality
```

### Scenario 5: Specific Feature Testing

```powershell
# Test only DHT and routing features
.\test-level2-features.ps1 -SkipSetup

# Then manually test:
# docker attach <container>
# /dht
# /routing
```

---

## 🐛 Troubleshooting

### Script Fails to Start

**Problem:** `Docker not found or not running`

**Solution:**
```powershell
# Check Docker is running
docker --version
docker ps

# If not running, start Docker Desktop
```

---

### Peers Not Discovering Each Other

**Problem:** `⚠ Peer discovery failed (0%)`

**Solution:**
1. Increase wait time (discovery can take 1-3 minutes)
2. Check Docker network:
   ```powershell
   docker network ls
   docker network inspect p2p-chat-go_p2p-network
   ```
3. Check container logs:
   ```powershell
   docker logs <container-id>
   ```

---

### Tests Taking Too Long

**Problem:** Tests exceed expected duration

**Solution:**
1. Use `-QuickMode` for faster tests:
   ```powershell
   .\test-run-all.ps1 -QuickMode
   ```
2. Run specific levels only:
   ```powershell
   .\test-level1-quickstart.ps1
   ```
3. Skip resource-intensive tests:
   ```powershell
   .\test-level4-stress.ps1 -SkipRapidTest
   ```

---

### High Resource Usage

**Problem:** Docker using too much CPU/memory

**Solution:**
1. Check Docker resource limits (Docker Desktop → Settings → Resources)
2. Run tests one at a time with cleanup:
   ```powershell
   .\test-level1-quickstart.ps1 -Cleanup
   .\test-level2-features.ps1 -Cleanup
   ```
3. Monitor usage:
   ```powershell
   docker stats
   ```

---

### Manual Tests Not Working

**Problem:** Cannot attach to container or commands not responding

**Solution:**
1. Check container is running:
   ```powershell
   docker ps
   ```
2. Try detaching and reattaching:
   - Detach: `Ctrl+P, Ctrl+Q`
   - Attach: `docker attach <container-id>`
3. Check logs for errors:
   ```powershell
   docker logs <container-id>
   ```

---

## 📝 Best Practices

### 1. Run Tests in Order

Start with Level 1 and progress sequentially:
```powershell
.\test-level1-quickstart.ps1 -Cleanup
# If passed, continue to Level 2
.\test-level2-features.ps1 -Cleanup
# And so on...
```

### 2. Always Cleanup Between Runs

Prevent resource conflicts:
```powershell
# After each test
.\test-levelX-xxx.ps1 -Cleanup

# Or manually
docker compose -f projects/p2p-chat-go/compose.yml down -v
```

### 3. Document Manual Tests

When performing manual verification:
1. Note the results in TEST-RESULTS-TEMPLATE.md
2. Capture screenshots if needed
3. Record any issues observed

### 4. Use Verbose Mode for Debugging

When troubleshooting:
```powershell
.\test-levelX-xxx.ps1 -Verbose
```

This shows full Docker output for debugging.

### 5. Monitor Resources

Keep an eye on system resources:
```powershell
# In separate terminal
docker stats

# Or Windows Task Manager
```

---

## 📚 Related Documentation

- **[TESTING-ROADMAP.md](TESTING-ROADMAP.md)** - Step-by-step manual testing guide
- **[TESTING.md](TESTING.md)** - Detailed test case documentation (26 tests)
- **[QUICKTEST.md](QUICKTEST.md)** - 5-minute quick start guide
- **[TEST-SUMMARY.md](TEST-SUMMARY.md)** - Testing overview
- **[TEST-RESULTS-TEMPLATE.md](TEST-RESULTS-TEMPLATE.md)** - Template for documenting results
- **[README.md](README.md)** - Project documentation

---

## 🎯 Quick Reference Card

### Essential Commands

```powershell
# Quick test (5 min)
.\test-level1-quickstart.ps1 -Cleanup

# Full test suite (2-3 hours)
.\test-run-all.ps1 -Cleanup

# Quick mode (1-1.5 hours)
.\test-run-all.ps1 -QuickMode -Cleanup

# With HTML report
.\test-run-all.ps1 -GenerateReport -Cleanup

# Check running containers
docker ps

# View logs
docker logs <container-id>

# Attach to peer
docker attach <container-id>

# Cleanup everything
docker compose -f projects/p2p-chat-go/compose.yml down -v
```

### Test Duration Reference

| Test | Quick Mode | Full Mode |
|------|-----------|-----------|
| Level 1 | ~5 min | ~5 min |
| Level 2 | ~15 min | ~15 min |
| Level 3 | ~20 min | ~30 min |
| Level 4 | ~25 min | ~45 min |
| Level 5 | ~30 min | ~60 min |
| **Total** | **~1.5 hrs** | **~2.5 hrs** |

---

## ✅ Pre-flight Checklist

Before running tests:

- [ ] Docker Desktop is running
- [ ] No other P2P peers running (check `docker ps`)
- [ ] Sufficient disk space (> 2 GB free)
- [ ] Sufficient RAM (> 4 GB free)
- [ ] Network connectivity available
- [ ] PowerShell 5.1+ or PowerShell 7+
- [ ] Located in project directory: `projects/p2p-chat-go`

---

## 🎉 Success Criteria

### All Tests Pass When:

✅ Level 1: Peers start, discover each other, codenames generated
✅ Level 2: DHT, Routing, Relay features operational
✅ Level 3: LAN direct connections work, discovery < 120s
✅ Level 4: System stable under stress, no crashes
✅ Level 5: Meets performance targets (see Level 5 section)

---

## 📞 Support

If you encounter issues not covered in this guide:

1. Check [TESTING-ROADMAP.md](TESTING-ROADMAP.md) Troubleshooting section
2. Review Docker logs: `docker logs <container-id>`
3. Check GitHub Issues: [compose-workbench-core/issues](https://github.com/geekp2p/compose-workbench-core/issues)

---

**Happy Testing!** 🚀

Test thoroughly, test often, and ensure quality before deployment.
