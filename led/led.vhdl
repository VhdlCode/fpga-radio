
-- Module Name: led - Behavioral

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led is
Port ( Clk : in std_logic;
Reset : in std_logic;
Led_out : out std_logic);
end led;

architecture Behavioral of led is
signal counter : unsigned(24 downto 0);
signal selector: std_logic;

begin

freq_divider: process (Clk, Reset)

begin
    if Reset = '1' then
        counter <= (others => '0');
        selector <= '0';

    elsif rising_edge(Clk) then
        counter <= counter + 1;

        if counter = "1000000000000000000000000" then

            selector <= not selector;   -- Frequency selector

        end if;
    end if;

end process;

-- Frequency Selection assignments
Led_out <= std_logic(counter(21)) when selector = '0' else -- 0.35seconds duration
              std_logic(counter(23)); -- 1.4seconds duration
end Behavioral;
