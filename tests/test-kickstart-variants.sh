#!/usr/bin/env bash
set -euo pipefail

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

standard_ks="$repo/dwm-fedora.ks"
nvidia_ks="$repo/dwm-fedora-nvidia.ks"
builder="$repo/scripts/build-dwm-fedora-installer-iso.sh"

# shellcheck source=scripts/dwm-packages.sh
source "$repo/scripts/dwm-packages.sh"

required_repos=(
	'repo --name="updates"'
	'repo --name="fedora-cisco-openh264"'
	'repo --name="rpmfusion-free"'
	'repo --name="rpmfusion-free-updates"'
	'repo --name="rpmfusion-free-tainted"'
	'repo --name="rpmfusion-nonfree"'
	'repo --name="rpmfusion-nonfree-updates"'
	'repo --name="rpmfusion-nonfree-tainted"'
	'repo --name="brave-browser"'
	'repo --name="mwt-packages"'
)

required_packages=(
	flatpak
	maim
	steam
	gamescope
	gamemode.x86_64
	gamemode.i686
	mangohud.x86_64
	mangohud.i686
	quickshell
	Thunar
	gvfs
	gvfs-smb
	tumbler
	thunar-archive-plugin
	file-roller
	xdg-user-dirs
	xdg-desktop-portal-gtk
	xsettingsd
	gnome-keyring
	gnome-keyring-pam
	qt6ct
	qt5ct
	adwaita-icon-theme
	papirus-icon-theme
	arc-theme
	adw-gtk3-theme
	numix-gtk-theme
	yaru-gtk3-theme
	yaru-gtk4-theme
	deepin-gtk-theme
	bluebird-gtk3-theme
	PackageKit
	PackageKit-glib
	python3-gobject
	python3-rpm
	accountsservice
	cups
	system-config-printer
	lxqt-admin
	dnfdragora
)

mapfile -t mapped_fedora_packages < <(
	ARCH=x86_64 dwm_packages fedora full | awk 'NF' | sort -u
)

dwm_packages fedora runtime-required | grep -Fx xclip >/dev/null
dwm_packages fedora runtime-required | grep -Fx xdotool >/dev/null
dwm_packages fedora recommended | grep -Fx maim >/dev/null

if dwm_packages fedora runtime-required | grep -Fx maim >/dev/null; then
	printf 'Optional screenshot package leaked into required Fedora packages.\n' >&2
	exit 1
fi
dwm_packages fedora screenshot-optional | grep -Fx maim >/dev/null
dwm_packages fedora x11 | grep -Fx setxkbmap >/dev/null
dwm_packages fedora x11 | grep -Fx xkbset >/dev/null
dwm_packages fedora recommended | grep -Fx playerctl >/dev/null
dwm_packages fedora desktop | grep -Fx quickshell >/dev/null
dwm_packages fedora desktop | grep -Fx flatpak >/dev/null
dwm_packages fedora desktop | grep -Fx xdg-desktop-portal-gtk >/dev/null
dwm_packages fedora desktop | grep -Fx dbus-tools >/dev/null
dwm_packages fedora desktop | grep -Fx inotify-tools >/dev/null
dwm_packages fedora desktop | grep -Fx xsettingsd >/dev/null
if ARCH=x86_64 dwm_packages fedora full | grep -Fx nwg-look >/dev/null; then
	printf 'Unavailable Fedora package leaked into the image package set: nwg-look\n' >&2
	exit 1
fi
dwm_packages fedora full | grep -Fx gvfs-smb >/dev/null
dwm_packages fedora full | grep -Fx gnome-keyring-pam >/dev/null

# Interactive defaults must remove the Server root cap as well as /home.
python3 - "$repo/branding/anaconda/etc/anaconda/conf.d/90-dwm-storage.conf" <<'PYCONFIG'
import configparser
import sys
config = configparser.ConfigParser()
assert config.read(sys.argv[1])
assert config['Storage']['file_system_type'] == 'xfs'
assert config['Storage']['default_scheme'] == 'PLAIN'
assert config['Storage']['default_partitioning'].strip() == '/ (min 2 GiB)'
PYCONFIG

# Public profiles require interactive storage review. Only the private
# factory may configure partitioning and authorize disposable-disk erasure.
for ks in "$standard_ks" "$nvidia_ks" "$repo/dwm-fedora-image.ks"; do
	if grep -Eq '^(autopart|clearpart|zerombr|ignoredisk|part|partition|logvol|volgroup|reqpart)([[:space:]]|$)' "$ks"; then
		printf 'Public Kickstart overrides interactive disk selection or shared root layout: %s\n' "$ks" >&2
		exit 1
	fi
done

for ks in "$standard_ks" "$nvidia_ks"; do
	if grep -Fxq nwg-look "$ks"; then
		printf 'Unavailable Fedora package found in %s: nwg-look\n' "$ks" >&2
		exit 1
	fi
	for repo_line in "${required_repos[@]}"; do
		grep -Fq "$repo_line" "$ks"
	done
	for package in "${required_packages[@]}"; do
		grep -Fxq "$package" "$ks"
	done
	for package in "${mapped_fedora_packages[@]}"; do
		grep -Fxq "$package" "$ks"
	done
	grep -Fxq power-profiles-daemon "$ks"
	grep -Eq '^[[:space:]]*systemctl[[:space:]]+enable[[:space:]]+power-profiles-daemon[.]service([[:space:]]|$)' "$ks"
	if grep -Eq 'updates-testing|rpmfusion-.*-updates-testing' "$ks"; then
		printf 'Testing repo found in %s\n' "$ks" >&2
		exit 1
	fi
	grep -Fq "url --metalink=\"https://mirrors.fedoraproject.org/metalink?repo=fedora-\$releasever&arch=\$basearch\"" "$ks"
	# Execute the actual post-script cleanup prefix in a disposable directory.
	# Replace its sudoers path before execution; never touch host authorization.
	awk '
		/^%post --erroronfail/ { active=1; next }
		active && /^target_user=/ { exit }
		active && /^install_sudoers=/ { print "install_sudoers=$DWM_TEST_SUDOERS"; next }
		active { print }
	' "$ks" >"$work/post-prefix"
	for failure in exit signal; do
		cp "$work/post-prefix" "$work/post-failure"
		cat >>"$work/post-failure" <<'SH'
printf 'fixture authorization\n' >"$install_sudoers"
if [ "$DWM_TEST_FAILURE" = signal ]; then
	kill -TERM "$$"
else
	exit 73
fi
SH
		status=0
		DWM_TEST_SUDOERS="$work/sudoers" DWM_TEST_FAILURE=$failure \
			sh "$work/post-failure" || status=$?
		expected_status=73
		[[ $failure != signal ]] || expected_status=1
		[[ $status == "$expected_status" && ! -e $work/sudoers ]]
	done

	grep -Fq 'firstboot --disable' "$ks"
	grep -Fq 'selinux --disabled' "$ks"
	grep -Fq './install.sh --non-interactive --profile recommended' "$ks"
	if grep -Fq -- '--install-herdr' "$ks"; then
		printf 'Herdr must not be installed by default in %s\n' "$ks" >&2
		exit 1
	fi
	# shellcheck disable=SC2016 # Match the literal deferred expansion in Kickstart.
	grep -Fq 'export DBUS_SYSTEM_BUS_ADDRESS=\$DBUS_SESSION_BUS_ADDRESS; exec ./install.sh' "$ks"
	grep -Fq '%include /tmp/kinetixos-gaming-packages' "$ks"
	if grep -Fqi 'copr' "$ks"; then
		printf 'Kickstart must not enable a COPR repository: %s\n' "$ks" >&2
		exit 1
	fi
	# shellcheck disable=SC2016
	grep -Fq 'case "$(uname -m)" in' "$ks"
	# shellcheck disable=SC2016
	grep -Fq 'usermod -aG gamemode "$target_user"' "$ks"
	grep -Fq "for xdg_dir in \\" "$ks"
	for xdg_parent in \
		"\"\$target_home/.local\"" \
		"\"\$target_home/.local/share\"" \
		"\"\$target_home/.config\""; do
		grep -Fq "$xdg_parent" "$ks"
	done
	grep -Fq "if [ -e \"\$xdg_dir\" ] || [ -L \"\$xdg_dir\" ]; then" "$ks"
	grep -Fq "if [ ! -d \"\$xdg_dir\" ]; then" "$ks"
	grep -Fq "install -d -o \"\$target_user\" -g \"\$target_group\" -m 0755 \"\$xdg_dir\"" "$ks"
	if grep -Fq "install -d -m 0755 \"\$target_home/.local/share\"" "$ks"; then
		printf 'Kickstart creates the user data parent without ownership: %s\n' "$ks" >&2
		exit 1
	fi
	if grep -Eq 'systemctl --user (enable|start).*(dwm|wm)-graphical-session' "$ks"; then
		printf 'Kickstart starts graphical autostart before the first dwm session: %s\n' "$ks" >&2
		exit 1
	fi
done

for package in steam gamescope gamemode.x86_64 gamemode.i686 mangohud.x86_64 mangohud.i686; do
	ARCH=x86_64 dwm_packages fedora full | grep -Fx "$package" >/dev/null
	ARCH=x86_64 dwm_packages fedora gaming | grep -Fx "$package" >/dev/null
	if ARCH=x86_64 dwm_packages fedora optional | grep -Fx "$package" >/dev/null; then
		printf 'Fedora gaming package leaked into the optional profile: %s\n' "$package" >&2
		exit 1
	fi
	if ARCH=aarch64 dwm_packages fedora full | grep -Fx "$package" >/dev/null; then
		printf 'x86-only Fedora gaming package leaked into aarch64 mapping: %s\n' "$package" >&2
		exit 1
	fi
done

if grep -Eq 'akmod-nvidia|xorg-x11-drv-nvidia|nvidia-drm|nouveau' "$standard_ks"; then
	printf 'Standard Kickstart contains NVIDIA-only content.\n' >&2
	exit 1
fi

grep -Fq 'akmod-nvidia' "$nvidia_ks"
grep -Fq 'xorg-x11-drv-nvidia' "$nvidia_ks"
grep -Fq 'xorg-x11-drv-nvidia-cuda' "$nvidia_ks"
# The NVIDIA image and the opt-in installer driver share one package map.
while IFS= read -r package; do
	grep -Fxq "$package" "$nvidia_ks"
	if grep -Fxq "$package" "$standard_ks"; then
		printf 'NVIDIA driver package leaked into the standard Kickstart: %s\n' "$package" >&2
		exit 1
	fi
	if ARCH=x86_64 dwm_packages fedora full | grep -Fx "$package" >/dev/null; then
		printf 'NVIDIA driver package leaked into the full profile: %s\n' "$package" >&2
		exit 1
	fi
done < <(dwm_packages fedora nvidia)
grep -Fq 'options nvidia-drm modeset=1 fbdev=1' "$nvidia_ks"
grep -Fq 'rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1' "$nvidia_ks"

# Both installer ISOs ask the same install questions in %pre, before
# Anaconda's UI, and install the gaming set only on yes.
extract_pre() {
	awk '/^%pre/ { active=1 } active { print } active && /^%end/ { exit }' "$1"
}
if [[ "$(extract_pre "$standard_ks")" != "$(extract_pre "$nvidia_ks")" ]]; then
	printf 'The %%pre blocks of the two Kickstarts differ.\n' >&2
	exit 1
fi
gaming_expected="$work/gaming-expected"
if [[ "$(uname -m)" == x86_64 ]]; then
	printf '%s\n' steam gamescope gamemode.x86_64 gamemode.i686 mangohud.x86_64 mangohud.i686 >"$gaming_expected"
else
	: >"$gaming_expected"
fi
for ks in "$standard_ks" "$nvidia_ks"; do
	extract_pre "$ks" | head -n 1 | grep -Fxq '%pre --interpreter=/bin/sh --erroronfail'
	# The system-image builder rewrites every "set -eu" line; keep %pre clear of it.
	if extract_pre "$ks" | grep -Fxq 'set -eu'; then
		printf '%%pre must not use a bare set -eu line: %s\n' "$ks" >&2
		exit 1
	fi
	# Rewrite /tmp/ before inserting $repo, which may itself contain /tmp/.
	extract_pre "$ks" | sed -e '1d' -e '$d' \
		-e "s#/tmp/#$work/pre/#g" \
		-e "s#/run/install/repo/kinetixos#$repo#g" >"$work/pre.sh"
	for answer in yes no eof; do
		rm -rf "$work/pre"
		mkdir -p "$work/pre"
		case $answer in
		yes) input='y\n\n\n\n\n' ;;
		no) input='\n\n\n\n\n' ;;
		eof) input='' ;;
		esac
		status=0
		printf '%b' "$input" | KINETIXOS_QUESTIONS_TTY=stdio sh "$work/pre.sh" >/dev/null 2>&1 || status=$?
		case $answer in
		yes)
			[[ $status == 0 ]] || {
				printf '%%pre failed for a yes answer: %s\n' "$ks" >&2
				exit 1
			}
			cmp -s "$gaming_expected" "$work/pre/kinetixos-gaming-packages" || {
				printf 'Gaming yes did not produce the gaming package list: %s\n' "$ks" >&2
				exit 1
			}
			;;
		no)
			[[ $status == 0 && -f $work/pre/kinetixos-gaming-packages ]] || {
				printf '%%pre failed or wrote no gaming include for a no answer: %s\n' "$ks" >&2
				exit 1
			}
			if [[ -s $work/pre/kinetixos-gaming-packages ]]; then
				printf 'Gaming no still lists gaming packages: %s\n' "$ks" >&2
				exit 1
			fi
			;;
		eof)
			if [[ $status == 0 ]]; then
				printf '%%pre continued without answers: %s\n' "$ks" >&2
				exit 1
			fi
			;;
		esac
	done
	grep -Fq 'install -m 0600 /tmp/kinetixos-install-answers /mnt/sysimage/root/kinetixos-install-answers' "$ks"
	grep -Fq 'iso-questions.sh" env /root/kinetixos-install-answers' "$ks"
	# shellcheck disable=SC2016 # Match the literal Kickstart text.
	grep -Fq '&& $install_env dbus-run-session' "$ks"
	grep -Fq 'rm -f /root/kinetixos-install-answers' "$ks"
	# Installer ISOs always seed the default wallpaper set for the new user;
	# a download failure must not abort the installation.
	# shellcheck disable=SC2016 # Match the literal Kickstart text.
	grep -Fq 'git clone --depth 1 https://github.com/Dexmodzz/my-background.git "$HOME/Pictures/backgrounds"' "$ks" || {
		printf 'Kickstart does not download the default wallpapers: %s\n' "$ks" >&2
		exit 1
	}
	grep -Fq 'Wallpaper download failed; add images to ~/Pictures/backgrounds.' "$ks" || {
		printf 'Wallpaper download failure is not handled as a warning: %s\n' "$ks" >&2
		exit 1
	}
	# The Thunar side pane seeder runs once at first login and needs the XDG
	# user folders; create them for the new user before that login, and
	# before the wallpaper download, as install.sh does for the full profile.
	xdg_line=$(grep -n "su - \"\$target_user\" -c 'xdg-user-dirs-update'" "$ks" | cut -d: -f1 | head -n 1 || true)
	wallpaper_line=$(grep -n 'my-background.git' "$ks" | cut -d: -f1 | head -n 1 || true)
	[[ -n $xdg_line && -n $wallpaper_line && $xdg_line -lt $wallpaper_line ]] || {
		printf 'Kickstart must create the XDG user folders before the wallpaper download: %s\n' "$ks" >&2
		exit 1
	}
	grep -Fq 'XDG user folder setup failed; Thunar bookmarks may be missing.' "$ks" || {
		printf 'XDG user folder failure is not handled as a warning: %s\n' "$ks" >&2
		exit 1
	}
done

grep -Fq 'variant=standard' "$builder"
grep -Fq 'dwm-fedora-nvidia.ks' "$builder"
grep -Fq 'rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1' "$builder"

printf 'Kickstart variants: PASS\n'
