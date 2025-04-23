// `default_nettype none
// `timescale 1ns/1ns

// // WORK IN PROGRESS

// module softmax #(
//     parameter int DW = 32,
//     parameter int N = 32, // Number of elements x_in the input vector
//     parameter int FP_BITS = 30,
//     parameter int MAX_BITS = 30,
//     parameter int OUT_BITS = 6

// ) (
//     input logic clk,
//     input logic rst,
//     input logic start,
//     input logic in_valid,
//     input logic signed [DW-1:0] x_in [0:N-1],   // Input matrix (fixed-point int32)
//     output logic signed [DW-1:0] out,  // Softmax outputs (fixed-point int32)
//     output logic done
// );
//     // Signals for max module
//     logic max_start;
//     logic signed [DW-1:0] max_din;
//     logic max_din_valid;
//     logic find_max_done;
//     logic signed [DW-1:0] q_max;

//     // Signals for exp module
//     logic signed [DW-1:0] x_tilde;
//     logic signed [DW-1:0] exp_input;
//     logic signed [DW-1:0] exp_output;
//     logic start_exp;

//     // Signals for sum and division
//     logic signed [DW-1:0] running_sum;
//     logic signed [DW-1:0] dividend, divisor, quotient, remainder;
//     logic divider_start;
//     logic divider_done;

//     // FIFO signals
//     logic [$clog2(N)-1:0] load_idx, div_idx;
//     logic fifo_a_wr_en, fifo_a_rd_en, fifo_a_empty, fifo_a_full;
//     logic signed [DW-1:0] fifo_a_data_out, fifo_a_data_in;
//     logic fifo_b_wr_en, fifo_b_rd_en, fifo_b_empty, fifo_b_full;
//     logic signed [DW-1:0] fifo_b_data_out, fifo_b_data_in;

//     // State machine
//     typedef enum logic [3:0] {
//         IDLE,
//         START_MAX,
//         LOAD_MAX,
//         WAIT_MAX,
//         SUBTRACT_MAX,
//         COMPUTE_EXP,
//         SUM_EXP,
//         START_DIV,
//         WAIT_DIV,
//         OUTPUT_DIV,
//         TEST_DONE
//     } state_t;
//     state_t state;

//     // Divider instance
//     divider #(
//         .DW(DW)
//     ) div_inst (
//         .clk(clk),
//         .rst(rst),
//         .start(divider_start),
//         .dividend(dividend),
//         .divisor(divisor),
//         .quotient(quotient),
//         .remainder(remainder),
//         .done(divider_done)
//     );

//     // Max instance
//     max #(
//         .DW(DW),
//         .N(N)
//     ) max_inst (
//         .clk(clk),
//         .rst(rst),
//         .start(max_start),
//         .din(max_din),
//         .din_valid(max_din_valid),
//         .done(find_max_done),
//         .max_out(q_max)
//     );

//     // Exp instance
//     exp #(
//         .DW(DW)
//     ) exp_inst (
//         .clk(clk),
//         .rst(rst),
//         .q(exp_input),
//         .q_out(exp_output)
//     );

//     // FIFO instances
//     fifo #(
//         .DW(DW),
//         .N(N)
//     ) fifo_a (
//         .clk(clk),
//         .rst_n(~rst),
//         .write_en(fifo_a_wr_en),
//         .read_en(fifo_a_rd_en),
//         .data_in(fifo_a_data_in),
//         .data_out(fifo_a_data_out),
//         .full(fifo_a_full),
//         .empty(fifo_a_empty)
//     );

//     fifo #(
//         .DW(DW),
//         .N(N)
//     ) fifo_b (
//         .clk(clk),
//         .rst_n(~rst),
//         .write_en(fifo_b_wr_en),
//         .read_en(fifo_b_rd_en),
//         .data_in(fifo_b_data_in),
//         .data_out(fifo_b_data_out),
//         .full(fifo_b_full),
//         .empty(fifo_b_empty)
//     );
//     // State machine
//     always_ff @(posedge clk or posedge rst) begin
//         if (rst) begin
//             state <= IDLE;
//             done <= 1'b0;
//             load_idx <= 0;
//             div_idx <= 0;
//             max_start <= 1'b0;
//             max_din_valid <= 1'b0;
//             fifo_a_wr_en <= 1'b0;
//             fifo_b_wr_en <= 1'b0;
//             fifo_a_rd_en <= 1'b0;
//             fifo_b_rd_en <= 1'b0;
//             running_sum <= 0;
//             divider_start <= 1'b0;
//             out <= 0;
//         end else begin
//             case (state)
//                 IDLE: begin
//                     if (start) begin
//                         state <= START_MAX;
//                         done <= 1'b0;
//                         load_idx <= 0;
//                     end
//                 end

//                 START_MAX: begin
//                     max_start <= 1'b1;      // Pulse start for one cycle
//                     state <= LOAD_MAX;
//                 end

//                 LOAD_MAX: begin
//                     max_start <= 1'b0;      // Deassert start after one cycle
//                     if (load_idx < N) begin
//                         max_din <= x_in[load_idx];
//                         max_din_valid <= 1'b1;
//                         fifo_a_wr_en <= 1'b1; // Store inputs x_in fifo_a
//                         fifo_a_data_in <= x_in[load_idx];
//                         load_idx <= load_idx + 1;
//                     end else begin
//                         max_din_valid <= 1'b0;
//                         fifo_a_wr_en <= 1'b0;
//                         state <= WAIT_MAX;
//                     end
//                 end

//                 WAIT_MAX: begin
//                     if (find_max_done) begin
//                         state <= SUBTRACT_MAX;
//                         // q_max is now valid for use
//                     end
//                 end

//                 SUBTRACT_MAX: begin
//                     if (!fifo_a_empty) begin
//                         fifo_a_rd_en <= 1'b1;                     // read next element
//                         x_tilde      <= fifo_a_data_out - q_max;  // subtract max
//                         start_exp    <= 1'b1;                     // assert for exactly one cycle
//                         state        <= COMPUTE_EXP;
//                     end else begin
//                         fifo_a_rd_en <= 1'b0;
//                         state        <= SUM_EXP;                  // move on when done
//                     end
//                 end

//                 // COMPUTE_EXP: capture exp_output, clear start_exp, loop back
//                 COMPUTE_EXP: begin
//                     start_exp     <= 1'b0;        // de‑assert pulse immediately
//                     fifo_b_wr_en  <= 1'b1;        // write exp_output into FIFO
//                     fifo_b_data_in <= exp_output;
//                     state         <= SUBTRACT_MAX; // process next element
//                 end

//                 SUM_EXP: begin
//                     if (!fifo_b_empty) begin
//                         fifo_b_rd_en <= 1'b1;                          // read one value :contentReference[oaicite:10]{index=10}
//                         running_sum  <= running_sum + fifo_b_data_out; // accumulate
//                         state        <= SUM_EXP;                       // stay until empty
//                     end else begin
//                         state        <= START_DIV;                     // all summed
//                     end
//                 end

//                 START_DIV: begin
//                     if (div_idx < N) begin
//                         fifo_a_rd_en  <= 1'b1;     // read numerator :contentReference[oaicite:11]{index=11}
//                         dividend      <= fifo_a_data_out;
//                         divisor       <= running_sum;
//                         divider_start <= 1'b1;     // one‑cycle start :contentReference[oaicite:12]{index=12}
//                         state         <= WAIT_DIV;
//                     end else begin
//                         state <= TEST_DONE;        // all divisions done → done&#8203;:contentReference[oaicite:13]{index=13}
//                     end
//                 end

//                 WAIT_DIV: begin
//                     if (!divider_done) begin
//                         fifo_b_rd_en <= 1'b0;
//                         divider_start <= 1'b0;
//                         state <= WAIT_DIV;
//                     end else begin
//                         state <= OUTPUT_DIV;
//                     end
//                 end

//                 OUTPUT_DIV: begin
//                     out <= quotient;
//                     div_idx <= div_idx + 1;
//                     if (!fifo_a_empty) begin
//                     state <= START_DIV;
//                      end else begin
//                         state <= TEST_DONE;
//                     end
//                 end


//                 TEST_DONE: begin
//                     done <= 1'b1;
//                     state <= IDLE;
//                 end

//                 default: state <= IDLE;
//             endcase
//         end
//     end

// endmodule 









// `default_nettype none
// `timescale 1ns/1ns

// module softmax #(
//     parameter int DW       = 32,
//     parameter int N        = 32, // Number of elements in the input vector
//     parameter int FP_BITS  = 30,
//     parameter int MAX_BITS = 30,
//     parameter int OUT_BITS = 6
// ) (
//     input  logic                   clk,
//     input  logic                   rst,
//     input  logic                   start,
//     input  logic                   in_valid,
//     input  logic signed [DW-1:0]   x_in [0:N-1],
//     output logic signed [DW-1:0]   out,
//     output logic                   done
// );

//   // ------------------------------------------------------------------
//   // 1) Local declarations (unchanged)
//   // ------------------------------------------------------------------
//   // Max module signals
//   logic        max_start, max_din_valid;
//   logic signed [DW-1:0] max_din, q_max;
//   logic        find_max_done;

//   // Exp module signals
//   logic signed [DW-1:0] x_tilde, exp_input, exp_output;
//   logic        start_exp;

//   // Sum & divider
//   logic signed [DW-1:0] running_sum, dividend, divisor, quotient, remainder;
//   logic        divider_start, divider_done;

//   // FIFOs
//   logic [$clog2(N)-1:0] load_idx, div_idx;
//   logic        fifo_a_wr_en, fifo_a_rd_en, fifo_a_empty, fifo_a_full;
//   logic signed [DW-1:0] fifo_a_data_in, fifo_a_data_out;
//   logic        fifo_b_wr_en, fifo_b_rd_en, fifo_b_empty, fifo_b_full;
//   logic signed [DW-1:0] fifo_b_data_in, fifo_b_data_out;

//   // State encoding
//   typedef enum logic [3:0] {
//     IDLE,
//     START_MAX,
//     LOAD_MAX,
//     WAIT_MAX,
//     SUBTRACT_MAX,
//     COMPUTE_EXP,
//     SUM_EXP,
//     START_DIV,
//     WAIT_DIV,
//     OUTPUT_DIV,
//     TEST_DONE
//   } state_t;

//   state_t state, next_state;

//   // ------------------------------------------------------------------
//   // 2) State register (sequential)
//   // ------------------------------------------------------------------
//   always_ff @(posedge clk or posedge rst) begin
//     if (rst) begin
//       state        <= IDLE;
//       done         <= 1'b0;
//       load_idx     <= 0;
//       div_idx      <= 0;
//       running_sum  <= 0;
//       out          <= 0;
//       // (we assume other regs are reset inside their own modules)
//     end else begin
//       state        <= next_state;

//       // State-dependent updates to datapath registers
//       case (state)
//         START_MAX:    max_start     <= 1'b1;
//         LOAD_MAX: begin
//           max_start      <= 1'b0;
//           if (load_idx < N) begin
//             max_din       <= x_in[load_idx];
//             max_din_valid <= 1'b1;
//             fifo_a_wr_en  <= 1'b1;
//             fifo_a_data_in<= x_in[load_idx];
//             load_idx      <= load_idx + 1;
//           end else begin
//             max_din_valid <= 1'b0;
//             fifo_a_wr_en  <= 1'b0;
//           end
//         end

//         WAIT_MAX:     /* nothing registers */ ;

//         SUBTRACT_MAX: if (!fifo_a_empty) begin
//           fifo_a_rd_en   <= 1'b1;
//           x_tilde        <= fifo_a_data_out - q_max;
//           start_exp      <= 1'b1;
//         end

//         COMPUTE_EXP: begin
//           start_exp       <= 1'b0;
//           fifo_b_wr_en    <= 1'b1;
//           fifo_b_data_in  <= exp_output;
//         end

//         SUM_EXP: if (!fifo_b_empty) begin
//           fifo_b_rd_en    <= 1'b1;
//           running_sum     <= running_sum + fifo_b_data_out;
//         end

//         START_DIV: if (div_idx < N) begin
//           fifo_a_rd_en    <= 1'b1;
//           dividend        <= fifo_a_data_out;
//           divisor         <= running_sum;
//           divider_start   <= 1'b1;
//         end

//         WAIT_DIV:      /* divider_start auto-cleared below */ ;

//         OUTPUT_DIV: begin
//           out             <= quotient;
//           div_idx         <= div_idx + 1;
//         end

//         TEST_DONE:    done           <= 1'b1;

//         default:      /* nothing */ ;
//       endcase

//       // De-assert single-cycle pulses in all other states:
//       if (state != START_MAX)    max_start    <= 1'b0;
//       if (state != LOAD_MAX)     max_din_valid<= 1'b0;
//       if (state != SUBTRACT_MAX) fifo_a_rd_en <= 1'b0;
//       if (state != COMPUTE_EXP)  fifo_b_wr_en <= 1'b0;
//       if (state != SUM_EXP)      fifo_b_rd_en <= 1'b0;
//       if (state != START_DIV)    divider_start<= 1'b0;
//     end
//   end

//   // ------------------------------------------------------------------
//   // 3) Next-state & outputs logic (combinational)
//   // ------------------------------------------------------------------
//   always_comb begin
//     // Default: hold current state and clear done
//     next_state = state;

//     // State transitions
//     case (state)
//       IDLE:     if (start)      next_state = START_MAX;

//       START_MAX: next_state      = LOAD_MAX;

//       LOAD_MAX: if (load_idx >= N) next_state = WAIT_MAX;

//       WAIT_MAX: if (find_max_done) next_state = SUBTRACT_MAX;

//       SUBTRACT_MAX:
//         if (fifo_a_empty) next_state = SUM_EXP;
//         else               next_state = COMPUTE_EXP;

//       COMPUTE_EXP:           next_state = SUBTRACT_MAX;

//       SUM_EXP:
//         if (fifo_b_empty)  next_state = START_DIV;
//         else               next_state = SUM_EXP;

//       START_DIV:
//         if (div_idx >= N)  next_state = TEST_DONE;
//         else               next_state = WAIT_DIV;

//       WAIT_DIV:
//         if (divider_done)  next_state = OUTPUT_DIV;

//       OUTPUT_DIV:
//         if (fifo_a_empty)  next_state = TEST_DONE;
//         else               next_state = START_DIV;

//       TEST_DONE:            next_state = IDLE;

//       default:              next_state = IDLE;
//     endcase
//   end

//   // ------------------------------------------------------------------
//   // 4) Submodule instantiations (unchanged)
//   // ------------------------------------------------------------------
//   divider #(.DW(DW)) div_inst (
//     .clk(clk), .rst(rst),
//     .start(divider_start),
//     .dividend(dividend),
//     .divisor(divisor),
//     .quotient(quotient),
//     .remainder(remainder),
//     .done(divider_done)
//   );

//   max #(.DW(DW), .N(N)) max_inst (
//     .clk(clk), .rst(rst),
//     .start(max_start),
//     .din(max_din),
//     .din_valid(max_din_valid),
//     .done(find_max_done),
//     .max_out(q_max)
//   );

//   exp #(.DW(DW)) exp_inst (
//     .clk(clk), .rst(rst),
//     .q(exp_input),
//     .q_out(exp_output)
//   );

//   fifo #(.DW(DW), .N(N)) fifo_a (
//     .clk(clk), .rst_n(~rst),
//     .write_en(fifo_a_wr_en),
//     .read_en(fifo_a_rd_en),
//     .data_in(fifo_a_data_in),
//     .data_out(fifo_a_data_out),
//     .full(fifo_a_full),
//     .empty(fifo_a_empty)
//   );

//   fifo #(.DW(DW), .N(N)) fifo_b (
//     .clk(clk), .rst_n(~rst),
//     .write_en(fifo_b_wr_en),
//     .read_en(fifo_b_rd_en),
//     .data_in(fifo_b_data_in),
//     .data_out(fifo_b_data_out),
//     .full(fifo_b_full),
//     .empty(fifo_b_empty)
//   );

// endmodule










`default_nettype none
`timescale 1ns/1ns

module softmax #(
    parameter int DW       = 32,
    parameter int N        = 4, // Number of elements in the input vector
    parameter int FP_BITS  = 30,
    parameter int MAX_BITS = 30,
    parameter int OUT_BITS = 6
) (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   start,
    input  logic                   in_valid,
    input  logic signed [DW-1:0]   x_in [0:N-1],
    output logic signed [DW-1:0]   out,
    output logic                   done
);

  // ------------------------------------------------------------------
  // 1) Local declarations (modified to add output_cnt)
  // ------------------------------------------------------------------
  // Max module signals
  logic        max_start, max_din_valid;
  logic signed [DW-1:0] max_din, q_max;
  logic        find_max_done;

  // Exp module signals
  logic signed [DW-1:0] x_tilde, exp_input, exp_output;
  logic        start_exp;

  // Sum & divider
  logic signed [DW-1:0] running_sum, dividend, divisor, quotient, remainder;
  logic        divider_start, divider_done;

  // FIFOs
  logic [$clog2(N):0] load_idx, div_idx;
  logic        fifo_a_wr_en, fifo_a_rd_en, fifo_a_empty, fifo_a_full;
  logic signed [DW-1:0] fifo_a_data_in, fifo_a_data_out;
  logic        fifo_b_wr_en, fifo_b_rd_en, fifo_b_empty, fifo_b_full;
  logic signed [DW-1:0] fifo_b_data_in, fifo_b_data_out;

  // Added counter for OUTPUT_MAX state to output q_max N times
  logic [$clog2(N)-1:0] output_cnt;

  // State encoding (added OUTPUT_MAX state)
  typedef enum logic [3:0] {
    IDLE,
    START_MAX,
    LOAD_MAX,
    WAIT_MAX,
    OUTPUT_MAX,       // New state to output q_max N times
    SUBTRACT_MAX,     // Commented states below are bypassed
    COMPUTE_EXP,
    SUM_EXP,
    START_DIV,
    WAIT_DIV,
    OUTPUT_DIV,
    TEST_DONE
  } state_t;

  state_t state, next_state;

  // ------------------------------------------------------------------
  // 2) State register (sequential)
  // ------------------------------------------------------------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state        <= IDLE;
      done         <= 1'b0;
      load_idx     <= 0;
      div_idx      <= 0;
      running_sum  <= 0;
      out          <= 0;
      output_cnt   <= 0; // Reset output counter
      // (we assume other regs are reset inside their own modules)
    end else begin
      state        <= next_state;

      // State-dependent updates to datapath registers
      case (next_state)
        START_MAX:    max_start     <= 1'b1;
        LOAD_MAX: begin
          if (load_idx < N) begin
            // $display("Time=%0t: state=%0d, next_state=%0d, out=%0d, q_max=%0d", $time, state, next_state, out, q_max);
            max_din       <= x_in[load_idx];
            max_din_valid <= 1'b1;
            fifo_a_wr_en  <= 1'b1;
            fifo_a_data_in<= x_in[load_idx];
            load_idx      <= load_idx + 1;
            // $display("Time=%0t: state=%0d, next_state=%0d, out=%0d, q_max=%0d", $time, state, next_state, out, q_max);
          end else begin
            // $display("Time=%0t: state=%0d, next_state=%0d, out=%0d, q_max=%0d", $time, state, next_state, out, q_max);
            max_din_valid <= 1'b0;
            fifo_a_wr_en  <= 1'b0;
          end
        end

        WAIT_MAX:     /* nothing registers */ ;

        // New state to output q_max N times
        OUTPUT_MAX: begin
        // $display("Time=%0t: state=%0d, next_state=%0d, out=%0d, q_max=%0d", $time, state, next_state, out, q_max);
        //   out <= q_max;
          if (output_cnt < N-1) begin
            output_cnt <= output_cnt + 1;
          end else begin
            output_cnt <= 0;
          end
        end

        // Commented out states to disable them for this test
        
        SUBTRACT_MAX: if (!fifo_a_empty) begin
          fifo_a_rd_en   <= 1'b1;
          x_tilde        <= fifo_a_data_out - q_max;
          start_exp      <= 1'b1;
        end
/*
        COMPUTE_EXP: begin
          start_exp       <= 1'b0;
          fifo_b_wr_en    <= 1'b1;
          fifo_b_data_in  <= exp_output;
        end

        SUM_EXP: if (!fifo_b_empty) begin
          fifo_b_rd_en    <= 1'b1;
          running_sum     <= running_sum + fifo_b_data_out;
        end

        START_DIV: if (div_idx < N) begin
          fifo_a_rd_en    <= 1'b1;
          dividend        <= fifo_a_data_out;
          divisor         <= running_sum;
          divider_start   <= 1'b1;
        end

        WAIT_DIV:      // divider_start auto-cleared below;

        OUTPUT_DIV: begin
          out             <= quotient;
          div_idx         <= div_idx + 1;
        end
        */

        TEST_DONE:    done           <= 1'b1;

        default:      /* nothing */ ;
      endcase

      // De-assert single-cycle pulses in all other states:
      if (state != LOAD_MAX)     max_din_valid<= 1'b0;
      // Commented out to disable unused signals
      if (state != SUBTRACT_MAX) fifo_a_rd_en <= 1'b0;
      // if (state != COMPUTE_EXP)  fifo_b_wr_en <= 1'b0;
      // if (state != SUM_EXP)      fifo_b_rd_en <= 1'b0;
      // if (state != START_DIV)    divider_start<= 1'b0;
    end
  end

  // ------------------------------------------------------------------
  // 3) Next-state & outputs logic (combinational)
  // ------------------------------------------------------------------
  always_comb begin
    // Default: hold current state and clear done
    next_state = state;

    // State transitions
    case (state)
      IDLE:     if (start)      next_state = START_MAX;

      START_MAX: next_state      = LOAD_MAX;

      LOAD_MAX: if (load_idx >= N) next_state = WAIT_MAX;

      WAIT_MAX: if (find_max_done) next_state = OUTPUT_MAX; // Modified to go to OUTPUT_MAX

      OUTPUT_MAX: if (output_cnt == N-1) next_state = SUBTRACT_MAX;
                  else next_state = OUTPUT_MAX;

      // Commented out transitions to disable unused states
      
      SUBTRACT_MAX:
        if (fifo_a_empty) next_state = TEST_DONE;
        else               next_state = SUBTRACT_MAX;
        /*
      COMPUTE_EXP:           next_state = SUBTRACT_MAX;

      SUM_EXP:
        if (fifo_b_empty)  next_state = START_DIV;
        else               next_state = SUM_EXP;

      START_DIV:
        if (div_idx >= N)  next_state = TEST_DONE;
        else               next_state = WAIT_DIV;

      WAIT_DIV:
        if (divider_done)  next_state = OUTPUT_DIV;

      OUTPUT_DIV:
        if (fifo_a_empty)  next_state = TEST_DONE;
        else               next_state = START_DIV;
      */

      TEST_DONE:            next_state = IDLE;

      default:              next_state = IDLE;
    endcase
  end

  // ------------------------------------------------------------------
  // 4) Submodule instantiations (unchanged)
  // ------------------------------------------------------------------
  divider #(.DW(DW)) div_inst (
    .clk(clk), .rst(rst),
    .start(divider_start),
    .dividend(dividend),
    .divisor(divisor),
    .quotient(quotient),
    .remainder(remainder),
    .done(divider_done)
  );

  max #(.DW(DW), .N(N)) max_inst (
    .clk(clk), .rst(rst),
    .start(max_start),
    .din(max_din),
    .din_valid(max_din_valid),
    .done(find_max_done),
    .max_out(q_max)
  );

  exp #(.DW(DW)) exp_inst (
    .clk(clk), .rst(rst),
    .q(exp_input),
    .q_out(exp_output)
  );

  fifo #(.DW(DW), .N(N)) fifo_a (
    .clk(clk), .rst(rst),
    .write_en(fifo_a_wr_en),
    .read_en(fifo_a_rd_en),
    .data_in(fifo_a_data_in),
    .data_out(fifo_a_data_out),
    .full(fifo_a_full),
    .empty(fifo_a_empty)
  );

  fifo #(.DW(DW), .N(N)) fifo_b (
    .clk(clk), .rst(rst),
    .write_en(fifo_b_wr_en),
    .read_en(fifo_b_rd_en),
    .data_in(fifo_b_data_in),
    .data_out(fifo_b_data_out),
    .full(fifo_b_full),
    .empty(fifo_b_empty)
  );

endmodule































// `default_nettype none
// `timescale 1ns/1ns

// module softmax #(
//     parameter int DW       = 32,
//     parameter int N        = 4,
//     parameter int FP_BITS  = 30,
//     parameter int MAX_BITS = 30,
//     parameter int OUT_BITS = 6
// ) (
//     input  logic                   clk,
//     input  logic                   rst,
//     input  logic                   start,
//     input  logic                   in_valid,
//     input  logic signed [DW-1:0]   x_in [0:N-1],
//     output logic signed [DW-1:0]   out,
//     output logic                   done
// );

//   logic        max_start, max_din_valid;
//   logic signed [DW-1:0] max_din, q_max;
//   logic        find_max_done;
//   logic signed [DW-1:0] x_tilde, exp_input, exp_output;
//   logic        start_exp;
//   logic signed [DW-1:0] running_sum, dividend, divisor, quotient, remainder;
//   logic        divider_start, divider_done;
//   logic [$clog2(N+1)-1:0] load_idx, div_idx; // Increased bit width to hold N
//   logic        fifo_a_wr_en, fifo_a_rd_en, fifo_a_empty, fifo_a_full;
//   logic signed [DW-1:0] fifo_a_data_in, fifo_a_data_out;
//   logic        fifo_b_wr_en, fifo_b_rd_en, fifo_b_empty, fifo_b_full;
//   logic signed [DW-1:0] fifo_b_data_in, fifo_b_data_out;
//   logic [$clog2(N)-1:0] output_cnt;

//   typedef enum logic [3:0] {
//     IDLE,
//     START_MAX,
//     LOAD_MAX,
//     WAIT_MAX,
//     OUTPUT_MAX,
//     SUBTRACT_MAX,
//     COMPUTE_EXP,
//     SUM_EXP,
//     START_DIV,
//     WAIT_DIV,
//     OUTPUT_DIV,
//     TEST_DONE
//   } state_t;

//   state_t state, next_state;

//   always_ff @(posedge clk or posedge rst) begin
//     if (rst) begin
//       state        <= IDLE;
//       done         <= 1'b0;
//       load_idx     <= 0;
//       div_idx      <= 0;
//       running_sum  <= 0;
//       out          <= 0;
//       output_cnt   <= 0;
//     end else begin
//       state <= next_state;
//       $display("Time=%0t: state=%0d, next_state=%0d, load_idx=%0d, max_din_valid=%0d", $time, state, next_state, load_idx, max_din_valid);

//       case (next_state)
//         START_MAX:    max_start     <= 1'b1;
//         LOAD_MAX: begin
//           if (load_idx < N) begin
//             max_din       <= x_in[load_idx];
//             max_din_valid <= 1'b1;
//             fifo_a_wr_en  <= 1'b1;
//             fifo_a_data_in<= x_in[load_idx];
//             load_idx      <= load_idx + 1;
//             $display("Time=%0t: LOAD_MAX if: load_idx=%0d", $time, load_idx);
//           end else begin
//             $display("Time=%0t: LOAD_MAX else: load_idx=%0d", $time, load_idx);
//             max_din_valid <= 1'b0;
//             fifo_a_wr_en  <= 1'b0;
//           end
//         end

//         WAIT_MAX:     /* nothing */ ;

//         OUTPUT_MAX: begin
//           out <= q_max;
//           if (output_cnt < N-1) begin
//             output_cnt <= output_cnt + 1;
//           end else begin
//             output_cnt <= 0;
//           end
//         end

//         TEST_DONE:    done <= 1'b1;

//         default:      /* nothing */ ;
//       endcase

//       if (state != LOAD_MAX) max_din_valid <= 1'b0;
//     end
//   end

//   always_comb begin
//     next_state = state;
//     case (state)
//       IDLE:     if (start) next_state = START_MAX;
//       START_MAX: next_state = LOAD_MAX;
//       LOAD_MAX: if (load_idx >= N) next_state = WAIT_MAX;
//       WAIT_MAX: if (find_max_done) next_state = OUTPUT_MAX;
//       OUTPUT_MAX: if (output_cnt == N-1) next_state = TEST_DONE;
//                   else next_state = OUTPUT_MAX;
//       TEST_DONE: next_state = IDLE;
//       default: next_state = IDLE;
//     endcase
//   end

//   divider #(.DW(DW)) div_inst (
//     .clk(clk), .rst(rst),
//     .start(divider_start),
//     .dividend(dividend),
//     .divisor(divisor),
//     .quotient(quotient),
//     .remainder(remainder),
//     .done(divider_done)
//   );

//   max #(.DW(DW), .N(N)) max_inst (
//     .clk(clk), .rst(rst),
//     .start(max_start),
//     .din(max_din),
//     .din_valid(max_din_valid),
//     .done(find_max_done),
//     .max_out(q_max)
//   );

//   exp #(.DW(DW)) exp_inst (
//     .clk(clk), .rst(rst),
//     .q(exp_input),
//     .q_out(exp_output)
//   );

//   fifo #(.DW(DW), .N(N)) fifo_a (
//     .clk(clk), .rst_n(~rst),
//     .write_en(fifo_a_wr_en),
//     .read_en(fifo_a_rd_en),
//     .data_in(fifo_a_data_in),
//     .data_out(fifo_a_data_out),
//     .full(fifo_a_full),
//     .empty(fifo_a_empty)
//   );

//   fifo #(.DW(DW), .N(N)) fifo_b (
//     .clk(clk), .rst_n(~rst),
//     .write_en(fifo_b_wr_en),
//     .read_en(fifo_b_rd_en),
//     .data_in(fifo_b_data_in),
//     .data_out(fifo_b_data_out),
//     .full(fifo_b_full),
//     .empty(fifo_b_empty)
//   );

// endmodule