#!/bin/sh
# Runs after the filesystem images are built, before genimage assembles the disk.
set -e

# The ISO and the hard disk need different GRUB core images, because the prefix
# baked into one has to name the device it will be read from: (cd) for the ISO,
# (hd0,msdos1) for the disk. Buildroot builds exactly one, using
# BR2_TARGET_GRUB2_BOOT_PARTITION -- which is set to "cd" so that its iso9660
# support works the way upstream intends.
#
# So build the disk's core image here, from the same modules grub2 installed
# into the target. Trying to make a single image serve both, by embedding a
# config that searches for its own grub.cfg, does not work: on the ISO, GRUB
# ends up with $root still pointing at hd0 and fails to load the kernel with
# "cannot get C/H/S values".
"$HOST_DIR/bin/grub-mkimage" \
	-d "$TARGET_DIR/lib/grub/i386-pc" \
	-O i386-pc \
	-o "$BINARIES_DIR/grub-disk.img" \
	-p "(hd0,msdos1)/boot/grub" \
	boot linux ext2 fat part_msdos part_gpt normal biosdisk \
	search search_fs_file configfile echo cat test

echo "post-image: built grub-disk.img ($(stat -c%s "$BINARIES_DIR/grub-disk.img") bytes)"
