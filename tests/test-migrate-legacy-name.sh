#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
migrate=$repo/scripts/migrate-legacy-name.sh
test_tmp_root=${DWM_TEST_TMP_ROOT:-${HOME}/tmp}
mkdir -p -- "$test_tmp_root"
work=$(mktemp -d "$test_tmp_root/migrate-legacy-name-test.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

run_user() {
	env -i PATH=/usr/bin:/bin HOME="$home" "$@" sh "$migrate" >/dev/null
}

# Legacy user directories move to the new names with their contents.
home=$work/home
mkdir -p "$home/.config/dwm-titus" "$home/.local/share/dwm-titus/scripts" \
	"$home/.local/state/dwm-titus" "$home/.config/picom"
printf 'hotkeys\n' >"$home/.config/dwm-titus/hotkeys.toml"
: >"$home/.local/state/dwm-titus/thunar-sidebar-seeded"
printf '%s\n' 'vsync = true;' '# dwm-titus opacity defaults begin' 'opacity-rule = [];' \
	'# dwm-titus opacity defaults end' >"$home/.config/picom/picom.conf"
run_user
[[ $(cat "$home/.config/kinetixos/hotkeys.toml") == hotkeys ]] || fail 'config not moved'
[[ -d $home/.local/share/kinetixos/scripts ]] || fail 'data not moved'
[[ -f $home/.local/state/kinetixos/thunar-sidebar-seeded ]] || fail 'state not moved'
[[ ! -e $home/.config/dwm-titus && ! -e $home/.local/share/dwm-titus && ! -e $home/.local/state/dwm-titus ]] ||
	fail 'legacy directories left behind'
grep -Fqx '# kinetixos opacity defaults begin' "$home/.config/picom/picom.conf" || fail 'begin marker'
grep -Fqx '# kinetixos opacity defaults end' "$home/.config/picom/picom.conf" || fail 'end marker'
grep -Fqx 'vsync = true;' "$home/.config/picom/picom.conf" || fail 'picom content changed'

# Re-running is a no-op.
run_user
[[ $(cat "$home/.config/kinetixos/hotkeys.toml") == hotkeys ]] || fail 'rerun changed config'

# Existing KinetixOS state always wins over a legacy copy.
mkdir -p "$home/.config/dwm-titus"
printf 'old\n' >"$home/.config/dwm-titus/hotkeys.toml"
run_user
[[ $(cat "$home/.config/kinetixos/hotkeys.toml") == hotkeys ]] || fail 'legacy overwrote new config'
[[ -f $home/.config/dwm-titus/hotkeys.toml ]] || fail 'legacy copy removed despite conflict'

# Legacy symlinks are preserved rather than followed.
home=$work/linked
mkdir -p "$home/.config" "$work/elsewhere"
ln -s "$work/elsewhere" "$home/.config/dwm-titus"
run_user
[[ -L $home/.config/dwm-titus && ! -e $home/.config/kinetixos ]] || fail 'symlink handled incorrectly'

# Relative XDG base directories fall back to the defaults.
home=$work/relative
mkdir -p "$home/.config/dwm-titus"
(cd "$home" && run_user XDG_CONFIG_HOME=relative)
[[ -d $home/.config/kinetixos && ! -e $home/relative ]] || fail 'relative XDG_CONFIG_HOME used'

# The system migration refuses to run without root, and bad usage fails.
if [[ $(id -u) != 0 ]]; then
	if sh "$migrate" --system /usr/local 2>/dev/null; then
		fail 'system migration ran without root'
	fi
fi
if sh "$migrate" --bogus 2>/dev/null; then
	fail 'accepted an unknown argument'
fi

printf '%s\n' 'Legacy name migration tests passed.'
