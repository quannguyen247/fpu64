`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_fma_prepare (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire [63:0] rs3,
    input wire [3:0] op,
    input wire is_double,
    input wire [2:0] rm,
    output reg valid_out,
    input wire ready_out,
    output reg is_double_out,
    output reg [2:0] rm_out,
    output reg special_out,
    output reg [63:0] special_result_out,
    output reg [4:0] special_flags_out,
    output reg product_sign_out,
    output reg addend_sign_out,
    output reg product_zero_out,
    output reg addend_zero_out,
    output reg signed [13:0] exp1_out,
    output reg signed [13:0] exp2_out,
    output reg signed [13:0] exp3_out,
    output reg [52:0] sig1_out,
    output reg [52:0] sig2_out,
    output reg [52:0] sig3_out
);

    wire stall = valid_out && !ready_out;
    wire sp_box1 = (rs1[63:32] == 32'hFFFFFFFF);
    wire sp_box2 = (rs2[63:32] == 32'hFFFFFFFF);
    wire sp_box3 = (rs3[63:32] == 32'hFFFFFFFF);
    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire sp_s2 = rs2[31];
    wire [7:0] sp_e2 = rs2[30:23];
    wire [22:0] sp_f2 = rs2[22:0];
    wire sp_s3 = rs3[31];
    wire [7:0] sp_e3 = rs3[30:23];
    wire [22:0] sp_f3 = rs3[22:0];
    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire dp_s2 = rs2[63];
    wire [10:0] dp_e2 = rs2[62:52];
    wire [51:0] dp_f2 = rs2[51:0];
    wire dp_s3 = rs3[63];
    wire [10:0] dp_e3 = rs3[62:52];
    wire [51:0] dp_f3 = rs3[51:0];
    wire sp_nan1 = !sp_box1 || ((sp_e1 == 8'hFF) && (sp_f1 != 23'd0));
    wire sp_nan2 = !sp_box2 || ((sp_e2 == 8'hFF) && (sp_f2 != 23'd0));
    wire sp_nan3 = !sp_box3 || ((sp_e3 == 8'hFF) && (sp_f3 != 23'd0));
    wire sp_snan1 = sp_box1 && (sp_e1 == 8'hFF) && (sp_f1 != 23'd0) && !sp_f1[22];
    wire sp_snan2 = sp_box2 && (sp_e2 == 8'hFF) && (sp_f2 != 23'd0) && !sp_f2[22];
    wire sp_snan3 = sp_box3 && (sp_e3 == 8'hFF) && (sp_f3 != 23'd0) && !sp_f3[22];
    wire sp_inf1 = sp_box1 && (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_inf2 = sp_box2 && (sp_e2 == 8'hFF) && (sp_f2 == 23'd0);
    wire sp_inf3 = sp_box3 && (sp_e3 == 8'hFF) && (sp_f3 == 23'd0);
    wire sp_zero1 = sp_box1 && (sp_e1 == 8'd0) && (sp_f1 == 23'd0);
    wire sp_zero2 = sp_box2 && (sp_e2 == 8'd0) && (sp_f2 == 23'd0);
    wire sp_zero3 = sp_box3 && (sp_e3 == 8'd0) && (sp_f3 == 23'd0);
    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_nan2 = (dp_e2 == 11'h7FF) && (dp_f2 != 52'd0);
    wire dp_nan3 = (dp_e3 == 11'h7FF) && (dp_f3 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_snan2 = dp_nan2 && !dp_f2[51];
    wire dp_snan3 = dp_nan3 && !dp_f3[51];
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_inf2 = (dp_e2 == 11'h7FF) && (dp_f2 == 52'd0);
    wire dp_inf3 = (dp_e3 == 11'h7FF) && (dp_f3 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);
    wire dp_zero2 = (dp_e2 == 11'd0) && (dp_f2 == 52'd0);
    wire dp_zero3 = (dp_e3 == 11'd0) && (dp_f3 == 52'd0);
    wire negate_product = (op == `F_NMSUB) || (op == `F_NMADD);
    wire negate_addend = (op == `F_MSUB) || (op == `F_NMADD);
    wire product_sign = is_double ? (dp_s1 ^ dp_s2 ^ negate_product) : (sp_s1 ^ sp_s2 ^ negate_product);
    wire addend_sign = is_double ? (dp_s3 ^ negate_addend) : (sp_s3 ^ negate_addend);
    wire any_nan = is_double ? (dp_nan1 || dp_nan2 || dp_nan3) : (sp_nan1 || sp_nan2 || sp_nan3);
    wire any_snan = is_double ? (dp_snan1 || dp_snan2 || dp_snan3) : (sp_snan1 || sp_snan2 || sp_snan3);
    wire multiply_invalid = is_double ? ((dp_zero1 && dp_inf2) || (dp_inf1 && dp_zero2)) : ((sp_zero1 && sp_inf2) || (sp_inf1 && sp_zero2));
    wire product_inf = is_double ? (dp_inf1 || dp_inf2) : (sp_inf1 || sp_inf2);
    wire addend_inf = is_double ? dp_inf3 : sp_inf3;
    wire product_zero = is_double ? (dp_zero1 || dp_zero2) : (sp_zero1 || sp_zero2);
    wire addend_zero = is_double ? dp_zero3 : sp_zero3;
    reg [52:0] sig1;
    reg [52:0] sig2;
    reg [52:0] sig3;
    reg signed [13:0] exp1;
    reg signed [13:0] exp2;
    reg signed [13:0] exp3;
    reg [23:0] sp_sig1;
    reg [23:0] sp_sig2;
    reg [23:0] sp_sig3;
    reg [52:0] dp_sig1;
    reg [52:0] dp_sig2;
    reg [52:0] dp_sig3;
    reg [4:0] sp_shift1;
    reg [4:0] sp_shift2;
    reg [4:0] sp_shift3;
    reg [5:0] dp_shift1;
    reg [5:0] dp_shift2;
    reg [5:0] dp_shift3;
    reg special;
    reg [63:0] special_result;
    reg [4:0] special_flags;
    integer norm_i1;
    integer norm_i2;
    integer norm_i3;

    assign ready_in = !stall;

    always @(*) begin
        sp_sig1 = {(sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
        sp_sig2 = {(sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};
        sp_sig3 = {(sp_e3 == 8'd0) ? 1'b0 : 1'b1, sp_f3};
        dp_sig1 = {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
        dp_sig2 = {(dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};
        dp_sig3 = {(dp_e3 == 11'd0) ? 1'b0 : 1'b1, dp_f3};
        sp_shift1 = 5'd0;
        sp_shift2 = 5'd0;
        sp_shift3 = 5'd0;
        dp_shift1 = 6'd0;
        dp_shift2 = 6'd0;
        dp_shift3 = 6'd0;
        if (sp_e1 == 8'd0 && sp_f1 != 23'd0) begin
            for (norm_i1 = 0; norm_i1 < 24; norm_i1 = norm_i1 + 1) begin
                if (!sp_sig1[23 - norm_i1] && sp_shift1 == norm_i1) sp_shift1 = sp_shift1 + 5'd1;
            end
            sp_sig1 = sp_sig1 << sp_shift1;
        end
        if (sp_e2 == 8'd0 && sp_f2 != 23'd0) begin
            for (norm_i2 = 0; norm_i2 < 24; norm_i2 = norm_i2 + 1) begin
                if (!sp_sig2[23 - norm_i2] && sp_shift2 == norm_i2) sp_shift2 = sp_shift2 + 5'd1;
            end
            sp_sig2 = sp_sig2 << sp_shift2;
        end
        if (sp_e3 == 8'd0 && sp_f3 != 23'd0) begin
            for (norm_i3 = 0; norm_i3 < 24; norm_i3 = norm_i3 + 1) begin
                if (!sp_sig3[23 - norm_i3] && sp_shift3 == norm_i3) sp_shift3 = sp_shift3 + 5'd1;
            end
            sp_sig3 = sp_sig3 << sp_shift3;
        end
        if (dp_e1 == 11'd0 && dp_f1 != 52'd0) begin
            for (norm_i1 = 0; norm_i1 < 53; norm_i1 = norm_i1 + 1) begin
                if (!dp_sig1[52 - norm_i1] && dp_shift1 == norm_i1) dp_shift1 = dp_shift1 + 6'd1;
            end
            dp_sig1 = dp_sig1 << dp_shift1;
        end
        if (dp_e2 == 11'd0 && dp_f2 != 52'd0) begin
            for (norm_i2 = 0; norm_i2 < 53; norm_i2 = norm_i2 + 1) begin
                if (!dp_sig2[52 - norm_i2] && dp_shift2 == norm_i2) dp_shift2 = dp_shift2 + 6'd1;
            end
            dp_sig2 = dp_sig2 << dp_shift2;
        end
        if (dp_e3 == 11'd0 && dp_f3 != 52'd0) begin
            for (norm_i3 = 0; norm_i3 < 53; norm_i3 = norm_i3 + 1) begin
                if (!dp_sig3[52 - norm_i3] && dp_shift3 == norm_i3) dp_shift3 = dp_shift3 + 6'd1;
            end
            dp_sig3 = dp_sig3 << dp_shift3;
        end
        if (is_double) begin
            sig1 = dp_sig1;
            sig2 = dp_sig2;
            sig3 = dp_sig3;
            exp1 = (dp_e1 == 11'd0) ? (-14'sd1022 - $signed({8'd0, dp_shift1})) : ($signed({3'd0, dp_e1}) - 14'sd1023);
            exp2 = (dp_e2 == 11'd0) ? (-14'sd1022 - $signed({8'd0, dp_shift2})) : ($signed({3'd0, dp_e2}) - 14'sd1023);
            exp3 = (dp_e3 == 11'd0) ? (-14'sd1022 - $signed({8'd0, dp_shift3})) : ($signed({3'd0, dp_e3}) - 14'sd1023);
        end else begin
            sig1 = {29'd0, sp_sig1};
            sig2 = {29'd0, sp_sig2};
            sig3 = {29'd0, sp_sig3};
            exp1 = (sp_e1 == 8'd0) ? (-14'sd126 - $signed({9'd0, sp_shift1})) : ($signed({6'd0, sp_e1}) - 14'sd127);
            exp2 = (sp_e2 == 8'd0) ? (-14'sd126 - $signed({9'd0, sp_shift2})) : ($signed({6'd0, sp_e2}) - 14'sd127);
            exp3 = (sp_e3 == 8'd0) ? (-14'sd126 - $signed({9'd0, sp_shift3})) : ($signed({6'd0, sp_e3}) - 14'sd127);
        end
    end

    always @(*) begin
        special = 1'b0;
        special_result = 64'd0;
        special_flags = 5'd0;
        if (any_nan || multiply_invalid) begin
            special = 1'b1;
            special_result = is_double ? 64'h7FF8000000000000 : 64'hFFFFFFFF_7FC00000;
            if (any_snan || multiply_invalid) special_flags[`FF_NV] = 1'b1;
        end else if (product_inf && addend_inf && (product_sign != addend_sign)) begin
            special = 1'b1;
            special_result = is_double ? 64'h7FF8000000000000 : 64'hFFFFFFFF_7FC00000;
            special_flags[`FF_NV] = 1'b1;
        end else if (product_inf) begin
            special = 1'b1;
            special_result = is_double ? {product_sign, 11'h7FF, 52'd0} : {32'hFFFFFFFF, product_sign, 8'hFF, 23'd0};
        end else if (addend_inf) begin
            special = 1'b1;
            special_result = is_double ? {addend_sign, 11'h7FF, 52'd0} : {32'hFFFFFFFF, addend_sign, 8'hFF, 23'd0};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            is_double_out <= 1'b0;
            rm_out <= 3'd0;
            special_out <= 1'b0;
            special_result_out <= 64'd0;
            special_flags_out <= 5'd0;
            product_sign_out <= 1'b0;
            addend_sign_out <= 1'b0;
            product_zero_out <= 1'b0;
            addend_zero_out <= 1'b0;
            exp1_out <= 14'sd0;
            exp2_out <= 14'sd0;
            exp3_out <= 14'sd0;
            sig1_out <= 53'd0;
            sig2_out <= 53'd0;
            sig3_out <= 53'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                is_double_out <= is_double;
                rm_out <= rm;
                special_out <= special;
                special_result_out <= special_result;
                special_flags_out <= special_flags;
                product_sign_out <= product_sign;
                addend_sign_out <= addend_sign;
                product_zero_out <= product_zero;
                addend_zero_out <= addend_zero;
                exp1_out <= exp1;
                exp2_out <= exp2;
                exp3_out <= exp3;
                sig1_out <= sig1;
                sig2_out <= sig2;
                sig3_out <= sig3;
            end
        end
    end

endmodule
