# What this project changes, and why

Everything not listed here comes unmodified from Ubuntu's archive, and
Firefox from Mozilla's. Every change to a package, every patch and every
workaround has a line here.

## Packages we build

Built by `packaging/build-all.sh` from `packaging/packages.conf`. Versions
carry the suffix `-0mwd<revision>` (`packaging/revision`).

| Package | Ubuntu 26.04 has | We build | What is different from Ubuntu's build |
|---|---|---|---|
| mate-desktop | 1.28.2 | 1.29.1 | Newer upstream release only. Required by mate-panel 1.29. |
| mate-panel | 1.27.1 | 1.29.2 | Newer release; `--enable-wayland`, all applets in-process (Ubuntu builds them as separate programs, which cannot work on Wayland); one code patch. |
| caja | 1.26.4 | 1.29.1 | Newer upstream release only. Draws the desktop on Wayland. |
| mate-media | 1.26.2 | 1.29.0 | Newer release; `--enable-wayland`, volume applet in-process. |
| mate-settings-daemon | 1.26.1 | 1.29.1 | Newer upstream release only. Runs natively on Wayland; 1.26 crashes. |
| marco | 1.26.2 | 1.29.1 | Newer upstream release only. Only its library is used (mate-control-center 1.29 requires it); labwc stays the window manager. |
| mate-control-center | 1.26.1 | 1.29.1 | Newer release: Appearance, Display and the main window open on Wayland (1.26 crashes). Extra build dependencies; packages for two libraries upstream dropped are removed; Keyboard, Mouse and Keyboard Shortcuts are started through XWayland because they still crash natively; the Displays entry opens wdisplays. |
| mate-applets | 1.26.1 | 1.28.1 | Newer release, built with `--enable-in-process` so its applets (Battery, System Monitor, Weather and others) load on Wayland. |
| mate-wayland-desktop | (ours) | 0.1 | Session entry and start script, Log Out helper, labwc configuration, panel layout, default settings. Built by `packaging/build-session-deb.sh`. |

For all eight MATE packages the build takes Ubuntu's packaging (`debian/`),
swaps in the newer upstream tarball, drops Ubuntu's patches and symbol
files (written for the old version), then applies
`packaging/<name>/adjust.sh` and `packaging/<name>/patches/`.

### Code patches

| Patch | Package | What it does | Upstream |
|---|---|---|---|
| `tray-left-click-menu.patch` | mate-panel | Left click opens the menu of tray icons that only provide a menu (for example the network icon). | To be submitted. |
| `tray-pixmap-icon-scale.patch` | mate-panel | Tray icons that a program sends as an image (rather than as an icon name) are drawn at the screen's real resolution on a scaled screen. The panel reduced them to the logical size and the screen then enlarged that, so they were blurry at any scale above 1. | To be submitted. |
| `volume-popup-position-wayland.patch` | mate-media | The volume slider opens under the volume icon on every monitor. On Wayland it was placed using the monitor's position in the whole layout, so with several monitors it opened at the screen's left edge or part-way along. | To be submitted. |
| `volume-popup-close-outside-wayland.patch` | mate-media | A click anywhere outside the volume slider closes it. On Wayland the slider is a layer-shell surface, which receives no clicks outside itself, so it stayed open until its icon was clicked again. While the slider is open an invisible surface covers each monitor and closes the slider when clicked. | To be submitted. |
| `volume-scroll-feedback.patch` | mate-media | Turning the mouse wheel over the volume icon shows the volume in a notification (the one the volume keys show: icon, percentage and level bar, replaced in place) and plays the sound the slider plays. The volume changed with nothing to show or tell what it now was. | Ours: it uses the session's notification. |
| `volume-scroll-touchpad.patch` | mate-media | Two-finger scrolling on a touchpad over the volume icon changes the volume, as a mouse wheel does | The icon asked only for wheel clicks. On Wayland a touchpad sends smooth scroll events, a stream of small distances with no clicks, which the icon never received. It now receives them, adds the distances up and makes one volume step for each whole unit; a wheel that sends both kinds is counted once. |

## Session (the `mate-wayland-desktop` package)

| What | Where | Why |
|---|---|---|
| labwc replaces Marco | `session/`, `labwc/` | Marco is X11-only. |
| Software-rendering fallback | `session/mate-wayland-desktop-session` | labwc will not start on a display without 3D acceleration unless told to. |
| Keyboard layout from `/etc/default/keyboard` passed to labwc as `XKB_DEFAULT_*` | `session/mate-wayland-desktop-session` | On Wayland the compositor owns the keyboard; without this the installer's layout choice is ignored. Same approach as Xfce's Wayland session. |
| Log Out helper owning `org.gnome.SessionManager` | `session/mate-wayland-desktop-logout` | The panel's Log Out expects mate-session-manager, which we do not run. |
| mate-settings-daemon started natively, XWayland as fallback | `labwc/autostart` | 1.29 works as a Wayland client; older versions crash. |
| Menta theme and Noto Sans font as defaults, set in both MATE's and GNOME's interface settings | `panel/90_mate-wayland-desktop.gschema.override` | Wayland GTK applications read `org.gnome.desktop.interface`. Without a set font they fell back to DejaVu Sans, which is wide and made menus look stretched. |
| MATE appearance changes copied to GNOME's interface settings | `session/mate-wayland-desktop-settings` | So the Appearance dialog works for Wayland applications. |
| `nm-applet --indicator` | `labwc/autostart` | The tray shows only indicator-style icons on Wayland. |
| Own panel icons for Blueman: idle, connected, switched off | `icons/status/`, `session/mate-wayland-desktop-icons` | Blueman's "connected" icon fell back to its coloured blue tile, which does not match the flat panel icons. Yaru has no plain Bluetooth symbol, so these three are drawn here. |
| `blueman-applet` started with the session | `labwc/autostart` | The session starts only what this file lists (no XDG autostart), so Blueman's icon would not appear otherwise. |
| No idle lock in the live session | `labwc/autostart` | There is no password to unlock with when booted from the ISO. |
| gtklock + swayidle for screen lock | `labwc/autostart`, `labwc/rc.xml` | mate-screensaver is X11-only. |
| wdisplays + kanshi for displays | `labwc/rc.xml`, `labwc/autostart` | MATE's own tool is X11-only. |
| Screenshots: Print selects an area, Shift+Print takes the whole desktop, both open in satty to annotate and copy; Ctrl+Print saves the whole desktop to Pictures at once | `session/mate-wayland-desktop-screenshot`, `labwc/rc.xml`, `packaging/build-session-deb.sh` | MATE's screenshot tool is X11-only. grim and slurp take the picture because they work across several screens at different scales; satty is the native-Wayland editor (arrows, text, numbered steps, boxes, highlight, blur, pixelate). The area and screen captures are piped straight into satty and never written to disk: Enter or the copy button puts the result on the clipboard and closes the window. satty runs with the GTK4 GL renderer, which is steady on NVIDIA where the default Vulkan renderer warns and can glitch. |
| HiDPI launcher: `hidpi-run`, `hidpi-menu` (menu entry "HiDPI Launcher") and `hidpi-desktop` run an X11 program sharp on a scaled screen | `session/hidpi/`, `packaging/build-session-deb.sh`, `iso/packages-desktop.txt` | The compositor enlarges XWayland windows as a picture, so X11 programs (Java programs and others without Wayland support) are blurry at any scale above 1, and no toolkit setting changes that. The launcher starts the program in an Xwayland of its own, running in a window at the screen's real resolution, and tells the toolkits (GTK, Qt, Java) to draw at double size, so the program is drawn with real detail. A small library preloaded into that Xwayland (`hidpi-xwl-shim.c`, compiled when the session package is built) gives the window the program's own name and application id, because Xwayland otherwise calls every such window "Xwayland on :N" and the taskbar could not show which program it is; with the name set, labwc draws its usual title bar. The launcher keeps the program's main window fitted to the outer window so both move as one, carries clipboard text both ways (xclip, wl-clipboard), and removes the window when the program closes. |
| HiDPI launcher, second way: `hidpi-run --native` runs a program as a normal Wayland window, and `hidpi-fix` chooses between the two ways and remembers the choice | `session/hidpi/`, `packaging/build-session-deb.sh` | Some programs can use Wayland but start on X11 anyway: they switch themselves to X11 when they start, or the toolkit they bundle sends window size limits in an order that wlroots compositors answer by disconnecting the program. For these, an Xwayland window of their own is a poor fit (a program that lives in the tray, for example). `--native` tells the toolkits to use Wayland only and preloads a small library (`hidpi-wl-shim.c`, compiled when the session package is built) that ignores the program's own switch to X11 and keeps its size limits valid at every step. The HiDPI Launcher now hands the chosen program to `hidpi-fix`, which starts it one way, asks whether it is sharp, tries the other way if not, and on "Yes, keep it" writes a copy of the program's menu entry (and start-at-login entry) into the user's own folders with the command going through `hidpi-run`. The program is then started from the menu as usual. Nothing of the program's own is changed, choosing the program again removes the fix, and a kept fix falls back to the ordinary command, with a notification, if the program fails to start. |
| Volume, microphone, brightness and media keys | `session/mate-wayland-desktop-keys`, `labwc/rc.xml` | On X11 mate-settings-daemon answers these keys. On Wayland only the compositor sees them, so labwc runs a helper: wpctl for sound, logind's SetBrightness for the backlight (no root or group needed), playerctl for play, pause and next. The new level is shown as a notification. |
| swaync (SwayNotificationCenter) for notifications, with the project's font and accent colour | `labwc/autostart`, `session/swaync/` | Ubuntu's mate-notification-daemon is 1.26, which is not a Wayland client and looks dated. swaync is started by the session before anything can ask D-Bus for a notification service. |
| System name "MATE Wayland Desktop": os-release, lsb-release, login prompt, welcome text, boot menu, firmware boot entry | `iso/branding/`, `iso/calamares/` | A derivative may not present itself as Ubuntu. Visible names are ours; the identifiers programs check (`ID=ubuntu`, codename) are unchanged for compatibility. The boot loader is installed in `EFI/mate`, matching what Ubuntu's boot loader packages derive from the name on updates; tested in a VM. |
| Own logo (`artwork/logo.svg`) on the menu button, the installer and the boot splash | `packaging/build-session-deb.sh`, `iso/plymouth/`, `iso/build-iso.sh` | Yaru's menu icon and Ubuntu's boot splash carry Ubuntu's logo, which a derivative may not ship. All three are produced from the one SVG. |
| Own default wallpaper, also on the login screen | `wallpapers/`, `panel/90_mate-wayland-desktop.gschema.override`, `session/lightdm-gtk-greeter.conf` | The distribution's own look. Shipped as SVG. |
| Lock screen shows the wallpaper | `session/gtklock/` | gtklock's default is a plain grey screen. |
| Panel restarted when a monitor is added or removed (workaround) | `session/mate-wayland-desktop-panel-refresh` | mate-panel 1.29.2 on Wayland redraws one pixel short after a monitor change, leaving a stray line. To be replaced by a fix in the panel, sent upstream. |
| Own icon theme: Yaru plus its flat panel icons under the names MATE's applets use | `icons/`, `session/mate-wayland-desktop-icons` | Yaru has the volume, battery and network icons only under `-symbolic` names; the applets ask for the plain names and fell back to the old Humanity set, which is also missing battery states. Generated from the installed Yaru at install time, with the grey darkened for the light panel. |
| Wallpaper on every monitor | `session/mate-wayland-desktop-wallpaper` | On Wayland, Caja's desktop covers one monitor only; the others were black with labwc's own menu. Drawn with MATE's own background renderer, so picture, placement and gradient match and follow the Appearance settings. Icons stay on the first monitor. |
| Display settings are kept, and a very dense screen starts at scale 2 | `session/mate-wayland-desktop-displays`, `labwc/autostart` | labwc starts every screen at scale 1 and remembers nothing; the Displays window (wdisplays) applies changes only until logout. On a 4K laptop screen everything was too small to read. The helper applies scale 2 to a screen of 192 dots per inch or more and at least 1200 pixels high (GNOME's rule) the first time a set of screens is seen, saves any layout that stays for ten seconds to `~/.config/mate-wayland-desktop/displays.json`, and applies it at login and when the same screens return. It stands aside for a user's own kanshi configuration and in a virtual machine. |
| Desktop follows the VM window size | `session/mate-wayland-desktop-vm-display`, `session/mate-wayland-desktop-vbox-display.service` | labwc does not switch to a new preferred size by itself, and Ubuntu's VirtualBox packages start their display helper (VBoxDRMClient) only for X11. Inactive on real hardware. |
| Font density for X11 programs fixed at 96 (`org.mate.font-rendering dpi`) | `panel/90_mate-wayland-desktop.gschema.override` | The settings daemon's automatic value is far too high on a high-density screen (311 on a 4K laptop panel), so XWayland programs that follow `Xft.dpi` drew about three times too large. The compositor scales XWayland windows itself. |
| Volume applet shows a plain volume slider: its media player controls are off by default (`org.mate.volume-control show-player-controls`), and the settings schema that holds the switch is packaged | `panel/90_mate-wayland-desktop.gschema.override`, `packaging/mate-media/adjust.sh` | mate-media 1.29 adds media player controls (track, cover picture, play and stop) to the popup that opens from the volume icon. They make the popup large, and it does not always close or open beside the icon. Ubuntu's file lists for the older version do not include the new schema, so without this change the applet had no settings and the controls could not be turned off at all. They can be switched back on in dconf. |
| Terminal default colours: grey on black | `panel/90_mate-wayland-desktop.gschema.override` | Chosen default, instead of the theme's colours. |
| Classic two-panel layout with volume control and battery; Yaru icons | `panel/` | Default look. On Wayland GTK takes the icon theme from `org.gnome.desktop.interface`. |

## ISO

| What | Where | Why |
|---|---|---|
| Minimal Ubuntu base, no GNOME, no snapd | `iso/packages-*.txt` | The distribution is this desktop only. |
| Our MATE packages held | `iso/build-iso.sh` | Keeps apt from replacing them with Ubuntu's. Until we publish a package repository, installed systems get no updates for them. |
| labwc's own session entry hidden | `iso/build-iso.sh` (dpkg-divert) | Only "MATE Wayland Desktop" should be on the login screen. |
| NetworkManager manages all network devices (netplan renderer) | `iso/build-iso.sh` | Needed for the network icon and Wi-Fi. |
| Ubuntu's login messages (help text, news) switched off; text boot splash title changed | `iso/build-iso.sh` | They name and advertise Ubuntu. |
| English (en_US) is the language of the image; the installer adds the regional formats of the region chosen | `iso/build-iso.sh`, `iso/calamares/modules/locale.conf` | Other languages can be added after installation. |
| `swaybg` installed | `iso/packages-desktop.txt`, `labwc/autostart` | Only a fallback for a Caja build without Wayland desktop support; not used with our Caja. |
| One "Displays" entry: MATE's own entry opens wdisplays, and wdisplays' own entry is hidden | `packaging/mate-control-center/adjust.sh`, `iso/build-iso.sh` (dpkg-divert) | MATE's display dialog works through X11 and shows an error on Wayland; wdisplays does the job and added a second entry with the same name. People who know MATE find Displays where it always was. |
| Calamares module settings | `iso/calamares/` | Ubuntu's calamares package ships none. |
| Calamares does not write the fallback boot loader (`installEFIFallback: false`) | `iso/calamares/modules/bootloader.conf` | Calamares copies plain GRUB to `EFI/BOOT/BOOTX64.EFI`. Ubuntu's signed GRUB has `/EFI/ubuntu` built in as its configuration folder, so with our `EFI/mate` a machine booted by choosing the disk stopped at a `grub>` prompt. Ubuntu's `grub-install` installs the shim and its fallback helper there by itself. |
| Separate unencrypted `/boot` on encrypted installs | `iso/calamares/modules/partition.conf` | Ubuntu's GRUB cannot unlock LUKS2; same layout as Ubuntu's own installer. The same `partitionLayout` block is also what creates the root partition on unencrypted installs. |
| Startup image rebuilt after `casper.conf` is installed | `iso/build-iso.sh` | The live-boot scripts read the copy inside the startup image; without this the live user and host name are defaults. |
| Installer launcher passes the Wayland environment | `iso/live/mate-wayland-desktop-install` | Ubuntu's sudo (sudo-rs) has no `-E`. |
| FFmpeg's decoding library (`libavcodec62`) | `iso/packages-desktop.txt` | Firefox decodes H.264 video and AAC sound with the system's FFmpeg. The image is installed without recommended packages and had none, so many web videos had no sound or did not play. |
| Media player: `mpv` | `iso/packages-desktop.txt` | The ISO had no program that plays video or music. mpv is Wayland-native, so it is sharp on scaled screens; VLC 3 runs through XWayland and is soft there. With no other player installed it is the default for video and audio files. |
| Bluetooth: `bluez` and `blueman` | `iso/packages-desktop.txt` | Bluetooth service and the pairing window with its panel icon; MATE has none of its own. Sound over Bluetooth is PipeWire's, already installed. Blueman pulls in `notification-daemon` as a dependency; it is never started, our notification program answers first. |
| App-indicator library and its Python binding | `iso/packages-desktop.txt` | Programs use it to put their icon in the notification area. Without the binding, Deluge and similar programs fall back to the X11-only tray and show no icon. |
| Noto Sans CJK font (`fonts-noto-cjk`) | `iso/packages-desktop.txt` | The other fonts on the ISO have no Chinese, Japanese or Korean characters, so such text, and the fullwidth punctuation that download tools put in file names in place of `:`, `?` and `\|`, showed as boxes with a number inside. |
| Firefox from Mozilla's APT repository, pinned above Ubuntu's; uBlock Origin installed by policy; default browser | `iso/firefox/`, `iso/build-iso.sh` | Ubuntu's `firefox` package only installs a snap and the system has no snapd. Installed systems keep Mozilla's repository for updates. The signing key is kept in the repository (fingerprint 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3). |
| VirtualBox guest packages (`virtualbox-guest-utils`, `virtualbox-guest-x11`), `wlr-randr` | `iso/packages-desktop.txt` | Shared folders, host command access and display resizing in VirtualBox without installing Guest Additions by hand. |
| No `discard` mount option on SSDs | `iso/calamares/modules/mount.conf` | Ubuntu trims weekly with `fstrim.timer`. A test install with `discard` on a VirtualBox disk ended up with zero-filled blocks in files. |

## Build system

| What | Where | Why |
|---|---|---|
| Builds run in Ubuntu system directories, isolated from the host | `lib/ubuntu-root.sh` | The build host need not be Ubuntu and is not changed by a build. |
| ISO packed with Ubuntu's GRUB from `iso/cache/tools` | `iso/build-iso.sh` | The image must not depend on the build host's boot loader. |
