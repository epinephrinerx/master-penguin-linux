#!/bin/bash
# Single source of truth for versions and paths. Sourced by every script here.

KERNEL_VERSION=6.18.52      # longterm; see https://www.kernel.org/releases.json
BUSYBOX_VERSION=1.38.0

# Where sources are unpacked and built. Must live on a native Linux filesystem —
# building under /mnt/c or /mnt/d on WSL goes through 9p and is brutally slow.
WORKDIR="${WORKDIR:-$HOME/work}"

KERNEL_DIR="$WORKDIR/linux-$KERNEL_VERSION"
BUSYBOX_DIR="$WORKDIR/busybox-$BUSYBOX_VERSION"
BZIMAGE="$KERNEL_DIR/arch/x86/boot/bzImage"
INITRAMFS="$WORKDIR/initramfs.cpio.gz"

# The real root filesystem: an ext4 image QEMU attaches as a virtio disk.
ROOTFS_IMG="$WORKDIR/rootfs.ext4"
ROOTFS_SIZE=256M
ROOT_DEV=/dev/vda
