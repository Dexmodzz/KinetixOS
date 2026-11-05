#!/bin/sh
# A bottom dock window must reserve its own space without replacing the top
# panel as the monitor's bar, whatever order the two appear in.

set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)

require_cmd() {
	for cmd; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			printf '%s\n' "missing required command: $cmd" >&2
			exit 77
		fi
	done
}

fail() {
	printf 'test-dock-reserve-xvfb: %s\n' "$*" >&2
	if [ -f "$work/dwm.log" ]; then
		tail -n 20 "$work/dwm.log" >&2
	fi
	exit 1
}

require_cmd Xvfb cc pkg-config xdotool xprop
pkg-config --exists x11

work=$(mktemp -d)
pids=
cleanup() {
	set +e
	for pid in $pids; do
		kill "$pid" 2>/dev/null
	done
	rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

home="$work/home"
mkdir -p "$home/.config/kinetixos" "$home/.local/share/kinetixos/config"
cp "$repo_dir/config/"*.toml "$home/.config/kinetixos/"
cp "$repo_dir/config/"*.toml "$home/.local/share/kinetixos/config/"

cat >"$work/xwin.c" <<'EOF'
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void
stop(int sig)
{
	(void)sig;
	running = 0;
}

int
main(int argc, char **argv)
{
	Display *dpy;
	Window win;
	Atom type, dock;
	XClassHint ch = { "dockreserve", "DockReserve" };
	long strut[12] = { 0 };
	int x = 0, y = 0, w = 300, h = 200;
	int isdock = 0;

	if (argc != 2)
		return 2;
	signal(SIGTERM, stop);
	signal(SIGINT, stop);
	if (!(dpy = XOpenDisplay(NULL)))
		return 2;
	if (strcmp(argv[1], "panel") == 0) {
		w = 1024; h = 32; isdock = 1;
	} else if (strcmp(argv[1], "dock") == 0) {
		x = 212; y = 768 - 96; w = 600; h = 96; isdock = 1;
		strut[3] = 72;        /* bottom */
		strut[10] = 212;      /* bottom_start_x */
		strut[11] = 811;      /* bottom_end_x */
	} else if (strcmp(argv[1], "normal") != 0) {
		return 2;
	}
	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), x, y, w, h, 0, 0, 0);
	XSetClassHint(dpy, win, &ch);
	if (isdock) {
		type = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
		dock = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
		XChangeProperty(dpy, win, type, XA_ATOM, 32, PropModeReplace,
		                (unsigned char *)&dock, 1);
		if (strut[3])
			XChangeProperty(dpy, win, XInternAtom(dpy, "_NET_WM_STRUT_PARTIAL", False),
			                XA_CARDINAL, 32, PropModeReplace, (unsigned char *)strut, 12);
	}
	XSelectInput(dpy, win, StructureNotifyMask);
	XMapWindow(dpy, win);
	XSync(dpy, False);
	printf("0x%lx\n", win);
	fflush(stdout);
	while (running) {
		while (XPending(dpy)) {
			XEvent ev;
			XNextEvent(dpy, &ev);
		}
		usleep(50000);
	}
	XDestroyWindow(dpy, win);
	XCloseDisplay(dpy);
	return 0;
}
EOF
# shellcheck disable=SC2046
cc -Wall -o "$work/xwin" "$work/xwin.c" $(pkg-config --cflags --libs x11)

display=":$((($$ % 500) + 650))"
Xvfb "$display" -screen 0 1024x768x24 -nolisten tcp >"$work/xvfb.log" 2>&1 &
pids="$pids $!"
i=0
until DISPLAY=$display xprop -root >/dev/null 2>&1; do
	i=$((i + 1))
	[ "$i" -lt 100 ] || fail "Xvfb did not start"
	sleep 0.05
done

dwm_pid=
start_dwm() {
	DISPLAY=$display HOME=$home XDG_CONFIG_HOME="$home/.config" \
		XDG_DATA_HOME="$home/.local/share" PATH="$repo_dir:$PATH" \
		"$repo_dir/dwm" >"$work/dwm.log" 2>&1 &
	dwm_pid=$!
	pids="$pids $dwm_pid"
	i=0
	until DISPLAY=$display xprop -root _NET_SUPPORTED 2>/dev/null | grep -q _NET; do
		i=$((i + 1))
		[ "$i" -lt 200 ] || fail "dwm did not start"
		sleep 0.05
	done
}

stop_dwm() {
	kill "$dwm_pid" 2>/dev/null || true
	wait "$dwm_pid" 2>/dev/null || true
}

# spawn MODE: start a test window; sets spawned_pid and spawned_id
spawn() {
	rm -f "$work/$1.id"
	DISPLAY=$display "$work/xwin" "$1" >"$work/$1.id" 2>/dev/null &
	spawned_pid=$!
	pids="$pids $spawned_pid"
	i=0
	until [ -s "$work/$1.id" ]; do
		i=$((i + 1))
		[ "$i" -lt 100 ] || fail "$1 window did not start"
		sleep 0.05
	done
	spawned_id=$(cat "$work/$1.id")
}

# wait_geometry WIN MIN_Y MAX_BOTTOM: tiled window within [MIN_Y, MAX_BOTTOM]
wait_geometry() {
	i=0
	while :; do
		geo=$(DISPLAY=$display xdotool getwindowgeometry --shell "$1" 2>/dev/null || true)
		gy=$(printf '%s\n' "$geo" | sed -n 's/^Y=//p')
		gh=$(printf '%s\n' "$geo" | sed -n 's/^HEIGHT=//p')
		if [ -n "$gy" ] && [ -n "$gh" ] && [ "$gy" -ge "$2" ] &&
			[ $((gy + gh)) -le "$3" ]; then
			return 0
		fi
		i=$((i + 1))
		[ "$i" -lt 100 ] || fail "window $1 at y=$gy h=$gh, want y>=$2 bottom<=$3"
		sleep 0.05
	done
}

# wait_bottom_above WIN LIMIT: window bottom edge extends past LIMIT
wait_bottom_above() {
	i=0
	while :; do
		geo=$(DISPLAY=$display xdotool getwindowgeometry --shell "$1" 2>/dev/null || true)
		gy=$(printf '%s\n' "$geo" | sed -n 's/^Y=//p')
		gh=$(printf '%s\n' "$geo" | sed -n 's/^HEIGHT=//p')
		if [ -n "$gy" ] && [ -n "$gh" ] && [ $((gy + gh)) -gt "$2" ]; then
			return 0
		fi
		i=$((i + 1))
		[ "$i" -lt 100 ] || fail "window $1 bottom $((gy + gh)) did not grow past $2"
		sleep 0.05
	done
}

# Order 1: panel, normal window, then dock.
start_dwm
spawn panel
panel=$spawned_id
panel_pid=$spawned_pid
spawn normal
normal=$spawned_id
normal_pid=$spawned_pid
wait_geometry "$normal" 32 768
spawn dock
dock=$spawned_id
dock_pid=$spawned_pid
wait_geometry "$normal" 32 696
DISPLAY=$display xprop -root _NET_CLIENT_LIST | grep -q "$panel" ||
	fail "panel missing from _NET_CLIENT_LIST once the dock appeared"
DISPLAY=$display xprop -root _NET_CLIENT_LIST | grep -q "$dock" ||
	fail "dock missing from _NET_CLIENT_LIST"

# Removing the dock gives the space back.
kill "$dock_pid"
wait "$dock_pid" 2>/dev/null || true
wait_bottom_above "$normal" 696
wait_geometry "$normal" 32 768

kill "$normal_pid" "$panel_pid"
wait "$normal_pid" "$panel_pid" 2>/dev/null || true
stop_dwm

# Order 2: dock first, then panel, then a normal window.
start_dwm
spawn dock
spawn panel
panel=$spawned_id
spawn normal
normal=$spawned_id
wait_geometry "$normal" 32 696
DISPLAY=$display xprop -root _NET_CLIENT_LIST | grep -q "$panel" ||
	fail "panel missing from _NET_CLIENT_LIST when the dock came first"

printf '%s\n' "test-dock-reserve-xvfb: PASS"
