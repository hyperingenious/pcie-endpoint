`ifndef PCIE_SCOREBOARD_SV
`define PCIE_SCOREBOARD_SV
class pcie_scoreboard extends uvm_component;
  uvm_analysis_imp_req #(pcie_tlp_item, pcie_scoreboard) req_imp;
  uvm_analysis_imp_cpl #(pcie_tlp_item, pcie_scoreboard) cpl_imp;
  pcie_reference_model refm;
  pcie_tlp_item        pending [256];
  int                  mismatches;
  bit                  expect_mismatch;
  string               test_name;
  int                  seed;
  `uvm_component_utils(pcie_scoreboard)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_imp = new("req_imp", this);
    cpl_imp = new("cpl_imp", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    refm = pcie_reference_model::type_id::create("refm", this);
    refm.reset();
    void'(uvm_config_db#(bit)::get(this, "", "expect_mismatch", expect_mismatch));
  endfunction
  function void write_req(pcie_tlp_item t);
    pcie_tlp_item exp;
    if (t.is_replay) return;
    refm.predict(t, exp);
    if (t.typ != 5'b00000 || !t.fmt[1]) pending[{t.req_id, t.tag}] = exp;
  endfunction
  function void write_cpl(pcie_tlp_item t);
    pcie_tlp_item exp;
    if (t.is_replay) return;
    if (!pending.exists({t.req_id, t.tag})) begin
      `uvm_error("SCB", $sformatf("UNEXPECTED cpl tag=%0h test=%s seed=%0d t=%0t", t.tag, test_name, seed, $time))
      mismatches++;
      return;
    end
    exp = pending[{t.req_id, t.tag}];
    if (exp.payload.size() && t.payload.size() && exp.payload[0] !== t.payload[0]) begin
      `uvm_error("SCB", $sformatf("MISMATCH tag=%0h exp=%h act=%h test=%s seed=%0d t=%0t",
                 t.tag, exp.payload[0], t.payload[0], test_name, seed, $time))
      mismatches++;
    end
    pending.delete({t.req_id, t.tag});
  endfunction
  function void check_phase(uvm_phase phase);
    if (expect_mismatch) begin
      if (mismatches == 0) `uvm_error("SCB_NEG", "Expected mismatch was not detected")
    end else if (pending.size() != 0)
      `uvm_error("SCB", $sformatf("%0d outstanding at EOT", pending.size()))
  endfunction
endclass
`endif
