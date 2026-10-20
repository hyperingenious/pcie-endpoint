// BAR-mapped storage and BAR0 control/status registers.
//
// BAR0 0x000-0x0FF: registers (map in pcie_pkg, REG_*); undefined offsets read 0, writes ignored.
// BAR0 0x100-0xFFF: byte-writable storage.
// BAR1 0x000-0xFFF: byte-writable storage, also the DMA local buffer.
//
// REG_STATUS bits: [0] DMA busy (RO), [1] DMA done, [2] DMA error, [3] MSI sent,
//                  [4] MSI blocked (doorbell while MSI disabled or Bus Master clear),
//                  [5] MSI pending (RO); [4:1] are RW1C.
// The engine write port has priority over the DMA write port for the same BAR1 DW.
module pcie_register_file
  import pcie_pkg::*;
(
  input  logic                 clk,
  input  logic                 rst_n,

  input  logic                 rd_bar,
  input  logic [9:0]           rd_idx,
  output logic [31:0]          rd_data,

  input  logic                 wr_en,
  input  logic                 wr_bar,
  input  logic [9:0]           wr_idx,
  input  logic [3:0]           wr_be,
  input  logic [31:0]          wr_data,

  input  logic [9:0]           dma_rd_idx,
  output logic [31:0]          dma_rd_data,
  input  logic                 dma_wr_en,
  input  logic [9:0]           dma_wr_idx,
  input  logic [31:0]          dma_wr_data,

  output logic [63:0]          dma_haddr,
  output logic [9:0]           dma_laddr,
  output logic [10:0]          dma_len,
  output logic                 dma_start,
  output logic                 dma_dir,
  output logic                 dma_ro,
  output logic                 dma_ns,
  output logic [23:0]          cpl_timeout,
  output logic                 msi_doorbell,

  input  logic                 dma_busy,
  input  logic                 dma_done_set,
  input  logic                 dma_err_set,
  input  logic                 msi_sent_set,
  input  logic                 msi_blocked_set,
  input  logic                 msi_pending,
  input  logic [7:0]           tags_in_use,
  input  logic [2:0]           outstanding,
  input  logic [15:0]          cpl_err_log,
  input  logic [NUM_ERR-1:0]   err_status,
  output logic [NUM_ERR-1:0]   err_clear
);
  logic [31:0] mem0 [0:1023];
  logic [31:0] mem1 [0:1023];

  logic [31:0] scratch;
  logic [3:0]  status_w1c;
  logic [31:0] haddr_l;
  logic [31:0] haddr_h;
  logic [9:0]  laddr;
  logic [10:0] len;
  logic [3:1]  ctrl;
  logic [23:0] timeout;

  logic [31:0] bm;
  logic        reg_wr;
  assign bm     = {{8{wr_be[3]}}, {8{wr_be[2]}}, {8{wr_be[1]}}, {8{wr_be[0]}}};
  assign reg_wr = wr_en && !wr_bar && (wr_idx < 10'd64);

  assign dma_haddr   = {haddr_h, haddr_l[31:2], 2'b00};
  assign dma_laddr   = laddr;
  assign dma_len     = len;
  assign dma_dir     = ctrl[1];
  assign dma_ro      = ctrl[2];
  assign dma_ns      = ctrl[3];
  assign cpl_timeout = timeout;

  assign dma_start    = reg_wr && (wr_idx == 10'(REG_DMA_CTRL >> 2)) && wr_be[0] && wr_data[0];
  assign msi_doorbell = reg_wr && (wr_idx == 10'(REG_MSI_DOORBELL >> 2)) && (|wr_be);
  assign err_clear    = (reg_wr && (wr_idx == 10'(REG_ERR_STATUS >> 2))) ? wr_data[NUM_ERR-1:0] & bm[NUM_ERR-1:0]
                                                                         : '0;

  function automatic logic [31:0] reg_read(input logic [9:0] idx);
    logic [31:0] v;
    v = 32'h0;
    case ({idx, 2'b00})
      12'(REG_ID):          v = BAR0_ID_VALUE;
      12'(REG_SCRATCH):     v = scratch;
      12'(REG_STATUS):      v = {26'h0, msi_pending, status_w1c, dma_busy};
      12'(REG_ERR_STATUS):  v = 32'(err_status);
      12'(REG_DMA_HADDR_L): v = {haddr_l[31:2], 2'b00};
      12'(REG_DMA_HADDR_H): v = haddr_h;
      12'(REG_DMA_LADDR):   v = {20'h0, laddr, 2'b00};
      12'(REG_DMA_LEN):     v = {21'h0, len};
      12'(REG_DMA_CTRL):    v = {28'h0, ctrl, 1'b0};
      12'(REG_CPL_TIMEOUT): v = {8'h0, timeout};
      12'(REG_TAG_STATUS):  v = {21'h0, outstanding, tags_in_use};
      12'(REG_CPL_ERR_LOG): v = {16'h0, cpl_err_log};
      default:              v = 32'h0;
    endcase
    return v;
  endfunction

  always_comb begin
    if (rd_bar)              rd_data = mem1[rd_idx];
    else if (rd_idx < 10'd64) rd_data = reg_read(rd_idx);
    else                     rd_data = mem0[rd_idx];
  end
  assign dma_rd_data = mem1[dma_rd_idx];

  function automatic logic [31:0] merge(input logic [31:0] old, input logic [31:0] wd, input logic [31:0] m);
    return (old & ~m) | (wd & m);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 1024; i++) begin
        mem0[i] <= 32'h0;
        mem1[i] <= 32'h0;
      end
    end else begin
      if (dma_wr_en && !(wr_en && wr_bar && wr_idx == dma_wr_idx))
        mem1[dma_wr_idx] <= dma_wr_data;
      if (wr_en && wr_bar)
        mem1[wr_idx] <= merge(mem1[wr_idx], wr_data, bm);
      else if (wr_en && wr_idx >= 10'd64)
        mem0[wr_idx] <= merge(mem0[wr_idx], wr_data, bm);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scratch    <= 32'h0;
      status_w1c <= 4'h0;
      haddr_l    <= 32'h0;
      haddr_h    <= 32'h0;
      laddr      <= 10'h0;
      len        <= 11'h0;
      ctrl       <= 3'h0;
      timeout    <= 24'(CPL_TIMEOUT_DEFAULT);
    end else begin
      logic [3:0] st;
      st = status_w1c;
      if (reg_wr) begin
        case ({wr_idx, 2'b00})
          12'(REG_SCRATCH):     scratch <= merge(scratch, wr_data, bm);
          12'(REG_STATUS):      st = st & ~(wr_data[4:1] & bm[4:1]);
          12'(REG_DMA_HADDR_L): haddr_l <= merge(haddr_l, wr_data, bm & 32'hFFFF_FFFC);
          12'(REG_DMA_HADDR_H): haddr_h <= merge(haddr_h, wr_data, bm);
          12'(REG_DMA_LADDR):   laddr   <= 10'(merge({20'h0, laddr, 2'b00}, wr_data, bm & 32'h0000_0FFC) >> 2);
          12'(REG_DMA_LEN):     len     <= 11'(merge({21'h0, len}, wr_data, bm & 32'h0000_07FF));
          12'(REG_DMA_CTRL):    ctrl    <= 3'(merge({28'h0, ctrl, 1'b0}, wr_data, bm & 32'h0000_000E) >> 1);
          12'(REG_CPL_TIMEOUT): timeout <= 24'(merge({8'h0, timeout}, wr_data, bm & 32'h00FF_FFFF));
          default: ;
        endcase
      end
      if (dma_done_set)    st[0] = 1'b1;
      if (dma_err_set)     st[1] = 1'b1;
      if (msi_sent_set)    st[2] = 1'b1;
      if (msi_blocked_set) st[3] = 1'b1;
      status_w1c <= st;
    end
  end
endmodule
