`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_sqrt (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,

    input wire is_double,
    input wire [2:0] rm,

    output reg valid_out,
    input wire ready_out,

    output wire [63:0] result,
    output wire [4:0] fflags
);

    localparam S_IDLE  = 2'd0;
    localparam S_SQRT  = 2'd1;
    localparam S_ROUND = 2'd2;
    localparam S_DONE  = 2'd3;

    reg [1:0] state;

    assign ready_in = (state == S_IDLE);

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_inf1 = (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);

    reg is_dbl_reg;
    reg [2:0] rm_reg;

    reg [5:0] count;
    reg [111:0] x_reg;
    reg [57:0] rem;
    reg [56:0] root;
    reg [11:0] exp;

    reg [63:0] res_reg;
    reg [4:0] flags_reg;

    wire [57:0] test_val = {root, 2'b01};
    wire [57:0] next_rem = {rem[55:0], x_reg[111:110]};
    wire [57:0] sub_res = next_rem - test_val;
    wire can_sub = (next_rem >= test_val);

    // Initial values for DP
    wire [11:0] dp_init_exp = {1'b0, dp_e1} - 12'd1023;
    wire [11:0] dp_init_exp_adj = dp_init_exp[0] ? (dp_init_exp - 12'd1) : dp_init_exp;
    wire [111:0] dp_x_reg_init = dp_init_exp[0] ? {1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1, 59'd0} : ({1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1, 58'd0} << 1);
    wire [11:0] dp_exp_init = $unsigned($signed(dp_init_exp_adj) >>> 1) + 12'd1023;

    // Initial values for SP
    wire [11:0] sp_init_exp = {3'd0, sp_e1} - 12'd127;
    wire [11:0] sp_init_exp_adj = sp_init_exp[0] ? (sp_init_exp - 12'd1) : sp_init_exp;
    wire [111:0] sp_x_reg_init = sp_init_exp[0] ? {1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1, 88'd0} : ({1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1, 87'd0} << 1);
    wire [11:0] sp_exp_init = $unsigned($signed(sp_init_exp_adj) >>> 1) + 12'd127;

    // Combinational Rounding Logic
    reg dp_guard;
    reg dp_round;
    reg dp_sticky;
    reg dp_round_up;
    reg [10:0] dp_res_exp;
    reg [51:0] dp_res_frac;
    reg [63:0] dp_final_res;
    reg [4:0] dp_final_flags;

    always @(*) begin
        dp_res_exp = exp[10:0];
        dp_guard = root[2];
        dp_round = root[1];
        dp_sticky = root[0] | (rem != 58'd0);
        dp_round_up = 1'b0;
        dp_final_flags = 5'd0;
        case (rm_reg)
            `RM_RNE: dp_round_up = dp_guard && (dp_round || dp_sticky || root[3]);
            `RM_RTZ: dp_round_up = 1'b0;
            `RM_RDN: dp_round_up = 1'b0;
            `RM_RUP: dp_round_up = (dp_guard || dp_round || dp_sticky);
            `RM_RMM: dp_round_up = dp_guard;
            default: dp_round_up = 1'b0;
        endcase
        dp_res_frac = root[54:3] + (dp_round_up ? 52'd1 : 52'd0);
        dp_final_res = {1'b0, dp_res_exp, dp_res_frac};
        if (dp_guard || dp_round || dp_sticky) dp_final_flags[`FF_NX] = 1'b1;
    end

    reg sp_guard;
    reg sp_round;
    reg sp_sticky;
    reg sp_round_up;
    reg [7:0] sp_res_exp;
    reg [22:0] sp_res_frac;
    reg [63:0] sp_final_res;
    reg [4:0] sp_final_flags;

    always @(*) begin
        sp_res_exp = exp[7:0];
        sp_guard = root[2];
        sp_round = root[1];
        sp_sticky = root[0] | (rem != 58'd0);
        sp_round_up = 1'b0;
        sp_final_flags = 5'd0;
        case (rm_reg)
            `RM_RNE: sp_round_up = sp_guard && (sp_round || sp_sticky || root[3]);
            `RM_RTZ: sp_round_up = 1'b0;
            `RM_RDN: sp_round_up = 1'b0;
            `RM_RUP: sp_round_up = (sp_guard || sp_round || sp_sticky);
            `RM_RMM: sp_round_up = sp_guard;
            default: sp_round_up = 1'b0;
        endcase
        sp_res_frac = root[25:3] + (sp_round_up ? 23'd1 : 23'd0);
        sp_final_res = {32'hFFFFFFFF, 1'b0, sp_res_exp, sp_res_frac};
        if (sp_guard || sp_round || sp_sticky) sp_final_flags[`FF_NX] = 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            valid_out <= 1'b0;

            is_dbl_reg <= 1'b0;
            rm_reg <= 3'd0;
            count <= 6'd0;
            x_reg <= 112'd0;
            rem <= 58'd0;
            root <= 57'd0;
            exp <= 12'd0;
            res_reg <= 64'd0;
            flags_reg <= 5'd0;
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
                            if (dp_nan1) begin
                                res_reg <= 64'h7FF8000000000000;
                                if (dp_snan1) flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (dp_zero1) begin
                                res_reg <= {dp_s1, 11'd0, 52'd0};
                                state <= S_DONE;
                            end else if (dp_s1) begin
                                res_reg <= 64'h7FF8000000000000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (dp_inf1) begin
                                res_reg <= {1'b0, 11'h7FF, 52'd0};
                                state <= S_DONE;
                            end else begin
                                x_reg <= dp_x_reg_init;
                                exp <= dp_exp_init;
                                root <= 57'd0;
                                rem <= 58'd0;
                                count <= 6'd56;
                                state <= S_SQRT;
                            end
                        end else begin
                            if (sp_nan1) begin
                                res_reg <= 64'hFFFFFFFF_7FC00000;
                                if (sp_snan1) flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (sp_zero1) begin
                                res_reg <= {32'hFFFFFFFF, sp_s1, 8'd0, 23'd0};
                                state <= S_DONE;
                            end else if (sp_s1) begin
                                res_reg <= 64'hFFFFFFFF_7FC00000;
                                flags_reg[`FF_NV] <= 1'b1;
                                state <= S_DONE;
                            end else if (sp_inf1) begin
                                res_reg <= {32'hFFFFFFFF, 1'b0, 8'hFF, 23'd0};
                                state <= S_DONE;
                            end else begin
                                x_reg <= sp_x_reg_init;
                                exp <= sp_exp_init;
                                root <= 57'd0;
                                rem <= 58'd0;
                                count <= 6'd27;
                                state <= S_SQRT;
                            end
                        end
                    end
                end

                S_SQRT: begin
                    if (count > 0) begin
                        if (can_sub) begin
                            rem <= sub_res;
                            root <= {root[55:0], 1'b1};
                        end else begin
                            rem <= next_rem;
                            root <= {root[55:0], 1'b0};
                        end
                        x_reg <= {x_reg[109:0], 2'b00};
                        count <= count - 1;
                    end else begin
                        state <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    if (is_dbl_reg) begin
                        res_reg <= dp_final_res;
                        flags_reg <= dp_final_flags;
                    end else begin
                        res_reg <= sp_final_res;
                        flags_reg <= sp_final_flags;
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    valid_out <= 1'b1;
                    if (ready_out && valid_out) begin
                        valid_out <= 1'b0;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end

    assign result = res_reg;
    assign fflags = flags_reg;

endmodule
