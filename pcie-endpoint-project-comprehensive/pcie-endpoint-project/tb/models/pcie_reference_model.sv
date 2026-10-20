`ifndef PCIE_REF_MODEL_SV
`define PCIE_REF_MODEL_SV
class pcie_reference_model extends uvm_component;
  bit [7:0]  bar0 [4096];
  bit [7:0]  bar1 [4096];
  bit [31:0] cfg  [1024];
  bit [31:0] bar0_base, bar1_base;
  bit        mse;
  `uvm_component_utils(pcie_reference_model)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void reset();
    foreach (bar0[i]) bar0[i] = 0;
    foreach (bar1[i]) bar1[i] = 0;
    foreach (cfg[i])  cfg[i]  = 0;
    cfg[0] = {16'h0001, 16'h1234};
    cfg[1] = {16'h0010, 16'h0000};
    cfg[2] = {24'hFF0000, 8'h01};
    cfg[13] = 32'h0000_0040;
    mse = 0; bar0_base = 0; bar1_base = 0;
  endfunction
  function void write_mem(bit [63:0] addr, bit [31:0] data, bit [3:0] be);
    int unsigned off;
    if (mse && addr[31:12] == bar0_base[31:12]) begin
      off = addr[11:0];
      for (int b=0;b<4;b++) if (be[b]) bar0[off+b] = data[8*b+:8];
    end else if (mse && addr[31:12] == bar1_base[31:12]) begin
      off = addr[11:0];
      for (int b=0;b<4;b++) if (be[b]) bar1[off+b] = data[8*b+:8];
    end
  endfunction
  function bit [31:0] read_mem(bit [63:0] addr);
    int unsigned off = addr[11:0];
    bit [31:0] d;
    if (addr[31:12] == bar0_base[31:12])
      for (int b=0;b<4;b++) d[8*b+:8] = bar0[off+b];
    else
      for (int b=0;b<4;b++) d[8*b+:8] = bar1[off+b];
    return d;
  endfunction
  function void apply_cfg_wr(bit [9:0] idx, bit [31:0] data, bit [3:0] be);
    bit [31:0] m, old;
    m = {{8{be[3]}},{8{be[2]}},{8{be[1]}},{8{be[0]}}};
    old = cfg[idx];
    if (idx == 1) begin
      cfg[1][15:0] = (old[15:0] & ~16'h0146) | (data[15:0] & 16'h0146);
      mse = cfg[1][1];
    end else if (idx == 4)
      bar0_base = (old & ~32'hFFFF_F000 & ~m) | (data & 32'hFFFF_F000 & m);
    else if (idx == 5)
      bar1_base = (old & ~32'hFFFF_F000 & ~m) | (data & 32'hFFFF_F000 & m);
  endfunction
  function void predict(pcie_tlp_item req, output pcie_tlp_item exp);
    import pcie_pkg::*;
    exp = pcie_tlp_item::type_id::create("exp");
    if (req.typ == TYP_MEM && req.fmt[1]) begin
      foreach (req.payload[i])
        write_mem(req.addr+i*4, req.payload[i], req.payload.size()==1 ? req.first_be : 4'hF);
    end else if (req.typ == TYP_CFG0 && req.fmt[1]) begin
      apply_cfg_wr(req.addr[11:2], req.payload.size()?req.payload[0]:0, req.first_be);
      exp.fmt=FMT_3DW_ND; exp.typ=TYP_CPL; exp.cpl_status=CPL_SC; exp.req_id=req.req_id; exp.tag=req.tag;
    end else if (req.typ == TYP_CFG0) begin
      exp.fmt=FMT_3DW_D; exp.typ=TYP_CPL; exp.cpl_status=CPL_SC; exp.req_id=req.req_id; exp.tag=req.tag;
      exp.payload = new[1]; exp.payload[0] = cfg[req.addr[11:2]];
    end else if (req.typ == TYP_MEM && !req.fmt[1]) begin
      int unsigned n = (req.length==0)?1:req.length;
      exp.fmt=FMT_3DW_D; exp.typ=TYP_CPL; exp.cpl_status=CPL_SC; exp.req_id=req.req_id; exp.tag=req.tag;
      exp.payload = new[n];
      for (int i=0;i<n;i++) exp.payload[i] = read_mem(req.addr+i*4);
    end
  endfunction
endclass
`endif
