library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Contador_pulsos_reloj is
  Generic ( FREQ_HZ : integer);
  Port ( rst_in : in std_logic;
         clk_in : in std_logic;
         tick_1s  : out std_logic);
end Contador_pulsos_reloj;

architecture Behavioral of Contador_pulsos_reloj is
    signal cuenta : integer range 0 to FREQ_HZ-1 := 0;
begin
    process(clk_in, rst_in)
        begin
            if rst_in = '1' then
                cuenta  <= 0;
                tick_1s <= '0';
            elsif rising_edge(clk_in) then
                if cuenta = FREQ_HZ-1 then
                    cuenta  <= 0;
                    tick_1s <= '1';     
                else
                    cuenta  <= cuenta + 1;
                    tick_1s <= '0';
                end if;
            end if;
        end process;
end Behavioral;


