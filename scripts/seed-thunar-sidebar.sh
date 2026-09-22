#!/bin/sh
# Seed the Thunar side pane once per account: Home and Trash on top, then the
# XDG Documents, Pictures, Music and Download folders as bookmarks. Recent,
# Desktop and Computer/File System are hidden. Paths come from xdg-user-dirs,
# so any locale and user name work. Existing user choices are never replaced.
set -eu

# XDG base directories must be absolute; ignore relative values.
config_home=$HOME/.config
case ${XDG_CONFIG_HOME:-} in /*) config_home=$XDG_CONFIG_HOME ;; esac
state_dir=$HOME/.local/state
case ${XDG_STATE_HOME:-} in /*) state_dir=$XDG_STATE_HOME ;; esac
state_dir=$state_dir/kinetixos
stamp=$state_dir/thunar-sidebar-seeded
bookmarks=$config_home/gtk-3.0/bookmarks

[ ! -e "$stamp" ] || exit 0
for cmd in thunar xfconf-query xdg-user-dir python3; do
	command -v "$cmd" >/dev/null 2>&1 || exit 0
done

# Print an existing XDG user directory; unset entries resolve to $HOME.
user_dir() {
	dir=$(xdg-user-dir "$1" 2>/dev/null) || return 1
	[ -n "$dir" ] && [ "$dir" != "$HOME" ] && [ -d "$dir" ] || return 1
	printf '%s\n' "$dir"
}

file_uri() {
	python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$1"
}

# Bookmarks without labels let GTK show the localized folder name.
if [ -s "$bookmarks" ]; then
	printf 'Preserving existing GTK bookmarks: %s\n' "$bookmarks"
else
	mkdir -p "${bookmarks%/*}"
	tmp=$(mktemp "${bookmarks%/*}/.dwm-bookmarks.XXXXXX")
	trap 'rm -f "$tmp"' EXIT
	for name in DOCUMENTS PICTURES MUSIC DOWNLOAD; do
		dir=$(user_dir "$name") || continue
		file_uri "$dir" >>"$tmp"
	done
	mv -f "$tmp" "$bookmarks"
	trap - EXIT
fi

# computer:/// is the Computer entry; file:/// is the File System device.
if xfconf-query -c thunar -p /hidden-bookmarks >/dev/null 2>&1; then
	printf '%s\n' 'Preserving existing Thunar hidden side pane entries'
else
	set -- -t string -s recent:/// -t string -s computer:/// -t string -s file:///
	if desktop=$(user_dir DESKTOP); then
		set -- "$@" -t string -s "$(file_uri "$desktop")"
	fi
	xfconf-query -c thunar -p /hidden-bookmarks -n -a "$@"
fi

mkdir -p "$state_dir"
: >"$stamp"
