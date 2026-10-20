`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import pcie_uvm_pkg::*;
import pcie_pkg::*;

module tb_top;
  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end
  initial begin rst_n = 0; repeat (8) @(posedge clk); rst_n = 1; end

  pcie_pkt_if        ep_if (clk, rst_n);
  pcie_pkt_if        rc_if (clk, rst_n);
  pcie_link_ctrl_if  ctrl  (clk, rst_n);

  initial begin
    ctrl.partner_present = 1;
    ctrl.force_link_down = 0;
    ctrl.force_recovery  = 0;
    ctrl.recovery_fail   = 0;
    ctrl.latency         = 0;
    ctrl.stall_rc_to_ep  = 0;
    ctrl.stall_ep_to_rc  = 0;
    ctrl.fault_arm       = 0;
    ctrl.fault_seed      = 1;
  end

  pcie_endpoint dut (.lnk(ep_if));

  pcie_link_model link (
    .clk, .rst_n,
    .ep(ep_if.link),
    .rc(rc_if.link),
    .ctrl(ctrl.model)
  );

  initial begin
    uvm_config_db#(virtual pcie_pkt_if)::set(null, "*", "vif", rc_if);
    uvm_config_db#(virtual pcie_link_ctrl_if)::set(null, "*", "ctrl", ctrl);
    run_test();
  end
endmodule
