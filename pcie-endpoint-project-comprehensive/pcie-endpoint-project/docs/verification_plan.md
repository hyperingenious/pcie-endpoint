# UVM Verification Plan

## 1. Verification objectives

Verify every implemented requirement against the selected PCIe 4.0 subset. The environment must detect incorrect packet decoding, state changes, Completion generation, configuration behavior, Data Link integrity/replay failures, flow-control errors, reset/recovery failures, and unintended behavior under backpressure and malformed traffic.

## 2. Testbench topology

- **Endpoint agent:** drives the DUT-facing packet interface when needed and monitors DUT input/output packets.
- **Root Complex agent/model:** issues Configuration and Memory requests, models host memory, accepts Endpoint-originated requests, and returns Completions.
- **Link/fault model:** controls packet delivery, delay, backpressure, link status, corruption, drop, and replay-related stimuli.
- **Reference model:** predicts configuration state, mapped memory/register state, accepted request consequences, expected Completion contents, Tag state, and Data Link state as applicable.
- **Scoreboard:** correlates observed requests and responses, compares data and metadata, detects missing/duplicate/unexpected packets, and checks side effects.
- **Coverage collector:** samples observed packet activity and state transitions.
- **Assertions:** check interface contract, internal invariants, transaction rules, and Data Link state rules.

## 3. UVM components

- `pcie_tlp_item`: packet-level TLP fields, payload, and constraints.
- `pcie_dllp_item`: DLLP type, fields, and integrity metadata for Data Link tests.
- `pcie_transaction_item`: higher-level operation and expected response/side effects.
- `pcie_sequencer`: coordinates sequences and driver.
- `pcie_driver`: drives packet-level transfers and link/fault controls according to the interface contract.
- `pcie_monitor`: samples accepted packets and publishes analysis transactions.
- `pcie_agent`: active/passive agent configuration.
- `pcie_rc_model`: Root Complex behavior and host memory model.
- `pcie_reference_model`: independent expected-state and expected-response model.
- `pcie_scoreboard`: request/response matching and state/data checking.
- `pcie_coverage`: transaction, protocol, error, reset, Data Link, and cross coverage.
- `pcie_env`: agent/model/checker assembly and connections.
- `pcie_base_test`: common configuration, objection handling, end-of-test checks.
- Test classes: focused tests listed in `testplan.csv`.

## 4. Scoreboard contract

The scoreboard shall:
- Update its model only from observed accepted transactions and documented reset events.
- Match request and Completion using applicable Requester ID/Tag and expected Completion semantics.
- Check Completion status, identifiers, length, byte count, lower address, and payload as applicable.
- Check BAR mapping, byte-enabled write effects, read-after-write behavior, and configuration field semantics.
- Detect missing, duplicate, unexpected, late, malformed, and mismatched packets.
- Track outstanding requests and Tags when requester functionality is enabled.
- Check Data Link sequence/replay behavior without confusing retransmission on the link with duplicate delivery to the Transaction Layer.
- Report enough context to reproduce a failure: test, seed, time, request, expected response, actual response, and state.
- Drain/check outstanding work at end of test; timeouts must be reported as failures unless explicitly expected.

## 5. Test categories

1. Compile/elaboration and smoke.
2. Directed configuration, BAR, Memory Read/Write, byte-enable, Completion, and reset tests.
3. Packet-format, length, boundary, and negative/error tests.
4. Back-to-back and backpressure tests.
5. Constrained-random legal transaction tests.
6. Randomized malformed/error injection tests in a separate negative-test group.
7. Requester/Tag/Completion tests if requester functionality is enabled.
8. Data Link initialization, DLLP, LCRC, ACK/NAK, replay, and flow-control tests if those features are implemented.
9. Link-model/recovery tests for the supported behavioral model.
10. Stress regression and repeatability checks.

## 6. Randomization strategy

- Constrain packet fields to legal combinations for normal traffic.
- Use separate negative sequences to deliberately violate selected rules.
- Randomize request type, address region, lengths, byte enables, data patterns, inter-packet gaps, backpressure, Tag usage, response delay, and supported error injection.
- Use deterministic seeds and save the seed for every run.
- Bias randomization toward boundaries and previously uncovered bins without removing broad legal diversity.
- Prevent tests from passing merely because generated traffic was never accepted or observed.

## 7. Test completion and failure policy

- Each test has an explicit completion criterion and timeout.
- Every mandatory test must have actually executed.
- Unexpected UVM_ERROR/UVM_FATAL, scoreboard mismatch, assertion failure, deadlock, or timeout fails the test.
- Expected checker-negative tests must demonstrate that the intended checker fired and no unrelated failure occurred.
- A regression report distinguishes PASS, FAIL, SKIP, NOT_IMPLEMENTED, and EXPECTED_NEGATIVE.

## 8. Signoff evidence

Retain tool versions, compile logs, test logs, random seeds, assertion summaries, coverage databases/reports, exclusions, unresolved failures, and known limitations. Signoff metrics are calculated only from real executed runs.
