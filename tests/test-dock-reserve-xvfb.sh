#!/bin/sh
# A dock window must reserve its own space without replacing the top panel
# as the monitor's bar, whatever order the two appear in and whichever edge
# (bottom, left, right or under the panel at the top) the dock sits on.

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
	} else if (strcmp(argv[1], "dockleft") == 0) {
		x = 0; y = 32; w = 96; h = 736; isdock = 1;
		strut[0] = 72;        /* left */
		strut[4] = 32;        /* left_start_y */
		strut[5] = 767;       /* left_end_y */
	} else if (strcmp(argv[1], "dockright") == 0) {
		x = 1024 - 96; y = 32; w = 96; h = 736; isdock = 1;
		strut[1] = 72;        /* right */
		strut[6] = 32;        /* right_start_y */
		strut[7] = 767;       /* right_end_y */
	} else if (strcmp(argv[1], "docktop") == 0) {
		x = 212; y = 32; w = 600; h = 96; isdock = 1;
		strut[2] = 72;        /* top, below the panel */
		strut[8] = 212;       /* top_start_x */
		strut[9] = 811;       /* top_end_x */
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
		if (strut[0] || strut[1] || strut[2] || strut[3])
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

# wait_box WIN MIN_X MIN_Y MAX_RIGHT MAX_BOTTOM: the only tiled window fills
# the box, give or take the gaps
wait_box() {
	i=0
	while :; do
		geo=$(DISPLAY=$display xdotool getwindowgeometry --shell "$1" 2>/dev/null || true)
		gx=$(printf '%s\n' "$geo" | sed -n 's/^X=//p')
		gy=$(printf '%s\n' "$geo" | sed -n 's/^Y=//p')
		gw=$(printf '%s\n' "$geo" | sed -n 's/^WIDTH=//p')
		gh=$(printf '%s\n' "$geo" | sed -n 's/^HEIGHT=//p')
		if [ -n "$gx" ] && [ -n "$gy" ] && [ -n "$gw" ] && [ -n "$gh" ] &&
			[ "$gx" -ge "$2" ] && [ "$gy" -ge "$3" ] &&
			[ $((gx + gw)) -le "$4" ] && [ $((gy + gh)) -le "$5" ] &&
			[ "$gw" -ge $(($4 - $2 - 64)) ] && [ "$gh" -ge $(($5 - $3 - 64)) ]; then
			return 0
		fi
		i=$((i + 1))
		[ "$i" -lt 100 ] || fail "window $1 at x=$gx y=$gy w=$gw h=$gh, want inside $2,$3-$4,$5"
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
dock_pid=$spawned_pid
spawn panel
panel=$spawned_id
panel_pid=$spawned_pid
spawn normal
normal=$spawned_id
normal_pid=$spawned_pid
wait_geometry "$normal" 32 696
DISPLAY=$display xprop -root _NET_CLIENT_LIST | grep -q "$panel" ||
	fail "panel missing from _NET_CLIENT_LIST when the dock came first"
kill "$dock_pid" "$panel_pid" "$normal_pid"
wait "$dock_pid" "$panel_pid" "$normal_pid" 2>/dev/null || true
stop_dwm

# Side and top docks: the panel stays the bar, the dock keeps its edge.
for mode in dockleft dockright docktop; do
	start_dwm
	spawn panel
	panel=$spawned_id
	panel_pid=$spawned_pid
	spawn "$mode"
	side_pid=$spawned_pid
	spawn normal
	normal=$spawned_id
	normal_pid=$spawned_pid
	case $mode in
	dockleft) wait_box "$normal" 72 32 1024 768 ;;
	dockright) wait_box "$normal" 0 32 952 768 ;;
	docktop) wait_box "$normal" 0 104 1024 768 ;;
	esac
	DISPLAY=$display xprop -root _NET_CLIENT_LIST | grep -q "$panel" ||
		fail "panel missing from _NET_CLIENT_LIST with $mode"
	kill "$side_pid"
	wait "$side_pid" 2>/dev/null || true
	wait_box "$normal" 0 32 1024 768
	kill "$normal_pid" "$panel_pid"
	wait "$normal_pid" "$panel_pid" 2>/dev/null || true
	stop_dwm
done

printf '%s\n' "test-dock-reserve-xvfb: PASS"
