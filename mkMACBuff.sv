// ============================================================================
// Project 3: Dot-Product-Based DNN Accelerator (mkMACBuff)
// ============================================================================
// This module performs 4-element dot products with 16-bit fixed-point values
// and stores results in a 64-entry memory buffer.
//
// Computation: result = (A0*B0) + (A1*B1) + (A2*B2) + (A3*B3)
//
// PIPELINE STAGES (Total: 6 cycles):
//   Stage 0:   Input registration (1 cycle)
//   Stage 1-4: multiplier_800M_16b pipeline (4 cycles)
//   Stage 5:   Adder tree for dot product (1 cycle)
//
// DESIGN APPROACH - USING multiplier_800M_16b:
// This design uses 4 instances of the multiplier_800M_16b module.
// The multiplier has a 4-stage pipeline and outputs a valid result with
// VALID_output signal. We capture the 4 products and sum them in an
// additional adder tree stage.
//
// Benefits:
// - Uses optimized 800MHz multiplier design
// - Cleaner interface with valid output signaling
// - Deep pipelining for high-frequency operation
// ============================================================================

module mkMACBuff (
    input  CLK, 
    input  RST_N,
    
    // MAC (Multiply-Accumulate) interface
    input  EN_mac,                // Enable MAC operation
    output RDY_mac,               // Ready to accept new operation
    input  [15:0] mac_vectA_0,    // Vector A, element 0
    input  [15:0] mac_vectB_0,    // Vector B, element 0
    input  [15:0] mac_vectA_1,    // Vector A, element 1
    input  [15:0] mac_vectB_1,    // Vector B, element 1
    input  [15:0] mac_vectA_2,    // Vector A, element 2
    input  [15:0] mac_vectB_2,    // Vector B, element 2
    input  [15:0] mac_vectA_3,    // Vector A, element 3
    input  [15:0] mac_vectB_3,    // Vector B, element 3
    
    // Memory write interface (internal to memory)
    output EN_writeMem,           // Enable memory write
    output [5:0] writeMem_addr,   // Write address
    output [33:0] writeMem_val,   // Write data (34-bit for dot product result)
    
    // Block read control
    input  EN_blockRead,          // Enable block read
    output RDY_blockRead,         // Ready for block read
    
    // Memory read interface (internal to memory)
    output EN_readMem,            // Enable memory read
    output [5:0] readMem_addr,    // Read address
    input  [33:0] readMem_val,    // Read data from memory
    
    // Memory value output interface
    output VALID_memVal,          // Valid flag for output
    output [33:0] memVal_data     // Memory output data
);

    // N is determined by the required precision for dot product:
    // 16-bit x 16-bit = 32-bit products
    // Sum of 4 products needs 2 extra bits: 32 + 2 = 34 bits
    // So N = 33 (for [33:0] which is 34 bits)
    localparam N = 33;

    // ========================================================================
    // Multiplier Module Signals
    // ========================================================================
    logic        mult0_VALID_output;
    logic [31:0] mult0_output_val;
    logic        mult0_stage1_occupied, mult0_stage2_occupied, mult0_stage3_occupied;
    
    logic        mult1_VALID_output;
    logic [31:0] mult1_output_val;
    logic        mult1_stage1_occupied, mult1_stage2_occupied, mult1_stage3_occupied;
    
    logic        mult2_VALID_output;
    logic [31:0] mult2_output_val;
    logic        mult2_stage1_occupied, mult2_stage2_occupied, mult2_stage3_occupied;
    
    logic        mult3_VALID_output;
    logic [31:0] mult3_output_val;
    logic        mult3_stage1_occupied, mult3_stage2_occupied, mult3_stage3_occupied;

    logic        result_EN_readMem_int;

    // ========================================================================
    // Adder Tree Pipeline
    // ========================================================================
    // Stage 1: Capture products when multipliers signal valid output
    // All multipliers are triggered together, so they complete together
    logic [31:0] stage1_prod0, stage1_prod1, stage1_prod2, stage1_prod3;
    logic        stage1_valid;
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            stage1_prod0 <= 32'h0;
            stage1_prod1 <= 32'h0;
            stage1_prod2 <= 32'h0;
            stage1_prod3 <= 32'h0;
            stage1_valid <= 1'b0;
        end else begin
            // Capture products when multipliers signal valid output
            // Since all are triggered together, they all complete together
            if (mult0_VALID_output) begin
                stage1_prod0 <= mult0_output_val;
                stage1_prod1 <= mult1_output_val;
                stage1_prod2 <= mult2_output_val;
                stage1_prod3 <= mult3_output_val;
                stage1_valid <= 1'b1;
            end else begin
                stage1_valid <= 1'b0;
            end
        end
    end
    
    // Stage 2: Sum all 4 products (34-bit to handle overflow)
    // Using binary tree addition for timing:
    // First level: add pairs
    logic [32:0] stage2_sum01, stage2_sum23;
    logic        stage2_valid;
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            stage2_sum01 <= 33'h0;
            stage2_sum23 <= 33'h0;
            stage2_valid <= 1'b0;
        end else begin
            if (stage1_valid) begin
                stage2_sum01 <= {1'b0, stage1_prod0} + {1'b0, stage1_prod1};
                stage2_sum23 <= {1'b0, stage1_prod2} + {1'b0, stage1_prod3};
                stage2_valid <= 1'b1;
            end else begin
                stage2_valid <= 1'b0;
            end
        end
    end
    
    // Stage 3: Final sum (34-bit to handle final overflow)
    logic [33:0] stage3_result;
    logic        stage3_valid;
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            stage3_result <= 34'h0;
            stage3_valid  <= 1'b0;
        end else begin
            if (stage2_valid) begin
                stage3_result <= {1'b0, stage2_sum01} + {1'b0, stage2_sum23};
                stage3_valid  <= 1'b1;
            end else begin
                stage3_valid  <= 1'b0;
            end
        end
    end

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
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (EN_mac) begin
                    next_state = WRITING;
                end
            end
            
            WRITING: begin
                if (result_write_count == 7'd63) begin
                    next_state = FULL;
                end
            end
            
            FULL: begin
                if (EN_blockRead) begin
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
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
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
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            result_read_count <= 6'd0;
        end else begin
            if (current_state == FULL) begin
                result_read_count <= 6'd0;
            end else if (current_state == READING && result_EN_readMem_int) begin
                result_read_count <= result_read_count + 6'd1;
            end
        end
    end
    
    // Ready signals
    assign RDY_mac = (current_state == IDLE || current_state == WRITING) && 
                     (result_write_count < 7'd57);  // Adjusted for 6-cycle latency (64-7=57)
    assign RDY_blockRead = (current_state == FULL);
    
    // ========================================================================
    // Memory Interface Signals
    // ========================================================================
    assign EN_writeMem   = stage3_valid && (current_state == WRITING);
    assign writeMem_addr = result_write_count[5:0];
    assign writeMem_val  = stage3_result;
    
    assign result_EN_readMem_int = (current_state == READING);
    assign EN_readMem      = result_EN_readMem_int;
    assign readMem_addr    = result_read_count;
    
    // Output registers
    logic VALID_memVal_reg;
    logic VALID_memVal_reg2;
    logic [33:0] memVal_data_reg;
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            VALID_memVal_reg <= 1'b0;
            memVal_data_reg  <= 34'h0;
        end else begin
            VALID_memVal_reg <= result_EN_readMem_int;
            VALID_memVal_reg2 <= VALID_memVal_reg;
            memVal_data_reg  <= readMem_val;
        end
    end
    
    assign VALID_memVal = VALID_memVal_reg2;
    assign memVal_data = memVal_data_reg;
    
    // ========================================================================
    // Input Pipeline Stage (for timing)
    // ========================================================================
    logic [15:0] mac_vectA_0_reg, mac_vectB_0_reg;
    logic [15:0] mac_vectA_1_reg, mac_vectB_1_reg;
    logic [15:0] mac_vectA_2_reg, mac_vectB_2_reg;
    logic [15:0] mac_vectA_3_reg, mac_vectB_3_reg;
    logic        EN_mac_reg;
    
    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            mac_vectA_0_reg <= 16'h0;
            mac_vectB_0_reg <= 16'h0;
            mac_vectA_1_reg <= 16'h0;
            mac_vectB_1_reg <= 16'h0;
            mac_vectA_2_reg <= 16'h0;
            mac_vectB_2_reg <= 16'h0;
            mac_vectA_3_reg <= 16'h0;
            mac_vectB_3_reg <= 16'h0;
            EN_mac_reg <= 1'b0;
        end else begin
            if (EN_mac) begin
                mac_vectA_0_reg <= mac_vectA_0;
                mac_vectB_0_reg <= mac_vectB_0;
                mac_vectA_1_reg <= mac_vectA_1;
                mac_vectB_1_reg <= mac_vectB_1;
                mac_vectA_2_reg <= mac_vectA_2;
                mac_vectB_2_reg <= mac_vectB_2;
                mac_vectA_3_reg <= mac_vectA_3;
                mac_vectB_3_reg <= mac_vectB_3;
                EN_mac_reg <= 1'b1;
            end else begin
                EN_mac_reg <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // Multiplier Module Instances (4x multiplier_800M_16b)
    // ========================================================================
    // Each multiplier performs one element of the dot product
    // We trigger all 4 simultaneously and collect results via VALID_output
    
    multiplier_800M_16b mult_inst_0 (
        .CLK(CLK),
        .RST_N(RST_N),
        .EN(EN_mac_reg),
        .input0(mac_vectA_0_reg),
        .input1(mac_vectB_0_reg),
        .stage1_occupied(mult0_stage1_occupied),
        .stage2_occupied(mult0_stage2_occupied),
        .stage3_occupied(mult0_stage3_occupied),
        .VALID_output(mult0_VALID_output),
        .output_val(mult0_output_val)
    );
    
    multiplier_800M_16b mult_inst_1 (
        .CLK(CLK),
        .RST_N(RST_N),
        .EN(EN_mac_reg),
        .input0(mac_vectA_1_reg),
        .input1(mac_vectB_1_reg),
        .stage1_occupied(mult1_stage1_occupied),
        .stage2_occupied(mult1_stage2_occupied),
        .stage3_occupied(mult1_stage3_occupied),
        .VALID_output(mult1_VALID_output),
        .output_val(mult1_output_val)
    );
    
    multiplier_800M_16b mult_inst_2 (
        .CLK(CLK),
        .RST_N(RST_N),
        .EN(EN_mac_reg),
        .input0(mac_vectA_2_reg),
        .input1(mac_vectB_2_reg),
        .stage1_occupied(mult2_stage1_occupied),
        .stage2_occupied(mult2_stage2_occupied),
        .stage3_occupied(mult2_stage3_occupied),
        .VALID_output(mult2_VALID_output),
        .output_val(mult2_output_val)
    );
    
    multiplier_800M_16b mult_inst_3 (
        .CLK(CLK),
        .RST_N(RST_N),
        .EN(EN_mac_reg),
        .input0(mac_vectA_3_reg),
        .input1(mac_vectB_3_reg),
        .stage1_occupied(mult3_stage1_occupied),
        .stage2_occupied(mult3_stage2_occupied),
        .stage3_occupied(mult3_stage3_occupied),
        .VALID_output(mult3_VALID_output),
        .output_val(mult3_output_val)
    );

endmodule: mkMACBuff
