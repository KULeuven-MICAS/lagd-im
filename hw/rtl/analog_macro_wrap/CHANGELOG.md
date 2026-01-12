## 0.1.0 - 2026-1-7
- Initial release of RTL and a testbench.

## 0.1.1 - 2026-1-12
- Add convertion for J/h from 2's complemented format to specific format.
- Remove signal *synchronizer_mode_i* as it is not useful.
- Add signal *wbl_floating_o* and *spin_feedback_o* which are newly required by the analog macro.
- Spread spin output to the analog macro in WBL. Its location is configued by a new parameter *SPIN_WBL_OFFSET*.
- Move the synchronization starting timing to be one cycle earlier.
- Add isolation AND gate in analog_tx if SYN=1.