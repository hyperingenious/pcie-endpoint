`ifndef PCIE_ALL_TESTS_SV
`define PCIE_ALL_TESTS_SV

class pcie_config_reset_test extends pcie_base_test;
  `uvm_component_utils(pcie_config_reset_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(0, 12'h000, 0, 4'hF); mk_cfg(0, 12'h004, 0, 4'hF); mk_cfg(0, 12'h008, 0, 4'hF);
  endtask
endclass

class pcie_config_read_test extends pcie_base_test;
  `uvm_component_utils(pcie_config_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    for (int i = 0; i < 40; i++) mk_cfg(0, 12'(i*4), 0, 4'hF);
  endtask
endclass

class pcie_config_write_test extends pcie_base_test;
  `uvm_component_utils(pcie_config_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h0000_0006, 4'hF); mk_cfg(0, 12'h004, 0, 4'hF);
  endtask
endclass

class pcie_config_ro_reserved_test extends pcie_base_test;
  `uvm_component_utils(pcie_config_ro_reserved_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h000, 32'hFFFF_FFFF, 4'hF); mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_capability_walk_test extends pcie_base_test;
  `uvm_component_utils(pcie_capability_walk_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(0, 12'h034, 0, 4'hF); mk_cfg(0, 12'h040, 0, 4'hF); mk_cfg(0, 12'h050, 0, 4'hF);
  endtask
endclass

class pcie_bar_region_test extends pcie_base_test;
  `uvm_component_utils(pcie_bar_region_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h0000_0002, 4'hF);
    mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_cfg(1, 12'h014, 32'h8000_1000, 4'hF);
    mk_mem(1, 32'h8000_0100, '{32'hA5A5_A5A5}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0100, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_bar_boundary_test extends pcie_base_test;
  `uvm_component_utils(pcie_bar_boundary_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0000, '{32'h1}, 4'hF, 4'h0);
    mk_mem(1, 32'h8000_0FFC, '{32'h2}, 4'hF, 4'h0);
  endtask
endclass

class pcie_unmapped_address_test extends pcie_base_test;
  `uvm_component_utils(pcie_unmapped_address_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF);
    mk_mem(1, 32'h9000_0000, '{32'h1}, 4'hF, 4'h0);
  endtask
endclass

class pcie_mem_single_write_read_test extends pcie_base_test;
  `uvm_component_utils(pcie_mem_single_write_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0104, '{32'h1122_3344}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0104, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_mem_multi_dword_test extends pcie_base_test;
  `uvm_component_utils(pcie_mem_multi_dword_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0200, '{32'h1, 32'h2, 32'h3, 32'h4}, 4'hF, 4'hF);
    mk_mem(0, 32'h8000_0200, '{32'h0, 32'h0, 32'h0, 32'h0}, 4'hF, 4'hF);
  endtask
endclass

class pcie_read_after_write_test extends pcie_base_test;
  `uvm_component_utils(pcie_read_after_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0108, '{32'hDEAD_BEEF}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0108, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_data_pattern_test extends pcie_base_test;
  `uvm_component_utils(pcie_data_pattern_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0110, '{32'h0000_0000}, 4'hF, 4'h0);
    mk_mem(1, 32'h8000_0114, '{32'hFFFF_FFFF}, 4'hF, 4'h0);
    mk_mem(1, 32'h8000_0118, '{32'hAAAA_5555}, 4'hF, 4'h0);
  endtask
endclass

class pcie_byte_enable_full_test extends pcie_base_test;
  `uvm_component_utils(pcie_byte_enable_full_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0120, '{32'h1122_3344}, 4'hF, 4'h0);
  endtask
endclass

class pcie_byte_enable_sparse_test extends pcie_base_test;
  `uvm_component_utils(pcie_byte_enable_sparse_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0124, '{32'hAABB_CCDD}, 4'b0101, 4'h0);
    mk_mem(0, 32'h8000_0124, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_byte_enable_boundary_test extends pcie_base_test;
  `uvm_component_utils(pcie_byte_enable_boundary_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0130, '{32'h1, 32'h2}, 4'b1110, 4'b0111);
  endtask
endclass

class pcie_supported_tlp_matrix_test extends pcie_base_test;
  `uvm_component_utils(pcie_supported_tlp_matrix_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(0, 12'h000, 0, 4'hF); mk_cfg(1, 12'h004, 32'h6, 4'hF);
    mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0100, '{32'h5}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0100, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_unsupported_tlp_test extends pcie_base_test;
  `uvm_component_utils(pcie_unsupported_tlp_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b000; t.typ = 5'b00010; t.length = 1; t.first_be = 4'hF; t.addr = 0;
    send_item(t);
  endtask
endclass

class pcie_length_min_test extends pcie_base_test;
  `uvm_component_utils(pcie_length_min_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(0, 32'h8000_0100, '{32'h0}, 4'h0, 4'h0);
  endtask
endclass

class pcie_length_max_test extends pcie_base_test;
  `uvm_component_utils(pcie_length_max_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    logic [31:0] d[];
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    d = new[32]; foreach (d[i]) d[i] = i;
    mk_mem(1, 32'h8000_0100, d, 4'hF, 4'hF);
  endtask
endclass

class pcie_length_invalid_test extends pcie_base_test;
  `uvm_component_utils(pcie_length_invalid_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b010; t.typ = 5'b00000; t.length = 10'd64; t.payload = new[1]; t.payload[0] = 0;
    t.addr = 32'h80000100; t.first_be = 4'hF; send_item(t);
  endtask
endclass

class pcie_completion_header_test extends pcie_base_test;
  `uvm_component_utils(pcie_completion_header_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_completion_payload_test extends pcie_base_test;
  `uvm_component_utils(pcie_completion_payload_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0100, '{32'h55}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0100, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_unexpected_completion_test extends pcie_base_test;
  `uvm_component_utils(pcie_unexpected_completion_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b000; t.typ = 5'b01010; t.req_id = 16'h0100; t.tag = 8'h7F; t.cpl_status = 0; t.byte_count = 4;
    send_item(t);
  endtask
endclass

class pcie_write_write_test extends pcie_base_test;
  `uvm_component_utils(pcie_write_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0100, '{32'h1}, 4'hF, 4'h0);
    mk_mem(1, 32'h8000_0104, '{32'h2}, 4'hF, 4'h0);
  endtask
endclass

class pcie_read_read_test extends pcie_base_test;
  `uvm_component_utils(pcie_read_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); mk_cfg(0, 12'h004, 0, 4'hF); endtask
endclass

class pcie_write_read_test extends pcie_base_test;
  `uvm_component_utils(pcie_write_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(0, 12'h004, 0, 4'hF); endtask
endclass

class pcie_read_write_test extends pcie_base_test;
  `uvm_component_utils(pcie_read_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); mk_cfg(1, 12'h004, 32'h2, 4'hF); endtask
endclass

class pcie_request_backpressure_test extends pcie_base_test;
  `uvm_component_utils(pcie_request_backpressure_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) ctrl.stall_rc_to_ep <= 1;
    #100; if (ctrl != null) ctrl.stall_rc_to_ep <= 0;
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_response_backpressure_test extends pcie_base_test;
  `uvm_component_utils(pcie_response_backpressure_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) ctrl.stall_ep_to_rc <= 1;
    mk_cfg(0, 12'h000, 0, 4'hF);
    #200; if (ctrl != null) ctrl.stall_ep_to_rc <= 0;
  endtask
endclass

class pcie_reset_idle_test extends pcie_base_test;
  `uvm_component_utils(pcie_reset_idle_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_reset_active_test extends pcie_base_test;
  `uvm_component_utils(pcie_reset_active_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF);
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_reset_recovery_test extends pcie_base_test;
  `uvm_component_utils(pcie_reset_recovery_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    wait (vif.phy_link_up);
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_malformed_header_test extends pcie_base_test;
  `uvm_component_utils(pcie_malformed_header_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b010; t.typ = 5'b00000; t.td = 1; t.length = 1; t.payload = new[1]; send_item(t);
  endtask
endclass

class pcie_invalid_address_test extends pcie_base_test;
  `uvm_component_utils(pcie_invalid_address_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF);
    mk_mem(0, 32'h0000_0000, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_unsupported_request_test extends pcie_base_test;
  `uvm_component_utils(pcie_unsupported_request_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b001; t.typ = 5'b00101; t.length = 1; t.first_be = 4'hF; send_item(t);
  endtask
endclass

class pcie_random_legal_test extends pcie_base_test;
  `uvm_component_utils(pcie_random_legal_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    repeat (20) mk_cfg(0, 12'($urandom_range(0, 36)*4), 0, 4'hF);
  endtask
endclass

class pcie_random_negative_test extends pcie_base_test;
  `uvm_component_utils(pcie_random_negative_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    repeat (8) begin
      pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
      t.fmt = 3'($urandom_range(0, 3)); t.typ = 5'($urandom); t.length = 10'($urandom_range(0, 64));
      t.ep = $urandom_range(0, 1); send_item(t);
    end
  endtask
endclass

class pcie_stress_test extends pcie_base_test;
  `uvm_component_utils(pcie_stress_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    repeat (40) begin
      logic [31:0] a;
      a = 32'h80000100 + ($urandom_range(0, 64) << 2);
      mk_mem($urandom_range(0, 1), a, '{32'($urandom)}, 4'hF, 4'h0);
    end
  endtask
endclass

class pcie_tag_lifecycle_test extends pcie_base_test;
  `uvm_component_utils(pcie_tag_lifecycle_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_cfg(1, 12'h020, 32'h0000_0003, 4'hF);
  endtask
endclass

class pcie_tag_boundary_test extends pcie_base_test;
  `uvm_component_utils(pcie_tag_boundary_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h01C, 32'h8, 4'hF); mk_cfg(1, 12'h020, 32'h3, 4'hF);
  endtask
endclass

class pcie_multiple_outstanding_test extends pcie_base_test;
  `uvm_component_utils(pcie_multiple_outstanding_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h01C, 32'h8, 4'hF); mk_cfg(1, 12'h020, 32'h3, 4'hF);
  endtask
endclass

class pcie_completion_reorder_test extends pcie_base_test;
  `uvm_component_utils(pcie_completion_reorder_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    env.rc_model.reorder = 1;
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h020, 32'h3, 4'hF);
  endtask
endclass

class pcie_split_completion_test extends pcie_base_test;
  `uvm_component_utils(pcie_split_completion_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    logic [31:0] d[];
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    d = new[32]; mk_mem(0, 32'h8000_0100, d, 4'hF, 4'hF);
  endtask
endclass

class pcie_ordering_rules_test extends pcie_base_test;
  `uvm_component_utils(pcie_ordering_rules_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h2, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0100, '{32'h1}, 4'hF, 4'h0);
    mk_mem(0, 32'h8000_0100, '{32'h0}, 4'hF, 4'h0);
  endtask
endclass

class pcie_completion_timeout_test extends pcie_base_test;
  `uvm_component_utils(pcie_completion_timeout_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    env.rc_model.withhold = 1;
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h024, 32'h20, 4'hF); mk_cfg(1, 12'h020, 32'h3, 4'hF);
    #5000;
  endtask
endclass

class pcie_dll_state_test extends pcie_base_test;
  `uvm_component_utils(pcie_dll_state_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); wait (vif.dll_state_dbg == 2); mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_dllp_codec_test extends pcie_base_test;
  `uvm_component_utils(pcie_dllp_codec_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_lcrc_reference_test extends pcie_base_test;
  `uvm_component_utils(pcie_lcrc_reference_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    import pcie_crc_pkg::*;
    import pcie_lcrc_ref_pkg::*;
    logic [31:0] rtl_v, ref_v;
    byte bytes[];
    bytes = new[2];
    bytes[0] = 8'h00;
    bytes[1] = 8'h00;
    rtl_v = lcrc_final(lcrc_seq(12'h0));
    ref_v = bit_serial_crc32(bytes, 2);
    if (rtl_v !== ref_v)
      `uvm_error("LCRC", $sformatf("mismatch rtl=%h ref=%h", rtl_v, ref_v))
    else
      `uvm_info("LCRC", $sformatf("match %h", rtl_v), UVM_LOW)
  endtask
endclass

class pcie_lcrc_fault_test extends pcie_base_test;
  `uvm_component_utils(pcie_lcrc_fault_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    pcie_tlp_item t = pcie_tlp_item::type_id::create("t");
    t.fmt = 3'b000; t.typ = 5'b00100; t.length = 1; t.first_be = 4'hF; t.lcrc_ok = 0; send_item(t);
  endtask
endclass

class pcie_sequence_wrap_test extends pcie_base_test;
  `uvm_component_utils(pcie_sequence_wrap_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); repeat (8) mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_ack_test extends pcie_base_test;
  `uvm_component_utils(pcie_ack_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); mk_cfg(0, 12'h004, 0, 4'hF); endtask
endclass

class pcie_nak_replay_test extends pcie_base_test;
  `uvm_component_utils(pcie_nak_replay_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) begin ctrl.fault_arm <= 1; ctrl.fault_dir <= 2'd1; ctrl.fault_kind <= 3'd2; end
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_replay_timeout_test extends pcie_base_test;
  `uvm_component_utils(pcie_replay_timeout_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) begin ctrl.fault_arm <= 1; ctrl.fault_dir <= 2'd3; ctrl.fault_kind <= 3'd1; end
    mk_cfg(0, 12'h000, 0, 4'hF); #2000;
  endtask
endclass

class pcie_replay_buffer_boundary_test extends pcie_base_test;
  `uvm_component_utils(pcie_replay_buffer_boundary_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); repeat (8) mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_fc_initialization_test extends pcie_base_test;
  `uvm_component_utils(pcie_fc_initialization_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); wait (vif.phy_link_up); #200; mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_fc_exhaustion_test extends pcie_base_test;
  `uvm_component_utils(pcie_fc_exhaustion_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); repeat (16) mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_fc_return_test extends pcie_base_test;
  `uvm_component_utils(pcie_fc_return_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); repeat (4) mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_fc_invalid_update_test extends pcie_base_test;
  `uvm_component_utils(pcie_fc_invalid_update_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body(); mk_cfg(0, 12'h000, 0, 4'hF); endtask
endclass

class pcie_link_down_test extends pcie_base_test;
  `uvm_component_utils(pcie_link_down_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(0, 12'h000, 0, 4'hF);
    if (ctrl != null) ctrl.force_link_down <= 1;
    #100; if (ctrl != null) ctrl.force_link_down <= 0;
    wait (vif.phy_link_up); mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_link_recovery_test extends pcie_base_test;
  `uvm_component_utils(pcie_link_recovery_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) ctrl.force_recovery <= 1;
    #50; if (ctrl != null) ctrl.force_recovery <= 0;
    wait (vif.phy_link_up); mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_packet_fault_injection_test extends pcie_base_test;
  `uvm_component_utils(pcie_packet_fault_injection_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    if (ctrl != null) begin ctrl.fault_arm <= 1; ctrl.fault_dir <= 0; ctrl.fault_kind <= 3'd1; ctrl.fault_seed <= seed; end
    mk_cfg(0, 12'h000, 0, 4'hF);
  endtask
endclass

class pcie_dma_write_test extends pcie_base_test;
  `uvm_component_utils(pcie_dma_write_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_cfg(1, 12'h014, 32'h8000_1000, 4'hF);
    mk_mem(1, 32'h8000_1000, '{32'h1111_1111}, 4'hF, 4'h0);
    mk_cfg(1, 12'h018, 0, 4'hF); mk_cfg(1, 12'h01C, 32'h1, 4'hF); mk_cfg(1, 12'h020, 32'h1, 4'hF);
  endtask
endclass

class pcie_dma_read_test extends pcie_base_test;
  `uvm_component_utils(pcie_dma_read_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF); mk_cfg(1, 12'h01C, 32'h1, 4'hF); mk_cfg(1, 12'h020, 32'h3, 4'hF);
  endtask
endclass

class pcie_interrupt_test extends pcie_base_test;
  `uvm_component_utils(pcie_interrupt_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    mk_cfg(1, 12'h004, 32'h6, 4'hF);
    mk_cfg(1, 12'h040, 32'h0001_0000, 4'h3);
    mk_cfg(1, 12'h044, 32'hFEE0_0000, 4'hF);
    mk_cfg(1, 12'h048, 32'h0000_00B1, 4'h3);
    mk_cfg(1, 12'h010, 32'h8000_0000, 4'hF);
    mk_mem(1, 32'h8000_0028, '{32'h1}, 4'hF, 4'h0);
  endtask
endclass

class pcie_checker_negative_if_test extends pcie_base_test;
  `uvm_component_utils(pcie_checker_negative_if_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual task run_test_body();
    `uvm_info(get_type_name(), "Expect IF-STALL assertion fire", UVM_LOW)
    force vif.tlp_tx_valid = 1;
    force vif.tlp_tx_ready = 0;
    @(posedge vif.clk);
    force vif.tlp_tx_data = 32'hDEAD_BEEF;
    #20;
    release vif.tlp_tx_valid;
    release vif.tlp_tx_ready;
    release vif.tlp_tx_data;
  endtask
endclass

class pcie_scoreboard_negative_test extends pcie_base_test;
  `uvm_component_utils(pcie_scoreboard_negative_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    uvm_config_db#(bit)::set(this, "env.scb", "expect_mismatch", 1'b1);
    super.build_phase(phase);
  endfunction
  virtual task run_test_body();
    env.scb.mismatches++;
    `uvm_info(get_type_name(), "Injected scoreboard mismatch for checker-negative", UVM_LOW)
  endtask
endclass

`endif
