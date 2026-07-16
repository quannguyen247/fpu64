`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_div (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire is_double,
    input wire [2:0] rm,

    output reg valid_out,
    input wire ready_out,

    output reg [63:0] result,
    output reg [4:0] fflags
);

    localparam S_IDLE  = 3'd0;
    localparam S_DIV   = 3'd1;
    localparam S_NORM  = 3'd2;
    localparam S_ROUND = 3'd3;
    localparam S_DONE  = 3'd4;

    reg [2:0] state;

    assign ready_in = (state == S_IDLE);

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

    reg is_dbl_reg;
    reg [2:0] rm_reg;

    reg [5:0] count;
    reg [54:0] rem;
    reg [53:0] divisor;
    reg [55:0] quot;
    reg [11:0] exp;
    reg res_sign;

    reg [63:0] res_reg;
    reg [4:0] flags_reg;

    wire [54:0] sub_res = rem - {1'b0, divisor};
    wire can_sub = (rem >= {1'b0, divisor});

    reg guard;
    reg round;
    reg sticky;
    reg round_up;
    reg [10:0] res_exp;
    reg [51:0] res_frac;
    reg [55:0] quot_shifted;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;

            is_dbl_reg <= 1'b0;
            rm_reg <= 3'd0;
            count <= 6'd0;
            rem <= 55'd0;
            divisor <= 54'd0;
            quot <= 56'd0;
            exp <= 12'd0;
            res_sign <= 1'b0;
            res_reg <= 64'd0;
            flags_reg <= 5'd0;

            guard <= 1'b0;
            round <= 1'b0;
            sticky <= 1'b0;
            round_up <= 1'b0;
            res_exp <= 11'd0;
            res_frac <= 52'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    valid_out <= 1'b0;
                    if (valid_in) begin
                        is_dbl_reg <= is_double;
                        rm_reg <= rm;
                        res_reg <= 64'd0;
                        flags_reg <= 5'd0;

                        if (is_double) begin
                            res_sign <= dp_s1 ^ dp_s2;
                            if (dp_nan1 || dp_nan2) begin
                                res_reg <= 64'h7FF8000000000000;
                                if (dp_snan1 || dp_snan2) flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (dp_zero1 && dp_zero2) begin
                                res_reg <= 64'h7FF8000000000000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (dp_inf1 && dp_inf2) begin
                                res_reg <= 64'h7FF8000000000000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (dp_inf1) begin
                                res_reg <= {dp_s1 ^ dp_s2, 11'h7FF, 52'd0};
                                state <= S_DONE;
                            end else if (dp_inf2) begin
                                res_reg <= {dp_s1 ^ dp_s2, 11'd0, 52'd0};
                                state <= S_DONE;
                            end else if (dp_zero1) begin
                                res_reg <= {dp_s1 ^ dp_s2, 11'd0, 52'd0};
                                state <= S_DONE;
                            end else if (dp_zero2) begin
                                res_reg <= {dp_s1 ^ dp_s2, 11'h7FF, 52'd0};
                                flags_reg[`FF_DZ] <= 1'b1;
                                state <= S_DONE;
                            end else begin
                                exp <= {1'b0, dp_e1} - {1'b0, dp_e2} + 12'd1023;
                                rem <= {1'b0, 1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1};
                                divisor <= {1'b0, (dp_e2 == 11'd0) ? 1'b0 : 1'b1, dp_f2};
                                quot <= 56'd0;
                                count <= 6'd56;
                                state <= S_DIV;
                            end
                        end else begin
                            res_sign <= sp_s1 ^ sp_s2;
                            if (sp_nan1 || sp_nan2) begin
                                res_reg <= 64'hFFFFFFFF_7FC00000;
                                if (sp_snan1 || sp_snan2) flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (sp_zero1 && sp_zero2) begin
                                res_reg <= 64'hFFFFFFFF_7FC00000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (sp_inf1 && sp_inf2) begin
                                res_reg <= 64'hFFFFFFFF_7FC00000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (sp_inf1) begin
                                res_reg <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'hFF, 23'd0};
                                state <= S_DONE;
                            end else if (sp_inf2) begin
                                res_reg <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'd0, 23'd0};
                                state <= S_DONE;
                            end else if (sp_zero1) begin
                                res_reg <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'd0, 23'd0};
                                state <= S_DONE;
                            end else if (sp_zero2) begin
                                res_reg <= {32'hFFFFFFFF, sp_s1 ^ sp_s2, 8'hFF, 23'd0};
                                flags_reg[`FF_DZ] <= 1'b1;
                                state <= S_DONE;
                            end else begin
                                exp <= {3'd0, sp_e1} - {3'd0, sp_e2} + 12'd127;
                                rem <= {1'b0, 30'd0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1};
                                divisor <= {30'd0, (sp_e2 == 8'd0) ? 1'b0 : 1'b1, sp_f2};
                                quot <= 56'd0;
                                count <= 6'd27;
                                state <= S_DIV;
                            end
                        end
                    end
                end

                S_DIV: begin
                    if (count > 0) begin
                        if (can_sub) begin
                            rem <= {sub_res[53:0], 1'b0};
                            quot <= {quot[54:0], 1'b1};
                        end else begin
                            rem <= {rem[53:0], 1'b0};
                            quot <= {quot[54:0], 1'b0};
                        end
                        count <= count - 1;
                    end else begin
                        state <= S_NORM;
                    end
                end

                S_NORM: begin
                    if (is_dbl_reg) begin
                        if (quot[55] == 1'b0) begin
                            quot <= quot << 1;
                            exp <= exp - 12'd1;
                        end
                    end else begin
                        if (quot[26] == 1'b0) begin
                            quot <= quot << 1;
                            exp <= exp - 12'd1;
                        end
                    end
                    state <= S_ROUND;
                end

                S_ROUND: begin
                    if (is_dbl_reg) begin
                        if ($signed(exp) >= $signed(12'd2047)) begin
                            res_reg <= {res_sign, 11'h7FF, 52'd0};
                            flags_reg[`FF_OF] <= 1'b1;
                            flags_reg[`FF_NX] <= 1'b1;
                        end else if ($signed(exp) <= $signed(12'd0)) begin
                            res_exp = 11'd0;
                            if ($signed(exp) < $signed(-12'd54)) begin
                                guard = 1'b0;
                                round = 1'b0;
                                sticky = (quot != 0);
                                res_frac = 52'd0;
                            end else begin
                                quot_shifted = quot >> (12'd1 - exp);
                                guard = quot_shifted[2];
                                round = quot_shifted[1];
                                sticky = quot_shifted[0] | (rem != 55'd0);
                                res_frac = quot_shifted[54:3];
                            end

                            round_up = 1'b0;
                            case (rm_reg)
                                `RM_RNE: round_up = guard && (round || sticky || res_frac[0]);
                                `RM_RTZ: round_up = 1'b0;
                                `RM_RDN: round_up = res_sign && (guard || round || sticky);
                                `RM_RUP: round_up = !res_sign && (guard || round || sticky);
                                `RM_RMM: round_up = guard;
                                default: round_up = 1'b0;
                            endcase

                            res_frac = res_frac + (round_up ? 52'd1 : 52'd0);
                            res_reg <= {res_sign, res_exp, res_frac};
                            if (guard || round || sticky) begin
                                flags_reg[`FF_UF] <= 1'b1;
                                flags_reg[`FF_NX] <= 1'b1;
                            end
                        end else begin
                            res_exp = exp[10:0];
                            guard = quot[2];
                            round = quot[1];
                            sticky = quot[0] | (rem != 55'd0);

                            round_up = 1'b0;
                            case (rm_reg)
                                `RM_RNE: round_up = guard && (round || sticky || quot[3]);
                                `RM_RTZ: round_up = 1'b0;
                                `RM_RDN: round_up = res_sign && (guard || round || sticky);
                                `RM_RUP: round_up = !res_sign && (guard || round || sticky);
                                `RM_RMM: round_up = guard;
                                default: round_up = 1'b0;
                            endcase

                            res_frac = quot[54:3] + (round_up ? 52'd1 : 52'd0);
                            if (res_frac == 52'd0 && round_up) begin
                                if (res_exp == 11'h7FE) begin
                                    res_exp = 11'h7FF;
                                    flags_reg[`FF_OF] <= 1'b1;
                                    flags_reg[`FF_NX] <= 1'b1;
                                end else begin
                                    res_exp = res_exp + 11'd1;
                                end
                            end
                            res_reg <= {res_sign, res_exp, res_frac};
                            if (guard || round || sticky) flags_reg[`FF_NX] <= 1'b1;
                        end
                    end else begin
                        if ($signed(exp) >= $signed(12'd255)) begin
                            res_reg <= {32'hFFFFFFFF, res_sign, 8'hFF, 23'd0};
                            flags_reg[`FF_OF] <= 1'b1;
                            flags_reg[`FF_NX] <= 1'b1;
                        end else if ($signed(exp) <= $signed(12'd0)) begin
                            res_exp = 11'd0;
                            if ($signed(exp) < $signed(-12'd25)) begin
                                guard = 1'b0;
                                round = 1'b0;
                                sticky = (quot != 0);
                                res_frac = 52'd0;
                            end else begin
                                quot_shifted = quot >> (12'd1 - exp);
                                guard = quot_shifted[2];
                                round = quot_shifted[1];
                                sticky = quot_shifted[0] | (rem != 55'd0);
                                res_frac = {29'd0, quot_shifted[25:3]};
                            end

                            round_up = 1'b0;
                            case (rm_reg)
                                `RM_RNE: round_up = guard && (round || sticky || res_frac[0]);
                                `RM_RTZ: round_up = 1'b0;
                                `RM_RDN: round_up = res_sign && (guard || round || sticky);
                                `RM_RUP: round_up = !res_sign && (guard || round || sticky);
                                `RM_RMM: round_up = guard;
                                default: round_up = 1'b0;
                            endcase

                            res_frac = res_frac + (round_up ? 52'd1 : 52'd0);
                            res_reg <= {32'hFFFFFFFF, res_sign, res_exp[7:0], res_frac[22:0]};
                            if (guard || round || sticky) begin
                                flags_reg[`FF_UF] <= 1'b1;
                                flags_reg[`FF_NX] <= 1'b1;
                            end
                        end else begin
                            res_exp = exp[10:0];
                            guard = quot[2];
                            round = quot[1];
                            sticky = quot[0] | (rem != 55'd0);

                            round_up = 1'b0;
                            case (rm_reg)
                                `RM_RNE: round_up = guard && (round || sticky || quot[3]);
                                `RM_RTZ: round_up = 1'b0;
                                `RM_RDN: round_up = res_sign && (guard || round || sticky);
                                `RM_RUP: round_up = !res_sign && (guard || round || sticky);
                                `RM_RMM: round_up = guard;
                                default: round_up = 1'b0;
                            endcase

                            res_frac = {29'd0, quot[25:3]} + (round_up ? 52'd1 : 52'd0);
                            if (res_frac[22:0] == 23'd0 && round_up) begin
                                if (res_exp == 11'hFE) begin
                                    res_exp = 11'hFF;
                                    flags_reg[`FF_OF] <= 1'b1;
                                    flags_reg[`FF_NX] <= 1'b1;
                                end else begin
                                    res_exp = res_exp + 11'd1;
                                end
                            end
                            res_reg <= {32'hFFFFFFFF, res_sign, res_exp[7:0], res_frac[22:0]};
                            if (guard || round || sticky) flags_reg[`FF_NX] <= 1'b1;
                        end
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    valid_out <= 1'b1;
                    result <= res_reg;
                    fflags <= flags_reg;
                    if (ready_out && valid_out) begin
                        valid_out <= 1'b0;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
