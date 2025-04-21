  module dump();
  initial begin
    $dumpfile("waveforms/subtract.vcd");
    $dumpvars(0, subtract); 
  end
  endmodule