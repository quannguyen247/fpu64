`timescale 1ns / 1ps

module fpu64_mul_product (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire sp_special_in,
    input wire [63:0] sp_special_result_in,
    input wire [4:0] sp_special_flags_in,
    input wire sp_result_sign_in,
    input wire [8:0] sp_exp_in,
    input wire [23:0] sp_m1_in,
    input wire [23:0] sp_m2_in,
    input wire dp_special_in,
    input wire [63:0] dp_special_result_in,
    input wire [4:0] dp_special_flags_in,
    input wire dp_result_sign_in,
    input wire [11:0] dp_exp_in,
    input wire [52:0] dp_m1_in,
    input wire [52:0] dp_m2_in,
    output wire valid_out,
    input wire ready_out,
    output wire is_double_out,
    output wire [2:0] rm_out,
    output wire sp_special_out,
    output wire [63:0] sp_special_result_out,
    output wire [4:0] sp_special_flags_out,
    output wire sp_result_sign_out,
    output wire [8:0] sp_exp_out,
    output wire [47:0] sp_norm_out,
    output wire dp_special_out,
    output wire [63:0] dp_special_result_out,
    output wire [4:0] dp_special_flags_out,
    output wire dp_result_sign_out,
    output wire [11:0] dp_exp_out,
    output wire [105:0] dp_norm_out
);

    wire stall_ex2;
    wire stall_ex3;
    wire stall_ex4;

    reg valid_ex2;
    reg valid_ex3;
    reg valid_ex4;

    assign stall_ex4 = valid_ex4 && !ready_out;
    assign stall_ex3 = valid_ex3 && stall_ex4;
    assign stall_ex2 = valid_ex2 && stall_ex3;
    assign ready_in = !stall_ex2;

    wire valid_ex1 = valid_in;
    wire ex1_is_double = is_double_in;
    wire [2:0] ex1_rm = rm_in;
    wire ex1_sp_special = sp_special_in;
    wire [63:0] ex1_sp_special_res = sp_special_result_in;
    wire [4:0] ex1_sp_special_flags = sp_special_flags_in;
    wire ex1_sp_res_sign = sp_result_sign_in;
    wire [8:0] ex1_sp_exp = sp_exp_in;
    wire [23:0] ex1_sp_m1 = sp_m1_in;
    wire [23:0] ex1_sp_m2 = sp_m2_in;
    wire ex1_dp_special = dp_special_in;
    wire [63:0] ex1_dp_special_res = dp_special_result_in;
    wire [4:0] ex1_dp_special_flags = dp_special_flags_in;
    wire ex1_dp_res_sign = dp_result_sign_in;
    wire [11:0] ex1_dp_exp = dp_exp_in;
    wire [52:0] ex1_dp_m1 = dp_m1_in;
    wire [52:0] ex1_dp_m2 = dp_m2_in;

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

    // ex4: final product sum + 1-bit normalization (merged from old ex4+ex5)
    reg ex4_is_double;
    reg [2:0] ex4_rm;

    reg ex4_sp_special;
    reg [63:0] ex4_sp_special_res;
    reg [4:0] ex4_sp_special_flags;
    reg ex4_sp_res_sign;
    reg [8:0] ex4_sp_exp;
    reg [47:0] ex4_sp_prod_norm;

    reg ex4_dp_special;
    reg [63:0] ex4_dp_special_res;
    reg [4:0] ex4_dp_special_flags;
    reg ex4_dp_res_sign;
    reg [11:0] ex4_dp_exp;
    reg [105:0] ex4_dp_prod_norm;

    wire [105:0] ex3_dp_prod_sum = {{70{1'b0}}, ex3_dp_d0} +
                                   {{51{1'b0}}, ex3_dp_d1, 18'd0} +
                                   {{32{1'b0}}, ex3_dp_d2, 36'd0} +
                                   {{16{1'b0}}, ex3_dp_d3, 54'd0} +
                                   {ex3_dp_d4, 72'd0};

    assign valid_out = valid_ex4;
    assign is_double_out = ex4_is_double;
    assign rm_out = ex4_rm;
    assign sp_special_out = ex4_sp_special;
    assign sp_special_result_out = ex4_sp_special_res;
    assign sp_special_flags_out = ex4_sp_special_flags;
    assign sp_result_sign_out = ex4_sp_res_sign;
    assign sp_exp_out = ex4_sp_exp;
    assign sp_norm_out = ex4_sp_prod_norm;
    assign dp_special_out = ex4_dp_special;
    assign dp_special_result_out = ex4_dp_special_res;
    assign dp_special_flags_out = ex4_dp_special_flags;
    assign dp_result_sign_out = ex4_dp_res_sign;
    assign dp_exp_out = ex4_dp_exp;
    assign dp_norm_out = ex4_dp_prod_norm;

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
            ex4_sp_prod_norm <= 48'd0;

            ex4_dp_special <= 1'b0;
            ex4_dp_special_res <= 64'd0;
            ex4_dp_special_flags <= 5'd0;
            ex4_dp_res_sign <= 1'b0;
            ex4_dp_exp <= 12'd0;
            ex4_dp_prod_norm <= 106'd0;
        end else if (!stall_ex4) begin
            valid_ex4 <= valid_ex3;
            if (valid_ex3) begin
                ex4_is_double <= ex3_is_double;
                ex4_rm <= ex3_rm;

                ex4_sp_special <= ex3_sp_special;
                ex4_sp_special_res <= ex3_sp_special_res;
                ex4_sp_special_flags <= ex3_sp_special_flags;
                ex4_sp_res_sign <= ex3_sp_res_sign;
                if (ex3_sp_prod[47]) begin
                    ex4_sp_prod_norm <= ex3_sp_prod;
                    ex4_sp_exp <= ex3_sp_exp + 9'd1;
                end else begin
                    ex4_sp_prod_norm <= ex3_sp_prod << 1;
                    ex4_sp_exp <= ex3_sp_exp;
                end

                ex4_dp_special <= ex3_dp_special;
                ex4_dp_special_res <= ex3_dp_special_res;
                ex4_dp_special_flags <= ex3_dp_special_flags;
                ex4_dp_res_sign <= ex3_dp_res_sign;
                if (ex3_dp_prod_sum[105]) begin
                    ex4_dp_prod_norm <= ex3_dp_prod_sum;
                    ex4_dp_exp <= ex3_dp_exp + 12'd1;
                end else begin
                    ex4_dp_prod_norm <= ex3_dp_prod_sum << 1;
                    ex4_dp_exp <= ex3_dp_exp;
                end
            end
        end
    end

endmodule
