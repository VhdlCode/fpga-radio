library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Blink is
    Port ( Clk     : in  STD_LOGIC;
           Reset   : in  STD_LOGIC;
           Led_out : out STD_LOGIC);
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
	
	Led_out <= STD_LOGIC(counter(22));
end Behavioral;
