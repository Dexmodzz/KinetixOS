#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
helper=$repo/scripts/dwm-hdmi-watch
test_tmp_root=${DWM_TEST_TMP_ROOT:-${HOME}/tmp}
mkdir -p -- "$test_tmp_root"
work=$(mktemp -d "$test_tmp_root/dwm-hdmi-watch-test.XXXXXX")
watcher=

cleanup() {
	set +e
	[ -z "$watcher" ] || kill "$watcher" 2>/dev/null
	: >"$work/xprop.stop"
	wait 2>/dev/null
	rm -rf -- "$work"
}
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# Fake xrandr: --query prints $work/outputs, other calls are logged.
mkdir -p "$work/bin" "$work/runtime"
cat >"$work/bin/xrandr" <<'SH'
#!/bin/sh
if [ "$1" = --query ]; then
	while read -r name state; do
		printf '%s %s (normal left inverted right x axis y axis)\n' "$name" "$state"
	done <"$FAKE_DIR/outputs"
	exit 0
fi
printf '%s\n' "$*" >>"$FAKE_DIR/xrandr.log"
SH
# Fake udevadm: forwards lines written to the events FIFO.
cat >"$work/bin/udevadm" <<'SH'
#!/bin/sh
printf '%s\n' "$$" >"$FAKE_DIR/udevadm.pid"
exec cat "$FAKE_DIR/events"
SH
# Fake xprop: blocks like -spy until the test "shuts down" the X server.
cat >"$work/bin/xprop" <<'SH'
#!/bin/sh
while [ ! -e "$FAKE_DIR/xprop.stop" ]; do sleep 0.05; done
SH
chmod +x "$work/bin/"*

set_outputs() {
	printf '%s\n' "$@" >"$work/outputs"
}

run_apply() {
	rm -f "$work/xrandr.log"
	PATH="$work/bin:/usr/bin:/bin" FAKE_DIR="$work" "$helper" --apply 2>/dev/null
}

expect_log() {
	local expected=$1 actual
	actual=$(cat "$work/xrandr.log" 2>/dev/null || true)
	[[ $actual == "$expected" ]] || fail "expected xrandr '$expected', got '$actual'"
}

wait_for() {
	local i
	for i in $(seq 100); do
		eval "$1" && return 0
		sleep 0.05
	done
	fail "timed out waiting for: $1"
}

# External monitor wins even with the laptop panel still reported connected.
set_outputs 'eDP-1 connected' 'HDMI-1 connected' 'DP-1-1 disconnected'
run_apply
expect_log '--output HDMI-1 --auto --primary --output eDP-1 --off'

# Any external connector counts, not only HDMI-1.
set_outputs 'eDP-1 connected' 'HDMI-1 disconnected' 'DP-1-1 connected'
run_apply
expect_log '--output DP-1-1 --auto --primary --output eDP-1 --off'

# Unplugged: the laptop panel returns and every external output is turned off.
set_outputs 'eDP-1 connected' 'HDMI-1 disconnected' 'DP-1-1 disconnected'
run_apply
expect_log '--output eDP-1 --auto --primary --output HDMI-1 --off --output DP-1-1 --off'

# A desktop with no internal panel and nothing connected is left alone.
set_outputs 'HDMI-1 disconnected'
run_apply
expect_log ''

# Unknown arguments are rejected.
if PATH="$work/bin:/usr/bin:/bin" "$helper" --bogus 2>/dev/null; then
	fail 'accepted an unknown argument'
fi

# Watch mode: applies at startup, reacts to hotplug, ignores no-op events,
# and exits with its udevadm child when the X server goes away.
mkfifo "$work/events"
exec 7<>"$work/events"
set_outputs 'eDP-1 connected' 'HDMI-1 connected'
rm -f "$work/xrandr.log"
PATH="$work/bin:/usr/bin:/bin" FAKE_DIR="$work" DISPLAY=:77 \
	XDG_RUNTIME_DIR="$work/runtime" DWM_HDMI_SETTLE_SECONDS=0 \
	"$helper" 2>/dev/null &
watcher=$!
wait_for '[ -s "$work/xrandr.log" ]'
expect_log '--output HDMI-1 --auto --primary --output eDP-1 --off'

# A second watcher for the same display exits immediately.
PATH="$work/bin:/usr/bin:/bin" FAKE_DIR="$work" DISPLAY=:77 \
	XDG_RUNTIME_DIR="$work/runtime" timeout 5 "$helper" 2>/dev/null ||
	fail 'duplicate watcher did not exit cleanly'

printf 'ACTION=change\n' >&7
sleep 0.3
expect_log '--output HDMI-1 --auto --primary --output eDP-1 --off'

set_outputs 'eDP-1 connected' 'HDMI-1 disconnected'
printf 'ACTION=change\n' >&7
wait_for '[ "$(wc -l <"$work/xrandr.log")" -eq 2 ]'
[[ $(tail -n 1 "$work/xrandr.log") == '--output eDP-1 --auto --primary --output HDMI-1 --off' ]] ||
	fail "unexpected unplug layout: $(tail -n 1 "$work/xrandr.log")"

udev_pid=$(cat "$work/udevadm.pid")
: >"$work/xprop.stop"
wait_for '! kill -0 "$watcher" 2>/dev/null'
watcher=
wait_for '! kill -0 "$udev_pid" 2>/dev/null'
exec 7>&-
[[ -z $(find "$work/runtime" -name '*.fifo') ]] || fail 'FIFO left behind'

# SIGTERM stops a watcher promptly, together with its udevadm child.
rm -f "$work/xprop.stop" "$work/udevadm.pid"
exec 7<>"$work/events"
PATH="$work/bin:/usr/bin:/bin" FAKE_DIR="$work" DISPLAY=:78 \
	XDG_RUNTIME_DIR="$work/runtime" DWM_HDMI_SETTLE_SECONDS=0 \
	"$helper" 2>/dev/null &
watcher=$!
wait_for '[ -s "$work/udevadm.pid" ]'
udev_pid=$(cat "$work/udevadm.pid")
kill -TERM "$watcher"
wait_for '! kill -0 "$watcher" 2>/dev/null'
watcher=
wait_for '! kill -0 "$udev_pid" 2>/dev/null'
exec 7>&-

printf '%s\n' 'dwm-hdmi-watch tests passed.'
