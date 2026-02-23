// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: axi_to_mem_adapter

// Description: Adapter for a single AXI req/rsp channel to memory req/rsp interfaces

// Parameters:
//      axi_req_t / axi_rsp_t: AXI request/response typedefs.
//      mem_req_t / mem_rsp_t: Memory request/response typedefs (see include/typedef.svh).
//      AddrWidth, IdWidth: AXI-side configuration.
//      DataWidth: Memory port data width.
//      BufDepth: Internal buffering depth passed through.
//      ReadWrite: 
//          0 = read-only (single memory port). 
//          1 = parallel read/write (two memory ports, split).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      axi_req_i / axi_rsp_o: AXI interface.
//      mem_req_o / mem_rsp_i: memory interfaces.
//          [ReadWrite:0] 1 or 2 memory ports depending on ReadWrite.

// Limitations:
// No handling of exclusive / atomic (mem_atop_o left unconnected).
// No separate test_i 
// No busy_o (backpressure on master side) implemented.
//      Assumption is that the AXI master can always stall.

// Testing:
//      No verification yet.
//      Synthesis only with ReadWrite=0 so far.


module axi_to_mem_adapter #(
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,
    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic,
    parameter int unsigned AddrWidth = 0,
    parameter int unsigned DataWidth = 0,
    parameter int unsigned IdWidth = 0,
    parameter int unsigned BufDepth = 0,
    parameter bit ReadWrite = 1'b0
)(
    input logic clk_i,
    input logic rst_ni,

    input axi_req_t axi_req_i,
    output axi_rsp_t axi_rsp_o,

    input mem_rsp_t mem_rsp_i,
    output mem_req_t mem_req_o
);

    axi_to_mem #(
        .axi_req_t(axi_req_t),
        .axi_resp_t(axi_rsp_t),
        .AddrWidth(AddrWidth),
        .IdWidth(IdWidth),
        .DataWidth(DataWidth),
        .BufDepth(BufDepth),
        .NumBanks(1),
        .HideStrb(1'b0),
        .OutFifoDepth(1)
    ) i_narrow_conv (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .busy_o(),
        .axi_req_i(axi_req_i),
        .axi_resp_o(axi_rsp_o),
        .mem_req_o(mem_req_o.q_valid),
        .mem_gnt_i(mem_rsp_i.q_ready),
        .mem_addr_o(mem_req_o.q.addr),
        .mem_wdata_o(mem_req_o.q.data),
        .mem_strb_o(mem_req_o.q.strb),
        .mem_atop_o(),
        .mem_we_o(mem_req_o.q.write),
        .mem_rvalid_i(mem_rsp_i.p.valid),
        .mem_rdata_i(mem_rsp_i.p.data)
    );

    `ifdef TARGET_LOG_INSTS
    $info("Instantiated axi_to_mem_adapter with parameters:");
    `ifndef TARGET_SYNOPSYS
    $info("Module: %m");
    $info("  axi_req_t: %s", $typename(axi_req_i));
    $info("  axi_rsp_t: %s", $typename(axi_rsp_o));
    $info("  mem_req_t: %s", $typename(mem_req_o[0]));
    $info("  mem_rsp_t: %s", $typename(mem_rsp_i[0]));
    `endif
    $info("  AddrWidth: %d", AddrWidth);
    $info("  DataWidth: %d", DataWidth);
    $info("  IdWidth: %d", IdWidth);
    $info("  BufDepth: %d", BufDepth);
    $info("  ReadWrite: %b", ReadWrite);
    `endif // TARGET_LOG_INSTS
endmodule
