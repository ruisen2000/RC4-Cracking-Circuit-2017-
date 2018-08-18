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
-- Description: The module used to decrypt the message using an already set up
-- S RAM.
-- To use this module:
-- 1. Ensure that this module as access to the S (working) RAM module, and that
--    the RAM has been shuffled. Ensure that it also has access to RAM to write to,.
--    as well as the ROM to decrypt from.
-- 2. Raise the start signal high, then lower it after 1 clock cycle.
-- 3. The message is decrypted when done is asserted.
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity ksa_task2b is
	port(
		clock : in  std_logic;  -- Clock pin
		start: in std_logic; -- Start signal.
		done: out std_logic;
		
		sAddress: out std_logic_vector(7 downto 0);  -- Address port to working (S) RAM module
		sData: out std_logic_vector(7 downto 0); -- Data port to working (S) RAM module
		dData: out std_logic_vector(7 downto 0); -- Data port to decrypted (D) RAM module
		sWrite, dWrite: out std_logic; -- Write enables to RAM modules
		sQ: in std_logic_vector(7 downto 0); -- q port from RAM module
		eAddress, dAddress: out std_logic_vector(4 downto 0); -- Address port to ROM and D RAM module.
		eQ: in std_logic_vector(7 downto 0) -- ROM q port
	);
end ksa_task2b;

-- Architecture part of the description

architecture RTL of ksa_task2b is
	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	type state_type is (init,
							  computeI,
							  readSi,
							  readSiStall,
							  computeJ,
							  readSj,
							  readSjStall,
							  writeSi,
							  writeSj,
							  doubleRead,
							  decryptAndStore,
							  doneState);
	signal PS, NS: state_type; -- Present and Next State, respectively
	signal iCounter, jCounter, registerSi, registerSj: unsigned (7 downto 0) := to_unsigned(0,8);
	signal kCounter: unsigned(4 downto 0);
	signal jNew: unsigned (7 downto 0) := to_unsigned(0, 8); -- Used to load the new j value into j.
	signal iLoad, iInit: std_logic; -- Control signals for iCounter.
	signal jLoad, jInit: std_logic; -- Control signals for jCounter.
	signal kLoad, kInit: std_logic; -- Control signals for kCounter, used to control outer loop.
	signal registerSiLoad, registerSjLoad: std_logic; -- Control signals for registerSi and registerSj

	signal sDataSel: std_logic; -- The data we are writing to the S RAM module.
	signal sFAddressSel: std_logic; -- Choose whether we want to supply the address that stores f in the algorithm.
	signal sAddressSel: std_logic; -- Choose whether we want i or j to run to the S RAM module address.
	

	begin
		
		-- Decryption stage.  Only gets stored in the d RAM module if dWrite is asserted.
		dData <= sQ XOR eQ;
		dAddress <= std_logic_vector(kCounter);
		eAddress <= std_logic_vector(kCounter);
		
		-- State register, iCounter, jCounter, 
		process (clock)
		begin
			if (rising_edge(clock)) then
				if (start = '1') then
					PS <= init;
				else
					PS <= NS;
					
					-- iCounter
					if(iInit= '1') then
						iCounter <= to_unsigned(0, iCounter'length);
					elsif (iLoad = '1') then
						iCounter <= iCounter + 1;
					end if;
					
					-- jCounter
					if(jInit = '1') then
						jCounter <= to_unsigned(0, jCounter'length);
					elsif (jLoad = '1') then
						jCounter <= jCounter + registerSi;
					end if;
					
					-- kCounter
					if(kInit= '1') then
						kCounter <= to_unsigned(0, kCounter'length);
					elsif (kLoad = '1') then
						kCounter <= kCounter + 1;
					end if;
					
					-- registerSi
					if(registerSiLoad = '1') then
						registerSi <= unsigned(sQ);
					end if;
					
					-- registerSj
					if(registerSjLoad = '1') then
						registerSj <= unsigned(sQ);
					end if;
					
					
				end if;
			end if;
		end process;
		
		-- Next State logic
		process (PS, kCounter)
		begin
			-- Default status signals
			iInit <= '0';
			iLoad <= '0';
			jInit <= '0';
			jLoad <= '0';
			kInit <= '0';
			kLoad <= '0';
			
			registerSiLoad <= '0';
			registerSjLoad <= '0';
			
			sWrite <= '0';
			dWrite <= '0';
			
			sAddressSel <= '0';
			sFAddressSel <= '0';
			sDataSel <= '0';
			
			done <= '0';
			
			case PS is
				when init =>
					iInit <= '1';
					jInit <= '1';
					kInit <= '1';
					NS <= computeI;
				when computeI =>
					iLoad <= '1';
					NS <= readSi;
				when readSi =>
					--Send address to read from the S RAM module
					NS <= readSiStall;
				when readSiStall =>
					-- Upon entering this state, since q for the S RAM module is async, data should be ready to read at the next clock cycle.
					registerSiLoad <= '1';
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
					-- Like previously, upon entering this state, since q for the S RAM module is async, data will be read at the next clock tick.
					registerSjLoad <= '1';
					NS <= writeSi;
				when writeSi =>
					-- Write S[i] to memory.
					sWrite <= '1';
					sDataSel <= '1';
					NS <= writeSj;
				when writeSj =>
					-- Write S[j] to memory.
					sAddressSel <= '1';
					sWrite <= '1';
					NS <= doubleRead;
				when doubleRead =>
					-- We will read s[s[i]+s[j]] and from ROM, but since k isn't changing here, ROM read is ready
					sFAddressSel <= '1';
					NS <= decryptAndStore;
				when decryptAndStore =>
					-- The XOR to decrypt is always happening, but we assert write to store it in RAM.
					dWrite <= '1';
					kLoad <= '1';
					if (kCounter = 31) then
						NS <= doneState;
					else
						NS <= computeI;
					end if;
				when doneState =>
					-- Do nothing.
					done <= '1';
					NS <= doneState;
				when others =>
					NS <= init;
			end case;
		end process;
		
		-- S RAM Module
		process(sDataSel, sAddressSel, sFAddressSel, registerSi, registerSj, iCounter, jCounter)
			-- See the block diagram for more info.
			variable sDataMux: unsigned(7 downto 0);
			variable sAddressMux: unsigned(7 downto 0);
			variable sFAddressMux: unsigned(7 downto 0);
		begin
			if(sDataSel = '1') then -- If 1, take the sQ loopback.
				sDataMux := registerSj;
			else
				sDataMux := registerSi; 
			end if;
			
			if (sAddressSel = '1') then
				sAddressMux := jCounter;
			else
				sAddressMux := iCounter;
			end if;
			
			if (sFAddressSel = '1') then
				sFAddressMux := registerSi + registerSj; -- mod 256 done automatically cause 8 bit overflow.
			else
				sFAddressMux := sAddressMux;
			end if;
			
			--Final assignments
			sAddress <= std_logic_vector(sFAddressMux);
			sData <= std_logic_vector(sDataMux);
		end process;
end RTL;


