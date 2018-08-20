library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs
-- includes both task 1 and task 2a

-- Greyson

entity ksa_part2b is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
		start: in std_logic;		
		q : in std_logic_vector(7 downto 0); -- q port 
		eQ: in std_logic_vector(7 downto 0); -- ROM q port with encrypted input
		done: out std_logic;
		wren, dWrite: out std_logic; -- Write enables to RAM modules, dWrite for RaM module for decrypted output
		eAddress, dAddress: out std_logic_vector(4 downto 0); -- Address port to encrypted data ROM and decrupted output D RAM module.
		address: out std_logic_vector(7 downto 0);  -- Address port to working (S) RAM module
		data: out std_logic_vector(7 downto 0); -- Data port to working (S) RAM module
		dData: out std_logic_vector(7 downto 0)); -- Data port to decrypted (D) RAM module
        
end ksa_part2b;

-- Architecture part of the description

architecture rtl of ksa_part2b is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
  
	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	type state_type is (init, compute_i, readSi, readSi_stall, compute_j, readSj, writeSj, writeSi, read_f, decryptAndStore, doneState);
	signal PS, NS: state_type; -- Present and Next State, respectively
	signal iCounter: unsigned (7 downto 0) := to_unsigned(0,8);
	signal registerSi, registerSj : unsigned(7 downto 0);
	signal j : unsigned(7 downto 0) := to_unsigned(0,8);
	signal j_new : unsigned(7 downto 0);  -- new value of j 
	signal kCounter: unsigned(4 downto 0);
	signal iLoad, iInit, jInit, jLoad, kInit, kload, siLoad, sjLoad: std_logic; -- signals for registers.
	signal sAddrSel, sfAddrSel: std_logic;  -- select either i,j, or address for f as the address 
	signal sDataSel: std_logic; -- selects whether data input to memory geets its value from task 1 or task 2

								

	 begin
	    -- Include the S memory structurally
		  
       -- write your code here.  As described in teh slide set, this 
       -- code will drive the address, data, and wren signals to
       -- fill the memory with the values 0...255
		 
		-- State register + iCounter
		process (CLOCK_50)
		begin
			if (rising_edge(CLOCK_50)) then
			
				if (start = '1') then
					PS <= init;
				else
					PS <= NS;
					
						-- i counter
					if(iInit= '1') then
						iCounter <= to_unsigned(0, iCounter'length);
					elsif (iLoad = '1') then
						iCounter <= (iCounter + 1) mod 256;
					end if;
					
					-- register to store j
					if(jInit = '1') then
						j <= to_unsigned(0, j'length);
					elsif (jLoad = '1') then
						j <= j_new;
					end if;
					
					-- register to store tmp
					if(kInit = '1') then
						kCounter <= to_unsigned(0, kCounter'length);
					elsif (kload = '1') then
						kCounter <= kCounter + 1; 
					end if;
					
					if (siLoad = '1') then
						registerSi <= unsigned(q);
					end if;
					
					if (sjLoad = '1') then
						registerSj <= unsigned(q);
					end if;
				
				end if;
				
			end if;
		end process;
		
		process (PS, iInit, iLoad, iCounter, kCounter)
		begin
			-- Default values;
			iInit <= '0';
			jInit <= '0';
			iLoad <= '0';
			jLoad <= '0';			
			kload <= '0';
			kinit <= '0';
			
			-- registers for s[i] and s[j]
			sjLoad <= '0';
			siLoad <= '0';
			
			wren <= '0';
			dWrite <= '0'; 
			done <= '0';
			
			sAddrSel <= '0';
			sDataSel <= '0';
			sfAddrSel <= '0';
			
			
			case PS is
				when init =>
					iInit <= '1';
					kInit <= '1';
					jInit <= '1';
					NS <= compute_i;
				when compute_i =>
					iLoad <= '1';					
					NS <= readSi;
				when readSi =>
					-- read s[i], control signals are 0					
					NS <= readSi_stall;						
				when readSi_stall =>
					siLoad <= '1';
					NS <= compute_j;
				when compute_j =>
					jLoad <= '1';
					NS <= readSj;
				when readSj =>
					sAddrSel <= '1';
					NS <= writeSj;
				when writeSj =>
				-- write s[j] to address i
					wren <= '1';
					sjLoad <= '1';
					sDataSel <= '1';
					NS <= writeSi;
				when writeSi =>
				-- write registerSi to address j	
					wren <= '1';
					sAddrSel <= '1';
					NS <= read_f;
				when read_f =>
					sfAddrSel <= '1';
					NS <= decryptAndStore;
				when decryptAndStore =>
					dWrite <= '1';
					kload <= '1';
					if (kCounter = 31) then
						NS <= doneState;
					else
						NS <= compute_i;
					end if;
				when doneState =>	
					done <= '1';
					NS <= doneState;
				when others =>
					NS <= init;
			end case;
		end process;
		
		-- This block controls access to the memory block
		process(iCounter, sDataSel, sAddrSel, q, sfAddrSel, j, registerSi, registerSj, eQ, kCounter)
		begin
			if (sDataSel = '1') then						
				data <= q; -- value of s[j] read from memory
			else
				data <= std_logic_vector(registerSi);
								
			end if;
			
			if (sfAddrSel = '1') then
					address <= std_logic_vector( (registerSi + registerSj) mod 256 );
			else
					if(sAddrSel = '1') then
						address <= std_logic_vector(j);
					else
						address <= std_logic_vector(iCounter);
					end if;
			end if;
			
			dData <= q xor eQ;
			eAddress <= std_logic_vector(kCounter);
			dAddress <= std_logic_vector(kCounter);
			j_new <= (j + registerSi) mod 256;		
				
		end process;
       
	  
		-- You will be likely writing this is a state machine. Ensure
		-- that after the memory is filled, you enter a DONE state which
		-- does nothing but loop back to itself.  


end RTL;


