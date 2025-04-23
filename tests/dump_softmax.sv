  module dump();
  initial begin
    $dumpfile("waveforms/softmax.vcd");
    $dumpvars(0, softmax); 
  end
  endmodule