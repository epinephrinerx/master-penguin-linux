#!/bin/bash
# Stage 3: compress the chroot into the squashfs the live system runs from,
# and lift the kernel and initrd out of it.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
source ./config/build.conf

[ "$(id -u)" -eq 0 ] || { echo "needs root (the squashfs has to keep ownership)" >&2; exit 1; }
[ -x "$MP_CHROOT/bin/true" ] || { echo "no chroot at $MP_CHROOT" >&2; exit 1; }

CASPER="$MP_ISODIR/casper"
mkdir -p "$CASPER" "$MP_ISODIR/.disk" "$MP_ISODIR/boot/grub"

echo "==> kernel and initrd"
# The chroot may hold several kernels after an upgrade; take the newest.
KVER=$(ls -1 "$MP_CHROOT/boot"/vmlinuz-* | sed 's|.*/vmlinuz-||' | sort -V | tail -1)
[ -n "$KVER" ] || { echo "no kernel in the chroot" >&2; exit 1; }
cp -f "$MP_CHROOT/boot/vmlinuz-$KVER" "$CASPER/vmlinuz"
cp -f "$MP_CHROOT/boot/initrd.img-$KVER" "$CASPER/initrd"
echo "    $KVER"

echo "==> manifest"
chroot "$MP_CHROOT" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "$CASPER/filesystem.manifest"
cp -f "$CASPER/filesystem.manifest" "$CASPER/filesystem.manifest-desktop"
# Packages listed here are removed by the installer after copying the system
# across, because they only make sense on the live disc.
for p in casper calamares calamares-settings-ubuntu-common; do
    sed -i "/^$p /d" "$CASPER/filesystem.manifest-desktop"
done

echo "==> squashfs (this is the slow part)"
rm -f "$CASPER/filesystem.squashfs"
# Almost nothing is excluded, and the two things that were are the reason this
# needed fixing:
#
#   proc, sys, run, tmp — mksquashfs -e on a directory drops the directory, not
#   just what is inside it. These are empty in a chroot anyway, and casper
#   mounts over them at boot. Without them, "mount /run" fails, adduser cannot
#   take its lock, the live user is never created, and the disc stops at a
#   login prompt for an account that does not exist.
#
#   boot/vmlinuz-* and boot/initrd.img-* — the copies in /casper are for
#   booting the disc. The installed system needs its own in /boot, and leaving
#   them out produces an install that completes and then has no kernel to boot.
#
# What is left is genuinely disposable: apt's package cache and its lists,
# already emptied by the chroot cleanup, excluded here as well so a partial
# build cannot smuggle several hundred megabytes into the image.
mksquashfs "$MP_CHROOT" "$CASPER/filesystem.squashfs" \
    -comp "$MP_COMP" -Xcompression-level "$MP_COMP_LEVEL" \
    -mem "$MP_SQUASH_MEM" -processors "$MP_SQUASH_PROCS" \
    -noappend -no-progress \
    -e var/cache/apt/archives var/lib/apt/lists \
    | tail -5

# casper reads this to size the progress bar and to check there is room.
printf '%s' "$(du -sx --block-size=1 "$MP_CHROOT" | cut -f1)" > "$CASPER/filesystem.size"

cat > "$MP_ISODIR/.disk/info" <<INFO
$MP_NAME $MP_VERSION - release amd64
INFO
echo "$MP_ID" > "$MP_ISODIR/.disk/mp-release"

echo "==> squashfs $(du -h "$CASPER/filesystem.squashfs" | cut -f1), chroot was $(du -sh "$MP_CHROOT" | cut -f1)"
