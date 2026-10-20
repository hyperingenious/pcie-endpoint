`ifndef PCIE_MONITOR_SV
`define PCIE_MONITOR_SV
class pcie_monitor extends uvm_monitor;
  virtual pcie_pkt_if vif;
  uvm_analysis_port #(pcie_tlp_item)  tlp_ap;
  uvm_analysis_port #(pcie_dllp_item) dllp_ap;
  bit watch_tx; // 1 = DUT TX (EP->RC), 0 = RC TX (RC->EP)
  `uvm_component_utils(pcie_monitor)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    tlp_ap  = new("tlp_ap", this);
    dllp_ap = new("dllp_ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual pcie_pkt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vif")
    void'(uvm_config_db#(bit)::get(this, "", "watch_tx", watch_tx));
  endfunction

  task collect_tlp();
    import pcie_pkg::*;
    import pcie_crc_pkg::*;
    import pcie_tlp_codec_pkg::*;
    logic v, r, s, e;
    logic [31:0] d;
    forever begin
      pcie_tlp_item it;
      logic [31:0] beats[$];
      logic [11:0] seqn;
      logic [31:0] crc;
      @(posedge vif.clk);
      v = watch_tx ? vif.tlp_tx_valid : vif.tlp_rx_valid;
      r = watch_tx ? vif.tlp_tx_ready : vif.tlp_rx_ready;
      s = watch_tx ? vif.tlp_tx_sop   : vif.tlp_rx_sop;
      if (!(v && r && s)) continue;
      seqn = watch_tx ? vif.tlp_tx_data[11:0] : vif.tlp_rx_data[11:0];
      crc  = lcrc_seq(seqn);
      forever begin
        @(posedge vif.clk);
        v = watch_tx ? vif.tlp_tx_valid : vif.tlp_rx_valid;
        r = watch_tx ? vif.tlp_tx_ready : vif.tlp_rx_ready;
        e = watch_tx ? vif.tlp_tx_eop   : vif.tlp_rx_eop;
        d = watch_tx ? vif.tlp_tx_data  : vif.tlp_rx_data;
        if (!(v && r)) continue;
        if (e) begin
          it = pcie_tlp_item::type_id::create("it");
          it.seq_num = seqn;
          it.lcrc_ok = (d == lcrc_final(crc));
          if (beats.size() >= 3) begin
            tlp_hdr_t h;
            h = decode_hdr(beats[0], beats[1], beats[2], beats.size()>3 ? beats[3] : 32'h0);
            it.fmt=h.fmt; it.typ=h.typ; it.tc=h.tc; it.attr=h.attr; it.length=h.length;
            it.req_id=h.req_id; it.tag=h.tag; it.first_be=h.first_be; it.last_be=h.last_be;
            it.addr=h.addr; it.cpl_id=h.cpl_id; it.cpl_status=h.cpl_status;
            it.byte_count=h.byte_count; it.lower_addr=h.lower_addr;
            int unsigned hdw = h.fmt[0] ? 4 : 3;
            it.payload = new[beats.size() > hdw ? beats.size()-hdw : 0];
            for (int i = 0; i < it.payload.size(); i++)
              it.payload[i] = bswap32(beats[hdw+i]);
          end
          tlp_ap.write(it);
          break;
        end else begin
          beats.push_back(d);
          crc = lcrc_dw(crc, d);
        end
      end
    end
  endtask

  task collect_dllp();
    forever begin
      @(posedge vif.clk);
      if (vif.dllp_rx_valid && vif.dllp_rx_ready) begin
        pcie_dllp_item d = pcie_dllp_item::type_id::create("d");
        d.dtype = vif.dllp_rx_data[47:40];
        d.seq   = {vif.dllp_rx_data[27:24], vif.dllp_rx_data[23:16]};
        dllp_ap.write(d);
      end
    end
  endtask

  task run_phase(uvm_phase phase);
    fork collect_tlp(); collect_dllp(); join
  endtask
endclass
`endif
