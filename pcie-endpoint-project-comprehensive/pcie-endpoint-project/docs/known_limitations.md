# Scope Boundaries and Known Limitations

## 1. Protocol specification baseline

PCI Express Base Specification Revision 4.0, Version 1.0 is the baseline. Only features marked supported below may be claimed as implemented.

## 2. Physical signaling

No analog PHY, SerDes, electrical compliance, or PIPE interface. `pcie_link_model` and `pcie_ltssm_model` are verification abstractions.

## 3. Link training

LTSSM subset: Detect, Polling, Configuration, L0, Recovery, Failed. Not Gen4 equalization or speed negotiation.

## 4. Optional capabilities — `not_supported`

I/O, Cfg Type 1, AtomicOps, locked transactions, TLP prefixes, ECRC/TD, MSI-X, Power Management, AER, DSN, LTR, ATS, SR-IOV, Resizable BAR, multi-function, VC1+, TC1+, CDC, analog/SerDes/PIPE.

## 5. Compliance claims

A passing simulation of this model is not PCI-SIG certification and does not imply interoperability with commercial Root Complexes.

## 6. Status labels

`planned`, `implemented`, `verified`, `partially_verified`, `not_supported`, `waived`.

## 7. Current repository status

| Area | Status |
|------|--------|
| RTL (`rtl/`, `pcie_endpoint.sv`) | `implemented` |
| Behavioral link (`rtl/beh/`) | `implemented` |
| Assertions (`pcie_endpoint_assertions.sv`) | `implemented` |
| UVM TB (`tb/`) | `implemented` |
| Test classes (64 + 2 checker-negative) | `implemented` |
| Regression scripts | `implemented` |
| Simulation signoff / coverage closure | `planned` until Questa produces logs |

## 8. Supported feature snapshot

- **TL:** Mem Rd/Wr (3DW/4DW), CfgRd0/CfgWr0, Cpl/CplD; two 4 KiB 32-bit BARs; First/Last DW BE; RCB split Completions; Type 0 header + MSI (0x40) + PCIe cap (0x50); Endpoint DMA requester (8 tags, 4 outstanding); UR/malformed/poisoned handling; TC0/VC0; IDO is UR; RO used in ordering.
- **DLL:** DL_Inactive/Init/Active; 12-bit sequence; LCRC32; ACK/NAK; replay depth 8, retry limit 4; VC0 InitFC/UpdateFC with advertised PH/PD/NPH/NPD and infinite Completions.
- **PHY model:** Packet transport, latency, stall, drop/corrupt/duplicate, LTSSM subset.

MSI is 32-bit, one vector, next pointer 50h so the PCI Express capability starts at 50h (no MSI pending-bit register in the 50h slot).
