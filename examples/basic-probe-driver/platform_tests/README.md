# BPD Platform Integration Tests

**Purpose:** Test Basic Probe Driver through MCC CustomInstrument interface using CocoTB

**Status:** Active development (forge_cocotb v3.0.0 infrastructure integrated)

---

## Directory Structure

```
platform_tests/
├── wrapper/                          # CocoTB tests via CustomWrapper interface
│   ├── P1_bpd_wrapper_basic.py      # P1 progressive tests (3-5 tests, <20 lines)
│   ├── P2_bpd_wrapper_intermediate.py  # P2 tests (10-15 tests)
│   ├── P3_bpd_wrapper_comprehensive.py  # P3 tests (20-30 tests)
│   ├── test_bpd_fsm_observer_wrapper.py  # FSM observer tests
│   ├── run.py                       # Test runner (cocotb_tools.runner)
│   ├── README.md                    # Wrapper test documentation
│   └── FSM_OBSERVER_INTEGRATION.md  # FSM observer guide
│
└── simulation/                       # (FUTURE) Platform simulation tests
    └── (empty - planned for forge-platform integration)
```

---

## Important: OutputD Platform Limitation

**Not all Moku platforms support 4 outputs per slot.** Default tests use only OutputA-C (3 outputs).

- **OutputA:** trig_out_active (pulse output)
- **OutputB:** intensity_out_active (pulse output)
- **OutputC:** FSM state (6-bit value in lower bits)
- **OutputD:** Not used in default tests (platform-specific, may not be available)

**Note:** `CustomWrapper_bpd_forge.vhd` ties OutputD to 0. Future FSM observer integration may use OutputD for voltage debugging on 4-output platforms.

---

## Testing Approach

### Wrapper Tests (`wrapper/`)

**What:** CocoTB tests through CustomWrapper MCC CustomInstrument interface
**Speed:** Fast (direct DUT signal access)
**Purpose:** Validate FORGE control scheme, register mapping, and FSM behavior

**Test Infrastructure:**
- **forge_cocotb v3.0.0** - Progressive testing framework (P1/P2/P3 levels)
- **MCC helpers** - 30+ utility functions (mcc_set_regs, wait_for_mcc_ready, validate_control0)
- **GHDL filtering** - 98% output reduction (287 lines → 8 lines)
- **Test runner** - run.py with cocotb_tools.runner

**Example:**
```python
from forge_cocotb.test_base import TestBase
from forge_cocotb.conftest import setup_clock, mcc_set_regs, wait_for_mcc_ready

class BPDWrapperTests(TestBase):
    async def test_forge_control(self):
        # Apply FORGE control scheme (CR0[31:29])
        await mcc_set_regs(self.dut, {0: 0xE0000000})  # All FORGE bits
        await wait_for_mcc_ready(self.dut, clk_signal="Clk")

        # Direct output reads
        state = int(self.dut.OutputC.value.signed_integer) & 0x3F
        assert state == 0x00  # IDLE
```

**Run:**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
python run.py                    # Run P1 tests (default)
TEST_LEVEL=P2 python run.py      # Run P2 tests
python run.py --verbose          # More output
```

### Platform Simulation Tests (`simulation/`) - FUTURE

**Status:** Planned - Directory exists but tests not yet implemented

**Purpose:** Test through forge-platform simulators (OscilloscopeSimulator, CloudCompileSimulator) for realistic platform integration testing. Platform simulators are for **hardware testing** on real Moku devices, not CocoTB simulation.

---

## Progressive Testing Levels (forge_cocotb v3.0.0)

| Level | Tests | Output | Runtime | Purpose |
|-------|-------|--------|---------|---------|
| P1 | 3-5 | <20 lines | <5s | LLM-friendly smoke tests |
| P2 | 10-15 | <50 lines | <30s | Standard validation |
| P3 | 20-30 | <100 lines | <2min | Comprehensive coverage |

---

## FORGE Control Scheme (CR0[31:29])

**Critical:** All BPD tests validate the FORGE 3-bit calling convention:

```
CR0[31] = forge_ready   ← Set by loader after deployment
CR0[30] = user_enable   ← User control (GUI toggle)
CR0[29] = clk_enable    ← Clock gating control

global_enable = forge_ready AND user_enable AND clk_enable AND loader_done
```

**MCC Helpers for FORGE:**
- `mcc_set_regs(dut, {0: 0xE0000000})` - Apply all FORGE bits
- `wait_for_mcc_ready(dut, clk_signal="Clk")` - Wait for CR0[31]
- `validate_control0(cr0_value, context)` - Verify CR0[31:29] bits set

**See:** `CLAUDE.md` section "FORGE Control Scheme" for complete specification

---

## Test Development Workflow

### Adding Wrapper Tests

1. Create test file: `wrapper/P{X}_bpd_wrapper_{level}.py`
2. Import forge_cocotb infrastructure:
   ```python
   from forge_cocotb.test_base import TestBase
   from forge_cocotb.conftest import (
       setup_clock, reset_active_high,
       mcc_set_regs, wait_for_mcc_ready, validate_control0
   )
   ```
3. Extend `TestBase` class
4. Use MCC helpers for FORGE control scheme
5. Drive `dut.Control{N}` for application registers
6. Read `dut.Output{A-C}` for FSM state and outputs
7. Run via `python run.py`

**Example:**
```python
class BPDTests(TestBase):
    def __init__(self, dut):
        super().__init__(dut, "bpd_tests")

    async def run_p1_basic(self):
        await setup_clock(self.dut, clk_signal="Clk")
        await reset_active_high(self.dut, rst_signal="Reset")
        await self.test("FORGE control", self.test_forge_control)

    async def test_forge_control(self):
        await mcc_set_regs(self.dut, {0: 0xE0000000})
        await wait_for_mcc_ready(self.dut, clk_signal="Clk")
        validate_control0(int(self.dut.Control0.value), "After enable")
```

---

## Common Testing Patterns

### Pattern 1: FORGE Control Validation

```python
# Apply FORGE control scheme (all three bits)
await mcc_set_regs(self.dut, {0: 0xE0000000})
await wait_for_mcc_ready(self.dut, clk_signal="Clk", timeout_cycles=10)
validate_control0(int(self.dut.Control0.value), "After FORGE enable")
```

### Pattern 2: FSM State Verification

```python
# Read FSM state from OutputC[5:0]
state = int(self.dut.OutputC.value.signed_integer) & 0x3F
assert state == 0x00, f"Expected IDLE (0x00), got 0x{state:02x}"
```

### Pattern 3: Reset Behavior

```python
self.dut.Reset.value = 1
await ClockCycles(self.dut.Clk, 2)
state = int(self.dut.OutputC.value.signed_integer) & 0x3F
assert state == 0x00  # IDLE after reset
```

---

## Dependencies

**Required:**
- `cocotb>=1.8.0` - CocoTB framework
- `cocotb-tools` - Test runner infrastructure
- `forge_cocotb` v3.0.0 - Progressive testing framework (workspace member)
- `forge-vhdl` - VHDL packages (forge_common_pkg.vhd)
- `ghdl` - VHDL simulator

**Install:**
```bash
cd /Users/johnycsh/Forge/BPD-Dev-v5
uv sync  # Installs all workspace dependencies
```

**Verify:**
```bash
python -c "from forge_cocotb.test_base import TestBase; print('✓ forge_cocotb installed')"
ghdl --version  # Should show GHDL version
```

---

## VHDL Source Files

Wrapper tests compile the following VHDL sources:

```
CustomInstrument.vhd              # MCC interface entity
forge_common_pkg.vhd              # FORGE control scheme package
BPD_forge_shim.vhd                # Layer 2 register mapping
BPD_forge_main.vhd                # Layer 3 FSM logic
CustomWrapper_bpd_forge.vhd       # Complete wrapper (instantiates shim + main)
```

**See:** `run.py` for complete HDL_SOURCES list

---

## Current Status

**Working:**
- ✅ forge_cocotb v3.0.0 infrastructure integrated
- ✅ Test runner (run.py) created
- ✅ P1/P2/P3 test files present
- ✅ MCC helpers available (30+ functions)
- ✅ GHDL filtering (98% output reduction)

**In Progress:**
- 🔧 Fixing VHDL compilation errors
- 🔧 Running P1 wrapper tests

**Future:**
- ⏳ Platform simulation tests (forge-platform integration)
- ⏳ Hardware validation on real Moku devices

---

## Next Steps

1. **Fix VHDL compilation** - Resolve entity/dependency issues
2. **Run P1 wrapper tests** - Validate basic wrapper functionality
3. **Expand P2/P3 coverage** - Add more comprehensive tests
4. **Integrate with CI/CD** - Automate testing

---

**Last Updated:** 2025-11-11
**Maintained By:** BPD Development Team
