library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Contador_RO is
  Generic ( BITS_DATOS : integer);
  Port ( clk_RO : in std_logic;
         rst_in : in std_logic;
         rst_cuenta : in std_logic;
         frq_salida : out std_logic_vector(BITS_DATOS-1 downto 0));
end Contador_RO;

architecture Behavioral of Contador_RO is
    signal cuenta  : unsigned(BITS_DATOS-1 downto 0) := (others => '0');
    signal frq_reg   : unsigned(BITS_DATOS-1 downto 0) := (others => '0');
begin
    process(clk_RO,rst_in)
    begin
        if rst_in = '1' then
            cuenta  <= (others => '0');
            frq_reg <= (others => '0');
        elsif clk_RO' event and clk_RO = '1' then
            if rst_cuenta = '1' then
                frq_reg <= cuenta;
                cuenta  <= (others => '0');
            else
                cuenta <= cuenta + 1;  
            end if;
        end if;    
    end process;
    frq_salida <= std_logic_vector(frq_reg);
end Behavioral;
