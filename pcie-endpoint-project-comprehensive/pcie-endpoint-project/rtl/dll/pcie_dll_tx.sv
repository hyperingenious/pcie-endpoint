// Transmit path: prepend sequence number, append LCRC, store TLP body for replay.
module pcie_dll_tx
  import pcie_pkg::*;
  import pcie_crc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        dl_active,
  input  logic        flush,

  input  logic        tlp_valid,
  output logic        tlp_ready,
  input  logic        tlp_sop,
  input  logic        tlp_eop,
  input  logic [31:0] tlp_data,

  output logic        lnk_valid,
  input  logic        lnk_ready,
  output logic        lnk_sop,
  output logic        lnk_eop,
  output logic [31:0] lnk_data,

  input  logic        ack_valid,
  input  logic [11:0] ack_seq,
  input  logic        nak_valid,
  output logic        retry_fail,
  output logic        replay_timeout_ev,
  output logic        replay_roll_ev,
  output logic [11:0] next_seq,
  output logic [3:0]  replay_occ,
  output logic        replay_empty,
  output logic        replay_active
);
  typedef enum logic [2:0] {T_IDLE, T_SEQ, T_BODY, T_CRC, T_RSEQ, T_RBODY, T_RCRC} tst_e;

  tst_e        st;
  logic [11:0] seq;
  logic [31:0] crc;
  logic [2:0]  retries;
  logic        tmo;
  logic        rb_full;
  logic        rp_go, rp_act, rp_val, rp_rdy, rp_sop, rp_eop;
  logic [31:0] rp_data;
  logic [11:0] rp_seq;

  assign next_seq     = seq;
  assign replay_active= rp_act || (st inside {T_RSEQ, T_RBODY, T_RCRC});
  assign tlp_ready    = dl_active && !flush && !rb_full && (st == T_BODY) && lnk_ready;
  assign rp_go        = (st == T_IDLE) && (nak_valid || tmo) && !replay_empty &&
                        (retries < 3'(RETRY_LIMIT));
  assign retry_fail   = (st == T_IDLE) && (nak_valid || tmo) && !replay_empty &&
                        (retries >= 3'(RETRY_LIMIT));
  assign replay_timeout_ev = tmo && !replay_empty;
  assign replay_roll_ev    = rp_go;

  pcie_replay_buffer u_rb (
    .clk, .rst_n, .flush,
    .wr_en(tlp_valid && tlp_ready), .wr_data(tlp_data),
    .wr_sop(tlp_sop), .wr_eop(tlp_eop), .wr_seq(seq),
    .full(rb_full), .empty(replay_empty), .occupancy(replay_occ),
    .ack_valid, .ack_seq,
    .replay_go(rp_go), .replay_active(rp_act),
    .replay_valid(rp_val), .replay_ready(rp_rdy),
    .replay_data(rp_data), .replay_sop(rp_sop), .replay_eop(rp_eop), .replay_seq(rp_seq)
  );

  pcie_replay_timer u_tm (
    .clk, .rst_n, .dl_active,
    .unacked_pending(!replay_empty),
    .restart(ack_valid || rp_go),
    .timeout(tmo)
  );

  assign rp_rdy = (st == T_RBODY) && lnk_ready;

  always_comb begin
    lnk_valid = 1'b0;
    lnk_sop   = 1'b0;
    lnk_eop   = 1'b0;
    lnk_data  = 32'h0;
    unique case (st)
      T_SEQ, T_RSEQ: begin
        lnk_valid = 1'b1;
        lnk_sop   = 1'b1;
        lnk_data  = {16'h0, 4'h0, (st == T_RSEQ) ? rp_seq : seq};
      end
      T_BODY: begin
        lnk_valid = tlp_valid && tlp_ready;
        lnk_data  = tlp_data;
      end
      T_RBODY: begin
        lnk_valid = rp_val;
        lnk_data  = rp_data;
      end
      T_CRC, T_RCRC: begin
        lnk_valid = 1'b1;
        lnk_eop   = 1'b1;
        lnk_data  = lcrc_final(crc);
      end
      default: ;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= T_IDLE; seq <= '0; crc <= LCRC_SEED; retries <= '0;
    end else if (flush) begin
      st <= T_IDLE; seq <= '0; retries <= '0;
    end else begin
      if (ack_valid) retries <= '0;
      if (rp_go)     retries <= retries + 1'b1;

      unique case (st)
        T_IDLE: begin
          if (rp_go) begin
            st  <= T_RSEQ;
            crc <= lcrc_seq(rp_seq);
          end else if (dl_active && tlp_valid && tlp_sop && !rb_full) begin
            st  <= T_SEQ;
            crc <= lcrc_seq(seq);
          end
        end
        T_SEQ: if (lnk_ready) st <= T_BODY;
        T_BODY: if (tlp_valid && tlp_ready) begin
          crc <= lcrc_dw(crc, tlp_data);
          if (tlp_eop) st <= T_CRC;
        end
        T_CRC: if (lnk_ready) begin
          seq <= (seq == 12'd4095) ? 12'd0 : (seq + 12'd1);
          st  <= T_IDLE;
        end
        T_RSEQ: if (lnk_ready) st <= T_RBODY;
        T_RBODY: if (rp_val && lnk_ready) begin
          crc <= lcrc_dw(crc, rp_data);
          if (rp_eop) st <= T_RCRC;
        end
        T_RCRC: if (lnk_ready) st <= rp_act ? T_RSEQ : T_IDLE;
        default: st <= T_IDLE;
      endcase
    end
  end
endmodule
