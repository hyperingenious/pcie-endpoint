// Behavioral LTSSM subset: Detect, Polling, Configuration, L0, Recovery, Failed.
// Not Gen4 equalization or speed negotiation.
module pcie_ltssm_model
  import pcie_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  logic         partner_present,
  input  logic         force_link_down,
  input  logic         force_recovery,
  input  logic         recovery_fail,
  output ltssm_state_e state,
  output logic         link_up,
  output logic         recovery
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= LT_DETECT;
    else if (force_link_down)
      state <= LT_DETECT;
    else unique case (state)
      LT_DETECT:  if (partner_present) state <= LT_POLLING;
      LT_POLLING: state <= LT_CONFIG;
      LT_CONFIG:  state <= LT_L0;
      LT_L0:      if (force_recovery) state <= LT_RECOVERY;
      LT_RECOVERY: state <= recovery_fail ? LT_FAILED : LT_L0;
      LT_FAILED:  if (partner_present) state <= LT_DETECT;
      default:    state <= LT_DETECT;
    endcase
  end
  assign link_up  = (state == LT_L0) || (state == LT_RECOVERY);
  assign recovery = (state == LT_RECOVERY);
endmodule
