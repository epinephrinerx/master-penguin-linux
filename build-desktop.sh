#!/bin/bash
# Build the desktop target with Buildroot.
#
# Buildroot supplies the cross toolchain, the kernel and the whole Wayland
# stack; this repo supplies PID 1 (src/mpinit.c, built as a Buildroot package)
# and everything under buildroot/board/rootfs-overlay.
#
# First run takes a couple of hours and downloads well over a gigabyte. Later
# runs only rebuild what changed — `make mpinit-rebuild all` is the fast path
# after editing the init.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
SRC="$PWD"
source ./config.sh

# On WSL the Windows PATH is appended to the Linux one, which drags in entries
# like "/mnt/c/Program Files/...". Buildroot refuses to start if PATH contains a
# space, tab or newline, so drop just those entries and keep the rest.
PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '[[:space:]]' | paste -sd: -)"
export PATH

# Ubuntu 26.04 ships the Rust uutils rewrite of coreutils as the default
# `install`, and Buildroot refuses to build against it — uutils/coreutils#12166.
# GNU install is on disk as gnuinstall; it just is not what /usr/bin/install
# points at.
if install --version 2>&1 | head -1 | grep -qi uutils; then
    cat >&2 <<'MSG'
error: /usr/bin/install is the uutils build, which Buildroot rejects.
       Register both and pick GNU:

         sudo update-alternatives --install /usr/bin/install install /usr/lib/cargo/bin/coreutils/install 50
         sudo update-alternatives --install /usr/bin/install install /usr/bin/gnuinstall 100
         sudo update-alternatives --set install /usr/bin/gnuinstall

       To go back:  sudo update-alternatives --set install /usr/lib/cargo/bin/coreutils/install
MSG
    exit 1
fi

BR_DIR="${BR_DIR:-$WORKDIR/buildroot}"
BR_OUTPUT="${BR_OUTPUT:-$WORKDIR/br-desktop}"
BR_VERSION="${BR_VERSION:-2026.08}"

if [ ! -d "$BR_DIR" ]; then
    echo "==> cloning buildroot into $BR_DIR"
    git clone -q https://gitlab.com/buildroot.org/buildroot.git "$BR_DIR"
fi

cd "$BR_DIR"
if [ "$(git describe --tags 2>/dev/null)" != "$BR_VERSION" ]; then
    echo "==> checking out buildroot $BR_VERSION"
    git fetch -q --tags
    git checkout -q "$BR_VERSION"
fi

mkdir -p "$BR_OUTPUT"

if [ ! -f "$BR_OUTPUT/.config" ]; then
    echo "==> generating config"
    make BR2_EXTERNAL="$SRC/buildroot" O="$BR_OUTPUT" master_penguin_defconfig
fi

echo "==> building (this is the long part)"
cd "$BR_OUTPUT"
make

echo
echo "==> images in $BR_OUTPUT/images:"
ls -lh "$BR_OUTPUT/images"
echo
echo "next: ./boot-desktop.sh"
