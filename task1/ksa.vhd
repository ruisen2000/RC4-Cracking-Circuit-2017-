library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs
-- includes both task 1 and task 2a

entity ksa is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0));  -- red lights
end ksa;

-- Architecture part of the description

architecture rtl of ksa is

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
	
	type state_type is (state_init, state_fill,	initTask2, readSi, readSi_stall, compute_j, readSj, readSj_stall, writeSj, done);
	signal PS, NS: state_type; -- Present and Next State, respectively
	signal iCounter: unsigned (7 downto 0) := to_unsigned(0,8);
	signal j : unsigned(7 downto 0) := to_unsigned(0,8);
	signal j_new : unsigned(7 downto 0);  -- new value of j 
	signal tmp : std_logic_vector(7 downto 0);
	signal iLoad, iInit, jInit, jLoad, tmp_init, tmp_load: std_logic; -- signals for registers.
	signal sAddrSel: std_logic;  -- select either i or j as the address for task 2a
	signal sDataSel: std_logic; -- selects whether data input to memory geets its value from task 1 or task 2
	signal task2DataSel : std_logic; -- selects between temp or s[j] as the data during swapping
	signal task2Data : std_logic_vector(7 downto 0);
	constant keyLength: unsigned(7 downto 0) := to_unsigned(3, 8);
								
    -- These are signals that are used to connect to the memory													 
	 signal address : STD_LOGIC_VECTOR (7 DOWNTO 0);	 
	 signal data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	 signal wren : STD_LOGIC;
	 signal q : STD_LOGIC_VECTOR (7 DOWNTO 0);	

	 begin
	    -- Include the S memory structurally
	
		u0: s_memory port map (
			address => address,
			clock => CLOCK_50,
			data => data,
			wren => wren, 
			q => q
		);
  
       -- write your code here.  As described in teh slide set, this 
       -- code will drive the address, data, and wren signals to
       -- fill the memory with the values 0...255
		 
		-- State register + iCounter
		process (CLOCK_50)
		begin
			if (rising_edge(CLOCK_50)) then
				PS <= NS;
				
				-- i counter
				if(iInit= '1') then
					iCounter <= to_unsigned(0, iCounter'length);
				elsif (iLoad = '1') then
					iCounter <= iCounter + 1;
				end if;
				
				-- register to store j
				if(jInit = '1') then
					j <= to_unsigned(0, j'length);
				elsif (jLoad = '1') then
					j <= j_new;
				end if;
				
				-- register to store tmp
				if(tmp_init = '1') then
					tmp <= (others => '0');
				elsif (tmp_load = '1') then
					tmp <= q; -- get value of s[i]
				end if;
				
			end if;
		end process;
		
		process (PS, iInit, iLoad, iCounter)
		begin
			-- Default values;
			iInit <= '0';
			jInit <= '0';
			iLoad <= '0';
			jLoad <= '0';
			wren <= '0';
			tmp_load <= '0';
			tmp_init <= '0';
			sAddrSel <= '0';
			task2DataSel <= '0';
			sDataSel <= '0';
			LEDG <= "00000000";
			LEDR <= "000000000000000000";
			LEDG(0) <= '1';
			
			case PS is
				when state_init =>
					iInit <= '1';
					NS <= state_fill;
				when state_fill =>
					iLoad <= '1';
					wren <= '1';
					if (iCounter = 255) then -- Loop until all memory locations are filled.
						NS <= initTask2;
					else
						NS <= state_fill;
					end if;
				when initTask2 =>
					iInit <= '1';
					jInit <= '1';
					tmp_init <= '1';
					NS <= readSi;
				when readSi =>
					-- read s[i], control signals are 0					
					NS <= readSi_stall;			
					
				when readSi_stall =>
					tmp_load <= '1';
					NS <= compute_j;
				when compute_j =>
					jLoad <= '1';
					NS <= readSj;
				when readSj =>
					sAddrSel <= '1';
					sDataSel <= '1';
					NS <= readSj_stall;
				when readSj_stall =>
					wren <= '1';
					task2DataSel <= '1';
					sDataSel <= '1';
					NS <= writeSj;
				when writeSj =>
					iLoad <= '1';
					sDataSel <= '1';
					wren <= '1';
					sAddrSel <= '1';
					if (iCounter = 255) then
						NS <= done;
					else 
						NS <= readSi;
					end if;
				when done =>
					LEDG(0) <= '1';
					NS <= done;
				when others =>
					NS <= state_init;
			end case;
		end process;
		
		-- This block controls access to the memory block
		process(iCounter, sDataSel, sAddrSel, task2DataSel, q, tmp, j)
		begin
			if (sDataSel = '0') then
				-- select task 1 data
				address <= std_logic_vector(iCounter);
				data <= std_logic_vector(iCounter);
			else
				-- task 2 data
				if (task2DataSel = '1') then
					data <= q;
				else
					data <= tmp;
				end if;
				
				if (sAddrSel = '1') then
					address <= std_logic_vector(j);
				else
					address <= std_logic_vector(iCounter);
				end if;
				
			end if;
		end process;
       
	   -- compute new value of j
		 process (j, tmp, iCounter, SW)

		 variable key_segment: unsigned(7 downto 0);
		 variable secret_key: std_logic_vector(23 downto 0) := "000000" & SW;
		 begin			
			
			secret_key := "000000" & SW;
			
			if((iCounter mod keyLength) = 2) then
				key_segment := unsigned(secret_key(7 downto 0));
			elsif ((iCounter mod keyLength) = 1) then
				key_segment := unsigned(secret_key(15 downto 8));
			else
				key_segment := unsigned(secret_key(23 downto 16));
			end if;
			
			j_new <= (j + unsigned(tmp) + key_segment) mod 256;					
		 
		 end process;
		-- You will be likely writing this is a state machine. Ensure
		-- that after the memory is filled, you enter a DONE state which
		-- does nothing but loop back to itself.  


end RTL;


