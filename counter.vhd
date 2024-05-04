library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter is
	generic(
		-- number of bits in the counter register
		N: integer := 4;
		-- minimum value the counter can count down to
		MIN: integer := 0;
		-- max value the counter can count up to
		MAX: integer := 9
		);
	port(
		clk, reset: in std_logic;
		-- signal that determines whether the counter value increases or decreases
		-- increases if up_down = '0' and decreases if up_down = '1'
		up_down: in std_logic;
		-- signal that increments or decrements the counter value
		inc_dec: in std_logic;
		-- signal that resets the counter
		clear: in std_logic;
		-- zero_flag is asserted when the counter reaches its minimum value
		-- full_flag is asserted when the counter reaches its maximum value
		zero_flag, full_flag: out std_logic;
		count: out std_logic_vector(N-1 downto 0)
		);
end counter;

architecture arch of counter is
	signal count_reg, count_next: unsigned(N-1 downto 0);
begin
	-- register
	process(clk, reset)
	begin
		if (reset = '1') then
			count_reg <= (others=>'0');
		elsif (clk'event and clk = '1') then
			count_reg <= count_next;
		end if;
	end process;
	
	full_flag <= '1' when count_reg = MAX else '0';
	zero_flag <= '1' when count_reg = MIN else '0';
	
	-- next state logic
	process(count_reg, up_down, inc_dec, clear)
	begin
		-- default is to maintain the value stored in the counter register
		count_next <= count_reg;
		-- if the clear signal is asserted ...
		if (clear = '1') then
			-- if the counter is configured to count up ...
			if (up_down = '0') then
				-- reset the counter value to the minimum
				count_next <= to_unsigned(MIN, N);
			-- if the counter is configured to count down ...
			else
				-- reset the counter value to the maximum
				count_next <= to_unsigned(MAX, N);
			end if;
		else
			-- if the counter is configured to count up ...
			if (up_down = '0') then
				-- if counter reaches its maximum value ...
				if (count_reg = MAX and inc_dec = '1') then
					-- roll over to the minimum
					count_next <= to_unsigned(MIN, N);
				-- otherwise ...
				elsif (inc_dec = '1') then
					-- increment the counter value
					count_next <= count_reg + 1;
				end if;
			-- if the counter is configured to count down ...
			else
				-- if counter reaches its minimum value ...
				if (count_reg = MIN and inc_dec = '1') then
					-- roll over to the maximum
					count_next <= to_unsigned(MAX, N);
				-- otherwise ...
				elsif (inc_dec = '1') then
					-- decrement the counter value
					count_next <= count_reg - 1;
				end if;
			end if;
		end if;
	end process;
	
	-- output logic
	count <= std_logic_vector(count_reg);
end arch;

