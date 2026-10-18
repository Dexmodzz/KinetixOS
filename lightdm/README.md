# LightDM Slick Greeter - KinetixOS

A modern Fedora LightDM login screen using Slick Greeter with a Nord colour
palette, blurred background, and the MesloLGS NF font.

The Fedora installer uses `slick-greeter`. The KinetixOS LightDM install target
renders the matching Fedora `lightdm.conf`.

## Files

| File | Destination |
|------|-------------|
| `lightdm.conf` | `/etc/lightdm/lightdm.conf` |
| `kinetixos-display-setup` | `/usr/libexec/kinetixos/lightdm-display-setup` |
| `slick-greeter.conf` | `/etc/lightdm/slick-greeter.conf` |
| `wallpaper.jpg` | `/usr/share/pixmaps/kinetixos.jpg` |

## External monitor with the lid closed

The rendered `lightdm.conf` sets `display-setup-script` to
`kinetixos-display-setup`, which runs `dwm-hdmi-watch --apply` before the
greeter starts. A connected external monitor becomes the only, primary display,
so the greeter appears on it even with the laptop lid closed. Because the
external output is enabled, systemd-logind treats the laptop as docked and
applies `HandleLidSwitchDocked=ignore` instead of suspending on the lid switch.
The script always exits 0 so a layout failure never stops the greeter.

## Install

The main `install.sh` handles this automatically. To apply manually:

```sh
sudo make install
```

The direct `make install` defaults match Fedora. Prefer the top-level
`install.sh` for a complete installation.

## Customisation

Edit `slick-greeter.conf` before running `sudo make install`:

- **background** — path to a wallpaper image
- **font-name** — any font already installed on the system
- **clock-format** — strftime-style format string
- **theme-name** — GTK theme for the panel (e.g. `Adwaita-dark`)
- **show-clock** / **show-hostname** — toggle status bar items
- **activate-numlock** — enable only when `numlockx` is installed
