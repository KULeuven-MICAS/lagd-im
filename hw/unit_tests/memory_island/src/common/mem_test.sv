// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`timescale 1ns/1ps

package mem_test;
  class mem_req_beat_c #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned UserWidth = 8,
    parameter int unsigned StrbWidth = DataWidth/8
  );
    rand logic [AddrWidth-1:0] addr;
    rand logic [DataWidth-1:0] data;
    rand logic [StrbWidth-1:0] strb;
    rand logic [UserWidth-1:0] user;
    rand bit write;
//  `LAGD_CLASS_PRINT_VARS(addr, data, strb, user)
  endclass : mem_req_beat_c

  class mem_rsp_beat_c #(
    parameter int unsigned DataWidth = 64
  );
    rand logic [DataWidth-1:0] data;
//  `LAGD_CLASS_PRINT_VARS(data)
  endclass : mem_rsp_beat_c

  class mem_driver #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned UserWidth = 8,
    parameter time ApplicationTime = 0ns,
    parameter time TestTime = 0ns,
    parameter int unsigned StrbWidth = DataWidth/8,
    parameter time TA = ApplicationTime,
    parameter time TT = TestTime
  );
    virtual mem_bus_dv_if #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .UserWidth(UserWidth),
      .StrbWidth(StrbWidth)
    ) mem_bus;

    typedef mem_req_beat_c #(AddrWidth, DataWidth, UserWidth, StrbWidth) req_beat_t;
    typedef mem_rsp_beat_c #(DataWidth) rsp_beat_t;

    function new(
      virtual mem_bus_dv_if #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .UserWidth(UserWidth),
        .StrbWidth(StrbWidth)
      ) mem_bus_i
    );
      this.mem_bus = mem_bus_i;
    endfunction : new

    function void reset_req();
      mem_bus.q.addr <= '0;
      mem_bus.q.data <= '0;
      mem_bus.q.strb <= '0;
      mem_bus.q.user <= '0;
      mem_bus.q_valid <= 1'b0;
    endfunction : reset_req

    function void reset_rsp();
      mem_bus.q_ready <= 1'b0;
      mem_bus.p.valid <= 1'b0;
      mem_bus.p.data <= '0;
    endfunction : reset_rsp

    task cycle_start();
      #TT;
    endtask : cycle_start

    task cycle_end();
      @(posedge mem_bus.clk_i);
    endtask : cycle_end

    //======================================================================
    // Master send/receive tasks
    //======================================================================

    task send_req(
      input req_beat_t beat
    );
      mem_bus.q.addr <= #TA beat.addr;
      mem_bus.q.data <= #TA beat.data;
      mem_bus.q.strb <= #TA beat.strb;
      mem_bus.q.user <= #TA beat.user;
      mem_bus.q_valid <= #TA 1'b1;
      wait (mem_bus.q_ready);
      cycle_end();
      wait (mem_bus.p.valid);
      mem_bus.q_valid <= #TA 1'b0;
    endtask : send_req

    task recv_rsp(
      output rsp_beat_t beat
    );
      wait (mem_bus.p.valid);
      beat.data = mem_bus.p.data;
    endtask : recv_rsp

    //======================================================================
    // Slave send/receive tasks
    //======================================================================
    // TODO

    //======================================================================
    // Monitor tasks
    //======================================================================
    // TODO

  endclass : mem_driver

  class mem_rand_master #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned UserWidth = 8,
    parameter time ApplicationTime = 0ns,
    parameter time TestTime = 0ns,
    parameter int unsigned StrbWidth = DataWidth/8,
    parameter time TA = ApplicationTime,
    parameter time TT = TestTime
  );

    // ======================================================================
    // Type definitions
    // ======================================================================

    typedef logic [AddrWidth-1:0] addr_t;
    typedef logic [DataWidth-1:0] data_t;
    typedef logic [UserWidth-1:0] user_t;
    typedef logic [StrbWidth-1:0] strb_t;

    typedef mem_test::mem_driver #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .UserWidth(UserWidth),
      .ApplicationTime(ApplicationTime),
      .TestTime(TestTime),
      .StrbWidth(StrbWidth),
      .TA(TA),
      .TT(TT)
    ) mem_driver_t;
    mem_driver_t drv;

    typedef struct packed {
      addr_t     addr_begin;
      addr_t     addr_end;
    } mem_region_t;
    mem_region_t mem_map[$];
    
    typedef mem_req_beat_c #(AddrWidth, DataWidth, UserWidth, StrbWidth) req_beat_t;


    function new(
      virtual mem_bus_dv_if #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .UserWidth(UserWidth),
        .StrbWidth(StrbWidth)
      ) mem_bus_i
    );
      this.drv = new(mem_bus_i);
      this.reset();
    endfunction : new

    function void reset();
      drv.reset_req();
    endfunction : reset

    function void add_memory_region(
      longint unsigned start_addr,
      longint unsigned end_addr
    );
      mem_map.push_back( {start_addr, end_addr} );
    endfunction : add_memory_region

    function req_beat_t new_rand_req(input user_t user);
      automatic req_beat_t beat = new;
      automatic logic rand_success;
      automatic int unsigned mem_region_idx;
      automatic mem_region_t mem_region;
      automatic addr_t addr;
      
      // Pick a random memory region
      if (mem_map.size() == 0) begin
        $fatal(1, "No memory regions defined!");
      end
      rand_success = std::randomize(mem_region_idx) with {
        mem_region_idx < mem_map.size();
      }; assert(rand_success);
      mem_region = mem_map[mem_region_idx];
      
      // Randomize address within region
      rand_success = std::randomize(addr) with {
        addr >= mem_region.addr_begin;
        addr <= mem_region.addr_end;
      }; assert(rand_success);
      beat.addr = addr;
      
      rand_success = std::randomize(beat.data); assert(rand_success);  // Random data
      beat.strb = '1;  // Set full write strobe
      beat.user = user;  // Set user field
      beat.write = 1'b1;  // Set write operation
      return beat;
    endfunction : new_rand_req

    function int unsigned gen_rand_wait(input int unsigned MaxInterval);
      automatic int unsigned delay_cycles;
      automatic logic rand_success;
      rand_success = std::randomize(delay_cycles) with {
        delay_cycles < MaxInterval;
      }; assert(rand_success);
      return delay_cycles;
    endfunction : gen_rand_wait

    task run(input user_t user = '0, input int unsigned NumTransactions = 100,
             input int unsigned RandInterval = 1, input int unsigned RandBurst = 0);
      automatic req_beat_t write_beat, read_beat;
      automatic mem_driver_t::rsp_beat_t rsp_beat_wr, rsp_beat_rd;
      
      $display("[%0t] Starting memory test with %0d transactions", $time, NumTransactions);
      
      for (int i = 0; i < NumTransactions; i++) begin
        // Generate and send write request
        write_beat = new_rand_req(user);
        $display("[%t] Transaction %d: Writing 0x%h to address 0x%h", 
                 $time, i, write_beat.data, write_beat.addr);
        fork
          drv.send_req(write_beat);
          drv.recv_rsp(rsp_beat_wr);
        join

        // Generate and send read request to same address
        read_beat = new;
        read_beat.addr = write_beat.addr;
        read_beat.data = '0;  // Don't care for reads
        read_beat.strb = '1;
        read_beat.user = user;
        read_beat.write = 1'b0;  // Read operation
        
        if (RandInterval > 0) begin
          repeat (gen_rand_wait(RandInterval)) @(posedge drv.mem_bus.clk_i);
        end

        $display("[%t] Transaction %d: Reading from address 0x%h", 
                 $time, i, read_beat.addr);
        fork
          drv.send_req(read_beat);
          drv.recv_rsp(rsp_beat_rd);
        join
        
        // Verify data matches
        if (rsp_beat_rd.data !== write_beat.data) begin
          $error("[%t] Transaction %d: Data mismatch! Expected 0x%h, got 0x%h at address 0x%h",
                 $time, i, write_beat.data, rsp_beat_rd.data, write_beat.addr);
        end else begin
          $display("[%t] Transaction %d: Data verified successfully (0x%h)", 
                   $time, i, rsp_beat_rd.data);
        end

        if(RandBurst > 0) begin
          repeat (gen_rand_wait(RandBurst)) @(posedge drv.mem_bus.clk_i);
        end
      end
      
      $display("[%t] Memory test completed: %0d transactions", $time, NumTransactions);
    endtask : run

  endclass : mem_rand_master
endpackage : mem_test