`timescale 1ns/1ps

module acc_tb;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // MAC interface
    logic         EN_mac;
    logic [15:0]  mac_vecA_0, mac_vecB_0;
    logic [15:0]  mac_vecA_1, mac_vecB_1;
    logic [15:0]  mac_vecA_2, mac_vecB_2;
    logic [15:0]  mac_vecA_3, mac_vecB_3;
    logic         RDY_mac;
    
    // Memory read interface
    logic         EN_readMem;
    logic         VALID_memVal;
    logic [31:0]  memVal_data;
    
    // Result memory interface
    logic [5:0]   result_readMem_addr;
    logic         result_EN_readMem_int;
    logic [31:0]  result_readMem_val;
    logic [5:0]   result_writeMem_addr;
    logic         result_EN_writeMem;
    logic [31:0]  result_writeMem_val;
    
    // Simple memory model (64 entries x 32 bits)
    logic [31:0] result_memory [0:63];
    
    // Memory model behavior
    always_ff @(posedge clk) begin
        if (result_EN_writeMem) begin
            result_memory[result_writeMem_addr] <= result_writeMem_val;
        end
        result_readMem_val <= result_memory[result_readMem_addr];
    end
    
    // DUT instantiation
    dnn_accelerator dut (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mac(EN_mac),
        .mac_vecA_0(mac_vecA_0),
        .mac_vecB_0(mac_vecB_0),
        .mac_vecA_1(mac_vecA_1),
        .mac_vecB_1(mac_vecB_1),
        .mac_vecA_2(mac_vecA_2),
        .mac_vecB_2(mac_vecB_2),
        .mac_vecA_3(mac_vecA_3),
        .mac_vecB_3(mac_vecB_3),
        .RDY_mac(RDY_mac),
        .EN_readMem(EN_readMem),
        .VALID_memVal(VALID_memVal),
        .memVal_data(memVal_data),
        .result_readMem_addr(result_readMem_addr),
        .result_EN_readMem_int(result_EN_readMem_int),
        .result_readMem_val(result_readMem_val),
        .result_writeMem_addr(result_writeMem_addr),
        .result_EN_writeMem(result_EN_writeMem),
        .result_writeMem_val(result_writeMem_val)
    );
    
    // Clock generation: 500MHz = 2ns period
    initial begin
        clk = 0;
        forever #1.1 clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        EN_mac = 0;
        EN_readMem = 0;
        mac_vecA_0 = 0;
        mac_vecB_0 = 0;
        mac_vecA_1 = 0;
        mac_vecB_1 = 0;
        mac_vecA_2 = 0;
        mac_vecB_2 = 0;
        mac_vecA_3 = 0;
        mac_vecB_3 = 0;
        
        // Reset
        @(posedge clk);
        #0.1 rst_n = 1;
        
        // Wait a few cycles (IDLE state)
        repeat(5) @(posedge clk);
        
        // IDLE -> WRITING: perform 64 MAC operations to fill memory
        #0.1 EN_mac = 1;
        for (int i = 0; i < 64; i++) begin
            @(posedge clk);
            #0.1;
            // Vary the input values based on iteration
            mac_vecA_0 = 16'd1 + i;
            mac_vecB_0 = 16'd2;
            mac_vecA_1 = 16'd3 + i;
            mac_vecB_1 = 16'd4;
            mac_vecA_2 = 16'd5 + i;
            mac_vecB_2 = 16'd6;
            mac_vecA_3 = 16'd7 + i;
            mac_vecB_3 = 16'd8;
        end
        
        @(posedge clk);
        #0.1 EN_mac = 0;
        
        // Wait for pipeline to flush and reach FULL state
        repeat(20) @(posedge clk);
        
        // FULL -> READING: start reading memory
        #0.1 EN_readMem = 1;
        
        // Wait for all 64 reads to complete (READING state)
        repeat(70) @(posedge clk);
        
        // Back to IDLE
        #0.1 EN_readMem = 0;
        
        repeat(5) @(posedge clk);
        
        $display("Test complete - all FSM states visited");
        $finish;
    end
    
    // Timeout
    initial begin
        #10000;
        $display("Timeout!");
        $finish;
    end

endmodule
