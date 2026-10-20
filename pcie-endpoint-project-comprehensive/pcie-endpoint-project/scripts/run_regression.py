#!/usr/bin/env python3
"""Run the PCIe Endpoint UVM regression with Questa/ModelSim."""
import csv
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "sim" / "logs"
REPORT = LOG_DIR / "regression_report.csv"
TESTPLAN = ROOT / "docs" / "testplan.csv"
EXTRA_NEG = ["pcie_checker_negative_if_test", "pcie_scoreboard_negative_test"]


def vsim_available() -> bool:
    return shutil.which("vsim") is not None and shutil.which("vlog") is not None


def load_tests():
    tests = []
    with TESTPLAN.open(newline="") as f:
        for row in csv.DictReader(f):
            tests.append(row["Test Name"])
    tests.extend(EXTRA_NEG)
    return tests


def classify(name: str, rc: int, log_text: str) -> str:
    if name in EXTRA_NEG:
        fired = ("IF-STALL" in log_text or "a_if_stall" in log_text or
                 "injected mismatch" in log_text.lower() or
                 "SCB_NEG" in log_text or "Expected IF-STALL" in log_text)
        return "EXPECTED_NEGATIVE" if fired else "FAIL"
    return "PASS" if rc == 0 and "UVM_ERROR" not in log_text and "UVM_FATAL" not in log_text else "FAIL"


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    tests = load_tests()
    rows = []
    if not vsim_available():
        for t in tests:
            rows.append((t, "NOT_RUN", "vsim/vlog not on PATH"))
        with REPORT.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["test", "status", "note"])
            w.writerows(rows)
        print("Simulator not found; wrote NOT_RUN for all tests")
        return 1

    env = os.environ.copy()
    for t in tests:
        env["UVM_TESTNAME"] = t
        log = LOG_DIR / f"{t}.log"
        proc = subprocess.run(
            ["vsim", "-c", "-do", "scripts/run_uvm.do"],
            cwd=ROOT, env=env, capture_output=True, text=True,
        )
        text = proc.stdout + proc.stderr
        log.write_text(text)
        status = classify(t, proc.returncode, text)
        rows.append((t, status, f"rc={proc.returncode}"))
        print(f"{t}: {status}")

    with REPORT.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["test", "status", "note"])
        w.writerows(rows)
    failed = sum(1 for _, s, _ in rows if s in ("FAIL", "NOT_RUN"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
