// ============================================================================
// Testbench for dnn_accelerator (Project 3)
// ============================================================================
// This testbench verifies the DNN accelerator which uses 4 instances of
// multiplier_800M_16b.
//
// Pipeline: 1 (input reg) + 4 (multiplier_800M_16b) + 1 (adder tree) = 6 cycles total latency
// ============================================================================

`timescale 1ns / 1ps
`define CLK_DELAY #2;
`define IN2REG_DELAY #0.5;

module mkMACBuff_TB;

// ============================================================================
// Parameters
// ============================================================================
localparam ADDR_WIDTH = 6;
localparam ADDR_DEPTH = 64;
localparam N = 33;  // 34-bit results for dot product

// ============================================================================
// Clock and Reset
// ============================================================================
reg CLK;
reg RESET;
wire RST_N;
assign RST_N = ~RESET;

// CLK generation - 2ns period (500MHz)
always #1 CLK = ~CLK; 

// ============================================================================
// DUT Interface Signals
// ============================================================================
// MAC interface
reg EN_mac;
wire RDY_mac;
reg [15:0] mac_vectA_0;
reg [15:0] mac_vectB_0;
reg [15:0] mac_vectA_1;
reg [15:0] mac_vectB_1;
reg [15:0] mac_vectA_2;
reg [15:0] mac_vectB_2;
reg [15:0] mac_vectA_3;
reg [15:0] mac_vectB_3;

// Memory write interface
wire EN_writeMem;
wire [5:0] writeMem_addr;
wire [N:0] writeMem_val;

// Block read interface
reg EN_blockRead;
wire RDY_blockRead;

// Memory read interface
wire EN_readMem;
wire [5:0] readMem_addr;
wire [N:0] readMem_val;

// Memory value output
wire VALID_memVal;
wire [N:0] memVal_data;

// ============================================================================
// DUT Instantiation
// ============================================================================
mkMACBuff mkMACBuff_DUT(
    .CLK(CLK), 
    .RST_N(RST_N),
    
    .EN_mac(EN_mac), 
    .RDY_mac(RDY_mac),
    .mac_vectA_0(mac_vectA_0), 
    .mac_vectB_0(mac_vectB_0),
    .mac_vectA_1(mac_vectA_1), 
    .mac_vectB_1(mac_vectB_1),
    .mac_vectA_2(mac_vectA_2), 
    .mac_vectB_2(mac_vectB_2),
    .mac_vectA_3(mac_vectA_3), 
    .mac_vectB_3(mac_vectB_3),
    
    .EN_writeMem(EN_writeMem), 
    .writeMem_addr(writeMem_addr), 
    .writeMem_val(writeMem_val),
    
    .EN_blockRead(EN_blockRead), 
    .RDY_blockRead(RDY_blockRead),
    
    .EN_readMem(EN_readMem), 
    .readMem_addr(readMem_addr), 
    .readMem_val(readMem_val),
    .VALID_memVal(VALID_memVal), 
    .memVal_data(memVal_data)
);
    
// ============================================================================
// Memory Wrapper Instantiation
// ============================================================================
memory_wrapper_2port #(
    .DEPTH(ADDR_DEPTH), 
    .LOGDEPTH(ADDR_WIDTH), 
    .WIDTH(N+1)
) memory_2port ( 
    .clkA(CLK), 
    .aA(readMem_addr), 
    .cenA(~EN_readMem), 
    .q(readMem_val),
    .clkB(CLK), 
    .aB(writeMem_addr), 
    .cenB(~EN_writeMem), 
    .d(writeMem_val)
);

// ============================================================================
// Task: Initialization
// ============================================================================
task TASK_init;
begin
    CLK = 1'b0;
    RESET = 1'b1;
    EN_mac = 1'b0;
    mac_vectA_0 = 16'h0;
    mac_vectB_0 = 16'h0;
    mac_vectA_1 = 16'h0;
    mac_vectB_1 = 16'h0;
    mac_vectA_2 = 16'h0;
    mac_vectB_2 = 16'h0;
    mac_vectA_3 = 16'h0;
    mac_vectB_3 = 16'h0;
    EN_blockRead = 1'b0;
end
endtask

// ============================================================================
// Task: Reset
// ============================================================================
task TASK_reset;
begin
    RESET = 1'b0;
    `CLK_DELAY;
    RESET = 1'b1;
    `CLK_DELAY;
    RESET = 1'b0;
    `CLK_DELAY;
end
endtask

// ============================================================================
// Task: Calculate Expected Dot Product
// ============================================================================
function automatic [33:0] calculate_dot_product(
    input [15:0] a0, a1, a2, a3,
    input [15:0] b0, b1, b2, b3
);
    logic [31:0] prod0, prod1, prod2, prod3;
    logic [33:0] result;
begin
    prod0 = a0 * b0;
    prod1 = a1 * b1;
    prod2 = a2 * b2;
    prod3 = a3 * b3;
    result = prod0 + prod1 + prod2 + prod3;
    calculate_dot_product = result;
    $display("prod0: %0d", prod0);
    $display("prod1: %0d", prod1);
    $display("prod2: %0d", prod2);
    $display("prod3: %0d", prod3);
    $display("result: %0d", result);
end
endfunction

// ============================================================================
// Task: Main DUT Testing
// ============================================================================
task TASK_DUT;
    // Define data structures to use in the task here
    logic [33:0] expMACBuff [ADDR_DEPTH-1:0];
    logic [33:0] expMACOut;
    integer i, j, k;
    integer error_count;
    integer total_tests;
    logic [15:0] test_vecA [0:3];
    logic [15:0] test_vecB [0:3];
begin
    error_count = 0;
    total_tests = 0;
    
    $display("\n========================================");
    $display("  dnn_accelerator Testbench");
    $display("  Using 4x multiplier_800M_16b");
    $display("  Testing 8 iterations of 64 dot products");
    $display("========================================\n");
    
    // ========================================================================
    // Test 8 iterations
    // ========================================================================
    for (k = 0; k < 8; k = k + 1) begin
        $display("========================================");
        $display("  ITERATION %0d", k+1);
        $display("========================================\n");
        
        // ====================================================================
        // Phase 1: Perform 64 dot products
        // ====================================================================
        $display("[%0t] Phase 1: Starting 64 dot products...", $time);
        $display("        Using 4x multiplier_800M_16b");
        $display("        Pipeline: 1 (input) + 4 (mult) + 1 (adder) = 6 cycles\n");
        
        for (i = 0; i < 64; i = i + 1) begin
            // Wait until accelerator is ready
            while (!RDY_mac) begin
                @(posedge CLK);
            end

            @(posedge CLK);

            // `IN2REG_DELAY;
            EN_mac = 1'b1;

            // Generate test vectors
            test_vecA[0] = $urandom_range(65535, 0);
            test_vecB[0] = $urandom_range(65535, 0);
            test_vecA[1] = $urandom_range(65535, 0);
            test_vecB[1] = $urandom_range(65535, 0);
            test_vecA[2] = $urandom_range(65535, 0);
            test_vecB[2] = $urandom_range(65535, 0);
            test_vecA[3] = $urandom_range(65535, 0);
            test_vecB[3] = $urandom_range(65535, 0);
            
            mac_vectA_0 = test_vecA[0];
            mac_vectB_0 = test_vecB[0];
            mac_vectA_1 = test_vecA[1];
            mac_vectB_1 = test_vecB[1];
            mac_vectA_2 = test_vecA[2];
            mac_vectB_2 = test_vecB[2];
            mac_vectA_3 = test_vecA[3];
            mac_vectB_3 = test_vecB[3];
            
            // Calculate expected result
            expMACBuff[i] = calculate_dot_product(
                test_vecA[0], test_vecA[1], test_vecA[2], test_vecA[3],
                test_vecB[0], test_vecB[1], test_vecB[2], test_vecB[3]
            );
            
            // messages
            $display("[%0t] Dot product %0d:", $time, i);
            $display("        A=[%0d, %0d, %0d, %0d]", 
                        test_vecA[0], test_vecA[1], test_vecA[2], test_vecA[3]);
            $display("        B=[%0d, %0d, %0d, %0d]", 
                        test_vecB[0], test_vecB[1], test_vecB[2], test_vecB[3]);
            $display("        Expected result = %0d", expMACBuff[i]);
        end
        
        $display("[%0t] All 64 dot products submitted", $time);

        while (RDY_mac) begin
            @(posedge CLK);
        end

        @(posedge CLK);
        EN_mac = 1'b0;
        
        // Wait until RDY_blockRead is asserted
        while (!RDY_blockRead) begin
            @(posedge CLK);
        end

        $display("[%0t] Memory is now full", $time);
        $display("[%0t] Ready for block read\n", $time);
        
        // ====================================================================
        // Phase 2: Read and verify results
        // ====================================================================
        $display("[%0t] Phase 2: Reading back results...", $time);
        
        // Start read 

        // `IN2REG_DELAY;
        @(negedge CLK);
        EN_blockRead = 1'b1;
        @(negedge CLK);

        // `IN2REG_DELAY;
        EN_blockRead = 1'b0;
        
        // PRE-SYNTHESIS: Read and verify all 64 results
        for (j = 0; j < 64; j = j + 1) begin
            while (!VALID_memVal) begin
                @(posedge CLK);
            end
            
            total_tests = total_tests + 1;
            if (memVal_data !== expMACBuff[j]) begin
                $display("[%0t] ERROR at index %0d: Expected %0d, Got %0d", 
                         $time, j, expMACBuff[j], memVal_data);
                error_count = error_count + 1;
            end 
            else begin
                $display("[%0t] Result %0d: %0d :)", $time, j, memVal_data);
            end
            
            @(posedge CLK);
        end
        
        // // POST-ROUTE: Read and verify all 64 results
        // for (j = 0; j < 64; j = j + 1) begin
        //     while (readMem_addr < 6'd1 && !VALID_memVal) begin
        //         @(posedge CLK);
        //     end
            
        //     total_tests = total_tests + 1;
        //     if (readMem_val !== expMACBuff[j]) begin
        //         $display("[%0t] ERROR at index %0d: Expected %0d, Got %0d", 
        //                  $time, j, expMACBuff[j], readMem_val);
        //         error_count = error_count + 1;
        //     end 
        //     else begin
        //         $display("[%0t] Result %0d: %0d :)", $time, j, readMem_val);
        //     end
            
        //     @(posedge CLK);
        // end
        
        $display("[%0t] All 64 results verified", $time);
        
        repeat(10) @(posedge CLK);
        $display("");
    end
    
    // ========================================================================
    // Test Summary
    // ========================================================================
    $display("\n========================================");
    $display("  TEST SUMMARY");
    $display("========================================");
    $display("Total tests: %0d", total_tests);
    $display("Errors:      %0d", error_count);
    if (error_count == 0) begin
        $display("STATUS:      PASS :)");
    end else begin
        $display("STATUS:      FAIL :(");
    end
    $display("========================================\n");
end
endtask

// ============================================================================
// Main Test Sequence
// ============================================================================
initial begin
    TASK_init;
    TASK_reset;
    TASK_DUT;
    
    repeat(10) @(posedge CLK);
    $finish;
end

// ============================================================================
// Timeout Watchdog
// ============================================================================
initial begin
    #2000000;  // 2ms timeout
    $display("\n[ERROR] Simulation timeout!");
    $finish;
end

// ============================================================================
// Waveform Dumping
// ============================================================================
initial begin
    $dumpfile("mkMACBuff_TB.vcd");
    $dumpvars(0, mkMACBuff_TB);
end

endmodule: mkMACBuff_TB
