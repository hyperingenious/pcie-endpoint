// Combinational decode of a captured TLP header (3 or 4 DWs) into fields and
// derived properties used by validation, routing and flow-control accounting.
module pcie_tlp_decoder
  import pcie_pkg::*;
  import pcie_tlp_codec_pkg::*;
(
  input  logic [31:0] dw0,
  input  logic [31:0] dw1,
  input  logic [31:0] dw2,
  input  logic [31:0] dw3,
  output tlp_hdr_t    hdr,
  output tlp_kind_e   kind,
  output logic [2:0]  hdr_dw,
  output logic [10:0] payload_dw,
  output fc_class_e   fc_class,
  output logic [11:0] data_credits
);
  assign hdr          = decode_hdr(dw0, dw1, dw2, dw3);
  assign kind         = tlp_classify(dw0[31:29], dw0[28:24]);
  assign hdr_dw       = fmt_is_4dw(dw0[31:29]) ? 3'd4 : 3'd3;
  assign payload_dw   = payload_dw_of(dw0[31:29], dw0[9:0]);
  assign fc_class     = fc_class_of(dw0[31:29], dw0[28:24]);
  assign data_credits = data_credits_of(dw0[31:29], dw0[9:0]);
endmodule
