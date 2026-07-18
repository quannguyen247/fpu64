`timescale 1ns / 1ps

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
    output wire valid_out,
    input wire ready_out,
    output wire is_double_out,
    output wire [2:0] rm_out,
    output wire special_out,
    output wire [63:0] special_result_out,
    output wire [4:0] special_flags_out,
    output wire result_sign_out,
    output wire signed [13:0] result_exp_out,
    output wire [167:0] norm_out
);

    wire align_add_valid;
    wire align_add_ready;
    wire align_add_is_double;
    wire [2:0] align_add_rm;
    wire align_add_special;
    wire [63:0] align_add_special_result;
    wire [4:0] align_add_special_flags;
    wire align_add_result_sign;
    wire signed [13:0] align_add_common_exp;
    wire [167:0] align_add_sum;

    fpu64_fma_align_add u_align_add (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .is_double_in(is_double_in),
        .rm_in(rm_in),
        .special_in(special_in),
        .special_result_in(special_result_in),
        .special_flags_in(special_flags_in),
        .product_sign_in(product_sign_in),
        .addend_sign_in(addend_sign_in),
        .product_zero_in(product_zero_in),
        .addend_zero_in(addend_zero_in),
        .product_exp_base_in(product_exp_base_in),
        .addend_exp_in(addend_exp_in),
        .addend_sig_in(addend_sig_in),
        .sp_product_in(sp_product_in),
        .dp_product_in(dp_product_in),
        .valid_out(align_add_valid),
        .ready_out(align_add_ready),
        .is_double_out(align_add_is_double),
        .rm_out(align_add_rm),
        .special_out(align_add_special),
        .special_result_out(align_add_special_result),
        .special_flags_out(align_add_special_flags),
        .result_sign_out(align_add_result_sign),
        .common_exp_out(align_add_common_exp),
        .sum_out(align_add_sum)
    );

    fpu64_fma_normalize u_normalize (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(align_add_valid),
        .ready_in(align_add_ready),
        .is_double_in(align_add_is_double),
        .rm_in(align_add_rm),
        .special_in(align_add_special),
        .special_result_in(align_add_special_result),
        .special_flags_in(align_add_special_flags),
        .result_sign_in(align_add_result_sign),
        .common_exp_in(align_add_common_exp),
        .sum_in(align_add_sum),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .is_double_out(is_double_out),
        .rm_out(rm_out),
        .special_out(special_out),
        .special_result_out(special_result_out),
        .special_flags_out(special_flags_out),
        .result_sign_out(result_sign_out),
        .result_exp_out(result_exp_out),
        .norm_out(norm_out)
    );

endmodule
