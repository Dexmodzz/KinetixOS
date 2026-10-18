#!/usr/bin/env bash
set -euo pipefail

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fedora_stage="$work/fedora"

make -C "$repo/lightdm" --no-print-directory \
	DESTDIR="$fedora_stage" \
	LIGHTDM_SEAT_SECTION='Seat:*' \
	LIGHTDM_GREETER_SESSION=slick-greeter \
	LIGHTDM_SESSION_WRAPPER= \
	LIGHTDM_LOGIND_CHECK=true \
	install >/dev/null
cat >"$work/fedora.expected" <<'CONF'
[LightDM]
logind-check-graphical=true

[Seat:*]
greeter-session=slick-greeter
user-session=dwm
display-setup-script=/usr/libexec/kinetixos/lightdm-display-setup
CONF
cmp -s "$work/fedora.expected" "$fedora_stage/etc/lightdm/lightdm.conf"

grep -Fqx 'xft-dpi=96' "$fedora_stage/etc/lightdm/slick-greeter.conf"
grep -Fqx 'activate-numlock=false' "$fedora_stage/etc/lightdm/slick-greeter.conf"

display_setup="$fedora_stage/usr/libexec/kinetixos/lightdm-display-setup"
test -x "$display_setup"

# The display setup applies the external monitor layout before the greeter.
fake_bin="$work/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/dwm-hdmi-watch" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$FAKE_HDMI_WATCH_LOG"
SH
chmod 755 "$fake_bin/dwm-hdmi-watch"
FAKE_HDMI_WATCH_LOG="$work/hdmi-watch.log" \
	DWM_HDMI_WATCH="$fake_bin/dwm-hdmi-watch" "$display_setup" 2>/dev/null
grep -Fqx -- '--apply' "$work/hdmi-watch.log"

# LightDM stops the seat when the script fails, so every failure exits 0.
cat >"$fake_bin/failing-hdmi-watch" <<'SH'
#!/bin/sh
exit 1
SH
chmod 755 "$fake_bin/failing-hdmi-watch"
DWM_HDMI_WATCH="$fake_bin/failing-hdmi-watch" "$display_setup" 2>/dev/null
DWM_HDMI_WATCH="$work/missing-hdmi-watch" "$display_setup" 2>/dev/null

printf 'LightDM config rendering: PASS\n'
