`default_nettype none
`timescale 1ns/1ns

module fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic write_en, //write enable
    input  logic read_en, //read enable
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic full,
    output logic empty
);

logic [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];

localparam PTR_W = $clog2(DEPTH);
logic [PTR_W-1:0] write_ptr, read_ptr; // head is write, tail is read

always @(posedge clk or negedge rst_n) begin
    if (rst_n) begin 
        write_ptr <= 0;
        read_ptr <= 0;
    end
    else begin
        if (write_en && !full) begin
            fifo_mem [write_ptr] <= data_in;
            write_ptr <= write_ptr + 1;
        end

        if (read_en && !empty) begin
            data_out <= fifo_mem [read_ptr];
            read_ptr <= read_ptr + 1;
        end
    end
end

assign full = (write_ptr == read_ptr + DEPTH-1);
assign empty = (write_ptr == read_ptr);

endmodule