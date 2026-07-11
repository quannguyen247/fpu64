`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_sqrt (
    input wire [63:0] rs1,

    input wire is_double,
    input wire [2:0] rm,

    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_inf1 = (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);

    reg [63:0] sp_res;
    reg [4:0] sp_flags;

    reg [23:0] sp_m1;
    reg [53:0] sp_x;
    reg [26:0] sp_root;
    reg [28:0] sp_rem;
    reg [28:0] sp_test;
    reg [8:0] sp_exp;
    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg sp_round_up;

    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);

    reg [63:0] dp_res;
    reg [4:0] dp_flags;

    reg [52:0] dp_m1;
    reg [111:0] dp_x;
    reg [56:0] dp_root;
    reg [57:0] dp_rem;
    reg [57:0] dp_test;
    reg [11:0] dp_exp;
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg dp_round_up;

    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;

    integer i;

    always @(*) begin
        sp_m1 = {(sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
        sp_exp = {1'b0, sp_e1} - 9'd127;
        sp_res = 64'd0;
        sp_flags = 5'd0;
        sp_res_exp = 8'd0;
        sp_res_frac = 23'd0;

        if (sp_nan1) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            if (sp_snan1) sp_flags[`FF_NV] = 1'b1;
        end else if (sp_zero1) begin
            sp_res = {32'hFFFFFFFF, sp_s1, 8'd0, 23'd0};
        end else if (sp_s1) begin
            sp_res = 64'hFFFFFFFF_7FC00000;
            sp_flags[`FF_NV] = 1'b1;
        end else if (sp_inf1) begin
            sp_res = {32'hFFFFFFFF, 1'b0, 8'hFF, 23'd0};
        end else begin
            if (sp_exp[0]) begin
                sp_x = {sp_m1, 30'd0};
                sp_exp = sp_exp - 9'd1;
            end else begin
                sp_x = {sp_m1, 29'd0} << 1;
            end
            sp_exp = $unsigned($signed(sp_exp) >>> 1) + 9'd127;
            sp_root = 27'd0;
            sp_rem = 29'd0;
            for (i = 0; i < 27; i = i + 1) begin
                sp_rem = {sp_rem[26:0], sp_x[53 - 2*i], sp_x[52 - 2*i]};
                sp_test = {sp_root, 2'b01};
                if (sp_rem >= sp_test) begin
                    sp_rem = sp_rem - sp_test;
                    sp_root = {sp_root[25:0], 1'b1};
                end else begin
                    sp_root = {sp_root[25:0], 1'b0};
                end
            end
            sp_res_exp = sp_exp[7:0];
            sp_guard = sp_root[2];
            sp_round = sp_root[1];
            sp_sticky = sp_root[0] | (sp_rem != 29'd0);
            sp_round_up = 1'b0;
            case (rm)
                `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || sp_root[3]);
                `RM_RTZ: sp_round_up = 1'b0;
                `RM_RDN: sp_round_up = 1'b0;
                `RM_RUP: sp_round_up = (sp_guard || sp_round || sp_sticky);
                `RM_RMM: sp_round_up = sp_guard;
                default: sp_round_up = 1'b0;
            endcase
            sp_res_frac = sp_root[25:3] + (sp_round_up ? 23'd1 : 23'd0);
            sp_res = {32'hFFFFFFFF, 1'b0, sp_res_exp, sp_res_frac};
            if (sp_guard || sp_round || sp_sticky) sp_flags[`FF_NX] = 1'b1;
        end
    end

    always @(*) begin
        dp_m1 = {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
        dp_exp = {1'b0, dp_e1} - 12'd1023;
        dp_res = 64'd0;
        dp_flags = 5'd0;
        dp_res_exp = 11'd0;
        dp_res_frac = 52'd0;

        if (dp_nan1) begin
            dp_res = 64'h7FF8000000000000;
            if (dp_snan1) dp_flags[`FF_NV] = 1'b1;
        end else if (dp_zero1) begin
            dp_res = {dp_s1, 11'd0, 52'd0};
        end else if (dp_s1) begin
            dp_res = 64'h7FF8000000000000;
            dp_flags[`FF_NV] = 1'b1;
        end else if (dp_inf1) begin
            dp_res = {1'b0, 11'h7FF, 52'd0};
        end else begin
            if (dp_exp[0]) begin
                dp_x = {dp_m1, 59'd0};
                dp_exp = dp_exp - 12'd1;
            end else begin
                dp_x = {dp_m1, 58'd0} << 1;
            end
            dp_exp = $unsigned($signed(dp_exp) >>> 1) + 12'd1023;
            dp_root = 56'd0;
            dp_rem = 58'd0;
            for (i = 0; i < 56; i = i + 1) begin
                dp_rem = {dp_rem[55:0], dp_x[111 - 2*i], dp_x[110 - 2*i]};
                dp_test = {dp_root, 2'b01};
                if (dp_rem >= dp_test) begin
                    dp_rem = dp_rem - dp_test;
                    dp_root = {dp_root[54:0], 1'b1};
                end else begin
                    dp_root = {dp_root[54:0], 1'b0};
                end
            end
            dp_res_exp = dp_exp[10:0];
            dp_guard = dp_root[2];
            dp_round = dp_root[1];
            dp_sticky = dp_root[0] | (dp_rem != 58'd0);
            dp_round_up = 1'b0;
            case (rm)
                `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || dp_root[3]);
                `RM_RTZ: dp_round_up = 1'b0;
                `RM_RDN: dp_round_up = 1'b0;
                `RM_RUP: dp_round_up = (dp_guard || dp_round || dp_sticky);
                `RM_RMM: dp_round_up = dp_guard;
                default: dp_round_up = 1'b0;
            endcase
            dp_res_frac = dp_root[54:3] + (dp_round_up ? 52'd1 : 52'd0);
            dp_res = {1'b0, dp_res_exp, dp_res_frac};
            if (dp_guard || dp_round || dp_sticky) dp_flags[`FF_NX] = 1'b1;
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
