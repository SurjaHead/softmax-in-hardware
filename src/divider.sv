
`default_nettype none
`timescale 1ns/1ns


module divider #(
  parameter DATA_WIDTH=32
)(
  input  logic         clk,
  input  logic         rst_n,
  input  logic         start,        
  input  logic [DATA_WIDTH-1:0]  dividend,     
  input  logic [DATA_WIDTH-1:0]  divisor,      
  output logic [DATA_WIDTH-1:0]  quotient,     
  output logic [DATA_WIDTH-1:0]  remainder,   
  output logic         done         
);

  typedef enum logic [1:0] {
    IDLE,  
    CALC,  
    DONE 
  } state_t;
  
  state_t state, next_state;
  
  logic signed [DATA_WIDTH:0] rem_reg, next_rem; // 17-bit signed remainder
  logic [DATA_WIDTH:0]        quo_reg, next_quo;
  logic [$clog2(DATA_WIDTH):0]         count, next_count; // 5-bit counter for DATA_WIDTH iterations
  logic signed [DATA_WIDTH:0] sub_result;        
  
  // sequential block: update state and registers on each clock
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      quo_reg <= 0;
      rem_reg <= 0;
      count   <= 0;
    end else begin
      state   <= next_state; 
      quo_reg <= next_quo;
      rem_reg <= next_rem;
      count   <= next_count;
    end
  end
  
  // combinational block: determine next state and next values
  always_comb begin
    next_state = state;
    next_quo   = quo_reg;
    next_rem   = rem_reg;
    next_count = count;
    done       = 1'b0;
    
    case (state)
      IDLE: begin
        if (start) begin 
          next_quo   = dividend;
          next_rem   = 0;
          next_count = DATA_WIDTH;
          next_state = CALC;
        end
      end
      
      CALC: begin
        next_rem = {rem_reg[DATA_WIDTH-1:0], quo_reg[DATA_WIDTH-1]};
        next_quo = quo_reg << 1;
        
        sub_result = next_rem - {1'b0, divisor};
        if (sub_result >= 0) begin
          next_rem   = sub_result;
          next_quo[0] = 1'b1;
        end else begin
          next_quo[0] = 1'b0;
        end
        
        next_count = count - 1;
        if (count == 1)
          next_state = DONE;
      end
      
      DONE: begin
        done = 1'b1;
        next_state = DONE;
      end
    endcase
  end
  
  // continuous assignments for outputs
  assign quotient  = quo_reg;
  assign remainder = rem_reg[DATA_WIDTH-1:0];

endmodule