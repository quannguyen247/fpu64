`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_div (
    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire [2:0] rm,

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
    wire sp_inf1 = (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_inf2 = (sp_e2 == 8'hFF) && (sp_f2 == 23'd0);
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);
    wire sp_zero2 = (sp_e2 == 8'd0) && (sp_f2 == 23'd0);

    reg [63:0] sp_res;
    reg [4:0] sp_flags;

    reg [23:0] sp_m1;
    reg [23:0] sp_m2;
    reg [26:0] sp_quot;
    reg [24:0] sp_rem;
    reg [8:0] sp_exp;
    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg sp_round_up;

    reg sp_res_sign;
    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;

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
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_inf2 = (dp_e2 == 11'h7FF) && (dp_f2 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);
    wire dp_zero2 = (dp_e2 == 11'd0) && (dp_f2 == 52'd0);

    reg [63:0] dp_res;
    reg [4:0] dp_flags;

    reg [52:0] dp_m1;
    reg [52:0] dp_m2;
    reg [55:0] dp_quot;
    reg [53:0] dp_rem;
    reg [11:0] dp_exp;
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg dp_round_up;

    reg dp_res_sign;
    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;

    integer i;

    always @(*) begin
        sp_m1 = {(sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
        sp_m2 = {(sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};
        sp_exp = {1'b0, sp_e1} - {1'b0, sp_e2} + 9'd127;
        sp_res_sign = sp_s1 ^ sp_s2;
        sp_res = 64'd0;
        sp_flags = 5'd0;
        sp_res_exp = 8'd0;
        sp_res_frac = 23'd0;

        if (sp_nan1 || sp_nan2) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            if (sp_snan1 || sp_snan2) sp_flags[`FF_NV] = 1'b1;
        end else if (sp_zero1 && sp_zero2) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            sp_flags[`FF_NV] = 1'b1;
        end else if (sp_inf1 && sp_inf2) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            sp_flags[`FF_NV] = 1'b1;
        end else if (sp_inf1) begin
            sp_res = {32'hFFFFFFFF, sp_res_sign, 8'hFF, 23'd0};
        end else if (sp_inf2) begin
            sp_res = {32'hFFFFFFFF, sp_res_sign, 8'd0, 23'd0};
        end else if (sp_zero1) begin
            sp_res = {32'hFFFFFFFF, sp_res_sign, 8'd0, 23'd0};
        end else if (sp_zero2) begin
            sp_res = {32'hFFFFFFFF, sp_res_sign, 8'hFF, 23'd0};
            sp_flags[`FF_DZ] = 1'b1;
        end else begin
            sp_rem = {1'b0, sp_m1};
            sp_quot = 27'd0;
            for (i = 0; i < 27; i = i + 1) begin
                if (sp_rem >= {1'b0, sp_m2}) begin
                    sp_rem = sp_rem - {1'b0, sp_m2};
                    sp_quot[26-i] = 1'b1;
                end else begin
                    sp_quot[26-i] = 1'b0;
                end
                sp_rem = {sp_rem[23:0], 1'b0};
            end
            if (sp_quot[26] == 1'b0) begin
                sp_quot = sp_quot << 1;
                sp_exp = sp_exp - 9'd1;
            end
            if ($signed(sp_exp) >= $signed(9'd255)) begin
                sp_res = {32'hFFFFFFFF, sp_res_sign, 8'hFF, 23'd0};
                sp_flags[`FF_OF] = 1'b1;
                sp_flags[`FF_NX] = 1'b1;
            end else if ($signed(sp_exp) <= $signed(9'd0)) begin
                sp_res_exp = 8'd0;
                sp_quot = sp_quot >> (9'd1 - sp_exp);
                sp_guard = sp_quot[2];
                sp_round = sp_quot[1];
                sp_sticky = sp_quot[0] | (sp_rem != 25'd0);
                sp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || sp_quot[3]);
                    `RM_RTZ: sp_round_up = 1'b0;
                    `RM_RDN: sp_round_up = sp_res_sign && (sp_guard || sp_round || sp_sticky);
                    `RM_RUP: sp_round_up = !sp_res_sign && (sp_guard || sp_round || sp_sticky);
                    `RM_RMM: sp_round_up = sp_guard;
                    default: sp_round_up = 1'b0;
                endcase
                sp_res_frac = sp_quot[25:3] + (sp_round_up ? 23'd1 : 23'd0);
                sp_res = {32'hFFFFFFFF, sp_res_sign, sp_res_exp, sp_res_frac};
                if (sp_guard || sp_round || sp_sticky) begin
                    sp_flags[`FF_UF] = 1'b1;
                    sp_flags[`FF_NX] = 1'b1;
                end
            end else begin
                sp_res_exp = sp_exp[7:0];
                sp_guard = sp_quot[2];
                sp_round = sp_quot[1];
                sp_sticky = sp_quot[0] | (sp_rem != 25'd0);
                sp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || sp_quot[3]);
                    `RM_RTZ: sp_round_up = 1'b0;
                    `RM_RDN: sp_round_up = sp_res_sign && (sp_guard || sp_round || sp_sticky);
                    `RM_RUP: sp_round_up = !sp_res_sign && (sp_guard || sp_round || sp_sticky);
                    `RM_RMM: sp_round_up = sp_guard;
                    default: sp_round_up = 1'b0;
                endcase
                sp_res_frac = sp_quot[25:3] + (sp_round_up ? 23'd1 : 23'd0);
                if (sp_res_frac == 23'd0 && sp_round_up) begin
                    if (sp_res_exp == 8'hFE) begin
                        sp_res_exp = 8'hFF;
                        sp_flags[`FF_OF] = 1'b1;
                        sp_flags[`FF_NX] = 1'b1;
                    end else begin
                        sp_res_exp = sp_res_exp + 8'd1;
                    end
                end
                sp_res = {32'hFFFFFFFF, sp_res_sign, sp_res_exp, sp_res_frac};
                if (sp_guard || sp_round || sp_sticky) sp_flags[`FF_NX] = 1'b1;
            end
        end
    end

    always @(*) begin
        dp_m1 = {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
        dp_m2 = {(dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};
        dp_exp = {1'b0, dp_e1} - {1'b0, dp_e2} + 12'd1023;
        dp_res_sign = dp_s1 ^ dp_s2;
        dp_res = 64'd0;
        dp_flags = 5'd0;
        dp_res_exp = 11'd0;
        dp_res_frac = 52'd0;

        if (dp_nan1 || dp_nan2) begin
            dp_res = 64'h7FF8000000000000;
            if (dp_snan1 || dp_snan2) dp_flags[`FF_NV] = 1'b1;
        end else if (dp_zero1 && dp_zero2) begin
            dp_res = 64'h7FF8000000000000;
            dp_flags[`FF_NV] = 1'b1;
        end else if (dp_inf1 && dp_inf2) begin
            dp_res = 64'h7FF8000000000000;
            dp_flags[`FF_NV] = 1'b1;
        end else if (dp_inf1) begin
            dp_res = {dp_res_sign, 11'h7FF, 52'd0};
        end else if (dp_inf2) begin
            dp_res = {dp_res_sign, 11'd0, 52'd0};
        end else if (dp_zero1) begin
            dp_res = {dp_res_sign, 11'd0, 52'd0};
        end else if (dp_zero2) begin
            dp_res = {dp_res_sign, 11'h7FF, 52'd0};
            dp_flags[`FF_DZ] = 1'b1;
        end else begin
            dp_rem = {1'b0, dp_m1};
            dp_quot = 56'd0;
            for (i = 0; i < 56; i = i + 1) begin
                if (dp_rem >= {1'b0, dp_m2}) begin
                    dp_rem = dp_rem - {1'b0, dp_m2};
                    dp_quot[55-i] = 1'b1;
                end else begin
                    dp_quot[55-i] = 1'b0;
                end
                dp_rem = {dp_rem[52:0], 1'b0};
            end
            if (dp_quot[55] == 1'b0) begin
                dp_quot = dp_quot << 1;
                dp_exp = dp_exp - 12'd1;
            end
            if ($signed(dp_exp) >= $signed(12'd2047)) begin
                dp_res = {dp_res_sign, 11'h7FF, 52'd0};
                dp_flags[`FF_OF] = 1'b1;
                dp_flags[`FF_NX] = 1'b1;
            end else if ($signed(dp_exp) <= $signed(12'd0)) begin
                dp_res_exp = 11'd0;
                dp_quot = dp_quot >> (12'd1 - dp_exp);
                dp_guard = dp_quot[2];
                dp_round = dp_quot[1];
                dp_sticky = dp_quot[0] | (dp_rem != 54'd0);
                dp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || dp_quot[3]);
                    `RM_RTZ: dp_round_up = 1'b0;
                    `RM_RDN: dp_round_up = dp_res_sign && (dp_guard || dp_round || dp_sticky);
                    `RM_RUP: dp_round_up = !dp_res_sign && (dp_guard || dp_round || dp_sticky);
                    `RM_RMM: dp_round_up = dp_guard;
                    default: dp_round_up = 1'b0;
                endcase
                dp_res_frac = dp_quot[54:3] + (dp_round_up ? 52'd1 : 52'd0);
                dp_res = {dp_res_sign, dp_res_exp, dp_res_frac};
                if (dp_guard || dp_round || dp_sticky) begin
                    dp_flags[`FF_UF] = 1'b1;
                    dp_flags[`FF_NX] = 1'b1;
                end
            end else begin
                dp_res_exp = dp_exp[10:0];
                dp_guard = dp_quot[2];
                dp_round = dp_quot[1];
                dp_sticky = dp_quot[0] | (dp_rem != 54'd0);
                dp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || dp_quot[3]);
                    `RM_RTZ: dp_round_up = 1'b0;
                    `RM_RDN: dp_round_up = dp_res_sign && (dp_guard || dp_round || dp_sticky);
                    `RM_RUP: dp_round_up = !dp_res_sign && (dp_guard || dp_round || dp_sticky);
                    `RM_RMM: dp_round_up = dp_guard;
                    default: dp_round_up = 1'b0;
                endcase
                dp_res_frac = dp_quot[54:3] + (dp_round_up ? 52'd1 : 52'd0);
                if (dp_res_frac == 52'd0 && dp_round_up) begin
                    if (dp_res_exp == 11'h7FE) begin
                        dp_res_exp = 11'h7FF;
                        dp_flags[`FF_OF] = 1'b1;
                        dp_flags[`FF_NX] = 1'b1;
                    end else begin
                        dp_res_exp = dp_res_exp + 11'd1;
                    end
                end
                dp_res = {dp_res_sign, dp_res_exp, dp_res_frac};
                if (dp_guard || dp_round || dp_sticky) dp_flags[`FF_NX] = 1'b1;
            end
        end
    end

    always @(*) begin
        if (is_double) begin
            result = dp_res;
            fflags = dp_flags;
        end else begin
            result = sp_res;
            fflags = sp_flags;
        end
    end

endmodule
