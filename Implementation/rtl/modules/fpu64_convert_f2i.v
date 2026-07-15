`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert_f2i (
    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire is_double,
    input wire [2:0] rm,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_sign = rs1[31];
    wire [7:0] sp_exp = rs1[30:23];
    wire [22:0] sp_frac = rs1[22:0];
    wire sp_nan = (sp_exp == 8'hFF) && (sp_frac != 23'd0);
    wire sp_inf = (sp_exp == 8'hFF) && (sp_frac == 23'd0);
    wire sp_zero = (sp_exp == 8'd0) && (sp_frac == 23'd0);
    wire dp_sign = rs1[63];
    wire [10:0] dp_exp = rs1[62:52];
    wire [51:0] dp_frac = rs1[51:0];
    wire dp_nan = (dp_exp == 11'h7FF) && (dp_frac != 52'd0);
    wire dp_inf = (dp_exp == 11'h7FF) && (dp_frac == 52'd0);
    wire dp_zero = (dp_exp == 11'd0) && (dp_frac == 52'd0);
    reg [63:0] temp;
    reg [11:0] exponent;
    reg sign;
    reg [63:0] shifted;
    reg [63:0] remainder;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_up;
    reg [63:0] rounded;
    reg [63:0] final_value;
    reg overflow;

    always @(*) begin
        result = 64'd0;
        fflags = 5'd0;
        overflow = 1'b0;
        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;
        shifted = 64'd0;
        if (is_double) begin
            sign = dp_sign;
            exponent = {1'b0, dp_exp} - 12'd1023;
            temp = {(dp_exp == 11'd0) ? 1'b0 : 1'b1, dp_frac, 11'd0};
        end else begin
            sign = sp_sign;
            exponent = {4'd0, sp_exp} - 12'd127;
            temp = {(sp_exp == 8'd0) ? 1'b0 : 1'b1, sp_frac, 40'd0};
        end
        if ((is_double && dp_nan) || (!is_double && sp_nan)) begin
            fflags[`FF_NV] = 1'b1;
            case (rs2_val)
                5'd0: result = 64'hFFFFFFFF_7FFFFFFF;
                5'd1: result = 64'hFFFFFFFF_FFFFFFFF;
                5'd2: result = 64'h7FFFFFFFFFFFFFFF;
                5'd3: result = 64'hFFFFFFFFFFFFFFFF;
                default: result = 64'd0;
            endcase
        end else if ((is_double && dp_inf) || (!is_double && sp_inf)) begin
            fflags[`FF_NV] = 1'b1;
            if (sign) begin
                case (rs2_val)
                    5'd0: result = 64'hFFFFFFFF_80000000;
                    5'd1: result = 64'hFFFFFFFF_00000000;
                    5'd2: result = 64'h8000000000000000;
                    5'd3: result = 64'h0000000000000000;
                    default: result = 64'd0;
                endcase
            end else begin
                case (rs2_val)
                    5'd0: result = 64'hFFFFFFFF_7FFFFFFF;
                    5'd1: result = 64'hFFFFFFFF_FFFFFFFF;
                    5'd2: result = 64'h7FFFFFFFFFFFFFFF;
                    5'd3: result = 64'hFFFFFFFFFFFFFFFF;
                    default: result = 64'd0;
                endcase
            end
        end else if ((is_double && dp_zero) || (!is_double && sp_zero)) begin
            result = 64'd0;
        end else begin
            if ($signed(exponent) >= $signed(12'd63)) begin
                overflow = 1'b1;
            end else if ($signed(exponent) < $signed(-12'd2)) begin
                shifted = 64'd0;
                guard_bit = 1'b0;
                round_bit = 1'b0;
                sticky_bit = (temp != 64'd0);
            end else begin
                shifted = temp >> (12'd63 - exponent);
                remainder = temp << (exponent + 12'd1);
                guard_bit = remainder[63];
                round_bit = remainder[62];
                sticky_bit = (remainder[61:0] != 62'd0);
            end
            round_up = 1'b0;
            case (rm)
                `RM_RNE: round_up = guard_bit && (round_bit || sticky_bit || shifted[0]);
                `RM_RTZ: round_up = 1'b0;
                `RM_RDN: round_up = sign && (guard_bit || round_bit || sticky_bit);
                `RM_RUP: round_up = !sign && (guard_bit || round_bit || sticky_bit);
                `RM_RMM: round_up = guard_bit;
                default: round_up = 1'b0;
            endcase
            rounded = shifted + (round_up ? 64'd1 : 64'd0);
            final_value = sign ? -rounded : rounded;
            if (guard_bit || round_bit || sticky_bit) fflags[`FF_NX] = 1'b1;
            case (rs2_val)
                5'd0: begin
                    if (overflow || $signed(final_value) > $signed(64'd2147483647) || $signed(final_value) < $signed(-64'd2147483648)) begin
                        fflags[`FF_NV] = 1'b1;
                        fflags[`FF_NX] = 1'b0;
                        result = sign ? 64'hFFFFFFFF_80000000 : 64'hFFFFFFFF_7FFFFFFF;
                    end else begin
                        result = {{32{final_value[31]}}, final_value[31:0]};
                    end
                end
                5'd1: begin
                    if (overflow || final_value[63:32] != 32'd0 || (sign && rounded != 64'd0)) begin
                        fflags[`FF_NV] = 1'b1;
                        fflags[`FF_NX] = 1'b0;
                        result = 64'hFFFFFFFF_FFFFFFFF;
                    end else begin
                        result = {{32{final_value[31]}}, final_value[31:0]};
                    end
                end
                5'd2: begin
                    if (overflow || (sign && !final_value[63] && final_value != 64'd0) || (!sign && final_value[63])) begin
                        fflags[`FF_NV] = 1'b1;
                        fflags[`FF_NX] = 1'b0;
                        result = sign ? 64'h8000000000000000 : 64'h7FFFFFFFFFFFFFFF;
                    end else begin
                        result = final_value;
                    end
                end
                5'd3: begin
                    if (overflow || (sign && rounded != 64'd0)) begin
                        fflags[`FF_NV] = 1'b1;
                        fflags[`FF_NX] = 1'b0;
                        result = 64'hFFFFFFFFFFFFFFFF;
                    end else begin
                        result = final_value;
                    end
                end
                default: result = 64'd0;
            endcase
        end
    end

endmodule
