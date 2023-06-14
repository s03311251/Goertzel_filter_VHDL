# Don't read me

![Dreamt-I-Went-Outside Acrylic Smartphone Stand](ninomae_inanis.webp)

Never a bad idea to put an anime girl in your README.

* Illustration: Kouhaku Kuroboshi
* Source: ["Ninomae Ina'nis Birthday Celebration 2023" Merch Complete Set](https://shop.geekjack.net/products/ninomae-inanis-birthday-celebration-2023-merch-complete-set?variant=45094943785206)

Homework for MOD2-02 Microelectronics & HW/SW-Co-Design, Summer Semester 2023

* Folder structure:
  * TODO

* Naming convention in VHDL:
  * Hungarian notation, as mentioned in the lecture slides
  * use capital letters for the first letter of the signal name
  * use all capital letters for constants

  * suffix:
    * `I`/`O`/`B` at the end of the suffix, indicating the direction of the signal
      * `I` for input
      * `O` for output
      * `B` for bidirectional

    * `S`/`C` at the beginning of the suffix, indicating the type of the signal
      * `S` for signal
      * `C` for clock

    * `_D` if internal signal

    * e.g. `Ena_SI`, `Rst_RBI`, `Clk_RBI`

  * Reset: `Rst_CI`
  * Clock: `Clk_RBI`

## References

* Dulik, T. (1999). An FPGA Implementation of Goertzel Algorithm. In: Lysaght, P., Irvine, J., Hartenstein, R. (eds) Field Programmable Logic and Applications. FPL 1999. Lecture Notes in Computer Science, vol 1673. Springer, Berlin, Heidelberg. <https://doi.org/10.1007/978-3-540-48302-1_35>

## ChatGPT

Please write me a synthesisable VHDL implementation of the Goertzel algorithm.
Input: 14 bit unsigned (offset binary numbers)
internal data: 18 bit signed (2‘s complement numbers)
output: 18 bit, magnitude of the frequency component at the target frequency
generic: N, k (target frequency), Fs (sampling frequency)

Remember to apply appropriate scaling.
Use synchronized active-high reset.

Use the following naming convention in VHDL:

* Hungarian notation
* use capital letters for the first letter of the port/signal name
* use all capital letters for constants

* suffix:
  * `I`/`O`/`B` at the end of the suffix, indicating the direction of the signal
    * `I` for input
    * `O` for output
    * `B` for bidirectional

  * `S`/`C` at the beginning of the suffix, indicating the type of the signal
    * `S` for signal
    * `C` for clock

  * `_D` if internal signal

  * e.g. `Ena_SI`, `Rst_RBI`, `Clk_RBI`

* Reset: `Rst_CI`
* Clock: `Clk_RBI`

Also, please write me a testbench for the Goertzel entity above.
It should read several text files containing the input data of different test cases, and also several text files containing the ground truth of output data. The testbench should compare the output of the Goertzel entity with the ground truth, and report where there is an error.
A text file has 1 sample per line, in integer.
name the Goertzel component DUT (device under test).
