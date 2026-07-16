`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_mul (
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

    output wire [63:0] result,
    output wire [4:0] fflags
);

    wire stall_ex1;
    wire stall_ex2;
    wire stall_ex3;
    wire stall_ex4;
    wire stall_ex5;
    wire stall_ex6;

    reg valid_ex1;
    reg valid_ex2;
    reg valid_ex3;
    reg valid_ex4;
    reg valid_ex5;
    reg valid_ex6;

    assign stall_ex6 = valid_ex6 && !ready_out;
    assign stall_ex5 = valid_ex5 && stall_ex6;
    assign stall_ex4 = valid_ex4 && stall_ex5;
    assign stall_ex3 = valid_ex3 && stall_ex4;
    assign stall_ex2 = valid_ex2 && stall_ex3;
    assign stall_ex1 = valid_ex1 && stall_ex2;
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

                if (sp_nan1 || sp_nan2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= 64'hFFFFFFFF_7FC00000;
                    if (sp_snan1 || sp_snan2) ex1_sp_special_flags[`FF_NV] <= 1'b1;
                end else if ((sp_inf1 && sp_zero2) || (sp_zero1 && sp_inf2)) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= 64'hFFFFFFFF_7FC00000;
                    ex1_sp_special_flags[`FF_NV] <= 1'b1;
                end else if (sp_inf1 || sp_inf2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'hFF, 23'd0};
                end else if (sp_zero1 || sp_zero2) begin
                    ex1_sp_special <= 1'b1;
                    ex1_sp_special_res <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'd0, 23'd0};
                end

                ex1_sp_exp <= {1'b0, sp_e1} + {1'b0, sp_e2} - 9'd127;
                ex1_sp_m1 <= {(sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
                ex1_sp_m2 <= {(sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};

                ex1_dp_special <= 1'b0;
                ex1_dp_special_res <= 64'd0;
                ex1_dp_special_flags <= 5'd0;
                ex1_dp_res_sign <= dp_s1 ^ dp_s2;

                if (dp_nan1 || dp_nan2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= 64'h7FF8000000000000;
                    if (dp_snan1 || dp_snan2) ex1_dp_special_flags[`FF_NV] <= 1'b1;
                end else if ((dp_inf1 && dp_zero2) || (dp_zero1 && dp_inf2)) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= 64'h7FF8000000000000;
                    ex1_dp_special_flags[`FF_NV] <= 1'b1;
                end else if (dp_inf1 || dp_inf2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {dp_s1 ^ dp_s2, 11'h7FF, 52'd0};
                end else if (dp_zero1 || dp_zero2) begin
                    ex1_dp_special <= 1'b1;
                    ex1_dp_special_res <= {dp_s1 ^ dp_s2, 11'd0, 52'd0};
                end

                ex1_dp_exp <= {1'b0, dp_e1} + {1'b0, dp_e2} - 12'd1023;
                ex1_dp_m1 <= {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
                ex1_dp_m2 <= {(dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};
            end
        end
    end

    reg ex2_is_double;
    reg [2:0] ex2_rm;

    reg ex2_sp_special;
    reg [63:0] ex2_sp_special_res;
    reg [4:0] ex2_sp_special_flags;
    reg ex2_sp_res_sign;
    reg [8:0] ex2_sp_exp;
    reg [47:0] ex2_sp_prod;

    reg ex2_dp_special;
    reg [63:0] ex2_dp_special_res;
    reg [4:0] ex2_dp_special_flags;
    reg ex2_dp_res_sign;
    reg [11:0] ex2_dp_exp;
    reg [35:0] ex2_dp_p00;
    reg [35:0] ex2_dp_p01;
    reg [34:0] ex2_dp_p02;
    reg [35:0] ex2_dp_p10;
    reg [35:0] ex2_dp_p11;
    reg [34:0] ex2_dp_p12;
    reg [34:0] ex2_dp_p20;
    reg [34:0] ex2_dp_p21;
    reg [33:0] ex2_dp_p22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex2 <= 1'b0;
            ex2_is_double <= 1'b0;
            ex2_rm <= 3'd0;

            ex2_sp_special <= 1'b0;
            ex2_sp_special_res <= 64'd0;
            ex2_sp_special_flags <= 5'd0;
            ex2_sp_res_sign <= 1'b0;
            ex2_sp_exp <= 9'd0;
            ex2_sp_prod <= 48'd0;

            ex2_dp_special <= 1'b0;
            ex2_dp_special_res <= 64'd0;
            ex2_dp_special_flags <= 5'd0;
            ex2_dp_res_sign <= 1'b0;
            ex2_dp_exp <= 12'd0;
            ex2_dp_p00 <= 36'd0;
            ex2_dp_p01 <= 36'd0;
            ex2_dp_p02 <= 35'd0;
            ex2_dp_p10 <= 36'd0;
            ex2_dp_p11 <= 36'd0;
            ex2_dp_p12 <= 35'd0;
            ex2_dp_p20 <= 35'd0;
            ex2_dp_p21 <= 35'd0;
            ex2_dp_p22 <= 34'd0;
        end else if (!stall_ex2) begin
            valid_ex2 <= valid_ex1;
            if (valid_ex1) begin
                ex2_is_double <= ex1_is_double;
                ex2_rm <= ex1_rm;

                ex2_sp_special <= ex1_sp_special;
                ex2_sp_special_res <= ex1_sp_special_res;
                ex2_sp_special_flags <= ex1_sp_special_flags;
                ex2_sp_res_sign <= ex1_sp_res_sign;
                ex2_sp_exp <= ex1_sp_exp;
                ex2_sp_prod <= ex1_sp_m1 * ex1_sp_m2;

                ex2_dp_special <= ex1_dp_special;
                ex2_dp_special_res <= ex1_dp_special_res;
                ex2_dp_special_flags <= ex1_dp_special_flags;
                ex2_dp_res_sign <= ex1_dp_res_sign;
                ex2_dp_exp <= ex1_dp_exp;
                ex2_dp_p00 <= ex1_dp_m1[17:0] * ex1_dp_m2[17:0];
                ex2_dp_p01 <= ex1_dp_m1[17:0] * ex1_dp_m2[35:18];
                ex2_dp_p02 <= ex1_dp_m1[17:0] * ex1_dp_m2[52:36];
                ex2_dp_p10 <= ex1_dp_m1[35:18] * ex1_dp_m2[17:0];
                ex2_dp_p11 <= ex1_dp_m1[35:18] * ex1_dp_m2[35:18];
                ex2_dp_p12 <= ex1_dp_m1[35:18] * ex1_dp_m2[52:36];
                ex2_dp_p20 <= ex1_dp_m1[52:36] * ex1_dp_m2[17:0];
                ex2_dp_p21 <= ex1_dp_m1[52:36] * ex1_dp_m2[35:18];
                ex2_dp_p22 <= ex1_dp_m1[52:36] * ex1_dp_m2[52:36];
            end
        end
    end

    reg ex3_is_double;
    reg [2:0] ex3_rm;

    reg ex3_sp_special;
    reg [63:0] ex3_sp_special_res;
    reg [4:0] ex3_sp_special_flags;
    reg ex3_sp_res_sign;
    reg [8:0] ex3_sp_exp;
    reg [47:0] ex3_sp_prod;

    reg ex3_dp_special;
    reg [63:0] ex3_dp_special_res;
    reg [4:0] ex3_dp_special_flags;
    reg ex3_dp_res_sign;
    reg [11:0] ex3_dp_exp;
    reg [35:0] ex3_dp_d0;
    reg [36:0] ex3_dp_d1;
    reg [37:0] ex3_dp_d2;
    reg [35:0] ex3_dp_d3;
    reg [33:0] ex3_dp_d4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex3 <= 1'b0;
            ex3_is_double <= 1'b0;
            ex3_rm <= 3'd0;

            ex3_sp_special <= 1'b0;
            ex3_sp_special_res <= 64'd0;
            ex3_sp_special_flags <= 5'd0;
            ex3_sp_res_sign <= 1'b0;
            ex3_sp_exp <= 9'd0;
            ex3_sp_prod <= 48'd0;

            ex3_dp_special <= 1'b0;
            ex3_dp_special_res <= 64'd0;
            ex3_dp_special_flags <= 5'd0;
            ex3_dp_res_sign <= 1'b0;
            ex3_dp_exp <= 12'd0;
            ex3_dp_d0 <= 36'd0;
            ex3_dp_d1 <= 37'd0;
            ex3_dp_d2 <= 38'd0;
            ex3_dp_d3 <= 36'd0;
            ex3_dp_d4 <= 34'd0;
        end else if (!stall_ex3) begin
            valid_ex3 <= valid_ex2;
            if (valid_ex2) begin
                ex3_is_double <= ex2_is_double;
                ex3_rm <= ex2_rm;

                ex3_sp_special <= ex2_sp_special;
                ex3_sp_special_res <= ex2_sp_special_res;
                ex3_sp_special_flags <= ex2_sp_special_flags;
                ex3_sp_res_sign <= ex2_sp_res_sign;
                ex3_sp_exp <= ex2_sp_exp;
                ex3_sp_prod <= ex2_sp_prod;

                ex3_dp_special <= ex2_dp_special;
                ex3_dp_special_res <= ex2_dp_special_res;
                ex3_dp_special_flags <= ex2_dp_special_flags;
                ex3_dp_res_sign <= ex2_dp_res_sign;
                ex3_dp_exp <= ex2_dp_exp;
                ex3_dp_d0 <= ex2_dp_p00;
                ex3_dp_d1 <= {1'b0, ex2_dp_p01} + {1'b0, ex2_dp_p10};
                ex3_dp_d2 <= {3'd0, ex2_dp_p02} + {2'd0, ex2_dp_p11} + {3'd0, ex2_dp_p20};
                ex3_dp_d3 <= {1'b0, ex2_dp_p12} + {1'b0, ex2_dp_p21};
                ex3_dp_d4 <= ex2_dp_p22;
            end
        end
    end

    reg ex4_is_double;
    reg [2:0] ex4_rm;

    reg ex4_sp_special;
    reg [63:0] ex4_sp_special_res;
    reg [4:0] ex4_sp_special_flags;
    reg ex4_sp_res_sign;
    reg [8:0] ex4_sp_exp;
    reg [47:0] ex4_sp_prod;

    reg ex4_dp_special;
    reg [63:0] ex4_dp_special_res;
    reg [4:0] ex4_dp_special_flags;
    reg ex4_dp_res_sign;
    reg [11:0] ex4_dp_exp;
    reg [105:0] ex4_dp_prod;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex4 <= 1'b0;
            ex4_is_double <= 1'b0;
            ex4_rm <= 3'd0;

            ex4_sp_special <= 1'b0;
            ex4_sp_special_res <= 64'd0;
            ex4_sp_special_flags <= 5'd0;
            ex4_sp_res_sign <= 1'b0;
            ex4_sp_exp <= 9'd0;
            ex4_sp_prod <= 48'd0;

            ex4_dp_special <= 1'b0;
            ex4_dp_special_res <= 64'd0;
            ex4_dp_special_flags <= 5'd0;
            ex4_dp_res_sign <= 1'b0;
            ex4_dp_exp <= 12'd0;
            ex4_dp_prod <= 106'd0;
        end else if (!stall_ex4) begin
            valid_ex4 <= valid_ex3;
            if (valid_ex3) begin
                ex4_is_double <= ex3_is_double;
                ex4_rm <= ex3_rm;

                ex4_sp_special <= ex3_sp_special;
                ex4_sp_special_res <= ex3_sp_special_res;
                ex4_sp_special_flags <= ex3_sp_special_flags;
                ex4_sp_res_sign <= ex3_sp_res_sign;
                ex4_sp_exp <= ex3_sp_exp;
                ex4_sp_prod <= ex3_sp_prod;

                ex4_dp_special <= ex3_dp_special;
                ex4_dp_special_res <= ex3_dp_special_res;
                ex4_dp_special_flags <= ex3_dp_special_flags;
                ex4_dp_res_sign <= ex3_dp_res_sign;
                ex4_dp_exp <= ex3_dp_exp;
                ex4_dp_prod <= {{70{1'b0}}, ex3_dp_d0} +
                               {{51{1'b0}}, ex3_dp_d1, 18'd0} +
                               {{32{1'b0}}, ex3_dp_d2, 36'd0} +
                               {{16{1'b0}}, ex3_dp_d3, 54'd0} +
                               {ex3_dp_d4, 72'd0};
            end
        end
    end

    reg ex5_is_double;
    reg [2:0] ex5_rm;

    reg ex5_sp_special;
    reg [63:0] ex5_sp_special_res;
    reg [4:0] ex5_sp_special_flags;
    reg ex5_sp_res_sign;
    reg [8:0] ex5_sp_exp;
    reg [47:0] ex5_sp_prod_norm;

    reg ex5_dp_special;
    reg [63:0] ex5_dp_special_res;
    reg [4:0] ex5_dp_special_flags;
    reg ex5_dp_res_sign;
    reg [11:0] ex5_dp_exp;
    reg [105:0] ex5_dp_prod_norm;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex5 <= 1'b0;
            ex5_is_double <= 1'b0;
            ex5_rm <= 3'd0;

            ex5_sp_special <= 1'b0;
            ex5_sp_special_res <= 64'd0;
            ex5_sp_special_flags <= 5'd0;
            ex5_sp_res_sign <= 1'b0;
            ex5_sp_exp <= 9'd0;
            ex5_sp_prod_norm <= 48'd0;

            ex5_dp_special <= 1'b0;
            ex5_dp_special_res <= 64'd0;
            ex5_dp_special_flags <= 5'd0;
            ex5_dp_res_sign <= 1'b0;
            ex5_dp_exp <= 12'd0;
            ex5_dp_prod_norm <= 106'd0;
        end else if (!stall_ex5) begin
            valid_ex5 <= valid_ex4;
            if (valid_ex4) begin
                ex5_is_double <= ex4_is_double;
                ex5_rm <= ex4_rm;

                ex5_sp_special <= ex4_sp_special;
                ex5_sp_special_res <= ex4_sp_special_res;
                ex5_sp_special_flags <= ex4_sp_special_flags;
                ex5_sp_res_sign <= ex4_sp_res_sign;
                if (ex4_sp_prod[47]) begin
                    ex5_sp_prod_norm <= ex4_sp_prod;
                    ex5_sp_exp <= ex4_sp_exp + 9'd1;
                end else begin
                    ex5_sp_prod_norm <= ex4_sp_prod << 1;
                    ex5_sp_exp <= ex4_sp_exp;
                end

                ex5_dp_special <= ex4_dp_special;
                ex5_dp_special_res <= ex4_dp_special_res;
                ex5_dp_special_flags <= ex4_dp_special_flags;
                ex5_dp_res_sign <= ex4_dp_res_sign;
                if (ex4_dp_prod[105]) begin
                    ex5_dp_prod_norm <= ex4_dp_prod;
                    ex5_dp_exp <= ex4_dp_exp + 12'd1;
                end else begin
                    ex5_dp_prod_norm <= ex4_dp_prod << 1;
                    ex5_dp_exp <= ex4_dp_exp;
                end
            end
        end
    end

    reg [64:0] ex6_res;
    reg [4:0] ex6_flags;

    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;
    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg sp_round_up;
    integer i_sp;

    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg dp_round_up;
    integer i_dp;

    reg [105:0] dp_prod_shifted;
    reg [47:0] sp_prod_shifted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex6 <= 1'b0;
            ex6_res <= 65'd0;
            ex6_flags <= 5'd0;
        end else if (!stall_ex6) begin
            valid_ex6 <= valid_ex5;
            if (valid_ex5) begin
                ex6_res <= 65'd0;
                ex6_flags <= 5'd0;

                if (ex5_is_double) begin
                    if (ex5_dp_special) begin
                        ex6_res <= ex5_dp_special_res;
                        ex6_flags <= ex5_dp_special_flags;
                    end else begin
                        if ($signed(ex5_dp_exp) >= $signed(12'd2047)) begin
                            ex6_res <= {ex5_dp_res_sign, 11'h7FF, 52'd0};
                            ex6_flags[`FF_OF] <= 1'b1;
                            ex6_flags[`FF_NX] <= 1'b1;
                        end else if ($signed(ex5_dp_exp) <= $signed(12'd0)) begin
                            dp_res_exp = 11'd0;
                            if ($signed(ex5_dp_exp) < $signed(-12'd54)) begin
                                dp_guard = 1'b0;
                                dp_round = 1'b0;
                                dp_sticky = (ex5_dp_prod_norm != 0);
                                dp_res_frac = 52'd0;
                            end else begin
                                dp_prod_shifted = ex5_dp_prod_norm >> (12'd1 - ex5_dp_exp);
                                dp_guard = dp_prod_shifted[52];
                                dp_round = dp_prod_shifted[51];
                                dp_sticky = 1'b0;
                                for (i_dp = 0; i_dp < 51; i_dp = i_dp + 1) begin
                                    if (dp_prod_shifted[i_dp]) dp_sticky = 1'b1;
                                end
                                dp_res_frac = dp_prod_shifted[104:53];
                            end

                            dp_round_up = 1'b0;
                            case (ex5_rm)
                                `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || dp_res_frac[0]);
                                `RM_RTZ: dp_round_up = 1'b0;
                                `RM_RDN: dp_round_up = ex5_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                                `RM_RUP: dp_round_up = !ex5_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                                `RM_RMM: dp_round_up = dp_guard;
                                default: dp_round_up = 1'b0;
                            endcase

                            dp_res_frac = dp_res_frac + (dp_round_up ? 52'd1 : 52'd0);
                            ex6_res <= {ex5_dp_res_sign, dp_res_exp, dp_res_frac};
                            if (dp_guard || dp_round || dp_sticky) begin
                                ex6_flags[`FF_UF] <= 1'b1;
                                ex6_flags[`FF_NX] <= 1'b1;
                            end
                        end else begin
                            dp_res_exp = ex5_dp_exp[10:0];
                            dp_guard = ex5_dp_prod_norm[52];
                            dp_round = ex5_dp_prod_norm[51];
                            dp_sticky = 1'b0;
                            for (i_dp = 0; i_dp < 51; i_dp = i_dp + 1) begin
                                if (ex5_dp_prod_norm[i_dp]) dp_sticky = 1'b1;
                            end

                            dp_round_up = 1'b0;
                            case (ex5_rm)
                                `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || ex5_dp_prod_norm[53]);
                                `RM_RTZ: dp_round_up = 1'b0;
                                `RM_RDN: dp_round_up = ex5_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                                `RM_RUP: dp_round_up = !ex5_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                                `RM_RMM: dp_round_up = dp_guard;
                                default: dp_round_up = 1'b0;
                            endcase

                            dp_res_frac = ex5_dp_prod_norm[104:53] + (dp_round_up ? 52'd1 : 52'd0);
                            if (dp_res_frac == 52'd0 && dp_round_up) begin
                                if (dp_res_exp == 11'h7FE) begin
                                    dp_res_exp = 11'h7FF;
                                    ex6_flags[`FF_OF] <= 1'b1;
                                    ex6_flags[`FF_NX] <= 1'b1;
                                end else begin
                                    dp_res_exp = dp_res_exp + 11'd1;
                                end
                            end
                            ex6_res <= {ex5_dp_res_sign, dp_res_exp, dp_res_frac};
                            if (dp_guard || dp_round || dp_sticky) ex6_flags[`FF_NX] <= 1'b1;
                        end
                    end
                end else begin
                    if (ex5_sp_special) begin
                        ex6_res <= ex5_sp_special_res;
                        ex6_flags <= ex5_sp_special_flags;
                    end else begin
                        if ($signed(ex5_sp_exp) >= $signed(9'd255)) begin
                            ex6_res <= {32'hFFFFFFFF, ex5_sp_res_sign, 8'hFF, 23'd0};
                            ex6_flags[`FF_OF] <= 1'b1;
                            ex6_flags[`FF_NX] <= 1'b1;
                        end else if ($signed(ex5_sp_exp) <= $signed(9'd0)) begin
                            sp_res_exp = 8'd0;
                            if ($signed(ex5_sp_exp) < $signed(-9'd25)) begin
                                sp_guard = 1'b0;
                                sp_round = 1'b0;
                                sp_sticky = (ex5_sp_prod_norm != 0);
                                sp_res_frac = 23'd0;
                            end else begin
                                sp_prod_shifted = ex5_sp_prod_norm >> (9'd1 - ex5_sp_exp);
                                sp_guard = sp_prod_shifted[23];
                                sp_round = sp_prod_shifted[22];
                                sp_sticky = 1'b0;
                                for (i_sp = 0; i_sp < 22; i_sp = i_sp + 1) begin
                                    if (sp_prod_shifted[i_sp]) sp_sticky = 1'b1;
                                end
                                sp_res_frac = sp_prod_shifted[46:24];
                            end

                            sp_round_up = 1'b0;
                            case (ex5_rm)
                                `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || sp_res_frac[0]);
                                `RM_RTZ: sp_round_up = 1'b0;
                                `RM_RDN: sp_round_up = ex5_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                                `RM_RUP: sp_round_up = !ex5_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                                `RM_RMM: sp_round_up = sp_guard;
                                default: sp_round_up = 1'b0;
                            endcase

                            sp_res_frac = sp_res_frac + (sp_round_up ? 23'd1 : 23'd0);
                            ex6_res <= {32'hFFFFFFFF, ex5_sp_res_sign, sp_res_exp, sp_res_frac};
                            if (sp_guard || sp_round || sp_sticky) begin
                                ex6_flags[`FF_UF] <= 1'b1;
                                ex6_flags[`FF_NX] <= 1'b1;
                            end
                        end else begin
                            sp_res_exp = ex5_sp_exp[7:0];
                            sp_guard = ex5_sp_prod_norm[23];
                            sp_round = ex5_sp_prod_norm[22];
                            sp_sticky = 1'b0;
                            for (i_sp = 0; i_sp < 22; i_sp = i_sp + 1) begin
                                if (ex5_sp_prod_norm[i_sp]) sp_sticky = 1'b1;
                            end

                            sp_round_up = 1'b0;
                            case (ex5_rm)
                                `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || ex5_sp_prod_norm[24]);
                                `RM_RTZ: sp_round_up = 1'b0;
                                `RM_RDN: sp_round_up = ex5_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                                `RM_RUP: sp_round_up = !ex5_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                                `RM_RMM: sp_round_up = sp_guard;
                                default: sp_round_up = 1'b0;
                            endcase

                            sp_res_frac = ex5_sp_prod_norm[46:24] + (sp_round_up ? 23'd1 : 23'd0);
                            if (sp_res_frac == 23'd0 && sp_round_up) begin
                                if (sp_res_exp == 8'hFE) begin
                                    sp_res_exp = 8'hFF;
                                    ex6_flags[`FF_OF] <= 1'b1;
                                    ex6_flags[`FF_NX] <= 1'b1;
                                end else begin
                                    sp_res_exp = sp_res_exp + 8'd1;
                                end
                            end
                            ex6_res <= {32'hFFFFFFFF, ex5_sp_res_sign, sp_res_exp, sp_res_frac};
                            if (sp_guard || sp_round || sp_sticky) ex6_flags[`FF_NX] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    assign valid_out = valid_ex6;
    assign result = ex6_res[63:0];
    assign fflags = ex6_flags;

endmodule
