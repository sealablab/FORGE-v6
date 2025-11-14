--------------------------------------------------------------------------------
-- File: counter_forge_shim.vhd
-- Generated: 2025-11-11
-- Generator: Manual (will be automated via forge-codegen in future)
--
-- Description:
--   Register mapping shim for Counter ForgeApp.
--   Maps raw Control Registers to friendly signal names and instantiates
--   the application main entity + hierarchical encoder.
--
-- Layer 2 of 3-Layer Forge Architecture:
--   Layer 1: CustomWrapper_counter_forge.vhd (MCC interface)
--   Layer 2: counter_forge_shim.vhd (THIS FILE - register mapping)
--   Layer 3: counter_forge_main.vhd (hand-written app logic)
--
-- Register Mapping:
--   CR0[5:0]  : max_state (configurable count limit, default 15)
--
-- References:
--   - forge_common_pkg.vhd (FORGE_READY control scheme)
--   - BPD_forge_shim.vhd (pattern reference)
--   - forge_hierarchical_encoder.vhd (OutputC encoder)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library WORK;
use WORK.forge_common_pkg.all;

entity counter_forge_shim is
    port (
        ------------------------------------------------------------------------
        -- Clock and Reset
        ------------------------------------------------------------------------
        Clk         : in  std_logic;
        Reset       : in  std_logic;  -- Active-high reset

        ------------------------------------------------------------------------
        -- FORGE Control Signals (from CustomWrapper)
        ------------------------------------------------------------------------
        forge_ready  : in  std_logic;  -- CR0[31] - Set by loader
        user_enable  : in  std_logic;  -- CR0[30] - User control
        clk_enable   : in  std_logic;  -- CR0[29] - Clock gating
        loader_done  : in  std_logic;  -- BRAM loader FSM done signal

        ------------------------------------------------------------------------
        -- Application Registers (from CustomWrapper)
        -- Raw Control Registers CR0 (MCC provides CR0-CR15)
        ------------------------------------------------------------------------
        Control0 : in  std_logic_vector(31 downto 0);

        ------------------------------------------------------------------------
        -- MCC I/O (from CustomWrapper)
        -- Native MCC types: signed(15 downto 0) for all ADC/DAC channels
        ------------------------------------------------------------------------
        InputA      : in  signed(15 downto 0);  -- Unused by counter
        InputB      : in  signed(15 downto 0);  -- Unused by counter
        InputC      : in  signed(15 downto 0);  -- Unused by counter
        OutputA     : out signed(15 downto 0);  -- State value (from MAIN)
        OutputB     : out signed(15 downto 0);  -- Unused (from MAIN)
        OutputC     : out signed(15 downto 0)   -- Hierarchical encoding (from encoder)
    );
end entity counter_forge_shim;

architecture rtl of counter_forge_shim is

    ----------------------------------------------------------------------------
    -- Application Register Signals (Friendly Names)
    ----------------------------------------------------------------------------
    signal max_state : unsigned(5 downto 0);

    ----------------------------------------------------------------------------
    -- State/Status Signals from MAIN (Layer 3)
    ----------------------------------------------------------------------------
    signal app_state_vector  : std_logic_vector(5 downto 0);  -- FSM state (6-bit)
    signal app_status_vector : std_logic_vector(7 downto 0);  -- App status (8-bit)

    ----------------------------------------------------------------------------
    -- Physical Outputs from MAIN
    ----------------------------------------------------------------------------
    signal main_output_a : signed(15 downto 0);
    signal main_output_b : signed(15 downto 0);

    ----------------------------------------------------------------------------
    -- Handshaking
    ----------------------------------------------------------------------------
    signal ready_for_updates : std_logic;

    ----------------------------------------------------------------------------
    -- Global Enable Computation (4-condition FORGE scheme)
    ----------------------------------------------------------------------------
    signal global_enable : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Compute Global Enable (FORGE Control Scheme)
    --
    -- All 4 conditions must be met:
    --   1. forge_ready (loader set this after deployment)
    --   2. user_enable (user control via GUI)
    --   3. clk_enable  (clock gating control)
    --   4. loader_done (BRAM loader FSM completed)
    ----------------------------------------------------------------------------
    global_enable <= combine_forge_ready(
        forge_ready => forge_ready,
        user_enable => user_enable,
        clk_enable  => clk_enable,
        loader_done => loader_done
    );

    ----------------------------------------------------------------------------
    -- Unpack Control Registers → Application Signals
    --
    -- Synchronized with ready_for_updates handshaking:
    --   - Only update registers when MAIN signals it's safe
    --   - Prevents mid-operation configuration changes
    ----------------------------------------------------------------------------
    process(Clk, Reset)
    begin
        if Reset = '1' then
            max_state <= to_unsigned(15, 6);  -- Default: count to 15
        elsif rising_edge(Clk) then
            if ready_for_updates = '1' then
                -- Main logic says it's safe to update registers
                max_state <= unsigned(Control0(5 downto 0));
            end if;
            -- else: Hold current values (main logic busy)
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Physical Outputs: Pass Through from MAIN (OutputA/B)
    -- OutputC driven by hierarchical encoder below
    ----------------------------------------------------------------------------
    OutputA <= main_output_a;
    OutputB <= main_output_b;

    ----------------------------------------------------------------------------
    -- Instantiate Layer 3: Counter Main Logic
    --
    -- The main application logic:
    --   - Completely MCC-agnostic
    --   - Uses friendly signal names only
    --   - Exports app_state_vector + app_status_vector for encoder
    ----------------------------------------------------------------------------
    U_MAIN: entity work.counter_forge_main
        port map (
            Clk    => Clk,
            Reset  => Reset,
            Enable => global_enable,

            max_state => max_state,

            OutputA => main_output_a,
            OutputB => main_output_b,

            app_state_vector  => app_state_vector,
            app_status_vector => app_status_vector,

            ready_for_updates => ready_for_updates
        );

    ----------------------------------------------------------------------------
    -- Instantiate Hierarchical Encoder (drives OutputC)
    --
    -- Per Handoff 6: SHIM instantiates forge_hierarchical_encoder
    --   - Receives app_state_vector[5:0] + app_status_vector[7:0] from MAIN
    --   - Encodes to voltage for oscilloscope visualization
    --   - Drives OutputC
    --
    -- Encoding:
    --   voltage = (state * 200) + (status * 0.78125)
    --   State range: 0-63 (6 bits)
    --   Status range: 0-255 (8 bits, but typically only bit 7 used for fault)
    ----------------------------------------------------------------------------
    U_ENCODER: entity work.forge_hierarchical_encoder
        generic map (
            DIGITAL_UNITS_PER_STATE  => 200,      -- 200 digital units per state
            DIGITAL_UNITS_PER_STATUS => 0.78125   -- 100/128 digital units per status LSB
        )
        port map (
            clk           => Clk,
            reset         => Reset,  -- Active-high reset

            state_vector  => app_state_vector,   -- 6-bit state from MAIN
            status_vector => app_status_vector,  -- 8-bit status from MAIN

            voltage_out   => OutputC             -- Encoded voltage output
        );

end architecture rtl;
