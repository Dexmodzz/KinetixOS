#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
seeder=$repo/scripts/seed-thunar-sidebar.sh
test_tmp_root=${DWM_TEST_TMP_ROOT:-${HOME}/tmp}
mkdir -p -- "$test_tmp_root"
work=$(mktemp -d "$test_tmp_root/thunar-sidebar-test.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# Fake xfconf store: one file per property, one value per line.
mkdir -p "$work/bin"
cat >"$work/bin/xfconf-query" <<'SH'
#!/bin/sh
store=$FAKE_XFCONF/$2$(printf '%s' "$4" | tr / _)
[ "$#" -eq 4 ] && { [ -f "$store" ] && cat "$store"; exit $?; }
shift 6
: >"$store"
while [ "$#" -gt 0 ]; do printf '%s\n' "$4" >>"$store"; shift 4; done
SH
cat >"$work/bin/thunar" <<'SH'
#!/bin/sh
SH
# Minimal xdg-user-dir: reads user-dirs.dirs like the real helper.
cat >"$work/bin/xdg-user-dir" <<'SH'
#!/bin/sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs" 2>/dev/null
eval "printf '%s\n' \"\${XDG_$1_DIR:-$HOME}\""
SH
chmod +x "$work/bin/"*
# Isolated PATH so a host Thunar or xfconf install cannot leak into the test.
mkdir -p "$work/sys"
for cmd in sh cat tr mkdir mktemp mv rm python3; do
	ln -s "$(command -v "$cmd")" "$work/sys/$cmd"
done

run_seeder() {
	env -i PATH="$work/bin:$work/sys" HOME="$home" FAKE_XFCONF="$home/xfconf" \
		sh "$seeder" >/dev/null
}

new_home() {
	home=$work/$1
	mkdir -p "$home/.config" "$home/xfconf"
	shift
	: >"$home/.config/user-dirs.dirs"
	while [ "$#" -gt 0 ]; do
		mkdir -p "$home/$2"
		printf 'XDG_%s_DIR="$HOME/%s"\n' "$1" "$2" >>"$home/.config/user-dirs.dirs"
		shift 2
	done
}

# German locale, a user name with a space, and a folder needing URI escaping.
new_home 'max mustermann' DESKTOP Schreibtisch DOCUMENTS Dokumente \
	PICTURES Bilder MUSIC 'Musik Sammlung' DOWNLOAD Downloads
run_seeder
h=$(printf '%s' "$home" | sed 's/ /%20/g')
expected="file://$h/Dokumente
file://$h/Bilder
file://$h/Musik%20Sammlung
file://$h/Downloads"
[[ $(cat "$home/.config/gtk-3.0/bookmarks") == "$expected" ]] ||
	fail "unexpected bookmarks: $(cat "$home/.config/gtk-3.0/bookmarks")"
expected="recent:///
computer:///
file:///
file://$h/Schreibtisch"
[[ $(cat "$home/xfconf/thunar_hidden-bookmarks") == "$expected" ]] ||
	fail "unexpected hidden entries: $(cat "$home/xfconf/thunar_hidden-bookmarks")"
[[ -f $home/.local/state/kinetixos/thunar-sidebar-seeded ]] || fail 'stamp missing'

# The stamp makes later runs no-ops even after the user edits the pane.
printf '%s\n' 'file:///srv' >"$home/.config/gtk-3.0/bookmarks"
run_seeder
[[ $(cat "$home/.config/gtk-3.0/bookmarks") == 'file:///srv' ]] || fail 'stamp ignored'

# Existing bookmarks and hidden entries are preserved; unset XDG dirs skipped.
new_home existing DOCUMENTS Documents
mkdir -p "$home/.config/gtk-3.0"
printf '%s\n' 'file:///opt' >"$home/.config/gtk-3.0/bookmarks"
printf '%s\n' 'trash:///' >"$home/xfconf/thunar_hidden-bookmarks"
run_seeder
[[ $(cat "$home/.config/gtk-3.0/bookmarks") == 'file:///opt' ]] || fail 'bookmarks replaced'
[[ $(cat "$home/xfconf/thunar_hidden-bookmarks") == 'trash:///' ]] || fail 'hidden replaced'

new_home sparse DOCUMENTS Documents
run_seeder
[[ $(cat "$home/.config/gtk-3.0/bookmarks") == "file://$home/Documents" ]] ||
	fail 'unset XDG directories were bookmarked'
[[ $(cat "$home/xfconf/thunar_hidden-bookmarks") == $'recent:///\ncomputer:///\nfile:///' ]] ||
	fail 'missing Desktop should not be hidden'

# Relative XDG base directories are invalid and fall back to the defaults.
new_home relative DOCUMENTS Documents
(cd "$home" && env -i PATH="$work/bin:$work/sys" HOME="$home" FAKE_XFCONF="$home/xfconf" \
	XDG_CONFIG_HOME=relative XDG_STATE_HOME=relative sh "$seeder" >/dev/null)
[[ ! -e $home/relative && -e $home/.config/gtk-3.0/bookmarks ]] ||
	fail 'relative XDG base directories were used'
[[ -f $home/.local/state/kinetixos/thunar-sidebar-seeded ]] || fail 'relative state dir used'

# Without Thunar the seeder does nothing and does not stamp.
new_home nothunar DOCUMENTS Documents
rm "$work/bin/thunar"
run_seeder
[[ ! -e $home/.config/gtk-3.0/bookmarks && ! -e $home/.local/state/kinetixos ]] ||
	fail 'seeded without Thunar'

printf '%s\n' 'Thunar sidebar seeding tests passed.'
