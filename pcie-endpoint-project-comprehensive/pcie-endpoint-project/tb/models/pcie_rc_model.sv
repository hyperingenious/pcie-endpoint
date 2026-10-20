`ifndef PCIE_RC_MODEL_SV
`define PCIE_RC_MODEL_SV
class pcie_rc_model extends uvm_component;
  bit [7:0] host [bit [63:0]];
  int unsigned cpl_delay;
  bit withhold;
  bit reorder;
  bit split;
  uvm_analysis_imp #(pcie_tlp_item, pcie_rc_model) imp;
  uvm_analysis_port #(pcie_tlp_item) cpl_ap;
  `uvm_component_utils(pcie_rc_model)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
    cpl_ap = new("cpl_ap", this);
  endfunction
  function void write_host(bit [63:0] addr, bit [31:0] data, bit [3:0] be);
    for (int b = 0; b < 4; b++)
      if (be[b]) host[addr+b] = data[8*b +: 8];
  endfunction
  function bit [31:0] read_host(bit [63:0] addr);
    bit [31:0] d;
    for (int b = 0; b < 4; b++) d[8*b +: 8] = host.exists(addr+b) ? host[addr+b] : 8'h00;
    return d;
  endfunction
  function void write(pcie_tlp_item t);
    import pcie_pkg::*;
    if (t.typ == TYP_MEM && t.fmt[1]) begin
      foreach (t.payload[i])
        write_host(t.addr + i*4, t.payload[i], (t.payload.size()==1) ? t.first_be : 4'hF);
    end else if (t.typ == TYP_MEM && !t.fmt[1] && !withhold) begin
      pcie_tlp_item c = pcie_tlp_item::type_id::create("cpl");
      int unsigned n = (t.length == 0) ? 1 : t.length;
      c.fmt = FMT_3DW_D; c.typ = TYP_CPL; c.req_id = t.req_id; c.tag = t.tag;
      c.cpl_id = 16'h0000; c.cpl_status = CPL_SC;
      c.byte_count = 12'(n*4); c.lower_addr = t.addr[6:0]; c.length = t.length;
      c.payload = new[n];
      for (int i = 0; i < n; i++) c.payload[i] = read_host(t.addr + i*4);
      cpl_ap.write(c);
    end
  endfunction
endclass
`endif
