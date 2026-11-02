`ifndef APB_IF_INCLUDED_
`define APB_IF_INCLUDED_

//-------------------------------------------------------
// Importing apb global package
//-------------------------------------------------------
import apb_global_pkg::*;

//--------------------------------------------------------------------------------------------
// Interface : apb_if
// Declaration of pin level signals for apb interface + AES sideband clock/reset
//--------------------------------------------------------------------------------------------
interface apb_if (input pclk, input preset_n, input crypto_clk);
  
  //Variable : crypto_rst_n
  //Dedicated active-low reset for the AES cryptographic core
  logic crypto_rst_n;

  //Variable : pselx
  //Used to select the slave
  logic [NO_OF_SLAVES-1:0] pselx;

  //Variable : penable
  //Used to write data when penable is high
  logic penable;  

  //Variable : paddr
  //Address selected in apb_slave
  logic [ADDRESS_WIDTH-1:0] paddr;

  //Variable : pwrite
  //Write when pwrite is 1 and read is 0
  logic pwrite;

  //Variable : pstrb
  //Used to transfer the data to pwdata bus
  logic [(DATA_WIDTH/8)-1:0] pstrb; 
  
  //Variable : pwdata
  //Used to store the wdata
  logic [DATA_WIDTH-1:0] pwdata;

  //Variable : pready
  //Used to extend the transfer
  logic pready;

  //Variable : prdata
  //Used to store the rdata from the slave  
  logic [DATA_WIDTH-1:0] prdata;

  //Variable : pslverr
  //Goes high when a transfer fails
  logic pslverr;
  
  //Variable : pprot
  //Used for different access
  logic [2:0] pprot; 

  //-------------------------------------------------------
  // Helper Task: Trigger AES Core Reset mid-simulation
  // Useful for TC_002 (reset_mid_encrypt) & TC_003 (crypto_reset_only)
  //-------------------------------------------------------
  task automatic pulse_crypto_reset(int unsigned num_crypto_clks = 5);
    crypto_rst_n <= 1'b0;
    repeat (num_crypto_clks) @(posedge crypto_clk);
    crypto_rst_n <= 1'b1;
  endtask

endinterface : apb_if
 
`endif
