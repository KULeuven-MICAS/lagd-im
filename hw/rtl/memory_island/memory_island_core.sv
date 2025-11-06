// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

module memory_island_core import memory_island_pkg::*; #(
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,

    parameter mem_cfg_t Cfg = default_mem_cfg(),
    
    // Derived parameters - do not touch
    parameter int unsigned NumNarrowReq = Cfg.NumDirectNarrowReq + $countones(Cfg.NarrowRW) +
        NumAxiNarrowReq,
    parameter int unsigned NumWideReq = Cfg.NumDirectWideReq + $countones(Cfg.WideRW) +
        NumAxiWideReq
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_narrow_req_t [NumNarrowReq-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumNarrowReq-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [NumWideReq-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumWideReq-1:0] mem_wide_rsp_o
);

endmodule : memory_island_core