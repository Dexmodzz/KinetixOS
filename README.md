<div align="center">
  <img alt="KinetixOS logo" src="./branding/anaconda/usr/share/anaconda/pixmaps/kinetixos-logo.png" />
  <p><strong>A fast, focused Fedora X11 desktop built for keyboard-driven work.</strong></p>
  <p>
    <a href="./docs/src/content/getting-started.md">Documentation</a> |
    <a href="https://github.com/Dexmodzz/KinetixOS/releases/latest">Latest release</a> |
    <a href="./CHANGELOG.md">Changelog</a> |
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
</div>

KinetixOS is a complete, lightweight X11 desktop with sensible defaults,
guided installation, and powerful customization. It is designed for people who
want a responsive keyboard-first workflow without having to assemble every
part themselves.

**KinetixOS is a Fedora-only distribution.** Fedora Linux is the sole supported
platform for installation, runtime behavior, package resolution, testing, and
release qualification. Use either the Fedora desktop image or the
existing-system installer on Fedora Linux.

## What You Get

| Experience | What it includes |
| --- | --- |
| **A focused desktop** | Automatic window tiling, nine workspaces, fast keyboard navigation, multi-monitor support, and flexible fullscreen modes. |
| **Everyday essentials** | A polished panel, application launcher, system tray, Control Center, Settings, notifications, screenshots, audio, brightness, and power controls. |
| **Easy discovery** | An interactive keybind viewer, guided display setup, built-in diagnostics, workstation self-heal, and clear unsupported-feature reporting. |
| **Personal configuration** | Live-reloading hotkeys, themes, and window rules, with local configuration preserved across upgrades. |
| **Two installation paths** | A ready-to-install Fedora image or an installer for an existing Fedora system. |

> KinetixOS is an X11 desktop. A Wayland-native session is not currently part
> of the project scope.

## Install

Choose the path that matches your system:

| Installation | Best for | What it does |
| --- | --- | --- |
| [Fedora ISO](#fedora-iso) | A fresh, dedicated installation | Installs the complete Fedora-only desktop from bootable media. |
| [Existing system](#existing-system) | A Fedora installation you already use | Installs dependencies, the desktop session, and the selected feature set while preserving local configuration. |

For complete requirements and installation details, see the
[Installation Guide](docs/src/content/install.md).

### Fedora ISO

KinetixOS does not publish prebuilt ISO images yet. Build the standard or NVIDIA
offline image locally from this repository by following
[compressed-image builds](docs/COMPRESSED-IMAGES.md) and
[releasing](docs/RELEASING.md). Write the resulting ISO as a disk image to an
8 GB or larger USB drive, boot it, choose your disk, locale and administrator
account in Anaconda, then install and reboot into the `dwm` session. Writing the
USB erases its contents; review Anaconda's disk changes before starting
installation.

### Existing System

```bash
git clone https://github.com/Dexmodzz/KinetixOS.git
cd KinetixOS

./install.sh --dry-run --non-interactive --profile recommended
./install.sh --profile recommended
```

The dry run shows the dependency and installation plan before anything changes.
The installer requires Fedora, preserves existing personal configuration, and
installs the managed desktop components. It accepts only Fedora's
`/etc/os-release` identity and rejects every other operating-system identity
before making changes.

| Profile | Includes |
| --- | --- |
| `core` | The X11 session, required dependencies, and one terminal emulator. |
| `recommended` | The complete everyday desktop, including Alacritty, Quickshell, Gear Lever for AppImages, theming, screenshots, audio, brightness, and the PackageKit, Python RPM binding, AccountsService, CUPS, and printer-tool prerequisites for Phase 6 system management. |
| `full` | The recommended desktop plus optional file-manager, keyring, wallpaper, display-manager, and supported Fedora gaming integrations. |

`maim` is an optional dependency used only by the screenshot hotkeys. If it is
unavailable, installation continues and reports that the screenshot hotkeys
remain disabled; invoking one makes `dwm-screenshot` exit with
`dwm-screenshot: maim is not installed`. `xclip` and `xdotool` remain required
runtime dependencies for the X11 desktop and its other managed helpers.

## First Login

**Super** is the Windows key on most keyboards.

| Action | Keybind |
| --- | --- |
| Open the application launcher | <kbd>Super</kbd> + <kbd>R</kbd> |
| Open Alacritty terminal | <kbd>Super</kbd> + <kbd>X</kbd> |
| Open Control Center | <kbd>Super</kbd> + <kbd>F1</kbd> |
| Show the interactive keybind viewer | <kbd>Super</kbd> + <kbd>/</kbd> |
| Close the focused window | <kbd>Super</kbd> + <kbd>Q</kbd> |
| Switch workspace | <kbd>Super</kbd> + <kbd>1-9</kbd> |
| Open the power menu | <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> |

With a display manager, select the `dwm` session when logging in. From a TTY,
start the session with:

```bash
startx
```

## Customize Your Desktop

Most personal settings live under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/kinetixos/
```

Hotkeys, themes, and window rules reload when their TOML files are saved.
Advanced compile-time preferences live in the user-owned `config.h`, which the
installer and future upgrades preserve.

The installer also provides `dwm-settings-display` and its root-owned
`libexec/kinetixos/dwm-settings-display-root` persistence helper. Live display
discovery and previews require `xrandr`; hotplug watching requires `udevadm`;
only persistent Xorg install and rollback require `pkexec`. Named profiles live
under the `display-profiles/` directory in the XDG path above.
Run `dwm-display-setup detect`, then `dwm-display-setup`, for a guided wizard
that detects outputs and configures modes, positions, rotation, and the primary
display with a reversible preview. Persistent generation selects compatible
TearFree or NVIDIA Full Composition Pipeline behavior automatically; pass
`--force-full-composition-pipeline off` to disable the NVIDIA default.
The adjacent `dwm-settings-input` provider uses `xinput`, `setxkbmap` for
keyboard settings, `xkbset` for session-wide AccessX controls, and `udevadm`
for stable device identity and hotplug events. Kept values are stored in
`input-settings.conf` in the same XDG directory; `DWM_INPUT_SETTINGS_FILE` can
select another file.

The compositor settings in **Settings -> Appearance -> Compositor** and the CLI
helper `dwm-settings-picom` manage window opacity and rendering backends. Sliders
adjust active and inactive window opacity with live persistence in the active configuration
(resolved from `DWM_PICOM_CONFIG`, a running Picom `--config` argument, or standard
fallback paths `~/.config/picom.conf` and `~/.config/picom/picom.conf`). The automatic
backend policy selects GLX for accelerated Intel/AMD graphics and falls back to XRender
on NVIDIA or software rendering, with manual GLX, XRender, and EGL overrides available.
Edits preserve custom comments and includes with up to ten automatic recovery backups.
Cursor theme changes in Settings take effect immediately across running X11
applications via `dwm-cursor-reload`.

See the [Configuration Guide](docs/src/content/configuration.md)
and [Theming Guide](docs/src/content/theming.md) for examples and
safe customization paths.

## Documentation

- [Installation](docs/src/content/install.md)
- [Getting Started](docs/src/content/getting-started.md)
- [Keybindings](docs/src/content/keybinds.md)
- [Configuration](docs/src/content/configuration.md)
- [Theming](docs/src/content/theming.md)
- [Control Center](docs/src/content/control-center.md)
- [Settings](docs/src/content/settings.md)
- [How KinetixOS Works](docs/src/content/patches.md)
- [Troubleshooting](docs/src/content/troubleshooting.md)

The technical guide explains the project architecture, what dwm is, and how
the maintained enhancements fit together. You do not need to understand or
apply dwm patches to install and use the desktop.

## Troubleshooting

**Settings -> System** separates read-only **Reload status** from confirmed
metadata refresh and package installation. Review all package changes, including
dependency additions and removals, before confirming. PackageKit owns
authorization and cancellation; closing Settings does not cancel an operation.
If discovery or recovery is incomplete, reload status and follow its guidance.

The same section provides confirmed account, password, printer, and software-source
tool launches. Missing tools or stale provider status disable only the affected
entry. Account and repository inventories remain read-only. A successful launch
does not mean administration inside the tool completed; authorize and confirm
those changes in the tool itself. Enter passwords only in the terminal prompt.

For timezone or system locale, **Load choices**, filter and select a reported
value, then **Review change**. Network time offers fixed enable/disable previews.
Review the complete preview before **Apply change**: a sent regional change
cannot be canceled. Cancel only dismisses the preview, and closing Settings does
not undo an action. An uncertain result requires fresh status and new confirmation,
not automatic retry. Locale changes apply to new sessions; log out manually when
ready. Synchronization status is labeled as the last read.
The panel and System Settings share one minute-level local clock. A newly
reported timezone refreshes both displays without restarting Quickshell.

Start with the built-in diagnostic report:

```bash
dwm-diagnostics
```

You can also run **Control Center -> Quick Actions -> Self-Heal** to execute a
configured workstation repair script (`dwm-self-heal` on `$PATH` or referenced in
`${XDG_CONFIG_HOME:-$HOME/.config}/kinetixos/self-heal.path`) inside an interactive
terminal with visible output and authorization prompts.

You can also open **Control Center -> System Health** for a graphical overview.
If the session does not start, run `startx` from a TTY to see its error output.
The [Troubleshooting Guide](docs/src/content/troubleshooting.md)
covers common session, panel, terminal, theme, display, and NVIDIA issues.

If the problem remains, [open an issue](https://github.com/Dexmodzz/KinetixOS/issues)
and include the relevant diagnostic output. Review it first and remove any
private system information.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the
development workflow and validation requirements, and report security issues
using [SECURITY.md](SECURITY.md).

The main repository check uses a managed workspace under `$HOME/tmp` and
removes it when the run finishes:

```bash
scripts/run-tests
```

Project requirements and active work are tracked in [SPEC.md](SPEC.md),
[ROADMAP.md](ROADMAP.md), and [TASKS.md](TASKS.md).
