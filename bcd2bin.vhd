library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity bcd2bin is
   port(
      clk, reset: in std_logic;
      start: in std_logic;
      bcd2, bcd1, bcd0 : in std_logic_vector(3 downto 0);
      ready: out std_logic;
	done_tick :out std_logic;
	bin : std_logic_vector(15 downto 0)
   );
end bcd2bin;



architecture fsmd_arch of bcd2bin is
   constant C_WIDTH: integer:=4; -- width of the counter
   constant C_INIT: unsigned(C_WIDTH-1 downto 0):="1000";


   type state_type is (idle, add, shift);
   signal state_reg, state_next: state_type;
   signal bcd_reg, bcd_next: unsigned(11 downto 0);
   signal bin_reg, bin_next: unsigned(7 downto 0);
   signal n_reg, n_next: unsigned(C_WIDTH-1 downto 0);
   

	signal bcd2_tmp, bcd1_tmp, bcd0_tmp: unsigned(3 downto 0);

begin

  -- state and data registers
   process(clk,reset)
   begin
      if reset='1' then
         state_reg <= idle;
         bcd_reg <= (others=>'0');
         bin_reg <= (others=>'0');
         n_reg <= (others=>'0');
         
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
         bcd_reg <= bcd_next;
         bin_reg <= bin_next;
         n_reg <= n_next;
         
      end if;
   end process;
   -- combinational circuit     
   process(start,state_reg,bcd_reg,bin_reg,n_reg,
           bcd2, bcd1, bcd0, bcd_tmp, bcd1_tmp, bcd0_tmp)
   begin
      bcd_next <= bcd_reg;
      bin_next <= bin_reg;
      n_next <= n_reg;
      state_next <= state_reg;
      ready <='0';
	done_tick <= '0';

      bcd2_tmp <= bcd_reg(11 downto 8);
      bcd1_tmp <= bcd_reg(7 downto 4);
      bcd0_tmp <= bcd_reg(3 downto 0);


      case state_reg is
         when idle =>
		ready <= '1';

            if start='1' then
               bcd_next <= unsigned(bcd2) & unsigned(bcd1) & unsigned(bcd0);
               bin_next <= (others =>'0');
               n_next <= C_INIT;
               state_next <= shift;
            else
               state_next <= idle;
            end if;


            
         when shift =>
           
            bin_next <= bcd_reg(0) & bin_reg(7 downto 1);
            bcd_next <= '0' & bcd_reg(11 downto 1);
            
            state_next <= sub;
         
       when sub =>
            if bcd2_tmp > 7 then
               bcd_next(11 downto 8) <= bcd2_tmp - 3;
            end if;
            if bcd1_tmp > 7 then
               bcd_next(7 downto 4) <= bcd1_tmp - 3;
            end if;
            if bcd0_tmp > 7 then
               bcd_next(3 downto 0) <= bcd0_tmp - 3;
            end if;
            
         
            n_next <= n_reg - 1;
            
         
            if (n_reg = 1) then
               done_tick  <= '1';
               state_next <= idle;
            else
               state_next <= shift;
            end if;
      end case;
   end process;

   bin <= std_logic_vector(bin_reg);
end fsmd_arch;
