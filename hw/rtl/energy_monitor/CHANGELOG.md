## 0.1.0 - 2025-11-27
- Initial release of RTL and a testbench.
- The latency is DATASPIN + PIPESMID + 1 cycles.
- Configurability: pipeline can be added at the module input interface and at the input interface of the middle adder tree. Bottle little-endian and big-endian are supported. The number of adder trees is configurable.

## 0.1.1 - 2026-01-16
- Fix a bug that hbias_i and hscaling_i are not mapped to the corrent adder trees when PARALLELISM > 1.

## 1.1.0 - 2026-01-22
- Enable external counter to control the energy monitor's state machine, so that the flipping-based energy calculation is supported.