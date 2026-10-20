// DLLP construction/decoding (package) and the Endpoint DLLP receive decoder and
// transmit multiplexer (module).
//
// DLLP beat: [47:40] type, [39:32] byte1, [31:24] byte2, [23:16] byte3, [15:0] CRC16.
//   Ack/Nak : byte2[3:0] = seq[11:8], byte3 = seq[7:0]
//   FC DLLPs: byte1[5:0] = HdrFC[7:2], byte2[7:6] = HdrFC[1:0], byte2[3:0] = DataFC[11:8],
//             byte3 = DataFC[7:0]; type[5:4] = credit class (00 P, 01 NP, 10 Cpl),
//             type[2:0] = VC ID (only VC0 supported)
package pcie_dllp_pkg;
  import pcie_pkg::*;
  import pcie_crc_pkg::*;

  function automatic logic [47:0] dllp_seal(input logic [31:0] body);
    return {body, dllp_crc16(body)};
  endfunction

  function automatic logic [47:0] dllp_acknak(input logic is_nak, input logic [11:0] seq);
    return dllp_seal({is_nak ? DLLP_NAK : DLLP_ACK, 8'h00, 4'h0, seq[11:8], seq[7:0]});
  endfunction

  function automatic logic [47:0] dllp_fc(input logic [7:0] typ, input logic [7:0] hdr, input logic [11:0] data);
    return dllp_seal({typ, 2'b00, hdr[7:2], hdr[1:0], 2'b00, data[11:8], data[7:0]});
  endfunction

  function automatic logic [7:0] fc_type_byte(input logic [1:0] kind, input fc_class_e cls);
    // kind: 1 = InitFC1, 2 = InitFC2, 3 = UpdateFC
    logic [1:0] top;
    top = (kind == 2'd1) ? 2'b01 : (kind == 2'd2) ? 2'b11 : 2'b10;
    return {top, cls, 4'h0};
  endfunction

  function automatic logic dllp_crc_ok(input logic [47:0] raw);
    return dllp_crc16(raw[47:16]) == raw[15:0];
  endfunction

  function automatic logic [11:0] dllp_seq(input logic [47:0] raw);
    return {raw[27:24], raw[23:16]};
  endfunction

  function automatic logic [7:0] dllp_hdrfc(input logic [47:0] raw);
    return {raw[37:32], raw[31:30]};
  endfunction

  function automatic logic [11:0] dllp_datafc(input logic [47:0] raw);
    return {raw[27:24], raw[23:16]};
  endfunction
endpackage

module pcie_dllp_codec
  import pcie_pkg::*;
  import pcie_dllp_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        link_ok,

  input  logic        dllp_rx_valid,
  output logic        dllp_rx_ready,
  input  logic [47:0] dllp_rx_data,

  output logic        rx_ack,
  output logic        rx_nak,
  output logic [11:0] rx_acknak_seq,
  output logic        rx_initfc1,
  output logic        rx_initfc2,
  output logic        rx_updfc,
  output fc_class_e   rx_fc_class,
  output logic [7:0]  rx_fc_hdr,
  output logic [11:0] rx_fc_data,
  output logic        rx_bad_crc,
  output logic        rx_unsupported,

  input  logic        nak_req,
  input  logic [11:0] nak_seq,
  output logic        nak_gnt,
  input  logic        ack_req,
  input  logic [11:0] ack_seq,
  output logic        ack_gnt,
  input  logic        fc_req,
  input  logic [7:0]  fc_type,
  input  logic [7:0]  fc_hdr,
  input  logic [11:0] fc_data,
  output logic        fc_gnt,

  output logic        dllp_tx_valid,
  input  logic        dllp_tx_ready,
  output logic [47:0] dllp_tx_data
);

  logic        acc;
  logic [7:0]  typ;
  logic        crc_ok;

  assign dllp_rx_ready = rst_n;
  assign acc    = dllp_rx_valid && dllp_rx_ready;
  assign typ    = dllp_rx_data[47:40];
  assign crc_ok = dllp_crc_ok(dllp_rx_data);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_ack         <= 1'b0;
      rx_nak         <= 1'b0;
      rx_acknak_seq  <= '0;
      rx_initfc1     <= 1'b0;
      rx_initfc2     <= 1'b0;
      rx_updfc       <= 1'b0;
      rx_fc_class    <= FC_P;
      rx_fc_hdr      <= '0;
      rx_fc_data     <= '0;
      rx_bad_crc     <= 1'b0;
      rx_unsupported <= 1'b0;
    end else begin
      rx_ack         <= 1'b0;
      rx_nak         <= 1'b0;
      rx_initfc1     <= 1'b0;
      rx_initfc2     <= 1'b0;
      rx_updfc       <= 1'b0;
      rx_bad_crc     <= 1'b0;
      rx_unsupported <= 1'b0;
      if (acc) begin
        rx_acknak_seq <= dllp_seq(dllp_rx_data);
        rx_fc_class   <= fc_class_e'(typ[5:4]);
        rx_fc_hdr     <= dllp_hdrfc(dllp_rx_data);
        rx_fc_data    <= dllp_datafc(dllp_rx_data);
        if (!crc_ok) begin
          rx_bad_crc <= 1'b1;
        end else if (typ == DLLP_ACK) begin
          rx_ack <= 1'b1;
        end else if (typ == DLLP_NAK) begin
          rx_nak <= 1'b1;
        end else if (typ[7:6] != 2'b00 && typ[5:4] != 2'b11 && typ[3:0] == 4'h0) begin
          case (typ[7:6])
            2'b01:   rx_initfc1 <= 1'b1;
            2'b11:   rx_initfc2 <= 1'b1;
            default: rx_updfc   <= 1'b1;
          endcase
        end else begin
          rx_unsupported <= 1'b1;   // PM, vendor-specific, non-VC0 FC and reserved DLLPs
        end
      end
    end
  end

  logic load;
  assign load    = link_ok && (!dllp_tx_valid || dllp_tx_ready);
  assign nak_gnt = load && nak_req;
  assign ack_gnt = load && !nak_req && ack_req;
  assign fc_gnt  = load && !nak_req && !ack_req && fc_req;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dllp_tx_valid <= 1'b0;
      dllp_tx_data  <= '0;
    end else if (!link_ok) begin
      dllp_tx_valid <= 1'b0;
    end else if (load) begin
      dllp_tx_valid <= nak_req || ack_req || fc_req;
      if (nak_req)      dllp_tx_data <= dllp_acknak(1'b1, nak_seq);
      else if (ack_req) dllp_tx_data <= dllp_acknak(1'b0, ack_seq);
      else if (fc_req)  dllp_tx_data <= dllp_fc(fc_type, fc_hdr, fc_data);
    end
  end

endmodule
