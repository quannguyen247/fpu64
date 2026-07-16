`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_fma;

    reg clk;
    reg rst_n;
    reg s_axis_valid;
    wire s_axis_ready;
    reg [63:0] rs1;
    reg [63:0] rs2;
    reg [63:0] rs3;
    reg [3:0] op;
    reg [2:0] funct3;
    reg [6:0] funct7;
    reg [4:0] rs2_val;
    reg is_double;
    wire m_axis_valid;
    reg m_axis_ready;
    wire [63:0] out_fp;
    wire [63:0] out_int;
    wire we_gpr;
    wire we_fpr;
    wire [4:0] fflags;

    integer vector_file;
    integer scan_count;
    integer vector_count;
    integer pass_count;
    integer fused_diff_count;
    integer hold_count;
    integer back_to_back_index;
    reg vector_is_double;
    reg [3:0] vector_op;
    reg [2:0] vector_rm;
    reg [63:0] vector_rs1;
    reg [63:0] vector_rs2;
    reg [63:0] vector_rs3;
    reg [63:0] vector_result;
    reg [4:0] vector_flags;
    reg vector_fused_diff;
    reg [63:0] held_result;
    reg [4:0] held_flags;
    reg [63:0] back_to_back_expected [0:3];

    fpu64_top u_fpu (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_valid(s_axis_valid),
        .s_axis_ready(s_axis_ready),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .rs2_val(rs2_val),
        .is_double(is_double),
        .m_axis_valid(m_axis_valid),
        .m_axis_ready(m_axis_ready),
        .out_fp(out_fp),
        .out_int(out_int),
        .we_gpr(we_gpr),
        .we_fpr(we_fpr),
        .fflags(fflags)
    );

    always #5 clk = ~clk;

    task issue_fma;
        input [63:0] issue_rs1;
        input [63:0] issue_rs2;
        input [63:0] issue_rs3;
        input [3:0] issue_op;
        input [2:0] issue_rm;
        input issue_is_double;
        begin
            @(negedge clk);
            rs1 = issue_rs1;
            rs2 = issue_rs2;
            rs3 = issue_rs3;
            op = issue_op;
            funct3 = issue_rm;
            is_double = issue_is_double;
            s_axis_valid = 1'b1;
            while (!s_axis_ready) @(negedge clk);
            @(negedge clk);
            s_axis_valid = 1'b0;
        end
    endtask

    task receive_and_check;
        input [63:0] expected_result;
        input [4:0] expected_flags;
        begin
            while (!m_axis_valid) begin
                @(posedge clk);
                #1;
            end
            if (out_fp !== expected_result || fflags !== expected_flags || !we_fpr || we_gpr) begin
                $display("FMA mismatch index=%0d op=%h double=%b rm=%h rs1=%h rs2=%h rs3=%h expected=%h/%b actual=%h/%b we_fpr=%b we_gpr=%b",
                         vector_count, op, is_double, funct3, rs1, rs2, rs3,
                         expected_result, expected_flags, out_fp, fflags, we_fpr, we_gpr);
                $fatal(1);
            end
            pass_count = pass_count + 1;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        s_axis_valid = 1'b0;
        rs1 = 64'd0;
        rs2 = 64'd0;
        rs3 = 64'd0;
        op = `F_MADD;
        funct3 = `RM_RNE;
        funct7 = 7'd0;
        rs2_val = 5'd0;
        is_double = 1'b0;
        m_axis_ready = 1'b1;
        vector_count = 0;
        pass_count = 0;
        fused_diff_count = 0;
        back_to_back_expected[0] = 64'hFFFFFFFF_40500000;
        back_to_back_expected[1] = 64'hFFFFFFFF_40300000;
        back_to_back_expected[2] = 64'hFFFFFFFF_C0300000;
        back_to_back_expected[3] = 64'hFFFFFFFF_C0500000;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        vector_file = $fopen("Implementation/vector/fma_vectors.hex", "r");
        if (vector_file == 0) begin
            $display("Unable to open FMA vector file");
            $fatal(1);
        end

        scan_count = $fscanf(vector_file, "%h %h %h %h %h %h %h %h %h\n",
                             vector_is_double, vector_op, vector_rm, vector_rs1, vector_rs2,
                             vector_rs3, vector_result, vector_flags, vector_fused_diff);
        while (scan_count == 9) begin
            vector_count = vector_count + 1;
            if (vector_fused_diff) fused_diff_count = fused_diff_count + 1;
            issue_fma(vector_rs1, vector_rs2, vector_rs3, vector_op, vector_rm, vector_is_double);
            receive_and_check(vector_result, vector_flags);
            scan_count = $fscanf(vector_file, "%h %h %h %h %h %h %h %h %h\n",
                                 vector_is_double, vector_op, vector_rm, vector_rs1, vector_rs2,
                                 vector_rs3, vector_result, vector_flags, vector_fused_diff);
        end
        $fclose(vector_file);
        if (vector_count != 1441 || fused_diff_count == 0) begin
            $display("FMA vector coverage failure vectors=%0d fused_distinguishing=%0d", vector_count, fused_diff_count);
            $fatal(1);
        end

        m_axis_ready = 1'b0;
        issue_fma(64'hFFFFFFFF_3FC00000, 64'hFFFFFFFF_40000000, 64'hFFFFFFFF_3E800000,
                  `F_MADD, `RM_RNE, 1'b0);
        while (!m_axis_valid) begin
            @(posedge clk);
            #1;
        end
        held_result = out_fp;
        held_flags = fflags;
        for (hold_count = 0; hold_count < 4; hold_count = hold_count + 1) begin
            @(posedge clk);
            #1;
            if (!m_axis_valid || out_fp !== held_result || fflags !== held_flags) begin
                $display("FMA backpressure stability failure valid=%b result=%h flags=%b", m_axis_valid, out_fp, fflags);
                $fatal(1);
            end
        end
        if (held_result !== 64'hFFFFFFFF_40500000 || held_flags !== 5'd0) begin
            $display("FMA backpressure result failure result=%h flags=%b", held_result, held_flags);
            $fatal(1);
        end
        pass_count = pass_count + 1;
        @(negedge clk);
        m_axis_ready = 1'b1;
        @(posedge clk);
        #1;

        issue_fma(64'h3FF8000000000000, 64'h4000000000000000, 64'h3FD0000000000000,
                  `F_MADD, `RM_RNE, 1'b1);
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        if (m_axis_valid) begin
            $display("FMA reset failed to clear valid");
            $fatal(1);
        end
        @(negedge clk);
        rst_n = 1'b1;
        issue_fma(64'h3FF8000000000000, 64'h4000000000000000, 64'h3FD0000000000000,
                  `F_MADD, `RM_RNE, 1'b1);
        receive_and_check(64'h400A000000000000, 5'd0);

        @(negedge clk);
        rs1 = 64'hFFFFFFFF_3FC00000;
        rs2 = 64'hFFFFFFFF_40000000;
        rs3 = 64'hFFFFFFFF_3E800000;
        funct3 = `RM_RNE;
        is_double = 1'b0;
        op = `F_MADD;
        s_axis_valid = 1'b1;
        @(negedge clk);
        op = `F_MSUB;
        @(negedge clk);
        op = `F_NMSUB;
        @(negedge clk);
        op = `F_NMADD;
        @(negedge clk);
        s_axis_valid = 1'b0;
        for (back_to_back_index = 0; back_to_back_index < 4; back_to_back_index = back_to_back_index + 1) begin
            while (!m_axis_valid) begin
                @(posedge clk);
                #1;
            end
            if (out_fp !== back_to_back_expected[back_to_back_index] || fflags !== 5'd0) begin
                $display("FMA back-to-back failure index=%0d expected=%h actual=%h flags=%b",
                         back_to_back_index, back_to_back_expected[back_to_back_index], out_fp, fflags);
                $fatal(1);
            end
            pass_count = pass_count + 1;
            @(posedge clk);
            #1;
        end

        $display("FMA TEST PASS vectors=%0d fused_distinguishing=%0d checks=%0d", vector_count, fused_diff_count, pass_count);
        $finish;
    end

endmodule
