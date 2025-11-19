// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_system #(
  SramInitFile = ""
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

  // UART receive and transmit.
  input  logic uart_rx_i,
  output logic uart_tx_o
);
  // Local parameters.
  localparam int unsigned SramMemSize   = 128 * 1024; // 128 KiB
  localparam int unsigned TlDataWidth   = top_pkg::TL_DW;
  localparam int unsigned TlIntgWidth   = 7;
  localparam int unsigned TlAddrOffset  = $clog2(TlDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - TlAddrOffset;
  localparam int unsigned AxiDataWidth  = 64;

  // Memory map
  localparam logic [AxiDataWidth-1:0] SRAMBase   = AxiDataWidth'(tl_peri_pkg::ADDR_SPACE_SRAM);

  // CVA6 configuration
  function automatic config_pkg::cva6_cfg_t build_cva6_config(config_pkg::cva6_user_cfg_t CVA6UserCfg);
    config_pkg::cva6_user_cfg_t cfg = CVA6UserCfg;
    cfg.RVZiCond = bit'(0);
    cfg.CvxifEn = bit'(0);
    cfg.NrNonIdempotentRules = unsigned'(1);
    cfg.NonIdempotentAddrBase = 1024'({64'b0});
    cfg.NonIdempotentLength = 1024'({SRAMBase});
    return build_config_pkg::build_config(cfg);
  endfunction

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_cva6_config(cva6_config_pkg::cva6_cfg);
  cva6_cheri_pkg::cap_pcc_t boot_cap;
  always_comb begin : gen_boot_cap
    boot_cap = cva6_cheri_pkg::PCC_ROOT_CAP;
    boot_cap.addr = SRAMBase + 'h80;
    boot_cap.flags.int_mode = 1'b1;
  end

  // Read/write signals.
  logic                       cva6_req;
  logic                       cva6_gnt;
  logic                       cva6_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] cva6_be;
  logic [top_pkg::AxiAddrWidth-1:0] cva6_addr;
  logic [top_pkg::AxiDataWidth-1:0] cva6_wdata;
  logic                       cva6_rvalid;
  logic [top_pkg::AxiDataWidth-1:0] cva6_rdata;
  logic                       cva6_dw_req;
  logic                       cva6_dw_gnt;
  logic                       cva6_dw_we;
  logic [(TlDataWidth/8)-1:0] cva6_dw_be;
  logic [top_pkg::TL_AW-1:0]  cva6_dw_addr;
  logic [TlDataWidth-1:0]     cva6_dw_wdata;
  logic [TlIntgWidth-1:0]     cva6_dw_wdata_intg;
  logic                       cva6_dw_rvalid;
  logic [TlDataWidth-1:0]     cva6_dw_rdata;
  logic                       sram_data_req;
  logic                       sram_data_we;
  logic [SramAddrWidth-1:0]   sram_data_addr;
  logic [TlDataWidth-1:0]     sram_data_wmask;
  logic [TlDataWidth-1:0]     sram_data_wdata;
  logic                       sram_data_rvalid;
  logic [TlDataWidth-1:0]     sram_data_rdata;

  top_pkg::axi_req_t  cva6_axi_req;
  top_pkg::axi_resp_t cva6_axi_resp;

  // Instantiate CVA6-CHERI.
  cva6 #(
    .CVA6Cfg       ( CVA6Cfg                ),
    .axi_ar_chan_t ( top_pkg::axi_ar_chan_t ),
    .axi_aw_chan_t ( top_pkg::axi_aw_chan_t ),
    .axi_w_chan_t  ( top_pkg::axi_w_chan_t  ),
    .b_chan_t      ( top_pkg::axi_b_chan_t  ),
    .r_chan_t      ( top_pkg::axi_r_chan_t  ),
    .noc_req_t     ( top_pkg::axi_req_t     ),
    .noc_resp_t    ( top_pkg::axi_resp_t    )
  ) i_cva6 (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .boot_addr_i   (boot_cap),
    .hart_id_i     ('0),
    .irq_i         (2'b0),
    .ipi_i         (1'b0),
    .time_irq_i    (1'b0),
    .debug_req_i   (1'b0),
    .rvfi_probes_o ( ),
    .cvxif_req_o   ( ),
    .cvxif_resp_i  ('0),
    .noc_req_o     (cva6_axi_req),
    .noc_resp_i    (cva6_axi_resp)
  );

  // Instantiate our UART block.
  uart u_uart (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),
    .lsio_trigger_o  ( ),

    .cio_rx_i    (uart_rx_i),
    .cio_tx_o    (uart_tx_o),
    .cio_tx_en_o ( ),

    // Inter-module signals.
    .tl_i (tl_uart_h2d),
    .tl_o (tl_uart_d2h),

    // Interrupts.
    .intr_tx_watermark_o  ( ),
    .intr_tx_empty_o      ( ),
    .intr_rx_watermark_o  ( ),
    .intr_tx_done_o       ( ),
    .intr_rx_overflow_o   ( ),
    .intr_rx_frame_err_o  ( ),
    .intr_rx_break_err_o  ( ),
    .intr_rx_timeout_o    ( ),
    .intr_rx_parity_err_o ( )
  );

  // Our RAM
  prim_ram_1p #(
    .Width           ( TlDataWidth          ),
    .DataBitsPerMask ( 8                    ),
    .Depth           ( 2 ** (SramAddrWidth) ),
    .MemInitFile     ( SramInitFile         )
  ) u_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_data_req),
    .write_i (sram_data_we),
    .addr_i  (sram_data_addr),
    .wdata_i (sram_data_wdata),
    .wmask_i (sram_data_wmask),
    .rdata_o (sram_data_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sram_data_rvalid  <= '0;
    end else begin
      sram_data_rvalid <= sram_data_req & ~sram_data_we;
    end
  end

  // TileLink signals.
  tlul_pkg::tl_h2d_t tl_cva6_lsu_h2d;
  tlul_pkg::tl_d2h_t tl_cva6_lsu_d2h;
  tlul_pkg::tl_h2d_t tl_sram_h2d;
  tlul_pkg::tl_d2h_t tl_sram_d2h;
  tlul_pkg::tl_h2d_t tl_uart_h2d;
  tlul_pkg::tl_d2h_t tl_uart_d2h;

  // Our main peripheral bus.
  xbar_peri xbar (
    // Clock and reset.
    .clk_i,
    .rst_ni,

    // Host interfaces.
    .tl_ibex_lsu_i (tl_cva6_lsu_h2d),
    .tl_ibex_lsu_o (tl_cva6_lsu_d2h),

    // Device interfaces.
    .tl_sram_o (tl_sram_h2d),
    .tl_sram_i (tl_sram_d2h),
    .tl_uart_o (tl_uart_h2d),
    .tl_uart_i (tl_uart_d2h),

    .scanmode_i (prim_mubi_pkg::MuBi4False)
  );

  // Convert AXI to memory signals.
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) cva6_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (cva6_axi_req),
    .axi_resp_o (cva6_axi_resp),

    // Memory interface.
    .mem_req_o    (cva6_req),
    .mem_gnt_i    (cva6_gnt),
    .mem_addr_o   (cva6_addr),
    .mem_wdata_o  (cva6_wdata),
    .mem_strb_o   (cva6_be),
    .mem_atop_o   ( ),
    .mem_we_o     (cva6_we),
    .mem_rvalid_i (cva6_rvalid),
    .mem_rdata_i  (cva6_rdata)
  );

  // Send side downsizer
  logic                                 dw_valid;   // Has valid transaction
  logic                                 dw_first_done;
  logic     [top_pkg::AxiAddrWidth-1:0] dw_store_addr;
  logic     [top_pkg::AxiDataWidth-1:0] dw_store_wdata;
  logic                                 dw_store_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] dw_store_be;

  assign cva6_gnt = dw_valid; // Grant when empty, otherwise process existing transaction

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dw_valid <= 0;
      dw_first_done <= 0;

      cva6_dw_req <= 0; // No req when empty
      cva6_dw_we  <= '0;
      cva6_dw_be  <= '0;
      cva6_dw_addr  <= '0;
      cva6_dw_wdata <= '0;
    end else if (!dw_valid && cva6_req) begin // New request
      dw_valid <= 1;
      dw_first_done <= 0; // have not done first 32 bits

      // Store transaction information
      dw_store_addr <= cva6_addr;
      dw_store_wdata <= cva6_wdata;
      dw_store_we <= cva6_we;
      dw_store_be <= cva6_be;

      cva6_dw_req <= 0;
      cva6_dw_we  <= '0;
      cva6_dw_be  <= '0;
      cva6_dw_addr  <= '0;
      cva6_dw_wdata <= '0;
    end else if (dw_valid && !cva6_dw_req && !dw_first_done) begin // Valid transaction, no untaken output, but have not started first 32 bits
      // Start first 32 bits
      cva6_dw_req <= 1;
      cva6_dw_addr <= dw_store_addr[31:0];
      cva6_dw_wdata <= dw_store_wdata[31:0];
      cva6_dw_we  <= dw_store_we;
      cva6_dw_be <= dw_store_be[3:0];
    end else if (dw_valid && cva6_dw_req && cva6_dw_gnt && !dw_first_done) begin // Valid transaction, first output just taken
      dw_first_done <= 1; // First 32 bits is done
      // Clear output
      cva6_dw_req <= 0;
      cva6_dw_we  <= '0;
      cva6_dw_be  <= '0;
      cva6_dw_addr  <= '0;
      cva6_dw_wdata <= '0;
    end else if (dw_valid && !cva6_dw_req && dw_first_done) begin // Valid transaction, no untaken output, first 32 bits already done
      // Start next 32 bits
      cva6_dw_req <= 1;
      cva6_dw_addr <= dw_store_addr[31:0] + 4;
      cva6_dw_wdata <= dw_store_wdata[63:32];
      cva6_dw_we  <= dw_store_we;
      cva6_dw_be <= dw_store_be[7:4];
    end else if (dw_valid && cva6_dw_req && cva6_dw_gnt && dw_first_done) begin // Valid transaction, second output just taken
      // transaction done
      dw_valid <= 0;
      dw_first_done <= 0;

      // Clear output
      cva6_dw_req <= 0;
      cva6_dw_we  <= '0;
      cva6_dw_be  <= '0;
      cva6_dw_addr  <= '0;
      cva6_dw_wdata <= '0;
    end
  end

  // Receive side upsizer
  logic        uw_valid;      // Has valid transaction
  logic [31:0] uw_first32_rdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      uw_valid <= 0;
      // Clear rdata return
      cva6_rvalid <= 0;
      cva6_rdata <= '0;
    end else if (cva6_rvalid) begin // Assert upsized output for only 1 cycle
      cva6_rvalid <= 0;
    end else if (!uw_valid && cva6_dw_rvalid) begin // First 32 bits arrive
      // Store first 32 bits of rdata
      uw_valid <= 1;
      uw_first32_rdata <= cva6_dw_rdata;
    end else if (uw_valid && cva6_dw_rvalid) begin // second 32 bits arrive
      // Clear transaction
      uw_valid <= 0;
      // Set upsized output
      cva6_rvalid <= 1;
      cva6_rdata <= {cva6_dw_rdata, uw_first32_rdata};
    end
  end

  // generate integrity to host adapter
  logic [TlDataWidth-1:0] unused_cva6_dw_wdata;
  prim_secded_inv_39_32_enc u_cva6_dw_intg_gen (
    .data_i(cva6_dw_wdata),
    .data_o({cva6_dw_wdata_intg, unused_cva6_dw_wdata})
  );

  // TileLink host adapter to connect CVA6 to bus.
  tlul_adapter_host #(
    .EnableDataIntgGen      ( 1 ),
    .EnableRspDataIntgCheck ( 1 )
  ) cva6_tlul_host_adapter (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i        (cva6_dw_req),
    .gnt_o        (cva6_dw_gnt),
    .addr_i       (cva6_dw_addr),
    .we_i         (cva6_dw_we),
    .wdata_i      (cva6_dw_wdata),
    .wdata_intg_i (cva6_dw_wdata_intg),
    .be_i         (cva6_dw_be),
    .instr_type_i (prim_mubi_pkg::MuBi4False),
    .user_rsvd_i  ('0),

    .valid_o      (cva6_dw_rvalid),
    .rdata_o      (cva6_dw_rdata),
    .rdata_intg_o ( ),
    .err_o        ( ),
    .intg_err_o   ( ),

    .tl_o         (tl_cva6_lsu_h2d),
    .tl_i         (tl_cva6_lsu_d2h)
  );

  // TileLink device adapter to connect SRAM to bus.
  tlul_adapter_sram #(
    .SramAw            ( SramAddrWidth ),
    .EnableRspIntgGen  ( 1             ),
    .EnableDataIntgGen ( 1             )
  ) sram_device_adapter (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // TL-UL interface.
    .tl_i        (tl_sram_h2d),
    .tl_o        (tl_sram_d2h),

    // Control interface.
    .en_ifetch_i (prim_mubi_pkg::MuBi4True),

    // SRAM interface.
    .req_o        (sram_data_req),
    .req_type_o   ( ),
    .gnt_i        (sram_data_req),
    .we_o         (sram_data_we),
    .addr_o       (sram_data_addr),
    .wdata_o      (sram_data_wdata),
    .wmask_o      (sram_data_wmask),
    .intg_error_o ( ),
    .user_rsvd_o  ( ),
    .rdata_i      (sram_data_rdata),
    .rvalid_i     (sram_data_rvalid),
    .rerror_i     (2'b00),

    // Readback functionality not required.
    .compound_txn_in_progress_o (),
    .readback_en_i              (prim_mubi_pkg::MuBi4False),
    .readback_error_o           (),
    .wr_collision_i             (1'b0),
    .write_pending_i            (1'b0)
  );
endmodule
