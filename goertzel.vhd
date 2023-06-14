LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.FIXED_PKG.ALL;
-- for constant calculation only (clog2()), still synthesizable
USE IEEE.MATH_REAL.ALL;

ENTITY goertzel IS
    GENERIC (
        N      : POSITIVE := 100; -- Number of samples
        SIG_BW : POSITIVE := 14;  -- bit width for input signal
        INT_BW : POSITIVE := 64;  -- bit width for internal data

        -- Coefficient for multiplication with Prod_q_D = 2cos(2piK/Fs)
        --
        -- Sampling frequency (Fs) = 1 MHz
        -- Target frequency (K) = 50 kHz
        -- 2cos(2piK/Fs) = 2 * cos (2pi * 50E3 / 1E6) = 1.90211303259031 < 2
        -- 2 bits for integer part, 1 bit for sign bit
        -- COEFF : SIGNED(INT_BW - SIG_BW + 1 DOWNTO 0) := to_unsigned(INTEGER(1.90211303259031 * (2 ** (INT_BW - SIG_BW)), 5));
        COEFF : SFIXED(2 DOWNTO 3 - INT_BW) := to_sfixed(1.90211303259031, 1, 2 - INT_BW)

        -- -- coefficient for Magnitude_SO calculation = e^(-j 2piK/Fs)
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
        -- TODO
        Magnitude_SO : OUT SIGNED(17 DOWNTO 0);

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
        num_in_log2 := POSITIVE(ceil(log2(real(num))));
        RETURN num_in_log2;
    END FUNCTION clog2;

    -- to count when the process finishes
    SIGNAL Cnt_D : UNSIGNED(clog2(N) - 1 DOWNTO 0) := (OTHERS => '0');
    -- state of the entity
    SIGNAL Active_D : STD_LOGIC := '0';
    -- intermediate result, delayed (z^-1) Prod
    SIGNAL Prod, Prod_q_D, Prod_qq_D : SIGNED(INT_BW - 1 DOWNTO 0);
BEGIN
    Prod <=
        SIGNED(resize(Sample_SI, Prod'LENGTH)) +
        SIGNED(resize(COEFF * SFIXED(Prod_q_D), INT_BW - 1, 0)) -
        Prod_qq_D;

    Magnitude_SO <= SIGNED(resize(Cnt_D, Magnitude_SO'LENGTH));
    -- Magnitude_SO <= STD_LOGIC_VECTOR(resize(ABSQQ_D, Magnitude_SO'length)) WHEN Rst_RBI = '1' ELSE
    -- STD_LOGIC_VECTOR(resize(scale_factor * ABSQQ_D, Magnitude_O'length));

    PROCESS (Clk_CI)
        VARIABLE Active_V : STD_LOGIC;
    BEGIN
        IF rising_edge(Clk_CI) THEN
            IF Rst_RBI = '1' THEN
                Cnt_D     <= (OTHERS => '0');
                Active_D  <= '0';
                Prod_q_D  <= (OTHERS => '0');
                Prod_qq_D <= (OTHERS => '0');
                Done_SO   <= '0';
            ELSE
                Active_V := Active_D;
                Done_SO <= '0';
                Cnt_D   <= Cnt_D + 1;

                -- calculated starts
                IF (Active_V = '0' AND En_SI = '1') THEN
                    Active_V := '1';
                    Cnt_D <= (OTHERS => '0');
                END IF;

                -- calculation finished
                IF (Active_V = '1' AND Cnt_D = to_unsigned(N, Cnt_D'LENGTH)) THEN
                    Active_V := '0';
                    Done_SO <= '1';
                END IF;

                IF (Active_V = '1') THEN
                    Prod_q_D  <= Prod;
                    Prod_qq_D <= Prod_q_D;
                ELSE
                    Prod_q_D  <= (OTHERS => '0');
                    Prod_qq_D <= (OTHERS => '0');
                END IF;

                Active_D <= Active_V;
            END IF;
        END IF;
    END PROCESS;
END behavioural;