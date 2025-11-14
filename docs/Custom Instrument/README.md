---
Last Updated: 2025-11-12
Maintainer: Moku Instrument Forge Team
---
#  [[docs/Custom Instrument/README|Custom Instrument]]


The **Custom Instrument** is the terminology liquid instruments is migrating to in the future. 



``` vhdl

entity Your_CustomApp_here is
		------------------------------------------------------------------------
        -- Standard Control Signals 
        -- Priority Order: Reset > ClkEn > Enable
        ------------------------------------------------------------------------
        Clk    : in  std_logic;
        Reset  : in  std_logic;  -- Active-high reset (forces safe state)
        ClkEn  : in  std_logic;  -- Clock enable (freezes sequential logic)
		Enable : in  std_logic;  -- Functional enable (gates work)
       
		------------------------------------------------------------------------
        -- MCC I/O (Native MCC Types)   
		------------------------------------------------------------------------
		InputA : out signed(15 downto 0);
        InputB : out signed(15 downto 0);
        InputC : out signed(15 downto 0);

        OutputA : out signed(15 downto 0);
        OutputB : out signed(15 downto 0);
        OutputC : out signed(15 downto 0);

		------------------------------------------------------------------------
        -- FORGE-Mandated State/Status vectors 
        ------------------------------------------------------------------------
        app_state_vector  : out std_logic_vector(5 downto 0);  -- FSM state (6-bit)
        app_status_vector : out std_logic_vector(7 downto 0);  -- App status (8-bit)
        ----
        
```

# See Also
##  [[docs/N/Custom Wrapper/README|Custom Wrapper]]

# See Also
## [MCC Examples](https://github.com/liquidinstruments/moku-examples/tree/main/mcc)
