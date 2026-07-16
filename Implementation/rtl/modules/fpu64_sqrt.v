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

    output reg [63:0] result,
    output reg [4:0] fflags
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
    reg [11:0] init_exp;

    wire [57:0] test_val = {root, 2'b01};
    wire [57:0] next_rem = {rem[55:0], x_reg[111:110]};
    wire [57:0] sub_res = next_rem - test_val;
    wire can_sub = (next_rem >= test_val);

    reg guard;
    reg round;
    reg sticky;
    reg round_up;
    reg [10:0] res_exp;
    reg [51:0] res_frac;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;

            is_dbl_reg <= 1'b0;
            rm_reg <= 3'd0;
            count <= 6'd0;
            x_reg <= 112'd0;
            rem <= 58'd0;
            root <= 57'd0;
            exp <= 12'd0;
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
                                init_exp = {1'b0, dp_e1} - 12'd1023;
                                if (init_exp[0]) begin
                                    x_reg <= {1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1, 59'd0};
                                    init_exp = init_exp - 12'd1;
                                end else begin
                                    x_reg <= {1'b0, (dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1, 58'd0} << 1;
                                end
                                exp <= $unsigned($signed(init_exp) >>> 1) + 12'd1023;
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
                                init_exp = {3'd0, sp_e1} - 12'd127;
                                if (init_exp[0]) begin
                                    x_reg <= {1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1, 88'd0};
                                    init_exp = init_exp - 12'd1;
                                end else begin
                                    x_reg <= {1'b0, (sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1, 87'd0} << 1;
                                end
                                exp <= $unsigned($signed(init_exp) >>> 1) + 12'd127;
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
                        res_exp = exp[10:0];
                        guard = root[2];
                        round = root[1];
                        sticky = root[0] | (rem != 58'd0);
                        round_up = 1'b0;
                        case (rm_reg)
                            `RM_RNE: round_up = guard && (round || sticky || root[3]);
                            `RM_RTZ: round_up = 1'b0;
                            `RM_RDN: round_up = 1'b0;
                            `RM_RUP: round_up = (guard || round || sticky);
                            `RM_RMM: round_up = guard;
                            default: round_up = 1'b0;
                        endcase
                        res_frac = root[54:3] + (round_up ? 52'd1 : 52'd0);
                        res_reg <= {1'b0, res_exp, res_frac};
                        if (guard || round || sticky) flags_reg[`FF_NX] <= 1'b1;
                    end else begin
                        res_exp = exp[10:0];
                        guard = root[2];
                        round = root[1];
                        sticky = root[0] | (rem != 58'd0);
                        round_up = 1'b0;
                        case (rm_reg)
                            `RM_RNE: round_up = guard && (round || sticky || root[3]);
                            `RM_RTZ: round_up = 1'b0;
                            `RM_RDN: round_up = 1'b0;
                            `RM_RUP: round_up = (guard || round || sticky);
                            `RM_RMM: round_up = guard;
                            default: round_up = 1'b0;
                        endcase
                        res_frac = {29'd0, root[25:3]} + (round_up ? 52'd1 : 52'd0);
                        res_reg <= {32'hFFFFFFFF, 1'b0, res_exp[7:0], res_frac[22:0]};
                        if (guard || round || sticky) flags_reg[`FF_NX] <= 1'b1;
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
