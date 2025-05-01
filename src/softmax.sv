
`default_nettype none
`timescale 1ns/1ps

module softmax #(
    parameter int DW            = 32,
    parameter int N             = 32,
    parameter int SREQ          = 32767,
    parameter int EXP_FP_BITS   = 8,
    parameter int MAX_BITS      = 30,
    parameter int OUT_BITS      = 8

)(
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     enable,

    input  logic                     in_valid,
    input  logic  signed [DW-1:0]    x_in,

    output logic                     out_valid,
    output logic  signed [DW-1:0]    y_out
);
    logic [$clog2(N):0] idx, exp_idx, div_idx;
    logic        fifo_a_wr_en, fifo_a_rd_en, fifo_a_empty, fifo_a_full;
    logic signed [DW-1:0] fifo_a_data_in, fifo_a_data_out;
    logic        fifo_b_wr_en, fifo_b_rd_en, fifo_b_empty, fifo_b_full;
    logic signed [DW-1:0] fifo_b_data_in, fifo_b_data_out;

    // ------------------------------------------------------------------

    fifo #(.DW(DW), .N(N)) fifo_a (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_a_wr_en),
        .rd_en(fifo_a_rd_en),
        .data_in(fifo_a_data_in),
        .data_out(fifo_a_data_out),
        .full(fifo_a_full),
        .empty(fifo_a_empty)
    );

    fifo #(.DW(DW), .N(N)) fifo_b (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_b_wr_en),
        .rd_en(fifo_b_rd_en),
        .data_in(fifo_b_data_in),
        .data_out(fifo_b_data_out),
        .full(fifo_b_full),
        .empty(fifo_b_empty)
    );

    // Find max
    logic signed [DW-1:0] xmax;
    logic max_done;
    always @(posedge clk) begin
      if (enable) begin
        if (rst) begin
          xmax <= 0;
          idx <= 0;
          max_done <= 1'b0;
        end else begin
          if (idx == N) begin
            max_done <= 1'b1;
          end
          if (in_valid && idx < N) begin
            xmax <= x_in > xmax ? x_in : xmax; // updating x_max if x_in is greater
            idx <= idx + 1;
            fifo_a_wr_en <= 1'b1; // fifo starts writing on the same cycle that fifo_a_wr_en is high
            fifo_a_data_in <= x_in;
            // y_out <= x_in[idx] - xmax; // subtract max  UNCOMMENT TO TEST FUNCTIONALITY IN ISOLATION
          end
          else begin
            fifo_a_wr_en <= 1'b0;
          end
        end
      end
    end

    // Subtract max
    logic signed [DW-1:0] x_tilde;
    always @(posedge clk) begin
      if (enable) begin
        if (max_done && !fifo_a_empty) begin
          fifo_a_rd_en <= 1'b1;
        end
        else begin
          fifo_a_rd_en <= 1'b0;
        end
        x_tilde <= fifo_a_data_out - xmax; // change x_tilde to y_out to test functionality in isolation
      end
    end

    // 2. exponentiate

    logic [DW-1:0] qexp_32;

    exp #(.DW(DW)) exp_inst(
        .clk (clk), 
        .rst (rst),
        .q   (x_tilde),
        .q_out(qexp_32)
    );

    logic [2*DW-1:0] qexp_64;
    assign qexp_64 = qexp_32 * SREQ; // 2*DW bits to avoid overflow

    localparam Q_REQ_W = DW/2;
    logic [Q_REQ_W:0] q_req;
    assign q_req = qexp_64 >> EXP_FP_BITS; // 16 bits shifted by 8 bits to get Q8 format

    // 3. accumulate Σe^x  (extra +log₂N bits for headroom)

    logic signed [DW-1:0] q_sum;
    logic [$clog2(N)-1:0] sum_idx = 0; // sum counter
    logic sum_done = 1'b0;
    
    logic accumulate_en;

    always @(posedge clk) begin
      if (enable) begin
        if (rst) begin
          q_sum <= 0;
          accumulate_en <= 0;
        end else begin
          fifo_b_wr_en <= (^q_req !== 1'bx);  // 1 if q_req is not xxx
          fifo_b_data_in <= q_req;
          accumulate_en <= !fifo_a_full && fifo_a_rd_en;  // Set when data is being processed
          if (accumulate_en) begin
            q_sum <= q_sum + q_req;  // Accumulate when q_req is valid
            sum_idx <= sum_idx + 1;
            if (sum_idx == N-1) begin
              sum_done <= 1'b1; // Set when all elements have been processed
            end
          end
        end
      end
    end

    // 4. division - find reciprocal of Σe^x to mulptiply with e^x
    logic [DW-1:0] dividend;
    logic [DW-1:0] divisor;
    logic [DW-1:0] quotient;
    logic [DW-1:0] remainder;
    logic divider_start;
    logic divider_done;

    assign divisor     =  q_sum;                       // q_sum is now stable
    assign divider_start = sum_done ? 1'b1 : 1'b0; // start divider when sum is done
    assign dividend = 1 << MAX_BITS; // 2^30 = 1073741824

    divider #(.DW(DW)) div_inst (
        .clk(clk),
        .rst(rst),
        .start(divider_start),
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .remainder(remainder),    
        .done(divider_done)
    );

    localparam int SHIFT = MAX_BITS - OUT_BITS; // calculating how many to shift down to get target out_bits
    
    logic [$clog2(N)-1:0] out_idx;
    logic [OUT_BITS:0] scaled;
    always @(posedge clk) begin
      if (enable) begin
        if (rst) begin
          fifo_b_rd_en <= 1'b0;
          out_valid <= 1'b0;
          out_idx <= 0;
        end
        else begin
          if (divider_done && !fifo_b_empty) begin
            fifo_b_rd_en <= 1'b1; 
            if (^fifo_b_data_out !== 1'bx) begin // check if fifo_b_data_out is not xxx
              y_out <= (quotient * fifo_b_data_out) >> SHIFT; // multiply by reciprocal and shift down to get Q8 format
              out_valid <= 1'b1;
            end
          end
          else begin
            fifo_b_rd_en <= 1'b0;
          end
        end
      end
    end

endmodule
