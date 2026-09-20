#!/bin/sh
# Runs after the target directory is assembled, before the images are made.
set -e
BOARD_DIR=$(dirname "$0")

install -D -m 0644 "$BOARD_DIR/grub.cfg" "$TARGET_DIR/boot/grub/grub.cfg"

# genimage needs GRUB's first stage next to the other images, and grub2 only
# puts it in the target — and only when BR2_TARGET_GRUB2_INSTALL_TOOLS is set.
STAGE1="$TARGET_DIR/lib/grub/i386-pc/boot.img"
if [ ! -f "$STAGE1" ]; then
    echo "post-build: $STAGE1 missing." >&2
    echo "post-build: set BR2_TARGET_GRUB2_INSTALL_TOOLS=y in the defconfig." >&2
    exit 1
fi
cp -f "$STAGE1" "$BINARIES_DIR/"
