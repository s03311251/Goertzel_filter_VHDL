LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- for cos function, which is for constants only, hence still synthesizable
USE IEEE.math_real.ALL;

ENTITY goertzel IS
    GENERIC (
        N   : POSITIVE := 100; -- Number of samples
        F_S : POSITIVE := 1E6; -- Sampling frequency
        K   : POSITIVE := 50E3 -- Target frequency component index
    );
    PORT (
        Clk_CI       : IN STD_LOGIC;
        Rst_RBI      : IN STD_LOGIC;
        Sample_SI    : IN UNSIGNED(13 DOWNTO 0);
        Magnitude_SO : OUT SIGNED(17 DOWNTO 0)
    );
END ENTITY goertzel;

ARCHITECTURE rtl OF goertzel IS
    CONSTANT SCALE_FACTOR : real := 2.0 / real(N);                           -- Scaling factor
    CONSTANT Coeff        : real := 2.0 * cos(2.0 * pi * real(K) / real(N)); -- Coefficient

    SIGNAL Q_D, Qprev_D : SIGNED(17 DOWNTO 0);
    SIGNAL Iprod_D      : SIGNED(17 DOWNTO 0);

BEGIN
    PROCESS (Clk_CI)
    BEGIN
        IF rising_edge(Clk_CI) THEN
            IF Rst_RBI = '1' THEN
                Qprev_D <= (OTHERS => '0');
                Q_D     <= (OTHERS => '0');
                Iprod_D <= (OTHERS => '0');
            ELSE
                Iprod_D <= SIGNED(Sample_SI) + Coeff * Q_D - Qprev_D;
                Qprev_D <= Q_D;
                Q_D     <= Iprod_D;
            END IF;
        END IF;
    END PROCESS;

    Magnitude_SO <= STD_LOGIC_VECTOR(resize(ABS(Qprev_D), Magnitude_SO'length)) WHEN Rst_RBI = '1' ELSE
        STD_LOGIC_VECTOR(resize(scale_factor * ABS(Qprev_D), Magnitude_O'length));
END ARCHITECTURE rtl;