#!/bin/sh
set -eu
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates git curl unzip xz-utils python3 python3-venv \
  build-essential clang cmake ninja-build pkg-config bison gperf \
  libgtk-3-dev libepoxy-dev libfontconfig1-dev libfreetype6-dev \
  libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev libdrm-dev libgbm-dev \
  liblzma-dev libzstd-dev libnss3-dev libasound2-dev
