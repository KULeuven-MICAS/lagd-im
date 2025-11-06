// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Adapted from 
// https://github.com/pulp-platform/cheshire/blob/main/hw/include/cheshire/typedef.svh
// https://github.com/pulp-platform/snitch_cluster/blob/5b2fccd96c42812774c20ab2f9b811e164809789/hw/mem_interface/include/mem_interface/typedef.svh#L38

`ifndef LAGD_TYPEDEF_SVH_
`define LAGD_TYPEDEF_SVH_

`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

// ==================
// AXI TYPEDEFS
// ==================

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

// ==================
// MEMORY TYPEDEFS
// ==================

`define MEM_TYPEDEF_REQ_CHAN_T(__req_chan_t, __addr_t, __data_t, __strb_t, __user_t) \
  typedef struct packed { \
    __addr_t             addr;  \
    logic                write; \
    __data_t             data;  \
    __strb_t             strb;  \
    __user_t             user;  \
  } __req_chan_t;

`define MEM_TYPEDEF_RSP_CHAN_T(__rsp_chan_t, __data_t) \
  typedef struct packed { \
    __data_t data;        \
    logic    valid;       \
  } __rsp_chan_t;

`define MEM_TYPEDEF_REQ_T(__req_t, __req_chan_t) \
  typedef struct packed { \
    __req_chan_t q;       \
    logic        q_valid; \
  } __req_t;

`define MEM_TYPEDEF_RSP_T(__rsp_t, __rsp_chan_t) \
  typedef struct packed { \
    __rsp_chan_t p;       \
    logic        q_ready; \
  } __rsp_t;

`define MEM_TYPEDEF_ALL(__name, __addr_t, __data_t, __strb_t, __user_t) \
  `MEM_TYPEDEF_REQ_CHAN_T(__name``_req_chan_t, __addr_t, __data_t, __strb_t, __user_t) \
  `MEM_TYPEDEF_RSP_CHAN_T(__name``_rsp_chan_t, __data_t) \
  `MEM_TYPEDEF_REQ_T(__name``_req_t, __name``_req_chan_t) \
  `MEM_TYPEDEF_RSP_T(__name``_rsp_t, __name``_rsp_chan_t)

`endif // LAGD_TYPEDEF_SVH_