ghdl -i --std=08 *.vhd && ghdl -m --std=08 goertzel_tb && ./goertzel_tb --wave=test.ghw && gtkwave test.ghw view.gtkw
