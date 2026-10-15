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

# Hardware and package state come from the environment so each case is
# independent of the host GPU and installed driver.
cat >"$work/bin/lspci" <<'EOF'
#!/bin/sh
printf '%s\n' "${DWM_TEST_LSPCI:-}"
EOF
cat >"$work/bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
-m) printf '%s\n' "${DWM_TEST_UNAME:-x86_64}" ;;
-r) printf '%s\n' 7.2.8-200.fc44.x86_64 ;;
*) exec /usr/bin/uname "$@" ;;
esac
EOF
cat >"$work/bin/rpm" <<'EOF'
#!/bin/sh
printf 'rpm\t%s\n' "$*" >>"${DWM_TEST_LOG:-/dev/null}"
case "$*" in
'-E %fedora') printf '44\n' ;;
"-q akmod-nvidia") [ "${DWM_TEST_DRIVER_INSTALLED:-0}" = 1 ] ;;
"-q rpmfusion-free-release") [ "${DWM_TEST_FREE_ENABLED:-0}" = 1 ] ;;
"-q rpmfusion-nonfree-release") exit 1 ;;
*) exit 1 ;;
esac
EOF
for command_name in sudo mokutil; do
	cat >"$work/bin/$command_name" <<'EOF'
#!/bin/sh
printf '%s\t%s\n' "${0##*/}" "$*" >>"${DWM_TEST_LOG:?}"
if [ "${0##*/}" = mokutil ]; then
	printf 'SecureBoot %s\n' "${DWM_TEST_SECURE_BOOT:-disabled}"
fi
case "$*" in
akmods*) exit "${DWM_TEST_AKMODS_STATUS:-0}" ;;
esac
EOF
done
chmod +x "$work/bin/"*

nvidia_gpu='01:00.0 VGA compatible controller: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti Mobile]'
amd_gpu='05:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Radeon Vega'

run_plan() {
	env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
		PATH="$work/bin:$PATH" "$@" \
		"$repo/install.sh" --dry-run --non-interactive --profile core
}

expect_plan() {
	local expected=$1 output="$work/plan.out"
	shift
	run_plan "$@" >"$output"
	if ! command grep -Fxq "  NVIDIA driver: $expected" "$output"; then
		printf 'Expected NVIDIA plan "%s", got:\n' "$expected" >&2
		command grep -F 'NVIDIA driver:' "$output" >&2 || true
		exit 1
	fi
}

hybrid_gpu="$amd_gpu
$nvidia_gpu"

expect_plan 'skipped (no NVIDIA GPU detected)' DWM_TEST_LSPCI="$amd_gpu"
expect_plan 'requires separate confirmation (use --install-nvidia when unattended)' \
	DWM_TEST_LSPCI="$hybrid_gpu"
expect_plan 'approved (akmod-nvidia from RPM Fusion free and nonfree)' \
	DWM_TEST_LSPCI="$nvidia_gpu" DWM_INSTALL_NVIDIA=yes
expect_plan 'already installed (akmod-nvidia)' \
	DWM_TEST_LSPCI="$nvidia_gpu" DWM_TEST_DRIVER_INSTALLED=1
expect_plan 'skipped (unsupported architecture: aarch64)' \
	DWM_TEST_LSPCI="$nvidia_gpu" DWM_TEST_UNAME=aarch64

env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
	DWM_TEST_LSPCI="$nvidia_gpu" PATH="$work/bin:$PATH" \
	"$repo/install.sh" --dry-run --non-interactive --profile core --install-nvidia \
	>"$work/flag.out"
command grep -Fq '  NVIDIA driver: approved' "$work/flag.out"
env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
	DWM_TEST_LSPCI="$nvidia_gpu" PATH="$work/bin:$PATH" \
	"$repo/install.sh" --dry-run --non-interactive --profile core --skip-nvidia \
	>"$work/skip.out"
command grep -Fq '  NVIDIA driver: skipped (--skip-nvidia)' "$work/skip.out"

if env HOME="$work/home" DWM_TEST_MODE=1 DWM_OS_RELEASE="$work/os-release" \
	DWM_INSTALL_NVIDIA=sometimes PATH="$work/bin:$PATH" \
	"$repo/install.sh" --dry-run --non-interactive --profile core \
	>"$work/invalid.out" 2>&1; then
	printf 'install.sh accepted an invalid DWM_INSTALL_NVIDIA value\n' >&2
	exit 1
fi
command grep -Fq 'Unsupported DWM_INSTALL_NVIDIA: sometimes' "$work/invalid.out"

# Exercise the prompt and install steps with the real function bodies.
functions="$work/nvidia-functions.sh"
for name in fedora_numeric_release enable_rpmfusion_repositories \
	nvidia_driver_installed nvidia_driver_candidate confirm_nvidia_driver \
	secure_boot_enabled install_nvidia_driver; do
	sed -n "/^$name() {\$/,/^}\$/p" "$repo/install.sh" >>"$functions"
	command grep -Fq "$name() {" "$functions"
done

run_function() {
	local mode=$1 answer=$2
	shift 2
	# shellcheck disable=SC2016 # Expanded by the inner shell.
	env DWM_TEST_LOG="$work/commands.log" PATH="$work/bin:$PATH" "$@" \
		bash -c '
			set -euo pipefail
			info() { printf "[INFO] %s\n" "$1"; }
			ok() { printf "[OK] %s\n" "$1"; }
			warn() { printf "[WARN] %s\n" "$1"; }
			detect_gpu() { case $DWM_TEST_LSPCI in *NVIDIA*) echo nvidia ;; *) echo amd ;; esac; }
			dwm_install_package_profile() { printf "packages\t%s\n" "$1" >>"$DWM_TEST_LOG"; }
			DISTRO_ID=fedora ARCH=x86_64 NVIDIA_INSTALL_MODE=$1 NON_INTERACTIVE=false
			NVIDIA_DRIVER_APPROVED=false
			. "$2"
			confirm_nvidia_driver
			install_nvidia_driver
		' sh "$mode" "$functions" <<<"$answer"
}

: >"$work/commands.log"
run_function auto n DWM_TEST_LSPCI="$nvidia_gpu" >"$work/declined.out"
command grep -Fq 'Install the proprietary NVIDIA driver (akmod-nvidia)? [y/N]' "$work/declined.out"
command grep -Fq 'NVIDIA driver declined' "$work/declined.out"
if command grep -Eq '^(sudo|packages)' "$work/commands.log"; then
	printf 'Declined NVIDIA prompt still changed the system\n' >&2
	exit 1
fi

: >"$work/commands.log"
run_function auto y DWM_TEST_LSPCI="$nvidia_gpu" DWM_TEST_FREE_ENABLED=1 \
	DWM_TEST_SECURE_BOOT=enabled >"$work/accepted.out"
command grep -Fq 'RPM Fusion free is already enabled.' "$work/accepted.out"
command grep -Fxq $'sudo\tdnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm' \
	"$work/commands.log"
command grep -Fxq $'packages\tnvidia' "$work/commands.log"
command grep -Fxq $'sudo\takmods --force --kernels 7.2.8-200.fc44.x86_64' "$work/commands.log"
command grep -Fq 'Secure Boot is enabled' "$work/accepted.out"
command grep -Fq 'Reboot before using it.' "$work/accepted.out"

: >"$work/commands.log"
run_function true '' DWM_TEST_LSPCI="$nvidia_gpu" DWM_TEST_AKMODS_STATUS=1 \
	>"$work/build-failure.out"
command grep -Fxq $'sudo\tdnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm' \
	"$work/commands.log"
command grep -Fq 'Retry with: sudo akmods --force --kernels 7.2.8-200.fc44.x86_64' \
	"$work/build-failure.out"
if command grep -Fq '[y/N]' "$work/build-failure.out"; then
	printf 'Explicit --install-nvidia approval still prompted\n' >&2
	exit 1
fi

: >"$work/commands.log"
run_function auto y DWM_TEST_LSPCI="$amd_gpu" >"$work/no-gpu.out"
if [[ -s $work/no-gpu.out ]] || command grep -Eq '^(sudo|packages)' "$work/commands.log"; then
	printf 'NVIDIA flow ran without an NVIDIA GPU\n' >&2
	exit 1
fi

: >"$work/commands.log"
run_function auto y DWM_TEST_LSPCI="$nvidia_gpu" DWM_TEST_DRIVER_INSTALLED=1 \
	>"$work/already.out"
command grep -Fq 'NVIDIA akmod driver already installed.' "$work/already.out"
if command grep -Eq '^(sudo|packages)' "$work/commands.log"; then
	printf 'Installed NVIDIA driver was reinstalled\n' >&2
	exit 1
fi

printf 'install-nvidia tests: PASS\n'
