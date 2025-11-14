--------------------------------------------------------------------------------
-- File: CustomWrapper_counter_forge.vhd
-- Author: Moku Instrument Forge Team
-- Date: 2025-11-11
-- Version: 3.0 (Forge 3-layer architecture)
--
-- Description:
--   CustomWrapper architecture for Counter example using Forge 3-layer pattern.
--   Implements FORGE_READY control scheme (CR0[31:29]) for safe MCC integration.
--
-- Entity: CustomWrapper (defined in CustomWrapper_test_stub.vhd)
--
-- FORGE Control Scheme (CR0[31:29]):
--   CR0[31] = forge_ready  - Set by MCC loader after deployment
--   CR0[30] = user_enable  - User control (GUI toggle)
--   CR0[29] = clk_enable   - Clock gating control
--   loader_done            - BRAM loader completion (tied to '1' for now)
--
-- Register Mapping:
--   CR0[31:29] → FORGE control bits (3-bit handshaking)
--   CR0[5:0]   → max_state (counter limit)
--
-- Architecture:
--   Layer 1: CustomWrapper_counter_forge.vhd (THIS FILE - MCC interface)
--   Layer 2: counter_forge_shim.vhd (register mapping + hierarchical encoder)
--   Layer 3: counter_forge_main.vhd (FSM logic)
--
-- Platform: Moku:Go
-- Clock Frequency: 125 MHz
--
-- References:
--   - forge_common_pkg.vhd (FORGE_READY control scheme)
--   - counter_forge_shim.vhd (shim layer)
--   - counter_forge_main.vhd (main logic)
--   - CustomWrapper_bpd_forge.vhd (pattern reference)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture counter_forge of CustomWrapper is

    ----------------------------------------------------------------------------
    -- FORGE Control Signals (extracted from CR0[31:29])
    ----------------------------------------------------------------------------
    signal forge_ready  : std_logic;
    signal user_enable  : std_logic;
    signal clk_enable   : std_logic;
    signal loader_done  : std_logic;

    ----------------------------------------------------------------------------
    -- Active-High Reset (internal)
    ----------------------------------------------------------------------------
    signal rst_n_internal : std_logic;

    ----------------------------------------------------------------------------
    -- Dummy Inputs (counter doesn't use physical inputs)
    ----------------------------------------------------------------------------
    signal dummy_input_a : signed(15 downto 0);
    signal dummy_input_b : signed(15 downto 0);
    signal dummy_input_c : signed(15 downto 0);

begin

    ----------------------------------------------------------------------------
    -- Convert Reset Polarity
    --
    -- MCC interface: Reset (active-low)
    -- Internal:      rst_n_internal (active-high)
    ----------------------------------------------------------------------------
    rst_n_internal <= not Reset;

    ----------------------------------------------------------------------------
    -- Extract FORGE Control Bits from Control0
    --
    -- CR0[31] = forge_ready  (set by loader after deployment)
    -- CR0[30] = user_enable  (user control)
    -- CR0[29] = clk_enable   (clock gating)
    ----------------------------------------------------------------------------
    forge_ready <= Control0(31);
    user_enable <= Control0(30);
    clk_enable  <= Control0(29);

    ----------------------------------------------------------------------------
    -- BRAM Loader Done Signal
    --
    -- TODO: Connect to actual BRAM loader when implemented
    -- For now, tie to '1' (no BRAM loading required)
    ----------------------------------------------------------------------------
    loader_done <= '1';

    ----------------------------------------------------------------------------
    -- Dummy Inputs (counter doesn't use physical inputs)
    ----------------------------------------------------------------------------
    dummy_input_a <= (others => '0');
    dummy_input_b <= (others => '0');
    dummy_input_c <= (others => '0');

    ----------------------------------------------------------------------------
    -- Instantiate Counter Forge Shim (Layer 2)
    --
    -- The shim layer:
    --   1. Receives FORGE control signals
    --   2. Maps Control0 to friendly names (max_state)
    --   3. Computes global_enable via combine_forge_ready()
    --   4. Instantiates counter_forge_main (Layer 3)
    --   5. Instantiates forge_hierarchical_encoder (OutputC)
    ----------------------------------------------------------------------------
    U_SHIM: entity work.counter_forge_shim
        port map (
            Clk   => Clk,
            Reset => rst_n_internal,

            -- FORGE control signals
            forge_ready => forge_ready,
            user_enable => user_enable,
            clk_enable  => clk_enable,
            loader_done => loader_done,

            -- Control registers
            Control0 => Control0,

            -- Physical I/O (MCC interface)
            InputA  => dummy_input_a,  -- Unused
            InputB  => dummy_input_b,  -- Unused
            InputC  => dummy_input_c,  -- Unused
            OutputA => OutputA,        -- State value (from MAIN)
            OutputB => OutputB,        -- Unused (from MAIN)
            OutputC => OutputC         -- Hierarchical encoding (from encoder)
        );

    ----------------------------------------------------------------------------
    -- Unused Control Registers
    --
    -- Counter only uses Control0, tie off remaining registers
    ----------------------------------------------------------------------------
    -- Control1-Control31 not connected (counter doesn't need them)

end architecture counter_forge;
