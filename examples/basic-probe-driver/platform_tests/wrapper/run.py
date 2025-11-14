#!/usr/bin/env python3
"""
CocoTB Test Runner for BPD Platform Wrapper Tests

Tests CustomWrapper_bpd architecture through MCC CustomInstrument interface.
Uses forge_cocotb progressive testing infrastructure (P1/P2/P3).

Usage:
    uv run python run.py                           # Run P1 tests (default)
    TEST_LEVEL=P2 uv run python run.py             # Run P2 tests
    GHDL_FILTER_LEVEL=none uv run python run.py   # No filtering (debug)

Clean output (recommended):
    uv run python run.py 2>&1 | grep -v "metavalue" | grep -v "assertion warning"

Note: GHDL prints warnings after Python exits. Use shell filtering above for cleanest output.

Author: BPD Development Team
Date: 2025-11-11
"""

import sys
import os
from pathlib import Path
import subprocess
import tempfile

# Test must be run from cocotb
try:
    from cocotb_tools.runner import get_runner
except ImportError:
    print("❌ CocoTB not found! Install with: uv sync")
    sys.exit(1)

# Import GHDL filter from forge_cocotb package
try:
    from forge_cocotb.ghdl_filter import GHDLOutputFilter, FilterLevel
except ImportError:
    print("❌ forge_cocotb not found! Install with: uv sync")
    sys.exit(1)

# Test configuration
VHDL_ROOT = Path(__file__).parent.parent.parent / "vhdl"
FORGE_VHDL_PKG = Path(__file__).parent.parent.parent.parent.parent / "libs" / "forge-vhdl" / "vhdl" / "packages"
FORGE_VHDL_DEBUG = Path(__file__).parent.parent.parent.parent.parent / "libs" / "forge-vhdl" / "vhdl" / "debugging"

HDL_SOURCES = [
    # FORGE packages
    FORGE_VHDL_PKG / "forge_common_pkg.vhd",
    FORGE_VHDL_PKG / "forge_voltage_5v_bipolar_pkg.vhd",

    # FORGE debugging components (HVS hierarchical encoder)
    FORGE_VHDL_DEBUG / "forge_hierarchical_encoder.vhd",

    # BPD application-specific packages
    VHDL_ROOT / "src" / "basic_app_types_pkg.vhd",
    VHDL_ROOT / "src" / "basic_app_voltage_pkg.vhd",
    VHDL_ROOT / "src" / "basic_app_time_pkg.vhd",

    # CustomWrapper entity declaration (CocoTB test stub)
    VHDL_ROOT / "CustomWrapper_test_stub.vhd",

    # BPD source files (Layer 2 + Layer 3)
    VHDL_ROOT / "BPD_forge_shim.vhd",
    VHDL_ROOT / "BPD_forge_main.vhd",

    # CustomWrapper architecture (bpd_forge)
    VHDL_ROOT / "CustomWrapper_bpd_forge.vhd",
]

HDL_TOPLEVEL = "customwrapper"  # GHDL lowercases entity names (CustomWrapper -> customwrapper)
TEST_MODULE = "P1_bpd_wrapper_basic"

def main():
    # Get filter level from environment
    filter_level_str = os.environ.get("GHDL_FILTER_LEVEL", "aggressive")
    try:
        filter_level = FilterLevel(filter_level_str)
    except ValueError:
        print(f"⚠️  Invalid GHDL_FILTER_LEVEL: {filter_level_str}, using 'aggressive'")
        filter_level = FilterLevel.AGGRESSIVE

    # Initialize GHDL filter
    ghdl_filter = GHDLOutputFilter(filter_level)

    # Get test runner
    runner = get_runner("ghdl")

    # Set environment for test
    test_level = os.environ.get("TEST_LEVEL", "P1_BASIC")
    print(f"Running BPD Wrapper Tests (Level: {test_level})")
    print(f"GHDL Filter: {filter_level.value}")
    print("=" * 70)

    # Set working directory to the test directory (cocotb expects this)
    os.chdir(Path(__file__).parent)

    # Convert Path objects to strings for cocotb_tools
    sources_str = [str(src) for src in HDL_SOURCES]

    # Build HDL (analyze + elaborate)
    print("\n📦 Building HDL sources...")
    runner.build(
        sources=sources_str,
        hdl_toplevel=HDL_TOPLEVEL,
        always=True,  # Always rebuild
        build_args=["--std=08"],  # VHDL-2008
    )

    # Run tests with output filtering
    print("\n🧪 Running CocoTB tests...\n")

    # Create a temporary file to capture unfiltered output
    with tempfile.NamedTemporaryFile(mode='w+', suffix='.log', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        # Redirect stdout/stderr to capture output
        original_stdout = sys.stdout
        original_stderr = sys.stderr

        # Create a custom writer that filters in real-time
        class FilteredWriter:
            def __init__(self, original, filter_obj):
                self.original = original
                self.filter = filter_obj
                self.buffer = []

            def write(self, text):
                # Write to original for logging
                with open(tmp_path, 'a') as f:
                    f.write(text)

                # Filter and display
                lines = text.split('\n')
                for i, line in enumerate(lines):
                    # Don't add empty line at end if text doesn't end with \n
                    if i == len(lines) - 1 and line == '':
                        continue

                    if self.filter.should_show_line(line + '\n'):
                        self.original.write(line + '\n')

            def flush(self):
                self.original.flush()

        # Only apply filter if not NONE level
        if filter_level != FilterLevel.NONE:
            sys.stdout = FilteredWriter(original_stdout, ghdl_filter)
            sys.stderr = FilteredWriter(original_stderr, ghdl_filter)

        # Run tests
        # Note: GHDL post-simulation warnings still appear after Python exits
        # These are printed by GHDL itself and cannot be captured by Python
        # Use shell-level filtering if needed: python run.py 2>&1 | grep -v "metavalue"
        runner.test(
            hdl_toplevel=HDL_TOPLEVEL,
            test_module=TEST_MODULE,
        )

    finally:
        # Restore stdout/stderr
        sys.stdout = original_stdout
        sys.stderr = original_stderr

        # Clean up temp file
        try:
            os.unlink(tmp_path)
        except:
            pass

    print("\n" + "=" * 70)
    print("✅ Tests completed")

    # Show filter stats if filtering was applied
    if filter_level != FilterLevel.NONE:
        stats = ghdl_filter.stats
        if stats.total_lines > 0:
            filtered_pct = (stats.filtered_lines / stats.total_lines) * 100
            print(f"📊 GHDL Filter Stats: {stats.filtered_lines}/{stats.total_lines} lines filtered ({filtered_pct:.1f}%)")

    print("=" * 70)

if __name__ == "__main__":
    sys.exit(main())
