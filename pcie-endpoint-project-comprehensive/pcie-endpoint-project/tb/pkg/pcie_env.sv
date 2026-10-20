`ifndef PCIE_ENV_SV
`define PCIE_ENV_SV
class pcie_env extends uvm_env;
  pcie_agent           rc_agent;
  pcie_agent           ep_agent;
  pcie_rc_model        rc_model;
  pcie_scoreboard      scb;
  pcie_coverage        cov;
  `uvm_component_utils(pcie_env)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rc_agent = pcie_agent::type_id::create("rc_agent", this);
    ep_agent = pcie_agent::type_id::create("ep_agent", this);
    ep_agent.is_active = 0;
    rc_model = pcie_rc_model::type_id::create("rc_model", this);
    scb = pcie_scoreboard::type_id::create("scb", this);
    cov = pcie_coverage::type_id::create("cov", this);
    uvm_config_db#(bit)::set(this, "ep_agent.mon", "watch_tx", 1'b1);
    uvm_config_db#(bit)::set(this, "rc_agent.mon", "watch_tx", 1'b0);
  endfunction
  function void connect_phase(uvm_phase phase);
    rc_agent.mon.tlp_ap.connect(scb.req_imp);
    ep_agent.mon.tlp_ap.connect(scb.cpl_imp);
    ep_agent.mon.tlp_ap.connect(rc_model.imp);
    rc_agent.mon.tlp_ap.connect(cov.analysis_export);
    ep_agent.mon.tlp_ap.connect(cov.analysis_export);
  endfunction
endclass
`endif
