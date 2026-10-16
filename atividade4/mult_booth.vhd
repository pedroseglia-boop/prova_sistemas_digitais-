----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    15:47:04 21/09/2026
-- Design Name:
-- Module Name:    
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity mult_booth is
   generic(DATA_WIDTH: integer :=8;
            COUNT_WIDTH: integer :=3); 
   
 --defult 8 bits para aproveitar test bent do projeto 3
 
      port(
      clk, reset: in std_logic;
      m_start: in std_logic; --sinal de entrada que inicia operação 1 bit
      x_in, y_in: in std_logic_vector(DATA_WIDTH - 1 downto 0);
      m_idle: out std_logic;--flag indica sistema ocioso
      m_done_tick: out std_logic; --flag indica que operação terminou
      z_out: out std_logic_vector(2*DATA_WIDTH - 1 downto 0)
   );
end  mult_booth;


architecture shift_add_sub_arch of mult_booth is
   type state_type is (idle, shift,  done);
   signal state_reg, state_next: state_type;
   signal x_ext_reg, x_ext_next: unsigned(DATA_WIDTH downto 0); --ele tem 1 bit a mais que o dado original por isso ext no nome
   signal xn_ext_reg, xn_ext_next: unsigned(DATA_WIDTH downto 0); --ele tem 1 bit a mais que o dado original por isso ext no nome
   signal p_reg, p_next: unsigned(2*DATA_WIDTH+1 downto 0); 
   signal counter_reg, counter_next : unsigned (COUNT_WIDTH-1 downto 0 );
   signal xn_in : unsigned(DATA_WIDTH-1 downto 0);
   signal sum : unsigned (DATA_WIDTH downto 0);
   
begin
   -- atualiza registros ou atribui o valor de set
   process(clk,reset)
   begin
      if reset='1' then
         state_reg <= idle;
         x_ext_reg <= (others=>'0');
         xn_ext_reg <= (others=>'0');
         p_reg <= (others=>'0');
         counter_reg <= (others=>'0');
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
         x_ext_reg <= x_ext_next;
         xn_ext_reg <= xn_ext_next;
         p_reg <= p_next;
         counter_reg <= counter_next;
            
      end if;
   end process;
   
   process(p_reg, x_ext_reg,xn_ext_reg )
   begin
          case p_reg (1 downto 0) is 
               when  "01" =>
                   sum <= p_reg(2*DATA_WIDTH+1 downto DATA_WIDTH+1)+x_ext_reg ;
               when "10" =>
                   sum <= p_reg(2*DATA_WIDTH+1 downto DATA_WIDTH+1)+xn_ext_reg ;
               when others =>
                   sum <= p_reg(2*DATA_WIDTH+1 downto DATA_WIDTH+1);
          end case;           
   end process;                

   
   

   --logica do proximo estado--
    
   process(m_start, x_in, y_in, xn_in,state_reg,x_ext_reg,
        xn_ext_reg,p_reg,counter_reg,sum)
   begin
      state_next <= state_reg;
      x_ext_next <= x_ext_reg;
      xn_ext_next <= xn_ext_reg;
      p_next <= p_reg;
      counter_next <= counter_reg;
      m_idle <= '0';
      m_done_tick <='0';
      case state_reg is
      
         when idle =>
               if m_start='1' then
                  x_ext_next <= unsigned((x_in(DATA_WIDTH-1)& x_in));
                  xn_ext_next <= (xn_in(DATA_WIDTH-1)& xn_in);
                  counter_next <= (others => '0');
                  p_next(0) <= '0';
                  p_next(DATA_WIDTH downto 1) <=  unsigned(y_in)  ;
                  p_next(2*DATA_WIDTH+1 downto DATA_WIDTH+1) <= (others => '0')  ;
                  state_next <= shift;
               end if;
               m_idle <='1';

         when shift =>
            counter_next <= counter_reg+1;            
            p_next <= sum(DATA_WIDTH)& sum &  p_reg(DATA_WIDTH downto 1) ; 
            if counter_reg = (DATA_WIDTH-1) then
               state_next <= done;
            
            end if;
            

         when done =>   
            m_done_tick <= '1';
            state_next <= idle;      
      end case;
   end process;

--combinacio9nal--

    z_out <= std_logic_vector(p_reg(2*DATA_WIDTH downto 1));
    xn_in <= unsigned(not x_in) + 1;


end shift_add_sub_arch;





























