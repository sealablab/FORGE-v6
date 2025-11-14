--------------------------------------------------------------------------------
-- File: CustomWrapper_bpd_with_observer.vhd
-- Author: AI-assisted implementation (Claude Code)
-- Date: 2025-11-05 (Updated: 2025-11-11 for HVS migration)
-- Version: 2.0 (HVS Hierarchical Encoder integration)
--
-- Description:
--   CustomWrapper architecture for Basic Probe Driver FSM with integrated
--   forge_hierarchical_encoder for oscilloscope-based state+status debugging.
--
-- Migration from fsm_observer to forge_hierarchical_encoder (HVS):
--   - Replaced voltage spreading with digital unit encoding (200 units/state)
--   - Added 8-bit status byte encoding for fine-grained debugging
--   - Fault detection via sign flip (status[7]=1 → negative voltage)
--   - Platform-agnostic: Pure digital domain, decoder handles voltage
--
-- FSM State Digital Encoding (HVS):
--   IDLE     (state=0) →    0 digital units (0 × 200)
--   ARMED    (state=1) →  200 digital units (1 × 200)
--   FIRING   (state=2) →  400 digital units (2 × 200)
--   COOLDOWN (state=3) →  600 digital units (3 × 200)
--   FAULT    (state=63, status[7]=1) → -prev_magnitude (sign flip)
--
-- Status Byte Encoding:
--   status[7]   = fault flag (1 = FAULT state, negative voltage)
--   status[6:0] = app status (trig_active, intensity_active, etc.)
--
-- Oscilloscope Usage:
--   1. Connect OutputD to oscilloscope
--   2. Use tools/decoder/hierarchical_decoder.py to decode digital values
--   3. Positive voltage = normal states (0, 200, 400, 600 digital units)
--   4. Negative voltage = FAULT state (magnitude preserved)
--
-- Entity: CustomWrapper (defined in CustomWrapper_test_stub.vhd)
--
-- Platform: Moku:Go
-- Clock Frequency: 125 MHz
--
-- References:
--   - forge_hierarchical_encoder.vhd (HVS encoder)
--   - tools/decoder/hierarchical_decoder.py (Python decoder)
--   - Obsidian/Project/Test-Architecture/forge_hierarchical_encoder_test_design.md
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library WORK;
use WORK.forge_serialization_types_pkg.all;
use WORK.forge_serialization_voltage_pkg.all;
use WORK.forge_serialization_time_pkg.all;
use WORK.forge_voltage_5v_bipolar_pkg.all;  -- For fsm_observer

architecture bpd_wrapper_with_observer of CustomWrapper is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------
    constant CLK_FREQ_HZ : integer := 125000000;  -- Moku:Go clock frequency
    constant GLOBAL_ENABLE : std_logic := '1';    -- Always enabled (no VOLO handshaking)

    ----------------------------------------------------------------------------
    -- Internal Signals - FSM Control Interface
    ----------------------------------------------------------------------------
    signal arm_enable           : std_logic;
    signal ext_trigger_in       : std_logic;
    signal trigger_wait_timeout : unsigned(15 downto 0);
    signal auto_rearm_enable    : std_logic;
    signal fault_clear          : std_logic;

    signal trig_out_voltage     : signed(15 downto 0);
    signal trig_out_duration    : unsigned(15 downto 0);

    signal intensity_voltage    : signed(15 downto 0);
    signal intensity_duration   : unsigned(15 downto 0);

    signal cooldown_interval    : unsigned(23 downto 0);

    signal probe_monitor_feedback    : signed(15 downto 0);
    signal monitor_enable            : std_logic;
    signal monitor_threshold_voltage : signed(15 downto 0);
    signal monitor_expect_negative   : std_logic;
    signal monitor_window_start      : unsigned(31 downto 0);
    signal monitor_window_duration   : unsigned(31 downto 0);

    ----------------------------------------------------------------------------
    -- Internal Signals - FSM Status Interface
    ----------------------------------------------------------------------------
    signal trig_out_active_port      : std_logic;
    signal intensity_out_active_port : std_logic;
    signal current_state_port        : std_logic_vector(5 downto 0);
    signal ready_for_updates         : std_logic;  -- Not used in wrapper

    ----------------------------------------------------------------------------
    -- HVS Hierarchical Encoder Signals
    ----------------------------------------------------------------------------
    signal current_status_port  : std_logic_vector(7 downto 0);  -- 8-bit status from FSM
    signal hvs_encoded_voltage  : signed(15 downto 0);             -- HVS digital output

begin

    ----------------------------------------------------------------------------
    -- Control Register Unpacking
    ----------------------------------------------------------------------------

    -- Control0: Lifecycle control bits
    arm_enable        <= Control0(0);
    ext_trigger_in    <= Control0(1);
    auto_rearm_enable <= Control0(2);
    fault_clear       <= Control0(3);

    -- Control1: Trigger output voltage (signed, mV)
    trig_out_voltage  <= signed(Control1(15 downto 0));

    -- Control2: Trigger pulse duration (unsigned, ns)
    trig_out_duration <= unsigned(Control2(15 downto 0));

    -- Control3: Intensity output voltage (signed, mV)
    intensity_voltage <= signed(Control3(15 downto 0));

    -- Control4: Intensity pulse duration (unsigned, ns)
    intensity_duration <= unsigned(Control4(15 downto 0));

    -- Control5: Trigger wait timeout (unsigned, s)
    trigger_wait_timeout <= unsigned(Control5(15 downto 0));

    -- Control6: Cooldown interval (unsigned, μs)
    cooldown_interval <= unsigned(Control6(23 downto 0));

    -- Control7: Monitor control bits
    monitor_enable          <= Control7(0);
    monitor_expect_negative <= Control7(1);

    -- Control8: Monitor threshold voltage (signed, mV)
    monitor_threshold_voltage <= signed(Control8(15 downto 0));

    -- Control9: Monitor window start delay (unsigned, ns)
    monitor_window_start <= unsigned(Control9);

    -- Control10: Monitor window duration (unsigned, ns)
    monitor_window_duration <= unsigned(Control10);

    ----------------------------------------------------------------------------
    -- Input Mapping
    ----------------------------------------------------------------------------
    probe_monitor_feedback <= InputA;

    ----------------------------------------------------------------------------
    -- Output Packing
    ----------------------------------------------------------------------------

    -- OutputA: Trigger active flag (0x0000 or 0xFFFF)
    OutputA <= (others => trig_out_active_port);

    -- OutputB: Intensity active flag (0x0000 or 0xFFFF)
    OutputB <= (others => intensity_out_active_port);

    -- OutputC: FSM state (6-bit state in lower bits, zero-padded)
    OutputC <= signed("0000000000" & current_state_port);

    -- OutputD: FSM Observer voltage (for oscilloscope debugging)
    OutputD <= fsm_observer_voltage;

    ----------------------------------------------------------------------------
    -- FSM Instantiation
    ----------------------------------------------------------------------------
    BPD_FSM: entity WORK.basic_probe_driver_custom_inst_main
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ
        )
        port map (
            -- Clock and Reset
            Clk                => Clk,
            Reset              => Reset,
            global_enable      => GLOBAL_ENABLE,
            ready_for_updates  => ready_for_updates,

            -- Application Signals (Typed)
            arm_enable                => arm_enable,
            ext_trigger_in            => ext_trigger_in,
            trigger_wait_timeout      => trigger_wait_timeout,
            auto_rearm_enable         => auto_rearm_enable,
            fault_clear               => fault_clear,

            trig_out_voltage          => trig_out_voltage,
            trig_out_duration         => trig_out_duration,

            intensity_voltage         => intensity_voltage,
            intensity_duration        => intensity_duration,

            cooldown_interval         => cooldown_interval,

            probe_monitor_feedback    => probe_monitor_feedback,
            monitor_enable            => monitor_enable,
            monitor_threshold_voltage => monitor_threshold_voltage,
            monitor_expect_negative   => monitor_expect_negative,
            monitor_window_start      => monitor_window_start,
            monitor_window_duration   => monitor_window_duration,

            -- Status Outputs
            trig_out_active_port      => trig_out_active_port,
            intensity_out_active_port => intensity_out_active_port,
            current_state_port        => current_state_port,
            current_status_port       => current_status_port
        );

    ----------------------------------------------------------------------------
    -- HVS Hierarchical Encoder Instantiation
    --
    -- Converts 6-bit FSM state + 8-bit status to digital voltage encoding
    -- - State encoding: 200 digital units per state (IDLE=0, ARMED=200, FIRING=400, ...)
    -- - Status encoding: Fine-grained offset via status[6:0] (0-127 → 0-99 digital units)
    -- - Fault detection: status[7]=1 → negative voltage (sign flip)
    -- - Platform-agnostic: Pure digital domain, voltage interpretation by decoder
    ----------------------------------------------------------------------------
    HVS_ENCODER: entity WORK.forge_hierarchical_encoder
        generic map (
            DIGITAL_UNITS_PER_STATE  => 200,      -- 200 digital units per state
            DIGITAL_UNITS_PER_STATUS => 0.78125   -- 100/128 for status offset
        )
        port map (
            clk           => Clk,
            reset         => Reset,
            state_vector  => current_state_port,    -- 6-bit FSM state (0-63)
            status_vector => current_status_port,   -- 8-bit status byte
            voltage_out   => hvs_encoded_voltage    -- Signed 16-bit digital output
        );

    ----------------------------------------------------------------------------
    -- OutputD Mapping: HVS Hierarchical Encoded State+Status
    -- Digital encoding: state × 200 + status_offset
    -- Oscilloscope will show voltage proportional to digital value
    -- Use tools/decoder/hierarchical_decoder.py to decode back to state+status
    ----------------------------------------------------------------------------
    OutputD <= hvs_encoded_voltage;

end architecture bpd_wrapper_with_observer;
