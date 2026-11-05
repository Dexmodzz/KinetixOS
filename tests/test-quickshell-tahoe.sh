#!/bin/sh
# Source guards for the macOS bar layout. The default layout must keep every
# existing panel widget; the macos layout only hides, never replaces, them.
set -eu

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")/.." && pwd
)
shell=$repo/config/quickshell
panel=$shell/panel/DwmPanel.qml

fail() {
	printf 'test-quickshell-tahoe: %s\n' "$*" >&2
	exit 1
}

grep -Fq 'readonly property bool macLayout: Theme.styleBarLayout === "macos"' "$panel" ||
	fail "macLayout must derive only from Theme.styleBarLayout"
grep -Fq 'RunningAppsArea {' "$panel" || fail "RunningAppsArea removed"
grep -Fq 'visible: !root.macLayout' "$panel" || fail "no widget is gated on the macos layout"
[ "$(grep -c 'visible: !root.macLayout' "$panel")" -ge 2 ] ||
	fail "centre clock and status segments must hide in the macos layout"
grep -Fq 'visible: Theme.styleBarLayout !== "macos"' "$shell/panel/RunningAppsArea.qml" ||
	fail "running apps must hide in the macos layout"
grep -Fq 'text: root.clock.macText' "$panel" || fail "macos layout lacks the menu bar clock"
grep -Fq 'apple: root.macLayout' "$panel" || fail "logo does not switch to the apple glyph"
grep -Fq 'dot: root.macLayout' "$panel" || fail "workspaces do not render as dots"
grep -Fq 'opacity: root.macLayout ? Theme.styleBarOpacity / 100 : 1' "$panel" ||
	fail "macos bar background ignores bar_opacity"
grep -Fq 'root.macText = Qt.formatDateTime(current, "ddd d MMM HH:mm");' "$shell/core/ClockModel.qml" ||
	fail "ClockModel lacks macText"
grep -Fq 'property bool apple: false' "$shell/panel/LogoButton.qml" || fail "LogoButton lacks apple"
grep -Fq 'property bool dot: false' "$shell/panel/WorkspaceButton.qml" || fail "WorkspaceButton lacks dot"

dock=$shell/dock/Dock.qml
item=$shell/dock/DockItem.qml
[ -f "$dock" ] || fail "dock/Dock.qml missing"
[ -f "$item" ] || fail "dock/DockItem.qml missing"
if grep -En '(^|[^A-Za-z])(Timer|Variants)[[:space:]]*\{' "$dock" "$item"; then
	fail "the dock must not poll or create one window per screen"
fi
grep -Fq 'exclusiveZone: root.reservedHeight' "$dock" || fail "dock does not reserve its rest height"
grep -Fq 'implicitHeight: root.reservedHeight + root.magnifyRoom' "$dock" ||
	fail "dock window has no room for magnified icons"
grep -Fq 'entry !== null' "$dock" || fail "unknown dock_apps IDs are not filtered"
grep -Fq 'Commands.launcherHelperCommand("launch-id", [' "$dock" || fail "dock does not launch through the helper"
grep -Fq 'root.desktopState.focusWindow(' "$dock" || fail "dock does not focus running windows"
grep -Fq 'active: Theme.styleDock' "$shell/shell.qml" || fail "shell does not load the dock from the style"

printf '%s\n' 'Quickshell tahoe layout: PASS'
