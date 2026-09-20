#!/bin/bash
# Fetch and build the kernel + BusyBox. Safe to re-run: skips what already exists.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

mkdir -p "$WORKDIR"

echo "==> [1/3] fetching sources into $WORKDIR"
cd "$WORKDIR"
[ -f "linux-$KERNEL_VERSION.tar.xz" ] ||
  wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz"
[ -f "busybox-$BUSYBOX_VERSION.tar.bz2" ] ||
  wget -q --show-progress "https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2"
[ -d "$KERNEL_DIR" ]  || tar xf "linux-$KERNEL_VERSION.tar.xz"
[ -d "$BUSYBOX_DIR" ] || tar xf "busybox-$BUSYBOX_VERSION.tar.bz2"

echo "==> [2/3] building kernel $KERNEL_VERSION"
cd "$KERNEL_DIR"
[ -f .config ] || make defconfig
# bzImage only — defconfig marks a lot of drivers as =m and we need none of them.
make -j"$(nproc)" bzImage
echo "    bzImage $(du -h "$BZIMAGE" | cut -f1)"

echo "==> [3/3] building busybox $BUSYBOX_VERSION (static)"
cd "$BUSYBOX_DIR"
if [ ! -f .config ]; then
  make defconfig
  # Static: the initramfs has no libc, so every binary must carry its own.
  sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' .config
  sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' .config
  # `yes` takes SIGPIPE the moment oldconfig stops reading. Under `set -o pipefail`
  # that failure propagates and `set -e` kills the script, so relax it just here.
  set +o pipefail
  yes "" | make oldconfig > "$WORKDIR/busybox-oldconfig.log" 2>&1
  set -o pipefail
fi
make -j"$(nproc)"
make install
file busybox | cut -d, -f1-3

echo "==> done. next: ./mkinitramfs.sh && ./boot.sh"
