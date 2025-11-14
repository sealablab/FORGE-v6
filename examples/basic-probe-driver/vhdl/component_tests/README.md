# BPD Component Tests

**Status:** Archived - fsm_observer tests removed after HVS migration
**Date:** 2025-11-11

---

## Migration Notice

This directory previously contained component tests for `fsm_observer.vhd` (OLD voltage spreading approach).

**Migration completed 2025-11-11:**
- ❌ Removed `bpd_fsm_observer_tests/` - Obsolete after HVS migration
- ❌ Removed `test_bpd_fsm_observer_progressive.py` - OLD test infrastructure
- ❌ Removed `mcc/` - OLD deployment artifacts with fsm_observer snapshots

**Replaced by:**
- ✅ `examples/basic-probe-driver/platform_tests/wrapper/` - HVS encoder integration tests
- ✅ `libs/forge-vhdl/vhdl/debugging/forge_hierarchical_encoder.vhd` - NEW HVS encoder
- ✅ `examples/basic-probe-driver/platform_tests/wrapper/HVS_ENCODER_INTEGRATION.md` - Migration documentation

---

## Why the Change?

**OLD Approach (fsm_observer):**
- Voltage values hardcoded in VHDL (V_MIN=0.0V, V_MAX=2.5V)
- Platform-specific (assumed ±5V DAC range)
- Violated separation of concerns (analog domain in VHDL)

**NEW Approach (forge_hierarchical_encoder):**
- Pure digital encoding (200 digital units per state)
- Platform-agnostic (decoder handles voltage interpretation)
- Clean separation of concerns (digital domain in VHDL, analog in Python)
- Richer encoding (6-bit state + 8-bit status vs 6-bit state only)

---

## Current Test Infrastructure

### Platform Tests (Primary)

**Location:** `examples/basic-probe-driver/platform_tests/wrapper/`

**Tests:**
- `P1_bpd_wrapper_basic.py` - HVS digital encoding validation
- `run.py` - CocoTB runner with GHDL filtering

**Run tests:**
```bash
cd examples/basic-probe-driver/platform_tests/wrapper
uv run python run.py
```

**Expected output:** <20 lines, P1 progressive testing standard

---

## Component Test Infrastructure (Future)

This directory is available for future BPD component-level tests (non-wrapper).

**Reserved for:**
- HVS encoder component tests (if needed beyond libs/forge-vhdl tests)
- BPD FSM state machine tests (isolated from wrapper)
- Application-specific component tests

**Not needed currently:** Platform tests cover integration adequately.

---

## Legacy Files

**Remaining in this directory:**
- `BPD-002v2.yaml` - OLD configuration file (to be revisited/removed)
- `run.py` - OLD test runner (contains fsm_observer-specific code)
- `test_configs.py` - OLD test configuration
- `sim_build/` - Build artifacts (can be deleted)
- `__pycache__/` - Python cache (can be deleted)

**Action required:** Clean up or repurpose these files for future component tests.

---

## Integration with forge-vhdl

BPD tests use forge-vhdl progressive testing infrastructure:

**Shared components:**
- `libs/forge-vhdl/python/forge_cocotb/` - CocoTB utilities package
- `libs/forge-vhdl/python/forge_cocotb/ghdl_filter.py` - GHDL output filtering
- `libs/forge-vhdl/python/forge_cocotb/test_base.py` - TestBase class with verbosity control
- `libs/forge-vhdl/python/forge_cocotb/conftest.py` - Clock/reset/MCC utilities

**Import pattern:**
```python
from forge_cocotb.test_base import TestBase, VerbosityLevel
from forge_cocotb.conftest import setup_clock, reset_active_high, mcc_set_regs
from forge_cocotb.ghdl_filter import GHDLOutputFilter, FilterLevel
```

---

## References

- **HVS Migration Docs:** `examples/basic-probe-driver/platform_tests/wrapper/HVS_ENCODER_INTEGRATION.md`
- **HVS Encoder VHDL:** `libs/forge-vhdl/vhdl/debugging/forge_hierarchical_encoder.vhd`
- **HVS Encoder Tests:** `libs/forge-vhdl/tests/forge_hierarchical_encoder_tests/`
- **Python Decoder:** `tools/decoder/hierarchical_decoder.py`
- **OLD fsm_observer (deprecated):** `libs/forge-vhdl/vhdl/debugging/fsm_observer.vhd`

---

**Last Updated:** 2025-11-11
**Maintained By:** BPD Development Team
