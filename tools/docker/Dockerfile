# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Use: $DOCKER build -t cheshire:latest -f tools/docker/Dockerfile --no-cache .

FROM ubuntu:22.04

RUN apt update
RUN apt upgrade -y
RUN apt install -y curl python3 build-essential git cmake pip 
RUN apt install -y autoconf automake autotools-dev  libmpc-dev libmpfr-dev libgmp-dev gawk bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
RUN apt install -y wget gdisk unzip

# Old riscv-gnu-toolchain used for occamy/hemaia
# # clone the required riscv-gnu-toolchain
# ARG RISCV_GCC_VERSION=8.3.0-2020.04.0
# # risvc-gnu-compiler
# RUN curl -Ls -o riscv-gcc.tar.gz https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-${RISCV_GCC_VERSION}-x86_64-linux-ubuntu14.tar.gz && \
#     mkdir -p /tools/riscv && chmod 777 /tools/riscv && \
#     tar -C /tools/riscv -xf riscv-gcc.tar.gz --strip-components=1  && \
#     rm -rf riscv-gcc.tar

# Install riscv-gnu-toolchain from source with arch and abi supporting CVA^
RUN git clone --recursive https://github.com/riscv/riscv-gnu-toolchain /tools/riscv
RUN cd /tools/riscv && \
    ./configure --prefix=/opt/riscv --with-arch=rv64gc_zifencei --with-abi=lp64d && \
    make -j8
ENV PATH="${PATH}:/tools/riscv/bin"

# install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="${PATH}:/root/.cargo/bin"

# bender
# ARG BENDER_VERSION=0.27.1
# RUN mkdir -p /tools/bender && chmod 777 /tools/bender && \
#    cd /tools/bender && curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init | bash -s -- ${BENDER_VERSION}
RUN cargo install bender
ENV PATH="${PATH}:/tools/bender"

# python3 dependencies from ../../third-parties/cheshire/requirements.txt

COPY  third_parties/cheshire/requirements.txt /requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -r /requirements.txt