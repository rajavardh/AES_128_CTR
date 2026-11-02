all:
	make clean; make sim; 

VCS_CMD_RAND    = vcs -V -R  -full64 -sverilog +v2k -debug_access+all -ntb_opts uvm-1.2 -debug_pp +ntb_random_seed_automatic -override_timescale=1ps/1ps -CFLAGS "-std=c99"
 
sim:
	${VCS_CMD_RAND} \
	+incdir+../../src/globals \
	+incdir+../../src/hvl_top/master/ \
	+incdir+../../src/hdl_top/master_agent_bfm/  \
	+incdir+../../src/hvl_top/env/virtual_sequencer/ \
	+incdir+../../src/hvl_top/test/virtual_sequences/ \
	+incdir+../../src/hvl_top/test/sequences/master_sequences/ \
	+incdir+../../src/hvl_top/test/sequences/slave_sequences/ \
	+incdir+../../src/hvl_top/env \
	+incdir+../../src/hvl_top/slave \
	+incdir+../../src/hvl_top/test \
	+incdir+../../src/hdl_top/slave_agent_bfm \
	+incdir+../../src/hdl_top/apb_if \
	../../src/hvl_top/env/aes_dpi.c \
	../../src/globals/apb_global_pkg.sv \
	../../src/hdl_top/apb_if/apb_if.sv \
	../../src/hvl_top/master/apb_master_pkg.sv \
	../../src/hvl_top/slave/apb_slave_pkg.sv \
	../../src/hvl_top/test/sequences/master_sequences/apb_master_seq_pkg.sv \
	../../src/hvl_top/test/sequences/slave_sequences/apb_slave_seq_pkg.sv \
	../../src/hvl_top/env/apb_env_pkg.sv \
	../../src/hvl_top/test/virtual_sequences/apb_virtual_seq_pkg.sv \
	../../src/hvl_top/test/apb_test_pkg.sv \
	../../src/hdl_top/master_agent_bfm/*.sv \
	../../src/hdl_top/slave_agent_bfm/*.sv \
	../../src/hdl_top/hdl_top.sv \
	../../src/hvl_top/hvl_top.sv \
	+UVM_TESTNAME=apb_aes_test \
	+UVM_VERBOSITY=MEDIUM \
	+plusarg_ignore \
	-l transcript_vcs.log

clean:
	rm -rf work/ transcript transcript_vcs.log waveform.wlf csrc simv simv.daidir ucli.key vc_hdrs.h
