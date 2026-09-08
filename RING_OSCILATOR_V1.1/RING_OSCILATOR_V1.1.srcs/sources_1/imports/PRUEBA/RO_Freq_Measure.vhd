library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RO_Freq_Measure is
  generic(NUM_ETAPAS : integer;    --NUMERO DE ETAPAS INVERSORAS
          BITS_FREQ : integer := 32); 
  Port (clk_in : in std_logic;
        rst_in : in std_logic; 
        ring_osc_in : in std_logic;
        ring_osc_out : out std_logic;
        enable_in : in std_logic;
        tick_1s_out  : out std_logic;
        Freq_RO : out std_logic_vector(BITS_FREQ-1 downto 0));
end RO_Freq_Measure;

architecture Behavioral of RO_Freq_Measure is

    component RING_OSCILLATOR is
      generic(NUM_ETAPAS : integer);  --NUMERO DE ETAPAS INVERSORAS. TIENE QUE SER PAR DEBIDO A QUE TENGO UN ENABLE CON UNA NAND
      Port ( enable_in : in std_logic;
             ring_osc_in : in std_logic;
             ring_osc_out : out std_logic);
    end component;
    
    component Contador_pulsos_reloj is
      Generic ( FREQ_HZ : integer);
      Port ( rst_in : in std_logic;
             clk_in : in std_logic;
             tick_1s  : out std_logic);
    end component;
    
    component Contador_RO_CDC is
      generic(
        BITS_DATOS : integer := 32
      );
      port(
        -- Dominio RO
        clk_RO    : in  std_logic;
        rst_in    : in  std_logic;
    
        -- Dominio clk_in (100 MHz)
        clk_in    : in  std_logic;
        tick_1s   : in  std_logic;  -- pulso 1 ciclo en clk_in
    
        -- Salida estable en clk_in (para UART)
        frq_salida : out std_logic_vector(BITS_DATOS-1 downto 0)
      );
    end component;
      
    signal s_ring_osc_out : std_logic;    
    signal tick_1s : std_logic;
    signal s_Freq_RO : std_logic_vector(BITS_FREQ-1 downto 0);
    
begin
    uut1: RING_OSCILLATOR
    generic map(NUM_ETAPAS => NUM_ETAPAS)
    Port map( enable_in      => enable_in,
              ring_osc_in    => ring_osc_in,
              ring_osc_out   => s_ring_osc_out);
    ring_osc_out <= s_ring_osc_out;  
    
    ---------------------------------------
    --FREQ_HZ ==> ventana de contador de RO
    -- 1s    = 100000000
    -- 100ms = 10000000
    -- 10ms  = 1000000       
    -- 1ms   = 100000       
    -- 1us   = 10000       
    uut2: Contador_pulsos_reloj
    generic map(FREQ_HZ => 100000)
    Port map( rst_in    => rst_in,
              clk_in    => clk_in,
              tick_1s   => tick_1s);       
    
    ---------------------------------------
    -- AJUSTAR Freq_RO  a la ventana
    -- freq_hz = Freq_RO * (F_fpga/F_ventana)
    -- F_fpga = 100MHZ
    -- F_ventana = FREQ_HZ              
    uut3: Contador_RO_CDC
    generic map(BITS_DATOS => BITS_FREQ)
    port map( clk_RO     => s_ring_osc_out,
              rst_in     => rst_in,
              clk_in     => clk_in,
              tick_1s    => tick_1s,
              frq_salida => s_Freq_RO);
              
    tick_1s_out <= tick_1s;
    Freq_RO <= std_logic_vector(resize(unsigned(s_Freq_RO) * 1000, BITS_FREQ));
end Behavioral;
