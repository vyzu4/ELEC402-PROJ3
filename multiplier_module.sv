// ============================================================================
// Project 2: Multiplier Module with Memory Storage
// ============================================================================
// This module performs 16-bit fixed-point multiplication and stores results
// in a 64-entry memory buffer. It uses a Finite State Machine (FSM) to 
// control when multiplication can occur and when memory can be read.
//
// BEGINNER'S GUIDE:
// - FSM: A state machine that controls the flow of operations
// - always_ff: Sequential logic that triggers on clock edges
// - always_comb: Combinational logic (no memory/state)
// - Pipeline: Breaking computation across multiple clock cycles
// ============================================================================

module multiplier_module (
    input  logic        clk,              // Clock signal
    input  logic        rst_n,            // Active-low reset (0 = reset)
    
    // Multiplication interface
    input  logic        EN_mult,          // Enable multiplication
    input  logic [15:0] mult_input0,      // First 16-bit input
    input  logic [15:0] mult_input1,      // Second 16-bit input
    output logic        RDY_mult,         // Ready signal (can accept new mult)
    
    // Memory block read interface
    input  logic        EN_blockRead,     // Enable block read from memory (high to read from mem block)
    output logic        VALID_memVal,     // Valid flag for output data (high for valid mem val)
    output logic [31:0] memVal_data,      // Memory output data (32-bit result)
    
    // Memory write interface (exposed)
    output logic        EN_writeMem,      // Enable write to memory
    output logic [5:0]  writeMem_addr,    // Write address
    output logic [31:0] writeMem_val,     // Write data
    
    // Memory read interface (exposed)
    output logic        EN_readMem,       // Enable read from memory (high to start reading mem)
    output logic [5:0]  readMem_addr,     // Address to read from
    input  logic [31:0] readMem_val       // Data read from memory
);

    // ========================================================================
    // Internal Signals and Parameters
    // ========================================================================
    
    // Multi-stage multiplier pipeline using shift-and-add
    // Stage 1: Register inputs
    logic [15:0] mult_stage1_a;
    logic [15:0] mult_stage1_b;
    logic        mult_stage1_valid;
    
    // Stage 2: Compute partial products for bits [3:0]
    logic [31:0] mult_stage2_pp0;     // Partial product for bit 0
    logic [31:0] mult_stage2_pp1;     // Partial product for bit 1
    logic [31:0] mult_stage2_pp2;     // Partial product for bit 2
    logic [31:0] mult_stage2_pp3;     // Partial product for bit 3
    logic [15:0] mult_stage2_a;       // Forward input a
    logic [15:0] mult_stage2_b;       // Forward input b
    logic        mult_stage2_valid;
    
    // Stage 3: Sum partial products [3:0] and compute partial products for bits [7:4]
    logic [31:0] mult_stage3_sum03;   // Sum of pp0 through pp3
    logic [31:0] mult_stage3_pp4;     // Partial product for bit 4
    logic [31:0] mult_stage3_pp5;     // Partial product for bit 5
    logic [31:0] mult_stage3_pp6;     // Partial product for bit 6
    logic [31:0] mult_stage3_pp7;     // Partial product for bit 7
    logic [15:0] mult_stage3_a;       // Forward input a
    logic [15:0] mult_stage3_b;       // Forward input b
    logic        mult_stage3_valid;
    
    // Stage 4: Sum partial products [7:4] and compute partial products for bits [11:8]
    logic [31:0] mult_stage4_sum07;   // Sum of all pp0 through pp7
    logic [31:0] mult_stage4_pp8;     // Partial product for bit 8
    logic [31:0] mult_stage4_pp9;     // Partial product for bit 9
    logic [31:0] mult_stage4_pp10;    // Partial product for bit 10
    logic [31:0] mult_stage4_pp11;    // Partial product for bit 11
    logic [15:0] mult_stage4_a;       // Forward input a
    logic [15:0] mult_stage4_b;       // Forward input b
    logic        mult_stage4_valid;
    
    // Stage 5: Sum partial products [11:8] and compute partial products for bits [15:12]
    logic [31:0] mult_stage5_sum011;  // Sum of all pp0 through pp11
    logic [31:0] mult_stage5_pp12;    // Partial product for bit 12
    logic [31:0] mult_stage5_pp13;    // Partial product for bit 13
    logic [31:0] mult_stage5_pp14;    // Partial product for bit 14
    logic [31:0] mult_stage5_pp15;    // Partial product for bit 15
    logic        mult_stage5_valid;
    
    // Stage 6: Final sum
    logic [31:0] mult_stage6_result;
    logic        mult_stage6_valid;
    
    // Memory control counters
    logic [6:0]  write_count;              // Count of items written (0-64)
    logic [5:0]  read_count;               // Count of items read (0-64)
    
    // FSM States
    typedef enum logic [1:0] {
        IDLE       = 2'b00,   // Waiting for operation
        WRITING    = 2'b01,   // Writing multiplication results to memory
        FULL       = 2'b10,   // Memory full, ready to read
        READING    = 2'b11    // Reading from memory
    } state_t;
    
    state_t current_state, next_state;
    
    // ========================================================================
    // Multiplier Pipeline (6 stages using shift-and-add)
    // ========================================================================
    // Stage 1: Register inputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage1_a     <= 16'h0;
            mult_stage1_b     <= 16'h0;
            mult_stage1_valid <= 1'b0;
        end else begin
            if (EN_mult && RDY_mult) begin
                mult_stage1_a     <= mult_input0;
                mult_stage1_b     <= mult_input1;
                mult_stage1_valid <= 1'b1;
            end else begin
                mult_stage1_valid <= 1'b0;
            end
        end
    end
    
    // Stage 2: Compute partial products for bits [3:0] of multiplier
    // For each bit i: if b[i] == 1, partial_product = a << i, else 0
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage2_pp0   <= 32'h0;
            mult_stage2_pp1   <= 32'h0;
            mult_stage2_pp2   <= 32'h0;
            mult_stage2_pp3   <= 32'h0;
            mult_stage2_a     <= 16'h0;
            mult_stage2_b     <= 16'h0;
            mult_stage2_valid <= 1'b0;
        end else begin
            if (mult_stage1_valid) begin
                mult_stage2_pp0   <= mult_stage1_b[0] ? {16'h0, mult_stage1_a} : 32'h0;
                mult_stage2_pp1   <= mult_stage1_b[1] ? {15'h0, mult_stage1_a, 1'b0} : 32'h0;
                mult_stage2_pp2   <= mult_stage1_b[2] ? {14'h0, mult_stage1_a, 2'b0} : 32'h0;
                mult_stage2_pp3   <= mult_stage1_b[3] ? {13'h0, mult_stage1_a, 3'b0} : 32'h0;
                mult_stage2_a     <= mult_stage1_a;
                mult_stage2_b     <= mult_stage1_b;
                mult_stage2_valid <= 1'b1;
            end else begin
                mult_stage2_valid <= 1'b0;
            end
        end
    end
    
    // Stage 3: Sum partial products [3:0] and compute partial products for bits [7:4]
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage3_sum03 <= 32'h0;
            mult_stage3_pp4   <= 32'h0;
            mult_stage3_pp5   <= 32'h0;
            mult_stage3_pp6   <= 32'h0;
            mult_stage3_pp7   <= 32'h0;
            mult_stage3_a     <= 16'h0;
            mult_stage3_b     <= 16'h0;
            mult_stage3_valid <= 1'b0;
        end else begin
            if (mult_stage2_valid) begin
                mult_stage3_sum03 <= mult_stage2_pp0 + mult_stage2_pp1 + mult_stage2_pp2 + mult_stage2_pp3;
                mult_stage3_pp4   <= mult_stage2_b[4] ? {12'h0, mult_stage2_a, 4'b0} : 32'h0;
                mult_stage3_pp5   <= mult_stage2_b[5] ? {11'h0, mult_stage2_a, 5'b0} : 32'h0;
                mult_stage3_pp6   <= mult_stage2_b[6] ? {10'h0, mult_stage2_a, 6'b0} : 32'h0;
                mult_stage3_pp7   <= mult_stage2_b[7] ? {9'h0, mult_stage2_a, 7'b0} : 32'h0;
                mult_stage3_a     <= mult_stage2_a;
                mult_stage3_b     <= mult_stage2_b;
                mult_stage3_valid <= 1'b1;
            end else begin
                mult_stage3_valid <= 1'b0;
            end
        end
    end
    
    // Stage 4: Sum partial products [7:4] with previous sum and compute partial products for bits [11:8]
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage4_sum07 <= 32'h0;
            mult_stage4_pp8   <= 32'h0;
            mult_stage4_pp9   <= 32'h0;
            mult_stage4_pp10  <= 32'h0;
            mult_stage4_pp11  <= 32'h0;
            mult_stage4_a     <= 16'h0;
            mult_stage4_b     <= 16'h0;
            mult_stage4_valid <= 1'b0;
        end else begin
            if (mult_stage3_valid) begin
                mult_stage4_sum07 <= mult_stage3_sum03 + mult_stage3_pp4 + mult_stage3_pp5 + mult_stage3_pp6 + mult_stage3_pp7;
                mult_stage4_pp8   <= mult_stage3_b[8] ? {8'h0, mult_stage3_a, 8'b0} : 32'h0;
                mult_stage4_pp9   <= mult_stage3_b[9] ? {7'h0, mult_stage3_a, 9'b0} : 32'h0;
                mult_stage4_pp10  <= mult_stage3_b[10] ? {6'h0, mult_stage3_a, 10'b0} : 32'h0;
                mult_stage4_pp11  <= mult_stage3_b[11] ? {5'h0, mult_stage3_a, 11'b0} : 32'h0;
                mult_stage4_a     <= mult_stage3_a;
                mult_stage4_b     <= mult_stage3_b;
                mult_stage4_valid <= 1'b1;
            end else begin
                mult_stage4_valid <= 1'b0;
            end
        end
    end
    
    // Stage 5: Sum partial products [11:8] with previous sum and compute partial products for bits [15:12]
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage5_sum011 <= 32'h0;
            mult_stage5_pp12   <= 32'h0;
            mult_stage5_pp13   <= 32'h0;
            mult_stage5_pp14   <= 32'h0;
            mult_stage5_pp15   <= 32'h0;
            mult_stage5_valid  <= 1'b0;
        end else begin
            if (mult_stage4_valid) begin
                mult_stage5_sum011 <= mult_stage4_sum07 + mult_stage4_pp8 + mult_stage4_pp9 + mult_stage4_pp10 + mult_stage4_pp11;
                mult_stage5_pp12   <= mult_stage4_b[12] ? {4'h0, mult_stage4_a, 12'b0} : 32'h0;
                mult_stage5_pp13   <= mult_stage4_b[13] ? {3'h0, mult_stage4_a, 13'b0} : 32'h0;
                mult_stage5_pp14   <= mult_stage4_b[14] ? {2'h0, mult_stage4_a, 14'b0} : 32'h0;
                mult_stage5_pp15   <= mult_stage4_b[15] ? {1'h0, mult_stage4_a, 15'b0} : 32'h0;
                mult_stage5_valid  <= 1'b1;
            end else begin
                mult_stage5_valid <= 1'b0;
            end
        end
    end
    
    // Stage 6: Final sum of all partial products
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage6_result <= 32'h0;
            mult_stage6_valid  <= 1'b0;
        end else begin
            if (mult_stage5_valid) begin
                mult_stage6_result <= mult_stage5_sum011 + mult_stage5_pp12 + mult_stage5_pp13 + mult_stage5_pp14 + mult_stage5_pp15;
                mult_stage6_valid  <= 1'b1;
            end else begin
                mult_stage6_valid  <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // FSM State Register
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // ========================================================================
    // FSM Next State Logic
    // ========================================================================
    always_comb begin
        // Default: stay in current state
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                // Start writing when first multiplication occurs
                if (EN_mult && RDY_mult) begin
                    next_state = WRITING;
                end
            end
            
            WRITING: begin
                // Transition to FULL when we've written 64 items
                if (write_count == 7'd64) begin
                    next_state = FULL;
                end
            end
            
            FULL: begin
                // Start reading when EN_blockRead is asserted
                if (EN_blockRead) begin
                    next_state = READING;
                end
            end
            
            READING: begin
                // Return to IDLE after reading all 64 entries
                if (read_count == 6'd63 && EN_readMem) begin
                // if (EN_readMem) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ========================================================================
    // Write Counter - Counts multiplication results written to memory
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_count <= 7'd0;
        end else begin
            if (current_state == IDLE || current_state == READING) begin
                write_count <= 7'd0;  // Reset counter when not writing
            end else if (mult_stage6_valid && write_count < 7'd64) begin
                write_count <= write_count + 7'd1;
            end
        end
    end
    
    // ========================================================================
    // Read Counter - Counts items read from memory
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_count <= 6'd0;
        end else begin
            if (current_state == FULL) begin
                read_count <= 6'd0;  // Reset at start of read
            end else if (current_state == READING && EN_readMem) begin
                read_count <= read_count + 6'd1;
            end
        end
    end
    
    // ========================================================================
    // Memory Write Control
    // ========================================================================
    assign EN_writeMem    = mult_stage6_valid && (current_state == WRITING);
    assign writeMem_addr  = write_count[5:0];   // Use lower 6 bits as address
    assign writeMem_val   = mult_stage6_result;
    
    // ========================================================================
    // Memory Read Control
    // ========================================================================
    // Directly drive the output ports
    assign EN_readMem   = (current_state == READING);
    assign readMem_addr = read_count;
    
    // ========================================================================
    // Output Assignments
    // ========================================================================
    // RDY_mult: Can accept multiplication when not FULL and memory not full
    assign RDY_mult = (current_state == IDLE || current_state == WRITING) && 
                      (write_count < 7'd64);
    
    // Memory output data and valid flag (delayed by 1 cycle due to memory read)
    logic VALID_memVal_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            VALID_memVal_reg <= 1'b0;
            memVal_data      <= 32'h0;
        end else begin
            VALID_memVal_reg <= EN_readMem;
            memVal_data      <= readMem_val;  // Directly from input port
        end
    end
    
    assign VALID_memVal = VALID_memVal_reg;
    
    // ========================================================================
    // Memory Interface - FULLY EXTERNAL
    // ========================================================================
    // Both read and write interfaces are now exposed as ports.
    // The memory should be instantiated OUTSIDE this module.
    // This allows for:
    // - Easy memory replacement/testing
    // - Clear separation of concerns
    // - Better modularity
    // - Simplified synthesis (memory can be black-boxed)

endmodule: multiplier_module
