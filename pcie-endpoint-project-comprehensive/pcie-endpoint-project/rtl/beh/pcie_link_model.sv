// Packet-level link between Root Complex and Endpoint. Preserves order on the
// normal path. Fault injection (drop/corrupt/duplicate/delay) is logged with the seed.
module pcie_link_model
  import pcie_pkg::*;
(
  input  logic                clk,
  input  logic                rst_n,
  pcie_pkt_if.link            ep,
  pcie_pkt_if.link            rc,
  pcie_link_ctrl_if.model     ctrl
);
  ltssm_state_e ltssm;
  logic         link_up, recovery;

  pcie_ltssm_model u_ltssm (
    .clk, .rst_n,
    .partner_present(ctrl.partner_present),
    .force_link_down(ctrl.force_link_down),
    .force_recovery(ctrl.force_recovery),
    .recovery_fail(ctrl.recovery_fail),
    .state(ltssm), .link_up, .recovery
  );

  assign ep.phy_link_up     = link_up;
  assign ep.phy_recovery    = recovery;
  assign ep.ltssm_state_dbg = ltssm;
  assign rc.phy_link_up     = link_up;
  assign rc.phy_recovery    = recovery;
  assign rc.ltssm_state_dbg = ltssm;
  assign ctrl.ltssm_state   = ltssm;

  // Four channels: TLP RC->EP, TLP EP->RC, DLLP RC->EP, DLLP EP->RC
  // Each is a small skid FIFO of packet beats plus optional extra delay.

  localparam int Q = 64;
  typedef struct packed {
    logic        sop;
    logic        eop;
    logic        is_dllp;
    logic [47:0] data;
  } beat_t;

  function automatic void log_fault(input string dir, input string kind);
    $display("[LINK_FAULT] seed=%0d time=%0t dir=%s kind=%s", ctrl.fault_seed, $time, dir, kind);
  endfunction

  logic [15:0] drop_nl0;
  assign ctrl.dropped_not_l0 = drop_nl0;

  logic        f_pend;
  logic [1:0]  f_dir;
  logic [2:0]  f_kind;
  logic [7:0]  f_skip;
  logic [7:0]  f_delay;
  logic [15:0] f_cnt;
  assign ctrl.fault_pending = f_pend;
  assign ctrl.fault_count   = f_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      f_pend <= 1'b0; f_dir <= '0; f_kind <= '0; f_skip <= '0; f_delay <= '0; f_cnt <= '0;
    end else if (ctrl.fault_arm) begin
      f_pend  <= 1'b1;
      f_dir   <= ctrl.fault_dir;
      f_kind  <= ctrl.fault_kind;
      f_skip  <= ctrl.fault_skip;
      f_delay <= ctrl.fault_delay;
    end
  end

  // --- TLP RC -> EP ---
  beat_t q0 [Q];
  logic [$clog2(Q):0] w0, r0, dly0;
  logic dup0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w0 <= '0; r0 <= '0; dly0 <= '0; dup0 <= 1'b0;
      ep.tlp_rx_valid <= 1'b0; ep.tlp_rx_sop <= 1'b0; ep.tlp_rx_eop <= 1'b0; ep.tlp_rx_data <= '0;
      rc.tlp_tx_ready <= 1'b0;
      drop_nl0 <= '0;
    end else begin
      logic acc, full, empty;
      full  = (w0 - r0) == Q;
      empty = (w0 == r0);
      rc.tlp_tx_ready <= link_up && !ctrl.stall_rc_to_ep && !full && (ltssm == LT_L0);
      acc = rc.tlp_tx_valid && rc.tlp_tx_ready;
      if (acc) begin
        logic do_fault;
        do_fault = f_pend && (f_dir == 2'd0) && (f_skip == 0);
        if (!link_up || ltssm != LT_L0) begin
          drop_nl0 <= drop_nl0 + 1'b1;
        end else if (do_fault && f_kind == 3'd1) begin
          log_fault("RC2EP_TLP", "drop");
          f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1;
        end else begin
          q0[w0[$clog2(Q)-1:0]] <= '{rc.tlp_tx_sop, rc.tlp_tx_eop, 1'b0,
                                      {16'h0, do_fault && f_kind == 3'd2 ? ~rc.tlp_tx_data : rc.tlp_tx_data}};
          w0 <= w0 + 1'b1;
          if (do_fault && f_kind == 3'd2) begin log_fault("RC2EP_TLP", "corrupt"); f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
          if (do_fault && f_kind == 3'd3) begin log_fault("RC2EP_TLP", "duplicate"); dup0 <= 1'b1; f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
          if (do_fault && f_kind == 3'd4) begin log_fault("RC2EP_TLP", "delay"); dly0 <= f_delay; f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
        end
        if (f_pend && f_dir == 2'd0 && f_skip != 0 && rc.tlp_tx_eop) f_skip <= f_skip - 1'b1;
      end
      if (dly0 != 0) dly0 <= dly0 - 1'b1;
      if (!empty && dly0 == 0 && !ctrl.stall_rc_to_ep && (ltssm == LT_L0)) begin
        ep.tlp_rx_valid <= 1'b1;
        ep.tlp_rx_sop   <= q0[r0[$clog2(Q)-1:0]].sop;
        ep.tlp_rx_eop   <= q0[r0[$clog2(Q)-1:0]].eop;
        ep.tlp_rx_data  <= q0[r0[$clog2(Q)-1:0]].data[31:0];
        if (ep.tlp_rx_ready) begin
          if (dup0 && q0[r0[$clog2(Q)-1:0]].eop) dup0 <= 1'b0;
          else r0 <= r0 + 1'b1;
        end
      end else if (ep.tlp_rx_ready || !ep.tlp_rx_valid) begin
        ep.tlp_rx_valid <= 1'b0;
      end
    end
  end

  // --- TLP EP -> RC ---
  beat_t q1 [Q];
  logic [$clog2(Q):0] w1, r1, dly1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w1 <= '0; r1 <= '0; dly1 <= '0;
      rc.tlp_rx_valid <= 1'b0; rc.tlp_rx_sop <= 1'b0; rc.tlp_rx_eop <= 1'b0; rc.tlp_rx_data <= '0;
      ep.tlp_tx_ready <= 1'b0;
    end else begin
      logic full, empty, acc;
      full  = (w1 - r1) == Q;
      empty = (w1 == r1);
      ep.tlp_tx_ready <= link_up && !ctrl.stall_ep_to_rc && !full && (ltssm == LT_L0);
      acc = ep.tlp_tx_valid && ep.tlp_tx_ready;
      if (acc) begin
        logic do_fault;
        do_fault = f_pend && (f_dir == 2'd1) && (f_skip == 0);
        if (do_fault && f_kind == 3'd1) begin
          log_fault("EP2RC_TLP", "drop"); f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1;
        end else begin
          q1[w1[$clog2(Q)-1:0]] <= '{ep.tlp_tx_sop, ep.tlp_tx_eop, 1'b0,
                                      {16'h0, do_fault && f_kind == 3'd2 ? ~ep.tlp_tx_data : ep.tlp_tx_data}};
          w1 <= w1 + 1'b1;
          if (do_fault && f_kind == 3'd2) begin log_fault("EP2RC_TLP", "corrupt"); f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
          if (do_fault && f_kind == 3'd4) begin log_fault("EP2RC_TLP", "delay"); dly1 <= f_delay; f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
        end
        if (f_pend && f_dir == 2'd1 && f_skip != 0 && ep.tlp_tx_eop) f_skip <= f_skip - 1'b1;
      end
      if (dly1 != 0) dly1 <= dly1 - 1'b1;
      if (!empty && dly1 == 0 && !ctrl.stall_ep_to_rc && (ltssm == LT_L0)) begin
        rc.tlp_rx_valid <= 1'b1;
        rc.tlp_rx_sop   <= q1[r1[$clog2(Q)-1:0]].sop;
        rc.tlp_rx_eop   <= q1[r1[$clog2(Q)-1:0]].eop;
        rc.tlp_rx_data  <= q1[r1[$clog2(Q)-1:0]].data[31:0];
        if (rc.tlp_rx_ready) r1 <= r1 + 1'b1;
      end else if (rc.tlp_rx_ready || !rc.tlp_rx_valid) begin
        rc.tlp_rx_valid <= 1'b0;
      end
    end
  end

  // --- DLLP pass-through with optional fault ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ep.dllp_rx_valid <= 1'b0; ep.dllp_rx_data <= '0;
      rc.dllp_rx_valid <= 1'b0; rc.dllp_rx_data <= '0;
      ep.dllp_tx_ready <= 1'b1; rc.dllp_tx_ready <= 1'b1;
    end else begin
      ep.dllp_tx_ready <= link_up;
      rc.dllp_tx_ready <= link_up;
      if (rc.dllp_tx_valid && rc.dllp_tx_ready && ltssm == LT_L0) begin
        if (f_pend && f_dir == 2'd2 && f_kind == 3'd1) begin
          log_fault("RC2EP_DLLP", "drop"); f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1;
          ep.dllp_rx_valid <= 1'b0;
        end else begin
          ep.dllp_rx_valid <= 1'b1;
          ep.dllp_rx_data  <= (f_pend && f_dir == 2'd2 && f_kind == 3'd2) ? ~rc.dllp_tx_data : rc.dllp_tx_data;
          if (f_pend && f_dir == 2'd2 && f_kind == 3'd2) begin log_fault("RC2EP_DLLP", "corrupt"); f_pend <= 1'b0; f_cnt <= f_cnt + 1'b1; end
        end
      end else if (ep.dllp_rx_ready) ep.dllp_rx_valid <= 1'b0;

      if (ep.dllp_tx_valid && ep.dllp_tx_ready && ltssm == LT_L0) begin
        rc.dllp_rx_valid <= 1'b1;
        rc.dllp_rx_data  <= ep.dllp_tx_data;
      end else if (rc.dllp_rx_ready) rc.dllp_rx_valid <= 1'b0;
    end
  end
endmodule
