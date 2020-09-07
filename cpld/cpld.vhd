----------------------------------------------------------------------------------
-- Company:        StarDot Community
-- Engineer:       Roland Leurs
--
-- Create Date:    16:11:13 04/27/2020
-- Design Name:
-- Module Name:    cpld - Behavioral
-- Project Name:   Elk - WiFi
-- Target Devices: XC9572XL
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpld is
   generic(
      clk_freq : integer := 625;   -- input frequency
      freq     : integer := 144    -- desired output frequency
   );

   port(
      A        : in  std_logic_vector(7 downto 0);
      clk_in   : in  std_logic;  -- input clock of clk_freq
      PH12     : in  std_logic;  -- Phi1/2 signal
      ERnW     : in  std_logic;  -- Electron R/nW signal
      MRnW     : in  std_logic;  -- Master R/nW signal
      madet    : in  std_logic;  -- Master detect (1 = Elk, 0 = Master)
      nPGFC    : in  std_logic;  -- Page &FC enable
      ROMQA    : in  std_logic;  -- ROM bank select
      nROMOE   : in  std_logic;  -- Rom Enable
      tx_a     : in  std_logic;  -- TX port A
      rx_a     : in  std_logic;  -- RX port A
      tx_b     : in  std_logic;  -- TX port B
      rx_b     : in  std_logic;  -- RX port B
      reset_in : in  std_logic;  -- Reset signal

      cs_uart  : out std_logic;  -- UART enable
      cs_rom   : out std_logic;  -- EEPROM enable
      cs_pareg : out std_logic;  -- Page Register enable
      ior      : out std_logic;  -- IOR (nrds)
      iow      : out std_logic;  -- IOW (nwds)
      clk_uart : out std_logic;  -- UART ~1.8432MHz clock
      led_rx_a : out std_logic;  -- LED RX port A
      led_tx_a : out std_logic;  -- LED TX port A
      led_rx_b : out std_logic;  -- LED RX port B
      led_tx_b : out std_logic;  -- LED TX port B
      rx_esp   : out std_logic;  -- Level shifted output of TXB
      reset_out: out std_logic   -- Inverted reset for the UART
   );
end cpld;

architecture Behavioral of cpld is
   constant increment  : integer := (freq*2)-clk_freq;
   signal accumulator  : signed(10 downto 0);
   signal phase_change : std_logic := '0';

   type  clkCounter is range 0 to 200000;
   signal clk18        : STD_LOGIC;
   signal hz10, hz10_1 : STD_LOGIC;
   signal trigger_rx_a : STD_LOGIC := '0';
   signal trigger_rx_b : STD_LOGIC := '0';
   signal trigger_tx_a : STD_LOGIC := '0';
   signal trigger_tx_b : STD_LOGIC := '0';
   signal wifi_disable : STD_LOGIC := '0';

begin
   -- Clock divider
   -- https://gist.github.com/RickKimball/45d0753a900f92d5fdd836746062588c
   process(clk_in, reset_in)
   begin
      if (reset_in = '0') then
         accumulator <= to_signed(0,11);
         phase_change <= '0';
      else
         if rising_edge(clk_in) then
            if ( accumulator + increment >= 0) then
               accumulator <= accumulator + increment;
               phase_change <= not phase_change;
               if madet = '0' then
                   -- Master, base clock is 8MHz
                   clk18 <= phase_change;
               else
                   -- Electron, base clock is 16MHz, so half output clock
                   clk18 <= phase_change xor clk18;
               end if;
            else
               accumulator <= accumulator + to_signed(freq * 2, 10);    --- This line changed
            end if;
         end if;
      end if;
   end process;

   clk_uart <= clk18;

   -- Chip Control logic
   process(nPGFC, A, PH12, ERnW, MRnW, madet, nROMOE, ROMQA, reset_in, wifi_disable)
   begin
      -- Platform independant control logic
      -- Enable UART at &FC3x
      -- and &FCFF (paged ram register)
      if nPGFC = '0' and (A(7 downto 4) = "0011" or A(7 downto 0) = "11111111") then
         cs_uart <= '0';
      else
         cs_uart <= '1';
      end if;
      -- Enable ROM
      if nROMOE = '0' and (madet = '1' or ERnW = '1') then
         cs_rom <= '0';
      else
         cs_rom <= '1';
      end if;
      -- Inverted reset for the UART
      -- but only when wifi is not disabled
      if wifi_disable = '0' then
         reset_out <= not reset_in;
      else
         reset_out <= '0';
      end if;

      -- Platform dependant control logic
      if madet = '1' then -- Electron control logic
         -- Enable Paged Ram Register when writing to &FCFF
         if nPGFC = '0' and A(7 downto 0) = "11111111" and ERnW = '0' then
            cs_pareg <= '0';
         else
            cs_pareg <= '1';
         end if;
         -- IOR (nrds) and IOW (nwds) signals
         if PH12 = '1' and ERnW = '1' then
            IOR <= '0';
         else
            IOR <= '1';
         end if;
         if PH12 = '1' and ERnW = '0' then
            IOW <= '0';
         else
            IOW <= '1';
         end if;
         -- Set/reset wifi_disable by writing to the LSR-B (&FC35) and
         -- MSR-B (&FC36) registers
         if rising_edge(ph12) then
            if nPGFC = '0' and (A(7 downto 1) = "0011010" or A(7 downto 1) = "0011011") and ERnW = '0' then
               wifi_disable <= A(0);
            end if;
         end if;
      else  -- BBC Master control logic
         if nPGFC = '0' and A(7 downto 0) = "11111111" and MRnW = '0' then
            cs_pareg <= '0';
         else
            cs_pareg <= '1';
         end if;
         -- IOR (nrds) and IOW (nwds) signals
         if PH12 = '1' and MRnW = '1' then
            IOR <= '0';
         else
            IOR <= '1';
         end if;
         if PH12 = '1' and MRnW = '0' then
            IOW <= '0';
         else
            IOW <= '1';
         end if;
         -- Set/reset wifi_disable by writing to the LSR-B (&FC35) and
         -- MSR-B (&FC36) registers
         if rising_edge(ph12) then
            if nPGFC = '0' and (A(7 downto 1) = "0011010" or A(7 downto 1) = "0011011") and MRnW = '0' then
               wifi_disable <= A(0);
            end if;
         end if;
      end if;
   end process;

   -- LED Control
   process(clk18)
	variable hz10Cnt : clkCounter := 0;
	begin
		if rising_edge(clk18) then
			-- Clock divider to 10 Hz clock signal
			-- If the input clock is not 1.8432MHz then the 184320 must be adjusted
			if hz10Cnt = 184320 then
				hz10 <= not hz10;
				hz10Cnt := 0;
			else
				hz10Cnt := hz10Cnt + 1;
			end if;
         hz10_1 <= hz10;
		end if;
	end process;

   -- LED controls
   -- The led should go on for 0.1 seconds when there is a state change
   -- on the assigned input pin.

   process(clk18, hz10, hz10_1, rx_a)
   begin
      if rising_edge(clk18) then
         if rx_a = '0' then
            trigger_rx_a <= '1';
         end if;

         -- detection of rising edge on 10hz signal
         if hz10_1 = '0' and hz10 = '1' then
            led_rx_a <= not trigger_rx_a;
            trigger_rx_a <= '0';
         end if;
      end if;
   end process;

   process(clk18, hz10, hz10_1, tx_a)
   begin
      if rising_edge(clk18) then
         if tx_a = '0' then
            trigger_tx_a <= '1';
         end if;

         -- detection of rising edge on 10hz signal
         if hz10_1 = '0' and hz10 = '1' then
            led_tx_a <= not trigger_tx_a;
            trigger_tx_a <= '0';
         end if;
      end if;
   end process;

   process(clk18, hz10, hz10_1, rx_b)
   begin
      if rising_edge(clk18) then
         if rx_b = '0' then
            trigger_rx_b <= '1';
         end if;

         -- detection of rising edge on 10hz signal
         if hz10_1 = '0' and hz10 = '1' then
            led_rx_b <= not trigger_rx_b;
            trigger_rx_b <= '0';
         end if;
      end if;
   end process;

   process(clk18, hz10, hz10_1, tx_b)
   begin
      if rising_edge(clk18) then
         if tx_b = '0' then
            trigger_tx_b <= '1';
         end if;

         -- detection of rising edge on 10hz signal
         if hz10_1 = '0' and hz10 = '1' then
            led_tx_b <= not trigger_tx_b;
            trigger_tx_b <= '0';
         end if;
      end if;
   end process;

   -- Simple level shifting
   rx_esp <= tx_b;

end Behavioral;
