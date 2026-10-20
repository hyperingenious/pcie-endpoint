// Schedules ACK (after ACK_LATENCY cycles of a good/duplicate TLP) or NAK
// (immediately on LCRC/sequence error). NAK has priority.
module pcie_ack_nak_ctrl
  import pcie_pkg::*;
#(
  parameter int LATENCY = ACK_LATENCY
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        dl_active,
  input  logic        rx_ok,
  input  logic        rx_dup,
  input  logic        rx_bad,
  input  logic [11:0] rx_seq,
  input  logic [11:0] rx_expected,
  output logic        ack_req,
  output logic [11:0] ack_seq,
  input  logic        ack_gnt,
  output logic        nak_req,
  output logic [11:0] nak_seq,
  input  logic        nak_gnt
);
  logic [3:0]  lat;
  logic        pend_ack;
  logic [11:0] pend_seq;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lat      <= '0;
      pend_ack <= 1'b0;
      pend_seq <= '0;
      ack_req  <= 1'b0;
      nak_req  <= 1'b0;
      ack_seq  <= '0;
      nak_seq  <= '0;
    end else if (!dl_active) begin
      lat      <= '0;
      pend_ack <= 1'b0;
      ack_req  <= 1'b0;
      nak_req  <= 1'b0;
    end else begin
      if (rx_bad) begin
        nak_req  <= 1'b1;
        nak_seq  <= (rx_expected == 12'd0) ? 12'd4095 : (rx_expected - 12'd1);
        pend_ack <= 1'b0;
        lat      <= '0;
        ack_req  <= 1'b0;
      end else if (nak_req && nak_gnt) begin
        nak_req <= 1'b0;
      end

      if (rx_ok || rx_dup) begin
        pend_ack <= 1'b1;
        pend_seq <= rx_seq;
        lat      <= 4'(LATENCY);
      end else if (pend_ack && lat != 0) begin
        lat <= lat - 1'b1;
      end else if (pend_ack && lat == 0) begin
        ack_req <= 1'b1;
        ack_seq <= pend_seq;
        pend_ack <= 1'b0;
      end
      if (ack_req && ack_gnt) ack_req <= 1'b0;
    end
  end
endmodule
