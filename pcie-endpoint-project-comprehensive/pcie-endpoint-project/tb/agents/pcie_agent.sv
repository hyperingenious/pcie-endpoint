`ifndef PCIE_AGENT_SV
`define PCIE_AGENT_SV
class pcie_agent extends uvm_agent;
  pcie_driver    drv;
  pcie_monitor   mon;
  pcie_sequencer seqr;
  bit is_active = 1;
  `uvm_component_utils(pcie_agent)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = pcie_monitor::type_id::create("mon", this);
    if (is_active) begin
      drv  = pcie_driver::type_id::create("drv", this);
      seqr = pcie_sequencer::type_id::create("seqr", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (is_active) drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass
`endif
