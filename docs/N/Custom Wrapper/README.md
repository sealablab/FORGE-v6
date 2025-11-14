# [Custom Wrapper](https://apis.liquidinstruments.com/mcc/wrapper.html)

The **Custom Wrapper** is the interface (or contract) that lets users mix-and-match instruments on the moku platform. 

At present, the only way to synthesize one all the way down to a bistream is to use
``` vhdl
entity CustomWrapper is
    port (
        Clk : in std_logic;
        Reset : in std_logic;
	
        InputA : in signed(15 downto 0);
        InputB : in signed(15 downto 0);
        InputC : in signed(15 downto 0);

        OutputA : out signed(15 downto 0);
        OutputB : out signed(15 downto 0);
        OutputC : out signed(15 downto 0);

        Control0 : in std_logic_vector(31 downto 0);
        Control1 : in std_logic_vector(31 downto 0);
        Control2 : in std_logic_vector(31 downto 0);
        -- etc etc
        Control14 : in std_logic_vector(31 downto 0);
        Control15 : in std_logic_vector(31 downto 0)
    );
end entity;

```