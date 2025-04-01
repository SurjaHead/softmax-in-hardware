  module dump();
  initial begin
    $dumpfile("waveforms/divider.vcd");
    $dumpvars(0, divider); 
  end
  endmodule