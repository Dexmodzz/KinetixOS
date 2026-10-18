#!/bin/sh
# Ask the KinetixOS installer ISO questions and turn the answers into build
# settings. The Kickstart %pre section runs "ask" before Anaconda's UI; %post
# runs "env" to pass the validated values to install.sh.
#
#   iso-questions.sh ask ANSWERS_FILE     ask on the console, write the answers
#   iso-questions.sh gaming ANSWERS_FILE  print yes or no
#   iso-questions.sh env ANSWERS_FILE     print validated DWM_* assignments
#
# KINETIXOS_QUESTIONS_TTY selects the console (default /dev/tty8). The value
# "stdio" uses the current stdin and stdout, for tests.
#
# There is no timeout and no fallback: when input ends before every question
# is answered, nothing is written and the command fails.
#
# Validation ranges must stay equal to scripts/configure-build.sh;
# tests/test-iso-questions.sh checks both.

set -eu

die() {
	printf 'iso-questions: %s\n' "$*" >&2
	exit 1
}

usage() {
	printf 'Usage: %s ask|gaming|env ANSWERS_FILE\n' "${0##*/}" >&2
	exit 2
}

lower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

trim() {
	printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# valid_int VALUE MIN MAX: a plain decimal integer without leading zeros.
valid_int() {
	case $1 in
	'' | *[!0-9]* | 0?*) return 1 ;;
	esac
	[ "${#1}" -le 4 ] || return 1
	[ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

valid_font_size() {
	valid_int "$1" 6 48
}

valid_nmaster() {
	valid_int "$1" 1 10
}

valid_mfact() {
	[ "${#1}" -le 8 ] || return 1
	printf '%s\n' "$1" | grep -Eqx '(0|1)(\.[0-9]+)?' || return 1
	awk -v value="$1" 'BEGIN { exit !(value >= 0.05 && value <= 0.95) }'
}

valid_modkey() {
	case $1 in
	super | alt) return 0 ;;
	*) return 1 ;;
	esac
}

valid_gaming() {
	case $1 in
	yes | no) return 0 ;;
	*) return 1 ;;
	esac
}

# read_answer PROMPT: print PROMPT and set "answer" to the trimmed reply.
read_answer() {
	printf '%s' "$1"
	if ! IFS= read -r line; then
		printf '\n'
		die "input ended before every question was answered; installation stopped."
	fi
	answer=$(trim "$line")
}

console_number() {
	case $1 in
	/dev/tty[1-9] | /dev/tty[1-9][0-9]) printf '%s\n' "${1#/dev/tty}" ;;
	*) printf '\n' ;;
	esac
}

switch_console() {
	[ -n "$1" ] || return 0
	if command -v chvt >/dev/null 2>&1; then
		chvt "$1" || printf 'iso-questions: could not switch to console %s\n' "$1" >&2
	else
		printf 'iso-questions: chvt is not available; questions are on console %s\n' "$1" >&2
	fi
}

print_banner() {
	cat <<'EOF'

KinetixOS installer setup

This installer needs a screen and keyboard: a physical machine, or a
virtual machine console such as Proxmox. It waits until every question
is answered. Press Enter to accept the default shown in brackets.

EOF
}

ask() {
	output=$1
	tty=${KINETIXOS_QUESTIONS_TTY:-/dev/tty8}
	console=

	if [ "$tty" != stdio ]; then
		[ -c "$tty" ] || die "console $tty is not available."
		# A console device is read and written at once on purpose.
		# shellcheck disable=SC2094
		exec <"$tty" >"$tty" 2>&1
		console=$(console_number "$tty")
		switch_console "$console"
	fi

	print_banner

	while :; do
		read_answer 'Enable RPM Fusion nonfree for Fedora gaming packages? [y/N] '
		case $(lower "$answer") in
		y | yes)
			gaming=yes
			break
			;;
		'' | n | no)
			gaming=no
			break
			;;
		esac
		printf 'Please answer y or n.\n'
	done

	while :; do
		read_answer 'Interface font size [12]: '
		font_size=${answer:-12}
		valid_font_size "$font_size" && break
		printf 'Please enter a whole number from 6 to 48.\n'
	done

	while :; do
		read_answer 'Primary modifier key (super or alt) [super]: '
		modkey=$(lower "${answer:-super}")
		valid_modkey "$modkey" && break
		printf 'Please answer super or alt.\n'
	done

	while :; do
		read_answer 'Default master-area ratio [0.55]: '
		mfact=${answer:-0.55}
		valid_mfact "$mfact" && break
		printf 'Please enter a decimal from 0.05 to 0.95.\n'
	done

	while :; do
		read_answer 'Default number of master windows [1]: '
		nmaster=${answer:-1}
		valid_nmaster "$nmaster" && break
		printf 'Please enter a whole number from 1 to 10.\n'
	done

	tmp="$output.tmp.$$"
	(
		umask 077
		printf '%s\n' \
			"KINETIXOS_GAMING=$gaming" \
			"DWM_FONT_SIZE=$font_size" \
			"DWM_MODKEY=$modkey" \
			"DWM_MFACT=$mfact" \
			"DWM_NMASTER=$nmaster" >"$tmp"
	) || {
		rm -f "$tmp"
		die "could not write $output."
	}
	mv -f "$tmp" "$output" || {
		rm -f "$tmp"
		die "could not write $output."
	}
	printf '\nAnswers saved. The installer continues now.\n'

	[ -z "$console" ] || switch_console 1
}

# load_answers FILE: parse and validate every line; never source the file.
load_answers() {
	[ -r "$1" ] || die "answers file $1 is not readable."
	gaming=
	font_size=
	modkey=
	mfact=
	nmaster=
	while IFS= read -r line || [ -n "$line" ]; do
		case $line in
		*=*) ;;
		*) die "invalid line in $1." ;;
		esac
		key=${line%%=*}
		value=${line#*=}
		case $key in
		KINETIXOS_GAMING)
			[ -z "$gaming" ] || die "duplicate $key in $1."
			valid_gaming "$value" || die "invalid $key in $1."
			gaming=$value
			;;
		DWM_FONT_SIZE)
			[ -z "$font_size" ] || die "duplicate $key in $1."
			valid_font_size "$value" || die "invalid $key in $1."
			font_size=$value
			;;
		DWM_MODKEY)
			[ -z "$modkey" ] || die "duplicate $key in $1."
			valid_modkey "$value" || die "invalid $key in $1."
			modkey=$value
			;;
		DWM_MFACT)
			[ -z "$mfact" ] || die "duplicate $key in $1."
			valid_mfact "$value" || die "invalid $key in $1."
			mfact=$value
			;;
		DWM_NMASTER)
			[ -z "$nmaster" ] || die "duplicate $key in $1."
			valid_nmaster "$value" || die "invalid $key in $1."
			nmaster=$value
			;;
		*)
			die "unknown key in $1."
			;;
		esac
	done <"$1"
	[ -n "$gaming" ] && [ -n "$font_size" ] && [ -n "$modkey" ] &&
		[ -n "$mfact" ] && [ -n "$nmaster" ] ||
		die "answers file $1 is incomplete."
}

[ "$#" -eq 2 ] || usage

case $1 in
ask)
	ask "$2"
	;;
gaming)
	load_answers "$2"
	printf '%s\n' "$gaming"
	;;
env)
	load_answers "$2"
	# The ISO has no X session to detect the refresh rate; users change it
	# later in Settings. Cursor warp is never asked and stays off.
	printf 'DWM_REFRESH_RATE=60 DWM_CURSORWARP=0 DWM_FONT_SIZE=%s DWM_MODKEY=%s DWM_MFACT=%s DWM_NMASTER=%s\n' \
		"$font_size" "$modkey" "$mfact" "$nmaster"
	;;
*)
	usage
	;;
esac
