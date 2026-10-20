package pcie_uvm_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import pcie_pkg::*;
  import pcie_crc_pkg::*;
  import pcie_tlp_codec_pkg::*;
  import pcie_dllp_pkg::*;
  import pcie_lcrc_ref_pkg::*;

  `uvm_analysis_imp_decl(_req)
  `uvm_analysis_imp_decl(_cpl)

  `include "pcie_uvm_items.sv"
  `include "../agents/pcie_sequencer.sv"
  `include "../agents/pcie_driver.sv"
  `include "../agents/pcie_monitor.sv"
  `include "../agents/pcie_agent.sv"
  `include "../models/pcie_rc_model.sv"
  `include "../models/pcie_reference_model.sv"
  `include "../checkers/pcie_scoreboard.sv"
  `include "../checkers/pcie_coverage.sv"
  `include "pcie_env.sv"
  `include "pcie_base_test.sv"
  `include "../tests/pcie_all_tests.sv"
endpackage
