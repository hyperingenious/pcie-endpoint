`timescale 1ns/1ps
module smoke_tb;
  initial begin
    $display("Simulator smoke test: basic SystemVerilog simulation is running.");
    $display("This test does not verify PCIe RTL or UVM functionality.");
    $display("SMOKE_TEST_PASS");
    $finish;
  end
endmodule
