`ifndef APB_VIRTUAL_AES_SEQ_SV
`define APB_VIRTUAL_AES_SEQ_SV

class apb_virtual_aes_seq extends apb_virtual_base_seq;
  `uvm_object_utils(apb_virtual_aes_seq)

  aes_reg_cfg_seq aes_seq_h;

  // NIST SP 800-38A F.5.1 Vectors
  bit [127:0] nist_key   = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
  bit [127:0] nist_iv    = 128'hf0f1f2f3_f4f5f6f7_f8f9fafb_fcfdfeff;
  bit [127:0] nist_pt[4] = '{
    128'h6bc1bee2_2e409f96_e93d7e11_7393172a,
    128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51,
    128'h30c81c46_a35ce411_e5fbc119_1a0a52ef,
    128'hf69f2445_df4f9b17_ad2b417b_e66c3710
  };

  function new(string name = "apb_virtual_aes_seq");
    super.new(name);
  endfunction

  task body();
    // Declare a handle for the Valid Data/Valid Wait State sequence
    apb_slave_vd_vws_seq slave_resp_seq; 
    
    super.body();
    
    // Create and start the slave response sequence in a continuous loop
    fork
      forever begin
        slave_resp_seq = apb_slave_vd_vws_seq::type_id::create("slave_resp_seq");
        slave_resp_seq.start(apb_slave_seqr_h[0]); // Starts on Slave 0
      end
    join_none
    
    // Now run your Master AES traffic
    foreach (nist_pt[i]) begin
      aes_seq_h = aes_reg_cfg_seq::type_id::create($sformatf("aes_seq_h_%0d", i));

      // Load Key & IV only on Block 0
      aes_seq_h.do_key_load       = (i == 0) ? 1'b1 : 1'b0;
      aes_seq_h.do_iv_load        = (i == 0) ? 1'b1 : 1'b0;
      aes_seq_h.do_encrypt        = 1'b1;

      aes_seq_h.cfg_key = nist_key;
      aes_seq_h.cfg_iv  = nist_iv;
      aes_seq_h.cfg_pt  = nist_pt[i];

      aes_seq_h.start(apb_master_seqr_h);
    end
  endtask
endclass : apb_virtual_aes_seq

`endif
