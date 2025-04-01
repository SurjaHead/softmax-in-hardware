  module dump();
  initial begin
    $dumpfile("waveforms/pe.vcd");
    $dumpvars(0, weight_stationary_pe); 
  end
  endmodule