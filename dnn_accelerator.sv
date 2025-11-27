// ============================================================================
// Project 3: Dot-Product-Based DNN Accelerator
// ============================================================================
// This module performs 4-element dot products with 16-bit fixed-point values
// and stores results in a 64-entry memory buffer.
//
// Computation: result = (A0*B0) + (A1*B1) + (A2*B2) + (A3*B3)
//
// DESIGN APPROACH - MAXIMUM IP REUSE:
// This design uses 4 complete instances of multiplier_module from Project 2!
// We tap into the write interface to capture multiplication results without
// actually storing them in each multiplier's memory. The 4 products are
// summed and stored in a central result memory.
//
// Benefits:
// - Maximum code reuse from Project 2
// - Each multiplier is already tested and verified
// - Shows system-level integration
// - Demonstrates hierarchical design
// ============================================================================

module dnn_accelerator (
    input  logic         clk,
    input  logic         rst_n,
    
    // MAC (Multiply-Accumulate) interface
    input  logic         EN_mac,              // Enable MAC operation
    input  logic [15:0]  mac_vecA_0,          // Vector A, element 0
    input  logic [15:0]  mac_vecB_0,          // Vector B, element 0
    input  logic [15:0]  mac_vecA_1,          // Vector A, element 1
    input  logic [15:0]  mac_vecB_1,          // Vector B, element 1
    input  logic [15:0]  mac_vecA_2,          // Vector A, element 2
    input  logic [15:0]  mac_vecB_2,          // Vector B, element 2
    input  logic [15:0]  mac_vecA_3,          // Vector A, element 3
    input  logic [15:0]  mac_vecB_3,          // Vector B, element 3
    output logic         RDY_mac,             // Ready to accept new operation
    
    // Memory read interface  
    input  logic         EN_readMem,          // Enable memory read
    output logic         VALID_memVal,        // Valid flag for output
    output logic [31:0]  memVal_data          // Memory output data
);

    // ========================================================================
    // Multiplier Module Write Interfaces (we tap these for results)
    // ========================================================================
    logic        mult0_EN_writeMem;
    logic [31:0] mult0_writeMem_val;
    logic        mult1_EN_writeMem;
    logic [31:0] mult1_writeMem_val;
    logic        mult2_EN_writeMem;
    logic [31:0] mult2_writeMem_val;
    logic        mult3_EN_writeMem;
    logic [31:0] mult3_writeMem_val;
    
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

    logic        result_EN_readMem_int;
    
    // Tie off unused read interfaces
    assign mult0_EN_blockRead = 1'b1;
    assign mult0_readMem_val = 32'h0;
    assign mult1_EN_blockRead = 1'b1;
    assign mult1_readMem_val = 32'h0;
    assign mult2_EN_blockRead = 1'b1;
    assign mult2_readMem_val = 32'h0;
    assign mult3_EN_blockRead = 1'b1;
    assign mult3_readMem_val = 32'h0;
    
    // ========================================================================
    // Adder Tree Pipeline
    // ========================================================================
    // Stage 1: Capture products when ANY multiplier signals write
    // All multipliers are triggered together, so they complete together
    // Use mult0_EN_writeMem as the trigger (they all finish simultaneously)
    logic [31:0] stage1_prod0, stage1_prod1, stage1_prod2, stage1_prod3;
    logic        stage1_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_prod0 <= 32'h0;
            stage1_prod1 <= 32'h0;
            stage1_prod2 <= 32'h0;
            stage1_prod3 <= 32'h0;
            stage1_valid <= 1'b0;
        end else begin
            // Capture products when first multiplier signals write
            // Since all are triggered together, they all complete together
            // We only check mult0_EN_writeMem, but capture from all 4
            if (mult0_EN_writeMem) begin
                stage1_prod0 <= mult0_writeMem_val;
                stage1_prod1 <= mult1_writeMem_val;
                stage1_prod2 <= mult2_writeMem_val;
                stage1_prod3 <= mult3_writeMem_val;
                stage1_valid <= 1'b1;
            end else begin
                stage1_valid <= 1'b0;
            end
        end
    end
    
    // Stage 2: Partial sums
    logic [31:0] stage2_sum01, stage2_sum23;
    logic        stage2_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_sum01 <= 32'h0;
            stage2_sum23 <= 32'h0;
            stage2_valid <= 1'b0;
        end else begin
            if (stage1_valid) begin
                stage2_sum01 <= stage1_prod0 + stage1_prod1;
                stage2_sum23 <= stage1_prod2 + stage1_prod3;
                stage2_valid <= 1'b1;
            end else begin
                stage2_valid <= 1'b0;
            end
        end
    end
    
    // Stage 3: Final sum
    logic [31:0] stage3_result;
    logic        stage3_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage3_result <= 32'h0;
            stage3_valid  <= 1'b0;
        end else begin
            if (stage2_valid) begin
                stage3_result <= stage2_sum01 + stage2_sum23;
                stage3_valid  <= 1'b1;
            end else begin
                stage3_valid  <= 1'b0;
            end
        end
    end

    // // stage 4
    // logic [31:0] final_sum;
    
    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         final_sum <= 32'h0;
    //     end else begin
    //         final_sum  <= stage3_result;
    //     end
    // end

    // ========================================================================
    // Result Memory Control
    // ========================================================================
    logic [6:0]  result_write_count;  // 0-64
    logic [5:0]  result_read_count;   // 0-63
    
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        WRITING = 2'b01,
        FULL    = 2'b10,
        READING = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // FSM Next State Logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (EN_mac) begin
                    next_state = WRITING;
                end
            end
            
            WRITING: begin
                if (result_write_count == 7'd64) begin
                    next_state = FULL;
                end
            end
            
            FULL: begin
                if (EN_readMem) begin
                    next_state = READING;
                end
            end
            
            READING: begin
                if (result_read_count == 6'd63 && result_EN_readMem_int) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Write Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_write_count <= 7'd0;
        end else begin
            if (current_state == IDLE || current_state == READING) begin
                result_write_count <= 7'd0;
            end else if (stage3_valid && result_write_count < 7'd64) begin
                result_write_count <= result_write_count + 7'd1;
            end
        end
    end
    
    // Read Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_read_count <= 6'd0;
        end else begin
            if (current_state == FULL) begin
                result_read_count <= 6'd0;
            end else if (current_state == READING && result_EN_readMem_int) begin
                result_read_count <= result_read_count + 6'd1;
            end
        end
    end
    
    // Ready signal
    assign RDY_mac = (current_state == IDLE || current_state == WRITING) && 
                     (result_write_count < 7'd64);
    
    // ========================================================================
    // Result Memory Interface
    // ========================================================================
    logic        result_EN_writeMem;
    logic [5:0]  result_writeMem_addr;
    logic [31:0] result_writeMem_val;
    // logic        result_EN_readMem_int;
    logic [5:0]  result_readMem_addr;
    logic [31:0] result_readMem_val;
    
    assign result_EN_writeMem   = stage3_valid && (current_state == WRITING);
    assign result_writeMem_addr = result_write_count[5:0];
    assign result_writeMem_val  = stage3_result;
    
    assign result_EN_readMem_int = (current_state == READING);
    assign result_readMem_addr   = result_read_count;
    
    // Output register
    logic VALID_memVal_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            VALID_memVal_reg <= 1'b0;
            memVal_data      <= 32'h0;
        end else begin
            VALID_memVal_reg <= result_EN_readMem_int;
            memVal_data      <= result_readMem_val;
        end
    end
    
    assign VALID_memVal = VALID_memVal_reg;
    
    // ========================================================================
    // Result Memory Instance
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
    // Multiplier Module Instances (4x from Project 2)
    // ========================================================================
    // Each multiplier performs one element of the dot product
    // We trigger all 4 simultaneously and collect results via write interface
    
    multiplier_module mult_inst_0 (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mult(EN_mac),
        .mult_input0(mac_vecA_0),
        .mult_input1(mac_vecB_0),
        .RDY_mult(RDY_mac),  // Not used
        .EN_blockRead(mult0_EN_blockRead),
        .VALID_memVal(mult0_VALID_memVal),
        .memVal_data(mult0_memVal_data),
        .EN_writeMem(mult0_EN_writeMem),
        .writeMem_addr(mult0_writeMem_addr),
        .writeMem_val(mult0_writeMem_val),
        .EN_readMem(mult0_EN_readMem),
        .readMem_addr(mult0_readMem_addr),
        .readMem_val(mult0_readMem_val)
    );
    
    multiplier_module mult_inst_1 (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mult(EN_mac),
        .mult_input0(mac_vecA_1),
        .mult_input1(mac_vecB_1),
        .RDY_mult(RDY_mac),
        .EN_blockRead(mult1_EN_blockRead),
        .VALID_memVal(mult1_VALID_memVal),
        .memVal_data(mult1_memVal_data),
        .EN_writeMem(mult1_EN_writeMem),
        .writeMem_addr(mult1_writeMem_addr),
        .writeMem_val(mult1_writeMem_val),
        .EN_readMem(mult1_EN_readMem),
        .readMem_addr(mult1_readMem_addr),
        .readMem_val(mult1_readMem_val)
    );
    
    multiplier_module mult_inst_2 (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mult(EN_mac),
        .mult_input0(mac_vecA_2),
        .mult_input1(mac_vecB_2),
        .RDY_mult(RDY_mac),
        .EN_blockRead(mult2_EN_blockRead),
        .VALID_memVal(mult2_VALID_memVal),
        .memVal_data(mult2_memVal_data),
        .EN_writeMem(mult2_EN_writeMem),
        .writeMem_addr(mult2_writeMem_addr),
        .writeMem_val(mult2_writeMem_val),
        .EN_readMem(mult2_EN_readMem),
        .readMem_addr(mult2_readMem_addr),
        .readMem_val(mult2_readMem_val)
    );
    
    multiplier_module mult_inst_3 (
        .clk(clk),
        .rst_n(rst_n),
        .EN_mult(EN_mac),
        .mult_input0(mac_vecA_3),
        .mult_input1(mac_vecB_3),
        .RDY_mult(RDY_mac),
        .EN_blockRead(mult3_EN_blockRead),
        .VALID_memVal(mult3_VALID_memVal),
        .memVal_data(mult3_memVal_data),
        .EN_writeMem(mult3_EN_writeMem),
        .writeMem_addr(mult3_writeMem_addr),
        .writeMem_val(mult3_writeMem_val),
        .EN_readMem(mult3_EN_readMem),
        .readMem_addr(mult3_readMem_addr),
        .readMem_val(mult3_readMem_val)
    );

endmodule: dnn_accelerator
