// ============================================================================
// Testbench for Multiplier Module (Project 2)
// ============================================================================
// This testbench verifies the multiplier module by:
// 1. Performing 64 multiplications and storing results
// 2. Reading back all 64 results
// 3. Verifying correctness
// 4. Repeating for 8 iterations as required
//
// BEGINNER'S GUIDE:
// - initial: Runs once at simulation start
// - $display: Prints messages to console
// - $finish: Ends simulation
// - #10: Waits 10 time units (10ns with our timescale)
// ============================================================================

`timescale 1ns/1ps

module multiplier_module_tb;

    // ========================================================================
    // Testbench Signals
    // ========================================================================
    logic        clk;
    logic        rst_n;
    
    // Multiplication interface
    logic        EN_mult;
    logic [15:0] mult_input0;
    logic [15:0] mult_input1;
    logic        RDY_mult;
    
    // Memory read interface
    logic        EN_blockRead;
    logic        VALID_memVal;
    logic [31:0] memVal_data;
    
    // Memory write interface signals (exposed from module)
    logic        EN_writeMem;
    logic [5:0]  writeMem_addr;
    logic [31:0] writeMem_val;
    
    // Memory read interface signals (exposed from module)
    logic        EN_readMem;
    logic [5:0]  readMem_addr;
    logic [31:0] readMem_val;
    
    // ========================================================================
    // Clock Generation (100MHz = 10ns period)
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Toggle every 5ns -> 10ns period
    end
    
    // ========================================================================
    // DUT (Device Under Test) Instantiation
    // ========================================================================
    multiplier_module multiplier_dut (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mult(EN_mult),
        .mult_input0(mult_input0),
        .mult_input1(mult_input1),
        .RDY_mult(RDY_mult),
        .EN_blockRead(EN_blockRead),
        .VALID_memVal(VALID_memVal),
        .memVal_data(memVal_data),
        // Memory write interface (outputs)
        .EN_writeMem(EN_writeMem),
        .writeMem_addr(writeMem_addr),
        .writeMem_val(writeMem_val),
        // Memory read interface (outputs + input)
        .EN_readMem(EN_readMem),
        .readMem_addr(readMem_addr),
        .readMem_val(readMem_val)
    );
    
    // ========================================================================
    // External Memory Instance
    // ========================================================================
    // Memory is now external, connected through the exposed interfaces
    memory_wrapper_2port #(
        .DEPTH(64),
        .LOGDEPTH(6),
        .WIDTH(32),
        .MEMTYPE(0),
        .TECHNODE(0),
        .COL_MUX(1)
    ) external_memory (
        // Read port A
        .clkA(clk),
        .aA(readMem_addr),
        .cenA(~EN_readMem),         // Active low enable
        .q(readMem_val),
        
        // Write port B
        .clkB(clk),
        .aB(writeMem_addr),
        .cenB(~EN_writeMem),        // Active low enable
        .d(writeMem_val)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer i, j, k;
    integer error_count;
    integer total_tests;
    logic [31:0] expected_result;
    
    // Storage for expected results (for verification)
    logic [31:0] expected_results [0:63];
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        // Initialize variables
        error_count = 0;
        total_tests = 0;
        
        // Initialize signals
        rst_n = 0;
        EN_mult = 0;
        mult_input0 = 0;
        mult_input1 = 0;
        EN_blockRead = 0;
        
        // Print header
        $display("\n========================================");
        $display("  Multiplier Module Testbench");
        $display("  Testing 8 iterations of 64 multiplications");
        $display("========================================\n");
        
        // Apply reset
        $display("[%0t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        $display("[%0t] Reset released\n", $time);
        
        // ====================================================================
        // Test 8 iterations as required by the project
        // ====================================================================
        for (k = 0; k < 8; k = k + 1) begin
            $display("========================================");
            $display("  ITERATION %0d", k+1);
            $display("========================================\n");
            
            // ================================================================
            // Phase 1: Perform 64 multiplications
            // ================================================================
            $display("[%0t] Phase 1: Starting 64 multiplications...", $time);
            
            for (i = 0; i < 64; i = i + 1) begin
                // Wait until multiplier is ready
                while (!RDY_mult) begin
                    @(posedge clk);
                end
                
                // Generate test inputs (can customize this)
                // Using simple pattern: input0 = i+1, input1 = i+k+1
                mult_input0 = (i + 1 + k*64) & 16'hFFFF;
                mult_input1 = (i + k + 1) & 16'hFFFF;
                
                // Calculate expected result
                expected_results[i] = mult_input0 * mult_input1;
                
                // Assert EN_mult for one cycle
                EN_mult = 1;
                
                if (i % 16 == 0) begin
                    $display("[%0t] Multiplication %0d: %0d x %0d = %0d", 
                             $time, i, mult_input0, mult_input1, expected_results[i]);
                end
                
                @(posedge clk);
                EN_mult = 0;
                
                // For early multiplications, we can continue immediately
                // But near the end, we need to wait for memory to have space
            end
            
            $display("[%0t] All 64 multiplications submitted", $time);
            
            // Wait for all multiplications to complete and be written to memory
            // The pipeline has 2 stages, so wait a few cycles
            repeat(10) @(posedge clk);
            
            // Wait until RDY_mult goes low (indicating memory is full)
            while (RDY_mult) begin
                @(posedge clk);
            end
            
            $display("[%0t] Memory is now full (64 results stored)\n", $time);
            
            // ================================================================
            // Phase 2: Read back all 64 results and verify
            // ================================================================
            $display("[%0t] Phase 2: Reading back results...", $time);
            
            // Assert EN_blockRead to start reading
            EN_blockRead = 1;
            @(posedge clk);
            EN_blockRead = 0;
            
            // Wait for first valid data (there's a delay due to memory read)
            while (!VALID_memVal) begin
                @(posedge clk);
            end
            
            // Read and verify all 64 results
            for (j = 0; j < 64; j = j + 1) begin
                // Wait for valid data
                while (!VALID_memVal) begin
                    @(posedge clk);
                end
                
                // Check result
                total_tests = total_tests + 1;
                if (memVal_data !== expected_results[j]) begin
                    $display("[%0t] ERROR at index %0d: Expected %0d, Got %0d", 
                             $time, j, expected_results[j], memVal_data);
                    error_count = error_count + 1;
                end else if (j % 16 == 0) begin
                    $display("[%0t] Result %0d: %0d ✓", $time, j, memVal_data);
                end
                
                @(posedge clk);
            end
            
            $display("[%0t] All 64 results read back", $time);
            
            // Wait a few cycles between iterations
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
            $display("STATUS:      PASS ✓");
        end else begin
            $display("STATUS:      FAIL ✗");
        end
        $display("========================================\n");
        
        // Finish simulation
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // ========================================================================
    // Timeout Watchdog (prevent infinite simulation)
    // ========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end
    
    // ========================================================================
    // Waveform Dumping (for viewing in GTKWave or similar)
    // ========================================================================
    initial begin
        $dumpfile("multiplier_module_tb.vcd");
        $dumpvars(0, multiplier_module_tb);
    end

endmodule: multiplier_module_tb
