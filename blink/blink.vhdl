-- *****************************************************************
-- FGPA-RADIO: LED BLINK MODULE.

-- The input/driving clock is the xula2 12MHz board clock.
-- This clock frequency is reduced to 1.43Hz, the blinking frequency
-- of connected LED.
-- Frequency reduction (division) is done by connecting the output
-- port/pin Led (to which an LED will be connected) to the 23rd bit 
-- of a 23 bits counter.
-- The 23rd bit (which is counter(22) in the code) divides the 12MHz
-- clock frequency by 8,388,608 (2^23) to give 1.43Hz.

-- *****************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Blink is
    Port ( Clk     : in  STD_LOGIC;
           Reset   : in  STD_LOGIC;
           Led     : out STD_LOGIC);
end Blink;

architecture Behavioral of Blink is
	signal counter:	unsigned(22 downto 0);

begin
	process (Clk, Reset)
	begin
	
		if Reset = '1' then
			counter <= (others => '0');
		elsif rising_edge(Clk) then
			counter <= counter + 1;
		end if;
			
	end process;
	
	Led <= STD_LOGIC(counter(22));
end Behavioral;
