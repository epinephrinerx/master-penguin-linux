#!/bin/bash
# Assemble the initramfs: busybox + initramfs/init, packed as gzipped cpio.
# This is only the bootstrap now — the real userland lives in the ext4 image.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
SRC="$PWD"
source ./config.sh

[ -d "$BUSYBOX_DIR/_install" ] || { echo "busybox not built yet — run ./build.sh first" >&2; exit 1; }

ROOT="$WORKDIR/initramfs-stage"
rm -rf "$ROOT"; mkdir -p "$ROOT"
cp -a "$BUSYBOX_DIR/_install/." "$ROOT/"
mkdir -p "$ROOT"/{proc,sys,dev,mnt/root}

install -m 0755 "$SRC/initramfs/init" "$ROOT/init"

cd "$ROOT"
# newc is the only cpio format the kernel's initramfs unpacker understands.
find . -print0 | cpio --null --create --format=newc 2>/dev/null | gzip -9 > "$INITRAMFS"
echo "initramfs $(du -h "$INITRAMFS" | cut -f1) -> $INITRAMFS"
