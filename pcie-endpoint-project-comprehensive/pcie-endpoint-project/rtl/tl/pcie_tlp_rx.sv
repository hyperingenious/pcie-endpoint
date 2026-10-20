// Receive-side TLP buffering between the Data Link Layer and Transaction Layer processing.
//
// Three queues (Posted, Non-Posted, Completion) are written speculatively by pcie_dll_rx and
// committed only after the LCRC and sequence checks pass; abort rolls the write pointer back,
// so a TLP rejected by the Data Link Layer never becomes visible here.
//
// Each committed packet gets a descriptor {DW count, posted stamp, RO}. The posted stamp is the
// number of Posted TLPs committed before it, which pcie_ordering_ctrl uses to keep Non-Posted
// Requests and Completions behind earlier Posted Requests.
module pcie_rx_queue #(
  parameter int DEPTH      = 256,
  parameter int DESC_DEPTH = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        wr_en,
  input  logic [31:0] wr_data,
  input  logic        commit,
  input  logic        abort,
  input  logic [5:0]  commit_count,
  input  logic [15:0] commit_stamp,
  input  logic        commit_ro,
  output logic        space_ok,
  output logic        avail,
  output logic [5:0]  head_count,
  output logic [15:0] head_stamp,
  output logic        head_ro,
  input  logic        rd_en,
  output logic [31:0] rd_data,
  input  logic        pop
);
  localparam int AW = $clog2(DEPTH);
  localparam int DW_ = $clog2(DESC_DEPTH);

  logic [31:0]    mem [DEPTH];
  logic [AW:0]    wr_spec, wr_commit, rd_ptr;
  logic [5:0]     d_count [DESC_DEPTH];
  logic [15:0]    d_stamp [DESC_DEPTH];
  logic           d_ro    [DESC_DEPTH];
  logic [DW_:0]   d_wr, d_rd;
  logic [AW:0]    used;

  assign used       = wr_spec - rd_ptr;
  assign space_ok   = (used <= (AW+1)'(DEPTH - pcie_pkg::MAX_TLP_DW)) &&
                      ((d_wr - d_rd) < (DW_+1)'(DESC_DEPTH));
  assign avail      = (d_wr != d_rd);
  assign head_count = d_count[d_rd[DW_-1:0]];
  assign head_stamp = d_stamp[d_rd[DW_-1:0]];
  assign head_ro    = d_ro[d_rd[DW_-1:0]];
  assign rd_data    = mem[rd_ptr[AW-1:0]];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_spec   <= '0;
      wr_commit <= '0;
      rd_ptr    <= '0;
      d_wr      <= '0;
      d_rd      <= '0;
      for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
      for (int i = 0; i < DESC_DEPTH; i++) begin
        d_count[i] <= '0;
        d_stamp[i] <= '0;
        d_ro[i]    <= 1'b0;
      end
    end else if (flush) begin
      wr_spec   <= '0;
      wr_commit <= '0;
      rd_ptr    <= '0;
      d_wr      <= '0;
      d_rd      <= '0;
    end else begin
      if (wr_en) begin
        mem[wr_spec[AW-1:0]] <= wr_data;
        wr_spec <= wr_spec + 1'b1;
      end
      if (commit) begin
        wr_commit <= wr_spec;
        d_count[d_wr[DW_-1:0]] <= commit_count;
        d_stamp[d_wr[DW_-1:0]] <= commit_stamp;
        d_ro[d_wr[DW_-1:0]]    <= commit_ro;
        d_wr <= d_wr + 1'b1;
      end else if (abort) begin
        wr_spec <= wr_commit;
      end
      if (rd_en) rd_ptr <= rd_ptr + 1'b1;
      if (pop)   d_rd   <= d_rd + 1'b1;
    end
  end
endmodule

module pcie_tlp_rx
  import pcie_pkg::*;
#(
  parameter int P_DEPTH    = 256,
  parameter int NP_DEPTH   = 128,
  parameter int CPL_DEPTH  = 256,
  parameter int DESC_DEPTH = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        wr_valid,
  input  logic        wr_first,
  input  logic [31:0] wr_data,
  input  logic        commit,
  input  logic        abort,
  output logic        space_ok,

  output logic [2:0]  pkt_avail,
  output logic [5:0]  head_count [3],
  output logic [15:0] head_stamp [3],
  output logic [2:0]  head_ro,
  output logic [15:0] p_consumed,
  input  logic        rd_en,
  input  fc_class_e   rd_q,
  output logic [31:0] rd_data,
  input  logic        pop
);
  fc_class_e   cur_q;
  fc_class_e   first_q;
  logic [5:0]  cur_count;
  logic        cur_ro;
  logic [15:0] p_committed;
  logic [2:0]  q_space;
  logic [31:0] q_rd_data [3];

  assign first_q  = fc_class_of(wr_data[31:29], wr_data[28:24]);
  assign space_ok = q_space[first_q];
  assign rd_data  = q_rd_data[rd_q];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_q       <= FC_P;
      cur_count   <= '0;
      cur_ro      <= 1'b0;
      p_committed <= '0;
      p_consumed  <= '0;
    end else if (flush) begin
      cur_count   <= '0;
      p_committed <= '0;
      p_consumed  <= '0;
    end else begin
      if (wr_valid && wr_first) begin
        cur_q     <= first_q;
        cur_ro    <= wr_data[13];
        cur_count <= 6'd1;
      end else if (wr_valid) begin
        cur_count <= cur_count + 1'b1;
      end
      if (commit && cur_q == FC_P) p_committed <= p_committed + 1'b1;
      if (pop && rd_q == FC_P)     p_consumed  <= p_consumed + 1'b1;
    end
  end

  for (genvar q = 0; q < 3; q++) begin : g_q
    localparam int D = (q == 0) ? P_DEPTH : (q == 1) ? NP_DEPTH : CPL_DEPTH;
    logic this_wr;
    assign this_wr = wr_valid && (wr_first ? (first_q == fc_class_e'(q)) : (cur_q == fc_class_e'(q)));

    pcie_rx_queue #(.DEPTH(D), .DESC_DEPTH(DESC_DEPTH)) u_q (
      .clk, .rst_n, .flush,
      .wr_en        (this_wr),
      .wr_data,
      .commit       (commit && cur_q == fc_class_e'(q)),
      .abort        (abort && cur_q == fc_class_e'(q)),
      .commit_count (cur_count),
      .commit_stamp (p_committed),
      .commit_ro    (cur_ro),
      .space_ok     (q_space[q]),
      .avail        (pkt_avail[q]),
      .head_count   (head_count[q]),
      .head_stamp   (head_stamp[q]),
      .head_ro      (head_ro[q]),
      .rd_en        (rd_en && rd_q == fc_class_e'(q)),
      .rd_data      (q_rd_data[q]),
      .pop          (pop && rd_q == fc_class_e'(q))
    );
  end
endmodule
