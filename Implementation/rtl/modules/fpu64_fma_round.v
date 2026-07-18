`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_fma_round (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_in,
    input wire is_double_in,
    input wire [2:0] rm_in,
    input wire special_in,
    input wire [63:0] special_result_in,
    input wire [4:0] special_flags_in,
    input wire result_sign_in,
    input wire signed [13:0] result_exp_in,
    input wire [167:0] norm_in,
    output reg valid_out,
    input wire ready_out,
    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire stall_stage3 = valid_out && !ready_out;
    wire stall_stage2;
    wire stall_stage1;
    wire stall_stage0;
    reg valid_stage0;
    reg valid_stage1;
    reg valid_stage2;
    
    reg stage0_is_double;
    reg [2:0] stage0_rm;
    reg stage0_special;
    reg [63:0] stage0_special_result;
    reg [4:0] stage0_special_flags;
    reg stage0_result_sign;
    reg [167:0] stage0_norm;
    reg stage0_subnormal;
    reg [13:0] stage0_subnormal_shift;
    reg signed [13:0] stage0_rounded_exp;

    reg stage1_is_double;
    reg [2:0] stage1_rm;
    reg stage1_special;
    reg [63:0] stage1_special_result;
    reg [4:0] stage1_special_flags;
    reg stage1_result_sign;
    reg stage1_subnormal;
    reg signed [13:0] stage1_rounded_exp;
    reg [167:0] stage1_round_vector;
    reg stage2_is_double;
    reg [2:0] stage2_rm;
    reg stage2_special;
    reg [63:0] stage2_special_result;
    reg [4:0] stage2_special_flags;
    reg stage2_result_sign;
    reg stage2_subnormal;
    reg signed [13:0] stage2_rounded_exp;
    reg stage2_zero;
    reg [52:0] stage2_dp_significand;
    reg [23:0] stage2_sp_significand;
    reg stage2_round_up;
    reg stage2_round_inexact;
    reg [167:0] round_vector_next;
    reg [13:0] subnormal_shift;
    reg signed [13:0] rounded_exp_next;
    reg subnormal_next;
    reg signed [13:0] rounded_exp;
    reg [53:0] dp_significand;
    reg [24:0] sp_significand;
    reg [10:0] dp_exp_field;
    reg [7:0] sp_exp_field;
    reg round_guard;
    reg round_bit;
    reg round_sticky;
    reg round_up;
    reg round_inexact;
    reg [52:0] dp_significand_next;
    reg [23:0] sp_significand_next;
    reg round_up_next;
    reg round_inexact_next;
    reg overflow_to_inf;
    reg [63:0] result_next;
    reg [4:0] flags_next;

    function [167:0] shift_right_jam;
        input [167:0] value;
        input [13:0] amount;
        reg [167:0] shifted;
        reg [167:0] discarded;
        begin
            if (amount == 14'd0) begin
                shift_right_jam = value;
            end else if (amount >= 14'd168) begin
                shift_right_jam = 168'd0;
                shift_right_jam[0] = |value;
            end else begin
                shifted = value >> amount;
                discarded = value << (14'd168 - amount);
                shifted[0] = shifted[0] | (|discarded);
                shift_right_jam = shifted;
            end
        end
    endfunction

    assign stall_stage2 = valid_stage2 && stall_stage3;
    assign stall_stage1 = valid_stage1 && stall_stage2;
    assign stall_stage0 = valid_stage0 && stall_stage1;
    assign ready_in = !stall_stage0;

    always @(*) begin
        subnormal_shift = 14'd0;
        rounded_exp_next = result_exp_in;
        subnormal_next = 1'b0;
        if (!special_in && norm_in != 168'd0) begin
            if (is_double_in && $signed(result_exp_in) < -14'sd1022) begin
                subnormal_shift = -14'sd1022 - result_exp_in;
                rounded_exp_next = -14'sd1022;
                subnormal_next = 1'b1;
            end else if (!is_double_in && $signed(result_exp_in) < -14'sd126) begin
                subnormal_shift = -14'sd126 - result_exp_in;
                rounded_exp_next = -14'sd126;
                subnormal_next = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage0 <= 1'b0;
            stage0_is_double <= 1'b0;
            stage0_rm <= 3'd0;
            stage0_special <= 1'b0;
            stage0_special_result <= 64'd0;
            stage0_special_flags <= 5'd0;
            stage0_result_sign <= 1'b0;
            stage0_norm <= 168'd0;
            stage0_subnormal <= 1'b0;
            stage0_subnormal_shift <= 14'd0;
            stage0_rounded_exp <= 14'sd0;
        end else if (!stall_stage0) begin
            valid_stage0 <= valid_in;
            if (valid_in) begin
                stage0_is_double <= is_double_in;
                stage0_rm <= rm_in;
                stage0_special <= special_in;
                stage0_special_result <= special_result_in;
                stage0_special_flags <= special_flags_in;
                stage0_result_sign <= result_sign_in;
                stage0_norm <= norm_in;
                stage0_subnormal <= subnormal_next;
                stage0_subnormal_shift <= subnormal_shift;
                stage0_rounded_exp <= rounded_exp_next;
            end
        end
    end

    always @(*) begin
        round_vector_next = stage0_norm;
        if (stage0_subnormal) begin
            round_vector_next = shift_right_jam(stage0_norm, stage0_subnormal_shift);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 1'b0;
            stage1_is_double <= 1'b0;
            stage1_rm <= 3'd0;
            stage1_special <= 1'b0;
            stage1_special_result <= 64'd0;
            stage1_special_flags <= 5'd0;
            stage1_result_sign <= 1'b0;
            stage1_subnormal <= 1'b0;
            stage1_rounded_exp <= 14'sd0;
            stage1_round_vector <= 168'd0;
        end else if (!stall_stage1) begin
            valid_stage1 <= valid_stage0;
            if (valid_stage0) begin
                stage1_is_double <= stage0_is_double;
                stage1_rm <= stage0_rm;
                stage1_special <= stage0_special;
                stage1_special_result <= stage0_special_result;
                stage1_special_flags <= stage0_special_flags;
                stage1_result_sign <= stage0_result_sign;
                stage1_subnormal <= stage0_subnormal;
                stage1_rounded_exp <= stage0_rounded_exp;
                stage1_round_vector <= round_vector_next;
            end
        end
    end

    always @(*) begin
        dp_significand_next = 53'd0;
        sp_significand_next = 24'd0;
        round_guard = 1'b0;
        round_bit = 1'b0;
        round_sticky = 1'b0;
        round_up_next = 1'b0;
        round_inexact_next = 1'b0;
        if (!stage1_special && stage1_round_vector != 168'd0 && stage1_is_double) begin
            dp_significand_next = stage1_round_vector[166:114];
            round_guard = stage1_round_vector[113];
            round_bit = stage1_round_vector[112];
            round_sticky = |stage1_round_vector[111:0];
            round_inexact_next = round_guard || round_bit || round_sticky;
            case (stage1_rm)
                `RM_RNE: round_up_next = round_guard && (round_bit || round_sticky || dp_significand_next[0]);
                `RM_RTZ: round_up_next = 1'b0;
                `RM_RDN: round_up_next = stage1_result_sign && round_inexact_next;
                `RM_RUP: round_up_next = !stage1_result_sign && round_inexact_next;
                `RM_RMM: round_up_next = round_guard;
                default: round_up_next = 1'b0;
            endcase
        end else if (!stage1_special && stage1_round_vector != 168'd0) begin
            sp_significand_next = stage1_round_vector[166:143];
            round_guard = stage1_round_vector[142];
            round_bit = stage1_round_vector[141];
            round_sticky = |stage1_round_vector[140:0];
            round_inexact_next = round_guard || round_bit || round_sticky;
            case (stage1_rm)
                `RM_RNE: round_up_next = round_guard && (round_bit || round_sticky || sp_significand_next[0]);
                `RM_RTZ: round_up_next = 1'b0;
                `RM_RDN: round_up_next = stage1_result_sign && round_inexact_next;
                `RM_RUP: round_up_next = !stage1_result_sign && round_inexact_next;
                `RM_RMM: round_up_next = round_guard;
                default: round_up_next = 1'b0;
            endcase
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
            stage2_result_sign <= 1'b0;
            stage2_subnormal <= 1'b0;
            stage2_rounded_exp <= 14'sd0;
            stage2_zero <= 1'b0;
            stage2_dp_significand <= 53'd0;
            stage2_sp_significand <= 24'd0;
            stage2_round_up <= 1'b0;
            stage2_round_inexact <= 1'b0;
        end else if (!stall_stage2) begin
            valid_stage2 <= valid_stage1;
            if (valid_stage1) begin
                stage2_is_double <= stage1_is_double;
                stage2_rm <= stage1_rm;
                stage2_special <= stage1_special;
                stage2_special_result <= stage1_special_result;
                stage2_special_flags <= stage1_special_flags;
                stage2_result_sign <= stage1_result_sign;
                stage2_subnormal <= stage1_subnormal;
                stage2_rounded_exp <= stage1_rounded_exp;
                stage2_zero <= (stage1_round_vector == 168'd0);
                stage2_dp_significand <= dp_significand_next;
                stage2_sp_significand <= sp_significand_next;
                stage2_round_up <= round_up_next;
                stage2_round_inexact <= round_inexact_next;
            end
        end
    end

    always @(*) begin
        rounded_exp = stage2_rounded_exp;
        dp_significand = 54'd0;
        sp_significand = 25'd0;
        dp_exp_field = 11'd0;
        sp_exp_field = 8'd0;
        round_up = stage2_round_up;
        round_inexact = stage2_round_inexact;
        overflow_to_inf = 1'b0;
        result_next = 64'd0;
        flags_next = 5'd0;
        if (stage2_special) begin
            result_next = stage2_special_result;
            flags_next = stage2_special_flags;
        end else if (stage2_zero) begin
            result_next = stage2_is_double ? {stage2_result_sign, 11'd0, 52'd0} : {32'hFFFFFFFF, stage2_result_sign, 8'd0, 23'd0};
        end else if (stage2_is_double) begin
            dp_significand = {1'b0, stage2_dp_significand};
            dp_significand = dp_significand + (round_up ? 54'd1 : 54'd0);
            if (dp_significand[53]) begin
                dp_significand = dp_significand >> 1;
                rounded_exp = rounded_exp + 14'sd1;
            end
            if ($signed(rounded_exp) > 14'sd1023) begin
                overflow_to_inf = (stage2_rm == `RM_RNE) || (stage2_rm == `RM_RMM) || ((stage2_rm == `RM_RUP) && !stage2_result_sign) || ((stage2_rm == `RM_RDN) && stage2_result_sign);
                result_next = overflow_to_inf ? {stage2_result_sign, 11'h7FF, 52'd0} : {stage2_result_sign, 11'h7FE, 52'hFFFFFFFFFFFFF};
                flags_next[`FF_OF] = 1'b1;
                flags_next[`FF_NX] = 1'b1;
            end else if (stage2_subnormal) begin
                if (dp_significand[52]) begin
                    result_next = {stage2_result_sign, 11'd1, dp_significand[51:0]};
                end else begin
                    result_next = {stage2_result_sign, 11'd0, dp_significand[51:0]};
                    if (round_inexact) flags_next[`FF_UF] = 1'b1;
                end
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end else begin
                dp_exp_field = rounded_exp + 14'sd1023;
                result_next = {stage2_result_sign, dp_exp_field, dp_significand[51:0]};
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end
        end else begin
            sp_significand = {1'b0, stage2_sp_significand};
            sp_significand = sp_significand + (round_up ? 25'd1 : 25'd0);
            if (sp_significand[24]) begin
                sp_significand = sp_significand >> 1;
                rounded_exp = rounded_exp + 14'sd1;
            end
            if ($signed(rounded_exp) > 14'sd127) begin
                overflow_to_inf = (stage2_rm == `RM_RNE) || (stage2_rm == `RM_RMM) || ((stage2_rm == `RM_RUP) && !stage2_result_sign) || ((stage2_rm == `RM_RDN) && stage2_result_sign);
                result_next = overflow_to_inf ? {32'hFFFFFFFF, stage2_result_sign, 8'hFF, 23'd0} : {32'hFFFFFFFF, stage2_result_sign, 8'hFE, 23'h7FFFFF};
                flags_next[`FF_OF] = 1'b1;
                flags_next[`FF_NX] = 1'b1;
            end else if (stage2_subnormal) begin
                if (sp_significand[23]) begin
                    result_next = {32'hFFFFFFFF, stage2_result_sign, 8'd1, sp_significand[22:0]};
                end else begin
                    result_next = {32'hFFFFFFFF, stage2_result_sign, 8'd0, sp_significand[22:0]};
                    if (round_inexact) flags_next[`FF_UF] = 1'b1;
                end
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end else begin
                sp_exp_field = rounded_exp + 14'sd127;
                result_next = {32'hFFFFFFFF, stage2_result_sign, sp_exp_field, sp_significand[22:0]};
                if (round_inexact) flags_next[`FF_NX] = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;
        end else if (!stall_stage3) begin
            valid_out <= valid_stage2;
            if (valid_stage2) begin
                result <= result_next;
                fflags <= flags_next;
            end
        end
    end

endmodule
