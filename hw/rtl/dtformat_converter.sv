// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// 2C to SM (pure combinational, no clk/enable signal).
//
// Parameters:
// - N: number of data
// - DATAW: bit precision of each data

module dtformat_converter #(
    parameter int N = 256,
    parameter int DATAW = 4
)(
    input logic [N-1:0][DATAW-1:0] data_2c_i, // data in 2's complement format
    output logic [N-1:0][DATAW-1:0] data_sm_o // data in signed magnitude format
);

    always_comb begin
        for (int i = 0; i < N; i++) begin
            if (data_2c_i[i][DATAW-1] == 1'b0) begin
                data_sm_o[i] = $signed(data_2c_i[i]);
            end else begin
                data_sm_o[i] = $signed({1'b1, (~data_2c_i[i][DATAW-2:0]) + 1'b1});
            end
        end
    end

endmodule