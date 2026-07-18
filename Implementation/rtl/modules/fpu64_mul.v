`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_mul (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

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
    wire prepare_sp_special;
    wire [63:0] prepare_sp_special_result;
    wire [4:0] prepare_sp_special_flags;
    wire prepare_sp_result_sign;
    wire [8:0] prepare_sp_exp;
    wire [23:0] prepare_sp_m1;
    wire [23:0] prepare_sp_m2;
    wire prepare_dp_special;
    wire [63:0] prepare_dp_special_result;
    wire [4:0] prepare_dp_special_flags;
    wire prepare_dp_result_sign;
    wire [11:0] prepare_dp_exp;
    wire [52:0] prepare_dp_m1;
    wire [52:0] prepare_dp_m2;
    wire product_valid;
    wire product_ready;
    wire product_is_double;
    wire [2:0] product_rm;
    wire product_sp_special;
    wire [63:0] product_sp_special_result;
    wire [4:0] product_sp_special_flags;
    wire product_sp_result_sign;
    wire [8:0] product_sp_exp;
    wire [47:0] product_sp_norm;
    wire product_dp_special;
    wire [63:0] product_dp_special_result;
    wire [4:0] product_dp_special_flags;
    wire product_dp_result_sign;
    wire [11:0] product_dp_exp;
    wire [105:0] product_dp_norm;

    fpu64_mul_prepare u_prepare (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .rm(rm),
        .valid_out(prepare_valid),
        .ready_out(prepare_ready),
        .is_double_out(prepare_is_double),
        .rm_out(prepare_rm),
        .sp_special_out(prepare_sp_special),
        .sp_special_result_out(prepare_sp_special_result),
        .sp_special_flags_out(prepare_sp_special_flags),
        .sp_result_sign_out(prepare_sp_result_sign),
        .sp_exp_out(prepare_sp_exp),
        .sp_m1_out(prepare_sp_m1),
        .sp_m2_out(prepare_sp_m2),
        .dp_special_out(prepare_dp_special),
        .dp_special_result_out(prepare_dp_special_result),
        .dp_special_flags_out(prepare_dp_special_flags),
        .dp_result_sign_out(prepare_dp_result_sign),
        .dp_exp_out(prepare_dp_exp),
        .dp_m1_out(prepare_dp_m1),
        .dp_m2_out(prepare_dp_m2)
    );

    fpu64_mul_product u_product (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(prepare_valid),
        .ready_in(prepare_ready),
        .is_double_in(prepare_is_double),
        .rm_in(prepare_rm),
        .sp_special_in(prepare_sp_special),
        .sp_special_result_in(prepare_sp_special_result),
        .sp_special_flags_in(prepare_sp_special_flags),
        .sp_result_sign_in(prepare_sp_result_sign),
        .sp_exp_in(prepare_sp_exp),
        .sp_m1_in(prepare_sp_m1),
        .sp_m2_in(prepare_sp_m2),
        .dp_special_in(prepare_dp_special),
        .dp_special_result_in(prepare_dp_special_result),
        .dp_special_flags_in(prepare_dp_special_flags),
        .dp_result_sign_in(prepare_dp_result_sign),
        .dp_exp_in(prepare_dp_exp),
        .dp_m1_in(prepare_dp_m1),
        .dp_m2_in(prepare_dp_m2),
        .valid_out(product_valid),
        .ready_out(product_ready),
        .is_double_out(product_is_double),
        .rm_out(product_rm),
        .sp_special_out(product_sp_special),
        .sp_special_result_out(product_sp_special_result),
        .sp_special_flags_out(product_sp_special_flags),
        .sp_result_sign_out(product_sp_result_sign),
        .sp_exp_out(product_sp_exp),
        .sp_norm_out(product_sp_norm),
        .dp_special_out(product_dp_special),
        .dp_special_result_out(product_dp_special_result),
        .dp_special_flags_out(product_dp_special_flags),
        .dp_result_sign_out(product_dp_result_sign),
        .dp_exp_out(product_dp_exp),
        .dp_norm_out(product_dp_norm)
    );

    fpu64_mul_round u_round (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(product_valid),
        .ready_in(product_ready),
        .is_double_in(product_is_double),
        .rm_in(product_rm),
        .sp_special_in(product_sp_special),
        .sp_special_result_in(product_sp_special_result),
        .sp_special_flags_in(product_sp_special_flags),
        .sp_result_sign_in(product_sp_result_sign),
        .sp_exp_in(product_sp_exp),
        .sp_norm_in(product_sp_norm),
        .dp_special_in(product_dp_special),
        .dp_special_result_in(product_dp_special_result),
        .dp_special_flags_in(product_dp_special_flags),
        .dp_result_sign_in(product_dp_result_sign),
        .dp_exp_in(product_dp_exp),
        .dp_norm_in(product_dp_norm),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .result(result),
        .fflags(fflags)
    );

endmodule
