# AutoTest

This folder contains all autotests for the LAGD chip.

`autotest_digital_macro.py`: verifies the function of digital_macro module in python (tqdm package is required).
`autotest_energy_monitor.py`: verifies the function of energy_monitor module in python (tqdm package is required).
`autotest_system.sh`: handles all the other verifications including the module level and the system level. It is in bash and automatically activates the local pixi environment. It saves output logs under `utils/logs/`.
