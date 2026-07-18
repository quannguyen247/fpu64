`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_mul_round (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire is_double_in,
    input wire [2:0] rm_in,

    input wire dp_special_in,
    input wire [63:0] dp_special_result_in,
    input wire [4:0] dp_special_flags_in,
    input wire sp_special_in,
    input wire [63:0] sp_special_result_in,
    input wire [4:0] sp_special_flags_in,

    input wire dp_result_sign_in,
    input wire [11:0] dp_exp_in,
    input wire [105:0] dp_norm_in,

    input wire sp_result_sign_in,
    input wire [8:0] sp_exp_in,
    input wire [47:0] sp_norm_in,

    output wire valid_out,
    input wire ready_out,

    output wire [63:0] result,
    output wire [4:0] fflags
);

    wire ex4_is_double = is_double_in;
    wire [2:0] ex4_rm = rm_in;
    wire ex4_dp_special = dp_special_in;
    wire [63:0] ex4_dp_special_res = dp_special_result_in;
    wire [4:0] ex4_dp_special_flags = dp_special_flags_in;
    wire ex4_sp_special = sp_special_in;
    wire [63:0] ex4_sp_special_res = sp_special_result_in;
    wire [4:0] ex4_sp_special_flags = sp_special_flags_in;
    wire ex4_dp_res_sign = dp_result_sign_in;
    wire [11:0] ex4_dp_exp = dp_exp_in;
    wire [105:0] ex4_dp_prod_norm = dp_norm_in;
    wire ex4_sp_res_sign = sp_result_sign_in;
    wire [8:0] ex4_sp_exp = sp_exp_in;
    wire [47:0] ex4_sp_prod_norm = sp_norm_in;

    reg valid_ex5;
    wire stall_ex5;
    reg valid_ex6;
    wire stall_ex6 = valid_ex6 && !ready_out;
    assign stall_ex5 = valid_ex5 && stall_ex6;
    assign ready_in = !stall_ex5;

    // ex5 regs
    reg ex5_is_double;
    
    reg ex5_dp_special;
    reg [63:0] ex5_dp_special_res;
    reg [4:0] ex5_dp_special_flags;
    reg ex5_sp_special;
    reg [63:0] ex5_sp_special_res;
    reg [4:0] ex5_sp_special_flags;

    reg ex5_dp_res_sign;
    reg [10:0] ex5_dp_res_exp;
    reg [51:0] ex5_dp_res_frac;
    reg ex5_dp_round_up;
    reg ex5_dp_inexact;
    reg ex5_dp_overflow;
    reg ex5_dp_underflow;

    reg ex5_sp_res_sign;
    reg [7:0] ex5_sp_res_exp;
    reg [22:0] ex5_sp_res_frac;
    reg ex5_sp_round_up;
    reg ex5_sp_inexact;
    reg ex5_sp_overflow;
    reg ex5_sp_underflow;

    // ex6 regs
    reg [64:0] ex6_res;
    reg [4:0] ex6_flags;

    // ex5 DP Comb
    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg dp_round_up;
    reg [105:0] dp_prod_shifted;
    integer i_dp;

    always @(*) begin
        dp_res_exp = 11'd0;
        dp_res_frac = 52'd0;
        dp_guard = 1'b0;
        dp_round = 1'b0;
        dp_sticky = 1'b0;
        dp_round_up = 1'b0;
        dp_prod_shifted = 106'd0;
        
        if ($signed(ex4_dp_exp) <= $signed(12'd0)) begin
            dp_res_exp = 11'd0;
            if ($signed(ex4_dp_exp) < $signed(-12'd54)) begin
                dp_guard = 1'b0;
                dp_round = 1'b0;
                dp_sticky = (ex4_dp_prod_norm != 0);
                dp_res_frac = 52'd0;
            end else begin
                dp_prod_shifted = ex4_dp_prod_norm >> (12'd1 - ex4_dp_exp);
                dp_guard = dp_prod_shifted[52];
                dp_round = dp_prod_shifted[51];
                dp_sticky = 1'b0;
                for (i_dp = 0; i_dp < 51; i_dp = i_dp + 1) begin
                    if (dp_prod_shifted[i_dp]) dp_sticky = 1'b1;
                end
                dp_res_frac = dp_prod_shifted[104:53];
            end
            
            case (ex4_rm)
                `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || dp_res_frac[0]);
                `RM_RTZ: dp_round_up = 1'b0;
                `RM_RDN: dp_round_up = ex4_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                `RM_RUP: dp_round_up = !ex4_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                `RM_RMM: dp_round_up = dp_guard;
                default: dp_round_up = 1'b0;
            endcase
        end else begin
            dp_res_exp = ex4_dp_exp[10:0];
            dp_guard = ex4_dp_prod_norm[52];
            dp_round = ex4_dp_prod_norm[51];
            dp_sticky = 1'b0;
            for (i_dp = 0; i_dp < 51; i_dp = i_dp + 1) begin
                if (ex4_dp_prod_norm[i_dp]) dp_sticky = 1'b1;
            end
            
            case (ex4_rm)
                `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || ex4_dp_prod_norm[53]);
                `RM_RTZ: dp_round_up = 1'b0;
                `RM_RDN: dp_round_up = ex4_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                `RM_RUP: dp_round_up = !ex4_dp_res_sign && (dp_guard || dp_round || dp_sticky);
                `RM_RMM: dp_round_up = dp_guard;
                default: dp_round_up = 1'b0;
            endcase
            dp_res_frac = ex4_dp_prod_norm[104:53];
        end
    end

    // ex5 SP Comb
    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;
    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg sp_round_up;
    reg [47:0] sp_prod_shifted;
    integer i_sp;

    always @(*) begin
        sp_res_exp = 8'd0;
        sp_res_frac = 23'd0;
        sp_guard = 1'b0;
        sp_round = 1'b0;
        sp_sticky = 1'b0;
        sp_round_up = 1'b0;
        sp_prod_shifted = 48'd0;
        
        if ($signed(ex4_sp_exp) <= $signed(9'd0)) begin
            sp_res_exp = 8'd0;
            if ($signed(ex4_sp_exp) < $signed(-9'd25)) begin
                sp_guard = 1'b0;
                sp_round = 1'b0;
                sp_sticky = (ex4_sp_prod_norm != 0);
                sp_res_frac = 23'd0;
            end else begin
                sp_prod_shifted = ex4_sp_prod_norm >> (9'd1 - ex4_sp_exp);
                sp_guard = sp_prod_shifted[23];
                sp_round = sp_prod_shifted[22];
                sp_sticky = 1'b0;
                for (i_sp = 0; i_sp < 22; i_sp = i_sp + 1) begin
                    if (sp_prod_shifted[i_sp]) sp_sticky = 1'b1;
                end
                sp_res_frac = sp_prod_shifted[46:24];
            end
            
            case (ex4_rm)
                `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || sp_res_frac[0]);
                `RM_RTZ: sp_round_up = 1'b0;
                `RM_RDN: sp_round_up = ex4_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                `RM_RUP: sp_round_up = !ex4_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                `RM_RMM: sp_round_up = sp_guard;
                default: sp_round_up = 1'b0;
            endcase
        end else begin
            sp_res_exp = ex4_sp_exp[7:0];
            sp_guard = ex4_sp_prod_norm[23];
            sp_round = ex4_sp_prod_norm[22];
            sp_sticky = 1'b0;
            for (i_sp = 0; i_sp < 22; i_sp = i_sp + 1) begin
                if (ex4_sp_prod_norm[i_sp]) sp_sticky = 1'b1;
            end
            
            case (ex4_rm)
                `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || ex4_sp_prod_norm[24]);
                `RM_RTZ: sp_round_up = 1'b0;
                `RM_RDN: sp_round_up = ex4_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                `RM_RUP: sp_round_up = !ex4_sp_res_sign && (sp_guard || sp_round || sp_sticky);
                `RM_RMM: sp_round_up = sp_guard;
                default: sp_round_up = 1'b0;
            endcase
            sp_res_frac = ex4_sp_prod_norm[46:24];
        end
    end

    // ex5 Seq
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_ex5 <= 1'b0;
            ex5_is_double <= 1'b0;
            
            ex5_dp_special <= 1'b0;
            ex5_dp_special_res <= 64'd0;
            ex5_dp_special_flags <= 5'd0;
            ex5_sp_special <= 1'b0;
            ex5_sp_special_res <= 64'd0;
            ex5_sp_special_flags <= 5'd0;

            ex5_dp_res_sign <= 1'b0;
            ex5_dp_res_exp <= 11'd0;
            ex5_dp_res_frac <= 52'd0;
            ex5_dp_round_up <= 1'b0;
            ex5_dp_inexact <= 1'b0;
            ex5_dp_overflow <= 1'b0;
            ex5_dp_underflow <= 1'b0;

            ex5_sp_res_sign <= 1'b0;
            ex5_sp_res_exp <= 8'd0;
            ex5_sp_res_frac <= 23'd0;
            ex5_sp_round_up <= 1'b0;
            ex5_sp_inexact <= 1'b0;
            ex5_sp_overflow <= 1'b0;
            ex5_sp_underflow <= 1'b0;
        end else if (!stall_ex5) begin
            valid_ex5 <= valid_in;
            if (valid_in) begin
                ex5_is_double <= ex4_is_double;
                
                ex5_dp_special <= ex4_dp_special;
                ex5_dp_special_res <= ex4_dp_special_res;
                ex5_dp_special_flags <= ex4_dp_special_flags;
                ex5_sp_special <= ex4_sp_special;
                ex5_sp_special_res <= ex4_sp_special_res;
                ex5_sp_special_flags <= ex4_sp_special_flags;

                ex5_dp_res_sign <= ex4_dp_res_sign;
                ex5_sp_res_sign <= ex4_sp_res_sign;

                ex5_dp_overflow <= 1'b0;
                ex5_dp_underflow <= 1'b0;
                ex5_dp_inexact <= 1'b0;
                ex5_dp_res_exp <= 11'd0;
                ex5_dp_res_frac <= 52'd0;
                ex5_dp_round_up <= 1'b0;

                ex5_sp_overflow <= 1'b0;
                ex5_sp_underflow <= 1'b0;
                ex5_sp_inexact <= 1'b0;
                ex5_sp_res_exp <= 8'd0;
                ex5_sp_res_frac <= 23'd0;
                ex5_sp_round_up <= 1'b0;

                if (ex4_is_double) begin
                    if (!ex4_dp_special) begin
                        if ($signed(ex4_dp_exp) >= $signed(12'd2047)) begin
                            ex5_dp_overflow <= 1'b1;
                            ex5_dp_inexact <= 1'b1;
                        end else begin
                            ex5_dp_res_exp <= dp_res_exp;
                            ex5_dp_res_frac <= dp_res_frac;
                            ex5_dp_round_up <= dp_round_up;
                            if (dp_guard || dp_round || dp_sticky) begin
                                if ($signed(ex4_dp_exp) <= $signed(12'd0)) ex5_dp_underflow <= 1'b1;
                                ex5_dp_inexact <= 1'b1;
                            end
                        end
                    end
                end else begin
                    if (!ex4_sp_special) begin
                        if ($signed(ex4_sp_exp) >= $signed(9'd255)) begin
                            ex5_sp_overflow <= 1'b1;
                            ex5_sp_inexact <= 1'b1;
                        end else begin
                            ex5_sp_res_exp <= sp_res_exp;
                            ex5_sp_res_frac <= sp_res_frac;
                            ex5_sp_round_up <= sp_round_up;
                            if (sp_guard || sp_round || sp_sticky) begin
                                if ($signed(ex4_sp_exp) <= $signed(9'd0)) ex5_sp_underflow <= 1'b1;
                                ex5_sp_inexact <= 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

    // ex6 DP Comb
    reg [51:0] ex6_dp_res_frac;
    reg [10:0] ex6_dp_res_exp;
    reg ex6_dp_overflow;
    reg ex6_dp_inexact;
    
    always @(*) begin
        ex6_dp_res_frac = ex5_dp_res_frac + (ex5_dp_round_up ? 52'd1 : 52'd0);
        ex6_dp_res_exp = ex5_dp_res_exp;
        ex6_dp_overflow = ex5_dp_overflow;
        ex6_dp_inexact = ex5_dp_inexact;
        
        if (ex5_dp_round_up && (&ex5_dp_res_frac)) begin
            if (ex5_dp_res_exp == 11'h7FE) begin
                ex6_dp_res_exp = 11'h7FF;
                ex6_dp_overflow = 1'b1;
                ex6_dp_inexact = 1'b1;
            end else begin
                ex6_dp_res_exp = ex5_dp_res_exp + 11'd1;
            end
        end
    end

    // ex6 SP Comb
    reg [22:0] ex6_sp_res_frac;
    reg [7:0] ex6_sp_res_exp;
    reg ex6_sp_overflow;
    reg ex6_sp_inexact;
    
    always @(*) begin
        ex6_sp_res_frac = ex5_sp_res_frac + (ex5_sp_round_up ? 23'd1 : 23'd0);
        ex6_sp_res_exp = ex5_sp_res_exp;
        ex6_sp_overflow = ex5_sp_overflow;
        ex6_sp_inexact = ex5_sp_inexact;
        
        if (ex5_sp_round_up && (&ex5_sp_res_frac)) begin
            if (ex5_sp_res_exp == 8'hFE) begin
                ex6_sp_res_exp = 8'hFF;
                ex6_sp_overflow = 1'b1;
                ex6_sp_inexact = 1'b1;
            end else begin
                ex6_sp_res_exp = ex5_sp_res_exp + 8'd1;
            end
        end
    end

    // ex6 Seq
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
                        ex6_res <= {1'b0, ex5_dp_special_res};
                        ex6_flags <= ex5_dp_special_flags;
                    end else if (ex6_dp_overflow) begin
                        ex6_res <= {1'b0, ex5_dp_res_sign, 11'h7FF, 52'd0};
                        ex6_flags[`FF_OF] <= 1'b1;
                        ex6_flags[`FF_NX] <= 1'b1;
                    end else begin
                        ex6_res <= {1'b0, ex5_dp_res_sign, ex6_dp_res_exp, ex6_dp_res_frac};
                        if (ex5_dp_underflow) ex6_flags[`FF_UF] <= 1'b1;
                        if (ex6_dp_inexact) ex6_flags[`FF_NX] <= 1'b1;
                    end
                end else begin
                    if (ex5_sp_special) begin
                        ex6_res <= {1'b0, ex5_sp_special_res};
                        ex6_flags <= ex5_sp_special_flags;
                    end else if (ex6_sp_overflow) begin
                        ex6_res <= {1'b0, 32'hFFFFFFFF, ex5_sp_res_sign, 8'hFF, 23'd0};
                        ex6_flags[`FF_OF] <= 1'b1;
                        ex6_flags[`FF_NX] <= 1'b1;
                    end else begin
                        ex6_res <= {1'b0, 32'hFFFFFFFF, ex5_sp_res_sign, ex6_sp_res_exp, ex6_sp_res_frac};
                        if (ex5_sp_underflow) ex6_flags[`FF_UF] <= 1'b1;
                        if (ex6_sp_inexact) ex6_flags[`FF_NX] <= 1'b1;
                    end
                end
            end
        end
    end

    assign valid_out = valid_ex6;
    assign result = ex6_res[63:0];
    assign fflags = ex6_flags;

endmodule
