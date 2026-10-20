// Type 0 Configuration Space for a single-Function PCIe Endpoint.
//
// Map (byte offset / DW index):
//   00h/0   Device ID | Vendor ID                       RO
//   04h/1   Status | Command                            Command[1,2,6,8] RW; Status[15,14,13,12,11,8] RW1C;
//                                                       Status[4] Capabilities List = 1
//   08h/2   Class Code | Revision ID                    RO
//   0Ch/3   BIST | Header Type 00h | Lat Timer | CLS    Cache Line Size RW (no effect), rest RO 0
//   10h/4   BAR0  32-bit memory, non-prefetchable, 4 KiB ([31:12] RW)
//   14h/5   BAR1  32-bit memory, non-prefetchable, 4 KiB ([31:12] RW)
//   18h-24h BAR2-5 not implemented (0)
//   2Ch/11  Subsystem ID | Subsystem Vendor ID          RO
//   34h/13  Capabilities Pointer = 40h                  RO
//   3Ch/15  Interrupt Pin 0 (no INTx) | Interrupt Line  Interrupt Line RW
//   40h/16  MSI: Message Control | Next 60h | ID 05h    Enable[0], MME[6:4] RW; 32-bit, 1 vector,
//                                                       per-vector masking capable
//   44h/17  MSI Message Address [31:2] RW
//   48h/18  MSI Message Data [15:0] RW
//   4Ch/19  MSI Mask Bits [0] RW
//   50h/20  MSI Pending Bits [0] RO
//   60h/24  PCI Express Capability (v2, Endpoint), Next 00h, ID 10h
//   64h/25  Device Capabilities: MPS 128 B, Role-Based Error Reporting
//   68h/26  Device Status | Device Control              Control RW (see mask); Status[3:0] RW1C,
//                                                       Status[5] Transactions Pending RO
//   6Ch/27  Link Capabilities: 16 GT/s, x1 (behavioral link; no electrical claim)
//   70h/28  Link Status | Link Control                  Control[1:0,3,6,7] RW; Status 16 GT/s x1
//   8Ch/35  Link Capabilities 2: speeds 2.5-16 GT/s
//   90h/36  Link Status 2 | Link Control 2              Target Link Speed RW
//   All other offsets, including Extended Configuration Space (100h+), read 0 and ignore writes.
module pcie_config_space
  import pcie_pkg::*;
#(
  parameter logic [15:0] VENDOR_ID    = 16'h1234,
  parameter logic [15:0] DEVICE_ID    = 16'h0001,
  parameter logic [7:0]  REVISION_ID  = 8'h01,
  parameter logic [23:0] CLASS_CODE   = 24'hFF0000,
  parameter logic [15:0] SUBSYS_VID   = 16'h1234,
  parameter logic [15:0] SUBSYS_ID    = 16'h0001,
  parameter logic [15:0] DEFAULT_BDF  = 16'h0100
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic [9:0]  rd_idx,
  output logic [31:0] rd_data,
  input  logic        wr_en,
  input  logic [9:0]  wr_idx,
  input  logic [3:0]  wr_be,
  input  logic [31:0] wr_data,
  input  logic [7:0]  wr_bus,
  input  logic [4:0]  wr_dev,

  input  logic        set_detected_parity,
  input  logic        set_rcvd_master_abort,
  input  logic        set_rcvd_target_abort,
  input  logic        set_master_data_parity,
  input  logic        set_ced,
  input  logic        set_nfed,
  input  logic        set_fed,
  input  logic        set_urd,
  input  logic        transactions_pending,
  input  logic        msi_pending,

  output logic        mem_space_en,
  output logic        bus_master_en,
  output logic        parity_err_resp,
  output logic [31:0] bar0,
  output logic [31:0] bar1,
  output logic        msi_enable,
  output logic [31:0] msi_addr,
  output logic [15:0] msi_data,
  output logic        msi_mask,
  output logic [15:0] completer_id,
  output logic [2:0]  max_read_req
);
  logic [15:0] command;
  logic [15:0] status;
  logic [7:0]  cache_line;
  logic [19:0] bar0_hi;
  logic [19:0] bar1_hi;
  logic [7:0]  int_line;
  logic        msi_en;
  logic [2:0]  msi_mme;
  logic [29:0] msi_addr_hi;
  logic [15:0] msi_data_r;
  logic        msi_mask_r;
  logic [15:0] dev_ctrl;
  logic [3:0]  dev_status;
  logic [7:0]  link_ctrl;
  logic [3:0]  target_speed;
  logic [7:0]  bus_num;
  logic [4:0]  dev_num;

  localparam logic [15:0] CMD_RW_MASK      = 16'h0146;
  localparam logic [15:0] STATUS_W1C_MASK  = 16'hF900;
  localparam logic [15:0] DEVCTL_RW_MASK   = 16'h78FF;
  localparam logic [15:0] DEVCTL_RESET     = 16'h0810;  // RO enable, No Snoop enable, MPS/MRRS 128 B
  localparam logic [7:0]  LNKCTL_RW_MASK   = 8'hCB;

  assign mem_space_en    = command[1];
  assign bus_master_en   = command[2];
  assign parity_err_resp = command[6];
  assign bar0            = {bar0_hi, 12'h000};
  assign bar1            = {bar1_hi, 12'h000};
  assign msi_enable      = msi_en;
  assign msi_addr        = {msi_addr_hi, 2'b00};
  assign msi_data        = msi_data_r;
  assign msi_mask        = msi_mask_r;
  assign completer_id    = {bus_num, dev_num, 3'b000};
  assign max_read_req    = dev_ctrl[14:12];

  function automatic logic [31:0] be_mask(input logic [3:0] be);
    return {{8{be[3]}}, {8{be[2]}}, {8{be[1]}}, {8{be[0]}}};
  endfunction

  function automatic logic [31:0] rw_merge(input logic [31:0] old, input logic [31:0] wd,
                                           input logic [31:0] rw, input logic [31:0] bm);
    return (old & ~(rw & bm)) | (wd & rw & bm);
  endfunction

  always_comb begin
    case (rd_idx)
      10'd0:  rd_data = {DEVICE_ID, VENDOR_ID};
      10'd1:  rd_data = {status, command};
      10'd2:  rd_data = {CLASS_CODE, REVISION_ID};
      10'd3:  rd_data = {8'h00, 8'h00, 8'h00, cache_line};
      10'd4:  rd_data = {bar0_hi, 12'h000};
      10'd5:  rd_data = {bar1_hi, 12'h000};
      10'd11: rd_data = {SUBSYS_ID, SUBSYS_VID};
      10'd13: rd_data = 32'h0000_0040;
      10'd15: rd_data = {16'h0000, 8'h00, int_line};
      10'd16: rd_data = {7'b0, 1'b0, 1'b0, msi_mme, 3'b000, msi_en, 8'h50, 8'h05};
      10'd17: rd_data = {msi_addr_hi, 2'b00};
      10'd18: rd_data = {16'h0000, msi_data_r};
      10'd19: rd_data = {31'h0, msi_mask_r};
      10'd20: rd_data = 32'h0002_0010;                 // PCIe Cap v2, Next 00h, ID 10h
      10'd21: rd_data = 32'h0000_8000;                 // Device Caps: role-based errors, MPS 128 B
      10'd22: rd_data = {10'h0, transactions_pending, 1'b0, dev_status, dev_ctrl};
      10'd23: rd_data = 32'h0040_0014;                 // Link Caps: 16 GT/s, x1 (behavioral)
      10'd24: rd_data = {16'h0014, 8'h00, link_ctrl};
      10'd27: rd_data = 32'h0000_001E;                 // Link Caps 2
      10'd28: rd_data = {16'h0000, 12'h000, target_speed};
      default: rd_data = 32'h0;
    endcase
  end

  logic [31:0] bm;
  logic [31:0] wr_cur;
  logic [31:0] wr_rw;
  logic [31:0] wv;
  assign bm = be_mask(wr_be);

  always_comb begin
    wr_cur = 32'h0;
    wr_rw  = 32'h0;
    case (wr_idx)
      10'd1:  begin wr_cur = {16'h0, command};       wr_rw = {16'h0, CMD_RW_MASK};    end
      10'd3:  begin wr_cur = {24'h0, cache_line};    wr_rw = 32'h0000_00FF;           end
      10'd4:  begin wr_cur = {bar0_hi, 12'h0};       wr_rw = 32'hFFFF_F000;           end
      10'd5:  begin wr_cur = {bar1_hi, 12'h0};       wr_rw = 32'hFFFF_F000;           end
      10'd15: begin wr_cur = {24'h0, int_line};      wr_rw = 32'h0000_00FF;           end
      10'd16: begin wr_cur = {9'h0, msi_mme, 3'b000, msi_en, 16'h0}; wr_rw = 32'h0071_0000; end
      10'd17: begin wr_cur = {msi_addr_hi, 2'b00};   wr_rw = 32'hFFFF_FFFC;           end
      10'd18: begin wr_cur = {16'h0, msi_data_r};    wr_rw = 32'h0000_FFFF;           end
      10'd19: begin wr_cur = {31'h0, msi_mask_r};    wr_rw = 32'h0000_0001;           end
      10'd22: begin wr_cur = {16'h0, dev_ctrl};      wr_rw = {16'h0, DEVCTL_RW_MASK}; end
      10'd24: begin wr_cur = {24'h0, link_ctrl};     wr_rw = {24'h0, LNKCTL_RW_MASK}; end
      10'd28: begin wr_cur = {28'h0, target_speed};  wr_rw = 32'h0000_000F;           end
      default: ;
    endcase
    wv = rw_merge(wr_cur, wr_data, wr_rw, bm);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      command      <= 16'h0000;
      status       <= 16'h0010;
      cache_line   <= 8'h00;
      bar0_hi      <= '0;
      bar1_hi      <= '0;
      int_line     <= 8'h00;
      msi_en       <= 1'b0;
      msi_mme      <= 3'b000;
      msi_addr_hi  <= '0;
      msi_data_r   <= '0;
      msi_mask_r   <= 1'b0;
      dev_ctrl     <= DEVCTL_RESET;
      dev_status   <= 4'h0;
      link_ctrl    <= 8'h00;
      target_speed <= 4'h4;
      bus_num      <= DEFAULT_BDF[15:8];
      dev_num      <= DEFAULT_BDF[7:3];
    end else begin
      logic [15:0] status_n;
      logic [3:0]  dev_status_n;
      status_n     = status;
      dev_status_n = dev_status;

      if (wr_en) begin
        bus_num <= wr_bus;
        dev_num <= wr_dev;
        case (wr_idx)
          10'd1: begin
            command  <= wv[15:0];
            status_n = status & ~(wr_data[31:16] & STATUS_W1C_MASK & bm[31:16]);
          end
          10'd3:  cache_line   <= wv[7:0];
          10'd4:  bar0_hi      <= wv[31:12];
          10'd5:  bar1_hi      <= wv[31:12];
          10'd15: int_line     <= wv[7:0];
          10'd16: begin
            msi_en  <= wv[16];
            msi_mme <= wv[22:20];
          end
          10'd17: msi_addr_hi  <= wv[31:2];
          10'd18: msi_data_r   <= wv[15:0];
          10'd19: msi_mask_r   <= wv[0];
          10'd22: begin
            dev_ctrl     <= wv[15:0];
            dev_status_n = dev_status & ~(wr_data[19:16] & bm[19:16]);
          end
          10'd24: link_ctrl    <= wv[7:0];
          10'd28: target_speed <= wv[3:0];
          default: ;
        endcase
      end

      if (set_master_data_parity) status_n[8]  = 1'b1;
      if (set_rcvd_target_abort)  status_n[12] = 1'b1;
      if (set_rcvd_master_abort)  status_n[13] = 1'b1;
      if (set_detected_parity)    status_n[15] = 1'b1;
      if (set_ced)  dev_status_n[0] = 1'b1;
      if (set_nfed) dev_status_n[1] = 1'b1;
      if (set_fed)  dev_status_n[2] = 1'b1;
      if (set_urd)  dev_status_n[3] = 1'b1;
      status     <= status_n;
      dev_status <= dev_status_n;
    end
  end
endmodule
