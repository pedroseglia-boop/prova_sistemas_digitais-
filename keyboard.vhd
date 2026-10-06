library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keybord is
   port (
      clk, reset: in std_logic;
      ps2d, ps2c : in std_logic;
      make_code: out std_logic_vector(7 downto 0);
      extend, press: out std_logic;
      done_tick: out std_logic
   );
end keybord;

architecture behavioral of keybord is 
   type stat_type is (idle, extended, released, done);
   signal state_reg, state_next: stat_type;
   signal extend_reg, extend_next: std_logic;
   signal press_reg, press_next: std_logic;
   signal make_code_reg, make_code_next: std_logic_vector(7 downto 0);
   signal rx_done_tick: std_logic;
   signal rx_data: std_logic_vector(7 downto 0);

begin
   my_rx: entity work.ps2rx(arch)
      port map(
         clk => clk, 
         reset => reset,
         ps2d => ps2d,
         ps2c => ps2c, 
         rx_en => '1', 
         rx_idle => open,
         rx_done_tick => rx_done_tick, 
         dout => rx_data
      );

   process(clk, reset)
   begin
      if reset = '1' then
         state_reg <= idle;
         extend_reg <= '0';
         press_reg <= '0';
         make_code_reg <= (others => '0');
      elsif clk'event and clk = '1' then
         state_reg <= state_next;
         extend_reg <= extend_next;
         press_reg <= press_next;
         make_code_reg <= make_code_next;
      end if;
   end process;

   process(state_reg, press_reg, extend_reg, make_code_reg, rx_done_tick, rx_data)
   begin
      state_next <= state_reg;
      press_next <= press_reg;
      extend_next <= extend_reg;
      make_code_next <= make_code_reg;
      done_tick <= '0';
      
      case state_reg is
         when idle =>
            if rx_done_tick = '1' then
               if rx_data = "11100000" then 
                  extend_next <= '1';
                  state_next <= extended;
               else
                  extend_next <= '0';
                  if rx_data = "11110000" then
                     press_next <= '0';
                     state_next <= released;
                  else
                     press_next <= '1';
                     make_code_next <= rx_data;
                     state_next <= done;
                  end if;
               end if;
            end if;

         when extended => 
            if rx_done_tick = '1' then
               if rx_data = "11110000" then
                  press_next <= '0';
                  state_next <= released;
               else
                  press_next <= '1';
                  make_code_next <= rx_data;
                  state_next <= done;
               end if;
            end if;

         when released =>
            if rx_done_tick = '1' then
               make_code_next <= rx_data;
               state_next <= done;
            end if;

         when done =>
            done_tick <= '1';
            state_next <= idle;
      end case;
   end process;

   make_code <= make_code_reg;
   extend <= extend_reg;
   press <= press_reg;

end behavioral;
