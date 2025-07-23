// `default_nettype none
// `timescale 1ns/1ns

// module max #(
//   parameter int DW = 32,
//   parameter int N  = 32
// )(
//   input  logic                   clk,
//   input  logic                   rst,
//   input  logic                   start,
//   input  logic signed [DW-1:0]   din,
//   input  logic                   din_valid,
//   output logic                   done,
//   output logic signed [DW-1:0]   max_out  
// );                                     

//   logic [$clog2(N)-1:0]   load_counter;
//   logic                   fifo_full, fifo_empty;
//   logic                   loading;
//   logic                   fifo_rd_en;
//   logic signed [DW-1:0]   fifo_data_out;
//   logic signed [DW-1:0]   q_max;

//   fifo #(
//     .DW(DW),
//     .N    (N)
//   ) fifo_inst (
//     .clk      (clk),
//     .rst    (rst),
//     .write_en (din_valid),
//     .read_en  (fifo_rd_en),
//     .data_in  (din),
//     .data_out (fifo_data_out),
//     .full     (fifo_full),
//     .empty    (fifo_empty)
//   );

//   // Simple FSM skeleton
//   typedef enum logic [1:0] { IDLE, LOAD, FIND_MAX, DONE } state_t;
//   state_t current_state, next_state;

//   // state register
//   always_ff @(posedge clk or posedge rst) begin
//     if (rst) begin
//       current_state <= IDLE;
//       q_max         <= 1'b0;
//       load_counter <= 1'b0;
//     end else begin
//       current_state <= next_state;
//       if (next_state == LOAD) begin
//         load_counter  <= load_counter + 1;
//       end
//     end
//   end

//   // next‑state + outputs
//   always_comb begin
//     // defaults
//     next_state = current_state;
//     done       = 1'b0;
//     fifo_rd_en = 1'b0;

//     case (current_state)
//       IDLE: if (start) next_state = LOAD;

//       LOAD: begin
//         if (load_counter < N && din_valid) begin
//           next_state    = LOAD;
//         end else begin
//           next_state    = FIND_MAX;
//         end
//       end

//       FIND_MAX: begin
//         if (!fifo_empty) begin
//           fifo_rd_en = 1'b1;
//           // capture max
//           if (fifo_data_out > q_max)
//             q_max = fifo_data_out;
//           next_state = FIND_MAX;
//         end else begin
//           next_state = DONE;
//         end
//       end

//       DONE: begin
//         done       = 1'b1;
//         next_state = IDLE;
//       end
//     endcase
//   end

//   // drive the output
//   assign max_out = q_max;

// endmodule








`default_nettype none
`timescale 1ns/1ns

module max #(
  parameter int DW = 32,
  parameter int N  = 32
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   start,
  input  logic signed [DW-1:0]   din,
  input  logic                   din_valid,
  output logic                   done,
  output logic signed [DW-1:0]   max_out  
);                                     

  logic [$clog2(N)-1:0]   load_counter;
  logic                   fifo_full, fifo_empty;
  logic                   loading;
  logic                   fifo_rd_en;
  logic signed [DW-1:0]   fifo_data_out;
  logic signed [DW-1:0]   q_max;

  fifo #(
    .DW(DW),
    .N(N)
  ) fifo_inst (
    
    .clk(clk),
    .rst(rst),  // Fixed to active-low reset
    .write_en(din_valid),
    .read_en(fifo_rd_en),
    .data_in(din),
    .data_out(fifo_data_out),
    .full(fifo_full),
    .empty(fifo_empty)
  );

  typedef enum logic [1:0] { IDLE, LOAD, FIND_MAX, DONE } state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      current_state <= IDLE;
      q_max         <= -32'h80000000;  // Smallest 32-bit signed integer
      load_counter  <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == LOAD && din_valid) begin
        load_counter <= load_counter + 1;
      end
      if (current_state == FIND_MAX && !fifo_empty) begin
        if (fifo_data_out > q_max) begin
          q_max <= fifo_data_out;
        end
      end
    end
  end

  always_comb begin
    next_state = current_state;
    done       = 1'b0;
    fifo_rd_en = 1'b0;

    case (current_state)
      IDLE: if (start) next_state = LOAD;

      LOAD: begin
        if (load_counter < N && din_valid) begin
          next_state = LOAD;
        end else begin
          next_state = FIND_MAX;
        end
      end

      FIND_MAX: begin
        if (!fifo_empty) begin
          fifo_rd_en = 1'b1;
          next_state = FIND_MAX;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        done       = 1'b1;
        next_state = IDLE;
      end
    endcase
  end

  assign max_out = q_max;

endmodule