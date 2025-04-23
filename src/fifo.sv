`default_nettype none
`timescale 1ns/1ns

module fifo #(
    parameter DW = 32,
    parameter N = 4
) (
    input  logic clk,
    input  logic rst,
    input  logic write_en, //write enable
    input  logic read_en, //read enable
    input  logic [DW-1:0] data_in,
    output logic [DW-1:0] data_out,
    output logic full,
    output logic empty
);

logic [DW-1:0] fifo_mem [0:N-1];

localparam PTR_W = $clog2(N);
logic [PTR_W-1:0] write_ptr, read_ptr; // head is write, tail is read

always @(posedge clk or negedge rst) begin
    if (rst) begin 
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

assign full = (write_ptr == read_ptr + N-1);
assign empty = (write_ptr == read_ptr);

endmodule