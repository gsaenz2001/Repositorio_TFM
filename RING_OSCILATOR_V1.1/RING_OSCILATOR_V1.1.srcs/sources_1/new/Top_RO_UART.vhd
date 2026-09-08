library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Top_RO_UART is
  generic(
    NUM_ETAPAS : integer := 5;
    BITS_FREQ  : integer := 32
  );
  port(
    clk_in      : in  std_logic;   -- 100 MHz
    rst_in      : in  std_logic;   -- botón reset
    ring_osc_in : in  std_logic_vector(3 downto 0);   
    ring_osc_out: out std_logic_vector(3 downto 0);
    enable_in   : in  std_logic_vector(3 downto 0);   -- enable del RO
    enable_RO_in   : in  std_logic;   -- enable del RO interno
    tx     : out std_logic    -- TX hacia USB-UART
  );
end Top_RO_UART;

architecture Behavioral of Top_RO_UART is

  component RO_Freq_Measure is
    generic(NUM_ETAPAS : integer;
            BITS_FREQ  : integer := 32); 
    Port ( clk_in       : in  std_logic;
           rst_in       : in  std_logic; 
           ring_osc_in  : in  std_logic;
           ring_osc_out : out std_logic;
           enable_in    : in  std_logic;
           Freq_RO      : out std_logic_vector(BITS_FREQ-1 downto 0);
           tick_1s_out  : out std_logic);
  end component;

  component Freq_To_UART is
    generic(
      BITS_FREQ        : integer := 32;
      CHAR_DELAY_TICKS : integer := 20000
    );
    port(
      clk      : in  std_logic;
      rst      : in  std_logic;
      tick_1s  : in  std_logic;
      f0       : in  std_logic_vector(BITS_FREQ-1 downto 0);
      f1       : in  std_logic_vector(BITS_FREQ-1 downto 0);
      f2       : in  std_logic_vector(BITS_FREQ-1 downto 0);
      f3       : in  std_logic_vector(BITS_FREQ-1 downto 0);
      tx_start : out std_logic;
      tx_data  : out std_logic_vector(7 downto 0)
    );
  end component;
  
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
  
  component RING_OSCILLATOR_INTERNO is
      generic(NUM_ETAPAS : integer); 
      Port ( enable_in : in std_logic;
             ring_osc_in : in std_logic;
             ring_osc_out : out std_logic);
   end component;

  -- arrays para 4 mediciones
  type t_freq_arr is array (0 to 3) of std_logic_vector(BITS_FREQ-1 downto 0);
  signal Freq_s : t_freq_arr := (others => (others => '0'));
  signal tick_s : std_logic_vector(3 downto 0) := (others => '0');
  
  signal tx_start_s: std_logic;
  signal tx_data_s : std_logic_vector(7 downto 0);
  
  constant NUM_RO_INTERNO : integer := 2;  
  constant NUM_ETAPAS_RO_INTERNO : integer := 3;  
  signal RO_INTERNO: std_logic_vector(NUM_RO_INTERNO-1 downto 0);

begin

  -- 1) Medida de frecuencia 
  gen_ext : for i in 0 to 3 generate
    u_meas : RO_Freq_Measure
      generic map(
        NUM_ETAPAS => NUM_ETAPAS,
        BITS_FREQ  => BITS_FREQ
      )
      port map(
        clk_in       => clk_in,
        rst_in       => rst_in,
        ring_osc_in  => ring_osc_in(i),
        ring_osc_out => ring_osc_out(i),
        enable_in    => enable_in(i),
        Freq_RO      => Freq_s(i),
        tick_1s_out  => tick_s(i)
      );
  end generate;

  -- 2) Conversor frecuencia -> texto UART (decimal)
  uut2: Freq_To_UART
    generic map(
      BITS_FREQ        => BITS_FREQ,
      CHAR_DELAY_TICKS => 20000
    )
    port map(
      clk      => clk_in,
      rst      => rst_in,
      tick_1s  => tick_s(0),
      f0       => Freq_s(0),
      f1       => Freq_s(1),
      f2       => Freq_s(2),
      f3       => Freq_s(3),
      tx_start => tx_start_s,
      tx_data  => tx_data_s
    );

  -- 3) Transmisor UART
  uut3: UART_tx
    generic map(
      BAUD_CLK_TICKS => 868   -- 115200 baudios con 100 MHz
    )
    port map(
      clk         => clk_in,
      reset       => rst_in,
      tx_start    => tx_start_s,
      tx_data_in  => tx_data_s,
      tx_data_out => tx
    );
    
   --4) Osciladores internos que van al rededor del principal
   gen_guard_ros : for i in 0 to NUM_RO_INTERNO-1 generate
    uut4 : RING_OSCILLATOR_INTERNO
      generic map ( NUM_ETAPAS => NUM_ETAPAS_RO_INTERNO)
      port map ( enable_in => enable_RO_in,
                 ring_osc_in  => RO_INTERNO(i),
                 ring_osc_out => RO_INTERNO(i));
  end generate;

end Behavioral;
