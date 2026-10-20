// Address decode for the two implemented 32-bit, non-prefetchable, 4 KiB memory BARs.
// A request hits at most one BAR. Addresses above 4 GiB never hit (32-bit BARs).
module pcie_bar_decoder
  import pcie_pkg::*;
(
  input  logic [63:0] addr,
  input  logic        mem_space_en,
  input  logic [31:0] bar0,
  input  logic [31:0] bar1,
  output logic [1:0]  bar_hit,      // one-hot: [0] BAR0, [1] BAR1
  output logic        hit_any,
  output logic [9:0]  dw_offset     // DW index inside the 4 KiB region
);
  logic low;
  assign low       = (addr[63:32] == 32'h0);
  assign bar_hit[0] = mem_space_en && low && (addr[31:12] == bar0[31:12]);
  assign bar_hit[1] = mem_space_en && low && !bar_hit[0] && (addr[31:12] == bar1[31:12]);
  assign hit_any   = |bar_hit;
  assign dw_offset = addr[11:2];
endmodule
