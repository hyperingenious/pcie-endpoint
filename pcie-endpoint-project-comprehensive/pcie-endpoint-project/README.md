# PCIe Endpoint RTL Design and UVM Verification

A SystemVerilog Endpoint for a documented PCI Express Base Specification Revision 4.0, Version 1.0 subset. The tree contains synthesizable Transaction and Data Link layers, a behavioral link/LTSSM model, assertions, and a UVM environment with a reference model, scoreboard, coverage, and the tests listed in `docs/testplan.csv`.

## Project status

RTL, link model, assertions, UVM environment, and every testplan class are **implemented** in source. Simulation signoff (pass/fail, coverage numbers) requires Questa/ModelSim with `vlog`/`vsim` and UVM on `PATH`. Without a simulator, `scripts/run_regression.py` records every test as `NOT_RUN` and exits nonzero. Never treat `NOT_RUN` as a pass.

## Scope

Packet-level model (not PIPE, not an electrical PHY). Supported and unsupported features are listed in `docs/known_limitations.md` and `docs/feature_specification.md`.

## Documentation

- `docs/architecture.md` — blocks and interfaces
- `docs/feature_specification.md` — feature inventory
- `docs/verification_plan.md` — UVM architecture
- `docs/testplan.csv` — 64 directed tests (status `implemented` until a log proves `verified`)
- `docs/coverage_plan.md`, `docs/assertion_plan.md`, `docs/specification_traceability.md`
- `docs/signoff_report.md` — fill only from real runs

## Source layout

- `rtl/` — Endpoint RTL; `rtl/beh/` is simulation-only
- `tb/` — interfaces, UVM agents, models, checkers, tests, `tb/top/tb_top.sv`
- `sim/filelists/` — `rtl.f`, `rtl_sim.f`, `tb.f`
- `scripts/` — `run_smoke.do`, `run_uvm.do`, `run_regression.py`

## Running tests

Smoke (no UVM):

```bash
cd pcie-endpoint-project-comprehensive/pcie-endpoint-project
vsim -c -do scripts/run_smoke.do
```

One UVM test:

```bash
export UVM_TESTNAME=pcie_config_reset_test
vsim -c -do scripts/run_uvm.do
```

Full regression (64 testplan tests plus two expected-negative checker tests):

```bash
python3 scripts/run_regression.py
```

Report: `sim/logs/regression_report.csv`. Per-test logs: `sim/logs/<test>.log`.
