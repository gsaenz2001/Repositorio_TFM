library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Contador_RO_CDC is
  generic( BITS_DATOS : integer := 32);
  port( clk_RO    : in  std_logic;
        rst_in    : in  std_logic;
        clk_in    : in  std_logic;
        tick_1s   : in  std_logic; 
        frq_salida : out std_logic_vector(BITS_DATOS-1 downto 0));
end entity;

architecture rtl of Contador_RO_CDC is

  -- Contador en dominio RO
  signal cuenta_ro    : unsigned(BITS_DATOS-1 downto 0) := (others => '0');
  signal snap_ro      : unsigned(BITS_DATOS-1 downto 0) := (others => '0');

  -- Handshake 
  signal req_tog_clk  : std_logic := '0'; -- clk_in -> clk_RO
  signal ack_tog_ro   : std_logic := '0'; -- clk_RO -> clk_in

  -- Sincronizadores (2 FF)
  signal req_sync1_ro, req_sync2_ro : std_logic := '0';
  signal ack_sync1_clk, ack_sync2_clk : std_logic := '0';

  signal req_seen_ro  : std_logic := '0';
  signal ack_seen_clk : std_logic := '0';

  -- Pasar el snapshot multibit al clk_in: lo muestreamos con 2 FF por bit
  signal snap_sync1_clk, snap_sync2_clk : unsigned(BITS_DATOS-1 downto 0) := (others => '0');

  signal frq_reg_clk  : unsigned(BITS_DATOS-1 downto 0) := (others => '0');

begin

  ---------------------------------------------------------------------------
  -- Dominio clk_in: genera petición (toggle) cada tick_1s
  ---------------------------------------------------------------------------
  process(clk_in, rst_in)
  begin
    if rst_in = '1' then
      req_tog_clk <= '0';
    elsif rising_edge(clk_in) then
      if tick_1s = '1' then
        req_tog_clk <= not req_tog_clk;  -- evento "fin de ventana 1 s"
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Dominio clk_RO: sincroniza req_tog_clk y cuando cambia:
  -- 1) captura cuenta_ro en snap_ro
  -- 2) resetea cuenta_ro
  -- 3) actualiza ack_tog_ro para confirmar
  ---------------------------------------------------------------------------
  process(clk_RO, rst_in)
  begin
    if rst_in = '1' then
      cuenta_ro   <= (others => '0');
      snap_ro     <= (others => '0');
      req_sync1_ro <= '0';
      req_sync2_ro <= '0';
      req_seen_ro  <= '0';
      ack_tog_ro   <= '0';
    elsif rising_edge(clk_RO) then
      -- contador del RO
      cuenta_ro <= cuenta_ro + 1;

      -- sync del toggle de petición
      req_sync1_ro <= req_tog_clk;
      req_sync2_ro <= req_sync1_ro;

      -- detectar cambio de toggle (evento)
      if req_sync2_ro /= req_seen_ro then
        req_seen_ro <= req_sync2_ro;

        -- cerrar ventana: latch + reset
        snap_ro   <= cuenta_ro;
        cuenta_ro <= (others => '0');

        -- ACK: reflejamos el toggle ya visto
        ack_tog_ro <= req_sync2_ro;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Dominio clk_in: sincroniza ack_tog_ro y también "trae" snap_ro (bus estable)
  ---------------------------------------------------------------------------
  process(clk_in, rst_in)
  begin
    if rst_in = '1' then
      ack_sync1_clk <= '0';
      ack_sync2_clk <= '0';
      ack_seen_clk  <= '0';
      snap_sync1_clk <= (others => '0');
      snap_sync2_clk <= (others => '0');
      frq_reg_clk    <= (others => '0');
    elsif rising_edge(clk_in) then
      -- sync del ack toggle
      ack_sync1_clk <= ack_tog_ro;
      ack_sync2_clk <= ack_sync1_clk;

      -- sincronización "suave" del bus snapshot (estable ~1s)
      snap_sync1_clk <= snap_ro;
      snap_sync2_clk <= snap_sync1_clk;

      -- cuando llega ACK nuevo, actualizamos la salida
      if ack_sync2_clk /= ack_seen_clk then
        ack_seen_clk <= ack_sync2_clk;
        frq_reg_clk  <= snap_sync2_clk;
      end if;
    end if;
  end process;

  frq_salida <= std_logic_vector(frq_reg_clk);

end architecture;
