module pcie_replay_timer
  import pcie_pkg::*;
#(
  parameter int TIMEOUT = REPLAY_TIMEOUT
) (
  input  logic clk,
  input  logic rst_n,
  input  logic dl_active,
  input  logic unacked_pending,
  input  logic restart,
  output logic timeout
);
  logic [15:0] ctr;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctr     <= '0;
      timeout <= 1'b0;
    end else if (!dl_active) begin
      ctr     <= '0;
      timeout <= 1'b0;
    end else if (restart || !unacked_pending) begin
      ctr     <= '0;
      timeout <= 1'b0;
    end else begin
      ctr     <= ctr + 1'b1;
      timeout <= (ctr >= 16'(TIMEOUT));
    end
  end
endmodule
