library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity pix_gen_circuit_breakout is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(1 downto 0);
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		video_on: in std_logic;
		-- signal to pause the animation
		graph_still: in std_logic;
		-- signal to reset the bricks
		reset_bricks: in std_logic;
		-- signal will be asserted when all the bricks are cleared
		zero_bricks_tick: out std_logic;
		-- signal will be asserted when the player misses the ball
		miss_tick: out std_logic;
		-- concatenation of all on status signals
		graph_on: out std_logic_vector(2 downto 0);
		-- output color
		graph_rgb: out std_logic_vector(7 downto 0)
		);
end pix_gen_circuit_breakout;

architecture arch of pix_gen_circuit_breakout is
	signal pix_x, pix_y: unsigned(9 downto 0);
	
	-- maximum display area in pixels
	constant MAX_Y: integer := 480;
	constant MAX_X: integer := 640;
	
	-- reference tick
	signal refr_tick: std_logic;
	
	-- width and height of each brick
	constant BRICK_W: integer := 80;
	constant BRICK_H: integer := 40;
	-- create a data type for instantiating arrays
	type array_int6 is array(0 to 5) of integer;
	type array_int3 is array(0 to 2) of integer;
	type array_2d_int is array(0 to 2, 0 to 5) of integer;
	type array_2d_std is array(0 to 2, 0 to 5) of std_logic;
	-- create a constant array of integers holding the left boundary of each brick
	constant BRICK_L: array_int6 := (20, 120, 220, 320, 420, 520);
	-- create a constant array of integers holding the top boundary of each brick
	constant BRICK_T: array_int3 := (40, 100, 160);
	-- create an array containing the colors of the bricks
	constant BRICK_COL: array_2d_int := (
	(224, 28, 3, 224, 28, 3),
	(3, 224, 28, 3, 224, 28),
	(28, 3, 224, 28, 3, 224));
	-- signal for determining whether the current pixel is inside one of the bricks
	signal brick_on: array_2d_std;
	-- 2D array of registers to keep track of the brick status
	signal brick_state_reg, brick_state_next: array_2d_std;
	signal brick_rgb: std_logic_vector(7 downto 0);
	-- signals for keeping track of the row and column index of the brick based on the current pixel
	signal brick_row_reg, brick_row_next: unsigned(2 downto 0);
	signal brick_col_reg, brick_col_next: unsigned(2 downto 0);
	-- signals for brick multiplexing scheme
	signal mplx_row_reg, mplx_row_next: unsigned(2 downto 0);
	signal mplx_col_reg, mplx_col_next: unsigned(2 downto 0);
	
	-- length of the paddle
	constant BAR_SIZE: integer := 80;
	-- top and bottom boundaries of the paddle
	constant BAR_Y_T: integer := 470;
	constant BAR_Y_B: integer := 474;
	-- velocity of the paddle
	constant BAR_V: integer := 4;
	-- left and right boundaries of the paddle
	signal bar_x_l, bar_x_r: unsigned(9 downto 0);
	-- register to store the left boundary (x axis position) of the paddle
	signal bar_x_reg, bar_x_next: unsigned(9 downto 0);
	
	-- size of the ball
	constant BALL_SIZE: integer := 8;
	-- ball velocity
	constant BALL_V_P: unsigned(9 downto 0) := to_unsigned(1, 10);
	constant BALL_V_N: unsigned(9 downto 0) := unsigned(to_signed(-1, 10));
	-- top and bottom boundaries of the ball
	signal ball_y_t, ball_y_b: unsigned(9 downto 0);
	-- left and right boundaries of the ball
	signal ball_x_l, ball_x_r: unsigned(9 downto 0);
	-- register to store the left boundary (x axis position) of the ball
	signal ball_x_reg, ball_x_next: unsigned(9 downto 0);
	-- register to store the top boundary (y axis position) of the ball
	signal ball_y_reg, ball_y_next: unsigned(9 downto 0);
	-- register to store x velocity
	signal x_delta_reg, x_delta_next: unsigned(9 downto 0);
	-- register to store y velocity
	signal y_delta_reg, y_delta_next: unsigned(9 downto 0);
	
	-- pattern ROM for drawing a round ball
	type rom_type is array(0 to 7) of std_logic_vector(7 downto 0);
	-- initialize the ROM using a constant
	constant BALL_ROM: rom_type := (
		"00111100",
		"01111110",
		"11111111",
		"11111111",
		"11111111",
		"11111111",
		"01111110",
		"00111100"
		);
	signal rom_addr: unsigned(2 downto 0);
	signal rom_col: unsigned(2 downto 0);
	signal rom_data: std_logic_vector(7 downto 0);
	signal rom_bit: std_logic;
	
	-- signals to determine whether the current pixel is inside any of the game objects
	signal bar_on, sq_ball_on, rd_ball_on: std_logic;
	
	-- registers to keep track of the number of bricks in play
	signal num_bricks_reg, num_bricks_next: unsigned(4 downto 0);
begin
	-- registers
	process(clk, reset)
	begin
		if (reset = '1') then
			-- initialize the ball on top of the paddle
			ball_x_reg <= to_unsigned(320, 10);
			ball_y_reg <= to_unsigned(BAR_Y_T - BALL_SIZE, 10);
			-- initialize the paddle in the center of the screen
			bar_x_reg <= to_unsigned(320 - BAR_SIZE/2, 10);
			x_delta_reg <= BALL_V_P;
			y_delta_reg <= BALL_V_N;
			brick_row_reg <= (others=>'0');
			brick_col_reg <= (others=>'0');
			mplx_row_reg <= (others=>'0');
			mplx_col_reg <= (others=>'0');
			-- there are 18 bricks at the beginning of a level
			num_bricks_reg <= to_unsigned(18, 5);
			for row in 0 to 2 loop
				for col in 0 to 5 loop
					brick_state_reg(row, col) <= '0';
				end loop;
			end loop;
		elsif (clk'event and clk = '1') then
			ball_x_reg <= ball_x_next;
			ball_y_reg <= ball_y_next;
			bar_x_reg <= bar_x_next;
			x_delta_reg <= x_delta_next;
			y_delta_reg <= y_delta_next;
			brick_row_reg <= brick_row_next;
			brick_col_reg <= brick_col_next;
			mplx_row_reg <= mplx_row_next;
			mplx_col_reg <= mplx_col_next;
			num_bricks_reg <= num_bricks_next;
			for row in 0 to 2 loop
				for col in 0 to 5 loop
					brick_state_reg(row, col) <= brick_state_next(row, col);
				end loop;
			end loop;
		end if;
	end process;
	
	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- create a reference tick that lasts one clock cycle every time the screen is refreshed
	refr_tick <= '1' when (pix_y = 480 and pix_x = 0) else '0';
	
	-- generate a one clock cycle tick if the number of bricks in play is zero
	zero_bricks_tick <= '1' when num_bricks_reg = 0 else '0';
	
	-- check if the current pixel is within the boundaries of a brick
	process(pix_x, pix_y, brick_row_reg, brick_col_reg)
	begin
		brick_row_next <= brick_row_reg;
		brick_col_next <= brick_col_reg;
		-- for loop must be inside a process statement
		for row in 0 to 2 loop
			for col in 0 to 5 loop
				-- if the current pixel is inside one of the brick boundaries ...
				if ((pix_x >= BRICK_L(col)) and (pix_x <= BRICK_L(col) + BRICK_W) and
					 (pix_y >= BRICK_T(row)) and (pix_y <= BRICK_T(row) + BRICK_H)) then
					-- set the brick_on signal to indicate that the pixel is inside a brick
					brick_on(row, col) <= '1';
					-- store the row and column indices of the brick array
					brick_row_next <= to_unsigned(row, 3);
					brick_col_next <= to_unsigned(col, 3);
				else
					brick_on(row, col) <= '0';
				end if;
			end loop;
		end loop;
	end process;
	
	-- retrieve the brick color if the current pixel is inside a brick
	brick_rgb <= std_logic_vector(to_unsigned(BRICK_COL(to_integer(brick_row_reg), to_integer(brick_col_reg)), 8));
	
	-- check if the current pixel is within the boundaries of the paddle
	bar_on <= '1' when (pix_x >= bar_x_l) and (pix_x <= bar_x_r) and 
							 (pix_y >= BAR_Y_T) and (pix_y <= BAR_Y_B) else '0';
	-- update the position of the paddle when the user presses the buttons
	bar_x_l <= bar_x_reg;
	bar_x_r <= bar_x_l + BAR_SIZE - 1;
	process(bar_x_l, bar_x_r, btn, bar_x_reg, refr_tick, graph_still)
	begin
		bar_x_next <= bar_x_reg;
		if (refr_tick = '1') then
			if (graph_still = '1') then
				bar_x_next <= to_unsigned(320 - BAR_SIZE/2, 10);
			-- if the left button is pressed ...
			elsif (btn(1) = '1' and bar_x_l > BAR_V) then
				-- subtract the velocity from the paddle's position to move it left
				bar_x_next <= bar_x_reg - BAR_V;
			-- if the right button is pressed ...
			elsif (btn(0) = '1' and bar_x_r < MAX_X - BAR_V) then
				-- add the velocity to the paddle's position to move it right
				bar_x_next <= bar_x_reg + BAR_V;
			end if;
		end if;
	end process;
	
	-- check if the current pixel is within the boundaries of the square ball
	sq_ball_on <= '1' when (pix_x >= ball_x_l) and (pix_x <= ball_x_r) and 
								  (pix_y >= ball_y_t) and (pix_y <= ball_y_b) else '0';
	-- find the bit in the pattern rom that corresponds with the current pixel
	rom_addr <= pix_y(2 downto 0) - ball_y_t(2 downto 0);
	rom_col <= pix_x(2 downto 0) - ball_x_l(2 downto 0);
	rom_data <= BALL_ROM(to_integer(rom_addr));
	rom_bit <= rom_data(to_integer(rom_col));
	-- check if the current pixel is within the boundaries of the square ball and round ball
	rd_ball_on <= '1' when (rom_bit = '1' and sq_ball_on = '1') else '0';
	-- update the position of the ball
	ball_x_l <= ball_x_reg;
	ball_x_r <= ball_x_l + BALL_SIZE - 1;
	ball_y_t <= ball_y_reg;
	ball_y_b <= ball_y_t + BALL_SIZE - 1;
	
	-- calculate the next position of the ball
	-- the ball will wrap arround to the top if it fall through the bottom of the screen		
	ball_x_next <= to_unsigned(320, 10) when graph_still = '1' else
						(others=>'0') when ball_x_reg > MAX_X else
						to_unsigned(MAX_X, 10) when ball_x_reg < 0 else
						ball_x_reg + x_delta_reg when refr_tick = '1' else
						ball_x_reg;
	ball_y_next <= to_unsigned(BAR_Y_T - BALL_SIZE, 10) when graph_still = '1' else
						(others=>'0') when ball_y_reg > MAX_Y else
						to_unsigned(MAX_Y, 10) when ball_y_reg < 0 else
						ball_y_reg + y_delta_reg when refr_tick = '1' else
						ball_y_reg;
	
	-- update the next state signals for the registers used in the multiplexing scheme
	mplx_col_next <= (others=>'0') when mplx_col_reg = 5 else mplx_col_reg + 1;
	mplx_row_next <= (others=>'0') when (mplx_row_reg = 2 and mplx_col_reg = 5) else
						  mplx_row_reg + 1 when mplx_col_reg = 5 else
						  mplx_row_reg;
	
	-- update the speed and direction of the ball
	-- also update the status of the bricks if there is a collision with the ball
	process(x_delta_reg, y_delta_reg, ball_x_l, ball_x_r, ball_y_t, ball_y_b, brick_state_reg,
	mplx_row_reg, mplx_col_reg, bar_x_l, bar_x_r, reset_bricks, num_bricks_reg)
	begin
		miss_tick <= '0';
		x_delta_next <= x_delta_reg;
		y_delta_next <= y_delta_reg;
		-- if the ball hits the top of the screen ...
		if (ball_y_t < 1) then
			-- reverse y axis direction
			y_delta_next <= BALL_V_P;
		-- if the ball hits the left border of the screen ...
		elsif (ball_x_l < 1) then
			-- reverse the x axis direction
			x_delta_next <= BALL_V_P;
		-- if the ball hits the right border of the screen ...
		elsif (ball_x_r > MAX_X - 1) then
			-- reverse the x axis direction
			x_delta_next <= BALL_V_N;
		-- if the ball only hits the paddle ... 
		elsif (ball_y_b > BAR_Y_T and ball_y_t < BAR_Y_T) then
			if (ball_x_l > bar_x_l and ball_x_r < bar_x_r) then
				-- reverse the y axis direction
				y_delta_next <= BALL_V_N;
			end if;
		-- if the ball hits the bottom of the screen ...
		elsif (ball_y_b > MAX_Y - 1) then
			-- assert the miss_tick signal 
			miss_tick <= '1';
		end if;
		
		-- if the reset_bricks signal is asserted ...
		if (reset_bricks = '1') then
			-- reset the number of bricks to the starting value
			num_bricks_next <= to_unsigned(18, 5);
		else
			-- otherwise maintain the value stored in the register
			num_bricks_next <= num_bricks_reg;
		end if;
		
		for row in 0 to 2 loop
			for col in 0 to 5 loop
				-- if the reset_bricks signal is asserted ...
				if (reset_bricks = '1') then
					-- reset the state of all bricks to show they exist
					brick_state_next(row, col) <= '0';
				else
					-- otherwise maintain the value stored in the registers
					brick_state_next(row, col) <= brick_state_reg(row, col);
				end if;
			end loop;
		end loop;
		
		-- if the current brick being processed by the multiplexing scheme exists ...
		if (brick_state_reg(to_integer(mplx_row_reg), to_integer(mplx_col_reg)) = '0') then
			-- check for collisions with the ball
			-- if there are any collisions, change directions and update the status of the brick
			if ((ball_y_t < BRICK_T(to_integer(mplx_row_reg)) + BRICK_H) and
				 (ball_y_b > BRICK_T(to_integer(mplx_row_reg)) + BRICK_H) and
				 (ball_x_r > BRICK_L(to_integer(mplx_col_reg))) and
				 (ball_x_l < BRICK_L(to_integer(mplx_col_reg)) + BRICK_W)) then
				y_delta_next <= BALL_V_P;
				brick_state_next(to_integer(mplx_row_reg), to_integer(mplx_col_reg)) <= '1';
				num_bricks_next <= num_bricks_reg - 1;
			elsif ((ball_y_b > BRICK_T(to_integer(mplx_row_reg))) and
					 (ball_y_t < BRICK_T(to_integer(mplx_row_reg))) and
					 (ball_x_r > BRICK_L(to_integer(mplx_col_reg))) and
					 (ball_x_l < BRICK_L(to_integer(mplx_col_reg)) + BRICK_W)) then
				y_delta_next <= BALL_V_N;
				brick_state_next(to_integer(mplx_row_reg), to_integer(mplx_col_reg)) <= '1';
				num_bricks_next <= num_bricks_reg - 1;
			elsif ((ball_x_l < BRICK_L(to_integer(mplx_col_reg)) + BRICK_W) and
					 (ball_x_r > BRICK_L(to_integer(mplx_col_reg)) + BRICK_W) and 
					 (ball_y_t < BRICK_T(to_integer(mplx_row_reg)) + BRICK_H) and
					 (ball_y_b > BRICK_T(to_integer(mplx_row_reg))))then
				x_delta_next <= BALL_V_P;
			   brick_state_next(to_integer(mplx_row_reg), to_integer(mplx_col_reg)) <= '1';
				num_bricks_next <= num_bricks_reg - 1;
			elsif ((ball_x_r > BRICK_L(to_integer(mplx_col_reg))) and
					 (ball_x_l < BRICK_L(to_integer(mplx_col_reg))) and
					 (ball_y_t < BRICK_T(to_integer(mplx_row_reg)) + BRICK_H) and
                (ball_y_b > BRICK_T(to_integer(mplx_row_reg))))then
				x_delta_next <= BALL_V_N;
				brick_state_next(to_integer(mplx_row_reg), to_integer(mplx_col_reg)) <= '1';
				num_bricks_next <= num_bricks_reg - 1;
			end if;
		end if;
	end process;
	
	process(video_on, bar_on, rd_ball_on, brick_on, brick_rgb, 
	brick_row_reg, brick_col_reg, brick_state_reg)
	begin
		if (video_on = '0') then
			-- output black color for the borders
		graph_rgb <= (others=>'0');
		else
			-- the following if-else statement determines which objects will be in the foreground
			-- paddle is in the foreground, followed by the ball, then the bricks and finally
			-- the background color
			if (bar_on = '1') then
			graph_rgb <= "11100000";			-- red
			elsif (rd_ball_on = '1') then
			graph_rgb <= "00011000";			-- green
			elsif ((brick_on(to_integer(brick_row_reg), to_integer(brick_col_reg)) = '1') and
					 (brick_state_reg(to_integer(brick_row_reg), to_integer(brick_col_reg)) = '0')) then
			graph_rgb <= brick_rgb;
			else
			graph_rgb <= "11111100";			-- yellow background
			end if;
		end if;
	end process;
	
	-- concatenate the on status signals
	graph_on <= bar_on & rd_ball_on & brick_on(to_integer(brick_row_reg), to_integer(brick_col_reg));
end arch;

