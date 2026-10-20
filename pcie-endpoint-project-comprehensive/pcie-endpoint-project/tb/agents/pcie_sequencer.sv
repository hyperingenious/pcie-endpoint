`ifndef PCIE_SEQUENCER_SV
`define PCIE_SEQUENCER_SV
class pcie_sequencer extends uvm_sequencer #(pcie_tlp_item);
  `uvm_component_utils(pcie_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
`endif
