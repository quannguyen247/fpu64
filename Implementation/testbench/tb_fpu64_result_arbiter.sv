`timescale 1ns / 1ps

module tb_fpu64_result_arbiter;

    reg clk;
    reg rst_n;
    reg addsub_valid;
    reg [134:0] addsub_payload;
    wire addsub_ready;
    reg mul_valid;
    reg [134:0] mul_payload;
    wire mul_ready;
    reg fma_valid;
    reg [134:0] fma_payload;
    wire fma_ready;
    reg div_valid;
    reg [134:0] div_payload;
    wire div_ready;
    reg sqrt_valid;
    reg [134:0] sqrt_payload;
    wire sqrt_ready;
    reg compare_valid;
    reg [134:0] compare_payload;
    wire compare_ready;
    reg classify_valid;
    reg [134:0] classify_payload;
    wire classify_ready;
    reg convert_valid;
    reg [134:0] convert_payload;
    wire convert_ready;
    reg misc_valid;
    reg [134:0] misc_payload;
    wire misc_ready;
    wire m_axis_valid;
    reg m_axis_ready;
    wire [134:0] result_payload;
    integer error_count;

    fpu64_result_arbiter u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .addsub_valid(addsub_valid),
        .addsub_payload(addsub_payload),
        .addsub_ready(addsub_ready),
        .mul_valid(mul_valid),
        .mul_payload(mul_payload),
        .mul_ready(mul_ready),
        .fma_valid(fma_valid),
        .fma_payload(fma_payload),
        .fma_ready(fma_ready),
        .div_valid(div_valid),
        .div_payload(div_payload),
        .div_ready(div_ready),
        .sqrt_valid(sqrt_valid),
        .sqrt_payload(sqrt_payload),
        .sqrt_ready(sqrt_ready),
        .compare_valid(compare_valid),
        .compare_payload(compare_payload),
        .compare_ready(compare_ready),
        .classify_valid(classify_valid),
        .classify_payload(classify_payload),
        .classify_ready(classify_ready),
        .convert_valid(convert_valid),
        .convert_payload(convert_payload),
        .convert_ready(convert_ready),
        .misc_valid(misc_valid),
        .misc_payload(misc_payload),
        .misc_ready(misc_ready),
        .m_axis_valid(m_axis_valid),
        .m_axis_ready(m_axis_ready),
        .result_payload(result_payload)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        addsub_valid = 1'b0;
        addsub_payload = {64'h0123456789ABCDEF, 64'h0, 1'b0, 1'b1, 5'h01};
        mul_valid = 1'b0;
        mul_payload = 135'd0;
        fma_valid = 1'b0;
        fma_payload = 135'd0;
        div_valid = 1'b0;
        div_payload = 135'd0;
        sqrt_valid = 1'b0;
        sqrt_payload = 135'd0;
        compare_valid = 1'b0;
        compare_payload = 135'd0;
        classify_valid = 1'b0;
        classify_payload = 135'd0;
        convert_valid = 1'b0;
        convert_payload = 135'd0;
        misc_valid = 1'b0;
        misc_payload = {64'hFEDCBA9876543210, 64'h1122334455667788, 1'b1, 1'b0, 5'h10};
        m_axis_ready = 1'b0;
        error_count = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        misc_valid = 1'b1;

        @(posedge clk);
        @(negedge clk);
        addsub_valid = 1'b1;
        #1;
        if (!m_axis_valid || result_payload !== misc_payload) begin
            error_count = error_count + 1;
            $display("ARBITER ERROR: stalled source was not held");
        end
        if (addsub_ready || misc_ready) begin
            error_count = error_count + 1;
            $display("ARBITER ERROR: ready asserted while output stalled");
        end

        m_axis_ready = 1'b1;
        #1;
        if (!misc_ready || addsub_ready || result_payload !== misc_payload) begin
            error_count = error_count + 1;
            $display("ARBITER ERROR: held source handshake was incorrect");
        end

        @(posedge clk);
        @(negedge clk);
        misc_valid = 1'b0;
        #1;
        if (!m_axis_valid || !addsub_ready || result_payload !== addsub_payload) begin
            error_count = error_count + 1;
            $display("ARBITER ERROR: pending priority source was not selected");
        end

        @(posedge clk);
        @(negedge clk);
        addsub_valid = 1'b0;
        #1;
        if (m_axis_valid) begin
            error_count = error_count + 1;
            $display("ARBITER ERROR: output valid remained asserted");
        end

        if (error_count == 0) begin
            $display("RESULT ARBITER TEST PASS");
        end else begin
            $display("RESULT ARBITER TEST FAIL errors=%0d", error_count);
        end
        $finish;
    end

endmodule
