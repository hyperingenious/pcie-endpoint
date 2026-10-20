`ifndef PCIE_UVM_ITEMS_SV
`define PCIE_UVM_ITEMS_SV
class pcie_tlp_item extends uvm_sequence_item;
  rand logic [2:0]  fmt;
  rand logic [4:0]  typ;
  rand logic [2:0]  tc;
  rand logic [2:0]  attr;
  rand logic        td, ep, th, ln;
  rand logic [1:0]  at;
  rand logic [9:0]  length;
  rand logic [15:0] req_id;
  rand logic [7:0]  tag;
  rand logic [3:0]  first_be, last_be;
  rand logic [63:0] addr;
  rand logic [15:0] cpl_id;
  rand logic [2:0]  cpl_status;
  rand logic [11:0] byte_count;
  rand logic [6:0]  lower_addr;
  rand logic [31:0] payload[];
  logic [11:0] seq_num;
  bit          is_replay;
  bit          is_malformed;
  bit          lcrc_ok = 1;
  `uvm_object_utils(pcie_tlp_item)
  function new(string name = "pcie_tlp_item"); super.new(name); endfunction
  constraint c_legal {
    tc == 0; attr[2] == 0; td == 0; ep == 0; th == 0; ln == 0; at == 0;
    typ inside {5'b00000, 5'b00100, 5'b01010};
    length inside {[0:32]};
    payload.size() <= 32;
  }
  function void do_copy(uvm_object rhs);
    pcie_tlp_item t;
    super.do_copy(rhs);
    $cast(t, rhs);
    fmt=t.fmt; typ=t.typ; tc=t.tc; attr=t.attr; td=t.td; ep=t.ep; th=t.th; ln=t.ln; at=t.at;
    length=t.length; req_id=t.req_id; tag=t.tag; first_be=t.first_be; last_be=t.last_be;
    addr=t.addr; cpl_id=t.cpl_id; cpl_status=t.cpl_status; byte_count=t.byte_count;
    lower_addr=t.lower_addr; payload=t.payload; seq_num=t.seq_num; is_replay=t.is_replay;
    is_malformed=t.is_malformed; lcrc_ok=t.lcrc_ok;
  endfunction
endclass

class pcie_dllp_item extends uvm_sequence_item;
  rand logic [7:0]  dtype;
  rand logic [11:0] seq;
  rand logic [7:0]  hdr_fc;
  rand logic [11:0] data_fc;
  bit               crc_ok = 1;
  `uvm_object_utils(pcie_dllp_item)
  function new(string name = "pcie_dllp_item"); super.new(name); endfunction
endclass

class pcie_transaction_item extends uvm_sequence_item;
  typedef enum {OP_MWR, OP_MRD, OP_CFGRD, OP_CFGWR, OP_CPL, OP_CPLD} op_e;
  rand op_e         op;
  rand logic [63:0] addr;
  rand logic [31:0] data[];
  rand logic [3:0]  first_be, last_be;
  rand logic [7:0]  tag;
  rand logic [15:0] req_id;
  logic [2:0]       exp_status;
  logic [31:0]      exp_data[];
  `uvm_object_utils(pcie_transaction_item)
  function new(string name = "pcie_transaction_item"); super.new(name); endfunction
endclass
`endif
