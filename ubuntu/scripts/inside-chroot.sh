#!/bin/bash
# Runs INSIDE the chroot. Everything that makes a debootstrapped minbase into
# Master Penguin Linux happens here.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

. /tmp/mp-build.conf

say() { printf '\n==> %s\n' "$*"; }

# --------------------------------------------------------------- apt sources
say "apt sources"
cat > /etc/apt/sources.list.d/ubuntu.sources <<SOURCES
Types: deb
URIs: ${MP_MIRROR}
Suites: ${MP_SUITE} ${MP_SUITE}-updates ${MP_SUITE}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: ${MP_SUITE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES
rm -f /etc/apt/sources.list

# Nothing in a chroot should be starting daemons.
cat > /usr/sbin/policy-rc.d <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# Documentation is a third of the installed size of a Debian system and none of
# it is reachable from a live desktop anyway.
cat > /etc/dpkg/dpkg.cfg.d/mp-trim <<'TRIM'
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
TRIM

# A previous run may have been interrupted part-way through unpacking -- the
# build machine runs out of memory, the terminal goes away, whatever. dpkg
# then refuses to do anything until told to finish what it started. Doing
# this unconditionally is what makes this stage safe to just run again.
dpkg --configure -a || true
apt-get -f install -y -qq || true

apt-get update -qq

# ------------------------------------------------------------------- locale
say "locale and timezone"
apt-get install -y -qq locales tzdata
sed -i 's/^# *\(en_US.UTF-8\)/\1/; s/^# *\(th_TH.UTF-8\)/\1/' /etc/locale.gen
locale-gen >/dev/null
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime
echo "Asia/Bangkok" > /etc/timezone

# -------------------------------------------------------------- package sets
install_list() {
    local f="$1"
    local pkgs
    pkgs=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$f" | tr '\n' ' ')
    say "installing from $(basename "$f")"
    # shellcheck disable=SC2086
    apt-get install -y -qq $pkgs
}

install_list /tmp/packages-base.list
install_list /tmp/packages-xfce.list
install_list /tmp/packages-apps.list

if [ "${MP_FIRMWARE}" = "1" ]; then
    say "linux-firmware (large, but wifi and GPUs need it on real hardware)"
    apt-get install -y -qq linux-firmware
fi

# ------------------------------------------------- Firefox and Thunderbird
say "Firefox and Thunderbird from the Mozilla apt repository"
# Ubuntu's own firefox/thunderbird debs are transitional packages that install
# snaps. Those take several seconds to first launch and add hundreds of
# megabytes of loopback-mounted squashfs. Mozilla publish real debs; use those
# and pin them above the archive so an upgrade cannot pull the snap back in.
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -o /etc/apt/keyrings/packages.mozilla.org.asc
cat > /etc/apt/sources.list.d/mozilla.list <<'MOZ'
deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
MOZ
cat > /etc/apt/preferences.d/mozilla <<'PIN'
Package: firefox* thunderbird*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
PIN
apt-get update -qq
apt-get install -y -qq firefox thunderbird

# Language packs are best-effort. Mozilla ship a Thai Firefox but not a Thai
# Thunderbird, and which locales exist changes between releases -- a missing
# one is a small loss, not a reason to fail a half-hour build.
for l10n in firefox-l10n-th thunderbird-l10n-th; do
    apt-get install -y -qq "$l10n" 2>/dev/null || echo "    no $l10n available, skipping"
done

# ------------------------------------------------------------------ branding
say "branding"
# /etc/os-release is already a symlink to /usr/lib/os-release on Ubuntu, so
# write the real file and point the symlink at it rather than copying one
# onto the other.
cat > /usr/lib/os-release <<RELEASE
NAME="${MP_NAME}"
PRETTY_NAME="${MP_NAME} ${MP_VERSION}"
ID=${MP_ID}
ID_LIKE=ubuntu
VERSION="${MP_VERSION}"
VERSION_ID="${MP_VERSION}"
HOME_URL="https://github.com/epinephrinerx/master-penguin-linux"
SUPPORT_URL="https://github.com/epinephrinerx/master-penguin-linux/issues"
UBUNTU_CODENAME=${MP_SUITE}
RELEASE
ln -sf ../usr/lib/os-release /etc/os-release
echo "${MP_ID}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1	localhost
127.0.1.1	${MP_ID}
::1		localhost ip6-localhost ip6-loopback
HOSTS

# -------------------------------------------------------------- Thai fonts
# R-05: the SIPA national font set -- all thirteen families, including
# TH Sarabun New and TH SarabunPSK, the typefaces Thai official documents are
# written in. None of them are in the Ubuntu archive; fonts-tlwg is a
# different family altogether.
#
# Licence: the SIPA / Department of Intellectual Property font licence, which
# ships with the files and is installed beside them. Its first clause permits
# use, copying, study, modification and distribution, and forbids selling the
# font by itself "except when sold bundled with other software" -- which is
# what an ISO is. We do not modify the fonts, so the clauses about renaming
# and notifying the copyright holder do not apply.
#
# Pinned to a commit, not a branch. A font that changes underneath the build
# changes document metrics, and that is not a thing to find out from a
# complaint that a form now runs onto a second page.
say "Thai document fonts (SIPA national set)"
FONT_REPO="${MP_TH_SARABUN_REPO:-epsilonxe/SIPAFonts}"
FONT_REF="${MP_TH_SARABUN_REF:-0e53affcc75c330397ebf5fb4ff5d4d324826757}"
FONTDIR=/usr/share/fonts/truetype/th-sipa

tmp=$(mktemp -d)
if curl -fsSL --max-time 180 -o "$tmp/f.zip" \
        "https://codeload.github.com/${FONT_REPO}/zip/${FONT_REF}"; then
    unzip -oq "$tmp/f.zip" -d "$tmp"
    src=$(find "$tmp" -maxdepth 1 -type d -name "SIPAFonts*" | head -1)
    install -d -m 0755 "$FONTDIR"

    # The set carries "IT" variants whose filenames suggest something separate
    # but whose internal family and style names are identical to the plain
    # ones -- the same TH SarabunPSK Regular, the same TH Niramit AS Bold.
    # Installing both leaves fontconfig picking between duplicates, which it
    # does consistently until something invalidates its cache and then
    # silently differently. Two families are affected, Sarabun and Niramit,
    # which is why this is a pattern and not a list of four filenames.
    installed=0
    skipped_it=0
    skipped_dup=0
    seen_keys=""

    find "$src" -maxdepth 1 -iname "*.ttf" -print0 | sort -z | \
    while IFS= read -r -d '' f; do
        base=$(basename "$f")

        case "$base" in
            *"IT·"*|*" IT "*|*" IT."*)
                skipped_it=$((skipped_it + 1))
                continue
                ;;
        esac

        key=$(fc-query --format '%{family[0]}|%{style[0]}' "$f" 2>/dev/null)
        [ -z "$key" ] && continue

        # Safety net: if a duplicate family and style survives the pattern
        # above, drop it and say so rather than shipping both.
        case "$seen_keys" in
            *"[$key]"*)
                echo "    duplicate, skipped: $base ($key)" >&2
                skipped_dup=$((skipped_dup + 1))
                continue
                ;;
        esac
        seen_keys="$seen_keys[$key]"

        install -m 0644 "$f" "$FONTDIR/"
        installed=$((installed + 1))
    done

    # The licence travels with the files it covers.
    [ -f "$src/LICENSE" ]   && install -m 0644 "$src/LICENSE"   "$FONTDIR/LICENSE"
    [ -f "$src/README.md" ] && install -m 0644 "$src/README.md" "$FONTDIR/README.md"
    cat > "$FONTDIR/SOURCE" <<SOURCE
Fetched from https://github.com/${FONT_REPO}
Commit ${FONT_REF}
Licence: SIPA / Department of Intellectual Property font licence, see LICENSE.

The "IT" variants in the upstream set are deliberately not installed: their
internal family and style names duplicate the plain ones, which leaves
fontconfig choosing between identical entries.
SOURCE

    fc-cache -f >/dev/null 2>&1 || true
    echo "    $(ls "$FONTDIR"/*.ttf 2>/dev/null | wc -l) faces installed"
    echo "    families: $(fc-query --format '%{family[0]}\n' "$FONTDIR"/*.ttf 2>/dev/null | sort -u | wc -l)"
else
    echo "    could not fetch the fonts -- continuing without them" >&2
fi
rm -rf "$tmp"

# ----------------------------------------------------------------- network
# R-16: hand every interface to NetworkManager.
#
# debootstrap leaves /etc/netplan empty, and on Ubuntu netplan is what assigns
# interfaces to a backend. With no configuration at all nothing claims the
# adapter: NetworkManager runs and manages nothing, systemd-networkd runs and
# manages nothing, and the machine has no network while every service involved
# reports itself healthy.
#
# Mode 0600 because netplan refuses to stay quiet about world-readable
# configuration, and a warning on every boot trains people to ignore warnings.
say "network"
install -d -m 0755 /etc/netplan
cat > /etc/netplan/01-network-manager-all.yaml <<NETPLAN
# Let NetworkManager manage every device, wired and wireless.
network:
  version: 2
  renderer: NetworkManager
NETPLAN
chmod 0600 /etc/netplan/01-network-manager-all.yaml

# One backend, not two. systemd-networkd arrives enabled from the base install
# and would otherwise sit alongside NetworkManager competing for the same
# interfaces -- which works until both decide to configure one at the same
# moment, and then fails in a way that looks like flaky hardware.
systemctl disable systemd-networkd.service      >/dev/null 2>&1 || true
systemctl disable systemd-networkd.socket       >/dev/null 2>&1 || true
systemctl disable systemd-networkd-wait-online.service >/dev/null 2>&1 || true
systemctl mask    systemd-networkd-wait-online.service >/dev/null 2>&1 || true

# systemd-resolved stays: NetworkManager hands it the DNS servers it learns,
# and /etc/resolv.conf already points at its stub.
systemctl enable systemd-resolved.service >/dev/null 2>&1 || true

# ------------------------------------------------------------ system policy
say "system policy"

# R-08: Ubuntu's crash reporter. When something segfaults it offers to send a
# report to Ubuntu, in a dialog that says "Ubuntu has experienced an internal
# error" -- the wrong product name, to a place with no interest in the report.
# Purged rather than disabled: a disabled apport is one upgrade away from
# being enabled again.
apt-get purge -y -qq apport apport-symptoms 2>/dev/null || true
# Core dumps still land somewhere a person can go and look for them.
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/60-mp-coredump.conf <<SYSCTL
kernel.core_pattern=/var/crash/core.%e.%p
SYSCTL

# R-07: security updates install by themselves, but nothing reboots the
# machine while somebody is working on it.
cat > /etc/apt/apt.conf.d/52mp-unattended <<UNATTENDED
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
UNATTENDED

# R-14: firewall on, deny incoming.
#
# The mDNS rule is not optional. CUPS finds network printers over multicast
# DNS on UDP 5353, and denying incoming without allowing it breaks printer
# discovery in a way that looks like a broken printer rather than a firewall.
# R-04 puts printing on the disc as an essential, so breaking it here would
# undo that.
ufw --force disable >/dev/null 2>&1 || true
ufw default deny incoming  >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true
ufw allow in 5353/udp comment "mDNS: printer and service discovery" >/dev/null 2>&1 || true
ufw allow in 631/udp  comment "CUPS browsing" >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true
systemctl enable ufw.service >/dev/null 2>&1 || true

# --------------------------------------------------------------- keyboard
say "keyboard layouts"

# R-11: US English and Thai Kedmanee everywhere, Left Alt + Left Shift to
# switch.
#
# US first is deliberate. If Thai is the layout a greeter starts in, the first
# thing anyone types is a password in the wrong alphabet, and the login fails
# without saying why.
cat > /etc/default/keyboard <<KEYBOARD
XKBMODEL="pc105"
XKBLAYOUT="us,th"
XKBVARIANT=","
XKBOPTIONS="grp:lalt_lshift_toggle,grp_led:scroll"
BACKSPACE="guess"
KEYBOARD

# The console follows the same setting.
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<XORGKB
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbModel" "pc105"
        Option "XkbLayout" "us,th"
        Option "XkbOptions" "grp:lalt_lshift_toggle"
EndSection
XORGKB

# ------------------------------------------------------------------ services
say "services"

# ----------------------------------------------------------- display manager
# The disc booted into GNOME. Not XFCE with some GNOME parts -- GNOME:
#
#     $ echo $XDG_CURRENT_DESKTOP ; ps -e -o comm=
#     ubuntu:GNOME
#     gdm-session-worker  gnome-session-binary  gnome-shell
#
# gdm3 arrives as a dependency of things that are wanted on their own terms --
# update-manager, update-notifier and network-manager-gnome all list
# gnome-shell first in an alternation, and gnome-shell pulls ubuntu-session,
# which pulls gdm3. gdm3's postinst then claims
# /etc/X11/default-display-manager and the display-manager.service symlink,
# and "systemctl enable lightdm" below does not take either of them back:
# enable only creates that symlink when nothing else already owns it.
#
# So XFCE was installed, configured, themed and never run. Everything aimed
# at it was inert -- the XFCE panel layout, the /etc/skel plank config, the
# xfdesktop launcher permissions, all of R-03. The dock on the left of the
# screen was GNOME's, and the untrusted-launcher badge was GNOME's, which is
# why making the file executable changed nothing.
#
# gdm3 is purged rather than merely disabled: leaving it installed leaves a
# postinst that can take the symlink back on any later upgrade. Purging it
# takes nothing else with it -- checked, because the wider removal does:
#
#     apt-get purge -s gdm3         -> 1 to remove
#     apt-get purge -s gnome-shell  -> 10, including update-manager and
#                                      network-manager-gnome, which R-07 and
#                                      R-16 are about
#
# gnome-shell therefore stays on the disc. It is dead weight for a system
# whose session is XFCE, but it is cheaper than losing the update UI and the
# network applet, and it makes the GNOME option on the software page much
# smaller than it would otherwise be.
apt-get purge -y -qq gdm3 >/dev/null 2>&1 || true
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
echo "set shared/default-x-display-manager lightdm" | debconf-communicate >/dev/null 2>&1 || true
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

systemctl enable NetworkManager.service    >/dev/null 2>&1 || true
systemctl enable lightdm.service           >/dev/null 2>&1 || true
systemctl enable systemd-resolved.service  >/dev/null 2>&1 || true
systemctl enable cups.service              >/dev/null 2>&1 || true
systemctl enable avahi-daemon.service      >/dev/null 2>&1 || true
# snapd needs a seeded state or it hangs the first boot waiting for one.
systemctl enable snapd.service             >/dev/null 2>&1 || true

# Flathub, so the Software app has somewhere to install flatpaks from.
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

# ------------------------------------------------------------------ initramfs
say "initramfs"
update-initramfs -u -k all

# --------------------------------------------------------------- live session
say "live session"
# casper creates the live user at boot and reads its name from here. Without
# FLAVOUR set, casper overrides USERNAME and HOST with a string it works out at
# boot, and the autologin config below would then name a user that does not
# exist.
cat > /etc/casper.conf <<CASPER
export USERNAME="mplive"
export USERFULLNAME="Master Penguin Live"
export HOST="${MP_ID}"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="Master Penguin"
CASPER

# R-10: the live session, and therefore the installer, starts in Thai.
#
# Calamares takes its initial language from the locale it is launched in. The
# language dropdown on its first page overrides this and carries the choice
# into the installed system, so defaulting to Thai costs an English speaker
# one click and saves everyone else from starting in a language they did not
# ask for.
cat > /etc/default/locale <<LOCALE
LANG=th_TH.UTF-8
LC_MESSAGES=th_TH.UTF-8
LC_NUMERIC=th_TH.UTF-8
LC_TIME=th_TH.UTF-8
LC_MONETARY=th_TH.UTF-8
LC_PAPER=th_TH.UTF-8
LC_MEASUREMENT=th_TH.UTF-8
LOCALE
# th_TH.UTF-8 was generated earlier alongside en_US.UTF-8, so both are there
# and switching in the installer needs no further work.

# Autologin for the live session.
#
# casper ships a script that does this itself, but it writes into a
# [SeatDefaults] section -- the LightDM syntax from before 1.12. Current
# LightDM ignores that section outright, so the settings land in the file and
# do nothing, and the live disc stops at a login prompt asking for a password
# nobody was ever given. Write it again under [Seat:*], where it is read.
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/10-mp-live.conf <<LIGHTDM
[Seat:*]
autologin-user=mplive
autologin-user-timeout=0
autologin-session=xfce
allow-guest=false
LIGHTDM

# --------------------------------------------------------------- R-24
# No screen lock in the live session.
#
# xfce4-screensaver blanks and then locks, and the live user has no password,
# so the lock screen asks for something that does not exist. During a test it
# came up over a running installer and looked like a crash. Ubuntu's own live
# sessions turn this off for the same reason.
#
# The test is the user name rather than a file in /etc/skel, because /etc/skel
# is copied to the account created during installation as well, and a laptop
# that never locks is a worse fault than the one being fixed here. Only the
# live user gets this; every account made later keeps the normal defaults.
install -d -m 0755 /usr/local/bin
cat > /usr/local/bin/mp-live-nolock <<'NOLOCK'
#!/bin/sh
[ "$(id -un)" = "mplive" ] || exit 0
xset s off -dpms 2>/dev/null || true
for p in /saver/enabled /lock/enabled /lock/saver-activation/enabled; do
    xfconf-query -c xfce4-screensaver -p "$p" -n -t bool -s false 2>/dev/null || true
done
NOLOCK
chmod 0755 /usr/local/bin/mp-live-nolock

cat > /etc/xdg/autostart/mp-live-nolock.desktop <<AUTOLOCK
[Desktop Entry]
Type=Application
Name=Live session: no screen lock
Exec=/usr/local/bin/mp-live-nolock
OnlyShowIn=XFCE;
NoDisplay=true
AUTOLOCK

# ----------------------------------------------------------------- calamares
say "installing the installer"
rm -rf /etc/calamares
install -d -m 0755 /etc/calamares
# cp -r, not cp -a. The source of these files is a working tree on an NTFS
# volume mounted into WSL, where every file reads back as 0777 and owned by
# the build user -- and cp -a faithfully carried that into the image. The
# result was a world-writable /etc/calamares/settings.conf on a disc whose
# desktop launcher runs "pkexec calamares": any account on the live session
# could rewrite what the installer executes as root. Ownership and modes are
# set here instead of inherited from the host filesystem.
cp -r /tmp/calamares/settings.conf /etc/calamares/
cp -r /tmp/calamares/modules       /etc/calamares/
cp -r /tmp/calamares/branding      /etc/calamares/
chown -R root:root /etc/calamares
find /etc/calamares -type d -exec chmod 0755 {} +
find /etc/calamares -type f -exec chmod 0644 {} +

# Scripts the installer calls in the target system: mp-make-swap (R-13) and
# mp-finish-install, which undoes the live-session settings and applies the
# things Calamares has no module for.
if [ -d /tmp/overlay ]; then
    cp -a /tmp/overlay/. /
    chmod 0755 /usr/local/sbin/mp-make-swap /usr/local/sbin/mp-finish-install
fi

# A launcher the live session can actually click. pkexec rather than sudo: the
# installer is a GUI application and needs a polkit prompt, not a terminal.
cat > /usr/share/applications/mp-install.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install Master Penguin Linux
Name[th]=ติดตั้ง Master Penguin Linux
Comment=Install this system to your disk
Comment[th]=ติดตั้งระบบนี้ลงดิสก์
Exec=pkexec /usr/bin/calamares
Icon=/etc/calamares/branding/master-penguin/logo.svg
Terminal=false
Categories=System;
Keywords=install;installer;calamares;
DESKTOP


# --------------------------------------------------------------- branding
# R-02: the boot splash, and getting Ubuntu's logo off it.
#
# The default theme is bgrt, which draws the firmware's own logo when there is
# one and otherwise falls back to spinner. spinner's watermark.png is a symlink
# to ubuntu-logo-text-dark.png, which is why the Ubuntu name appears on the
# first screen of a system that is not Ubuntu.
#
# spinner is set directly rather than left on bgrt: bgrt shows whatever the
# machine's firmware supplies, which is a manufacturer logo on real hardware
# and nothing predictable in a VM. A distribution that wants its own first
# screen cannot leave that to the firmware.
say "boot splash"
if [ -d /usr/share/plymouth/themes/spinner ]; then
    MPLOGO=/usr/share/plymouth/themes/spinner/watermark.png
    rm -f "$MPLOGO"
    if command -v rsvg-convert >/dev/null 2>&1 && [ -f /tmp/calamares/branding/master-penguin/logo.svg ]; then
        rsvg-convert -w 256 -h 256 \
            /tmp/calamares/branding/master-penguin/logo.svg -o "$MPLOGO"
    fi
    # If the conversion could not run, leave no watermark at all rather than
    # putting the old symlink back: a blank splash is a smaller problem than
    # somebody else's brand on it.
    [ -s "$MPLOGO" ] || : > "$MPLOGO"

    # Blue field, matching the palette everything else uses.
    sed -i \
        -e 's/^BackgroundStartColor=.*/BackgroundStartColor=0x0d3c6e/' \
        -e 's/^BackgroundEndColor=.*/BackgroundEndColor=0x1668c4/' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth 2>/dev/null || true

    plymouth-set-default-theme spinner >/dev/null 2>&1 || \
        update-alternatives --set default.plymouth \
            /usr/share/plymouth/themes/spinner/spinner.plymouth >/dev/null 2>&1 || true
fi

# The same mark for the desktop and anything that asks the theme for a
# distributor logo.
install -d -m 0755 /usr/share/master-penguin
if [ -f /tmp/calamares/branding/master-penguin/logo.svg ]; then
    install -m 0644 /tmp/calamares/branding/master-penguin/logo.svg \
        /usr/share/master-penguin/logo.svg
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w 256 -h 256 /usr/share/master-penguin/logo.svg \
            -o /usr/share/master-penguin/logo.png
        install -D -m 0644 /usr/share/master-penguin/logo.png \
            /usr/share/icons/hicolor/256x256/apps/master-penguin.png
        gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
    fi
fi

# ------------------------------------------------------------- wallpaper
# R-02: the desktop itself was black.
#
# xfdesktop takes its default from a short list of files compiled into the
# binary:
#
#     $ strings /usr/bin/xfdesktop | grep backgrounds
#     /usr/share/xfce4/backdrops/xubuntu-wallpaper.png
#     /usr/share/backgrounds/xfce/xfce-stripes.png
#     /usr/share/backgrounds/xfce/xfce-teal.png
#     /usr/share/backgrounds/xfce/xfce-verticals.png
#
# None of them exist here. The first is Xubuntu's and this is not Xubuntu;
# the other three are shipped as .svg, not .png. Nothing matched, and a
# desktop with no backdrop is black.
#
# The file is written under this project's own name and the name xfdesktop
# looks for is a symlink to it, so the asset is ours and the lookup still
# finds it without having to guess a monitor name.
say "wallpaper"
if [ -f /tmp/calamares/branding/master-penguin/wallpaper.svg ]; then
    install -d -m 0755 /usr/share/backgrounds/master-penguin /usr/share/xfce4/backdrops
    install -m 0644 /tmp/calamares/branding/master-penguin/wallpaper.svg         /usr/share/backgrounds/master-penguin/mp-wallpaper.svg
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w 1920 -h 1080             /usr/share/backgrounds/master-penguin/mp-wallpaper.svg             -o /usr/share/backgrounds/master-penguin/mp-wallpaper.png
        ln -sf /usr/share/backgrounds/master-penguin/mp-wallpaper.png             /usr/share/xfce4/backdrops/xubuntu-wallpaper.png
    fi
fi

# ...and say it explicitly as well, for the monitor names a virtual machine
# and a laptop are each likely to report. A property for a monitor that is
# not present is simply never read, so listing several costs nothing; the
# solid colour underneath is the deep blue rather than black, so even a
# machine whose monitor is named something not listed here comes up in the
# right colour instead of the wrong one.
XFCONF=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml
install -d -m 0755 "$XFCONF"
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<channel name="xfce4-desktop" version="1.0">'
    echo '  <property name="backdrop" type="empty">'
    echo '    <property name="screen0" type="empty">'
    for m in monitorVirtual-1 monitorVirtual1 monitorVGA-1 monitoreDP-1              monitorHDMI-1 monitorDP-1 monitorLVDS-1 monitor0; do
        echo "      <property name=\"$m\" type=\"empty\">"
        echo '        <property name="workspace0" type="empty">'
        echo '          <property name="color-style" type="int" value="0"/>'
        echo '          <property name="rgba1" type="array">'
        echo '            <value type="double" value="0.050980"/>'
        echo '            <value type="double" value="0.235294"/>'
        echo '            <value type="double" value="0.431373"/>'
        echo '            <value type="double" value="1.000000"/>'
        echo '          </property>'
        echo '          <property name="image-style" type="int" value="5"/>'
        echo '          <property name="last-image" type="string" value="/usr/share/backgrounds/master-penguin/mp-wallpaper.png"/>'
        echo '        </property>'
        echo '      </property>'
    done
    echo '    </property>'
    echo '  </property>'
    echo '</channel>'
} > "$XFCONF/xfce4-desktop.xml"
chmod 0644 "$XFCONF/xfce4-desktop.xml"

# --------------------------------------------------------------- dock
# R-15: the installer has to be reachable without a fight.
#
# A .desktop file on the desktop is the obvious place for it and the one that
# does not work: Thunar asks whether the launcher is trusted every single time,
# because the answer lives in per-user GIO metadata that cannot be seeded from
# /etc/skel. Pinning it to the dock sidesteps the question entirely — plank
# reads a plain file, and a dock item is not a file the user is being asked to
# execute.
say "dock"
PLANK=/etc/skel/.config/plank/dock1
install -d -m 0755 "$PLANK/launchers"

dockitem() {
    cat > "$PLANK/launchers/$1.dockitem" <<ITEM
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/$2
ITEM
}
dockitem 00-install  mp-install.desktop
dockitem 10-files    thunar.desktop
dockitem 20-terminal xfce4-terminal.desktop
dockitem 30-firefox  firefox.desktop
dockitem 40-mail     thunderbird.desktop
dockitem 50-software org.gnome.Software.desktop

# Bottom, centred, magnifying — the R-03 shape.
cat > "$PLANK/settings" <<PLANK_SETTINGS
[PlankDockPreferences]
CurrentWorkspaceOnly=false
IconSize=48
HideMode=0
UnhideDelay=0
HideDelay=0
Monitor=
DockItems=00-install.dockitem;;10-files.dockitem;;20-terminal.dockitem;;30-firefox.dockitem;;40-mail.dockitem;;50-software.dockitem
Position=2
Offset=0
Theme=Transparent
Alignment=3
ItemsAlignment=3
LockItems=false
PressureReveal=false
PinnedOnly=false
AutoPinning=true
ShowDockItem=false
ZoomEnabled=true
ZoomPercent=150
PLANK_SETTINGS

# Start it with the session, for every account rather than only the first one
# built from /etc/skel.
cat > /etc/xdg/autostart/plank.desktop <<AUTOSTART
[Desktop Entry]
Type=Application
Name=Dock
Exec=plank
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
AUTOSTART

# ...and put the icon back on the desktop as well, because taking it away
# left a live disc with no visible way to start the installer at all.
#
# It was removed on the theory that the "this launcher is untrusted" prompt
# came from per-user GIO metadata that /etc/skel cannot seed. That is Thunar's
# behaviour for files in a window; the desktop is drawn by xfdesktop, which
# decides the same question differently -- it runs a .desktop file without
# asking if, and only if, the file is executable. It was mode 0644, so it
# asked. Every Ubuntu live disc ships its installer launcher 0755 for this
# reason.
install -d -m 0755 /etc/skel/Desktop
install -m 0755 /usr/share/applications/mp-install.desktop     /etc/skel/Desktop/mp-install.desktop

# And a third way in, for when a session has neither a dock nor desktop icons:
# the applications menu, under System.
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

# -------------------------------------------------------------------- tidy up
say "cleaning up"
# casper mounts over these at boot, so they have to exist in the image as
# empty directories. An image without /run is one where adduser cannot take
# its lock and the live user is never created.
mkdir -p /proc /sys /run /tmp /var/tmp /mnt /media
chmod 1777 /tmp /var/tmp
# Only the newest kernel. The chroot had two -- 7.0.0-31 and 7.0.0-34 -- and
# the disc carried both: two initrds at 94 MB each and two module trees, about
# 300 MB for a kernel nothing would ever boot. 30-squashfs.sh already takes the
# newest for /casper, so the older one was dead weight on the disc and would
# have been dead weight on every installed system as well.
KEEP=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed "s|.*/vmlinuz-||" | sort -V | tail -1)
if [ -n "$KEEP" ]; then
    OLD=$(dpkg-query -W -f='${Package}\n' 'linux-image-*' 'linux-modules-*' 'linux-headers-*' 2>/dev/null | grep -E '^linux-(image|modules|headers)(-unsigned|-extra)?-[0-9]' | grep -v -- "$KEEP" || true)
    if [ -n "$OLD" ]; then
        say "removing kernels older than $KEEP"
        apt-get purge -y -qq $OLD >/dev/null 2>&1 || true
    fi
fi

apt-get autoremove -y -qq
apt-get clean
rm -f /usr/sbin/policy-rc.d
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
# Hand DNS back to systemd-resolved. The build replaced this with a real file
# so apt could resolve names inside the chroot.
rm -f /etc/resolv.conf
ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

rm -f /etc/machine-id /var/lib/dbus/machine-id
: > /etc/machine-id
find /var/log -type f -exec truncate -s 0 {} +

say "chroot size: $(du -sh / --exclude=/proc --exclude=/sys --exclude=/dev 2>/dev/null | cut -f1)"
