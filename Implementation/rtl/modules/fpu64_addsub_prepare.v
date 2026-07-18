`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_addsub_prepare (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire is_sub,
    input wire [2:0] rm,

    output reg valid_out,
    input wire ready_out,

    output reg ex1_is_double,
    output reg [2:0] ex1_rm,

    output reg ex1_sp_special,
    output reg [63:0] ex1_sp_special_res,
    output reg [4:0] ex1_sp_special_flags,
    output reg ex1_sp_eff_sub,
    output reg ex1_sp_res_sign,
    output reg [7:0] ex1_sp_res_exp,
    output reg [8:0] ex1_sp_exp_diff,
    output reg [24:0] ex1_sp_op1,
    output reg [24:0] ex1_sp_op2,

    output reg ex1_dp_special,
    output reg [63:0] ex1_dp_special_res,
    output reg [4:0] ex1_dp_special_flags,
    output reg ex1_dp_eff_sub,
    output reg ex1_dp_res_sign,
    output reg [10:0] ex1_dp_res_exp,
    output reg [11:0] ex1_dp_exp_diff,
    output reg [53:0] ex1_dp_op1,
    output reg [53:0] ex1_dp_op2
);

    wire stall = valid_out && !ready_out;
    assign ready_in = !stall;

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire sp_s2 = rs2[31] ^ is_sub;
    wire [7:0] sp_e2 = rs2[30:23];
    wire [22:0] sp_f2 = rs2[22:0];

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire dp_s2 = rs2[63] ^ is_sub;
    wire [10:0] dp_e2 = rs2[62:52];
    wire [51:0] dp_f2 = rs2[51:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_nan2 = (sp_e2 == 8'hFF) && (sp_f2 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_snan2 = sp_nan2 && !sp_f2[22];
    wire sp_inf1 = (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_inf2 = (sp_e2 == 8'hFF) && (sp_f2 == 23'd0);
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);
    wire sp_zero2 = (sp_e2 == 8'd0) && (sp_f2 == 23'd0);

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_nan2 = (dp_e2 == 11'h7FF) && (dp_f2 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_snan2 = dp_nan2 && !dp_f2[51];
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_inf2 = (dp_e2 == 11'h7FF) && (dp_f2 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);
    wire dp_zero2 = (dp_e2 == 11'd0) && (dp_f2 == 52'd0);

    wire [8:0] sp_exp1_ext = (sp_e1 == 8'd0) ? 9'd1 : {1'b0, sp_e1};
    wire [8:0] sp_exp2_ext = (sp_e2 == 8'd0) ? 9'd1 : {1'b0, sp_e2};
    wire [24:0] sp_m1_ext = {1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
    wire [24:0] sp_m2_ext = {1'b0, (sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};

    wire [11:0] dp_exp1_ext = (dp_e1 == 11'd0) ? 12'd1 : {1'b0, dp_e1};
    wire [11:0] dp_exp2_ext = (dp_e2 == 11'd0) ? 12'd1 : {1'b0, dp_e2};
    wire [53:0] dp_m1_ext = {1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
    wire [53:0] dp_m2_ext = {1'b0, (dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};

    wire sp_swap = (sp_exp2_ext > sp_exp1_ext) || ((sp_exp1_ext == sp_exp2_ext) && (sp_m2_ext > sp_m1_ext));
    wire dp_swap = (dp_exp2_ext > dp_exp1_ext) || ((dp_exp1_ext == dp_exp2_ext) && (dp_m2_ext > dp_m1_ext));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            ex1_is_double <= 1'b0;
            ex1_rm <= 3'd0;

            ex1_sp_special <= 1'b0;
            ex1_sp_special_res <= 64'd0;
            ex1_sp_special_flags <= 5'd0;
            ex1_sp_eff_sub <= 1'b0;
            ex1_sp_res_sign <= 1'b0;
            ex1_sp_res_exp <= 8'd0;
            ex1_sp_exp_diff <= 9'd0;
            ex1_sp_op1 <= 25'd0;
            ex1_sp_op2 <= 25'd0;

            ex1_dp_special <= 1'b0;
            ex1_dp_special_res <= 64'd0;
            ex1_dp_special_flags <= 5'd0;
            ex1_dp_eff_sub <= 1'b0;
            ex1_dp_res_sign <= 1'b0;
            ex1_dp_res_exp <= 11'd0;
            ex1_dp_exp_diff <= 12'd0;
            ex1_dp_op1 <= 54'd0;
            ex1_dp_op2 <= 54'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                ex1_is_double <= is_double;
                ex1_rm <= rm;

                ex1_sp_special <= 1'b0;
                ex1_sp_special_res <= 64'd0;
                ex1_sp_special_flags <= 5'd0;
                if (sp_nan1 || sp_nan2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= 64'hFFFFFFFF_7FC00000;
                    if (sp_snan1 || sp_snan2) ex1_sp_special_flags[`FF_NV] <= 1'b1;
                end else if (sp_inf1 && sp_inf2 && (sp_s1 != sp_s2)) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= 64'hFFFFFFFF_7FC00000;
                    ex1_sp_special_flags[`FF_NV] <= 1'b1;
                end else if (sp_inf1) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, sp_s1, 8'hFF, 23'd0};
                end else if (sp_inf2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, sp_s2, 8'hFF, 23'd0};
                end else if (sp_zero1 && sp_zero2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, (sp_s1 == sp_s2) ? sp_s1 : (rm == `RM_RDN), 8'd0, 23'd0};
                end
                
                ex1_sp_eff_sub <= (sp_s1 != sp_s2);
                if (sp_swap) begin
                    ex1_sp_res_sign <= sp_s2;
                    ex1_sp_res_exp <= sp_e2;
                    ex1_sp_exp_diff <= sp_exp2_ext - sp_exp1_ext;
                    ex1_sp_op1 <= sp_m2_ext;
                    ex1_sp_op2 <= sp_m1_ext;
                end else begin
                    ex1_sp_res_sign <= sp_s1;
                    ex1_sp_res_exp <= sp_e1;
                    ex1_sp_exp_diff <= sp_exp1_ext - sp_exp2_ext;
                    ex1_sp_op1 <= sp_m1_ext;
                    ex1_sp_op2 <= sp_m2_ext;
                end

                ex1_dp_special <= 1'b0;
                ex1_dp_special_res <= 64'd0;
                ex1_dp_special_flags <= 5'd0;
                if (dp_nan1 || dp_nan2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= 64'h7FF8000000000000;
                    if (dp_snan1 || dp_snan2) ex1_dp_special_flags[`FF_NV] <= 1'b1;
                end else if (dp_inf1 && dp_inf2 && (dp_s1 != dp_s2)) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= 64'h7FF8000000000000;
                    ex1_dp_special_flags[`FF_NV] <= 1'b1;
                end else if (dp_inf1) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {dp_s1, 11'h7FF, 52'd0};
                end else if (dp_inf2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {dp_s2, 11'h7FF, 52'd0};
                end else if (dp_zero1 && dp_zero2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {(dp_s1 == dp_s2) ? dp_s1 : (rm == `RM_RDN), 11'd0, 52'd0};
                end

                ex1_dp_eff_sub <= (dp_s1 != dp_s2);
                if (dp_swap) begin
                    ex1_dp_res_sign <= dp_s2;
                    ex1_dp_res_exp <= dp_e2;
                    ex1_dp_exp_diff <= dp_exp2_ext - dp_exp1_ext;
                    ex1_dp_op1 <= dp_m2_ext;
                    ex1_dp_op2 <= dp_m1_ext;
                end else begin
                    ex1_dp_res_sign <= dp_s1;
                    ex1_dp_res_exp <= dp_e1;
                    ex1_dp_exp_diff <= dp_exp1_ext - dp_exp2_ext;
                    ex1_dp_op1 <= dp_m1_ext;
                    ex1_dp_op2 <= dp_m2_ext;
                end
            end
        end
    end

endmodule
