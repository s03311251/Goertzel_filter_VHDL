-- https://vhdlguide.com/2017/09/22/textio/

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
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
        to_100_char("sine_wave_50kHz_30deg.txt" & NUL),
        to_100_char("sine_wave_50kHz_45deg.txt" & NUL),
        to_100_char("sine_wave_50kHz_90deg.txt" & NUL),
        to_100_char("sine_wave_50kHz_120deg.txt" & NUL),
        to_100_char("sine_wave_49kHz_0deg.txt" & NUL),
        to_100_char("sine_wave_49kHz_30deg.txt" & NUL),
        to_100_char("sine_wave_49kHz_45deg.txt" & NUL),
        to_100_char("sine_wave_49kHz_90deg.txt" & NUL),
        to_100_char("sine_wave_49kHz_120deg.txt" & NUL),
        to_100_char("sine_wave_51kHz_0deg.txt" & NUL),
        to_100_char("sine_wave_51kHz_30deg.txt" & NUL),
        to_100_char("sine_wave_51kHz_45deg.txt" & NUL),
        to_100_char("sine_wave_51kHz_90deg.txt" & NUL),
        to_100_char("sine_wave_51kHz_120deg.txt" & NUL),
        to_100_char("sine_wave_5kHz_0deg.txt" & NUL),
        to_100_char("sine_wave_5kHz_30deg.txt" & NUL),
        to_100_char("sine_wave_5kHz_45deg.txt" & NUL),
        to_100_char("sine_wave_5kHz_90deg.txt" & NUL),
        to_100_char("sine_wave_5kHz_120deg.txt" & NUL),
        to_100_char("sine_wave_200kHz_0deg.txt" & NUL),
        to_100_char("sine_wave_200kHz_30deg.txt" & NUL),
        to_100_char("sine_wave_200kHz_45deg.txt" & NUL),
        to_100_char("sine_wave_200kHz_90deg.txt" & NUL),
        to_100_char("sine_wave_200kHz_120deg.txt" & NUL),
        to_100_char("sine_wave_combined_0deg.txt" & NUL),
        to_100_char("sine_wave_combined_30deg.txt" & NUL),
        to_100_char("sine_wave_combined_90deg.txt" & NUL),
        to_100_char("sine_wave_combined_120deg.txt" & NUL),
        to_100_char("sine_wave_combined_45deg.txt" & NUL),
        to_100_char("rectangular_wave_50kHz_0deg.txt" & NUL),
        to_100_char("rectangular_wave_50kHz_30deg.txt" & NUL),
        to_100_char("rectangular_wave_50kHz_45deg.txt" & NUL),
        to_100_char("rectangular_wave_50kHz_90deg.txt" & NUL),
        to_100_char("rectangular_wave_50kHz_120deg.txt" & NUL),
        to_100_char("rectangular_wave_16kHz_0deg.txt" & NUL),
        to_100_char("rectangular_wave_16kHz_30deg.txt" & NUL),
        to_100_char("rectangular_wave_16kHz_45deg.txt" & NUL),
        to_100_char("rectangular_wave_16kHz_90deg.txt" & NUL),
        to_100_char("rectangular_wave_16kHz_120deg.txt" & NUL),
        to_100_char("rectangular_wave_10kHz_0deg.txt" & NUL),
        to_100_char("rectangular_wave_10kHz_30deg.txt" & NUL),
        to_100_char("rectangular_wave_10kHz_45deg.txt" & NUL),
        to_100_char("rectangular_wave_10kHz_90deg.txt" & NUL),
        to_100_char("rectangular_wave_10kHz_120deg.txt" & NUL),
        to_100_char("rectangular_wave_200kHz_0deg.txt" & NUL),
        to_100_char("rectangular_wave_200kHz_30deg.txt" & NUL),
        to_100_char("rectangular_wave_200kHz_45deg.txt" & NUL),
        to_100_char("rectangular_wave_200kHz_90deg.txt" & NUL),
        to_100_char("rectangular_wave_200kHz_120deg.txt" & NUL),
        to_100_char("triangle_wave_50kHz_0deg.txt" & NUL),
        to_100_char("triangle_wave_50kHz_90deg.txt" & NUL)
    );

    -- for File I/O
    CONSTANT SIG_LINE_BW : POSITIVE := 16; -- SIG_BW, rounded up to nearest multiple of 4
    CONSTANT EXP_LINE_BW : POSITIVE := 20;

    -- (clock period / 2) in simulation time
    CONSTANT CLK_T : TIME := 10 ns;

    -- for simulation
    SIGNAL Eof     : STD_LOGIC := '0';
    SIGNAL Sigterm : STD_LOGIC := '0';

    -- for DUT
    CONSTANT N             : POSITIVE                    := 100;
    CONSTANT SIG_BW        : POSITIVE                    := 14;
    CONSTANT INT_BW        : POSITIVE                    := 18;
    CONSTANT LSB_TRUNC     : POSITIVE                    := 5;
    CONSTANT MAG_TRUNC     : POSITIVE                    := 11;
    CONSTANT C             : SIGNED(INT_BW - 1 DOWNTO 0) := "01" & x"E6F1";
    CONSTANT C_F           : POSITIVE                    := INT_BW - 2;
    SIGNAL Clk_CI          : STD_LOGIC                   := '0';
    SIGNAL Rst_RBI         : STD_LOGIC                   := '0';
    SIGNAL Sample_SI       : UNSIGNED(SIG_BW - 1 DOWNTO 0);
    SIGNAL Magnitude_sq_SO : SIGNED(INT_BW - 1 DOWNTO 0);
    SIGNAL En_SI           : STD_LOGIC;
    SIGNAL Done_SO         : STD_LOGIC;

    -- File I/O
    FILE fptr : text;

    COMPONENT goertzel IS
        GENERIC (
            N         : POSITIVE                    := 100;
            SIG_BW    : POSITIVE                    := 14;
            INT_BW    : POSITIVE                    := 18;
            LSB_TRUNC : POSITIVE                    := 5;
            MAG_TRUNC : POSITIVE                    := 11;
            C         : SIGNED(INT_BW - 1 DOWNTO 0) := "01" & x"E6F1";
            C_F       : POSITIVE                    := INT_BW - 2
        );
        PORT (
            Clk_CI          : IN STD_LOGIC;
            Rst_RBI         : IN STD_LOGIC;
            Sample_SI       : IN UNSIGNED(SIG_BW - 1 DOWNTO 0);
            Magnitude_sq_SO : OUT SIGNED(INT_BW - 1 DOWNTO 0);
            En_SI           : IN STD_LOGIC;
            Done_SO         : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN

    ClockGenerator : PROCESS
    BEGIN
        clkloop : LOOP
            WAIT FOR CLK_T;
            Clk_CI <= NOT Clk_CI;
            IF Sigterm = '1' THEN
                EXIT;
            END IF;
        END LOOP clkloop;
        WAIT;
    END PROCESS;

    Rst_RBI <= '1', '0' AFTER 100 ns;

    GetData_proc : PROCESS

        VARIABLE fstatus : file_open_status;

        VARIABLE file_line    : line;
        VARIABLE var_data     : UNSIGNED(SIG_LINE_BW - 1 DOWNTO 0);
        VARIABLE var_expected : SIGNED(EXP_LINE_BW - 1 DOWNTO 0);
    BEGIN

        -- initialize

        var_data     := (OTHERS => '0');
        var_expected := (OTHERS => '0');
        Eof       <= '0';
        Sample_SI <= (OTHERS => '0');
        En_SI     <= '0';
        WAIT UNTIL Rst_RBI = '0';

        -- open input signal files

        FOR i IN TEST_CASE'RANGE LOOP
            -- open input signal file
            file_open(fstatus, fptr, INPUT_DIR & TEST_CASE(i), read_mode);

            WHILE (NOT endfile(fptr)) LOOP
                WAIT UNTIL Clk_CI = '1';
                En_SI <= '1';
                readline(fptr, file_line);
                hread(file_line, var_data); -- hex
                Sample_SI <= resize(var_data, Sample_SI'LENGTH);
            END LOOP;

            file_close(fptr);

            -- wait for DUT to finish            
            En_SI <= '0';
            WAIT UNTIL Done_SO = '1';
            REPORT "Test case " & INTEGER'IMAGE(i) & ": " & TEST_CASE(i);

            -- open expected result file
            file_open(fstatus, fptr, EXPECTED_DIR & TEST_CASE(i), read_mode);

            WHILE (NOT endfile(fptr)) LOOP
                readline(fptr, file_line);
                hread(file_line, var_expected); -- hex

                -- ASSERT (resize(var_expected, Magnitude_sq_SO'LENGTH) /= Magnitude_sq_SO)
                -- REPORT "PASS" SEVERITY NOTE;
                ASSERT (resize(var_expected, Magnitude_sq_SO'LENGTH) = Magnitude_sq_SO)
                REPORT "FAIL, Expected Magnitude_sq_SO: " & INTEGER'IMAGE(to_integer(var_expected)) & " Actual: " & INTEGER'IMAGE(to_integer(Magnitude_sq_SO)) SEVERITY WARNING;
            END LOOP;

            file_close(fptr);

        END LOOP;

        -- terminate
        WAIT UNTIL rising_edge(Clk_CI);
        Eof     <= '1';
        Sigterm <= '1';
        WAIT;
    END PROCESS;

    DUT : goertzel
    GENERIC MAP(
        N         => N,
        SIG_BW    => SIG_BW,
        INT_BW    => INT_BW,
        LSB_TRUNC => LSB_TRUNC,
        MAG_TRUNC => MAG_TRUNC,
        C         => C,
        C_F       => C_F
    )
    PORT MAP(

        Clk_CI          => Clk_CI,
        Rst_RBI         => Rst_RBI,
        Sample_SI       => Sample_SI,
        Magnitude_sq_SO => Magnitude_sq_SO,
        En_SI           => En_SI,
        Done_SO         => Done_SO
    );
END testbench_arch;