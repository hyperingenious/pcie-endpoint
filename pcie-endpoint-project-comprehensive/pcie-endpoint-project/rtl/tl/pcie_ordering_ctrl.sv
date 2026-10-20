// Transaction ordering for VC0 (single TC in use).
//
// Receive side: the Posted queue is processed in order. A Non-Posted Request is eligible only
// after every Posted Request received before it has been consumed. A Completion is eligible
// after earlier Posted Requests, or immediately when its RO attribute is set.
//
// Transmit side: three queues (Posted from the requester/MSI, Non-Posted from the requester,
// Completions from the request handler). Posted TLPs keep their order. A Non-Posted Request
// never passes an earlier Posted Request. A Completion passes an earlier Posted Request only
// when RO is set. Posted Requests may pass Non-Posted Requests and Completions. Selection is
// round-robin among eligible queues whose flow-control credits are available.
module pcie_ordering_ctrl
  import pcie_pkg::*;
#(
  parameter int TX_P_DEPTH   = 128,
  parameter int TX_NP_DEPTH  = 64,
  parameter int TX_CPL_DEPTH = 128,
  parameter int DESC_DEPTH   = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // RX eligibility
  input  logic [2:0]  rx_avail,
  input  logic [15:0] rx_head_stamp [3],
  input  logic [2:0]  rx_head_ro,
  input  logic [15:0] rx_p_consumed,
  output logic        rx_np_ok,
  output logic        rx_cpl_ok,

  // TX queue write ports, index by fc_class_e
  input  logic [2:0]  txq_wr_en,
  input  logic [31:0] txq_wr_data [3],
  input  logic [2:0]  txq_commit,
  input  logic [5:0]  txq_commit_count [3],
  input  logic [2:0]  txq_commit_ro,
  output logic [2:0]  txq_space_ok,

  // flow-control gate
  output logic [11:0] fc_need_data [3],
  input  logic [2:0]  fc_ok,
  output logic        fc_consume,
  output fc_class_e   fc_consume_class,

  // TLP stream to the Data Link Layer
  input  logic        tx_enable,
  output logic        tx_valid,
  input  logic        tx_ready,
  output logic        tx_sop,
  output logic        tx_eop,
  output logic [31:0] tx_data,
  output fc_class_e   tx_class,
  output logic        tx_bypass_p
);
  function automatic logic stamp_done(input logic [15:0] consumed, input logic [15:0] stamp);
    logic [15:0] d;
    d = consumed - stamp;
    return !d[15];
  endfunction

  assign rx_np_ok  = rx_avail[FC_NP]  && stamp_done(rx_p_consumed, rx_head_stamp[FC_NP]);
  assign rx_cpl_ok = rx_avail[FC_CPL] && (rx_head_ro[FC_CPL] || stamp_done(rx_p_consumed, rx_head_stamp[FC_CPL]));

  logic [15:0] p_committed;
  logic [15:0] p_sent;
  logic [2:0]  q_avail;
  logic [5:0]  q_count [3];
  logic [15:0] q_stamp [3];
  logic [2:0]  q_ro;
  logic [31:0] q_rd_data [3];
  logic [2:0]  q_rd_en;
  logic [2:0]  q_pop;

  for (genvar q = 0; q < 3; q++) begin : g_txq
    localparam int D = (q == 0) ? TX_P_DEPTH : (q == 1) ? TX_NP_DEPTH : TX_CPL_DEPTH;
    pcie_rx_queue #(.DEPTH(D), .DESC_DEPTH(DESC_DEPTH)) u_q (
      .clk, .rst_n, .flush,
      .wr_en        (txq_wr_en[q]),
      .wr_data      (txq_wr_data[q]),
      .commit       (txq_commit[q]),
      .abort        (1'b0),
      .commit_count (txq_commit_count[q]),
      .commit_stamp (p_committed),
      .commit_ro    (txq_commit_ro[q]),
      .space_ok     (txq_space_ok[q]),
      .avail        (q_avail[q]),
      .head_count   (q_count[q]),
      .head_stamp   (q_stamp[q]),
      .head_ro      (q_ro[q]),
      .rd_en        (q_rd_en[q]),
      .rd_data      (q_rd_data[q]),
      .pop          (q_pop[q])
    );
    assign fc_need_data[q] = data_credits_of(q_rd_data[q][31:29], q_rd_data[q][9:0]);
  end

  logic [2:0] elig;
  assign elig[FC_P]   = q_avail[FC_P]   && fc_ok[FC_P];
  assign elig[FC_NP]  = q_avail[FC_NP]  && fc_ok[FC_NP]  && stamp_done(p_sent, q_stamp[FC_NP]);
  assign elig[FC_CPL] = q_avail[FC_CPL] && fc_ok[FC_CPL] &&
                        (q_ro[FC_CPL] || stamp_done(p_sent, q_stamp[FC_CPL]));

  logic       busy;
  fc_class_e  cur;
  logic [5:0] left;
  logic [1:0] rr;
  logic       pick_valid;
  fc_class_e  pick;

  always_comb begin
    pick_valid = 1'b0;
    pick       = FC_P;
    for (int k = 0; k < 3; k++) begin
      int c;
      c = (int'(rr) + k) % 3;
      if (!pick_valid && elig[c]) begin
        pick_valid = 1'b1;
        pick       = fc_class_e'(c);
      end
    end
  end

  logic start;
  assign start            = !busy && tx_enable && pick_valid;
  assign fc_consume       = start;
  assign fc_consume_class = pick;

  assign tx_valid = busy;
  assign tx_class = cur;
  assign tx_data  = q_rd_data[cur];
  assign tx_eop   = busy && (left == 6'd1);

  logic first_beat;
  assign tx_sop = busy && first_beat;

  always_comb begin
    q_rd_en = '0;
    q_pop   = '0;
    if (busy && tx_ready) begin
      q_rd_en[cur] = 1'b1;
      if (left == 6'd1) q_pop[cur] = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy        <= 1'b0;
      cur         <= FC_P;
      left        <= '0;
      rr          <= '0;
      first_beat  <= 1'b0;
      p_committed <= '0;
      p_sent      <= '0;
      tx_bypass_p <= 1'b0;
    end else if (flush) begin
      busy        <= 1'b0;
      left        <= '0;
      first_beat  <= 1'b0;
      p_committed <= '0;
      p_sent      <= '0;
      tx_bypass_p <= 1'b0;
    end else begin
      if (txq_commit[FC_P]) p_committed <= p_committed + 1'b1;
      if (start) begin
        busy        <= 1'b1;
        cur         <= pick;
        left        <= q_count[pick];
        first_beat  <= 1'b1;
        rr          <= (pick == FC_CPL) ? 2'd0 : 2'(int'(pick) + 1);
        tx_bypass_p <= (pick != FC_P) && !stamp_done(p_sent, q_stamp[pick]);
      end else if (busy && tx_ready) begin
        first_beat <= 1'b0;
        left       <= left - 1'b1;
        if (left == 6'd1) begin
          busy <= 1'b0;
          if (cur == FC_P) p_sent <= p_sent + 1'b1;
        end
      end
    end
  end
endmodule
