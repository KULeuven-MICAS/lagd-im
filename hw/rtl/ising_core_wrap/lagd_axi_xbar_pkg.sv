// Copyright (c) 2014-2020 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// - Thomas Benz <tbenz@iis.ee.ethz.ch>
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// - Cyril Koenig <cykoenig@iis.ee.ethz.ch>
// - Matheus Cavalcante <matheusd@iis.ee.ethz.ch>

// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for AXI crossbar interface definitions

package lagd_axi_xbar_pkg;

  /// Configuration for `axi_xbar`.
  typedef struct packed {
    /// Number of slave ports of the crossbar.
    /// This many master modules are connected to it.
    int unsigned   NoSlvPorts;
    /// Number of master ports of the crossbar.
    /// This many slave modules are connected to it.
    int unsigned   NoMstPorts;
    /// Maximum number of open transactions each master connected to the crossbar can have in
    /// flight at the same time.
    int unsigned   MaxMstTrans;
    /// Maximum number of open transactions each slave connected to the crossbar can have in
    /// flight at the same time.
    int unsigned   MaxSlvTrans;
    /// Determine if the internal FIFOs of the crossbar are instantiated in fallthrough mode.
    /// 0: No fallthrough
    /// 1: Fallthrough
    bit            FallThrough;
    /// The Latency mode of the xbar. This determines if the channels on the ports have
    /// a spill register instantiated.
    /// Example configurations are provided with the enum `xbar_latency_e`.
    bit [9:0]      LatencyMode;
    /// This is the number of `axi_multicut` stages instantiated in the line cross of the channels.
    /// Having multiple stages can potentially add a large number of FFs!
    int unsigned   PipelineStages;
    /// AXI ID width of the salve ports. The ID width of the master ports is determined
    /// Automatically. See `axi_mux` for details.
    int unsigned   AxiIdWidthSlvPorts;
    /// The used ID portion to determine if a different salve is used for the same ID.
    /// See `axi_demux` for details.
    int unsigned   AxiIdUsedSlvPorts;
    /// Are IDs unique?
    bit            UniqueIds;
    /// AXI4+ATOP address field width.
    int unsigned   AxiAddrWidth;
    /// AXI4+ATOP data field width.
    int unsigned   AxiDataWidth;
    /// The number of address rules defined for routing of the transactions.
    /// Each master port can have multiple rules, should have however at least one.
    /// If a transaction can not be routed the xbar will answer with an `axi_pkg::RESP_DECERR`.
    int unsigned   NoAddrRules;
  } xbar_cfg_t;

  /// Commonly used rule types for `axi_xbar` (32-bit addresses).
  typedef struct packed {
    int unsigned idx;
    logic [31:0] start_addr;
    logic [31:0] end_addr;
  } xbar_rule_32_t;

endpackage : lagd_axi_xbar_pkg