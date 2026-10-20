// Receive path: strip sequence and LCRC, check integrity and sequence, and
// speculatively write TLP DWs into the Transaction Layer queues.
module pcie_dll_rx
  import pcie_pkg::*;
  import pcie_crc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        dl_active,
  input  logic        flush,

  input  logic        lnk_valid,
  output logic        lnk_ready,
  input  logic        lnk_sop,
  input  logic        lnk_eop,
  input  logic [31:0] lnk_data,

  output logic        wr_valid,
  output logic        wr_first,
  output logic [31:0] wr_data,
  output logic        commit,
  output logic        abort,
  input  logic        space_ok,

  output logic        rx_ok,
  output logic        rx_dup,
  output logic        rx_bad,
  output logic [11:0] rx_seq,
  output logic [11:0] rx_expected,
  output logic        overflow
);
  typedef enum logic [1:0] {R_IDLE, R_BODY, R_DONE} rst_e;
  rst_e        st;
  logic [11:0] exp;
  logic [11:0] got;
  logic [31:0] crc;
  logic        saw_body;
  logic        drop;

  assign lnk_ready   = rst_n && (space_ok || drop || st != R_BODY);
  assign rx_expected = exp;

  logic        acc;
  assign acc = lnk_valid && lnk_ready;

  always_comb begin
    wr_valid = 1'b0;
    wr_first = 1'b0;
    wr_data  = lnk_data;
    commit   = 1'b0;
    abort    = 1'b0;
    rx_ok    = 1'b0;
    rx_dup   = 1'b0;
    rx_bad   = 1'b0;
    overflow = 1'b0;
    if (st == R_BODY && acc && !lnk_eop && !drop) begin
      wr_valid = 1'b1;
      wr_first = !saw_body;
    end
    if (st == R_BODY && acc && lnk_eop) begin
      logic [31:0] expect_crc;
      logic        good;
      expect_crc = lcrc_final(crc);
      good       = (lnk_data == expect_crc);
      if (!good) begin
        rx_bad = 1'b1;
        abort  = saw_body;
      end else if (got == exp) begin
        rx_ok  = 1'b1;
        commit = saw_body;
      end else if (got == (exp - 12'd1) || (exp == 12'd0 && got == 12'd4095)) begin
        rx_dup = 1'b1;
        abort  = saw_body;
      end else begin
        rx_bad = 1'b1;
        abort  = saw_body;
      end
    end
    if (acc && lnk_sop && !space_ok) overflow = 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= R_IDLE; exp <= '0; got <= '0; crc <= LCRC_SEED;
      saw_body <= 1'b0; drop <= 1'b0;
    end else if (flush || !dl_active) begin
      st <= R_IDLE; exp <= '0; saw_body <= 1'b0; drop <= 1'b0;
    end else begin
      rx_seq <= got;
      unique case (st)
        R_IDLE: if (acc && lnk_sop) begin
          got      <= lnk_data[11:0];
          crc      <= lcrc_seq(lnk_data[11:0]);
          saw_body <= 1'b0;
          drop     <= !space_ok;
          st       <= R_BODY;
        end
        R_BODY: if (acc) begin
          if (lnk_eop) begin
            if (lnk_data == lcrc_final(crc) && got == exp) begin
              exp <= (exp == 12'd4095) ? 12'd0 : (exp + 12'd1);
            end
            st <= R_IDLE;
          end else begin
            crc      <= lcrc_dw(crc, lnk_data);
            saw_body <= 1'b1;
          end
        end
        default: st <= R_IDLE;
      endcase
    end
  end
endmodule
