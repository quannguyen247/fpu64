`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_addsub (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire is_sub,
    input wire [2:0] rm,

    output wire valid_out,
    input wire ready_out,

    output wire [63:0] result,
    output wire [4:0] fflags
);

    wire prepare_valid;
    wire prepare_ready;
    wire ex1_is_double;
    wire [2:0] ex1_rm;
    wire ex1_sp_special;
    wire [63:0] ex1_sp_special_res;
    wire [4:0] ex1_sp_special_flags;
    wire ex1_sp_eff_sub;
    wire ex1_sp_res_sign;
    wire [7:0] ex1_sp_res_exp;
    wire [8:0] ex1_sp_exp_diff;
    wire [24:0] ex1_sp_op1;
    wire [24:0] ex1_sp_op2;
    wire ex1_dp_special;
    wire [63:0] ex1_dp_special_res;
    wire [4:0] ex1_dp_special_flags;
    wire ex1_dp_eff_sub;
    wire ex1_dp_res_sign;
    wire [10:0] ex1_dp_res_exp;
    wire [11:0] ex1_dp_exp_diff;
    wire [53:0] ex1_dp_op1;
    wire [53:0] ex1_dp_op2;

    wire align_valid;
    wire align_ready;
    wire ex2_is_double;
    wire [2:0] ex2_rm;
    wire ex2_sp_special;
    wire [63:0] ex2_sp_special_res;
    wire [4:0] ex2_sp_special_flags;
    wire ex2_sp_res_sign;
    wire [7:0] ex2_sp_res_exp;
    wire [28:0] ex2_sp_sum;
    wire ex2_dp_special;
    wire [63:0] ex2_dp_special_res;
    wire [4:0] ex2_dp_special_flags;
    wire ex2_dp_res_sign;
    wire [10:0] ex2_dp_res_exp;
    wire [57:0] ex2_dp_sum;

    wire normalize_valid;
    wire normalize_ready;
    wire ex4_is_double;
    wire [2:0] ex4_rm;
    wire ex4_sp_special;
    wire [63:0] ex4_sp_special_res;
    wire [4:0] ex4_sp_special_flags;
    wire ex4_sp_res_sign;
    wire [7:0] ex4_sp_exp_adj;
    wire [28:0] ex4_sp_sum_norm;
    wire ex4_dp_special;
    wire [63:0] ex4_dp_special_res;
    wire [4:0] ex4_dp_special_flags;
    wire ex4_dp_res_sign;
    wire [10:0] ex4_dp_exp_adj;
    wire [57:0] ex4_dp_sum_norm;

    fpu64_addsub_prepare u_prepare (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_sub(is_sub),
        .rm(rm),
        .valid_out(prepare_valid),
        .ready_out(prepare_ready),
        .ex1_is_double(ex1_is_double),
        .ex1_rm(ex1_rm),
        .ex1_sp_special(ex1_sp_special),
        .ex1_sp_special_res(ex1_sp_special_res),
        .ex1_sp_special_flags(ex1_sp_special_flags),
        .ex1_sp_eff_sub(ex1_sp_eff_sub),
        .ex1_sp_res_sign(ex1_sp_res_sign),
        .ex1_sp_res_exp(ex1_sp_res_exp),
        .ex1_sp_exp_diff(ex1_sp_exp_diff),
        .ex1_sp_op1(ex1_sp_op1),
        .ex1_sp_op2(ex1_sp_op2),
        .ex1_dp_special(ex1_dp_special),
        .ex1_dp_special_res(ex1_dp_special_res),
        .ex1_dp_special_flags(ex1_dp_special_flags),
        .ex1_dp_eff_sub(ex1_dp_eff_sub),
        .ex1_dp_res_sign(ex1_dp_res_sign),
        .ex1_dp_res_exp(ex1_dp_res_exp),
        .ex1_dp_exp_diff(ex1_dp_exp_diff),
        .ex1_dp_op1(ex1_dp_op1),
        .ex1_dp_op2(ex1_dp_op2)
    );

    fpu64_addsub_align_add u_align_add (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(prepare_valid),
        .ready_in(prepare_ready),
        .ex1_is_double(ex1_is_double),
        .ex1_rm(ex1_rm),
        .ex1_sp_special(ex1_sp_special),
        .ex1_sp_special_res(ex1_sp_special_res),
        .ex1_sp_special_flags(ex1_sp_special_flags),
        .ex1_sp_eff_sub(ex1_sp_eff_sub),
        .ex1_sp_res_sign(ex1_sp_res_sign),
        .ex1_sp_res_exp(ex1_sp_res_exp),
        .ex1_sp_exp_diff(ex1_sp_exp_diff),
        .ex1_sp_op1(ex1_sp_op1),
        .ex1_sp_op2(ex1_sp_op2),
        .ex1_dp_special(ex1_dp_special),
        .ex1_dp_special_res(ex1_dp_special_res),
        .ex1_dp_special_flags(ex1_dp_special_flags),
        .ex1_dp_eff_sub(ex1_dp_eff_sub),
        .ex1_dp_res_sign(ex1_dp_res_sign),
        .ex1_dp_res_exp(ex1_dp_res_exp),
        .ex1_dp_exp_diff(ex1_dp_exp_diff),
        .ex1_dp_op1(ex1_dp_op1),
        .ex1_dp_op2(ex1_dp_op2),
        .valid_out(align_valid),
        .ready_out(align_ready),
        .ex2_is_double(ex2_is_double),
        .ex2_rm(ex2_rm),
        .ex2_sp_special(ex2_sp_special),
        .ex2_sp_special_res(ex2_sp_special_res),
        .ex2_sp_special_flags(ex2_sp_special_flags),
        .ex2_sp_res_sign(ex2_sp_res_sign),
        .ex2_sp_res_exp(ex2_sp_res_exp),
        .ex2_sp_sum(ex2_sp_sum),
        .ex2_dp_special(ex2_dp_special),
        .ex2_dp_special_res(ex2_dp_special_res),
        .ex2_dp_special_flags(ex2_dp_special_flags),
        .ex2_dp_res_sign(ex2_dp_res_sign),
        .ex2_dp_res_exp(ex2_dp_res_exp),
        .ex2_dp_sum(ex2_dp_sum)
    );

    fpu64_addsub_normalize u_normalize (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(align_valid),
        .ready_in(align_ready),
        .ex2_is_double(ex2_is_double),
        .ex2_rm(ex2_rm),
        .ex2_sp_special(ex2_sp_special),
        .ex2_sp_special_res(ex2_sp_special_res),
        .ex2_sp_special_flags(ex2_sp_special_flags),
        .ex2_sp_res_sign(ex2_sp_res_sign),
        .ex2_sp_res_exp(ex2_sp_res_exp),
        .ex2_sp_sum(ex2_sp_sum),
        .ex2_dp_special(ex2_dp_special),
        .ex2_dp_special_res(ex2_dp_special_res),
        .ex2_dp_special_flags(ex2_dp_special_flags),
        .ex2_dp_res_sign(ex2_dp_res_sign),
        .ex2_dp_res_exp(ex2_dp_res_exp),
        .ex2_dp_sum(ex2_dp_sum),
        .valid_out(normalize_valid),
        .ready_out(normalize_ready),
        .ex4_is_double(ex4_is_double),
        .ex4_rm(ex4_rm),
        .ex4_sp_special(ex4_sp_special),
        .ex4_sp_special_res(ex4_sp_special_res),
        .ex4_sp_special_flags(ex4_sp_special_flags),
        .ex4_sp_res_sign(ex4_sp_res_sign),
        .ex4_sp_exp_adj(ex4_sp_exp_adj),
        .ex4_sp_sum_norm(ex4_sp_sum_norm),
        .ex4_dp_special(ex4_dp_special),
        .ex4_dp_special_res(ex4_dp_special_res),
        .ex4_dp_special_flags(ex4_dp_special_flags),
        .ex4_dp_res_sign(ex4_dp_res_sign),
        .ex4_dp_exp_adj(ex4_dp_exp_adj),
        .ex4_dp_sum_norm(ex4_dp_sum_norm)
    );

    fpu64_addsub_round u_round (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(normalize_valid),
        .ready_in(normalize_ready),
        .ex4_is_double(ex4_is_double),
        .ex4_rm(ex4_rm),
        .ex4_sp_special(ex4_sp_special),
        .ex4_sp_special_res(ex4_sp_special_res),
        .ex4_sp_special_flags(ex4_sp_special_flags),
        .ex4_sp_res_sign(ex4_sp_res_sign),
        .ex4_sp_exp_adj(ex4_sp_exp_adj),
        .ex4_sp_sum_norm(ex4_sp_sum_norm),
        .ex4_dp_special(ex4_dp_special),
        .ex4_dp_special_res(ex4_dp_special_res),
        .ex4_dp_special_flags(ex4_dp_special_flags),
        .ex4_dp_res_sign(ex4_dp_res_sign),
        .ex4_dp_exp_adj(ex4_dp_exp_adj),
        .ex4_dp_sum_norm(ex4_dp_sum_norm),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .result(result),
        .fflags(fflags)
    );

endmodule
