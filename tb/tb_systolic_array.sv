`timescale 1ns/1ps
// 4x4 systolic array test. The testbench drives the array edge lanes with its
// OWN injection code (A[i][k] at t=i+k, B[k][j] at t=j+k) and checks, per PE:
//   * a MAC fires exactly when 0 <= t-i-j < 4, with operands A[i][k], B[k][j],
//     k = t-i-j, and `last` only for k=3;
//   * result_valid pulses exactly once, at t = i+j+4, carrying C[i][j];
//   * number of active PEs each cycle matches the analytical wavefront.
module tb_systolic_array;
    reg clk = 0, rst_n = 0, clear_acc = 0;
    reg  [31:0] a_data = 0, b_data = 0;
    reg  [3:0]  a_valid = 0, a_last = 0, b_valid = 0, b_last = 0;
    wire [511:0] result_flat;
    wire [15:0]  result_valid;

    systolic_array_4x4 #(.DATA_W(8), .ACC_W(32)) dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_data(a_data), .a_valid(a_valid), .a_last(a_last),
        .b_data(b_data), .b_valid(b_valid), .b_last(b_last),
        .result_flat(result_flat), .result_valid(result_valid)
    );
    always #5 clk = ~clk;

    // per-PE taps via hierarchical references
    wire [127:0] pe_a, pe_b;
    wire [15:0]  pe_av, pe_bv, pe_al, pe_bl;
    wire [511:0] pe_acc;
    genvar gi, gj;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : tr
            for (gj = 0; gj < 4; gj = gj + 1) begin : tc
                assign pe_a [(gi*4+gj)*8 +: 8]   = dut.g_row[gi].g_col[gj].u_pe.a_in;
                assign pe_b [(gi*4+gj)*8 +: 8]   = dut.g_row[gi].g_col[gj].u_pe.b_in;
                assign pe_av[gi*4+gj]            = dut.g_row[gi].g_col[gj].u_pe.a_valid_in;
                assign pe_bv[gi*4+gj]            = dut.g_row[gi].g_col[gj].u_pe.b_valid_in;
                assign pe_al[gi*4+gj]            = dut.g_row[gi].g_col[gj].u_pe.a_last_in;
                assign pe_bl[gi*4+gj]            = dut.g_row[gi].g_col[gj].u_pe.b_last_in;
                assign pe_acc[(gi*4+gj)*32 +: 32] = dut.g_row[gi].g_col[gj].u_pe.acc;
            end
        end
    endgenerate

    integer Ai [0:15];
    integer Bi [0:15];
    integer Ci [0:15];
    integer got [0:15];
    integer pulses [0:15];
    integer tcur = -100;
    integer errors = 0, checks = 0, jobs = 0;
    integer seed = 32'h2026_1116;

    task fail(input [255:0] msg, input integer p, input integer a, input integer b);
        begin
            errors = errors + 1;
            if (errors < 20) $display("FAIL %0s pe=%0d got/exp %0d / %0d (t=%0d job=%0d)", msg, p, a, b, tcur, jobs);
        end
    endtask

    // ---- monitor: sampled mid-cycle (negedge) ----
    integer mi, mj, mk, p, expect_active, active;
    always @(negedge clk) begin
        if (tcur >= 0) begin
            active = 0; expect_active = 0;
            for (mi = 0; mi < 4; mi = mi + 1)
                for (mj = 0; mj < 4; mj = mj + 1) begin
                    p  = mi*4 + mj;
                    mk = tcur - mi - mj;
                    checks = checks + 1;
                    if (mk >= 0 && mk < 4) begin
                        expect_active = expect_active + 1;
                        if (!(pe_av[p] && pe_bv[p])) fail("MAC window: valid missing", p, 0, 1);
                        else begin
                            active = active + 1;
                            if ($signed(pe_a[p*8 +: 8]) !== Ai[mi*4+mk]) fail("A operand", p, $signed(pe_a[p*8 +: 8]), Ai[mi*4+mk]);
                            if ($signed(pe_b[p*8 +: 8]) !== Bi[mk*4+mj]) fail("B operand", p, $signed(pe_b[p*8 +: 8]), Bi[mk*4+mj]);
                            if (pe_al[p] !== (mk == 3) || pe_bl[p] !== (mk == 3)) fail("last marker", p, pe_al[p], (mk == 3));
                        end
                    end else begin
                        if (pe_av[p] || pe_bv[p]) fail("valid outside window", p, 1, 0);
                    end
                    if (result_valid[p]) begin
                        pulses[p] = pulses[p] + 1;
                        got[p] = $signed(result_flat[p*32 +: 32]);
                        if (mk !== 4) fail("result_valid at wrong cycle", p, tcur, mi+mj+4);
                    end
                end
            if (active !== expect_active) fail("active PE count", -1, active, expect_active);
        end
    end

    task drive_lanes(input integer t);
        integer r, c, kk;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                kk = t - r;
                if (kk >= 0 && kk < 4) begin
                    a_data[r*8 +: 8] = Ai[r*4+kk]; a_valid[r] = 1; a_last[r] = (kk == 3);
                end else begin
                    a_data[r*8 +: 8] = 0; a_valid[r] = 0; a_last[r] = 0;
                end
            end
            for (c = 0; c < 4; c = c + 1) begin
                kk = t - c;
                if (kk >= 0 && kk < 4) begin
                    b_data[c*8 +: 8] = Bi[kk*4+c]; b_valid[c] = 1; b_last[c] = (kk == 3);
                end else begin
                    b_data[c*8 +: 8] = 0; b_valid[c] = 0; b_last[c] = 0;
                end
            end
        end
    endtask

    task run_job(input [255:0] name);
        integer r, c, k2, t;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    Ci[r*4+c] = 0;
                    for (k2 = 0; k2 < 4; k2 = k2 + 1) Ci[r*4+c] = Ci[r*4+c] + Ai[r*4+k2] * Bi[k2*4+c];
                end
            for (r = 0; r < 16; r = r + 1) begin pulses[r] = 0; got[r] = 0; end
            clear_acc = 1; a_valid = 0; b_valid = 0; a_last = 0; b_last = 0; a_data = 0; b_data = 0;
            @(posedge clk); #1; clear_acc = 0;
            for (t = 0; t < 14; t = t + 1) begin
                drive_lanes(t);
                tcur = t;
                @(posedge clk); #1;
            end
            tcur = -100;
            for (r = 0; r < 16; r = r + 1) begin
                checks = checks + 3;
                if (pulses[r] !== 1) fail("result pulse count", r, pulses[r], 1);
                if (got[r] !== Ci[r]) fail("result value", r, got[r], Ci[r]);
                if ($signed(pe_acc[r*32 +: 32]) !== Ci[r]) fail("final accumulator", r, $signed(pe_acc[r*32 +: 32]), Ci[r]);
            end
            jobs = jobs + 1;
        end
    endtask

    function integer rnd8(input integer dummy);
        begin rnd8 = ($random(seed) & 255) - 128; end
    endfunction

    integer x, y, z;
    initial begin
        @(posedge clk); @(posedge clk); #1; rst_n = 1;

        // identity x sequence
        for (x = 0; x < 16; x = x + 1) begin Ai[x] = (x/4 == x%4) ? 1 : 0; Bi[x] = x + 1; end
        run_job("identity");
        // all ones
        for (x = 0; x < 16; x = x + 1) begin Ai[x] = 1; Bi[x] = 1; end
        run_job("ones");
        // extremes
        for (x = 0; x < 16; x = x + 1) begin Ai[x] = -128; Bi[x] = -128; end
        run_job("min*min");
        for (x = 0; x < 16; x = x + 1) begin Ai[x] = -128; Bi[x] = 127; end
        run_job("min*max");
        // zero after nonzero (stale accumulator check)
        for (x = 0; x < 16; x = x + 1) begin Ai[x] = 0; Bi[x] = 55; end
        run_job("zero");
        // A impulses: single A[i][k], B all ones -> row i of C = A[i][k]
        for (y = 0; y < 16; y = y + 1) begin
            for (x = 0; x < 16; x = x + 1) begin Ai[x] = 0; Bi[x] = 1; end
            Ai[y] = -(y + 3);
            run_job("A impulse");
        end
        // B impulses: single B[k][j], A all ones
        for (y = 0; y < 16; y = y + 1) begin
            for (x = 0; x < 16; x = x + 1) begin Ai[x] = 1; Bi[x] = 0; end
            Bi[y] = y + 5;
            run_job("B impulse");
        end
        // random
        for (z = 0; z < 40; z = z + 1) begin
            for (x = 0; x < 16; x = x + 1) begin Ai[x] = rnd8(0); Bi[x] = rnd8(0); end
            run_job("random");
        end

        $display("tb_systolic_array: %0d jobs, %0d checks, %0d errors", jobs, checks, errors);
        if (errors == 0) $display("TEST_RESULT: PASS tb_systolic_array");
        else             $display("TEST_RESULT: FAIL tb_systolic_array");
        $finish;
    end

    initial begin
        #5000000;
        $display("TEST_RESULT: FAIL tb_systolic_array (timeout)");
        $finish;
    end
endmodule
