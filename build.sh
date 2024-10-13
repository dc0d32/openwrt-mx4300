#!/bin/bash

make -j$(nproc) download $1
make -j$(nproc) tools/ccache/compile $1
export CONFIG_CCACHE=y
make -j$(nproc) $1

