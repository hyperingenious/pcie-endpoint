`ifndef PCIE_DRIVER_SV
`define PCIE_DRIVER_SV
class pcie_driver extends uvm_driver #(pcie_tlp_item);
  virtual pcie_pkt_if.mon vif; // used as port via config
  virtual pcie_pkt_if     drv_if;
  virtual pcie_link_ctrl_if ctrl;
  logic [11:0] tx_seq;
  logic [11:0] rx_exp;
  bit          fc_done;
  `uvm_component_utils(pcie_driver)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual pcie_pkt_if)::get(this, "", "vif", drv_if))
      `uvm_fatal("NOVIF", "vif")
    void'(uvm_config_db#(virtual pcie_link_ctrl_if)::get(this, "", "ctrl", ctrl));
  endfunction

  task automatic send_dllp(logic [47:0] d);
    @(posedge drv_if.clk);
    drv_if.dllp_tx_valid <= 1'b1;
    drv_if.dllp_tx_data  <= d;
    do @(posedge drv_if.clk); while (!drv_if.dllp_tx_ready);
    drv_if.dllp_tx_valid <= 1'b0;
  endtask

  task automatic send_beat(logic sop, logic eop, logic [31:0] data);
    @(posedge drv_if.clk);
    drv_if.tlp_tx_valid <= 1'b1;
    drv_if.tlp_tx_sop   <= sop;
    drv_if.tlp_tx_eop   <= eop;
    drv_if.tlp_tx_data  <= data;
    do @(posedge drv_if.clk); while (!drv_if.tlp_tx_ready);
    drv_if.tlp_tx_valid <= 1'b0;
    drv_if.tlp_tx_sop   <= 1'b0;
    drv_if.tlp_tx_eop   <= 1'b0;
  endtask

  task automatic drive_tlp(pcie_tlp_item t);
    import pcie_pkg::*;
    import pcie_crc_pkg::*;
    import pcie_tlp_codec_pkg::*;
    logic [31:0] crc;
    int unsigned ndw, i;
    logic [31:0] dws[$];
    logic [2:0]  hdw;
    hdw = t.fmt[0] ? 3'd4 : 3'd3;
    dws.push_back(enc_dw0(t.fmt, t.typ, t.tc, t.attr, t.td, t.ep, t.length));
    if (t.typ == TYP_CPL) begin
      dws.push_back(enc_cpl_dw1(t.cpl_id, t.cpl_status, t.byte_count));
      dws.push_back(enc_cpl_dw2(t.req_id, t.tag, t.lower_addr));
    end else begin
      dws.push_back(enc_req_dw1(t.req_id, t.tag, t.last_be, t.first_be));
      if (t.fmt[0]) begin
        dws.push_back(t.addr[63:32]);
        dws.push_back({t.addr[31:2], 2'b00});
      end else
        dws.push_back({t.addr[31:2], 2'b00});
    end
    foreach (t.payload[i]) dws.push_back(bswap32(t.payload[i]));
    crc = lcrc_seq(tx_seq);
    send_beat(1'b1, 1'b0, {16'h0, 4'h0, tx_seq});
    foreach (dws[i]) begin
      crc = lcrc_dw(crc, dws[i]);
      send_beat(1'b0, 1'b0, dws[i]);
    end
    send_beat(1'b0, 1'b1, t.lcrc_ok ? lcrc_final(crc) : ~lcrc_final(crc));
    tx_seq = (tx_seq == 12'd4095) ? 12'd0 : (tx_seq + 12'd1);
  endtask

  task automatic fc_bringup();
    import pcie_pkg::*;
    import pcie_dllp_pkg::*;
    int seen1, seen2;
    seen1 = 0; seen2 = 0;
    forever begin
      send_dllp(dllp_fc(DLLP_INITFC1_P,   ADV_PH,  ADV_PD));
      send_dllp(dllp_fc(DLLP_INITFC1_NP,  ADV_NPH, ADV_NPD));
      send_dllp(dllp_fc(DLLP_INITFC1_CPL, 8'd8,    12'd32));
      if (seen1 == 3) begin
        send_dllp(dllp_fc(DLLP_INITFC2_P,   ADV_PH,  ADV_PD));
        send_dllp(dllp_fc(DLLP_INITFC2_NP,  ADV_NPH, ADV_NPD));
        send_dllp(dllp_fc(DLLP_INITFC2_CPL, 8'd8,    12'd32));
      end
      if (seen1 == 3 && seen2 == 3) break;
      repeat (4) @(posedge drv_if.clk);
      if (drv_if.dllp_rx_valid) begin
        logic [7:0] ty;
        ty = drv_if.dllp_rx_data[47:40];
        if (ty[7:6] == 2'b01) seen1 = 3;
        if (ty[7:6] == 2'b11) seen2 = 3;
      end
    end
    fc_done = 1;
  endtask

  task run_phase(uvm_phase phase);
    import pcie_dllp_pkg::*;
    tx_seq = 0; rx_exp = 0; fc_done = 0;
    drv_if.tlp_tx_valid <= 0;
    drv_if.dllp_tx_valid <= 0;
    drv_if.tlp_rx_ready <= 1;
    drv_if.dllp_rx_ready <= 1;
    if (ctrl != null) begin
      ctrl.partner_present <= 1;
      ctrl.force_link_down <= 0;
      ctrl.latency <= 0;
    end
    wait (drv_if.rst_n);
    wait (drv_if.phy_link_up);
    fork
      fc_bringup();
      forever begin
        @(posedge drv_if.clk);
        if (drv_if.tlp_rx_valid && drv_if.tlp_rx_ready && drv_if.tlp_rx_eop)
          send_dllp(dllp_acknak(1'b0, rx_exp));
      end
    join_none
    wait (fc_done);
    forever begin
      seq_item_port.get_next_item(req);
      drive_tlp(req);
      seq_item_port.item_done();
    end
  endtask
endclass
`endif
