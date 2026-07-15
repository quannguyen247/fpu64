`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_compare (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire [63:0] rs2,

    input wire [2:0] funct3,
    input wire is_double,

    output reg valid_out,
    input wire ready_out,

    output reg [63:0] result,
    output reg [4:0] fflags
);

    wire stall = valid_out && !ready_out;
    assign ready_in = !stall;

    wire [7:0] sp_e1 = rs1[30:23];
    wire [22:0] sp_f1 = rs1[22:0];
    wire [7:0] sp_e2 = rs2[30:23];
    wire [22:0] sp_f2 = rs2[22:0];

    wire sp_nan1 = (sp_e1 == 8'hFF) && (sp_f1 != 23'd0);
    wire sp_nan2 = (sp_e2 == 8'hFF) && (sp_f2 != 23'd0);
    wire sp_snan1 = sp_nan1 && !sp_f1[22];
    wire sp_snan2 = sp_nan2 && !sp_f2[22];
    wire sp_any_nan = sp_nan1 || sp_nan2;
    wire sp_any_snan = sp_snan1 || sp_snan2;

    wire [10:0] dp_e1 = rs1[62:52];
    wire [51:0] dp_f1 = rs1[51:0];
    wire [10:0] dp_e2 = rs2[62:52];
    wire [51:0] dp_f2 = rs2[51:0];

    wire dp_nan1 = (dp_e1 == 11'h7FF) && (dp_f1 != 52'd0);
    wire dp_nan2 = (dp_e2 == 11'h7FF) && (dp_f2 != 52'd0);
    wire dp_snan1 = dp_nan1 && !dp_f1[51];
    wire dp_snan2 = dp_nan2 && !dp_f2[51];
    wire dp_any_nan = dp_nan1 || dp_nan2;
    wire dp_any_snan = dp_snan1 || dp_snan2;

    wire any_nan = is_double ? dp_any_nan : sp_any_nan;
    wire any_snan = is_double ? dp_any_snan : sp_any_snan;

    wire cmp_lt;
    wire cmp_eq;
    fpu64_compare_logic u_cmp_logic (
        .rs1(rs1),
        .rs2(rs2),
        .is_double(is_double),
        .is_lt(cmp_lt),
        .is_eq(cmp_eq)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
            fflags <= 5'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                result <= 64'd0;
                fflags <= 5'd0;
                case (funct3)
                    3'b010: begin
                        if (any_nan) begin
                            result <= 64'd0;
                            if (any_snan) fflags[`FF_NV] <= 1'b1;
                        end else begin
                            result <= cmp_eq ? 64'd1 : 64'd0;
                        end
                    end
                    3'b001: begin
                        if (any_nan) begin
                            result <= 64'd0;
                            fflags[`FF_NV] <= 1'b1;
                        end else begin
                            result <= cmp_lt ? 64'd1 : 64'd0;
                        end
                    end
                    3'b000: begin
                        if (any_nan) begin
                            result <= 64'd0;
                            fflags[`FF_NV] <= 1'b1;
                        end else begin
                            result <= (cmp_lt || cmp_eq) ? 64'd1 : 64'd0;
                        end
                    end
                    default: begin
                        result <= 64'd0;
                    end
                endcase
            end
        end
    end

endmodule
