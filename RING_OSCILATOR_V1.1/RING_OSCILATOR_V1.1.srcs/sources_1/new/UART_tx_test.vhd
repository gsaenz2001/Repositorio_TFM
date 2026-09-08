library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_tx_test is
    port(
        clk   : in  std_logic;   -- Reloj 100 MHz de la Basys3 (W5)
        reset : in  std_logic;   -- Botón de reset (T18) o puedes dejarlo a '0'
        tx    : out std_logic    -- TX hacia el USB-UART (A18)
    );
end UART_tx_test;

architecture Behavioral of UART_tx_test is

    -- Declaramos el componente UART_tx tal y como está en el proyecto de Hackster
    component UART_tx is
        generic(
            BAUD_CLK_TICKS : integer := 868  -- 100e6 / 115200 ? 868
        );
        port(
            clk         : in  std_logic;
            reset       : in  std_logic;
            tx_start    : in  std_logic;
            tx_data_in  : in  std_logic_vector (7 downto 0);
            tx_data_out : out std_logic
        );
    end component;

    signal tx_start  : std_logic := '0';
    signal tx_data   : std_logic_vector(7 downto 0) := x"35"; -- ASCII '5'
    signal cnt       : integer range 0 to 5_000_000 := 0;    -- para ~50 ms

begin

    -- Instancia del transmisor UART
    U_TX : UART_tx
        generic map(
            BAUD_CLK_TICKS => 868       -- 115200 baudios con clk=100 MHz
        )
        port map(
            clk         => clk,
            reset       => reset,
            tx_start    => tx_start,
            tx_data_in  => tx_data,
            tx_data_out => tx
        );

    -- Generador de pulsos tx_start cada ~50 ms
    -- Cada pulso hace que se envíe un byte '5' por UART
    process(clk, reset)
    begin
        if reset = '1' then
            cnt      <= 0;
            tx_start <= '0';
        elsif rising_edge(clk) then
            if cnt = 5_000_000 then      -- 5e6 ciclos / 100e6 Hz = 0,05 s
                cnt      <= 0;
                tx_start <= '1';         -- pulso de 1 ciclo
            else
                cnt      <= cnt + 1;
                tx_start <= '0';
            end if;
        end if;
    end process;

end Behavioral;
