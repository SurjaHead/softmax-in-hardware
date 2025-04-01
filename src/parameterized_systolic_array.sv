module parameterized_systolic_array #(
    parameter DATA_WIDTH = 16,
    parameter N = 4
)(
    input  wire                      clk,
    input  wire                      reset,
    input  wire                      load_weights,
    input  wire                      start,

    input  wire [N*DATA_WIDTH-1:0]  x_in,
    input  wire [N*N*DATA_WIDTH-1:0] w_in,
    // y_out: N outputs in a single bus (one for each row)
    output wire [N*DATA_WIDTH-1:0]  y_out,
    output reg                      done
);

    wire [DATA_WIDTH-1:0] input_in [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] input_out[0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] psum_in  [0:N-1][0:N-1];
    wire [DATA_WIDTH-1:0] psum_out [0:N-1][0:N-1];

    wire [DATA_WIDTH-1:0] zero_wire = {DATA_WIDTH{1'b0}};

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin: row_gen
            for (j = 0; j < N; j = j + 1) begin: col_gen
                assign input_in[i][j] = (j == 0)
                    ? x_in[i*DATA_WIDTH +: DATA_WIDTH]
                    : input_out[i][j-1];

                assign psum_in[i][j] = (i == 0)
                    ? zero_wire
                    : psum_out[i-1][j]; // gets the psum from previous row, same column

                wire [DATA_WIDTH-1:0] w_ij;
                assign w_ij = w_in[(i*N + j)*DATA_WIDTH +: DATA_WIDTH];

                weight_stationary_pe #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) pe_inst (
                    .clk       (clk),
                    .reset     (reset),
                    .load_weight(load_weights),
                    .valid     (start),
                    .input_in  (input_in[i][j]),
                    .weight    (w_ij),
                    .psum_in   (psum_in[i][j]),
                    .input_out (input_out[i][j]),
                    .psum_out  (psum_out[i][j])
                );
            end
        end
    endgenerate
    
    // for row i, the final output y_out[i] is taken from the last column’s psum_out[i][N-1]
    
    reg [DATA_WIDTH-1:0] y_reg [0:N-1];
    integer k;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < N; k = k + 1) begin
                y_reg[k] <= 0;
            end
            done <= 1'b0;
        end else begin
            if (start) begin
                for (k = 0; k < N; k = k + 1) begin
                    y_reg[k] <= psum_out[N-1][k]; // gets the psum from the last row, which different column each iteration
                end
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // pack y_reg into y_out bus
    generate
        for (i = 0; i < N; i = i + 1) begin: pack_outputs
            assign y_out[i*DATA_WIDTH +: DATA_WIDTH] = y_reg[i];
        end
    endgenerate

endmodule
