`timescale 1ns/1ps
// Unit test of output_buffer: staggered/simultaneous captures, counts,
// all_captured_next look-ahead, clear, and duplicate-capture detection.
module tb_output_buffer;
    reg clk = 0, rst_n = 0, clear = 0;
    reg  [511:0] result_flat = 0;
    reg  [15:0]  result_valid = 0;
    wire [511:0] c_flat;
    wire [15:0]  c_valid_bits;
    wire all_valid, all_captured_next, capture_error;
    wire [4:0] capture_count;

    output_buffer #(.ACC_W(32)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .result_flat(result_flat), .result_valid(result_valid),
        .c_flat(c_flat), .c_valid_bits(c_valid_bits), .all_valid(all_valid),
        .all_captured_next(all_captured_next), .capture_count(capture_count), .capture_error(capture_error)
    );
    always #5 clk = ~clk;

    integer errors = 0, p;
    task chk(input cond, input [8*40-1:0] what);
        begin if (!cond) begin errors = errors + 1; $display("FAIL: %0s", what); end end
    endtask
    task pulse(input [15:0] mask);
        begin
            result_valid = mask;
            for (p = 0; p < 16; p = p + 1) result_flat[p*32 +: 32] = 32'd1000 * (p + 1) - 7;
            @(posedge clk); #1; result_valid = 0;
        end
    endtask

    initial begin
        @(posedge clk); @(posedge clk); #1; rst_n = 1;
        chk(c_flat == 0 && c_valid_bits == 0 && !all_valid && capture_count == 0 && !capture_error, "reset state");

        // anti-diagonal style staggered captures, several at once
        pulse(16'h0001); chk(capture_count == 1 && c_valid_bits == 16'h0001, "1 capture");
        pulse(16'h0012); chk(capture_count == 3, "2 simultaneous captures counted as 2");
        pulse(16'h0F00); chk(capture_count == 7, "4 simultaneous captures counted as 4");
        chk(!capture_error, "no duplicate so far");
        chk(!all_valid && !all_captured_next, "not complete");
        // final pulse completes: look-ahead high in the same cycle, registered valid next cycle
        result_valid = 16'hF0EC;
        for (p = 0; p < 16; p = p + 1) result_flat[p*32 +: 32] = 32'd1000 * (p + 1) - 7;
        #1;
        chk(all_captured_next && !all_valid, "all_captured_next leads all_valid by one cycle");
        @(posedge clk); #1; result_valid = 0;
        chk(all_valid && capture_count == 16 && !capture_error, "complete: 16 captures, no error");
        chk($signed(c_flat[15*32 +: 32]) == 32'sd15993, "element 15 stored");
        chk($signed(c_flat[0*32 +: 32]) == 32'sd993, "element 0 stored");

        // duplicate capture must be flagged
        pulse(16'h0004);
        chk(capture_error, "duplicate capture flagged");
        // clear wipes data, valid, count, error
        clear = 1; @(posedge clk); #1; clear = 0;
        chk(c_flat == 0 && c_valid_bits == 0 && capture_count == 0 && !capture_error && !all_valid, "clear");
        // negative values stored as signed
        result_valid = 16'h0001; result_flat[31:0] = -32'sd65536; @(posedge clk); #1; result_valid = 0;
        chk($signed(c_flat[31:0]) == -32'sd65536, "negative result");
        // reset clears
        rst_n = 0; @(posedge clk); #1; rst_n = 1;
        chk(c_valid_bits == 0 && c_flat == 0 && capture_count == 0, "reset");

        $display("tb_output_buffer: %0d errors", errors);
        if (errors == 0) $display("TEST_RESULT: PASS tb_output_buffer");
        else             $display("TEST_RESULT: FAIL tb_output_buffer");
        $finish;
    end
endmodule
