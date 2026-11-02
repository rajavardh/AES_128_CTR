`ifndef APB_AES_NIST_TEST_SV
`define APB_AES_NIST_TEST_SV

class apb_aes_test extends apb_base_test;
  `uvm_component_utils(apb_aes_test)

  apb_virtual_aes_seq vseq_h;

  function new(string name = "apb_aes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    vseq_h = apb_virtual_aes_seq::type_id::create("vseq_h");

    phase.raise_objection(this);
    vseq_h.start(apb_env_h.apb_virtual_seqr_h);
    #100;
    phase.drop_objection(this);
  endtask
endclass : apb_aes_test

`endif
