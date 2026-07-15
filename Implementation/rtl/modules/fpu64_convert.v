`timescale 1ns / 1ps

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
    wire unsupported_fmt = funct7[1];
    wire [63:0] f2i_result;
    wire [4:0] f2i_flags;
    wire [63:0] i2f_result;
    wire [4:0] i2f_flags;
    wire [63:0] f2f_result;
    wire [4:0] f2f_flags;

    assign ready_in = !stall;

    fpu64_convert_f2i u_f2i (
        .rs1(rs1),
        .rs2_val(rs2_val),
        .is_double(funct7[0]),
        .rm(rm),
        .result(f2i_result),
        .fflags(f2i_flags)
    );

    fpu64_convert_i2f u_i2f (
        .rs1(rs1),
        .rs2_val(rs2_val),
        .is_double(funct7[0]),
        .rm(rm),
        .result(i2f_result),
        .fflags(i2f_flags)
    );

    fpu64_convert_f2f u_f2f (
        .rs1(rs1),
        .to_double(funct7[0]),
        .rm(rm),
        .result(f2f_result),
        .fflags(f2f_flags)
    );

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
                        out_int <= f2i_result;
                        fflags <= f2i_flags | {unsupported_fmt, 4'd0};
                    end
                    5'b11010, 5'b11011: begin
                        we_fpr <= 1'b1;
                        out_fp <= i2f_result;
                        fflags <= i2f_flags | {unsupported_fmt, 4'd0};
                    end
                    5'b01000, 5'b01001: begin
                        we_fpr <= 1'b1;
                        out_fp <= f2f_result;
                        fflags <= f2f_flags | {unsupported_fmt, 4'd0};
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
