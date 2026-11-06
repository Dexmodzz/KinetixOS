#!/bin/sh
# Loads the real dock under Xvfb and checks what the user sees:
# - the dock appears once desktop entries finish loading;
# - its X shape (which on X11 also clips drawing and Picom blur) is the
#   rounded pill at rest, with nothing above it;
# - while hovered the shape grows upwards so magnified icons are not cut off.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fail() {
	printf 'Quickshell dock Xvfb: FAIL: %s\n' "$1" >&2
	exit 1
}
for tool in Xvfb quickshell xdotool cc; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'Quickshell dock Xvfb: SKIP (%s missing)\n' "$tool"
		exit 0
	}
done

tmp=$(mktemp -d)
xvfb_pid=
qs_pid=
cleanup() {
	[ -z "$qs_pid" ] || kill "$qs_pid" 2>/dev/null || true
	[ -z "$xvfb_pid" ] || kill "$xvfb_pid" 2>/dev/null || true
	rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

cat >"$tmp/shape.c" <<'EOF'
#include <X11/Xlib.h>
#include <X11/extensions/shape.h>
#include <stdio.h>
#include <stdlib.h>
/* Prints: rect-count min-x min-y max-x max-y of the bounding shape. */
int main(int argc, char **argv)
{
	Display *dpy = XOpenDisplay(NULL);
	int count, ordering, i, x0 = 1 << 30, y0 = 1 << 30, x1 = -1, y1 = -1;
	XRectangle *r;

	if (!dpy || argc != 2)
		return 2;
	r = XShapeGetRectangles(dpy, strtoul(argv[1], NULL, 0), ShapeBounding, &count, &ordering);
	for (i = 0; i < count; i++) {
		x0 = r[i].x < x0 ? r[i].x : x0;
		y0 = r[i].y < y0 ? r[i].y : y0;
		x1 = r[i].x + r[i].width > x1 ? r[i].x + r[i].width : x1;
		y1 = r[i].y + r[i].height > y1 ? r[i].y + r[i].height : y1;
	}
	printf("%d %d %d %d %d\n", count, x0, y0, x1, y1);
	return 0;
}
EOF
cc -o "$tmp/shape" "$tmp/shape.c" -lX11 -lXext || fail "cannot build the shape reader"

mkdir "$tmp/shell"
cp -R "$repo_dir/config/quickshell/." "$tmp/shell/"
cat >"$tmp/shell/shell.qml" <<'EOF'
import QtQuick
import Quickshell
import qs.core
import qs.dock

ShellRoot {
    QtObject {
        id: fakeState
        property var runningApps: []
        property var fullscreenMonitorIndexes: []
        function screenIndex(screen) { return 0; }
        function focusWindow(id) {}
    }
    Component.onCompleted: {
        Theme.styleDockIconSize = 48;
        Theme.styleDockMagnify = 150;
        Theme.styleDockRadius = 22;
        Theme.styleDockApps = ["dock-test-a", "dock-test-b", "dock-test-c"];
    }
    Dock { desktopState: fakeState }
}
EOF
mkdir -p "$tmp/data/applications"
for id in dock-test-a dock-test-b dock-test-c; do
	printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\nIcon=folder\n' \
		"$id" >"$tmp/data/applications/$id.desktop"
done

display=:$((90 + $$ % 9))
Xvfb "$display" -screen 0 1024x768x24 -nolisten tcp >/dev/null 2>&1 &
xvfb_pid=$!
sleep 1
DISPLAY=$display XDG_DATA_DIRS=$tmp/data XDG_DATA_HOME=$tmp/data-home \
	XDG_RUNTIME_DIR=$tmp quickshell -p "$tmp/shell/shell.qml" >"$tmp/qs.log" 2>&1 &
qs_pid=$!

win=
tries=0
while [ "$tries" -lt 40 ]; do
	win=$(DISPLAY=$display xdotool search --onlyvisible --pid "$qs_pid" 2>/dev/null | head -n 1 || true)
	[ -n "$win" ] && break
	tries=$((tries + 1))
	sleep 0.25
done
[ -n "$win" ] || fail "the dock never appeared (desktop entries loaded after the item list was built?)"
sleep 0.5

# Sets s_count s_x0 s_y0 s_x1 s_y1 from the dock's bounding shape.
read_shape() {
	DISPLAY=$display "$tmp/shape" "$win" >"$tmp/shape.out"
	read -r s_count s_x0 s_y0 s_x1 s_y1 <"$tmp/shape.out"
}

read_shape
rest_count=$s_count rest_x0=$s_x0 rest_y0=$s_y0 rest_x1=$s_x1 rest_y1=$s_y1
# 48 px icons at 150 % leave 24 px of magnify room above the pill.
[ "$rest_y0" -ge 24 ] || fail "at rest the dock shape reaches above the pill (top $rest_y0)"
[ "$rest_count" -gt 2 ] || fail "the dock shape is a plain rectangle, so its blur has square corners"

eval "$(DISPLAY=$display xdotool getwindowgeometry --shell "$win")"
DISPLAY=$display xdotool mousemove $((X + (rest_x0 + rest_x1) / 2)) $((Y + (rest_y0 + rest_y1) / 2))
sleep 0.8
read_shape
[ "$s_y0" -lt "$rest_y0" ] || fail "hovered, the shape does not grow, so magnified icons are clipped"

DISPLAY=$display xdotool mousemove 5 5
sleep 0.8
read_shape
[ "$s_y0" -eq "$rest_y0" ] || fail "after the pointer leaves, the shape does not return to the pill"

printf '%s\n' 'Quickshell dock Xvfb: PASS'
