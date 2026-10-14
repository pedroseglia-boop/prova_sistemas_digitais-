library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_8b_top is 
   port(
   clk, reset : in std_logic ;  
   ps2d, ps2c:  in  std_logic; --comunicao teclado
   tx :         out std_logic  --saida uart -> pc

   );

end mult_8b_top;

architecture arch of mult_8b_top is 
--sinais circuitos instanciados

   --keybord  
   signal make_code: std_logic_vector(7 downto 0); --teclado
   signal extend, press: std_logic; --teclado
   signal k_done_tick: std_logic; --teclado

   --uart
   constant DVSR: std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(324, 11)); --uart
   signal wr_uart: std_logic; --uart
   signal w_data: std_logic_vector(7 downto 0); --uart


   --multiplicador
   signal m_start : std_logic;  
   -- x_reg => registrador 
   -- y_reg => registrador 
   --z_reg => registrador
   signal z_out : std_logic_vector (15 downto 0);  -- recebe resultado da multiplicacao e transfere para z_reg
   signal m_idle : std_logic;  
   signal m_done_tick : std_logic;  

   --bcd2bin
   signal c_start_bcd2bin :std_logic;
   signal bcd2_in : std_logic_vector(3 downto 0);
   signal bcd1_in : std_logic_vector(3 downto 0);
   signal bcd0_in : std_logic_vector(3 downto 0);
   signal ready_bcd2bin:std_logic; 
   signal c_done_tick_bcd2bin : std_logic; 
   signal bin_out : std_logic_vector(7 downto 0) ;

   --bin2bcd_16
   signal c_start_16bin2bcd :std_logic;
   signal bin_16in : std_logic_vector(15 downto 0) ;
   signal ready_16bin2bcd : std_logic; 
   signal c_done_tick_16bin2bcd : std_logic;
   signal bcd4_16out : std_logic_vector(3 downto 0);
   signal bcd3_16out : std_logic_vector(3 downto 0);
   signal bcd2_16out : std_logic_vector(3 downto 0);
   signal bcd1_16out : std_logic_vector(3 downto 0);
   signal bcd0_16out : std_logic_vector(3 downto 0);   

--sinais para os circuitos combinacionais

   --circuito combinacional, make_code2bcd
   signal digito_numerico : std_logic; --flag 
   signal bcd : std_logic_vector(3 downto 0); -- armazena conversao 

   signal bcd2ascii: std_logic_vector(4 downto 0); -- 

   signal ascii : std_logic_vector(7 downto 0);

   
--sinais maquina de estados
   --flags ainda sem funcao definida
   signal erro : std_logic; -- indica erro na validacao do valor inserido
   signal x_done_tick : std_logic; --indica que todos os digitos de x foram recebidos   
   signal y_done_tick : std_logic; --indica que todos os digitos de y foram recebidos   


   type state_type is (idle, tecla_igual_x, tecla1_x, tecla2_x, tecla3_x, armazena_x, tecla_enter_x, 
    tecla_igual_y, tecla1_y, tecla2_y, tecla3_y, armazena_y, tecla_enter_y,
    start_bcd2bin, wait_bcd2bin,
    mult, wait_mult,
    view ,print,
    start_bin2bcd, wait_bin2bcd,
    erro_tx_0, erro_tx_1, erro_tx_2, erro_tx_3, erro_tx_4, erro_tx_5, 
    wrong_tx_0, wrong_tx_1, wrong_tx_2, wrong_tx_3, wrong_tx_4, wrong_tx_5, wrong_tx_6, wrong_tx_7, wrong_tx_8) ;
   signal state_reg, state_next : state_type;
   signal x_bcd2_reg, x_bcd1_reg, x_bcd0_reg :std_logic_vector(3 downto 0);
   signal x_bcd2_next, x_bcd1_next, x_bcd0_next :std_logic_vector(3 downto 0);
   signal y_bcd2_reg, y_bcd1_reg, y_bcd0_reg :std_logic_vector(3 downto 0);
   signal y_bcd2_next, y_bcd1_next, y_bcd0_next :std_logic_vector(3 downto 0);
   signal x_sign_reg, x_sign_next : std_logic;
   signal y_sign_reg, y_sign_next : std_logic;
   signal valid_reg, valid_next :std_logic;
   signal counter_reg, counter_next : unsigned(1 downto 0); 
   --guarda o valor de entrada temporariamente para convercao bcd2bin
   signal in_bcd2_reg, in_bcd1_reg, in_bcd0_reg :std_logic_vector(3 downto 0);
   signal in_bcd2_next, in_bcd1_next, in_bcd0_next :std_logic_vector(3 downto 0);
   signal in_sign_reg, in_sign_next : std_logic;
   signal ctrl_sign_reg, ctrl_sign_next : unsigned (1 downto 0); -- para controle, detecta quando repito digito de sinal  

   --guarda operandos da multiplicacao , enquanto aguarda a ordem de multiplicar
   signal x_reg, x_next : std_logic_vector(7 downto 0);
   signal y_reg, y_next :  std_logic_vector(7 downto 0);
   signal z_reg, z_next : std_logic_vector(15 downto 0);
   signal z_sign_reg, z_sign_next : std_logic; 

   signal z_bcd4_reg, z_bcd3_reg, z_bcd2_reg, z_bcd1_reg,z_bcd0_reg : std_logic_vector (3 downto 0);
   signal z_bcd4_next, z_bcd3_next, z_bcd2_next, z_bcd1_next, z_bcd0_next : std_logic_vector (3 downto 0);
   signal print_ctrl_reg, print_ctrl_next: unsigned (4 downto 0);

   signal conv_ctrl_reg, conv_ctrl_next  : std_logic_vector (1 downto 0); -- controle da conversao , indica se estou convertendo x => 01 , y=> 10 ou nenhum deles 00 



begin
-- Instancia Teclado PS2
  
   keyboard_0: entity work.keybord(behavioral)
      port map(
         clk       => clk, --in
         reset     => reset,  --in
         ps2d      => ps2d,  --in
         ps2c      => ps2c, --in
         make_code => make_code, --saida -> signal 
         extend    => extend, --saida -> signal
         press     => press,  --saida -> signal
         done_tick => k_done_tick --saida -> signal
      );               
  
   -- Instancia da UART

   uart_0: entity work.uart(str_arch)
      generic map (
         DBIT    => 8,   -- # data bits
         SB_TICK => 16,  -- # ticks for stop bits, 16 per bit
         FIFO_W  => 5    -- # FIFO addr bits (depth: 2^FIFO_W)
      )
      port map(
         clk      => clk, --in
         reset    => reset, --in
         rd_uart  => '0',  
         dvsr     => DVSR, --in -> constante
         wr_uart  => wr_uart, --in -> signal
         rx       => '1', 
         w_data   => w_data, --in -> signal
         tx_full  => open, 
         rx_empty => open, 
         r_data   => open,
         tx       => tx --saida
      );

   mult_0 : entity work.mult_booth(shift_add_sub_arch)
      -- generic map( ) nao precisa de generic map, valor default = usado nessa aplicacao
      port map (
         clk       => clk,  --in
         reset     => reset, --in 
         m_start => m_start , --in -> signal    ,sinal de entrada que inicia operacao 1 bit
         x_in => x_reg ,    --in -> signal aqui eu ponho o valor reg ou valor next ? 
         y_in => y_reg ,    --in -> signal
         m_idle => m_idle ,  --saida -> signal    ,flag indica sistema ocioso
         m_done_tick => m_done_tick,  --saida -> signal     ,flag indica que operacao terminou
         z_out => z_out  --saida -> signal
      );
   
   bcd2bin_0: entity work.bcd2bin(arch)
      port map (
         clk       => clk, 
         reset     => reset, 
         start => c_start_bcd2bin , --in -> signal
         bcd2 => bcd2_in ,  --in -> signal
         bcd1 => bcd1_in ,  --in -> signal
         bcd0 => bcd0_in, --in -> signal
         ready => ready_bcd2bin, --saida -> signal      ,flag indica conversor ocioso
	      done_tick => c_done_tick_bcd2bin,  --saida -> signal       ,flag indica conversao terminou
         bin => bin_out --saida -> signal

      );
   bin2bcd_0 : entity work.bin2bcd_16b(arch)
   port map(
      clk        => clk,
      reset      => reset,
      start      => c_start_16bin2bcd,
      bin        => bin_16in, 
      ready      => ready_16bin2bcd, 
      done_tick  => c_done_tick_16bin2bcd ,
      bcd4 => bcd4_16out,      
      bcd3 => bcd3_16out,      
      bcd2 => bcd2_16out,
      bcd1 => bcd1_16out,
      bcd0 => bcd0_16out
   );


   process(clk, reset)
      begin 
      if reset = '1' then
         state_reg <= idle;
         x_bcd2_reg <= (others=>'0');
         x_bcd1_reg <= (others=>'0');
         x_bcd0_reg <= (others=>'0');
         y_bcd2_reg <= (others=>'0');
         y_bcd1_reg <= (others=>'0');
         y_bcd0_reg <= (others=>'0');
         x_sign_reg <= '0';
         y_sign_reg <= '0';
         valid_reg <= '0';
         counter_reg <= (others=>'0');
         in_bcd2_reg <= (others=>'0');
         in_bcd1_reg <= (others=>'0');
         in_bcd0_reg <= (others=>'0');
         in_sign_reg <= '0'; 
         conv_ctrl_reg <= (others=>'0');
         x_reg <=  (others=>'0');
         y_reg <= (others=>'0');
         z_reg <= (others=>'0');
         ctrl_sign_reg <= (others=>'0');
         z_bcd4_reg <= (others=>'0');
         z_bcd3_reg <= (others=>'0');
         z_bcd2_reg <= (others=>'0');
         z_bcd1_reg <= (others=>'0');
        z_bcd0_reg <= (others=>'0');
         print_ctrl_reg <= (others=>'0');
   

         
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
         x_bcd2_reg <= x_bcd2_next;
         x_bcd1_reg <= x_bcd1_next;
         x_bcd0_reg <= x_bcd0_next;
         y_bcd2_reg <= y_bcd2_next;
         y_bcd1_reg <= y_bcd1_next;
         y_bcd0_reg <= y_bcd0_next;
         x_sign_reg <= x_sign_next;
         y_sign_reg <= y_sign_next;
         valid_reg <= valid_next;
         counter_reg <= counter_next;
         in_bcd2_reg <= in_bcd2_next;
         in_bcd1_reg <= in_bcd1_next;
         in_bcd0_reg <= in_bcd0_next;         
         in_sign_reg <= in_sign_next; 
         conv_ctrl_reg <= conv_ctrl_next;
         x_reg <= x_next ;
         y_reg <= y_next;
         z_reg <= z_next;
         ctrl_sign_reg <= ctrl_sign_next;
         z_bcd4_reg <= z_bcd4_next;
         z_bcd3_reg <= z_bcd3_next;
         z_bcd2_reg <= z_bcd2_next;
         z_bcd1_reg <= z_bcd1_next;
        z_bcd0_reg <= z_bcd0_next;
         print_ctrl_reg <= print_ctrl_next;

      end if;
   end process;

   --logica proximo estado
   process( make_code, extend, press, k_done_tick, --teclado
            wr_uart, w_data,  --uart
            m_start, m_idle, m_done_tick, x_sign_reg, y_sign_reg, x_reg, y_reg, z_reg, z_out,  -- multiplicacao
            c_start_bcd2bin, bcd2_in, bcd1_in, bcd0_in, ready_bcd2bin, c_done_tick_bcd2bin, bin_out,  --bcd2bin
            c_start_16bin2bcd, bin_16in, ready_16bin2bcd, c_done_tick_16bin2bcd, bcd4_16out, bcd3_16out, bcd2_16out, bcd1_16out, bcd0_16out, --16bin2bcd
            state_reg, 
            x_bcd2_reg, x_bcd1_reg, x_bcd0_reg, y_bcd2_reg, y_bcd1_reg, y_bcd0_reg,  valid_reg, --validacao entrada
            counter_reg, in_bcd2_reg, in_bcd1_reg, in_bcd0_reg, conv_ctrl_reg,  in_sign_reg, ctrl_sign_reg,
            z_bcd4_reg, z_bcd3_reg, z_bcd2_reg, z_bcd1_reg,z_bcd0_reg , print_ctrl_reg,
            erro,  digito_numerico, x_done_tick, y_done_tick, bcd, bcd2ascii, ascii )
   begin
      state_next <= state_reg;--saidas defalt
      x_bcd2_next <= x_bcd2_reg;
      x_bcd1_next <= x_bcd1_reg;
      x_bcd0_next <= x_bcd0_reg;
      y_bcd2_next <= y_bcd2_reg;
      y_bcd1_next <= y_bcd1_reg;
      y_bcd0_next <= y_bcd0_reg;
      x_sign_next <= x_sign_reg;
      y_sign_next <= y_sign_reg;
      valid_next <= valid_reg;
      counter_next <= counter_reg;
      in_bcd2_next <= in_bcd2_reg;
      in_bcd1_next <= in_bcd1_reg;
      in_bcd0_next <= in_bcd0_reg;         
      in_sign_next <= in_sign_reg; 
      x_next <= x_reg;
      y_next <= y_reg;
      z_next <= z_reg;
      conv_ctrl_next <= conv_ctrl_reg;
      ctrl_sign_next <= ctrl_sign_reg;
      z_bcd4_next <= z_bcd4_reg;
      z_bcd3_next <= z_bcd3_reg;
      z_bcd2_next <= z_bcd2_reg;
      z_bcd1_next <= z_bcd1_reg;
      z_bcd0_next <=z_bcd0_reg;
      print_ctrl_next <= print_ctrl_reg ;
      

      c_start_16bin2bcd <= '0';
      bin_16in<=  (others=>'0');

      --zero sinais de entrada para evitar valores intermediarios incorretos que possam se propagar para o cicuito multiplicador
      bcd0_in <=  (others=>'0');
      bcd1_in <=  (others=>'0');
      bcd2_in <=  (others=>'0');
      c_start_bcd2bin <=  '0' ;

      m_start <='0';--INICIA MULTIPLICAcaO

      erro <= '0';   
      wr_uart <= '0';
      w_data <= x"20"; -- ESPAcO em ASCII

      x_done_tick <= '0';
      y_done_tick <= '0';
      
      valid_next <= '1'; -- temporario, apenas para testar cicuito.

      case state_reg is
         when idle =>
         --zero o valor de todos os registradores de uso temporario, seus dados nao tem funcao no estado idle 
         counter_next <= (others=>'0'); --esse é o melhor estado para zerar esse registrador ?
         in_bcd2_next <= (others=>'0');
         in_bcd1_next <= (others=>'0');
         in_bcd0_next <= (others=>'0');         
         in_sign_next <= '0'; 
         conv_ctrl_next <= (others=>'0');
         print_ctrl_next <= (others=>'0');
         ctrl_sign_next <= (others=>'0');
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code = x"22" then --x
                        state_next <= tecla_igual_x;
                     elsif make_code = x"35" then --y
                        state_next <= tecla_igual_y;
                     elsif make_code = x"1b" then --s
                        state_next <= view; 
                     elsif make_code = x"4d" then -- p
                        state_next <= mult;
                     else 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else 
                     erro <= '1';
                     state_next <= erro_tx_0;
                  end if;
               end if;
            end if;



         when tecla_igual_x => 
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code = x"55" then --  '='
                        state_next <= tecla1_x;
                     else -- se nao for '=' => tecla invalida
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;
                  end if;
               end if;
            end if;
         
         when tecla1_x => 
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then                  
                     if make_code = x"55" then -- se digito de signal '+'
                        in_sign_next <= '0';
                        ctrl_sign_next <= ctrl_sign_reg + 1; --  controle, evita repeticao do caracter de signal                     
                        if ctrl_sign_reg  ="01" then --se ctrl_sign_reg  ="01" digitei caracter + pela 2 vez
                           erro <= '1';
                           state_next <= erro_tx_0;
                        end if;                    -- teste primeiro se a entrada é valida e depois atualizo meus registros
                     elsif make_code = x"4e"then -- se digito de signal "-"
                        in_sign_next <= '1'; 
                        ctrl_sign_next <= ctrl_sign_reg  + 1; -- counter faz controle, evita repeticao do caracter de signal                         
                         if ctrl_sign_reg  ="01" then --se ctrl_sign_reg  ="01" digitei caracter - pela 2 vez
                           erro <= '1';
                           state_next <= erro_tx_0;
                        end if;                    -- teste primeiro se a entrada é valida e depois atualizo meus registros
                     elsif digito_numerico = '1' then -- se numero 
                        in_bcd2_next <= bcd ; --origem: combinacional,  make_code => bcd
                        counter_next <= "01"; --seto counter em 1 => 1 bcd armazenado. funcao contagem de digitos armazenados
                        state_next <= tecla2_x;
                     else -- se for letra ou simbolo diferente de + e - => tecla invalida
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;
                  end if;                                          
               end if;
            end if;   

         when tecla2_x =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if digito_numerico = '1' then 
                        in_bcd1_next <= bcd;
                        counter_next <= counter_reg + 1;
                        state_next <= tecla3_x;
                     elsif make_code =x"5a" then -- se "enter"
                        state_next <= armazena_x;
                     else -- se DIFERENTE de numero ou enter => tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;            
                  end if;                           
               end if;
            end if;   

         when tecla3_x =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if digito_numerico = '1' then 
                        in_bcd0_next <= bcd; --bcd menos significativo
                        counter_next <= counter_reg + 1;
                        state_next <= tecla_enter_x;
                     elsif make_code =x"5a" then --se ENTER => proximo estado
                        state_next <= armazena_x;
                     else -- se DIFERENTE de numero ou enter => tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;                           
                  end if;                           
               end if;
            end if;   

         when tecla_enter_x =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code =x"5a" then
                        state_next <= armazena_x;
                     else -- se nao for numero nem enter entao uma tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;            
                  end if;                           
               end if;
            end if;   
         
         
         
         when armazena_x => --  Corrige o valor BCD conforme a quantidade de digitos  
            counter_next <= "00"; --zero contagem           
            conv_ctrl_next <= "01"; --informa  para start_bcd2bin que estou convertendo o valor de x
            x_done_tick <= '1'; -- indica que terminou de receber o valor de x, nao sei se vou usar essa flag
            if counter_reg = "01" then 
                x_bcd2_next <= (others=>'0');  
                x_bcd1_next <= (others=>'0');  
                x_bcd0_next <= in_bcd2_reg ; -- "desloco"  bcd2 => bcd0  
                x_sign_next <= in_sign_reg;
                state_next <= start_bcd2bin; --valor valido => converter
            elsif counter_reg = "10" then
                x_bcd2_next <= (others=>'0');
                x_bcd1_next <= in_bcd2_reg ; --  "desloco"  bcd2 => bcd1
                x_bcd0_next <= in_bcd1_reg ; --  "desloco"  bcd1 => bcd0
                x_sign_next <= in_sign_reg;
                state_next <= start_bcd2bin; --valor valido =>  converter
            elsif counter_reg = "11" then -- se = '3'  verifico -129 < bcd < 128 . obs x > 3 é don't care, elsif é uma redundancia    
               if  in_bcd2_reg = "0000" then --numero da forma 021, ou seja. e menor que 100
                  x_bcd0_next  <= in_bcd0_reg ; 
                  x_bcd1_next <= in_bcd1_reg ;
                  x_bcd2_next <= in_bcd2_reg ;
                  x_sign_next <= in_sign_reg;  
                  state_next <= start_bcd2bin; --valor valido =>  converter               
               elsif in_bcd2_reg = "0001" then --se valor < ou = 199 
                  if in_bcd1_reg = "0001" or in_bcd1_reg = "0000" then --se valor <  ou = 119
                     x_bcd0_next  <= in_bcd0_reg ; 
                     x_bcd1_next <= in_bcd1_reg ;
                     x_bcd2_next <= in_bcd2_reg ;
                     x_sign_next <= in_sign_reg;
                     state_next <= start_bcd2bin; --valor valido => converter                  
                  elsif in_bcd1_reg = "0010" then -- se valor entre 120 <-> 129 
                     if in_bcd0_reg < "1000" and in_sign_reg = '0' then --se valor positivo esta entre 0-7, ou seja 120 <-> 127 
                         x_bcd0_next  <= in_bcd0_reg ; 
                         x_bcd1_next <= in_bcd1_reg ;
                         x_bcd2_next <= in_bcd2_reg ;
                         x_sign_next <= '0';  
                         state_next <= start_bcd2bin; --valor valido => converter
                     elsif in_bcd0_reg < "1001" and in_sign_reg = '1' then --se valor negativo esta entre 0-8 ou seja -120 <-> -128 
                         x_bcd0_next <= in_bcd0_reg ; 
                         x_bcd1_next <= in_bcd1_reg ;
                         x_bcd2_next <= in_bcd2_reg ;
                         x_sign_next <= '1';   
                         state_next <= start_bcd2bin; --valor valido entao vamos converter
                     else -- valor fora do intervalo valido , x < -128 ou x > 127
                        erro <= '1';
                        state_next <= wrong_tx_0;    
                     end if;
                  else -- valor fora do intervalo valido , x < ou  = -130 ou x > ou = 130
                     erro <= '1';
                     state_next <= wrong_tx_0;    
                  end if;
               else -- valor fora do intervalo valido , x < ou  = -200 ou x > ou = 200
                  erro <= '1';
                  state_next <= wrong_tx_0;                
               end if;   
            else
               erro <= '1';
               state_next <= erro_tx_0;                   
            end if; 
 




         when tecla_igual_y => 
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code = x"55" then --  '='
                        state_next <= tecla1_y;
                     else -- se nao for '=' => tecla invalida
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;
                  end if;
               end if;
            end if;
         
         when tecla1_y => 
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code = x"55" then -- se digito de signal '+'
                        if ctrl_sign_reg  ="01" then --se digitei caracter "+" mais de uma vez
                           erro <= '1';
                           state_next <= erro_tx_0;
                        end if;                    -- teste primeiro se a entrada é valida e depois atualizo meus registros
                        in_sign_next <= '0';
                        ctrl_sign_next <= ctrl_sign_reg + 1; --  controle, evita repeticao do caracter de signal
                     elsif make_code = x"4e"then -- se digito de signal "-"
                         if ctrl_sign_reg  ="01" then --signifca que digitei caracter "-" mais de uma vez
                           erro <= '1';
                           state_next <= erro_tx_0;
                        end if;                    -- teste primeiro se a entrada é valida e depois atualizo meus registros
                        in_sign_next <= '1'; 
                        ctrl_sign_next <= ctrl_sign_reg  + 1; -- counter faz controle, evita repeticao do caracter de signal
                     elsif digito_numerico = '1' then -- se numero 
                        in_bcd2_next <= bcd ; --origem: combinacional,  make_code => bcd
                        counter_next <= "01"; --seto counter em 1 => 1 bcd armazenado. funcao contagem de digitos armazenados
                        state_next <= tecla2_y;
                     else -- se for letra ou simbolo diferente de + e - => tecla invalida
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;
                  end if;                                          
               end if;
            end if;   

         when tecla2_y =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if digito_numerico = '1' then 
                        in_bcd1_next <= bcd;
                        counter_next <= counter_reg + 1;
                        state_next <= tecla3_y;
                     elsif make_code =x"5a" then -- se "enter"
                        state_next <= armazena_y;
                     else -- se DIFERENTE de numero ou enter => tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;            
                  end if;                           
               end if;
            end if;   

         when tecla3_y =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if digito_numerico = '1' then 
                        in_bcd0_next <= bcd; --bcd menos significativo
                        counter_next <= counter_reg + 1;
                        state_next <= tecla_enter_y;
                     elsif make_code =x"5a" then --se ENTER => proximo estado
                        state_next <= armazena_y;
                     else -- se DIFERENTE de numero ou enter => tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;                           
                  end if;                           
               end if;
            end if;   

         when tecla_enter_y =>
            if k_done_tick = '1' then 
               if press = '1' then
                  if extend = '0' then
                     if make_code =x"5a" then
                        state_next <= armazena_y;
                     else -- se nao for numero nem enter entao uma tecla invalida 
                        erro <= '1';
                        state_next <= erro_tx_0;
                     end if;
                  else -- se for extendida => tecla invalida
                     erro <= '1';
                     state_next <= erro_tx_0;            
                  end if;                           
               end if;
            end if;   
         
         
         
         when armazena_y => --  Corrige o valor BCD conforme a quantidade de digitos  
            counter_next <= "00"; --zero contagem           
            conv_ctrl_next <= "10"; --informa  para start_bcd2bin que estou convertendo o valor de y
            y_done_tick <= '1'; -- indica que terminou de receber o valor de y, nao sei se vou usar essa flag
            if counter_reg = "01" then 
                y_bcd2_next <= (others=>'0');  
                y_bcd1_next <= (others=>'0');              
                y_bcd0_next <= in_bcd2_reg ; -- "desloco"  bcd2 => bcd0  
                y_sign_next <= in_sign_reg;
                state_next <= start_bcd2bin; --valor valido => converter
            elsif counter_reg = "10" then
                y_bcd2_next <= (others=>'0');                  
                y_bcd1_next <= in_bcd2_reg ; --  "desloco"  bcd2 => bcd1                
                y_bcd0_next <= in_bcd1_reg ; --  "desloco"  bcd1 => bcd0
                y_sign_next <= in_sign_reg;
                state_next <= start_bcd2bin; --valor valido =>  converter
            elsif counter_reg = "11" then -- se = '3'  verifico -129 < bcd < 128 . obs x > 3 é don't care, elsif é uma redundancia    
               if  in_bcd2_reg = "0000" then --numero da forma 021, ou seja. e menor que 100
                  y_bcd0_next  <= in_bcd0_reg ; 
                  y_bcd1_next <= in_bcd1_reg ;
                  y_bcd2_next <= in_bcd2_reg ;
                  y_sign_next <= in_sign_reg;  
                  state_next <= start_bcd2bin; --valor valido =>  converter               
               elsif in_bcd2_reg = "0001" then --se valor < ou = 199 
                  if in_bcd1_reg = "0001" or in_bcd1_reg = "0000" then --se valor <  ou = 119
                     y_bcd0_next  <= in_bcd0_reg ; 
                     y_bcd1_next <= in_bcd1_reg ;
                     y_bcd2_next <= in_bcd2_reg ;
                     y_sign_next <= in_sign_reg;
                     state_next <= start_bcd2bin; --valor valido => converter                  
                  elsif in_bcd1_reg = "0010" then -- se valor entre 120 <-> 129 
                     if in_bcd0_reg < "1000" and in_sign_reg = '0' then --se valor positivo esta entre 0-7, ou seja 120 <-> 127 
                         y_bcd0_next  <= in_bcd0_reg ; 
                         y_bcd1_next <= in_bcd1_reg ;
                         y_bcd2_next <= in_bcd2_reg ;
                         y_sign_next <= '0';  
                         state_next <= start_bcd2bin; --valor valido => converter
                     elsif in_bcd0_reg < "1001" and in_sign_reg = '1' then --se valor negativo esta entre 0-8 ou seja -120 <-> -128 
                         y_bcd0_next <= in_bcd0_reg ; 
                         y_bcd1_next <= in_bcd1_reg ;
                         y_bcd2_next <= in_bcd2_reg ;
                         y_sign_next <= '1';   
                         state_next <= start_bcd2bin; --valor valido entao vamos converter
                     else -- valor fora do intervalo valido , y < -128 ou y > 127
                        erro <= '1';
                        state_next <= wrong_tx_0;    
                     end if;
                  else -- valor fora do intervalo valido , y < ou  = -130 ou y > ou = 130
                     erro <= '1';
                     state_next <= wrong_tx_0;    
                  end if;
               else -- valor fora do intervalo valido , y < ou  = -200 ou y > ou = 200
                  erro <= '1';
                  state_next <= wrong_tx_0;                
               end if;   
            else
               erro <= '1';
               state_next <= erro_tx_0;                   
            end if; 


         when start_bcd2bin => -- pergunta : conversor ocioso?  
            if ready_bcd2bin = '1' then -- espera confirmacao e inicia conversao
               state_next <= wait_bcd2bin; 
               if conv_ctrl_reg ="01"  then -- se estamos convertando valor de x => 01 
                  bcd2_in <= x_bcd2_reg;
                  bcd1_in <= x_bcd1_reg;
                  bcd0_in <= x_bcd0_reg;
                  c_start_bcd2bin <= '1';
            
               elsif conv_ctrl_reg ="10" then -- se estamos convertando valor de y => 10 
                  bcd2_in <= y_bcd2_reg;
                  bcd1_in <= y_bcd1_reg;
                  bcd0_in <= y_bcd0_reg;
                  c_start_bcd2bin <= '1';
               end if;
            end if;   

      when wait_bcd2bin => -- espera a conversao terminar
         if c_done_tick_bcd2bin = '1' then
                if conv_ctrl_reg ="01" then -- se estamos convertando valor de x => 01 e bcd2bin terminou  convercao entao
                   conv_ctrl_next <= "00"; --Zero para evitar lixo
                   state_next <= idle; --volto para idle a espera de novo comando
                   if x_sign_reg = '1' then --se valor for negativo
                      x_next  <= std_logic_vector( unsigned(not bin_out) + 1) ; --fa   o complemento de 2 e guardo
                   else --se valor for positivo
                      x_next <= bin_out; --apenas guardo
                   end if; 
                elsif conv_ctrl_reg ="10" then -- se estamos convertando valor de y => 10 e bcd2bin terminou  convercao entao
                   conv_ctrl_next <= "00";  --Zero para evitar lixo
                   state_next <= idle; --volto para idle a espera de novo comando
                   if y_sign_reg = '1' then --se valor for negativo
                      y_next  <= std_logic_vector( unsigned(not bin_out) + 1) ;  --fa   o complemento de 2 e guardo
                   else --se valor for positivo
                      y_next <= bin_out; --apenas guardo
                   end if;             
                end if; --casos onde conv_ctrl_reg = 11 ou 00 => don't care.
        end if;
      
      when mult => 
         if m_idle = '1' then 
            m_start <= '1';
            state_next <= wait_mult;
            end if;
         
      when wait_mult =>
         if m_done_tick = '1' then
            state_next <= print; 
            z_sign_next <= z_out(15);
            if z_out(15) = '1' then
            z_next <= std_logic_vector(unsigned( not (z_reg)) + 1);
            else
               z_next <= z_reg;
            end if;
         end if;

      when view =>
         if valid_reg = '1' then
            state_next <= print;            
         else 
            state_next <= mult;
         end if;

      when start_bin2bcd => --conversor ocioso ?
         if ready_16bin2bcd = '1' then-- espera confirmacao         
            c_start_16bin2bcd <= '1'; -- inicia conversao
            bin_16in <= z_reg;
            state_next <= wait_bin2bcd;             
         end if;

      when wait_bin2bcd =>
         if c_done_tick_16bin2bcd = '1' then
            z_bcd0_next <= bcd0_16out;      
            z_bcd1_next <= bcd1_16out;
            z_bcd2_next <= bcd2_16out;
            z_bcd3_next <= bcd3_16out;
            z_bcd4_next <= bcd4_16out;                        
            state_next <= print;
         
         end if;            
      
      when print =>
         print_ctrl_next <= print_ctrl_reg + 1;
         w_data <= ascii;
         wr_uart <= '1';                
         if print_ctrl_reg = 25 then
            w_data <= x"0d";
            wr_uart <= '1';                            
         elsif print_ctrl_reg = 26 then 
            w_data <= x"0a";
            wr_uart <= '1'; 
            state_next <= idle; --salto de linha                                  
         end if;
            
      when erro_tx_0=> --obs : fifo 32 posicoes, tx_full = '1' n�o acontece
         w_data <= x"45"; --E
         wr_uart <= '1';
         state_next <= erro_tx_1;
      when erro_tx_1=>
         state_next <= erro_tx_2;
         w_data <= x"52";--R
         wr_uart <= '1';
      when erro_tx_2=>
         state_next <= erro_tx_3;
         w_data <= x"52";--R
         wr_uart <= '1';
      when erro_tx_3=>
         w_data <= x"4f";--O
         wr_uart <= '1';      
         state_next <= erro_tx_4;
      when erro_tx_4=>
         w_data <= x"0a"; --Line Feed, pula de linha
         wr_uart <= '1';
         state_next <= erro_tx_5;               
      when erro_tx_5=>
         w_data <= x"0d"; --Line Feed, pula de linha
         wr_uart <= '1';      
         state_next <= idle;
      
      

      when wrong_tx_0=> --obs : fifo 32 posicoes, tx_full = '1' n�o acontece
         w_data <= x"77"; --w
         wr_uart <= '1';
         state_next <= wrong_tx_1;
      when wrong_tx_1=>
         state_next <= wrong_tx_2;
         w_data <= x"72";--r
         wr_uart <= '1';
      when wrong_tx_2=>
         state_next <= wrong_tx_3;
         w_data <= x"6f";--o
         wr_uart <= '1';
      when wrong_tx_3=>
         w_data <= x"6e";--n
         wr_uart <= '1';      
         state_next <= wrong_tx_4;
      when wrong_tx_4=>
         w_data <= x"67"; --g
         wr_uart <= '1';      
         state_next <= wrong_tx_5;
      when wrong_tx_5=> 
         w_data <= x"20"; --espaco
         wr_uart <= '1';
         state_next <= wrong_tx_6;
      when wrong_tx_6=>
         state_next <= wrong_tx_7;
         if conv_ctrl_reg = "01" then --valor de  x fora da faixa
            w_data <= x"78";-- x
            wr_uart <= '1';      
         elsif conv_ctrl_reg = "10" then --valor de  y fora da faixa
            w_data <= x"79";-- y
            wr_uart <= '1';          
         end if;
      when wrong_tx_7=> 
         w_data <= x"0a"; --espaco
         wr_uart <= '1';
         state_next <= wrong_tx_8;   
      when wrong_tx_8=> 
         w_data <= x"0d"; --inicio linha
         wr_uart <= '1';
         state_next <= idle;

      
      
        end case;

   end process;


   --circuitos combinaicinais conversao make_code2bcd
   process(make_code)
   begin
      bcd  <= (others=>'0'); -- valor defalt, impede a criação de memoria
      --nao preciso me preucupar com k_done_tick pois make_code sempre recebe um valor valido, ele nao oscila com valores intermediarios lixo ante de receber valor final
      digito_numerico <= '1';
      case make_code is
         when "00010110" => bcd <= "0001"; --1
         when "00011110" => bcd <= "0010"; --2
         when "00100110" => bcd <= "0011"; --3
         when "00100101" => bcd <= "0100"; --4                 
         when "00101110" => bcd <= "0101"; --5
         when "00110110" => bcd <= "0110"; --6
         when "00111101" => bcd <= "0111"; --7
         when "00111110" => bcd <= "1000"; --8
         when "01000110" => bcd <= "1001"; --9
         when "01000101" => bcd <= "0000"; --0
         when others => digito_numerico <= '0'; 
      end case;
   end process;
   
   --circuito combinacinal bcd para ascii
   process(print_ctrl_reg, x_sign_reg,  x_bcd0_reg,  x_bcd1_reg,  x_bcd2_reg, y_sign_reg,  y_bcd0_reg,  y_bcd1_reg,  y_bcd2_reg, 
            z_sign_reg,  z_bcd0_reg,  z_bcd1_reg,  z_bcd2_reg, z_bcd3_reg,  z_bcd4_reg  )
   begin
      bcd2ascii <= "00000"; -- espaco
      
      case print_ctrl_reg is
         when "00000" => bcd2ascii <= "10001"; -- x
         when "00001" => bcd2ascii <= "10010";-- =         
         when "00010" => bcd2ascii  <= "1" & x_sign_reg & "000"; -- sinal de x
         when "00011" => bcd2ascii <= "0" & x_bcd0_reg; --
         when "00100" => bcd2ascii <= "0" & x_bcd1_reg; --                 
         when "00101" => bcd2ascii <= "0" & x_bcd2_reg; --
         when "00110" => bcd2ascii <= "10011"; -- espaco
         when "00111" => bcd2ascii <= "10100"; -- y
         when "01000" => bcd2ascii <= "10010"; -- =
         when "01001" => bcd2ascii <= "1" & y_sign_reg & "000";-- sinal de y
         when "01010" => bcd2ascii <= "0" & y_bcd0_reg; -- 
         when "01011" => bcd2ascii <= "0" & y_bcd1_reg; -- 
         when "01100" => bcd2ascii <= "0" & y_bcd2_reg; -- 
         when "01101" => bcd2ascii <= "10011"; -- espaco
         when "01110" => bcd2ascii <= "10001";-- x
         when "01111" => bcd2ascii <= "10111"; -- *
         when "10000" => bcd2ascii <= "10100";-- y
         when "10001" => bcd2ascii <= "10010"; -- =
         when "10010" => bcd2ascii <= "1" & z_sign_reg & "000"; --         
         when "10011" => bcd2ascii <= "0" & z_bcd4_reg; --
         when "10100" => bcd2ascii <= "0" & z_bcd3_reg; --
         when "10101" => bcd2ascii <= "0" & z_bcd2_reg; --
         when "10110" => bcd2ascii <= "0" & z_bcd1_reg; --
         when others  => bcd2ascii <= "0" & z_bcd0_reg; -- 
      end case;
      end process;

process(bcd2ascii, x_bcd0_reg, x_bcd1_reg, x_bcd2_reg, y_bcd0_reg, y_bcd1_reg, y_bcd2_reg, z_bcd0_reg, z_bcd1_reg, z_bcd2_reg, z_bcd3_reg, z_bcd4_reg )
   begin 
    ascii <= x"20"; --valor default
      case bcd2ascii is
         when "00000" => ascii <= x"30"; -- 0
         when "00001" => ascii <= x"31"; -- 1
         when "00010" => ascii <= x"32"; -- 2
         when "00011" => ascii <= x"33"; -- 3
         when "00100" => ascii <= x"34"; -- 4
         when "00101" => ascii <= x"35"; -- 5
         when "00110" => ascii <= x"36"; -- 6
         when "00111" => ascii <= x"37"; -- 7
         when "01000" => ascii <= x"38"; -- 8
         when "01001" => ascii <= x"39"; -- 9
         when "10001" => ascii <= x"78"; -- x
         when "10010" => ascii <= x"3d"; -- =
         when "10011" => ascii <= x"20"; -- espa�o
         when "10100" => ascii <= x"79"; -- y
         when "10000" => ascii <= x"2b"; -- +
         when "11000" => ascii <= x"2d"; -- -
         when others => ascii <= x"2a"; -- *
      end case;


   end process;
   end arch;

