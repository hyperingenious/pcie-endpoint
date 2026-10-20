// Data Link Layer CRC functions.
//
// LCRC: 32-bit CRC, polynomial 04C11DB7h, reflected bit order, seed FFFFFFFFh,
// result complemented (the CRC-32/IEEE parameter set). Covered bytes are the two
// sequence-number bytes {4'h0, seq[11:8]} and seq[7:0], then every TLP byte.
//
// DLLP CRC: 16-bit CRC, polynomial 100Bh, seed FFFFh, MSB-first over the four
// DLLP body bytes, result complemented.
//
// ECRC (TLP Digest) is a separate end-to-end CRC that this design does not
// generate or check; see docs/known_limitations.md.
package pcie_crc_pkg;

  localparam logic [31:0] LCRC_SEED = 32'hFFFF_FFFF;

  function automatic logic [31:0] lcrc_byte(input logic [31:0] crc, input logic [7:0] b);
    logic [31:0] c;
    c = crc ^ {24'h0, b};
    for (int i = 0; i < 8; i++)
      c = c[0] ? ((c >> 1) ^ 32'hEDB8_8320) : (c >> 1);
    return c;
  endfunction

  function automatic logic [31:0] lcrc_dw(input logic [31:0] crc, input logic [31:0] dw);
    logic [31:0] c;
    c = lcrc_byte(crc, dw[31:24]);
    c = lcrc_byte(c, dw[23:16]);
    c = lcrc_byte(c, dw[15:8]);
    c = lcrc_byte(c, dw[7:0]);
    return c;
  endfunction

  // Running CRC after the sequence-number bytes
  function automatic logic [31:0] lcrc_seq(input logic [11:0] seq);
    logic [31:0] c;
    c = lcrc_byte(LCRC_SEED, {4'h0, seq[11:8]});
    c = lcrc_byte(c, seq[7:0]);
    return c;
  endfunction

  function automatic logic [31:0] lcrc_final(input logic [31:0] crc);
    return ~crc;
  endfunction

  function automatic logic [15:0] dllp_crc16(input logic [31:0] body);
    logic [15:0] c;
    logic        fb;
    c = 16'hFFFF;
    for (int i = 31; i >= 0; i--) begin
      fb = c[15] ^ body[i];
      c  = {c[14:0], 1'b0};
      if (fb) c = c ^ 16'h100B;
    end
    return ~c;
  endfunction

endpackage
