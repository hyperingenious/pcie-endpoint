# Architecture Specification

## 1. System boundary

The DUT is a single PCIe Endpoint Function model. A Root Complex/link-partner model provides host-originated requests and receives Endpoint-originated requests. A packet-level transport is used between the models. This transport is a project verification abstraction and is not represented as the standardized electrical interface or as a complete PHY interface.

The architecture separates three protocol layers:

- **Transaction Layer (TL):** request/completion processing, configuration transactions, address routing, ordering controls, and transaction-level error handling.
- **Data Link Layer (DLL):** per-link reliable TLP transfer, DLLPs, sequence numbers, LCRC, acknowledgements, retry/replay, and flow-control initialization/accounting as implemented.
- **Physical Layer behavioral model:** packet transport, link-up/down indications, controlled errors, delay/backpressure, and any selected logical training-state model. It does not model analog circuitry or actual serial signaling.

## 2. Logical architecture

```text
UVM tests and sequences
          |
          v
UVM Endpoint/Root-Complex agents ---- Reference model / scoreboard / coverage
          |                                          ^
          v                                          |
Packet-level link-partner model <----> Endpoint DUT -+
                                         |
                    +--------------------+--------------------+
                    |                    |                    |
              Transaction Layer    Data Link Layer     PHY/link model
                    |                    |                    |
              Config/BAR/core      DLLPs/replay/FC      Link status/errors
```

## 3. RTL responsibilities

### Common definitions
- `pcie_pkg.sv`: protocol enums, constants, packed header structures, helper functions, and project-supported encodings.
- `pcie_crc.sv`: CRC/LCRC calculation functions or module, with reference vectors in verification.
- `pcie_tlp_codec.sv`: header/payload packing and unpacking helpers, kept separate from request side effects.

### Transaction Layer
- `pcie_tlp_rx.sv`: receives packet-level TLPs from the Data Link Layer and presents validated packets to transaction processing.
- `pcie_tlp_decoder.sv`: decodes supported Fmt/Type/header fields.
- `pcie_tlp_validator.sv`: validates supported packet shape, lengths, byte enables, and required field constraints.
- `pcie_config_space.sv`: configuration registers and supported capability structures.
- `pcie_bar_decoder.sv`: BAR address mapping and access-region selection.
- `pcie_request_handler.sv`: dispatches supported Memory and Configuration requests.
- `pcie_register_file.sv`: implements the chosen memory-mapped register/storage model and byte write masks.
- `pcie_completion_gen.sv`: creates Completions for supported requests.
- `pcie_requester.sv`: optional Endpoint-originated requests, Tag allocation, and Completion tracking, if included in the selected implementation.
- `pcie_ordering_ctrl.sv`: ordering controls and buffering for the implemented transaction set.
- `pcie_error_handler.sv`: malformed/unsupported request handling and applicable error reporting.

### Data Link Layer
- `pcie_dll_tx.sv`: sequence-number insertion, LCRC generation, retry-buffer enqueue, and transmission-side state.
- `pcie_dll_rx.sv`: LCRC/sequence checks, duplicate/loss detection as applicable, and valid-TLP forwarding.
- `pcie_dllp_codec.sv`: DLLP construction and decoding for implemented packet types.
- `pcie_ack_nak_ctrl.sv`: ACK/NAK generation/processing and acknowledgement progress.
- `pcie_replay_buffer.sv`: stores unacknowledged TLPs and supplies packets for replay.
- `pcie_replay_timer.sv`: replay timeout and retry control.
- `pcie_flow_control.sv`: credit initialization, advertised credits, consumption, and returned-credit accounting for supported Virtual Channels and traffic classes.
- `pcie_dll_state.sv`: Data Link Control and Management State Machine state tracking and link-state notifications.

### Behavioral Physical Layer/link model
- `pcie_link_model.sv`: packet delivery, latency, backpressure, drop/corruption injection, and link availability.
- `pcie_ltssm_model.sv`: only if implemented, a behavioral subset of link training/status state behavior. It is not an electrical PHY or a complete Gen4 LTSSM implementation unless separately specified and verified.

### Integration
- `pcie_endpoint.sv`: top-level Endpoint integration and parameters.
- `pcie_endpoint_assertions.sv`: interface, state, transaction, and Data Link invariants.

## 4. Verification architecture

A UVM Endpoint agent observes and drives the Endpoint-facing packet interface. A Root Complex agent generates configuration/memory requests and handles Endpoint-originated requests. Monitors publish observed packets to the reference model, scoreboard, coverage collector, and protocol checkers. The scoreboard uses expected state and request/response correlation rather than assuming one request always produces one immediate response.

## 5. Interface contract

The packet interface must define, before RTL implementation:
- clock and reset polarity/asynchronous or synchronous behavior;
- packet valid/ready acceptance rule;
- packet start/end/framing representation, if packets span multiple beats;
- data width, byte enables, and metadata carried per beat;
- stability requirements while stalled;
- whether one packet may be accepted per cycle or multiple beats are required;
- reset behavior for in-flight packets;
- separation between TLP transport and DLLP/control traffic;
- how link-up, link-down, error injection, and backpressure are represented.

The chosen abstraction must not be described as a standardized PCIe PIPE interface unless it implements the relevant PIPE contract.

## 6. Configuration parameters

All configurable values must have documented defaults and legal ranges. Candidate parameters include data width, implemented BAR regions/sizes, storage depth, requester ID, Vendor/Device IDs, supported maximum payload/read request sizes, outstanding request capacity, replay buffer depth, and enabled capability structures. Parameters that would imply unsupported PCIe behavior must not be exposed as though fully compliant.
