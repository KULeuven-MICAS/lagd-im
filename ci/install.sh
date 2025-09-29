# !/bin/bash

# Copyright 2025 KU Leuven.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

set -e
PROJECT_DIR=$(realpath $(dirname $0)/..)

# Check if pixi is installed, if not install it
if ! command -v pixi &> /dev/null
then 
    echo "pixi could not be found, installing it..."
    curl -fsSL https://pixi.sh/install.sh | sh
fi

# Install dependencies
pixi install

# Install bender
if ! command -v bender &> /dev/null
then 
    if ! command -v $HOME/.cargo/bin/bender &> /dev/null
    then 
        pixi run cargo install bender
    else
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
fi

# Checkout hardware dependencies
bender checkout

# Install RISCV GCC toolchain
RISCV_GCC_PATH=$PROJECT_DIR/.opt/riscv-gnu-toolchain
mkdir -p $RISCV_GCC_PATH
    
DISTRO=ubuntu-18.04
NIGHTLY=2022.11.12
TARGET=riscv64-elf

# Get the riscv-gnu-toolchain for elf target
# Note: 2022.11.12 is the last version supporting ubuntu-18.04 with glibc 2.27
# Rocky Linux 8 has glibc 2.28, so it is possible to run without container
RISCV_GCC_NAME=riscv-gcc-${NIGHTLY}-${DISTRO}-${TARGET}
curl -Ls -o ${RISCV_GCC_NAME}.tar.gz https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${NIGHTLY}/${TARGET}-${DISTRO}-nightly-${NIGHTLY}-nightly.tar.gz
chmod 777 ${RISCV_GCC_NAME}.tar.gz
mkdir -p ${RISCV_GCC_NAME} && chmod 777 ${RISCV_GCC_NAME}
tar -C ${RISCV_GCC_PATH} -xf ${RISCV_GCC_NAME}.tar.gz --strip-components=1
rm ${RISCV_GCC_NAME}.tar.gz