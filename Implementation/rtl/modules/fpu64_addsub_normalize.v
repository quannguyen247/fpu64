`timescale 1ns / 1ps

module fpu64_addsub_normalize (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire ex2_is_double,
    input wire [2:0] ex2_rm,

    input wire ex2_sp_special,
    input wire [63:0] ex2_sp_special_res,
    input wire [4:0] ex2_sp_special_flags,
    input wire ex2_sp_res_sign,
    input wire [7:0] ex2_sp_res_exp,
    input wire [28:0] ex2_sp_sum,

    input wire ex2_dp_special,
    input wire [63:0] ex2_dp_special_res,
    input wire [4:0] ex2_dp_special_flags,
    input wire ex2_dp_res_sign,
    input wire [10:0] ex2_dp_res_exp,
    input wire [57:0] ex2_dp_sum,

    output reg valid_out,
    input wire ready_out,

    output reg ex4_is_double,
    output reg [2:0] ex4_rm,

    output reg ex4_sp_special,
    output reg [63:0] ex4_sp_special_res,
    output reg [4:0] ex4_sp_special_flags,
    output reg ex4_sp_res_sign,
    output reg [7:0] ex4_sp_exp_adj,
    output reg [28:0] ex4_sp_sum_norm,

    output reg ex4_dp_special,
    output reg [63:0] ex4_dp_special_res,
    output reg [4:0] ex4_dp_special_flags,
    output reg ex4_dp_res_sign,
    output reg [10:0] ex4_dp_exp_adj,
    output reg [57:0] ex4_dp_sum_norm
);

    wire stall_ex3;
    wire stall_ex4 = valid_out && !ready_out;
    reg valid_ex3;

    assign stall_ex3 = valid_ex3 && stall_ex4;
    assign ready_in = !stall_ex3;

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

    reg [5:0] sp_shift;
    integer j_sp;

    reg [6:0] dp_shift;
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
            valid_ex3 <= valid_in;
            if (valid_in) begin
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
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
            valid_out <= valid_ex3;
            if (valid_ex3) begin
                ex4_is_double <= ex3_is_double;
                ex4_rm <= ex3_rm;

                ex4_sp_special <= ex3_sp_special;
                ex4_sp_special_res <= ex3_sp_special_res;
                ex4_sp_special_flags <= ex3_sp_special_flags;
                ex4_sp_res_sign <= ex3_sp_res_sign;

                if (ex3_sp_shift_right) begin
                    ex4_sp_exp_adj <= (ex3_sp_exp_adj == 8'hFE) ? 8'hFF : (ex3_sp_exp_adj + 8'd1);
                    ex4_sp_sum_norm <= {1'b0, ex3_sp_sum[28:2], ex3_sp_sum[1] | ex3_sp_sum[0]};
                end else begin
                    ex4_sp_sum_norm <= ex3_sp_sum << ex3_sp_shift;
                    ex4_sp_exp_adj <= ex3_sp_exp_adj - ex3_sp_shift;
                end

                ex4_dp_special <= ex3_dp_special;
                ex4_dp_special_res <= ex3_dp_special_res;
                ex4_dp_special_flags <= ex3_dp_special_flags;
                ex4_dp_res_sign <= ex3_dp_res_sign;

                if (ex3_dp_shift_right) begin
                    ex4_dp_exp_adj <= (ex3_dp_exp_adj == 11'h7FE) ? 11'h7FF : (ex3_dp_exp_adj + 11'd1);
                    ex4_dp_sum_norm <= {1'b0, ex3_dp_sum[57:2], ex3_dp_sum[1] | ex3_dp_sum[0]};
                end else begin
                    ex4_dp_sum_norm <= ex3_dp_sum << ex3_dp_shift;
                    ex4_dp_exp_adj <= ex3_dp_exp_adj - ex3_dp_shift;
                end
            end
        end
    end

endmodule
