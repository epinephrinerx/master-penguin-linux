#!/bin/bash
# Stage 4: wrap the live tree into an ISO that boots on both EFI and BIOS.
#
# Both boot paths are deliberate. EFI is what every hypervisor now defaults to,
# and BIOS is what older machines and some VM templates still use. An ISO with
# only one of them looks blank on the other.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
HERE="$PWD"
source ./config/build.conf

[ -f "$MP_ISODIR/casper/filesystem.squashfs" ] || {
    echo "no squashfs — run 30-squashfs.sh first" >&2; exit 1; }

mkdir -p "$MP_OUT" "$MP_ISODIR/boot/grub" "$MP_ISODIR/EFI/boot"
VOLID="MP_LINUX"

echo "==> grub.cfg"
sed -e "s|@NAME@|$MP_NAME|g" -e "s|@VERSION@|$MP_VERSION|g" \
    "$HERE/grub/grub.cfg" > "$MP_ISODIR/boot/grub/grub.cfg"

echo "==> BIOS core image"
# The embedded config is what GRUB runs before it has a prefix it can trust:
# find the disc by a file only this disc has, then read the real menu from it.
cat > "$MP_OUT/embed-bios.cfg" <<'EMBED'
search --no-floppy --set=root --file /.disk/mp-release
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EMBED
grub-mkstandalone \
    --format=i386-pc \
    --output="$MP_OUT/core.img" \
    --install-modules="linux normal iso9660 biosdisk search search_fs_file memdisk tar ls echo configfile part_msdos part_gpt ext2 fat" \
    --modules="linux normal iso9660 biosdisk search search_fs_file" \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=$MP_OUT/embed-bios.cfg"
cat /usr/lib/grub/i386-pc/cdboot.img "$MP_OUT/core.img" > "$MP_ISODIR/boot/grub/bios.img"

echo "==> EFI bootloader"
cat > "$MP_OUT/embed-efi.cfg" <<'EMBED'
search --no-floppy --set=root --file /.disk/mp-release
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EMBED
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$MP_ISODIR/EFI/boot/bootx64.efi" \
    --modules="linux normal iso9660 search search_fs_file part_gpt part_msdos fat ext2 all_video efi_gop efi_uga configfile echo" \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=$MP_OUT/embed-efi.cfg"

# A FAT image holding that .efi, which the firmware boots via El Torito and
# which is also exposed as a real EFI system partition by -append_partition.
echo "==> efiboot.img"
rm -f "$MP_ISODIR/boot/grub/efiboot.img"
EFI_KB=$(( ( $(stat -c%s "$MP_ISODIR/EFI/boot/bootx64.efi") / 1024 ) + 256 ))
mkfs.vfat -C -n MPEFI "$MP_ISODIR/boot/grub/efiboot.img" "$EFI_KB" >/dev/null
mmd   -i "$MP_ISODIR/boot/grub/efiboot.img" ::/EFI ::/EFI/BOOT
mcopy -i "$MP_ISODIR/boot/grub/efiboot.img" \
      "$MP_ISODIR/EFI/boot/bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI

echo "==> md5sums"
( cd "$MP_ISODIR" && find . -type f -not -path './md5sum.txt' -print0 \
    | xargs -0 md5sum > md5sum.txt )

ISO="$MP_OUT/${MP_ID}-${MP_VERSION}-amd64.iso"
echo "==> xorriso"
rm -f "$ISO"
xorriso -as mkisofs \
    -iso-level 3 -full-iso9660-filenames -rational-rock \
    -volid "$VOLID" \
    -eltorito-boot boot/grub/bios.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
        --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
        -e boot/grub/efiboot.img -no-emul-boot \
        -append_partition 2 0xef "$MP_ISODIR/boot/grub/efiboot.img" \
    -output "$ISO" \
    "$MP_ISODIR"

echo
echo "==> $(du -h "$ISO" | cut -f1)  $ISO"
