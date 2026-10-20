// Sequential Transaction Layer engine: dequeue a TLP, validate it, apply posted
// side effects, start Completions, and feed received Completions to the requester.
module pcie_request_handler
  import pcie_pkg::*;
  import pcie_tlp_codec_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  input  logic [2:0]  pkt_avail,
  input  logic [5:0]  head_count [3],
  input  logic        rx_np_ok,
  input  logic        rx_cpl_ok,
  output logic        rd_en,
  output fc_class_e   rd_q,
  input  logic [31:0] rd_data,
  output logic        pop,

  input  logic        mem_space_en,
  input  logic [31:0] bar0,
  input  logic [31:0] bar1,

  output logic [9:0]  cfg_rd_idx,
  input  logic [31:0] cfg_rd_data,
  output logic        cfg_wr_en,
  output logic [9:0]  cfg_wr_idx,
  output logic [3:0]  cfg_wr_be,
  output logic [31:0] cfg_wr_data,
  output logic [7:0]  cfg_wr_bus,
  output logic [4:0]  cfg_wr_dev,

  output logic        mem_rd_bar,
  output logic [9:0]  mem_rd_idx,
  input  logic [31:0] mem_rd_data,
  output logic        mem_wr_en,
  output logic        mem_wr_bar,
  output logic [9:0]  mem_wr_idx,
  output logic [3:0]  mem_wr_be,
  output logic [31:0] mem_wr_data,

  output logic        cpl_start,
  output cpl_ctx_t    cpl_ctx,
  input  logic        cpl_busy,
  input  logic        cpl_done,

  output logic        req_cpl_hdr_valid,
  output tlp_hdr_t    req_cpl_hdr,
  output tlp_kind_e   req_cpl_kind,
  output logic [10:0] req_cpl_payload_dw,
  output logic        req_cpl_data_valid,
  output logic [31:0] req_cpl_data,

  output logic        ev_malformed,
  output logic        ev_poisoned,
  output logic        ev_ur,
  output logic [1:0]  dbg_bar_hit,
  output logic        dbg_rejected,
  output logic        dbg_wrote,
  output logic [3:0]  dbg_wr_be,
  output logic [11:0] dbg_wr_addr
);
  typedef enum logic [2:0] {
    S_IDLE, S_HDR, S_DECIDE, S_PAY, S_CPL, S_WAIT, S_POP
  } state_e;

  state_e      st;
  fc_class_e   qsel;
  logic [5:0]  beats_left;
  logic [2:0]  hdr_i;
  logic [31:0] dw [4];
  tlp_hdr_t    hdr;
  tlp_kind_e   kind;
  logic [2:0]  hdr_dw;
  logic [10:0] payload_dw;
  fc_class_e   fc_cls;
  logic [11:0] data_credits;
  verdict_e    verdict;
  logic [3:0]  reason;
  logic [1:0]  bar_hit;
  logic        hit_any;
  logic [9:0]  dw_off;
  logic [10:0] pay_i;
  logic        apply;

  pcie_tlp_decoder u_dec (
    .dw0(dw[0]), .dw1(dw[1]), .dw2(dw[2]), .dw3(dw[3]),
    .hdr, .kind, .hdr_dw, .payload_dw, .fc_class(fc_cls), .data_credits
  );

  pcie_bar_decoder u_bar (
    .addr(hdr.addr), .mem_space_en, .bar0, .bar1,
    .bar_hit, .hit_any, .dw_offset(dw_off)
  );

  pcie_tlp_validator u_val (
    .hdr, .kind, .hdr_dw, .payload_dw,
    .dw_count(head_count[qsel]),
    .mem_space_en, .bar_hit_any(hit_any),
    .verdict, .reason
  );

  logic pick_valid;
  fc_class_e pick;
  always_comb begin
    pick_valid = 1'b0;
    pick       = FC_P;
    if (rx_cpl_ok) begin
      pick_valid = 1'b1;
      pick       = FC_CPL;
    end else if (rx_np_ok) begin
      pick_valid = 1'b1;
      pick       = FC_NP;
    end else if (pkt_avail[FC_P]) begin
      pick_valid = 1'b1;
      pick       = FC_P;
    end
  end

  assign rd_q = qsel;
  assign cfg_rd_idx = hdr.cfg_reg;
  assign mem_rd_bar = bar_hit[1];
  assign mem_rd_idx = dw_off;
  assign cfg_wr_bus = hdr.cfg_bus;
  assign cfg_wr_dev = hdr.cfg_dev;
  assign cfg_wr_idx = hdr.cfg_reg;
  assign cfg_wr_data = pcie_tlp_codec_pkg::bswap32(rd_data);
  assign mem_wr_data = pcie_tlp_codec_pkg::bswap32(rd_data);
  assign mem_wr_bar  = bar_hit[1];

  function automatic logic [3:0] pay_be(input logic [10:0] idx, input logic [10:0] n,
                                        input logic [3:0] fbe, input logic [3:0] lbe);
    if (n == 11'd1) return fbe;
    if (idx == 11'd0) return fbe;
    if (idx == n - 11'd1) return lbe;
    return 4'hF;
  endfunction

  always_comb begin
    rd_en              = 1'b0;
    pop                = 1'b0;
    cfg_wr_en          = 1'b0;
    cfg_wr_be          = 4'h0;
    mem_wr_en          = 1'b0;
    mem_wr_idx         = dw_off + pay_i[9:0];
    mem_wr_be          = 4'h0;
    cpl_start          = 1'b0;
    cpl_ctx            = '0;
    req_cpl_hdr_valid  = 1'b0;
    req_cpl_hdr        = hdr;
    req_cpl_kind       = kind;
    req_cpl_payload_dw = payload_dw;
    req_cpl_data_valid = 1'b0;
    req_cpl_data       = rd_data;
    ev_malformed       = 1'b0;
    ev_poisoned        = 1'b0;
    ev_ur              = 1'b0;
    dbg_bar_hit        = bar_hit;
    dbg_rejected       = 1'b0;
    dbg_wrote          = 1'b0;
    dbg_wr_be          = 4'h0;
    dbg_wr_addr        = {dw_off, 2'b00};

    case (st)
      S_IDLE: ;
      S_HDR:  rd_en = 1'b1;
      S_DECIDE: begin
        ev_malformed = (verdict == V_MALFORMED);
        ev_poisoned  = (verdict == V_POISONED);
        ev_ur        = (verdict == V_UR);
        dbg_rejected = (verdict != V_OK);
        if (kind == TK_CPL || kind == TK_CPLD || kind == TK_UNSUP_CPL)
          req_cpl_hdr_valid = 1'b1;
      end
      S_PAY: begin
        rd_en = 1'b1;
        if (apply && (kind == TK_MWR)) begin
          mem_wr_en   = 1'b1;
          mem_wr_be   = pay_be(pay_i, payload_dw, hdr.first_be, hdr.last_be);
          dbg_wrote   = 1'b1;
          dbg_wr_be   = mem_wr_be;
          dbg_wr_addr = {dw_off + pay_i[9:0], 2'b00};
        end else if (apply && (kind == TK_CFGWR0)) begin
          cfg_wr_en = 1'b1;
          cfg_wr_be = hdr.first_be;
        end else if (kind == TK_CPLD) begin
          req_cpl_data_valid = 1'b1;
        end
      end
      S_CPL: begin
        cpl_start = 1'b1;
        cpl_ctx.src              = (verdict != V_OK) ? CS_NONE :
                                   (kind == TK_CFGRD0) ? CS_CFG :
                                   (kind == TK_MRD)    ? CS_MEM : CS_NONE;
        cpl_ctx.status           = (verdict == V_UR) ? CPL_UR : CPL_SC;
        cpl_ctx.bar              = bar_hit[1];
        cpl_ctx.addr             = {dw_off, 2'b00};
        cpl_ctx.len_dw           = (kind == TK_MRD) ? ((hdr.length == 10'd0) ? 11'd1024 : {1'b0, hdr.length}) : 11'd1;
        if (kind == TK_MRD && hdr.length == 10'd1 && hdr.first_be == 4'h0)
          cpl_ctx.len_dw = 11'd1;
        cpl_ctx.req_id           = hdr.req_id;
        cpl_ctx.tag              = hdr.tag;
        cpl_ctx.tc               = hdr.tc;
        cpl_ctx.attr             = hdr.attr[1:0];
        cpl_ctx.byte_count       = (kind == TK_MRD) ? req_byte_count(cpl_ctx.len_dw, hdr.first_be, hdr.last_be) : 13'd4;
        if (kind == TK_MRD && hdr.length == 10'd1 && hdr.first_be == 4'h0)
          cpl_ctx.byte_count = 13'd1;
        cpl_ctx.lower_addr       = (kind == TK_MRD) ? req_lower_addr(hdr.addr, hdr.first_be) : 7'd0;
        cpl_ctx.lead_bytes_valid = (kind == TK_MRD);
        cpl_ctx.lead_bytes       = be_lead(hdr.first_be);
      end
      S_POP: pop = 1'b1;
      default: ;
    endcase
  end

  logic need_cpl;
  assign need_cpl = (kind == TK_MRD) || (kind == TK_CFGRD0) || (kind == TK_CFGWR0) ||
                    (verdict == V_UR && (kind == TK_UNSUP_NP || kind == TK_MRD ||
                                         kind == TK_CFGRD0 || kind == TK_CFGWR0));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st         <= S_IDLE;
      qsel       <= FC_P;
      beats_left <= '0;
      hdr_i      <= '0;
      pay_i      <= '0;
      apply      <= 1'b0;
      for (int i = 0; i < 4; i++) dw[i] <= '0;
    end else if (flush) begin
      st <= S_IDLE;
    end else begin
      case (st)
        S_IDLE: if (pick_valid && !cpl_busy) begin
          qsel       <= pick;
          beats_left <= head_count[pick];
          hdr_i      <= '0;
          pay_i      <= '0;
          st         <= S_HDR;
        end
        S_HDR: begin
          dw[hdr_i] <= rd_data;
          hdr_i     <= hdr_i + 1'b1;
          beats_left <= beats_left - 1'b1;
          if (hdr_i == 3'd2 && !rd_data[29] && hdr_i == 3'd2) begin
            // decided after 3rd beat using already-latched dw0 fmt; use dw[0]
          end
          if ((hdr_i == 3'd2 && !dw[0][29]) || (hdr_i == 3'd3 && dw[0][29]))
            st <= S_DECIDE;
        end
        S_DECIDE: begin
          apply <= (verdict == V_OK);
          if ((kind == TK_CPL || kind == TK_CPLD || kind == TK_UNSUP_CPL) && payload_dw != 0)
            st <= S_PAY;
          else if (verdict == V_OK && (kind == TK_MWR || kind == TK_CFGWR0) && payload_dw != 0)
            st <= S_PAY;
          else if (need_cpl && (verdict == V_OK || verdict == V_UR))
            st <= S_CPL;
          else
            st <= (beats_left == 0) ? S_POP : S_PAY;
        end
        S_PAY: begin
          pay_i      <= pay_i + 1'b1;
          beats_left <= beats_left - 1'b1;
          if (beats_left == 6'd1) begin
            if (need_cpl && apply && (kind == TK_CFGWR0 || kind == TK_MRD || kind == TK_CFGRD0))
              st <= S_CPL;
            else if (need_cpl && verdict == V_UR)
              st <= S_CPL;
            else
              st <= S_POP;
          end
        end
        S_CPL:  st <= S_WAIT;
        S_WAIT: if (cpl_done || !cpl_busy) st <= S_POP;
        S_POP:  st <= S_IDLE;
        default: st <= S_IDLE;
      endcase
    end
  end
endmodule
