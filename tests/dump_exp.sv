  module dump();
  initial begin
    $dumpfile("waveforms/exp.vcd");
    $dumpvars(0, exp); 
  end
  endmodule