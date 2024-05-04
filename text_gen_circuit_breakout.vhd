library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- the text generation circuit generates the text for the game
-- it consists of the following messages:
-- >> display the level (upto 9) using a font size of 32x16
-- >> display the number of balls (upto 9) using a font size of 32x16
-- >> display the name of the game (Breakout) using a font size of 128x64
-- >> display the rules of the game using a font size of 16x8
-- >> display the game over message using a font size of 64x32
entity text_gen_circuit_breakout is
	port(
		clk: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		-- input for the level 
		level: in std_logic_vector(3 downto 0);
		-- input for the number of balls
		balls: in std_logic_vector(3 downto 0);
		-- concatenation of the on status of all messages
		text_on: out std_logic_vector(4 downto 0);
		text_rgb: out std_logic_vector(7 downto 0)
		);
end text_gen_circuit_breakout;

architecture arch of text_gen_circuit_breakout is
	signal pix_x, pix_y: unsigned(9 downto 0);
	-- address to the font ROM which is the concatenation of the character address with the row address
	signal rom_addr: std_logic_vector(10 downto 0);
	-- there are 127 characters in ASCII code which requires a 7-bit character address
	signal char_addr, name_char_addr, level_char_addr, balls_char_addr, 
			 rules_char_addr, go_char_addr: std_logic_vector(6 downto 0);
	-- each character pattern in the ROM has 16 rows which requires a 4-bit row address
	signal row_addr, name_row_addr, level_row_addr, balls_row_addr, 
			 rules_row_addr, go_row_addr: std_logic_vector(3 downto 0);
	-- each character pattern in the ROM has 8 columns which requires a 3-bit bit address
	signal bit_addr, name_bit_addr, level_bit_addr, balls_bit_addr, 
			 rules_bit_addr, go_bit_addr: std_logic_vector(2 downto 0);
	signal font_word: std_logic_vector(7 downto 0);
	signal font_bit: std_logic;
	-- status signals indicating whether the current pixel is part of any message
	signal level_on, balls_on, name_on, rules_on, over_on: std_logic;
	
	-- define a 2D memory unit to store the rules of the game
	-- the message will have 4 rows of text with 32 characters each
	-- this means the ROM size is 128 words with each word being 7 bits wide
	type rule_rom_type is array(0 to 127) of std_logic_vector(6 downto 0);
	-- rules for player 1
	constant RULE_ROM: rule_rom_type := (
		-- row 1
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"1001101",		-- M
		"1101111",		-- o
		"1110110",		-- v
		"1100101",		-- e
		"0100000",		-- 
		"1110000",		-- p
		"1100001",		-- a
		"1100100",		-- d
		"1100100",		-- d
		"1101100",		-- l
		"1100101",		-- e
		"0100000",		-- 
		"1101100",		-- l
		"1100101",		-- e
		"1100110", 		-- f
		"1110100",		-- t
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		-- row 2
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"1110010",		-- r
		"1101001",		-- i
		"1100111",		-- g
		"1101000",		-- h
		"1110100",		-- t
		"0100000",		-- 
		"1110101",		-- u
		"1110011",		-- s
		"1101001",		-- i
		"1101110",		-- n
		"1100111",		-- g
		"0100000",		-- 
		"1100010",		-- b
		"1110101",		-- u
		"1110100",		-- t
		"1110100",		-- t
		"1101111",		-- o
		"1101110",		-- n
		"1110011",		-- s
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		-- row 3
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"1010011",		-- S
		"1010111",		-- W
		"0110001",		-- 1
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"1010011",		-- S
		"1010111",		-- W
		"0110010",		-- 2
		"0101110",		-- .
		"0100000",		-- 
		"1010000",		-- P
		"1110010",		-- r
		"1100101",		-- e
		"1110011",		-- s
		"1110011",		-- s
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		-- row 4
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1111001",		-- y
		"0100000",		-- 
		"1100010",		-- b
		"1110101",		-- u
		"1110100",		-- t
		"1110100",		-- t
		"1101111",		-- o
		"1101110",		-- n
		"0100000",		-- 
		"1110100",		-- t
		"1101111",		-- o
		"0100000",		-- 
		"1110011",		-- s
		"1110100",		-- t
		"1100001",		-- a
		"1110010",		-- r
		"1110100",		-- t
		"0101110",		-- .
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000"		-- 
		);
begin
	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- instantiate the font ROM
	font_unit: entity work.font_rom(arch) port map(clk => clk, addr => rom_addr, data => font_word);
	
	------------------------------------------------------------------------------------
	-- level message:
	-- >> display at the top left of the screen
	-- >> use 32x16 font
	------------------------------------------------------------------------------------
	
	-- Note: 
	-- the screen with a resolution of 480x640 can fit a 15x40 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(4 downto 0) is equivalent to pix_y%32 
	-- pix_y(9 downto 5) is equivalent to pix_y/32 (integer division) up to 31
	-- pix_x(3 downto 0) is equivalent to pix_x%16
	-- pix_x(9 downto 4) is equivalent to pix_x/16 (integer division) up to 63
	
	-- the level should be displayed at the top left of the screen
	-- assert the on status signal for the area where the level will be displayed
	level_on <= '1' when pix_y(9 downto 5) = 0 and 
								pix_x(9 downto 4) >= 0 and pix_x(9 downto 4) < 8 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 1 bit to increase the font size from 16x8 to 32x16
	level_row_addr <= std_logic_vector(pix_y(4 downto 1));
	level_bit_addr <= std_logic_vector(pix_x(3 downto 1));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 4) select level_char_addr <= 
		"1001100" when "000000", 	-- L
		"1100101" when "000001",	-- e
		"1110110" when "000010", 	-- v
		"1100101" when "000011",	-- e
		"1101100" when "000100", 	-- l
		"0111010" when "000101", 	-- :
		"0100000" when "000110", 	--
		"011" & level when "000111", -- 1-digit level
		"0100000" when others;
		
	------------------------------------------------------------------------------------
	-- number of balls message:
	-- >> display at the top right of the screen
	-- >> use 32x16 font
	------------------------------------------------------------------------------------
	-- the number of balls should be displayed at the top right of the screen
	-- assert the on status signal for the area where the number of balls will be displayed
	balls_on <= '1' when pix_y(9 downto 5) = 0 and 
								pix_x(9 downto 4) >= 31 and pix_x(9 downto 4) < 40 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 1 bit to increase the font size from 16x8 to 32x16
	balls_row_addr <= std_logic_vector(pix_y(4 downto 1));
	balls_bit_addr <= std_logic_vector(pix_x(3 downto 1));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 4) select balls_char_addr <= 
		"1000010" when "011111", 	-- B
		"1100001" when "100000", 	-- a
		"1101100" when "100001", 	-- l
		"1101100" when "100010", 	-- l
		"1110011" when "100011", 	-- s
		"0111010" when "100100", 	-- :
		"0100000" when "100101", 	--
		"011" & balls when "100110",
		"0100000" when others;
	
	------------------------------------------------------------------------------------
	-- name message:
	-- >> display at the center of the screen
	-- >> use 128x64 font
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 3.75x10 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(6 downto 0) is equivalent to pix_y%128 
	-- pix_y(9 downto 7) is equivalent to pix_y/128 (integer division) up to 7
	-- pix_x(5 downto 0) is equivalent to pix_x%64
	-- pix_x(9 downto 6) is equivalent to pix_x/64 (integer division) up to 15
	
	-- the name of the game should be displayed in the center of the screen
	-- assert the on status signal for the area where the name will be displayed
	name_on <= '1' when pix_y(9 downto 7) = 1 and
							  pix_x(9 downto 6) >= 1 and pix_x(9 downto 6) < 9 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 3 bits to increase the font size from 16x8 to 128x64
	name_row_addr <= std_logic_vector(pix_y(6 downto 3));
	name_bit_addr <= std_logic_vector(pix_x(5 downto 3));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 6) select name_char_addr <=
		"1000010" when "0001",	-- B
		"1010010" when "0010",  -- R
		"1000101" when "0011", 	-- E
		"1000001" when "0100", 	-- A
		"1001011" when "0101", 	-- K
		"1001111" when "0110", 	-- O
		"1010101" when "0111", 	-- U
		"1010100" when "1000", 	-- T
		"0100000" when others;	--
	
	------------------------------------------------------------------------------------
	-- game over message:
	-- >> display at the bottom of the screen
	-- >> use 64x32 font
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 7.5x20 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(5 downto 0) is equivalent to pix_y%64 
	-- pix_y(9 downto 6) is equivalent to pix_y/64 (integer division) up to 15
	-- pix_x(4 downto 0) is equivalent to pix_x%32
	-- pix_x(9 downto 5) is equivalent to pix_x/32 (integer division) up to 32
	
	-- the game over message should be displayed at the bottom of the screen
	-- assert the on status signal for the area where the game over message will be displayed
	over_on <= '1' when pix_y(9 downto 6) = 4 and
							  pix_x(9 downto 5) >= 5 and pix_x(9 downto 5) < 14 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 2 bits to increase the font size from 16x8 to 64x32
	go_row_addr <= std_logic_vector(pix_y(5 downto 2));
	go_bit_addr <= std_logic_vector(pix_x(4 downto 2));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 5) select go_char_addr <=
		"1000111" when "00101",	-- G
		"1100001" when "00110", -- a
		"1101101" when "00111", -- m
		"1100101" when "01000", -- e
		"0100000" when "01001", --
		"1001111" when "01010", -- O
		"1110110" when "01011", -- v
		"1100101" when "01100", -- e
		"1110010" when "01101", -- r
		"0100000" when others;	--
	
	------------------------------------------------------------------------------------
	-- rules message:
	-- >> display at the center of the screen
	-- >> use 16x8 font
	-- >> the message contains 4 rows of text with 32 characters each
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 30x80 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(3 downto 0) is equivalent to pix_y%16 
	-- pix_y(9 downto 4) is equivalent to pix_y/16 (integer division) up to 63
	-- pix_x(2 downto 0) is equivalent to pix_x%8
	-- pix_x(9 downto 3) is equivalent to pix_x/8 (integer division) up to 127
	
	-- the rules should be displayed in the center of the screen
	-- assert the on status signal for the area where the rules will be displayed
	rules_on <= '1' when pix_y(9 downto 4) >= 20 and pix_y(9 downto 4) < 24 and
								pix_x(9 downto 3) >= 32 and pix_x(9 downto 3) < 64 else '0';
	rules_row_addr <= std_logic_vector(pix_y(3 downto 0));
	rules_bit_addr <= std_logic_vector(pix_x(2 downto 0));
	rules_char_addr <= RULE_ROM(to_integer(pix_y(5 downto 4) & pix_x(7 downto 3)));
	
	
	------------------------------------------------------------------------------------
	-- multiplexer for font ROM addresses and rgb
	------------------------------------------------------------------------------------
	-- the multiplexer circuit determines which message is given priority and placed in the foreground
	process(level_char_addr, level_row_addr, level_bit_addr,
			  balls_char_addr, balls_row_addr, balls_bit_addr,
			  rules_char_addr, rules_row_addr, rules_bit_addr,
			  name_char_addr, name_row_addr, name_bit_addr,
			  go_char_addr, go_row_addr, go_bit_addr,
			  level_on, balls_on, rules_on, name_on,
			  over_on, pix_x, pix_y, font_bit)
	begin
		text_rgb <= "11111100";					-- yellow background
		if level_on = '1' then
			char_addr <= level_char_addr;
			row_addr <= level_row_addr;
			bit_addr <= level_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- level in black
			end if;
		elsif balls_on = '1' then
			char_addr <= balls_char_addr;
			row_addr <= balls_row_addr;
			bit_addr <= balls_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- number of balls in black
			end if;
		elsif rules_on = '1' then
			char_addr <= rules_char_addr;
			row_addr <= rules_row_addr;
			bit_addr <= rules_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- rules in black
			end if;
		elsif over_on = '1' then
			char_addr <= go_char_addr;
			row_addr <= go_row_addr;
			bit_addr <= go_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- game over message in black
			end if;
		elsif name_on = '1' then
			char_addr <= name_char_addr;
			row_addr <= name_row_addr;
			bit_addr <= name_bit_addr;
			if font_bit = '1' then
				text_rgb <= "11100011";			-- name in purple
			end if;
		else
			char_addr <= (others=>'0');
			row_addr <= (others=>'0');
			bit_addr <= (others=>'0');
			text_rgb <= "11111100";
		end if;
	end process;
	
	-- output logic
	-- concatenate the on status signals together
	text_on <= level_on & balls_on & rules_on & name_on & over_on;
	
	------------------------------------------------------------------------------------
	-- font ROM interface
	------------------------------------------------------------------------------------
	-- the address to the font ROM is the concatenation of the character and row addresses
	rom_addr <= char_addr & row_addr;
	-- the bit address is used to retrieve the individual pixel state within a row of the character pattern
	-- take the inverse of the bit address because the pixels on a screen ...
	-- increase from left to right while the data type of the ROM is std_logic_vector ...
	-- where the indices of each bit decrease from left to right
	font_bit <= font_word(to_integer(unsigned(not bit_addr)));
end arch;

