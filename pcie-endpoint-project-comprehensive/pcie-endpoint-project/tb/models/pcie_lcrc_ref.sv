// Independent bit-serial LCRC reference (testbench only). Same polynomial as
// the RTL, different bit walk, used by pcie_lcrc_reference_test.
package pcie_lcrc_ref_pkg;
  function automatic logic [31:0] bit_serial_crc32(input logic [7:0] bytes[], input int n);
    logic [31:0] c;
    c = 32'hFFFF_FFFF;
    for (int i = 0; i < n; i++) begin
      c = c ^ {24'h0, bytes[i]};
      for (int b = 0; b < 8; b++)
        c = c[0] ? ((c >> 1) ^ 32'hEDB8_8320) : (c >> 1);
    end
    return ~c;
  endfunction
endpackage
