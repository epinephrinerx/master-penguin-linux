#!/bin/bash
# Boot the built kernel + initramfs + ext4 root under QEMU. Quit: Ctrl-A then X
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

[ -f "$BZIMAGE" ]    || { echo "no kernel — run ./build.sh first" >&2; exit 1; }
[ -f "$INITRAMFS" ]  || { echo "no initramfs — run ./mkinitramfs.sh first" >&2; exit 1; }
[ -f "$ROOTFS_IMG" ] || { echo "no root image — run ./mkrootfs.sh first" >&2; exit 1; }

# KVM needs the user in the `kvm` group; falls back to software emulation (TCG).
ACCEL=()
[ -w /dev/kvm ] && ACCEL=(-enable-kvm -cpu host)

exec qemu-system-x86_64 "${ACCEL[@]}" \
  -kernel "$BZIMAGE" \
  -initrd "$INITRAMFS" \
  -drive "file=$ROOTFS_IMG,format=raw,if=virtio" \
  -append "console=ttyS0 root=$ROOT_DEV" \
  -smp "$(nproc)" -m 1G -nographic -no-reboot "$@"
