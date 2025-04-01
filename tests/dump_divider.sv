  module dump();
  initial begin
    $dumpfile("divider.vcd");
    $dumpvars(0, divider); 
  end
  endmodule