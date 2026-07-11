`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_compare (
    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire [2:0] funct3,
    input wire is_double,

    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire sp_s2 = rs2[31];
    wire [7:0] sp_e2 = rs2[30:23];
    wire [22:0] sp_f2 = rs2[22:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_nan2 = (sp_e2 == 8'hFF) && (sp_f2 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_snan2 = sp_nan2 && !sp_f2[22];
    wire sp_any_nan = sp_nan1 || sp_nan2;
    wire sp_any_snan = sp_snan1 || sp_snan2;
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);
    wire sp_zero2 = (sp_e2 == 8'd0) && (sp_f2 == 23'd0);
    wire sp_both_zero = sp_zero1 && sp_zero2;
    wire sp_mag1_lt_mag2 = ({sp_e1, sp_f1} < {sp_e2, sp_f2});
    wire sp_mag_eq = ({sp_e1, sp_f1} == {sp_e2, sp_f2});

    reg sp_lt;
    reg sp_eq;

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire dp_s2 = rs2[63];
    wire [10:0] dp_e2 = rs2[62:52];
    wire [51:0] dp_f2 = rs2[51:0];

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_nan2 = (dp_e2 == 11'h7FF) && (dp_f2 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_snan2 = dp_nan2 && !dp_f2[51];
    wire dp_any_nan = dp_nan1 || dp_nan2;
    wire dp_any_snan = dp_snan1 || dp_snan2;
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);
    wire dp_zero2 = (dp_e2 == 11'd0) && (dp_f2 == 52'd0);
    wire dp_both_zero = dp_zero1 && dp_zero2;
    wire dp_mag1_lt_mag2 = ({dp_e1, dp_f1} < {dp_e2, dp_f2});
    wire dp_mag_eq = ({dp_e1, dp_f1} == {dp_e2, dp_f2});

    reg dp_lt;
    reg dp_eq;

    wire any_nan = is_double ? dp_any_nan : sp_any_nan;
    wire any_snan = is_double ? dp_any_snan : sp_any_snan;
    wire cmp_lt = is_double ? dp_lt : sp_lt;
    wire cmp_eq = is_double ? dp_eq : sp_eq;

    always @(*) begin
        sp_eq = sp_both_zero || (sp_s1 == sp_s2 && sp_mag_eq);
        if (sp_both_zero)
            sp_lt = 1'b0;
        else if (sp_s1 && !sp_s2)
            sp_lt = 1'b1;
        else if (!sp_s1 && sp_s2)
            sp_lt = 1'b0;
        else if (!sp_s1)
            sp_lt = sp_mag1_lt_mag2;
        else
            sp_lt = !sp_mag1_lt_mag2 && !sp_mag_eq;
    end

    always @(*) begin
        dp_eq = dp_both_zero || (dp_s1 == dp_s2 && dp_mag_eq);
        if (dp_both_zero)
            dp_lt = 1'b0;
        else if (dp_s1 && !dp_s2)
            dp_lt = 1'b1;
        else if (!dp_s1 && dp_s2)
            dp_lt = 1'b0;
        else if (!dp_s1)
            dp_lt = dp_mag1_lt_mag2;
        else
            dp_lt = !dp_mag1_lt_mag2 && !dp_mag_eq;
    end

    always @(*) begin
        result = 64'd0;
        fflags = 5'd0;
        case (funct3)
            3'b010: begin
                if (any_nan) begin
                    result = 64'd0;
                    if (any_snan) fflags[`FF_NV] = 1'b1;
                end else begin
                    result = cmp_eq ? 64'd1 : 64'd0;
                end
            end
            3'b001: begin
                if (any_nan) begin
                    result = 64'd0;
                    fflags[`FF_NV] = 1'b1;
                end else begin
                    result = cmp_lt ? 64'd1 : 64'd0;
                end
            end
            3'b000: begin
                if (any_nan) begin
                    result = 64'd0;
                    fflags[`FF_NV] = 1'b1;
                end else begin
                    result = (cmp_lt || cmp_eq) ? 64'd1 : 64'd0;
                end
            end
            default: begin
                result = 64'd0;
            end
        endcase
    end

endmodule
