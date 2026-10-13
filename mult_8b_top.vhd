
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_8b_top is
    port(
        clk, reset : in std_logic;
        ps2d, ps2c : in std_logic;
        tx         : out std_logic
    );
end mult_8b_top;

architecture arch of mult_8b_top is

    component uart is
        generic(
            DBIT    : integer := 8;
            SB_TICK : integer := 16;
            FIFO_W  : integer := 4
        );
        port(
            clk, reset : in  std_logic;
            rd_uart    : in  std_logic;
            wr_uart    : in  std_logic;
            dvsr       : in  std_logic_vector(10 downto 0);
            rx         : in  std_logic;
            w_data     : in  std_logic_vector(7 downto 0);
            tx_full    : out std_logic;
            rx_empty   : out std_logic;
            r_data     : out std_logic_vector(7 downto 0);
            tx         : out std_logic
        );
    end component;

    component mult_booth is
        generic(
            DATA_WIDTH  : integer := 8;
            COUNT_WIDTH : integer := 3
        );
        port(
            clk, reset  : in  std_logic;
            m_start     : in  std_logic;
            x_in, y_in  : in  std_logic_vector(7 downto 0);
            m_idle      : out std_logic;
            m_done_tick : out std_logic;
            z_out       : out std_logic_vector(15 downto 0)
        );
    end component;

    component keybord is 
        port(
            clk, reset : in  std_logic;
            ps2d, ps2c : in  std_logic;    
            make_code  : out std_logic_vector(7 downto 0);
            extend     : out std_logic;
            press      : out std_logic;
            done_tick  : out std_logic
        );
    end component;

    component bcd2bin is
        port(
            clk, reset: in  std_logic;
            start     : in  std_logic;
            bcd2, bcd1, bcd0 : in std_logic_vector(3 downto 0);
            ready     : out std_logic;
            done_tick : out std_logic;
            bin       : out std_logic_vector(7 downto 0)
        );
    end component;    

    component bin2bcd is
        port(
            clk, reset: in  std_logic;
            start     : in  std_logic;
            bin       : in  std_logic_vector(15 downto 0);
            ready     : out std_logic;
            done_tick : out std_logic;
            bcd4, bcd3, bcd2, bcd1, bcd0 : out std_logic_vector(3 downto 0)
        );
    end component;            



    -- Sinais do Teclado
    signal make_code   : std_logic_vector(7 downto 0);
    signal extend      : std_logic;
    signal press       : std_logic;
    signal k_done_tick : std_logic;

    -- Sinais da UART 
    constant DVSR : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(324, 11));
    signal wr_uart : std_logic;
    signal w_data  : std_logic_vector(7 downto 0);
    signal tx_full : std_logic;

    -- Sinais do Mult_Booth
    signal m_start     : std_logic;
    signal m_idle      : std_logic;
    signal m_done_tick : std_logic;
    signal z_out       : std_logic_vector(15 downto 0);

    -- Sinais bcd2bin

    signal c_start_bcd2bin     : std_logic;
    signal bcd2_in, bcd1_in, bcd0_in : std_logic_vector(3 downto 0);
    signal ready_bcd2bin       : std_logic;
    signal c_done_tick_bcd2bin : std_logic;
    signal bin_out             : std_logic_vector(7 downto 0);

    -- Sinais bin2bcd

    signal c_start_bin2bcd     : std_logic;
    signal bin_in              : std_logic_vector(15 downto 0);
    signal ready_bin2bcd       : std_logic;
    signal c_done_tick_bin2bcd : std_logic;
    signal bcd4_out, bcd3_out, bcd2_out, bcd1_out, bcd0_out : std_logic_vector(3 downto 0);

    -- Sinais Combinacionais  PS/2
    signal digito_numerico : std_logic;
    signal bcd             : std_logic_vector(3 downto 0);

    -- Estados da Máquina de Estados (FSM)
    type state_type is (
        idle, 
        tecla_igual, tecla1, tecla2, tecla3, tecla_enter, armazena_val,
        start_bcd2bin, wait_bcd2bin,
        start_mult, wait_mult, start_bin2bcd, wait_bin2bcd,
        send_uart_result, send_uart_error
    );

    signal state_reg, state_next : state_type;

    -- Registradores BCD e Sinais de X, Y e Z
    signal x_bcd2_reg, x_bcd1_reg, x_bcd0_reg : std_logic_vector(3 downto 0);
    signal x_bcd2_next, x_bcd1_next, x_bcd0_next : std_logic_vector(3 downto 0);

    signal y_bcd2_reg, y_bcd1_reg, y_bcd0_reg : std_logic_vector(3 downto 0);
    signal y_bcd2_next, y_bcd1_next, y_bcd0_next : std_logic_vector(3 downto 0);

    signal z_bcd4_reg, z_bcd3_reg, z_bcd2_reg, z_bcd1_reg, z_bcd0_reg : std_logic_vector(3 downto 0);
    signal z_bcd4_next, z_bcd3_next, z_bcd2_next, z_bcd1_next, z_bcd0_next : std_logic_vector(3 downto 0);

    signal x_sign_reg, x_sign_next : std_logic;
    signal y_sign_reg, y_sign_next : std_logic;
    signal z_sign_reg, z_sign_next : std_logic;

    signal valid_reg, valid_next   : std_logic;
    signal counter_reg, counter_next : unsigned(1 downto 0);

    -- Registradores temporários de entrada
    signal in_bcd2_reg, in_bcd1_reg, in_bcd0_reg : std_logic_vector(3 downto 0);
    signal in_bcd2_next, in_bcd1_next, in_bcd0_next : std_logic_vector(3 downto 0);
    signal in_sign_reg, in_sign_next : std_logic;

    -- Operandos em Complemento de 2 e Resultado
    signal x_in_reg, x_in_next : std_logic_vector(7 downto 0);
    signal y_in_reg, y_in_next : std_logic_vector(7 downto 0);
    signal z_reg, z_next       : std_logic_vector(15 downto 0);

    -- Controle de Variável ('0' = X, '1' = Y) e contador da UART
    signal var_sel_reg, var_sel_next : std_logic;
    signal char_cnt_reg, char_cnt_next : integer range 0 to 31;

begin



    u_keyboard: keybord
        port map(
            clk       => clk,
            reset     => reset,
            ps2d      => ps2d,
            ps2c      => ps2c,
            make_code => make_code,
            extend    => extend,
            press     => press,
            done_tick => k_done_tick
        );

    u_uart: uart
        generic map(DBIT => 8, SB_TICK => 16, FIFO_W => 4)
        port map(
            clk      => clk,
            reset    => reset,
            rd_uart  => '0',
            wr_uart  => wr_uart,
            dvsr     => DVSR,
            rx       => '1',
            w_data   => w_data,
            tx_full  => tx_full,
            rx_empty => open,
            r_data   => open,
            tx       => tx
        );

    u_mult_booth: mult_booth
        generic map(DATA_WIDTH => 8, COUNT_WIDTH => 3)
        port map(
            clk         => clk,
            reset       => reset,
            m_start     => m_start,
            x_in        => x_in_reg,
            y_in        => y_in_reg,
            m_idle      => m_idle,
            m_done_tick => m_done_tick,
            z_out       => z_out
        );

    u_bcd2bin: bcd2bin
        port map(
            clk       => clk,
            reset     => reset,
            start     => c_start_bcd2bin,
            bcd2      => bcd2_in,
            bcd1      => bcd1_in,
            bcd0      => bcd0_in,
            ready     => ready_bcd2bin,
            done_tick => c_done_tick_bcd2bin,
            bin       => bin_out
        );

    u_bin2bcd: bin2bcd
        port map(
            clk       => clk,
            reset     => reset,
            start     => c_start_bin2bcd,
            bin       => bin_in,
            ready     => ready_bin2bcd,
            done_tick => c_done_tick_bin2bcd,
            bcd4      => bcd4_out,
            bcd3      => bcd3_out,
            bcd2      => bcd2_out,
            bcd1      => bcd1_out,
            bcd0      => bcd0_out
        );


    process(clk, reset)
    begin
        if reset = '1' then
            state_reg      <= idle;
            x_bcd2_reg     <= (others=>'0'); x_bcd1_reg <= (others=>'0'); x_bcd0_reg <= (others=>'0');
            y_bcd2_reg     <= (others=>'0'); y_bcd1_reg <= (others=>'0'); y_bcd0_reg <= (others=>'0');
            z_bcd4_reg     <= (others=>'0'); z_bcd3_reg <= (others=>'0'); z_bcd2_reg <= (others=>'0');
            z_bcd1_reg     <= (others=>'0'); z_bcd0_reg <= (others=>'0');
            x_sign_reg     <= '0'; y_sign_reg <= '0'; z_sign_reg <= '0';
            valid_reg      <= '0';
            counter_reg    <= (others=>'0');
            in_bcd2_reg    <= (others=>'0'); in_bcd1_reg <= (others=>'0'); in_bcd0_reg <= (others=>'0');
            in_sign_reg    <= '0';
            var_sel_reg    <= '0';
            x_in_reg       <= (others=>'0'); y_in_reg <= (others=>'0'); z_reg <= (others=>'0');
            char_cnt_reg   <= 0;
        elsif rising_edge(clk) then
            state_reg      <= state_next;
            x_bcd2_reg     <= x_bcd2_next; x_bcd1_reg <= x_bcd1_next; x_bcd0_reg <= x_bcd0_next;
            y_bcd2_reg     <= y_bcd2_next; y_bcd1_reg <= y_bcd1_next; y_bcd0_reg <= y_bcd0_next;
            z_bcd4_reg     <= z_bcd4_next; z_bcd3_reg <= z_bcd3_next; z_bcd2_reg <= z_bcd2_next;
            z_bcd1_reg     <= z_bcd1_next; z_bcd0_reg <= z_bcd0_next;
            x_sign_reg     <= x_sign_next; y_sign_reg <= y_sign_next; z_sign_reg <= z_sign_next;
            valid_reg      <= valid_next;
            counter_reg    <= counter_next;
            in_bcd2_reg    <= in_bcd2_next; in_bcd1_reg <= in_bcd1_next; in_bcd0_reg <= in_bcd0_next;
            in_sign_reg    <= in_sign_next;
            var_sel_reg    <= var_sel_next;
            x_in_reg       <= x_in_next; y_in_reg <= y_in_next; z_reg <= z_next;
            char_cnt_reg   <= char_cnt_next;
        end if;
    end process;


    process(state_reg, make_code, extend, press, k_done_tick,
            m_idle, m_done_tick, z_out,
            ready_bcd2bin, c_done_tick_bcd2bin, bin_out,
            ready_bin2bcd, c_done_tick_bin2bcd, bcd4_out, bcd3_out, bcd2_out, bcd1_out, bcd0_out,
            x_bcd2_reg, x_bcd1_reg, x_bcd0_reg, y_bcd2_reg, y_bcd1_reg, y_bcd0_reg,
            z_bcd4_reg, z_bcd3_reg, z_bcd2_reg, z_bcd1_reg, z_bcd0_reg,
            x_sign_reg, y_sign_reg, z_sign_reg, valid_reg, counter_reg,
            in_bcd2_reg, in_bcd1_reg, in_bcd0_reg, in_sign_reg, var_sel_reg,
            x_in_reg, y_in_reg, z_reg, char_cnt_reg, tx_full, digito_numerico, bcd)
    begin
        state_next      <= state_reg;
        x_bcd2_next     <= x_bcd2_reg; x_bcd1_next <= x_bcd1_reg; x_bcd0_next <= x_bcd0_reg;
        y_bcd2_next     <= y_bcd2_reg; y_bcd1_next <= y_bcd1_reg; y_bcd0_next <= y_bcd0_reg;
        z_bcd4_next     <= z_bcd4_reg; z_bcd3_next <= z_bcd3_reg; z_bcd2_next <= z_bcd2_reg;
        z_bcd1_next     <= z_bcd1_reg; z_bcd0_next <= z_bcd0_reg;
        x_sign_next     <= x_sign_reg; y_sign_next <= y_sign_reg; z_sign_next <= z_sign_reg;
        valid_next      <= valid_reg;
        counter_next    <= counter_reg;
        in_bcd2_next    <= in_bcd2_reg; in_bcd1_next <= in_bcd1_reg; in_bcd0_next <= in_bcd0_reg;
        in_sign_next    <= in_sign_reg;
        var_sel_next    <= var_sel_reg;
        x_in_next       <= x_in_reg; y_in_next <= y_in_reg; z_next <= z_reg;
        char_cnt_next   <= char_cnt_reg;

        c_start_bcd2bin <= '0';
        bcd2_in <= in_bcd2_reg; bcd1_in <= in_bcd1_reg; bcd0_in <= in_bcd0_reg;
        c_start_bin2bcd <= '0';

        if z_sign_reg = '1' then
            bin_in <= std_logic_vector(-signed(z_reg));
        else
            bin_in <= z_reg;
        end if;

        m_start <= '0';
        wr_uart <= '0';
        w_data  <= x"20";

        case state_reg is

            when idle =>
                counter_next <= "00";
                in_bcd2_next <= (others=>'0'); in_bcd1_next <= (others=>'0'); in_bcd0_next <= (others=>'0');
                in_sign_next <= '0';

                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if make_code = x"22" then      -- Tecla 'x'
                        var_sel_next <= '0';
                        state_next <= tecla_igual;
                    elsif make_code = x"35" then  -- Tecla 'y'
                        var_sel_next <= '1';
                        state_next <= tecla_igual;
                    elsif make_code = x"4D" then  -- Tecla 'p'
                        if m_idle = '1' then
                            state_next <= start_mult;
                        end if;
                    elsif make_code = x"1B" then  -- Tecla 's'
                        if valid_reg = '1' then
                            char_cnt_next <= 0;
                            state_next <= send_uart_result;
                        else
                            if m_idle = '1' then
                                state_next <= start_mult;
                            end if;
                        end if;
                    end if;
                end if;

            when tecla_igual =>
                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if make_code = x"55" then     -- Tecla '='
                        state_next <= tecla1;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when tecla1 =>
                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if make_code = x"55" or make_code = x"79" then -- '+'
                        in_sign_next <= '0';
                    elsif make_code = x"4E" then                   -- '-'
                        in_sign_next <= '1';
                    elsif digito_numerico = '1' then               -- Dígito 1
                        in_bcd2_next <= bcd;
                        counter_next <= "01";
                        state_next <= tecla2;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when tecla2 =>
                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if digito_numerico = '1' then                  -- Dígito 2
                        in_bcd1_next <= bcd;
                        counter_next <= counter_reg + 1;
                        state_next <= tecla3;
                    elsif make_code = x"5A" then                   -- Enter prematuro
                        state_next <= armazena_val;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when tecla3 =>
                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if digito_numerico = '1' then                  -- Dígito 3
                        in_bcd0_next <= bcd;
                        counter_next <= counter_reg + 1;
                        state_next <= tecla_enter;
                    elsif make_code = x"5A" then                   -- Enter prematuro
                        state_next <= armazena_val;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when tecla_enter =>
                if k_done_tick = '1' and press = '1' and extend = '0' then
                    if make_code = x"5A" then                      -- Enter
                        state_next <= armazena_val;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when armazena_val =>
                if counter_reg = "01" then
                    in_bcd0_next <= in_bcd2_reg;
                    in_bcd1_next <= (others=>'0');
                    in_bcd2_next <= (others=>'0');
                elsif counter_reg = "10" then
                    in_bcd0_next <= in_bcd1_reg;
                    in_bcd1_next <= in_bcd2_reg;
                    in_bcd2_next <= (others=>'0');
                end if;
                state_next <= start_bcd2bin;

            when start_bcd2bin =>
                if ready_bcd2bin = '1' then
                    c_start_bcd2bin <= '1';
                    state_next <= wait_bcd2bin;
                end if;

            when wait_bcd2bin =>
                if c_done_tick_bcd2bin = '1' then
                    -- Validação do intervalo (-128 a +127)
                    if (in_sign_reg = '0' and unsigned(bin_out) <= 127) or
                       (in_sign_reg = '1' and unsigned(bin_out) <= 128) then

                        valid_next <= '0';

                        if var_sel_reg = '0' then
                            x_bcd2_next <= in_bcd2_reg; x_bcd1_next <= in_bcd1_reg; x_bcd0_next <= in_bcd0_reg;
                            x_sign_next <= in_sign_reg;
                            if in_sign_reg = '1' then
                                x_in_next <= std_logic_vector(-signed(bin_out));
                            else
                                x_in_next <= bin_out;
                            end if;
                        else
                            y_bcd2_next <= in_bcd2_reg; y_bcd1_next <= in_bcd1_reg; y_bcd0_next <= in_bcd0_reg;
                            y_sign_next <= in_sign_reg;
                            if in_sign_reg = '1' then
                                y_in_next <= std_logic_vector(-signed(bin_out));
                            else
                                y_in_next <= bin_out;
                            end if;
                        end if;
                        state_next <= idle;
                    else
                        char_cnt_next <= 0;
                        state_next <= send_uart_error;
                    end if;
                end if;

            when start_mult =>
                m_start <= '1';
                state_next <= wait_mult;

            when wait_mult =>
                if m_done_tick = '1' then
                    z_next <= z_out;
                    if signed(z_out) < 0 then
                        z_sign_next <= '1';
                    else
                        z_sign_next <= '0';
                    end if;
                    state_next <= start_bin2bcd;
                end if;

            when start_bin2bcd =>
                if ready_bin2bcd = '1' then
                    c_start_bin2bcd <= '1';
                    state_next <= wait_bin2bcd;
                end if;

            when wait_bin2bcd =>
                if c_done_tick_bin2bcd = '1' then
                    z_bcd4_next <= bcd4_out; z_bcd3_next <= bcd3_out; z_bcd2_next <= bcd2_out;
                    z_bcd1_next <= bcd1_out; z_bcd0_next <= bcd0_out;
                    valid_next  <= '1';
                    char_cnt_next <= 0;
                    state_next  <= send_uart_result;
                end if;

            when send_uart_error =>
                if tx_full = '0' then
                    wr_uart <= '1';
                    case char_cnt_reg is
                        when 0 => w_data <= x"77"; -- 'w'
                        when 1 => w_data <= x"72"; -- 'r'
                        when 2 => w_data <= x"6F"; -- 'o'
                        when 3 => w_data <= x"6E"; -- 'n'
                        when 4 => w_data <= x"67"; -- 'g'
                        when 5 => w_data <= x"20"; -- ' '
                        when 6 => 
                            if var_sel_reg = '0' then w_data <= x"78"; -- 'x'
                            else w_data <= x"79";                      -- 'y'
                            end if;
                        when 7 => w_data <= x"0D"; -- '\r'
                        when 8 => w_data <= x"0A"; -- '\n'
                        when others => null;
                    end case;

                    if char_cnt_reg = 8 then
                        state_next <= idle;
                    else
                        char_cnt_next <= char_cnt_reg + 1;
                    end if;
                end if;

            when send_uart_result =>
                if tx_full = '0' then
                    wr_uart <= '1';
                    case char_cnt_reg is
                        when 0  => w_data <= x"78"; -- 'x'
                        when 1  => w_data <= x"3D"; -- '='
                        when 2  => if x_sign_reg = '1' then w_data <= x"2D"; else w_data <= x"2B"; end if;
                        when 3  => w_data <= "0011" & x_bcd2_reg;
                        when 4  => w_data <= "0011" & x_bcd1_reg;
                        when 5  => w_data <= "0011" & x_bcd0_reg;
                        when 6  => w_data <= x"20"; -- ' '
                        when 7  => w_data <= x"79"; -- 'y'
                        when 8  => w_data <= x"3D"; -- '='
                        when 9  => if y_sign_reg = '1' then w_data <= x"2D"; else w_data <= x"2B"; end if;
                        when 10 => w_data <= "0011" & y_bcd2_reg;
                        when 11 => w_data <= "0011" & y_bcd1_reg;
                        when 12 => w_data <= "0011" & y_bcd0_reg;
                        when 13 => w_data <= x"20"; -- ' '
                        when 14 => w_data <= x"78"; -- 'x'
                        when 15 => w_data <= x"2A"; -- '*'
                        when 16 => w_data <= x"79"; -- 'y'
                        when 17 => w_data <= x"3D"; -- '='
                        when 18 => if z_sign_reg = '1' then w_data <= x"2D"; else w_data <= x"2B"; end if;
                        when 19 => w_data <= "0011" & z_bcd4_reg;
                        when 20 => w_data <= "0011" & z_bcd3_reg;
                        when 21 => w_data <= "0011" & z_bcd2_reg;
                        when 22 => w_data <= "0011" & z_bcd1_reg;
                        when 23 => w_data <= "0011" & z_bcd0_reg;
                        when 24 => w_data <= x"0D"; -- '\r'
                        when 25 => w_data <= x"0A"; -- '\n'
                        when others => null;
                    end case;

                    if char_cnt_reg = 25 then
                        state_next <= idle;
                    else
                        char_cnt_next <= char_cnt_reg + 1;
                    end if;
                end if;

        end case;
    end process;



    process(make_code)
    begin
        digito_numerico <= '1';
        case make_code is
            when "00010110" => bcd <= "0001"; -- 1
            when "00011110" => bcd <= "0010"; -- 2
            when "00100110" => bcd <= "0011"; -- 3
            when "00100101" => bcd <= "0100"; -- 4                  
            when "00101110" => bcd <= "0101"; -- 5
            when "00110110" => bcd <= "0110"; -- 6
            when "00111101" => bcd <= "0111"; -- 7
            when "00111110" => bcd <= "1000"; -- 8
            when "01000110" => bcd <= "1001"; -- 9
            when "01000101" => bcd <= "0000"; -- 0
            when others     => digito_numerico <= '0';
        end case;
    end process;

end arch;

```
	
	
		
		
