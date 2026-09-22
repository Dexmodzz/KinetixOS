#!/bin/sh
# Migrate an existing dwm-titus installation to the KinetixOS names once.
#
#   migrate-legacy-name.sh             user directories and markers
#   migrate-legacy-name.sh --system P  system files for install prefix P (root)
#
# A legacy path is moved only when its new name does not exist yet, so the
# migration is idempotent and never overwrites KinetixOS state.
set -eu

legacy=dwm-titus
current=kinetixos

log() {
	printf '  %s\n' "$*"
}

# Move $1 to $2 when $1 is a real directory or file and $2 is absent.
move_once() {
	[ -e "$1" ] || return 0
	if [ -L "$1" ]; then
		log "Preserving legacy symlink $1"
	elif [ -e "$2" ] || [ -L "$2" ]; then
		log "Keeping $2; legacy $1 left in place"
	else
		mkdir -p "${2%/*}"
		mv "$1" "$2"
		log "Migrated $1 -> $2"
	fi
}

# Rewrite legacy block markers so managed sections are still recognized.
rewrite_markers() {
	[ -f "$1" ] && [ ! -L "$1" ] || return 0
	grep -q "# $legacy opacity defaults" "$1" || return 0
	tmp=$(mktemp "${1%/*}/.kinetixos-migrate.XXXXXX")
	sed "s/^# $legacy opacity defaults \(begin\|end\)\$/# $current opacity defaults \1/" \
		"$1" >"$tmp"
	chmod --reference="$1" "$tmp" 2>/dev/null || true
	mv -f "$tmp" "$1"
	log "Updated managed markers in $1"
}

xdg_dir() {
	case ${1:-} in
	/*) printf '%s\n' "$1" ;;
	*) printf '%s\n' "$2" ;;
	esac
}

migrate_user() {
	[ "$(id -u)" != 0 ] || {
		printf 'migrate-legacy-name: run the user migration as the target user\n' >&2
		exit 1
	}
	config_home=$(xdg_dir "${XDG_CONFIG_HOME:-}" "$HOME/.config")
	data_home=$(xdg_dir "${XDG_DATA_HOME:-}" "$HOME/.local/share")
	state_home=$(xdg_dir "${XDG_STATE_HOME:-}" "$HOME/.local/state")
	move_once "$config_home/$legacy" "$config_home/$current"
	move_once "$data_home/$legacy" "$data_home/$current"
	move_once "$state_home/$legacy" "$state_home/$current"
	rewrite_markers "$config_home/picom.conf"
	rewrite_markers "$config_home/picom/picom.conf"
}

migrate_system() {
	prefix=$1
	[ "$(id -u)" = 0 ] || {
		printf 'migrate-legacy-name: the system migration requires root\n' >&2
		exit 1
	}
	move_once "/var/lib/$legacy" "/var/lib/$current"
	move_once "/etc/X11/xorg.conf.d/90-$legacy-display.conf" \
		"/etc/X11/xorg.conf.d/90-$current-display.conf"
	# The new install already provides these; the legacy copies are stale.
	for stale in "$prefix/libexec/$legacy" "$prefix/share/$legacy"; do
		if [ -d "$stale" ] && [ ! -L "$stale" ]; then
			rm -rf -- "$stale"
			log "Removed legacy $stale"
		fi
	done
}

case ${1:-} in
'') migrate_user ;;
--system)
	[ "$#" -eq 2 ] && [ -n "$2" ] || {
		printf 'Usage: migrate-legacy-name.sh [--system PREFIX]\n' >&2
		exit 2
	}
	migrate_system "$2"
	;;
*)
	printf 'Usage: migrate-legacy-name.sh [--system PREFIX]\n' >&2
	exit 2
	;;
esac
