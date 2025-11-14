"""
Progressive Test Level 1 (P1) - Basic Probe Driver Wrapper
Fast smoke tests for CustomWrapper_bpd_forge architecture

Test Coverage:
- Reset behavior
- FORGE control scheme (CR0[31:29])
- Control register unpacking
- Output signal mapping
- Basic FSM state visibility

Expected Runtime: <5s
Expected Output: <20 lines (P1 standard)
"""

import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
import sys
from pathlib import Path

# Add forge_cocotb to path
FORGE_COCOTB_PATH = Path(__file__).parent.parent.parent.parent.parent / "libs" / "forge-vhdl" / "python"
sys.path.insert(0, str(FORGE_COCOTB_PATH))

# Import forge_cocotb infrastructure
from forge_cocotb.test_base import TestBase, VerbosityLevel
from forge_cocotb.conftest import (
    setup_clock,
    reset_active_high,
    mcc_set_regs,
    wait_for_mcc_ready,
    validate_control0
)

# FSM State Constants (from BPD_forge_main.vhd)
STATE_IDLE     = 0b000000  # 0
STATE_ARMED    = 0b000001  # 1
STATE_FIRING   = 0b000010  # 2
STATE_COOLDOWN = 0b000011  # 3
STATE_FAULT    = 0b111111  # 63

# HVS Digital Encoding Constants (via forge_hierarchical_encoder in shim layer)
# OutputC shows hierarchical digital encoding for oscilloscope debugging
# Encoding: state × 200 + status_offset
# IDLE=0, ARMED=200, FIRING=400, COOLDOWN=600, FAULT=negative (sign flip)
HVS_DIGITAL_IDLE     = 0      # State 0 × 200
HVS_DIGITAL_ARMED    = 200    # State 1 × 200
HVS_DIGITAL_FIRING   = 400    # State 2 × 200
HVS_DIGITAL_COOLDOWN = 600    # State 3 × 200
# FAULT state: Negative digital value (sign-flip of previous state magnitude)

# Tolerance for digital comparison (±10 digital units for status offset variation)
HVS_DIGITAL_TOLERANCE = 10

# FORGE Control Scheme Constants
MCC_CR0_FORGE_READY = 0x80000000  # CR0[31] = forge_ready
MCC_CR0_USER_ENABLE = 0x40000000  # CR0[30] = user_enable
MCC_CR0_CLK_ENABLE  = 0x20000000  # CR0[29] = clk_enable
MCC_CR0_ALL_ENABLED = 0xE0000000  # All three bits set


class BPDWrapperBasicTests(TestBase):
    """P1 - BASIC tests for CustomWrapper_bpd_forge"""

    def __init__(self, dut):
        super().__init__(dut, "bpd_wrapper_basic")

    async def run_p1_basic(self):
        """P1 test suite entry point"""
        # Setup
        await setup_clock(self.dut, clk_signal="Clk")
        await reset_active_high(self.dut, rst_signal="Reset")

        # Initialize all control registers to 0
        for i in range(16):
            ctrl_name = f"Control{i}"
            if hasattr(self.dut, ctrl_name):
                getattr(self.dut, ctrl_name).value = 0

        # Run tests
        await self.test("Reset behavior", self.test_reset)
        await self.test("FORGE control scheme", self.test_forge_control)
        await self.test("Output mapping", self.test_output_mapping)

    async def test_reset(self):
        """Verify Reset drives FSM to IDLE state (HVS digital encoding)"""
        # Assert reset
        self.dut.Reset.value = 1
        await ClockCycles(self.dut.Clk, 2)

        # Check FSM is in IDLE via HVS digital encoding on OutputC
        digital_out = int(self.dut.OutputC.value.signed_integer)
        assert abs(digital_out - HVS_DIGITAL_IDLE) <= HVS_DIGITAL_TOLERANCE, \
            f"Expected IDLE digital ({HVS_DIGITAL_IDLE} ±{HVS_DIGITAL_TOLERANCE}), got {digital_out}"

        # Check outputs are inactive
        assert int(self.dut.OutputA.value.signed_integer) == 0, "trig_out_active should be 0 after reset"
        assert int(self.dut.OutputB.value.signed_integer) == 0, "intensity_out_active should be 0 after reset"

    async def test_forge_control(self):
        """Verify FORGE control scheme enables module correctly (HVS digital encoding)"""
        # Release reset
        self.dut.Reset.value = 0
        await ClockCycles(self.dut.Clk, 2)

        # Test 1: No FORGE bits set (module should remain disabled)
        self.dut.Control0.value = 0x00000000
        await ClockCycles(self.dut.Clk, 2)
        # FSM should be IDLE with global_enable=0
        digital_out = int(self.dut.OutputC.value.signed_integer)
        assert abs(digital_out - HVS_DIGITAL_IDLE) <= HVS_DIGITAL_TOLERANCE, \
            f"Expected IDLE digital ({HVS_DIGITAL_IDLE}) with no FORGE bits, got {digital_out}"

        # Test 2: Apply FORGE control bits (enable module)
        # CR0[31:29] = forge_ready | user_enable | clk_enable
        await mcc_set_regs(self.dut, {
            0: MCC_CR0_ALL_ENABLED  # All three FORGE bits set
        }, set_mcc_ready=False)  # Don't set bit 31 again, already set

        await wait_for_mcc_ready(self.dut, settle_cycles=10)

        # Validate FORGE control0
        validate_control0(int(self.dut.Control0.value), "After FORGE enable")

        # Module should now be enabled (global_enable=1), still in IDLE
        digital_out = int(self.dut.OutputC.value.signed_integer)
        assert abs(digital_out - HVS_DIGITAL_IDLE) <= HVS_DIGITAL_TOLERANCE, \
            f"Module should still be IDLE, got digital {digital_out}"

    async def test_output_mapping(self):
        """Verify OutputA/B/C correctly reflect FSM status (HVS digital encoding)"""
        # Ensure module is enabled with FORGE control
        self.dut.Reset.value = 0
        self.dut.Control0.value = MCC_CR0_ALL_ENABLED
        await ClockCycles(self.dut.Clk, 2)

        # OutputC should show HVS hierarchical digital encoding (initially IDLE = 0)
        digital_out = int(self.dut.OutputC.value.signed_integer)
        assert abs(digital_out - HVS_DIGITAL_IDLE) <= HVS_DIGITAL_TOLERANCE, \
            f"Expected IDLE digital ({HVS_DIGITAL_IDLE}) in OutputC, got {digital_out}"

        # OutputA/B should be 0x0000 when outputs inactive
        assert int(self.dut.OutputA.value.signed_integer) == 0, "OutputA should be 0 in IDLE"
        assert int(self.dut.OutputB.value.signed_integer) == 0, "OutputB should be 0 in IDLE"

        # OutputD is reserved (tied to 0 in CustomWrapper_bpd_forge)
        # NOTE: CustomWrapper_bpd_with_observer uses OutputD for HVS encoding, but this test
        #       uses CustomWrapper_bpd_forge which has OutputD tied to zero
        assert int(self.dut.OutputD.value.signed_integer) == 0, "OutputD should be 0 (reserved)"


@cocotb.test()
async def test_bpd_wrapper_p1(dut):
    """P1 test entry point"""
    tester = BPDWrapperBasicTests(dut)
    await tester.run_p1_basic()
