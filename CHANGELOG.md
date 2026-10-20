# Changelog

All notable project changes are documented here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic
versions from `config.mk`.

## [Unreleased]

### Added

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

- Cursor warp is off by default (`cursorwarp = 0`).

### Fixed

- Show the LightDM greeter on a connected external monitor when the laptop lid
  is closed, and stop the lid switch from suspending the laptop at the greeter.
- Keep Settings panes hidden and disabled while they load asynchronously, so
  controls never flash usable before their data arrives.

## [0.1.0]

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
