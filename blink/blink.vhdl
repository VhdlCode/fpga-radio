-- Routine that makes an external LED blink at a fraction of the frequency
-- of an externally provided clock (XuLA2 board clock) at 12MHz. An unsigned
-- increment counter inside a process is used.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;     -- lib for basic operators an basic data types
use IEEE.NUMERIC_STD.ALL;        -- lib for signed/unsigned types and more goods

entity Blink is
  Port ( Clk   : in  std_logic;
         Reset : in  std_logic;
         Led   : out std_logic);
end Blink;

architecture Behavioral of Blink is
  signal counter: unsigned(22 downto 0);

  begin

    process (Clk, Reset)              -- it is a good practise to use an
    begin                             -- asynchronous reset in a clocked process
      if Reset = '1' then
        counter <= (others => '0');
      elsif rising_edge(Clk) then
        counter <= counter + 1;       -- increment unsigned variable
      end if;
    end process;

    Led <= std_logic(counter(22));    -- unsigned to std_logic casting

end Behavioral;
