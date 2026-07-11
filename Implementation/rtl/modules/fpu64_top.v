`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_top (
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [63:0] rs3,

    input wire [3:0] op,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [4:0] rs2_val,
    input wire is_double,

    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire [63:0] addsub_out;
    wire [4:0] addsub_fflags;

    wire [63:0] mul_out;
    wire [4:0] mul_fflags;

    wire [63:0] div_out;
    wire [4:0] div_fflags;

    wire [63:0] sqrt_out;
    wire [4:0] sqrt_fflags;

    wire [63:0] compare_out;
    wire [4:0] compare_fflags;

    wire [63:0] classify_out;

    wire [63:0] convert_fp;
    wire [63:0] convert_int;
    wire convert_we_gpr;
    wire convert_we_fpr;
    wire [4:0] convert_fflags;

    wire sgnj_sign = is_double ? rs1[63] : rs1[31];

    wire sp_nan1 = (rs1[30:23] == 8'hFF) && (rs1[22:0] != 23'd0);
    wire sp_nan2 = (rs2[30:23] == 8'hFF) && (rs2[22:0] != 23'd0);
    wire sp_snan1 = sp_nan1 && !rs1[22];
    wire sp_snan2 = sp_nan2 && !rs2[22];

    wire dp_nan1 = (rs1[62:52] == 11'h7FF) && (rs1[51:0] != 52'd0);
    wire dp_nan2 = (rs2[62:52] == 11'h7FF) && (rs2[51:0] != 52'd0);
    wire dp_snan1 = dp_nan1 && !rs1[51];
    wire dp_snan2 = dp_nan2 && !rs2[51];

    wire minmax_any_nan = is_double ? (dp_nan1 || dp_nan2) : (sp_nan1 || sp_nan2);
    wire minmax_any_snan = is_double ? (dp_snan1 || dp_snan2) : (sp_snan1 || sp_snan2);
    wire minmax_both_nan = is_double ? (dp_nan1 && dp_nan2) : (sp_nan1 && sp_nan2);
    wire minmax_lt = compare_out[0];

    reg [63:0] sgnj_result;
    reg [63:0] minmax_result;
    reg [4:0] minmax_fflags;

    fpu64_addsub u_addsub (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_sub(op == `F_SUB),
        .rm(funct3),
        .result(addsub_out),
        .fflags(addsub_fflags)
    );

    fpu64_mul u_mul (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .rm(funct3),
        .result(mul_out),
        .fflags(mul_fflags)
    );

    fpu64_div u_div (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .rm(funct3),
        .result(div_out),
        .fflags(div_fflags)
    );

    fpu64_sqrt u_sqrt (
        .rs1(rs1),
        .is_double(is_double),
        .rm(funct3),
        .result(sqrt_out),
        .fflags(sqrt_fflags)
    );

    fpu64_compare u_compare (
        .rs1(rs1),
        .rs2(rs2),
        .funct3(funct3),
        .is_double(is_double),
        .result(compare_out),
        .fflags(compare_fflags)
    );

    fpu64_classify u_classify (
        .rs1(rs1),
        .is_double(is_double),
        .result(classify_out)
    );

    fpu64_convert u_convert (
        .rs1(rs1),
        .rs2_val(rs2_val),
        .funct7(funct7),
        .rm(funct3),
        .out_fp(convert_fp),
        .out_int(convert_int),
        .we_gpr(convert_we_gpr),
        .we_fpr(convert_we_fpr),
        .fflags(convert_fflags)
    );

    always @(*) begin
        if (is_double) begin
            case (funct3)
                3'b000: sgnj_result = {rs2[63], rs1[62:0]};
                3'b001: sgnj_result = {~rs2[63], rs1[62:0]};
                3'b010: sgnj_result = {rs1[63] ^ rs2[63], rs1[62:0]};
                default: sgnj_result = rs1;
            endcase
        end else begin
            case (funct3)
                3'b000: sgnj_result = {32'hFFFFFFFF, rs2[31], rs1[30:0]};
                3'b001: sgnj_result = {32'hFFFFFFFF, ~rs2[31], rs1[30:0]};
                3'b010: sgnj_result = {32'hFFFFFFFF, rs1[31] ^ rs2[31], rs1[30:0]};
                default: sgnj_result = rs1;
            endcase
        end
    end

    always @(*) begin
        minmax_result = 64'd0;
        minmax_fflags = 5'd0;
        if (minmax_any_nan) begin
            if (minmax_any_snan) minmax_fflags[`FF_NV] = 1'b1;
            if (minmax_both_nan) begin
                minmax_result = is_double ? 64'h7FF8000000000000 : 64'hFFFFFFFF_7FC00000;
            end else begin
                minmax_result = is_double ? (dp_nan1 ? rs2 : rs1) : (sp_nan1 ? rs2 : rs1);
            end
        end else begin
            case (funct3[0])
                1'b0: minmax_result = minmax_lt ? rs1 : rs2;
                1'b1: minmax_result = minmax_lt ? rs2 : rs1;
            endcase
        end
    end

    always @(*) begin
        out_fp = 64'd0;
        out_int = 64'd0;
        we_gpr = 1'b0;
        we_fpr = 1'b0;
        fflags = 5'd0;
        case (op)
            `F_ADD, `F_SUB: begin
                we_fpr = 1'b1;
                out_fp = addsub_out;
                fflags = addsub_fflags;
            end
            `F_MUL: begin
                we_fpr = 1'b1;
                out_fp = mul_out;
                fflags = mul_fflags;
            end
            `F_DIV: begin
                we_fpr = 1'b1;
                out_fp = div_out;
                fflags = div_fflags;
            end
            `F_SQRT: begin
                we_fpr = 1'b1;
                out_fp = sqrt_out;
                fflags = sqrt_fflags;
            end
            `F_SGNJ: begin
                we_fpr = 1'b1;
                out_fp = sgnj_result;
            end
            `F_MINMAX: begin
                we_fpr = 1'b1;
                out_fp = minmax_result;
                fflags = minmax_fflags;
            end
            `F_CVT: begin
                we_gpr = convert_we_gpr;
                we_fpr = convert_we_fpr;
                out_fp = convert_fp;
                out_int = convert_int;
                fflags = convert_fflags;
            end
            `F_COMP: begin
                we_gpr = 1'b1;
                out_int = compare_out;
                fflags = compare_fflags;
            end
            `F_CLASS: begin
                we_gpr = 1'b1;
                out_int = classify_out;
            end
            `F_MVTX: begin
                we_fpr = 1'b1;
                out_fp = is_double ? rs1 : {32'hFFFFFFFF, rs1[31:0]};
            end
            `F_MVXT: begin
                we_gpr = 1'b1;
                out_int = is_double ? rs1 : {{32{sgnj_sign}}, rs1[31:0]};
            end
            default: begin
            end
        endcase
    end

endmodule
