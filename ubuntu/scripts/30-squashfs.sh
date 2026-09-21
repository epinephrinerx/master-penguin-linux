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
mksquashfs "$MP_CHROOT" "$CASPER/filesystem.squashfs" \
    -comp "$MP_COMP" -Xcompression-level "$MP_COMP_LEVEL" \
    -noappend -no-progress \
    -e boot/vmlinuz-* boot/initrd.img-* \
       proc sys dev/pts run tmp/* var/tmp/* \
       var/cache/apt/archives/*.deb var/lib/apt/lists/* \
    | tail -5

# casper reads this to size the progress bar and to check there is room.
printf '%s' "$(du -sx --block-size=1 "$MP_CHROOT" | cut -f1)" > "$CASPER/filesystem.size"

cat > "$MP_ISODIR/.disk/info" <<INFO
$MP_NAME $MP_VERSION - release amd64
INFO
echo "$MP_ID" > "$MP_ISODIR/.disk/mp-release"

echo "==> squashfs $(du -h "$CASPER/filesystem.squashfs" | cut -f1), chroot was $(du -sh "$MP_CHROOT" | cut -f1)"
