  module dump();
  initial begin
    $dumpfile("waveforms/fifo.vcd");
    $dumpvars(0, fifo); 
  end
  endmodule