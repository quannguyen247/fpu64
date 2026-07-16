`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_misc (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [3:0] op,
    input wire [2:0] funct3,
    input wire is_double,

    output reg valid_out,
    input wire ready_out,

    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire stall;
    wire dp_nan1;
    wire dp_nan2;
    wire sp_nan1;
    wire sp_nan2;
    wire dp_snan1;
    wire dp_snan2;
    wire sp_snan1;
    wire sp_snan2;
    wire minmax_any_nan;
    wire minmax_any_snan;
    wire minmax_both_nan;
    wire sgnj_sign;
    wire cmp_lt;
    reg [63:0] sgnj_res;
    reg [63:0] minmax_res;
    reg [4:0] minmax_flg;

    assign stall = valid_out && !ready_out;
    assign ready_in = !stall;
    assign dp_nan1 = (rs1[62:52] == 11'h7FF) && (rs1[51:0] != 52'd0);
    assign dp_nan2 = (rs2[62:52] == 11'h7FF) && (rs2[51:0] != 52'd0);
    assign sp_nan1 = (rs1[30:23] == 8'hFF) && (rs1[22:0] != 23'd0);
    assign sp_nan2 = (rs2[30:23] == 8'hFF) && (rs2[22:0] != 23'd0);
    assign dp_snan1 = dp_nan1 && !rs1[51];
    assign dp_snan2 = dp_nan2 && !rs2[51];
    assign sp_snan1 = sp_nan1 && !rs1[22];
    assign sp_snan2 = sp_nan2 && !rs2[22];
    assign minmax_any_nan = is_double ? (dp_nan1 || dp_nan2) : (sp_nan1 || sp_nan2);
    assign minmax_any_snan = is_double ? (dp_snan1 || dp_snan2) : (sp_snan1 || sp_snan2);
    assign minmax_both_nan = is_double ? (dp_nan1 && dp_nan2) : (sp_nan1 && sp_nan2);
    assign sgnj_sign = is_double ? rs1[63] : rs1[31];

    fpu64_compare_logic u_cmp_logic (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_lt(cmp_lt),
        .is_eq()
    );

    always @(*) begin
        if (is_double) begin
            case (funct3)
                3'b000: sgnj_res = {rs2[63], rs1[62:0]};
                3'b001: sgnj_res = {~rs2[63], rs1[62:0]};
                3'b010: sgnj_res = {rs1[63] ^ rs2[63], rs1[62:0]};
                default: sgnj_res = rs1;
            endcase
        end else begin
            case (funct3)
                3'b000: sgnj_res = {32'hFFFFFFFF, rs2[31], rs1[30:0]};
                3'b001: sgnj_res = {32'hFFFFFFFF, ~rs2[31], rs1[30:0]};
                3'b010: sgnj_res = {32'hFFFFFFFF, rs1[31] ^ rs2[31], rs1[30:0]};
                default: sgnj_res = {32'hFFFFFFFF, rs1[31:0]};
            endcase
        end
    end

    always @(*) begin
        minmax_res = 64'd0;
        minmax_flg = 5'd0;
        if (minmax_any_nan) begin
            if (minmax_any_snan) begin
                minmax_flg[`FF_NV] = 1'b1;
            end
            if (minmax_both_nan) begin
                minmax_res = is_double ? 64'h7FF8000000000000 : 64'hFFFFFFFF_7FC00000;
            end else begin
                minmax_res = is_double ? (dp_nan1 ? rs2 : rs1) : (sp_nan1 ? rs2 : rs1);
            end
        end else begin
            case (funct3[0])
                1'b0: minmax_res = cmp_lt ? rs1 : rs2;
                1'b1: minmax_res = cmp_lt ? rs2 : rs1;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            out_fp <= 64'd0;
            out_int <= 64'd0;
            we_gpr <= 1'b0;
            we_fpr <= 1'b0;
            fflags <= 5'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                out_fp <= 64'd0;
                out_int <= 64'd0;
                we_gpr <= 1'b0;
                we_fpr <= 1'b0;
                fflags <= 5'd0;
                case (op)
                    `F_SGNJ: begin
                        we_fpr <= 1'b1;
                        out_fp <= sgnj_res;
                    end
                    `F_MINMAX: begin
                        we_fpr <= 1'b1;
                        out_fp <= minmax_res;
                        fflags <= minmax_flg;
                    end
                    `F_MVTX: begin
                        we_fpr <= 1'b1;
                        out_fp <= is_double ? rs1 : {32'hFFFFFFFF, rs1[31:0]};
                    end
                    `F_MVXT: begin
                        we_gpr <= 1'b1;
                        out_int <= is_double ? rs1 : {{32{sgnj_sign}}, rs1[31:0]};
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
