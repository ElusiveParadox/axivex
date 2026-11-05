// output_buffer: captures each PE result on its result_valid pulse.
// `clear` (transaction accept) zeroes data and valid bits. Several PEs may
// finish in the same cycle; each element has its own valid bit.
//   all_valid          : every element captured (registered state)
//   all_captured_next  : every element captured, counting this cycle's pulses
//   capture_count      : total captures this transaction (popcount accumulated)
//   capture_error      : sticky; a PE pulsed result_valid for an element that
//                        was already captured (duplicate result)
`timescale 1ns/1ps
module output_buffer #(
    parameter ACC_W = 32
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                clear,
    input  wire [16*ACC_W-1:0] result_flat,
    input  wire [15:0]         result_valid,

    output reg  [16*ACC_W-1:0] c_flat,
    output reg  [15:0]         c_valid_bits,
    output wire                all_valid,
    output wire                all_captured_next,
    output reg  [4:0]          capture_count,
    output reg                 capture_error
);
    integer n;
    reg [4:0] pulses;

    always @* begin
        pulses = 5'd0;
        for (n = 0; n < 16; n = n + 1)
            pulses = pulses + {4'b0, result_valid[n]};
    end

    assign all_valid         = &c_valid_bits;
    assign all_captured_next = &(c_valid_bits | result_valid);

    genvar p;
    generate
        for (p = 0; p < 16; p = p + 1) begin : g_cap
            always @(posedge clk) begin
                if (!rst_n || clear) begin
                    c_flat[p*ACC_W +: ACC_W] <= {ACC_W{1'b0}};
                    c_valid_bits[p]          <= 1'b0;
                end else if (result_valid[p]) begin
                    c_flat[p*ACC_W +: ACC_W] <= result_flat[p*ACC_W +: ACC_W];
                    c_valid_bits[p]          <= 1'b1;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n || clear) begin
            capture_count <= 5'd0;
            capture_error <= 1'b0;
        end else begin
            capture_count <= capture_count + pulses;
            if (|(result_valid & c_valid_bits)) capture_error <= 1'b1;
        end
    end
endmodule
