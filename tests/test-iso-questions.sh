#!/usr/bin/env bash
set -euo pipefail

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)
helper="$repo/scripts/image/iso-questions.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export KINETIXOS_QUESTIONS_TTY=stdio

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# ask NAME INPUT: run the questions with INPUT; the answers file is $work/NAME.
ask() {
	printf '%b' "$2" | sh "$helper" ask "$work/$1" >"$work/$1.out" 2>&1
}

expect_answers() {
	local name=$1
	shift
	local expected
	expected=$(printf '%s\n' "$@")
	[[ -f $work/$name ]] || fail "$name: answers file missing"
	[[ "$(cat "$work/$name")" == "$expected" ]] ||
		fail "$name: got $(tr '\n' ' ' <"$work/$name")"
}

# ask_defaults
ask defaults '\n\n\n\n\n' || fail "ask_defaults: non-zero exit"
expect_answers defaults KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
	DWM_MFACT=0.55 DWM_NMASTER=1
[[ "$(stat -c %a "$work/defaults")" == 600 ]] || fail "ask_defaults: mode not 600"

# ask_custom
ask custom 'y\n14\nalt\n0.60\n2\n' || fail "ask_custom: non-zero exit"
expect_answers custom KINETIXOS_GAMING=yes DWM_FONT_SIZE=14 DWM_MODKEY=alt \
	DWM_MFACT=0.60 DWM_NMASTER=2

# ask_retries_invalid
ask retries 'maybe\nn\n500\n5\n49\n16\nctrl\nsuper\n1.5\n0.04\n0.5\n0\n11\n3\n' ||
	fail "ask_retries_invalid: non-zero exit"
expect_answers retries KINETIXOS_GAMING=no DWM_FONT_SIZE=16 DWM_MODKEY=super \
	DWM_MFACT=0.5 DWM_NMASTER=3

# ask_normalises_case_and_spaces
ask spaces 'YES\n 20 \n ALT \n0.7\n4\n' || fail "ask_normalises_case_and_spaces: non-zero exit"
expect_answers spaces KINETIXOS_GAMING=yes DWM_FONT_SIZE=20 DWM_MODKEY=alt \
	DWM_MFACT=0.7 DWM_NMASTER=4

# ask_fails_on_eof: never fall back to defaults when nobody answered.
if ask eof 'y\n14\n'; then
	fail "ask_fails_on_eof: succeeded on truncated input"
fi
[[ ! -e $work/eof ]] || fail "ask_fails_on_eof: answers file was written"
if ask empty ''; then
	fail "ask_fails_on_eof: succeeded on empty input"
fi
[[ ! -e $work/empty ]] || fail "ask_fails_on_eof: answers file was written on empty input"

# ask_banner
grep -Fq 'screen and keyboard' "$work/defaults.out" || fail "ask_banner: no screen and keyboard notice"
grep -Fq 'Proxmox' "$work/defaults.out" || fail "ask_banner: no Proxmox mention"
grep -Fq 'Enable RPM Fusion nonfree for Fedora gaming packages? [y/N]' "$work/defaults.out" ||
	fail "ask_banner: gaming prompt wording changed"

# gaming_reads_answer
[[ "$(sh "$helper" gaming "$work/custom")" == yes ]] || fail "gaming_reads_answer: custom not yes"
[[ "$(sh "$helper" gaming "$work/defaults")" == no ]] || fail "gaming_reads_answer: defaults not no"
if sh "$helper" gaming "$work/missing" >/dev/null 2>&1; then
	fail "gaming_reads_answer: missing file accepted"
fi

# env_line
[[ "$(sh "$helper" env "$work/custom")" == 'DWM_REFRESH_RATE=60 DWM_CURSORWARP=0 DWM_FONT_SIZE=14 DWM_MODKEY=alt DWM_MFACT=0.60 DWM_NMASTER=2' ]] ||
	fail "env_line: got $(sh "$helper" env "$work/custom")"

# env_rejects_injection
sed 's/^DWM_FONT_SIZE=.*/DWM_FONT_SIZE=12;reboot/' "$work/custom" >"$work/injected"
if out=$(sh "$helper" env "$work/injected" 2>/dev/null); then
	fail "env_rejects_injection: accepted"
fi
[[ -z $out ]] || fail "env_rejects_injection: printed $out"
# shellcheck disable=SC2016 # The literal command substitution is the payload.
printf 'DWM_EXTRA=$(reboot)\n' >>"$work/custom-extra"
cat "$work/custom" "$work/custom-extra" >"$work/unknown"
if out=$(sh "$helper" env "$work/unknown" 2>/dev/null); then
	fail "env_rejects_injection: unknown key accepted"
fi
[[ -z $out ]] || fail "env_rejects_injection: printed $out for unknown key"
cat "$work/custom" "$work/custom" >"$work/duplicate"
if sh "$helper" env "$work/duplicate" >/dev/null 2>&1; then
	fail "env_rejects_injection: duplicate keys accepted"
fi

# env_rejects_missing_key
grep -v '^DWM_NMASTER=' "$work/custom" >"$work/no-nmaster"
if out=$(sh "$helper" env "$work/no-nmaster" 2>/dev/null); then
	fail "env_rejects_missing_key: accepted"
fi
[[ -z $out ]] || fail "env_rejects_missing_key: printed $out"

# ranges_match_configure_build: boundaries agree with scripts/configure-build.sh.
configure_accepts() {
	env DWM_REFRESH_RATE=60 "$@" "$repo/scripts/configure-build.sh" --non-interactive \
		--template "$repo/config.def.h" --output "$work/range-config.h" >/dev/null 2>&1
	local status=$?
	rm -f "$work/range-config.h"
	return "$status"
}

n=0
for valid in 6 48; do
	n=$((n + 1))
	ask "font-ok-$n" "\n$valid\n\n\n\n" || fail "ranges: ask rejected font $valid"
	expect_answers "font-ok-$n" KINETIXOS_GAMING=no "DWM_FONT_SIZE=$valid" DWM_MODKEY=super \
		DWM_MFACT=0.55 DWM_NMASTER=1
	configure_accepts "DWM_FONT_SIZE=$valid" || fail "ranges: configure-build rejected font $valid"
done
for invalid in 5 49; do
	n=$((n + 1))
	ask "font-bad-$n" "\n$invalid\n12\n\n\n\n" || fail "ranges: ask failed after font $invalid"
	expect_answers "font-bad-$n" KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
		DWM_MFACT=0.55 DWM_NMASTER=1
	if configure_accepts "DWM_FONT_SIZE=$invalid"; then
		fail "ranges: configure-build accepted font $invalid"
	fi
done
for valid in 1 10; do
	n=$((n + 1))
	ask "nmaster-ok-$n" "\n\n\n\n$valid\n" || fail "ranges: ask rejected nmaster $valid"
	expect_answers "nmaster-ok-$n" KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
		DWM_MFACT=0.55 "DWM_NMASTER=$valid"
	configure_accepts "DWM_NMASTER=$valid" || fail "ranges: configure-build rejected nmaster $valid"
done
for invalid in 0 11; do
	n=$((n + 1))
	ask "nmaster-bad-$n" "\n\n\n\n$invalid\n2\n" || fail "ranges: ask failed after nmaster $invalid"
	expect_answers "nmaster-bad-$n" KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
		DWM_MFACT=0.55 DWM_NMASTER=2
	if configure_accepts "DWM_NMASTER=$invalid"; then
		fail "ranges: configure-build accepted nmaster $invalid"
	fi
done
for valid in 0.05 0.95; do
	n=$((n + 1))
	ask "mfact-ok-$n" "\n\n\n$valid\n\n" || fail "ranges: ask rejected mfact $valid"
	expect_answers "mfact-ok-$n" KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
		"DWM_MFACT=$valid" DWM_NMASTER=1
	configure_accepts "DWM_MFACT=$valid" || fail "ranges: configure-build rejected mfact $valid"
done
for invalid in 0.04 0.96; do
	n=$((n + 1))
	ask "mfact-bad-$n" "\n\n\n$invalid\n0.5\n\n" || fail "ranges: ask failed after mfact $invalid"
	expect_answers "mfact-bad-$n" KINETIXOS_GAMING=no DWM_FONT_SIZE=12 DWM_MODKEY=super \
		DWM_MFACT=0.5 DWM_NMASTER=1
	if configure_accepts "DWM_MFACT=$invalid"; then
		fail "ranges: configure-build accepted mfact $invalid"
	fi
done

printf '%s\n' "ISO install questions: PASS"
