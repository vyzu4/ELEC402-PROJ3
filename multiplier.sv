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
    
    // Multiplier pipeline registers
    // We use 2-stage pipeline: Stage 1 registers inputs, Stage 2 computes result
    logic [15:0] mult_stage1_a;            // Stage 1: input A
    logic [15:0] mult_stage1_b;            // Stage 1: input B
    logic        mult_stage1_valid;        // Stage 1: valid flag
    
    logic [31:0] mult_stage2_result;       // Stage 2: multiplication result
    logic        mult_stage2_valid;        // Stage 2: valid flag
    
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
    // Multiplier Pipeline (2 stages)
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
    
    // Stage 2: Perform multiplication and register result
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage2_result <= 32'h0;
            mult_stage2_valid  <= 1'b0;
        end else begin
            if (mult_stage1_valid) begin
                mult_stage2_result <= mult_stage1_a * mult_stage1_b;
                mult_stage2_valid  <= 1'b1;
            end else begin
                mult_stage2_valid  <= 1'b0;
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
            end else if (mult_stage2_valid && write_count < 7'd64) begin
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
    assign EN_writeMem    = mult_stage2_valid && (current_state == WRITING);
    assign writeMem_addr  = write_count[5:0];   // Use lower 6 bits as address
    assign writeMem_val   = mult_stage2_result;
    
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
