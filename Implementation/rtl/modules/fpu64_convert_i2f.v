`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_i2f (
    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire is_double,
    input wire [2:0] rm,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    reg [63:0] absolute_value;
    reg sign;
    reg [5:0] leading_zero_count;
    reg [11:0] exponent;
    reg [63:0] significand;
    reg [63:0] remainder;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_up;
    reg [63:0] rounded_significand;
    reg [10:0] dp_exp;
    reg [51:0] dp_frac;
    reg [7:0] sp_exp;
    reg [22:0] sp_frac;
    integer leading_i;

    always @(*) begin
        result = 64'd0;
        fflags = 5'd0;
        sign = 1'b0;
        absolute_value = 64'd0;
        case (rs2_val)
            5'd0: begin
                sign = rs1[31];
                absolute_value = sign ? -{{32{rs1[31]}}, rs1[31:0]} : {{32{1'b0}}, rs1[31:0]};
            end
            5'd1: begin
                sign = 1'b0;
                absolute_value = {{32{1'b0}}, rs1[31:0]};
            end
            5'd2: begin
                sign = rs1[63];
                absolute_value = sign ? -rs1 : rs1;
            end
            5'd3: begin
                sign = 1'b0;
                absolute_value = rs1;
            end
            default: begin
            end
        endcase
        if (absolute_value == 64'd0) begin
            if (is_double) begin
                result = {sign, 11'd0, 52'd0};
            end else begin
                result = {32'hFFFFFFFF, sign, 8'd0, 23'd0};
            end
        end else begin
            leading_zero_count = 6'd0;
            for (leading_i = 0; leading_i < 64; leading_i = leading_i + 1) begin
                if (absolute_value[63 - leading_i] == 1'b0 && leading_zero_count == leading_i) begin
                    leading_zero_count = leading_zero_count + 6'd1;
                end
            end
            exponent = 12'd63 - leading_zero_count;
            if (is_double) begin
                if (leading_zero_count <= 11) begin
                    significand = absolute_value >> (11 - leading_zero_count);
                    remainder = absolute_value << (leading_zero_count + 53);
                    guard_bit = remainder[63];
                    round_bit = remainder[62];
                    sticky_bit = (remainder[61:0] != 62'd0);
                end else begin
                    significand = absolute_value << (leading_zero_count - 11);
                    guard_bit = 1'b0;
                    round_bit = 1'b0;
                    sticky_bit = 1'b0;
                end
                round_up = 1'b0;
                case (rm)
                    `RM_RNE: round_up = guard_bit && (round_bit || sticky_bit || significand[0]);
                    `RM_RTZ: round_up = 1'b0;
                    `RM_RDN: round_up = sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RUP: round_up = !sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RMM: round_up = guard_bit;
                    default: round_up = 1'b0;
                endcase
                rounded_significand = significand + (round_up ? 64'd1 : 64'd0);
                if (rounded_significand[53]) begin
                    rounded_significand = rounded_significand >> 1;
                    exponent = exponent + 12'd1;
                end
                dp_exp = exponent + 12'd1023;
                dp_frac = rounded_significand[51:0];
                result = {sign, dp_exp, dp_frac};
                if (guard_bit || round_bit || sticky_bit) fflags[`FF_NX] = 1'b1;
            end else begin
                if (leading_zero_count <= 40) begin
                    significand = absolute_value >> (40 - leading_zero_count);
                    remainder = absolute_value << (leading_zero_count + 24);
                    guard_bit = remainder[63];
                    round_bit = remainder[62];
                    sticky_bit = (remainder[61:0] != 62'd0);
                end else begin
                    significand = absolute_value << (leading_zero_count - 40);
                    guard_bit = 1'b0;
                    round_bit = 1'b0;
                    sticky_bit = 1'b0;
                end
                round_up = 1'b0;
                case (rm)
                    `RM_RNE: round_up = guard_bit && (round_bit || sticky_bit || significand[0]);
                    `RM_RTZ: round_up = 1'b0;
                    `RM_RDN: round_up = sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RUP: round_up = !sign && (guard_bit || round_bit || sticky_bit);
                    `RM_RMM: round_up = guard_bit;
                    default: round_up = 1'b0;
                endcase
                rounded_significand = significand + (round_up ? 64'd1 : 64'd0);
                if (rounded_significand[24]) begin
                    rounded_significand = rounded_significand >> 1;
                    exponent = exponent + 12'd1;
                end
                sp_exp = exponent + 12'd127;
                sp_frac = rounded_significand[22:0];
                result = {32'hFFFFFFFF, sign, sp_exp, sp_frac};
                if (guard_bit || round_bit || sticky_bit) fflags[`FF_NX] = 1'b1;
            end
        end
    end

endmodule
