`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_addsub_round (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire ex4_is_double,
    input wire [2:0] ex4_rm,

    input wire ex4_sp_special,
    input wire [63:0] ex4_sp_special_res,
    input wire [4:0] ex4_sp_special_flags,
    input wire ex4_sp_res_sign,
    input wire [7:0] ex4_sp_exp_adj,
    input wire [28:0] ex4_sp_sum_norm, // [28:0], [27] is hidden bit, [2:0] are GRS

    input wire ex4_dp_special,
    input wire [63:0] ex4_dp_special_res,
    input wire [4:0] ex4_dp_special_flags,
    input wire ex4_dp_res_sign,
    input wire [10:0] ex4_dp_exp_adj,
    input wire [57:0] ex4_dp_sum_norm, // [57:0], [55] is hidden bit, [2:0] are GRS

    output wire valid_out,
    input wire ready_out,

    output wire [63:0] result,
    output wire [4:0] fflags
);

    reg valid_ex5;
    wire stall_ex5;
    assign stall_ex5 = valid_ex5 && !ready_out;
    assign ready_in = !stall_ex5;

    reg [63:0] ex5_res;
    reg [4:0] ex5_flags;

    reg dp_g, dp_r, dp_s;
    reg dp_round_up;
    reg [52:0] dp_rounded_full;
    reg dp_carry;
    reg [10:0] dp_exp_adj;
    reg dp_nx;

    // Combinational logic for DP rounding
    always @(*) begin
        dp_g = ex4_dp_sum_norm[2];
        dp_r = ex4_dp_sum_norm[1];
        dp_s = ex4_dp_sum_norm[0];
        dp_round_up = 1'b0;
        dp_nx = dp_g | dp_r | dp_s;
        
        case (ex4_rm)
            `RM_RNE: dp_round_up = dp_g && (dp_r || dp_s || ex4_dp_sum_norm[3]);
            `RM_RTZ: dp_round_up = 1'b0;
            `RM_RDN: dp_round_up = ex4_dp_res_sign && (dp_g || dp_r || dp_s);
            `RM_RUP: dp_round_up = !ex4_dp_res_sign && (dp_g || dp_r || dp_s);
            `RM_RMM: dp_round_up = dp_g;
            default: dp_round_up = 1'b0;
        endcase

        {dp_carry, dp_rounded_full} = ex4_dp_sum_norm[55:3] + dp_round_up;
        dp_exp_adj = ex4_dp_exp_adj;

        if (dp_carry) begin // overflow occurred (e.g. 1.111...1 -> 10.000...0)
            dp_exp_adj = (dp_exp_adj == 11'h7FE) ? 11'h7FF : (dp_exp_adj + 11'd1);
        end else if (dp_exp_adj == 11'd0 && dp_rounded_full[52] == 1'b1) begin
            dp_exp_adj = 11'd1; // subnormal rounded up to normal
        end
    end

    reg sp_g, sp_r, sp_s;
    reg sp_round_up;
    reg [23:0] sp_rounded_full;
    reg sp_carry;
    reg [7:0] sp_exp_adj;
    reg sp_nx;

    // Combinational logic for SP rounding
    always @(*) begin
        sp_g = ex4_sp_sum_norm[2];
        sp_r = ex4_sp_sum_norm[1];
        sp_s = ex4_sp_sum_norm[0];
        sp_round_up = 1'b0;
        sp_nx = sp_g | sp_r | sp_s;

        case (ex4_rm)
            `RM_RNE: sp_round_up = sp_g && (sp_r || sp_s || ex4_sp_sum_norm[3]);
            `RM_RTZ: sp_round_up = 1'b0;
            `RM_RDN: sp_round_up = ex4_sp_res_sign && (sp_g || sp_r || sp_s);
            `RM_RUP: sp_round_up = !ex4_sp_res_sign && (sp_g || sp_r || sp_s);
            `RM_RMM: sp_round_up = sp_g;
            default: sp_round_up = 1'b0;
        endcase

        {sp_carry, sp_rounded_full} = ex4_sp_sum_norm[27:3] + sp_round_up;
        sp_exp_adj = ex4_sp_exp_adj;

        if (sp_carry) begin
            sp_exp_adj = (sp_exp_adj == 8'hFE) ? 8'hFF : (sp_exp_adj + 8'd1);
        end else if (sp_exp_adj == 8'd0 && sp_rounded_full[23] == 1'b1) begin
            sp_exp_adj = 8'd1; // subnormal rounded up to normal
        end
    end

    // Sequential logic for pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex5 <= 1'b0;
            ex5_res <= 64'd0;
            ex5_flags <= 5'd0;
        end else if (!stall_ex5) begin
            valid_ex5 <= valid_in;
            if (valid_in) begin
                ex5_res <= 64'd0;
                ex5_flags <= 5'd0;

                if (ex4_is_double) begin
                    if (ex4_dp_special) begin
                        ex5_res <= ex4_dp_special_res;
                        ex5_flags <= ex4_dp_special_flags;
                    end else if (ex4_dp_sum_norm[57:1] == 57'd0) begin
                        ex5_res <= {(ex4_rm == `RM_RDN), 11'd0, 52'd0};
                    end else begin
                        if (dp_exp_adj == 11'h7FF) begin
                            ex5_res <= {ex4_dp_res_sign, 11'h7FF, 52'd0};
                            ex5_flags[`FF_OF] <= 1'b1;
                            ex5_flags[`FF_NX] <= 1'b1;
                        end else begin
                            ex5_res <= {ex4_dp_res_sign, dp_exp_adj, dp_rounded_full[51:0]};
                            if (dp_nx) ex5_flags[`FF_NX] <= 1'b1;
                        end
                    end
                end else begin
                    if (ex4_sp_special) begin
                        ex5_res <= ex4_sp_special_res;
                        ex5_flags <= ex4_sp_special_flags;
                    end else if (ex4_sp_sum_norm[28:1] == 28'd0) begin
                        ex5_res <= {32'hFFFFFFFF, (ex4_rm == `RM_RDN), 8'd0, 23'd0};
                    end else begin
                        if (sp_exp_adj == 8'hFF) begin
                            ex5_res <= {32'hFFFFFFFF, ex4_sp_res_sign, 8'hFF, 23'd0};
                            ex5_flags[`FF_OF] <= 1'b1;
                            ex5_flags[`FF_NX] <= 1'b1;
                        end else begin
                            ex5_res <= {32'hFFFFFFFF, ex4_sp_res_sign, sp_exp_adj, sp_rounded_full[22:0]};
                            if (sp_nx) ex5_flags[`FF_NX] <= 1'b1;
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
