module pcie_dll_state
  import pcie_pkg::*;
(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       phy_link_up,
  input  logic       phy_recovery,
  input  logic       fc_init_done,
  output dl_state_e  state,
  output logic       dl_active,
  output logic       flush
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= DL_INACTIVE;
    else if (!phy_link_up)
      state <= DL_INACTIVE;
    else if (phy_recovery && state == DL_ACTIVE)
      state <= DL_INACTIVE;
    else begin
      case (state)
        DL_INACTIVE: if (phy_link_up) state <= DL_INIT;
        DL_INIT:     if (fc_init_done) state <= DL_ACTIVE;
        DL_ACTIVE:   if (!phy_link_up || phy_recovery) state <= DL_INACTIVE;
        default:     state <= DL_INACTIVE;
      endcase
    end
  end

  assign dl_active = (state == DL_ACTIVE);
  assign flush     = !rst_n || !phy_link_up || (state != DL_ACTIVE && phy_recovery);
endmodule
