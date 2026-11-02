`ifndef HDL_TOP_INCLUDED
`define HDL_TOP_INCLUDED

//--------------------------------------------------------------------------------------------
// Module      : HDL Top
// Description : Has APB interface, Master/Slave BFMs, and AES-128 Accelerator DUT.
//--------------------------------------------------------------------------------------------
module hdl_top;

  //-------------------------------------------------------
  // Importing uvm package and Including uvm macros file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //-------------------------------------------------------
  // Importing apb global package
  //-------------------------------------------------------
  import apb_global_pkg::*;

  initial begin
    `uvm_info("HDL_TOP","HDL_TOP",UVM_LOW);
  end

  //Variable : pclk & crypto_clk
  //Declaration of system clock and AES core clock
  bit pclk;
  bit crypto_clk;

  //Variable : preset_n
  //Declaration of system reset
  bit preset_n;

  //-------------------------------------------------------
  // Generation of pclk (Period = 10ns -> 100 MHz)
  //-------------------------------------------------------
  initial begin
    pclk = 1'b0;
    forever #5 pclk = !pclk;
  end

  //-------------------------------------------------------
  // Generation of crypto_clk (Period = 5ns -> 200 MHz)
  //-------------------------------------------------------
  initial begin
    crypto_clk = 1'b0;
    forever #2.5 crypto_clk = !crypto_clk;
  end

  //-------------------------------------------------------
  // APB Interface Instantiation (Updated with crypto_clk)
  //-------------------------------------------------------
  apb_if intf_s[NO_OF_SLAVES](pclk, preset_n, crypto_clk);
  apb_if intf(pclk, preset_n, crypto_clk);

  //-------------------------------------------------------
  // Generation of system preset_n and initial crypto_rst_n
  //-------------------------------------------------------
  initial begin
    preset_n          = 1'b1;
    intf.crypto_rst_n = 1'b1;
    
    #15;
    preset_n          = 1'b0;
    intf.crypto_rst_n = 1'b0;

    repeat(2) begin
      @(posedge pclk);
    end
    preset_n          = 1'b1;
    intf.crypto_rst_n = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");      // name of the VCD file
    $dumpvars(0, hdl_top);          // dump variables from the testbench top
  end

  //-------------------------------------------------------
  // APB Master BFM Agent Instantiation
  //-------------------------------------------------------
  apb_master_agent_bfm apb_master_agent_bfm_h(intf); 
  
  //-------------------------------------------------------
  // Interconnect routing between Master intf and Slave intf_s[0]
  //-------------------------------------------------------
  always_comb begin
    intf_s[0].crypto_rst_n = intf.crypto_rst_n;
    case(intf.pselx)
      1'b1: begin
              intf_s[0].pselx   = intf.pselx[0];
              intf_s[0].penable = intf.penable;
              intf_s[0].paddr   = intf.paddr;
              intf_s[0].pwrite  = intf.pwrite;
              intf_s[0].pstrb   = intf.pstrb;
              intf_s[0].pwdata  = intf.pwdata;
              intf_s[0].pprot   = intf.pprot;
              intf.pready       = intf_s[0].pready;
              intf.prdata       = intf_s[0].prdata;
              intf.pslverr      = intf_s[0].pslverr;
            end
      default: begin
              intf_s[0].pselx   = 'b0;
              intf_s[0].penable = 'b0;
              intf.pready       = intf_s[0].pready;
              intf.prdata       = intf_s[0].prdata;
              intf.pslverr      = intf_s[0].pslverr;
            end
    endcase
  end

  //-------------------------------------------------------
  // AES-128 Accelerator DUT Instantiation
  // (Verify port names against your AES top RTL module)
  //-------------------------------------------------------
  /*aes_crypto_accel_top u_aes_dut (
    .pclk         (pclk),
    .presetn      (preset_n),
    .crypto_clk   (crypto_clk),
    .crypto_rst_n (intf_s[0].crypto_rst_n),
    .psel         (intf_s[0].pselx[0]),
    .penable      (intf_s[0].penable),
    .paddr        (intf_s[0].paddr),
    .pwrite       (intf_s[0].pwrite),
    .pstrb        (intf_s[0].pstrb),
    .pwdata       (intf_s[0].pwdata),
    .pprot        (intf_s[0].pprot),
    .pready       (intf_s[0].pready),
    .prdata       (intf_s[0].prdata),
    .pslverr      (intf_s[0].pslverr)
  );*/

  //-------------------------------------------------------
  // APB Slave BFM Agent Instantiation (Monitor Only)
  //-------------------------------------------------------
  genvar i;
  generate
    for (i=0; i < NO_OF_SLAVES; i++) begin : apb_slave_agent_bfm
      apb_slave_agent_bfm #(.SLAVE_ID(i)) apb_slave_agent_bfm_h(intf_s[i]);
      defparam apb_slave_agent_bfm[i].apb_slave_agent_bfm_h.SLAVE_ID = i;
    end
  endgenerate

endmodule : hdl_top

`endif
