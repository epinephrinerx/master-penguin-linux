#!/bin/bash
# Build the real root filesystem as an ext4 image.
#
# mke2fs -d populates the image straight from a directory, so this needs no
# loop mount and no root. The one thing it cannot do is create device nodes —
# which is fine, because the initramfs moves devtmpfs across instead.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
SRC="$PWD"
source ./config.sh

[ -d "$BUSYBOX_DIR/_install" ] || { echo "busybox not built yet — run ./build.sh first" >&2; exit 1; }

STAGE="$WORKDIR/rootfs-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"

cp -a "$BUSYBOX_DIR/_install/." "$STAGE/"   # userland
cp -a "$SRC/rootfs/." "$STAGE/"             # the skeleton tracked in git

# Empty directories cannot be carried in git, so create them here.
mkdir -p "$STAGE"/{proc,sys,dev,tmp,run,mnt,root,var/log}
chmod 1777 "$STAGE/tmp"
chmod 0700 "$STAGE/root"
chmod 0755 "$STAGE/etc/init.d/rcS"

# Our own PID 1. Static, because this root has no shared libc to load — and
# a dynamically linked init would die before it could say why.
cc -static -Os -Wall -Wextra -o "$STAGE/sbin/mpinit" "$SRC/src/mpinit.c"
ln -sf mpinit "$STAGE/sbin/init"
# BusyBox init stays available as a fallback, reachable with KERNEL_EXTRA=init=/bin/init.
# The symlink has to be *named* init: BusyBox picks its applet from
# basename(argv[0]), so exec'ing /bin/busybox directly just prints its help
# and exits -- which as PID 1 means an instant kernel panic.
ln -sf busybox "$STAGE/bin/init"

rm -f "$ROOTFS_IMG"
mke2fs -q -t ext4 -L masterpenguin -d "$STAGE" "$ROOTFS_IMG" "$ROOTFS_SIZE"
echo "rootfs $(du -h "$ROOTFS_IMG" | cut -f1) -> $ROOTFS_IMG"
