#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT

cat >"$work/os-release" <<'EOF'
ID=fedora
PRETTY_NAME="Fedora Linux 44"
EOF

mkdir -p "$work/bin" "$work/home"
cat >"$work/bin/systemctl" <<'EOF'
#!/bin/sh
printf 'systemctl\t%s\n' "$*" >>"${DWM_TEST_LOG:-/dev/null}"
case "$*" in
get-default) printf '%s\n' "${DWM_TEST_DEFAULT_TARGET:-multi-user.target}" ;;
*) exit 0 ;;
esac
EOF
cat >"$work/bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo\t%s\n' "$*" >>"${DWM_TEST_LOG:?}"
exit "${DWM_TEST_SUDO_STATUS:-0}"
EOF
chmod +x "$work/bin/"*

expect_plan() {
	local expected=$1 output="$work/plan.out"
	shift
	env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
		PATH="$work/bin:$PATH" "$@" \
		"$repo/install.sh" --dry-run --non-interactive --profile core >"$output"
	if ! command grep -Fxq "  Graphical login at boot: $expected" "$output"; then
		printf 'Expected graphical login plan "%s", got:\n' "$expected" >&2
		command grep -F 'Graphical login at boot:' "$output" >&2 || true
		exit 1
	fi
}

expect_plan 'unchanged (use --enable-graphical-login when unattended)'
expect_plan 'already enabled (graphical.target)' DWM_TEST_DEFAULT_TARGET=graphical.target
expect_plan 'approved (sets graphical.target when a display manager is enabled)' \
	DWM_GRAPHICAL_LOGIN=true
expect_plan 'skipped (--skip-graphical-login)' DWM_GRAPHICAL_LOGIN=no

env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
	PATH="$work/bin:$PATH" \
	"$repo/install.sh" --dry-run --non-interactive --profile core --enable-graphical-login \
	>"$work/flag.out"
command grep -Fq '  Graphical login at boot: approved' "$work/flag.out"

if env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
	DWM_GRAPHICAL_LOGIN=sometimes PATH="$work/bin:$PATH" \
	"$repo/install.sh" --dry-run --non-interactive --profile core \
	>"$work/invalid.out" 2>&1; then
	printf 'install.sh accepted an invalid DWM_GRAPHICAL_LOGIN value\n' >&2
	exit 1
fi
command grep -Fq 'Unsupported DWM_GRAPHICAL_LOGIN: sometimes' "$work/invalid.out"

# Exercise the real function bodies against a fixture display-manager link.
functions="$work/graphical-login-functions.sh"
for name in default_boot_target configure_graphical_login; do
	sed -n "/^$name() {\$/,/^}\$/p" "$repo/install.sh" >>"$functions"
	command grep -Fq "$name() {" "$functions"
done
ln -s /usr/lib/systemd/system/lightdm.service "$work/display-manager.service"

run_function() {
	local mode=$1 non_interactive=$2 answer=$3 link=$4 dm=$5
	shift 5
	: >"$work/commands.log"
	# shellcheck disable=SC2016 # Expanded by the inner shell.
	env DWM_TEST_LOG="$work/commands.log" PATH="$work/bin:$PATH" "$@" \
		bash -c '
			set -euo pipefail
			info() { printf "[INFO] %s\n" "$1"; }
			ok() { printf "[OK] %s\n" "$1"; }
			warn() { printf "[WARN] %s\n" "$1"; }
			GRAPHICAL_LOGIN_MODE=$1 NON_INTERACTIVE=$2 DISPLAY_MANAGER_LINK=$3
			. "$4"
			configure_graphical_login "$5"
		' sh "$mode" "$non_interactive" "$link" "$functions" "$dm" <<<"$answer"
}

set_default_ran() {
	command grep -Fxq $'sudo\tsystemctl set-default graphical.target' "$work/commands.log"
}

expect_target_unchanged() {
	if set_default_ran; then
		printf 'Default boot target changed without approval: %s\n' "$1" >&2
		exit 1
	fi
}

run_function auto false '' "$work/display-manager.service" lightdm >"$work/accept.out"
command grep -Fq 'Start the graphical login (lightdm) at boot? [Y/n]' "$work/accept.out"
set_default_ran
command grep -Fq 'Undo with: sudo systemctl set-default multi-user.target' "$work/accept.out"

run_function auto false n "$work/display-manager.service" lightdm >"$work/decline.out"
command grep -Fq 'Graphical login at boot declined' "$work/decline.out"
expect_target_unchanged decline

run_function auto true '' "$work/display-manager.service" lightdm >"$work/unattended.out"
command grep -Fq 'Re-run with --enable-graphical-login' "$work/unattended.out"
expect_target_unchanged unattended
if command grep -Fq '[Y/n]' "$work/unattended.out"; then
	printf 'Unattended install prompted for the graphical login\n' >&2
	exit 1
fi

run_function true true '' "$work/display-manager.service" lightdm >"$work/approved.out"
set_default_ran
if command grep -Fq '[Y/n]' "$work/approved.out"; then
	printf 'Explicit --enable-graphical-login approval still prompted\n' >&2
	exit 1
fi

run_function false false y "$work/display-manager.service" lightdm >"$work/skipped.out"
command grep -Fq 'Graphical login at boot skipped' "$work/skipped.out"
expect_target_unchanged skipped

run_function true false '' "$work/display-manager.service" lightdm \
	DWM_TEST_DEFAULT_TARGET=graphical.target >"$work/already.out"
command grep -Fq 'Graphical login starts at boot (lightdm).' "$work/already.out"
expect_target_unchanged already

run_function true false '' "$work/missing-link" gdm >"$work/not-enabled.out"
command grep -Fq 'gdm is installed but no display manager is enabled' "$work/not-enabled.out"
expect_target_unchanged not-enabled

run_function true false '' "$work/display-manager.service" '' >"$work/no-dm.out"
[[ ! -s $work/no-dm.out ]]
expect_target_unchanged no-dm

run_function true false '' "$work/display-manager.service" lightdm \
	DWM_TEST_SUDO_STATUS=1 >"$work/sudo-failure.out"
command grep -Fq 'Could not change the default boot target' "$work/sudo-failure.out"

printf 'install-graphical-login tests: PASS\n'
