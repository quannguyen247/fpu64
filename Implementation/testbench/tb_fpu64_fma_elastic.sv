`timescale 1ns / 1ps
`include "fpu64_defs.vh"

module tb_fpu64_fma_elastic;

    localparam integer TXN_COUNT = 16;
    localparam integer FORMAT_COUNT = 8;
    localparam integer EXPECTED_LATENCY = 14;
    localparam integer TIMEOUT_CYCLES = 2000;
    localparam integer PHASE_IDLE = 0;
    localparam integer PHASE_NOMINAL = 1;
    localparam integer PHASE_STRESS = 2;

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

    reg vector_is_double [0:TXN_COUNT-1];
    reg [3:0] vector_op [0:TXN_COUNT-1];
    reg [2:0] vector_rm [0:TXN_COUNT-1];
    reg [63:0] vector_rs1 [0:TXN_COUNT-1];
    reg [63:0] vector_rs2 [0:TXN_COUNT-1];
    reg [63:0] vector_rs3 [0:TXN_COUNT-1];
    reg [63:0] expected_result [0:TXN_COUNT-1];
    reg [4:0] expected_flags [0:TXN_COUNT-1];
    integer accept_cycle [0:TXN_COUNT-1];
    integer receive_cycle [0:TXN_COUNT-1];

    integer phase;
    integer cycle_count;
    integer accept_count;
    integer receive_count;
    integer error_count;
    integer input_stall_cycles;
    integer output_stall_run;
    integer max_output_stall_run;
    integer random_ready_low_cycles;
    integer random_low_run;
    integer check_index;
    integer wait_count;
    reg output_stalled_previous;
    reg input_stalled_previous;
    reg [134:0] held_output_payload;
    reg [211:0] held_input_payload;
    reg [15:0] ready_lfsr;
    reg stress_random_active;

    integer vector_file;
    integer scan_count;
    integer load_count;
    integer sp_count;
    integer dp_count;
    integer scan_index;
    integer duplicate_result;
    reg scan_is_double;
    reg [3:0] scan_op;
    reg [2:0] scan_rm;
    reg [63:0] scan_rs1;
    reg [63:0] scan_rs2;
    reg [63:0] scan_rs3;
    reg [63:0] scan_result;
    reg [4:0] scan_flags;
    reg scan_fused_diff;

    wire [134:0] observed_output_payload;
    wire [211:0] observed_input_payload;

    assign observed_output_payload = {out_fp, out_int, we_gpr, we_fpr, fflags};
    assign observed_input_payload = {rs1, rs2, rs3, op, funct3, funct7, rs2_val, is_double};

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

    task load_vectors;
        begin
            vector_file = $fopen("Implementation/vector/fma_vectors.hex", "r");
            if (vector_file == 0) begin
                $display("Unable to open FMA vector file");
                $fatal(1);
            end
            load_count = 0;
            sp_count = 0;
            dp_count = 0;
            scan_count = $fscanf(vector_file, "%h %h %h %h %h %h %h %h %h\n",
                                 scan_is_double, scan_op, scan_rm, scan_rs1, scan_rs2,
                                 scan_rs3, scan_result, scan_flags, scan_fused_diff);
            while (scan_count == 9 && load_count < TXN_COUNT) begin
                duplicate_result = 0;
                for (scan_index = 0; scan_index < load_count; scan_index = scan_index + 1) begin
                    if (scan_result === expected_result[scan_index] &&
                        scan_flags === expected_flags[scan_index]) begin
                        duplicate_result = 1;
                    end
                end
                if (!duplicate_result &&
                    ((!scan_is_double && sp_count < FORMAT_COUNT) ||
                     (scan_is_double && dp_count < FORMAT_COUNT))) begin
                    vector_is_double[load_count] = scan_is_double;
                    vector_op[load_count] = scan_op;
                    vector_rm[load_count] = scan_rm;
                    vector_rs1[load_count] = scan_rs1;
                    vector_rs2[load_count] = scan_rs2;
                    vector_rs3[load_count] = scan_rs3;
                    expected_result[load_count] = scan_result;
                    expected_flags[load_count] = scan_flags;
                    load_count = load_count + 1;
                    if (scan_is_double) begin
                        dp_count = dp_count + 1;
                    end else begin
                        sp_count = sp_count + 1;
                    end
                end
                if (load_count < TXN_COUNT) begin
                    scan_count = $fscanf(vector_file, "%h %h %h %h %h %h %h %h %h\n",
                                         scan_is_double, scan_op, scan_rm, scan_rs1, scan_rs2,
                                         scan_rs3, scan_result, scan_flags, scan_fused_diff);
                end
            end
            $fclose(vector_file);
            if (load_count != TXN_COUNT || sp_count != FORMAT_COUNT || dp_count != FORMAT_COUNT) begin
                $display("FMA elastic vector load failure loaded=%0d sp=%0d dp=%0d",
                         load_count, sp_count, dp_count);
                $fatal(1);
            end
        end
    endtask

    task drive_stream;
        integer drive_index;
        begin
            for (drive_index = 0; drive_index < TXN_COUNT; drive_index = drive_index + 1) begin
                @(negedge clk);
                rs1 = vector_rs1[drive_index];
                rs2 = vector_rs2[drive_index];
                rs3 = vector_rs3[drive_index];
                op = vector_op[drive_index];
                funct3 = vector_rm[drive_index];
                funct7 = 7'd0;
                rs2_val = 5'd0;
                is_double = vector_is_double[drive_index];
                s_axis_valid = 1'b1;
                @(posedge clk);
                while (!s_axis_ready) begin
                    @(posedge clk);
                end
            end
            @(negedge clk);
            s_axis_valid = 1'b0;
        end
    endtask

    task wait_for_outputs;
        begin
            wait_count = 0;
            while (receive_count < TXN_COUNT && wait_count < TIMEOUT_CYCLES) begin
                @(negedge clk);
                wait_count = wait_count + 1;
            end
            if (receive_count != TXN_COUNT) begin
                $display("FMA elastic timeout accepted=%0d received=%0d", accept_count, receive_count);
                $fatal(1);
            end
        end
    endtask

    task check_nominal;
        integer nominal_latency;
        begin
            if (accept_count != TXN_COUNT || receive_count != TXN_COUNT) begin
                $display("FMA nominal count failure accepted=%0d received=%0d", accept_count, receive_count);
                $fatal(1);
            end
            for (check_index = 0; check_index < TXN_COUNT; check_index = check_index + 1) begin
                nominal_latency = receive_cycle[check_index] - accept_cycle[check_index];
                if (nominal_latency != EXPECTED_LATENCY) begin
                    $display("FMA nominal latency failure index=%0d expected=%0d actual=%0d",
                             check_index, EXPECTED_LATENCY, nominal_latency);
                    $fatal(1);
                end
                if (check_index > 0) begin
                    if (accept_cycle[check_index] - accept_cycle[check_index-1] != 1) begin
                        $display("FMA nominal input II failure index=%0d", check_index);
                        $fatal(1);
                    end
                    if (receive_cycle[check_index] - receive_cycle[check_index-1] != 1) begin
                        $display("FMA nominal output II failure index=%0d", check_index);
                        $fatal(1);
                    end
                end
            end
            $display("FMA ELASTIC NOMINAL PASS latency=%0d input_ii=1 output_ii=1 transactions=%0d",
                     EXPECTED_LATENCY, TXN_COUNT);
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            phase = PHASE_IDLE;
            rst_n = 1'b0;
            s_axis_valid = 1'b0;
            m_axis_ready = 1'b0;
            stress_random_active = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task drive_stress_ready;
        begin
            repeat (EXPECTED_LATENCY + 20) @(negedge clk);
            stress_random_active = 1'b1;
            while (receive_count < TXN_COUNT) begin
                ready_lfsr = {ready_lfsr[14:0],
                              ready_lfsr[15] ^ ready_lfsr[13] ^ ready_lfsr[12] ^ ready_lfsr[10]};
                if (random_low_run >= 7) begin
                    m_axis_ready = 1'b1;
                    random_low_run = 0;
                end else begin
                    m_axis_ready = ready_lfsr[0];
                    if (m_axis_ready) begin
                        random_low_run = 0;
                    end else begin
                        random_low_run = random_low_run + 1;
                        random_ready_low_cycles = random_ready_low_cycles + 1;
                    end
                end
                @(negedge clk);
            end
            m_axis_ready = 1'b1;
            stress_random_active = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count = 0;
            accept_count = 0;
            receive_count = 0;
            error_count = 0;
            input_stall_cycles = 0;
            output_stall_run = 0;
            max_output_stall_run = 0;
            output_stalled_previous = 1'b0;
            input_stalled_previous = 1'b0;
            held_output_payload = 135'd0;
            held_input_payload = 212'd0;
        end else if (phase != PHASE_IDLE) begin
            cycle_count = cycle_count + 1;

            if (input_stalled_previous) begin
                if (!s_axis_valid || observed_input_payload !== held_input_payload) begin
                    $display("FMA elastic input changed while stalled cycle=%0d", cycle_count);
                    $fatal(1);
                end
            end
            input_stalled_previous = s_axis_valid && !s_axis_ready;
            if (s_axis_valid && !s_axis_ready) begin
                held_input_payload = observed_input_payload;
                input_stall_cycles = input_stall_cycles + 1;
            end

            if (output_stalled_previous) begin
                if (!m_axis_valid || observed_output_payload !== held_output_payload) begin
                    $display("FMA elastic output changed while stalled cycle=%0d", cycle_count);
                    $fatal(1);
                end
            end
            output_stalled_previous = m_axis_valid && !m_axis_ready;
            if (m_axis_valid && !m_axis_ready) begin
                held_output_payload = observed_output_payload;
                output_stall_run = output_stall_run + 1;
                if (output_stall_run > max_output_stall_run) begin
                    max_output_stall_run = output_stall_run;
                end
            end else begin
                output_stall_run = 0;
            end

            if (s_axis_valid && s_axis_ready) begin
                if (accept_count >= TXN_COUNT) begin
                    $display("FMA elastic duplicate input acceptance cycle=%0d", cycle_count);
                    $fatal(1);
                end
                accept_cycle[accept_count] = cycle_count;
                accept_count = accept_count + 1;
            end

            if (m_axis_valid && m_axis_ready) begin
                if (receive_count >= TXN_COUNT) begin
                    $display("FMA elastic duplicate output cycle=%0d", cycle_count);
                    $fatal(1);
                end
                if (receive_count >= accept_count) begin
                    $display("FMA elastic output without accepted input cycle=%0d", cycle_count);
                    $fatal(1);
                end
                if (out_fp !== expected_result[receive_count] ||
                    fflags !== expected_flags[receive_count] ||
                    we_fpr !== 1'b1 || we_gpr !== 1'b0 || out_int !== 64'd0) begin
                    $display("FMA elastic mismatch/reorder index=%0d expected=%h/%b actual=%h/%b int=%h we=%b%b",
                             receive_count, expected_result[receive_count], expected_flags[receive_count],
                             out_fp, fflags, out_int, we_gpr, we_fpr);
                    $fatal(1);
                end
                receive_cycle[receive_count] = cycle_count;
                receive_count = receive_count + 1;
            end
        end
    end

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
        m_axis_ready = 1'b0;
        phase = PHASE_IDLE;
        ready_lfsr = 16'h1ACE;
        stress_random_active = 1'b0;
        random_ready_low_cycles = 0;
        random_low_run = 0;

        load_vectors();

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        phase = PHASE_NOMINAL;
        m_axis_ready = 1'b1;
        drive_stream();
        wait_for_outputs();
        check_nominal();
        @(negedge clk);
        phase = PHASE_IDLE;
        repeat (4) begin
            @(posedge clk);
            if (m_axis_valid) begin
                $display("FMA nominal unexpected output after drain");
                $fatal(1);
            end
        end

        reset_dut();
        @(negedge clk);
        phase = PHASE_STRESS;
        m_axis_ready = 1'b0;
        ready_lfsr = 16'h1ACE;
        random_ready_low_cycles = 0;
        random_low_run = 0;
        fork
            drive_stream();
            drive_stress_ready();
        join
        wait_for_outputs();
        if (accept_count != TXN_COUNT || receive_count != TXN_COUNT) begin
            $display("FMA stress count failure accepted=%0d received=%0d", accept_count, receive_count);
            $fatal(1);
        end
        if (input_stall_cycles == 0) begin
            $display("FMA stress did not backpressure the input");
            $fatal(1);
        end
        if (max_output_stall_run < 16) begin
            $display("FMA stress stall too short max=%0d", max_output_stall_run);
            $fatal(1);
        end
        if (random_ready_low_cycles == 0) begin
            $display("FMA stress random ready produced no low cycles");
            $fatal(1);
        end
        @(negedge clk);
        phase = PHASE_IDLE;
        repeat (4) begin
            @(posedge clk);
            if (m_axis_valid) begin
                $display("FMA stress unexpected output after drain");
                $fatal(1);
            end
        end

        $display("FMA ELASTIC STRESS PASS transactions=%0d input_stall_cycles=%0d max_output_stall=%0d random_ready_low=%0d",
                 TXN_COUNT, input_stall_cycles, max_output_stall_run, random_ready_low_cycles);
        $display("FMA ELASTIC TEST PASS");
        $finish;
    end

endmodule
