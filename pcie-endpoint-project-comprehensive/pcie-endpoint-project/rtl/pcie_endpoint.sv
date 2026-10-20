// Top-level Endpoint: Transaction Layer + Data Link Layer on the packet interface.
module pcie_endpoint
  import pcie_pkg::*;
(
  pcie_pkt_if.port lnk
);
  logic        flush;
  logic        dl_active;
  dl_state_e   dl_st;
  logic        fc_init_done;
  logic        fc_error;

  assign lnk.dll_state_dbg   = dl_st;
  assign lnk.dl_retrain_req  = 1'b0;

  // ---------------- DLLP codec ----------------
  logic        rx_ack, rx_nak, rx_initfc1, rx_initfc2, rx_updfc, rx_bad_crc, rx_unsup;
  logic [11:0] rx_acknak_seq;
  fc_class_e   rx_fc_class;
  logic [7:0]  rx_fc_hdr;
  logic [11:0] rx_fc_data;
  logic        nak_req, ack_req, fc_req, nak_gnt, ack_gnt, fc_gnt;
  logic [11:0] nak_seq, ack_seq;
  logic [7:0]  fc_type, fc_hdr_w;
  logic [11:0] fc_data_w;

  pcie_dllp_codec u_dllp (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .link_ok(lnk.phy_link_up),
    .dllp_rx_valid(lnk.dllp_rx_valid), .dllp_rx_ready(lnk.dllp_rx_ready), .dllp_rx_data(lnk.dllp_rx_data),
    .rx_ack, .rx_nak, .rx_acknak_seq, .rx_initfc1, .rx_initfc2, .rx_updfc,
    .rx_fc_class, .rx_fc_hdr, .rx_fc_data, .rx_bad_crc, .rx_unsupported(rx_unsup),
    .nak_req, .nak_seq, .nak_gnt, .ack_req, .ack_seq, .ack_gnt,
    .fc_req, .fc_type, .fc_hdr(fc_hdr_w), .fc_data(fc_data_w), .fc_gnt,
    .dllp_tx_valid(lnk.dllp_tx_valid), .dllp_tx_ready(lnk.dllp_tx_ready), .dllp_tx_data(lnk.dllp_tx_data)
  );

  pcie_dll_state u_dlst (
    .clk(lnk.clk), .rst_n(lnk.rst_n),
    .phy_link_up(lnk.phy_link_up), .phy_recovery(lnk.phy_recovery),
    .fc_init_done, .state(dl_st), .dl_active, .flush
  );

  logic [2:0]  credit_ok;
  logic [11:0] fc_need_data [3];
  logic        fc_consume;
  fc_class_e   fc_consume_class;
  logic        hdr_inf [3];
  logic [7:0]  hdr_cred [3];
  logic [11:0] data_cred [3];
  logic        rx_p_freed, rx_np_freed;
  logic [11:0] rx_p_dfree, rx_np_dfree;

  pcie_flow_control u_fc (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush, .in_init(dl_st == DL_INIT),
    .rx_initfc1, .rx_initfc2, .rx_updfc, .rx_fc_class, .rx_fc_hdr, .rx_fc_data,
    .consume(fc_consume), .consume_class(fc_consume_class),
    .consume_data(fc_need_data[fc_consume_class]),
    .need_hdr(3'b111), .need_data(fc_need_data), .credit_ok,
    .rx_p_freed, .rx_np_freed, .rx_p_data_freed(rx_p_dfree), .rx_np_data_freed(rx_np_dfree),
    .fc_req, .fc_type, .fc_hdr(fc_hdr_w), .fc_data(fc_data_w), .fc_gnt,
    .fc_init_done, .fc_error, .hdr_inf, .hdr_cred, .data_cred
  );

  logic        wr_valid, wr_first, commit, abort, space_ok;
  logic [31:0] wr_data;
  logic        rx_ok, rx_dup, rx_bad, overflow;
  logic [11:0] rx_seq, rx_expected;

  pcie_dll_rx u_dll_rx (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .dl_active, .flush,
    .lnk_valid(lnk.tlp_rx_valid), .lnk_ready(lnk.tlp_rx_ready),
    .lnk_sop(lnk.tlp_rx_sop), .lnk_eop(lnk.tlp_rx_eop), .lnk_data(lnk.tlp_rx_data),
    .wr_valid, .wr_first, .wr_data, .commit, .abort, .space_ok,
    .rx_ok, .rx_dup, .rx_bad, .rx_seq, .rx_expected, .overflow
  );

  pcie_ack_nak_ctrl u_ack (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .dl_active,
    .rx_ok, .rx_dup, .rx_bad, .rx_seq, .rx_expected,
    .ack_req, .ack_seq, .ack_gnt, .nak_req, .nak_seq, .nak_gnt
  );

  logic [2:0]  pkt_avail, head_ro;
  logic [5:0]  head_count [3];
  logic [15:0] head_stamp [3];
  logic [15:0] p_consumed;
  logic        rd_en, pop;
  fc_class_e   rd_q;
  logic [31:0] rd_data;

  pcie_tlp_rx u_tlp_rx (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush,
    .wr_valid, .wr_first, .wr_data, .commit, .abort, .space_ok,
    .pkt_avail, .head_count, .head_stamp, .head_ro, .p_consumed,
    .rd_en, .rd_q, .rd_data, .pop
  );

  logic        rx_np_ok, rx_cpl_ok;
  logic [2:0]  txq_wr_en, txq_commit, txq_space_ok, txq_commit_ro;
  logic [31:0] txq_wr_data [3];
  logic [5:0]  txq_commit_count [3];
  logic        ord_tx_valid, ord_tx_ready, ord_tx_sop, ord_tx_eop;
  logic [31:0] ord_tx_data;
  fc_class_e   ord_tx_class;
  logic        tx_bypass_p;

  pcie_ordering_ctrl u_ord (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush,
    .rx_avail(pkt_avail), .rx_head_stamp(head_stamp), .rx_head_ro(head_ro),
    .rx_p_consumed(p_consumed), .rx_np_ok, .rx_cpl_ok,
    .txq_wr_en, .txq_wr_data, .txq_commit, .txq_commit_count, .txq_commit_ro, .txq_space_ok,
    .fc_need_data, .fc_ok(credit_ok), .fc_consume, .fc_consume_class,
    .tx_enable(dl_active), .tx_valid(ord_tx_valid), .tx_ready(ord_tx_ready),
    .tx_sop(ord_tx_sop), .tx_eop(ord_tx_eop), .tx_data(ord_tx_data),
    .tx_class(ord_tx_class), .tx_bypass_p
  );

  logic        retry_fail, replay_tmo, replay_roll, replay_empty, replay_active;
  logic [11:0] next_seq;
  logic [3:0]  replay_occ;

  pcie_dll_tx u_dll_tx (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .dl_active, .flush,
    .tlp_valid(ord_tx_valid), .tlp_ready(ord_tx_ready),
    .tlp_sop(ord_tx_sop), .tlp_eop(ord_tx_eop), .tlp_data(ord_tx_data),
    .lnk_valid(lnk.tlp_tx_valid), .lnk_ready(lnk.tlp_tx_ready),
    .lnk_sop(lnk.tlp_tx_sop), .lnk_eop(lnk.tlp_tx_eop), .lnk_data(lnk.tlp_tx_data),
    .ack_valid(rx_ack), .ack_seq(rx_acknak_seq), .nak_valid(rx_nak),
    .retry_fail, .replay_timeout_ev(replay_tmo), .replay_roll_ev(replay_roll),
    .next_seq, .replay_occ, .replay_empty, .replay_active
  );

  // ---------------- Config / BAR / memory ----------------
  logic        mem_space_en, bus_master_en, parity_err_resp;
  logic [31:0] bar0, bar1;
  logic        msi_enable, msi_mask, msi_pending;
  logic [31:0] msi_addr;
  logic [15:0] msi_data, completer_id;
  logic [2:0]  max_read_req;
  logic [9:0]  cfg_rd_idx, cfg_wr_idx;
  logic [31:0] cfg_rd_data, cfg_wr_data;
  logic        cfg_wr_en;
  logic [3:0]  cfg_wr_be;
  logic [7:0]  cfg_wr_bus;
  logic [4:0]  cfg_wr_dev;
  logic        trans_pend;
  logic [NUM_ERR-1:0] err_event, err_clear, err_status;
  logic        set_ced, set_nfed, set_fed, set_urd;
  logic        set_dpe, set_mdpe, set_rma, set_rta;

  pcie_config_space u_cfg (
    .clk(lnk.clk), .rst_n(lnk.rst_n),
    .rd_idx(cfg_rd_idx), .rd_data(cfg_rd_data),
    .wr_en(cfg_wr_en), .wr_idx(cfg_wr_idx), .wr_be(cfg_wr_be), .wr_data(cfg_wr_data),
    .wr_bus(cfg_wr_bus), .wr_dev(cfg_wr_dev),
    .set_detected_parity(set_dpe), .set_rcvd_master_abort(set_rma),
    .set_rcvd_target_abort(set_rta), .set_master_data_parity(set_mdpe),
    .set_ced, .set_nfed, .set_fed, .set_urd,
    .transactions_pending(trans_pend), .msi_pending,
    .mem_space_en, .bus_master_en, .parity_err_resp, .bar0, .bar1,
    .msi_enable, .msi_addr, .msi_data, .msi_mask, .completer_id, .max_read_req
  );

  logic        mem_rd_bar, mem_wr_en, mem_wr_bar;
  logic [9:0]  mem_rd_idx, mem_wr_idx;
  logic [31:0] mem_rd_data, mem_wr_data;
  logic [3:0]  mem_wr_be;
  logic [63:0] dma_haddr;
  logic [9:0]  dma_laddr;
  logic [10:0] dma_len;
  logic        dma_start, dma_dir, dma_ro, dma_ns, dma_busy, dma_done, dma_err;
  logic [23:0] cpl_timeout;
  logic        msi_doorbell, msi_sent, msi_blocked;
  logic [7:0]  tags_in_use;
  logic [2:0]  outstanding;
  logic [15:0] cpl_err_log;
  logic [9:0]  buf_rd_idx, buf_wr_idx;
  logic [31:0] buf_rd_data, buf_wr_data;
  logic        buf_wr_en;

  pcie_register_file u_rf (
    .clk(lnk.clk), .rst_n(lnk.rst_n),
    .rd_bar(mem_rd_bar), .rd_idx(mem_rd_idx), .rd_data(mem_rd_data),
    .wr_en(mem_wr_en), .wr_bar(mem_wr_bar), .wr_idx(mem_wr_idx), .wr_be(mem_wr_be), .wr_data(mem_wr_data),
    .dma_rd_idx(buf_rd_idx), .dma_rd_data(buf_rd_data),
    .dma_wr_en(buf_wr_en), .dma_wr_idx(buf_wr_idx), .dma_wr_data(buf_wr_data),
    .dma_haddr, .dma_laddr, .dma_len, .dma_start, .dma_dir, .dma_ro, .dma_ns, .cpl_timeout, .msi_doorbell,
    .dma_busy, .dma_done_set(dma_done), .dma_err_set(dma_err),
    .msi_sent_set(msi_sent), .msi_blocked_set(msi_blocked), .msi_pending,
    .tags_in_use, .outstanding, .cpl_err_log, .err_status, .err_clear
  );

  logic        cpl_start, cpl_busy, cpl_done;
  cpl_ctx_t    cpl_ctx;
  logic        cg_mem_rd_bar;
  logic [9:0]  cg_mem_rd_idx, cg_cfg_rd_idx;
  logic [31:0] cg_q_data;
  logic        cg_q_wr, cg_q_commit, cg_q_ro;
  logic [5:0]  cg_q_cnt;

  pcie_completion_gen u_cg (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush,
    .start(cpl_start), .ctx(cpl_ctx), .completer_id, .busy(cpl_busy),
    .mem_rd_bar(cg_mem_rd_bar), .mem_rd_idx(cg_mem_rd_idx), .mem_rd_data(mem_rd_data),
    .cfg_rd_idx(cg_cfg_rd_idx), .cfg_rd_data,
    .q_wr_en(cg_q_wr), .q_wr_data(cg_q_data), .q_commit(cg_q_commit),
    .q_commit_count(cg_q_cnt), .q_commit_ro(cg_q_ro), .q_space_ok(txq_space_ok[FC_CPL]),
    .cpl_done
  );

  logic        req_cpl_hdr_valid, req_cpl_data_valid;
  tlp_hdr_t    req_cpl_hdr;
  tlp_kind_e   req_cpl_kind;
  logic [10:0] req_cpl_payload_dw;
  logic [31:0] req_cpl_data;
  logic        ev_malformed, ev_poisoned, ev_ur;
  logic [1:0]  dbg_bar_hit;
  logic        dbg_rejected, dbg_wrote;
  logic [3:0]  dbg_wr_be;
  logic [11:0] dbg_wr_addr;

  // Mux register-file / config reads for the engine vs completion generator
  logic        rh_mem_rd_bar;
  logic [9:0]  rh_mem_rd_idx, rh_cfg_rd_idx;
  assign mem_rd_bar = cpl_busy ? cg_mem_rd_bar : rh_mem_rd_bar;
  assign mem_rd_idx = cpl_busy ? cg_mem_rd_idx : rh_mem_rd_idx;
  assign cfg_rd_idx = cpl_busy ? cg_cfg_rd_idx : rh_cfg_rd_idx;

  pcie_request_handler u_rh (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush,
    .pkt_avail, .head_count, .rx_np_ok, .rx_cpl_ok,
    .rd_en, .rd_q, .rd_data, .pop,
    .mem_space_en, .bar0, .bar1,
    .cfg_rd_idx(rh_cfg_rd_idx), .cfg_rd_data,
    .cfg_wr_en, .cfg_wr_idx, .cfg_wr_be, .cfg_wr_data, .cfg_wr_bus, .cfg_wr_dev,
    .mem_rd_bar(rh_mem_rd_bar), .mem_rd_idx(rh_mem_rd_idx), .mem_rd_data,
    .mem_wr_en, .mem_wr_bar, .mem_wr_idx, .mem_wr_be, .mem_wr_data,
    .cpl_start, .cpl_ctx, .cpl_busy, .cpl_done,
    .req_cpl_hdr_valid, .req_cpl_hdr, .req_cpl_kind, .req_cpl_payload_dw,
    .req_cpl_data_valid, .req_cpl_data,
    .ev_malformed, .ev_poisoned, .ev_ur,
    .dbg_bar_hit, .dbg_rejected, .dbg_wrote, .dbg_wr_be, .dbg_wr_addr
  );

  logic        p_wr, np_wr, p_cmt, np_cmt, q_ro;
  logic [31:0] q_wd;
  logic [5:0]  q_cnt;
  logic        ev_cpl_timeout, ev_unexp_cpl, ev_bad_cpl, ev_cpl_status, ev_cpl_ur, ev_cpl_ca;
  logic        ev_tag_alloc, ev_tag_free;
  logic [7:0]  ev_tag;

  pcie_requester u_req (
    .clk(lnk.clk), .rst_n(lnk.rst_n), .flush,
    .requester_id(completer_id), .bus_master_en,
    .dma_start, .dma_haddr, .dma_laddr, .dma_len, .dma_dir, .dma_ro, .dma_ns, .cpl_timeout,
    .dma_busy, .dma_done, .dma_err,
    .msi_doorbell, .msi_enable, .msi_mask, .msi_addr, .msi_data,
    .msi_pending, .msi_sent, .msi_blocked,
    .buf_rd_idx, .buf_rd_data, .buf_wr_en, .buf_wr_idx, .buf_wr_data,
    .p_wr_en(p_wr), .np_wr_en(np_wr), .q_wr_data(q_wd), .p_commit(p_cmt), .np_commit(np_cmt),
    .q_commit_count(q_cnt), .q_commit_ro(q_ro),
    .p_space_ok(txq_space_ok[FC_P]), .np_space_ok(txq_space_ok[FC_NP]),
    .cpl_hdr_valid(req_cpl_hdr_valid), .cpl_hdr(req_cpl_hdr), .cpl_kind(req_cpl_kind),
    .cpl_payload_dw(req_cpl_payload_dw), .cpl_data_valid(req_cpl_data_valid), .cpl_data(req_cpl_data),
    .tags_in_use, .outstanding, .cpl_err_log,
    .ev_cpl_timeout, .ev_unexp_cpl, .ev_bad_cpl, .ev_cpl_status, .ev_cpl_ur, .ev_cpl_ca,
    .ev_tag_alloc, .ev_tag_free, .ev_tag
  );

  // TX queue write mux: completion generator vs requester
  always_comb begin
    txq_wr_en        = '0;
    txq_commit       = '0;
    txq_commit_ro    = '0;
    txq_commit_count = '{default: '0};
    txq_wr_data      = '{default: '0};
    txq_wr_en[FC_CPL]        = cg_q_wr;
    txq_wr_data[FC_CPL]      = cg_q_data;
    txq_commit[FC_CPL]       = cg_q_commit;
    txq_commit_count[FC_CPL] = cg_q_cnt;
    txq_commit_ro[FC_CPL]    = cg_q_ro;
    txq_wr_en[FC_P]          = p_wr;
    txq_wr_data[FC_P]        = q_wd;
    txq_commit[FC_P]         = p_cmt;
    txq_commit_count[FC_P]   = q_cnt;
    txq_commit_ro[FC_P]      = q_ro;
    txq_wr_en[FC_NP]         = np_wr;
    txq_wr_data[FC_NP]       = q_wd;
    txq_commit[FC_NP]        = np_cmt;
    txq_commit_count[FC_NP]  = q_cnt;
    txq_commit_ro[FC_NP]     = q_ro;
  end

  // DMA buffer port shares BAR1
  pcie_error_handler u_err (
    .clk(lnk.clk), .rst_n(lnk.rst_n),
    .err_event, .err_clear, .poisoned_cpl(req_cpl_hdr.ep && req_cpl_hdr_valid),
    .cpl_status_ur(ev_cpl_ur), .cpl_status_ca(ev_cpl_ca), .parity_err_resp,
    .err_status, .set_ced, .set_nfed, .set_fed, .set_urd,
    .set_detected_parity(set_dpe), .set_master_data_parity(set_mdpe),
    .set_rcvd_master_abort(set_rma), .set_rcvd_target_abort(set_rta)
  );

  always_comb begin
    err_event = '0;
    err_event[ERR_MALFORMED]   = ev_malformed;
    err_event[ERR_POISONED]    = ev_poisoned;
    err_event[ERR_UR]          = ev_ur;
    err_event[ERR_RX_OVERFLOW] = overflow;
    err_event[ERR_FC_PROTOCOL] = fc_error;
    err_event[ERR_BAD_LCRC]    = rx_bad;
    err_event[ERR_BAD_DLLP]    = rx_bad_crc;
    err_event[ERR_REPLAY_ROLL] = replay_roll;
    err_event[ERR_REPLAY_TMO]  = replay_tmo;
    err_event[ERR_CPL_TIMEOUT] = ev_cpl_timeout;
    err_event[ERR_UNEXP_CPL]   = ev_unexp_cpl;
    err_event[ERR_BAD_CPL]     = ev_bad_cpl;
    err_event[ERR_CPL_STATUS]  = ev_cpl_status;
    err_event[ERR_DLLP_PROTO]  = rx_unsup;
  end

  assign trans_pend = dma_busy || (outstanding != 0);
  assign rx_p_freed  = pop && (rd_q == FC_P);
  assign rx_np_freed = pop && (rd_q == FC_NP);
  assign rx_p_dfree  = 12'd1;
  assign rx_np_dfree = 12'd1;

`ifndef SYNTHESIS
  pcie_endpoint_assertions u_asrt (
    .clk(lnk.clk), .rst_n(lnk.rst_n),
    .tlp_tx_valid(lnk.tlp_tx_valid), .tlp_tx_ready(lnk.tlp_tx_ready),
    .tlp_tx_sop(lnk.tlp_tx_sop), .tlp_tx_eop(lnk.tlp_tx_eop), .tlp_tx_data(lnk.tlp_tx_data),
    .tlp_rx_valid(lnk.tlp_rx_valid), .tlp_rx_ready(lnk.tlp_rx_ready),
    .tlp_rx_sop(lnk.tlp_rx_sop), .tlp_rx_eop(lnk.tlp_rx_eop), .tlp_rx_data(lnk.tlp_rx_data),
    .dllp_tx_valid(lnk.dllp_tx_valid), .dllp_tx_ready(lnk.dllp_tx_ready),
    .dllp_rx_valid(lnk.dllp_rx_valid), .dllp_rx_ready(lnk.dllp_rx_ready),
    .phy_link_up(lnk.phy_link_up), .phy_recovery(lnk.phy_recovery),
    .dll_state(dl_st), .dl_active, .flush,
    .bar_hit(dbg_bar_hit), .rejected(dbg_rejected), .wrote(dbg_wrote), .wr_be(dbg_wr_be),
    .tags_in_use, .replay_empty, .replay_active, .replay_occ,
    .hdr_cred, .data_cred, .credit_ok, .fc_consume,
    .rx_bad, .commit, .rx_ok,
    .ltssm(lnk.ltssm_state_dbg)
  );
`endif
endmodule
