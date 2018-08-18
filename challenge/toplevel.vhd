-- Filename: toplevel.vhd
-- Author 1: Ryan Lui
-- Author 1 Student #: 301251951
-- Author 2: Greyson Wang
-- Author 2 Student #: 301249759
-- Group Number: 27
-- Lab Section
-- Lab: 6
-- Task Completed: All.
-- Date: 2017-03-14
-- Description: A 4-core RC4 decryptor. Displays successful message on LCD.
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity toplevel is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 HEX5, HEX4, HEX3, HEX2, HEX1, HEX0: out std_logic_vector(6 downto 0);
		 LCD_RW : out std_logic; -- Determines whether we want to read from/write to LCD.
            LCD_EN : out std_logic; -- LCD's ENable, accepts data on LCD_DATA on falling edge
            LCD_RS : out std_logic; -- Determines if we are sending an instruction/data to LCD.
            LCD_ON : out std_logic; -- Determines if LCD display is on or not.
            LCD_BLON : out std_logic; -- Determines if LCD backlight is on or not. 
            LCD_DATA : out std_logic_vector(7 downto 0);
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0));  -- red lights
end toplevel;

-- Architecture part of the description

architecture rtl of toplevel is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
	component digit7seg is
		PORT(
			digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
			seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
		);
	end component;
	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	component decryption_core is
		generic(
			rangeStart: in unsigned(23 downto 0); -- Secret key range.
			rangeStop: in unsigned(23 downto 0) -- Secret key range, self explanatory.
		);
		port(
			clock : in  std_logic;  -- Clock pin
			secret: out unsigned(23 downto 0); -- The secret that 
			start : in  std_logic; -- Start/Reset
			stop: in std_logic; -- Stop signal, brings circuit to completion state immediately.
			decrypted: out std_logic; -- Done signal
			failed: out std_logic; -- Error signal.			
			decryptedAddress: in std_logic_vector(4 downto 0);
			decryptedQ: out std_logic_vector(7 downto 0)
		);
	end component;
	
	type state_type is (
		decryptStart,
		decryptStall,
		resetLCD0,
		resetLCD1,
		resetLCD2,
		resetLCD3,
		resetLCD4,
		resetLCD5,	
		LCDStall,
		readCore1,		
		readCore2,		
		readCore3,		
		readCore4,
		done_state
		);
		
	signal PS, NS: state_type; -- Present and Next State, respectively
	
	-- Self explanatory signals feeding to the 4 decryption cores.
	signal start: std_logic_vector(1 to 4);
	signal stop: std_logic_vector(1 to 4);
	signal done: std_logic_vector(1 to 4);
	signal failed: std_logic_vector(1 to 4); -- Not being used right now.
	
	signal secret_core1, secret_core2, secret_core3, secret_core4: unsigned(23 downto 0); -- The secret key from each decryption core.
	
	signal dQ_core1, dQ_core2, dQ_core3, dQ_core4: std_logic_vector(7 downto 0); -- The dQ from each decryption core. Will use to check values later.
	
	signal keyReg: unsigned(23 downto 0);
	signal dAddress: unsigned(4 downto 0);
	signal addressInit, addressLoad : std_logic; -- Reset and enable for dAddress.
	
	signal lcd_clock: std_logic; -- Tristate for driving a signal on the LCD enable.
	signal slow_clock: std_logic; -- Selects which clock to use: 0 for 50MHz, 1 for divided clock.
	signal slowCounter: unsigned(14 downto 0); -- Clock divider
	signal main_clock: std_logic; -- CLock splitter
	
	signal LCDCounter: unsigned(7 downto 0) := x"00"; -- Used to keep track of where we are in the LCD, so we can print spaces when we are off the screen.
	signal LCDCounterInit, LCDCounterLoad: std_logic; -- Reset and enable for the aforementioned counter.
	
	begin
	
	LCD_BLON <= '1';
    LCD_ON <= '1';
    LCD_RW <= '0';
		
		
		decryptionCore1: decryption_core
			generic map(
				rangeStart => x"000000",
				rangeStop => x"0FFFFF")
			port map(
				clock => main_clock,
				secret => secret_core1,
				start => start(1),
				stop => done(2) or done(3) or done(4),
				decrypted => done(1),
				failed => failed(1),				
				decryptedAddress => std_logic_vector(dAddress),
				decryptedQ => dQ_core1
			);
			
		decryptionCore2: decryption_core
			generic map(
				rangeStart => x"100000",
				rangeStop => x"1FFFFF")
			port map(
				clock => main_clock,
				secret => secret_core2,
				start => start(2),
				stop => done(1) or done(3) or done(4),
				decrypted => done(2),
				failed => failed(2),				
				decryptedAddress => std_logic_vector(dAddress),
				decryptedQ => dQ_core2
			);
		decryptionCore3: decryption_core
			generic map(
				rangeStart => x"200000",
				rangeStop => x"2FFFFF")
			port map(
				clock => main_clock,
				secret => secret_core3,
				start => start(3),
				stop => done(1) or done(2) or done(4),
				decrypted => done(3),
				failed => failed(3),				
				decryptedAddress => std_logic_vector(dAddress),
				decryptedQ => dQ_core3
			);
		decryptionCore4: decryption_core
			generic map(
				rangeStart => x"300000",
				rangeStop => x"3FFFFF")
			port map(
				clock => main_clock,
				secret => secret_core4,
				start => start(4),
				stop => done(1) or done(2) or done(3),
				decrypted => done(4),
				failed => failed(4),				
				decryptedAddress => std_logic_vector(dAddress),
				decryptedQ => dQ_core4
			);
		
		--7 segment mapping
		display5: digit7seg port map(digit => keyReg(23 downto 20), seg7 => HEX5);
		display4: digit7seg port map(digit => keyReg(19 downto 16), seg7 => HEX4);
		display3: digit7seg port map(digit => keyReg(15 downto 12), seg7 => HEX3);
		display2: digit7seg port map(digit => keyReg(11 downto 8), seg7 => HEX2);
		display1: digit7seg port map(digit => keyReg(7 downto 4), seg7 => HEX1);
		display0: digit7seg port map(digit => keyReg(3 downto 0), seg7 => HEX0);
		
		process(CLOCK_50)
		begin
			if(rising_edge(CLOCK_50)) then
				slowCounter <= slowCounter + 1;
			end if;
		end process;
		
		-- State register, iCounter, jCounter, 
		process (main_clock)
		begin
			if (rising_edge(main_clock)) then
				if (KEY(3) = '0') then
					PS <= decryptStart;
				else
					PS <= NS;
				end if;
				
				if (addressInit = '1') then
					dAddress <= to_unsigned(0, dAddress'length);
				elsif (addressLoad = '1') then
					dAddress <= dAddress + 1;
				end if;
				
				if(LCDCounterInit = '1') then
					LCDCounter <= to_unsigned(0, LCDCounter'length);
				elsif(LCDCounterLoad = '1') then
					LCDCounter <= LCDCounter + 1;
				end if;
					
			end if;
		end process;
		
		-- Next State logic
		process (PS, done, KEY, start, dQ_core1, dQ_core2, dQ_core3, dQ_core4, addressInit, addressLoad, dAddress, LCDCounter)
		begin
			-- Default values
			start <= "0000";
			LCD_RS <= '0'; -- Default to sending instructions
			LCD_DATA <= x"00"; -- Default
			LEDG <= x"00"; -- LEDG off.
			addressInit <= '0'; -- Not resetting dAddress
			addressLoad <= '0'; -- Not enabling dAddress
			lcd_clock <= '0'; -- Don't allow LCD_EN to toggle back and forth.
			slow_clock <= '0'; -- Use CLOCK_50 by default.
			LCDCounterInit <= '0'; -- Not resetting LCDCounter.
			LCDCounterLoad <= '0'; -- Not enabling LCDCounter.

			case PS is
				when decryptStart =>
					start <= "1111";
					addressInit <= '1';
					NS <= decryptStall;
				when decryptStall =>
				-- each core will search through 1/4 of all the possible keys. 
				-- Stop when one of the cores has found a correct key
					if(done = "0000") then
						NS <= decryptStall;
					else
						NS <= resetLCD0;
					end if;
				when resetLCD0 => NS <= resetLCD1; -- x0
									LCD_RS <= '0';
									LCD_DATA <= x"38";
									LEDG <= x"00"; -- Current state								
									lcd_clock <= '1';
									slow_clock <= '1';
								
				when resetLCD1 => NS <= resetLCD2; -- x1
									LCD_RS <= '0';
									LCD_DATA <= x"38";
									LEDG <= x"01"; -- Current state
									lcd_clock <= '1';
									slow_clock <= '1';
									
				when resetLCD2 => NS <= resetLCD3; -- x2
									LCD_RS <= '0';
									LCD_DATA <= x"0C";
									LEDG <= x"02"; -- Current state
									lcd_clock <= '1';
									slow_clock <= '1';
									
				when resetLCD3 => NS <= resetLCD4; -- x3
									LCD_RS <= '0';
									LCD_DATA <= x"01";
									LEDG <= x"03"; -- Current state
									lcd_clock <= '1';
									slow_clock <= '1';
									
				when resetLCD4 => NS <= resetLCD5; -- x4
									LCD_RS <= '0';
									LCD_DATA <= x"06";
									LEDG <= x"04"; -- Current state
									lcd_clock <= '1';
									addressInit <= '1';
									LCDCounterInit <= '1';
									slow_clock <= '1';
				when resetLCD5 => 
									LCD_RS <= '0';
									LCD_DATA <= x"80";
									LEDG <= x"05"; -- Current state
									
									addressLoad <= '1';
									lcd_clock <= '1';
									slow_clock <= '1';
									if(done(1) = '1') then
										NS <= readCore1;
									elsif (done(2) = '1') then
										NS <= readCore2;
									elsif (done(3) = '1') then
										NS <= readCore3;
									else 
										NS <= readCore4;
									end if;
				when LCDStall =>
									LCD_RS <= '1';
									LCD_DATA <= x"20";
									LCDCounterLoad <= '1';
									LEDG <= x"00";
									lcd_clock <= '1';
									slow_clock <= '1';
									if(LCDCounter = 39) then -- Stall until we are about to hit the end of the first row in the screen.
										addressLoad <= '1';
										if(done(1) = '1') then
											NS <= readCore1;
										elsif (done(2) = '1') then
											NS <= readCore2;
										elsif (done(3) = '1') then
											NS <= readCore3;
										else 
											NS <= readCore4;
										end if;
									else
										NS <= LCDStall;
									end if;
				when readCore1  =>
									LCD_RS <= '1';
									LCD_DATA <= dQ_core1;
									LEDG <= x"06"; -- Current state
									
									addressLoad <= '1';
									lcd_clock <= '1';
									slow_clock <= '1';
									LCDCounterLoad <= '1';
									if (LCDCounter = 15) then
										addressLoad <= '0'; -- Don't load the counter in this state, load it just as we come back from the stall state.
										NS <= LCDStall;
									elsif(dAddress = 31) then
										NS <= done_state;
									else
										NS <= readCore1;
									end if;			
				when readCore2  =>								
									LCD_RS <= '1';
									LCD_DATA <= dQ_core2;
									LEDG <= x"07"; -- Current state
									addressLoad <= '1';
									lcd_clock <= '1';
									slow_clock <= '1';
									LCDCounterLoad <= '1';
									if (LCDCounter = 15) then
										addressLoad <= '0'; -- Don't load the counter in this state, load it just as we come back from the stall state.
										NS <= LCDStall;
									elsif(dAddress = 31) then
										NS <= done_state;
									else
										NS <= readCore2;
									end if;					
				when readCore3  =>									
									LCD_RS <= '1';
									LCD_DATA <= dQ_core3;
									LEDG <= x"08"; -- Current state
									
									addressLoad <= '1';
									lcd_clock <= '1';
									slow_clock <= '1';
									LCDCounterLoad <= '1';
									if (LCDCounter = 15) then
										addressLoad <= '0'; -- Don't load the counter in this state, load it just as we come back from the stall state.
										NS <= LCDStall;
									elsif(dAddress = 31) then
										NS <= done_state;
									else
										NS <= readCore3;
									end if;					
				when readCore4  =>									
									LCD_RS <= '1';
									LCD_DATA <= dQ_core4;
									LEDG <= x"09"; -- Current state
									
									addressLoad <= '1';
									lcd_clock <= '1';
									slow_clock <= '1';
									LCDCounterLoad <= '1';
									if (LCDCounter = 15) then
										addressLoad <= '0'; -- Don't load the counter in this state, load it just as we come back from the stall state.
										NS <= LCDStall;
									elsif(dAddress = 31) then
										NS <= done_state;
									else
										NS <= readCore4;
									end if;		
				when done_state =>
							LEDG <= x"10"; -- Current state
							NS <= done_state;
				when others =>
					NS <= decryptStart;
			end case;
		end process;
		
		process(done, secret_core1, secret_core2, secret_core3, secret_core4)
		begin
			if(done(1) = '1') then
				keyReg <= unsigned(secret_core1);
			elsif(done(2) = '1') then
				keyReg <= unsigned(secret_core2);
			elsif(done(3) = '1') then
				keyReg <= unsigned(secret_core3);
			elsif(done(4) = '1') then
				keyReg <= unsigned(secret_core4);
			else
				keyReg <= x"000000";
			end if;
		end process;
		
		process(lcd_clock, main_clock)
		begin
			if(lcd_clock = '1') then
				LCD_EN<= not main_clock;
			else
				LCD_EN <= 'Z';
			end if;
		end process;
		
		process (slow_clock, slowCounter, CLOCK_50)
		begin
			if(slow_clock = '1') then
				main_clock <= std_logic(slowCounter(slowCounter'high));
			else
				main_clock <= CLOCK_50;
			end if;
		end process;
end RTL;


