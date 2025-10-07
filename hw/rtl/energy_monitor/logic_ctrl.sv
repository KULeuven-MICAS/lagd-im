// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Logic FSM for the energy monitor module.
//

// TODO: add debug mode (execution in step)

`include "../lib/registers.svh"

module logic_ctrl (
    input logic clk_i, // input clock signal
    input logic rst_ni, // asynchornous reset, active low
    input logic en_i, // module enable signal

    input logic config_valid_i, // input config valid signal
    output logic config_ready_o, // output config ready signal

    input logic spin_valid_i, // input spin valid signal
    output logic spin_ready_o, // output spin ready signal

    input logic weight_valid_i, // input weight valid signal
    output logic weight_ready_o, // output weight ready signal

    input logic counter_ready_i, // counter ready signal
    input logic cmpt_done_i, // computation done signal

    output logic energy_valid_o, // output energy valid signal
    input logic energy_ready_i, // input energy ready signal

    input logic debug_en_i // debug step signal
);
    // State enumeration
    typedef enum logic [1:0] {
        SLEEP = 2'b00,
        IDLE = 2'b01,
        LOAD = 2'b10,
        COMPUTE = 2'b11
    } state_t;
    state_t current_state, next_state;

    assign config_ready_o = (current_state == IDLE);
    assign spin_ready_o = (current_state == IDLE);
    assign weight_ready_o = (current_state == LOAD);
    assign energy_valid_o = (current_state == COMPUTE) && counter_ready_i && cmpt_done_i;

    `FFL(current_state, next_state, en_i, SLEEP, clk_i, rst_ni)

    always_comb begin
        next_state = current_state;
        case (current_state)
            SLEEP: begin
                if (en_i) begin
                    next_state = IDLE;
                end
            end
            IDLE: begin
                if (!en_i) begin
                    next_state = SLEEP;
                end else begin
                    if (debug_en_i)
                        next_state = IDLE; // stay in IDLE in debug mode
                    else begin
                        if (spin_valid_i && spin_ready_o)
                            next_state = LOAD;
                    end
                end
            end
            LOAD: begin
                if (!en_i) begin
                    next_state = SLEEP;
                end else begin
                    if (debug_en_i)
                        next_state = LOAD; // stay in LOAD in debug mode
                    else begin
                        if (weight_valid_i && weight_ready_o)
                            next_state = COMPUTE;
                    end
                end
            end
            COMPUTE: begin
                if (!en_i) begin
                    next_state = SLEEP;
                end else begin
                    if (debug_en_i)
                        next_state = COMPUTE; // stay in COMPUTE in debug mode
                    else begin
                        case ({energy_ready_i, counter_ready_i, cmpt_done_i})
                            3'b000: next_state = COMPUTE; // wait for the next cmpt_done
                            3'b001: next_state = LOAD;
                            3'b010: next_state = COMPUTE; // wait for the next cmpt_done
                            3'b011: next_state = COMPUTE; // wait for energy_ready_i
                            3'b100: next_state = COMPUTE;
                            3'b101: next_state = LOAD;
                            3'b110: next_state = COMPUTE; // wait for the next cmpt_done
                            3'b111: next_state = IDLE;
                            default: next_state = SLEEP;
                        endcase
                    end
                end
            end
            default: begin
                next_state = SLEEP;
            end
        endcase
    end
endmodule