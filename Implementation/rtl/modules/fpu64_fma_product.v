`timescale 1ns / 1ps

module fpu64_fma_product (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire special_in,
    input wire [63:0] special_result_in,
    input wire [4:0] special_flags_in,
    input wire product_sign_in,
    input wire addend_sign_in,
    input wire product_zero_in,
    input wire addend_zero_in,
    input wire signed [13:0] exp1_in,
    input wire signed [13:0] exp2_in,
    input wire signed [13:0] exp3_in,
    input wire [52:0] sig1_in,
    input wire [52:0] sig2_in,
    input wire [52:0] sig3_in,
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
    output reg signed [13:0] product_exp_base_out,
    output reg signed [13:0] addend_exp_out,
    output reg [52:0] addend_sig_out,
    output reg [47:0] sp_product_out,
    output reg [105:0] dp_product_out
);

    wire stall_stage1;
    wire stall_stage2;
    wire stall_stage3 = valid_out && !ready_out;
    reg valid_stage1;
    reg valid_stage2;
    reg stage1_is_double;
    reg [2:0] stage1_rm;
    reg stage1_special;
    reg [63:0] stage1_special_result;
    reg [4:0] stage1_special_flags;
    reg stage1_product_sign;
    reg stage1_addend_sign;
    reg stage1_product_zero;
    reg stage1_addend_zero;
    reg signed [13:0] stage1_product_exp_base;
    reg signed [13:0] stage1_addend_exp;
    reg [52:0] stage1_addend_sig;
    reg [47:0] stage1_sp_product;
    reg [35:0] stage1_dp_p00;
    reg [35:0] stage1_dp_p01;
    reg [34:0] stage1_dp_p02;
    reg [35:0] stage1_dp_p10;
    reg [35:0] stage1_dp_p11;
    reg [34:0] stage1_dp_p12;
    reg [34:0] stage1_dp_p20;
    reg [34:0] stage1_dp_p21;
    reg [33:0] stage1_dp_p22;
    reg stage2_is_double;
    reg [2:0] stage2_rm;
    reg stage2_special;
    reg [63:0] stage2_special_result;
    reg [4:0] stage2_special_flags;
    reg stage2_product_sign;
    reg stage2_addend_sign;
    reg stage2_product_zero;
    reg stage2_addend_zero;
    reg signed [13:0] stage2_product_exp_base;
    reg signed [13:0] stage2_addend_exp;
    reg [52:0] stage2_addend_sig;
    reg [47:0] stage2_sp_product;
    reg [35:0] stage2_dp_d0;
    reg [36:0] stage2_dp_d1;
    reg [37:0] stage2_dp_d2;
    reg [35:0] stage2_dp_d3;
    reg [33:0] stage2_dp_d4;

    assign stall_stage2 = valid_stage2 && stall_stage3;
    assign stall_stage1 = valid_stage1 && stall_stage2;
    assign ready_in = !stall_stage1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 1'b0;
            stage1_is_double <= 1'b0;
            stage1_rm <= 3'd0;
            stage1_special <= 1'b0;
            stage1_special_result <= 64'd0;
            stage1_special_flags <= 5'd0;
            stage1_product_sign <= 1'b0;
            stage1_addend_sign <= 1'b0;
            stage1_product_zero <= 1'b0;
            stage1_addend_zero <= 1'b0;
            stage1_product_exp_base <= 14'sd0;
            stage1_addend_exp <= 14'sd0;
            stage1_addend_sig <= 53'd0;
            stage1_sp_product <= 48'd0;
            stage1_dp_p00 <= 36'd0;
            stage1_dp_p01 <= 36'd0;
            stage1_dp_p02 <= 35'd0;
            stage1_dp_p10 <= 36'd0;
            stage1_dp_p11 <= 36'd0;
            stage1_dp_p12 <= 35'd0;
            stage1_dp_p20 <= 35'd0;
            stage1_dp_p21 <= 35'd0;
            stage1_dp_p22 <= 34'd0;
        end else if (!stall_stage1) begin
            valid_stage1 <= valid_in;
            if (valid_in) begin
                stage1_is_double <= is_double_in;
                stage1_rm <= rm_in;
                stage1_special <= special_in;
                stage1_special_result <= special_result_in;
                stage1_special_flags <= special_flags_in;
                stage1_product_sign <= product_sign_in;
                stage1_addend_sign <= addend_sign_in;
                stage1_product_zero <= product_zero_in;
                stage1_addend_zero <= addend_zero_in;
                stage1_product_exp_base <= exp1_in + exp2_in;
                stage1_addend_exp <= exp3_in;
                stage1_addend_sig <= sig3_in;
                stage1_sp_product <= sig1_in[23:0] * sig2_in[23:0];
                stage1_dp_p00 <= sig1_in[17:0] * sig2_in[17:0];
                stage1_dp_p01 <= sig1_in[17:0] * sig2_in[35:18];
                stage1_dp_p02 <= sig1_in[17:0] * sig2_in[52:36];
                stage1_dp_p10 <= sig1_in[35:18] * sig2_in[17:0];
                stage1_dp_p11 <= sig1_in[35:18] * sig2_in[35:18];
                stage1_dp_p12 <= sig1_in[35:18] * sig2_in[52:36];
                stage1_dp_p20 <= sig1_in[52:36] * sig2_in[17:0];
                stage1_dp_p21 <= sig1_in[52:36] * sig2_in[35:18];
                stage1_dp_p22 <= sig1_in[52:36] * sig2_in[52:36];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage2 <= 1'b0;
            stage2_is_double <= 1'b0;
            stage2_rm <= 3'd0;
            stage2_special <= 1'b0;
            stage2_special_result <= 64'd0;
            stage2_special_flags <= 5'd0;
            stage2_product_sign <= 1'b0;
            stage2_addend_sign <= 1'b0;
            stage2_product_zero <= 1'b0;
            stage2_addend_zero <= 1'b0;
            stage2_product_exp_base <= 14'sd0;
            stage2_addend_exp <= 14'sd0;
            stage2_addend_sig <= 53'd0;
            stage2_sp_product <= 48'd0;
            stage2_dp_d0 <= 36'd0;
            stage2_dp_d1 <= 37'd0;
            stage2_dp_d2 <= 38'd0;
            stage2_dp_d3 <= 36'd0;
            stage2_dp_d4 <= 34'd0;
        end else if (!stall_stage2) begin
            valid_stage2 <= valid_stage1;
            if (valid_stage1) begin
                stage2_is_double <= stage1_is_double;
                stage2_rm <= stage1_rm;
                stage2_special <= stage1_special;
                stage2_special_result <= stage1_special_result;
                stage2_special_flags <= stage1_special_flags;
                stage2_product_sign <= stage1_product_sign;
                stage2_addend_sign <= stage1_addend_sign;
                stage2_product_zero <= stage1_product_zero;
                stage2_addend_zero <= stage1_addend_zero;
                stage2_product_exp_base <= stage1_product_exp_base;
                stage2_addend_exp <= stage1_addend_exp;
                stage2_addend_sig <= stage1_addend_sig;
                stage2_sp_product <= stage1_sp_product;
                stage2_dp_d0 <= stage1_dp_p00;
                stage2_dp_d1 <= {1'b0, stage1_dp_p01} + {1'b0, stage1_dp_p10};
                stage2_dp_d2 <= {3'd0, stage1_dp_p02} + {2'd0, stage1_dp_p11} + {3'd0, stage1_dp_p20};
                stage2_dp_d3 <= {1'b0, stage1_dp_p12} + {1'b0, stage1_dp_p21};
                stage2_dp_d4 <= stage1_dp_p22;
            end
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
            product_exp_base_out <= 14'sd0;
            addend_exp_out <= 14'sd0;
            addend_sig_out <= 53'd0;
            sp_product_out <= 48'd0;
            dp_product_out <= 106'd0;
        end else if (!stall_stage3) begin
            valid_out <= valid_stage2;
            if (valid_stage2) begin
                is_double_out <= stage2_is_double;
                rm_out <= stage2_rm;
                special_out <= stage2_special;
                special_result_out <= stage2_special_result;
                special_flags_out <= stage2_special_flags;
                product_sign_out <= stage2_product_sign;
                addend_sign_out <= stage2_addend_sign;
                product_zero_out <= stage2_product_zero;
                addend_zero_out <= stage2_addend_zero;
                product_exp_base_out <= stage2_product_exp_base;
                addend_exp_out <= stage2_addend_exp;
                addend_sig_out <= stage2_addend_sig;
                sp_product_out <= stage2_sp_product;
                dp_product_out <= {{70{1'b0}}, stage2_dp_d0} +
                                  {{51{1'b0}}, stage2_dp_d1, 18'd0} +
                                  {{32{1'b0}}, stage2_dp_d2, 36'd0} +
                                  {{16{1'b0}}, stage2_dp_d3, 54'd0} +
                                  {stage2_dp_d4, 72'd0};
            end
        end
    end

endmodule
