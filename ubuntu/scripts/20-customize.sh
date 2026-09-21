#!/bin/bash
# Stage 2: turn the bootstrapped minbase into the actual system.
#
# The work happens in inside-chroot.sh; this script's job is to give that a
# chroot it can run apt in, and to take the mounts back down afterwards no
# matter how it exits. A bind mount left behind in /proc or /dev is how a build
# script ends up deleting parts of the host.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
HERE="$PWD"
source ./config/build.conf

[ "$(id -u)" -eq 0 ] || { echo "needs root" >&2; exit 1; }
[ -x "$MP_CHROOT/bin/true" ] || { echo "no chroot at $MP_CHROOT — run 10-bootstrap.sh first" >&2; exit 1; }

MOUNTED=""
cleanup() {
    local d
    # Unmount in reverse order, and keep going if one is already gone.
    for d in $(printf '%s\n' $MOUNTED | tac); do
        umount -l "$d" 2>/dev/null || true
    done
}
trap cleanup EXIT

bind() {
    local src="$1" dst="$MP_CHROOT$2"
    mkdir -p "$dst"
    mount --bind "$src" "$dst"
    MOUNTED="$MOUNTED $dst"
}

echo "==> mounting"
bind /dev     /dev
bind /dev/pts /dev/pts
mount -t proc  none "$MP_CHROOT/proc";  MOUNTED="$MOUNTED $MP_CHROOT/proc"
mount -t sysfs none "$MP_CHROOT/sys";   MOUNTED="$MOUNTED $MP_CHROOT/sys"
mount -t tmpfs none "$MP_CHROOT/run";   MOUNTED="$MOUNTED $MP_CHROOT/run"

# DNS for apt. The chroot has no resolv.conf of its own yet.
cp -f /etc/resolv.conf "$MP_CHROOT/etc/resolv.conf"

echo "==> staging scripts and lists"
install -m 0755 "$HERE/scripts/inside-chroot.sh" "$MP_CHROOT/tmp/inside-chroot.sh"
install -m 0644 "$HERE"/config/packages-*.list  "$MP_CHROOT/tmp/"
# Pass the build settings in as plain values; the chroot cannot read our config.
{
    echo "MP_SUITE='$MP_SUITE'"
    echo "MP_MIRROR='$MP_MIRROR'"
    echo "MP_NAME='$MP_NAME'"
    echo "MP_ID='$MP_ID'"
    echo "MP_VERSION='$MP_VERSION'"
    echo "MP_FIRMWARE='$MP_FIRMWARE'"
} > "$MP_CHROOT/tmp/mp-build.conf"

echo "==> staging calamares"
rm -rf "$MP_CHROOT/tmp/calamares"
cp -a "$HERE/calamares" "$MP_CHROOT/tmp/calamares"

echo "==> entering chroot"
chroot "$MP_CHROOT" /tmp/inside-chroot.sh

echo "==> done"
