`timescale 1ns/1ps
// Unit test of one processing element.
module tb_processing_element;
    reg clk = 0, rst_n = 0, clear_acc = 0;
    reg signed [7:0] a_in = 0, b_in = 0;
    reg a_valid_in = 0, b_valid_in = 0, a_last_in = 0, b_last_in = 0;
    wire signed [7:0] a_out, b_out;
    wire a_valid_out, b_valid_out, a_last_out, b_last_out;
    wire signed [31:0] result;
    wire result_valid;

    processing_element #(.DATA_W(8), .ACC_W(32)) dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a_in), .b_in(b_in), .a_valid_in(a_valid_in), .b_valid_in(b_valid_in),
        .a_last_in(a_last_in), .b_last_in(b_last_in),
        .a_out(a_out), .b_out(b_out), .a_valid_out(a_valid_out), .b_valid_out(b_valid_out),
        .a_last_out(a_last_out), .b_last_out(b_last_out),
        .result(result), .result_valid(result_valid)
    );

    always #5 clk = ~clk;

    integer errors = 0, checks = 0, pulses = 0;
    wire signed [31:0] acc_mon = dut.acc;

    always @(posedge clk) if (result_valid) pulses <= pulses + 1;

    task expect_eq(input integer got, input integer exp, input [255:0] what);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got %0d expected %0d (t=%0t)", what, got, exp, $time);
            end
        end
    endtask

    // Drive one cycle: values applied just after posedge, checked after next posedge.
    task drive(input integer a, input integer b, input v_a, input v_b, input l_a, input l_b);
        begin
            a_in = a; b_in = b; a_valid_in = v_a; b_valid_in = v_b;
            a_last_in = l_a; b_last_in = l_b;
            @(posedge clk); #1;
        end
    endtask

    task idle_cycle; begin drive(0, 0, 0, 0, 0, 0); end endtask

    integer k;
    integer sumv;
    integer av [0:3];
    integer bv [0:3];

    initial begin
        @(posedge clk); @(posedge clk); #1; rst_n = 1;

        // reset state
        expect_eq(acc_mon, 0, "acc after reset");
        expect_eq(result_valid, 0, "result_valid after reset");

        // 1. forwarding: one registered hop, data and metadata
        a_in = -57; b_in = 93; a_valid_in = 1; b_valid_in = 1; a_last_in = 1; b_last_in = 0;
        @(posedge clk); #1;
        expect_eq(a_out, -57, "a_out forwarded");
        expect_eq(b_out, 93, "b_out forwarded");
        expect_eq(a_valid_out, 1, "a_valid_out");
        expect_eq(b_valid_out, 1, "b_valid_out");
        expect_eq(a_last_out, 1, "a_last_out");
        expect_eq(b_last_out, 0, "b_last_out");
        // a_last without b_last must not produce a result
        expect_eq(result_valid, 0, "no result when only A last");
        a_in = 0; b_in = 0; a_valid_in = 0; b_valid_in = 0; a_last_in = 0; b_last_in = 0;
        @(posedge clk); #1;
        expect_eq(a_valid_out, 0, "a_valid_out drops");
        expect_eq(a_out, 0, "a_out follows input");

        // clear the accumulator touched by test 1
        clear_acc = 1; @(posedge clk); #1; clear_acc = 0;
        expect_eq(acc_mon, 0, "acc cleared");

        // 2. four-term signed dot product with last marker on the 4th
        av[0] = 3;    bv[0] = -7;
        av[1] = -128; bv[1] = -128;
        av[2] = 127;  bv[2] = -128;
        av[3] = -1;   bv[3] = 5;
        sumv = 0;
        pulses = 0;
        for (k = 0; k < 4; k = k + 1) begin
            drive(av[k], bv[k], 1, 1, (k == 3), (k == 3));
            sumv = sumv + av[k] * bv[k];
            if (k < 3) begin
                expect_eq(acc_mon, sumv, "running acc");
                expect_eq(result_valid, 0, "no early result_valid");
            end
        end
        expect_eq(acc_mon, sumv, "final acc includes last product");
        expect_eq(result, sumv, "result includes final product");
        expect_eq(result_valid, 1, "result_valid pulse");
        idle_cycle;
        expect_eq(result_valid, 0, "result_valid is one cycle");
        expect_eq(result, sumv, "result held");
        expect_eq(pulses, 1, "exactly one result pulse");

        // 3. valid gating: only one of the valids high -> no accumulation
        drive(100, 100, 1, 0, 0, 0);
        expect_eq(acc_mon, sumv, "A valid only: no MAC");
        drive(100, 100, 0, 1, 0, 0);
        expect_eq(acc_mon, sumv, "B valid only: no MAC");
        drive(100, 100, 0, 0, 1, 1);
        expect_eq(acc_mon, sumv, "invalid + last: no MAC");
        expect_eq(result_valid, 0, "invalid + last: no result");

        // 4. clear -> new job, no stale sum
        clear_acc = 1; @(posedge clk); #1; clear_acc = 0;
        expect_eq(acc_mon, 0, "acc zero after clear");
        expect_eq(result, 0, "result zero after clear");
        pulses = 0;
        drive(-2, 9, 1, 1, 1, 1);          // single-term job (last on first term)
        expect_eq(acc_mon, -18, "single term acc");
        expect_eq(result, -18, "single term result");
        expect_eq(result_valid, 1, "single term result_valid");
        idle_cycle;
        expect_eq(pulses, 1, "single term one pulse");

        // 5. clear drops forwarding pipeline
        a_in = 11; b_in = 12; a_valid_in = 1; b_valid_in = 1; clear_acc = 1;
        @(posedge clk); #1; clear_acc = 0; a_valid_in = 0; b_valid_in = 0;
        expect_eq(a_valid_out, 0, "clear flushes valid pipeline");
        expect_eq(acc_mon, 0, "clear wins over MAC");

        // 6. reset mid-flight
        drive(5, 5, 1, 1, 0, 0);
        expect_eq(acc_mon, 25, "pre-reset acc");
        rst_n = 0; @(posedge clk); #1; rst_n = 1;
        a_valid_in = 0; b_valid_in = 0;
        expect_eq(acc_mon, 0, "reset clears acc");
        expect_eq(a_valid_out, 0, "reset clears valid pipeline");
        expect_eq(result_valid, 0, "reset clears result_valid");

        // 7. long run of non-last valid terms then restart after last
        for (k = 0; k < 8; k = k + 1) drive(1, 1, 1, 1, 0, 0);
        expect_eq(acc_mon, 8, "8 accumulations");
        expect_eq(result_valid, 0, "no result without last");

        $display("tb_processing_element: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("TEST_RESULT: PASS tb_processing_element");
        else             $display("TEST_RESULT: FAIL tb_processing_element");
        $finish;
    end

    initial begin
        #100000;
        $display("TEST_RESULT: FAIL tb_processing_element (timeout)");
        $finish;
    end
endmodule
