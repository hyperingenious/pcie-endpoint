`ifndef PCIE_BASE_SEQUENCE_SV
`define PCIE_BASE_SEQUENCE_SV
class pcie_legal_seq extends uvm_sequence #(pcie_tlp_item);
  `uvm_object_utils(pcie_legal_seq)
  function new(string name = "pcie_legal_seq"); super.new(name); endfunction
  task body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    start_item(t);
    void'(t.randomize() with { typ == 5'b00100; fmt == 3'b000; length == 1; first_be == 4'hF; });
    finish_item(t);
  endtask
endclass
`endif
