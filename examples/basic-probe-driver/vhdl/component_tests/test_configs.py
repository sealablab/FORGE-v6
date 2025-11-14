"""
Test configurations for BPD component tests.

STATUS: Archived after HVS migration (2025-11-11)

This file previously configured fsm_observer component tests, which were removed
after migrating to forge_hierarchical_encoder (HVS approach).

Current BPD tests are located in:
    examples/basic-probe-driver/platform_tests/wrapper/

For new component tests, use this file as a template following the forge-vhdl
test infrastructure pattern.

Author: BPD Development Team
Date: 2025-11-11
"""

from pathlib import Path
from dataclasses import dataclass, field
from typing import List

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SRC_DIR = PROJECT_ROOT / "src"
TESTS_DIR = PROJECT_ROOT / "tests"

# External dependencies
FORGE_VHDL = PROJECT_ROOT.parent.parent.parent / "libs" / "forge-vhdl"
FORGE_VHDL_PKG = FORGE_VHDL / "vhdl" / "packages"
FORGE_VHDL_DEBUG = FORGE_VHDL / "vhdl" / "debugging"


@dataclass
class TestConfig:
    """Configuration for a single CocoTB test"""
    name: str
    sources: List[Path]
    toplevel: str
    test_module: str
    category: str = "misc"
    ghdl_args: List[str] = field(default_factory=lambda: ["--std=08"])


# ==================================================================================
# Test Configurations
# ==================================================================================

TESTS_CONFIG = {
    # No component tests configured currently.
    # Platform tests are located in examples/basic-probe-driver/platform_tests/wrapper/
    #
    # To add new component tests, follow this pattern:
    #
    # "my_component": TestConfig(
    #     name="my_component",
    #     sources=[
    #         FORGE_VHDL_PKG / "forge_common_pkg.vhd",
    #         SRC_DIR / "my_component.vhd",
    #     ],
    #     toplevel="my_component",
    #     test_module="P1_my_component_basic",
    #     category="component",
    # ),
}


# Helper functions for run.py integration
def get_test_config(module_name: str) -> TestConfig:
    """Get test configuration by module name"""
    if module_name not in TESTS_CONFIG:
        raise ValueError(
            f"Unknown test module: {module_name}\n"
            f"No component tests configured. See examples/basic-probe-driver/platform_tests/wrapper/"
        )
    return TESTS_CONFIG[module_name]


def list_all_tests() -> List[str]:
    """List all available test modules"""
    return sorted(TESTS_CONFIG.keys())


def list_tests_by_category(category: str) -> List[str]:
    """List test modules by category"""
    return sorted([name for name, cfg in TESTS_CONFIG.items() if cfg.category == category])


# Compatibility aliases for forge-vhdl run.py
def get_test_names() -> List[str]:
    """Alias for list_all_tests()"""
    return list_all_tests()


def get_tests_by_category(category: str) -> List[str]:
    """Alias for list_tests_by_category()"""
    return list_tests_by_category(category)


def get_categories() -> List[str]:
    """Get list of all categories"""
    categories = set(cfg.category for cfg in TESTS_CONFIG.values())
    return sorted(categories)
