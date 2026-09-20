# master penguin linux

A Linux system built from source, one layer at a time — kernel, userland, init,
and eventually a bootable image. Not a fork of anything: the kernel and BusyBox
come straight from upstream, everything around them is written here.

**Status:** stage 1 — boots to a BusyBox shell in QEMU in about 1.5 seconds.

```
===========================================
        master penguin linux
===========================================
Linux (none) 6.18.52 #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux
cpus : 16
mem  : 966 MB
init : 1 (/init)
===========================================
~ #
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
./mkinitramfs.sh    # pack initramfs/init + busybox into a cpio archive
./boot.sh           # boot it under QEMU     (quit: Ctrl-A then X)
```

Re-running `build.sh` is cheap — it skips anything already downloaded or configured.
The edit loop for userland work is just the last two:

```sh
vim initramfs/init && ./mkinitramfs.sh && ./boot.sh
```

Builds land in `$WORKDIR` (default `~/work`), never inside the repo. On WSL, keep
that on the distro's own ext4 — building under `/mnt/c` or `/mnt/d` goes through
the 9p filesystem and turns a 10-minute kernel build into an hour.

## Layout

| path | what it is |
|---|---|
| `config.sh` | versions and paths — the only place to bump the kernel |
| `build.sh` | downloads and compiles kernel + BusyBox |
| `mkinitramfs.sh` | assembles the root filesystem into `initramfs.cpio.gz` |
| `boot.sh` | runs QEMU, with KVM when available |
| `initramfs/init` | **PID 1** — the actual source code of this system |

## How the boot works

```
QEMU/SeaBIOS  ->  bzImage  ->  unpack initramfs into rootfs  ->  exec /init  ->  sh
```

There is no bootloader and no disk yet. The kernel is handed to QEMU directly with
`-kernel`, and the entire userland is a 1.3 MB gzipped cpio archive the kernel
unpacks into RAM before running `/init`.

`/init` is PID 1, and PID 1 may never exit — if it does, the kernel panics
immediately. Replacing the last line of `initramfs/init` with `exec /bin/echo hi`
is the fastest way to see that for yourself, and it is the entire reason real init
systems are infinite loops.

## Roadmap

- [x] **1** — kernel + BusyBox initramfs, boots to a shell
- [ ] **2** — real root filesystem on a disk image, `switch_root` out of initramfs
- [ ] **3** — hand-written init (PID 1 in C): reap orphans, supervise services
- [ ] **4** — two-pass cross toolchain, so the system can rebuild itself
- [ ] **5** — package manager and build recipes
- [ ] **6** — bootloader + bootable ISO

## Notes

Things that cost time, written down so they only cost it once:

- **BusyBox `oldconfig` kills the build.** `yes "" | make oldconfig` — `yes` takes
  SIGPIPE when `oldconfig` stops reading, `set -o pipefail` turns that into a
  pipeline failure, and `set -e` aborts. Relax `pipefail` around that one line.
- **`cttyhack` breaks piped input.** It gives the shell a controlling terminal so
  Ctrl-C works, but the shell then reads `/dev/console` instead of QEMU's stdin.
  For scripted runs, boot with `-append "console=ttyS0 init=/bin/sh"`.
- **Kernel `make bzImage`, not `make`.** `defconfig` marks hundreds of drivers `=m`
  and none of them are needed for this.
