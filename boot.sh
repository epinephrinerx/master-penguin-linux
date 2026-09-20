#!/bin/bash
# Boot the built kernel + initramfs under QEMU. Quit with: Ctrl-A then X
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

[ -f "$BZIMAGE" ]   || { echo "no kernel — run ./build.sh first" >&2; exit 1; }
[ -f "$INITRAMFS" ] || { echo "no initramfs — run ./mkinitramfs.sh first" >&2; exit 1; }

# KVM needs the user in the `kvm` group; falls back to software emulation (TCG).
ACCEL=()
[ -w /dev/kvm ] && ACCEL=(-enable-kvm -cpu host)

exec qemu-system-x86_64 "${ACCEL[@]}" \
  -kernel "$BZIMAGE" \
  -initrd "$INITRAMFS" \
  -append "console=ttyS0" \
  -smp "$(nproc)" -m 1G -nographic -no-reboot "$@"
