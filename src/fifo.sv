`default_nettype none
`timescale 1ns/1ns

module fifo #(
    parameter DW = 32,
    parameter N = 32,
    parameter INIT_VALUE = 16'b0000000000000101
) (
    input  logic clk,
    input  logic rst,
    input  logic wr_en, //write enable
    input  logic rd_en, //read enable
    input  logic [DW-1:0] data_in,
    output logic [DW-1:0] data_out,
    output logic full,
    output logic empty
);

logic [DW-1:0] fifo_mem [N];
logic [$clog2(N)-1:0] write_ptr;
logic [$clog2(N)-1:0] read_ptr;
logic [$clog2(N):0] counter;  // Note: Increased size to handle N elements (0 to N)

// Initialize the first location
initial begin
    fifo_mem[0] = INIT_VALUE;
end

always_ff @(posedge clk) begin
    if (rst) begin
        write_ptr <= 0;
        read_ptr  <= 0;
        counter   <= 1;  // Initialize counter to 1 since we have one value
    end else begin
        // Write operation
        if (wr_en && !full) begin
            if (write_ptr != 0) begin  // Don't overwrite the initial value
                fifo_mem[write_ptr] <= data_in;
            end
            write_ptr <= write_ptr + 1;
        end
        // Read operation
        if (rd_en && !empty) begin
            data_out <= fifo_mem[read_ptr];
            read_ptr <= read_ptr + 1;
        end
        // Update counter
        if (wr_en && !full && rd_en && !empty) begin
            counter <= counter;  // No change if both write and read
        end else if (wr_en && !full) begin
            counter <= counter + 1;  // Write only
        end else if (rd_en && !empty) begin
            counter <= counter - 1;  // Read only
        end
    end
end

assign empty = (counter == 0);
assign full  = (counter == N);

endmodule
