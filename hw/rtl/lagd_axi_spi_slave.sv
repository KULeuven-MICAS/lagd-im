// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

module lagd_axi_spi_slave #(
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input logic spi_sclk_i,
    input logic spi_cs_i,
    output logic [3:0] spi_oen_o,
    input logic [3:0] spi_sdi_i,
    output logic [3:0] spi_sdo_o,
    
    output axi_req_t axi_req_o,
    input axi_rsp_t axi_rsp_i
);

    axi_spi_slave #(
        .AXI_ADDR_WIDTH($bits(axi_req_o.aw.addr)),
        .AXI_DATA_WIDTH($bits(axi_rsp_i.r.data)),
        .AXI_USER_WIDTH($bits(axi_req_o.aw.user)),
        .AXI_ID_WIDTH($bits(axi_req_o.aw.id))
    ) i_axi_spi_slave (
        .test_mode(1'b0),
        // SPI Interface
        .spi_sclk(spi_sclk_i),
        .spi_cs(spi_cs_i),
        .spi_sdi0(spi_sdi_i[0]),
        .spi_sdi1(spi_sdi_i[1]),
        .spi_sdi2(spi_sdi_i[2]),
        .spi_sdi3(spi_sdi_i[3]),
        .spi_sdo0(spi_sdo_o[0]),
        .spi_sdo1(spi_sdo_o[1]),
        .spi_sdo2(spi_sdo_o[2]),
        .spi_sdo3(spi_sdo_o[3]),
        .spi_oen0_o(spi_oen_o[0]),
        .spi_oen1_o(spi_oen_o[1]),
        .spi_oen2_o(spi_oen_o[2]),
        .spi_oen3_o(spi_oen_o[3]),

        // Chip ID
        .chip_id('0),

        // AXI4 MASTER
        .axi_aclk(clk_i),
        .axi_aresetn(rst_ni),
        // WRITE ADDRESS CHANNEL
        .axi_master_aw_valid(axi_req_o.aw_valid),
        .axi_master_aw_addr(axi_req_o.aw.addr),
        .axi_master_aw_prot(axi_req_o.aw.prot),
        .axi_master_aw_region(axi_req_o.aw.region),
        .axi_master_aw_len(axi_req_o.aw.len),
        .axi_master_aw_size(axi_req_o.aw.size),  // Only 32bit aw / ar is supported. Be careful
        .axi_master_aw_burst(axi_req_o.aw.burst),
        .axi_master_aw_lock(axi_req_o.aw.lock),
        .axi_master_aw_cache(axi_req_o.aw.cache),
        .axi_master_aw_qos(axi_req_o.aw.qos),
        .axi_master_aw_id(axi_req_o.aw.id),
        .axi_master_aw_user(axi_req_o.aw.user),
        .axi_master_aw_ready(axi_rsp_i.aw_ready),

        // READ ADDRESS CHANNEL
        .axi_master_ar_valid(axi_req_o.ar_valid),
        .axi_master_ar_addr(axi_req_o.ar.addr),
        .axi_master_ar_prot(axi_req_o.ar.prot),
        .axi_master_ar_region(axi_req_o.ar.region),
        .axi_master_ar_len(axi_req_o.ar.len),
        .axi_master_ar_size(axi_req_o.ar.size),  // Only 32bit aw / ar is supported. Be careful
        .axi_master_ar_burst(axi_req_o.ar.burst),
        .axi_master_ar_lock(axi_req_o.ar.lock),
        .axi_master_ar_cache(axi_req_o.ar.cache),
        .axi_master_ar_qos(axi_req_o.ar.qos),
        .axi_master_ar_id(axi_req_o.ar.id),
        .axi_master_ar_user(axi_req_o.ar.user),
        .axi_master_ar_ready(axi_rsp_i.ar_ready),

        // WRITE DATA CHANNEL
        .axi_master_w_valid(axi_req_o.w_valid),
        .axi_master_w_data (axi_req_o.w.data),
        .axi_master_w_strb (axi_req_o.w.strb),
        .axi_master_w_user (axi_req_o.w.user),
        .axi_master_w_last (axi_req_o.w.last),
        .axi_master_w_ready(axi_rsp_i.w_ready),
        // READ DATA CHANNEL
        .axi_master_r_valid(axi_rsp_i.r_valid),
        .axi_master_r_data(axi_rsp_i.r.data),
        .axi_master_r_resp(axi_rsp_i.r.resp),
        .axi_master_r_last(axi_rsp_i.r.last),
        .axi_master_r_id(axi_rsp_i.r.id),
        .axi_master_r_user(axi_rsp_i.r.user),
        .axi_master_r_ready(axi_req_o.r_ready),

        // WRITE RESPONSE CHANNEL
        .axi_master_b_valid(axi_rsp_i.b_valid),
        .axi_master_b_resp(axi_rsp_i.b.resp),
        .axi_master_b_id(axi_rsp_i.b.id),
        .axi_master_b_user(axi_rsp_i.b.user),
        .axi_master_b_ready(axi_req_o.b_ready)
    );

endmodule