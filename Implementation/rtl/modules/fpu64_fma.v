`timescale 1ns / 1ps

module fpu64_fma (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [63:0] rs3,
    input wire [3:0] op,
    input wire is_double,
    input wire [2:0] rm,
    output wire valid_out,
    input wire ready_out,
    output wire [63:0] result,
    output wire [4:0] fflags
);

    wire prepare_valid;
    wire prepare_ready;
    wire prepare_is_double;
    wire [2:0] prepare_rm;
    wire prepare_special;
    wire [63:0] prepare_special_result;
    wire [4:0] prepare_special_flags;
    wire prepare_product_sign;
    wire prepare_addend_sign;
    wire prepare_product_zero;
    wire prepare_addend_zero;
    wire signed [13:0] prepare_exp1;
    wire signed [13:0] prepare_exp2;
    wire signed [13:0] prepare_exp3;
    wire [52:0] prepare_sig1;
    wire [52:0] prepare_sig2;
    wire [52:0] prepare_sig3;
    wire product_valid;
    wire product_ready;
    wire product_is_double;
    wire [2:0] product_rm;
    wire product_special;
    wire [63:0] product_special_result;
    wire [4:0] product_special_flags;
    wire product_sign;
    wire addend_sign;
    wire product_zero;
    wire addend_zero;
    wire signed [13:0] product_exp_base;
    wire signed [13:0] addend_exp;
    wire [52:0] addend_sig;
    wire [47:0] sp_product;
    wire [105:0] dp_product;
    wire accumulate_valid;
    wire accumulate_ready;
    wire accumulate_is_double;
    wire [2:0] accumulate_rm;
    wire accumulate_special;
    wire [63:0] accumulate_special_result;
    wire [4:0] accumulate_special_flags;
    wire accumulate_result_sign;
    wire signed [13:0] accumulate_result_exp;
    wire [167:0] accumulate_norm;

    fpu64_fma_prepare u_prepare (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .op(op),
        .is_double(is_double),
        .rm(rm),
        .valid_out(prepare_valid),
        .ready_out(prepare_ready),
        .is_double_out(prepare_is_double),
        .rm_out(prepare_rm),
        .special_out(prepare_special),
        .special_result_out(prepare_special_result),
        .special_flags_out(prepare_special_flags),
        .product_sign_out(prepare_product_sign),
        .addend_sign_out(prepare_addend_sign),
        .product_zero_out(prepare_product_zero),
        .addend_zero_out(prepare_addend_zero),
        .exp1_out(prepare_exp1),
        .exp2_out(prepare_exp2),
        .exp3_out(prepare_exp3),
        .sig1_out(prepare_sig1),
        .sig2_out(prepare_sig2),
        .sig3_out(prepare_sig3)
    );

    fpu64_fma_product u_product (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(prepare_valid),
        .ready_in(prepare_ready),
        .is_double_in(prepare_is_double),
        .rm_in(prepare_rm),
        .special_in(prepare_special),
        .special_result_in(prepare_special_result),
        .special_flags_in(prepare_special_flags),
        .product_sign_in(prepare_product_sign),
        .addend_sign_in(prepare_addend_sign),
        .product_zero_in(prepare_product_zero),
        .addend_zero_in(prepare_addend_zero),
        .exp1_in(prepare_exp1),
        .exp2_in(prepare_exp2),
        .exp3_in(prepare_exp3),
        .sig1_in(prepare_sig1),
        .sig2_in(prepare_sig2),
        .sig3_in(prepare_sig3),
        .valid_out(product_valid),
        .ready_out(product_ready),
        .is_double_out(product_is_double),
        .rm_out(product_rm),
        .special_out(product_special),
        .special_result_out(product_special_result),
        .special_flags_out(product_special_flags),
        .product_sign_out(product_sign),
        .addend_sign_out(addend_sign),
        .product_zero_out(product_zero),
        .addend_zero_out(addend_zero),
        .product_exp_base_out(product_exp_base),
        .addend_exp_out(addend_exp),
        .addend_sig_out(addend_sig),
        .sp_product_out(sp_product),
        .dp_product_out(dp_product)
    );

    fpu64_fma_accumulate u_accumulate (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(product_valid),
        .ready_in(product_ready),
        .is_double_in(product_is_double),
        .rm_in(product_rm),
        .special_in(product_special),
        .special_result_in(product_special_result),
        .special_flags_in(product_special_flags),
        .product_sign_in(product_sign),
        .addend_sign_in(addend_sign),
        .product_zero_in(product_zero),
        .addend_zero_in(addend_zero),
        .product_exp_base_in(product_exp_base),
        .addend_exp_in(addend_exp),
        .addend_sig_in(addend_sig),
        .sp_product_in(sp_product),
        .dp_product_in(dp_product),
        .valid_out(accumulate_valid),
        .ready_out(accumulate_ready),
        .is_double_out(accumulate_is_double),
        .rm_out(accumulate_rm),
        .special_out(accumulate_special),
        .special_result_out(accumulate_special_result),
        .special_flags_out(accumulate_special_flags),
        .result_sign_out(accumulate_result_sign),
        .result_exp_out(accumulate_result_exp),
        .norm_out(accumulate_norm)
    );

    fpu64_fma_round u_round (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(accumulate_valid),
        .ready_in(accumulate_ready),
        .is_double_in(accumulate_is_double),
        .rm_in(accumulate_rm),
        .special_in(accumulate_special),
        .special_result_in(accumulate_special_result),
        .special_flags_in(accumulate_special_flags),
        .result_sign_in(accumulate_result_sign),
        .result_exp_in(accumulate_result_exp),
        .norm_in(accumulate_norm),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .result(result),
        .fflags(fflags)
    );

endmodule
