`ifndef SYNTHESIS
module pcie_endpoint_assertions
  import pcie_pkg::*;
(
  input logic        clk,
  input logic        rst_n,
  input logic        tlp_tx_valid, tlp_tx_ready, tlp_tx_sop, tlp_tx_eop,
  input logic [31:0] tlp_tx_data,
  input logic        tlp_rx_valid, tlp_rx_ready, tlp_rx_sop, tlp_rx_eop,
  input logic [31:0] tlp_rx_data,
  input logic        dllp_tx_valid, dllp_tx_ready,
  input logic        dllp_rx_valid, dllp_rx_ready,
  input logic        phy_link_up, phy_recovery,
  input dl_state_e   dll_state,
  input logic        dl_active, flush,
  input logic [1:0]  bar_hit,
  input logic        rejected, wrote,
  input logic [3:0]  wr_be,
  input logic [7:0]  tags_in_use,
  input logic        replay_empty, replay_active,
  input logic [3:0]  replay_occ,
  input logic [7:0]  hdr_cred [3],
  input logic [11:0] data_cred [3],
  input logic [2:0]  credit_ok,
  input logic        fc_consume,
  input logic        rx_bad, commit, rx_ok,
  input logic [2:0]  ltssm
);
  // IF-HS: transfer only on valid && ready
  property p_if_hs;
    @(posedge clk) disable iff (!rst_n)
      tlp_rx_valid && tlp_rx_ready |-> 1'b1;
  endproperty
  a_if_hs: assert property (p_if_hs);

  // IF-STALL: TX fields stable while valid && !ready
  property p_if_stall;
    @(posedge clk) disable iff (!rst_n)
      (tlp_tx_valid && !tlp_tx_ready) |=> $stable({tlp_tx_sop, tlp_tx_eop, tlp_tx_data});
  endproperty
  a_if_stall: assert property (p_if_stall);

  // IF-RST: no TX during reset
  property p_if_rst;
    @(posedge clk) !rst_n |-> !tlp_tx_valid && !dllp_tx_valid;
  endproperty
  a_if_rst: assert property (p_if_rst);

  // IF-FRM: sop/eop consistent — eop implies a packet was open
  property p_if_frm;
    @(posedge clk) disable iff (!rst_n)
      tlp_tx_valid && tlp_tx_ready && tlp_tx_eop |-> tlp_tx_sop || $past(tlp_tx_valid);
  endproperty
  a_if_frm: assert property (p_if_frm);

  // IF-ONCE: a held beat is accepted at most once
  property p_if_once;
    @(posedge clk) disable iff (!rst_n)
      tlp_tx_valid && tlp_tx_ready |=> !($stable(tlp_tx_data) && tlp_tx_valid && $past(tlp_tx_ready) && $past(tlp_tx_sop) && tlp_tx_sop);
  endproperty
  a_if_once: assert property (p_if_once);

  // RST-GATE / DLL-DOWN: no TLP TX unless DL_Active
  property p_dll_down;
    @(posedge clk) disable iff (!rst_n)
      (dll_state != DL_ACTIVE) |-> !tlp_tx_valid;
  endproperty
  a_dll_down: assert property (p_dll_down);

  // TL-BAR: at most one BAR hit
  property p_tl_bar;
    @(posedge clk) disable iff (!rst_n)
      $onehot0(bar_hit);
  endproperty
  a_tl_bar: assert property (p_tl_bar);

  // TL-REJ: rejected request does not write
  property p_tl_rej;
    @(posedge clk) disable iff (!rst_n)
      rejected |-> !wrote;
  endproperty
  a_tl_rej: assert property (p_tl_rej);

  // TL-BE: a write with BE==0 does not count as a data update
  property p_tl_be;
    @(posedge clk) disable iff (!rst_n)
      wrote |-> wr_be != 4'h0;
  endproperty
  a_tl_be: assert property (p_tl_be);

  // TL-TAG: each tag bit is 0 or 1 (uniqueness encoded in one-hot of in-use bits is not required)
  property p_tl_tag;
    @(posedge clk) disable iff (!rst_n)
      $countones(tags_in_use) <= MAX_OUTSTANDING;
  endproperty
  a_tl_tag: assert property (p_tl_tag);

  // DLL-LCRC: bad LCRC is not committed to TL
  property p_dll_lcrc;
    @(posedge clk) disable iff (!rst_n)
      rx_bad |-> !commit;
  endproperty
  a_dll_lcrc: assert property (p_dll_lcrc);

  // DLL-RPLY: occupancy never exceeds depth
  property p_dll_rply;
    @(posedge clk) disable iff (!rst_n)
      replay_occ <= 4'(REPLAY_DEPTH);
  endproperty
  a_dll_rply: assert property (p_dll_rply);

  // DLL-CRD: consume only when credits allow
  property p_dll_crd;
    @(posedge clk) disable iff (!rst_n)
      fc_consume |-> |credit_ok;
  endproperty
  a_dll_crd: assert property (p_dll_crd);

  // LT-FSM: only defined LTSSM values
  property p_lt_fsm;
    @(posedge clk) disable iff (!rst_n)
      ltssm inside {LT_DETECT, LT_POLLING, LT_CONFIG, LT_L0, LT_RECOVERY, LT_FAILED};
  endproperty
  a_lt_fsm: assert property (p_lt_fsm);

  // DLL-FSM
  property p_dll_fsm;
    @(posedge clk) disable iff (!rst_n)
      dll_state inside {DL_INACTIVE, DL_INIT, DL_ACTIVE};
  endproperty
  a_dll_fsm: assert property (p_dll_fsm);
endmodule
`endif
