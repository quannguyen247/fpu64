`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_comprehensive;

    reg clk;
    reg rst_n;

    reg s_axis_valid;
    wire s_axis_ready;

    reg [63:0] rs1;
    reg [63:0] rs2;
    reg [63:0] rs3;
    reg [3:0]  op;
    reg [2:0]  funct3;
    reg [6:0]  funct7;
    reg [4:0]  rs2_val;
    reg        is_double;

    wire m_axis_valid;
    reg m_axis_ready;

    wire [63:0] out_fp;
    wire [63:0] out_int;
    wire        we_gpr;
    wire        we_fpr;
    wire [4:0]  fflags;

    reg [63:0] o_fp;
    reg [63:0] o_int;
    reg        o_we_gpr;
    reg        o_we_fpr;
    reg [4:0]  o_fflags;

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

    task fpu_issue(
        input [63:0] i_rs1,
        input [63:0] i_rs2,
        input [3:0] i_op,
        input [2:0] i_funct3,
        input [6:0] i_funct7,
        input [4:0] i_rs2_val,
        input i_is_double
    );
        begin
            rs1 = i_rs1;
            rs2 = i_rs2;
            op = i_op;
            funct3 = i_funct3;
            funct7 = i_funct7;
            rs2_val = i_rs2_val;
            is_double = i_is_double;
            
            s_axis_valid = 1;
            @(posedge clk);
            while (!s_axis_ready) @(posedge clk);
            s_axis_valid = 0;
        end
    endtask

    task fpu_receive();
        begin
            m_axis_ready = 1;
            while (!m_axis_valid) @(posedge clk);
            o_fp = out_fp;
            o_int = out_int;
            o_we_gpr = we_gpr;
            o_we_fpr = we_fpr;
            o_fflags = fflags;
            @(posedge clk);
            m_axis_ready = 0;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        s_axis_valid = 0;
        m_axis_ready = 0;
        rs3 = 64'd0;

        // Reset
        #20;
        rst_n = 1;
        #20;

        // --- SP ADD ---
        fpu_issue(64'h0000000040A00000, 64'h0000000040400000, `F_ADD, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h41000000) begin
            $display("Fail SP ADD: %h", o_fp);
            $finish;
        end

        // --- DP ADD ---
        fpu_issue(64'h4014000000000000, 64'h4008000000000000, `F_ADD, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h4020000000000000) begin
            $display("Fail DP ADD: %h", o_fp);
            $finish;
        end

        // --- SP SUB ---
        fpu_issue(64'h0000000040A00000, 64'h0000000040400000, `F_SUB, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h40000000) begin
            $display("Fail SP SUB: %h", o_fp);
            $finish;
        end

        // --- DP SUB ---
        fpu_issue(64'h4014000000000000, 64'h4008000000000000, `F_SUB, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h4000000000000000) begin
            $display("Fail DP SUB: %h", o_fp);
            $finish;
        end

        // --- SP MUL ---
        fpu_issue(64'h0000000040A00000, 64'h0000000040400000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h41700000) begin
            $display("Fail SP MUL: %h", o_fp);
            $finish;
        end

        // --- DP MUL ---
        fpu_issue(64'h4014000000000000, 64'h4008000000000000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h402E000000000000) begin
            $display("Fail DP MUL: %h", o_fp);
            $finish;
        end

        // --- SP DIV ---
        fpu_issue(64'h0000000040A00000, 64'h0000000040000000, `F_DIV, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h40200000) begin
            $display("Fail SP DIV: %h", o_fp);
            $finish;
        end

        // --- DP DIV ---
        fpu_issue(64'h4014000000000000, 64'h4000000000000000, `F_DIV, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h4004000000000000) begin
            $display("Fail DP DIV: %h", o_fp);
            $finish;
        end

        // --- SP SQRT ---
        fpu_issue(64'h0000000041100000, 64'd0, `F_SQRT, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h40400000) begin
            $display("Fail SP SQRT: %h", o_fp);
            $finish;
        end

        // --- DP SQRT ---
        fpu_issue(64'h4022000000000000, 64'd0, `F_SQRT, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h4008000000000000) begin
            $display("Fail DP SQRT: %h", o_fp);
            $finish;
        end

        // --- SP CMP LT ---
        fpu_issue(64'h0000000040A00000, 64'h0000000040400000, `F_COMP, 3'b001, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'd0) begin
            $display("Fail SP CMP LT: %h", o_int);
            $finish;
        end

        // --- DP CMP LT ---
        fpu_issue(64'h4008000000000000, 64'h4014000000000000, `F_COMP, 3'b001, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_int !== 64'd1) begin
            $display("Fail DP CMP LT: %h", o_int);
            $finish;
        end

        // --- SP CLASS ---
        fpu_issue(64'h0000000040A00000, 64'd0, `F_CLASS, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'b0001000000) begin
            $display("Fail SP CLASS: %h", o_int);
            $finish;
        end

        // --- DP CLASS ---
        fpu_issue(64'hBFF0000000000000, 64'd0, `F_CLASS, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_int !== 64'b0000000010) begin
            $display("Fail DP CLASS: %h", o_int);
            $finish;
        end

        // --- CVT SP to W ---
        fpu_issue(64'h0000000041700000, 64'd0, `F_CVT, `RM_RNE, 7'b1100000, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'd15) begin
            $display("Fail CVT SP to W: %h", o_int);
            $finish;
        end

        // --- CVT DP to W ---
        fpu_issue(64'h402E000000000000, 64'd0, `F_CVT, `RM_RNE, 7'b1100001, 5'd0, 1);
        fpu_receive();
        if (o_int !== 64'd15) begin
            $display("Fail CVT DP to W: %h", o_int);
            $finish;
        end

        // --- CVT W to SP ---
        fpu_issue(64'd15, 64'd0, `F_CVT, `RM_RNE, 7'b1101000, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h41700000) begin
            $display("Fail CVT W to SP: %h", o_fp);
            $finish;
        end

        // --- CVT W to DP ---
        fpu_issue(64'd15, 64'd0, `F_CVT, `RM_RNE, 7'b1101001, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h402E000000000000) begin
            $display("Fail CVT W to DP: %h", o_fp);
            $finish;
        end

        // --- CVT DP to SP ---
        fpu_issue(64'h402E000000000000, 64'd0, `F_CVT, `RM_RNE, 7'b0100000, 5'd1, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h41700000) begin
            $display("Fail CVT DP to SP: %h", o_fp);
            $finish;
        end

        // --- CVT SP to DP ---
        fpu_issue(64'h0000000041700000, 64'd0, `F_CVT, `RM_RNE, 7'b0100001, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h402E000000000000) begin
            $display("Fail CVT SP to DP: %h", o_fp);
            $finish;
        end

        fpu_issue(64'h000000007FC00001, 64'h000000003F800000, `F_COMP, 3'b010, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'd0 || o_fflags !== 5'd0) begin
            $display("Fail SP FEQ QNAN: result=%h fflags=%b", o_int, o_fflags);
            $finish;
        end

        fpu_issue(64'h000000007F800001, 64'h000000003F800000, `F_COMP, 3'b010, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'd0 || o_fflags !== 5'b10000) begin
            $display("Fail SP FEQ SNAN: result=%h fflags=%b", o_int, o_fflags);
            $finish;
        end

        fpu_issue(64'h000000007FC00001, 64'h000000003F800000, `F_COMP, 3'b001, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_int !== 64'd0 || o_fflags !== 5'b10000) begin
            $display("Fail SP FLT QNAN: result=%h fflags=%b", o_int, o_fflags);
            $finish;
        end

        fpu_issue(64'h0000000000000000, 64'h7FF0000000000000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h7FF8000000000000 || o_fflags !== 5'b10000) begin
            $display("Fail DP MUL ZERO INF: result=%h fflags=%b", o_fp, o_fflags);
            $finish;
        end

        fpu_issue(64'h7FEFFFFFFFFFFFFF, 64'h4000000000000000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h7FF0000000000000 || o_fflags !== 5'b00101) begin
            $display("Fail DP MUL OVERFLOW: result=%h fflags=%b", o_fp, o_fflags);
            $finish;
        end

        fpu_issue(64'h0010000000000000, 64'h3FE0000000000000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h0008000000000000 || o_fflags !== 5'd0) begin
            $display("Fail DP MUL EXACT SUBNORMAL: result=%h fflags=%b", o_fp, o_fflags);
            $finish;
        end

        fpu_issue(64'hD4A4820F210BE1AC, 64'h546435D585DC1D80, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'hE919E7936A68F943) begin
            $display("Fail DP MUL RANDOM 1: %h", o_fp);
            $finish;
        end

        fpu_issue(64'hD485D1CA003D7AC0, 64'h54820C614BEC59E8, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'hE9189CE54727AD89) begin
            $display("Fail DP MUL RANDOM 2: %h", o_fp);
            $finish;
        end

        fpu_issue(64'h549AA360D8EF68A8, 64'h54A0D289C472609E, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        fpu_receive();
        if (o_fp !== 64'h694C01E68E0BBFB6) begin
            $display("Fail DP MUL RANDOM 3: %h", o_fp);
            $finish;
        end

        fpu_issue(64'hFFFFFFFF4F578A8B, 64'hFFFFFFFFD0021798, `F_MUL, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'hDFDB1070) begin
            $display("Fail SP MUL RANDOM 1: %h", o_fp);
            $finish;
        end

        fpu_issue(64'hFFFFFFFFD0015405, 64'hFFFFFFFFCFCF82E1, `F_MUL, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'h6051AA1D) begin
            $display("Fail SP MUL RANDOM 2: %h", o_fp);
            $finish;
        end

        fpu_issue(64'hFFFFFFFFCFDCBE2B, 64'hFFFFFFFF4FD1478A, `F_MUL, `RM_RNE, 7'd0, 5'd0, 0);
        fpu_receive();
        if (o_fp[31:0] !== 32'hE03474F1) begin
            $display("Fail SP MUL RANDOM 3: %h", o_fp);
            $finish;
        end

        fpu_issue(64'h4000000000000000, 64'h4008000000000000, `F_MUL, `RM_RNE, 7'd0, 5'd0, 1);
        m_axis_ready = 0;
        while (!m_axis_valid) @(posedge clk);
        o_fp = out_fp;
        repeat (3) begin
            @(posedge clk);
            if (!m_axis_valid || out_fp !== o_fp) begin
                $display("Fail DP MUL BACKPRESSURE: valid=%b result=%h", m_axis_valid, out_fp);
                $finish;
            end
        end
        if (o_fp !== 64'h4018000000000000) begin
            $display("Fail DP MUL BACKPRESSURE RESULT: %h", o_fp);
            $finish;
        end
        m_axis_ready = 1;
        @(posedge clk);
        m_axis_ready = 0;

        $display("ALL COMPREHENSIVE TESTS PASS");
        $finish;
    end

endmodule
