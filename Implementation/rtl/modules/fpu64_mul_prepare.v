`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_mul_prepare (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire [63:0] rs1,
    input wire [63:0] rs2,
    input wire is_double,
    input wire [2:0] rm,
    output wire valid_out,
    input wire ready_out,
    output wire is_double_out,
    output wire [2:0] rm_out,
    output wire sp_special_out,
    output wire [63:0] sp_special_result_out,
    output wire [4:0] sp_special_flags_out,
    output wire sp_result_sign_out,
    output wire [8:0] sp_exp_out,
    output wire [23:0] sp_m1_out,
    output wire [23:0] sp_m2_out,
    output wire dp_special_out,
    output wire [63:0] dp_special_result_out,
    output wire [4:0] dp_special_flags_out,
    output wire dp_result_sign_out,
    output wire [11:0] dp_exp_out,
    output wire [52:0] dp_m1_out,
    output wire [52:0] dp_m2_out
);

    wire stall_ex1;
    reg valid_ex1;

    assign stall_ex1 = valid_ex1 && !ready_out;
    assign ready_in = !stall_ex1;

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire sp_s2 = rs2[31];
    wire [7:0] sp_e2 = rs2[30:23];
    wire [22:0] sp_f2 = rs2[22:0];

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire dp_s2 = rs2[63];
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

    reg ex1_is_double;
    reg [2:0] ex1_rm;

    reg ex1_sp_special;
    reg [63:0] ex1_sp_special_res;
    reg [4:0] ex1_sp_special_flags;
    reg ex1_sp_res_sign;
    reg [8:0] ex1_sp_exp;
    reg [23:0] ex1_sp_m1;
    reg [23:0] ex1_sp_m2;

    reg ex1_dp_special;
    reg [63:0] ex1_dp_special_res;
    reg [4:0] ex1_dp_special_flags;
    reg ex1_dp_res_sign;
    reg [11:0] ex1_dp_exp;
    reg [52:0] ex1_dp_m1;
    reg [52:0] ex1_dp_m2;

    assign valid_out = valid_ex1;
    assign is_double_out = ex1_is_double;
    assign rm_out = ex1_rm;
    assign sp_special_out = ex1_sp_special;
    assign sp_special_result_out = ex1_sp_special_res;
    assign sp_special_flags_out = ex1_sp_special_flags;
    assign sp_result_sign_out = ex1_sp_res_sign;
    assign sp_exp_out = ex1_sp_exp;
    assign sp_m1_out = ex1_sp_m1;
    assign sp_m2_out = ex1_sp_m2;
    assign dp_special_out = ex1_dp_special;
    assign dp_special_result_out = ex1_dp_special_res;
    assign dp_special_flags_out = ex1_dp_special_flags;
    assign dp_result_sign_out = ex1_dp_res_sign;
    assign dp_exp_out = ex1_dp_exp;
    assign dp_m1_out = ex1_dp_m1;
    assign dp_m2_out = ex1_dp_m2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex1 <= 1'b0;
            ex1_is_double <= 1'b0;
            ex1_rm <= 3'd0;

            ex1_sp_special <= 1'b0;
            ex1_sp_special_res <= 64'd0;
            ex1_sp_special_flags <= 5'd0;
            ex1_sp_res_sign <= 1'b0;
            ex1_sp_exp <= 9'd0;
            ex1_sp_m1 <= 24'd0;
            ex1_sp_m2 <= 24'd0;

            ex1_dp_special <= 1'b0;
            ex1_dp_special_res <= 64'd0;
            ex1_dp_special_flags <= 5'd0;
            ex1_dp_res_sign <= 1'b0;
            ex1_dp_exp <= 12'd0;
            ex1_dp_m1 <= 53'd0;
            ex1_dp_m2 <= 53'd0;
        end else if (!stall_ex1) begin
            valid_ex1 <= valid_in;
            if (valid_in) begin
                ex1_is_double <= is_double;
                ex1_rm <= rm;

                ex1_sp_special <= 1'b0;
                ex1_sp_special_res <= 64'd0;
                ex1_sp_special_flags <= 5'd0;
                ex1_sp_res_sign <= sp_s1 ^ sp_s2;
                ex1_sp_m1 <= {(sp_e1 != 8'd0), sp_f1};
                ex1_sp_m2 <= {(sp_e2 != 8'd0), sp_f2};

                if (sp_e1 == 8'd0 && sp_f1 == 23'd0)
                    ex1_sp_exp <= 9'd0 + 9'd1 - 9'd127;
                else
                    ex1_sp_exp <= {1'b0, sp_e1} - 9'd127;

                if (sp_e2 == 8'd0 && sp_f2 == 23'd0)
                    ex1_sp_exp <= ex1_sp_exp;
                else
                    ex1_sp_exp <= ({1'b0, sp_e1} - 9'd127) + ({1'b0, sp_e2} - 9'd127) + 9'd127;

                if (sp_snan1 || sp_snan2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_flags <= 5'b10000;
                    if (sp_snan1) ex1_sp_special_res <= {32'hFFFFFFFF, rs1[31:0] | 32'h00400000};
                    else ex1_sp_special_res <= {32'hFFFFFFFF, rs2[31:0] | 32'h00400000};
                end else if (sp_nan1) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, rs1[31:0]};
                end else if (sp_nan2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, rs2[31:0]};
                end else if (sp_inf1 || sp_inf2) begin
                    ex1_sp_special <= 1'b1;
                    if ((sp_inf1 && sp_zero2) || (sp_inf2 && sp_zero1)) begin
                        ex1_sp_special_res <= {32'hFFFFFFFF, 32'h7FC00000};
                        ex1_sp_special_flags <= 5'b10000;
                    end else begin
                        ex1_sp_special_res <= {32'hFFFFFFFF, (sp_s1 ^ sp_s2), 8'hFF, 23'd0};
                    end
                end else if (sp_zero1 || sp_zero2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, (sp_s1 ^ sp_s2), 31'd0};
                end

                ex1_dp_special <= 1'b0;
                ex1_dp_special_res <= 64'd0;
                ex1_dp_special_flags <= 5'd0;
                ex1_dp_res_sign <= dp_s1 ^ dp_s2;
                ex1_dp_m1 <= {(dp_e1 != 11'd0), dp_f1};
                ex1_dp_m2 <= {(dp_e2 != 11'd0), dp_f2};

                if (dp_e1 == 11'd0 && dp_f1 == 52'd0)
                    ex1_dp_exp <= 12'd0 + 12'd1 - 12'd1023;
                else
                    ex1_dp_exp <= {1'b0, dp_e1} - 12'd1023;

                if (dp_e2 == 11'd0 && dp_f2 == 52'd0)
                    ex1_dp_exp <= ex1_dp_exp;
                else
                    ex1_dp_exp <= ({1'b0, dp_e1} - 12'd1023) + ({1'b0, dp_e2} - 12'd1023) + 12'd1023;

                if (dp_snan1 || dp_snan2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_flags <= 5'b10000;
                    if (dp_snan1) ex1_dp_special_res <= rs1 | 64'h0008000000000000;
                    else ex1_dp_special_res <= rs2 | 64'h0008000000000000;
                end else if (dp_nan1) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= rs1;
                end else if (dp_nan2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= rs2;
                end else if (dp_inf1 || dp_inf2) begin
                    ex1_dp_special <= 1'b1;
                    if ((dp_inf1 && dp_zero2) || (dp_inf2 && dp_zero1)) begin
                        ex1_dp_special_res <= 64'h7FF8000000000000;
                        ex1_dp_special_flags <= 5'b10000;
                    end else begin
                        ex1_dp_special_res <= {(dp_s1 ^ dp_s2), 11'h7FF, 52'd0};
                    end
                end else if (dp_zero1 || dp_zero2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {(dp_s1 ^ dp_s2), 63'd0};
                end
            end
        end
    end

endmodule
