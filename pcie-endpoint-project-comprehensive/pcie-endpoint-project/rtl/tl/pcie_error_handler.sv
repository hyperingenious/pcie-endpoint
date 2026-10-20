// Error collection. Each event pulse latches a sticky flag (REG_ERR_STATUS, RW1C) and
// sets the matching Configuration Space status bits.
//
// Severity mapping (default PCIe severities, no AER):
//   Correctable  -> Device Status CED : Bad LCRC/sequence (Bad TLP), Bad DLLP,
//                                        REPLAY_NUM rollover, replay timer timeout
//   Non-fatal    -> Device Status NFED: Poisoned TLP received, Unsupported Request,
//                                        Completion timeout, Unexpected Completion,
//                                        unsuccessful Completion status
//   Fatal        -> Device Status FED : Malformed TLP, receiver overflow, FC protocol
//                                        error, DLL protocol error, malformed Completion
//   Unsupported Request also sets Device Status URD.
//   Poisoned TLP received sets Status.Detected Parity Error; a poisoned Completion for an
//   Endpoint request additionally sets Master Data Parity Error when Parity Error Response
//   is enabled. Completion status UR/CA sets Received Master/Target Abort.
module pcie_error_handler
  import pcie_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,
  input  logic [NUM_ERR-1:0] err_event,
  input  logic [NUM_ERR-1:0] err_clear,
  input  logic               poisoned_cpl,
  input  logic               cpl_status_ur,
  input  logic               cpl_status_ca,
  input  logic               parity_err_resp,
  output logic [NUM_ERR-1:0] err_status,
  output logic               set_ced,
  output logic               set_nfed,
  output logic               set_fed,
  output logic               set_urd,
  output logic               set_detected_parity,
  output logic               set_master_data_parity,
  output logic               set_rcvd_master_abort,
  output logic               set_rcvd_target_abort
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) err_status <= '0;
    else        err_status <= (err_status & ~err_clear) | err_event;
  end

  assign set_ced  = err_event[ERR_BAD_LCRC] | err_event[ERR_BAD_DLLP] |
                    err_event[ERR_REPLAY_ROLL] | err_event[ERR_REPLAY_TMO];
  assign set_nfed = err_event[ERR_POISONED] | err_event[ERR_UR] | err_event[ERR_CPL_TIMEOUT] |
                    err_event[ERR_UNEXP_CPL] | err_event[ERR_CPL_STATUS];
  assign set_fed  = err_event[ERR_MALFORMED] | err_event[ERR_RX_OVERFLOW] |
                    err_event[ERR_FC_PROTOCOL] | err_event[ERR_DLLP_PROTO] | err_event[ERR_BAD_CPL];
  assign set_urd  = err_event[ERR_UR];
  assign set_detected_parity    = err_event[ERR_POISONED];
  assign set_master_data_parity = poisoned_cpl && parity_err_resp;
  assign set_rcvd_master_abort  = cpl_status_ur;
  assign set_rcvd_target_abort  = cpl_status_ca;
endmodule
