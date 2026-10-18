#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/dwm-utils.sh
# shellcheck disable=SC1091
source "$REPO_DIR/scripts/dwm-utils.sh"
# shellcheck source=scripts/dwm-packages.sh
# shellcheck disable=SC1091
source "$REPO_DIR/scripts/dwm-packages.sh"

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info() { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
ok() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
err() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

usage() {
	cat <<EOF
Usage: ./install.sh [options]

Options:
  --profile PROFILE      Install profile: core, recommended, or full.
                         Defaults to DWM_INSTALL_PROFILE or full.
  --non-interactive      Use unattended defaults and do not prompt.
  --yes                  Accept the interactive install summary.
  --install-herdr        Install verified Herdr as an optional workspace.
  --skip-herdr           Do not install Herdr.
  --enable-fedora-gaming-repos
                         Approve RPM Fusion nonfree for Steam.
  --install-nvidia       Approve the proprietary NVIDIA akmod driver from
                         RPM Fusion when an NVIDIA GPU is detected.
  --skip-nvidia          Do not install or offer the NVIDIA driver.
  --enable-graphical-login
                         Boot to graphical.target so the enabled display
                         manager starts at boot.
  --skip-graphical-login Keep the current default boot target.
  --dry-run              Print the resolved plan and exit before changes.
  -h, --help             Show this help.
EOF
}

case "$DISTRO_FAMILY" in
fedora)
	command -v dnf &>/dev/null || {
		err "Fedora was detected, but dnf was not found."
		exit 1
	}
	;;
*)
	err "Unsupported distribution: $DISTRO_NAME"
	err "KinetixOS supports Fedora only."
	exit 1
	;;
esac

BG_DIR="$HOME/Pictures/backgrounds"
MESLO_VERSION="3.4.0"
MESLO_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${MESLO_VERSION}/Meslo.zip"
MESLO_SHA256="13b502ac8c2bd9d3161018064560e23cd42b175bb730780a270975265a19ad57"
NORDIC_THEME_URL="https://github.com/EliverLara/Nordic.git"
NORDIC_THEME_REF="master"
ARCH="$(uname -m)"
INSTALL_PROFILE="${DWM_INSTALL_PROFILE:-full}"
HERDR_INSTALL_MODE="${DWM_INSTALL_HERDR:-false}"
NVIDIA_INSTALL_MODE="${DWM_INSTALL_NVIDIA:-auto}"
NVIDIA_DRIVER_APPROVED=false
GRAPHICAL_LOGIN_MODE="${DWM_GRAPHICAL_LOGIN:-auto}"
DISPLAY_MANAGER_LINK=/etc/systemd/system/display-manager.service
NON_INTERACTIVE=false
ASSUME_YES=false
FEDORA_GAMING_REPOS_APPROVED=false
DRY_RUN=false

while (($# > 0)); do
	case "$1" in
	--profile)
		if (($# < 2)); then
			err "--profile requires a value."
			exit 1
		fi
		INSTALL_PROFILE=$2
		shift 2
		;;
	--profile=*)
		INSTALL_PROFILE=${1#*=}
		shift
		;;
	--non-interactive)
		NON_INTERACTIVE=true
		ASSUME_YES=true
		shift
		;;
	--yes)
		ASSUME_YES=true
		shift
		;;
	--install-herdr)
		HERDR_INSTALL_MODE=true
		shift
		;;
	--skip-herdr)
		HERDR_INSTALL_MODE=false
		shift
		;;
	--enable-fedora-gaming-repos)
		FEDORA_GAMING_REPOS_APPROVED=true
		shift
		;;
	--install-nvidia)
		NVIDIA_INSTALL_MODE=true
		shift
		;;
	--skip-nvidia)
		NVIDIA_INSTALL_MODE=false
		shift
		;;
	--enable-graphical-login)
		GRAPHICAL_LOGIN_MODE=true
		shift
		;;
	--skip-graphical-login)
		GRAPHICAL_LOGIN_MODE=false
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		err "Unknown option: $1"
		usage >&2
		exit 1
		;;
	esac
done

case "$INSTALL_PROFILE" in
core | minimal)
	INSTALL_PROFILE="core"
	;;
recommended | full) ;;
*)
	err "Unsupported DWM_INSTALL_PROFILE: $INSTALL_PROFILE"
	err "Supported profiles: core, recommended, full"
	exit 1
	;;
esac

case "$HERDR_INSTALL_MODE" in
auto)
	# Retain compatibility with the old value, but no longer install Herdr by
	# default for any profile.
	HERDR_INSTALL_MODE=false
	;;
1 | true | yes)
	HERDR_INSTALL_MODE=true
	;;
0 | false | no)
	HERDR_INSTALL_MODE=false
	;;
*)
	err "Unsupported DWM_INSTALL_HERDR: $HERDR_INSTALL_MODE"
	err "Supported values: auto, true, false"
	exit 1
	;;
esac

case "$NVIDIA_INSTALL_MODE" in
auto) ;;
1 | true | yes)
	NVIDIA_INSTALL_MODE=true
	;;
0 | false | no)
	NVIDIA_INSTALL_MODE=false
	;;
*)
	err "Unsupported DWM_INSTALL_NVIDIA: $NVIDIA_INSTALL_MODE"
	err "Supported values: auto, true, false"
	exit 1
	;;
esac

case "$GRAPHICAL_LOGIN_MODE" in
auto) ;;
1 | true | yes)
	GRAPHICAL_LOGIN_MODE=true
	;;
0 | false | no)
	GRAPHICAL_LOGIN_MODE=false
	;;
*)
	err "Unsupported DWM_GRAPHICAL_LOGIN: $GRAPHICAL_LOGIN_MODE"
	err "Supported values: auto, true, false"
	exit 1
	;;
esac

if [[ ! -t 0 || ! -t 1 ]]; then
	NON_INTERACTIVE=true
	ASSUME_YES=true
fi

if [[ $EUID -eq 0 && $DRY_RUN != true ]]; then
	err "Run this installer as a normal user. It invokes sudo only when needed."
	exit 1
fi

install_recommended_profile() {
	[[ $INSTALL_PROFILE == "recommended" || $INSTALL_PROFILE == "full" ]]
}

install_optional_profile() {
	[[ $INSTALL_PROFILE == "full" ]]
}

herdr_arch_supported() {
	case $ARCH in
	x86_64 | amd64 | aarch64 | arm64)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

install_herdr_profile() {
	[[ $HERDR_INSTALL_MODE == true ]] && herdr_arch_supported
}

fedora_gaming_profile() {
	[[ $DISTRO_ID == "fedora" && $INSTALL_PROFILE == "full" && $ARCH == "x86_64" ]]
}

confirm_fedora_gaming_repositories() {
	local answer

	if ! fedora_gaming_profile || [[ $FEDORA_GAMING_REPOS_APPROVED == true ]]; then
		return
	fi
	if [[ $NON_INTERACTIVE == true ]]; then
		warn "Skipping Fedora gaming packages because third-party repositories were not approved."
		warn "Re-run with --enable-fedora-gaming-repos to approve RPM Fusion nonfree."
		return
	fi

	printf 'Enable RPM Fusion nonfree for Fedora gaming packages? [y/N] '
	read -r answer
	case "$answer" in
	y | Y | yes | YES)
		FEDORA_GAMING_REPOS_APPROVED=true
		;;
	*)
		warn "Fedora gaming repositories declined; skipping Steam, Gamescope, GameMode, and MangoHud."
		;;
	esac
}

fedora_numeric_release() {
	local fedora_release

	if ! command -v rpm &>/dev/null; then
		warn "rpm is unavailable; cannot determine the Fedora release for RPM Fusion." >&2
		return 1
	fi
	fedora_release=$(rpm -E '%fedora')
	case "$fedora_release" in
	'' | *[!0-9]*)
		warn "Could not determine the numeric Fedora release for RPM Fusion." >&2
		return 1
		;;
	esac
	printf '%s\n' "$fedora_release"
}

# Install the RPM Fusion release package for each named repository (free or
# nonfree) that is not already enabled. The purpose names the approved feature.
enable_rpmfusion_repositories() {
	local purpose=$1
	shift
	local fedora_release
	local repo
	local urls=()
	local names=()

	fedora_release=$(fedora_numeric_release) || return 1
	for repo in "$@"; do
		if rpm -q "rpmfusion-${repo}-release" &>/dev/null; then
			ok "RPM Fusion $repo is already enabled."
			continue
		fi
		urls+=("https://mirrors.rpmfusion.org/${repo}/fedora/rpmfusion-${repo}-release-${fedora_release}.noarch.rpm")
		names+=("$repo")
	done
	if ((${#urls[@]} == 0)); then
		return 0
	fi

	info "Enabling RPM Fusion ${names[*]} for $purpose..."
	sudo dnf install -y "${urls[@]}"
}

configure_fedora_gaming_repositories() {
	if [[ $DISTRO_ID != "fedora" || $INSTALL_PROFILE != "full" || $ARCH != "x86_64" ]]; then
		return 1
	fi
	if [[ $FEDORA_GAMING_REPOS_APPROVED != true ]]; then
		return 1
	fi

	if ! enable_rpmfusion_repositories Steam nonfree; then
		warn "Could not enable RPM Fusion nonfree; skipping Fedora gaming packages."
		return 1
	fi
}

nvidia_driver_installed() {
	command -v rpm &>/dev/null && rpm -q akmod-nvidia &>/dev/null
}

nvidia_driver_candidate() {
	[[ $DISTRO_ID == "fedora" && $ARCH == "x86_64" ]] || return 1
	[[ "$(detect_gpu)" == "nvidia" ]]
}

nvidia_driver_status() {
	if [[ $ARCH != "x86_64" ]]; then
		printf 'skipped (unsupported architecture: %s)\n' "$ARCH"
	elif nvidia_driver_installed; then
		printf 'already installed (akmod-nvidia)\n'
	elif ! nvidia_driver_candidate; then
		printf 'skipped (no NVIDIA GPU detected)\n'
	elif [[ $NVIDIA_INSTALL_MODE == false ]]; then
		printf 'skipped (--skip-nvidia)\n'
	elif [[ $NVIDIA_INSTALL_MODE == true ]]; then
		printf 'approved (akmod-nvidia from RPM Fusion free and nonfree)\n'
	else
		printf 'requires separate confirmation (use --install-nvidia when unattended)\n'
	fi
}

confirm_nvidia_driver() {
	local answer

	if nvidia_driver_installed; then
		ok "NVIDIA akmod driver already installed."
		return
	fi
	if ! nvidia_driver_candidate || [[ $NVIDIA_INSTALL_MODE == false ]]; then
		return
	fi
	if [[ $NVIDIA_INSTALL_MODE == true ]]; then
		NVIDIA_DRIVER_APPROVED=true
		return
	fi
	if [[ $NON_INTERACTIVE == true ]]; then
		warn "Skipping the proprietary NVIDIA driver because it was not approved."
		warn "Re-run with --install-nvidia to install akmod-nvidia from RPM Fusion."
		return
	fi

	echo ""
	info "An NVIDIA GPU was detected."
	printf '  %s\n' \
		"The proprietary driver installs akmod-nvidia from RPM Fusion free and nonfree." \
		"akmods rebuilds the kernel module for every new Fedora kernel." \
		"The RPM Fusion driver package adds kernel arguments that disable Nouveau." \
		"A reboot is required before the driver is used."
	printf 'Install the proprietary NVIDIA driver (akmod-nvidia)? [y/N] '
	read -r answer
	case "$answer" in
	y | Y | yes | YES)
		NVIDIA_DRIVER_APPROVED=true
		;;
	*)
		warn "NVIDIA driver declined; the open-source Nouveau driver remains in use."
		;;
	esac
}

secure_boot_enabled() {
	command -v mokutil &>/dev/null &&
		mokutil --sb-state 2>/dev/null | command grep -Fqi 'SecureBoot enabled'
}

install_nvidia_driver() {
	local kernel

	if [[ $NVIDIA_DRIVER_APPROVED != true ]]; then
		return
	fi
	if ! enable_rpmfusion_repositories "the NVIDIA driver" free nonfree; then
		warn "Could not enable RPM Fusion; the NVIDIA driver was not installed."
		return
	fi

	info "Installing the proprietary NVIDIA akmod driver..."
	if ! dwm_install_package_profile nvidia; then
		warn "NVIDIA driver packages could not be installed; Nouveau remains in use."
		return
	fi

	kernel=$(uname -r)
	info "Building the NVIDIA kernel module for $kernel (this can take several minutes)..."
	if sudo akmods --force --kernels "$kernel"; then
		ok "NVIDIA kernel module built for $kernel."
	else
		warn "The NVIDIA kernel module build did not finish."
		warn "Retry with: sudo akmods --force --kernels $kernel"
	fi

	if secure_boot_enabled; then
		warn "Secure Boot is enabled; the unsigned NVIDIA module will not load until its key is enrolled."
		warn "Enroll the akmods key with: sudo kmodgenca -a && sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
		warn "Then reboot and complete the MOK enrollment prompt."
	fi
	ok "NVIDIA driver installed. Reboot before using it."
}

configure_fedora_gamemode_access() {
	local target_user

	if [[ $DISTRO_ID != "fedora" || $INSTALL_PROFILE != "full" ]]; then
		return
	fi
	if ! getent group gamemode >/dev/null 2>&1; then
		warn "GameMode was not installed; skipping privileged tuning access."
		return
	fi

	target_user=$(id -un)
	if id -nG "$target_user" | tr ' ' '\n' | command grep -Fxq gamemode; then
		ok "$target_user already has GameMode tuning access."
		return
	fi

	info "Adding $target_user to the gamemode group..."
	sudo usermod -aG gamemode "$target_user"
	warn "Log out and back in before using GameMode privileged tuning."
}

package_line() {
	local profile=$1

	dwm_packages "$DISTRO_FAMILY" "$profile" | paste -sd ' ' -
}

print_summary_profile() {
	local label=$1
	local profile=$2
	local packages

	packages="$(package_line "$profile")"
	if [[ -n $packages ]]; then
		printf '  %s: %s\n' "$label" "$packages"
	else
		printf '  %s: none\n' "$label"
	fi
}

print_install_summary() {
	echo ""
	echo "Installation summary:"
	printf '  Distribution: %s\n' "$DISTRO_NAME"
	printf '  Family: %s\n' "$DISTRO_FAMILY"
	printf '  Package manager: %s\n' "$PKG_CMD"
	printf '  Profile: %s\n' "$INSTALL_PROFILE"
	printf '  Mode: %s\n' "$([[ $NON_INTERACTIVE == true ]] && echo non-interactive || echo interactive)"
	print_summary_profile "Required packages" required
	if install_recommended_profile; then
		print_summary_profile "Recommended packages" recommended
		printf '  Gear Lever: user-scoped Flathub install (%s)\n' 'it.mijorus.gearlever'
	else
		printf '  Recommended packages: skipped\n'
	fi
	if install_optional_profile; then
		print_summary_profile "Optional extras" optional
		if fedora_gaming_profile; then
			print_summary_profile "Fedora gaming packages" gaming
			if [[ $FEDORA_GAMING_REPOS_APPROVED == true ]]; then
				printf '  Third-party repositories: approved\n'
			else
				printf '  Third-party repositories: require separate confirmation\n'
			fi
		fi
	else
		printf '  Optional extras: skipped\n'
	fi
	print_summary_profile "Terminal candidates" terminal
	printf '  NVIDIA driver: %s\n' "$(nvidia_driver_status)"
	printf '  Graphical login at boot: %s\n' "$(graphical_login_status)"
	if install_herdr_profile; then
		printf '  Herdr workspace: verified user install from https://herdr.dev/install.sh\n'
	elif [[ $HERDR_INSTALL_MODE == true ]]; then
		printf '  Herdr workspace: skipped (unsupported architecture: %s)\n' "$ARCH"
	else
		printf '  Herdr workspace: skipped (optional; use --install-herdr to enable)\n'
	fi
	echo ""
}

confirm_install_summary() {
	local answer

	print_install_summary

	if [[ $DRY_RUN == true ]]; then
		ok "Dry run complete; no changes were made."
		exit 0
	fi

	if [[ $ASSUME_YES == true ]]; then
		return
	fi

	printf 'Continue with installation? [y/N] '
	read -r answer
	case "$answer" in
	y | Y | yes | YES) ;;
	*)
		err "Installation cancelled."
		exit 1
		;;
	esac
}

install_meslo_nerd_font() {
	local font_dir="$HOME/.local/share/fonts/Meslo"
	local tmp_dir
	local archive

	if fc-list 2>/dev/null | command grep -Eqi 'MesloLGS (NF|Nerd Font)'; then
		ok "MesloLGS Nerd Font is already installed."
		return
	fi

	tmp_dir="$(mktemp -d)"
	archive="$tmp_dir/Meslo.zip"

	info "Downloading Meslo Nerd Font v${MESLO_VERSION}..."
	if ! curl --fail --location --show-error --silent "$MESLO_URL" --output "$archive"; then
		rm -rf "$tmp_dir"
		err "Failed to download Meslo Nerd Font."
		return 1
	fi

	if ! printf '%s  %s\n' "$MESLO_SHA256" "$archive" | sha256sum --check --status; then
		rm -rf "$tmp_dir"
		err "Meslo Nerd Font checksum verification failed."
		return 1
	fi

	mkdir -p "$font_dir"
	unzip -j -q -o "$archive" '*.ttf' -d "$font_dir"
	rm -rf "$tmp_dir"
	fc-cache -f "$font_dir" >/dev/null 2>&1
	ok "MesloLGS Nerd Font installed."
}

install_nordic_gtk_theme() {
	local target="/usr/share/themes/Nordic"
	local tmp_dir

	if [[ -d "$target/gtk-3.0" || -d "$target/gtk-4.0" ]]; then
		ok "Nordic GTK theme is already installed system-wide."
		return 0
	fi

	if ! command -v git &>/dev/null; then
		warn "git is unavailable; skipping Nordic GTK theme install."
		return 1
	fi

	tmp_dir="$(mktemp -d)"
	if ! git clone --depth 1 --branch "$NORDIC_THEME_REF" "$NORDIC_THEME_URL" "$tmp_dir/Nordic" 2>/dev/null; then
		rm -rf "$tmp_dir"
		warn "Could not download Nordic GTK theme; continuing without it."
		return 1
	fi

	sudo rm -rf "$target"
	sudo install -d -m 0755 /usr/share/themes
	sudo cp -a "$tmp_dir/Nordic" "$target"
	sudo find "$target" -type d -exec chmod 0755 {} +
	sudo find "$target" -type f -exec chmod 0644 {} +
	rm -rf "$tmp_dir"
	ok "Nordic GTK theme installed system-wide."
}

install_supported_terminal() {
	if ! dwm_install_first_available_profile terminal; then
		err "No supported terminal is available in the enabled repositories."
		return 1
	fi
}

configure_quickshell_picom_opacity() {
	local config="/etc/xdg/picom.conf"
	local backup="${config}.kinetixos.bak"
	local tooltip_rule="^([[:space:]]*\"[0-9]+([.][0-9]+)?:window_type = 'tooltip')(\"[[:space:]]*,?[[:space:]]*)$"
	local configured_rule="^[[:space:]]*\"[0-9]+([.][0-9]+)?:window_type = 'tooltip' && name != 'quickshell'\"[[:space:]]*,?[[:space:]]*$"
	local tmp

	if [[ ! -f $config ]]; then
		warn "Picom system config not found; skipping Quickshell opacity override."
		return
	fi
	if sudo grep -Eq "$configured_rule" "$config"; then
		ok "Quickshell Picom opacity is already configured."
		return
	fi
	if ! sudo grep -Eq "$tooltip_rule" "$config"; then
		warn "Recognized Picom tooltip opacity rule not found; preserving $config."
		return
	fi

	tmp="$(mktemp)"
	if ! sudo sed -E \
		"s/${tooltip_rule}/\\1 \&\& name != 'quickshell'\\3/" \
		"$config" | tee "$tmp" >/dev/null; then
		rm -f "$tmp"
		warn "Could not prepare the Quickshell Picom opacity override."
		return
	fi

	if [[ ! -f $backup ]]; then
		sudo install -o root -g root -m 0644 "$config" "$backup"
	fi
	sudo install -o root -g root -m 0644 "$tmp" "$config"
	rm -f "$tmp"
	ok "Configured fully opaque Quickshell windows in Picom."
}

configure_displays_after_install() {
	local answer

	if [[ $NON_INTERACTIVE == true ]]; then
		warn "Display setup deferred for non-interactive installation."
		warn "Run dwm-display-setup from an X11 session after login."
		return 0
	fi
	if [[ -z ${DISPLAY:-} ]] || ! command -v xrandr >/dev/null 2>&1; then
		warn "Display setup needs an active X11 session and was deferred."
		warn "After login, run: dwm-display-setup"
		return 0
	fi
	if ! xrandr --query 2>/dev/null | awk '$2 == "connected" { found = 1 } END { exit !found }'; then
		warn "No connected X11 outputs were detected; display setup was deferred."
		return 0
	fi

	printf 'Configure persistent display resolution and positioning now? [Y/n] '
	read -r answer
	case $answer in
	n | N | no | NO)
		warn "Display setup skipped. Run dwm-display-setup when ready."
		;;
	*)
		if ! "$REPO_DIR/scripts/dwm-display-setup" wizard; then
			warn "Display setup did not complete. Existing Xorg configuration was preserved."
			warn "Run dwm-display-setup to try again."
		fi
		;;
	esac
}

default_boot_target() {
	command -v systemctl &>/dev/null || return 0
	systemctl get-default 2>/dev/null || true
}

graphical_login_status() {
	if [[ "$(default_boot_target)" == graphical.target ]]; then
		printf 'already enabled (graphical.target)\n'
	elif [[ $GRAPHICAL_LOGIN_MODE == false ]]; then
		printf 'skipped (--skip-graphical-login)\n'
	elif [[ $GRAPHICAL_LOGIN_MODE == true ]]; then
		printf 'approved (sets graphical.target when a display manager is enabled)\n'
	elif [[ $NON_INTERACTIVE == true ]]; then
		printf 'unchanged (use --enable-graphical-login when unattended)\n'
	else
		printf 'asked after display-manager setup\n'
	fi
}

# A display manager starts at boot only when the default target is graphical.
# Change that target only with explicit approval, and print the manual command
# whenever it is left unchanged.
configure_graphical_login() {
	local dm=$1
	local current_target
	local answer

	[[ -n $dm ]] || return 0
	command -v systemctl &>/dev/null || return 0
	current_target=$(default_boot_target)
	if [[ $current_target == graphical.target ]]; then
		ok "Graphical login starts at boot ($dm)."
		return 0
	fi
	if [[ ! -L $DISPLAY_MANAGER_LINK ]]; then
		warn "$dm is installed but no display manager is enabled; the default boot target was not changed."
		warn "Enable it with: sudo systemctl enable $dm.service && sudo systemctl set-default graphical.target"
		return 0
	fi

	case "$GRAPHICAL_LOGIN_MODE" in
	false)
		warn "Graphical login at boot skipped; the system still boots to ${current_target:-its current target}."
		warn "Enable it later with: sudo systemctl set-default graphical.target"
		return 0
		;;
	auto)
		if [[ $NON_INTERACTIVE == true ]]; then
			warn "The system boots to ${current_target:-a non-graphical target}, so $dm will not start at boot."
			warn "Re-run with --enable-graphical-login or run: sudo systemctl set-default graphical.target"
			return 0
		fi
		printf 'Start the graphical login (%s) at boot? [Y/n] ' "$dm"
		read -r answer
		case "$answer" in
		n | N | no | NO)
			warn "Graphical login at boot declined; log in on a TTY and run startx."
			warn "Enable it later with: sudo systemctl set-default graphical.target"
			return 0
			;;
		esac
		;;
	esac

	info "Setting the default boot target to graphical.target..."
	if sudo systemctl set-default graphical.target; then
		ok "$dm will start at the next boot. Undo with: sudo systemctl set-default ${current_target:-multi-user.target}"
	else
		warn "Could not change the default boot target; run: sudo systemctl set-default graphical.target"
	fi
}

detect_display_manager() {
	local unit

	unit="$(readlink -f "$DISPLAY_MANAGER_LINK" 2>/dev/null || true)"
	case "$(basename "$unit")" in
	lightdm.service)
		echo "lightdm"
		return
		;;
	gdm.service)
		echo "gdm"
		return
		;;
	sddm.service)
		echo "sddm"
		return
		;;
	esac

	for unit in lightdm gdm sddm; do
		if command -v "$unit" &>/dev/null; then
			echo "$unit"
			return
		fi
	done
}

install_lightdm_config() {
	local lightdm_config="/etc/lightdm/lightdm.conf"
	local lightdm_seat_section="SeatDefaults"
	local lightdm_greeter_session="lightdm-slick-greeter"
	local lightdm_session_wrapper="/etc/lightdm/Xsession"
	local lightdm_logind_check=false

	lightdm_seat_section="Seat:*"
	lightdm_greeter_session="slick-greeter"
	lightdm_session_wrapper=""
	lightdm_logind_check=true

	sudo make -C "$REPO_DIR/lightdm" \
		LIGHTDM_SEAT_SECTION="$lightdm_seat_section" \
		LIGHTDM_GREETER_SESSION="$lightdm_greeter_session" \
		LIGHTDM_SESSION_WRAPPER="$lightdm_session_wrapper" \
		LIGHTDM_LOGIND_CHECK="$lightdm_logind_check" \
		install
	if command -v restorecon &>/dev/null; then
		sudo restorecon \
			"$lightdm_config" \
			/etc/lightdm/slick-greeter.conf \
			/usr/libexec/kinetixos/lightdm-display-setup \
			/usr/share/pixmaps/kinetixos.jpg \
			/usr/share/pixmaps/kinetixos-logo.png
	fi
}

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║             KinetixOS Installer           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Distribution: $DISTRO_NAME"
info "Family: $DISTRO_FAMILY"
info "Package manager: $PKG_CMD"
info "Install profile: $INSTALL_PROFILE"
confirm_install_summary
confirm_fedora_gaming_repositories
confirm_nvidia_driver

if [[ $NON_INTERACTIVE != true ]]; then
	"$REPO_DIR/scripts/configure-build.sh"
else
	"$REPO_DIR/scripts/configure-build.sh" --non-interactive
fi

# ── Required build and runtime dependencies ──────────────
info "Installing required build and runtime dependencies..."
dwm_install_package_profile build
dwm_install_package_profile x11
dwm_install_package_profile runtime-required
dwm_install_package_profile media
ok "Required build and runtime dependencies installed."

# ── Proprietary NVIDIA driver ────────────────────────────
install_nvidia_driver

# ── Recommended desktop dependencies ─────────────────────
if install_recommended_profile; then
	info "Installing recommended desktop dependencies..."
	dwm_install_package_profile desktop
	dwm_install_package_profile system-management
	if ! env -u DWM_TEST_MODE -u DWM_TEST_QUICKSHELL_VERSION \
		"$REPO_DIR/scripts/dwm-quickshell-version-check"; then
		err "The installed Quickshell build is incompatible with KinetixOS."
		exit 1
	fi
	if ! dwm_install_available_package_profile screenshot-optional; then
		warn "maim is unavailable in the enabled repositories; screenshot hotkeys will remain disabled."
	fi
	dwm_install_package_profile theme
	if ! dwm_install_available_package_profile theme-gtk; then
		warn "Some GTK theme packages were unavailable in enabled repositories."
	fi
	install_nordic_gtk_theme || true
	dwm_install_package_profile fonts
	ok "Recommended desktop dependencies installed."
else
	warn "Skipping recommended desktop dependencies for core profile."
fi

if command -v picom >/dev/null 2>&1; then
	configure_quickshell_picom_opacity
fi

# ── Optional desktop extras ──────────────────────────────
if install_optional_profile; then
	info "Installing optional desktop extras..."
	if ! dwm_install_available_package_profile optional; then
		warn "Some optional desktop extras were unavailable in enabled repositories."
	fi
	if fedora_gaming_profile; then
		if [[ $FEDORA_GAMING_REPOS_APPROVED != true ]]; then
			warn "Fedora gaming packages were skipped because their repositories were not approved."
		elif configure_fedora_gaming_repositories; then
			info "Installing Fedora gaming packages..."
			if ! dwm_install_available_package_profile gaming; then
				warn "Some Fedora gaming packages were unavailable in the approved repositories."
			fi
			configure_fedora_gamemode_access
		else
			warn "Fedora gaming repository setup failed; no gaming packages were installed."
		fi
	fi
	ok "Optional desktop extras processed."
else
	warn "Skipping optional desktop extras for $INSTALL_PROFILE profile."
fi

# ── Qt / GTK theming ─────────────────────────────────────
if install_recommended_profile; then
	info "Configuring Qt/GTK dark-mode dependencies..."
	# dconf: required for gsettings to persist GTK color-scheme changes
	# qt6ct / qt5ct: QT_QPA_PLATFORMTHEME backend for Qt dark mode in standalone WMs
	dwm_install_first_available_profile theme-optional ||
		warn "Neither qt6ct nor qt5ct is available - Qt apps may not respect dark mode."
	ok "Qt/GTK theming dependencies configured."
fi

# ── Fonts ────────────────────────────────────────────────
if install_recommended_profile; then
	info "Installing fonts..."
	FONT_DIR="$HOME/.local/share/fonts"
	mkdir -p "$FONT_DIR"
	install_meslo_nerd_font
	ok "Fonts installed."
fi

# ── Terminal emulator ────────────────────────────────────
terminal=""
if command -v alacritty &>/dev/null; then
	terminal="alacritty"
	ok "Preferred terminal already installed: $terminal"
else
	info "Installing the preferred Alacritty terminal from enabled repositories..."
	if dwm_install_first_available_profile terminal-primary; then
		terminal="alacritty"
		ok "Preferred terminal installed: $terminal"
	else
		warn "Alacritty is unavailable; falling back to another supported terminal."
		for t in kitty st warp-terminal xterm; do command -v "$t" &>/dev/null && {
			terminal="$t"
			break
		}; done
		if [ -z "$terminal" ]; then
			install_supported_terminal
			terminal="$(detect_terminal)"
		fi
	fi
fi

# ── Herdr terminal workspace ─────────────────────────────
if install_herdr_profile; then
	info "Installing the verified Herdr workspace for interactive terminals..."
	if "$REPO_DIR/scripts/install-herdr"; then
		ok "Herdr is installed; set DWM_HERDR=1 and use dwm-terminal to open it in $terminal."
	else
		herdr_status=$?
		if [[ $herdr_status -eq 2 ]]; then
			warn "Herdr is ready, but one or more detected agent integrations could not be installed."
		else
			warn "Herdr installation failed; Alacritty remains the default terminal."
		fi
	fi
elif [[ $HERDR_INSTALL_MODE == true ]]; then
	warn "Skipping Herdr installation on unsupported architecture: $ARCH."
fi

# ── XDG dirs + wallpapers ────────────────────────────────
if install_optional_profile && command -v xdg-user-dirs-update &>/dev/null; then
	xdg-user-dirs-update
fi

if install_optional_profile; then
	mkdir -p "$HOME/Pictures"
	if [ ! -d "$BG_DIR" ]; then
		info "Downloading wallpapers..."
		if git clone https://github.com/Dexmodzz/my-background.git "$BG_DIR" 2>/dev/null; then
			ok "Wallpapers downloaded to $BG_DIR"
		else
			warn "Failed to download wallpapers. Add your own to $BG_DIR."
		fi
	else
		ok "Wallpapers already present."
	fi
fi

# ── Display manager ──────────────────────────────────────
currentdm="$(detect_display_manager)"

if [ -n "$currentdm" ]; then
	ok "Display manager already installed: $currentdm"
elif ! install_optional_profile; then
	warn "No display manager found; skipping display-manager installation for $INSTALL_PROFILE profile."
else
	info "No display manager found - installing LightDM..."
	dwm_install_package_profile lightdm
	sudo systemctl enable lightdm.service
	currentdm="lightdm"
	ok "LightDM installed and enabled."
fi

# ── LightDM greeter config ───────────────────────────────
if [[ $currentdm == "lightdm" ]]; then
	info "Deploying LightDM Slick Greeter config..."
	install_lightdm_config
	ok "LightDM config deployed."
fi

# ── Graphical login at boot ──────────────────────────────
configure_graphical_login "$currentdm"

# ── Build & Install ──────────────────────────────────────
cd "$REPO_DIR"
make clean
make
sudo make install \
	DATADIR="/usr/share" \
	USER_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
	USER_HOME="$HOME" \
	OWNER="$(id -un)" \
	XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" \
	XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
	XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
# Seed before Gear Lever creates its AppImage MIME preference file.
bash "$REPO_DIR/scripts/seed-default-apps.sh"
if install_recommended_profile; then
	info "Setting up Gear Lever for AppImage management..."
	if "$REPO_DIR/scripts/install-gearlever"; then
		ok "Gear Lever is installed."
	else
		warn "Gear Lever setup failed; retry with scripts/install-gearlever when Flathub is reachable."
	fi
fi
configure_displays_after_install

# ── Done ─────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║          Installation Complete!           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
info "Detected: $DISTRO_NAME"
echo "  • Build configuration: $REPO_DIR/config.h"
echo "  • Reconfigure by removing config.h and running the installer again"
echo "  • Display setup: dwm-display-setup"
echo "  • Log out and select 'dwm', or start with: startx"
if [[ $currentdm == "lightdm" ]]; then
	echo "  • Start LightDM now (optional): sudo systemctl start lightdm.service"
fi
echo ""
echo "  SUPER+/   keybind viewer     SUPER+X  terminal"
echo "  SUPER+F1  control center     SUPER+R  app launcher"
echo "  SUPER+Q   close window"
echo ""
echo "  Full reference: https://github.com/Dexmodzz/KinetixOS/blob/main/docs/src/content/keybinds.md or SUPER+/ in dwm"
echo ""
