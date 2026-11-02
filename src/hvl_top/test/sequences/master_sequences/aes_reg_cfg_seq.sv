`ifndef AES_REG_CFG_SEQ_SV
`define AES_REG_CFG_SEQ_SV

class aes_reg_cfg_seq extends apb_master_base_seq;
    `uvm_object_utils(aes_reg_cfg_seq)

    //-------------------------------------------------------
    // 1. AES-128 Register Offsets (Per Spec Section 5)
    //-------------------------------------------------------
    localparam bit [31:0] ADDR_CTRL        = 32'h0000_0000;
    localparam bit [31:0] ADDR_STATUS      = 32'h0000_0004;

    localparam bit [31:0] ADDR_KEY0        = 32'h0000_0010; // Key[127:96]
    localparam bit [31:0] ADDR_KEY1        = 32'h0000_0014; // Key[95:64]
    localparam bit [31:0] ADDR_KEY2        = 32'h0000_0018; // Key[63:32]
    localparam bit [31:0] ADDR_KEY3        = 32'h0000_001C; // Key[31:0]

    localparam bit [31:0] ADDR_IV0         = 32'h0000_0020; // IV[127:96]
    localparam bit [31:0] ADDR_IV1         = 32'h0000_0024; // IV[95:64]
    localparam bit [31:0] ADDR_IV2         = 32'h0000_0028; // IV[63:32]
    localparam bit [31:0] ADDR_IV3         = 32'h0000_002C; // IV[31:0]

    localparam bit [31:0] ADDR_PT0         = 32'h0000_0030; // PT[127:96]
    localparam bit [31:0] ADDR_PT1         = 32'h0000_0034; // PT[95:64]
    localparam bit [31:0] ADDR_PT2         = 32'h0000_0038; // PT[63:32]
    localparam bit [31:0] ADDR_PT3         = 32'h0000_003C; // PT[31:0]

    localparam bit [31:0] ADDR_CT0         = 32'h0000_0040; // CT[127:96]
    localparam bit [31:0] ADDR_CT1         = 32'h0000_0044; // CT[95:64]
    localparam bit [31:0] ADDR_CT2         = 32'h0000_0048; // CT[63:32]
    localparam bit [31:0] ADDR_CT3         = 32'h0000_004C; // CT[31:0] (Read consumes FIFO)

    localparam bit [31:0] ADDR_CYCLE_COUNT = 32'h0000_0050; // Expected constant: 11

    //-------------------------------------------------------
    // 2. Configuration Variables Passed from Virtual Sequence / Test
    //-------------------------------------------------------
    rand bit [127:0] cfg_key;
    rand bit [127:0] cfg_iv;
    rand bit [127:0] cfg_pt;
    bit [127:0]      read_ct;
    bit [31:0]       read_data;

    // Control flags so Virtual Sequence can enable/disable phases
    rand bit do_key_load = 1'b1;
    rand bit do_iv_load  = 1'b1;
    rand bit do_encrypt  = 1'b1;

    function new(string name = "aes_reg_cfg_seq");
        super.new(name);
    endfunction

    //-------------------------------------------------------
    // 3. Main Configuration & Encryption Flow
    //-------------------------------------------------------
    virtual task body();
        super.body();

        `uvm_info("AES_REG_SEQ", $sformatf("Starting AES Sequence -> KEY_LOAD:%0b, IV_LOAD:%0b, ENCRYPT:%0b",
                  do_key_load, do_iv_load, do_encrypt), UVM_LOW)

        // STEP 1: LOAD 128-BIT KEY & POLL KEY_READY
        if (do_key_load) begin
            // Wait until STATUS.BUSY (bit 0) == 0 before loading key (Spec Limitation 4)
            do begin
                read_reg(ADDR_STATUS, read_data);
            end while (read_data[0] == 1'b1);

            write_reg(ADDR_KEY0, cfg_key[127:96]);
            write_reg(ADDR_KEY1, cfg_key[95:64]);
            write_reg(ADDR_KEY2, cfg_key[63:32]);
            write_reg(ADDR_KEY3, cfg_key[31:0]);

            // Trigger CTRL.KEY_LOAD (Bit 0 = 1)
            write_reg(ADDR_CTRL, 32'h0000_0001);

            // Poll STATUS.KEY_READY (Bit 1) until 1
            do begin
                read_reg(ADDR_STATUS, read_data);
            end while (read_data[1] == 1'b0);

            `uvm_info("AES_REG_SEQ", "KEY_READY is asserted (1)!", UVM_LOW)
        end

        // STEP 2: LOAD 128-BIT IV / INITIAL COUNTER
        if (do_iv_load) begin
            write_reg(ADDR_IV0, cfg_iv[127:96]);
            write_reg(ADDR_IV1, cfg_iv[95:64]);
            write_reg(ADDR_IV2, cfg_iv[63:32]);
            write_reg(ADDR_IV3, cfg_iv[31:0]);

            // Trigger CTRL.IV_LOAD (Bit 1 = 1)
            write_reg(ADDR_CTRL, 32'h0000_0002);
        end

        // STEP 3: STAGE PLAINTEXT, PUSH TO FIFO, POLL & READ CIPHERTEXT
        if (do_encrypt) begin
            write_reg(ADDR_PT0, cfg_pt[127:96]);
            write_reg(ADDR_PT1, cfg_pt[95:64]);
            write_reg(ADDR_PT2, cfg_pt[63:32]);
            write_reg(ADDR_PT3, cfg_pt[31:0]);

            // Trigger CTRL.PT_PUSH (Bit 2 = 1)
            write_reg(ADDR_CTRL, 32'h0000_0004);

            // Poll STATUS until RX_FIFO_EMPTY (Bit 3) == 0 and BUSY (Bit 0) == 0
            do begin
                read_reg(ADDR_STATUS, read_data);
            end while (read_data[3] == 1'b1 || read_data[0] == 1'b1);

            // Read back 128-bit Ciphertext (Reading CT3 consumes the FIFO entry)
            read_reg(ADDR_CT0, read_ct[127:96]);
            read_reg(ADDR_CT1, read_ct[95:64]);
            read_reg(ADDR_CT2, read_ct[63:32]);
            read_reg(ADDR_CT3, read_ct[31:0]);

            `uvm_info("AES_REG_SEQ", $sformatf("PT: %032h -> CT: %032h", cfg_pt, read_ct), UVM_LOW)
        end
    endtask

    //-------------------------------------------------------
    // 4. Write & Read Helper Tasks (Same pattern as Camera Project)
    //    Defaults to pprot = 3'b001 (Privileged: pprot[0] = 1)
    //-------------------------------------------------------
    virtual task write_reg(
        bit [31:0]        addr,
        bit [31:0]        data,
        protection_type_e prot = NORMAL_SECURE_INSTRUCTION, // 3'b001 -> pprot[0]=1
        bit [3:0]         strb = 4'b1111
    );
        apb_master_tx write_tx = apb_master_tx::type_id::create("write_tx");
        
        start_item(write_tx);
        write_tx.apb_master_agent_cfg_h = p_sequencer.apb_master_agent_cfg_h;
        
        if (!write_tx.randomize() with {
            pwrite        == apb_global_pkg::WRITE;   
            pselx         == apb_global_pkg::SLAVE_0; 
            transfer_size == apb_global_pkg::BIT_32;  
        }) begin
            `uvm_error("APB_SEQ", "Failed to randomize APB write transaction rules")
        end
        
        // Overwrite post_randomize() values with exact target values
        write_tx.paddr  = addr;
        write_tx.pwdata = data;
        write_tx.pprot  = prot;
        write_tx.pstrb  = strb;
        
        finish_item(write_tx);
    endtask

    virtual task read_reg(
        bit [31:0]        addr,
        output bit [31:0] data,
        input protection_type_e prot = NORMAL_SECURE_INSTRUCTION // 3'b001 -> pprot[0]=1
    );
        apb_master_tx read_tx = apb_master_tx::type_id::create("read_tx");
        
        start_item(read_tx);
        read_tx.apb_master_agent_cfg_h = p_sequencer.apb_master_agent_cfg_h;
        
        if (!read_tx.randomize() with {
            pwrite        == apb_global_pkg::READ;    
            pselx         == apb_global_pkg::SLAVE_0; 
            transfer_size == apb_global_pkg::BIT_32;  
        }) begin
            `uvm_error("APB_SEQ", "Failed to randomize APB read transaction rules")
        end
        
        read_tx.paddr = addr;
        read_tx.pprot = prot;
        read_tx.pstrb = 4'b0000;
        
        finish_item(read_tx);
        
        data = read_tx.prdata;
    endtask

endclass : aes_reg_cfg_seq

`endif // AES_REG_CFG_SEQ_SV
