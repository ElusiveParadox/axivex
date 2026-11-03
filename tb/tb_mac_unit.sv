`timescale 1ns/1ps
// Exhaustive INT8 x INT8 check of mac_unit against integer arithmetic,
// repeated for several accumulator seeds, plus accumulator-chain checks.
module tb_mac_unit;
    reg  signed [7:0]  a, b;
    reg  signed [31:0] acc_in;
    wire signed [15:0] product;
    wire signed [31:0] acc_out;

    mac_unit #(.DATA_W(8), .ACC_W(32)) dut (
        .a(a), .b(b), .acc_in(acc_in), .product(product), .acc_out(acc_out)
    );

    integer ia, ib, s, errors, checks;
    integer exp_p, exp_s;
    integer seeds [0:5];
    integer chain, kk;

    initial begin
        errors = 0; checks = 0;
        seeds[0] = 0; seeds[1] = 1; seeds[2] = -1;
        seeds[3] = 65536; seeds[4] = -65536; seeds[5] = 2147000000;
        for (s = 0; s < 6; s = s + 1) begin
            for (ia = -128; ia <= 127; ia = ia + 1) begin
                for (ib = -128; ib <= 127; ib = ib + 1) begin
                    a = ia; b = ib; acc_in = seeds[s];
                    #1;
                    exp_p = ia * ib;
                    exp_s = seeds[s] + exp_p;
                    checks = checks + 1;
                    if (product !== exp_p[15:0] || acc_out !== exp_s[31:0]) begin
                        errors = errors + 1;
                        if (errors < 10)
                            $display("FAIL a=%0d b=%0d acc=%0d product=%0d acc_out=%0d exp=%0d/%0d",
                                     ia, ib, seeds[s], product, acc_out, exp_p, exp_s);
                    end
                end
            end
        end
        // chain of four extreme products: 4 * (-128 * -128) = 65536
        chain = 0; acc_in = 0;
        for (kk = 0; kk < 4; kk = kk + 1) begin
            a = -128; b = -128; #1;
            acc_in = acc_out;
            chain = chain + 16384;
        end
        checks = checks + 1;
        if (acc_in !== chain) begin errors = errors + 1; $display("FAIL chain %0d vs %0d", acc_in, chain); end
        // negative chain: 4 * (-128 * 127) = -65024
        chain = 0; acc_in = 0;
        for (kk = 0; kk < 4; kk = kk + 1) begin
            a = -128; b = 127; #1;
            acc_in = acc_out;
            chain = chain - 16256;
        end
        checks = checks + 1;
        if (acc_in !== chain) begin errors = errors + 1; $display("FAIL neg chain %0d vs %0d", acc_in, chain); end

        $display("tb_mac_unit: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("TEST_RESULT: PASS tb_mac_unit");
        else             $display("TEST_RESULT: FAIL tb_mac_unit");
        $finish;
    end
endmodule
