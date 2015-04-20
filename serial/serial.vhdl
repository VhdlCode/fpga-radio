-- Serial RS232 transceiver (Baud rate = 921600bps) module using FSM
-- Driving clock is 12MHz (XuLA2 Board Clock). Receiver (RxD) state machine are
-- IDLE(initial state; switches to READY state if RxD is high for 2.8s),
-- READY(switches to ACTIVE when start bit is detected), ACTIVE(does receiving;
-- switches to ERROR if com cable is disconnected or data has error),
-- ERROR(switches to IDLE RxD if RxD remains low for 2.8s; or SYNC if Sync_RxD
-- is high), SYNC(re-synchronise receiver by switching to READY after RxD is
-- high for 2.8s)
-- Transmitter states are LoadTxD(initial state; accepts in parallel data to be
-- sent; switches to SendTxD when Start_TxD is high) SendTxD(does sending of data;
-- switches to LoadTxD when data is sent)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity serial is
  Port (Clk       : in  std_logic;
        Reset     : in  std_logic;
        RxD       : in  std_logic;
        Sync_RxD  : in  std_logic;
        TxD_Data  : in  std_logic_vector (0 to 7); -- data to be sent
        Start_TxD : in  std_logic;                 -- starts data transmission
        Next_TxDat: out std_logic;                 -- high when data to be sent can be loaded
        TxD       : out std_logic;
        RxD_Data  : out std_logic_vector (0 to 7); -- Received data
        Read_RxDat: out std_logic;                 -- shows when received data can be read
        RxD_Boot  : out std_logic;                 -- shows when receiver is in idle state
        RxD_Error : out std_logic);                -- high when error oocurs during receiving
end entity serial;

architecture Behavioral of serial is
  type state_RxD is (Idle, Ready, Active, Error, Sync);
  signal PS_RxD, NS_RxD       : state_RxD;
  signal Prev_Val, Byte_Ready : std_logic;
  signal Delay_Transit        : std_logic_vector (1 downto 0);
  signal FSM_RxD_Out          : std_logic_vector (2 downto 0);
  signal Sampling, Baud       : unsigned (3 downto 0);
  signal Bit_Num, Bit_Count   : unsigned (3 downto 0);
  signal Delay_Timer          : unsigned (25 downto 0);
  signal Self_Reset, Bad_Data : boolean;
  signal Read_Bit, Ok_Read    : boolean;
  signal Stop_Read, Cable_Prob: boolean;
  signal Data_Sig             : std_logic_vector (0 to 8);
  type state_TxD is (LoadTxD, SendTxD);
  signal Start_Pulse, Start_Sig : std_logic;
  Signal PS_TxD, NS_TxD         : state_TxD;
  signal FSM_TxD_Out            : std_logic;
  signal TxD_Sent, Next_Bit     : boolean;
  signal TxD_ShiftReg           : std_logic_vector (0 to 10);
  
begin
  
-- Serial Receiver (RxD)
  -- RxD Control FMS begins
  sync_proc_RxD: process(Clk, Reset, NS_RxD)
  begin
    if (Reset = '1') then
      PS_RxD <= Idle;
      Delay_Timer <= (others => '0');
      Read_RxDat <= '0';
      Self_Reset <= false;
    elsif (rising_edge(Clk)) then
      if (Delay_Transit = "01") then      -- Delay for state Idle to Ready, Error to Idle
        Delay_Timer <= Delay_Timer + 1 ;
        Self_Reset <= true;
      elsif (Delay_Transit = "10") then   -- Delay for state Sync to Ready
        Delay_Timer <= Delay_Timer + 1 ;
        Self_Reset <= true;
      else
        if (Ok_Read = true) then
          Read_RxDat <= '1';
        elsif (Stop_Read = true) then
          Read_RxDat <= '0';
        end if;
        PS_RxD <= NS_RxD;
        Delay_Timer <= (others => '0');
        Self_Reset <= false;
      end if;
    end if;
  end process sync_proc_RxD;

  comb_proc_RxD: process(PS_RxD, RxD, Byte_Ready, Delay_Timer, Bad_Data, Sync_RxD, Cable_Prob)
  begin
    FSM_RxD_Out <= "000";                  -- pre assignments to prevent latch
    Delay_Transit <= "00";
    Ok_Read <= false;
    Stop_Read <= false;
    case PS_RxD is
      when Idle =>                         -- Idle state.
        FSM_RxD_Out <= "000";
        if (RxD = '1') then                -- Com cable connected
          if (Delay_Timer(25) = '1') then  -- 2.8s wait for the cable connection
            Delay_Transit <= "00";         -- stop timer
            NS_RxD <= Ready;
          else
            Delay_Transit <= "01";         -- start timer
            NS_RxD <= Idle;                -- stay in current state
          end if;
        else
          Delay_Transit <= "00";
          NS_RxD <= Idle;
        end if;
      when Ready =>                        -- Ready state
        FSM_RxD_Out <= "001";
        if (RxD = '0') then                -- start bit detected
          NS_RxD <= Active;
          Stop_Read <= True;
        else
          NS_RxD <= Ready;
          Stop_Read <= false;
        end if;
      when Active =>                       -- Active state (for receiving RxD data)
        FSM_RxD_Out <= "010";
        if (Byte_Ready = '1') then
          NS_RxD <= Ready;
          Ok_Read <= true;
        elsif (Bad_Data = true or Cable_Prob = true) then
          Ok_Read <= false;
          NS_RxD <= Error;
        else
          Ok_Read <= false;
          NS_RxD <= Active;
        end if;
      when Error =>                         -- Error state
        FSM_RxD_Out <= "011";
        if (Sync_Rxd = '1') then
          NS_RxD <= Sync;
          Delay_Transit <= "00";
        elsif (RxD = '0') then
          if (Delay_Timer(25) = '1') then   -- check for 2.8s if Com cable is disconnected
            Delay_Transit <= "00";          -- stop timer
            NS_RxD <= Idle;
          else
            Delay_Transit <= "01";          -- start timer
            NS_RxD <= Error;                -- stay in current state
          end if;
        else
          NS_RxD <= Error;
          Delay_Transit <= "00";
        end if;
      when Sync =>
        FSM_RxD_Out <= "100";
        if (RxD = '1') then
          if (Delay_Timer = x"104") then    -- RxD remains high for width of two bytes
            Delay_Transit <= "00";
            NS_RxD <= Ready;
          else
            Delay_Transit <= "10";
            NS_RxD <= Sync;
          end if;
        else
          Delay_Transit <= "00";
          NS_RxD <= Sync;
        end if;
      when Others =>
        FSM_RxD_Out <= "000";
        NS_RxD <= Ready;
    end case;
  end process comb_proc_RxD;
  -- RxD FSM ends
  
  check_bit_fidelity: process(Clk, Reset, Self_Reset)
  begin
    if (Reset = '1' or Self_Reset = true) then
      Sampling <= (others =>'0');
    elsif(rising_edge(Clk)) then
      if (FSM_RxD_Out = "010") then
        Sampling <= Sampling + 1;
        Read_Bit <= false;
        If (Sampling < x"9") then
          Prev_Val <= RxD;
          if (Sampling > x"3") then
            If (Prev_Val /= RxD) then       -- Check the integrity of the current bit
              Bad_Data <= true;
            end if;
          end if;
        elsif (Sampling = x"9") then
          Read_Bit <= true;
          elsif (Sampling = x"C") then      -- full bit width count.
          Sampling <= (others =>'0');
        end if;
      else
        Bad_Data <= false;
        Sampling <= (others =>'0');
        Read_Bit <= false;
      end if;
    end if;
  end process check_bit_fidelity;
  
  Receive_Bit: process(Clk, Reset, Self_Reset)
  begin
    if (Reset = '1' or Self_Reset = true) then
      Bit_Num <= (others =>'0');
      Data_Sig <= (others =>'0');
    elsif(rising_edge(Clk)) then
      if (Read_Bit = true) then
        Bit_Num <= Bit_Num + 1;                      -- counts the number of bits received
        Data_Sig <= Data_Sig(1 to 8) & Prev_Val   ;  -- receive the bit
        if (Bit_Num = x"9") then    
          Bit_Num <= x"0";
          if (Prev_Val = '1') then
            Byte_Ready <= '1';
            Cable_Prob <= false;
          else                                       -- Com cable disconnected
            Cable_Prob <= true;
            Byte_Ready <= '0';
          end if;
        end if;
      else
        Byte_Ready <= '0';
        Cable_Prob <= false;
      end if;
    end if;
  end process Receive_Bit;
 
  RxD_Data <= Data_Sig(0 to 7);
  RxD_Boot <= '1' when FSM_RxD_Out = "000" else
              '0';
  RxD_Error  <= '1' when FSM_RxD_Out = "011" else
              '0';
-- Serial Receiver (RxD) Ends

-- Serial Transmitter (TxD)
  pulser: process(Clk, Reset)                        -- Converts Start_TxD to a pulse independent of its length
  begin
    if (Reset = '1') then
      Start_Pulse <= '0';
      Start_Sig <='0';
    elsif (rising_edge(Clk)) then
      Start_Sig <= Start_TxD;
      if (Start_TxD = '1' and Start_Sig = '0') then
        Start_Pulse <= '1';
      else
        Start_Pulse <= '0';
      end if;
    end if;
  end process pulser;
  
-- TxD Control FMS begins
  sync_proc_TxD: process(Clk, Reset, NS_TxD)
  begin
    if (Reset = '1') then
      PS_TxD <= LoadTxD;
    elsif (rising_edge(Clk)) then
      PS_TxD <= NS_TxD;
    end if;
  end process sync_proc_TxD;

  comb_proc_TxD: process(PS_TxD, Start_Pulse, TxD_Sent)
  begin
    FSM_TxD_Out <= '1';             -- pre assignment to prevent latch
    case PS_TxD is
      when LoadTxD =>			          -- LoadTxD (initial) state
        FSM_TxD_Out <= '1';
        if (Start_Pulse = '1') then
          NS_TxD <= SendTxD;
        else
          NS_TxD <= LoadTxD;
        end if;
      when SendTxD =>			          -- SendTxD state
        FSM_TxD_Out <= '0';
        if (TxD_Sent = true) then
          NS_TxD <= LoadTxD;
        else
          NS_TxD <= SendTxD;
        end if;
      when Others =>
        FSM_TxD_Out <= '1';
        NS_TxD <= LoadTxD;
    end case;
  end process comb_proc_TxD;
  
  Next_TxDat <= FSM_TxD_Out;
  TxD <= TxD_ShiftReg(0);

  baud_generator: process(Clk, Reset, FSM_TxD_Out)
  begin
    if (Reset = '1' or FSM_TxD_Out = '1') then
      Baud <= (others =>'0');
    elsif(rising_edge(Clk)) then
      if (FSM_TxD_Out = '0') then
        Baud <= Baud + 1;
        Next_Bit <= false;
        if (Baud = x"C") then                              -- Baud rate is 921600bps aprox count from 0 is 13 decimal
          Baud <= (others =>'0');
          Next_Bit <= true;
        end if;
      end if;
    end if;
    end process baud_generator;
  
  send_TxD: Process(Clk, Reset)
  begin
    if (Reset = '1') then
      Bit_Count <= x"0";
    elsif(rising_edge(Clk)) then
      if (FSM_TxD_Out = '1') then
        TxD_ShiftReg <= "10" & TxD_Data & '1';            -- Load TxD data in parallel with contol bits
        TxD_Sent <= false;
      else
        if (Next_Bit= true) then
          Bit_Count <= Bit_Count + 1;
          if (Bit_Count = x"9") then                      -- if bits chunck (8 bits data, 2 bits control) has been sent
            Bit_Count <= x"0";
            TxD_Sent <= true;
          else
            TxD_ShiftReg <= TxD_ShiftReg(1 to 10) & '0';  -- send each bit serially
          end if;
        end if;
      end if;
    end if;
  end process send_TxD;
-- Serial Transmitter (TxD) Ends

end architecture Behavioral;
