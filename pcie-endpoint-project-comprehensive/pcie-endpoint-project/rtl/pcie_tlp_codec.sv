// TLP header packing/unpacking helpers. Pure functions with no side effects;
// request processing lives in rtl/tl/.
package pcie_tlp_codec_pkg;
  import pcie_pkg::*;

  // DW0 bit positions follow the PCIe 4.0 common header figure.
  function automatic tlp_hdr_t decode_hdr(input logic [31:0] dw0, input logic [31:0] dw1,
                                          input logic [31:0] dw2, input logic [31:0] dw3);
    tlp_hdr_t h;
    h = '0;
    h.fmt      = dw0[31:29];
    h.typ      = dw0[28:24];
    h.tc       = dw0[22:20];
    h.attr     = {dw0[18], dw0[13:12]};
    h.ln       = dw0[17];
    h.th       = dw0[16];
    h.td       = dw0[15];
    h.ep       = dw0[14];
    h.at       = dw0[11:10];
    h.length   = dw0[9:0];
    if (dw0[28:24] == TYP_CPL || dw0[28:24] == TYP_CPLLK) begin
      h.cpl_id     = dw1[31:16];
      h.cpl_status = dw1[15:13];
      h.bcm        = dw1[12];
      h.byte_count = dw1[11:0];
      h.req_id     = dw2[31:16];
      h.tag        = dw2[15:8];
      h.lower_addr = dw2[6:0];
    end else begin
      h.req_id   = dw1[31:16];
      h.tag      = dw1[15:8];
      h.last_be  = dw1[7:4];
      h.first_be = dw1[3:0];
      if (dw0[29]) h.addr = {dw2, dw3[31:2], 2'b00};
      else         h.addr = {32'h0, dw2[31:2], 2'b00};
      h.cfg_bus  = dw2[31:24];
      h.cfg_dev  = dw2[23:19];
      h.cfg_func = dw2[18:16];
      h.cfg_reg  = dw2[11:2];
    end
    return h;
  endfunction

  function automatic logic [31:0] enc_dw0(input logic [2:0] fmt, input logic [4:0] typ, input logic [2:0] tc,
                                          input logic [2:0] attr, input logic td, input logic ep,
                                          input logic [9:0] length);
    return {fmt, typ, 1'b0, tc, 1'b0, attr[2], 1'b0, 1'b0, td, ep, attr[1:0], 2'b00, length};
  endfunction

  function automatic logic [31:0] enc_req_dw1(input logic [15:0] rid, input logic [7:0] tag,
                                              input logic [3:0] last_be, input logic [3:0] first_be);
    return {rid, tag, last_be, first_be};
  endfunction

  function automatic logic [31:0] enc_cpl_dw1(input logic [15:0] cid, input logic [2:0] st,
                                              input logic [11:0] bc);
    return {cid, st, 1'b0, bc};
  endfunction

  function automatic logic [31:0] enc_cpl_dw2(input logic [15:0] rid, input logic [7:0] tag,
                                              input logic [6:0] la);
    return {rid, tag, 1'b0, la};
  endfunction

  function automatic logic [31:0] bswap32(input logic [31:0] v);
    return {v[7:0], v[15:8], v[23:16], v[31:24]};
  endfunction

endpackage
