#!/bin/bash
# Boot the Buildroot-built desktop target under QEMU.
#
#   ./boot-desktop.sh                 open a window (needs WSLg or a real X/Wayland display)
#   ./boot-desktop.sh --headless      no window; take screenshots over the QEMU monitor
#
# Quit: close the window, or Ctrl-A then X on the serial console.
#
# Unlike the hand-built track there is no initramfs here — QEMU hands the kernel
# straight to the ext4 image as root=/dev/vda. The stages 1-3 boot chain is still
# the one exercised by ./boot.sh.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

IMAGES="${BR_OUTPUT:-$HOME/work/br-desktop}/images"
KERNEL="$IMAGES/bzImage"
ROOTFS="$IMAGES/rootfs.ext2"

[ -f "$KERNEL" ] || { echo "no kernel — run ./build-desktop.sh first" >&2; exit 1; }
[ -f "$ROOTFS" ] || { echo "no rootfs — run ./build-desktop.sh first" >&2; exit 1; }

HEADLESS=0
MONITOR=""
if [ "${1:-}" = "--headless" ]; then
    HEADLESS=1
    MONITOR="${MP_MONITOR:-/tmp/mp-monitor.sock}"
    shift
fi

ACCEL=()
[ -w /dev/kvm ] && ACCEL=(-enable-kvm -cpu host)

DISPLAY_ARGS=(-display gtk,show-cursor=on)
if [ "$HEADLESS" = "1" ]; then
    rm -f "$MONITOR"
    DISPLAY_ARGS=(-display none -monitor "unix:$MONITOR,server,nowait")
fi

# virtio-gpu is what the kernel's DRM driver binds to; virtio-keyboard/tablet
# give libinput something to enumerate. The serial console stays on stdio so the
# boot log and the mpinit shell are still reachable next to the graphical screen.
exec qemu-system-x86_64 "${ACCEL[@]}" \
  -kernel "$KERNEL" \
  -drive "file=$ROOTFS,format=raw,if=virtio" \
  -append "console=ttyS0 root=/dev/vda rw ${KERNEL_EXTRA:-}" \
  -device virtio-gpu-pci,xres=1280,yres=800 \
  -device virtio-keyboard-pci \
  -device virtio-tablet-pci \
  "${DISPLAY_ARGS[@]}" \
  -serial mon:stdio \
  -smp "$(nproc)" -m 2G -no-reboot "$@"
