`timescale 1ns / 1ps

module fpu64_result_arbiter (
    input wire clk,
    input wire rst_n,

    input wire addsub_valid,
    input wire [134:0] addsub_payload,
    output reg addsub_ready,

    input wire mul_valid,
    input wire [134:0] mul_payload,
    output reg mul_ready,

    input wire fma_valid,
    input wire [134:0] fma_payload,
    output reg fma_ready,

    input wire div_valid,
    input wire [134:0] div_payload,
    output reg div_ready,

    input wire sqrt_valid,
    input wire [134:0] sqrt_payload,
    output reg sqrt_ready,

    input wire compare_valid,
    input wire [134:0] compare_payload,
    output reg compare_ready,

    input wire classify_valid,
    input wire [134:0] classify_payload,
    output reg classify_ready,

    input wire convert_valid,
    input wire [134:0] convert_payload,
    output reg convert_ready,

    input wire misc_valid,
    input wire [134:0] misc_payload,
    output reg misc_ready,

    output wire m_axis_valid,
    input wire m_axis_ready,
    output wire [134:0] result_payload
);

    localparam [3:0] SOURCE_ADDSUB = 4'd0;
    localparam [3:0] SOURCE_MUL = 4'd1;
    localparam [3:0] SOURCE_FMA = 4'd2;
    localparam [3:0] SOURCE_DIV = 4'd3;
    localparam [3:0] SOURCE_SQRT = 4'd4;
    localparam [3:0] SOURCE_COMPARE = 4'd5;
    localparam [3:0] SOURCE_CLASSIFY = 4'd6;
    localparam [3:0] SOURCE_CONVERT = 4'd7;
    localparam [3:0] SOURCE_MISC = 4'd8;
    localparam [3:0] SOURCE_NONE = 4'd15;

    reg hold_valid;
    reg [3:0] hold_source;
    reg [3:0] selected_source;
    reg selected_valid;
    reg [134:0] selected_payload;

    assign m_axis_valid = selected_valid;
    assign result_payload = selected_payload;

    always @(*) begin
        selected_source = SOURCE_NONE;
        if (hold_valid) begin
            selected_source = hold_source;
        end else if (addsub_valid) begin
            selected_source = SOURCE_ADDSUB;
        end else if (mul_valid) begin
            selected_source = SOURCE_MUL;
        end else if (fma_valid) begin
            selected_source = SOURCE_FMA;
        end else if (div_valid) begin
            selected_source = SOURCE_DIV;
        end else if (sqrt_valid) begin
            selected_source = SOURCE_SQRT;
        end else if (compare_valid) begin
            selected_source = SOURCE_COMPARE;
        end else if (classify_valid) begin
            selected_source = SOURCE_CLASSIFY;
        end else if (convert_valid) begin
            selected_source = SOURCE_CONVERT;
        end else if (misc_valid) begin
            selected_source = SOURCE_MISC;
        end
    end

    always @(*) begin
        selected_valid = 1'b0;
        selected_payload = 135'd0;
        addsub_ready = 1'b0;
        mul_ready = 1'b0;
        fma_ready = 1'b0;
        div_ready = 1'b0;
        sqrt_ready = 1'b0;
        compare_ready = 1'b0;
        classify_ready = 1'b0;
        convert_ready = 1'b0;
        misc_ready = 1'b0;
        case (selected_source)
            SOURCE_ADDSUB: begin
                selected_valid = addsub_valid;
                selected_payload = addsub_payload;
                addsub_ready = m_axis_ready && addsub_valid;
            end
            SOURCE_MUL: begin
                selected_valid = mul_valid;
                selected_payload = mul_payload;
                mul_ready = m_axis_ready && mul_valid;
            end
            SOURCE_FMA: begin
                selected_valid = fma_valid;
                selected_payload = fma_payload;
                fma_ready = m_axis_ready && fma_valid;
            end
            SOURCE_DIV: begin
                selected_valid = div_valid;
                selected_payload = div_payload;
                div_ready = m_axis_ready && div_valid;
            end
            SOURCE_SQRT: begin
                selected_valid = sqrt_valid;
                selected_payload = sqrt_payload;
                sqrt_ready = m_axis_ready && sqrt_valid;
            end
            SOURCE_COMPARE: begin
                selected_valid = compare_valid;
                selected_payload = compare_payload;
                compare_ready = m_axis_ready && compare_valid;
            end
            SOURCE_CLASSIFY: begin
                selected_valid = classify_valid;
                selected_payload = classify_payload;
                classify_ready = m_axis_ready && classify_valid;
            end
            SOURCE_CONVERT: begin
                selected_valid = convert_valid;
                selected_payload = convert_payload;
                convert_ready = m_axis_ready && convert_valid;
            end
            SOURCE_MISC: begin
                selected_valid = misc_valid;
                selected_payload = misc_payload;
                misc_ready = m_axis_ready && misc_valid;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_valid <= 1'b0;
            hold_source <= SOURCE_NONE;
        end else if (hold_valid) begin
            if (selected_valid && m_axis_ready) begin
                hold_valid <= 1'b0;
            end
        end else if (selected_valid && !m_axis_ready) begin
            hold_valid <= 1'b1;
            hold_source <= selected_source;
        end
    end

endmodule
