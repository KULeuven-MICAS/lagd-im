// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Copied from 
// https://github.com/pulp-platform/snitch_cluster/blob/5b2fccd96c42812774c20ab2f9b811e164809789/hw/mem_interface/include/mem_interface/typedef.svh#L38

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