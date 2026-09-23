# Requirements

Issues found while testing Master Penguin Linux, written up as things to do.

**How this file is used.** Problems get reported one at a time. Each one is
turned into a requirement here — what is wrong, what "fixed" looks like, and
how it will be checked. **Nothing is implemented until it is explicitly asked
for.** This file is the queue, not the work.

Their original wording is kept verbatim under *Reported*, because the exact
description of a symptom is often the most useful thing in a bug report.

## Status

| | |
|---|---|
| `OPEN` | written down, not started |
| `WIP` | being worked on now |
| `DONE` | fixed and verified — how it was verified is recorded |
| `WONTFIX` | deliberately not doing it; the reason is recorded |

## Requirement format

```
### R-nn — one-line summary

Status:   OPEN
Reported: "what was actually said"
Area:     which track and which file(s)

Problem
    What goes wrong, and what it looks like when it does.

Requirement
    What has to be true afterwards. Written so it can be disagreed with.

Verification
    How it gets proved, concretely. A screenshot, a command and its output,
    a boot that reaches a given point.

Notes
    Anything relevant: suspected cause, related requirements, trade-offs.
```

---

## Open

### R-02 — blue and white everywhere, from the first thing on screen

Status:   OPEN
Reported: "ผมอยากให้ theme ทั้งหมดเป็นสีฟ้าขาว ตั้งแต่แรกเลยครับ พอได้ไหมครับ"
Area:     ubuntu track — package lists, `inside-chroot.sh`, `grub/grub.cfg`,
          `calamares/branding/master-penguin/`

Problem
    The system has no identity of its own. It is whatever each component
    defaults to: a black GRUB menu, Ubuntu's purple boot splash, Greybird's
    grey desktop, a Calamares branding in dark navy that matches none of it.
    Nothing says this is one system rather than a pile of parts.

Requirement
    Every screen from power-on to desktop is blue and white, and they are the
    *same* blue and white. "From the first thing on screen" is the point:
    theming only the desktop leaves three unbranded screens in front of it.

    The surfaces, in the order a person meets them:

    | # | Surface | What has to change |
    |---|---|---|
    | 1 | GRUB menu (ISO) | background, highlight, text |
    | 2 | Boot splash (Plymouth) | logo and progress on a blue field |
    | 3 | LightDM greeter | background, and the greeter's own colours |
    | 4 | Desktop | GTK theme, window borders, icons, panel, wallpaper |
    | 5 | Installer (Calamares) | branding colours and slideshow |

    One palette, defined in one place, used by all five. Changing the blue
    should be one edit, not five.

    Proposed palette, to be confirmed before any work starts:

    | Token | Value | Used for |
    |---|---|---|
    | deep | `#0d3c6e` | GRUB background, splash field, greeter background |
    | primary | `#1668c4` | panel, selection, buttons, window borders |
    | light | `#6cb2f0` | highlights, focus rings, progress |
    | paper | `#f4f8fd` | window backgrounds, the "white" |
    | ink | `#0f2a44` | text on light backgrounds |

Verification
    Five screenshots, one per surface, taken from a single boot of the ISO in
    VirtualBox: GRUB menu, splash, greeter (or the moment it is skipped),
    desktop, installer. Put side by side they read as one system.

Notes
    Feasibility, since it was asked directly: yes, all five. They are not
    equally cheap.

    Cheap — existing packages, configuration only:
      - GTK and window-manager theme. `arc-theme` is blue and white already
        and is in universe; the alternative is recolouring Greybird.
      - Icons. `papirus-icon-theme` has blue folders and a very large set.
      - LightDM greeter, XFCE panel and desktop settings: all config files.
      - Calamares branding: colours in `branding.desc`, already structured
        for this.

    Real work — has to be made:
      - Wallpaper. Drawn, not downloaded, so it can carry the penguin.
      - GRUB theme. Needs a background image and a `theme.txt`; the ISO menu
        currently sets no colours at all.
      - Plymouth theme. The fiddliest of the five: a theme directory, a
        script, and an initramfs rebuild for every change. Worth doing last,
        and worth checking how it looks under VirtualBox's VMSVGA, where
        early KMS is not a given.

    Settled: the boot chain keeps this blue and white as the product identity,
    and the installed desktop (R-03) is macOS-like using the same blue as its
    accent. One palette across both.

    Open question: the exact blue. The palette above is a starting point, not
    a decision — a shade that looks right in a screenshot can be unreadable
    as greeter text. Worth settling before the work, because it touches five
    places.

    **Update 2026-09-22.** The sidebar was still near-black, and the step
    names on it still could not be read. The palette was right and the key
    names were wrong. branding.desc used `sidebarBackground`, `sidebarText`,
    `sidebarTextSelect` and `sidebarBackgroundSelected` — the Calamares 3.2
    names, which is what almost all the documentation in circulation still
    shows. The build on this disc is 3.3.14 and knows none of them:

        $ grep -c sidebarBackground libcalamaresui.so.3.3.14   -> 0
        $ strings libcalamaresui.so.3.3.14 | grep -E "^Sidebar"
          SidebarBackground
          SidebarText
          SidebarTextCurrent
          SidebarBackgroundCurrent

    Unknown style keys are ignored without a message, so the entire block did
    nothing. Now written with the four names this build actually reads.

    The slideshow had the same shape of fault for a different reason: its text
    was `#f2f4f7`, near-white, on the white panel Calamares draws behind it.
    It now sets its own background and its own colours rather than inheriting
    either.

    **Verified and one gap found, 2026-09-23.** On an installed system booted
    from its own disk: the boot splash is the blue gradient with this
    project's penguin and no Ubuntu text, the desktop wallpaper is the blue
    gradient, and the installer's sidebar is blue with readable white text.
    The slideshow reads correctly as well -- blue heading, dark text on a
    light panel, where before it was near-white text on white.

    The gap: the login screen came up in Ubuntu's aubergine. The greeter does
    not use the desktop wallpaper -- lightdm-gtk-greeter has its own
    background setting and its default comes from the distribution's theme
    package. Now set in
    /etc/lightdm/lightdm-gtk-greeter.conf.d/10-mp.conf. Unverified.

### R-03 — the installed desktop should look as close to macOS as XFCE allows

Status:   OPEN
Reported: "หลังติดตั้งผมอยากได้ theme ที่คล้าย MacOS ที่สุดครับ พอทำได้ไหมครับบน XFCE"
Area:     ubuntu track — package lists, `inside-chroot.sh`, XFCE defaults in
          `/etc/skel`

Problem
    A stock XFCE desktop looks like a stock XFCE desktop: a panel across the
    top with a mouse-shaped menu button, square window buttons on the right,
    grey everything. It is nobody's idea of a Mac.

Requirement
    After installation, the desktop reads as macOS-like at a glance. Concretely,
    and in rough order of how much each one contributes:

    | Element | Target | How |
    |---|---|---|
    | Dock | bottom centre, magnifying, translucent | `plank`, with the WhiteSur dock theme |
    | Window buttons | left side, three round lights | xfwm4 theme with a left button layout |
    | GTK theme | Big Sur-ish: light, soft, rounded | WhiteSur GTK theme |
    | Icons | macOS-style | WhiteSur icon theme |
    | Cursor | macOS-style pointer | `capitaine-cursors`, already in universe |
    | Panel | thin bar at the top, clock on the right | xfce4-panel, reconfigured |
    | Font | SF-like UI font | Inter |
    | Overview | Mission Control-ish | `xfdashboard`, bound to a hot corner |
    | Search | Spotlight-ish | `xfce4-appfinder` on a keybinding |

    All of it default for a new user — set in `/etc/skel`, not a document
    telling people how to configure it themselves.

Verification
    Install to a virtual disk, log in as the account created during install,
    screenshot the bare desktop and one with a window open. Judged by eye
    against a macOS screenshot: dock, left-hand traffic lights, top bar.

Notes
    Feasibility, since it was asked directly: yes for everything in the table.
    XFCE is a better base for this than GNOME, because its panel and window
    manager are both freely rearrangeable.

    What will *not* be faithful, and should be said now rather than discovered
    later:

      - **The global menu bar.** On macOS an application's menus live in the
        top bar, not in its window. Nothing on XFCE does this reliably; the
        projects that try are fragile and not packaged in Ubuntu 26.04. This
        is the one difference nobody can un-see, and it is not worth breaking
        the desktop to chase.
      - Finder. Thunar can be made to resemble it in layout only.
      - The genie effect, Launchpad, Stage Manager, and similar: no.

    Legal and packaging notes, which shape the work:

      - WhiteSur is not in the Ubuntu archive. It has to be fetched at build
        time and pinned to a commit, not installed from the network at first
        boot — a desktop that only looks right if the machine is online is
        not a theme, it is a hope.
      - **Nothing from Apple gets shipped.** Not the SF fonts, not the Apple
        logo for the menu button, not macOS wallpapers. Inter is the SF
        substitute; the menu button gets the penguin. This is not caution for
        its own sake — those assets are not redistributable, and an ISO that
        carries them cannot be handed to anyone.

    Relationship with R-02, which needs deciding before either starts:
    R-02 asks for blue and white "from the first thing on screen"; this asks
    for macOS-like "after installation". Two readings:

      a. The boot chain (GRUB, splash, greeter) stays blue and white as the
         product's identity, and the desktop behind it is macOS-like with a
         blue accent. The two meet in the middle and WhiteSur takes a blue
         accent natively.
      b. Blue and white is the live disc only, and an installed system is
         macOS-like throughout.

    **Settled: (a).** The boot chain stays blue and white; the desktop is
    macOS-like with the R-02 blue as its accent colour. WhiteSur takes an
    accent natively, so the two meet without fighting.

    **Dock options, checked against the Ubuntu 26.04 archive rather than
    remembered.** Asked for directly, so the survey is recorded here:

    | Package | Version | What it is | Magnifies |
    |---|---|---|---|
    | `plank` | 0.11.89 | a real dock, floating, bottom centre | yes |
    | `cairo-dock` | 3.5.1 | a dock with applets, sub-docks, 3D views | yes |
    | `tint2` | 17.0.1 | a panel that can be shaped into a dock | no |
    | `xfce4-docklike-plugin` | 0.5.1 | grouped icon buttons inside the XFCE panel | no |
    | xfce4-panel alone | — | a second panel, icon launchers, auto-hide | no |

    Not in the archive any more, in case they come up: `docky`, `dockbarx`,
    `latte-dock`.

    Recommendation: **plank**. The magnification on hover is the single detail
    that reads as "Mac" from across a room, and only plank and cairo-dock do
    it. Between those two, plank is deliberately plain — a handful of settings
    and no way to make it look wrong — while cairo-dock is endlessly
    configurable and, configured carelessly, lands somewhere around 2009.
    WhiteSur also ships a plank theme, so the dock and the windows match
    without extra work.

    Against plank: upstream is quiet. It is packaged, it works, and nothing
    about it is load-bearing — if it ever goes, the dock goes and the desktop
    carries on.

    The two no-magnification options are worth knowing about for a different
    reason: `xfce4-docklike-plugin` adds no process at all, since it lives in
    the panel that is already running. On a slow machine that is the argument.

    **Settled: plank.**

    Two things follow from that and should be done at the same time rather
    than discovered later:

      - Plank is a separate process and has to be started with the session,
        not left to be launched by hand. An autostart entry in `/etc/xdg/autostart`
        so it applies to every account, including ones created after install.
      - With a dock holding the launchers and running applications, the XFCE
        panel should stop doing that job. Otherwise every open window appears
        twice, once in each, which no Mac has ever done. The panel keeps the
        menu, the clock and the system tray; the window buttons come out.

### R-04 — let people choose what gets installed, during the install

Status:   OPEN
Reported: "ในการติดตั้ง ให้มีตัวเลือก package ที่จำเป็นได้ไหมครับ"
Area:     ubuntu track — `calamares/netinstall-desktops.yaml`,
          `calamares/modules/netinstall.conf`, package lists

Problem
    The installer offers a desktop and three vague extras (LibreOffice, Media,
    Development). That is not a choice, it is a placeholder. Everything else is
    decided by whoever built the ISO, so an install is either missing things
    people need or carrying things they do not want, and there is no moment at
    which they get a say.

Requirement
    The installer has a page of software groups, each with a plain description
    of what it is for and what it costs in disk space. Chosen groups are
    installed as part of the install, not left as homework.

    Proposed groups. The list itself is the thing to argue about, so it is
    written out rather than left as "some categories":

    | Group | Contains | Roughly | Where | Default |
    |---|---|---|---|---|
    | Media | codecs, VLC | 350 MB | **on the disc** | on |
    | Printing and scanning | simple-scan, driver backends | 150 MB | **on the disc** | on |
    | Office | LibreOffice + Thai dictionaries | 700 MB | download | off |
    | Graphics | GIMP, Inkscape | 550 MB | download | off |
    | Development | build-essential, git, python3-pip | 400 MB | download | off |
    | Backup | timeshift | 50 MB | download | off |
    | Remote access | openssh-server, remmina | 80 MB | download | off |

    Sizes get measured, not guessed, before the page ships.

    Two rules that matter more than the list:

    1. **Unticking everything still produces a working system.** Nothing in
       this page may be load-bearing. The base install already has a browser,
       a mail client, a file manager, a terminal and the three package
       managers; groups are additions, never prerequisites.
    2. **Every group says what it costs.** A person on a slow connection is
       choosing how long they will wait, and they can only do that if the
       number is in front of them.

Verification
    Two installs to virtual disks from one ISO: one with everything unticked,
    one with everything ticked. Both boot to a working desktop. The first has
    no LibreOffice and no GIMP; the second has both. Screenshot the page
    itself, since being readable is most of the requirement.

Notes
    Mechanically this is cheap: Calamares' netinstall module already does
    exactly this and is already wired up. The work is deciding the list and
    measuring the sizes.

    **Settled: what is necessary goes on the disc, the rest is downloaded.**

    That needs a test for "necessary", or it just moves the argument. The one
    used above: *would its absence be noticed on the first day of ordinary use,
    on a machine with no network?* Under that test only two groups qualify —
    without codecs an ordinary video file will not play, and a printer plugged
    into a machine is expected to print. Everything else can wait until there
    is a connection, because wanting GIMP and needing GIMP are different.

    Cost: about 500 MB on the disc, which puts the ISO near 2.6 GB, inside the
    3.xx GB ceiling with room left.

    One borderline call worth naming rather than burying: **Backup** fails the
    test — nobody misses timeshift on day one — but it is only 50 MB, and the
    day it is wanted is usually the day the network is not. It is listed as a
    download to keep the rule honest. Say so and it moves.

    A trap in the Media group: `ubuntu-restricted-extras` cannot be used for
    an on-disc group. It pulls `ttf-mscorefonts-installer`, which downloads
    the fonts from the network when it is configured, so an offline install
    would fail on the one group that is meant to work offline. The group has
    to name the codec packages directly — the gstreamer plugin sets and
    libavcodec — and leave the fonts out.

    Still to be written up separately: the netinstall page is English only.
    The group names and descriptions live in the YAML and nothing translates
    them, so a Thai installer session reads this page in English.

### R-05 — ship TH Sarabun New with the system

Status:   OPEN
Reported: "ฝัง font TH Sarabun New ไว้ในเครื่องด้วยครับ"
Area:     ubuntu track — `scripts/inside-chroot.sh`, package lists

Problem
    TH Sarabun New is the typeface Thai government documents are written in —
    it has been the required font for official documents since 2010. It is not
    in the Ubuntu archive, and `fonts-thai-tlwg` does not contain it.

    Without it, any Thai document that asks for TH Sarabun New gets a
    substitute. Thai substitution is not the mild inconvenience it is in
    Latin text: the metrics differ, so line breaks move, pagination shifts,
    and a form that was laid out to fit one page no longer does. A person
    receiving an official .docx sees a document that is wrong, not merely
    different.

Requirement
    1. Both families — **TH Sarabun New and TH SarabunPSK** — are installed
       system-wide, present on the ISO itself, and available with no network
       and no extra steps.
    2. All four faces of each: Regular, Bold, Italic, Bold Italic. A document
       using bold text needs the real bold face, not a synthesised slant.
       Eight files in total.
    3. Applications find it by name. Opening a document that specifies
       "TH Sarabun New" uses it rather than substituting.
    4. It does not become the interface font. This is a document typeface;
       the desktop keeps the UI font from R-03.

Verification
    On a booted live session, with no network:
      - `fc-list | grep -i sarabun` lists eight faces, four per family.
      - `fc-match "TH Sarabun New"` and `fc-match "TH SarabunPSK"` each
        return themselves, not a substitute and not each other.
      - Open a Thai .docx that specifies the font and screenshot it. Compare
        page count against the same file elsewhere — the real test is that
        the layout holds, not that Thai renders at all.

Notes
    Size is not a consideration: the family is a couple of megabytes. It goes
    on the disc regardless of the R-04 split, because a font that has to be
    downloaded is a font that is missing exactly when an offline machine
    opens a government form.

    **The licence has to be confirmed before this ships.** TH Sarabun New came
    out of the SIPA national font programme and is distributed free for public
    use, which is why it is everywhere in Thailand — but "free to download"
    and "free to redistribute inside an ISO handed to other people" are not
    the same permission. The exact licence text needs reading, and its terms
    recorded here, before the font goes into an image anyone else receives.
    This is the one thing in this requirement that could turn it down.

    Sourcing: fetched at build time from a pinned URL with a recorded
    checksum, installed into `/usr/share/fonts/truetype/`, then `fc-cache`.
    Pinned, because a font that changes underneath the build changes document
    metrics without anyone noticing.

    **Settled: both families ship.** TH SarabunPSK is the older release of the
    same design, and a great many existing documents ask for that name
    specifically. Carrying both costs about two megabytes and removes the
    alternative, which was a fontconfig alias pointing one name at the other
    — aliases hold in most applications and quietly fail in some, and the
    ones that fail tend to be the office suites this matters for.

    The licence check covers both. They come from the same programme, but
    that is an assumption until the terms for each have actually been read.

### R-06 — the installed system must boot on EFI machines, and with Secure Boot on

Status:   OPEN
Reported: gap review — "1,2 ดำเนินการให้ครอบคลุมผู้ใช้ส่วนใหญ่เลยครับ"
Area:     ubuntu track — package lists, `scripts/40-iso.sh`, Calamares bootloader

Problem
    The chroot has `grub-pc` and nothing else — it arrived as a dependency, not
    by choice. There is no `grub-efi-amd64`, so installing onto an EFI machine
    has no bootloader to install. Every machine sold in the last decade boots
    EFI by default, including the VMs this is being tested in.

    Separately, the EFI binary on the ISO is built with `grub-mkstandalone` and
    is unsigned. PCs ship with Secure Boot enabled, and firmware will not load
    an unsigned bootloader. The disc appears blank and the machine moves on to
    the next boot device.

Requirement
    1. The chroot carries the bootloader packages for both firmwares:
       `grub-efi-amd64-signed`, `shim-signed`, `grub-pc`, `efibootmgr`.
    2. Calamares installs the one matching the firmware it finds, and the
       installed system boots unaided afterwards.
    3. The ISO boots with Secure Boot enabled, via shim and a signed GRUB
       rather than a self-built one.
    4. BIOS boot keeps working. Older machines and VM templates still use it.

Verification
    Install from the ISO in four VirtualBox configurations and boot the result
    in each: EFI with Secure Boot on, EFI with it off, BIOS, and one EFI
    install onto a disk that already has another OS on it, to check the
    existing boot entries survive.

Notes
    Point 3 changes how the ISO is built, and not trivially. A signed GRUB only
    loads what its signed core allows, so the `grub-mkstandalone` approach with
    an embedded config cannot be used on the Secure Boot path — that path has
    to use the shim and signed grub from Ubuntu, with a `grub.cfg` read off the
    disc. Expect the ISO to end up with two EFI paths: the signed one for
    Secure Boot, the current one as a fallback.

    None of this is visible from a booted live session. It only shows up by
    installing and rebooting, which is why it went unnoticed.

    **Verified 2026-09-23 (EFI).** The installed system boots from its own
    disk with no disc present, under OVMF, using the variable store the
    installer wrote to -- so efibootmgr did register an entry. The ESP
    carries the bootloader under this project's name:

        $ ls /boot/efi/EFI/
        BOOT  master-penguin

    That is the half of R-06 that no live-session test could reach, and it is
    what the efivarfs mount added in R-21 was for. Secure Boot itself (shim
    plus a signed grub) is still not done, and BIOS boot of an installed
    system is still unverified.

### R-07 — updates people can actually see

Status:   OPEN
Reported: gap review — "3 ดำเนินการให้ครอบคลุมผู้ใช้ส่วนใหญ่เลยครับ"
Area:     ubuntu track — package lists, `scripts/inside-chroot.sh`

Problem
    `unattended-upgrades` is installed, so security updates are applied
    silently, but there is no `update-manager` and no `update-notifier`.
    Nobody is told an update exists, nobody can see what was installed, and
    nobody can ask for updates on purpose. A desktop where updates are
    invisible is one where people assume there are none.

Requirement
    1. `update-manager` and `update-notifier` installed, so updates are
       announced and can be applied on demand.
    2. Security updates continue to install by themselves, unattended.
    3. Nothing reboots the machine on its own.

Verification
    On an installed system with an update pending, a notification appears, and
    opening it lists the update and applies it. `unattended-upgrades --dry-run`
    shows the security origin enabled.

Notes
    Point 3 is the one that gets forgotten. Automatic security updates are
    right for most people; a machine that restarts itself in the middle of
    their work is not, and `unattended-upgrades` will do exactly that if
    `Automatic-Reboot` is left on.

### R-08 — no crash reporter that says Ubuntu

Status:   OPEN
Reported: gap review — "4 ดำเนินการให้ครอบคลุมผู้ใช้ส่วนใหญ่เลยครับ"
Area:     ubuntu track — package lists, `scripts/inside-chroot.sh`

Problem
    `apport` is installed. When something crashes it shows a dialog saying
    "Ubuntu has experienced an internal error" and offers to send a report to
    Ubuntu, where nobody is expecting reports about this system. It names the
    wrong product to the person using it, and sends data somewhere that has no
    use for it.

Requirement
    1. No crash dialog naming Ubuntu ever appears.
    2. No crash data is sent anywhere by default.
    3. Core dumps can still be collected locally by someone who goes looking.
       Removing the ability to diagnose a crash is not the goal.

Verification
    Kill an application with SIGSEGV on an installed system. No dialog appears.
    `apport` is absent or disabled, and `/var/crash` stays empty.

### R-09 — a way to install proprietary drivers

Status:   OPEN
Reported: gap review — "5 ควรต้องใส่ครับ"
Area:     ubuntu track — package lists

Problem
    `ubuntu-drivers-common` is not installed, so there is no way to find or
    install the NVIDIA driver, or any other vendor driver, short of knowing the
    package name by heart. On a machine with an NVIDIA card that means software
    rendering and no obvious way out of it.

Requirement
    1. `ubuntu-drivers-common` installed, so `ubuntu-drivers list` and
       `ubuntu-drivers install` work.
    2. A graphical route to the same thing — the Additional Drivers tab in
       `software-properties-gtk`.
    3. Nothing proprietary installed by default. It is offered, not assumed.

Verification
    `ubuntu-drivers list` runs on an installed system and reports sensibly on
    hardware with no proprietary option available. The Additional Drivers tab
    opens.

### R-10 — the installer runs in Thai, and says so on the first screen

Status:   OPEN
Reported: "6 ให้เลือกตัวติดตั้งไทยหรืออังกฤษในหน้าแรก แต่ Default ให้เป็นไทยครับ"
Area:     ubuntu track — `calamares/`, `scripts/inside-chroot.sh`

Problem
    The installer is in English throughout, with no way to change it. For the
    people this is built for, that is the first thing they meet and the least
    welcoming thing about it.

Requirement
    1. The installer opens in Thai.
    2. The first screen offers Thai or English, and switching changes every
       page, not only the one in front of you.
    3. The choice carries into the installed system: choose Thai and the
       desktop comes up in Thai, with Thai date and number formats.
    4. The package selection page from R-04 is translated too. It is the one
       page whose text this project writes, so nothing translates it by
       default.

Verification
    Boot the ISO: the installer is in Thai. Switch to English on the first page
    and walk every page including package selection — all English. Install in
    Thai, boot the result: the desktop is in Thai.

Notes
    Calamares already ships Thai translations, `calamares-python.mo` for `th`
    is in the chroot, so its own pages are done. Point 4 is the work: the group
    names and descriptions live in this project's YAML.

### R-11 — Thai and English keyboards from the first screen, Alt + Left Shift to switch

Status:   OPEN
Reported: "ให้ภาษาในการติดตั้งเป็นไทย และใส่คีย์บอร์ดไทยมาตรฐานกับ US English
          ไว้ตั้งแต่แรกเลยครับ โดยให้ปุ่มเปลี่ยนภาษาเป็น Alt + Left Shift ตั้งแต่แรก"
Area:     ubuntu track — `scripts/inside-chroot.sh`, Calamares keyboard module,
          XFCE defaults

Problem
    Only one keyboard layout is configured, and adding a second is something a
    person has to know to go and do. Someone installing in Thai cannot type
    Thai during the install — including into the field where they name their
    own account.

Requirement
    1. Two layouts present everywhere, in this order: **US English**, then
       **Thai Kedmanee**, the standard Thai layout.
    2. **Left Alt + Left Shift** switches between them.
    3. It works in all four places, from the first screen onwards: the live
       session, the installer, the installed system, and for accounts created
       later — not only the first one.
    4. The active layout is visible on screen. A switching shortcut with no
       indicator is a way to type the wrong alphabet into a password field and
       have no idea why the login failed.

Verification
    In the live session, type Thai and English in a text editor and switch with
    the shortcut. Do the same on the installer's account page. After
    installing, log in and repeat. Create a second account and repeat again.

Notes
    In X11 terms: layouts `us,th`, option `grp:lalt_lshift_toggle`, and
    `xfce4-xkb-plugin` on the panel for point 4.

    US first and Thai second is deliberate. A greeter that starts in Thai means
    a password typed in Thai characters and a login that fails without saying
    why — the same failure point 4 exists to prevent.

    **Not fixed on the installed system, 2026-09-23.** Both system files were
    correct and the session still had one layout:

        $ cat /etc/default/keyboard
        XKBLAYOUT="us,th"
        $ cat /etc/X11/xorg.conf.d/00-keyboard.conf
        Option "XkbLayout" "us,th"
        $ setxkbmap -query
        layout:  us
        options: grp:lalt_lshift_toggle

    The toggle survived and the second layout did not, so something applied a
    layout after X had read its configuration. Under XFCE that is
    xfsettingsd, which takes the setting from its own xfconf channel once it
    owns it rather than from /etc/default/keyboard. The panel indicator
    agreed: "EN", with nothing to switch to.

    Now stated at that layer as well, in
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml with
    XkbUseSystemDefaults false, so there is no question about which copy wins.
    Unverified until the next install.

### R-12 — offer to encrypt the disk during installation

Status:   OPEN
Reported: "7 เปิดครับ"
Area:     ubuntu track — Calamares partition module

Problem
    Installation offers no encryption. A laptop that is lost is a laptop whose
    files are readable by whoever picks it up.

Requirement
    1. The partitioning page offers full-disk encryption with a passphrase.
    2. It is offered, not forced: off unless chosen, because a forgotten
       passphrase is unrecoverable data loss and that has to be the person's
       own decision.
    3. The passphrase field says what happens if it is lost, in whichever
       language the installer is running in.
    4. An encrypted install boots: passphrase prompt, then the system.

Verification
    Install with encryption chosen, reboot, confirm the passphrase is asked for
    and the system comes up. Confirm the swap from R-13 is inside the encrypted
    volume rather than beside it.

Notes
    That last check is the one that catches people out. Swap left outside the
    encrypted volume holds whatever was in memory, in clear, which defeats the
    point of encrypting the disk. Keeping swap as a file inside the encrypted
    root avoids it entirely.

### R-13 — swap, sized deliberately

Status:   OPEN
Reported: "8 แนะนำที่เท่าไร บอกมาเลยครับ"
Area:     ubuntu track — Calamares partition module

Problem
    Nothing decides how much swap an install gets, so it is whatever Calamares
    happens to default to. Too little and the machine dies under memory
    pressure instead of slowing down; too much and a laptop loses disk to
    something it will never touch.

Requirement
    1. Swap is a **file inside the root filesystem**, not a partition.
    2. Size: **equal to RAM, capped at 8 GB, never below 2 GB.**

       | RAM | Swap |
       |---|---|
       | 2 GB | 2 GB |
       | 4 GB | 4 GB |
       | 8 GB | 8 GB |
       | 16 GB | 8 GB |
       | 32 GB and up | 8 GB |

    3. **Hibernation is not enabled**, and the installer does not offer it.

Verification
    Install on VMs with 4 GB and with 16 GB of RAM. `swapon --show` reports a
    file of 4 GB and of 8 GB. With encryption chosen, the file is inside the
    encrypted root.

Notes
    Why a file rather than a partition: it can be resized later with two
    commands, it needs no decision about partition layout at install time, and
    under encryption it is covered by the same LUKS volume as everything else.
    A partition has none of those properties and, on a current kernel, no
    remaining advantage.

    Why capped at 8 GB: swap on a desktop absorbs pressure, it is not meant to
    be used continuously. A machine with 32 GB of RAM that is genuinely using
    32 GB of swap stopped being usable long before it filled.

    Why no hibernation: it needs swap at least the size of RAM, which breaks
    the cap, and resuming from an encrypted swap file is fragile — it works
    until a kernel update and then the session appears to have been lost.
    Suspend to RAM covers what most people actually want from it. Worth
    revisiting later as a deliberate feature, not shipped as an untested
    default.

    **Verified 2026-09-23.** On the installed system:

        $ swapon --show
        NAME       TYPE  SIZE USED PRIO
        /swapfile  file    4G   0B   -1
        $ free -h | grep Mem
        Mem:  3.8Gi

    3.8 GiB of RAM rounds to 4 GB; the 8 GB cap and the quarter-of-the-disk
    cap (29.5 GB / 4 = 7.3 GB) are both above that, and the 2 GB floor is
    below it. So 4 GB is the rule applied correctly rather than a number that
    happens to look reasonable.

### R-14 — a firewall, and switched on

Status:   OPEN
Reported: "10 ใส่เลยครับ"
Area:     ubuntu track — package lists, `scripts/inside-chroot.sh`

Problem
    There is no firewall. Ubuntu ships `ufw` but leaves it inactive, so the
    default is that anything listening is reachable from whatever network the
    machine is on, including the ones in cafes and hotels.

Requirement
    1. `ufw` installed and **enabled**: deny incoming, allow outgoing.
    2. `gufw` for a graphical way to change it.
    3. Printer discovery still works. mDNS has to be allowed explicitly.

Verification
    On an installed system, `ufw status verbose` shows active and deny
    incoming. A network printer is still discovered. A port scan from another
    machine finds nothing open.

Notes
    Point 3 is the trade-off this requirement exists to get right. Enabling
    deny-incoming without allowing mDNS on UDP 5353 silently breaks the
    printing that R-04 puts on the disc as essential — and breaks it in a way
    that looks like a printer fault rather than a firewall rule.

    **Verified 2026-09-23.** `ufw status` on the installed system reports
    "Status: active". It also reported the world-writable /usr that became
    R-25, which is the second time a check has been worth more than the thing
    it was checking.

### R-15 — the way to start the installer has to be obvious and has to work

Status:   OPEN
Reported: observed while verifying R-01
Area:     ubuntu track — `scripts/inside-chroot.sh`, XFCE and plank defaults

Problem
    The launcher on the live desktop shows as the literal filename
    "mp-install.desktop" with a broken-image icon, and does nothing useful when
    clicked. Thunar will not treat a .desktop file on the desktop as a launcher
    unless it is both executable and recorded as trusted in per-user GIO
    metadata — and per-user metadata cannot be seeded from /etc/skel, because it
    does not live in the home directory.

    On a live disc, starting the installer is the main thing anyone is there to
    do. Presenting it as a broken file is worse than not presenting it.

Requirement
    1. The installer can be started from the live desktop without knowing
       anything, in at most two clicks.
    2. Whatever is shown carries the product name and its icon — never a
       filename, never a broken image.
    3. It works for the live user as created by casper at boot, not only for an
       account someone set up by hand.

Verification
    Boot the ISO and screenshot the desktop: the installer is visible and
    named. Launch it from that screenshot path and reach the welcome page.

Notes
    The desktop-icon route is the one that does not work. Better candidates,
    in order of how little can go wrong: a launcher pinned to the plank dock
    that R-03 is adding anyway, the applications menu entry that already
    exists, or an autostarted window on first login.

    An earlier attempt at the GIO metadata call was removed from
    inside-chroot.sh on the grounds that it did not do what its comment
    claimed. The call was wrong, but the underlying mechanism it was reaching
    for is real — Thunar does check that metadata. It is still the wrong fix
    here, because the metadata is per-user.

    **Update 2026-09-22.** Reported again, worse: *"ไม่มีไอคอนให้ติดตั้ง
    Linux ขึ้นมาครับ"* — there was no icon to start the installer at all.

    The desktop icon was removed on the reasoning that the "untrusted
    launcher" prompt came from per-user GIO metadata that /etc/skel cannot
    seed. That is true of Thunar, which draws folder windows. It is not true
    of xfdesktop, which draws the desktop, and which runs a .desktop file
    without asking if and only if the file is executable. It was mode 0644.
    Ubuntu's own live discs ship their installer launcher 0755 for exactly
    this reason.

    So the diagnosis was wrong and the fix removed the only thing that was
    working. The icon is back at mode 0755, the dock item stays, and the
    applications menu entry stays — three ways in, so this cannot come down
    to any one of them behaving unexpectedly.

### R-16 — the network has to work

Status:   OPEN
Reported: "ทดสอบคร่าวๆ ยังไม่สามารถเชื่อมต่อกับ network adaptor ได้ครับ"
Area:     ubuntu track — `scripts/inside-chroot.sh`

Problem
    No network. The adapter is present and NetworkManager is installed,
    enabled and running — it simply is not managing anything.

    `/etc/netplan/` is empty. On Ubuntu, netplan is what assigns interfaces to
    a backend; with no configuration at all, nothing is handed to
    NetworkManager and nothing is handed to systemd-networkd either, so the
    interface sits there unclaimed. Ubuntu images ship a one-line file that
    does this and it was never created, because debootstrap does not and
    nothing in this build did it afterwards.

    This is worse than it first looks. Without a network:
      - the optional package groups from R-04 cannot be fetched, so the
        installer silently offers choices it cannot honour
      - updates (R-07) never appear
      - the welcome page requirement check reports no internet, which is
        correct and looks like the machine is offline rather than misbuilt

Requirement
    1. A wired connection comes up by itself, in the live session and after
       installing, with no configuration by hand.
    2. Wi-Fi appears in the network menu on hardware that has it.
    3. One backend manages the interfaces, not two arguing over them.

Verification
    Boot the ISO in a VM with NAT networking: `ip addr` shows an address,
    `ping -c1 archive.ubuntu.com` succeeds, and the panel shows a connection.
    Then install, reboot, and check the same three things on the installed
    system.

Notes
    The fix is `/etc/netplan/01-network-manager-all.yaml` with
    `renderer: NetworkManager`, at mode 0600 — netplan warns about
    world-readable configuration and will keep warning until it is fixed.

    Worth checking at the same time that systemd-networkd is not also enabled
    and trying to claim the same interface. Both running is a configuration
    that works until it does not, and then does so intermittently.

    **Verified 2026-09-23 on an installed system.** Previously only the live
    session had been checked.

        $ ip -4 addr show
        inet 10.0.2.15/24 ... enp0s2
        $ getent hosts archive.ubuntu.com
        2a06:bc80:0:1000::18 archive.ubuntu.com

    Address from DHCP, names resolving, on a system installed to disk.

### R-17 — the stated minimum disk size has to be the real one

Status:   OPEN
Reported: "การติดตั้งขึ้นพื้นที่ไม่พอครับ ผมต้องปรับพื้นที่ก่อนครับ"
Area:     ubuntu track — `calamares/modules/welcome.conf`, partitioning

Problem
    The installer refuses to proceed for want of space. The welcome page says
    15 GB is enough, and 15 GB is not enough, which is the worse half of the
    problem: a number that is wrong in the optimistic direction sends people
    away to resize a disk and come back to the same refusal.

    Where 15 came from: roughly the unpacked system, and nothing else. What
    actually has to fit:

    | | |
    |---|---|
    | unpacked system | about 5 GB |
    | swap file (R-13) | equal to RAM, up to 8 GB |
    | EFI system partition | 512 MB |
    | somewhere to put files | not nothing |

    On a machine with 16 GB of RAM the swap file alone is 8 GB, so the true
    floor is over 15 before the person has saved a single document. The two
    requirements were written separately and never added up.

Requirement
    1. The minimum the installer states is one an install actually fits in,
       including the swap file, on a machine with a lot of RAM.
    2. If the disk is too small, say so with the number that is needed and the
       number that is there — not "not enough space".
    3. The figure is derived from the parts, not guessed, and the derivation
       is written down where the number is set.

Verification
    Install on a disk exactly at the stated minimum, on a VM with 16 GB of RAM
    so the swap file is at its cap. It completes, boots, and has free space.
    Then try one gigabyte under it and confirm the refusal names both numbers.

Notes
    Worth reconsidering the swap cap at the same time. 8 GB of swap on a
    16 GB machine is defensible on a desktop with a large disk and absurd on a
    32 GB SSD in a small laptop. Sizing swap against the disk as well as
    against RAM would keep both honest.

### R-18 — shutting down has to finish

Status:   OPEN
Reported: "ส่วนตอน shutdown เครื่องไม่ปิดครับ"
Area:     ubuntu track — `grub/grub.cfg`, casper

Problem
    Shutting down does not complete; the machine sits there instead of
    powering off.

    An earlier boot log shows where it is likely stuck:

        [FAILED] Failed unmounting cdrom.mount - /cdrom.
        Starting casper.service - Shuts down the "live" preinstalled system...

    casper ejects the medium on shutdown and then waits for somebody to press
    Enter to confirm they have removed it. In a virtual machine nobody is going
    to, and on a serial console the prompt may not even be visible, so it waits
    indefinitely and looks like a hang.

Requirement
    1. Shutting down the live session powers the machine off without anyone
       having to press anything.
    2. On real hardware, whatever tells a person to take the USB stick out is
       still worth keeping — it stops a machine booting the installer again.
       A prompt nobody sees is not that; a message that does not block is.
    3. The installed system, which has no medium to eject, shuts down
       cleanly too. Worth checking separately: it is a different path.

Verification
    Over the serial console, log in and run `poweroff`. QEMU exits by itself
    within a reasonable time. Repeat on the installed system.

Notes
    casper takes `noprompt` on the kernel command line, which skips the wait.
    The trade-off is point 2, and it is a real one rather than a formality:
    a machine left with the stick in reboots into the installer, and somebody
    who has just installed an operating system does not necessarily expect
    that.

### R-19 — the installer has to be able to install

Status:   OPEN
Reported: screenshot — "Failed to unpack image /cdrom/casper/filesystem.squashfs"
          / "rsync failed with error code 127"
Area:     ubuntu track — `config/packages-base.list`

Problem
    Installation fails at the point where the system is copied onto the disk.
    Exit code 127 is the shell saying the command does not exist: `rsync` is
    not installed, and Calamares copies the unpacked squashfs with it.

    The same check turned up `lvm2` and `kpartx` missing, which the
    partitioning module reaches for on some layouts.

    This got as far as a person trying it because none of the earlier
    verification installed anything. Booting the live session proves the disc
    works; it says nothing at all about whether the installer does.

Requirement
    1. An install completes from the ISO with no network, onto an empty disk.
    2. Everything Calamares shells out to is present on the disc: rsync,
       lvm2, kpartx, cryptsetup, the filesystem tools.
    3. A completed install boots without the disc.

Verification
    Install to a virtual disk and boot the result. Not a screenshot of the
    live session — the actual install, the actual reboot.

### R-20 — the software selection page has to show the software

Status:   OPEN
Reported: screenshot — the desktop chooser is empty, headings and nothing else
Area:     ubuntu track — `calamares/netinstall-desktops.yaml`

Problem
    The page from R-04 draws its two column headings and no rows. The file it
    reads is present, valid YAML, and describes three groups.

    Calamares 3.3 expects the list under a top-level `groups` key. A bare list
    is the 3.2 format. 3.3 reads the file, does not find `groups`, and shows an
    empty page rather than an error — so it looks like a missing file instead
    of a misshapen one.

Requirement
    1. Every group and subgroup is listed, with its description and size.
    2. The Thai text appears when the installer is running in Thai.
    3. Ticking a group installs it; ticking none still gives a working system.

Verification
    Screenshot the page: three groups, ten subgroups, sizes visible. Then
    complete an install with one optional group ticked and confirm it is
    present afterwards.

Notes
    Whether 3.3 honours `name[th]` for these strings is still unproven. If the
    page comes up in English once the groups appear, that is the next thing to
    look at, and it is a smaller problem than an empty page.

---

    **Update 2026-09-22.** Still not shown — reported as *"ยังไม่มีตัวเลือก
    Desktop environment"*. Moving the list under a top-level `groups:` key was
    necessary and not sufficient: the key that points *at* the file does not
    exist in this build either.

        $ grep -c groupsFilePath libcalamares_viewmodule_netinstall.so  -> 0
        $ grep -c groupsUrl      libcalamares_viewmodule_netinstall.so  -> 0
        $ grep -c groups         libcalamares_viewmodule_netinstall.so  -> 1

    3.3.14 takes a single key, `groups`, holding either the list itself or a
    URL to fetch one from. `groupsFilePath` was a 3.2 spelling and was being
    ignored, so the module had no groups at all.

    The list is now written directly into netinstall.conf rather than loaded
    from netinstall-desktops.yaml, which has been deleted. There is nothing to
    find, nothing to fetch and nothing to time out, so the page can no longer
    fail for a reason unrelated to the page.

    **Sizes corrected 2026-09-22.** Rule 2 of that file says every group
    states what it costs. The figures were guesses and were wrong by between
    four and thirty times, in both directions. Measured with
    `apt-get install -s` against the built chroot, summing the Size field of
    everything apt said it would fetch:

        group          was        is
        GNOME          1.2 GB     10 MB    (already on the disc -- R-22)
        KDE Plasma     900 MB     330 MB
        Office         700 MB     290 MB
        Graphics       550 MB     70 MB
        Development    400 MB     75 MB
        Backup         50 MB      5 MB
        Remote access  80 MB      2 MB

    All 24 packages named on the page were also checked for an install
    candidate with `apt-cache policy` -- the method that catches a package
    with no candidate, which `apt-cache show` does not.

    **Actually fixed 2026-09-23, on the third attempt.** Moving the list under
    a `groups` key was necessary; inlining it into netinstall.conf was
    necessary; neither was sufficient. The list is read through `groupsUrl`,
    and the value "local" is what says "the list is in this file":

        SourceItem SourceItem::makeSourceItem( const QString& groupsUrl, ... )
        {
            if ( groupsUrl == QStringLiteral( "local" ) )
                return SourceItem { QUrl(), configurationMap.value( "groups" ).toList() };
            ...
        }

    With no groupsUrl at all the queue is empty, and the module reports that
    in a line that reads like success:

        Loading netinstall from 0 alternate sources.
        ViewModule "netinstall@netinstall" loading complete.

    Nothing warns and nothing fails. The page's title and sidebar label come
    from a different part of the config, so they were correct throughout,
    which is what made it look like the list was being read and rejected.

    The method that produced the first two wrong answers was grepping the
    compiled module for key names. It reported that `groupsUrl` does not
    exist in this build. It does. Reading that version's own source settled in
    one minute what three builds had not.

    Verified on screen: three groups, ten subgroups, with the measured sizes.

### R-21 — the target system has to be mounted properly before anything runs in it

Status:   WIP
Reported: "ภาพที่สองคือ error ที่ระบบตอบกลับมาตอนติดตั้งไม่ผ่านครับ"
Area:     ubuntu/calamares/modules/mount.conf (new)

Problem
    The install runs to about 25%, unpacks the filesystem, and then stops with
    a dialog:

        Command update-initramfs finished with exit code 1.
        update-initramfs: Generating /boot/initrd.img-7.0.0-31-generic
        /usr/sbin/mkinitramfs: 195: cannot create /dev/null: Permission denied
        W: No zstd in /usr/bin:/sbin:/bin, using gzip
        /usr/sbin/mkinitramfs: 412: cannot create /dev/null: Permission denied
        E: no ldd around - install libc-bin
        update-initramfs: failed for /boot/initrd.img-7.0.0-31-generic with 1.

    Three of those four lines are misdirection. libc-bin is installed and
    /usr/bin/ldd is in the image; zstd is installed and /usr/bin/zstd is in
    the image. Both are found by scripts that test with

        command -v ldd >/dev/null

    and when the redirect to /dev/null cannot be opened the test fails, so the
    tool is reported missing. There is exactly one fault: the target has no
    /dev.

    Calamares mounts the root filesystem and then mounts whatever
    mount.conf lists. There was no mount.conf. The module does not carry a
    default list and says so itself:

        extra_mounts = libcalamares.job.configuration.get("extraMounts") or []
        if not extra_mounts:
            warning("No extra mounts defined. Does mount.conf exist?")
                        -- usr/lib/x86_64-linux-gnu/calamares/modules/mount/main.py

    So every step that runs inside the target — update-initramfs, grub-probe,
    efibootmgr, and apt for anything picked on the software page — was running
    in a chroot with no /dev, no /proc and no /sys. update-initramfs is simply
    the first one to be reached.

Requirement
    1. mount.conf exists and mounts /proc, /sys, /dev, /run and /run/udev
       into the target.
    2. /dev is bound recursively, so /dev/pts and /dev/shm come with it —
       debconf and apt need a pty in the target.
    3. efivarfs is mounted at /sys/firmware/efi/efivars on EFI machines and
       not on BIOS ones. Without it efibootmgr writes the bootloader to disk
       and then cannot register it, which produces an install that reports
       success and boots to nothing. This is the same fault R-06 is about.
    4. update-initramfs finishes, and the generated initrd is zstd, not the
       gzip fallback — that is the check that /dev really is there rather
       than merely present.

Verification
    An install to a blank virtual disk that reaches the "installation
    finished" page. Then, on the installed system:
      - `/boot/initrd.img-*` exists,
      - `file` reports it as Zstandard, not gzip,
      - on EFI, `efibootmgr` lists a "Master Penguin" entry.

Notes
    This is why R-19 never got past its first point, and why nothing in R-06,
    R-12, R-13 or R-15's third point has been verifiable: no install has ever
    completed, so there has never been an installed system to look at.

### R-22 — the desktop on the disc has to be the desktop that runs

Status:   WIP
Reported: Found while checking R-15 in a VM, not reported directly.
Area:     ubuntu/scripts/inside-chroot.sh

Problem
    The live disc boots into GNOME. Not XFCE with GNOME pieces attached --
    GNOME:

        $ echo $XDG_CURRENT_DESKTOP
        ubuntu:GNOME
        $ ps -e -o comm= | grep -E "shell|session"
        gdm-session-worker
        gnome-session-binary
        gnome-shell

    XFCE is installed and configured and has never run. Everything aimed at
    it has been inert from the first ISO: the panel layout, the plank dock
    seeded into /etc/skel, the launcher permissions R-15 turned on, and the
    whole of R-03. The dock down the left of the screen is GNOME's. The
    "untrusted launcher" badge on the installer icon is GNOME's, which is why
    making the file executable changed nothing -- xfdesktop, which that rule
    is about, was not running.

    How it gets there: update-manager, update-notifier and
    network-manager-gnome each have a dependency written as an alternation
    beginning with gnome-shell --

        Depends: gnome-shell | notification-daemon
        Depends: gnome-shell | policykit-1-gnome | polkit-kde-agent-1 | ...

    -- and apt takes the first alternative when none is installed yet.
    gnome-shell pulls ubuntu-session, which pulls gdm3. gdm3's postinst then
    writes /etc/X11/default-display-manager and claims the
    display-manager.service symlink. The build's `systemctl enable lightdm`
    does not take either back: enable creates that symlink only when nothing
    already owns it, so it succeeded and changed nothing.

Requirement
    1. The live session is XFCE, under LightDM.
    2. gdm3 is not on the disc. Purged, not disabled -- an installed gdm3
       keeps a postinst that can reclaim the symlink on any later upgrade.
    3. Nothing else is lost to the purge. Checked before doing it:

           apt-get purge -s gdm3        -> 1 package
           apt-get purge -s gnome-shell -> 10, including update-manager and
                                           network-manager-gnome

       so gnome-shell stays. It is dead weight on a disc whose session is
       XFCE, and it is still cheaper than losing the update UI (R-07) and
       the network applet (R-16).

Verification
    On the live disc: `echo $XDG_CURRENT_DESKTOP` says XFCE, `pgrep xfdesktop`
    and `pgrep plank` both return a pid, and the installer icon on the desktop
    runs on the first double-click.

Notes
    This also makes the GNOME option on the software page nearly free, since
    gnome-shell is already there -- which is how the sizes on that page came
    to be re-measured (R-20).

    Left open deliberately: gnome-shell and its ~60 dependent packages are
    still on the disc. They could be removed by installing the *later*
    alternatives (notification-daemon, policykit-1-gnome) before the packages
    that would otherwise pull gnome-shell in, so apt finds the alternation
    already satisfied. That is a real saving and a real risk to the update UI,
    and it is not what any of the reported problems were about.

### R-23 — "erase disk" has to create a disk to install on

Status:   WIP
Reported: Found by installing to a blank virtual disk, which had never been done.
Area:     ubuntu/calamares/modules/partition.conf

Problem
    With R-21 fixed the install got past the mount stage and failed at the
    next one, with a message that describes a symptom:

        Failed to unpack image "/cdrom/casper/filesystem.squashfs"
        rsync failed with error code 11.

    Code 11 is an I/O error. The cause was that there was nowhere to write.
    "Erase disk" built a GPT table, created the EFI partition, and stopped --
    the job list goes straight from partitioning to mount:

        Starting job "Creating new gpt partition table on /dev/vda"    ( 4 / 32 )
        Starting job "Create new 512MiB partition ... with entries EFI" ( 5 / 32 )
        Starting job "Set flags on partition /dev/vda1"                ( 6 / 32 )
        Starting job "mount"                                           ( 9 / 32 )
        Starting job "unpackfs"                                       ( 10 / 32 )

    and afterwards the disk agreed:

        vda    30G  disk
        └─vda1 512M part /tmp/calamares-root-1iselbvw/boot/efi

    No root partition was ever created, so the install target was an ordinary
    directory in the live system's tmpfs. rsync wrote 4.7 GB of image into RAM
    until it ran out.

    The summary page had said so, and it was read as if it had not: it listed
    four actions, every one of them about the EFI partition, and the disk
    preview said "พื้นที่ว่าง 29.50 GiB". Free space, not a filesystem.

Requirement
    1. partition.conf states the layout rather than relying on the default.
       The documentation says an absent partitionLayout means "a single
       partition for root that uses 100% of the space". That is not what this
       build did, and four explicit lines cannot be misread.
    2. The EFI settings use the "efi:" block. efiSystemPartition and
       efiSystemPartitionSize are the 3.2 spellings -- the third time this
       version's renamed keys have cost a build, after sidebarBackground in
       the branding and groupsFilePath in netinstall.
    3. The ESP is 512 MiB, not the 300 MiB default: a kernel and initrd are
       about 110 MB together here, and an ESP that cannot hold two of them
       turns the first kernel update into an unbootable machine.
    4. "Erase disk" is pre-selected, rather than two empty radio buttons with
       a greyed-out Next button and nothing saying why.

Verification
    The summary page must name the root partition before anything is written:

        Create new 30205MiB partition on /dev/vda (vda) with entries mp-root
        Install Master Penguin on new ext4 system partition

    Then the install has to finish, and `lsblk` on the installed system has to
    show a mounted ext4 root.

Notes
    Every requirement in this file that depends on an installed system --
    R-06, R-12, R-13, R-01 point 3, R-19 point 3 -- was unverifiable until
    this was found, because no install had ever produced a filesystem.

### R-24 — the live session must not lock a user out of it

Status:   OPEN
Reported: Found when the installer disappeared behind a lock screen mid-test.
Area:     ubuntu/scripts/inside-chroot.sh

Problem
    The live session blanks and then locks. The live user has no password, so
    the lock screen asks for something that does not exist:

        master-penguin
        [ Master Penguin Live ]  [ ปลดล็อค ]

    An empty password happened to be accepted here, which is its own problem
    -- a lock that anyone can open is not a lock, and a lock that cannot be
    opened would be worse. Neither is what should happen on a live disc, and
    it also hides a running installer behind a dialog that looks like a
    failure.

    Ubuntu's own live sessions disable screen locking for exactly this reason.

Requirement
    1. No screen lock in the live session: xfce4-screensaver's lock is off
       and DPMS blanking is off, for the live user only.
    2. The installed system keeps both, on the normal defaults. This is a
       live-session setting, not a system-wide one -- a laptop that never
       locks is a worse fault than the one being fixed.

Verification
    Boot the disc, leave it alone for ten minutes, and find the desktop still
    there and unlocked. Install, reboot, and find that the installed system
    does lock.

### R-25 — nothing in the image may be world-writable

Status:   WIP
Reported: Found by running `ufw status` on the installed system, which said so
          in passing.
Area:     ubuntu/scripts/inside-chroot.sh

Problem
    On the installed system:

        WARN: uid is 0 but "/" is owned by 1000
        WARN: uid is 0 but "/usr" is owned by 1000
        WARN: /usr is world writable!
        WARN: /usr is group writable!

    and in the chroot the image is built from:

        drwxrwxrwx golf:golf  /
        drwxrwxrwx golf:golf  /usr
        drwxrwxrwx golf:golf  /usr/local
        drwxrwxrwx golf:golf  /usr/local/sbin

    A world-writable /usr means any account on the machine can replace any
    binary in it, and the next thing run as root runs somebody else's code.
    On a single-user laptop it is latent; on a shared machine it is a root
    escalation that needs no exploit.

    The cause is one flag. The overlay tree is on an NTFS volume mounted into
    WSL, where every file reads back as 0777 owned by the build user, and the
    copy was

        cp -a /tmp/overlay/. /

    cp -a preserves ownership and mode, and applies them to each destination
    directory it walks through -- so "/", "/usr", "/usr/local" and
    "/usr/local/sbin" all took the attributes of a directory on a Windows
    filesystem. The path is exactly the one the overlay's only two files sit
    at, which is why those four and nothing else.

    The same fault had already been found and fixed once, for
    /etc/calamares, and fixed only there. That was the tell and it was
    missed: if cp -a from this tree damaged one destination it damaged every
    destination.

Requirement
    1. The overlay is copied with cp -r, which does not carry the source's
       ownership or mode onto directories that already exist.
    2. What the overlay ships is chowned and chmoded explicitly rather than
       inherited.
    3. The directories an earlier build already damaged are repaired, because
       stage 20 runs against an existing chroot.
    4. The build fails if any world-writable directory without the sticky bit
       exists in the image. /tmp and /var/tmp are the legitimate cases and
       have the sticky bit; everything else is a mistake, and a check is the
       only thing that stops this class of fault coming back a third time.

Verification
    `find / -xdev -type d -perm -0002 ! -perm -1000` returns nothing, in the
    chroot and on an installed system. The build stops on its own if it does
    not.

## Deferred

### D-01 — checksums and release artifacts

Reported: "9. รอทำทีเดียวตอนปล่อย release ครับ"

    For when a release is made rather than a build: publish `SHA256SUMS`
    alongside the ISO, settle a version scheme, and decide whether the sums are
    signed. An unsigned checksum file sitting next to the image it describes
    proves only that the download finished.

---

## Done

### R-01 — the live disc must not ask anyone to log in

Status:   DONE
Reported: "หน้าติดตั้ง มีการให้ใส่ login เลย ซึ่งปรกติไม่ควรจะให้มีครับ
          จนกว่าเราจะเริ่มติดตั้งจริงบนเครื่อง"
Area:     ubuntu track — `scripts/inside-chroot.sh`, `calamares/modules/shellprocess-mp.conf`

Problem
    Booting the ISO stops at a LightDM greeter asking for a username and a
    password. There is no account to give it: nothing has been installed yet.
    The disc is unusable at that point — a person cannot try the system, and
    cannot reach the installer either.

    An account belongs to an installed system. The only place it should ever
    be asked for is the installer's own user page, which is where it gets
    created.

Requirement
    1. Booting the ISO reaches the XFCE desktop directly. No greeter, no
       username field, no user to click, no password.
    2. The account is created in one place only: the installer.
    3. The installed system does ask for a login at boot, with the account
       made during installation. Whatever makes the live disc skip the
       greeter must not survive onto the installed disk.

    Point 3 is not incidental. "Disable the login screen" would satisfy the
    complaint and leave every installed machine logging in unprompted.

Verification
    1. Boot the ISO headless in VirtualBox on EFI firmware, screenshot after
       roughly two minutes: a desktop, no greeter.
    2. Install to a virtual disk, boot the result: a greeter, asking for the
       account created during the install.

Notes
    Cause is known. casper does configure autologin, but writes it into a
    `[SeatDefaults]` section — LightDM syntax from before 1.12. Current
    LightDM ignores that section entirely, so the settings are written and
    have no effect. Ubuntu proper does not hit this because it uses GDM.

    A fix is already written into `inside-chroot.sh`: the same settings under
    `[Seat:*]`, plus an `/etc/casper.conf` naming the live user `mplive`.
    `shellprocess-mp.conf` removes both during installation, which is what
    point 3 depends on. None of it is verified — the build that would have
    produced an ISO from the fixed tree was interrupted at the last stage when
    the machine ran out of memory.

    Supersedes the R-00 placeholder this file was created with.

    **Verified 2026-09-21.** The ISO boots to an XFCE desktop with no greeter,
    under both BIOS (QEMU) and EFI (VirtualBox). Point 3, that an installed
    system still asks, is implemented in mp-finish-install but not yet proven —
    nothing has been installed to a disk yet.

    What actually caused it, which was none of the things first suspected:

    `mksquashfs -e run` drops the *directory*, not its contents. The image had
    no /run, /proc or /sys at all. casper could not mount them, `adduser` could
    not take its lock at /run/adduser, the live user was never created, and the
    autologin pointed at an account that did not exist — so LightDM fell back to
    asking for a username. The LightDM `[SeatDefaults]` problem was real and
    fixed, but it was not what was stopping this.

    Two other faults surfaced from the same investigation:
      - The BIOS boot path did not work at all. `grub-mkstandalone` puts its
        modules in a memdisk, which does not survive being wrapped as an El
        Torito image; GRUB dropped to a rescue prompt. Now built with
        `grub-mkimage --format=i386-pc-eltorito`. EFI had been working, which
        is why this went unseen.
      - `boot/vmlinuz-*` and `boot/initrd.img-*` were also excluded from the
        squashfs. An install would have completed and then had no kernel in
        /boot to boot from. Not yet triggered, because nothing had been
        installed yet.



---

## Current state, for context

| | |
|---|---|
| Base | Ubuntu 26.04 LTS (`resolute`), amd64 |
| Desktop on the disc | XFCE; GNOME and KDE offered as downloads by the installer |
| Installer | Calamares, creating the first user during install |
| Packaging | apt, snap, flatpak — all three, with gnome-software over the top |
| Browser, mail | Firefox and Thunderbird as real debs from Mozilla, not snaps |
| Thai | fonts, `ibus-libthai`, language packs |
| Last ISO built | 2.1 GB, boots under EFI, stops at a login prompt (R-00) |
| Build | `sudo ubuntu/build.sh [stage...]`, output in `/var/tmp/mp-ubuntu/out` |
