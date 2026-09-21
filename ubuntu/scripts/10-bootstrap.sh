#!/bin/bash
# Stage 1: lay down a minimal Ubuntu with debootstrap.
#
# --variant=minbase gives the smallest thing apt can work in: no recommends, no
# standard-priority packages. Everything above that is chosen explicitly in
# stage 2, which is the whole point of "Ubuntu, with the parts we do not want
# left out".
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
source ./config/build.conf

[ "$(id -u)" -eq 0 ] || { echo "needs root (chroot, mknod)" >&2; exit 1; }

mkdir -p "$MP_WORK"

if [ -d "$MP_CHROOT" ] && [ -x "$MP_CHROOT/bin/true" ]; then
    echo "==> chroot already bootstrapped at $MP_CHROOT (delete it to start over)"
    exit 0
fi

echo "==> debootstrap $MP_SUITE into $MP_CHROOT"
rm -rf "$MP_CHROOT"
mkdir -p "$MP_CHROOT"
debootstrap --arch="$MP_ARCH" --variant=minbase \
    --components=main,restricted,universe,multiverse \
    "$MP_SUITE" "$MP_CHROOT" "$MP_MIRROR"

echo "==> $(du -sh "$MP_CHROOT" | cut -f1) bootstrapped"
