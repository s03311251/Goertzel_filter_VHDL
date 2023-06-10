LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY goertzel_tb IS
END ENTITY goertzel_tb;

ARCHITECTURE tb_arch OF goertzel_tb IS
    SIGNAL Clk_TB    : STD_LOGIC             := '0';
    SIGNAL Rst_TB    : STD_LOGIC             := '1';
    SIGNAL Sample_TB : UNSIGNED(13 DOWNTO 0) := (OTHERS => '0');
    SIGNAL Mag_TB    : SIGNED(17 DOWNTO 0);

    CONSTANT N      : POSITIVE := 128;                 -- Number of samples
    CONSTANT k      : POSITIVE := 20;                  -- Target frequency component index
    CONSTANT Fs     : POSITIVE := 1000;                -- Sampling frequency
    CONSTANT T_file : STRING   := "input_samples.txt"; -- Input data file
    CONSTANT G_file : STRING   := "ground_truth.txt";  -- Ground truth data file

    TYPE SampleArray IS ARRAY(NATURAL RANGE <>) OF INTEGER;
    FILE Tfile, Gfile     : text;
    VARIABLE Tline, Gline : line;
    VARIABLE Tdata, Gdata : INTEGER;
    VARIABLE ErrorCount   : NATURAL := 0;

BEGIN
    Clk_TB <= NOT Clk_TB AFTER 5 ns; -- Clock generation

    DUT : ENTITY work.Goertzel
        GENERIC MAP(
            N  => N,
            k  => k,
            Fs => Fs
        )
        PORT MAP(
            Clk_RBI     => Clk_TB,
            Rst_CI      => Rst_TB,
            Sample_I    => Sample_TB,
            Magnitude_O => Mag_TB
        );

    -- Open input and ground truth files
    file_open(Tfile, T_file, read_mode);
    file_open(Gfile, G_file, read_mode);

    -- Read input and ground truth values from files
    WHILE NOT endfile(Tfile) LOOP
        readline(Tfile, Tline);
        read(Tline, Tdata);
        Sample_TB <= TO_UNSIGNED(Tdata, Sample_TB'length);

        WAIT FOR 10 ns; -- Simulate processing time

        -- Read expected output value
        readline(Gfile, Gline);
        read(Gline, Gdata);

        -- Compare output with expected value
        IF Mag_TB /= TO_SIGNED(Gdata, Mag_TB'length) THEN
            REPORT "Output mismatch: Expected " & INTEGER'image(Gdata) & ", Got " & INTEGER'image(to_integer(Mag_TB));
            ErrorCount := ErrorCount + 1;
        END IF;
    END LOOP;

    -- Close input and ground truth files
    file_close(Tfile);
    file_close(Gfile);

    -- Report test summary
    REPORT "Test completed. Total errors: " & NATURAL'image(ErrorCount);
    WAIT;
END ARCHITECTURE tb_arch;