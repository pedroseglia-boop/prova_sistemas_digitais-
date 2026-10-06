library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kb_monitor is
   port (
      clk, reset: in  std_logic;
      ps2d, ps2c: in  std_logic;
      tx:         out std_logic
   );
end kb_monitor;

architecture arch of kb_monitor is
   constant SP: std_logic_vector(7 downto 0) := "00100000"; -- Espaço em ASCII (x"20")
   
   type statetype is (idle, send_type, send_state, send1, send0, sendb);
   signal state_reg, state_next: statetype;
   signal w_data: std_logic_vector(7 downto 0);
   signal wr_uart: std_logic;
   signal ascii_code: std_logic_vector(7 downto 0);
   signal hex_in: std_logic_vector(3 downto 0);
   
   constant DVSR: std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(324, 11));
   
   signal make_code: std_logic_vector(7 downto 0);
   signal extend, press: std_logic;
   signal done_tick: std_logic;

begin
   --====================================================
   -- Instanciação do Teclado PS2
   --====================================================
   my_keyboard: entity work.keybord(behavioral)
      port map(
         clk       => clk, 
         reset     => reset, 
         ps2d      => ps2d, 
         ps2c      => ps2c,
         make_code => make_code, 
         extend    => extend, 
         press     => press, 
         done_tick => done_tick
      );               

   --====================================================
   -- Instanciação da UART
   --====================================================
   uart_unit: entity work.uart(str_arch)
      generic map (
         DBIT    => 8,   -- # data bits
         SB_TICK => 16,  -- # ticks for stop bits, 16 per bit
         FIFO_W  => 4    -- # FIFO addr bits (depth: 2^FIFO_W)
      )
      port map(
         clk      => clk, 
         reset    => reset, 
         rd_uart  => '0', 
         dvsr     => DVSR,
         wr_uart  => wr_uart, 
         rx       => '1', 
         w_data   => w_data,
         tx_full  => open, 
         rx_empty => open, 
         r_data   => open,
         tx       => tx
      );

   --====================================================
   -- FSM para enviar a sequência ASCII via UART
   --====================================================
   -- Registrador de estado
   process (clk, reset)
   begin
      if reset = '1' then
         state_reg <= idle;
      elsif (clk'event and clk = '1') then
         state_reg <= state_next;
      end if;
   end process;

   -- Lógica de próximo estado
   process(state_reg, done_tick, extend, press, ascii_code)
   begin
      wr_uart    <= '0';
      w_data     <= SP;
      state_next <= state_reg;

      case state_reg is
         when idle =>  -- Inicia quando um scan code é recebido
            if done_tick = '1' then
               state_next <= send_type;
            end if;

         when send_type => -- Envia caractere de Tipo (E ou N)
            if extend = '1' then
               w_data <= "01000101"; -- 'E' em ASCII (x"45")
            else
               w_data <= "01001110"; -- 'N' em ASCII (x"4E")
            end if;
            wr_uart    <= '1';
            state_next <= send_state;

         when send_state => -- Envia caractere de Estado (P ou R)
            if press = '1' then
               w_data <= "01010000"; -- 'P' em ASCII (x"50")
            else
               w_data <= "01010010"; -- 'R' em ASCII (x"52")
            end if;
            wr_uart    <= '1';
            state_next <= send1;

         when send1 => -- Envia o caractere hex superior
            w_data     <= ascii_code;
            wr_uart    <= '1';
            state_next <= send0;

         when send0 => -- Envia o caractere hex inferior
            w_data     <= ascii_code;
            wr_uart    <= '1';
            state_next <= sendb;

         when sendb => -- Envia o caractere de espaço (' ')
            w_data     <= SP;
            wr_uart    <= '1';
            state_next <= idle;
      end case;
   end process;

   --====================================================
   -- Conversão: Scan Code para código ASCII
   --====================================================
   -- Divide o scan code em dois dígitos hexadecimais de 4 bits
   hex_in <= make_code(7 downto 4) when state_reg = send1 else
             make_code(3 downto 0);
             
   -- Converte dígito hexadecimal para código ASCII
   with hex_in select
      ascii_code <=
         "00110000" when "0000",  -- '0'
         "00110001" when "0001",  -- '1'
         "00110010" when "0010",  -- '2'
         "00110011" when "0011",  -- '3'
         "00110100" when "0100",  -- '4'
         "00110101" when "0101",  -- '5'
         "00110110" when "0110",  -- '6'
         "00110111" when "0111",  -- '7'
         "00111000" when "1000",  -- '8'
         "00111001" when "1001",  -- '9'
         "01000001" when "1010",  -- 'A'
         "01000010" when "1011",  -- 'B'
         "01000011" when "1100",  -- 'C'
         "01000100" when "1101",  -- 'D'
         "01000101" when "1110",  -- 'E'
         "01000110" when others;  -- 'F'

end arch;
