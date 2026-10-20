`ifndef PCIE_COVERAGE_SV
`define PCIE_COVERAGE_SV
class pcie_coverage extends uvm_subscriber #(pcie_tlp_item);
  pcie_tlp_item item;
  covergroup cg_pkt;
    cp_fmt: coverpoint item.fmt { bins dw3 = {3'b000, 3'b010}; bins dw4 = {3'b001, 3'b011};
      ignore_bins prefix = {3'b100}; // TLP prefixes not supported
    }
    cp_typ: coverpoint item.typ { bins mem={5'b00000}; bins cfg0={5'b00100}; bins cpl={5'b01010};
      ignore_bins io = {5'b00010}; // I/O not supported
    }
    cp_len: coverpoint item.length { bins z={0}; bins one={1}; bins max={32}; bins mid={[2:31]}; }
    cp_be:  coverpoint item.first_be { bins full={4'hF}; bins zero={4'h0}; bins sparse={[1:14]}; }
    x_fmt_typ: cross cp_fmt, cp_typ;
  endgroup
  covergroup cg_err;
    cp_mal: coverpoint item.is_malformed { bins yes={1}; bins no={0}; }
    cp_lcrc: coverpoint item.lcrc_ok { bins ok={1}; bins bad={0}; }
  endgroup
  covergroup cg_cpl;
    cp_st: coverpoint item.cpl_status { bins sc={0}; bins ur={1}; bins ca={4};
      ignore_bins crs={2}; // CRS not generated
    }
    cp_bc: coverpoint item.byte_count { bins one={1}; bins four={4}; bins other=default; }
  endgroup
  `uvm_component_utils(pcie_coverage)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_pkt = new(); cg_err = new(); cg_cpl = new();
  endfunction
  function void write(pcie_tlp_item t);
    item = t;
    cg_pkt.sample();
    cg_err.sample();
    if (t.typ == 5'b01010) cg_cpl.sample();
  endfunction
endclass
`endif
