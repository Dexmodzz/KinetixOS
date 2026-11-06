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
grep -Fq 'apple: false' "$panel" || fail "the macos layout must keep the KinetixOS logo"
grep -Fq 'dot: false' "$panel" || fail "the macos layout must keep numbered workspaces"
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
grep -Fq 'readonly property int fullThickness: root.reservedSize + root.magnifyRoom' "$dock" ||
	fail "dock window has no room for magnified icons"
grep -Fq 'implicitHeight: root.vertical ? 0 : root.fullThickness - (root.blurVisible ? 0 : 1)' "$dock" ||
	fail "dock window does not take its full size at rest"
grep -Fq 'implicitWidth: root.vertical ? root.fullThickness - (root.blurVisible ? 0 : 1) : 0' "$dock" ||
	fail "side dock window does not take its full size at rest"
grep -Fq 'entry !== null' "$dock" || fail "unknown dock_apps IDs are not filtered"
grep -Fq 'Commands.launcherHelperCommand("launch-id", [' "$dock" || fail "dock does not launch through the helper"
grep -Fq 'root.desktopState.focusWindow(' "$dock" || fail "dock does not focus running windows"
grep -Fq 'active: dockSettings.enabled' "$shell/shell.qml" || fail "shell does not load the dock from its settings"
settings=$shell/dock/DockSettings.qml
menu=$shell/dock/DockMenu.qml
[ -f "$settings" ] || fail "dock/DockSettings.qml missing"
[ -f "$menu" ] || fail "dock/DockMenu.qml missing"
grep -Fq '|| (root.visibilityMode !== "off" && Theme.styleDock)' "$settings" ||
	fail "dock visibility does not default to the style"
grep -Fq 'root.customApps ? root.storedApps : Theme.styleDockApps' "$settings" ||
	fail "pinned apps do not default to the style's dock_apps"
grep -Fq '/kinetixos/dock.json' "$settings" || fail "dock settings are not stored under kinetixos"
grep -Fq 'acceptedButtons: Qt.RightButton' "$dock" || fail "the dock has no context menu"
grep -Fq 'for (const entry of DesktopEntries.applications.values)' "$menu" ||
	fail "the dock menu does not list installed apps"
grep -Fq 'root.dockSettings.showTrash, root.trashFull' "$dock" || fail "the dock has no optional Trash"
grep -Fq 'root.dockSettings.setShowTrash(' "$menu" || fail "the dock menu cannot show or hide the Trash"
grep -Fq 'root.desktopState.closeApp(' "$menu" || fail "the dock menu cannot quit an app"
grep -Fq 'root.confirmQuit = true' "$menu" || fail "quitting an app on another desktop does not ask first"
grep -Fq "printf 'app_desktops=%s" "$repo/scripts/dwm-quickshell-state" || fail "the state helper does not report app desktops"
grep -Fq 'root.dockSettings.setAutoHide(' "$menu" || fail "the dock menu has no auto-hide switch"
grep -Fq 'exclusiveZone: root.autoHide ? 1 : root.reservedSize' "$dock" || fail "an auto-hidden dock still reserves its space"
grep -Fq 'root.dockSettings.toggleEnabled()' "$shell/controlcenter/ControlCenterWindow.qml" ||
	fail "Bar Widgets lacks the dock switch"
grep -Fq 'root.dockSettings.setPosition(' "$shell/controlcenter/ControlCenterWindow.qml" ||
	fail "Bar Widgets lacks the dock position"

printf '%s\n' 'Quickshell tahoe layout: PASS'
