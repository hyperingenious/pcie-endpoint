// Endpoint-originated requests: DMA engine and MSI.
//
// DMA write (REG_DMA_CTRL.dir = 0): BAR1[laddr..] -> host[haddr..] as Memory Writes of at most
// 128 B (MPS) that never cross a 4 KB host boundary.
// DMA read  (dir = 1): host[haddr..] -> BAR1[laddr..] as Memory Reads of at most 128 B (MRRS)
// that never cross a 4 KB boundary. Tags 0-7 are allocated round-robin; at most 4 reads are
// outstanding. Completions are matched on Requester ID plus Tag and checked for status,
// Byte Count (remaining bytes) and Lower Address (expected next address). A bad or unexpected
// Completion is dropped and logged without touching any other Tag. Each Tag has a timeout
// (REG_CPL_TIMEOUT cycles, 0 disables) after which it is released and a late Completion
// becomes unexpected.
// Headers are 4DW when the host address is above 4 GiB, otherwise 3DW. Requests need
// Bus Master Enable; a DMA started without it, with a bad length/range, or while busy,
// reports a DMA error and issues nothing.
//
// MSI: a doorbell write sends one 32-bit-address Memory Write (Length 1, First BE 0011b,
// data = Message Data) when MSI and Bus Master are enabled and no DMA write is in progress.
// While the vector is masked the request is held as pending and sent after unmasking.
// A doorbell with MSI or Bus Master disabled is dropped and flagged.
module pcie_requester
  import pcie_pkg::*;
  import pcie_tlp_codec_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic [15:0] requester_id,
  input  logic        bus_master_en,

  input  logic        dma_start,
  input  logic [63:0] dma_haddr,
  input  logic [9:0]  dma_laddr,
  input  logic [10:0] dma_len,
  input  logic        dma_dir,
  input  logic        dma_ro,
  input  logic        dma_ns,
  input  logic [23:0] cpl_timeout,
  output logic        dma_busy,
  output logic        dma_done,
  output logic        dma_err,

  input  logic        msi_doorbell,
  input  logic        msi_enable,
  input  logic        msi_mask,
  input  logic [31:0] msi_addr,
  input  logic [15:0] msi_data,
  output logic        msi_pending,
  output logic        msi_sent,
  output logic        msi_blocked,

  output logic [9:0]  buf_rd_idx,
  input  logic [31:0] buf_rd_data,
  output logic        buf_wr_en,
  output logic [9:0]  buf_wr_idx,
  output logic [31:0] buf_wr_data,

  output logic        p_wr_en,
  output logic        np_wr_en,
  output logic [31:0] q_wr_data,
  output logic        p_commit,
  output logic        np_commit,
  output logic [5:0]  q_commit_count,
  output logic        q_commit_ro,
  input  logic        p_space_ok,
  input  logic        np_space_ok,

  input  logic        cpl_hdr_valid,
  input  tlp_hdr_t    cpl_hdr,
  input  tlp_kind_e   cpl_kind,
  input  logic [10:0] cpl_payload_dw,
  input  logic        cpl_data_valid,
  input  logic [31:0] cpl_data,

  output logic [7:0]  tags_in_use,
  output logic [2:0]  outstanding,
  output logic [15:0] cpl_err_log,
  output logic        ev_cpl_timeout,
  output logic        ev_unexp_cpl,
  output logic        ev_bad_cpl,
  output logic        ev_cpl_status,
  output logic        ev_cpl_ur,
  output logic        ev_cpl_ca,
  output logic        ev_tag_alloc,
  output logic        ev_tag_free,
  output logic [7:0]  ev_tag
);
  // ---------------------------------------------------------------- DMA job state
  logic        job_active;
  logic        job_dir;
  logic        job_ro, job_ns;
  logic        job_err;
  logic [63:0] job_haddr;     // next host byte address to request
  logic [9:0]  job_lidx;      // next BAR1 DW index to request
  logic [10:0] job_left;      // DWs not yet requested

  // per-tag read context
  logic [7:0]  t_active;
  logic [12:0] t_rem   [8];
  logic [9:0]  t_lidx  [8];
  logic [6:0]  t_la    [8];
  logic [23:0] t_age   [8];

  assign tags_in_use = t_active;
  always_comb begin
    outstanding = '0;
    for (int i = 0; i < 8; i++) outstanding += 3'(t_active[i]);
  end

  // next request size: <= 32 DW and inside the current 4 KB host page
  logic [10:0] page_left_dw;
  logic [5:0]  req_dw;
  assign page_left_dw = 11'd1024 - {1'b0, job_haddr[11:2]};
  always_comb begin
    logic [10:0] n;
    n = (job_left < 11'd32) ? job_left : 11'd32;
    if (page_left_dw < n) n = page_left_dw;
    req_dw = n[5:0];
  end

  // round-robin free tag search
  logic [2:0] tag_ptr;
  logic       free_found;
  logic [2:0] free_tag;
  always_comb begin
    free_found = 1'b0;
    free_tag   = 3'd0;
    for (int k = 0; k < 8; k++) begin
      logic [2:0] t;
      t = tag_ptr + 3'(k);
      if (!free_found && !t_active[t]) begin
        free_found = 1'b1;
        free_tag   = t;
      end
    end
  end

  // ---------------------------------------------------------------- TX writer
  typedef enum logic [1:0] {W_IDLE, W_HDR, W_DATA} wst_e;
  wst_e        wst;
  logic        w_np;
  logic        w_msi;
  logic [31:0] w_hdr [4];
  logic [2:0]  w_hdr_n;
  logic [2:0]  w_hbeat;
  logic [5:0]  w_dw;
  logic [5:0]  w_dbeat;
  logic [9:0]  w_lidx;
  logic        w_ro;

  logic is64;
  assign is64 = (job_haddr[63:32] != 32'h0);

  logic msi_req;
  assign msi_req = msi_pending && msi_enable && bus_master_en && !msi_mask &&
                   !(job_active && !job_dir);

  logic issue_wr, issue_rd, issue_msi;
  assign issue_wr  = (wst == W_IDLE) && job_active && !job_dir && !job_err && job_left != 0 && p_space_ok;
  assign issue_rd  = (wst == W_IDLE) && job_active &&  job_dir && !job_err && job_left != 0 && np_space_ok &&
                     free_found && (outstanding < 3'(MAX_OUTSTANDING));
  assign issue_msi = (wst == W_IDLE) && !issue_wr && msi_req && p_space_ok;

  assign buf_rd_idx = w_lidx;

  always_comb begin
    p_wr_en        = 1'b0;
    np_wr_en       = 1'b0;
    q_wr_data      = 32'h0;
    p_commit       = 1'b0;
    np_commit      = 1'b0;
    q_commit_count = {3'd0, w_hdr_n} + w_dw;
    q_commit_ro    = w_ro;
    if (wst == W_HDR) begin
      q_wr_data = w_hdr[w_hbeat[1:0]];
      if (w_np) np_wr_en = 1'b1; else p_wr_en = 1'b1;
      if (w_hbeat == w_hdr_n - 3'd1 && w_dw == 6'd0) begin
        if (w_np) np_commit = 1'b1; else p_commit = 1'b1;
      end
    end else if (wst == W_DATA) begin
      q_wr_data = w_msi ? bswap32({16'h0, msi_data}) : bswap32(buf_rd_data);
      p_wr_en   = 1'b1;
      p_commit  = (w_dbeat == w_dw - 6'd1);
    end
  end

  // ---------------------------------------------------------------- Completion intake
  logic        c_accept;      // current Completion data is being stored
  logic [2:0]  c_tag;
  logic [9:0]  c_lidx;

  logic        hdr_match;
  logic [2:0]  h_tag;
  logic [12:0] h_bc;
  logic [12:0] h_bytes;
  assign h_tag     = cpl_hdr.tag[2:0];
  assign h_bc      = (cpl_hdr.byte_count == 12'd0) ? 13'd4096 : {1'b0, cpl_hdr.byte_count};
  assign h_bytes   = {cpl_payload_dw, 2'b00};
  assign hdr_match = (cpl_hdr.req_id == requester_id) && (cpl_hdr.tag[7:3] == 5'd0) && t_active[h_tag];

  typedef enum logic [2:0] {C_OK, C_UNEXP, C_BAD, C_STATUS} cres_e;
  cres_e cres;
  always_comb begin
    cres = C_OK;
    if (cpl_kind == TK_UNSUP_CPL || !hdr_match)            cres = C_UNEXP;
    else if (cpl_hdr.cpl_status != CPL_SC)                  cres = C_STATUS;
    else if (cpl_kind != TK_CPLD)                           cres = C_BAD;
    else if (h_bc != t_rem[h_tag])                          cres = C_BAD;
    else if (cpl_hdr.lower_addr != t_la[h_tag])             cres = C_BAD;
    else if (h_bytes > t_rem[h_tag])                        cres = C_BAD;
    else if (h_bytes != t_rem[h_tag] && cpl_hdr.lower_addr[5:0] + h_bytes[5:0] != 6'd0)
                                                            cres = C_BAD;  // non-final must end on RCB
  end

  // timeouts (one per cycle is enough; ages are independent)
  logic [7:0] t_expired;
  always_comb begin
    for (int i = 0; i < 8; i++)
      t_expired[i] = t_active[i] && (cpl_timeout != 24'd0) && (t_age[i] >= cpl_timeout);
  end

  assign buf_wr_en   = c_accept && cpl_data_valid;
  assign buf_wr_idx  = c_lidx;
  assign buf_wr_data = bswap32(cpl_data);

  logic hdr_ev;
  assign hdr_ev = cpl_hdr_valid;
  assign ev_unexp_cpl   = hdr_ev && cres == C_UNEXP;
  assign ev_bad_cpl     = hdr_ev && cres == C_BAD;
  assign ev_cpl_status  = hdr_ev && cres == C_STATUS;
  assign ev_cpl_ur      = ev_cpl_status && cpl_hdr.cpl_status == CPL_UR;
  assign ev_cpl_ca      = ev_cpl_status && cpl_hdr.cpl_status == CPL_CA;
  assign ev_cpl_timeout = |t_expired;
  assign ev_tag_alloc   = issue_rd;

  // tag release this cycle (timeout, error or final data) for the event port
  logic       rel_hdr;
  assign rel_hdr     = hdr_ev && (cres == C_BAD || cres == C_STATUS ||
                                  (cres == C_OK && h_bytes == t_rem[h_tag]));
  assign ev_tag_free = rel_hdr || (|t_expired);
  always_comb begin
    ev_tag = 8'(free_tag);
    if (rel_hdr) ev_tag = 8'(h_tag);
    else if (|t_expired) begin
      for (int i = 7; i >= 0; i--) if (t_expired[i]) ev_tag = 8'(i);
    end
  end

  logic job_finish;
  assign job_finish = job_active && (job_left == 0 || job_err) && (wst == W_IDLE) &&
                      (job_dir ? (t_active == 8'h0) : 1'b1);
  assign dma_busy = job_active;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      job_active <= 1'b0; job_dir <= 1'b0; job_ro <= 1'b0; job_ns <= 1'b0; job_err <= 1'b0;
      job_haddr  <= '0;   job_lidx <= '0;  job_left <= '0;
      t_active   <= '0;   tag_ptr <= '0;
      for (int i = 0; i < 8; i++) begin
        t_rem[i] <= '0; t_lidx[i] <= '0; t_la[i] <= '0; t_age[i] <= '0;
      end
      wst <= W_IDLE; w_np <= 1'b0; w_msi <= 1'b0; w_hdr_n <= 3'd3; w_hbeat <= '0;
      w_dw <= '0; w_dbeat <= '0; w_lidx <= '0; w_ro <= 1'b0;
      for (int i = 0; i < 4; i++) w_hdr[i] <= '0;
      c_accept <= 1'b0; c_tag <= '0; c_lidx <= '0;
      msi_pending <= 1'b0;
      dma_done <= 1'b0; dma_err <= 1'b0; msi_sent <= 1'b0; msi_blocked <= 1'b0;
      cpl_err_log <= '0;
    end else if (flush) begin
      if (job_active) begin
        dma_done <= 1'b1;
        dma_err  <= 1'b1;
      end else begin
        dma_done <= 1'b0;
        dma_err  <= 1'b0;
      end
      job_active <= 1'b0; job_err <= 1'b0; job_left <= '0;
      t_active <= '0; wst <= W_IDLE; c_accept <= 1'b0;
      msi_sent <= 1'b0; msi_blocked <= 1'b0;
    end else begin
      dma_done    <= 1'b0;
      dma_err     <= 1'b0;
      msi_sent    <= 1'b0;
      msi_blocked <= 1'b0;

      // ---- job control
      if (dma_start) begin
        if (job_active || !bus_master_en || dma_len == 11'd0 || dma_len > 11'd1024 ||
            ({1'b0, dma_laddr} + dma_len > 11'd1024)) begin
          dma_err  <= 1'b1;
          dma_done <= !job_active;
        end else begin
          job_active <= 1'b1;
          job_dir    <= dma_dir;
          job_ro     <= dma_ro;
          job_ns     <= dma_ns;
          job_err    <= 1'b0;
          job_haddr  <= dma_haddr;
          job_lidx   <= dma_laddr;
          job_left   <= dma_len;
        end
      end else if (job_finish) begin
        job_active <= 1'b0;
        dma_done   <= 1'b1;
        dma_err    <= job_err;
      end

      // ---- MSI doorbell
      if (msi_doorbell) begin
        if (msi_enable && bus_master_en) msi_pending <= 1'b1;
        else                             msi_blocked <= 1'b1;
      end

      // ---- request issue
      if (issue_wr || issue_rd) begin
        w_np    <= issue_rd;
        w_msi   <= 1'b0;
        w_hdr_n <= is64 ? 3'd4 : 3'd3;
        w_hbeat <= '0;
        w_dw    <= issue_rd ? 6'd0 : req_dw;
        w_dbeat <= '0;
        w_lidx  <= job_lidx;
        w_ro    <= job_ro;
        w_hdr[0] <= enc_dw0(issue_rd ? (is64 ? FMT_4DW_ND : FMT_3DW_ND) : (is64 ? FMT_4DW_D : FMT_3DW_D),
                            TYP_MEM, 3'd0, {1'b0, job_ro, job_ns}, 1'b0, 1'b0, 10'(req_dw));
        w_hdr[1] <= enc_req_dw1(requester_id, issue_rd ? {5'd0, free_tag} : 8'd0,
                                (req_dw == 6'd1) ? 4'h0 : 4'hF, 4'hF);
        w_hdr[2] <= is64 ? job_haddr[63:32] : {job_haddr[31:2], 2'b00};
        w_hdr[3] <= {job_haddr[31:2], 2'b00};
        wst      <= W_HDR;
        job_haddr <= job_haddr + 64'({req_dw, 2'b00});
        job_lidx  <= job_lidx + 10'(req_dw);
        job_left  <= job_left - 11'(req_dw);
        if (issue_rd) begin
          t_active[free_tag] <= 1'b1;
          t_rem[free_tag]    <= {5'd0, req_dw, 2'b00};
          t_lidx[free_tag]   <= job_lidx;
          t_la[free_tag]     <= {job_haddr[6:2], 2'b00};
          t_age[free_tag]    <= '0;
          tag_ptr            <= free_tag + 3'd1;
        end
      end else if (issue_msi) begin
        w_np     <= 1'b0;
        w_msi    <= 1'b1;
        w_hdr_n  <= 3'd3;
        w_hbeat  <= '0;
        w_dw     <= 6'd1;
        w_dbeat  <= '0;
        w_ro     <= 1'b0;
        w_hdr[0] <= enc_dw0(FMT_3DW_D, TYP_MEM, 3'd0, 3'd0, 1'b0, 1'b0, 10'd1);
        w_hdr[1] <= enc_req_dw1(requester_id, 8'd0, 4'h0, 4'b0011);
        w_hdr[2] <= {msi_addr[31:2], 2'b00};
        w_hdr[3] <= 32'h0;
        wst      <= W_HDR;
        msi_pending <= 1'b0;
        msi_sent    <= 1'b1;
      end

      case (wst)
        W_HDR: begin
          w_hbeat <= w_hbeat + 1'b1;
          if (w_hbeat == w_hdr_n - 3'd1) wst <= (w_dw == 6'd0) ? W_IDLE : W_DATA;
        end
        W_DATA: begin
          w_dbeat <= w_dbeat + 1'b1;
          w_lidx  <= w_lidx + 1'b1;
          if (w_dbeat == w_dw - 6'd1) wst <= W_IDLE;
        end
        default: ;
      endcase

      // ---- tag ageing and timeout
      for (int i = 0; i < 8; i++) begin
        if (t_active[i] && !(issue_rd && free_tag == 3'(i))) t_age[i] <= t_age[i] + 1'b1;
        if (t_expired[i]) begin
          t_active[i] <= 1'b0;
          job_err     <= 1'b1;
          cpl_err_log <= {1'b0, 3'd0, 4'd4, 8'(i)};
        end
      end

      // ---- Completion intake
      if (cpl_hdr_valid) begin
        c_accept <= (cres == C_OK);
        c_tag    <= h_tag;
        c_lidx   <= t_lidx[h_tag];
        case (cres)
          C_OK: begin
            t_rem[h_tag]  <= t_rem[h_tag] - h_bytes;
            t_lidx[h_tag] <= t_lidx[h_tag] + 10'(cpl_payload_dw);
            t_la[h_tag]   <= t_la[h_tag] + h_bytes[6:0];
            t_age[h_tag]  <= '0;
            if (h_bytes == t_rem[h_tag]) t_active[h_tag] <= 1'b0;
          end
          C_UNEXP: begin
            cpl_err_log <= {1'b0, cpl_hdr.cpl_status, 4'd1, cpl_hdr.tag};
          end
          C_BAD: begin
            t_active[h_tag] <= 1'b0;
            job_err         <= 1'b1;
            cpl_err_log     <= {1'b0, cpl_hdr.cpl_status, 4'd2, cpl_hdr.tag};
          end
          default: begin
            t_active[h_tag] <= 1'b0;
            job_err         <= 1'b1;
            cpl_err_log     <= {1'b0, cpl_hdr.cpl_status, 4'd3, cpl_hdr.tag};
          end
        endcase
      end else if (c_accept && cpl_data_valid) begin
        c_lidx <= c_lidx + 1'b1;
      end
    end
  end
endmodule
