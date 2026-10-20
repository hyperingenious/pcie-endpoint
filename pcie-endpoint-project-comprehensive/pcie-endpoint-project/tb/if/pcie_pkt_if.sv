// Packet-level link port interface (project abstraction, not PIPE).
//
// Contract (docs/architecture.md section 5):
//  * Single clock; rst_n is asynchronous assert, synchronous deassert, active low.
//  * A beat transfers on a rising clock edge when valid && ready.
//  * While valid && !ready, sop/eop/data hold their values.
//  * TLP beats of one packet are contiguous: sop on the sequence beat, eop on the LCRC beat.
//  * DLLPs use a separate channel, one 48-bit DLLP per beat.
//  * phy_link_up is 1 in L0 and Recovery; phy_recovery is 1 in Recovery.
//  * On link-down or reset, in-flight beats are discarded and valid may drop without ready.
//
// "tx" signals are driven by the port owner (DUT or Root Complex driver); "rx" signals and
// tx_ready are driven by the behavioral link model.
interface pcie_pkt_if (input logic clk, input logic rst_n);

  logic        tlp_tx_valid;
  logic        tlp_tx_ready;
  logic        tlp_tx_sop;
  logic        tlp_tx_eop;
  logic [31:0] tlp_tx_data;

  logic        tlp_rx_valid;
  logic        tlp_rx_ready;
  logic        tlp_rx_sop;
  logic        tlp_rx_eop;
  logic [31:0] tlp_rx_data;

  logic        dllp_tx_valid;
  logic        dllp_tx_ready;
  logic [47:0] dllp_tx_data;

  logic        dllp_rx_valid;
  logic        dllp_rx_ready;
  logic [47:0] dllp_rx_data;

  logic        phy_link_up;
  logic        phy_recovery;
  logic        dl_retrain_req;
  logic [1:0]  dll_state_dbg;
  logic [2:0]  ltssm_state_dbg;

  modport port (
    input  clk, rst_n,
    output tlp_tx_valid, tlp_tx_sop, tlp_tx_eop, tlp_tx_data, input tlp_tx_ready,
    input  tlp_rx_valid, tlp_rx_sop, tlp_rx_eop, tlp_rx_data, output tlp_rx_ready,
    output dllp_tx_valid, dllp_tx_data, input dllp_tx_ready,
    input  dllp_rx_valid, dllp_rx_data, output dllp_rx_ready,
    input  phy_link_up, phy_recovery, ltssm_state_dbg,
    output dl_retrain_req, dll_state_dbg
  );

  modport link (
    input  clk, rst_n,
    input  tlp_tx_valid, tlp_tx_sop, tlp_tx_eop, tlp_tx_data, output tlp_tx_ready,
    output tlp_rx_valid, tlp_rx_sop, tlp_rx_eop, tlp_rx_data, input tlp_rx_ready,
    input  dllp_tx_valid, dllp_tx_data, output dllp_tx_ready,
    output dllp_rx_valid, dllp_rx_data, input dllp_rx_ready,
    output phy_link_up, phy_recovery, ltssm_state_dbg,
    input  dl_retrain_req, dll_state_dbg
  );

  modport mon (
    input clk, rst_n,
    input tlp_tx_valid, tlp_tx_ready, tlp_tx_sop, tlp_tx_eop, tlp_tx_data,
    input tlp_rx_valid, tlp_rx_ready, tlp_rx_sop, tlp_rx_eop, tlp_rx_data,
    input dllp_tx_valid, dllp_tx_ready, dllp_tx_data,
    input dllp_rx_valid, dllp_rx_ready, dllp_rx_data,
    input phy_link_up, phy_recovery, dl_retrain_req, dll_state_dbg, ltssm_state_dbg
  );

endinterface
