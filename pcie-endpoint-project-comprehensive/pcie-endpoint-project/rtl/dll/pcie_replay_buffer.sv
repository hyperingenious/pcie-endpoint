// Stores transmitted TLP bodies (header+payload DWs) until ACK. Replay walks
// the oldest unacknowledged packet through the newest, in order.
module pcie_replay_buffer
  import pcie_pkg::*;
#(
  parameter int DEPTH  = REPLAY_DEPTH,
  parameter int MAX_DW = MAX_TLP_DW
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic        wr_en,
  input  logic [31:0] wr_data,
  input  logic        wr_sop,
  input  logic        wr_eop,
  input  logic [11:0] wr_seq,
  output logic        full,
  output logic        empty,
  output logic [3:0]  occupancy,

  input  logic        ack_valid,
  input  logic [11:0] ack_seq,

  input  logic        replay_go,
  output logic        replay_active,
  output logic        replay_valid,
  input  logic        replay_ready,
  output logic [31:0] replay_data,
  output logic        replay_sop,
  output logic        replay_eop,
  output logic [11:0] replay_seq
);
  logic [31:0] mem [DEPTH][MAX_DW];
  logic [5:0]  len [DEPTH];
  logic [11:0] seq [DEPTH];
  logic        used [DEPTH];

  logic [2:0]  wr_slot;
  logic [5:0]  wr_idx;
  logic [2:0]  oldest;
  logic [2:0]  rp_slot;
  logic [5:0]  rp_idx;

  function automatic logic seq_acked(input logic [11:0] s, input logic [11:0] a);
    return (a - s) < 12'd2048;
  endfunction

  always_comb begin
    occupancy = 4'd0;
    oldest    = 3'd0;
    empty     = 1'b1;
    for (int i = 0; i < DEPTH; i++) begin
      if (used[i]) begin
        occupancy = occupancy + 4'd1;
        if (empty || ((seq[i] - seq[oldest]) >= 12'd2048)) oldest = 3'(i);
        empty = 1'b0;
      end
    end
    full = (occupancy == 4'(DEPTH));
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_slot <= '0; wr_idx <= '0;
      rp_slot <= '0; rp_idx <= '0;
      replay_active <= 1'b0;
      replay_valid  <= 1'b0;
      replay_data   <= '0;
      replay_sop    <= 1'b0;
      replay_eop    <= 1'b0;
      replay_seq    <= '0;
      for (int i = 0; i < DEPTH; i++) begin
        used[i] <= 1'b0;
        len[i]  <= '0;
        seq[i]  <= '0;
        for (int j = 0; j < MAX_DW; j++) mem[i][j] <= '0;
      end
    end else if (flush) begin
      wr_idx <= '0;
      replay_active <= 1'b0;
      replay_valid  <= 1'b0;
      for (int i = 0; i < DEPTH; i++) used[i] <= 1'b0;
    end else begin
      if (wr_en && !full) begin
        if (wr_sop) begin
          wr_idx <= 6'd1;
          mem[wr_slot][0] <= wr_data;
          seq[wr_slot]    <= wr_seq;
        end else begin
          mem[wr_slot][wr_idx] <= wr_data;
          wr_idx <= wr_idx + 1'b1;
        end
        if (wr_eop) begin
          len[wr_slot]  <= wr_sop ? 6'd1 : (wr_idx + 6'd1);
          used[wr_slot] <= 1'b1;
          wr_slot       <= wr_slot + 1'b1;
          wr_idx        <= '0;
        end
      end

      if (ack_valid) begin
        for (int i = 0; i < DEPTH; i++)
          if (used[i] && seq_acked(seq[i], ack_seq)) used[i] <= 1'b0;
      end

      if (replay_go && !empty) begin
        replay_active <= 1'b1;
        rp_slot       <= oldest;
        rp_idx        <= '0;
        replay_valid  <= 1'b1;
        replay_data   <= mem[oldest][0];
        replay_sop    <= 1'b1;
        replay_eop    <= (len[oldest] == 6'd1);
        replay_seq    <= seq[oldest];
      end else if (replay_active && replay_valid && replay_ready) begin
        if (replay_eop) begin
          logic [2:0] nxt;
          logic       found;
          found = 1'b0;
          nxt   = rp_slot;
          for (int k = 1; k < DEPTH; k++) begin
            logic [2:0] c;
            c = rp_slot + 3'(k);
            if (!found && used[c] && !seq_acked(seq[c], seq[rp_slot])) begin
              found = 1'b1;
              nxt   = c;
            end
          end
          if (found) begin
            rp_slot      <= nxt;
            rp_idx       <= '0;
            replay_data  <= mem[nxt][0];
            replay_sop   <= 1'b1;
            replay_eop   <= (len[nxt] == 6'd1);
            replay_seq   <= seq[nxt];
          end else begin
            replay_active <= 1'b0;
            replay_valid  <= 1'b0;
            replay_sop    <= 1'b0;
            replay_eop    <= 1'b0;
          end
        end else begin
          rp_idx      <= rp_idx + 1'b1;
          replay_data <= mem[rp_slot][rp_idx + 6'd1];
          replay_sop  <= 1'b0;
          replay_eop  <= (rp_idx + 6'd2 == {1'b0, len[rp_slot]});
        end
      end
    end
  end
endmodule
