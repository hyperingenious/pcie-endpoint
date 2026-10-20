// Completion generation for one Non-Posted Request at a time.
//
// Memory Read data is returned in Completions that end on 64-byte Read Completion Boundaries
// (RCB) unless they are the last one, so every Completion carries at most 16 DW (<= MPS).
// Byte Count is the number of bytes still to be returned, including the current Completion;
// Lower Address is the byte address of the first returned byte (first Completion) or the
// RCB-aligned DW address (later Completions). A zero-length read returns one DW, Byte Count 1.
// Configuration Reads return one DW. Status other than SC, and Configuration Writes, return a
// Completion without data.
//
// Before each Completion the generator waits for room in the Completion TX queue, so the
// request handler can keep processing Posted Requests while a long read is pending.
module pcie_completion_gen
  import pcie_pkg::*;
  import pcie_tlp_codec_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        start,
  input  cpl_ctx_t    ctx,
  input  logic [15:0] completer_id,
  output logic        busy,

  output logic        mem_rd_bar,
  output logic [9:0]  mem_rd_idx,
  input  logic [31:0] mem_rd_data,
  output logic [9:0]  cfg_rd_idx,
  input  logic [31:0] cfg_rd_data,

  output logic        q_wr_en,
  output logic [31:0] q_wr_data,
  output logic        q_commit,
  output logic [5:0]  q_commit_count,
  output logic        q_commit_ro,
  input  logic        q_space_ok,

  output logic        cpl_done
);
  typedef enum logic [1:0] {S_IDLE, S_WAIT, S_HDR, S_DATA} state_e;

  state_e      st;
  cpl_ctx_t    c;
  logic [9:0]  dw_idx;
  logic [10:0] rem_dw;
  logic [12:0] rem_bc;
  logic        first;
  logic [4:0]  chunk_dw;
  logic [4:0]  beat;
  logic [1:0]  hdr_beat;

  logic [4:0]  next_chunk;
  logic [4:0]  to_rcb;
  assign to_rcb     = 5'd16 - {1'b0, dw_idx[3:0]};
  assign next_chunk = (c.src == CS_NONE) ? 5'd0 :
                      (c.src == CS_CFG)  ? 5'd1 :
                      ({6'd0, to_rcb} < rem_dw) ? to_rcb : rem_dw[4:0];

  logic [12:0] chunk_bytes;
  assign chunk_bytes = {6'd0, chunk_dw, 2'b00} - ((first && c.lead_bytes_valid) ? {11'd0, c.lead_bytes} : 13'd0);

  logic [6:0]  la;
  assign la = first ? c.lower_addr : {dw_idx[4:0], 2'b00};

  logic [31:0] hdr_dw [3];
  assign hdr_dw[0] = enc_dw0((c.src == CS_NONE) ? FMT_3DW_ND : FMT_3DW_D, TYP_CPL, c.tc,
                             {1'b0, c.attr}, 1'b0, 1'b0, 10'(chunk_dw));
  assign hdr_dw[1] = enc_cpl_dw1(completer_id, c.status, rem_bc[11:0]);
  assign hdr_dw[2] = enc_cpl_dw2(c.req_id, c.tag, la);

  assign busy       = (st != S_IDLE);
  assign mem_rd_bar = c.bar;
  assign mem_rd_idx = dw_idx;
  assign cfg_rd_idx = c.addr[11:2];

  always_comb begin
    q_wr_en        = 1'b0;
    q_wr_data      = 32'h0;
    q_commit       = 1'b0;
    q_commit_count = 6'd3 + {1'b0, chunk_dw};
    q_commit_ro    = c.attr[1];
    if (st == S_HDR) begin
      q_wr_en   = 1'b1;
      q_wr_data = hdr_dw[hdr_beat];
      q_commit  = (hdr_beat == 2'd2) && (chunk_dw == 5'd0);
    end else if (st == S_DATA) begin
      q_wr_en   = 1'b1;
      q_wr_data = bswap32((c.src == CS_CFG) ? cfg_rd_data : mem_rd_data);
      q_commit  = (beat == chunk_dw - 5'd1);
    end
  end

  assign cpl_done = q_commit && (rem_dw == {6'd0, chunk_dw});

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st       <= S_IDLE;
      c        <= '0;
      dw_idx   <= '0;
      rem_dw   <= '0;
      rem_bc   <= '0;
      first    <= 1'b0;
      chunk_dw <= '0;
      beat     <= '0;
      hdr_beat <= '0;
    end else if (flush) begin
      st <= S_IDLE;
    end else begin
      case (st)
        S_IDLE: if (start) begin
          c      <= ctx;
          dw_idx <= ctx.addr[11:2];
          rem_dw <= (ctx.src == CS_NONE) ? 11'd0 : (ctx.src == CS_CFG) ? 11'd1 : ctx.len_dw;
          rem_bc <= ctx.byte_count;
          first  <= 1'b1;
          st     <= S_WAIT;
        end
        S_WAIT: if (q_space_ok) begin
          chunk_dw <= next_chunk;
          hdr_beat <= 2'd0;
          beat     <= 5'd0;
          st       <= S_HDR;
        end
        S_HDR: begin
          hdr_beat <= hdr_beat + 1'b1;
          if (hdr_beat == 2'd2) begin
            if (chunk_dw == 5'd0) st <= S_IDLE;
            else                  st <= S_DATA;
          end
        end
        S_DATA: begin
          beat   <= beat + 1'b1;
          dw_idx <= dw_idx + 1'b1;
          if (beat == chunk_dw - 5'd1) begin
            rem_dw <= rem_dw - {6'd0, chunk_dw};
            rem_bc <= rem_bc - chunk_bytes;
            first  <= 1'b0;
            st     <= (rem_dw == {6'd0, chunk_dw}) ? S_IDLE : S_WAIT;
          end
        end
        default: st <= S_IDLE;
      endcase
    end
  end
endmodule
