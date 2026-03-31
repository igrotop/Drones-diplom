LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_unsigned.ALL;

entity indicators_control is
port ( 	d0, d1, d2, d3 : in integer;
			clk: in std_logic;
			rst: in std_logic;
			Q: out std_logic_vector (7 downto 0);
			en: out std_logic_vector (3 downto 0)
);
end indicators_control;

architecture i_c of indicators_control is
	type leds_T is array (0 to 3) of std_logic_vector (7 downto 0);
	signal leds : leds_T;
	
	type d_T is array (0 to 3) of integer;
	signal d: d_T;
begin
	
	read_data: process (clk, rst)
	begin
		if rst = '0' then
			for i in 0 to 3 loop
				leds (i)(7 downto 0) <= (others => '0');
			end loop;
		elsif rising_edge(clk) then
			d(0) <= d0;
			d(1) <= d1;
			d(2) <= d2;
			d(3) <= d3;
			
			for i in 0 to 3 loop
			
				case d(i) is
					when 0 =>						
						leds (i)(7 downto 0) <= "00111111";
					when 1 =>						
						leds (i)(7 downto 0) <= "00000110";
					when 2 =>						
						leds (i)(7 downto 0) <= "01011011";
					when 3 =>						
						leds (i)(7 downto 0) <= "01001111";
					when 4 =>						
						leds (i)(7 downto 0) <= "01100110";
					when 5 =>						
						leds (i)(7 downto 0) <= "01101101";
					when 6 =>						
						leds (i)(7 downto 0) <= "01111101";
					when 7 =>						
						leds (i)(7 downto 0) <= "00000111";
					when 8 =>
						leds (i)(7 downto 0) <= "01111111";
					when 9 =>
						leds (i)(7 downto 0) <= "01101111";
					when others =>						
						leds (i)(7 downto 0) <= "00000000";
				end case;
				
			end loop;
			leds (3)(7) <= '1';
		end if;
	end process;
	
	activate_leds: process (clk, rst)
		variable index: natural := 0;
		constant enable: unsigned(3 downto 0) := "1110";
		variable seg : std_logic_vector(7 downto 0);
	begin
		if rst = '0' then
			Q <= (others => '0');
		elsif rising_edge(clk) then
			seg := leds(index);
			-- Segments a..g: active low on board (common anode), same as not(leds(...)).
			Q(6 downto 0) <= not seg(6 downto 0);
			-- Decimal point after digit 3 (разряд целых вольт): включается только при
			-- активном разряде index=3, без зависимости от устаревшего чтения leds в этом такте.
			if index = 3 then
				Q(7) <= '0';
			else
				Q(7) <= not seg(7);
			end if;
			en <= not(std_logic_vector(rotate_left(enable, index)));
			if index < 3 then
				index := index + 1;
			elsif index = 3 then
				index := 0;
			end if;
		end if;
	end process;

end architecture i_c;
