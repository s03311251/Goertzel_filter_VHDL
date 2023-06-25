LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
-- for constant calculation only (using clog2()), still synthesizable
USE IEEE.MATH_REAL.ALL;

ENTITY goertzel IS
    GENERIC (
        N         : POSITIVE := 100; -- Number of samples
        SIG_BW    : POSITIVE := 14;  -- bit width for input signal
        INT_BW    : POSITIVE := 18;  -- bit width for internal data
        LSB_TRUNC : POSITIVE := 5;   -- truncate internal data's LSB to avoid overflow
        MAG_TRUNC : POSITIVE := 11;  -- truncate final result (Magnitude_sq_SO)

        -- Coefficient for multiplication with Prod_q_D = 2cos(2pi Fk/Fs)
        --
        -- Sampling frequency (Fs) = 1 MHz
        -- Target frequency (Fk) = 50 kHz
        -- 2cos(2pi Fk/Fs) = 2 * cos (2pi * 50E3 / 1E6) = 1.90211303259031
        -- 1.90211303259031 -> rounded to 1.9021148681640625 = 0x1E6F1 * 2^-16
        COEFF : SIGNED(INT_BW - 1 DOWNTO 0) := "01" & x"E6F1";
        -- # of bits of fractional part of COEFF
        COEFF_F : POSITIVE := INT_BW - 2
    );
    PORT (
        Clk_CI  : IN STD_LOGIC;
        Rst_RBI : IN STD_LOGIC;

        -- Signals
        -- offset binary numbers
        -- 1st sample should arrive the same clk cycle as the rising edge of En_SI
        Sample_SI : IN UNSIGNED(SIG_BW - 1 DOWNTO 0);

        -- output in terms of (magnitude^2 / 2^21)
        -- (maximum value of magnitude^2 is between 2^37 to 2^38)
        Magnitude_sq_SO : OUT SIGNED(INT_BW - 1 DOWNTO 0);

        -- Controls
        -- enable, active high
        En_SI : IN STD_LOGIC;
        -- active high, keep high for 1 clk cycle when finished
        Done_SO : OUT STD_LOGIC
    );
END ENTITY goertzel;

ARCHITECTURE behavioural OF goertzel IS

    -- for bit width calculation
    FUNCTION clog2(
        num : IN POSITIVE
    )
        RETURN POSITIVE IS
        VARIABLE num_in_log2 : POSITIVE;
    BEGIN
        num_in_log2 := POSITIVE(ceil(log2(REAL(num))));
        RETURN num_in_log2;
    END FUNCTION clog2;

    -- to count when the process finishes
    SIGNAL Cnt_D : UNSIGNED(clog2(N) - 1 DOWNTO 0) := (OTHERS => '0');
    -- state of the entity
    SIGNAL Active_D : STD_LOGIC := '0';
    -- intermediate result, delayed (z^-1) Prod
    SIGNAL Prod_debug : REAL;

    SIGNAL w0, w1_D, w2_D : SIGNED(INT_BW - 1 DOWNTO 0);
    -- Sample_SI + COEFF * w2_D - Prod_qq_D
    SIGNAL Sum          : SIGNED(INT_BW + LSB_TRUNC - 1 DOWNTO 0);
    SIGNAL Magnitude_sq : SIGNED(INT_BW - 1 DOWNTO 0);

BEGIN
    -- calculate the intermediate result
    -- COEFF: (INT_BW - COEFF_F - 1 DOWNTO -COEFF_F) -> (1 DOWNTO -16)
    -- Prod_q_D: (INT_BW + LSB_TRUNC - 1 DOWNTO LSB_TRUNC -> 22 DOWNTO 5)
    -- product: ((INT_BW - COEFF_F - 1) + (INT_BW + LSB_TRUNC - 1)) DOWNTO -COEFF_F - (-LSB_TRUNC)) -> (23 DOWNTO -11)
    -- take interger part -> shift Multi_prod right by 11 bits (COEFF_F - LSB_TRUNC)
    Sum <=
        resize(SIGNED('0' & Sample_SI), Sum'LENGTH) +
        resize(shift_right(COEFF * w1_D, COEFF_F - LSB_TRUNC), Sum'LENGTH) -
        shift_left(resize(w2_D, Sum'LENGTH), LSB_TRUNC);
    w0 <= Sum(INT_BW + LSB_TRUNC - 1 DOWNTO LSB_TRUNC);

    -- results has been shifted by 2*LSB_TRUNC = 10 bits
    -- MATLAB sim shows that the results take at most 38 bits, hence truncate additional 10 bits to fit into INT_BW (18 bits)
    Magnitude_sq <= resize(shift_right(
        w1_D * w1_D +
        w2_D * w2_D -
        shift_right(w1_D * w2_D * COEFF, COEFF_F),
        MAG_TRUNC), Magnitude_sq'LENGTH);

    PROCESS (Clk_CI)
        VARIABLE Active_V : STD_LOGIC;
        VARIABLE debug    : UNSIGNED(47 DOWNTO 0) := x"ABCDEF012345";
    BEGIN
        IF rising_edge(Clk_CI) THEN
            IF Rst_RBI = '1' THEN
                Cnt_D    <= (OTHERS => '0');
                Active_D <= '0';
                w1_D     <= (OTHERS => '0');
                w2_D     <= (OTHERS => '0');
                Done_SO  <= '0';
            ELSE
                Active_V := Active_D;
                Done_SO <= '0';
                Cnt_D   <= Cnt_D + 1;

                -- calculated starts
                IF (Active_V = '0' AND En_SI = '1') THEN
                    Active_V := '1';
                    Cnt_D <= (OTHERS => '0');
                END IF;

                -- store intermediate result
                IF (Active_V = '1') THEN
                    w1_D <= w0;
                    w2_D <= w1_D;
                ELSE
                    w1_D <= (OTHERS => '0');
                    w2_D <= (OTHERS => '0');
                END IF;

                -- calculation finished
                -- N - 1 because:
                -- index of Cnt_D starts from 0 -> -1
                -- Cnt_D starts counting 2 clk cycles after 1st sample arrives -> -2
                -- test bench is fetching Prod_SO 1 clk cycle before -> +1
                -- output to FF -> +1
                IF (Active_V = '1' AND Cnt_D = to_unsigned(N - 1, Cnt_D'LENGTH)) THEN
                    Active_V := '0';
                    Done_SO <= '1';
                END IF;

                Active_D <= Active_V;
            END IF;

            -- output to FF for better timing
            -- reset is unnecessary, as the output is guard by Done_SO, also save routing resource
            Magnitude_sq_SO <= Magnitude_sq;
        END IF;
    END PROCESS;
END behavioural;