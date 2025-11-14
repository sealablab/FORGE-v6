# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**FORGE-v6** is a platform-agnostic FPGA development framework for building custom instruments on Moku hardware platforms (Go, Lab, Pro, Delta). The repository implements the **FORGE architecture** (Formal Organization for Register-Gated Execution) - a 3-layer pattern that provides safe initialization, clean abstraction, and AI-friendly design for custom FPGA firmware.

## Project Architecture

### High-Level Structure

```
FORGE-v6/
├── sys/forge-platform/     # FORGE foundational VHDL entities (MCC interface)
├── libs/                   # Git submodules for platform models and utilities
│   ├── moku-models/       # Pydantic models for Moku platform specs
│   ├── riscure-models/    # Example probe specifications
│   └── forge-vhdl/        # Reusable VHDL components
├── examples/              # Reference implementations
│   ├── basic-probe-driver/ # Production FORGE reference (fault injection driver)
│   └── counter/           # Minimal viable FORGE example
├── docs/                  # Architecture documentation
└── AI/                    # Agent definitions and workflows
```

### The FORGE 3-Layer Architecture

The core innovation of this system is the FORGE 3-layer architecture that separates concerns:

**Layer 1: MCC_TOP_forge_loader** (Future/Planned)
- Manages BRAM initialization from external sources
- Sets `forge_ready` flag when deployment complete
- Shared infrastructure across all applications

**Layer 2: APP_forge_shim** (Generated/Present)
- Maps Control Registers (CR20-CR30) → typed application signals
- Enforces FORGE control scheme (CR0[31:29])
- Computes `global_enable` from 4 safety conditions
- Generated from YAML specifications

**Layer 3: APP_forge_main** (Hand-written)
- Pure application logic (FSM, timers, outputs)
- Zero knowledge of Control Registers or FORGE control scheme
- Portable across platforms
- Uses friendly signal names only (e.g., `app_reg_arm_enable`, `app_reg_trigger_voltage`)

### FORGE Control Scheme (CR0[31:29])

The FORGE control scheme uses 3 bits in Control Register 0 for safe initialization:

```
CR0[31] = forge_ready   ← Set by loader after deployment
CR0[30] = user_enable   ← User control (GUI toggle)
CR0[29] = clk_enable    ← Clock gating control
```

Plus a fourth signal: `loader_done` (BRAM loader FSM completion)

**All four conditions must be met** for the module to operate:
```vhdl
global_enable = forge_ready AND user_enable AND clk_enable AND loader_done
```

This ensures modules are disabled on power-on and only start when fully initialized.

## Common Development Tasks

### Running CocoTB Tests

The project uses **Progressive Testing** (P1 → P2 → P3 levels) with CocoTB:

```bash
# Navigate to test directory
cd examples/basic-probe-driver/platform_tests/wrapper/

# P1: LLM-optimized tests (<20 lines each, fast feedback)
uv run python run.py

# P2: Comprehensive validation
TEST_LEVEL=P2_INTERMEDIATE uv run python run.py

# P3: Full coverage (every edge case)
TEST_LEVEL=P3_COMPREHENSIVE uv run python run.py

# List available tests
uv run python run.py --list

# Run with verbose output
uv run python run.py --verbose

# Run without GHDL output filtering
uv run python run.py --no-filter
```

### Working with moku-models

The `libs/moku-models/` submodule provides Pydantic models for Moku device configuration:

```bash
# Install with device operations support
cd libs/moku-models
pip install -e ".[device]"

# Deploy a configuration to hardware
python3 scripts/push.py -c ./examples/01-basic-cloudcompile.json -i 192.168.13.147 -b ./temp_bits.tar

# Pull configuration from device
python scripts/pull.py 192.168.1.100 --output pulled_config.json

# Validate configuration file
python scripts/validate_moku_config.py pulled_config.json
```

**WARNING:** `push.py` force-connects and overwrites existing device state!

### Available Moku Platforms

| Platform | Slots | Analog I/O | Clock | DIO | Constant |
|----------|-------|------------|-------|-----|----------|
| Moku:Go | 2 | 2 IN / 2 OUT | 125 MHz | 16 | `MOKU_GO_PLATFORM` |
| Moku:Lab | 2 | 2 IN / 2 OUT | 500 MHz | - | `MOKU_LAB_PLATFORM` |
| Moku:Pro | 4 | 4 IN / 4 OUT | 1.25 GHz | - | `MOKU_PRO_PLATFORM` |
| Moku:Delta | 3 | 8 IN / 8 OUT | 5 GHz | 32 | `MOKU_DELTA_PLATFORM` |

## Key Design Patterns

### Creating a New Custom Instrument

When building a new instrument, follow the Basic Probe Driver (BPD) reference implementation:

1. **Define Application Registers (YAML)**
   - Specify `app_reg_*` signals with types from `forge_serialization_*` packages
   - CR0[31:29] is RESERVED for FORGE control scheme
   - Use CR20-CR30 for application registers

2. **Copy BPD Structure**
   ```bash
   cp -r examples/basic-probe-driver/vhdl my-instrument/
   ```

3. **Study These Files in Order:**
   - `vhdl/FORGE_ARCHITECTURE.md` - Complete 3-layer specification
   - `CustomWrapper_bpd_forge.vhd` - MCC interface integration
   - `BPD_forge_shim.vhd` - Register unpacking pattern
   - `src/basic_probe_driver_custom_inst_main.vhd` - FSM implementation

4. **Keep FORGE Patterns:**
   - CR0[31:29] control scheme
   - `app_reg_*` abstraction (NO raw Control Registers in main!)
   - `ready_for_updates` handshaking
   - 3-layer architecture

5. **Replace BPD-Specific Logic:**
   - Probe control → Your instrument control
   - FI timing → Your timing requirements
   - FSM states → Your state machine

### Progressive Testing Philosophy

The FORGE ecosystem uses **Progressive Testing** to help both AI agents and humans iterate faster:

- **P1 Tests:** LLM-optimized (<20 lines each), fast feedback, basic validation
- **P2 Tests:** Comprehensive scenarios, detailed validation
- **P3 Tests:** Full coverage, every edge case

This allows rapid iteration starting with simple tests and progressively adding complexity.

### Type System for YAML → VHDL

The project supports 23+ serialization types for YAML → VHDL code generation:

**Voltage types:** 0-3.3V, 0-5V, ±0.5V, ±20V, ±25V
**Time types:** nanoseconds, microseconds, milliseconds
**Other:** Boolean, integers (signed/unsigned), enumerated types

See `tools/forge-codegen/llms.txt` (if available) for complete type catalog.

## File Organization Conventions

### Documentation Philosophy: 3-Tier Progressive Disclosure

The repository uses a tiered documentation system optimized for AI agents:

**Tier 1:** `llms.txt` files (~500-1000 tokens)
- Always load first
- Quick component catalog

**Tier 2:** `CLAUDE.md` files (~3000-5000 tokens)
- Design/integration details
- This file is Tier 2

**Tier 3:** Source code + tests (variable tokens)
- Implementation details
- Accessed selectively

### Where Things Live

- **VHDL Foundational Entities:** `sys/forge-platform/` (DO NOT MODIFY)
  - `MCC_CustomInstrument.vhd` - Simplified MCC interface (16 CR, 16 SR)
  - `FORGE_App_Wrapper.vhd` - 3-layer wrapper template

- **Reference Implementations:** `examples/`
  - `basic-probe-driver/` - Production FORGE reference (fault injection driver)
  - `counter/` - Minimal viable FORGE example

- **Platform Models:** `libs/moku-models/` (Git submodule)
  - Pydantic models for Moku hardware specifications
  - Deployment scripts (`push.py`, `pull.py`)
  - Validation utilities

- **VHDL Utilities:** `libs/forge-vhdl/` (Git submodule)
  - Reusable components (clock dividers, voltage utils, FSM observer)

- **AI Agents:** `AI/` directory
  - Agent markdown files (version-controlled, not hidden)
  - Agent pipeline documentation
  - **Note:** Only `cocotb-integration-test` agent has been tested

### Git Submodules

This repository uses git submodules extensively:

```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/YOUR-USERNAME/FORGE-v6.git

# Update submodules
git submodule update --init --recursive

# Update to latest submodule commits
git submodule update --remote
```

Submodules are in `libs/`:
- `moku-models` - Platform definitions
- `riscure-models` - Probe specifications
- `forge-platform-sim` - Platform simulator (FORGE-v5 legacy)

## Important Constraints

### VHDL Development

1. **Never modify foundational entities** in `sys/forge-platform/`
   - `MCC_CustomInstrument.vhd` is authoritative
   - Use `FORGE_App_Wrapper.vhd` as a template only

2. **Always respect CR0[31:29] reservation** for FORGE control scheme
   - CR0[31] = `forge_ready`
   - CR0[30] = `user_enable`
   - CR0[29] = `clk_enable`
   - Application registers: CR0[28:0] + CR1-CR15

3. **Layer 3 (main) must be MCC-agnostic**
   - No Control Register knowledge
   - Only typed application signals
   - Uses generic `Enable` signal (not FORGE-specific)

### Testing Requirements

1. **Always start with P1 tests** before moving to P2/P3
2. **Use CocoTB** for VHDL unit tests (not vendor-specific tools)
3. **Test at each layer:**
   - Layer 3: Application logic in isolation
   - Layer 2: Register mapping and synchronization
   - Layer 1: FORGE control scheme integration

### Hardware Safety

1. **Voltage validation** is critical
   - Uses `forge_serialization_voltage_pkg` for type-safe voltage handling
   - Validates against platform constraints from `moku-models`
   - Validates against probe specifications from probe models

2. **Never bypass the FORGE control scheme**
   - Ensures safe power-on state (all disabled)
   - Prevents premature starts during deployment
   - Protects against async register updates

## Development Workflow

### Typical Development Flow

1. **Define requirements** in YAML (register specification)
2. **Copy BPD structure** as starting template
3. **Implement Layer 3** (main application logic)
4. **Create Layer 2** (shim for register mapping)
5. **Write P1 tests** (basic validation)
6. **Iterate** based on test results
7. **Add P2/P3 tests** (comprehensive validation)
8. **Deploy to hardware** using moku-models scripts

### When Working on Existing Code

1. **Read the architecture docs first:**
   - `examples/basic-probe-driver/vhdl/FORGE_ARCHITECTURE.md`
   - `examples/basic-probe-driver/README.md`

2. **Understand the 3-layer separation**
   - Layer boundaries are strict
   - Layer 3 never knows about Control Registers

3. **Follow existing patterns exactly**
   - BPD is the authoritative reference
   - If BPD does it, you should too

## Known Issues and Status

### Current Project Phase

The repository is in **template release** status:
- FORGE architecture is production-proven
- BPD reference implementation is complete
- Some agents are untested (only `cocotb-integration-test` validated)
- Layer 1 (BRAM loader) is future work

### Intentional Rough Edges

The BPD example has known issues (documented):
- FSM has known bug (debugging deferred for template work)
- BRAM loader not yet integrated
- Type system gaps documented

**This is intentional** - shows real-world development:
- How to document known issues
- How to defer non-critical work
- How to maintain velocity

## AI Agent Integration

### Available Agents (in `AI/` directory)

The repository includes several AI agent definitions:

- **cocotb-integration-test** - Automated CocoTB test generation (TESTED)
- **cocotb-progressive-test-runner** - Test orchestration
- **cocotb-progressive-test-designer** - Test design
- **forge-vhdl-component-generator** - Component generation
- **hardware-debug** - Debug assistance
- **deployment-orchestrator** - Deployment automation

**Note:** Only `cocotb-integration-test` has been production-tested.

### Agent Pipeline Concept

The AI agents follow a pipeline:
1. **Requirements gathering** - Determine if creating component or instrument
2. **Design** - Generate YAML specifications
3. **Implementation** - Generate VHDL following FORGE patterns
4. **Testing** - Progressive testing (P1 → P2 → P3)
5. **Deployment** - Hardware validation

### Using Agents

Agents are stored in the `AI/` directory (not hidden) for easy version control and sharing. The system is designed to be "LLM-friendly" with:
- Clear layer separation
- Typed signals (not raw bits)
- Progressive testing
- Extensive documentation

## Additional Resources

### Key Documentation Files

- `sys/forge-platform/README.md` - Complete FORGE platform guide
- `examples/basic-probe-driver/README.md` - BPD reference guide
- `examples/basic-probe-driver/vhdl/FORGE_ARCHITECTURE.md` - 3-layer spec
- `libs/moku-models/README.md` - Platform models documentation
- `docs/CocoTB/README.md` - CocoTB usage in FORGE
- `docs/Progressive Testing/README.md` - Progressive testing philosophy

### External References

- [Liquid Instruments MCC API](https://apis.liquidinstruments.com/mcc/wrapper.html)
- [CocoTB Documentation](https://www.cocotb.org)
- [Moku Platforms](https://liquidinstruments.com/products/hardware-platforms/)

## Version Information

**Repository:** FORGE-v6
**Architecture Version:** 2.0.0 (Template Release, 2025-11-06)
**Main Branch:** `main`
**License:** MIT
