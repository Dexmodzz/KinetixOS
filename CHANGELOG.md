# Changelog

All notable project changes are documented here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic
versions from `config.mk`.

## [Unreleased]

### Added

- "Moderno morbido" theme: night blue with a periwinkle accent, three rounded
  bar islands, a restyled Application Index launcher, 12 px window gaps,
  2 px borders, and Picom rounded corners and shadows.
- Optional theme style profiles (`style = "NAME"` with a `[style.NAME]`
  section in `themes.toml`) for shell radii, bar layout, fonts, dwm gaps and
  borders, and Picom corners and shadows. Themes without one are unchanged.
- Optional `shell_*` theme colors that separate shell surfaces and text roles
  from the terminal palette.
- `dwm-settings-theme merge-shipped`, run on install and update, adds newly
  shipped themes and style profiles to an existing user `themes.toml`.
- The installer downloads the Outfit font (SIL OFL 1.1) for the soft style.
- "macOS Tahoe" theme: dark system colors, a translucent macOS-style menu bar
  (apple glyph, bold app name, dot workspaces, clock on the right), a bottom
  dock with favorites, running dots and hover magnification, dual_kawase blur
  behind shell surfaces, and the system blue accent in GTK3 and GTK4.
- Style keys `bar_layout`, `bar_opacity`, `dock`, `dock_icon_size`,
  `dock_magnify`, `dock_radius`, `dock_opacity`, `dock_apps`, `blur` and
  `gtk_css`. Their defaults keep every existing theme unchanged.
- dwm reserves a bottom dock window (its `_NET_WM_STRUT` bottom) separately
  from the top panel.
- `dwm-quickshell-launcher launch-id DESKTOP-ID`.

### Changed

- The runtime TOML parser limit is 1024 entries (was 512), so the shipped
  themes file has room for more themes.

## [0.1.0] - 2026-10-20

### Added

- First independent KinetixOS release: a Fedora-only X11 desktop built on a
  patched dwm, the managed Quickshell shell, Settings, Control Center, desktop
  source updates from `github.com/Dexmodzz/KinetixOS`, and Fedora image and
  existing-system installers.
- New KinetixOS logo for the panel, LightDM greeter and Anaconda installer.
- Dwindle layout (`[D]`) as the default tiling layout, with configurable gaps.
- Make a connected external monitor the only, primary display whether the
  laptop lid is open or closed, and restore the laptop panel when it is
  unplugged. The layout is applied at session start and `dwm-hdmi-watch`
  follows hotplug events for the lifetime of its X server.
- Seed the Thunar side pane once per account: Home and Trash on top, then the
  Documents, Pictures, Music and Download folders as bookmarks, with Recent,
  Desktop and Computer/File System hidden. Folders are resolved through
  xdg-user-dirs, so localized names and any user name work.
- The standard and NVIDIA installer ISOs ask, before Anaconda's UI, whether to
  install the Fedora gaming packages and the dwm font size, modifier key,
  master-area ratio and master window count. Gaming packages are installed only
  on yes. The questions need a screen and keyboard (a Proxmox VM console works).
- The installer ISOs create the XDG user folders during installation, so the
  Thunar side pane bookmarks Documents, Pictures, Music and Downloads from the
  first login, as with `install.sh --profile full`.
- The installer ISOs download the default wallpapers into
  `~/Pictures/backgrounds`, so a fresh install no longer starts on a black
  background.
- `install.sh` offers the proprietary NVIDIA driver (`akmod-nvidia` from RPM
  Fusion) when it detects an NVIDIA GPU. The prompt defaults to no; use
  `--install-nvidia` or `--skip-nvidia` for unattended installs.
- `install.sh` offers to boot to `graphical.target` when a display manager is
  enabled but the system boots to a TTY, so LightDM starts after installation
  on Fedora Server. Use `--enable-graphical-login` or `--skip-graphical-login`
  for unattended installs.

### Changed

- Configuration, data and state now live under `kinetixos` directories
  (`~/.config/kinetixos`, `~/.local/share/kinetixos`,
  `~/.local/state/kinetixos`, `/var/lib/kinetixos`). Installing over an existing
  `dwm-titus` installation migrates those directories and managed system files
  once, preserving personal configuration.
- Wallpapers are downloaded from `github.com/Dexmodzz/my-background`.
- Install Gamescope from the official Fedora repositories instead of a COPR.
  Fedora 44 ships Gamescope 3.16.29, which includes the upstream SDL shutdown
  fix (ValveSoftware/gamescope#2246); the gaming profile now only enables RPM
  Fusion nonfree for Steam.
- Cursor warp is off by default (`cursorwarp = 0`).

### Fixed

- Show the LightDM greeter on a connected external monitor when the laptop lid
  is closed, and stop the lid switch from suspending the laptop at the greeter.
- Keep Settings panes hidden and disabled while they load asynchronously, so
  controls never flash usable before their data arrives.
