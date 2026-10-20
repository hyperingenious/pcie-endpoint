# Functional and Code Coverage Plan

## 1. Principles

Coverage is sampled from observed accepted packets, observed responses, and actual state transitions. Sequence intent alone is not coverage. Coverage goals apply to implemented features and must include documented exclusions with technical justification.

## 2. Transaction Layer covergroups

### Packet format and type
- Supported Fmt encodings.
- Supported Type encodings.
- Header size: 3-DW/4-DW where applicable.
- Payload present/absent.
- Supported request classes: Memory Read, Memory Write, Configuration Read/Write, Completion, and any implemented Message/Atomic operation.
- Unsupported/malformed categories in negative coverage.

### Address and BAR
- Every implemented BAR/region.
- First/last legal DWORD and selected interior locations.
- Boundary crossing, alignment, unmapped address, and out-of-range access.
- Operation type × address region.

### Length and byte enables
- Minimum, typical, maximum supported, and invalid lengths.
- Single-DWORD and multi-DWORD transactions.
- First DW BE and Last DW BE legal patterns for each supported request length class.
- Full, sparse, leading/trailing, and zero-enable cases where legal.
- Length × request type; byte-enable class × write type; length × boundary condition.

### Completion
- Completion with/without Data as applicable.
- Success and each implemented unsuccessful status.
- Tag, Requester ID, Completer ID matching classes.
- Byte Count and Lower Address boundary classes.
- Completion payload length and split-completion index if supported.
- Request type × Completion status; length × Completion form.

### Configuration
- Each implemented register and field class: writable, read-only, reserved, W1C/special semantics if present.
- Read/write operation × register class.
- Capability structure × access type.
- Reset value observation and write mask behavior.

### Requester/outstanding traffic
- Active outstanding request count: zero, one, intermediate, configured maximum.
- Tag allocation/release and wrap/reuse boundary.
- Completion arrival order: in-order and permitted out-of-order.
- Completion size/count progression for split Completion support.
- Timeout, unexpected, duplicate, and mismatched Completion cases.

### Errors/reset/backpressure
- Each implemented error category.
- Reset from idle, request reception, response transmission, outstanding requester state, replay, and flow-control initialization.
- Stall duration classes: none, short, medium, long/boundary.
- Stall × request type and stall × response type.
- Error category × packet type; reset state × outstanding work.

## 3. Data Link covergroups

- DLL state transitions and link-up/down.
- DLLP type, valid/corrupt, and control outcome.
- Sequence number: initial, normal increment, wraparound, mismatch, duplicate.
- LCRC: valid, injected corruption, boundary vectors.
- ACK/NAK: normal acknowledgement, negative acknowledgement, delayed/lost acknowledgement, acknowledgement of outstanding buffered TLPs.
- Replay: no replay, single replay, repeated replay, timer expiry, buffer boundary/full condition, reset during replay.
- Flow control: initialization states, credit class, available/consumed/returned credit buckets, exhausted/replenished, invalid update.
- Crosses: packet integrity outcome × ACK/NAK outcome; replay cause × buffer occupancy; credit state × packet class; link state × TLP transmission attempt.

## 4. Behavioral Physical Layer/link-model coverage

- Link state: down, initializing, active, retraining/recovery, failed, as implemented.
- Packet delivery outcome: normal, delayed, blocked, dropped, corrupted, duplicated (in fault tests only).
- Error injection point × packet class.
- Link event × outstanding request/replay state.
- Successful link recovery and failure-to-recover scenarios for the modelled subset.

## 5. Code and assertion coverage

Collect statement/branch/toggle/FSM coverage supported by the simulator. Assertion coverage must show required properties were enabled and exercised. For critical assertions, add checker-negative tests to validate detection. Do not equate assertion pass count with full assertion coverage.

## 6. Cross-coverage controls

- Define legal bins from the supported feature contract.
- Use `ignore_bins` only for combinations proven illegal or not part of the supported subset, and document the reason.
- Avoid exploding unhelpful Cartesian products; select crosses tied to protocol risks.
- Do not exclude a bin solely because it is difficult to hit.
- Review uncovered bins and determine whether the cause is missing stimulus, unreachable behavior, a design defect, an overbroad bin, or a justified exclusion.

## 7. Goals

Target at least 95% of applicable functional coverage, above 95% statement, above 90% branch and toggle, and 100% of defined legal FSM states/transitions. These are goals, not guarantees. Any exclusions or shortfalls must be reported; metrics must come from actual simulation databases.
