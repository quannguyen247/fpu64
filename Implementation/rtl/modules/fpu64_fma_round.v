`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_fma_round (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire special_in,
    input wire [63:0] special_result_in,
    input wire [4:0] special_flags_in,
    input wire result_sign_in,
    input wire signed [13:0] result_exp_in,
    input wire [167:0] norm_in,
    output reg valid_out,
    input wire ready_out,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire stall = valid_out && !ready_out;
    reg [167:0] round_vector;
    reg [13:0] subnormal_shift;
    reg signed [13:0] rounded_exp;
    reg [53:0] dp_significand;
    reg [24:0] sp_significand;
    reg [10:0] dp_exp_field;
    reg [7:0] sp_exp_field;
    reg round_guard;
    reg round_bit;
    reg round_sticky;
    reg round_up;
    reg round_inexact;
    reg overflow_to_inf;
    reg [63:0] result_next;
    reg [4:0] flags_next;

    function [167:0] shift_right_jam;
        input [167:0] value;
        input [13:0] amount;
        reg [167:0] shifted;
        reg [167:0] mask;
        begin
            if (amount == 14'd0) begin
                shift_right_jam = value;
            end else if (amount >= 14'd168) begin
                shift_right_jam = 168'd0;
                shift_right_jam[0] = |value;
            end else begin
                shifted = value >> amount;
                mask = (168'd1 << amount) - 168'd1;
                shifted[0] = shifted[0] | (|(value & mask));
                shift_right_jam = shifted;
            end
        end
    endfunction

    assign ready_in = !stall;

    always @(*) begin
        round_vector = norm_in;
        subnormal_shift = 14'd0;
        rounded_exp = result_exp_in;
        dp_significand = 54'd0;
        sp_significand = 25'd0;
        dp_exp_field = 11'd0;
        sp_exp_field = 8'd0;
        round_guard = 1'b0;
        round_bit = 1'b0;
        round_sticky = 1'b0;
        round_up = 1'b0;
        round_inexact = 1'b0;
        overflow_to_inf = 1'b0;
        result_next = 64'd0;
        flags_next = 5'd0;
        if (special_in) begin
            result_next = special_result_in;
            flags_next = special_flags_in;
        end else if (norm_in == 168'd0) begin
            result_next = is_double_in ? {result_sign_in, 11'd0, 52'd0} : {32'hFFFFFFFF, result_sign_in, 8'd0, 23'd0};
        end else if (is_double_in) begin
            if ($signed(result_exp_in) < -14'sd1022) begin
                subnormal_shift = -14'sd1022 - result_exp_in;
                round_vector = shift_right_jam(norm_in, subnormal_shift);
                rounded_exp = -14'sd1022;
            end
            dp_significand = {1'b0, round_vector[166:114]};
            round_guard = round_vector[113];
            round_bit = round_vector[112];
            round_sticky = |round_vector[111:0];
            round_inexact = round_guard || round_bit || round_sticky;
            case (rm_in)
                `RM_RNE: round_up = round_guard && (round_bit || round_sticky || dp_significand[0]);
                `RM_RTZ: round_up = 1'b0;
                `RM_RDN: round_up = result_sign_in && round_inexact;
                `RM_RUP: round_up = !result_sign_in && round_inexact;
                `RM_RMM: round_up = round_guard;
                default: round_up = 1'b0;
            endcase
            dp_significand = dp_significand + (round_up ? 54'd1 : 54'd0);
            if (dp_significand[53]) begin
                dp_significand = dp_significand >> 1;
                rounded_exp = rounded_exp + 14'sd1;
            end
            if ($signed(rounded_exp) > 14'sd1023) begin
                overflow_to_inf = (rm_in == `RM_RNE) || (rm_in == `RM_RMM) || ((rm_in == `RM_RUP) && !result_sign_in) || ((rm_in == `RM_RDN) && result_sign_in);
                result_next = overflow_to_inf ? {result_sign_in, 11'h7FF, 52'd0} : {result_sign_in, 11'h7FE, 52'hFFFFFFFFFFFFF};
                flags_next[`FF_OF] = 1'b1;
                flags_next[`FF_NX] = 1'b1;
            end else if ($signed(result_exp_in) < -14'sd1022) begin
                if (dp_significand[52]) begin
                    result_next = {result_sign_in, 11'd1, dp_significand[51:0]};
                end else begin
                    result_next = {result_sign_in, 11'd0, dp_significand[51:0]};
                    if (round_inexact) flags_next[`FF_UF] = 1'b1;
                end
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end else begin
                dp_exp_field = rounded_exp + 14'sd1023;
                result_next = {result_sign_in, dp_exp_field, dp_significand[51:0]};
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end
        end else begin
            if ($signed(result_exp_in) < -14'sd126) begin
                subnormal_shift = -14'sd126 - result_exp_in;
                round_vector = shift_right_jam(norm_in, subnormal_shift);
                rounded_exp = -14'sd126;
            end
            sp_significand = {1'b0, round_vector[166:143]};
            round_guard = round_vector[142];
            round_bit = round_vector[141];
            round_sticky = |round_vector[140:0];
            round_inexact = round_guard || round_bit || round_sticky;
            case (rm_in)
                `RM_RNE: round_up = round_guard && (round_bit || round_sticky || sp_significand[0]);
                `RM_RTZ: round_up = 1'b0;
                `RM_RDN: round_up = result_sign_in && round_inexact;
                `RM_RUP: round_up = !result_sign_in && round_inexact;
                `RM_RMM: round_up = round_guard;
                default: round_up = 1'b0;
            endcase
            sp_significand = sp_significand + (round_up ? 25'd1 : 25'd0);
            if (sp_significand[24]) begin
                sp_significand = sp_significand >> 1;
                rounded_exp = rounded_exp + 14'sd1;
            end
            if ($signed(rounded_exp) > 14'sd127) begin
                overflow_to_inf = (rm_in == `RM_RNE) || (rm_in == `RM_RMM) || ((rm_in == `RM_RUP) && !result_sign_in) || ((rm_in == `RM_RDN) && result_sign_in);
                result_next = overflow_to_inf ? {32'hFFFFFFFF, result_sign_in, 8'hFF, 23'd0} : {32'hFFFFFFFF, result_sign_in, 8'hFE, 23'h7FFFFF};
                flags_next[`FF_OF] = 1'b1;
                flags_next[`FF_NX] = 1'b1;
            end else if ($signed(result_exp_in) < -14'sd126) begin
                if (sp_significand[23]) begin
                    result_next = {32'hFFFFFFFF, result_sign_in, 8'd1, sp_significand[22:0]};
                end else begin
                    result_next = {32'hFFFFFFFF, result_sign_in, 8'd0, sp_significand[22:0]};
                    if (round_inexact) flags_next[`FF_UF] = 1'b1;
                end
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end else begin
                sp_exp_field = rounded_exp + 14'sd127;
                result_next = {32'hFFFFFFFF, result_sign_in, sp_exp_field, sp_significand[22:0]};
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                result <= result_next;
                fflags <= flags_next;
            end
        end
    end

endmodule
