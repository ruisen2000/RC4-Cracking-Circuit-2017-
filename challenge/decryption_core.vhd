-- Filename: decryption_core.vhd
-- Author 1: Ryan Lui
-- Author 1 Student #: 301251951
-- Author 2: Greyson Wang
-- Author 2 Student #: 301249759
-- Group Number: 27
-- Lab Section
-- Lab: 6
-- Task Completed: All.
-- Date: 2017-03-14
-- Description: Similar to the top level of task 3, but is modified to also accept a
-- range of keys to look at, making it easier to instantiate cores at the top level.
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity decryption_core is
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
end decryption_core;

-- Architecture part of the description

architecture rtl of decryption_core is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
   COMPONENT d_memory IS
	   PORT (
		   address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		   clock		: IN STD_LOGIC  := '1';
		   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   wren		: IN STD_LOGIC ;
		   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
   END component;
	
   COMPONENT s_memory IS
	   PORT (
		   address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   clock		: IN STD_LOGIC  := '1';
		   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		   wren		: IN STD_LOGIC ;
		   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
   END component;

	COMPONENT e_memory IS
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
		);
	END component;

	component setKey is
		port(
			clock : in  std_logic;  -- Clock pin
			secretKey: in std_logic_vector(23 downto 0); -- The secret key
			start: in std_logic; -- Start signal, used to reset.
			done: out std_logic; -- Done signal
			sAddress: out std_logic_vector(7 downto 0); -- Address to drive to s RAM module.
			sData: out std_logic_vector(7 downto 0); -- Data to drive to s RAM module.
			sQ: in std_logic_vector(7 downto 0);
			sWrite: out std_logic); -- Write enable on s RAM module.
	end component;

	component decrypt is
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
	end component;

	component digit7seg is
		PORT(
			digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
			seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
		);
	end component;
	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	type state_type is (
		init,
		startSetKey,
		setKeyStall,
		startDecrypt,
		decryptStall,
		checkInit,
		checkValid,
		incrementKey,
		error,
		done,
		interrupted);
	signal PS, NS: state_type; -- Present and Next State, respectively

	signal setKey_start, setKey_done, decrypt_start, decrypt_done: std_logic; -- Control/status signals.
	
	signal setKey_sData: std_logic_vector(7 downto 0); -- The data we are writing to the S RAM module.
	signal setKey_sAddress: std_logic_vector(7 downto 0); -- The address we will supply to the S RAM module.
	signal setKey_sWrite: std_logic; -- Write enable for S RAM module.
	
	signal decrypt_sData: std_logic_vector(7 downto 0); -- The data we are writing to the S RAM module.
	signal decrypt_sAddress: std_logic_vector(7 downto 0); -- The address we will supply to the S RAM module.
	signal decrypt_sWrite: std_logic; -- Write enable for S RAM module.
	
	signal sData: std_logic_vector(7 downto 0); -- The data we are writing to the S RAM module.
	signal sAddress: std_logic_vector(7 downto 0); -- The address we will supply to the S RAM module.
	signal sWrite: std_logic; -- Write enable for S RAM module.
	signal sQ: std_logic_vector(7 downto 0); -- The data retrieved from the S RAM module
	
	-- The set of D RAM memory signals from the decryption module.
	signal decrypt_dData: std_logic_vector(7 downto 0); -- The data we are writing to the D RAM module.
	signal decrypt_dAddress: std_logic_vector(4 downto 0); -- The address we will supply to the D RAM module.
	signal decrypt_dWrite: std_logic; -- Write enable for D RAM module.
	
	signal dData: std_logic_vector(7 downto 0); -- The data we are writing to the D RAM module.
	signal dAddress: std_logic_vector(4 downto 0); -- The address we will supply to the D RAM module.
	signal dWrite: std_logic; -- Write enable for D RAM module.
	signal dQ: std_logic_vector(7 downto 0); -- The data retrieved from the S RAM module
	
	signal eAddress: std_logic_vector(4 downto 0); -- The address we will supply to the E ROM module.
	signal eQ: std_logic_vector(7 downto 0); -- The data retrieved from the E ROM module
	
	
	signal decryptMux: std_logic; -- To control which S RAM signals get fed through: the setKey or decryption.
	
	signal addressReg: unsigned(4 downto 0); -- Used to loop through the decrypted RAM to validate bytes.
	signal keyReg: unsigned(23 downto 0);  -- Used to keep track of the key.  Only 22 bits since the 2 MSB are 00.
	signal keyInit, keyLoad: std_logic; -- ENable and reset for keyReg.
	signal addressInit, addressLoad: std_logic; -- ENable and reset for addressReg
	signal valid: std_logic; -- Determines if the byte in the decrypted memory is "valid"
	signal decryptedMux: std_logic; -- Controls which D RAM signals get fed in.  Used when the core has finished decrypting the message in ROM, and allows the outer entity to read from this RAM.  This takes precedence over verifyMux
	signal verifyMux: std_logic; -- Selects which signals go into the D RAM module: the decryption or verification.
	

	begin
		
		secret <= keyReg; -- The key register.
		
	    -- Include the S memory structurally
	
		sMem_BLOCK: s_memory port map (
			address => sAddress,
			clock => clock,
			data => sData,
			wren => sWrite,
			q => sQ
		);

		dMem_BLOCK: d_memory port map (
			address => dAddress,
			clock => clock,
			data => dData,
			wren => dWrite, 
			q => dQ
		);
		
		eMem_BLOCK: e_memory port map (
			address => eAddress,
			clock => clock,
			q => eQ
		);
		
		setKey_BLOCK: setKey port map (
			clock => clock,
			secretKey => std_logic_vector(keyReg),
			start => setKey_start,
			done => setKey_done,
			sAddress => setKey_sAddress,
			sData => setKey_sData,
			sWrite => setKey_sWrite,
			sQ => sQ
		);
		
		decrypt_BLOCK: decrypt port map (
			clock => clock,
			start => decrypt_start,
			done => decrypt_done,
			sAddress => decrypt_sAddress,
			sData => decrypt_sData,
			sQ => sQ,
			sWrite => decrypt_sWrite,
			dAddress => decrypt_dAddress,
			dData => decrypt_dData,
			dWrite => decrypt_dWrite,
			eAddress => eAddress,
			eQ => eQ
		);
       -- write your code here.  As described in teh slide set, this 
       -- code will drive the address, data, and wren signals to
       -- fill the memory with the values 0...255
		 
		-- State register, iCounter, jCounter, 
		process (clock)
		begin
			if (rising_edge(clock)) then
				if (start = '1') then
					PS <= init;
				elsif (stop = '1') then
					PS <= interrupted;
				else
					PS <= NS;
					
					-- keyReg enable and reset.
					if(keyInit = '1') then
						keyReg <= rangeStart; -- Replaced this with the range start.
					elsif (keyLoad = '1') then
						keyReg <= keyReg + 1;
					end if;
					
					-- addressReg enable and reset.
					if (addressInit = '1') then
						addressReg <= to_unsigned(0, addressReg'length);
					elsif (addressLoad = '1') then
						addressReg <= addressReg + 1;
					end if;
				end if;
			end if;
		end process;
		
		-- Next State logic
		process (PS, setKey_done, decrypt_done, valid, addressReg, keyReg)
		begin
			-- Default values
			decryptMux <= '0';
			setKey_start <= '0';
			decrypt_start <= '0';
			keyInit <= '0';
			keyLoad <= '0';
			addressInit <= '0';
			addressLoad <= '0';
			verifyMux <= '0';
			failed <= '0';
			decrypted <= '0';
			decryptedMux <= '0';
			
			case PS is
				when init =>
					keyInit <= '1';
					addressInit <= '1';
					NS <= startSetKey;
				when startSetKey =>
					setKey_start <= '1';
					NS <= setKeyStall;
				when setKeyStall =>
					if (setKey_done = '1') then
						NS <= startDecrypt;
					else
						NS <= setKeyStall;
					end if;
				when startDecrypt =>
					decrypt_start <= '1';
					decryptMux <= '1';
					NS <= decryptStall;
				when decryptStall =>
					decryptMux <= '1';
					if(decrypt_done = '1') then
						NS <= checkInit;
					else
						NS <= decryptStall;
					end if;
				when checkInit =>
					addressInit <= '1';
					verifyMux <= '1';
					NS <= checkValid;
				when checkValid =>
					addressLoad <= '1';
					verifyMux <= '1';
					if((valid = '1') and (addressReg < 31)) then
						NS <= checkValid;
					elsif ((valid = '1') and (addressReg = 31)) then
						NS <= done;
					else
						NS <= incrementKey;
					end if;
				when incrementKey =>
					keyLoad <= '1';
					if (keyReg = rangeStop) then -- Replaced this with the range stop.
						NS <= error;
					else
						NS <= startSetKey;
					end if;
				when error =>
					failed <= '1';
					NS <= error;
				when done =>
					decrypted <= '1';
					decryptedMux <= '1';
					NS <= done;
				when interrupted =>
					failed <= '1';
					NS <= interrupted;
				when others =>
					NS <= startSetKey;
			end case;
		end process;
		
		-- Large MUX
		process(decryptMux, decrypt_sAddress, decrypt_sData, decrypt_sWrite, setKey_sAddress, setKey_sData, setKey_sWrite, verifyMux, addressReg, decrypt_dAddress, decrypt_dWrite, decrypt_dData, decryptedMux, decryptedAddress)
		
		begin
			if (decryptMux = '1') then
				sAddress <= decrypt_sAddress;
				sData <= decrypt_sData;
				sWrite <= decrypt_sWrite;
			else
				sAddress <= setKey_sAddress;
				sData <= setKey_sData;
				sWrite <= setKey_sWrite;
			end if;
	
			if (decryptedMux = '1') then -- Message decrypted, allow outside to send address to read.
				dAddress <= decryptedAddress;
				dWrite <= '0'; -- Force to reading only.
				dData <= x"00";
			elsif (verifyMux = '1') then
				dAddress <= std_logic_vector(addressReg);
				dWrite <= '0'; -- Must be hardwired to 0 to constantly read.
				dData <= std_logic_vector(to_unsigned(0, dData'length)); -- This is a don't care sitation
			else
				dAddress <= decrypt_dAddress;
				dWrite <= decrypt_dWrite;
				dData <= decrypt_dData;
			end if;
		end process;
		
		-- Validator
		process(dQ)
		
		begin
			if( ( (unsigned(dQ) >= 97) AND (unsigned(dQ) <= 122) ) OR (unsigned(dQ) = 32) ) then
				valid <= '1';
			else
				valid <= '0';
			end if;
		end process;
       
	   decryptedQ <= dQ;

end RTL;


