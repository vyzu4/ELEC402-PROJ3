module mkMACBuff (
    input  CLK, 
    input  RST_N,

    input  EN_mac,
    output RDY_mac,
    input  [15:0] mac_vectA_0,
    input  [15:0] mac_vectB_0,
    input  [15:0] mac_vectA_1,
    input  [15:0] mac_vectB_1,
    input  [15:0] mac_vectA_2,
    input  [15:0] mac_vectB_2,
    input  [15:0] mac_vectA_3,
    input  [15:0] mac_vectB_3,

    output EN_writeMem,
    output [5:0] writeMem_addr,
    output [33:0] writeMem_val,

    input  EN_blockRead,
    output RDY_blockRead,

    output EN_readMem,
    output [5:0] readMem_addr,
    input  [33:0] readMem_val,

    output VALID_memVal,
    output [33:0] memVal_data
);

    localparam N = 33;

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

    logic [6:0]  result_write_count;
    logic [5:0]  result_read_count;

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
            IDLE:    if (EN_mac) next_state = WRITING;
            WRITING: if (result_write_count == 7'd63) next_state = FULL;
            FULL:    if (EN_blockRead) next_state = READING;
            READING: if (result_read_count == 6'd63 && result_EN_readMem_int) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            result_write_count <= 7'd0;
        end else begin
            if (current_state == IDLE || current_state == READING)
                result_write_count <= 7'd0;
            else if (stage3_valid && result_write_count < 7'd64)
                result_write_count <= result_write_count + 7'd1;
        end
    end

    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            result_read_count <= 6'd0;
        end else begin
            if (current_state == FULL)
                result_read_count <= 6'd0;
            else if (current_state == READING && result_EN_readMem_int)
                result_read_count <= result_read_count + 6'd1;
        end
    end

    assign RDY_mac = (current_state == IDLE || current_state == WRITING) &&
                     (result_write_count < 7'd57);
    assign RDY_blockRead = (current_state == FULL);

    assign EN_writeMem   = stage3_valid && (current_state == WRITING);
    assign writeMem_addr = result_write_count[5:0];
    assign writeMem_val  = stage3_result;

    assign result_EN_readMem_int = (current_state == READING);
    assign EN_readMem   = result_EN_readMem_int;
    assign readMem_addr = result_read_count;

    logic VALID_memVal_reg;
    logic VALID_memVal_reg2;
    logic [33:0] memVal_data_reg;

    always_ff @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            VALID_memVal_reg  <= 1'b0;
            VALID_memVal_reg2 <= 1'b0;
            memVal_data_reg   <= 34'h0;
        end else begin
            VALID_memVal_reg  <= result_EN_readMem_int;
            VALID_memVal_reg2 <= VALID_memVal_reg;
            memVal_data_reg   <= readMem_val;
        end
    end

    assign VALID_memVal = VALID_memVal_reg2;
    assign memVal_data  = memVal_data_reg;

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
            EN_mac_reg      <= 1'b0;
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
                EN_mac_reg      <= 1'b1;
            end else begin
                EN_mac_reg <= 1'b0;
            end
        end
    end

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

endmodule
