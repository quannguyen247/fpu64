`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_f2f (
    input wire [63:0] rs1,
    input wire to_double,
    input wire [2:0] rm,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_sign = rs1[31];
    wire [7:0] sp_exp = rs1[30:23];
    wire [22:0] sp_frac = rs1[22:0];
    wire sp_nan = (sp_exp == 8'hFF) && (sp_frac != 23'd0);
    wire sp_snan = sp_nan && !sp_frac[22];
    wire sp_inf = (sp_exp == 8'hFF) && (sp_frac == 23'd0);
    wire sp_zero = (sp_exp == 8'd0) && (sp_frac == 23'd0);
    wire dp_sign = rs1[63];
    wire [10:0] dp_exp = rs1[62:52];
    wire [51:0] dp_frac = rs1[51:0];
    wire dp_nan = (dp_exp == 11'h7FF) && (dp_frac != 52'd0);
    wire dp_snan = dp_nan && !dp_frac[51];
    wire dp_inf = (dp_exp == 11'h7FF) && (dp_frac == 52'd0);
    wire dp_zero = (dp_exp == 11'd0) && (dp_frac == 52'd0);
    reg [23:0] sp_significand;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_up;
    reg [24:0] rounded_significand;
    reg [7:0] result_sp_exp;
    reg [22:0] result_sp_frac;
    reg [11:0] converted_exp;

    always @(*) begin
        result = 64'd0;
        fflags = 5'd0;
        if (to_double) begin
            if (sp_nan) begin
                result = 64'h7FF8000000000000;
                if (sp_snan) fflags[`FF_NV] = 1'b1;
            end else if (sp_inf) begin
                result = {sp_sign, 11'h7FF, 52'd0};
            end else if (sp_zero) begin
                result = {sp_sign, 11'd0, 52'd0};
            end else begin
                converted_exp = {4'd0, sp_exp} - 12'd127 + 12'd1023;
                result = {sp_sign, converted_exp[10:0], sp_frac, 29'd0};
            end
        end else begin
            if (dp_nan) begin
                result = 64'hFFFFFFFF_7FC00000;
                if (dp_snan) fflags[`FF_NV] = 1'b1;
            end else if (dp_inf) begin
                result = {32'hFFFFFFFF, dp_sign, 8'hFF, 23'd0};
            end else if (dp_zero) begin
                result = {32'hFFFFFFFF, dp_sign, 8'd0, 23'd0};
            end else begin
                sp_significand = {(dp_exp == 11'd0) ? 1'b0 : 1'b1, dp_frac[51:29]};
                guard_bit = dp_frac[28];
                round_bit = dp_frac[27];
                sticky_bit = (dp_frac[26:0] != 27'd0);
                round_up = 1'b0;
                case (rm)
                    `RM_RNE: round_up = guard_bit && (round_bit || sticky_bit || sp_significand[0]);
                    `RM_RTZ: round_up = 1'b0;
                    `RM_RDN: round_up = dp_sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RUP: round_up = !dp_sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RMM: round_up = guard_bit;
                    default: round_up = 1'b0;
                endcase
                rounded_significand = sp_significand + (round_up ? 25'd1 : 25'd0);
                converted_exp = {1'b0, dp_exp} - 12'd1023 + (rounded_significand[24] ? 12'd1 : 12'd0);
                if (rounded_significand[24]) rounded_significand = rounded_significand >> 1;
                if ($signed(converted_exp) >= $signed(12'd128)) begin
                    result = {32'hFFFFFFFF, dp_sign, 8'hFF, 23'd0};
                    fflags[`FF_OF] = 1'b1;
                    fflags[`FF_NX] = 1'b1;
                end else if ($signed(converted_exp) <= $signed(12'd0)) begin
                    result = {32'hFFFFFFFF, dp_sign, 8'd0, 23'd0};
                    fflags[`FF_UF] = 1'b1;
                    fflags[`FF_NX] = 1'b1;
                end else begin
                    result_sp_exp = converted_exp[7:0] + 8'd127;
                    result_sp_frac = rounded_significand[22:0];
                    result = {32'hFFFFFFFF, dp_sign, result_sp_exp, result_sp_frac};
                    if (guard_bit || round_bit || sticky_bit) fflags[`FF_NX] = 1'b1;
                end
            end
        end
    end

endmodule
