# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

DOCKER=0
if docker -h >& /dev/null; then
    DOCKER=docker
elif podman -h >& /dev/null; then
    DOCKER=podman
else
    echo "Error: Docker or Podman not found"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
PROJECT_ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

$DOCKER run -it -v ${PROJECT_ROOT_DIR}:/lagd-im cheshire:latest