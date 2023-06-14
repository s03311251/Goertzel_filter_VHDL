-- https://vhdlguide.com/2017/09/22/textio/

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.FIXED_PKG.ALL;
-- USE IEEE.MATH_REAL.ALL;
USE STD.TEXTIO.ALL;

ENTITY goertzel_tb IS
END goertzel_tb;

ARCHITECTURE testbench_arch OF goertzel_tb IS

    -- https://groups.google.com/g/comp.lang.vhdl/c/KV2s6_dDHDk
    FUNCTION to_100_char(string_in : STRING) RETURN STRING IS
        VARIABLE V                     : STRING(1 TO 100) := (OTHERS => ' ');
    BEGIN
        IF string_in'length > 100 THEN
            RETURN string_in(1 TO 100);
        ELSE
            V(1 TO string_in'length) := string_in;
            RETURN V;
        END IF;
    END to_100_char;

    TYPE STRING_LIST IS ARRAY (NATURAL RANGE <>) OF STRING(1 TO 100);

    CONSTANT INPUT_DIR    : STRING      := "test_cases/input/";
    CONSTANT EXPECTED_DIR : STRING      := "test_cases/expected/";
    CONSTANT TEST_CASE    : STRING_LIST := (
        to_100_char("sine_wave_50kHz_0deg.txt" & NUL),
        to_100_char("sine_wave_50kHz_0deg.txt" & NUL)
    );
    CONSTANT LINE_BW : POSITIVE := 16;
    CONSTANT CLK_T   : TIME     := 10 ns;

    SIGNAL clk     : STD_LOGIC := '0';
    SIGNAL rst     : STD_LOGIC := '0';
    SIGNAL eof     : STD_LOGIC := '0';
    SIGNAL sigterm : STD_LOGIC := '0';

    -- for DUT
    CONSTANT N            : POSITIVE                    := 100;
    CONSTANT SIG_BW       : POSITIVE                    := 14;
    CONSTANT INT_BW       : POSITIVE                    := 18;
    CONSTANT LSB_TRUNCATE : POSITIVE                    := 5;
    CONSTANT COEFF        : SFIXED(2 DOWNTO 3 - INT_BW) := to_sfixed(1.90211303259031, 2, 3 - INT_BW);
    SIGNAL Sample_SI      : UNSIGNED(SIG_BW - 1 DOWNTO 0);
    -- SIGNAL Magnitude_SO   : SIGNED(17 DOWNTO 0);
    SIGNAL Prod_SO   : SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
    SIGNAL Prod_q_SO : SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
    SIGNAL En_SI     : STD_LOGIC;
    SIGNAL Done_SO   : STD_LOGIC;

    -- File I/O
    FILE fptr : text;

    COMPONENT goertzel IS
        GENERIC (
            N            : POSITIVE                    := 100; -- Number of samples
            SIG_BW       : POSITIVE                    := 14;  -- bit width for input signal
            INT_BW       : POSITIVE                    := 18;  -- bit width for internal data
            LSB_TRUNCATE : POSITIVE                    := 5;   -- truncate internal data's LSB to avoid overflow
            COEFF        : SFIXED(2 DOWNTO 3 - INT_BW) := to_sfixed(1.90211303259031, 2, 3 - INT_BW)
        );
        PORT (
            Clk_CI    : IN STD_LOGIC;
            Rst_RBI   : IN STD_LOGIC;
            Sample_SI : IN UNSIGNED(SIG_BW - 1 DOWNTO 0);
            Prod_SO   : OUT SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
            Prod_q_SO : OUT SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
            En_SI     : IN STD_LOGIC;
            Done_SO   : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN

    ClockGenerator : PROCESS
    BEGIN
        clkloop : LOOP
            WAIT FOR CLK_T;
            clk <= NOT clk;
            IF sigterm = '1' THEN
                EXIT;
            END IF;
        END LOOP clkloop;
        WAIT;
    END PROCESS;

    rst <= '1', '0' AFTER 100 ns;

    GetData_proc : PROCESS

        VARIABLE fstatus : file_open_status;

        VARIABLE file_line : line;
        VARIABLE var_data  : UNSIGNED(LINE_BW - 1 DOWNTO 0);

    BEGIN

        -- initialize

        var_data := (OTHERS => '0');
        eof       <= '0';
        Sample_SI <= (OTHERS => '0');
        En_SI     <= '0';
        WAIT UNTIL rst = '0';

        -- open input signal files

        FOR i IN TEST_CASE'RANGE LOOP
            REPORT "List element " & INTEGER'image(i) & ": " & TEST_CASE(i);

            file_open(fstatus, fptr, INPUT_DIR & TEST_CASE(i), read_mode);

            WHILE (NOT endfile(fptr)) LOOP
                WAIT UNTIL clk = '1';
                En_SI <= '1';
                readline(fptr, file_line);
                hread(file_line, var_data); -- hex
                Sample_SI <= resize(var_data, Sample_SI'LENGTH);
            END LOOP;

            file_close(fptr);
            En_SI <= '0';
            WAIT UNTIL Done_SO = '1';
            -- WAIT FOR 1000 ns;
        END LOOP;

        -- terminate

        WAIT UNTIL rising_edge(clk);
        eof     <= '1';
        sigterm <= '1';
        WAIT;
    END PROCESS;

    DUT : goertzel
    GENERIC MAP(
        N            => N,
        SIG_BW       => SIG_BW,
        INT_BW       => INT_BW,
        LSB_TRUNCATE => LSB_TRUNCATE,
        COEFF        => COEFF
    )
    PORT MAP(

        Clk_CI    => clk,
        Rst_RBI   => rst,
        Sample_SI => Sample_SI,
        Prod_SO   => Prod_SO,
        Prod_q_SO => Prod_q_SO,
        En_SI     => En_SI,
        Done_SO   => Done_SO
    );
END testbench_arch;