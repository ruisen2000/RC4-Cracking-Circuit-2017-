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
-- Description: The top level entity for task 2b.  Requires ksa_task2a_modular and
-- ksa_task2b
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entity part of the description.  Describes inputs and outputs

entity ksa_task2b_TL is
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0));  -- red lights
end ksa_task2b_TL;

-- Architecture part of the description

architecture rtl of ksa_task2b_TL is

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

	component ksa_task2a_modular is
		port(
			clock : in  std_logic;  -- Clock pin
			secretKey: in std_logic_vector(17 downto 0); -- the lower 18 bits for the secret key.
			start: in std_logic; -- Start signal, used to reset.
			done: out std_logic; -- Done signal
			sAddress: out std_logic_vector(7 downto 0); -- Address to drive to s RAM module.
			sData: out std_logic_vector(7 downto 0); -- Data to drive to s RAM module.
			sQ: in std_logic_vector(7 downto 0);
			sWrite: out std_logic); -- Write enable on s RAM module.
	end component;

	component ksa_task2b is
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

	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	
	type state_type is (
		startSetKey,
		setKeyStall,
		startDecrypt,
		decryptStall,
		done);
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
	
	signal dData: std_logic_vector(7 downto 0); -- The data we are writing to the D RAM module.
	signal dAddress: std_logic_vector(4 downto 0); -- The address we will supply to the D RAM module.
	signal dWrite: std_logic; -- Write enable for D RAM module.
	signal dQ: std_logic_vector(7 downto 0); -- The data retrieved from the S RAM module
	
	signal eAddress: std_logic_vector(4 downto 0); -- The address we will supply to the E ROM module.
	signal eQ: std_logic_vector(7 downto 0); -- The data retrieved from the E ROM module
	
	signal decryptMux: std_logic; -- To control which s_memory signals get fed through.

	 begin
	    -- Include the S memory structurally
	
		sMem_BLOCK: s_memory port map (
			address => sAddress,
			clock => CLOCK_50,
			data => sData,
			wren => sWrite, 
			q => sQ
		);

		dMem_BLOCK: d_memory port map (
			address => dAddress,
			clock => CLOCK_50,
			data => dData,
			wren => dWrite, 
			q => dQ
		);
		
		eMem_BLOCK: e_memory port map (
			address => eAddress,
			clock => CLOCK_50,
			q => eQ
		);
		
		setKey_BLOCK: ksa_task2a_modular port map (
			clock => CLOCK_50,
			secretKey => SW,
			start => setKey_start,
			done => setKey_done,
			sAddress => setKey_sAddress,
			sData => setKey_sData,
			sWrite => setKey_sWrite,
			sQ => sQ
		);
		
		decrypt_BLOCK: ksa_task2b port map (
			clock => CLOCK_50,
			start => decrypt_start,
			done => decrypt_done,
			sAddress => decrypt_sAddress,
			sData => decrypt_sData,
			sQ => sQ,
			sWrite => decrypt_sWrite,
			dAddress => dAddress,
			dData => dData,
			dWrite => dWrite,
			eAddress => eAddress,
			eQ => eQ
		);
       -- write your code here.  As described in teh slide set, this 
       -- code will drive the address, data, and wren signals to
       -- fill the memory with the values 0...255
		 
		-- State register, iCounter, jCounter, 
		process (CLOCK_50)
		begin
			if (rising_edge(CLOCK_50)) then
				if (KEY(3) = '0') then
					PS <= startSetKey;
				else
					PS <= NS;
				end if;
			end if;
		end process;
		
		-- Next State logic
		process (PS, setKey_done, decrypt_done)
		begin
			-- Default values
			decryptMux <= '0';
			setKey_start <= '0';
			decrypt_start <= '0';
			
			case PS is
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
						NS <= done;
					else
						NS <= decryptStall;
					end if;
				when done =>
					NS <= done;
				when others =>
					NS <= startSetKey;
			end case;
		end process;
		
		-- Large MUX
		process(decryptMux, decrypt_sAddress, decrypt_sData, decrypt_sWrite, setKey_sAddress, setKey_sData, setKey_sWrite)
		
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
		end process;
       
		 
		-- You will be likely writing this is a state machine. Ensure
		-- that after the memory is filled, you enter a DONE state which
		-- does nothing but loop back to itself.  


end RTL;


