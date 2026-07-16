`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_top (
    input wire clk,
    input wire rst_n,

    input wire s_axis_valid,
    output wire s_axis_ready,

    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [63:0] rs3,
    input wire [3:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [4:0] rs2_val,
    input wire is_double,

    output wire m_axis_valid,
    input wire m_axis_ready,

    output wire [63:0] out_fp,
    output wire [63:0] out_int,
    output wire we_gpr,
    output wire we_fpr,
    output wire [4:0] fflags
);

    wire addsub_valid_in;
    wire addsub_ready_in;
    wire addsub_valid_out;
    wire [63:0] addsub_out;
    wire [4:0] addsub_fflags;
    wire addsub_ready_out;
    wire [134:0] addsub_payload;
    wire mul_valid_in;
    wire mul_ready_in;
    wire mul_valid_out;
    wire [63:0] mul_out;
    wire [4:0] mul_fflags;
    wire mul_ready_out;
    wire [134:0] mul_payload;
    wire fma_valid_in;
    wire fma_ready_in;
    wire fma_valid_out;
    wire [63:0] fma_out;
    wire [4:0] fma_fflags;
    wire fma_ready_out;
    wire [134:0] fma_payload;
    wire div_valid_in;
    wire div_ready_in;
    wire div_valid_out;
    wire [63:0] div_out;
    wire [4:0] div_fflags;
    wire div_ready_out;
    wire [134:0] div_payload;
    wire sqrt_valid_in;
    wire sqrt_ready_in;
    wire sqrt_valid_out;
    wire [63:0] sqrt_out;
    wire [4:0] sqrt_fflags;
    wire sqrt_ready_out;
    wire [134:0] sqrt_payload;
    wire compare_valid_in;
    wire compare_ready_in;
    wire compare_valid_out;
    wire [63:0] compare_out;
    wire [4:0] compare_fflags;
    wire compare_ready_out;
    wire [134:0] compare_payload;
    wire classify_valid_in;
    wire classify_ready_in;
    wire classify_valid_out;
    wire [63:0] classify_out;
    wire classify_ready_out;
    wire [134:0] classify_payload;
    wire convert_valid_in;
    wire convert_ready_in;
    wire convert_valid_out;
    wire [63:0] convert_fp;
    wire [63:0] convert_int;
    wire convert_we_gpr;
    wire convert_we_fpr;
    wire [4:0] convert_fflags;
    wire convert_ready_out;
    wire [134:0] convert_payload;
    wire misc_valid_in;
    wire misc_ready_in;
    wire misc_valid_out;
    wire [63:0] misc_fp;
    wire [63:0] misc_int;
    wire misc_we_gpr;
    wire misc_we_fpr;
    wire [4:0] misc_fflags;
    wire misc_ready_out;
    wire [134:0] misc_payload;
    wire [134:0] result_payload;

    assign addsub_valid_in = s_axis_valid && (op == `F_ADD || op == `F_SUB);
    assign mul_valid_in = s_axis_valid && (op == `F_MUL);
    assign fma_valid_in = s_axis_valid &&
                          (op == `F_MADD || op == `F_MSUB || op == `F_NMSUB || op == `F_NMADD);
    assign div_valid_in = s_axis_valid && (op == `F_DIV);
    assign sqrt_valid_in = s_axis_valid && (op == `F_SQRT);
    assign compare_valid_in = s_axis_valid && (op == `F_COMP);
    assign classify_valid_in = s_axis_valid && (op == `F_CLASS);
    assign convert_valid_in = s_axis_valid && (op == `F_CVT);
    assign misc_valid_in = s_axis_valid &&
                           (op == `F_SGNJ || op == `F_MINMAX || op == `F_MVTX || op == `F_MVXT);

    assign s_axis_ready = (op == `F_ADD || op == `F_SUB) ? addsub_ready_in :
                          (op == `F_MUL) ? mul_ready_in :
                          (op == `F_MADD || op == `F_MSUB || op == `F_NMSUB || op == `F_NMADD) ? fma_ready_in :
                          (op == `F_DIV) ? div_ready_in :
                          (op == `F_SQRT) ? sqrt_ready_in :
                          (op == `F_COMP) ? compare_ready_in :
                          (op == `F_CLASS) ? classify_ready_in :
                          (op == `F_CVT) ? convert_ready_in :
                          (op == `F_SGNJ || op == `F_MINMAX || op == `F_MVTX || op == `F_MVXT) ? misc_ready_in :
                          1'b0;

    assign addsub_payload = {addsub_out, 64'd0, 1'b0, 1'b1, addsub_fflags};
    assign mul_payload = {mul_out, 64'd0, 1'b0, 1'b1, mul_fflags};
    assign fma_payload = {fma_out, 64'd0, 1'b0, 1'b1, fma_fflags};
    assign div_payload = {div_out, 64'd0, 1'b0, 1'b1, div_fflags};
    assign sqrt_payload = {sqrt_out, 64'd0, 1'b0, 1'b1, sqrt_fflags};
    assign compare_payload = {64'd0, compare_out, 1'b1, 1'b0, compare_fflags};
    assign classify_payload = {64'd0, classify_out, 1'b1, 1'b0, 5'd0};
    assign convert_payload = {convert_fp, convert_int, convert_we_gpr, convert_we_fpr, convert_fflags};
    assign misc_payload = {misc_fp, misc_int, misc_we_gpr, misc_we_fpr, misc_fflags};
    assign out_fp = result_payload[134:71];
    assign out_int = result_payload[70:7];
    assign we_gpr = result_payload[6];
    assign we_fpr = result_payload[5];
    assign fflags = result_payload[4:0];

    fpu64_addsub u_addsub (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(addsub_valid_in),
        .ready_in(addsub_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_sub(op == `F_SUB),
        .rm(funct3),
        .valid_out(addsub_valid_out),
        .ready_out(addsub_ready_out),
        .result(addsub_out),
        .fflags(addsub_fflags)
    );

    fpu64_mul u_mul (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(mul_valid_in),
        .ready_in(mul_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .rm(funct3),
        .valid_out(mul_valid_out),
        .ready_out(mul_ready_out),
        .result(mul_out),
        .fflags(mul_fflags)
    );

    fpu64_fma u_fma (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(fma_valid_in),
        .ready_in(fma_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .op(op),
        .is_double(is_double),
        .rm(funct3),
        .valid_out(fma_valid_out),
        .ready_out(fma_ready_out),
        .result(fma_out),
        .fflags(fma_fflags)
    );

    fpu64_div u_div (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(div_valid_in),
        .ready_in(div_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .rm(funct3),
        .valid_out(div_valid_out),
        .ready_out(div_ready_out),
        .result(div_out),
        .fflags(div_fflags)
    );

    fpu64_sqrt u_sqrt (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(sqrt_valid_in),
        .ready_in(sqrt_ready_in),
        .rs1(rs1),
        .is_double(is_double),
        .rm(funct3),
        .valid_out(sqrt_valid_out),
        .ready_out(sqrt_ready_out),
        .result(sqrt_out),
        .fflags(sqrt_fflags)
    );

    fpu64_compare u_compare (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(compare_valid_in),
        .ready_in(compare_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .funct3(funct3),
        .is_double(is_double),
        .valid_out(compare_valid_out),
        .ready_out(compare_ready_out),
        .result(compare_out),
        .fflags(compare_fflags)
    );

    fpu64_classify u_classify (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(classify_valid_in),
        .ready_in(classify_ready_in),
        .rs1(rs1),
        .is_double(is_double),
        .valid_out(classify_valid_out),
        .ready_out(classify_ready_out),
        .result(classify_out)
    );

    fpu64_convert u_convert (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(convert_valid_in),
        .ready_in(convert_ready_in),
        .rs1(rs1),
        .rs2_val(rs2_val),
        .funct7(funct7),
        .rm(funct3),
        .valid_out(convert_valid_out),
        .ready_out(convert_ready_out),
        .out_fp(convert_fp),
        .out_int(convert_int),
        .we_gpr(convert_we_gpr),
        .we_fpr(convert_we_fpr),
        .fflags(convert_fflags)
    );

    fpu64_misc u_misc (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(misc_valid_in),
        .ready_in(misc_ready_in),
        .rs1(rs1),
        .rs2(rs2),
        .op(op),
        .funct3(funct3),
        .is_double(is_double),
        .valid_out(misc_valid_out),
        .ready_out(misc_ready_out),
        .out_fp(misc_fp),
        .out_int(misc_int),
        .we_gpr(misc_we_gpr),
        .we_fpr(misc_we_fpr),
        .fflags(misc_fflags)
    );

    fpu64_result_arbiter u_result_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .addsub_valid(addsub_valid_out),
        .addsub_payload(addsub_payload),
        .addsub_ready(addsub_ready_out),
        .mul_valid(mul_valid_out),
        .mul_payload(mul_payload),
        .mul_ready(mul_ready_out),
        .fma_valid(fma_valid_out),
        .fma_payload(fma_payload),
        .fma_ready(fma_ready_out),
        .div_valid(div_valid_out),
        .div_payload(div_payload),
        .div_ready(div_ready_out),
        .sqrt_valid(sqrt_valid_out),
        .sqrt_payload(sqrt_payload),
        .sqrt_ready(sqrt_ready_out),
        .compare_valid(compare_valid_out),
        .compare_payload(compare_payload),
        .compare_ready(compare_ready_out),
        .classify_valid(classify_valid_out),
        .classify_payload(classify_payload),
        .classify_ready(classify_ready_out),
        .convert_valid(convert_valid_out),
        .convert_payload(convert_payload),
        .convert_ready(convert_ready_out),
        .misc_valid(misc_valid_out),
        .misc_payload(misc_payload),
        .misc_ready(misc_ready_out),
        .m_axis_valid(m_axis_valid),
        .m_axis_ready(m_axis_ready),
        .result_payload(result_payload)
    );

endmodule
