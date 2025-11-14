# Agent Input Validation

**Pre-condition checker to run BEFORE invoking any forge-vhdl agent.**

This validation step ensures agents receive properly formatted inputs and prevents cascade failures.

---

## Purpose

Agents expect specific input formats and complete information. Running them without validation leads to:
- ❌ VHDL compilation errors (missing ports, undefined signals)
- ❌ Test failures (incorrect expected values)
- ❌ Wasted tokens (agent attempts invalid task, fails, requires retry)
- ❌ Incomplete implementations (agent makes wrong assumptions)

**This validator catches issues BEFORE agent invocation.**

---

## Validation by Agent

### Agent 1: forge-vhdl-component-generator

**Input Required:** Specification file in `workflow/specs/pending/[component_name].md`

**Pre-Flight Checklist:**

```
□ Specification file exists and is readable
□ File follows naming convention: forge_<category>_<function>.md
□ Contains all required sections (see below)
□ No "TODO" or "TBD" placeholders in critical sections
□ Component name is valid VHDL identifier (lowercase, underscores, no spaces)
□ Category is valid: utilities | debugging | loader
```

**Required Sections (all must be present):**

```markdown
# [Component Name]

## Metadata
- Category: [must be specified]
- Version: [must be specified]

## Overview
[Must have both one-sentence + detailed description]

## Requirements
### Functional Requirements
[Cannot be empty]

### Standards Compliance
[Must reference VHDL-2008, no enums]

## Interface
### Entity Declaration
```vhdl
entity [name] is
    generic (...);  -- Optional, can be empty
    port (...);     -- REQUIRED, cannot be empty
end entity;
```

### Port Descriptions
[Table with at least: clk, rst_n OR explanation why not needed]

## Behavior
[Must describe logic OR state machine]

### Reset Behavior
[Must specify what happens on rst_n = '0']

## Testing
### P1 Tests (Essential)
[Must have at least 3 test cases defined]
```

**Detailed Validation:**

1. **Interface Section**
   ```
   ✅ At least one input port defined
   ✅ At least one output port defined
   ✅ Port types are valid: std_logic | std_logic_vector | signed | unsigned
   ✅ Port directions are valid: in | out | inout
   ✅ Port order follows standard: clk, rst_n, clk_en, enable, data..., status...
   ✅ No use of 'real', 'boolean', 'time' types in ports (CocoTB incompatible)
   ```

2. **Behavior Section**
   ```
   ✅ If FSM: states defined as std_logic_vector (NOT enum)
   ✅ If FSM: state encodings specified ("00", "01", etc.)
   ✅ If FSM: state transitions documented
   ✅ Reset values specified for all outputs
   ✅ Enable hierarchy documented (if multiple enables)
   ```

3. **Testing Section**
   ```
   ✅ At least 3 P1 tests defined
   ✅ Each test has: name, scenario, expected output
   ✅ Expected outputs are specific values (not "should work")
   ✅ Test durations are reasonable (<100 cycles for P1)
   ```

4. **Standards Compliance**
   ```
   ✅ No VHDL enums mentioned in FSM states
   ✅ No records in entity ports
   ✅ Component name follows forge_<category>_<function> pattern
   ✅ Reset signal named 'rst_n' (active-low)
   ✅ VHDL-2008 compatibility confirmed
   ```

**If Validation Fails:**
```
STOP: Cannot invoke forge-vhdl-component-generator

Issues found in specification:
- [List specific missing sections]
- [List standards violations]
- [List ambiguous requirements]

Please fix specification file before proceeding.

Recommended action:
1. Review workflow/INTERACTIVE_REQUIREMENTS.md
2. Re-gather missing information
3. Update specification file
4. Re-run validation
```

**If Validation Passes:**
```
✅ Specification validated successfully

Ready to invoke forge-vhdl-component-generator:
- Input: workflow/specs/pending/[component_name].md
- Output: vhdl/components/[category]/[component_name].vhd
- Expected duration: ~30-60 seconds

Proceed? [User confirmation recommended]
```

---

### Agent 2: cocotb-progressive-test-designer

**Input Required:** Generated VHDL file from Agent 1

**Pre-Flight Checklist:**

```
□ VHDL file exists at expected path: vhdl/components/[category]/[component_name].vhd
□ File is readable and non-empty
□ Original specification file still available (for test expectations)
□ GHDL is installed (needed to parse VHDL for interface extraction)
```

**VHDL File Validation:**

1. **Syntactic Validity**
   ```
   ✅ File contains 'entity [name] is' declaration
   ✅ File contains 'architecture rtl of [name] is' declaration
   ✅ Entity and architecture names match
   ✅ Entity declaration is parseable (balanced parentheses, semicolons)
   ✅ No obvious syntax errors (unmatched 'if', 'process', etc.)
   ```

2. **Interface Match**
   ```
   ✅ Entity ports match specification
   ✅ Port names match specification (exact, case-sensitive)
   ✅ Port types match specification
   ✅ Port widths match specification
   ✅ Generics match specification (if any)
   ```

3. **CocoTB Compatibility**
   ```
   ✅ No 'real' types in entity ports
   ✅ No 'boolean' types in entity ports (use std_logic)
   ✅ No 'time' types in entity ports
   ✅ No custom record types in entity ports
   ✅ All ports are accessible types: std_logic, std_logic_vector, signed, unsigned
   ```

4. **Standards Compliance**
   ```
   ✅ Uses VHDL-2008 syntax
   ✅ No enums in entity (should be in architecture only, as std_logic_vector)
   ✅ Reset signal is 'rst_n' (active-low)
   ✅ Port order matches standard: clk, rst_n, clk_en, enable, data, status
   ```

**Specification Cross-Check:**

```
Compare VHDL entity against specification:

□ All specified ports are present in VHDL
□ No unexpected ports in VHDL (unless noted in spec as "internal debug")
□ Port directions match specification
□ Generic defaults match specification

If mismatches found: Report to user, suggest fixes
```

**If Validation Fails:**
```
STOP: Cannot invoke cocotb-progressive-test-designer

Issues found in VHDL file:
- [List syntax errors]
- [List interface mismatches with spec]
- [List CocoTB incompatibilities]

Possible causes:
1. Agent 1 (forge-vhdl-component-generator) produced invalid VHDL
2. Specification was ambiguous or contradictory
3. VHDL standards violations

Recommended action:
1. Review VHDL file: vhdl/components/[category]/[component_name].vhd
2. Check against specification
3. Fix errors manually OR regenerate with Agent 1
4. Re-run validation
```

**If Validation Passes:**
```
✅ VHDL file validated successfully

Ready to invoke cocotb-progressive-test-designer:
- Input: vhdl/components/[category]/[component_name].vhd
- Input: workflow/specs/pending/[component_name].md (for test expectations)
- Output: Test architecture, strategy, expected values
- Expected duration: ~30-60 seconds

Proceed? [User confirmation recommended]
```

---

### Agent 3: cocotb-progressive-test-runner

**Input Required:** Test architecture from Agent 2

**Pre-Flight Checklist:**

```
□ Test architecture document exists (from Agent 2 output)
□ VHDL file still exists and unchanged
□ Test directory exists: cocotb_tests/components/
□ GHDL is installed and accessible
□ Python environment has cocotb, forge_cocotb packages
```

**Test Architecture Validation:**

1. **Required Components**
   ```
   ✅ Test strategy defined (what to test at P1/P2/P3 levels)
   ✅ Expected values specified (for each test case)
   ✅ Test wrapper design (if needed for packages)
   ✅ Constants file design (test values, parameters)
   ```

2. **Test Case Specifications**
   ```
   For each P1 test:
   ✅ Test name is descriptive
   ✅ Scenario is clear (setup, stimulus, expected)
   ✅ Expected outputs are specific values (not vague)
   ✅ Duration is specified (<50 cycles for P1)
   ✅ No contradictory expectations
   ```

3. **Directory Structure**
   ```
   ✅ Target directory exists: cocotb_tests/components/
   ✅ No conflicting test files for this component
   ✅ Can create subdirectory: [component_name]_tests/
   ✅ Write permissions OK
   ```

**Environment Validation:**

```
Run quick environment checks:

1. GHDL executable:
   $ which ghdl
   ✅ Returns path to GHDL

2. GHDL version:
   $ ghdl --version
   ✅ Returns 4.x or newer (3.x may work but not tested)

3. Python packages:
   $ python -c "import cocotb; import forge_cocotb"
   ✅ No import errors

4. Test runner:
   $ ls cocotb_tests/run.py
   ✅ File exists and is executable
```

**If Validation Fails:**
```
STOP: Cannot invoke cocotb-progressive-test-runner

Issues found:
- [List test architecture problems]
- [List environment issues]
- [List missing prerequisites]

Possible causes:
1. Agent 2 (cocotb-progressive-test-designer) produced incomplete test architecture
2. GHDL not installed or not in PATH
3. Python environment missing packages

Recommended action:
1. If test architecture incomplete: Re-run Agent 2
2. If GHDL missing: Run scripts/cloud_setup_with_ghdl.py
3. If Python packages missing: Run ./scripts/setup.sh (NOT 'uv sync' alone!)
4. Re-run validation

**IMPORTANT:** Always use ./scripts/setup.sh for setup, not 'uv sync' alone.
The setup script installs workspace members (forge_cocotb, forge_platform, forge_tools)
in editable mode, which 'uv sync' does not do automatically.
```

**If Validation Passes:**
```
✅ Test architecture and environment validated successfully

Ready to invoke cocotb-progressive-test-runner:
- Input: Test architecture from Agent 2
- Input: VHDL file: vhdl/components/[category]/[component_name].vhd
- Output: Test suite files in cocotb_tests/components/[component_name]_tests/
- Output: Test execution results (PASS/FAIL for each test)
- Expected duration: ~2-5 minutes (compilation + simulation)

Proceed? [User confirmation recommended]
```

---

## Validation Workflow

**Use this sequence before agent invocation:**

```
User approves specification
    ↓
Validate Agent 1 Inputs
    ├─ PASS → Invoke Agent 1 (forge-vhdl-component-generator)
    └─ FAIL → Report issues, fix spec, retry validation
    ↓
Agent 1 completes
    ↓
Validate Agent 2 Inputs
    ├─ PASS → Invoke Agent 2 (cocotb-progressive-test-designer)
    └─ FAIL → Report issues, fix VHDL, retry validation
    ↓
Agent 2 completes
    ↓
Validate Agent 3 Inputs
    ├─ PASS → Invoke Agent 3 (cocotb-progressive-test-runner)
    └─ FAIL → Report issues, fix environment/architecture, retry validation
    ↓
Agent 3 completes
    ↓
Success: VHDL + tests generated and validated
```

---

## Validation Script (Future Enhancement)

**Potential automation:** `scripts/validate_agent_inputs.py`

```python
#!/usr/bin/env python3
"""Automated validation for agent inputs"""

def validate_specification(spec_file):
    """Validate Agent 1 inputs"""
    # Check file exists, sections present, no TODOs, etc.
    # Return: (is_valid: bool, issues: List[str])

def validate_vhdl(vhdl_file, spec_file):
    """Validate Agent 2 inputs"""
    # Parse VHDL, compare to spec, check CocoTB compatibility
    # Return: (is_valid: bool, issues: List[str])

def validate_test_env():
    """Validate Agent 3 inputs"""
    # Check GHDL, Python packages, file permissions
    # Return: (is_valid: bool, issues: List[str])

# Usage:
# $ python scripts/validate_agent_inputs.py spec workflow/specs/pending/forge_util_pwm.md
# $ python scripts/validate_agent_inputs.py vhdl vhdl/components/utilities/forge_util_pwm.vhd
# $ python scripts/validate_agent_inputs.py env
```

---

## Error Message Templates

**Missing Section Error:**
```
❌ Validation Failed: Missing Required Section

File: workflow/specs/pending/[component_name].md
Missing: [Section Name]

This section is required for [Agent Name] to generate correct output.

Example format:
[Show section template from workflow/INTERACTIVE_REQUIREMENTS.md]

Fix: Add this section to specification, then re-run validation.
```

**Standards Violation Error:**
```
❌ Validation Failed: VHDL Standards Violation

File: [spec or VHDL file]
Issue: [Specific violation]

VHDL-FORGE standard requires: [Correct approach]
Found instead: [Incorrect approach]

Why this matters: [Brief explanation of why this is required]

Fix: [Specific fix instructions]
Reference: CLAUDE.md, section "VHDL Coding Standards"
```

**CocoTB Incompatibility Error:**
```
❌ Validation Failed: CocoTB Type Incompatibility

File: vhdl/components/[category]/[component_name].vhd
Port: [port_name]
Issue: Type '[type]' cannot be accessed by CocoTB

CocoTB can only access these types in entity ports:
- std_logic
- std_logic_vector
- signed
- unsigned

CocoTB CANNOT access:
- real (use signed with scaling factor)
- boolean (use std_logic: '0' = false, '1' = true)
- time (use integer clock cycles)
- custom records (flatten to individual signals)

Fix: Change port type or use test wrapper pattern.
Reference: CLAUDE.md, section "Critical CocoTB Interface Rules"
```

---

## Summary Checklist

Before invoking agents, verify:

**Agent 1 (Component Generator):**
- [ ] Specification file exists
- [ ] All required sections present
- [ ] Interface fully defined (ports, types, widths)
- [ ] Behavior specified (FSM states or logic flow)
- [ ] At least 3 P1 tests defined
- [ ] Standards compliance confirmed

**Agent 2 (Test Designer):**
- [ ] VHDL file exists from Agent 1
- [ ] VHDL syntax is valid (parseable)
- [ ] Entity ports match specification
- [ ] No CocoTB-incompatible types in ports
- [ ] GHDL is installed

**Agent 3 (Test Runner):**
- [ ] Test architecture exists from Agent 2
- [ ] VHDL file still valid
- [ ] GHDL installed and working
- [ ] Python packages installed (cocotb, forge_cocotb)
- [ ] Test directory writable

If all checkboxes ✅ → **PROCEED WITH AGENT INVOCATION**

If any checkbox ❌ → **FIX ISSUE BEFORE PROCEEDING**

---

**Version:** 1.0.0
**Last Updated:** 2025-11-09
**Purpose:** Prevent agent failures via pre-flight validation
