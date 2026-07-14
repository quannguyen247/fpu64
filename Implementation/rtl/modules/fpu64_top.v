`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_top (
    input wire clk,
    input wire rst_n,

    input wire s_axis_valid,
    output wire s_axis_ready,

    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [3:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [4:0] rs2_val,
    input wire is_double,

    output wire m_axis_valid,
    input wire m_axis_ready,

    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire addsub_valid_in = s_axis_valid && (op == `F_ADD || op == `F_SUB);
    wire addsub_ready_in;
    wire addsub_valid_out;
    wire [63:0] addsub_out;
    wire [4:0] addsub_fflags;
    wire addsub_ready_out;

    wire mul_valid_in = s_axis_valid && (op == `F_MUL);
    wire mul_ready_in;
    wire mul_valid_out;
    wire [63:0] mul_out;
    wire [4:0] mul_fflags;
    wire mul_ready_out;

    wire div_valid_in = s_axis_valid && (op == `F_DIV);
    wire div_ready_in;
    wire div_valid_out;
    wire [63:0] div_out;
    wire [4:0] div_fflags;
    wire div_ready_out;

    wire sqrt_valid_in = s_axis_valid && (op == `F_SQRT);
    wire sqrt_ready_in;
    wire sqrt_valid_out;
    wire [63:0] sqrt_out;
    wire [4:0] sqrt_fflags;
    wire sqrt_ready_out;

    wire compare_valid_in = s_axis_valid && (op == `F_COMP);
    wire compare_ready_in;
    wire compare_valid_out;
    wire [63:0] compare_out;
    wire [4:0] compare_fflags;
    wire compare_ready_out;

    wire classify_valid_in = s_axis_valid && (op == `F_CLASS);
    wire classify_ready_in;
    wire classify_valid_out;
    wire [63:0] classify_out;
    wire classify_ready_out;

    wire convert_valid_in = s_axis_valid && (op == `F_CVT);
    wire convert_ready_in;
    wire convert_valid_out;
    wire [63:0] convert_fp;
    wire [63:0] convert_int;
    wire convert_we_gpr;
    wire convert_we_fpr;
    wire [4:0] convert_fflags;
    wire convert_ready_out;

    wire misc_valid_in = s_axis_valid && (op == `F_SGNJ || op == `F_MINMAX || op == `F_MVTX || op == `F_MVXT);
    wire misc_ready_in;
    wire misc_valid_out;
    wire [63:0] misc_fp;
    wire [63:0] misc_int;
    wire misc_we_gpr;
    wire misc_we_fpr;
    wire [4:0] misc_fflags;
    wire misc_ready_out;

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

    assign s_axis_ready = (op == `F_ADD || op == `F_SUB) ? addsub_ready_in :
                          (op == `F_MUL) ? mul_ready_in :
                          (op == `F_DIV) ? div_ready_in :
                          (op == `F_SQRT) ? sqrt_ready_in :
                          (op == `F_COMP) ? compare_ready_in :
                          (op == `F_CLASS) ? classify_ready_in :
                          (op == `F_CVT) ? convert_ready_in :
                          (op == `F_SGNJ || op == `F_MINMAX || op == `F_MVTX || op == `F_MVXT) ? misc_ready_in : 1'b0;

    assign m_axis_valid = addsub_valid_out | mul_valid_out | div_valid_out | sqrt_valid_out |
                          compare_valid_out | classify_valid_out | convert_valid_out | misc_valid_out;

    // Arbitration logic to avoid data drop if multiple units finish simultaneously
    assign addsub_ready_out   = m_axis_ready && addsub_valid_out;
    assign mul_ready_out      = m_axis_ready && !addsub_valid_out && mul_valid_out;
    assign div_ready_out      = m_axis_ready && !addsub_valid_out && !mul_valid_out && div_valid_out;
    assign sqrt_ready_out     = m_axis_ready && !addsub_valid_out && !mul_valid_out && !div_valid_out && sqrt_valid_out;
    assign compare_ready_out  = m_axis_ready && !addsub_valid_out && !mul_valid_out && !div_valid_out && !sqrt_valid_out && compare_valid_out;
    assign classify_ready_out = m_axis_ready && !addsub_valid_out && !mul_valid_out && !div_valid_out && !sqrt_valid_out && !compare_valid_out && classify_valid_out;
    assign convert_ready_out  = m_axis_ready && !addsub_valid_out && !mul_valid_out && !div_valid_out && !sqrt_valid_out && !compare_valid_out && !classify_valid_out && convert_valid_out;
    assign misc_ready_out     = m_axis_ready && !addsub_valid_out && !mul_valid_out && !div_valid_out && !sqrt_valid_out && !compare_valid_out && !classify_valid_out && !convert_valid_out && misc_valid_out;

    always @(*) begin
        out_fp = 64'd0;
        out_int = 64'd0;
        we_gpr = 1'b0;
        we_fpr = 1'b0;
        fflags = 5'd0;
        if (addsub_valid_out) begin
            out_fp = addsub_out;
            we_fpr = 1'b1;
            fflags = addsub_fflags;
        end else if (mul_valid_out) begin
            out_fp = mul_out;
            we_fpr = 1'b1;
            fflags = mul_fflags;
        end else if (div_valid_out) begin
            out_fp = div_out;
            we_fpr = 1'b1;
            fflags = div_fflags;
        end else if (sqrt_valid_out) begin
            out_fp = sqrt_out;
            we_fpr = 1'b1;
            fflags = sqrt_fflags;
        end else if (compare_valid_out) begin
            out_int = compare_out;
            we_gpr = 1'b1;
            fflags = compare_fflags;
        end else if (classify_valid_out) begin
            out_int = classify_out;
            we_gpr = 1'b1;
        end else if (convert_valid_out) begin
            out_fp = convert_fp;
            out_int = convert_int;
            we_gpr = convert_we_gpr;
            we_fpr = convert_we_fpr;
            fflags = convert_fflags;
        end else if (misc_valid_out) begin
            out_fp = misc_fp;
            out_int = misc_int;
            we_gpr = misc_we_gpr;
            we_fpr = misc_we_fpr;
            fflags = misc_fflags;
        end
    end

endmodule
