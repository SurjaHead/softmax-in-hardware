`default_nettype none
`timescale 1ns/1ns

module subtract #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 32
) (
    input  logic clk,
    input  logic rst,
    input  logic signed [DATA_WIDTH-1:0] x,
    input  logic signed [DATA_WIDTH-1:0] x_max,
    output logic signed [DATA_WIDTH-1:0] out
);

assign out = x - x_max; 

endmodule