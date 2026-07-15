`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_fma_accumulate (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire special_in,
    input wire [63:0] special_result_in,
    input wire [4:0] special_flags_in,
    input wire product_sign_in,
    input wire addend_sign_in,
    input wire product_zero_in,
    input wire addend_zero_in,
    input wire signed [13:0] product_exp_base_in,
    input wire signed [13:0] addend_exp_in,
    input wire [52:0] addend_sig_in,
    input wire [47:0] sp_product_in,
    input wire [105:0] dp_product_in,
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

    wire stall_stage1;
    wire stall_stage2;
    wire stall_stage3;
    wire stall_stage4 = valid_out && !ready_out;
    reg valid_stage1;
    reg valid_stage2;
    reg valid_stage3;
    reg [167:0] product_base;
    reg [167:0] addend_base;
    reg [167:0] product_aligned;
    reg [167:0] addend_aligned;
    reg signed [13:0] product_exp_norm;
    reg signed [13:0] common_exp;
    reg [13:0] exp_difference;
    reg stage1_is_double;
    reg [2:0] stage1_rm;
    reg stage1_special;
    reg [63:0] stage1_special_result;
    reg [4:0] stage1_special_flags;
    reg stage1_product_sign;
    reg stage1_addend_sign;
    reg signed [13:0] stage1_common_exp;
    reg [167:0] stage1_product;
    reg [167:0] stage1_addend;
    reg stage2_is_double;
    reg [2:0] stage2_rm;
    reg stage2_special;
    reg [63:0] stage2_special_result;
    reg [4:0] stage2_special_flags;
    reg stage2_result_sign;
    reg signed [13:0] stage2_common_exp;
    reg [167:0] stage2_sum;
    reg [7:0] leading_index;
    reg leading_found;
    reg stage3_is_double;
    reg [2:0] stage3_rm;
    reg stage3_special;
    reg [63:0] stage3_special_result;
    reg [4:0] stage3_special_flags;
    reg stage3_result_sign;
    reg signed [13:0] stage3_common_exp;
    reg [167:0] stage3_sum;
    reg [7:0] stage3_leading_index;
    integer leading_i;

    function [167:0] shift_right_jam;
        input [167:0] value;
        input [13:0] amount;
        reg [167:0] shifted;
        reg [167:0] mask;
        begin
            if (amount == 14'd0) begin
                shift_right_jam = value;
            end else if (amount >= 14'd168) begin
                shift_right_jam = 168'd0;
                shift_right_jam[0] = |value;
            end else begin
                shifted = value >> amount;
                mask = (168'd1 << amount) - 168'd1;
                shifted[0] = shifted[0] | (|(value & mask));
                shift_right_jam = shifted;
            end
        end
    endfunction

    assign stall_stage3 = valid_stage3 && stall_stage4;
    assign stall_stage2 = valid_stage2 && stall_stage3;
    assign stall_stage1 = valid_stage1 && stall_stage2;
    assign ready_in = !stall_stage1;

    always @(*) begin
        product_base = 168'd0;
        addend_base = 168'd0;
        product_aligned = 168'd0;
        addend_aligned = 168'd0;
        product_exp_norm = product_exp_base_in;
        common_exp = 14'sd0;
        exp_difference = 14'd0;
        if (is_double_in) begin
            if (dp_product_in[105]) begin
                product_base[166:61] = dp_product_in;
                product_exp_norm = product_exp_base_in + 14'sd1;
            end else begin
                product_base[166:61] = dp_product_in << 1;
            end
            addend_base[166:114] = addend_sig_in;
        end else begin
            if (sp_product_in[47]) begin
                product_base[166:119] = sp_product_in;
                product_exp_norm = product_exp_base_in + 14'sd1;
            end else begin
                product_base[166:119] = sp_product_in << 1;
            end
            addend_base[166:143] = addend_sig_in[23:0];
        end
        if (product_zero_in && addend_zero_in) begin
            common_exp = 14'sd0;
        end else if (product_zero_in) begin
            addend_aligned = addend_base;
            common_exp = addend_exp_in;
        end else if (addend_zero_in) begin
            product_aligned = product_base;
            common_exp = product_exp_norm;
        end else if ($signed(product_exp_norm) >= $signed(addend_exp_in)) begin
            exp_difference = product_exp_norm - addend_exp_in;
            product_aligned = product_base;
            addend_aligned = shift_right_jam(addend_base, exp_difference);
            common_exp = product_exp_norm;
        end else begin
            exp_difference = addend_exp_in - product_exp_norm;
            product_aligned = shift_right_jam(product_base, exp_difference);
            addend_aligned = addend_base;
            common_exp = addend_exp_in;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 1'b0;
            stage1_is_double <= 1'b0;
            stage1_rm <= 3'd0;
            stage1_special <= 1'b0;
            stage1_special_result <= 64'd0;
            stage1_special_flags <= 5'd0;
            stage1_product_sign <= 1'b0;
            stage1_addend_sign <= 1'b0;
            stage1_common_exp <= 14'sd0;
            stage1_product <= 168'd0;
            stage1_addend <= 168'd0;
        end else if (!stall_stage1) begin
            valid_stage1 <= valid_in;
            if (valid_in) begin
                stage1_is_double <= is_double_in;
                stage1_rm <= rm_in;
                stage1_special <= special_in;
                stage1_special_result <= special_result_in;
                stage1_special_flags <= special_flags_in;
                stage1_product_sign <= product_sign_in;
                stage1_addend_sign <= addend_sign_in;
                stage1_common_exp <= common_exp;
                stage1_product <= product_aligned;
                stage1_addend <= addend_aligned;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage2 <= 1'b0;
            stage2_is_double <= 1'b0;
            stage2_rm <= 3'd0;
            stage2_special <= 1'b0;
            stage2_special_result <= 64'd0;
            stage2_special_flags <= 5'd0;
            stage2_result_sign <= 1'b0;
            stage2_common_exp <= 14'sd0;
            stage2_sum <= 168'd0;
        end else if (!stall_stage2) begin
            valid_stage2 <= valid_stage1;
            if (valid_stage1) begin
                stage2_is_double <= stage1_is_double;
                stage2_rm <= stage1_rm;
                stage2_special <= stage1_special;
                stage2_special_result <= stage1_special_result;
                stage2_special_flags <= stage1_special_flags;
                stage2_common_exp <= stage1_common_exp;
                if (stage1_product_sign == stage1_addend_sign) begin
                    stage2_sum <= stage1_product + stage1_addend;
                    stage2_result_sign <= stage1_product_sign;
                end else if (stage1_product > stage1_addend) begin
                    stage2_sum <= stage1_product - stage1_addend;
                    stage2_result_sign <= stage1_product_sign;
                end else if (stage1_addend > stage1_product) begin
                    stage2_sum <= stage1_addend - stage1_product;
                    stage2_result_sign <= stage1_addend_sign;
                end else begin
                    stage2_sum <= 168'd0;
                    stage2_result_sign <= (stage1_rm == `RM_RDN);
                end
            end
        end
    end

    always @(*) begin
        leading_index = 8'd0;
        leading_found = 1'b0;
        for (leading_i = 0; leading_i < 168; leading_i = leading_i + 1) begin
            if (!leading_found && stage2_sum[167 - leading_i]) begin
                leading_index = 8'd167 - leading_i;
                leading_found = 1'b1;
            end
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
            valid_stage3 <= valid_stage2;
            if (valid_stage2) begin
                stage3_is_double <= stage2_is_double;
                stage3_rm <= stage2_rm;
                stage3_special <= stage2_special;
                stage3_special_result <= stage2_special_result;
                stage3_special_flags <= stage2_special_flags;
                stage3_result_sign <= stage2_result_sign;
                stage3_common_exp <= stage2_common_exp;
                stage3_sum <= stage2_sum;
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
