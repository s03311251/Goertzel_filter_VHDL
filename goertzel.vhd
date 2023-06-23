LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
-- for constant calculation only (using clog2()), still synthesizable
USE IEEE.MATH_REAL.ALL;

ENTITY goertzel IS
    GENERIC (
        N            : POSITIVE := 100; -- Number of samples
        SIG_BW       : POSITIVE := 14;  -- bit width for input signal
        INT_BW       : POSITIVE := 18;  -- bit width for internal data
        LSB_TRUNCATE : POSITIVE := 5;   -- truncate internal data's LSB to avoid overflow

        -- Coefficient for multiplication with Prod_q_D = 2cos(2pi Fk/Fs)
        --
        -- Sampling frequency (Fs) = 1 MHz
        -- Target frequency (Fk) = 50 kHz
        -- 2cos(2pi Fk/Fs) = 2 * cos (2pi * 50E3 / 1E6) = 1.90211303259031
        -- 1.90211303259031 -> rounded to 1.902099609375 = 0x1E6F1 * 2^-16
        COEFF : SIGNED(INT_BW - 1 DOWNTO 0) := "01" & x"E6F1";
        -- # of bits of fractional part of COEFF
        COEFF_F : POSITIVE := INT_BW - 2

        -- -- coefficient for Magnitude_SO calculation = e^(-j 2pi Fk/Fs)
        -- -- = e^(-j * 2pi * 50E3 / 1E6)
        -- WNK
    );
    PORT (
        Clk_CI  : IN STD_LOGIC;
        Rst_RBI : IN STD_LOGIC;

        -- Signals
        -- offset binary numbers
        -- 1st sample should arrive the same clk cycle as the rising edge of En_SI
        Sample_SI : IN UNSIGNED(SIG_BW - 1 DOWNTO 0);
        -- Magnitude_SO : OUT SIGNED(17 DOWNTO 0);
        w0_SO : OUT SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
        w1_SO : OUT SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);

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
    -- COEFF * w2_D
    SIGNAL Multi_proc : SIGNED(INT_BW * 2 - 1 DOWNTO 0);
    -- Sample_SI + COEFF * w2_D - Prod_qq_D
    SIGNAL Sum : SIGNED(INT_BW + LSB_TRUNCATE - 1 DOWNTO 0);
BEGIN

    -- Output
    w0_SO <= w0 & (LSB_TRUNCATE - 1 DOWNTO 0   => '0');
    w1_SO <= w1_D & (LSB_TRUNCATE - 1 DOWNTO 0 => '0');

    -- calculate the intermediate result
    -- Prod_debug <= to_real(
    --     -- to_sfixed(SIGNED('0' & Sample_SI), Prod'HIGH, 0));
    --     resize(to_sfixed(SIGNED('0' & Sample_SI), Prod'HIGH, 0) +
    --     COEFF * Prod_q_D -
    --     Prod_qq_D, Prod'HIGH, 0));
    -- -- to_sfixed(SIGNED('0' & Sample_SI), Prod'HIGH, 0) +
    -- -- COEFF * Prod_q_D -
    -- -- Prod_qq_D);

    Multi_proc <= COEFF * w1_D;
    -- COEFF: (INT_BW - COEFF_F - 1 downto -COEFF_F) -> (1 downto -16)
    -- Prod_q_D: (INT_BW + LSB_TRUNCATE - 1 downto LSB_TRUNCATE -> 22 downto 5)
    -- Multi_prod: ((INT_BW - COEFF_F - 1) + (INT_BW + LSB_TRUNCATE - 1)) downto -COEFF_F - (-LSB_TRUNCATE)) -> (23 downto -11)
    -- take those to the right hand side of decimal point -> shift Multi_prod left by 11 bits (COEFF_F - LSB_TRUNCATE)
    Sum <=
        resize(SIGNED('0' & Sample_SI), Sum'LENGTH) +
        Multi_proc(INT_BW + COEFF_F - 1 DOWNTO COEFF_F - LSB_TRUNCATE) -
        shift_left(resize(w2_D, Sum'LENGTH), LSB_TRUNCATE);
    w0 <= Sum(INT_BW + LSB_TRUNCATE - 1 DOWNTO LSB_TRUNCATE);

    -- Magnitude_SO <= STD_LOGIC_VECTOR(resize(ABSQQ_D, Magnitude_SO'length)) WHEN Rst_RBI = '1' ELSE
    -- STD_LOGIC_VECTOR(resize(scale_factor * ABSQQ_D, Magnitude_O'length));

    PROCESS (Clk_CI)
        VARIABLE Active_V : STD_LOGIC;
    BEGIN
        IF rising_edge(Clk_CI) THEN
            -- REPORT "w0_SO " & INTEGER'image(to_integer(w0_SO)) &
            --     " Sample_SI " & INTEGER'image(to_integer(to_sfixed(SIGNED('0' & Sample_SI)))) &
            --     " COEFF*w2_D " & INTEGER'image(to_integer(Multi_proc(INT_BW + COEFF_F - 1 DOWNTO COEFF_F - LSB_TRUNCATE))) &
            --     " w2_D " & INTEGER'image(to_integer(resize(w1_D, Sum'LENGTH))) &
            --     " Prod_qq_D " & INTEGER'image(to_integer(resize(w2_D, Sum'LENGTH)));

            -- REPORT "ROUND TO EVEN NO. " & INTEGER'image(to_integer(to_sfixed(-1.5, 32, 0)));

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
                -- N - 2 because:
                -- index of Cnt_D starts from 0 -> -1
                -- Cnt_D starts counting 2 clk cycles after 1st sample arrives -> -2
                -- test bench is fetching Prod_SO 1 clk cycle before  -> +1
                IF (Active_V = '1' AND Cnt_D = to_unsigned(N - 2, Cnt_D'LENGTH)) THEN
                    Active_V := '0';
                    Done_SO <= '1';
                END IF;

                Active_D <= Active_V;
            END IF;
        END IF;
    END PROCESS;
END behavioural;