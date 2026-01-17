`define True 1'b1
`define False 1'b0

// Configuration package for digital macro unit tests
package config_pkg;
    // design-time parameters
    parameter int NUM_SPIN = 256;
    parameter int BITDATA = 4;
    parameter int SCALING_BIT = 5;
    parameter int LITTLE_ENDIAN = `False; // True: little endian, False: big endian
    parameter int PIPESINTF = 1;
    parameter int PIPESMID = 1;
    parameter int PARALLELISM = 4;
    parameter int BypassDataConversion = `False;
    parameter int ENERGY_TOTAL_BIT = 32;
    parameter int SPIN_DEPTH = 2;
    parameter int FLIP_ICON_DEPTH = 1024;
    parameter int COUNTER_BITWIDTH = 16;
    parameter int SYNCHRONIZER_PIPEDEPTH = 3;
    parameter int SPIN_WBL_OFFSET = 0;
    parameter int H_IS_NEGATIVE = `True;

    // run-time parameters (related to algorithm)
    parameter int IconLastAddrPlusOne = 1024;
    parameter int EnComparison = `True;
    parameter int FlipDisable = `False;
    parameter int EnableAnalogLoop = `True;

    // run-time parameters (related to hardware)
    parameter int CyclePerWwlHigh = 5;
    parameter int CyclePerWwlLow = 5;
    parameter int CyclePerSpinWrite = 3;
    parameter int CyclePerSpinCompute = 7;
    parameter int SynchronizerPipeNum = 3;
    parameter int SpinWwlStrobe = {NUM_SPIN{1'b1}};
    parameter int SpinFeedback = {NUM_SPIN{1'b1}}; // all spins in feedback mode
    parameter int Flush = `False;

    // derived parameters
    parameter int BITJ = BITDATA;
    parameter int BITH = BITDATA;
    parameter int EmCfgCounter = NUM_SPIN - 1;
endpackage
