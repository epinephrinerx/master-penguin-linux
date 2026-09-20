# master penguin linux

A Linux system built from source, one layer at a time — kernel, userland, init,
and eventually a bootable image. Not a fork of anything: the kernel and BusyBox
come straight from upstream, everything around them is written here.

**Status:** stage 2 — an initramfs hands over to a real ext4 root with `switch_root`,
and BusyBox init takes over from there. Cold boot to prompt is about 1.5 seconds.

```
[initramfs] root device: /dev/vda
[initramfs] handing over to /sbin/init

===========================================
        master penguin linux
===========================================
Linux 6.18.52
root : /dev/vda (rw,relatime)
init : /bin/busybox (pid 1)
boots: 3 (persisted on disk)
===========================================
root@master-penguin:~#
```

## Requirements

A Linux host (WSL2 is fine) with:

```sh
sudo apt install build-essential flex bison bc libssl-dev libelf-dev \
                 libncurses-dev cpio wget xz-utils file qemu-system-x86
```

For hardware acceleration, add yourself to the `kvm` group — `sudo usermod -aG kvm $USER`,
then start a new session. Without it QEMU falls back to software emulation, which
still works, just slower.

## Quick start

```sh
./build.sh          # fetch + compile kernel and busybox  (~10 min, ~2.8 GB)
./mkrootfs.sh       # build the ext4 root image from rootfs/ + busybox
./mkinitramfs.sh    # pack the bootstrap initramfs
./boot.sh           # boot it under QEMU     (quit: Ctrl-A then X)
```

Re-running `build.sh` is cheap — it skips anything already downloaded or configured.
Day to day only the last three matter, and each takes about a second:

```sh
vi rootfs/etc/init.d/rcS && ./mkrootfs.sh && ./boot.sh
```

Builds land in `$WORKDIR` (default `~/work`), never inside the repo. On WSL, keep
that on the distro's own ext4 — building under `/mnt/c` or `/mnt/d` goes through
the 9p filesystem and turns a 10-minute kernel build into an hour.

## Layout

| path | what it is |
|---|---|
| `config.sh` | versions and paths — the only place to bump the kernel |
| `build.sh` | downloads and compiles kernel + BusyBox |
| `mkrootfs.sh` | builds `rootfs.ext4` from `rootfs/` + BusyBox |
| `mkinitramfs.sh` | packs `initramfs/init` + BusyBox into a cpio archive |
| `boot.sh` | runs QEMU, with KVM when available |
| `initramfs/init` | PID 1 **in the initramfs** — finds the root disk, then `switch_root` |
| `rootfs/` | the real root filesystem skeleton: inittab, fstab, rcS, os-release |

## How the boot works

```
QEMU/SeaBIOS
  -> bzImage
     -> unpack initramfs into RAM
        -> exec /init                     (initramfs/init)
           -> mount /dev/vda ro
           -> mount --move /dev
           -> switch_root                 (initramfs is deleted here)
              -> /sbin/init               (busybox)
                 -> /etc/inittab
                    -> sysinit: /etc/init.d/rcS
                    -> respawn: -/bin/sh
```

The initramfs is now a bootstrap and nothing else. It exists because at the moment
the kernel finishes booting, nothing knows how to reach the root filesystem yet —
on a real machine that means loading disk and RAID drivers, decrypting LUKS, or
finding an LVM volume. Here it only has to mount `/dev/vda`, but the shape is the same.

`switch_root` then *deletes* the initramfs to reclaim the RAM and execs the real
`/sbin/init` as PID 1. That is why `/dev` has to be moved across first: the new root
has an empty `/dev`, and init cannot even open `/dev/console` to report a failure.

Unlike stage 1, this root survives reboots — `boots:` in the banner counts them,
and the record is in `/var/log/boot.log` on the disk image.

## Roadmap

- [x] **1** — kernel + BusyBox initramfs, boots to a shell
- [x] **2** — real ext4 root on a disk image, `switch_root` out of the initramfs
- [ ] **3** — hand-written init (PID 1 in C): reap orphans, supervise services
- [ ] **4** — two-pass cross toolchain, so the system can rebuild itself
- [ ] **5** — package manager and build recipes
- [ ] **6** — bootloader + bootable ISO

## Notes

Things that cost time, written down so they only cost it once:

- **`mount -o remount,rw /` needs `/proc` already mounted.** BusyBox `mount` reads
  `/proc/mounts` to work out what it is remounting. Put `mount -t proc proc /proc`
  first in `rcS`, or the root silently stays read-only.
- **Killing QEMU is a power cut.** Writes sit in the guest page cache and vanish;
  `poweroff` inside the guest runs the `::shutdown` line in `inittab` and unmounts
  cleanly. Anything that must survive a hard kill needs an explicit `sync`.
- **`mke2fs -d` builds the image from a directory** — no loop mount, no root. It
  cannot create device nodes, which is fine here because `/dev` is moved in from
  the initramfs.
- **BusyBox `oldconfig` kills the build.** `yes "" | make oldconfig` — `yes` takes
  SIGPIPE when `oldconfig` stops reading, `set -o pipefail` turns that into a
  pipeline failure, and `set -e` aborts. Relax `pipefail` around that one line.
- **Kernel `make bzImage`, not `make`.** `defconfig` marks hundreds of drivers `=m`
  and none of them are needed for this. `VIRTIO_BLK` and `EXT4_FS` are already
  built in, so no custom config is needed yet.
- **`cttyhack` breaks piped input.** Only the initramfs rescue shell uses it now;
  under BusyBox init, `-/bin/sh` in `inittab` gets a proper controlling terminal.
