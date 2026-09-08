library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity RING_OSCILLATOR is
  generic(NUM_ETAPAS : integer);  --NUMERO DE ETAPAS INVERSORAS. TIENE QUE SER PAR DEBIDO A QUE TENGO UN ENABLE CON UNA NAND
  Port ( enable_in : in std_logic;
         ring_osc_in : in std_logic;
         ring_osc_out : out std_logic);
end RING_OSCILLATOR;

architecture Behavioral of RING_OSCILLATOR is
    signal ring : std_logic_vector(NUM_ETAPAS-1 downto 0) := (others => '0');
    
    --EVITA QUE VIVADO ME OPTIMICE LAS ETAPAS INVERSORAS
    --VIVADO ME QUITARIA TODAS LAS ETAPAS Y ME DEJARIA SOLO UNA
    attribute dont_touch : string;
    attribute dont_touch of ring : signal is "true";
begin
    
    -- Comprobacion de si es PAR o IMPAR, y que sea mayor o igual a 1 el numero de inversores
    assert (NUM_ETAPAS > 1 and NUM_ETAPAS mod 2 /= 0)
    report "ERROR: NUM_ETAPAS debe ser impar y mayor que 1"
    severity FAILURE;

    -------------LOS RETARDOS SON NECESARIOS PARA LA SIMULACION-----------
    -- Primera etapa con enable (NAND)
--    ring(0) <= not (enable_in and ring_osc_in) after 10ns;
    
--    -- Cadena de inversores
--    gen_inv_sim: for i in 1 to NUM_ETAPAS-1 generate
--        ring(i) <= not ring(i-1) after 10 ns;
--    end generate;

--    ring_osc_out <= ring(NUM_ETAPAS-1);



    ---------CÓDIGO PARA LA IMPLEMENTACIÓN---------------------------
    ring(0) <= not (enable_in and ring_osc_in);
    
    -- Cadena de inversores
    gen_inv_imp: for i in 1 to NUM_ETAPAS-1 generate
        ring(i) <= not ring(i-1);
    end generate;

    ring_osc_out <= ring(NUM_ETAPAS-1);
end Behavioral;
