`ifndef PCIE_BASE_TEST_SV
`define PCIE_BASE_TEST_SV
class pcie_item_seq extends uvm_sequence #(pcie_tlp_item);
  pcie_tlp_item item;
  `uvm_object_utils(pcie_item_seq)
  function new(string name="pcie_item_seq"); super.new(name); endfunction
  task body();
    start_item(item);
    finish_item(item);
  endtask
endclass

class pcie_base_test extends uvm_test;
  pcie_env env;
  virtual pcie_pkt_if vif;
  virtual pcie_link_ctrl_if ctrl;
  int unsigned timeout_ns = 200_000;
  int unsigned seed;
  `uvm_component_utils(pcie_base_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = pcie_env::type_id::create("env", this);
    if (!uvm_config_db#(virtual pcie_pkt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vif")
    void'(uvm_config_db#(virtual pcie_link_ctrl_if)::get(this, "", "ctrl", ctrl));
    if (!$value$plusargs("ntb_random_seed=%d", seed)) seed = $urandom();
    env.scb.seed = seed;
    env.scb.test_name = get_type_name();
  endfunction

  task send_item(pcie_tlp_item t);
    pcie_item_seq s = pcie_item_seq::type_id::create("s");
    s.item = t;
    s.start(env.rc_agent.seqr);
  endtask

  task automatic mk_cfg(input bit wr, input logic [11:0] off, input logic [31:0] data, input logic [3:0] be);
    import pcie_pkg::*;
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = wr ? FMT_3DW_D : FMT_3DW_ND;
    t.typ = TYP_CFG0; t.tc = 0; t.attr = 0; t.length = 1;
    t.req_id = 16'h0000; t.tag = 8'h01; t.first_be = be; t.last_be = 0;
    t.addr = {52'h0, off}; if (wr) begin t.payload = new[1]; t.payload[0] = data; end
    send_item(t);
  endtask

  task automatic mk_mem(input bit wr, input logic [31:0] addr, input logic [31:0] data[], input logic [3:0] fbe, input logic [3:0] lbe);
    import pcie_pkg::*;
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = wr ? FMT_3DW_D : FMT_3DW_ND;
    t.typ = TYP_MEM; t.tc = 0; t.attr = 0;
    t.length = data.size(); t.req_id = 16'h0000; t.tag = 8'h02;
    t.first_be = fbe; t.last_be = (data.size()>1)?lbe:4'h0;
    t.addr = addr; t.payload = data;
    send_item(t);
  endtask

  virtual task run_test_body();
    `uvm_info(get_type_name(), "base body", UVM_LOW)
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        wait (vif.phy_link_up);
        #1000;
        run_test_body();
        #2000;
      end
      begin
        #(timeout_ns * 1ns);
        `uvm_error("TIMEOUT", get_type_name())
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
`endif
