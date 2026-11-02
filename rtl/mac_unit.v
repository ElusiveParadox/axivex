`timescale 1ns/1ps
module mac_unit #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
) (
    input  wire signed [DATA_W-1:0]   a,
    input  wire signed [DATA_W-1:0]   b,
    input  wire signed [ACC_W-1:0]    acc_in,
    output wire signed [2*DATA_W-1:0] product,
    output wire signed [ACC_W-1:0]    acc_out
);
    localparam PROD_W = 2*DATA_W;
    localparam EXT_W  = ACC_W - PROD_W;

    assign product = a * b;

    wire signed [ACC_W-1:0] product_ext = {{EXT_W{product[PROD_W-1]}}, product};

    assign acc_out = acc_in + product_ext;
endmodule
