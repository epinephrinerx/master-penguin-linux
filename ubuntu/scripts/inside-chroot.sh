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
apt-get install -y -qq firefox firefox-l10n-th thunderbird thunderbird-l10n-th

# ------------------------------------------------------------------ branding
say "branding"
cat > /etc/os-release <<RELEASE
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
cp /etc/os-release /usr/lib/os-release
echo "${MP_ID}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1	localhost
127.0.1.1	${MP_ID}
::1		localhost ip6-localhost ip6-loopback
HOSTS

# ------------------------------------------------------------------ services
say "services"
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

# ----------------------------------------------------------------- calamares
say "installing the installer"
rm -rf /etc/calamares
install -d -m 0755 /etc/calamares
cp -a /tmp/calamares/settings.conf          /etc/calamares/
cp -a /tmp/calamares/modules                /etc/calamares/
cp -a /tmp/calamares/branding               /etc/calamares/
cp -a /tmp/calamares/netinstall-desktops.yaml /etc/calamares/

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

# ...and the same icon sitting on the live desktop, which is where a person
# looks for it. casper builds the live user's home from /etc/skel.
#
# Mode 0755 is not decoration: Thunar refuses to launch a .desktop file from the
# desktop unless it is executable, and silently offers to open it in a text
# editor instead.
install -d -m 0755 /etc/skel/Desktop
install -m 0755 /usr/share/applications/mp-install.desktop /etc/skel/Desktop/

# -------------------------------------------------------------------- tidy up
say "cleaning up"
apt-get autoremove -y -qq
apt-get clean
rm -f /usr/sbin/policy-rc.d
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
rm -f /etc/machine-id /var/lib/dbus/machine-id
: > /etc/machine-id
find /var/log -type f -exec truncate -s 0 {} +

say "chroot size: $(du -sh / --exclude=/proc --exclude=/sys --exclude=/dev 2>/dev/null | cut -f1)"
