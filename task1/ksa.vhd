-- Filename: ksa.vhd
-- Author 1: Ryan Lui
-- Author 1 Student #: 301251951
-- Author 2: Greyson Wang
-- Author 2 Student #: 301249759
-- Group Number: 27
-- Lab Section
-- Lab: 6
-- Task Completed: All.
-- Date: 2017-03-14
-- Description: Task 1, standalone
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity ksa is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(15 downto 0);  -- slider switches
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
	
	type state_type is (state_init, 
                       state_fill,						
   	 					  state_done);
	signal PS, NS: state_type; -- Present and Next State, respectively
	signal iCounter: unsigned (7 downto 0) := to_unsigned(0,8);
	signal iLoad, iInit: std_logic; -- signals for state register.
								
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
				if(iInit= '1') then
					iCounter <= to_unsigned(0, iCounter'length);
				elsif (iLoad = '1') then
					iCounter <= iCounter + 1;
				end if;
			end if;
		end process;
		
		process (PS, iInit, iLoad, iCounter)
		begin
			-- Default values;
			iInit <= '0';
			iLoad <= '0';
			wren <= '0';
			case PS is
				when state_init =>
					iInit <= '1';
					NS <= state_fill;
				when state_fill =>
					iLoad <= '1';
					wren <= '1';
					if (iCounter = 255) then -- Loop until all memory locations are filled.
						NS <= state_done;
					else
						NS <= state_fill;
					end if;
				when state_done =>
					-- Do nothing.
					NS <= state_done;
				when others =>
					NS <= state_init;
			end case;
		end process;
		
		--Structural assignment
      address <= std_logic_vector(iCounter);
		data <= std_logic_vector(iCounter);
       
		 
		-- You will be likely writing this is a state machine. Ensure
		-- that after the memory is filled, you enter a DONE state which
		-- does nothing but loop back to itself.  


end RTL;


