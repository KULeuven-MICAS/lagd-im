# Cheshire Configuration Type documentation

The `cheshire_cfg_t` SystemVerilog struct defines the configuration parameters for the Cheshire system-on-chip (SoC) architecture. This struct includes a variety of parameters that control the behavior and features of the SoC, including core settings, interrupt configurations, AXI bus parameters, and peripheral options.
The original definition can be found in the [cheshire_cfg_t.sv](../src/cheshire/cheshire_cfg_t.sv) file.
The original documentation can be found in this link: [cheshire](https://pulp-platform.github.io/cheshire/um/arch/#memory-map).

```systemverilog
    // Bit vector types for parameters.
    //We limit range to keep parameters sane.
    typedef bit [ 7:0] byte_bt;
    typedef bit [15:0] shrt_bt;
    typedef bit [31:0] word_bt;
    typedef bit [63:0] doub_bt;
    
    //❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔
    typedef bit [ 9:0] dw_bt;     // data widths
    typedef bit [ 5:0] aw_bt;     // address, ID widths or small buffers
    //❔❔❔❔❔❔❔ why this weird bitwidths ❔❔❔❔❔❔❔❔❔❔
    
    // Externally controllable parameters
    typedef struct packed {
        // CVA6 parameters
        // Return Address Stack depth
        shrt_bt Cva6RASDepth;
        // Branch Target Buffer entries                                                           
        shrt_bt Cva6BTBEntries;
        shrt_bt Cva6BHTEntries;                                                         // Branch History Table entries
        shrt_bt Cva6NrPMPEntries;                                                       // Number of PMP entries

        // To reduce parameterization entropy, the range [0x2.., 0x8..) is defined to contain exactly
        // one cached, idempotent, and executable (CIE) and one non-CIE region. The parameters below
        // control the CIE region's size and whether it abuts with the top or bottom of this range.
        doub_bt Cva6ExtCieLength;                                                       // Length of CIE region in bytes 
        bit     Cva6ExtCieOnTop;                                                        // CIE region is at top of range, or bottom 
                                                                                        //(default=0 - CIE at bottom [0x2.., 0x4..))
        // Hart parameters
        bit [MaxCoresWidth-1:0] NumCores;                                               // Number of CVA6 cores (max 32)     
        doub_bt NumExtIrqHarts;
        doub_bt NumExtDbgHarts;
        // ❔❔❔❔❔ Limits for outstanding transactions ❔❔❔❔❔
        doub_bt CoreUserAmoOffs;                                                        // Base offset for core IDs within user AMO range
        dw_bt     CoreMaxTxns;                                                          // Maximum total AXI4 transactions per core
        dw_bt     CoreMaxTxnsPerId;                                                     // Maximum AXI4 transactions per core and ID 
        // ❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔❔
        // Interrupt parameters
        doub_bt NumExtInIntrs;
        shrt_bt NumExtClicIntrs;
        byte_bt NumExtOutIntrTgts;
        shrt_bt NumExtOutIntrs;
        shrt_bt ClicIntCtlBits;
        shrt_bt NumExtIntrSyncs;
        
        //---------------------------- AXI parameters --------------------------------------------
        // AXI address width (default=48)
        aw_bt     AddrWidth;
        // AXI data width (default=64)
        dw_bt     AxiDataWidth;
        // AXI user width (default=2) --> AMO + normal port?
        dw_bt     AxiUserWidth;
        // AXI master ID width (default=2) ❔
        aw_bt     AxiMstIdWidth;
        // Max inflight AXI transactions per master and slave (default=24)
        dw_bt     AxiMaxMstTrans;
        dw_bt     AxiMaxSlvTrans;
        // User signals identify atomics masters.
        // A '0 user signal indicates no atomics.
        // Convention: lower AMO bits for cores, MSB for serial link (default=2bits)
        dw_bt     AxiUserAmoMsb;
        dw_bt     AxiUserAmoLsb;
        // AXI4 user channel bit-range for custom errors
        dw_bt     AxiUserErrBits;
        dw_bt     AxiUserErrLsb;
        // Default user assignment, adjusted by user features (AMO) (default=0)
        doub_bt AxiUserDefault;
        // Reg parameters
        dw_bt     RegMaxReadTxns;
        dw_bt     RegMaxWriteTxns;
        // Number of timing cuts inside Regbus AMO filter
        aw_bt     RegAmoNumCuts;
        // Whether to insert a cut after Regbus AMO filter
        bit         RegAmoPostCut;
        // Whether to insert a cut inside AXI-to-Rb. adapter
        bit         RegAdaptMemCut;
        
        // External AXI ports (limited number of ports and rules)
        bit         [MaxExtAxiMstWidth-1:0]         AxiExtNumMst;
        bit         [MaxExtAxiSlvWidth-1:0]         AxiExtNumSlv;
        bit         [MaxExtAxiSlvWidth-1:0]         AxiExtNumRules;
        byte_bt [2**MaxExtAxiSlvWidth-1:0]    AxiExtRegionIdx;
        doub_bt [2**MaxExtAxiSlvWidth-1:0]    AxiExtRegionStart;
        doub_bt [2**MaxExtAxiSlvWidth-1:0]    AxiExtRegionEnd;
        // External reg slaves (limited number of ports and rules)
        bit         [MaxExtRegSlvWidth-1:0]         RegExtNumSlv;
        bit         [MaxExtRegSlvWidth-1:0]         RegExtNumRules;
        byte_bt [2**MaxExtRegSlvWidth-1:0]    RegExtRegionIdx;
        doub_bt [2**MaxExtRegSlvWidth-1:0]    RegExtRegionStart;
        doub_bt [2**MaxExtRegSlvWidth-1:0]    RegExtRegionEnd;
        // Real-time clock speed
        word_bt RtcFreq;                                                                // RTC frequency in Hz
        // Address of platform ROM
        word_bt PlatformRom;                                                            // Address of platform ROM (not in defaul map)
        // Enabled hardware features
        bit         Bootrom;                                                            // Boot ROM (1 in default map)
        bit         Uart;                                                               // UART (1 in default map) 
        bit         I2c;                                                                // I2C (1 in default map)
        bit         SpiHost;                                                            // SPI Host (1 in default map)
        bit         Gpio;                                                               // GPIO (1 in default map)
        bit         Dma;                                                                // DMA (1 in default map)
        bit         SerialLink;                                                         // Serial Link (1 in default map)
        bit         Vga;                                                                // VGA (1 in default map)
        bit         Usb;                                                                // USB (1 in default map)

        bit         AxiRt;                                                              // AXI RT (0 in default map)
        // ❔ Disabled features because there is one in the CLINC❔
        bit         Clic;                                                               // CLIC (0 in default map)
        // Core Local Interrupt Controller
        bit         IrqRouter;                                                          // Interrupt Router (0 in default map)
        // IRQ Router routs interrupts to specific cores
        bit         BusErr;                                                             // Bus Error Unit (1 in default map)
        // Universal Non-intrusive Bus Error Notification & Tracking (UNBENT)
        
        // Parameters for Debug Module
        jtag_idcode_t DbgIdCode;
        dw_bt     DbgMaxReqs;
        dw_bt     DbgMaxReadTxns;
        dw_bt     DbgMaxWriteTxns;
        aw_bt     DbgAmoNumCuts;
        bit         DbgAmoPostCut;
        // Parameters for LLC
        bit         LlcNotBypass;
        shrt_bt LlcSetAssoc;
        shrt_bt LlcNumLines;
        shrt_bt LlcNumBlocks;
        dw_bt     LlcMaxReadTxns;
        dw_bt     LlcMaxWriteTxns;
        aw_bt     LlcAmoNumCuts;
        bit         LlcAmoPostCut;
        bit         LlcOutConnect;
        doub_bt LlcOutRegionStart;
        doub_bt LlcOutRegionEnd;
        // Parameters for VGA
        byte_bt VgaRedWidth;
        byte_bt VgaGreenWidth;
        byte_bt VgaBlueWidth;
        aw_bt     VgaHCountWidth;
        aw_bt     VgaVCountWidth;
        dw_bt     VgaBufferDepth;
        dw_bt     VgaMaxReadTxns;
        // Parameters for Serial Link
        dw_bt     SlinkMaxTxnsPerId;
        dw_bt     SlinkMaxUniqIds;
        shrt_bt SlinkMaxClkDiv;
        doub_bt SlinkRegionStart;
        doub_bt SlinkRegionEnd;
        doub_bt SlinkTxAddrMask;
        doub_bt SlinkTxAddrDomain;
        dw_bt     SlinkUserAmoBit;
        // Parameters for USB
        dw_bt     UsbDmaMaxReads;
        doub_bt UsbAddrMask;
        doub_bt UsbAddrDomain;
        // Parameters for DMA
        dw_bt     DmaConfMaxReadTxns;
        dw_bt     DmaConfMaxWriteTxns;
        aw_bt     DmaConfAmoNumCuts;
        bit         DmaConfAmoPostCut;
        bit         DmaConfEnableTwoD;
        dw_bt     DmaNumAxInFlight;
        dw_bt     DmaMemSysDepth;
        aw_bt     DmaJobFifoDepth;
        bit         DmaRAWCouplingAvail;
        // Parameters for GPIO
        bit         GpioInputSyncs;
        // Parameters for AXI RT
        aw_bt     AxiRtNumPending;
        dw_bt     AxiRtWBufferDepth;
        aw_bt     AxiRtNumAddrRegions;
        bit         AxiRtCutPaths;
        bit         AxiRtEnableChecks;
    } cheshire_cfg_t;
```