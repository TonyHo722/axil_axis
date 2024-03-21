.PHONY:sim clean wave w

sim:
	xvlog -sv -i ../ tb_test.v -f filelist
	xelab tb_test -debug typical --snapshot tb_test_xelab --timescale 1ns/1ns
	xsim tb_test_xelab --tclbatch log_wave.tcl

clean:
	- rm vivado*.log vivado*.jou
	- rm xsim*.log xsim*.jou
	- rm xvlog.* xelab.*
	- rm -rf xsim.dir
	- rm -rf .Xil

wave:
	# gtkwave top_bench.vcd &
	vivado -source open_wave.tcl &
w:	wave
