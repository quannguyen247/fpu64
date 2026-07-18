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

    wire stall_align;
    wire stall_stage1;
    wire stall_add;
    wire stall_stage2;
    wire stall_stage3;
    wire stall_stage4 = valid_out && !ready_out;
    reg valid_align;
    reg valid_stage1;
    reg valid_add;
    reg valid_stage2;
    reg valid_stage3;
    reg [167:0] product_base;
    reg [167:0] addend_base;
    reg [167:0] product_aligned;
    reg [167:0] addend_aligned;
    reg signed [13:0] product_exp_norm;
    reg signed [13:0] common_exp;
    reg [13:0] exp_difference;
    reg shift_addend;
    reg align_is_double;
    reg [2:0] align_rm;
    reg align_special;
    reg [63:0] align_special_result;
    reg [4:0] align_special_flags;
    reg align_product_sign;
    reg align_addend_sign;
    reg align_product_zero;
    reg align_addend_zero;
    reg align_shift_addend;
    reg signed [13:0] align_common_exp;
    reg [13:0] align_exp_difference;
    reg [167:0] align_product_base;
    reg [167:0] align_addend_base;
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
    reg add_is_double;
    reg [2:0] add_rm;
    reg add_special;
    reg [63:0] add_special_result;
    reg [4:0] add_special_flags;
    reg add_result_sign;
    reg signed [13:0] add_common_exp;
    reg [83:0] add_low_result;
    reg [83:0] add_high_a;
    reg [83:0] add_high_b;
    reg add_subtract;
    reg add_carry_or_borrow;
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

    wire stage1_upper_equal = (stage1_product[167:84] == stage1_addend[167:84]);
    wire stage1_lower_equal = (stage1_product[83:0] == stage1_addend[83:0]);
    wire stage1_product_greater = (stage1_product[167:84] > stage1_addend[167:84]) ||
                                  (stage1_upper_equal && (stage1_product[83:0] > stage1_addend[83:0]));
    wire [84:0] stage1_add_low = {1'b0, stage1_product[83:0]} + {1'b0, stage1_addend[83:0]};
    wire [84:0] stage1_product_sub_low = {1'b0, stage1_product[83:0]} - {1'b0, stage1_addend[83:0]};
    wire [84:0] stage1_addend_sub_low = {1'b0, stage1_addend[83:0]} - {1'b0, stage1_product[83:0]};

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
    assign stall_stage2 = valid_stage2 && stall_stage3;
    assign stall_add = valid_add && stall_stage2;
    assign stall_stage1 = valid_stage1 && stall_add;
    assign stall_align = valid_align && stall_stage1;
    assign ready_in = !stall_align;

    always @(*) begin
        product_base = 168'd0;
        addend_base = 168'd0;
        product_exp_norm = product_exp_base_in;
        common_exp = 14'sd0;
        exp_difference = 14'd0;
        shift_addend = 1'b0;
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
            common_exp = addend_exp_in;
        end else if (addend_zero_in) begin
            common_exp = product_exp_norm;
        end else if ($signed(product_exp_norm) >= $signed(addend_exp_in)) begin
            exp_difference = product_exp_norm - addend_exp_in;
            shift_addend = 1'b1;
            common_exp = product_exp_norm;
        end else begin
            exp_difference = addend_exp_in - product_exp_norm;
            common_exp = addend_exp_in;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_align <= 1'b0;
            align_is_double <= 1'b0;
            align_rm <= 3'd0;
            align_special <= 1'b0;
            align_special_result <= 64'd0;
            align_special_flags <= 5'd0;
            align_product_sign <= 1'b0;
            align_addend_sign <= 1'b0;
            align_product_zero <= 1'b0;
            align_addend_zero <= 1'b0;
            align_shift_addend <= 1'b0;
            align_common_exp <= 14'sd0;
            align_exp_difference <= 14'd0;
            align_product_base <= 168'd0;
            align_addend_base <= 168'd0;
        end else if (!stall_align) begin
            valid_align <= valid_in;
            if (valid_in) begin
                align_is_double <= is_double_in;
                align_rm <= rm_in;
                align_special <= special_in;
                align_special_result <= special_result_in;
                align_special_flags <= special_flags_in;
                align_product_sign <= product_sign_in;
                align_addend_sign <= addend_sign_in;
                align_product_zero <= product_zero_in;
                align_addend_zero <= addend_zero_in;
                align_shift_addend <= shift_addend;
                align_common_exp <= common_exp;
                align_exp_difference <= exp_difference;
                align_product_base <= product_base;
                align_addend_base <= addend_base;
            end
        end
    end

    always @(*) begin
        product_aligned = 168'd0;
        addend_aligned = 168'd0;
        if (align_product_zero && align_addend_zero) begin
            product_aligned = 168'd0;
            addend_aligned = 168'd0;
        end else if (align_product_zero) begin
            addend_aligned = align_addend_base;
        end else if (align_addend_zero) begin
            product_aligned = align_product_base;
        end else if (align_shift_addend) begin
            product_aligned = align_product_base;
            addend_aligned = shift_right_jam(align_addend_base, align_exp_difference);
        end else begin
            product_aligned = shift_right_jam(align_product_base, align_exp_difference);
            addend_aligned = align_addend_base;
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
            valid_stage1 <= valid_align;
            if (valid_align) begin
                stage1_is_double <= align_is_double;
                stage1_rm <= align_rm;
                stage1_special <= align_special;
                stage1_special_result <= align_special_result;
                stage1_special_flags <= align_special_flags;
                stage1_product_sign <= align_product_sign;
                stage1_addend_sign <= align_addend_sign;
                stage1_common_exp <= align_common_exp;
                stage1_product <= product_aligned;
                stage1_addend <= addend_aligned;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_add <= 1'b0;
            add_is_double <= 1'b0;
            add_rm <= 3'd0;
            add_special <= 1'b0;
            add_special_result <= 64'd0;
            add_special_flags <= 5'd0;
            add_result_sign <= 1'b0;
            add_common_exp <= 14'sd0;
            add_low_result <= 84'd0;
            add_high_a <= 84'd0;
            add_high_b <= 84'd0;
            add_subtract <= 1'b0;
            add_carry_or_borrow <= 1'b0;
        end else if (!stall_add) begin
            valid_add <= valid_stage1;
            if (valid_stage1) begin
                add_is_double <= stage1_is_double;
                add_rm <= stage1_rm;
                add_special <= stage1_special;
                add_special_result <= stage1_special_result;
                add_special_flags <= stage1_special_flags;
                add_common_exp <= stage1_common_exp;
                if (stage1_product_sign == stage1_addend_sign) begin
                    add_low_result <= stage1_add_low[83:0];
                    add_high_a <= stage1_product[167:84];
                    add_high_b <= stage1_addend[167:84];
                    add_subtract <= 1'b0;
                    add_carry_or_borrow <= stage1_add_low[84];
                    add_result_sign <= stage1_product_sign;
                end else if (stage1_product_greater) begin
                    add_low_result <= stage1_product_sub_low[83:0];
                    add_high_a <= stage1_product[167:84];
                    add_high_b <= stage1_addend[167:84];
                    add_subtract <= 1'b1;
                    add_carry_or_borrow <= stage1_product_sub_low[84];
                    add_result_sign <= stage1_product_sign;
                end else if (!stage1_upper_equal || !stage1_lower_equal) begin
                    add_low_result <= stage1_addend_sub_low[83:0];
                    add_high_a <= stage1_addend[167:84];
                    add_high_b <= stage1_product[167:84];
                    add_subtract <= 1'b1;
                    add_carry_or_borrow <= stage1_addend_sub_low[84];
                    add_result_sign <= stage1_addend_sign;
                end else begin
                    add_low_result <= 84'd0;
                    add_high_a <= 84'd0;
                    add_high_b <= 84'd0;
                    add_subtract <= 1'b0;
                    add_carry_or_borrow <= 1'b0;
                    add_result_sign <= (stage1_rm == `RM_RDN);
                end
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
            valid_stage2 <= valid_add;
            if (valid_add) begin
                stage2_is_double <= add_is_double;
                stage2_rm <= add_rm;
                stage2_special <= add_special;
                stage2_special_result <= add_special_result;
                stage2_special_flags <= add_special_flags;
                stage2_common_exp <= add_common_exp;
                stage2_result_sign <= add_result_sign;
                if (add_subtract) begin
                    stage2_sum <= {add_high_a - add_high_b - add_carry_or_borrow, add_low_result};
                end else begin
                    stage2_sum <= {add_high_a + add_high_b + add_carry_or_borrow, add_low_result};
                end
            end
        end
    end

    wire [20:0] group_nonzero;
    genvar g;
    generate
        for (g = 0; g < 21; g = g + 1) begin : gen_group_nonzero
            assign group_nonzero[g] = |stage2_sum[g*8 +: 8];
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

    wire [7:0] fine_group = stage2_sum[coarse_index*8 +: 8];
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
        if (stage2_sum == 168'd0) begin
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
