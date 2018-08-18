-- Filename: digit7seg.vhd
-- Author 1: Ryan Lui
-- Author 1 Student #: 301251951
-- Author 2: Greyson Wang
-- Author 2 Student #: 301249759
-- Group Number: 27
-- Lab Section
-- Lab: 6
-- Task Completed: All.
-- Date: 2017-01-29
-- Description: The hex seg decoder.  Very similar to ENSC 252 one, except the c in
-- this one is upper case (C) instead of the lower case (c) one in 252.
------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY WORK;
USE WORK.ALL;

-----------------------------------------------------
--
--  This block will contain a decoder to decode a 4-bit number
--  to a 7-bit vector suitable to drive a HEX dispaly
--
--  It is a purely combinational block (think Pattern 1) and
--  is similar to a block you designed in Lab 1.
--
--------------------------------------------------------

ENTITY digit7seg IS
	PORT(
          digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
          seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
	);
END;


ARCHITECTURE behavioral OF digit7seg IS
BEGIN

-- Your code goes here
	process (digit)
	begin
		-- Using ENSC 252 truth table for this seg decoder.
		case digit is
			when x"0" => seg7 <= "1000000";
			when x"1" => seg7 <= "1111001";
			when x"2" => seg7 <= "0100100";
			when x"3" => seg7 <= "0110000";
			when x"4" => seg7 <= "0011001";
			when x"5" => seg7 <= "0010010";
			when x"6" => seg7 <= "0000010";
			when x"7" => seg7 <= "1111000";
			when x"8" => seg7 <= "0000000";
			when x"9" => seg7 <= "0011000";
			when x"a" => seg7 <= "0001000";
			when x"b" => seg7 <= "0000011";
			when x"c" => seg7 <= "1000110"; --capital C
			when x"d" => seg7 <= "0100001";
			when x"e" => seg7 <= "0000110";
			when others => seg7 <= "0001110";
		end case;
	end process;
END;
