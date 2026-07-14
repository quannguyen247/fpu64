`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_addsub (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire is_sub,
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

    reg valid_ex1;
    reg valid_ex2;
    reg valid_ex3;
    reg valid_ex4;
    reg valid_ex5;

    wire stall_ex5 = valid_ex5 && !ready_out;
    assign stall_ex4 = valid_ex4 && stall_ex5;
    assign stall_ex3 = valid_ex3 && stall_ex4;
    assign stall_ex2 = valid_ex2 && stall_ex3;
    assign stall_ex1 = valid_ex1 && stall_ex2;
    assign ready_in = !stall_ex1;

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

    reg ex1_is_double;
    reg [2:0] ex1_rm;

    reg ex1_sp_special;
    reg [63:0] ex1_sp_special_res;
    reg [4:0] ex1_sp_special_flags;
    reg ex1_sp_eff_sub;
    reg ex1_sp_res_sign;
    reg [7:0] ex1_sp_res_exp;
    reg [8:0] ex1_sp_exp_diff;
    reg [24:0] ex1_sp_op1;
    reg [24:0] ex1_sp_op2;

    reg ex1_dp_special;
    reg [63:0] ex1_dp_special_res;
    reg [4:0] ex1_dp_special_flags;
    reg ex1_dp_eff_sub;
    reg ex1_dp_res_sign;
    reg [10:0] ex1_dp_res_exp;
    reg [11:0] ex1_dp_exp_diff;
    reg [53:0] ex1_dp_op1;
    reg [53:0] ex1_dp_op2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex1 <= 1'b0;
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
        end else if (!stall_ex1) begin
            valid_ex1 <= valid_in;
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

    reg ex2_is_double;
    reg [2:0] ex2_rm;

    reg ex2_sp_special;
    reg [63:0] ex2_sp_special_res;
    reg [4:0] ex2_sp_special_flags;
    reg ex2_sp_res_sign;
    reg [7:0] ex2_sp_res_exp;
    reg [28:0] ex2_sp_sum;

    reg ex2_dp_special;
    reg [63:0] ex2_dp_special_res;
    reg [4:0] ex2_dp_special_flags;
    reg ex2_dp_res_sign;
    reg [10:0] ex2_dp_res_exp;
    reg [57:0] ex2_dp_sum;

    wire [24:0] sp_m_align;
    wire sp_guard, sp_round, sp_sticky;
    wire [27:0] sp_op1_align;
    wire [27:0] sp_op2_align;

    wire [53:0] dp_m_align;
    wire dp_guard, dp_round, dp_sticky;
    wire [56:0] dp_op1_align;
    wire [56:0] dp_op2_align;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex2 <= 1'b0;
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
        end else if (!stall_ex2) begin
            valid_ex2 <= valid_ex1;
            if (valid_ex1) begin
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

    reg ex3_is_double;
    reg [2:0] ex3_rm;
    
    reg ex3_sp_special;
    reg [63:0] ex3_sp_special_res;
    reg [4:0] ex3_sp_special_flags;
    reg ex3_sp_res_sign;
    reg [7:0] ex3_sp_exp_adj;
    reg [28:0] ex3_sp_sum_norm;

    reg ex3_dp_special;
    reg [63:0] ex3_dp_special_res;
    reg [4:0] ex3_dp_special_flags;
    reg ex3_dp_res_sign;
    reg [10:0] ex3_dp_exp_adj;
    reg [57:0] ex3_dp_sum_norm;

    reg ex4_is_double;
    reg [2:0] ex4_rm;
    
    reg ex4_sp_special;
    reg [63:0] ex4_sp_special_res;
    reg [4:0] ex4_sp_special_flags;
    reg ex4_sp_res_sign;
    reg [7:0] ex4_sp_exp_adj;
    reg [28:0] ex4_sp_sum_norm;

    reg ex4_dp_special;
    reg [63:0] ex4_dp_special_res;
    reg [4:0] ex4_dp_special_flags;
    reg ex4_dp_res_sign;
    reg [10:0] ex4_dp_exp_adj;
    reg [57:0] ex4_dp_sum_norm;

    reg [63:0] ex5_res;
    reg [4:0] ex5_flags;

    reg [28:0] sp_sum_norm_ex3;
    reg [28:0] sp_sum_norm_ex4;
    reg [5:0] sp_shift;
    reg [7:0] sp_exp_adj;
    reg sp_g, sp_r, sp_s, sp_round_up;
    integer j_sp;

    reg [57:0] dp_sum_norm_ex3;
    reg [57:0] dp_sum_norm_ex4;
    reg [6:0] dp_shift;
    reg [10:0] dp_exp_adj;
    reg dp_g, dp_r, dp_s, dp_round_up;
    integer j_dp;

    always @(*) begin
        sp_shift = 6'd0;
        for (j_sp = 0; j_sp < 26; j_sp = j_sp + 1) begin
            if (ex2_sp_sum[26 - j_sp] == 1'b1 && sp_shift == 6'd0) begin
                sp_shift = j_sp;
            end
        end
        if (sp_shift >= ex2_sp_res_exp) begin
            sp_shift = ex2_sp_res_exp - 8'd1;
        end

        dp_shift = 7'd0;
        for (j_dp = 0; j_dp < 55; j_dp = j_dp + 1) begin
            if (ex2_dp_sum[55 - j_dp] == 1'b1 && dp_shift == 7'd0) begin
                dp_shift = j_dp;
            end
        end
        if (dp_shift >= ex2_dp_res_exp) begin
            dp_shift = ex2_dp_res_exp - 11'd1;
        end
    end

    // ==========================================
    // ==========================================
    // STAGE 3: Normalization (LZA)
    // ==========================================
    reg [28:0] ex3_sp_sum;
    reg [5:0] ex3_sp_shift;
    reg [57:0] ex3_dp_sum;
    reg [6:0] ex3_dp_shift;
    reg ex3_sp_shift_right;
    reg ex3_dp_shift_right;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex3 <= 1'b0;
            ex3_is_double <= 1'b0;
            ex3_rm <= 3'd0;

            ex3_sp_special <= 1'b0;
            ex3_sp_special_res <= 64'd0;
            ex3_sp_special_flags <= 5'd0;
            ex3_sp_res_sign <= 1'b0;
            ex3_sp_exp_adj <= 8'd0;
            ex3_sp_sum <= 29'd0;
            ex3_sp_shift <= 6'd0;
            ex3_sp_shift_right <= 1'b0;

            ex3_dp_special <= 1'b0;
            ex3_dp_special_res <= 64'd0;
            ex3_dp_special_flags <= 5'd0;
            ex3_dp_res_sign <= 1'b0;
            ex3_dp_exp_adj <= 11'd0;
            ex3_dp_sum <= 58'd0;
            ex3_dp_shift <= 7'd0;
            ex3_dp_shift_right <= 1'b0;
        end else if (!stall_ex3) begin
            valid_ex3 <= valid_ex2;
            if (valid_ex2) begin
                ex3_is_double <= ex2_is_double;
                ex3_rm <= ex2_rm;

                ex3_sp_special <= ex2_sp_special;
                ex3_sp_special_res <= ex2_sp_special_res;
                ex3_sp_special_flags <= ex2_sp_special_flags;
                ex3_sp_res_sign <= ex2_sp_res_sign;
                ex3_sp_sum <= ex2_sp_sum;
                ex3_sp_exp_adj <= ex2_sp_res_exp;

                if (ex2_sp_sum[27]) begin
                    ex3_sp_shift_right <= 1'b1;
                    ex3_sp_shift <= 6'd0;
                end else begin
                    ex3_sp_shift_right <= 1'b0;
                    ex3_sp_shift <= sp_shift;
                end

                ex3_dp_special <= ex2_dp_special;
                ex3_dp_special_res <= ex2_dp_special_res;
                ex3_dp_special_flags <= ex2_dp_special_flags;
                ex3_dp_res_sign <= ex2_dp_res_sign;
                ex3_dp_sum <= ex2_dp_sum;
                ex3_dp_exp_adj <= ex2_dp_res_exp;

                if (ex2_dp_sum[56]) begin
                    ex3_dp_shift_right <= 1'b1;
                    ex3_dp_shift <= 7'd0;
                end else begin
                    ex3_dp_shift_right <= 1'b0;
                    ex3_dp_shift <= dp_shift;
                end
            end
        end
    end

    // ==========================================
    // STAGE 4: Normalization (Shift)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex4 <= 1'b0;
            ex4_is_double <= 1'b0;
            ex4_rm <= 3'd0;

            ex4_sp_special <= 1'b0;
            ex4_sp_special_res <= 64'd0;
            ex4_sp_special_flags <= 5'd0;
            ex4_sp_res_sign <= 1'b0;
            ex4_sp_exp_adj <= 8'd0;
            ex4_sp_sum_norm <= 29'd0;

            ex4_dp_special <= 1'b0;
            ex4_dp_special_res <= 64'd0;
            ex4_dp_special_flags <= 5'd0;
            ex4_dp_res_sign <= 1'b0;
            ex4_dp_exp_adj <= 11'd0;
            ex4_dp_sum_norm <= 58'd0;
        end else if (!stall_ex4) begin
            valid_ex4 <= valid_ex3;
            if (valid_ex3) begin
                ex4_is_double <= ex3_is_double;
                ex4_rm <= ex3_rm;

                ex4_sp_special <= ex3_sp_special;
                ex4_sp_special_res <= ex3_sp_special_res;
                ex4_sp_special_flags <= ex3_sp_special_flags;
                ex4_sp_res_sign <= ex3_sp_res_sign;

                if (ex3_sp_shift_right) begin
                    sp_sum_norm_ex3 = ex3_sp_sum >> 1;
                    sp_sum_norm_ex3[0] = sp_sum_norm_ex3[0] | ex3_sp_sum[0];
                    ex4_sp_exp_adj <= (ex3_sp_exp_adj == 8'hFE) ? 8'hFF : (ex3_sp_exp_adj + 8'd1);
                    ex4_sp_sum_norm <= sp_sum_norm_ex3;
                end else begin
                    ex4_sp_sum_norm <= ex3_sp_sum << ex3_sp_shift;
                    ex4_sp_exp_adj <= ex3_sp_exp_adj - ex3_sp_shift;
                end

                ex4_dp_special <= ex3_dp_special;
                ex4_dp_special_res <= ex3_dp_special_res;
                ex4_dp_special_flags <= ex3_dp_special_flags;
                ex4_dp_res_sign <= ex3_dp_res_sign;

                if (ex3_dp_shift_right) begin
                    dp_sum_norm_ex3 = ex3_dp_sum >> 1;
                    dp_sum_norm_ex3[0] = dp_sum_norm_ex3[0] | ex3_dp_sum[0];
                    ex4_dp_exp_adj <= (ex3_dp_exp_adj == 11'h7FE) ? 11'h7FF : (ex3_dp_exp_adj + 11'd1);
                    ex4_dp_sum_norm <= dp_sum_norm_ex3;
                end else begin
                    ex4_dp_sum_norm <= ex3_dp_sum << ex3_dp_shift;
                    ex4_dp_exp_adj <= ex3_dp_exp_adj - ex3_dp_shift;
                end
            end
        end
    end

    // ==========================================
    // STAGE 5: Rounding and Pack
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex5 <= 1'b0;
            ex5_res <= 64'd0;
            ex5_flags <= 5'd0;
        end else if (!stall_ex5) begin
            valid_ex5 <= valid_ex4;
            if (valid_ex4) begin
                ex5_res <= 64'd0;
                ex5_flags <= 5'd0;

                if (ex4_is_double) begin
                    if (ex4_dp_special) begin
                        ex5_res <= ex4_dp_special_res;
                        ex5_flags <= ex4_dp_special_flags;
                    end else if (ex4_dp_sum_norm[57:1] == 57'd0) begin
                        ex5_res <= {(ex4_rm == `RM_RDN), 11'd0, 52'd0};
                    end else begin
                        dp_g = ex4_dp_sum_norm[2];
                        dp_r = ex4_dp_sum_norm[1];
                        dp_s = ex4_dp_sum_norm[0];
                        dp_round_up = 1'b0;
                        case (ex4_rm)
                            `RM_RNE: dp_round_up = dp_g && (dp_r || dp_s || ex4_dp_sum_norm[3]);
                            `RM_RTZ: dp_round_up = 1'b0;
                            `RM_RDN: dp_round_up = ex4_dp_res_sign && (dp_g || dp_r || dp_s);
                            `RM_RUP: dp_round_up = !ex4_dp_res_sign && (dp_g || dp_r || dp_s);
                            `RM_RMM: dp_round_up = dp_g;
                            default: dp_round_up = 1'b0;
                        endcase

                        dp_sum_norm_ex4 = ex4_dp_sum_norm;
                        dp_exp_adj = ex4_dp_exp_adj;

                        if (dp_round_up) begin
                            dp_sum_norm_ex4[55:3] = dp_sum_norm_ex4[55:3] + 53'd1;
                            if (dp_sum_norm_ex4[56]) begin
                                dp_sum_norm_ex4[55:3] = dp_sum_norm_ex4[55:3] >> 1;
                                dp_exp_adj = (dp_exp_adj == 11'h7FE) ? 11'h7FF : (dp_exp_adj + 11'd1);
                            end
                        end

                        if (dp_exp_adj == 11'h7FF) begin
                            ex5_res <= {ex4_dp_res_sign, 11'h7FF, 52'd0};
                            ex5_flags[`FF_OF] <= 1'b1;
                            ex5_flags[`FF_NX] <= 1'b1;
                        end else begin
                            ex5_res <= {ex4_dp_res_sign, dp_exp_adj, dp_sum_norm_ex4[54:3]};
                            if (dp_g || dp_r || dp_s) ex5_flags[`FF_NX] <= 1'b1;
                        end
                    end
                end else begin
                    if (ex4_sp_special) begin
                        ex5_res <= ex4_sp_special_res;
                        ex5_flags <= ex4_sp_special_flags;
                    end else if (ex4_sp_sum_norm[28:1] == 28'd0) begin
                        ex5_res <= {32'hFFFFFFFF, (ex4_rm == `RM_RDN), 8'd0, 23'd0};
                    end else begin
                        sp_g = ex4_sp_sum_norm[2];
                        sp_r = ex4_sp_sum_norm[1];
                        sp_s = ex4_sp_sum_norm[0];
                        sp_round_up = 1'b0;
                        case (ex4_rm)
                            `RM_RNE: sp_round_up = sp_g && (sp_r || sp_s || ex4_sp_sum_norm[3]);
                            `RM_RTZ: sp_round_up = 1'b0;
                            `RM_RDN: sp_round_up = ex4_sp_res_sign && (sp_g || sp_r || sp_s);
                            `RM_RUP: sp_round_up = !ex4_sp_res_sign && (sp_g || sp_r || sp_s);
                            `RM_RMM: sp_round_up = sp_g;
                            default: sp_round_up = 1'b0;
                        endcase

                        sp_sum_norm_ex4 = ex4_sp_sum_norm;
                        sp_exp_adj = ex4_sp_exp_adj;

                        if (sp_round_up) begin
                            sp_sum_norm_ex4[26:3] = sp_sum_norm_ex4[26:3] + 24'd1;
                            if (sp_sum_norm_ex4[27]) begin
                                sp_sum_norm_ex4[26:3] = sp_sum_norm_ex4[26:3] >> 1;
                                sp_exp_adj = (sp_exp_adj == 8'hFE) ? 8'hFF : (sp_exp_adj + 8'd1);
                            end
                        end

                        if (sp_exp_adj == 8'hFF) begin
                            ex5_res <= {32'hFFFFFFFF, ex4_sp_res_sign, 8'hFF, 23'd0};
                            ex5_flags[`FF_OF] <= 1'b1;
                            ex5_flags[`FF_NX] <= 1'b1;
                        end else begin
                            ex5_res <= {32'hFFFFFFFF, ex4_sp_res_sign, sp_exp_adj, sp_sum_norm_ex4[25:3]};
                            if (sp_g || sp_r || sp_s) ex5_flags[`FF_NX] <= 1'b1;
                        end
                    end
                end
            end
        end
    end
    assign valid_out = valid_ex5;
    assign result = ex5_res;
    assign fflags = ex5_flags;

endmodule
