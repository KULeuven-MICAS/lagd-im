// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// N-to-1 mux for a vector.
//
// Parameters:
// - DATAWIDTH: data width

module vector_mux #(
    parameter int DATAWIDTH = 256,
    parameter int IDX_BIT = $clog2(DATAWIDTH)
) (
    input en_i,
    input [DATAWIDTH-1:0] data_i,
    input [IDX_BIT-1:0] idx_i,
    output data_o
);

assign data_o = (en_i) ? data_i[idx_i] : '0;

endmodule