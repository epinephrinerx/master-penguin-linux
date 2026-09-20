# master penguin linux

A Linux system built from source, one layer at a time — kernel, userland, init,
and eventually a bootable image. Not a fork of anything: the kernel and BusyBox
come straight from upstream, everything around them is written here.

**Status:** stage 3 — PID 1 is now `mpinit`, written for this system in about 300
lines of C. It reaps orphans, supervises services and shuts the machine down
cleanly. Cold boot to prompt is about 1.5 seconds.

```
[initramfs] root device: /dev/vda
[initramfs] handing over to /sbin/init

===========================================
        master penguin linux
===========================================
Linux 6.18.52
root : /dev/vda (rw,relatime)
init : /sbin/mpinit (pid 1)
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
./mkrootfs.sh       # compile mpinit, build the ext4 root image
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
| `src/mpinit.c` | **PID 1** — the init this system actually runs |
| `initramfs/init` | PID 1 *in the initramfs* — finds the root disk, then `switch_root` |
| `rootfs/` | the real root filesystem skeleton: mpinit.conf, fstab, rcS, os-release |

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

## init

`src/mpinit.c` replaces BusyBox init. It is deliberately small, and it exists to
make the three obligations of PID 1 concrete:

**It may never exit.** If PID 1 returns, the kernel panics immediately. Every
path through the file either loops or calls `reboot()`.

**It reaps whatever it is given.** When a process dies its children are
reparented to PID 1. A single blocking `waitpid(-1, ...)` collects them all —
services it started, and orphans it has never heard of. Skip that and zombies
accumulate until nothing can fork.

**It supervises.** Services come from `/etc/mpinit.conf`:

```
sysinit /etc/init.d/rcS     run once, to completion, before anything else
respawn /bin/sh             keep running; restart whenever it exits
```

Respawns are throttled — more than five restarts in ten seconds and it backs
off, so a service that dies on startup cannot spin the CPU forever.

Shutdown follows the BusyBox signal convention, so `poweroff`, `halt` and
`reboot` keep working: SIGUSR1 halts, SIGUSR2 powers off, SIGTERM reboots, and
Ctrl-Alt-Del arrives as SIGINT because init asks for it with `RB_DISABLE_CAD`.
Each one stops every process, syncs, remounts `/` read-only and calls `reboot()`.

There is a self-test for all of this. Boot with `KERNEL_EXTRA=selftest ./boot.sh`
and `/root/selftest.sh` checks that PID 1 is mpinit, that an orphan is reparented
to it, that no zombies survive, and that killing the supervised shell brings a new
one back — then powers off, which exercises the shutdown path too.

BusyBox init is still in the image as a fallback: `KERNEL_EXTRA=init=/bin/init ./boot.sh`
boots it from `/etc/inittab` instead.

## Roadmap

- [x] **1** — kernel + BusyBox initramfs, boots to a shell
- [x] **2** — real ext4 root on a disk image, `switch_root` out of the initramfs
- [x] **3** — hand-written init (PID 1 in C): reap orphans, supervise services
- [ ] **4** — two-pass cross toolchain, so the system can rebuild itself
- [ ] **5** — package manager and build recipes
- [ ] **6** — bootloader + bootable ISO

## Notes

Things that cost time, written down so they only cost it once:

- **`mount -o remount,rw /` needs `/proc` already mounted.** BusyBox `mount` reads
  `/proc/mounts` to work out what it is remounting. Put `mount -t proc proc /proc`
  first in `rcS`, or the root silently stays read-only.
- **Do not give a sysinit script a controlling terminal.** When a session leader
  that owns one exits, the kernel runs `disassociate_ctty()`, and on the console
  that vhangup throws away output still queued. A boot script losing its last
  few printed lines is a miserable thing to debug. `mpinit` hands a ctty to
  respawn services only.
- **A backgrounded job in a script dies with the script.** No job control means
  `cmd &` stays in the same process group, which gets SIGHUP when the session
  leader exits. `setsid cmd &` escapes it.
- **`/proc/self` is whoever does the reading.** `$(cat /proc/self/stat)` reports
  `cat`, not the shell that called it. To check who adopted an orphan, record its
  pid and read `/proc/<pid>/stat` from outside.
- **BusyBox picks its applet from `basename(argv[0])`.** Exec'ing `/bin/busybox`
  as init just prints its help and exits — instant panic. The fallback symlink
  has to be named `init`.
- **`mkrootfs.sh` destroys the disk.** It rebuilds `rootfs.ext4` from scratch every
  run, so anything written inside the guest is gone. `rootfs/` in git is the source
  of truth; the image is a build artifact. Skip `mkrootfs.sh` and just `./boot.sh`
  when you want to keep what is in there.
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
