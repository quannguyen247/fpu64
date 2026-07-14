`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module fpu64_classify (
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output wire ready_in,

    input wire [63:0] rs1,
    input wire is_double,

    output reg valid_out,
    input wire ready_out,

    output reg [63:0] result
);

    wire stall = valid_out && !ready_out;
    assign ready_in = !stall;

    wire sp_sign = rs1[31];
    wire [7:0] sp_exp = rs1[30:23];
    wire [22:0] sp_frac = rs1[22:0];

    wire sp_exp_zero = (sp_exp == 8'd0);
    wire sp_exp_max = (sp_exp == 8'hFF);
    wire sp_frac_zero = (sp_frac == 23'd0);

    wire dp_sign = rs1[63];
    wire [10:0] dp_exp = rs1[62:52];
    wire [51:0] dp_frac = rs1[51:0];

    wire dp_exp_zero = (dp_exp == 11'd0);
    wire dp_exp_max = (dp_exp == 11'h7FF);
    wire dp_frac_zero = (dp_frac == 52'd0);

    reg [9:0] class_bits;

    always @(*) begin
        class_bits = 10'd0;
        if (is_double) begin
            if (dp_exp_max && !dp_frac_zero && !dp_frac[51])
                class_bits[8] = 1'b1;
            else if (dp_exp_max && !dp_frac_zero && dp_frac[51])
                class_bits[9] = 1'b1;
            else if (dp_sign && dp_exp_max && dp_frac_zero)
                class_bits[0] = 1'b1;
            else if (!dp_sign && dp_exp_max && dp_frac_zero)
                class_bits[7] = 1'b1;
            else if (dp_sign && dp_exp_zero && dp_frac_zero)
                class_bits[3] = 1'b1;
            else if (!dp_sign && dp_exp_zero && dp_frac_zero)
                class_bits[4] = 1'b1;
            else if (dp_sign && dp_exp_zero && !dp_frac_zero)
                class_bits[2] = 1'b1;
            else if (!dp_sign && dp_exp_zero && !dp_frac_zero)
                class_bits[5] = 1'b1;
            else if (dp_sign)
                class_bits[1] = 1'b1;
            else
                class_bits[6] = 1'b1;
        end else begin
            if (sp_exp_max && !sp_frac_zero && !sp_frac[22])
                class_bits[8] = 1'b1;
            else if (sp_exp_max && !sp_frac_zero && sp_frac[22])
                class_bits[9] = 1'b1;
            else if (sp_sign && sp_exp_max && sp_frac_zero)
                class_bits[0] = 1'b1;
            else if (!sp_sign && sp_exp_max && sp_frac_zero)
                class_bits[7] = 1'b1;
            else if (sp_sign && sp_exp_zero && sp_frac_zero)
                class_bits[3] = 1'b1;
            else if (!sp_sign && sp_exp_zero && sp_frac_zero)
                class_bits[4] = 1'b1;
            else if (sp_sign && sp_exp_zero && !sp_frac_zero)
                class_bits[2] = 1'b1;
            else if (!sp_sign && sp_exp_zero && !sp_frac_zero)
                class_bits[5] = 1'b1;
            else if (sp_sign)
                class_bits[1] = 1'b1;
            else
                class_bits[6] = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            result <= 64'd0;
        end else if (!stall) begin
            valid_out <= valid_in;
            if (valid_in) begin
                result <= {54'd0, class_bits};
            end
        end
    end

endmodule
