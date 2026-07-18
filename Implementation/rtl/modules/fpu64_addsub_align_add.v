`timescale 1ns / 1ps

module fpu64_addsub_align_add (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire ex1_is_double,
    input wire [2:0] ex1_rm,

    input wire ex1_sp_special,
    input wire [63:0] ex1_sp_special_res,
    input wire [4:0] ex1_sp_special_flags,
    input wire ex1_sp_eff_sub,
    input wire ex1_sp_res_sign,
    input wire [7:0] ex1_sp_res_exp,
    input wire [8:0] ex1_sp_exp_diff,
    input wire [24:0] ex1_sp_op1,
    input wire [24:0] ex1_sp_op2,

    input wire ex1_dp_special,
    input wire [63:0] ex1_dp_special_res,
    input wire [4:0] ex1_dp_special_flags,
    input wire ex1_dp_eff_sub,
    input wire ex1_dp_res_sign,
    input wire [10:0] ex1_dp_res_exp,
    input wire [11:0] ex1_dp_exp_diff,
    input wire [53:0] ex1_dp_op1,
    input wire [53:0] ex1_dp_op2,

    output reg valid_out,
    input wire ready_out,

    output reg ex2_is_double,
    output reg [2:0] ex2_rm,

    output reg ex2_sp_special,
    output reg [63:0] ex2_sp_special_res,
    output reg [4:0] ex2_sp_special_flags,
    output reg ex2_sp_res_sign,
    output reg [7:0] ex2_sp_res_exp,
    output reg [28:0] ex2_sp_sum,

    output reg ex2_dp_special,
    output reg [63:0] ex2_dp_special_res,
    output reg [4:0] ex2_dp_special_flags,
    output reg ex2_dp_res_sign,
    output reg [10:0] ex2_dp_res_exp,
    output reg [57:0] ex2_dp_sum
);

    wire stall = valid_out && !ready_out;
    assign ready_in = !stall;

    wire [24:0] sp_m_align;
    wire sp_guard;
    wire sp_round;
    wire sp_sticky;
    wire [27:0] sp_op1_align;
    wire [27:0] sp_op2_align;

    wire [53:0] dp_m_align;
    wire dp_guard;
    wire dp_round;
    wire dp_sticky;
    wire [56:0] dp_op1_align;
    wire [56:0] dp_op2_align;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            ex2_is_double <= 1'b0;
            ex2_rm <= 3'd0;

            ex2_sp_special <= 1'b0;
            ex2_sp_special_res <= 64'd0;
            ex2_sp_special_flags <= 5'd0;
            ex2_sp_res_sign <= 1'b0;
            ex2_sp_res_exp <= 8'd0;
            ex2_sp_sum <= 29'd0;

            ex2_dp_special <= 1'b0;
            ex2_dp_special_res <= 64'd0;
            ex2_dp_special_flags <= 5'd0;
            ex2_dp_res_sign <= 1'b0;
            ex2_dp_res_exp <= 11'd0;
            ex2_dp_sum <= 58'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                ex2_is_double <= ex1_is_double;
                ex2_rm <= ex1_rm;

                ex2_sp_special <= ex1_sp_special;
                ex2_sp_special_res <= ex1_sp_special_res;
                ex2_sp_special_flags <= ex1_sp_special_flags;
                ex2_sp_res_sign <= ex1_sp_res_sign;
                ex2_sp_res_exp <= ex1_sp_res_exp;

                if (ex1_sp_eff_sub) begin
                    ex2_sp_sum <= sp_op1_align - sp_op2_align;
                end else begin
                    ex2_sp_sum <= sp_op1_align + sp_op2_align;
                end

                ex2_dp_special <= ex1_dp_special;
                ex2_dp_special_res <= ex1_dp_special_res;
                ex2_dp_special_flags <= ex1_dp_special_flags;
                ex2_dp_res_sign <= ex1_dp_res_sign;
                ex2_dp_res_exp <= ex1_dp_res_exp;

                if (ex1_dp_eff_sub) begin
                    ex2_dp_sum <= dp_op1_align - dp_op2_align;
                end else begin
                    ex2_dp_sum <= dp_op1_align + dp_op2_align;
                end
            end
        end
    end

    assign sp_m_align = (ex1_sp_exp_diff > 9'd25) ? 25'd0 : (ex1_sp_op2 >> ex1_sp_exp_diff);
    assign sp_guard = (ex1_sp_exp_diff > 9'd25) ? 1'b0 : ((ex1_sp_exp_diff >= 9'd1) ? ex1_sp_op2[ex1_sp_exp_diff - 1] : 1'b0);
    assign sp_round = (ex1_sp_exp_diff > 9'd25) ? 1'b0 : ((ex1_sp_exp_diff >= 9'd2) ? ex1_sp_op2[ex1_sp_exp_diff - 2] : 1'b0);
    wire sp_sticky_part = (ex1_sp_exp_diff > 9'd25) ? (ex1_sp_op2 != 25'd0) : 1'b0;
    wire [24:0] sp_mask = (25'd1 << (ex1_sp_exp_diff >= 9'd2 ? ex1_sp_exp_diff - 9'd2 : 9'd0)) - 25'd1;
    assign sp_sticky = sp_sticky_part | ((ex1_sp_op2 & sp_mask) != 25'd0);
    assign sp_op1_align = {ex1_sp_op1, 3'b000};
    assign sp_op2_align = {sp_m_align, sp_guard, sp_round, sp_sticky};

    assign dp_m_align = (ex1_dp_exp_diff > 12'd54) ? 54'd0 : (ex1_dp_op2 >> ex1_dp_exp_diff);
    assign dp_guard = (ex1_dp_exp_diff > 12'd54) ? 1'b0 : ((ex1_dp_exp_diff >= 12'd1) ? ex1_dp_op2[ex1_dp_exp_diff - 1] : 1'b0);
    assign dp_round = (ex1_dp_exp_diff > 12'd54) ? 1'b0 : ((ex1_dp_exp_diff >= 12'd2) ? ex1_dp_op2[ex1_dp_exp_diff - 2] : 1'b0);
    wire dp_sticky_part = (ex1_dp_exp_diff > 12'd54) ? (ex1_dp_op2 != 54'd0) : 1'b0;
    wire [53:0] dp_mask = (54'd1 << (ex1_dp_exp_diff >= 12'd2 ? ex1_dp_exp_diff - 12'd2 : 12'd0)) - 54'd1;
    assign dp_sticky = dp_sticky_part | ((ex1_dp_op2 & dp_mask) != 54'd0);
    assign dp_op1_align = {ex1_dp_op1, 3'b000};
    assign dp_op2_align = {dp_m_align, dp_guard, dp_round, dp_sticky};

endmodule
