`timescale 1ns/1ps
// AXIVEX top-level testbench.
//
// Plusargs:
//   +VEC=<file>    vector file (see reference/matrix_model.py). Each line is one
//                  transaction; expected C comes from the Python reference.
//   +OUT=<file>    write measured results: name total_lat run_cycles retire_cycles macs C[0..15]
//   +TRACE=<file>  write per-cycle PE/FSM trace for the first +TRACE_N transactions
//   +VCD=<file>    dump waveform
//   +SCEN          also run reset / busy / back-to-back / held-start scenarios
//
// Cycle accounting (cycle index of the cycle in which start is first high = 0):
//   load/start 1 + CLEAR 1 + RUN 10 + RETIRE 1 -> DONE visible at cycle 13.
module tb_axivex_top;
    // ---------------- DUT ----------------
    reg          clk = 0, rst_n = 0, start = 0;
    reg  [127:0] a_flat = 0, b_flat = 0;
    wire         busy, done, c_valid, start_rejected, result_error;
    wire [511:0] c_flat;

    axivex_top #(.DATA_W(8), .ACC_W(32)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .a_flat(a_flat), .b_flat(b_flat),
        .busy(busy), .done(done), .c_flat(c_flat), .c_valid(c_valid),
        .start_rejected(start_rejected), .result_error(result_error)
    );
    always #5 clk = ~clk;

    localparam [2:0] S_IDLE = 0, S_CLEAR = 1, S_RUN = 2, S_RETIRE = 3, S_DONE = 4;

    // ---------------- taps ----------------
    wire [2:0] st  = dut.u_ctrl.state;
    wire [3:0] cnt = dut.u_ctrl.cycle_count;
    wire [4:0] cap_count = dut.u_out.capture_count;

    wire [127:0] pe_a, pe_b;
    wire [15:0]  pe_av, pe_bv, pe_al, pe_bl, pe_rv;
    wire [511:0] pe_acc;
    wire [255:0] pe_prod;
    genvar gi, gj;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : tr
            for (gj = 0; gj < 4; gj = gj + 1) begin : tc
                assign pe_a [(gi*4+gj)*8 +: 8]    = dut.u_array.g_row[gi].g_col[gj].u_pe.a_in;
                assign pe_b [(gi*4+gj)*8 +: 8]    = dut.u_array.g_row[gi].g_col[gj].u_pe.b_in;
                assign pe_av[gi*4+gj]             = dut.u_array.g_row[gi].g_col[gj].u_pe.a_valid_in;
                assign pe_bv[gi*4+gj]             = dut.u_array.g_row[gi].g_col[gj].u_pe.b_valid_in;
                assign pe_al[gi*4+gj]             = dut.u_array.g_row[gi].g_col[gj].u_pe.a_last_in;
                assign pe_bl[gi*4+gj]             = dut.u_array.g_row[gi].g_col[gj].u_pe.b_last_in;
                assign pe_rv[gi*4+gj]             = dut.u_array.g_row[gi].g_col[gj].u_pe.result_valid;
                assign pe_acc[(gi*4+gj)*32 +: 32] = dut.u_array.g_row[gi].g_col[gj].u_pe.acc;
                assign pe_prod[(gi*4+gj)*16 +: 16]= dut.u_array.g_row[gi].g_col[gj].u_pe.product;
            end
        end
    endgenerate

    // ---------------- bookkeeping ----------------
    integer cyc = 0;
    always @(posedge clk) cyc <= cyc + 1;

    integer errors = 0, txns_checked = 0, txns_failed = 0;
    reg [8*40-1:0] cur_name = "init";
    reg [127:0] exp_a = 0, exp_b = 0;       // matrices the testbench intends for the current job
    integer Ai [0:15];
    integer Bi [0:15];
    integer Ci [0:15];
    integer Cf [0:15];                      // expected C from the Python reference (vector mode)
    integer got [0:15];

    integer vec_fd = 0, out_fd = 0, trace_fd = 0, trace_n = 1;
    reg [8*256-1:0] vec_path, out_path, trace_path, vcd_path;
    reg verbose = 0;

    task err(input [8*48-1:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 25) $display("  ERROR @cyc %0d [%0s]: %0s", cyc, cur_name, msg);
        end
    endtask

    // ---------------- monitor / assertions (sampled mid-cycle) ----------------
    reg         prev_valid = 0, prev_rstn = 1, prev_clear = 0, prev_done = 0;
    reg [127:0] prev_a = 0, prev_b = 0;
    reg [15:0]  prev_av = 0, prev_bv = 0, prev_al = 0, prev_bl = 0;
    reg [511:0] prev_acc = 0;
    reg [255:0] prev_prod = 0;

    reg         txn_active = 0, trace_on = 0;
    integer     txn_count = 0, trace_c = 0;
    integer     m_run = 0, m_ret = 0, m_fire = 0, m_active_max = 0;
    integer     m_pulses [0:15];
    integer     done_count = 0, rej_count = 0;
    integer     m_last_run = 0, m_last_ret = 0, m_last_fire = 0, m_last_macs_active = 0;
    reg         m_stats_ok = 0;

    integer p, q, ii, jj, kk, pa, pp, na, fire_n, exp_rv, sum_p;
    reg     fire, exp_valid;
    reg [7:0] exp_val;

    initial begin for (p = 0; p < 16; p = p + 1) m_pulses[p] = 0; end

    always @(negedge clk) begin
        if (prev_valid && !prev_rstn) begin txn_active = 0; trace_on = 0; end

        // FSM / interface rules
        if (st == S_CLEAR) begin
            txn_active = 1; txn_count = txn_count + 1;
            m_run = 0; m_ret = 0; m_fire = 0; m_active_max = 0;
            for (p = 0; p < 16; p = p + 1) m_pulses[p] = 0;
            trace_on = (trace_fd != 0) && (txn_count <= trace_n);
            trace_c = 0;
        end
        if (busy !== ((st == S_CLEAR) || (st == S_RUN) || (st == S_RETIRE))) err("busy inconsistent with state");
        if (done !== (st == S_DONE)) err("done inconsistent with state");
        if (done && busy) err("done and busy together");
        if (result_error) err("output_buffer duplicate capture");
        if (start_rejected) rej_count = rej_count + 1;
        if (txn_active && st != S_DONE && c_valid) err("c_valid before DONE");
        if (st == S_RUN) m_run = m_run + 1;
        if (st == S_RETIRE) m_ret = m_ret + 1;

        // operand injection at the array edge, checked against the intended matrices
        for (ii = 0; ii < 4; ii = ii + 1) begin
            kk = cnt - ii;
            exp_valid = (st == S_RUN) && (kk >= 0) && (kk < 4);
            if (pe_av[ii*4] !== exp_valid) err("row injection valid window");
            if (pe_bv[ii] !== exp_valid)   err("col injection valid window");
        end
        if (st == S_RUN && txn_active) begin
            for (ii = 0; ii < 4; ii = ii + 1) begin
                kk = cnt - ii;
                if (kk >= 0 && kk < 4) begin
                    if (pe_a[(ii*4)*8 +: 8] !== exp_a[(ii*4+kk)*8 +: 8]) err("A injected value != A[i][t-i]");
                    if (pe_b[ii*8 +: 8]     !== exp_b[(kk*4+ii)*8 +: 8]) err("B injected value != B[t-j][j]");
                    if (pe_al[ii*4] !== (kk == 3)) err("A last marker at edge");
                    if (pe_bl[ii]   !== (kk == 3)) err("B last marker at edge");
                end
            end
        end

        // per-PE checks
        fire_n = 0;
        for (p = 0; p < 16; p = p + 1) begin
            if (pe_av[p] !== pe_bv[p]) err("A/B valid misaligned");
            if (pe_av[p] && pe_bv[p] && (pe_al[p] !== pe_bl[p])) err("A/B last misaligned");
            if (pe_av[p] && pe_bv[p]) fire_n = fire_n + 1;
            if (pe_rv[p]) m_pulses[p] = m_pulses[p] + 1;
            if (prev_valid && prev_rstn && !prev_clear) begin
                fire = prev_av[p] & prev_bv[p];
                pa = $signed(prev_acc[p*32 +: 32]);
                pp = $signed(prev_prod[p*16 +: 16]);
                na = $signed(pe_acc[p*32 +: 32]);
                if (fire) begin if (na !== pa + pp) err("acc != old acc + product"); end
                else      begin if (na !== pa)      err("accumulated with invalid operands"); end
                exp_rv = (fire && prev_al[p] && prev_bl[p]) ? 1 : 0;
                if (pe_rv[p] !== exp_rv[0]) err("result_valid != fire & last");
            end else if (prev_valid && (!prev_rstn || prev_clear)) begin
                if (pe_acc[p*32 +: 32] !== 32'd0) err("acc not cleared");
                if (pe_rv[p] !== 1'b0) err("result_valid after clear/reset");
            end
        end
        m_fire = m_fire + fire_n;
        if (fire_n > m_active_max) m_active_max = fire_n;

        // forwarding: east (A) and south (B) neighbours see last cycle's value
        if (prev_valid && prev_rstn && !prev_clear) begin
            for (ii = 0; ii < 4; ii = ii + 1)
                for (jj = 0; jj < 3; jj = jj + 1) begin
                    p = ii*4 + jj; q = ii*4 + jj + 1;
                    if (pe_a[q*8 +: 8] !== prev_a[p*8 +: 8] || pe_av[q] !== prev_av[p] || pe_al[q] !== prev_al[p])
                        err("A forwarding east lost data");
                end
            for (ii = 0; ii < 3; ii = ii + 1)
                for (jj = 0; jj < 4; jj = jj + 1) begin
                    p = ii*4 + jj; q = (ii+1)*4 + jj;
                    if (pe_b[q*8 +: 8] !== prev_b[p*8 +: 8] || pe_bv[q] !== prev_bv[p] || pe_bl[q] !== prev_bl[p])
                        err("B forwarding south lost data");
                end
        end

        // completion
        if (done) begin
            done_count = done_count + 1;
            if (prev_done) err("done longer than one cycle");
            if (!txn_active) err("spurious done (no accepted job)");
            else begin
                sum_p = 0;
                for (p = 0; p < 16; p = p + 1) begin
                    sum_p = sum_p + m_pulses[p];
                    if (m_pulses[p] != 1) err("PE result pulse count != 1");
                end
                if (sum_p != 16) err("total PE results != 16");
                if (cap_count !== 5'd16) err("capture_count != 16 at done");
                if (!c_valid) err("c_valid low at done");
                if (m_fire != 64) err("MAC count != 64");
                m_last_run = m_run; m_last_ret = m_ret; m_last_fire = m_fire;
                m_last_macs_active = m_active_max; m_stats_ok = 1;
                txn_active = 0;
            end
        end

        // trace row
        if (trace_on) begin
            trace_c = trace_c + 1;
            $fwrite(trace_fd, "%0s %0d %0d %0d %0d %0d %0d", cur_name, trace_c, st, cnt, busy, done, c_valid);
            for (p = 0; p < 16; p = p + 1)
                $fwrite(trace_fd, " %0d %0d %0d %0d %0d %0d %0d",
                        $signed(pe_a[p*8 +: 8]), $signed(pe_b[p*8 +: 8]), pe_av[p], pe_bv[p],
                        pe_al[p] & pe_bl[p], $signed(pe_acc[p*32 +: 32]), pe_rv[p]);
            $fwrite(trace_fd, "\n");
            if (done) trace_on = 0;
        end

        prev_valid = 1; prev_rstn = rst_n; prev_clear = dut.clear_acc; prev_done = done;
        prev_a = pe_a; prev_b = pe_b; prev_av = pe_av; prev_bv = pe_bv;
        prev_al = pe_al; prev_bl = pe_bl; prev_acc = pe_acc; prev_prod = pe_prod;
    end

    // ---------------- stimulus helpers ----------------
    task pack_ports;
        integer r;
        begin
            for (r = 0; r < 16; r = r + 1) begin
                a_flat[r*8 +: 8] = Ai[r];
                b_flat[r*8 +: 8] = Bi[r];
            end
            exp_a = a_flat; exp_b = b_flat;
        end
    endtask

    task compute_expected;
        integer r, c, k2;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    Ci[r*4+c] = 0;
                    for (k2 = 0; k2 < 4; k2 = k2 + 1) Ci[r*4+c] = Ci[r*4+c] + Ai[r*4+k2] * Bi[k2*4+c];
                end
        end
    endtask

    integer start_cyc = 0;
    // Pulse start (>=1 cycle). Called at posedge+1 or negedge+1.
    task start_txn(input [8*40-1:0] name);
        begin
            cur_name = name;
            compute_expected;
            pack_ports;
            m_stats_ok = 0;
            start_cyc = cyc;
            start = 1;
            @(posedge clk); #1;
            start = 0;
        end
    endtask

    integer wd_timeout;
    // Wait until done is high (checked at posedge+1), then settle to negedge+1
    // so the monitor has finished its done-cycle checks.
    task wait_done;
        integer n;
        begin
            wd_timeout = 0; n = 0;
            while (!done && n < 80) begin @(posedge clk); #1; n = n + 1; end
            if (!done) begin wd_timeout = 1; err("timeout waiting for done"); end
            @(negedge clk); #1;
        end
    endtask

    integer last_lat = 0;
    // Read C at the done cycle and compare against Ci (tb loop) and, optionally, Cf (Python).
    task check_result(input use_cf);
        integer r, bad;
        begin
            bad = 0;
            last_lat = cyc - start_cyc;
            for (r = 0; r < 16; r = r + 1) begin
                got[r] = $signed(c_flat[r*32 +: 32]);
                if (got[r] !== Ci[r]) bad = bad + 1;
                if (use_cf && got[r] !== Cf[r]) bad = bad + 1;
                if (use_cf && Cf[r] !== Ci[r]) bad = bad + 1;
            end
            if (!c_valid) bad = bad + 1;
            if (wd_timeout) bad = bad + 1;
            if (last_lat != 13) begin bad = bad + 1; $display("  latency %0d != 13", last_lat); end
            if (m_last_run != 10) begin bad = bad + 1; $display("  run cycles %0d != 10", m_last_run); end
            if (m_last_ret != 1)  begin bad = bad + 1; $display("  retire cycles %0d != 1", m_last_ret); end
            txns_checked = txns_checked + 1;
            if (bad != 0) begin
                txns_failed = txns_failed + 1;
                $display("[FAIL] %0s", cur_name);
                for (r = 0; r < 16; r = r + 1)
                    if (got[r] !== Ci[r] || (use_cf && got[r] !== Cf[r]))
                        $display("   C[%0d][%0d] got %0d expected %0d", r/4, r%4, got[r], Ci[r]);
            end else if (verbose) $display("[PASS] %0s latency=%0d", cur_name, last_lat);
        end
    endtask

    task dump_result;
        integer r;
        begin
            if (out_fd != 0) begin
                $fwrite(out_fd, "%0s %0d %0d %0d %0d", cur_name, last_lat, m_last_run, m_last_ret, m_last_fire);
                for (r = 0; r < 16; r = r + 1) $fwrite(out_fd, " %0d", got[r]);
                $fwrite(out_fd, "\n");
            end
        end
    endtask

    task run_checked(input [8*40-1:0] name, input use_cf);
        begin
            start_txn(name);
            wait_done;
            check_result(use_cf);
            dump_result;
        end
    endtask

    task load_random(input integer sd);
        integer r, s2;
        begin
            s2 = sd;
            for (r = 0; r < 16; r = r + 1) begin
                Ai[r] = ($random(s2) & 255) - 128;
                Bi[r] = ($random(s2) & 255) - 128;
            end
        end
    endtask

    task idle_cycles(input integer n);
        begin repeat (n) begin @(posedge clk); #1; end end
    endtask

    task wait_state(input [2:0] s, input integer c);
        integer n;
        begin
            n = 0;
            while (!(st == s && (c < 0 || cnt == c)) && n < 60) begin @(posedge clk); #1; n = n + 1; end
            if (n >= 60) err("wait_state timeout");
        end
    endtask

    task pulse_reset(input integer n);
        begin rst_n = 0; repeat (n) begin @(posedge clk); #1; end rst_n = 1; end
    endtask

    task expect_idle_clean(input [8*40-1:0] what);
        integer r, bad;
        begin
            bad = 0;
            if (st !== S_IDLE) bad = bad + 1;
            if (busy || done || c_valid) bad = bad + 1;
            if (pe_av !== 16'd0 || pe_bv !== 16'd0 || pe_rv !== 16'd0) bad = bad + 1;
            for (r = 0; r < 16; r = r + 1) if (pe_acc[r*32 +: 32] !== 32'd0) bad = bad + 1;
            if (c_flat !== 512'd0) bad = bad + 1;
            if (bad != 0) begin errors = errors + 1; $display("  ERROR: not clean after %0s", what); end
        end
    endtask

    // ---------------- vector mode ----------------
    integer n_items, rc, v;
    reg [8*40-1:0] vname;
    task run_vectors;
        begin
            n_items = 0;
            rc = $fscanf(vec_fd, "%s", vname);
            while (rc == 1) begin
                for (v = 0; v < 16; v = v + 1) rc = $fscanf(vec_fd, "%d", Ai[v]);
                for (v = 0; v < 16; v = v + 1) rc = $fscanf(vec_fd, "%d", Bi[v]);
                for (v = 0; v < 16; v = v + 1) rc = $fscanf(vec_fd, "%d", Cf[v]);
                run_checked(vname, 1);
                n_items = n_items + 1;
                rc = $fscanf(vec_fd, "%s", vname);
            end
            $display("vector file: %0d transactions run", n_items);
        end
    endtask

    // ---------------- scenarios ----------------
    integer d0, k3;
    task scenarios;
        begin
            $display("--- scenarios ---");
            // S1 reset in idle (after a completed job, results must clear)
            load_random(11); run_checked("scen_pre_reset_idle", 0);
            idle_cycles(3);
            pulse_reset(2);
            idle_cycles(1);
            expect_idle_clean("reset in idle");
            idle_cycles(10);

            // S2 reset during CLEAR / RUN / RETIRE; then a clean job must be correct
            for (k3 = 0; k3 < 4; k3 = k3 + 1) begin
                load_random(100 + k3);
                d0 = done_count;
                cur_name = "scen_reset_mid_job";
                compute_expected; pack_ports; start_cyc = cyc;
                start = 1; @(posedge clk); #1; start = 0;
                case (k3)
                    0: wait_state(S_CLEAR, -1);
                    1: wait_state(S_RUN, 0);
                    2: wait_state(S_RUN, 6);
                    3: wait_state(S_RETIRE, -1);
                endcase
                pulse_reset(1);
                idle_cycles(1);
                expect_idle_clean("reset mid-job");
                idle_cycles(30);
                if (done_count != d0) err("done pulsed after reset mid-job");
                load_random(200 + k3);
                run_checked("scen_after_reset", 0);
            end

            // S3 start while busy is rejected; ports changed mid-job are ignored
            load_random(21);
            d0 = done_count; rej_count = 0;
            start_txn("scen_start_while_busy");
            wait_state(S_RUN, 3);
            a_flat = {16{8'h55}}; b_flat = {16{8'hAA}};   // garbage on the ports
            start = 1; @(posedge clk); #1; start = 0;
            wait_done;
            check_result(0); dump_result;
            if (rej_count != 1) err("start_rejected pulse count != 1");
            idle_cycles(40);
            if (done_count != d0 + 1) err("extra done after rejected start");

            // S4 result stays stable and is not disturbed by changing input ports
            begin : hold_block
                reg [511:0] snap;
                snap = c_flat;
                a_flat = ~a_flat; b_flat = ~b_flat;
                idle_cycles(20);
                if (c_flat !== snap || !c_valid) err("result not held after done");
            end

            // S5 back-to-back: new start in the DONE cycle
            load_random(31); start_txn("scen_b2b_0"); wait_done; check_result(0); dump_result;
            for (k3 = 1; k3 < 6; k3 = k3 + 1) begin
                load_random(31 + k3);
                run_checked("scen_b2b_n", 0);
            end

            // S6 start held high: only one job runs
            load_random(41);
            d0 = done_count;
            cur_name = "scen_start_held";
            compute_expected; pack_ports; m_stats_ok = 0; start_cyc = cyc;
            idle_cycles(3);
            start_cyc = cyc;
            start = 1;
            @(posedge clk); #1;
            wait_done;
            check_result(0); dump_result;
            idle_cycles(40);
            start = 0;
            idle_cycles(5);
            if (done_count != d0 + 1) err("held start retriggered");

            // S7 start while in reset is ignored
            d0 = done_count;
            rst_n = 0; start = 1; idle_cycles(2); start = 0; idle_cycles(1); rst_n = 1;
            idle_cycles(30);
            if (done_count != d0) err("start during reset produced a job");
            expect_idle_clean("start during reset");

            // S8 normal job after everything
            load_random(51); run_checked("scen_final", 0);
        end
    endtask

    // ---------------- main ----------------
    initial begin
        if ($test$plusargs("VERBOSE")) verbose = 1;
        if ($value$plusargs("OUT=%s", out_path))   out_fd   = $fopen(out_path, "w");
        if ($value$plusargs("TRACE=%s", trace_path)) trace_fd = $fopen(trace_path, "w");
        if ($value$plusargs("TRACE_N=%d", trace_n)) ;
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            $dumpfile(vcd_path);
            $dumpvars(0, tb_axivex_top);
        end
        if ($value$plusargs("VEC=%s", vec_path)) begin
            vec_fd = $fopen(vec_path, "r");
            if (vec_fd == 0) begin $display("cannot open vector file"); $finish; end
        end

        rst_n = 0; start = 0;
        repeat (3) @(posedge clk);
        #1; rst_n = 1;
        idle_cycles(2);
        expect_idle_clean("power-up reset");

        if (vec_fd != 0) run_vectors;
        if ($test$plusargs("SCEN")) scenarios;

        idle_cycles(5);
        $display("tb_axivex_top: %0d transactions checked, %0d failed, %0d monitor/assert errors",
                 txns_checked, txns_failed, errors);
        if (errors == 0 && txns_failed == 0 && txns_checked > 0) $display("TEST_RESULT: PASS tb_axivex_top");
        else $display("TEST_RESULT: FAIL tb_axivex_top");
        if (out_fd != 0) $fclose(out_fd);
        if (trace_fd != 0) $fclose(trace_fd);
        $finish;
    end

    initial begin
        #50000000;
        $display("TEST_RESULT: FAIL tb_axivex_top (global timeout)");
        $finish;
    end
endmodule
