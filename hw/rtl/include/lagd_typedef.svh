// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Inspired from 
// https://github.com/pulp-platform/cheshire/blob/main/hw/include/cheshire/typedef.svh

`ifndef LAGD_TYPEDEF_SVH_
`define LAGD_TYPEDEF_SVH_

`include "axi/typedef.svh"
`include "register_interface/typedef.svh"
`include "memory_interface/typedef.svh"

// ==================
// AXI TYPEDEFS
// ==================

`define LAGD_TYPEDEF_AXI_CT(__name, __addr_t, __id_t, __data_t, __strb_t, __user_t) \
    `AXI_TYPEDEF_ALL_CT(__name, __name``_req_t, __name``_rsp_t, \
        __addr_t, __id_t, __data_t, __strb_t, __user_t)

`define LAGD_TYPEDEF_AXI(__name, __addr_t, __data_t, __strb_t, __user_t, __cfg) \
    localparam type __name``_mst_id_t  = logic [__cfg.AxiMstIdWidth  -1:0]; \
    localparam cheshire_pkg::axi_in_t __name``__AxiIn = cheshire_pkg::gen_axi_in(__cfg); \
    localparam type __name``_slv_id_t  = logic [__cfg.AxiMstIdWidth + \
        $clog2(__name``__AxiIn.num_in)-1:0]; \
    `LAGD_TYPEDEF_AXI_CT(__name``_mst, __addr_t, \
        __name``_mst_id_t, __data_t, __strb_t, __user_t) \
    `LAGD_TYPEDEF_AXI_CT(__name``_slv, __addr_t, \
        __name``_slv_id_t, __data_t, __strb_t, __user_t)

`define LAGD_TYPEDEF_REG(__name, __addr_t) \
    `REG_BUS_TYPEDEF_ALL(__name, __addr_t, logic [31:0], logic [3:0])

// Note that the prefix does *not* include a leading underscore.
`define LAGD_TYPEDEF_ALL(__prefix, __JDataWidth, __FDataWidth ,__cheshire_cfg) \
    localparam type __prefix``addr_t = logic [__cheshire_cfg.AddrWidth-1:0]; \
    localparam type __prefix``narr_data_t = logic [__cheshire_cfg.AxiDataWidth-1:0]; \
    localparam type __prefix``j_mem_data_t = logic [__JDataWidth-1:0]; \
    localparam type __prefix``f_mem_data_t = logic [__FDataWidth-1:0]; \
    localparam type __prefix``narr_strb_t = logic [__cheshire_cfg.AxiDataWidth/8-1:0]; \
    localparam type __prefix``j_mem_strb_t = logic [__JDataWidth/8-1:0]; \
    localparam type __prefix``f_mem_strb_t = logic [__FDataWidth/8-1:0]; \
    localparam type __prefix``user_t = logic [__cheshire_cfg.AxiUserWidth-1:0]; \
    `LAGD_TYPEDEF_AXI(__prefix``axi, __prefix``addr_t, __prefix``narr_data_t, \
        __prefix``narr_strb_t, __prefix``user_t, __cheshire_cfg) \
    `LAGD_TYPEDEF_AXI(__prefix``axi_wide, __prefix``addr_t, __prefix``f_mem_data_t, \
        __prefix``f_mem_strb_t, __prefix``user_t, __cheshire_cfg) \
    `LAGD_TYPEDEF_REG(__prefix``reg, __prefix``addr_t) \
    `MEM_TYPEDEF_ALL(__prefix``mem_narr, __prefix``addr_t, __prefix``narr_data_t, \
        __prefix``narr_strb_t, __prefix``user_t) \
    `MEM_TYPEDEF_ALL(__prefix``mem_f, __prefix``addr_t, __prefix``f_mem_data_t, \
        __prefix``f_mem_strb_t, __prefix``user_t) \
    `MEM_TYPEDEF_ALL(__prefix``mem_j, __prefix``addr_t, __prefix``j_mem_data_t, \
        __prefix``j_mem_strb_t, __prefix``user_t)

`endif // LAGD_TYPEDEF_SVH_