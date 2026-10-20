# Assertion and Protocol Checker Plan

Assertions must match the actual packet-level interface and the selected PCIe subset. Properties based on a standard interface must not be applied to a project-specific abstraction unless the equivalent contract is explicitly defined.

## 1. Packet interface
- Valid/ready acceptance occurs only on the specified handshake edge.
- Packet metadata and data remain stable while valid is asserted and ready is low, where required by the interface contract.
- No packet acceptance when reset or link gating forbids it.
- Packet framing, beat count, and end-of-packet indication remain consistent for multi-beat packets.
- No duplicate acceptance of one held packet.
- No unintended packet loss under finite backpressure.

## 2. Transaction Layer
- Accepted TLPs use supported formats/types and satisfy defined header/length constraints.
- Request payload length agrees with packet framing and decoded length.
- BAR decoder selects at most the documented destination for one request.
- Rejected requests do not update mapped state.
- Byte-disabled lanes remain unchanged after a write.
- Completion generation is causally associated with a request where a Completion is required.
- Completion header/payload metadata is consistent with the supported Completion format.
- No duplicate Completion for one completed request unless explicitly required by a modeled retry path; link-level replay must not become duplicate TL delivery.
- Requester Tags are not simultaneously reused when uniqueness is required.
- Unexpected/mismatched Completions do not corrupt unrelated request state.
- Ordering-control state does not permit a prohibited ordering case in the supported subset.

## 3. Configuration/reset
- Reset initializes all specified registers/state.
- Read-only and reserved fields are not modified by writes.
- Reset clears or aborts in-flight state according to the documented contract.
- No stale response is emitted after reset unless the model explicitly defines otherwise.
- Illegal FSM state/transition checks for all implemented control FSMs.

## 4. Data Link Layer
- Sequence number advances according to accepted transmitted TLP behavior.
- Retry-buffer entries are retained until acknowledged and are released only under the defined acknowledgement rules.
- Replay emits the required buffered packets in order.
- LCRC failure prevents corrupted TLP delivery to the Transaction Layer and triggers the specified recovery response.
- Sequence mismatch/duplicate handling follows the implemented receive rules.
- ACK/NAK and replay timer state transitions are legal.
- Credit counters never underflow/overflow their defined representation.
- TLP transmission is blocked when the implemented flow-control policy has insufficient credit.
- Link-down/inactive state prevents prohibited DLL activity.

## 5. Behavioral link model
- Normal packet delivery preserves order as defined by the model.
- Fault injection is only active when configured and is recorded in the test log.
- Link-down/recovery transitions follow the model contract.

## 6. Checker-negative validation
For selected properties, create controlled violations at the checker boundary or via fault injection. Each negative test must prove the intended property reports a failure and the test harness classifies it as an expected checker failure. Normal regression must remain free of unexpected assertion failures.

## 7. Assertion report fields
Record property name, source location, enable/disable status, observed pass/fail counts, vacuity considerations where supported, associated test IDs, and whether negative detection was validated.
