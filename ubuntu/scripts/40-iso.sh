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
# grub-mkimage with the eltorito format, not grub-mkstandalone.
#
# mkstandalone packs everything into a memdisk and points prefix at it. That
# survives being written to a disk; it does not survive being wrapped as an El
# Torito boot image. GRUB comes up looking for /boot/grub/i386-pc/ls.mod on a
# device it has not identified, finds nothing, and drops to a rescue prompt —
# which looks exactly like a disc that failed to boot.
#
# The eltorito format carries its own boot sector and takes a plain prefix.
# Left as a path with no device in front of it, GRUB resolves it against
# whatever it booted from, which on a CD is the CD — no search required. This
# is how the Ubuntu discs themselves are made.
grub-mkimage \
    --format=i386-pc-eltorito \
    --output="$MP_ISODIR/boot/grub/bios.img" \
    --prefix="/boot/grub" \
    biosdisk iso9660 normal linux configfile search search_fs_file \
    echo test ls cat part_msdos part_gpt ext2 fat all_video gfxterm

# efi_uga is deliberately absent: UGA is the pre-GOP graphics protocol and
# only ever existed for 32-bit EFI, so there is no x86_64-efi module for it.
echo "==> EFI bootloader"
cat > "$MP_OUT/embed-efi.cfg" <<'EMBED'
# The EFI path finds the disc with search already, but the same explicit
# attempts cost nothing and keep the two paths reading the same way.
if [ -f (cd0)/.disk/mp-release ]; then set root=(cd0); fi
if [ ! -f ($root)/.disk/mp-release ]; then
    search --no-floppy --set=root --file /.disk/mp-release
fi
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EMBED
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$MP_ISODIR/EFI/boot/bootx64.efi" \
    --modules="linux normal iso9660 search search_fs_file part_gpt part_msdos fat ext2 all_video efi_gop configfile echo test" \
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
