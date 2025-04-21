`default_nettype none
`timescale 1ns/1ns

module exp #(
  parameter int DW = 32
)(
  input  logic         clk,
  input  logic         rst,
  input  logic signed [DW-1:0] q,
  output logic signed [DW-1:0] q_out
);
    // Constants
    localparam int SCALE = 256;    // Scaling factor for 8 fractional bits
    localparam int LN2 = 177;      // ln(2) * 256 ≈ 177
    localparam int A = 92;         // Scaled coefficient ≈ 0.3585 * 256
    localparam int B = 346;        // Shift term ≈ 1.353 * 256
    localparam int C = 88;         // Constant term ≈ 0.344 * 256

    // Signed input
    logic signed [DW-1:0] q_signed;
    assign q_signed = $signed(q);

    // Decompose q into z and p: q = z * LN2 + p
    logic signed [DW-1:0] z_signed;
    assign z_signed = q_signed / LN2;  // Signed division, truncates toward zero

    logic signed [DW-1:0] p;
    assign p = q_signed - z_signed * LN2;  // Remainder

    // Polynomial approximation: L(p) = 0.3585 * (p + 1.353)^2 + 0.344
    logic signed [DW-1:0] t;
    assign t = p + B;  // t = p + 1.353 * 256

    logic signed [2*DW-1:0] t2;
    assign t2 = t * t;

    logic signed [3*DW-1:0] q_L;
    assign q_L = ((A * t2) >>> 16) + C;  // re-quantize to keep scale of 256

    // Shift based on z
    logic signed [3*DW-1:0] shifted_q_L;
    assign q_out = (z_signed >= 0) ? (q_L << z_signed) : (q_L >> (-z_signed));


endmodule
