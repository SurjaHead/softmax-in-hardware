  module dump();
  initial begin
    $dumpfile("param_sys_array.vcd");
    $dumpvars(0, parameterized_systolic_array); 
  end
  endmodule