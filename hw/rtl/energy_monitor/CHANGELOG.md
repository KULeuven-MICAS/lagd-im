## 0.1.0 - 2025-11-27
- Initial release of RTL and a testbench.
- The latency is DATASPIN + PIPESMID + 1 cycles.
- Configurability: pipeline can be added at the module input interface and at the input interface of the middle adder tree. Bottle little-endian and big-endian are supported. The number of adder trees is configurable.
