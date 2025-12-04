//
module multiplier_800M_16b(
    CLK, RST_N,
    EN, input0, input1, 
    stage1_occupied,
    stage2_occupied,
    stage3_occupied,
    VALID_output, output_val
    );
input CLK, RST_N;

input EN;
input [15:0] input0, input1;
output stage1_occupied, stage2_occupied, stage3_occupied;
output VALID_output;
output [31:0] output_val;

localparam ZERO_8b = 8'd0;

// 1st stage
reg stage1_occupied_reg;
wire [7:0] partials_4bmult [15:0];
reg [7:0] stage1_regs [15:0];

assign partials_4bmult[0] = input0[3:0] * input1[3:0];
assign partials_4bmult[1] = input0[3:0] * input1[7:4];
assign partials_4bmult[2] = input0[3:0] * input1[11:8];
assign partials_4bmult[3] = input0[3:0] * input1[15:12];

assign partials_4bmult[4] = input0[7:4] * input1[3:0];
assign partials_4bmult[5] = input0[7:4] * input1[7:4];
assign partials_4bmult[6] = input0[7:4] * input1[11:8];
assign partials_4bmult[7] = input0[7:4] * input1[15:12];

assign partials_4bmult[8] = input0[11:8] * input1[3:0];
assign partials_4bmult[9] = input0[11:8] * input1[7:4];
assign partials_4bmult[10] = input0[11:8] * input1[11:8];
assign partials_4bmult[11] = input0[11:8] * input1[15:12];

assign partials_4bmult[12] = input0[15:12] * input1[3:0];
assign partials_4bmult[13] = input0[15:12] * input1[7:4];
assign partials_4bmult[14] = input0[15:12] * input1[11:8];
assign partials_4bmult[15] = input0[15:12] * input1[15:12];

always @(posedge CLK) begin
    if (~RST_N) begin
        stage1_occupied_reg <= 1'b0;
        stage1_regs[0] <= ZERO_8b;
        stage1_regs[1] <= ZERO_8b;
        stage1_regs[2] <= ZERO_8b;
        stage1_regs[3] <= ZERO_8b;
        stage1_regs[4] <= ZERO_8b;
        stage1_regs[5] <= ZERO_8b;
        stage1_regs[6] <= ZERO_8b;
        stage1_regs[7] <= ZERO_8b;
        stage1_regs[8] <= ZERO_8b;
        stage1_regs[9] <= ZERO_8b;
        stage1_regs[10] <= ZERO_8b;
        stage1_regs[11] <= ZERO_8b;
        stage1_regs[12] <= ZERO_8b;
        stage1_regs[13] <= ZERO_8b;
        stage1_regs[14] <= ZERO_8b;
        stage1_regs[15] <= ZERO_8b;
    end
    else begin
        stage1_occupied_reg <= EN;
        if (EN) begin
            stage1_regs[0] <= partials_4bmult[0];
            stage1_regs[1] <= partials_4bmult[1];
            stage1_regs[2] <= partials_4bmult[2];
            stage1_regs[3] <= partials_4bmult[3];
            stage1_regs[4] <= partials_4bmult[4];
            stage1_regs[5] <= partials_4bmult[5];
            stage1_regs[6] <= partials_4bmult[6];
            stage1_regs[7] <= partials_4bmult[7];
            stage1_regs[8] <= partials_4bmult[8];
            stage1_regs[9] <= partials_4bmult[9];
            stage1_regs[10] <= partials_4bmult[10];
            stage1_regs[11] <= partials_4bmult[11];
            stage1_regs[12] <= partials_4bmult[12];
            stage1_regs[13] <= partials_4bmult[13];
            stage1_regs[14] <= partials_4bmult[14];
            stage1_regs[15] <= partials_4bmult[15];
        end
    end
end

// 2nd stage
reg stage2_occupied_reg;
wire [31:0] partials_add1 [3:0];
reg [31:0] stage2_regs [3:0];

assign partials_add1[0] = {24'd0, stage1_regs[0]} + {20'd0, stage1_regs[1], 4'd0} + {16'd0, stage1_regs[2], 8'd0} + {12'd0, stage1_regs[3], 12'd0};

assign partials_add1[1] = {20'd0, stage1_regs[4], 4'd0} + {16'd0, stage1_regs[5], 8'd0} + {12'd0, stage1_regs[6], 12'd0} + {8'd0, stage1_regs[7], 16'd0};

assign partials_add1[2] = {16'd0, stage1_regs[8], 8'd0} + {12'd0, stage1_regs[9], 12'd0} + {8'd0, stage1_regs[10], 16'd0} + {4'd0, stage1_regs[11], 20'd0};

assign partials_add1[3] = {12'd0, stage1_regs[12], 12'd0} + {8'd0, stage1_regs[13], 16'd0} + {4'd0, stage1_regs[14], 20'd0} + {stage1_regs[15], 24'd0};

always @(posedge CLK) begin
    if (~RST_N) begin
        stage2_occupied_reg <= 1'b0;
        stage2_regs[3] <= 32'd0;
        stage2_regs[2] <= 32'd0;
        stage2_regs[1] <= 32'd0;
        stage2_regs[0] <= 32'd0;
    end
    else begin
        stage2_occupied_reg <= stage1_occupied;
        if (stage1_occupied) begin
            stage2_regs[3] <= partials_add1[3];
            stage2_regs[2] <= partials_add1[2];
            stage2_regs[1] <= partials_add1[1];
            stage2_regs[0] <= partials_add1[0];
        end
    end
end

// 3rd stage
reg stage3_occupied_reg;
wire [31:0] partials_add2 [1:0];
reg [31:0] stage3_regs[1:0];

assign partials_add2[0] = stage2_regs[0] + stage2_regs[1];
assign partials_add2[1] = stage2_regs[2] + stage2_regs[3];

always @(posedge CLK) begin
    if (~RST_N) begin
        stage3_occupied_reg <= 1'b0;
        stage3_regs[0] <= 32'd0;
        stage3_regs[1] <= 32'd0;
    end
    else begin
        stage3_occupied_reg <= stage2_occupied;
        if (stage2_occupied) begin
            stage3_regs[0] <= partials_add2[0];
            stage3_regs[1] <= partials_add2[1];
        end
    end
end

// 4th stage
reg stage4_occupied_reg;
wire [31:0] final_sum;
reg [31:0] output_val_reg;

assign final_sum = stage3_regs[0] + stage3_regs[1];

always @(posedge CLK) begin
    if (~RST_N) begin
        stage4_occupied_reg <= 1'b0;
        output_val_reg <= 32'd0;
    end
    else begin
        stage4_occupied_reg <= stage3_occupied;
        if (stage3_occupied) begin
            output_val_reg <= final_sum;
        end
    end
end

// outputs
assign stage1_occupied = stage1_occupied_reg;
assign stage2_occupied = stage2_occupied_reg;
assign stage3_occupied = stage3_occupied_reg;
assign VALID_output = stage4_occupied_reg;
assign output_val = output_val_reg;

endmodule: multiplier_800M_16b
