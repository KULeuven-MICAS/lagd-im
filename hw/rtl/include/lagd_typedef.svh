// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>


`ifndef LAGD_TYPEDEF_SVH_
`define LAGD_TYPEDEF_SVH_

`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

`define LAGD_TYPEDEF_AXI_CT(__name, __addr_t, __id_t, __data_t, __strb_t, __user_t) \
    `AXI_TYPEDEF_ALL_CT(__name, __name``_req_t, __name``_rsp_t, \
        __addr_t, __id_t, __data_t, __strb_t, __user_t)

`define LAGD_TYPEDEF_AXI(__name, __addr_t, __cfg) \
    localparam cheshire_pkg::axi_in_t __name``__AxiIn = cheshire_pkg::gen_axi_in(__cfg); \
    localparam type __name``_data_t    = logic [__cfg.AxiDataWidth   -1:0]; \
    localparam type __name``_strb_t    = logic [__cfg.AxiDataWidth/8 -1:0]; \
    localparam type __name``_user_t    = logic [__cfg.AxiUserWidth   -1:0]; \
    localparam type __name``_slv_id_t  = logic [__cfg.AxiMstIdWidth + \
        $clog2(__name``__AxiIn.num_in)-1:0]; \
    `LAGD_TYPEDEF_AXI_CT(__name``_slv, __addr_t, \
        __name``_slv_id_t, __name``_data_t, __name``_strb_t, __name``_user_t)

`define LAGD_TYPEDEF_REG(__name, __addr_t) \
    `REG_BUS_TYPEDEF_ALL(__name, __addr_t, logic [31:0], logic [3:0])

// Note that the prefix does *not* include a leading underscore.
`define LAGD_TYPEDEF_ALL(__prefix, __cheshire_cfg) \
    localparam type __prefix``addr_t = logic [__cheshire_cfg.AddrWidth-1:0]; \
    `LAGD_TYPEDEF_AXI(__prefix``axi, __prefix``addr_t, __cheshire_cfg) \
    `LAGD_TYPEDEF_REG(__prefix``reg, __prefix``addr_t)

`endif // LAGD_TYPEDEF_SVH_