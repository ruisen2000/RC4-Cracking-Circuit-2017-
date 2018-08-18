-- Filename: ksa_task2b.vhd
-- Author 1: Ryan Lui
-- Author 1 Student #: 301251951
-- Author 2: Greyson Wang
-- Author 2 Student #: 301249759
-- Group Number: 27
-- Lab Section
-- Lab: 6
-- Task Completed: All.
-- Date: 2017-03-14
-- Description: Task 2a, standalone
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity ksa_task2a is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0));  -- red lights
end ksa_task2a;

-- Architecture part of the description

architecture rtl of ksa_task2a is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
   COMPONENT s_memory IS
	   PORT (
		   address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   clock		: IN STD_LOGIC  := '1';
		   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   wren		: IN STD_LOGIC ;
		   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
   END component;

	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	type state_type is (state_init, 
                       state_fill,						
   	 					  state_done,
							  initTask2,
							  readSi,
							  readSiStall2,
							  readSiStall,
							  computeJ,
							  readSj,
							  readSjStall2,
							  readSjStall,
							  writeSj);
	signal PS, NS: state_type; -- Present and Next State, respectively
	signal iCounter, jCounter, tmpCounter: unsigned (7 downto 0) := to_unsigned(0,8);
	signal jNew: unsigned (7 downto 0) := to_unsigned(0, 8); -- Used to load the new j value into j.
	signal iLoad, iInit: std_logic; -- signals for state register.
	signal tmpLoad: std_logic; -- Enable for tmp, used for swapping S[i] and S[j]
	signal jLoad, jInit: std_logic; -- Enable for jCounter.
	signal sData: std_logic_vector(7 downto 0); -- The data we are writing to the S RAM module.
	signal sAddress: std_logic_vector(7 downto 0); -- The address we will supply to the S RAM module.
	signal sQ: std_logic_vector(7 downto 0); -- The data retrieved from the S RAM module
	signal sAddressSel, sDataSel, sDatasQSel, sWrite: std_logic; -- Control signals for the S memory block. Refer to the block diagram.
								
    -- These are signals that are used to connect to the memory													 
	 signal address : STD_LOGIC_VECTOR (7 DOWNTO 0);	 
	 signal data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	 signal wren : STD_LOGIC;
	 signal q : STD_LOGIC_VECTOR (7 DOWNTO 0);	

	 begin
	    -- Include the S memory structurally
	
		u0: s_memory port map (
			address => sAddress,
			clock => CLOCK_50,
			data => sData,
			wren => sWrite, 
			q => sQ
		);
  
       -- write your code here.  As described in teh slide set, this 
       -- code will drive the address, data, and wren signals to
       -- fill the memory with the values 0...255
		 
		-- State register, iCounter, jCounter, 
		process (CLOCK_50)
		begin
			if (rising_edge(CLOCK_50)) then
				if (KEY(3) = '0') then
					PS <= state_init;
				else
					PS <= NS;
					if(iInit= '1') then
						iCounter <= to_unsigned(0, iCounter'length);
					elsif (iLoad = '1') then
						iCounter <= iCounter + 1;
					end if;
					
					if(jInit = '1') then
						jCounter <= to_unsigned(0, jCounter'length);
					elsif (jLoad = '1') then
						jCounter <= jNew;
					end if;
					
					if(tmpLoad = '1') then
						tmpCounter <= unsigned(sQ);
					end if;
				end if;
			end if;
		end process;
		
		-- Next State logic
		process (PS, iCounter)
		begin
			-- Default values;
			iInit <= '0';
			iLoad <= '0';
			jInit <= '0';
			jLoad <= '0';
			tmpLoad <= '0';
			sWrite <= '0';
			sAddressSel <= '0';
			sDataSel <= '0';
			sDatasQSel <= '0';
			LEDG <= "00000000";
			LEDR <= "000000000000000000";
			LEDG(0) <= '0';
			
			case PS is
				when state_init =>
					iInit <= '1';
					NS <= state_fill;
				when state_fill =>
					iLoad <= '1';
					sWrite <= '1';
					if (iCounter = 255) then -- Loop until all memory locations are filled.
						NS <= initTask2;
					else
						NS <= state_fill;
					end if;
				when initTask2 =>
					iInit <= '1';
					jInit <= '1';
					NS <= readSi;
				when readSi =>
					--Send address to read from the S RAM module
					NS <= readSiStall;
				when readSiStall =>
					-- Upon entering this state, since q for the S RAM module is async, data should be ready to read at the next clock cycle.
					tmpLoad <= '1';
					NS <= computeJ;
				when computeJ =>
					-- Compute and store the new value of j into the register.
					jLoad <= '1';
					NS <= readSj;
				when readSj =>
					-- Now that j is computed, send this address to the RAM module to read.
					sAddressSel <= '1';
					NS <= readSjStall;
				when readSjStall =>
					-- Like previously, upon entering this state, since q for the S RAM module is async, data will be read at the next clock tick, and we will also do the writing for S[i] <= S[j]
					sWrite <= '1';
					sDataSel <= '1';
					sDatasQSel <= '1';
					NS <= writeSj;
				when writeSj =>
					-- We can now write tmp to S[j], and then increment i at the next clock cycle.
					-- If we are at i=255, then we are done.
					sWrite <= '1';
					sAddressSel <= '1';
					sDataSel <= '1';
					iLoad <= '1';
					if(iCounter = 255) then
						NS <= state_done;
					else
						NS <= readSi;
					end if;
				when state_done =>
					-- Do nothing.
					LEDG(0) <= '1';
					NS <= state_done;
				when others =>
					NS <= state_init;
			end case;
		end process;
		
		-- The Key (using SW)
		process(SW, iCounter, jCounter, tmpCounter)
			variable key_8bit: unsigned(7 downto 0);
			variable key_full: std_logic_vector(23 downto 0) := "000000" & SW;
		begin
			key_full := "000000" & SW;
			if((iCounter mod 3) = 2) then
				key_8bit := unsigned(key_full(7 downto 0));
			elsif ((iCounter mod 3) = 1) then
				key_8bit := unsigned(key_full(15 downto 8));
			else
				key_8bit := unsigned(key_full(23 downto 16));
			end if;
			
			jNew <= (jCounter + tmpCounter + key_8bit) mod 256;
		end process;
		
		-- S RAM Module
	process(sDatasQSel, sDataSel, sAddressSel, sQ, tmpCounter, iCounter, jCounter)
			variable sDatasQMux: unsigned(7 downto 0);
			variable sDataMux: unsigned(7 downto 0);
			variable sAddressMux: unsigned(7 downto 0);
		begin
			if(sDatasQSel = '1') then -- If 1, take the sQ loopback.
				sDatasQMux := unsigned(sQ);
			else
				sDatasQMux := tmpCounter;
			end if;
			
			if (sDataSel = '1') then
				sDataMux := sDatasQMux;
			else
				sDataMux := iCounter;
			end if;
			
			if (sAddressSel = '1') then
				sAddressMux := jCounter;
			else
				sAddressMux := iCounter;
			end if;
			
			--Final assignments
			sAddress <= std_logic_vector(sAddressMux);
			sData <= std_logic_vector(sDataMux);
		end process;
       
		 
		-- You will be likely writing this is a state machine. Ensure
		-- that after the memory is filled, you enter a DONE state which
		-- does nothing but loop back to itself.  


end RTL;


