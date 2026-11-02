`ifndef APB_SCOREBOARD_INCLUDED_
`define APB_SCOREBOARD_INCLUDED_

//--------------------------------------------------------------------------------------------
// DPI-C Import for AES Golden Reference Model
//--------------------------------------------------------------------------------------------
import "DPI-C" context function void c_aes128_ctr_encrypt(
  input  bit [127:0] key,
  input  bit [127:0] ctr,
  input  bit [127:0] pt,
  output bit [127:0] ct
);

//--------------------------------------------------------------------------------------------
// Class: apb_scoreboard
// Tracks AES configuration and verifies ciphertext against a DPI-C Golden Model
//--------------------------------------------------------------------------------------------
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  apb_master_tx apb_master_tx_h;
  apb_slave_tx  apb_slave_tx_h;
  
  uvm_tlm_analysis_fifo#(apb_master_tx) apb_master_analysis_fifo;
  uvm_tlm_analysis_fifo#(apb_slave_tx)  apb_slave_analysis_fifo[];

  //-------------------------------------------------------
  // AES Shadow Registers & State
  //-------------------------------------------------------
  bit [127:0] shadow_key;
  bit [127:0] shadow_iv;
  bit [127:0] shadow_pt;
  
  bit [127:0] active_key;
  bit [127:0] active_ctr;
  
  bit [127:0] actual_ct;
  bit [127:0] expected_ct_q[$]; // Queue to hold expected ciphertexts

  bit key_locked = 1'b0;

  // Trackers
  int aes_blocks_encrypted = 0;
  int aes_blocks_passed    = 0;
  int aes_blocks_failed    = 0;
  bit index;

  extern function new(string name = "apb_scoreboard", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function void check_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : apb_scoreboard

function apb_scoreboard::new(string name = "apb_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  apb_master_analysis_fifo = new("apb_master_analysis_fifo", this);
  apb_slave_analysis_fifo  = new[NO_OF_SLAVES];
  foreach(apb_slave_analysis_fifo[i]) begin
    apb_slave_analysis_fifo[i] = new($sformatf("apb_slave_analysis_fifo[%0d]",i), this);
  end
endfunction : new

task apb_scoreboard::run_phase(uvm_phase phase);
  bit [127:0] exp_ct;
  super.run_phase(phase);

  forever begin
    apb_master_analysis_fifo.get(apb_master_tx_h);
    
    // Drain slave FIFO so it doesn't overflow (monitors are still active)
    for(int i=0; i<NO_OF_SLAVES; i++) begin
      if(apb_master_tx_h.pselx[i] == 1) begin
        index = i;
        break;
      end
    end
    apb_slave_analysis_fifo[index].get(apb_slave_tx_h);

    // Only process successful transactions
    if (apb_master_tx_h.pslverr == 0) begin
      
      //-------------------------------------------------------
      // WRITE TRANSACTIONS (Configuring AES)
      //-------------------------------------------------------
      if (apb_master_tx_h.pwrite == apb_global_pkg::WRITE) begin
        // Enforce Privileged Check (pprot[0] must be 1)
        if (apb_master_tx_h.pprot[0] == 1'b1) begin
          case (apb_master_tx_h.paddr[6:0])
            // KEY Write
            7'h10: if (!key_locked) shadow_key[127:96] = apb_master_tx_h.pwdata;
            7'h14: if (!key_locked) shadow_key[95:64]  = apb_master_tx_h.pwdata;
            7'h18: if (!key_locked) shadow_key[63:32]  = apb_master_tx_h.pwdata;
            7'h1C: if (!key_locked) shadow_key[31:0]   = apb_master_tx_h.pwdata;

            // IV Write
            7'h20: shadow_iv[127:96] = apb_master_tx_h.pwdata;
            7'h24: shadow_iv[95:64]  = apb_master_tx_h.pwdata;
            7'h28: shadow_iv[63:32]  = apb_master_tx_h.pwdata;
            7'h2C: shadow_iv[31:0]   = apb_master_tx_h.pwdata;

            // PT Write
            7'h30: shadow_pt[127:96] = apb_master_tx_h.pwdata;
            7'h34: shadow_pt[95:64]  = apb_master_tx_h.pwdata;
            7'h38: shadow_pt[63:32]  = apb_master_tx_h.pwdata;
            7'h3C: shadow_pt[31:0]   = apb_master_tx_h.pwdata;

            // CTRL Pulses
            7'h00: begin
              if (apb_master_tx_h.pwdata[0]) active_key = shadow_key; // KEY_LOAD
              if (apb_master_tx_h.pwdata[1]) active_ctr = shadow_iv;  // IV_LOAD
              if (apb_master_tx_h.pwdata[4]) key_locked = 1'b1;       // KEY_LOCK
              if (apb_master_tx_h.pwdata[3]) begin                    // ZEROIZE
                active_key = 0;
                active_ctr = 0;
                expected_ct_q.delete();
              end
              if (apb_master_tx_h.pwdata[2]) begin                    // PT_PUSH
                // Calculate expected ciphertext using C Model
                c_aes128_ctr_encrypt(active_key, active_ctr, shadow_pt, exp_ct);
                expected_ct_q.push_back(exp_ct);
                aes_blocks_encrypted++;
                
                `uvm_info("SB_AES_PREDICT", $sformatf("Predicted Block %0d CT: %032h", aes_blocks_encrypted, exp_ct), UVM_LOW)
                
                // Hardware auto-increments the 128-bit counter
                active_ctr = active_ctr + 1;
              end
            end
          endcase
        end
      end

      //-------------------------------------------------------
      // READ TRANSACTIONS (Verifying AES output)
      //-------------------------------------------------------
      else if (apb_master_tx_h.pwrite == apb_global_pkg::READ) begin
        case (apb_master_tx_h.paddr[6:0])
          7'h40: actual_ct[127:96] = apb_master_tx_h.prdata;
          7'h44: actual_ct[95:64]  = apb_master_tx_h.prdata;
          7'h48: actual_ct[63:32]  = apb_master_tx_h.prdata;
          7'h4C: begin
            actual_ct[31:0] = apb_master_tx_h.prdata;
            
            // CT3 read marks the end of a block read. Pop expected and compare!
            if (expected_ct_q.size() > 0) begin
              exp_ct = expected_ct_q.pop_front();
              if (actual_ct == exp_ct) begin
                aes_blocks_passed++;
                `uvm_info("SB_MATCH", $sformatf("[PASS] AES Ciphertext matches! Actual: %032h", actual_ct), UVM_LOW)
              end else begin
                aes_blocks_failed++;
                `uvm_error("SB_MISMATCH", $sformatf("[FAIL] Ciphertext mismatch!\nExpected: %032h\nActual  : %032h", exp_ct, actual_ct))
              end
            end else begin
              `uvm_error("SB_UNEXPECTED_READ", "RTL provided Ciphertext, but Scoreboard queue was empty!")
            end
          end
        endcase
      end
    end
  end
endtask : run_phase

function void apb_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);
  if (expected_ct_q.size() != 0) begin
    `uvm_error("SB_CHECK", $sformatf("Simulation ended with %0d expected ciphertexts unread by testbench!", expected_ct_q.size()))
  end
endfunction : check_phase

function void apb_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
  `uvm_info("SB_REPORT", "--------------------------------------------------", UVM_NONE)
  `uvm_info("SB_REPORT", "             AES-128 SCOREBOARD REPORT            ", UVM_NONE)
  `uvm_info("SB_REPORT", "--------------------------------------------------", UVM_NONE)
  `uvm_info("SB_REPORT", $sformatf("Blocks Encrypted (PT_PUSH): %0d", aes_blocks_encrypted), UVM_NONE)
  `uvm_info("SB_REPORT", $sformatf("Blocks Passed             : %0d", aes_blocks_passed), UVM_NONE)
  `uvm_info("SB_REPORT", $sformatf("Blocks Failed             : %0d", aes_blocks_failed), UVM_NONE)
  `uvm_info("SB_REPORT", "--------------------------------------------------", UVM_NONE)
endfunction : report_phase

`endif
