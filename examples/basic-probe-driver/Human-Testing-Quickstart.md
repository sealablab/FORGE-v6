# Human Testing Quickstart Guide
## Basic Probe Driver (BPD) Platform Tests

**Last Updated:** 2025-11-11
**Target Audience:** Human developers running manual tests
**Prerequisites:** Python 3.10+, uv package manager, GHDL simulator

---

## Table of Contents

- [Directory Structure](#directory-structure)
- [Quick Start](#quick-start)
- [Running Tests](#running-tests)
- [Understanding Test Output](#understanding-test-output)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

---

## Directory Structure

### Overview

```
examples/basic-probe-driver/
├── BPD-RTL.yaml                    # Register specification (YAML)
├── README.md                        # Project overview
├── VHDL_SERIALIZATION_MIGRATION.md  # Migration notes
│
├── vhdl/                            # VHDL source files
│   ├── src/                         # Application-specific packages
│   │   ├── basic_app_types_pkg.vhd
│   │   ├── basic_app_voltage_pkg.vhd
│   │   ├── basic_app_time_pkg.vhd
│   │   └── basic_probe_driver_custom_inst_main.vhd  # FSM main entity
│   │
│   ├── BPD_forge_main.vhd          # Layer 3: Application FSM
│   ├── BPD_forge_shim.vhd          # Layer 2: Register mapping + HVS encoder
│   ├── CustomWrapper_bpd_forge.vhd # Layer 1: MCC interface (production)
│   ├── CustomWrapper_bpd_with_observer.vhd  # Alternative with HVS on OutputD
│   ├── CustomWrapper_test_stub.vhd # Entity stub for CocoTB tests
│   │
│   ├── FORGE_ARCHITECTURE.md       # Complete 3-layer architecture guide
│   ├── component_tests/            # Component-level tests (archived)
│   └── external_Example/           # Reference implementation (DS1140)
│
└── platform_tests/                  # Platform integration tests (PRIMARY)
    ├── README.md                    # Test suite overview
    └── wrapper/                     # CustomWrapper tests
        ├── run.py                   # CocoTB test runner (entry point)
        ├── P1_bpd_wrapper_basic.py # Fast smoke tests (<20 lines output)
        ├── P2_bpd_wrapper_intermediate.py  # Standard validation
        ├── P3_bpd_wrapper_comprehensive.py # Full coverage
        │
        ├── HVS_ENCODER_INTEGRATION.md  # HVS migration documentation
        └── README.md                   # Wrapper test guide
```

### Key Files for Testing

| File | Purpose |
|------|---------|
| `platform_tests/wrapper/run.py` | **Main entry point** - Run this to execute tests |
| `P1_bpd_wrapper_basic.py` | Fast smoke tests (default, <5s runtime) |
| `P2_bpd_wrapper_intermediate.py` | Standard validation (~30s runtime) |
| `P3_bpd_wrapper_comprehensive.py` | Full coverage (~2min runtime) |
| `HVS_ENCODER_INTEGRATION.md` | Technical docs for HVS encoder migration |

---

## Quick Start

### 1. Navigate to Test Directory

```bash
cd examples/basic-probe-driver/platform_tests/wrapper
```

### 2. Run Default Tests (P1 - Fast Smoke Tests)

```bash
uv run python run.py
```

**Expected output:** <20 lines, <5 seconds
**Tests:** Reset behavior, FORGE control scheme, Output mapping

### 3. Verify Success

Look for:
```
✅ Tests completed
📊 GHDL Filter Stats: X/Y lines filtered (Z%)
```

---

## Running Tests

### Progressive Test Levels

BPD uses **progressive testing** for token-efficient debugging:

| Level | Tests | Output | Runtime | Purpose |
|-------|-------|--------|---------|---------|
| **P1** | 3 | <20 lines | <5s | Fast iteration, LLM-friendly |
| **P2** | 10-15 | <50 lines | <30s | Standard validation |
| **P3** | 20-30 | <100 lines | <2min | Comprehensive coverage |

### P1 - Basic Tests (Default)

**Fast smoke tests for rapid iteration:**

```bash
cd examples/basic-probe-driver/platform_tests/wrapper
uv run python run.py
```

**Tests:**
1. Reset behavior → FSM in IDLE state (HVS digital = 0)
2. FORGE control scheme → Module enables via CR0[31:29]
3. Output mapping → OutputC shows HVS encoding

### P2 - Intermediate Tests

**Standard validation with edge cases:**

```bash
cd examples/basic-probe-driver/platform_tests/wrapper
TEST_LEVEL=P2 uv run python run.py
```

**Additional tests:**
- State transitions (IDLE → ARMED → FIRING → COOLDOWN)
- Control register validation
- Status byte encoding
- Fault detection

### P3 - Comprehensive Tests

**Full coverage with stress testing:**

```bash
cd examples/basic-probe-driver/platform_tests/wrapper
TEST_LEVEL=P3 uv run python run.py
```

**Additional tests:**
- All state combinations
- Boundary conditions
- Rapid state cycling
- Fault recovery

---

## Understanding Test Output

### Clean Output (Default)

BPD uses **GHDL output filtering** for 98% noise reduction:

```
Running BPD Wrapper Tests (Level: P1_BASIC)
GHDL Filter: aggressive
======================================================================

📦 Building HDL sources...

🧪 Running CocoTB tests...

     0.00ns INFO     cocotb                             Running tests
     0.00ns INFO     cocotb.regression                  running P1_bpd_wrapper_basic.test_bpd_wrapper_p1 (1/1)
     0.00ns INFO     cocotb.customwrapper               ✓ Clock started on 'Clk' (10ns period = 100.0MHz)
    20.00ns INFO     cocotb.customwrapper               ✓ Reset complete (active-high, 2 cycles)
    20.00ns INFO     cocotb.customwrapper               T1: Reset behavior
    40.00ns INFO     cocotb.customwrapper                 ✓ PASS
    40.00ns INFO     cocotb.customwrapper               T2: FORGE control scheme
160043640.00ns INFO     cocotb.customwrapper                 ✓ PASS
160043640.00ns INFO     cocotb.customwrapper               T3: Output mapping
160043660.00ns INFO     cocotb.customwrapper                 ✓ PASS
160043660.00ns INFO     cocotb.regression                  P1_bpd_wrapper_basic.test_bpd_wrapper_p1 passed

======================================================================
✅ Tests completed
📊 GHDL Filter Stats: 287/305 lines filtered (94.1%)
======================================================================
```

### Filter Levels

Control output verbosity with `GHDL_FILTER_LEVEL`:

```bash
# Aggressive filtering (default, 90-98% reduction)
GHDL_FILTER_LEVEL=aggressive uv run python run.py

# Normal filtering (80-90% reduction)
GHDL_FILTER_LEVEL=normal uv run python run.py

# Minimal filtering (50-70% reduction)
GHDL_FILTER_LEVEL=minimal uv run python run.py

# No filtering (debug mode)
GHDL_FILTER_LEVEL=none uv run python run.py
```

### Shell-Level Filtering (Optional)

For even cleaner output, pipe through grep:

```bash
uv run python run.py 2>&1 | grep -v "metavalue" | grep -v "assertion warning"
```

---

## Troubleshooting

### Issue: "CocoTB not found"

**Error:**
```
❌ CocoTB not found! Install with: uv sync
```

**Solution:**
```bash
cd /Users/johnycsh/Forge/BPD-Dev-v5
uv sync
```

### Issue: "forge_cocotb not found"

**Error:**
```
❌ forge_cocotb not found! Install with: uv sync
```

**Solution:**
Ensure `libs/forge-vhdl` submodule is initialized:

```bash
git submodule update --init --recursive
uv sync
```

### Issue: Test failures

**Check VHDL compilation:**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
GHDL_FILTER_LEVEL=none uv run python run.py
```

**Check for missing dependencies:**
```bash
ls ../../libs/forge-vhdl/vhdl/packages/
ls ../../libs/forge-vhdl/vhdl/debugging/
```

Should contain:
- `forge_common_pkg.vhdl`
- `forge_hierarchical_encoder.vhd`

### Issue: GHDL version mismatch

**Check GHDL version:**
```bash
ghdl --version
```

**Expected:** GHDL 4.0+ with VHDL-2008 support

**Install GHDL (macOS):**
```bash
brew install ghdl
```

---

## Advanced Usage

### Running Specific Test Levels

**P1 only (default):**
```bash
uv run python run.py
```

**P2 with normal filtering:**
```bash
TEST_LEVEL=P2 GHDL_FILTER_LEVEL=normal uv run python run.py
```

**P3 with no filtering (full debug):**
```bash
TEST_LEVEL=P3 GHDL_FILTER_LEVEL=none uv run python run.py
```

### Combining Environment Variables

```bash
# P2 tests with minimal filtering
TEST_LEVEL=P2 GHDL_FILTER_LEVEL=minimal uv run python run.py

# P3 tests with shell-level filtering
TEST_LEVEL=P3 uv run python run.py 2>&1 | grep -E "PASS|FAIL|ERROR"
```

### Understanding HVS Digital Encoding

The BPD uses **HVS (Hierarchical Voltage State) encoding** for oscilloscope debugging:

**Digital Values:**
- IDLE: 0 digital units
- ARMED: 200 digital units
- FIRING: 400 digital units
- COOLDOWN: 600 digital units
- FAULT: Negative value (sign flip)

**On ±5V platform (Moku):**
- 0 units → 0.0mV
- 200 units → 30.5mV
- 400 units → 61.0mV
- 600 units → 91.6mV

**Decode values:**
```bash
cd tools/decoder
python3 hierarchical_decoder.py
```

See `platform_tests/wrapper/HVS_ENCODER_INTEGRATION.md` for complete documentation.

---

## Test Architecture

### FORGE 3-Layer Architecture

BPD implements the FORGE pattern:

```
Layer 1: CustomWrapper_bpd_forge.vhd
         ↓ (MCC CustomInstrument interface)
         ↓ CR0[31:29] = FORGE control scheme
         ↓
Layer 2: BPD_forge_shim.vhd
         ↓ (Register unpacking + HVS encoder)
         ↓ app_reg_* signals
         ↓
Layer 3: BPD_forge_main.vhd
         ↓ (Application FSM, MCC-agnostic)
         ↓ Status outputs (state + status byte)
         ↓
HVS Encoder: forge_hierarchical_encoder
         ↓ (Digital encoding: 200 units/state)
         ↓
OutputC: Digital value (0, 200, 400, 600, ...)
```

### FORGE Control Scheme (CR0[31:29])

**Critical Pattern:** All Moku instruments must implement this:

```
CR0[31] = forge_ready   (set by loader after deployment)
CR0[30] = user_enable   (user control via GUI)
CR0[29] = clk_enable    (clock gating control)

global_enable = forge_ready AND user_enable AND clk_enable AND loader_done
```

**Tests validate:**
- Module disabled when CR0 = 0x00000000 (power-on state)
- Module enabled when CR0 = 0xE0000000 (all bits set)

See `vhdl/FORGE_ARCHITECTURE.md` for complete specification.

---

## Related Documentation

### BPD-Specific

- `examples/basic-probe-driver/README.md` - Project overview
- `examples/basic-probe-driver/vhdl/FORGE_ARCHITECTURE.md` - Complete architecture guide
- `examples/basic-probe-driver/platform_tests/wrapper/HVS_ENCODER_INTEGRATION.md` - HVS migration docs
- `examples/basic-probe-driver/BPD-RTL.yaml` - Register specification

### Testing Infrastructure

- `libs/forge-vhdl/CLAUDE.md` - CocoTB progressive testing standard
- `libs/forge-vhdl/python/forge_cocotb/` - Test utilities package

### Project Root

- `CLAUDE.md` - Monorepo architecture and development guide
- `llms.txt` - Quick navigation reference

---

## Quick Reference Card

### Essential Commands

```bash
# Navigate to tests
cd examples/basic-probe-driver/platform_tests/wrapper

# Run default tests (P1, fast)
uv run python run.py

# Run with different levels
TEST_LEVEL=P2 uv run python run.py
TEST_LEVEL=P3 uv run python run.py

# Control output verbosity
GHDL_FILTER_LEVEL=aggressive uv run python run.py  # Quietest
GHDL_FILTER_LEVEL=none uv run python run.py        # Full debug

# Clean output (shell filtering)
uv run python run.py 2>&1 | grep -v "metavalue"

# Decode HVS values
cd ../../../tools/decoder
python3 hierarchical_decoder.py
```

### Expected Runtimes

- **P1:** <5 seconds (3 tests)
- **P2:** <30 seconds (10-15 tests)
- **P3:** <2 minutes (20-30 tests)

### Test Status Indicators

- `✓ PASS` - Test passed
- `✗ FAIL` - Test failed (shows assertion error)
- `⏱ Network latency` - Simulating MCC network delay
- `📊 GHDL Filter Stats` - Output reduction statistics

---

**Questions?** See `examples/basic-probe-driver/platform_tests/wrapper/README.md` for detailed test documentation.

**Issues?** Check `examples/basic-probe-driver/vhdl/FORGE_ARCHITECTURE.md` for architecture deep dive.
