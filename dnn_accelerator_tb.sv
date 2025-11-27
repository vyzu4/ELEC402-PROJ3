// ============================================================================
// Testbench for DNN Accelerator (Project 3)
// ============================================================================
// This testbench verifies the DNN accelerator which uses 4 instances of
// multiplier_module from Project 2.
//
// Pipeline: 2 (mult from P2) + 3 (adder tree) = 5 cycles total latency
//
// Memory wrapper is instantiated in the testbench and connected to the DUT.
// ============================================================================

`timescale 1ns/1ps

module dnn_accelerator_tb;

    // ========================================================================
    // Testbench Signals
    // ========================================================================
    logic        clk;
    logic        rst_n;
    
    // MAC interface
    logic        EN_mac;
    logic [15:0] mac_vecA_0;
    logic [15:0] mac_vecB_0;
    logic [15:0] mac_vecA_1;
    logic [15:0] mac_vecB_1;
    logic [15:0] mac_vecA_2;
    logic [15:0] mac_vecB_2;
    logic [15:0] mac_vecA_3;
    logic [15:0] mac_vecB_3;
    logic        RDY_mac;
    
    // Memory read interface
    logic        EN_readMem;
    logic        VALID_memVal;
    logic [31:0] memVal_data;

    // Result memory interface signals
    logic [5:0]  result_readMem_addr;
    logic        result_EN_readMem_int;
    logic [31:0] result_readMem_val;
    logic [5:0]  result_writeMem_addr;
    logic        result_EN_writeMem;
    logic [31:0] result_writeMem_val;

    ///////////////////////////////////////////

    // Dummy signals for multiplier read interfaces (unused)
    logic [5:0]  mult0_writeMem_addr, mult0_readMem_addr;
    logic        mult0_EN_readMem, mult0_EN_blockRead;
    logic        mult0_VALID_memVal;
    logic [31:0] mult0_memVal_data, mult0_readMem_val;

    logic [5:0]  mult1_writeMem_addr, mult1_readMem_addr;
    logic        mult1_EN_readMem, mult1_EN_blockRead;
    logic        mult1_VALID_memVal;
    logic [31:0] mult1_memVal_data, mult1_readMem_val;

    logic [5:0]  mult2_writeMem_addr, mult2_readMem_addr;
    logic        mult2_EN_readMem, mult2_EN_blockRead;
    logic        mult2_VALID_memVal;
    logic [31:0] mult2_memVal_data, mult2_readMem_val;

    logic [5:0]  mult3_writeMem_addr, mult3_readMem_addr;
    logic        mult3_EN_readMem, mult3_EN_blockRead;
    logic        mult3_VALID_memVal;
    logic [31:0] mult3_memVal_data, mult3_readMem_val;
    
    // ========================================================================
    // Clock Generation (1GHz = 1ns period for Project 3)
    // ========================================================================
    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    dnn_accelerator dnn_accelerator_dut (
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
        // Memory interface connections
        .result_readMem_addr(result_readMem_addr),
        .result_EN_readMem_int(result_EN_readMem_int),
        .result_readMem_val(result_readMem_val),
        .result_writeMem_addr(result_writeMem_addr),
        .result_EN_writeMem(result_EN_writeMem),
        .result_writeMem_val(result_writeMem_val)
    );
    
    // ========================================================================
    // Result Memory Instance (instantiated in testbench)
    // ========================================================================
    memory_wrapper_2port #(
        .DEPTH(64),
        .LOGDEPTH(6),
        .WIDTH(32),
        .MEMTYPE(0),
        .TECHNODE(0),
        .COL_MUX(1)
    ) result_memory (
        .clkA(clk),
        .aA(result_readMem_addr),
        .cenA(~result_EN_readMem_int),
        .q(result_readMem_val),
        
        .clkB(clk),
        .aB(result_writeMem_addr),
        .cenB(~result_EN_writeMem),
        .d(result_writeMem_val)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer i, j, k;
    integer error_count;
    integer total_tests;
    logic [31:0] expected_result;
    logic [31:0] expected_results [0:63];
    
    // Test vectors
    logic [15:0] test_vecA [0:3];
    logic [15:0] test_vecB [0:3];
    
    // ========================================================================
    // Helper Task: Calculate Expected Dot Product
    // ========================================================================
    task automatic calculate_dot_product(
        input [15:0] a0, a1, a2, a3,
        input [15:0] b0, b1, b2, b3,
        output [31:0] result
    );
        logic [31:0] prod0, prod1, prod2, prod3;
        begin
            prod0 = a0 * b0;
            prod1 = a1 * b1;
            prod2 = a2 * b2;
            prod3 = a3 * b3;
            result = prod0 + prod1 + prod2 + prod3;
        end
    endtask

    // always begin
    //     repeat(2000) @(posedge clk);
    //     rst_n = ~rst_n;
    // end
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        // Initialize
        error_count = 0;
        total_tests = 0;
        
        rst_n = 0;
        EN_mac = 0;
        mac_vecA_0 = 0;
        mac_vecB_0 = 0;
        mac_vecA_1 = 0;
        mac_vecB_1 = 0;
        mac_vecA_2 = 0;
        mac_vecB_2 = 0;
        mac_vecA_3 = 0;
        mac_vecB_3 = 0;
        EN_readMem = 0;

        // mult0_EN_readMem = 1;
        
        // Print header
        $display("\n========================================");
        $display("  DNN Accelerator Testbench");
        $display("  Using 4x multiplier_module from Project 2");
        $display("  Testing 8 iterations of 64 dot products");
        $display("  Memory wrapper instantiated in testbench");
        $display("========================================\n");
        
        // Apply reset
        $display("[%0t] Applying reset...", $time);
        @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        $display("[%0t] Reset released\n", $time);
        
        // ====================================================================
        // Test 8 iterations
        // ====================================================================
        for (k = 0; k < 8; k = k + 1) begin
            // // quick reset
            // rst_n = 0;
            // @(posedge clk);
            // rst_n = 1;

            $display("========================================");
            $display("  ITERATION %0d", k+1);
            $display("========================================\n");
            
            // ================================================================
            // Phase 1: Perform 64 dot products
            // ================================================================
            $display("[%0t] Phase 1: Starting 64 dot products...", $time);
            $display("        Using 4x Project 2 multiplier_module");
            $display("        Pipeline: 2 (mult) + 3 (adder) = 5 cycles\n");
            
            for (i = 0; i < 64; i = i + 1) begin
                // Wait until accelerator is ready
                while (!RDY_mac) begin
                    @(posedge clk);
                end
                
                // Generate test vectors
                test_vecA[0] = (i + 1 + k*64) & 16'hFFFF;
                test_vecB[0] = (i + k + 1) & 16'hFFFF;
                test_vecA[1] = (i + 2 + k*64) & 16'hFFFF;
                test_vecB[1] = (i + k + 2) & 16'hFFFF;
                test_vecA[2] = (i + 3 + k*64) & 16'hFFFF;
                test_vecB[2] = (i + k + 3) & 16'hFFFF;
                test_vecA[3] = (i + 4 + k*64) & 16'hFFFF;
                test_vecB[3] = (i + k + 4) & 16'hFFFF;
                
                // Apply inputs
                mac_vecA_0 = test_vecA[0];
                mac_vecB_0 = test_vecB[0];
                mac_vecA_1 = test_vecA[1];
                mac_vecB_1 = test_vecB[1];
                mac_vecA_2 = test_vecA[2];
                mac_vecB_2 = test_vecB[2];
                mac_vecA_3 = test_vecA[3];
                mac_vecB_3 = test_vecB[3];
                
                // Calculate expected result
                calculate_dot_product(
                    test_vecA[0], test_vecA[1], test_vecA[2], test_vecA[3],
                    test_vecB[0], test_vecB[1], test_vecB[2], test_vecB[3],
                    expected_results[i]
                );
                
                // Enable MAC
                EN_mac = 1;
                
                if (i % 16 == 0) begin
                    $display("[%0t] Dot product %0d:", $time, i);
                    $display("        A=[%0d, %0d, %0d, %0d]", 
                             test_vecA[0], test_vecA[1], test_vecA[2], test_vecA[3]);
                    $display("        B=[%0d, %0d, %0d, %0d]", 
                             test_vecB[0], test_vecB[1], test_vecB[2], test_vecB[3]);
                    $display("        Expected result = %0d", expected_results[i]);
                end
                
                @(posedge clk);
                EN_mac = 0;
            end
            
            $display("[%0t] All 64 dot products submitted", $time);
            
            // Wait for pipeline to complete
            repeat(20) @(posedge clk);
            
            while (RDY_mac) begin
                @(posedge clk);
            end
            
            $display("[%0t] Memory is now full\n", $time);
            
            // ================================================================
            // Phase 2: Read and verify results
            // ================================================================
            $display("[%0t] Phase 2: Reading back results...", $time);
            
            // Start read operation
            EN_readMem = 1;
            @(posedge clk);
            EN_readMem = 0;
            
            // Wait for first valid data
            while (!VALID_memVal) begin
                @(posedge clk);
            end
            
            // Wait one more cycle for data to be properly captured
            @(posedge clk);
            
            // Read and verify all 64 results
            for (j = 0; j < 64; j = j + 1) begin
                // Data is now valid, check it
                total_tests = total_tests + 1;

                if (memVal_data !== expected_results[j]) begin
                    $display("[%0t] ERROR at index %0d: Expected %0d, Got %0d", 
                             $time, j, expected_results[j], memVal_data);
                    error_count = error_count + 1;
                end 
                else begin
                    $display("[%0t] PASS! Result %0d: %0d", $time, j, memVal_data);
                end
                
                // Advance to next cycle
                @(posedge clk);
            end
            
            $display("[%0t] All 64 results verified", $time);
            
            repeat(10) @(posedge clk);
            $display("");
        end
        
        // ====================================================================
        // Test Summary
        // ====================================================================
        $display("\n========================================");
        $display("  TEST SUMMARY");
        $display("========================================");
        $display("Total tests: %0d", total_tests);
        $display("Errors:      %0d", error_count);
        if (error_count == 0) begin
            $display("STATUS:      PASS");
        end else begin
            $display("STATUS:      FAIL");
        end
        $display("========================================\n");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #2000000;  // 2ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end
    
    // ========================================================================
    // Waveform Dumping
    // ========================================================================
    initial begin
        $dumpfile("dnn_accelerator_tb.vcd");
        $dumpvars(0, dnn_accelerator_tb);
    end

endmodule: dnn_accelerator_tb
