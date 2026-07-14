`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_convert (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [4:0] rs2_val,
    input wire [6:0] funct7,
    input wire [2:0] rm,

    output reg valid_out,
    input wire ready_out,

    output reg [63:0] out_fp,
    output reg [63:0] out_int,
    output reg we_gpr,
    output reg we_fpr,
    output reg [4:0] fflags
);

    wire stall = valid_out && !ready_out;
    assign ready_in = !stall;

    wire sp_s1 = rs1[31];
    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_inf1 = (sp_e1 == 8'hFF) && (sp_f1 == 23'd0);
    wire sp_zero1 = (sp_e1 == 8'd0) && (sp_f1 == 23'd0);

    wire dp_s1 = rs1[63];
    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_inf1 = (dp_e1 == 11'h7FF) && (dp_f1 == 52'd0);
    wire dp_zero1 = (dp_e1 == 11'd0) && (dp_f1 == 52'd0);
    wire cvt_s_d  = (funct7 == 7'b0100100);

    wire unsupported_fmt = funct7[1]; // Quad (10) or Half (11) precision not supported

    // F2I (Float to Int)
    reg [63:0] f2i_out;
    reg [4:0] f2i_flags;

    reg [63:0] i2f_out;
    reg [4:0] i2f_flags;

    reg [63:0] f2f_out;
    reg [4:0] f2f_flags;

    reg [63:0] f2i_temp;
    reg [11:0] f2i_exp;
    reg f2i_sign;
    reg [63:0] f2i_shifted;
    reg [63:0] f2i_rem;
    reg f2i_guard;
    reg f2i_round;
    reg f2i_sticky;
    reg f2i_round_up;
    reg [63:0] f2i_rounded;
    reg [63:0] f2i_final;
    reg f2i_overflow;

    reg [63:0] i2f_abs;
    reg i2f_sign;
    reg [5:0] i2f_lzc;
    reg [11:0] i2f_exp;
    reg [63:0] i2f_m;
    reg [63:0] i2f_rem;
    reg i2f_guard;
    reg i2f_round;
    reg i2f_sticky;
    reg i2f_round_up;
    reg [63:0] i2f_m_rounded;
    reg [10:0] i2f_dp_exp;
    reg [51:0] i2f_dp_frac;
    reg [7:0] i2f_sp_exp;
    reg [22:0] i2f_sp_frac;

    reg [23:0] f2f_sp_m;
    reg f2f_guard;
    reg f2f_round;
    reg f2f_sticky;
    reg f2f_round_up;
    reg [24:0] f2f_sp_m_rounded;
    reg [7:0] f2f_sp_exp;
    reg [22:0] f2f_sp_frac;
    reg [11:0] f2f_dp_exp;

    integer i;
    integer i2;

    always @(*) begin
        f2i_out = 64'd0;
        f2i_flags = 5'd0;
        f2i_overflow = 1'b0;
        f2i_guard = 1'b0;
        f2i_round = 1'b0;
        f2i_sticky = 1'b0;
        f2i_shifted = 64'd0;

        if (funct7[0]) begin
            f2i_sign = dp_s1;
            f2i_exp = {1'b0, dp_e1} - 12'd1023;
            f2i_temp = {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1, 11'd0};
        end else begin
            f2i_sign = sp_s1;
            f2i_exp = {4'd0, sp_e1} - 12'd127;
            f2i_temp = {(sp_e1 == 8'd0) ? 1'b0 : 1'b1, sp_f1, 40'd0};
        end

        if ((funct7[0] && dp_nan1) || (!funct7[0] && sp_nan1)) begin
            f2i_flags[`FF_NV] = 1'b1;
            case (rs2_val)
                5'd0: f2i_out = 64'hFFFFFFFF_7FFFFFFF;
                5'd1: f2i_out = 64'hFFFFFFFF_FFFFFFFF;
                5'd2: f2i_out = 64'h7FFFFFFFFFFFFFFF;
                5'd3: f2i_out = 64'hFFFFFFFFFFFFFFFF;
                default: f2i_out = 64'd0;
            endcase
        end else if ((funct7[0] && dp_inf1) || (!funct7[0] && sp_inf1)) begin
            f2i_flags[`FF_NV] = 1'b1;
            if (f2i_sign) begin
                case (rs2_val)
                    5'd0: f2i_out = 64'hFFFFFFFF_80000000;
                    5'd1: f2i_out = 64'hFFFFFFFF_00000000;
                    5'd2: f2i_out = 64'h8000000000000000;
                    5'd3: f2i_out = 64'h0000000000000000;
                    default: f2i_out = 64'd0;
                endcase
            end else begin
                case (rs2_val)
                    5'd0: f2i_out = 64'hFFFFFFFF_7FFFFFFF;
                    5'd1: f2i_out = 64'hFFFFFFFF_FFFFFFFF;
                    5'd2: f2i_out = 64'h7FFFFFFFFFFFFFFF;
                    5'd3: f2i_out = 64'hFFFFFFFFFFFFFFFF;
                    default: f2i_out = 64'd0;
                endcase
            end
        end else if ((funct7[0] && dp_zero1) || (!funct7[0] && sp_zero1)) begin
            f2i_out = 64'd0;
        end else begin
            if ($signed(f2i_exp) >= $signed(12'd63)) begin
                f2i_overflow = 1'b1;
            end else if ($signed(f2i_exp) < $signed(-12'd2)) begin
                f2i_shifted = 64'd0;
                f2i_guard = 1'b0;
                f2i_round = 1'b0;
                f2i_sticky = (f2i_temp != 64'd0);
            end else begin
                f2i_shifted = f2i_temp >> (12'd63 - f2i_exp);
                f2i_rem = f2i_temp << (f2i_exp + 12'd1);
                f2i_guard = f2i_rem[63];
                f2i_round = f2i_rem[62];
                f2i_sticky = (f2i_rem[61:0] != 62'd0);
            end
            f2i_round_up = 1'b0;
            case (rm)
                `RM_RNE: f2i_round_up = f2i_guard && (f2i_round || f2i_sticky || f2i_shifted[0]);
                `RM_RTZ: f2i_round_up = 1'b0;
                `RM_RDN: f2i_round_up = f2i_sign && (f2i_guard || f2i_round || f2i_sticky);
                `RM_RUP: f2i_round_up = !f2i_sign && (f2i_guard || f2i_round || f2i_sticky);
                `RM_RMM: f2i_round_up = f2i_guard;
                default: f2i_round_up = 1'b0;
            endcase
            f2i_rounded = f2i_shifted + (f2i_round_up ? 64'd1 : 64'd0);
            f2i_final = f2i_sign ? -f2i_rounded : f2i_rounded;
            if (f2i_guard || f2i_round || f2i_sticky) f2i_flags[`FF_NX] = 1'b1;
            case (rs2_val)
                5'd0: begin
                    if (f2i_overflow || $signed(f2i_final) > $signed(64'd2147483647) || $signed(f2i_final) < $signed(-64'd2147483648)) begin
                        f2i_flags[`FF_NV] = 1'b1;
                        f2i_flags[`FF_NX] = 1'b0;
                        f2i_out = f2i_sign ? 64'hFFFFFFFF_80000000 : 64'hFFFFFFFF_7FFFFFFF;
                    end else begin
                        f2i_out = {{32{f2i_final[31]}}, f2i_final[31:0]};
                    end
                end
                5'd1: begin
                    if (f2i_overflow || f2i_final[63:32] != 32'd0 || (f2i_sign && f2i_rounded != 64'd0)) begin
                        f2i_flags[`FF_NV] = 1'b1;
                        f2i_flags[`FF_NX] = 1'b0;
                        f2i_out = 64'hFFFFFFFF_FFFFFFFF;
                    end else begin
                        f2i_out = {{32{f2i_final[31]}}, f2i_final[31:0]};
                    end
                end
                5'd2: begin
                    if (f2i_overflow || (f2i_sign && !f2i_final[63] && f2i_final != 64'd0) || (!f2i_sign && f2i_final[63])) begin
                        f2i_flags[`FF_NV] = 1'b1;
                        f2i_flags[`FF_NX] = 1'b0;
                        f2i_out = f2i_sign ? 64'h8000000000000000 : 64'h7FFFFFFFFFFFFFFF;
                    end else begin
                        f2i_out = f2i_final;
                    end
                end
                5'd3: begin
                    if (f2i_overflow || (f2i_sign && f2i_rounded != 64'd0)) begin
                        f2i_flags[`FF_NV] = 1'b1;
                        f2i_flags[`FF_NX] = 1'b0;
                        f2i_out = 64'hFFFFFFFFFFFFFFFF;
                    end else begin
                        f2i_out = f2i_final;
                    end
                end
                default: f2i_out = 64'd0;
            endcase
        end
    end

    always @(*) begin
        i2f_out = 64'd0;
        i2f_flags = 5'd0;
        i2f_sign = 1'b0;
        i2f_abs = 64'd0;
        case (rs2_val)
            5'd0: begin
                i2f_sign = rs1[31];
                i2f_abs = i2f_sign ? -{{32{rs1[31]}}, rs1[31:0]} : {{32{1'b0}}, rs1[31:0]};
            end
            5'd1: begin
                i2f_sign = 1'b0;
                i2f_abs = {{32{1'b0}}, rs1[31:0]};
            end
            5'd2: begin
                i2f_sign = rs1[63];
                i2f_abs = i2f_sign ? -rs1 : rs1;
            end
            5'd3: begin
                i2f_sign = 1'b0;
                i2f_abs = rs1;
            end
            default: begin
            end
        endcase
        if (i2f_abs == 64'd0) begin
            if (funct7[0]) begin
                i2f_out = {i2f_sign, 11'd0, 52'd0};
            end else begin
                i2f_out = {32'hFFFFFFFF, i2f_sign, 8'd0, 23'd0};
            end
        end else begin
            i2f_lzc = 6'd0;
            for (i2 = 0; i2 < 64; i2 = i2 + 1) begin
                if (i2f_abs[63-i2] == 1'b0 && i2f_lzc == i2) begin
                    i2f_lzc = i2f_lzc + 6'd1;
                end
            end
            i2f_exp = 12'd63 - i2f_lzc;
            if (funct7[0]) begin
                if (i2f_lzc <= 11) begin
                    i2f_m = i2f_abs >> (11 - i2f_lzc);
                    i2f_rem = i2f_abs << (i2f_lzc + 53);
                    i2f_guard = i2f_rem[63];
                    i2f_round = i2f_rem[62];
                    i2f_sticky = (i2f_rem[61:0] != 62'd0);
                end else begin
                    i2f_m = i2f_abs << (i2f_lzc - 11);
                    i2f_guard = 1'b0;
                    i2f_round = 1'b0;
                    i2f_sticky = 1'b0;
                end
                i2f_round_up = 1'b0;
                case (rm)
                    `RM_RNE: i2f_round_up = i2f_guard && (i2f_round || i2f_sticky || i2f_m[0]);
                    `RM_RTZ: i2f_round_up = 1'b0;
                    `RM_RDN: i2f_round_up = i2f_sign && (i2f_guard || i2f_round || i2f_sticky);
                    `RM_RUP: i2f_round_up = !i2f_sign && (i2f_guard || i2f_round || i2f_sticky);
                    `RM_RMM: i2f_round_up = i2f_guard;
                    default: i2f_round_up = 1'b0;
                endcase
                i2f_m_rounded = i2f_m + (i2f_round_up ? 64'd1 : 64'd0);
                if (i2f_m_rounded[53]) begin
                    i2f_m_rounded = i2f_m_rounded >> 1;
                    i2f_exp = i2f_exp + 12'd1;
                end
                i2f_dp_exp = i2f_exp + 12'd1023;
                i2f_dp_frac = i2f_m_rounded[51:0];
                i2f_out = {i2f_sign, i2f_dp_exp, i2f_dp_frac};
                if (i2f_guard || i2f_round || i2f_sticky) i2f_flags[`FF_NX] = 1'b1;
            end else begin
                if (i2f_lzc <= 40) begin
                    i2f_m = i2f_abs >> (40 - i2f_lzc);
                    i2f_rem = i2f_abs << (i2f_lzc + 24);
                    i2f_guard = i2f_rem[63];
                    i2f_round = i2f_rem[62];
                    i2f_sticky = (i2f_rem[61:0] != 62'd0);
                end else begin
                    i2f_m = i2f_abs << (i2f_lzc - 40);
                    i2f_guard = 1'b0;
                    i2f_round = 1'b0;
                    i2f_sticky = 1'b0;
                end
                i2f_round_up = 1'b0;
                case (rm)
                    `RM_RNE: i2f_round_up = i2f_guard && (i2f_round || i2f_sticky || i2f_m[0]);
                    `RM_RTZ: i2f_round_up = 1'b0;
                    `RM_RDN: i2f_round_up = i2f_sign && (i2f_guard || i2f_round || i2f_sticky);
                    `RM_RUP: i2f_round_up = !i2f_sign && (i2f_guard || i2f_round || i2f_sticky);
                    `RM_RMM: i2f_round_up = i2f_guard;
                    default: i2f_round_up = 1'b0;
                endcase
                i2f_m_rounded = i2f_m + (i2f_round_up ? 64'd1 : 64'd0);
                if (i2f_m_rounded[24]) begin
                    i2f_m_rounded = i2f_m_rounded >> 1;
                    i2f_exp = i2f_exp + 12'd1;
                end
                i2f_sp_exp = i2f_exp + 12'd127;
                i2f_sp_frac = i2f_m_rounded[22:0];
                i2f_out = {32'hFFFFFFFF, i2f_sign, i2f_sp_exp, i2f_sp_frac};
                if (i2f_guard || i2f_round || i2f_sticky) i2f_flags[`FF_NX] = 1'b1;
            end
        end
    end

    always @(*) begin
        f2f_out = 64'd0;
        f2f_flags = 5'd0;
        if (funct7[0]) begin
            if (sp_nan1) begin
                f2f_out = 64'h7FF8000000000000;
                if (sp_snan1) f2f_flags[`FF_NV] = 1'b1;
            end else if (sp_inf1) begin
                f2f_out = {sp_s1, 11'h7FF, 52'd0};
            end else if (sp_zero1) begin
                f2f_out = {sp_s1, 11'd0, 52'd0};
            end else begin
                f2f_dp_exp = {4'd0, sp_e1} - 12'd127 + 12'd1023;
                f2f_out = {sp_s1, f2f_dp_exp[10:0], sp_f1, 29'd0};
            end
        end else begin
            if (dp_nan1) begin
                f2f_out = 64'hFFFFFFFF_7FC00000;
                if (dp_snan1) f2f_flags[`FF_NV] = 1'b1;
            end else if (dp_inf1) begin
                f2f_out = {32'hFFFFFFFF, dp_s1, 8'hFF, 23'd0};
            end else if (dp_zero1) begin
                f2f_out = {32'hFFFFFFFF, dp_s1, 8'd0, 23'd0};
            end else begin
                f2f_sp_m = {(dp_e1 == 11'd0) ? 1'b0 : 1'b1, dp_f1[51:29]};
                f2f_guard = dp_f1[28];
                f2f_round = dp_f1[27];
                f2f_sticky = (dp_f1[26:0] != 27'd0);
                f2f_round_up = 1'b0;
                case (rm)
                    `RM_RNE: f2f_round_up = f2f_guard && (f2f_round || f2f_sticky || f2f_sp_m[0]);
                    `RM_RTZ: f2f_round_up = 1'b0;
                    `RM_RDN: f2f_round_up = dp_s1 && (f2f_guard || f2f_round || f2f_sticky);
                    `RM_RUP: f2f_round_up = !dp_s1 && (f2f_guard || f2f_round || f2f_sticky);
                    `RM_RMM: f2f_round_up = f2f_guard;
                    default: f2f_round_up = 1'b0;
                endcase
                f2f_sp_m_rounded = f2f_sp_m + (f2f_round_up ? 25'd1 : 25'd0);
                f2f_dp_exp = {1'b0, dp_e1} - 12'd1023 + (f2f_sp_m_rounded[24] ? 12'd1 : 12'd0);
                if (f2f_sp_m_rounded[24]) begin
                    f2f_sp_m_rounded = f2f_sp_m_rounded >> 1;
                end
                if ($signed(f2f_dp_exp) >= $signed(12'd128)) begin
                    f2f_out = {32'hFFFFFFFF, dp_s1, 8'hFF, 23'd0};
                    f2f_flags[`FF_OF] = 1'b1;
                    f2f_flags[`FF_NX] = 1'b1;
                end else if ($signed(f2f_dp_exp) <= $signed(12'd0)) begin
                    f2f_out = {32'hFFFFFFFF, dp_s1, 8'd0, 23'd0};
                    f2f_flags[`FF_UF] = 1'b1;
                    f2f_flags[`FF_NX] = 1'b1;
                end else begin
                    f2f_sp_exp = f2f_dp_exp[7:0] + 8'd127;
                    f2f_sp_frac = f2f_sp_m_rounded[22:0];
                    f2f_out = {32'hFFFFFFFF, dp_s1, f2f_sp_exp, f2f_sp_frac};
                    if (f2f_guard || f2f_round || f2f_sticky) f2f_flags[`FF_NX] = 1'b1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            out_fp <= 64'd0;
            out_int <= 64'd0;
            we_gpr <= 1'b0;
            we_fpr <= 1'b0;
            fflags <= 5'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                out_fp <= 64'd0;
                out_int <= 64'd0;
                we_gpr <= 1'b0;
                we_fpr <= 1'b0;
                fflags <= 5'd0;
                case (funct7[6:2])
                    5'b11000, 5'b11001: begin
                        we_gpr <= 1'b1;
                        out_int <= f2i_out;
                        fflags <= f2i_flags | {unsupported_fmt, 4'd0}; // Flag NV if unsupported format
                    end
                    5'b11010, 5'b11011: begin
                        we_fpr <= 1'b1;
                        out_fp <= i2f_out;
                        fflags <= i2f_flags | {unsupported_fmt, 4'd0};
                    end
                    5'b01000, 5'b01001: begin
                        we_fpr <= 1'b1;
                        out_fp <= f2f_out;
                        fflags <= f2f_flags | {unsupported_fmt, 4'd0};
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
