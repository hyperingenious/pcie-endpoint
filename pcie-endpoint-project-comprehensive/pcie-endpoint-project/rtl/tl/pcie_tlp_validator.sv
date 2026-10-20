// Receive-side TLP validation for the supported subset. Produces one verdict; checks are
// evaluated in this order and the first failing rule wins.
//
// Malformed (discarded, no Completion, sticky error):
//   reserved Fmt/Type encodings and TLP Prefixes; DW count shorter than the header;
//   Length inconsistent with the received DW count; payload above Max_Payload_Size (128 B);
//   TD=1 (ECRC not supported); TH or LN set; AT != 00b;
//   Memory Request crossing a 4 KB boundary; Byte Enable rules (Length 1 with non-zero
//   Last BE, Length > 1 with a zero First/Last BE);
//   Configuration Request with Length != 1, TC != 0 or non-zero Last BE.
// Poisoned (EP=1): discarded, no Completion, sticky error.
// Unsupported Request (Non-Posted: Completion with UR status; Posted: Status bit only):
//   I/O, Configuration Type 1, MRdLk, AtomicOps, Messages; request with TC != 0 or IDO set;
//   Memory Request with Memory Space disabled or no BAR hit; Configuration Request to
//   Function != 0.
// Completions are only checked for structure here; the requester judges their contents.
module pcie_tlp_validator
  import pcie_pkg::*;
(
  input  tlp_hdr_t    hdr,
  input  tlp_kind_e   kind,
  input  logic [2:0]  hdr_dw,
  input  logic [10:0] payload_dw,
  input  logic [5:0]  dw_count,
  input  logic        mem_space_en,
  input  logic        bar_hit_any,
  output verdict_e    verdict,
  output logic [3:0]  reason
);
  logic        is_mem;
  logic        is_cfg;
  logic        is_cpl;
  logic [11:0] expect_dw;
  logic [10:0] len_dw;
  logic [13:0] end_byte;

  assign is_mem    = (kind == TK_MRD) || (kind == TK_MWR);
  assign is_cfg    = (kind == TK_CFGRD0) || (kind == TK_CFGWR0);
  assign is_cpl    = (kind == TK_CPL) || (kind == TK_CPLD) || (kind == TK_UNSUP_CPL);
  assign expect_dw = {9'd0, hdr_dw} + {1'b0, payload_dw};
  assign len_dw    = (hdr.length == 10'd0) ? 11'd1024 : {1'b0, hdr.length};
  assign end_byte  = {2'b00, hdr.addr[11:0]} + {1'b0, len_dw, 2'b00};

  always_comb begin
    verdict = V_OK;
    reason  = R_NONE;
    if (kind == TK_MALFORMED) begin
      verdict = V_MALFORMED; reason = R_ENCODING;
    end else if ({3'd0, dw_count} < {3'd0, hdr_dw}) begin
      verdict = V_MALFORMED; reason = R_TRUNCATED;
    end else if (hdr.td) begin
      verdict = V_MALFORMED; reason = R_DIGEST;
    end else if ({6'd0, dw_count} != expect_dw) begin
      verdict = V_MALFORMED; reason = R_LENGTH;
    end else if (payload_dw > 11'(MAX_PAYLOAD_DW)) begin
      verdict = V_MALFORMED; reason = R_MPS;
    end else if (hdr.th || hdr.ln || hdr.at != 2'b00) begin
      verdict = V_MALFORMED; reason = R_HDR_FIELD;
    end else if (is_mem && end_byte > 14'd4096) begin
      verdict = V_MALFORMED; reason = R_4K_CROSS;
    end else if (is_mem && ((len_dw == 11'd1 && hdr.last_be != 4'h0) ||
                            (len_dw != 11'd1 && (hdr.first_be == 4'h0 || hdr.last_be == 4'h0)))) begin
      verdict = V_MALFORMED; reason = R_BYTE_EN;
    end else if (is_cfg && (hdr.length != 10'd1 || hdr.tc != 3'd0 || hdr.last_be != 4'h0)) begin
      verdict = V_MALFORMED; reason = R_CFG_RULE;
    end else if (hdr.ep) begin
      verdict = V_POISONED; reason = R_POISONED;
    end else if (is_cpl) begin
      verdict = V_OK; reason = R_NONE;
    end else if (kind == TK_UNSUP_NP || kind == TK_UNSUP_P) begin
      verdict = V_UR; reason = R_UR_TYPE;
    end else if (hdr.tc != 3'd0 || hdr.attr[2]) begin
      verdict = V_UR; reason = R_UR_TC_IDO;
    end else if (is_mem && !mem_space_en) begin
      verdict = V_UR; reason = R_UR_MSE;
    end else if (is_mem && !bar_hit_any) begin
      verdict = V_UR; reason = R_UR_BAR;
    end else if (is_cfg && hdr.cfg_func != 3'd0) begin
      verdict = V_UR; reason = R_UR_FUNC;
    end
  end
endmodule
