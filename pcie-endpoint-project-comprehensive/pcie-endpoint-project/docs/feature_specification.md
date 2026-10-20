# Feature Specification and Layer-by-Layer Scope

## 1. Specification baseline and implementation policy

Baseline: *PCI Express Base Specification, Revision 4.0, Version 1.0*, supplied with the project. Each requirement must be tied to the relevant specification section in `specification_traceability.md` after the exact rule has been reviewed. The inventory below is a project requirements checklist, not a claim that all items are already implemented.

For every feature, record one status: `planned`, `implemented`, `verified`, `partially_verified`, `not_supported`, or `waived`. Do not label the Endpoint fully PCIe-compliant unless the applicable requirements and interoperability obligations are met.

## 2. Transaction Layer

### 2.1 Packet formats and common header
- Decode supported `Fmt` and `Type` encodings.
- Support the required 3-DW and 4-DW header forms for selected requests.
- Decode Length, Requester ID, Tag, First DW BE, Last DW BE, Traffic Class, Attributes, and address/register fields as applicable.
- Handle payload presence/absence consistently with the supported packet type.
- Validate reserved fields and unsupported encodings according to the selected error policy.
- Support packing/unpacking tests against independent reference vectors.
- Implement TLP Digest/ECRC only if enabled in the feature configuration; distinguish ECRC from Data Link LCRC.
- TLP Prefixes and optional extensions are explicitly supported or rejected/documented, not silently ignored.

### 2.2 Request types
- Memory Read Request.
- Memory Write Request.
- Configuration Type 0 Read/Write requests applicable to the modeled Endpoint.
- Configuration Type 1 handling only if required by the chosen topology/model; an Endpoint must not claim unsupported routing behavior.
- I/O requests: explicitly unsupported unless a justified implementation is added.
- Message requests: selected supported Message types only if implemented.
- Atomic operations: unsupported unless individually specified and tested.
- Locked transactions and other optional request types: explicitly unsupported unless included.

### 2.3 Memory transaction behavior
- Address decode through implemented BAR regions.
- Read data from mapped storage/registers.
- Write payload handling for supported lengths.
- Correct First/Last DW Byte Enable interpretation and byte-lane updates.
- Boundary checks for address range, alignment, request length, and enabled byte lanes.
- Defined behavior for unmapped address, unsupported request, invalid length, and malformed header.
- Correct Completion-with-Data generation for successful Memory Reads.
- Memory Writes normally do not produce a Completion; verify this behavior for the supported request class.
- No unintended state modification after rejected requests.

### 2.4 Completion behavior
- Completion without Data and Completion with Data handling as applicable.
- Correct Completer ID, Requester ID, Tag, Completion Status, Byte Count, Lower Address, and payload.
- Successful Completion and supported unsuccessful statuses.
- Completion association and duplicate/missing response detection.
- Multiple Completion TLPs for one request if split Completion support is implemented.
- Maximum payload/read request constraints and boundary cases for the selected subset.
- Unexpected Completion, mismatched Tag, malformed Completion, and Completion timeout handling in the requester model where applicable.

### 2.5 Configuration space and capabilities
- Configuration header fields: Vendor ID, Device ID, Command, Status, Revision ID, Class Code, Header Type, and BIST/other fields only as supported.
- BAR registers with documented size/type/address behavior and address decoding.
- Reset values and writable/read-only/reserved semantics for every implemented register field.
- Configuration Read/Write request decoding and response construction.
- Capability-list pointer and implemented capability structures.
- PCI Express Capability fields relevant to the modeled Endpoint, with unsupported fields documented.
- MSI and/or MSI-X only if implemented; include capability registers, enable/mask behavior, and generated interrupt write/message behavior according to the chosen model.
- Power Management capability only if implemented; define supported states and side effects.
- AER, Device Serial Number, LTR, ATS, SR-IOV, Resizable BAR, and other optional capabilities are explicitly out of scope unless separately added with complete requirements and tests.

### 2.6 Ordering and flow-control interaction
- Define the supported Traffic Classes and Virtual Channels.
- Implement the ordering rules applicable to supported request types and attributes.
- Define behavior for Relaxed Ordering and ID-Based Ordering attributes; do not ignore these silently if they are accepted.
- Handle posted versus non-posted request behavior appropriately.
- Coordinate transaction transmission with available Data Link/receive credits in the implemented architecture.
- Unsupported TC/VC mappings and attributes must be rejected or handled according to the documented policy.

### 2.7 Requester functionality
If Endpoint-originated requests are included:
- Generate Memory Read/Write requests to the Root Complex model.
- Allocate, track, and release Tags.
- Limit outstanding requests to configured capacity and applicable constraints.
- Match Completions by Requester ID/Tag and validate Byte Count/Lower Address progression.
- Support permitted Completion reordering.
- Handle split Completions if enabled.
- Detect timeout, unexpected, duplicate, malformed, and unsuccessful Completions.
- Verify reset/abort handling for outstanding requests.

### 2.8 Error handling and reporting
- Unsupported request type/format.
- Malformed TLP/header/length/byte enables.
- Unmapped BAR/address and illegal access.
- Unsupported or invalid configuration access.
- Unexpected/malformed Completion.
- Completion timeout where requester behavior is modeled.
- Data integrity errors and replay events from Data Link Layer.
- Defined error log/status side effects for implemented reporting registers.
- Negative tests verify detection without corrupting unrelated state.

### 2.9 Virtual Channels, Traffic Class, and advanced transactions
- Support a defined TC/VC subset and mapping.
- Test ordering across supported classes and behavior for unsupported mappings.
- TLP Prefixes, AtomicOps, ID-based ordering, relaxed ordering, and other advanced transaction features are individually enumerated as supported or unsupported.
- End-to-End CRC/ECRC behavior is separately specified from Data Link LCRC.

## 3. Data Link Layer

### 3.1 Link control and management state
- Model Data Link inactive/initializing/active states required by the implementation.
- Exchange link status with the behavioral link/PHY model.
- Gate normal TLP processing when Data Link is not active.
- Reset sequence counters, retry state, and flow-control initialization as required.
- Define behavior on link-down, reset, retraining notification, and recovery.

### 3.2 DLLPs
- Define common DLLP packet format and integrity protection.
- Encode/decode the DLLP types actually supported.
- Implement ACK and NAK DLLPs.
- Implement Flow Control initialization/update DLLPs for supported credit types/Virtual Channels.
- Include power-management or other DLLPs only if in selected scope.
- Detect/discard corrupt DLLPs and verify recovery/forward progress.

### 3.3 TLP sequence and integrity
- Assign transmit sequence numbers according to the specified sequence space.
- Validate receive sequence numbers.
- Generate and check TLP LCRC.
- Verify CRC implementation with independent known-answer/reference vectors.
- Handle sequence wraparound and boundaries.
- Detect corrupted, duplicated, missing, or out-of-sequence packets as applicable.
- Keep Data Link LCRC distinct from optional Transaction Layer ECRC.

### 3.4 Retry/replay
- Store transmitted TLPs until positively acknowledged.
- Advance acknowledgement state and release acknowledged retry-buffer entries.
- Generate replay on NAK or replay timeout.
- Replay the required buffered TLP sequence in order.
- Prevent duplicate delivery to the Transaction Layer where the protocol requires suppression.
- Handle retry-buffer full/empty and boundary conditions.
- Count retries and detect retry-limit/link-failure conditions as specified for the chosen model.
- Test ACK during outstanding traffic, NAK, lost ACK, corrupted TLP, timeout, replay progress, and link reset during replay.

### 3.5 Flow control
- Model initial credit advertisement and initialization completion for implemented credit classes.
- Track Header and Data credits for supported posted, non-posted, and Completion traffic, and supported VC(s).
- Account for TLP consumption and credit return correctly.
- Prevent transmission when insufficient credits are available.
- Test credit exhaustion, replenishment, wrap/update behavior, initialization, reset, and malformed credit updates.
- Document all buffer sizes, credit scaling, and omitted VC/TC cases.

### 3.6 Data Link errors and status
- CRC error detection.
- Sequence mismatch and NAK scheduling behavior.
- ACK/NAK latency behavior to the degree modeled.
- Replay timer behavior and timeout boundary tests.
- Link status propagation and reset behavior.
- Correct interaction with Transaction Layer backpressure and packet delivery.

## 4. Physical Layer and link model

### 4.1 Behavioral link transport
- Deliver packet objects or framed beats between link partners.
- Model latency, valid/ready backpressure, and finite buffering if applicable.
- Inject packet loss, corruption, duplication, delay, and link-down events for verification.
- Preserve ordering in normal delivery and explicitly model fault cases.
- Provide deterministic random seeds and event logging.

### 4.2 Logical link-state model
- Represent link-up/down and retraining notifications.
- If LTSSM behavior is implemented, define the exact subset of states/transitions and associated entry/exit conditions.
- Test link initialization, failure to reach active, retraining request, recovery success/failure, and return to normal packet transfer for the implemented model.
- Clearly distinguish behavioral state modeling from a real PHY.

### 4.3 Explicit exclusions
- No analog transmitters/receivers, equalization circuitry, clock recovery, PLL, impedance matching, electrical compliance, jitter, signal integrity, lane margining, or physical SerDes implementation.
- No claim of full Gen4 128b/130b electrical/link interoperability.
- PIPE-level compliance is not claimed unless a real PIPE interface contract and its applicable behavior are implemented and verified.

## 5. Reset, clocking, and parameterization
- Define reset polarity, synchrony, and reset values.
- Verify reset during idle, packet reception, packet transmission, active requester operations, replay, and flow-control initialization.
- Ensure no stale requests/completions are emitted after reset.
- Define behavior for clocking assumptions; CDC is out of scope unless explicitly designed.
- Test all documented parameter boundary values and illegal parameter values where elaboration checks exist.

## 6. Design quality and observability
- No inferred latches in synthesizable RTL unless intentionally specified.
- Explicit reset behavior for all stateful logic.
- No silent packet loss; backpressure or documented error behavior is used.
- Error/status counters and debug outputs only where useful and documented.
- Lint and elaboration checks; synthesis checks where supported by the chosen tools.
- Clear separation of synthesizable RTL, behavioral models, and testbench-only fault injection.
