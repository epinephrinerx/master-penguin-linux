#!/bin/bash
# Boot the built kernel + initramfs + ext4 root under QEMU. Quit: Ctrl-A then X
#
# Extra kernel command line arguments go through KERNEL_EXTRA:
#
#     KERNEL_EXTRA=selftest ./boot.sh
#     KERNEL_EXTRA=init=/bin/init ./boot.sh      (fall back to BusyBox init)
#
# They have to be folded into the one -append QEMU honours — passing a second
# -append does not merge with the first, it is silently ignored.
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
  -append "console=ttyS0 root=$ROOT_DEV ${KERNEL_EXTRA:-}" \
  -smp "$(nproc)" -m 1G -nographic -no-reboot "$@"
