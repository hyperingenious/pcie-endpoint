// PCIe Endpoint project package: protocol encodings, header layout, limits and helpers.
//
// Link packet abstraction (see docs/architecture.md, "Interface contract"):
//   TLP on the link  = beat0 {16'h0, 4'h0, seq[11:0]}, TLP DWs..., final beat LCRC[31:0]
//   Every beat is a byte stream with the first-transmitted byte in [31:24].
//   Payload bytes are carried in address order (byte lane 0 first), so a payload
//   beat is the byte-swapped register value.
//   DLLP on the link = one 48-bit beat {type, byte1, byte2, byte3, crc16}.
package pcie_pkg;

  localparam int SEQ_W          = 12;
  localparam int MAX_PAYLOAD_DW = 32;                          // MPS = 128 B
  localparam int MAX_READ_DW    = 1024;                        // Length field limit
  localparam int MAX_HDR_DW     = 4;
  localparam int MAX_TLP_DW     = MAX_HDR_DW + MAX_PAYLOAD_DW + 1; // + optional digest
  localparam int RCB_BYTES      = 64;
  localparam int BAR_BYTES      = 4096;

  // Fmt encodings
  localparam logic [2:0] FMT_3DW_ND = 3'b000;
  localparam logic [2:0] FMT_4DW_ND = 3'b001;
  localparam logic [2:0] FMT_3DW_D  = 3'b010;
  localparam logic [2:0] FMT_4DW_D  = 3'b011;
  localparam logic [2:0] FMT_PREFIX = 3'b100;

  // Type encodings
  localparam logic [4:0] TYP_MEM      = 5'b00000;
  localparam logic [4:0] TYP_MEMLK    = 5'b00001;
  localparam logic [4:0] TYP_IO       = 5'b00010;
  localparam logic [4:0] TYP_CFG0     = 5'b00100;
  localparam logic [4:0] TYP_CFG1     = 5'b00101;
  localparam logic [4:0] TYP_CPL      = 5'b01010;
  localparam logic [4:0] TYP_CPLLK    = 5'b01011;
  localparam logic [4:0] TYP_FETCHADD = 5'b01100;
  localparam logic [4:0] TYP_SWAP     = 5'b01101;
  localparam logic [4:0] TYP_CAS      = 5'b01110;

  typedef enum logic [3:0] {
    TK_MRD       = 4'd0,
    TK_MWR       = 4'd1,
    TK_CFGRD0    = 4'd2,
    TK_CFGWR0    = 4'd3,
    TK_CPL       = 4'd4,
    TK_CPLD      = 4'd5,
    TK_UNSUP_NP  = 4'd6,  // IO, Cfg Type 1, MRdLk, AtomicOps: UR Completion
    TK_UNSUP_P   = 4'd7,  // Msg/MsgD: UR, no Completion
    TK_UNSUP_CPL = 4'd8,  // CplLk/CplDLk: Unexpected Completion
    TK_MALFORMED = 4'd9   // reserved Fmt/Type, TLP Prefix
  } tlp_kind_e;

  typedef enum logic [1:0] {
    FC_P   = 2'd0,
    FC_NP  = 2'd1,
    FC_CPL = 2'd2
  } fc_class_e;

  typedef enum logic [2:0] {
    CPL_SC  = 3'b000,
    CPL_UR  = 3'b001,
    CPL_CRS = 3'b010,
    CPL_CA  = 3'b100
  } cpl_status_e;

  typedef enum logic [1:0] {
    DL_INACTIVE = 2'd0,
    DL_INIT     = 2'd1,
    DL_ACTIVE   = 2'd2
  } dl_state_e;

  typedef enum logic [2:0] {
    LT_DETECT   = 3'd0,
    LT_POLLING  = 3'd1,
    LT_CONFIG   = 3'd2,
    LT_L0       = 3'd3,
    LT_RECOVERY = 3'd4,
    LT_FAILED   = 3'd5
  } ltssm_state_e;

  typedef enum logic [1:0] {
    V_OK        = 2'd0,
    V_MALFORMED = 2'd1,
    V_UR        = 2'd2,
    V_POISONED  = 2'd3
  } verdict_e;

  // Validator reason codes (first failing rule)
  localparam logic [3:0] R_NONE      = 4'd0;
  localparam logic [3:0] R_ENCODING  = 4'd1;
  localparam logic [3:0] R_TRUNCATED = 4'd2;
  localparam logic [3:0] R_DIGEST    = 4'd3;
  localparam logic [3:0] R_LENGTH    = 4'd4;
  localparam logic [3:0] R_MPS       = 4'd5;
  localparam logic [3:0] R_HDR_FIELD = 4'd6;
  localparam logic [3:0] R_4K_CROSS  = 4'd7;
  localparam logic [3:0] R_BYTE_EN   = 4'd8;
  localparam logic [3:0] R_CFG_RULE  = 4'd9;
  localparam logic [3:0] R_POISONED  = 4'd10;
  localparam logic [3:0] R_UR_TYPE   = 4'd11;
  localparam logic [3:0] R_UR_TC_IDO = 4'd12;
  localparam logic [3:0] R_UR_MSE    = 4'd13;
  localparam logic [3:0] R_UR_BAR    = 4'd14;
  localparam logic [3:0] R_UR_FUNC   = 4'd15;

  // Flow-control credits advertised by the Endpoint receiver (VC0). Completion
  // credits are advertised as infinite (0), as required of an Endpoint.
  localparam logic [7:0]  ADV_PH   = 8'd8;
  localparam logic [11:0] ADV_PD   = 12'd32;
  localparam logic [7:0]  ADV_NPH  = 8'd8;
  localparam logic [11:0] ADV_NPD  = 12'd8;
  localparam logic [7:0]  ADV_CPLH = 8'd0;
  localparam logic [11:0] ADV_CPLD = 12'd0;

  // BAR0 register map (byte offsets). 0x100-0xFFF of BAR0 and all of BAR1 are
  // byte-writable storage; BAR1 is also the DMA local buffer.
  localparam logic [11:0] REG_ID          = 12'h000;  // RO  32'h5043_4945
  localparam logic [11:0] REG_SCRATCH     = 12'h004;  // RW
  localparam logic [11:0] REG_STATUS      = 12'h008;  // [0] DMA busy RO, [7:1] RW1C (see register file)
  localparam logic [11:0] REG_ERR_STATUS  = 12'h00C;  // sticky RW1C error flags
  localparam logic [11:0] REG_DMA_HADDR_L = 12'h010;  // RW, [1:0] RO 0
  localparam logic [11:0] REG_DMA_HADDR_H = 12'h014;  // RW, non-zero selects 4DW headers
  localparam logic [11:0] REG_DMA_LADDR   = 12'h018;  // RW, BAR1 byte offset [11:2]
  localparam logic [11:0] REG_DMA_LEN     = 12'h01C;  // RW, DW count [10:0], 1..1024
  localparam logic [11:0] REG_DMA_CTRL    = 12'h020;  // [0] start (self-clearing), [1] dir 1=read host, [2] RO, [3] NS
  localparam logic [11:0] REG_CPL_TIMEOUT = 12'h024;  // RW cycles [23:0], default 2000
  localparam logic [11:0] REG_MSI_DOORBELL= 12'h028;  // WO, any enabled byte rings
  localparam logic [11:0] REG_TAG_STATUS  = 12'h02C;  // RO [7:0] tags in use, [10:8] outstanding reads
  localparam logic [11:0] REG_CPL_ERR_LOG = 12'h030;  // RO last bad Completion {status, kind[3:0], tag}
  localparam logic [11:0] BAR0_MEM_BASE   = 12'h100;
  localparam logic [31:0] BAR0_ID_VALUE   = 32'h5043_4945;
  localparam int unsigned CPL_TIMEOUT_DEFAULT = 2000;
  localparam int unsigned NUM_TAGS        = 8;
  localparam int unsigned MAX_OUTSTANDING = 4;
  localparam int unsigned REPLAY_DEPTH    = 8;
  localparam int unsigned RETRY_LIMIT     = 4;
  localparam int unsigned ACK_LATENCY     = 4;
  localparam int unsigned REPLAY_TIMEOUT  = 64;

  // Endpoint error flags (REG_ERR_STATUS bit positions)
  localparam int ERR_MALFORMED   = 0;
  localparam int ERR_POISONED    = 1;
  localparam int ERR_UR          = 2;
  localparam int ERR_RX_OVERFLOW = 3;
  localparam int ERR_FC_PROTOCOL = 4;
  localparam int ERR_BAD_LCRC    = 5;
  localparam int ERR_BAD_DLLP    = 6;
  localparam int ERR_REPLAY_ROLL = 7;
  localparam int ERR_REPLAY_TMO  = 8;
  localparam int ERR_CPL_TIMEOUT = 9;
  localparam int ERR_UNEXP_CPL   = 10;
  localparam int ERR_BAD_CPL     = 11;
  localparam int ERR_CPL_STATUS  = 12;
  localparam int ERR_DLLP_PROTO  = 13;
  localparam int NUM_ERR         = 14;

  // DLLP type byte (VC0 only; low 3 bits carry the VC ID for FC DLLPs)
  localparam logic [7:0] DLLP_ACK         = 8'h00;
  localparam logic [7:0] DLLP_NAK         = 8'h10;
  localparam logic [7:0] DLLP_INITFC1_P   = 8'h40;
  localparam logic [7:0] DLLP_INITFC1_NP  = 8'h50;
  localparam logic [7:0] DLLP_INITFC1_CPL = 8'h60;
  localparam logic [7:0] DLLP_INITFC2_P   = 8'hC0;
  localparam logic [7:0] DLLP_INITFC2_NP  = 8'hD0;
  localparam logic [7:0] DLLP_INITFC2_CPL = 8'hE0;
  localparam logic [7:0] DLLP_UPDFC_P     = 8'h80;
  localparam logic [7:0] DLLP_UPDFC_NP    = 8'h90;
  localparam logic [7:0] DLLP_UPDFC_CPL   = 8'hA0;

  typedef struct packed {
    logic [2:0]  fmt;
    logic [4:0]  typ;
    logic [2:0]  tc;
    logic [2:0]  attr;        // {IDO, RO, NS}
    logic        th;
    logic        ln;
    logic        td;
    logic        ep;
    logic [1:0]  at;
    logic [9:0]  length;
    logic [15:0] req_id;
    logic [7:0]  tag;
    logic [3:0]  last_be;
    logic [3:0]  first_be;
    logic [63:0] addr;        // byte address, [1:0] = 0
    logic [7:0]  cfg_bus;
    logic [4:0]  cfg_dev;
    logic [2:0]  cfg_func;
    logic [9:0]  cfg_reg;     // DW index {ext_reg, reg}
    logic [15:0] cpl_id;
    logic [2:0]  cpl_status;
    logic        bcm;
    logic [11:0] byte_count;
    logic [6:0]  lower_addr;
  } tlp_hdr_t;

  // Completion source selected by the request handler
  localparam logic [1:0] CS_NONE = 2'd0;   // Cpl without data
  localparam logic [1:0] CS_MEM  = 2'd1;   // CplD from BAR storage/registers
  localparam logic [1:0] CS_CFG  = 2'd2;   // CplD from Configuration Space

  typedef struct packed {
    logic [1:0]  src;
    logic [2:0]  status;
    logic        bar;
    logic [11:0] addr;
    logic [10:0] len_dw;
    logic [15:0] req_id;
    logic [7:0]  tag;
    logic [2:0]  tc;
    logic [1:0]  attr;        // {RO, NS}
    logic [12:0] byte_count;  // Byte Count of the first Completion
    logic [6:0]  lower_addr;  // Lower Address of the first Completion
    logic        lead_bytes_valid;
    logic [1:0]  lead_bytes;  // disabled leading bytes in the first DW
  } cpl_ctx_t;

  function automatic logic fmt_has_data(input logic [2:0] fmt);
    return (fmt == FMT_3DW_D) || (fmt == FMT_4DW_D);
  endfunction

  function automatic logic fmt_is_4dw(input logic [2:0] fmt);
    return fmt[0];
  endfunction

  function automatic tlp_kind_e tlp_classify(input logic [2:0] fmt, input logic [4:0] typ);
    tlp_kind_e k;
    k = TK_MALFORMED;
    if (fmt[2]) begin
      k = TK_MALFORMED;                                  // TLP Prefix: not supported
    end else if (typ == TYP_MEM) begin
      k = fmt[1] ? TK_MWR : TK_MRD;
    end else if (typ == TYP_MEMLK) begin
      k = fmt[1] ? TK_MALFORMED : TK_UNSUP_NP;
    end else if (typ == TYP_IO || typ == TYP_CFG1) begin
      k = fmt[0] ? TK_MALFORMED : TK_UNSUP_NP;
    end else if (typ == TYP_CFG0) begin
      k = fmt[0] ? TK_MALFORMED : (fmt[1] ? TK_CFGWR0 : TK_CFGRD0);
    end else if (typ == TYP_CPL) begin
      k = fmt[0] ? TK_MALFORMED : (fmt[1] ? TK_CPLD : TK_CPL);
    end else if (typ == TYP_CPLLK) begin
      k = fmt[0] ? TK_MALFORMED : TK_UNSUP_CPL;
    end else if (typ == TYP_FETCHADD || typ == TYP_SWAP || typ == TYP_CAS) begin
      k = fmt[1] ? TK_UNSUP_NP : TK_MALFORMED;
    end else if (typ[4:3] == 2'b10) begin
      k = fmt[0] ? TK_UNSUP_P : TK_MALFORMED;            // Messages always use 4DW headers
    end
    return k;
  endfunction

  function automatic fc_class_e fc_class_of(input logic [2:0] fmt, input logic [4:0] typ);
    fc_class_e c;
    if (typ == TYP_CPL || typ == TYP_CPLLK)
      c = FC_CPL;
    else if ((typ == TYP_MEM && fmt[1]) || typ[4:3] == 2'b10)
      c = FC_P;
    else
      c = FC_NP;
    return c;
  endfunction

  function automatic logic [10:0] payload_dw_of(input logic [2:0] fmt, input logic [9:0] length);
    if (!fmt_has_data(fmt)) return 11'd0;
    return (length == 10'd0) ? 11'd1024 : {1'b0, length};
  endfunction

  // Flow-control data credits: one unit per 16 bytes of payload
  function automatic logic [11:0] data_credits_of(input logic [2:0] fmt, input logic [9:0] length);
    logic [10:0] dw;
    dw = payload_dw_of(fmt, length);
    return {1'b0, (dw + 11'd3) >> 2};
  endfunction

  // Index of the lowest enabled byte (0 for an empty mask)
  function automatic logic [1:0] be_lead(input logic [3:0] be);
    if (be[0]) return 2'd0;
    if (be[1]) return 2'd1;
    if (be[2]) return 2'd2;
    if (be[3]) return 2'd3;
    return 2'd0;
  endfunction

  // Number of disabled bytes above the highest enabled byte
  function automatic logic [1:0] be_trail(input logic [3:0] be);
    if (be[3]) return 2'd0;
    if (be[2]) return 2'd1;
    if (be[1]) return 2'd2;
    if (be[0]) return 2'd3;
    return 2'd0;
  endfunction

  // Total Byte Count of a Memory Read Request (13 bits: 4096 is legal)
  function automatic logic [12:0] req_byte_count(input logic [10:0] len_dw, input logic [3:0] first_be,
                                                 input logic [3:0] last_be);
    logic [12:0] bc;
    if (len_dw == 11'd1) begin
      if (first_be == 4'b0000) bc = 13'd1;
      else bc = 13'd4 - {11'd0, be_lead(first_be)} - {11'd0, be_trail(first_be)};
    end else begin
      bc = {len_dw, 2'b00} - {11'd0, be_lead(first_be)} - {11'd0, be_trail(last_be)};
    end
    return bc;
  endfunction

  function automatic logic [6:0] req_lower_addr(input logic [63:0] addr, input logic [3:0] first_be);
    return {addr[6:2], be_lead(first_be)};
  endfunction

endpackage
