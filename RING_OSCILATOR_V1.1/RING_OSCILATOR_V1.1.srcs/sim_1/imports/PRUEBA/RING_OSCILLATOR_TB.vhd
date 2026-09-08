library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity RING_OSCILLATOR_TB is
--  Port ( );
end RING_OSCILLATOR_TB;

architecture Behavioral of RING_OSCILLATOR_TB is

    component RING_OSCILLATOR is
      generic(NUM_ETAPAS : integer := 5);  --NUMERO DE ETAPAS INVERSORAS. TIENE QUE SER PAR DEBIDO A QUE TENGO UN ENABLE CON UNA NAND
      Port ( enable_in : in std_logic;
             ring_osc_in : in std_logic;
             ring_osc_out : out std_logic);
    end component;
    
    signal enable_in : std_logic := '0';
    signal ring_osc_in : std_logic := '0';
    signal ring_osc_out : std_logic;

    
begin
    uut1: RING_OSCILLATOR
    generic map(NUM_ETAPAS => 5)
    Port map( enable_in      => enable_in,
              ring_osc_in    => ring_osc_in,
              ring_osc_out   => ring_osc_out);
              
    process
    begin
        -- Inicialización
        enable_in <= '0';
        wait for 500 ns;
    
        -- Activa enable
        enable_in <= '1';
        wait for 1000 ns;
    
        -- Conecta feedback
        wait for 2000 ns;
    
        -- Desactiva y reactiva
        enable_in <= '0';
        wait for 3000 ns;
        enable_in <= '1';
        wait;
    end process;
        ring_osc_in <= ring_osc_out;

end Behavioral;
