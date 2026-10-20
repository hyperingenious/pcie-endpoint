# Specification Traceability Matrix

Confirm the exact PCIe 4.0 paragraph before marking `verified`. Source exists; `verified` requires a passing run log.

| Requirement ID | Summary | Spec area | RTL | Tests | Assertions | Coverage | Status |
|---|---|---|---|---|---|---|---|
| TL-PKT-001 | Decode supported TLP headers | Ch. 2 §§2.2.1–2.2.6 | `pcie_tlp_decoder`, `pcie_tlp_codec_pkg` | TLP-01, TLP-02 | a_if_frm | cg_pkt cp_fmt/cp_typ | implemented |
| TL-REQ-001 | Memory/Cfg request validation | Ch. 2 §§2.2.7, 2.3.1 | `pcie_tlp_validator`, `pcie_request_handler` | MEM-*, CFG-*, ERR-* | a_tl_rej | cg_err | implemented |
| TL-CPL-001 | Completion generation | Ch. 2 §§2.2.9, 2.3.2 | `pcie_completion_gen` | CPL-01, CPL-02, CPL-04 | — | cg_cpl | implemented |
| TL-BE-001 | Byte-enable rules | Ch. 2 §2.2.5 | `pcie_register_file` | BE-01–03 | a_tl_be | cg_pkt cp_be | implemented |
| TL-ORD-001 | VC0 ordering | Ch. 2 §2.4 | `pcie_ordering_ctrl` | ORD-01, B2B-* | — | x_fmt_typ | implemented |
| TL-FC-001 | TL/DLL credit gate | Ch. 2 §2.6; Ch. 3 §3.4 | `pcie_flow_control` | FC-01–04 | a_dll_crd | — | implemented |
| TL-ERR-001 | Malformed/UR/poisoned | Ch. 2 §2.3 | `pcie_error_handler` | ERR-*, TLP-02 | a_tl_rej | cg_err | implemented |
| TL-CFG-001 | Type 0 + MSI + PCIe cap | Ch. 7 | `pcie_config_space` | CFG-01–05 | a_dll_fsm | — | implemented |
| TL-REQ-EP | Endpoint requester/DMA/MSI | Ch. 2 requester | `pcie_requester` | REQ-*, TAG-*, DMA-*, INT-01 | a_tl_tag | — | implemented |
| DLL-STATE-001 | DL control state | Ch. 3 §§3.1–3.2 | `pcie_dll_state` | DLL-01 | a_dll_down, a_dll_fsm | — | implemented |
| DLL-FC-001 | FC init/update | Ch. 3 §§3.3–3.4 | `pcie_flow_control` | FC-* | a_dll_crd | — | implemented |
| DLL-DLLP-001 | DLLP encode/decode | Ch. 3 §3.5 | `pcie_dllp_pkg` | DLL-02 | — | — | implemented |
| DLL-SEQ-001 | Sequence numbers | Ch. 3 §3.6 | `pcie_dll_rx`, `pcie_dll_tx` | DLL-05 | — | — | implemented |
| DLL-LCRC-001 | LCRC generate/check | Ch. 3 §3.6 | `pcie_crc_pkg` | DLL-03, DLL-04 | a_dll_lcrc | cg_err cp_lcrc | implemented |
| DLL-RPLY-001 | Replay buffer/timer | Ch. 3 §3.6 | `pcie_replay_buffer`, `pcie_replay_timer` | DLL-06–09 | a_dll_rply | — | implemented |
| PHY-LINK-001 | Link status/faults | Ch. 4 (model) | `pcie_link_model`, `pcie_ltssm_model` | LINK-*, PHY-01 | a_lt_fsm | — | implemented |
| CFG-RST-001 | Reset behavior | registers/layers | `pcie_endpoint` | RST-* | a_if_rst | — | implemented |
| TB-SCB-001 | Scoreboard match | project | `pcie_scoreboard` | CPL-03, SCB neg | — | — | implemented |
| TB-COV-001 | Functional coverage | project | `pcie_coverage` | RND-01, STR-01 | — | cg_pkt | implemented |
| NS-IO | I/O requests | — | — | — | — | ignore_bins io | not_supported |
| NS-ATOMIC | AtomicOps | — | — | — | — | — | not_supported |
| NS-ECRC | ECRC/TD | — | — | — | — | — | not_supported |
| NS-MSIX | MSI-X | — | — | INT-01 is MSI only | — | — | not_supported |
| NS-PREFIX | TLP prefixes | — | — | — | — | ignore_bins prefix | not_supported |
