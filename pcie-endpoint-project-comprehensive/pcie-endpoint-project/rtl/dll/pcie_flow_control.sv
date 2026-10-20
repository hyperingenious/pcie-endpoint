// VC0 flow-control: advertise Endpoint credits, track partner credits, run
// InitFC1/InitFC2, apply UpdateFC. InitFC field 0 = infinite. UpdateFC 0 = no change.
// Counters saturate at their field width. An out-of-range update is flagged and ignored.
module pcie_flow_control
  import pcie_pkg::*;
  import pcie_dllp_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        in_init,

  input  logic        rx_initfc1,
  input  logic        rx_initfc2,
  input  logic        rx_updfc,
  input  fc_class_e   rx_fc_class,
  input  logic [7:0]  rx_fc_hdr,
  input  logic [11:0] rx_fc_data,

  input  logic        consume,
  input  fc_class_e   consume_class,
  input  logic [11:0] consume_data,
  input  logic [2:0]  need_hdr,
  input  logic [11:0] need_data [3],
  output logic [2:0]  credit_ok,

  input  logic        rx_p_freed,
  input  logic        rx_np_freed,
  input  logic [11:0] rx_p_data_freed,
  input  logic [11:0] rx_np_data_freed,

  output logic        fc_req,
  output logic [7:0]  fc_type,
  output logic [7:0]  fc_hdr,
  output logic [11:0] fc_data,
  input  logic        fc_gnt,

  output logic        fc_init_done,
  output logic        fc_error,
  output logic        hdr_inf [3],
  output logic [7:0]  hdr_cred [3],
  output logic [11:0] data_cred [3]
);
  logic [2:0] seen1, seen2, sent1, sent2;
  logic [1:0] init_cls;
  logic [1:0] upd_cls;
  logic [7:0]  rx_alloc_h [3];
  logic [11:0] rx_alloc_d [3];
  logic [7:0]  rx_free_h [3];
  logic [11:0] rx_free_d [3];

  assign fc_init_done = (&seen1) && (&seen2) && (&sent1) && (&sent2);

  function automatic logic [7:0] adv_h(input fc_class_e c);
    case (c)
      FC_P:    return ADV_PH;
      FC_NP:   return ADV_NPH;
      default: return ADV_CPLH;
    endcase
  endfunction

  function automatic logic [11:0] adv_d(input fc_class_e c);
    case (c)
      FC_P:    return ADV_PD;
      FC_NP:   return ADV_NPD;
      default: return ADV_CPLD;
    endcase
  endfunction

  for (genvar c = 0; c < 3; c++) begin : g_ok
    assign hdr_inf[c]   = (hdr_cred[c] == 8'd0) && fc_init_done;
    assign credit_ok[c] = fc_init_done &&
                          (hdr_inf[c] || hdr_cred[c] >= 8'(need_hdr[c])) &&
                          (data_cred[c] == 12'd0 || data_cred[c] >= need_data[c]);
  end

  always_comb begin
    fc_req  = 1'b0;
    fc_type = 8'h0;
    fc_hdr  = 8'h0;
    fc_data = 12'h0;
    if (in_init && !fc_init_done) begin
      fc_req  = 1'b1;
      if (!sent1[init_cls]) begin
        fc_type = fc_type_byte(2'd1, fc_class_e'(init_cls));
        fc_hdr  = adv_h(fc_class_e'(init_cls));
        fc_data = adv_d(fc_class_e'(init_cls));
      end else if (&seen1 && !sent2[init_cls]) begin
        fc_type = fc_type_byte(2'd2, fc_class_e'(init_cls));
        fc_hdr  = adv_h(fc_class_e'(init_cls));
        fc_data = adv_d(fc_class_e'(init_cls));
      end else
        fc_req = 1'b0;
    end else if (fc_init_done && (rx_free_h[upd_cls] != 0 || rx_free_d[upd_cls] != 0)) begin
      fc_req  = 1'b1;
      fc_type = fc_type_byte(2'd3, fc_class_e'(upd_cls));
      fc_hdr  = rx_free_h[upd_cls];
      fc_data = rx_free_d[upd_cls];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seen1 <= '0; seen2 <= '0; sent1 <= '0; sent2 <= '0;
      init_cls <= '0; upd_cls <= '0;
      fc_error <= 1'b0;
      for (int i = 0; i < 3; i++) begin
        hdr_cred[i]  <= '0;
        data_cred[i] <= '0;
        rx_alloc_h[i] <= '0;
        rx_alloc_d[i] <= '0;
        rx_free_h[i]  <= '0;
        rx_free_d[i]  <= '0;
      end
    end else if (flush) begin
      seen1 <= '0; seen2 <= '0; sent1 <= '0; sent2 <= '0;
      fc_error <= 1'b0;
      for (int i = 0; i < 3; i++) begin
        hdr_cred[i]   <= '0;
        data_cred[i]  <= '0;
        rx_free_h[i]  <= '0;
        rx_free_d[i]  <= '0;
      end
    end else begin
      if (rx_initfc1) begin
        if (rx_fc_hdr > 8'd127 || rx_fc_data > 12'd2047) fc_error <= 1'b1;
        else begin
          seen1[rx_fc_class]    <= 1'b1;
          hdr_cred[rx_fc_class] <= rx_fc_hdr;
          data_cred[rx_fc_class]<= rx_fc_data;
        end
      end
      if (rx_initfc2) begin
        if (rx_fc_hdr > 8'd127 || rx_fc_data > 12'd2047) fc_error <= 1'b1;
        else seen2[rx_fc_class] <= 1'b1;
      end
      if (rx_updfc) begin
        if (rx_fc_hdr > 8'd127 || rx_fc_data > 12'd2047) begin
          fc_error <= 1'b1;
        end else begin
          if (rx_fc_hdr != 0 && hdr_cred[rx_fc_class] != 0) begin
            logic [8:0] s;
            s = {1'b0, hdr_cred[rx_fc_class]} + {1'b0, rx_fc_hdr};
            hdr_cred[rx_fc_class] <= s[8] ? 8'hFF : s[7:0];
          end
          if (rx_fc_data != 0 && data_cred[rx_fc_class] != 0) begin
            logic [12:0] s;
            s = {1'b0, data_cred[rx_fc_class]} + {1'b0, rx_fc_data};
            data_cred[rx_fc_class] <= s[12] ? 12'hFFF : s[11:0];
          end
        end
      end

      if (consume) begin
        if (hdr_cred[consume_class] != 0)
          hdr_cred[consume_class] <= hdr_cred[consume_class] - 8'(need_hdr[consume_class]);
        if (data_cred[consume_class] != 0)
          data_cred[consume_class] <= data_cred[consume_class] - consume_data;
      end

      if (rx_p_freed) begin
        rx_free_h[FC_P] <= rx_free_h[FC_P] + 8'd1;
        rx_free_d[FC_P] <= rx_free_d[FC_P] + rx_p_data_freed;
      end
      if (rx_np_freed) begin
        rx_free_h[FC_NP] <= rx_free_h[FC_NP] + 8'd1;
        rx_free_d[FC_NP] <= rx_free_d[FC_NP] + rx_np_data_freed;
      end

      if (fc_gnt && fc_req) begin
        if (in_init && !(&sent1)) sent1[init_cls] <= 1'b1;
        else if (in_init)         sent2[init_cls] <= 1'b1;
        else begin
          rx_free_h[upd_cls] <= '0;
          rx_free_d[upd_cls] <= '0;
        end
        init_cls <= init_cls + 2'd1;
        if (init_cls == 2'd2) init_cls <= 2'd0;
        upd_cls  <= (upd_cls == 2'd2) ? 2'd0 : (upd_cls + 2'd1);
      end else begin
        init_cls <= (init_cls == 2'd2) ? 2'd0 : (init_cls + 2'd1);
      end
    end
  end
endmodule
