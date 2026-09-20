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

# busybox is the init too; /sbin/init is what switch_root execs.
ln -sf ../bin/busybox "$STAGE/sbin/init"

rm -f "$ROOTFS_IMG"
mke2fs -q -t ext4 -L masterpenguin -d "$STAGE" "$ROOTFS_IMG" "$ROOTFS_SIZE"
echo "rootfs $(du -h "$ROOTFS_IMG" | cut -f1) -> $ROOTFS_IMG"
