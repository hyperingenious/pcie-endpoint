// Controls and status of the behavioral link model. Verification-only: none of these
// signals exist on the synthesizable Endpoint.
interface pcie_link_ctrl_if (input logic clk, input logic rst_n);

  // Link state controls
  logic        partner_present;     // remote partner detected; Detect -> Polling
  logic        force_link_down;     // hold the link in Detect while 1
  logic        force_recovery;      // request Recovery from L0 (level, sampled in L0)
  logic        recovery_fail;       // Recovery exits to Failed instead of L0
  logic [7:0]  latency;             // cycles a packet stays in the link before delivery

  // Backpressure toward senders (tx_ready held low while 1)
  logic        stall_rc_to_ep;      // Root Complex TLP sender
  logic        stall_ep_to_rc;      // Endpoint TLP sender

  // Packet fault injection: arm with a one-cycle pulse on fault_arm
  logic        fault_arm;
  logic [1:0]  fault_dir;           // 0 TLP RC->EP, 1 TLP EP->RC, 2 DLLP RC->EP, 3 DLLP EP->RC
  logic [2:0]  fault_kind;          // 1 drop, 2 corrupt, 3 duplicate, 4 delay
  logic [7:0]  fault_skip;          // packets to pass unharmed before the faulted one
  logic [7:0]  fault_delay;         // extra cycles for the delay fault
  logic [31:0] fault_seed;          // test seed, recorded in every fault log line

  // Status from the model
  logic        fault_pending;
  logic [15:0] fault_count;
  logic [15:0] dropped_not_l0;      // packets discarded because the link was not in L0
  logic [2:0]  ltssm_state;

  modport tb (
    input  clk, rst_n,
    output partner_present, force_link_down, force_recovery, recovery_fail, latency,
    output stall_rc_to_ep, stall_ep_to_rc,
    output fault_arm, fault_dir, fault_kind, fault_skip, fault_delay, fault_seed,
    input  fault_pending, fault_count, dropped_not_l0, ltssm_state
  );

  modport model (
    input  clk, rst_n,
    input  partner_present, force_link_down, force_recovery, recovery_fail, latency,
    input  stall_rc_to_ep, stall_ep_to_rc,
    input  fault_arm, fault_dir, fault_kind, fault_skip, fault_delay, fault_seed,
    output fault_pending, fault_count, dropped_not_l0, ltssm_state
  );

endinterface
