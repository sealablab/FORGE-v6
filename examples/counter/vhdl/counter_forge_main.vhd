--------------------------------------------------------------------------------
-- File: counter_forge_main.vhd
-- Author: Moku Instrument Forge Team
-- Date: 2025-11-11
-- Version: 2.0 (Layer 3 - MCC-agnostic refactor)
--
-- Description:
--   Simple counter FSM for FORGE counter example following forge-vhdl standards.
--   This is Layer 3 of the Forge architecture - completely MCC-agnostic.
--
-- Platform: Moku:Go
-- Clock Frequency: 125 MHz (8 ns period)
--
-- FSM States (std_logic_vector encoding - Verilog compatible):
--   Counting from 0 → max_state
--   When overflow occurs, wraps to 0 and sets overflow_flag
--
-- Design Innovation: FSM state IS the counter!
--   - 6-bit state machine counts 0→1→2→...→max→overflow→0
--   - OutputA = state value (16-bit extended for visualization)
--   - OutputC = hierarchical encoding (state + status, driven by SHIM)
--
-- Layer 3 of 3-Layer Forge Architecture:
--   Layer 1: CustomWrapper_counter_forge.vhd (MCC interface)
--   Layer 2: counter_forge_shim.vhd (register mapping + hierarchical encoder)
--   Layer 3: counter_forge_main.vhd (THIS FILE - application logic)
--
-- References:
--   - counter_forge_shim.vhd (shim layer)
--   - forge_common_pkg.vhd (FORGE_READY control scheme)
--   - basic-probe-driver/ (reference pattern)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity counter_forge_main is
    port (
        ------------------------------------------------------------------------
        -- Standard Control Signals (MCC-Agnostic)
        -- Priority Order: Reset > Enable
        ------------------------------------------------------------------------
        Clk    : in  std_logic;
        Reset  : in  std_logic;  -- Active-high reset (forces safe state)
        Enable : in  std_logic;  -- Functional enable (gates work)

        ------------------------------------------------------------------------
        -- Application Signals (Friendly Names)
        -- Mapped from Control Registers by shim layer
        ------------------------------------------------------------------------
        max_state : in unsigned(5 downto 0);  -- Maximum count value (0-63)

        ------------------------------------------------------------------------
        -- Physical Outputs (2 outputs from MAIN)
        -- OutputC driven by SHIM layer (hierarchical encoder, not by MAIN)
        ------------------------------------------------------------------------
        OutputA : out signed(15 downto 0);  -- Current state (16-bit extended)
        OutputB : out signed(15 downto 0);  -- Unused

        ------------------------------------------------------------------------
        -- FORGE-Mandated State/Status Exports (Handoff 6)
        -- Used by SHIM for hierarchical encoding on OutputC
        ------------------------------------------------------------------------
        app_state_vector  : out std_logic_vector(5 downto 0);  -- FSM state (6-bit)
        app_status_vector : out std_logic_vector(7 downto 0);  -- App status (8-bit)

        ------------------------------------------------------------------------
        -- Handshaking Signal
        ------------------------------------------------------------------------
        ready_for_updates : out std_logic  -- Safe to update configuration
    );
end entity counter_forge_main;

architecture rtl of counter_forge_main is

    ----------------------------------------------------------------------------
    -- State Signals
    ----------------------------------------------------------------------------
    signal state         : unsigned(5 downto 0);  -- Counter state (0-63)
    signal overflow_flag : std_logic;             -- Overflow indicator

begin

    ----------------------------------------------------------------------------
    -- State Counter FSM Process
    --
    -- Design: FSM state IS the counter (6-bit linear encoding 0-63)
    --   - Auto-increments every clock cycle when enabled
    --   - Wraps to 0 when reaching max_state (sets overflow flag)
    --   - OutputA = current state (16-bit zero-extended)
    ----------------------------------------------------------------------------
    process(Clk, Reset)
    begin
        if Reset = '1' then
            -- Reset to state 0
            state             <= (others => '0');
            overflow_flag     <= '0';
            ready_for_updates <= '1';  -- Safe to update at reset

        elsif rising_edge(Clk) then
            -- Default: clear overflow flag (pulse)
            overflow_flag <= '0';

            if Enable = '0' then
                -- Disabled: hold at state 0, ready for updates
                state             <= (others => '0');
                ready_for_updates <= '1';
            else
                -- Enabled: increment state counter
                ready_for_updates <= '0';  -- Lock configuration during counting

                if state >= max_state then
                    -- Overflow: wrap to 0, set fault flag
                    state         <= (others => '0');
                    overflow_flag <= '1';
                else
                    -- Normal increment
                    state <= state + 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Physical Outputs (OutputC driven by SHIM's hierarchical encoder)
    ----------------------------------------------------------------------------
    OutputA <= resize(signed(state), 16);  -- State as 16-bit signed (zero-extended)
    OutputB <= (others => '0');            -- Unused

    ----------------------------------------------------------------------------
    -- FORGE-Mandated State/Status Exports (Handoff 6)
    --
    -- State Vector: 6-bit state (linear encoding)
    -- Status Vector:
    --   Bit 7: overflow_flag (fault indicator)
    --   Bits 6-0: Reserved for future status bits
    ----------------------------------------------------------------------------
    app_state_vector <= std_logic_vector(state);  -- 6-bit state (linear encoding)

    -- Status vector: overflow flag only (no state duplication)
    app_status_vector <= (7 => overflow_flag, others => '0');

end architecture rtl;
