#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# This script cleans up Docker images and dangling images.

DOCKER=0
if docker -h >& /dev/null; then
    DOCKER=docker
elif podman -h >& /dev/null; then
    DOCKER=podman
else
    echo "Error: Docker or Podman not found"
    exit 1
fi

#This line is not general. buildah works better then podman rmi --force --cazziemazzi
buildah rm --all

# Remove all dangling images
$DOCKER rmi -f $($DOCKER images --filter "dangling=true" -q)

echo "Images:"
for i in $($DOCKER images --format "{{.Repository}}:{{.Tag}}"); do
    echo "  $i"
done