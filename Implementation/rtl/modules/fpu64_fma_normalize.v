`timescale 1ns / 1ps

module fpu64_fma_normalize (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire special_in,
    input wire [63:0] special_result_in,
    input wire [4:0] special_flags_in,
    input wire result_sign_in,
    input wire signed [13:0] common_exp_in,
    input wire [167:0] sum_in,
    output reg valid_out,
    input wire ready_out,
    output reg is_double_out,
    output reg [2:0] rm_out,
    output reg special_out,
    output reg [63:0] special_result_out,
    output reg [4:0] special_flags_out,
    output reg result_sign_out,
    output reg signed [13:0] result_exp_out,
    output reg [167:0] norm_out
);

    wire stall_stage3;
    wire stall_stage4 = valid_out && !ready_out;
    reg valid_stage3;
    reg [7:0] leading_index;
    reg stage3_is_double;
    reg [2:0] stage3_rm;
    reg stage3_special;
    reg [63:0] stage3_special_result;
    reg [4:0] stage3_special_flags;
    reg stage3_result_sign;
    reg signed [13:0] stage3_common_exp;
    reg [167:0] stage3_sum;
    reg [7:0] stage3_leading_index;

    function [167:0] shift_right_jam;
        input [167:0] value;
        input [13:0] amount;
        reg [167:0] shifted;
        reg [167:0] discarded;
        begin
            if (amount == 14'd0) begin
                shift_right_jam = value;
            end else if (amount >= 14'd168) begin
                shift_right_jam = 168'd0;
                shift_right_jam[0] = |value;
            end else begin
                shifted = value >> amount;
                discarded = value << (14'd168 - amount);
                shifted[0] = shifted[0] | (|discarded);
                shift_right_jam = shifted;
            end
        end
    endfunction

    assign stall_stage3 = valid_stage3 && stall_stage4;
    assign ready_in = !stall_stage3;

    wire [20:0] group_nonzero;
    genvar g;
    generate
        for (g = 0; g < 21; g = g + 1) begin : gen_group_nonzero
            assign group_nonzero[g] = |sum_in[g*8 +: 8];
        end
    endgenerate

    reg [4:0] coarse_index;
    always @(*) begin
        if      (group_nonzero[20]) coarse_index = 5'd20;
        else if (group_nonzero[19]) coarse_index = 5'd19;
        else if (group_nonzero[18]) coarse_index = 5'd18;
        else if (group_nonzero[17]) coarse_index = 5'd17;
        else if (group_nonzero[16]) coarse_index = 5'd16;
        else if (group_nonzero[15]) coarse_index = 5'd15;
        else if (group_nonzero[14]) coarse_index = 5'd14;
        else if (group_nonzero[13]) coarse_index = 5'd13;
        else if (group_nonzero[12]) coarse_index = 5'd12;
        else if (group_nonzero[11]) coarse_index = 5'd11;
        else if (group_nonzero[10]) coarse_index = 5'd10;
        else if (group_nonzero[ 9]) coarse_index = 5'd9;
        else if (group_nonzero[ 8]) coarse_index = 5'd8;
        else if (group_nonzero[ 7]) coarse_index = 5'd7;
        else if (group_nonzero[ 6]) coarse_index = 5'd6;
        else if (group_nonzero[ 5]) coarse_index = 5'd5;
        else if (group_nonzero[ 4]) coarse_index = 5'd4;
        else if (group_nonzero[ 3]) coarse_index = 5'd3;
        else if (group_nonzero[ 2]) coarse_index = 5'd2;
        else if (group_nonzero[ 1]) coarse_index = 5'd1;
        else                        coarse_index = 5'd0;
    end

    wire [7:0] fine_group = sum_in[coarse_index*8 +: 8];
    reg [2:0] fine_index;
    always @(*) begin
        if      (fine_group[7]) fine_index = 3'd7;
        else if (fine_group[6]) fine_index = 3'd6;
        else if (fine_group[5]) fine_index = 3'd5;
        else if (fine_group[4]) fine_index = 3'd4;
        else if (fine_group[3]) fine_index = 3'd3;
        else if (fine_group[2]) fine_index = 3'd2;
        else if (fine_group[1]) fine_index = 3'd1;
        else                    fine_index = 3'd0;
    end

    always @(*) begin
        if (sum_in == 168'd0) begin
            leading_index = 8'd0;
        end else begin
            leading_index = {coarse_index, fine_index};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage3 <= 1'b0;
            stage3_is_double <= 1'b0;
            stage3_rm <= 3'd0;
            stage3_special <= 1'b0;
            stage3_special_result <= 64'd0;
            stage3_special_flags <= 5'd0;
            stage3_result_sign <= 1'b0;
            stage3_common_exp <= 14'sd0;
            stage3_sum <= 168'd0;
            stage3_leading_index <= 8'd0;
        end else if (!stall_stage3) begin
            valid_stage3 <= valid_in;
            if (valid_in) begin
                stage3_is_double <= is_double_in;
                stage3_rm <= rm_in;
                stage3_special <= special_in;
                stage3_special_result <= special_result_in;
                stage3_special_flags <= special_flags_in;
                stage3_result_sign <= result_sign_in;
                stage3_common_exp <= common_exp_in;
                stage3_sum <= sum_in;
                stage3_leading_index <= leading_index;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            is_double_out <= 1'b0;
            rm_out <= 3'd0;
            special_out <= 1'b0;
            special_result_out <= 64'd0;
            special_flags_out <= 5'd0;
            result_sign_out <= 1'b0;
            result_exp_out <= 14'sd0;
            norm_out <= 168'd0;
        end else if (!stall_stage4) begin
            valid_out <= valid_stage3;
            if (valid_stage3) begin
                is_double_out <= stage3_is_double;
                rm_out <= stage3_rm;
                special_out <= stage3_special;
                special_result_out <= stage3_special_result;
                special_flags_out <= stage3_special_flags;
                result_sign_out <= stage3_result_sign;
                if (stage3_sum == 168'd0) begin
                    result_exp_out <= 14'sd0;
                    norm_out <= 168'd0;
                end else if (stage3_leading_index > 8'd166) begin
                    result_exp_out <= stage3_common_exp + 14'sd1;
                    norm_out <= shift_right_jam(stage3_sum, 14'd1);
                end else begin
                    result_exp_out <= stage3_common_exp - (14'sd166 - $signed({6'd0, stage3_leading_index}));
                    norm_out <= stage3_sum << (8'd166 - stage3_leading_index);
                end
            end
        end
    end

endmodule
