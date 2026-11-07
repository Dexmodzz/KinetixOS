#!/bin/sh
set -eu

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")/.." && pwd
)

theme=$repo/config/quickshell/core/Theme.qml
core=$repo/config/quickshell/core
shell=$repo/config/quickshell
design_doc=$repo/docs/OMARCHY-UI-ADAPTATION.md

qml_packages=$(bash -c '. "$1"; dwm_packages fedora qml-validation' sh \
	"$repo/scripts/dwm-packages.sh")
[ "$(printf '%s\n' "$qml_packages" | wc -l)" -eq 3 ]
printf '%s\n' "$qml_packages" | grep -Fx quickshell >/dev/null
printf '%s\n' "$qml_packages" | grep -Fx xsettingsd >/dev/null
printf '%s\n' "$qml_packages" | grep -Fx qt6-qtdeclarative-devel >/dev/null

for token in \
	popupBackground popupBorder menuActionText menuHoverBackground \
	menuSelectedBackground menuSelectedText menuHeaderHeight \
	controlNormalFill controlHoverFill controlFocusBorder \
	controlSelectedFill controlDisabledFill spacingXxs spacingHuge \
	fontCaptionSize fontBodySmallSize fontBodySize fontTitleSize controlHeight \
	controlRowHeight controlPaddingX controlRadius popupPadding; do
	grep -Eq "readonly property (string|int) $token:" "$theme"
done

grep -Fq 'Theme.popupBackground' "$core/ShellSurface.qml"
grep -Fq 'Theme.popupBorder' "$core/ShellSurface.qml"
grep -Fq 'Theme.controlNormalFill' "$core/ShellButton.qml"
grep -Fq 'Theme.controlFocusBorder' "$core/ShellButton.qml"
grep -Fq 'Theme.menuHoverBackground' "$core/MenuRow.qml"
grep -Fq 'root.active ? Theme.menuSelectedBackground' "$core/MenuRow.qml"
grep -Fq 'Theme.menuSelectedText' "$core/MenuRow.qml"
grep -Fq 'Theme.menuHeaderHeight' "$core/MenuHeader.qml"
grep -Fq 'Theme.fontBodySmallSize' "$core/SectionLabel.qml"

# Bar layout, dock and blur style tokens default to the classic look.
grep -Fq 'property string styleBarLayout: "default"' "$theme"
grep -Fq 'property int styleBarOpacity: 100' "$theme"
grep -Fq 'property bool styleDock: false' "$theme"
grep -Fq 'property int styleDockIconSize: 48' "$theme"
grep -Fq 'property int styleDockMagnify: 100' "$theme"
grep -Fq 'property int styleDockRadius: 0' "$theme"
grep -Fq 'property int styleDockOpacity: 100' "$theme"
grep -Fq 'property var styleDockApps: []' "$theme"
grep -Fq 'property bool styleBlur: false' "$theme"
grep -Fq 'root.styleBarLayout = v.bar_layout === "macos" ? "macos" : "default";' "$theme"
grep -Fq 'root.styleDock = v.dock === "true";' "$theme"
grep -Fq 'root.styleBlur = v.blur === "true";' "$theme"
grep -Fq 'root.styleDockApps = typeof v.dock_apps === "string" && v.dock_apps.length > 0 ? v.dock_apps.split(",") : [];' "$theme"
grep -Fq 'function withAlpha(color, percent)' "$theme"

grep -Fq 'This is a design influence, not a shell transplant.' "$design_doc"
grep -Fq 'current root-scoped models' "$design_doc"

if grep -REn \
	-e 'Quickshell\.(Wayland|Hyprland)' \
	-e 'WlrLayershell' \
	-e '(^|[^[:alnum:]_-])(hyprctl|uwsm-app|wl-copy|wl-paste)([^[:alnum:]_-]|$)' \
	"$shell"; then
	printf '%s\n' 'Managed Quickshell configuration contains a forbidden Wayland or Hyprland dependency.' >&2
	exit 1
fi

printf '%s\n' 'Quickshell design system: PASS'
