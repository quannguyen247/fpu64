`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_addsub (
    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire is_sub,
    input wire [2:0] rm,

    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire sp_s2 = rs2[31] ^ is_sub;
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

    reg [24:0] sp_m1;
    reg [24:0] sp_m2;
    reg [8:0] sp_exp1;
    reg [8:0] sp_exp2;
    reg [24:0] sp_m_align;
    reg [8:0] sp_exp_diff;
    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg [27:0] sp_op1;
    reg [27:0] sp_op2;
    reg [28:0] sp_sum;
    reg [28:0] sp_sum_norm;
    reg [5:0] sp_shift;

    reg sp_g;
    reg sp_r;
    reg sp_s;
    reg sp_round_up;

    reg sp_res_sign;
    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire dp_s2 = rs2[63] ^ is_sub;
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

    reg [53:0] dp_m1;
    reg [53:0] dp_m2;
    reg [11:0] dp_exp1;
    reg [11:0] dp_exp2;
    reg [53:0] dp_m_align;
    reg [11:0] dp_exp_diff;
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg [56:0] dp_op1;
    reg [56:0] dp_op2;
    reg [57:0] dp_sum;
    reg [57:0] dp_sum_norm;
    reg [6:0] dp_shift;

    reg dp_g;
    reg dp_r;
    reg dp_s;
    reg dp_round_up;

    reg dp_res_sign;
    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;

    integer i;

    always @(*) begin
        sp_m1 = {1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
        sp_m2 = {1'b0, (sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};
        sp_exp1 = (sp_e1 == 8'd0) ? 9'd1 : {1'b0, sp_e1};
        sp_exp2 = (sp_e2 == 8'd0) ? 9'd1 : {1'b0, sp_e2};
        sp_res = 64'd0;
        sp_flags = 5'd0;
        sp_sum = 29'd0;
        sp_res_exp = 8'd0;
        sp_res_frac = 23'd0;
        sp_res_sign = 1'b0;

        if (sp_nan1 || sp_nan2) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            if (sp_snan1 || sp_snan2) sp_flags[`FF_NV] = 1'b1;
        end else if (sp_inf1 && sp_inf2 && (sp_s1 != sp_s2)) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            sp_flags[`FF_NV] = 1'b1;
        end else if (sp_inf1) begin
            sp_res = {32'hFFFFFFFF, sp_s1, 8'hFF, 23'd0};
        end else if (sp_inf2) begin
            sp_res = {32'hFFFFFFFF, sp_s2, 8'hFF, 23'd0};
        end else if (sp_zero1 && sp_zero2) begin
            sp_res_sign = (sp_s1 == sp_s2) ? sp_s1 : (rm == `RM_RDN);
            sp_res = {32'hFFFFFFFF, sp_res_sign, 8'd0, 23'd0};
        end else begin
            if (sp_exp1 > sp_exp2 || (sp_exp1 == sp_exp2 && sp_m1 >= sp_m2)) begin
                sp_exp_diff = sp_exp1 - sp_exp2;
                sp_res_exp = sp_exp1[7:0];
                sp_res_sign = sp_s1;
                sp_sticky = 1'b0;
                if (sp_exp_diff > 9'd25) begin
                    sp_m_align = 25'd0;
                    sp_sticky = (sp_m2 != 25'd0);
                    sp_guard = 1'b0;
                    sp_round = 1'b0;
                end else begin
                    sp_m_align = sp_m2 >> sp_exp_diff;
                    sp_guard = (sp_exp_diff >= 9'd1) ? sp_m2[sp_exp_diff - 1] : 1'b0;
                    sp_round = (sp_exp_diff >= 9'd2) ? sp_m2[sp_exp_diff - 2] : 1'b0;
                    if (sp_exp_diff >= 9'd3) begin
                        for (i = 0; i < 25; i = i + 1) begin
                            if (i < sp_exp_diff - 2 && sp_m2[i]) sp_sticky = 1'b1;
                        end
                    end
                end
                sp_op1 = {sp_m1, 3'b000};
                sp_op2 = {sp_m_align, sp_guard, sp_round, sp_sticky};
                if (sp_s1 == sp_s2) begin
                    sp_sum = sp_op1 + sp_op2;
                end else begin
                    sp_sum = sp_op1 - sp_op2;
                end
            end else begin
                sp_exp_diff = sp_exp2 - sp_exp1;
                sp_res_exp = sp_exp2[7:0];
                sp_res_sign = sp_s2;
                sp_sticky = 1'b0;
                if (sp_exp_diff > 9'd25) begin
                    sp_m_align = 25'd0;
                    sp_sticky = (sp_m1 != 25'd0);
                    sp_guard = 1'b0;
                    sp_round = 1'b0;
                end else begin
                    sp_m_align = sp_m1 >> sp_exp_diff;
                    sp_guard = (sp_exp_diff >= 9'd1) ? sp_m1[sp_exp_diff - 1] : 1'b0;
                    sp_round = (sp_exp_diff >= 9'd2) ? sp_m1[sp_exp_diff - 2] : 1'b0;
                    if (sp_exp_diff >= 9'd3) begin
                        for (i = 0; i < 25; i = i + 1) begin
                            if (i < sp_exp_diff - 2 && sp_m1[i]) sp_sticky = 1'b1;
                        end
                    end
                end
                sp_op1 = {sp_m2, 3'b000};
                sp_op2 = {sp_m_align, sp_guard, sp_round, sp_sticky};
                if (sp_s1 == sp_s2) begin
                    sp_sum = sp_op1 + sp_op2;
                end else begin
                    sp_sum = sp_op1 - sp_op2;
                end
            end
            if (sp_sum[28:1] == 28'd0) begin
                sp_res = {32'hFFFFFFFF, (rm == `RM_RDN), 8'd0, 23'd0};
            end else begin
                if (sp_sum[27]) begin
                    sp_sum_norm = sp_sum >> 1;
                    sp_sum_norm[0] = sp_sum_norm[0] | sp_sum[0];
                    if (sp_res_exp == 8'hFE) begin
                        sp_res_exp = 8'hFF;
                    end else begin
                        sp_res_exp = sp_res_exp + 8'd1;
                    end
                end else begin
                    sp_shift = 6'd0;
                    for (i = 0; i < 26; i = i + 1) begin
                        if (sp_sum[26 - i] == 1'b1 && sp_shift == 6'd0) begin
                            sp_shift = i;
                        end
                    end
                    if (sp_shift >= sp_res_exp) begin
                        sp_shift = sp_res_exp - 8'd1;
                    end
                    sp_sum_norm = sp_sum << sp_shift;
                    sp_res_exp = sp_res_exp - sp_shift;
                end
                sp_g = sp_sum_norm[2];
                sp_r = sp_sum_norm[1];
                sp_s = sp_sum_norm[0];
                sp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: sp_round_up = sp_g && (sp_r || sp_s || sp_sum_norm[3]);
                    `RM_RTZ: sp_round_up = 1'b0;
                    `RM_RDN: sp_round_up = sp_res_sign && (sp_g || sp_r || sp_s);
                    `RM_RUP: sp_round_up = !sp_res_sign && (sp_g || sp_r || sp_s);
                    `RM_RMM: sp_round_up = sp_g;
                    default: sp_round_up = 1'b0;
                endcase
                if (sp_round_up) begin
                    sp_sum_norm[26:3] = sp_sum_norm[26:3] + 24'd1;
                    if (sp_sum_norm[27]) begin
                        sp_sum_norm[26:3] = sp_sum_norm[26:3] >> 1;
                        if (sp_res_exp == 8'hFE) begin
                            sp_res_exp = 8'hFF;
                        end else begin
                            sp_res_exp = sp_res_exp + 8'd1;
                        end
                    end
                end
                if (sp_res_exp == 8'hFF) begin
                    sp_res = {32'hFFFFFFFF, sp_res_sign, 8'hFF, 23'd0};
                    sp_flags[`FF_OF] = 1'b1;
                    sp_flags[`FF_NX] = 1'b1;
                end else begin
                    sp_res_frac = sp_sum_norm[25:3];
                    sp_res = {32'hFFFFFFFF, sp_res_sign, sp_res_exp, sp_res_frac};
                    if (sp_g || sp_r || sp_s) sp_flags[`FF_NX] = 1'b1;
                end
            end
        end
    end

    always @(*) begin
        dp_m1 = {1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
        dp_m2 = {1'b0, (dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};
        dp_exp1 = (dp_e1 == 11'd0) ? 12'd1 : {1'b0, dp_e1};
        dp_exp2 = (dp_e2 == 11'd0) ? 12'd1 : {1'b0, dp_e2};
        dp_res = 64'd0;
        dp_flags = 5'd0;
        dp_sum = 58'd0;
        dp_res_exp = 11'd0;
        dp_res_frac = 52'd0;
        dp_res_sign = 1'b0;

        if (dp_nan1 || dp_nan2) begin
            dp_res = 64'h7FF8000000000000;
            if (dp_snan1 || dp_snan2) dp_flags[`FF_NV] = 1'b1;
        end else if (dp_inf1 && dp_inf2 && (dp_s1 != dp_s2)) begin
            dp_res = 64'h7FF8000000000000;
            dp_flags[`FF_NV] = 1'b1;
        end else if (dp_inf1) begin
            dp_res = {dp_s1, 11'h7FF, 52'd0};
        end else if (dp_inf2) begin
            dp_res = {dp_s2, 11'h7FF, 52'd0};
        end else if (dp_zero1 && dp_zero2) begin
            dp_res_sign = (dp_s1 == dp_s2) ? dp_s1 : (rm == `RM_RDN);
            dp_res = {dp_res_sign, 11'd0, 52'd0};
        end else begin
            if (dp_exp1 > dp_exp2 || (dp_exp1 == dp_exp2 && dp_m1 >= dp_m2)) begin
                dp_exp_diff = dp_exp1 - dp_exp2;
                dp_res_exp = dp_exp1[10:0];
                dp_res_sign = dp_s1;
                dp_sticky = 1'b0;
                if (dp_exp_diff > 12'd54) begin
                    dp_m_align = 54'd0;
                    dp_sticky = (dp_m2 != 54'd0);
                    dp_guard = 1'b0;
                    dp_round = 1'b0;
                end else begin
                    dp_m_align = dp_m2 >> dp_exp_diff;
                    dp_guard = (dp_exp_diff >= 12'd1) ? dp_m2[dp_exp_diff - 1] : 1'b0;
                    dp_round = (dp_exp_diff >= 12'd2) ? dp_m2[dp_exp_diff - 2] : 1'b0;
                    if (dp_exp_diff >= 12'd3) begin
                        for (i = 0; i < 54; i = i + 1) begin
                            if (i < dp_exp_diff - 2 && dp_m2[i]) dp_sticky = 1'b1;
                        end
                    end
                end
                dp_op1 = {dp_m1, 3'b000};
                dp_op2 = {dp_m_align, dp_guard, dp_round, dp_sticky};
                if (dp_s1 == dp_s2) begin
                    dp_sum = dp_op1 + dp_op2;
                end else begin
                    dp_sum = dp_op1 - dp_op2;
                end
            end else begin
                dp_exp_diff = dp_exp2 - dp_exp1;
                dp_res_exp = dp_exp2[10:0];
                dp_res_sign = dp_s2;
                dp_sticky = 1'b0;
                if (dp_exp_diff > 12'd54) begin
                    dp_m_align = 54'd0;
                    dp_sticky = (dp_m1 != 54'd0);
                    dp_guard = 1'b0;
                    dp_round = 1'b0;
                end else begin
                    dp_m_align = dp_m1 >> dp_exp_diff;
                    dp_guard = (dp_exp_diff >= 12'd1) ? dp_m1[dp_exp_diff - 1] : 1'b0;
                    dp_round = (dp_exp_diff >= 12'd2) ? dp_m1[dp_exp_diff - 2] : 1'b0;
                    if (dp_exp_diff >= 12'd3) begin
                        for (i = 0; i < 54; i = i + 1) begin
                            if (i < dp_exp_diff - 2 && dp_m1[i]) dp_sticky = 1'b1;
                        end
                    end
                end
                dp_op1 = {dp_m2, 3'b000};
                dp_op2 = {dp_m_align, dp_guard, dp_round, dp_sticky};
                if (dp_s1 == dp_s2) begin
                    dp_sum = dp_op1 + dp_op2;
                end else begin
                    dp_sum = dp_op1 - dp_op2;
                end
            end
            if (dp_sum[57:1] == 57'd0) begin
                dp_res = {(rm == `RM_RDN), 11'd0, 52'd0};
            end else begin
                if (dp_sum[56]) begin
                    dp_sum_norm = dp_sum >> 1;
                    dp_sum_norm[0] = dp_sum_norm[0] | dp_sum[0];
                    if (dp_res_exp == 11'h7FE) begin
                        dp_res_exp = 11'h7FF;
                    end else begin
                        dp_res_exp = dp_res_exp + 11'd1;
                    end
                end else begin
                    dp_shift = 7'd0;
                    for (i = 0; i < 55; i = i + 1) begin
                        if (dp_sum[55 - i] == 1'b1 && dp_shift == 7'd0) begin
                            dp_shift = i;
                        end
                    end
                    if (dp_shift >= dp_res_exp) begin
                        dp_shift = dp_res_exp - 11'd1;
                    end
                    dp_sum_norm = dp_sum << dp_shift;
                    dp_res_exp = dp_res_exp - dp_shift;
                end
                dp_g = dp_sum_norm[2];
                dp_r = dp_sum_norm[1];
                dp_s = dp_sum_norm[0];
                dp_round_up = 1'b0;
                case (rm)
                    `RM_RNE: dp_round_up = dp_g && (dp_r || dp_s || dp_sum_norm[3]);
                    `RM_RTZ: dp_round_up = 1'b0;
                    `RM_RDN: dp_round_up = dp_res_sign && (dp_g || dp_r || dp_s);
                    `RM_RUP: dp_round_up = !dp_res_sign && (dp_g || dp_r || dp_s);
                    `RM_RMM: dp_round_up = dp_g;
                    default: dp_round_up = 1'b0;
                endcase
                if (dp_round_up) begin
                    dp_sum_norm[55:3] = dp_sum_norm[55:3] + 53'd1;
                    if (dp_sum_norm[56]) begin
                        dp_sum_norm[55:3] = dp_sum_norm[55:3] >> 1;
                        if (dp_res_exp == 11'h7FE) begin
                            dp_res_exp = 11'h7FF;
                        end else begin
                            dp_res_exp = dp_res_exp + 11'd1;
                        end
                    end
                end
                if (dp_res_exp == 11'h7FF) begin
                    dp_res = {dp_res_sign, 11'h7FF, 52'd0};
                    dp_flags[`FF_OF] = 1'b1;
                    dp_flags[`FF_NX] = 1'b1;
                end else begin
                    dp_res_frac = dp_sum_norm[54:3];
                    dp_res = {dp_res_sign, dp_res_exp, dp_res_frac};
                    if (dp_g || dp_r || dp_s) dp_flags[`FF_NX] = 1'b1;
                end
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
