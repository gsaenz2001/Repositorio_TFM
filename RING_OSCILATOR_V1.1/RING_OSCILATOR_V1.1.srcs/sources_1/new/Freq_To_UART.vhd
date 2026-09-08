library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Freq_To_UART is
  generic(
    BITS_FREQ        : integer := 32;
    CHAR_DELAY_TICKS : integer := 20000  -- margen entre caracteres (~0,2ms)
  );
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;

    tick_1s  : in  std_logic;   -- pulso de 1s (Contador_pulsos_reloj)
    f0       : in  std_logic_vector(BITS_FREQ-1 downto 0);
    f1       : in  std_logic_vector(BITS_FREQ-1 downto 0);
    f2       : in  std_logic_vector(BITS_FREQ-1 downto 0);
    f3       : in  std_logic_vector(BITS_FREQ-1 downto 0);

    tx_start : out std_logic;   -- hacia UART_tx
    tx_data  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture Behavioral of Freq_To_UART is

  -- 9 dígitos decimales: d(0)=unidades, d(8)=centenas de millón
  type t_digits9 is array (0 to 8) of integer range 0 to 9;

  function bin_to_dec9(x : std_logic_vector) return t_digits9 is
    variable u   : unsigned(x'range);
    variable tmp : integer range 0 to 999_999_999;
    variable d   : t_digits9 := (others => 0);
  begin
    u := unsigned(x);

    if to_integer(u) > 999_999_999 then
      tmp := 999_999_999;      -- saturamos si se pasa
    else
      tmp := to_integer(u);
    end if;

    for i in 0 to 8 loop
      d(i) := tmp mod 10;
      tmp  := tmp / 10;
    end loop;

    return d;
  end function;

  -- 4 números, cada uno con 9 dígitos
  type t_digits4 is array(0 to 3) of t_digits9;
  signal digits4 : t_digits4 := (others => (others => 0));

  signal ro_idx       : integer range 0 to 3 := 0;  -- cuál de f0..f3
  signal digit_idx    : integer range 0 to 8 := 8;  -- de 8 a 0
  signal char_counter : integer range 0 to CHAR_DELAY_TICKS := 0;

  type t_state is (
    IDLE,
    SEND_DIGIT, WAIT_DIGIT,
    SEND_COMMA, WAIT_COMMA,
    SEND_CR, WAIT_CR,
    SEND_LF, WAIT_LF
  );
  signal state : t_state := IDLE;

begin

  process(clk, rst)
  begin
    if rst = '1' then
      state        <= IDLE;
      tx_start     <= '0';
      tx_data      <= (others => '0');
      ro_idx       <= 0;
      digit_idx    <= 8;
      char_counter <= 0;

    elsif rising_edge(clk) then
      tx_start <= '0';  -- pulso de 1 ciclo

      case state is

        when IDLE =>
          if tick_1s = '1' then
            -- Capturamos y convertimos todo al inicio del frame UART
            digits4(0) <= bin_to_dec9(f0);
            digits4(1) <= bin_to_dec9(f1);
            digits4(2) <= bin_to_dec9(f2);
            digits4(3) <= bin_to_dec9(f3);

            ro_idx    <= 0;
            digit_idx <= 8;
            state     <= SEND_DIGIT;
          end if;

        when SEND_DIGIT =>
          tx_data      <= std_logic_vector(to_unsigned(digits4(ro_idx)(digit_idx) + 48, 8));
          tx_start     <= '1';
          char_counter <= 0;
          state        <= WAIT_DIGIT;

        when WAIT_DIGIT =>
          if char_counter = CHAR_DELAY_TICKS then
            if digit_idx = 0 then
              if ro_idx = 3 then
                state <= SEND_CR;        -- ya enviamos f3 completo
              else
                state <= SEND_COMMA;     -- separar f0,f1,f2 con coma
              end if;
            else
              digit_idx <= digit_idx - 1;
              state     <= SEND_DIGIT;
            end if;
          else
            char_counter <= char_counter + 1;
          end if;

        when SEND_COMMA =>
          tx_data      <= x"2C";  -- ','
          tx_start     <= '1';
          char_counter <= 0;
          state        <= WAIT_COMMA;

        when WAIT_COMMA =>
          if char_counter = CHAR_DELAY_TICKS then
            ro_idx    <= ro_idx + 1;
            digit_idx <= 8;
            state     <= SEND_DIGIT;
          else
            char_counter <= char_counter + 1;
          end if;

        when SEND_CR =>
          tx_data      <= x"0D";  -- '\r'
          tx_start     <= '1';
          char_counter <= 0;
          state        <= WAIT_CR;

        when WAIT_CR =>
          if char_counter = CHAR_DELAY_TICKS then
            state <= SEND_LF;
          else
            char_counter <= char_counter + 1;
          end if;

        when SEND_LF =>
          tx_data      <= x"0A";  -- '\n'
          tx_start     <= '1';
          char_counter <= 0;
          state        <= WAIT_LF;

        when WAIT_LF =>
          if char_counter = CHAR_DELAY_TICKS then
            state <= IDLE;
          else
            char_counter <= char_counter + 1;
          end if;

      end case;
    end if;
  end process;

end Behavioral;