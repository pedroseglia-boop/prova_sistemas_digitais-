library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity bcd2bin is
   port(
      clk, reset: in std_logic;
      start: in std_logic;
      bcd2, bcd1, bcd0 : in std_logic_vector(3 downto 0); --todo bcd se representa com 4 bists
      ready:out std_logic; --flag indica conversor ocioso
	   done_tick :out std_logic; --flag indica conversão terminou
      bin : out  std_logic_vector(7 downto 0) --preciso de 8 bits para representar o valor bcd com 3 digitos
   );
end bcd2bin;



architecture arch of bcd2bin is
   
   type state_type is (idle, op, done);
   signal state_reg, state_next: state_type;
   signal p2s_reg, p2s_next : std_logic_vector (7 downto 0) ;
   signal n_reg, n_next: unsigned(3 downto 0); --tamanho necessario para contar 8 itarações necessarias para a converção bcd -> binario
   signal bcd2_reg, bcd2_next: unsigned(3 downto 0);
   signal bcd1_reg, bcd1_next: unsigned(3 downto 0);
   signal bcd0_reg, bcd0_next: unsigned(3 downto 0);
   signal bcd2_tmp, bcd1_tmp, bcd0_tmp: unsigned(3 downto 0); --onde vou realizar a subtração por 3 conbinacionalmente
   

begin

  -- atualização dos flip-flops e estados com o clock
   process(clk,reset)
   begin
      if reset='1' then
         state_reg <= idle;
         p2s_reg <= (others=>'0');
         n_reg <= (others=>'0');
         bcd2_reg <= (others=>'0');
         bcd1_reg <= (others=>'0');
         bcd0_reg <= (others=>'0'); 
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
         p2s_reg <= p2s_next;
         n_reg <= n_next;
         bcd2_reg <= bcd2_next;
         bcd1_reg <= bcd1_next;
         bcd0_reg <= bcd0_next;   
      end if;
   end process;


   -- logica para proximo estado     
   process(start,bcd2, bcd1, bcd0, state_reg, p2s_reg, n_reg, n_next, bcd0_reg, bcd1_reg,
            bcd2_reg, bcd0_tmp, bcd1_tmp, bcd2_tmp) --pões todas as entradas e sinais
   begin
      --saidas default, saidas padrão
      state_next <= state_reg;
      ready <='0';
	   done_tick <= '0';
      p2s_next <= p2s_reg;
      bcd0_next <= bcd0_reg;
      bcd1_next <= bcd1_reg;
      bcd2_next <= bcd2_reg;
      n_next <= n_reg;

      case state_reg is
         when idle =>
		      ready <= '1';
            if start='1' then
               bcd2_next <= unsigned (bcd2); --recebe bcd da entrada
               bcd1_next <= unsigned (bcd1); --recebe bcd da entrada
               bcd0_next <= unsigned (bcd0); --recebe bcd da entrada
               n_next <= "1000" ;-- numero de iterações 
               p2s_next <= (others=>'0'); --guarda os valor da saida binaria 
               state_next <= op; --proximo estado
            end if;
            
         when op =>
            
         p2s_next <= bcd0_tmp(0) & p2s_reg(7 downto 1);

         bcd0_next <= bcd1_tmp(0) & bcd0_tmp (3 downto 1) ;
         bcd1_next <= bcd2_tmp(0) & bcd1_tmp (3 downto 1) ;
         bcd2_next <= '0' & bcd2_tmp (3 downto 1) ;
         
         n_next <= n_reg - 1 ;
         
         if (n_next = 0) then  
            state_next <=done;
         end if;

       when done =>
       state_next <= idle;
       done_tick <= '1';
      end case;

      end process;

    bcd0_tmp <= bcd0_reg - 3 when bcd0_reg > 7 else bcd0_reg ;
    bcd1_tmp <= bcd1_reg - 3 when bcd1_reg > 7 else bcd1_reg ;
    bcd2_tmp <= bcd2_reg - 3 when bcd2_reg > 7 else bcd2_reg ;
   --configurando valor da saida 

   bin <= std_logic_vector(p2s_reg);

end arch;

