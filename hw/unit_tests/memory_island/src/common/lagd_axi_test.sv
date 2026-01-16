// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// This is incomplete: AXI sequential stimulus generator class

package lagd_axi_test;
    class axi_seq_master #(
        // AXI interface parameters
        parameter int unsigned AddrWidth = 48,
        parameter int unsigned DataWidth = 64,
        parameter int unsigned IdWidth   = 6,
        parameter int unsigned UserWidth = 2,
        // Stimuli application and test time
        parameter time AppTime = 0ps,
        parameter time TestTime = 0ps,
        // Maximum number of reand/writes in flight
        parameter int unsigned MaxReadTxns  = 1,
        parameter int unsigned MaxWriteTxns = 1,
        // Upper and lower bounds on wait cycles on Ax, W, and resp (R and B) channels
        parameter int unsigned AxMinWaitCycles = 0,
        parameter int unsigned AxMaxWaitCycles = 100,
        parameter int unsigned WMinWaitCycles  = 0,
        parameter int unsigned WMaxWaitCycles  = 5,
        parameter int unsigned RspMinWaitCycles  = 0,
        parameter int unsigned RspMaxWaitCycles  = 20,
        // AXI feature usage
        parameter int SizeAlign = 0,
        parameter bit AxiMaxBurstLen = 0,
        parameter bit TrafficShaping = 0,
        parameter bit AxiExcls = 1'b0,
        parameter bit AxiBurstFixed = 1'b0,
        parameter bit AxiBurstIncr = 1'b1,
        parameter bit AxiBurstWrap = 1'b0,
        parameter bit UniqueIds = 1'b0, // Among all in-flight transactions
        // Derived parameters
        parameter int unsigned AxiStrbWidth = DataWidth / 8,
        parameter int unsigned NumAxiIds = (1 << IdWidth),
        parameter int unsigned AxUserRange = 1,
        parameter bit AxUserRand = 0
    );

    typedef axi_test::axi_driver #(
        .AW(AddrWidth), .DW(DataWidth), .IW(IdWidth), .UW(UserWidth),
        .TA(AppTime), .TT(TestTime)
    ) axi_driver_t;
    typedef logic [AddrWidth-1:0] addr_t;
    typedef axi_pkg::burst_t burst_t;
    typedef axi_pkg::cache_t cache_t;
    typedef logic [DataWidth-1:0] data_t;
    typedef logic [IdWidth-1:0] id_t;
    typedef axi_pkg::len_t len_t;
    typedef axi_pkg::size_t size_t;
    typedef logic [UserWidth-1:0] user_t;
    typedef axi_pkg::mem_type_t mem_type_t;

    typedef axi_driver_t::ax_beat_t ax_beat_t;
    typedef axi_driver_t::b_beat_t b_beat_t;
    typedef axi_driver_t::r_beat_t r_beat_t;
    typedef axi_driver_t::w_beat_t w_beat_t;

    axi_driver_t drv;
    int unsigned r_flight_cnt [NumAxiIds-1:0];
    int unsigned w_flight_cnt [NumAxiIds-1:0];
    int unsigned total_r_flight_cnt, total_w_flight_cnt;
    
    len_t max_len;
    burst_t allowed_bursts [$];

    std::semaphore cnt_sem;
    ax_beat_t aw_queue [$];
    ax_beat_t w_queue [$];
    ax_beat_t excl_queue [$];

    typedef struct packed {
        addr_t     addr_begin;
        addr_t     addr_end;
        mem_type_t mem_type;
    } mem_region_t;
    mem_region_t mem_map[$];

    struct packed {
        int unsigned len  ;
        int unsigned size ;
        int unsigned cprob;
    } traffic_shape[$];
    int unsigned max_cprob;
    
    function new(
        virtual AXI_BUS_DV #(
            .AXI_ADDR_WIDTH(AW),
            .AXI_DATA_WIDTH(DW),
            .AXI_ID_WIDTH(IW),
            .AXI_USER_WIDTH(UW)
        ) axi
    );
        if (AxiMaxBurstLen <= 0 || AxiMaxBurstLen > 256) begin
            this.max_len = 255;
        end else begin
            this.max_len = AxiMaxBurstLen - 1;
        end
        this.drv = new(axi);
        this.cnt_sem = new(1);
        this.reset();
        if (AxiBurstFixed) begin
            this.allowed_bursts.push_back(AxiBurstFixed);
        end
        if (AxiBurstIncr) begin
            this.allowed_bursts.push_back(AxiBurstIncr);
        end
        if (AxiBurstWrap) begin
            this.allowed_bursts.push_back(AxiBurstWrap);
        end
        assert(allowed_bursts.size()) else $fatal(1, "At least one burst type has to be specified!");
    endfunction // new

    function void reset();
        drv.reset_master();
        r_flight_cnt = '{default: 0};
        w_flight_cnt = '{default: 0};
        tot_r_flight_cnt = 0;
        tot_w_flight_cnt = 0;
    endfunction : reset

    function void add_memory_region(input addr_t addr_begin, input addr_t addr_end, input mem_type_t mem_type);
        mem_map.push_back({addr_begin, addr_end, mem_type});
    endfunction : add_memory_region

    function void clear_memory_regions();
        mem_map.delete();
    endfunction : clear_memory_regions

    task run(input int n_reads, input int n_writes);
        automatic logic ar_done = 1'b0;
        automatic logic aw_done = 1'b0;
        send


endclass : axi_seq_master