<div align="center">
  <img alt="KinetixOS logo" src="./branding/anaconda/usr/share/anaconda/pixmaps/kinetixos-logo.png" />
  <p><strong>A fast, focused Fedora X11 desktop built for keyboard-driven work.</strong></p>
  <p>
    <a href="https://github.com/Dexmodzz/KinetixOS/releases/latest">Download</a> |
    <a href="./docs/src/content/getting-started.md">Documentation</a> |
    <a href="./CHANGELOG.md">Changelog</a> |
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
</div>

KinetixOS is a complete, lightweight desktop for Fedora Linux. Windows arrange
themselves automatically, everything is one keystroke away, and the panel,
Control Center and Settings cover the daily tasks without editing files.

It is built on a patched [dwm](https://dwm.suckless.org/) window manager and a
[Quickshell](https://quickshell.org/) shell, and runs on X11. Fedora Linux
(currently Fedora 44, x86_64) is the only supported platform.

## What You Get

| | |
| --- | --- |
| **Tiling windows** | Windows tile automatically (dwindle layout by default), with nine workspaces, floating and fullscreen modes, and multi-monitor support. |
| **A complete desktop** | Panel, app launcher, system tray, notifications, Control Center and Settings, with volume, brightness, Bluetooth, network and power controls. |
| **Ready-to-use apps** | Brave Origin browser, Thunar file manager, Alacritty terminal, Celluloid and mpv for media, sxiv for images, Gear Lever for AppImages. |
| **Easy to learn** | An on-screen keybind viewer (<kbd>Super</kbd> + <kbd>/</kbd>), built-in diagnostics and a System Health view. |
| **Your settings stay yours** | Hotkeys, themes and window rules are plain TOML files that reload when you save them, and upgrades never overwrite them. |
| **Desktop updates** | Settings -> System checks for new KinetixOS versions and installs them with progress and recovery. |

## Install

| You have... | Use | Guide |
| --- | --- | --- |
| A new or spare computer (or VM) | The installer ISO | [Installer ISO](#installer-iso) |
| Fedora 44 already installed | `install.sh` | [Existing Fedora system](#existing-fedora-system) |

Full details: [Installation Guide](docs/src/content/install.md).

### Installer ISO

1. From the [latest release](https://github.com/Dexmodzz/KinetixOS/releases/latest),
   download **`kinetixos.iso`** (any graphics card) or
   **`kinetixos-nvidia.iso`** (NVIDIA cards, proprietary driver), plus
   `SHA256SUMS`.
2. Check the download. In the download folder run
   `sha256sum --ignore-missing -c SHA256SUMS`; your ISO must say `OK`.
3. Write the ISO to a USB drive of 8 GB or more with an image writer (this
   erases the drive), and boot from it.
4. Before the graphical installer opens, a text screen asks a few questions.
   Press <kbd>Enter</kbd> to keep a default:

   | Question | Default |
   | --- | --- |
   | Install the gaming packages (Steam, Gamescope, GameMode, MangoHud)? | no |
   | Font size | 12 |
   | Modifier key (`super` or `alt`) | super |
   | Master area ratio | 0.55 |
   | Number of master windows | 1 |

5. In the Fedora installer, pick the language, disk and time zone, and create
   your user with administrator rights. Then start the installation.
6. Reboot and log in. The installer sets up LightDM and the **dwm** session.

The ISO downloads packages during installation, so the computer needs an
internet connection. It also needs a screen and keyboard; a virtual machine
console such as Proxmox VE works.

### Existing Fedora System

```bash
git clone https://github.com/Dexmodzz/KinetixOS.git
cd KinetixOS
./install.sh --dry-run --non-interactive --profile recommended   # preview, changes nothing
./install.sh --profile recommended
```

The installer works only on Fedora, shows the package plan before it changes
anything, and keeps your existing configuration. Choose a profile:

| Profile | What it installs |
| --- | --- |
| `core` | The minimum: dwm, the X11 session, a terminal and media players. |
| `recommended` | The full everyday desktop: Quickshell panel and Settings, compositor, themes and fonts, screenshots, audio, Bluetooth, printing, Flatpak and Gear Lever. |
| `full` (default) | `recommended` plus Thunar, keyring login, wallpapers, the LightDM login screen and, if you approve, the gaming packages. |

If an NVIDIA card is detected, the installer offers the proprietary driver
(default no). If your system boots to a text console, it offers to start the
graphical login at boot. Run `./install.sh --help` for every option.

## First Login

Select the **dwm** session at the login screen, or run `startx` from a text
console. **Super** is the Windows key.

| Action | Keys |
| --- | --- |
| App launcher | <kbd>Super</kbd> + <kbd>R</kbd> |
| Terminal | <kbd>Super</kbd> + <kbd>X</kbd> |
| File manager | <kbd>Super</kbd> + <kbd>E</kbd> |
| Browser | <kbd>Super</kbd> + <kbd>B</kbd> |
| Control Center | <kbd>Super</kbd> + <kbd>F1</kbd> |
| Show all keybinds | <kbd>Super</kbd> + <kbd>/</kbd> |
| Close the window | <kbd>Super</kbd> + <kbd>Q</kbd> |
| Go to workspace 1-9 | <kbd>Super</kbd> + <kbd>1</kbd>...<kbd>9</kbd> |
| Move the window to workspace 1-9 | <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd>...<kbd>9</kbd> |
| Screenshot: monitor | <kbd>Super</kbd> + <kbd>P</kbd> |
| Screenshot: area to file / to clipboard | <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> / <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>P</kbd> |
| Power menu | <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> |

## Customize

- **Settings** (Control Center -> Settings, or `dwm-settings open`) covers
  displays, keyboard and mouse, appearance, default apps and system tasks.
- **Hotkeys, themes and window rules** live in
  `~/.config/kinetixos/` (`hotkeys.toml`, `themes.toml`, `window-rules.toml`).
  Save the file and the change applies immediately.
- **Build-time options** such as font size and modifier key live in
  `config.h` in the source folder. The installer and updates keep your copy.

See the [Configuration](docs/src/content/configuration.md) and
[Theming](docs/src/content/theming.md) guides for examples.

## Updates

Open **Settings -> System -> Desktop updates** to check for and install new
KinetixOS versions; Fedora package updates are in the same section. For
source checkouts, see
[Source updates and recovery](docs/src/content/install.md#source-updates-and-recovery).

## Troubleshooting

- Run `dwm-diagnostics` for a report of what works and what is missing.
- Open **Control Center -> System Health** for the same overview on screen.
- If the session does not start, log in on a text console and run `startx`
  to see the error.
- The [Troubleshooting Guide](docs/src/content/troubleshooting.md) covers
  session, panel, display, theme and NVIDIA problems.

Still stuck? [Open an issue](https://github.com/Dexmodzz/KinetixOS/issues) and
attach the `dwm-diagnostics` output after removing any private information.

## For Experienced Users

**How it fits together**

- **dwm core** (`dwm.c`, C99): compile-time defaults in `config.def.h`, your
  local copy in `config.h`. At runtime dwm reads `hotkeys.toml`,
  `themes.toml` and `window-rules.toml` (user copy first, shipped defaults in
  `config/`) and reloads them through inotify. It publishes its state through
  EWMH and custom root-window atoms.
- **Quickshell shell** (`config/quickshell/`, QML): panel, launcher, Control
  Center, Settings and notifications. The QML stays unprivileged and gets its
  data from the `dwm-quickshell-*` and `dwm-settings-*` helper commands.
- **Privileged actions** go through small root-owned helpers in
  `libexec/kinetixos/` behind polkit, each limited to an allowlist.
- **Packages**: `scripts/dwm-packages.sh` is the single Fedora package map used
  by `install.sh`, diagnostics and the Kickstart profiles.
- **Installer ISOs**: `dwm-fedora.ks` and `dwm-fedora-nvidia.ks` on top of the
  Fedora Server netinst ISO; `%post` runs `install.sh --profile recommended`.

**Build, test, make your own ISO**

```bash
make                              # build dwm (creates config.h if missing)
scripts/dev-sync-install.sh       # build and sync this checkout into your session
scripts/run-tests                 # full test gate in a temporary workspace
```

To build the installer ISOs yourself, follow [RELEASING.md](docs/RELEASING.md).
[How KinetixOS Works](docs/src/content/patches.md) explains the dwm patches;
[SPEC.md](SPEC.md) defines the scope and [ROADMAP.md](ROADMAP.md) the plan.

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

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow and the checks each change needs, and report security issues as
described in [SECURITY.md](SECURITY.md).
