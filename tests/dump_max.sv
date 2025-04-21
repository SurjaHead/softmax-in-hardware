  module dump();
  initial begin
    $dumpfile("waveforms/max.vcd");
    $dumpvars(0, max); 
  end
  endmodule