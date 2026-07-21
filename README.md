
# LAGD Ising RTL

This repository is for the hardware implementation of the Ising LAGD chip.

**Warning**: this repository takes around 8.0 GB of disk size

## Getting the sources

To download, run the following code:

```bash
$ git clone --recurse-submodules `git@github.com:KULeuven-MICAS/lagd-im.git`
$ ./ci/install.sh
$ cd lagd-im/.bender/git/checkouts/cheshire-4912d4aca2fac633
$ mkdir -p target/sim/models
$ cd target/sim/models
$ wget --no-check-certificate https://freemodelfoundry.com/fmf_vlog_models/flash/s25fs512s.v -O s25fs512s.v
$ wget https://ww1.microchip.com/downloads/en/DeviceDoc/24xx1025_Verilog_Model.zip -O 24xx1025_Verilog_Model.zip
$ unzip -o 24xx1025_Verilog_Model.zip -d .
$ rm -f 24xx1025_Verilog_Model.zip 24AA1025.v 24LC1025.v
```

These commands will install the following tools:

1. Pixi (for dependency management)
   Warning: after installing Pixi, please restart your terminal and run the script again
   We recommend to install Pixi before running the script
2. Dependency libraries (see pixi.toml)
3. Bender (for hardware dependency management)
4. Hardware dependencies (see Bender.yml)
5. RISC-V GNU Toolchain (for software compilation)
6. Simulation behavior model required by Cheshire for SPI (s25fs512s.v) and I2C (24FC1025.v)

## Third-party libraries

1. [Cheshire](https://github.com/pulp-platform/cheshire) - Pulp Cheshire SoC V0.3.1 (tag=v0.3.1-1-g3d9aefb)

## GitHub Actions list

### Linting

1. License check (pulp-platform/pulp-actions/lint-license@v2.4.1)
2. Verible lint (chipsalliance/verible-linter-action@main)
   - Verible version: v0.0-4017-g62aee204
3. Yaml lint (ibiqlik/action-yamllint@v3)
4. Python lint (py-actions/flake8@v2)
   - Python version: 3.11
   - Flake8 version: 6.0.0
5. Clang-format check (DoozyX/clang-format-lint-action@v0.16.2)
   - Clang-format version: 14
6. EditorConfig check (editorconfig-checker/action-editorconfig-checker@main)
7. TCL lint
    - Tclint version 0.4.2
