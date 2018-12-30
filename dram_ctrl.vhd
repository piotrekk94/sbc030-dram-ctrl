library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity dram_ctrl is
	port (
		clk : in std_logic;
		rstn : in std_logic;
		addr : in std_logic_vector(27 downto 0);
		siz0 : in std_logic;
		siz1 : in std_logic;
		rw : in std_logic;
		scs : in std_logic;
		cbreq : in std_logic;
		sterm : out std_logic;
		cback : out std_logic;
		dram_addr : out std_logic_vector(11 downto 0);
		dram_ras : out std_logic_vector(3 downto 0);
		dram_cas : out std_logic_vector(3 downto 0);
		dram_we : out std_logic
	);
end;

architecture arch of dram_ctrl is

type state_type is (idle, ras, cas, term, pre, ref_cas, ref_ras);

signal state : state_type;

signal addr_mux : std_logic := '0';
signal byte_sel : std_logic_vector(3 downto 0);

signal ref_ack : std_logic;
signal ref_req : std_logic;

signal cas_i : std_logic_vector(3 downto 0);
signal ras_i : std_logic_vector(3 downto 0);

signal scs_i, scs_d, scs_dd : std_logic;

signal we_i : std_logic;

begin

	dram_we <= rw or we_i;
	
	cback <= '1';

	dram_addr <= addr(13 downto 2) when addr_mux = '0' else addr(25 downto 14);
	
	byte_sel(0) <= '0' when rw = '1' or addr(1 downto 0) = "00" else '1';

	byte_sel(1) <= '0' when rw = '1' or addr(1 downto 0) = "01" or 
			(addr(1) = '0' and (siz0 = '0' or siz1 = '1')) else '1';

	byte_sel(2) <= '0' when rw = '1' or addr(1 downto 0) = "10" or 
			(addr(1) = '0' and ((siz0 = '0' and siz1 = '0') or 
			(siz0 = '1' and siz1 = '1') or 
			(addr(0) = '1' and siz0 = '0'))) else '1';

	byte_sel(3) <= '0' when rw = '1' or addr(1 downto 0) = "11" or 
			(addr(0) = '1' and siz0 = '1' and siz1 = '1') or 
			(siz0 = '0' and siz1 = '0') or 
			(addr(1) = '1' and siz1 = '1') else '1';
	
	cas_i(0) <= byte_sel(0);
	cas_i(1) <= byte_sel(2);
	cas_i(2) <= byte_sel(1);
	cas_i(3) <= byte_sel(3);
	
	ras_i <= "1110" when addr(27 downto 26) = "00" else
				"1101" when addr(27 downto 26) = "10" else
				"1011" when addr(27 downto 26) = "01" else
				"0111" when addr(27 downto 26) = "11";
	
	
	scs_i <= scs;
	
	process(clk, rstn)
	variable cnt : integer range 0 to 255;
	begin
		if(rstn = '0')then
			ref_req <= '0';
			cnt := 0;
		elsif(rising_edge(clk))then
			if(cnt < 180)then
				cnt := cnt + 1;
			else
				ref_req <= '1';
			end if;
			
			if(ref_ack = '1')then
				ref_req <= '0';
				cnt := 0;
			end if;
		end if;
	end process;
	
	process(clk, rstn)
	begin
		if(rstn = '0')then
			state <= idle;
			ref_ack <= '0';
			addr_mux <= '0';
			dram_ras <= (others => '1');
			dram_cas <= (others => '1');
			sterm <= '1';
		elsif(rising_edge(clk))then
			ref_ack <= '0';
			case state is
			when idle =>
				state <= idle;
				addr_mux <= '0';
				sterm <= '1';
				we_i <= '0';
				dram_ras <= (others => '1');
				dram_cas <= (others => '1');
				if(ref_req = '1')then
					state <= ref_cas;
					ref_ack <= '1';
					we_i <= '1';
					dram_cas <= (others => '0');
				elsif(scs_i = '0')then
					state <= ras;
					dram_ras <= ras_i;
				end if;

			when ras =>
				addr_mux <= '1';
				state <= cas;
			when cas =>
				dram_cas <= cas_i;
				state <= term;
			when term =>
				sterm <= '0';
				state <= pre;

			when ref_cas =>
				dram_ras <= (others => '0');
				state <= ref_ras;
			when ref_ras =>
				state <= pre;

			when pre =>
				dram_ras <= (others => '1');
				dram_cas <= (others => '1');
				sterm <= '1';
				we_i <= '0';
				state <= idle;
			when others =>
				state <= idle;
				addr_mux <= '0';
				we_i <= '0';
				sterm <= '1';
				dram_ras <= (others => '1');
				dram_cas <= (others => '1');
			end case;
		end if;
	end process;
	
end; 
