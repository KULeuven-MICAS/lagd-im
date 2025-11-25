// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// LAGD AXI crossbar module

`include "lagd_axi_xbar_pkg.sv"
`include "axi/src/axi_intf.sv"
`include "axi/src/axi_xbar.sv"

module lagd_axi_xbar #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ID_WIDTH   = 4,
    parameter AXI_USER_WIDTH = 0
) (
    input  logic                                 clk_i,
    input  logic                                 rst_ni,
    // AXI slave interface
    input  lagd_axi_slv_req_t                     axi_narrow_req_i,
    output lagd_axi_slv_rsp_t                     axi_narrow_rsp_o,
    // AXI master interface
    output lagd_axi_slv_req_t                     axi_narrow_req_j_o,
    input  lagd_axi_slv_rsp_t                     axi_narrow_rsp_j_i,
    output lagd_axi_slv_req_t                     axi_narrow_req_h_o,
    input  lagd_axi_slv_rsp_t                     axi_narrow_rsp_h_i,
    output lagd_axi_slv_req_t                     axi_narrow_req_flip_o,
    input  lagd_axi_slv_rsp_t                     axi_narrow_rsp_flip_i
);
    typedef lagd_axi_xbar_pkg::xbar_rule_32_t rule_t;

    localparam lagd_axi_xbar_pkg::xbar_cfg_t xbar_cfg = `{ // TODO: to be checked
        NoSlvPorts         : 1,
        NoMstPorts         : 3,
        MaxMstTrans        : 8,
        MaxSlvTrans        : 8,
        FallThrough        : 1'b0,
        LatencyMode        : 10'b0000000000,
        PipelineStages     : 1,
        AxiIdWidthSlvPorts : AXI_ID_WIDTH,
        AxiIdUsedSlvPorts  : AXI_ID_WIDTH,
        UniqueIds          : 1'b1,
        AxiAddrWidth       : AXI_ADDR_WIDTH,
        AxiDataWidth       : AXI_DATA_WIDTH,
        NoAddrRules        : 1
    };

    localparam rule_t [xbar_cfg.NoAddrRules-1:0] AddrMap = '{
        '{
            rule_t`{idx: 0, start_addr: 'h9000_0000, end_addr: 'h9000_2000},
            rule_t`{idx: 1, start_addr: 'h9000_2000, end_addr: 'hA000_4000},
            rule_t`{idx: 2, start_addr: 'hA000_4000, end_addr: 'hA000_6000}
        }
    };

    axi_xbar #(
    .Cfg                   (xbar_cfg               ),
    .Connectivity          ('1                     ),
    .ATOPs                 (0                      ),
    .slv_aw_chan_t         (lagd_axi_slv_aw_chan_t ),
    .mst_aw_chan_t         (lagd_axi_slv_aw_chan_t ),
    .w_chan_t              (lagd_axi_slv_w_chan_t  ),
    .slv_b_chan_t          (lagd_axi_slv_b_chan_t  ),
    .mst_b_chan_t          (lagd_axi_slv_b_chan_t  ),
    .slv_ar_chan_t         (lagd_axi_slv_ar_chan_t ),
    .mst_ar_chan_t         (lagd_axi_slv_ar_chan_t ),
    .slv_r_chan_t          (lagd_axi_slv_r_chan_t  ),
    .mst_r_chan_t          (lagd_axi_slv_r_chan_t  ),
    .slv_req_t             (lagd_axi_slv_req_t     ),
    .slv_resp_t            (lagd_axi_slv_rsp_t     ),
    .mst_req_t             (lagd_axi_slv_req_t     ),
    .mst_resp_t            (lagd_axi_slv_rsp_t     )
    ) i_axi_xbar ( 
    .clk_i                 (clk_i                  ),
    .rst_ni                (rst_ni                 ),
    .test_i                (1'b0                   ),
    .slv_ports_req_i       (axi_narrow_req_i       ),
    .slv_ports_resp_o      (axi_narrow_rsp_o       ),
    .mst_ports_req_o       ({axi_narrow_req_j_o,
                            axi_narrow_req_h_o,
                            axi_narrow_req_flip_o}),
    .mst_ports_resp_i      ({axi_narrow_rsp_j_i,
                            axi_narrow_rsp_h_i,
                            axi_narrow_rsp_flip_i}),
    .addr_map_i            (AddrMap                ),
    .en_default_mst_port_i ('0                     ),
    .default_mst_port_i    ('0                     )
    )

endmodule