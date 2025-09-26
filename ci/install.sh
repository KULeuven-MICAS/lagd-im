# !/bin/bash

set -e
PROJECT_DIR= $(realpath $(dirname $0)/..)

# Check if pixi is installed, if not install it
if ! command -v pixi &> /dev/null
then 
    echo "pixi could not be found, installing it..."
    curl -fsSL https://pixi.sh/install.sh | sh
fi

# Install dependencies
pixi install
# Install bender
pixi run cargo install bender

# Add bender to PATH
export PATH="$HOME/.cargo/bin:$PATH"
# Checkout hardware dependencies
bender checkout

# Install RISCV GCC toolchain
RISCV_GCC_PATH=$PROJECT_DIR/opt/riscv-gnu-toolchain
mkdir -p $RISCV_GCC_PATH
    
DISTO = ubuntu-18.04
NIGHTLY = 2022.11.12
TARGET = riscv64-elf

RISCV_GCC_NAME = riscv-gcc-${NIGHTLY}-${DISTO}-${TARGET}
curl -Ls -o ${RISCV_GCC_NAME}.tar.gz https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${NIGHTLY}/${TARGET}-${DISTO}-nightly-${NIGHTLY}-nightly.tar.gz
chmod 777 ${RISCV_GCC_NAME}.tar.gz
mkdir -p ${RISCV_GCC_NAME} && chmod 777 ${RISCV_GCC_NAME}
tar -C ${RISCV_GCC_NAME} -xf ${RISCV_GCC_NAME}.tar.gz --strip-components=1
rm ${RISCV_GCC_NAME}.tar.gz