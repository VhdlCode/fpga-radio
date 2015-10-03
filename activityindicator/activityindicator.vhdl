-- Activity Indicator Module
-- This module blinks an LED (using an up counter) when its Enable port is set high
-- (by the UART or Modulator unit). The source clock is the XuLA1 board clock (12MHz).


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ActivityIndicator is
  Port ( Clk      : in  STD_LOGIC;
         Reset   : in  STD_LOGIC;
         Enable : in  STD_LOGIC;
         Led     : out  STD_LOGIC);
end ActivityIndicator;

architecture Behavioral of ActivityIndicator is
  signal counter : unsigned(22 downto 0);

begin
  process (Clk, Reset)
    begin
      if (Reset = '1') then
        counter <= (others => '0');
      elsif rising_edge(Clk) then
        counter <= counter + 1;
      end if;
  end process;
	
  Led <= STD_LOGIC(counter(22)) when Enable = '1' else
              '0';
end Behavioral;
