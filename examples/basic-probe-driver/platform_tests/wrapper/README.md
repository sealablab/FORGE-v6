# BPD Platform Wrapper Tests

**Purpose:** Test Basic Probe Driver through MCC CustomInstrument interface using CocoTB
**Infrastructure:** forge_cocotb v3.0.0 progressive testing framework
**Status:** ✅ Active (P1 tests passing)

---

## Quick Start

```bash
# Navigate to test directory
cd examples/basic-probe-driver/platform_tests/wrapper

# Run P1 tests (default, <20 lines output)
uv run python run.py

# Run P2 tests (comprehensive)
TEST_LEVEL=P2 uv run python run.py

# Debug mode (no filtering)
GHDL_FILTER_LEVEL=none uv run python run.py
```

**Expected P1 Output:** ~20 lines, <5 second runtime, all tests PASS

---

## Test Structure

### P1 - BASIC Tests (Current)
**File:** `P1_bpd_wrapper_basic.py`
**Runtime:** ~5-10 seconds
**Output:** <20 lines (LLM-optimized)
**Coverage:**
- `test_reset` - Reset behavior and IDLE state
- `test_forge_control` - FORGE control scheme (CR0[31:29])
- `test_output_mapping` - OutputA/B/C signal verification

**Status:** ✅ All tests passing

### P2 - INTERMEDIATE Tests (Planned)
**File:** `P2_bpd_wrapper_intermediate.py`
**Runtime:** ~30 seconds
**Output:** <50 lines
**Coverage:**
- FSM state transitions (IDLE → ARMED → FIRING → COOLDOWN)
- Control register unpacking verification
- Timeout and fault handling
- Auto-rearm (burst mode) testing

**Status:** 🔧 File exists, needs validation

### P3 - COMPREHENSIVE Tests (Planned)
**File:** `P3_bpd_wrapper_comprehensive.py`
**Runtime:** ~2 minutes
**Output:** <100 lines
**Coverage:**
- Burst mode multi-cycle testing
- Edge cases (zero durations, max timeouts)
- Monitor threshold testing
- Advanced fault scenarios

**Status:** 🔧 File exists, needs validation

### FSM Observer Tests (Separate)
**File:** `test_bpd_fsm_observer_wrapper.py`
**Purpose:** Oscilloscope debugging via fsm_observer voltage output
**Status:** 🔧 File exists, needs wrapper architecture update

---

## FORGE Architecture

### FORGE Control Scheme (CR0[31:29])

**Critical:** All BPD tests validate the 3-bit calling convention:

```
CR0[31] = forge_ready   ← Set by loader after deployment complete
CR0[30] = user_enable   ← User control (GUI toggle)
CR0[29] = clk_enable    ← Clock gating control

global_enable = forge_ready AND user_enable AND clk_enable AND loader_done
```

**MCC Helpers Available:**
- `mcc_set_regs(dut, {0: 0xE0000000})` - Apply all FORGE bits
- `wait_for_mcc_ready(dut, clk_signal="Clk")` - Wait for CR0[31]
- `validate_control0(cr0_value, context)` - Verify CR0[31:29] set

**See:** `CLAUDE.md` section "FORGE Control Scheme" for complete specification

---

## Signal Mapping Reference

### Control Register Allocation (MCC CustomInstrument Interface)
```
CR0[31:29]      → FORGE control scheme (forge_ready, user_enable, clk_enable)
CR0[28:0]       → Reserved for application (future)
CR1[0]          → arm_enable
CR1[1]          → ext_trigger_in
CR1[2]          → auto_rearm_enable
CR1[3]          → fault_clear
CR2[15:0]       → trig_out_voltage (signed, mV)
CR3[15:0]       → trig_out_duration (unsigned, ns)
CR4[15:0]       → intensity_voltage (signed, mV)
CR5[15:0]       → intensity_duration (unsigned, ns)
CR6[15:0]       → trigger_wait_timeout (unsigned, s)
CR7[23:0]       → cooldown_interval (unsigned, μs)
CR8[0]          → monitor_enable
CR8[1]          → monitor_expect_negative
CR9[15:0]       → monitor_threshold_voltage (signed, mV)
CR10[31:0]      → monitor_window_start (unsigned, ns)
CR11[31:0]      → monitor_window_duration (unsigned, ns)
CR12-CR15       → Reserved (future expansion)
```

### Input/Output Mapping
```
InputA[15:0]    → probe_monitor_feedback (signed, mV)
InputB-D        → Unused

OutputA[15:0]   → trig_out_active (0x0000 or 0xFFFF)
OutputB[15:0]   → intensity_out_active (0x0000 or 0xFFFF)
OutputC[15:0]   → HVS voltage-encoded FSM state (signed, ±5V scale)
                  IDLE=0.0V, ARMED=0.625V, FIRING=1.25V, COOLDOWN=1.875V
                  FAULT=negative voltage (sign-flip pattern)
OutputD         → Unused (tied to 0 in CustomWrapper_bpd_forge.vhd)
```

**HVS (Hierarchical Voltage Encoding Scheme):**
- Shim layer integrates `fsm_observer` component to convert raw 6-bit FSM state to voltage
- Linear interpolation: 5 states spread across 0.0V-2.5V range (0.625V steps)
- Sign-flip pattern: FAULT state shows as negative voltage (magnitude preserves context)
- Scale: ±5V → signed 16-bit (32767 counts = 5V, 6553.4 counts/V)

**Note:** OutputD platform limitation - not all Moku platforms support 4 outputs per slot.

### HVS Voltage Encoding Details

**Digital-to-Voltage Mapping:**
```
FSM State       Binary      Digital Value    Voltage
IDLE            0b000000    0 (0x0000)       0.0V
ARMED           0b000001    4096 (0x1000)    0.625V
FIRING          0b000010    8192 (0x2000)    1.25V
COOLDOWN        0b000011    12288 (0x3000)   1.875V
(unused)        0b000100    16384 (0x4000)   2.5V
FAULT           0b111111    -prev_voltage    Negative (sign-flip)
```

**fsm_observer Configuration:**
```
NUM_STATES = 5              -- Total normal states
V_MIN = 0.0V                -- IDLE voltage
V_MAX = 2.5V                -- Maximum normal state voltage
FAULT_STATE_THRESHOLD = 5   -- States 0-4 normal, ≥5 is fault
Scale: ±5V bipolar (forge_voltage_5v_bipolar_pkg)
```

**Oscilloscope Debugging:**
1. Connect OutputC to oscilloscope input
2. Set voltage scale: 0-3V range, DC coupling
3. Observe FSM state transitions as voltage steps
4. Fault detection: Negative voltage indicates fault entry

### FSM State Encoding (Internal)
```
IDLE     = 0b000000
ARMED    = 0b000001
FIRING   = 0b000010
COOLDOWN = 0b000011
FAULT    = 0b111111
```

**Note:** Main entity outputs raw 6-bit state. Shim layer converts to voltage via fsm_observer.

---

## Running Tests

### Prerequisites
```bash
# Install dependencies (from BPD-Dev-v5 root)
uv sync

# Verify installation
ghdl --version  # Should show GHDL 5.0+
python -c "from forge_cocotb.test_base import TestBase; print('✓ forge_cocotb installed')"
```

### Standard Usage

**P1 Tests (Default, LLM-optimized):**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
uv run python run.py
```

**P2 Tests (Comprehensive):**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
TEST_LEVEL=P2 uv run python run.py
```

**P3 Tests (Full coverage):**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
TEST_LEVEL=P3 uv run python run.py
```

### Debug Mode

**No filtering (see all GHDL output):**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
GHDL_FILTER_LEVEL=none uv run python run.py
```

**Verbose CocoTB output:**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
uv run python run.py --verbose
```

### Output Filtering

**Automatic Filtering:**
- GHDL filter is enabled by default (`GHDL_FILTER_LEVEL=aggressive`)
- Suppresses metavalue warnings during Python execution
- Suppresses GHDL post-simulation warnings via subprocess stderr capture

**Manual Shell Filtering (if needed):**
```bash
# Additional grep filtering (typically not needed with current implementation)
uv run python run.py 2>&1 | grep -v "metavalue" | grep -v "assertion warning"
```

**Filter Levels:**
- `aggressive` (default) - 90-98% output reduction
- `normal` - 80-90% output reduction
- `minimal` - 50-70% output reduction
- `none` - No filtering (debug mode)

---

## Test Infrastructure (forge_cocotb v3.0.0)

### Available MCC Helpers (30+ functions)

**Clock & Reset:**
- `setup_clock(dut, clk_signal="Clk", period_ns=10)` - 100MHz default
- `reset_active_high(dut, rst_signal="Reset", cycles=2)`
- `reset_active_low(dut, rst_signal="rst_n", cycles=2)`

**FORGE Control:**
- `mcc_set_regs(dut, {reg: value}, set_mcc_ready=False)`
- `wait_for_mcc_ready(dut, clk_signal="Clk", settle_cycles=10)`
- `validate_control0(cr0_value, context_msg)`

**Signal Access:**
- `get_fsm_state(dut, output_signal="OutputC")` - Extract FSM state from OutputC[5:0]
- All helpers support network latency simulation

**See:** `libs/forge-vhdl/python/forge_cocotb/conftest.py` for complete API

### GHDL Output Filter

**Implementation:** `libs/forge-vhdl/python/forge_cocotb/ghdl_filter.py`

**Filters:**
- Metavalue warnings (NUMERIC_STD operations on uninitialized signals)
- Null argument warnings
- Initialization warnings (@0ms)
- GHDL internal messages
- Duplicate warnings

**Preserves:**
- Errors and failures
- Test PASS/FAIL results
- Assertion errors
- Test headers and separators

**Performance:** 90-98% output reduction (287 lines → 8 lines for P1 tests)

---

## Test Configuration

### Platform Settings
- **Clock:** 125 MHz (8 ns period) - Moku:Go/Lab/Pro standard
- **Reset:** Active-high (`Reset = '1'`)
- **VHDL Standard:** VHDL-2008 (`--std=08`)

### Time Unit Conversions
- **ns durations:** Direct cycle count @ 125 MHz (1 cycle = 8 ns)
- **μs intervals:** 125 cycles per μs
- **s timeouts:** 125,000,000 cycles per second

### Test Optimization
- P1 uses small values (short timeouts, brief pulses) for fast execution
- P2 uses realistic values (typical operational parameters)
- P3 uses boundary/stress values (max timeouts, edge cases)

---

## Known Limitations

### Current Implementation
1. **OutputD unused** - Platform limitation (not all Moku units support 4 outputs/slot)
2. **Monitor latch** - `monitor_triggered` is internal FSM signal (not observable)
3. **HVS voltage encoding** - ✅ Implemented on OutputC via fsm_observer in shim layer

### Test Coverage Gaps
1. **DAC outputs** - Voltage outputs not yet wired to entity ports
2. **P2/P3 validation** - Files exist but need execution validation
3. **Hardware testing** - Simulation-only (no real Moku platform validation yet)

---

## FSM Observer Integration

**Status:** ✅ Implemented in shim layer (OutputC)

### Architecture
HVS (Hierarchical Voltage Encoding Scheme) is now integrated in the BPD FORGE architecture:

**Implementation Location:** `BPD_forge_shim.vhd` (Layer 2 of FORGE 3-layer pattern)
- Instantiates `fsm_observer` component from forge-vhdl
- Main entity outputs raw 6-bit `current_state` signal
- Shim layer converts to voltage via fsm_observer
- Voltage output mapped to OutputC for oscilloscope debugging

**Key Components:**
- `BPD_forge_main.vhd`: Outputs `current_state` (6-bit raw state)
- `BPD_forge_shim.vhd`: Integrates fsm_observer, outputs voltage on OutputC
- `fsm_observer.vhd`: Converts state to voltage (forge-vhdl component)

### Oscilloscope Debug Pattern
```
OutputC voltage encoding (HVS pattern):
  IDLE     (0x00) →  0.0V   (0 counts)
  ARMED    (0x01) →  0.625V (4096 counts)
  FIRING   (0x02) →  1.25V  (8192 counts)
  COOLDOWN (0x03) →  1.875V (12288 counts)
  FAULT    (0x3F) → -prev_voltage (sign-flip pattern)

Configuration:
  NUM_STATES = 5
  V_MIN = 0.0V, V_MAX = 2.5V
  FAULT_STATE_THRESHOLD = 5
  Scale: ±5V bipolar (forge_voltage_5v_bipolar_pkg)
```

**Example Debug Session:**
```
Scope OutputC:
  +0.625V → FSM in ARMED state
  +1.25V  → FSM in FIRING state
  -1.25V  → FSM FAULTED from FIRING state (sign flip indicates fault!)
```

**Benefits:**
- Non-invasive debugging (parallel observation of FSM state)
- No need for special wrapper architecture
- Standard FORGE pattern (shim layer responsibility)
- Oscilloscope-visible FSM transitions

---

## VHDL Source Files

Tests compile the following sources (in dependency order):

```
1. CustomWrapper_test_stub.vhd        # MCC entity declaration (CocoTB compatible)
2. forge_common_pkg.vhd               # FORGE control scheme package
3. forge_voltage_5v_bipolar_pkg.vhd   # ±5V voltage conversions (for fsm_observer)
4. fsm_observer.vhd                   # HVS voltage encoding component
5. basic_app_types_pkg.vhd            # BPD type definitions
6. basic_app_voltage_pkg.vhd          # BPD voltage conversions
7. basic_app_time_pkg.vhd             # BPD time conversions
8. BPD_forge_main.vhd                 # Layer 3: Application FSM
9. BPD_forge_shim.vhd                 # Layer 2: Register mapping + HVS integration
10. CustomWrapper_bpd_forge.vhd       # Wrapper architecture (instantiates shim)
```

**Locations:**
- `examples/basic-probe-driver/vhdl/` - BPD-specific sources
- `libs/forge-vhdl/vhdl/packages/` - FORGE packages
- `libs/forge-vhdl/vhdl/debugging/` - fsm_observer

---

## References

### Documentation
- **CLAUDE.md** (project root) - FORGE 3-layer architecture specification
- **BPD-RTL.yaml** - Authoritative register specification
- **FORGE_ARCHITECTURE.md** (vhdl/) - Complete 3-layer architecture guide
- **FSM_OBSERVER_INTEGRATION.md** (this directory) - FSM observer patterns

### VHDL Implementation
- **CustomWrapper_bpd_forge.vhd** - Production wrapper (current)
- **BPD_forge_shim.vhd** - Layer 2 register mapping
- **BPD_forge_main.vhd** - Layer 3 FSM logic
- **CustomWrapper_test_stub.vhd** - MCC entity (CocoTB compatible)

### Test Infrastructure
- **forge_cocotb** - Progressive testing framework (libs/forge-vhdl/python/forge_cocotb/)
- **run.py** - Test runner with GHDL filter integration

---

**Last Updated:** 2025-11-11
**Maintained By:** BPD Development Team
**Status:** P1 tests ✅ passing, P2/P3 🔧 pending validation
