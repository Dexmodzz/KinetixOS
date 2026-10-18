# ISO install-time questions - design

Date: 2026-10-18
Status: draft, awaiting owner approval
Branch: `codex/iso-install-questions`

## Intent

Installing KinetixOS from the two installer ISOs (standard, `dwm-fedora.ks`,
and NVIDIA, `dwm-fedora-nvidia.ks`) currently asks the user nothing about the
desktop. The Kickstart `%post` runs
`./install.sh --non-interactive --profile recommended`, so every question that
an interactive `install.sh` run asks is answered with a fixed default, and the
gaming package set (Steam, Gamescope, GameMode, MangoHud) is always installed
through `%include /tmp/kinetixos-gaming-packages`.

The owner wants the ISOs to ask a small, chosen set of questions during
installation, so that dwm is built once with the right values and the gaming
packages are installed only when the user asks for them.

## Goals

1. Both ISOs ask these questions during installation, before the graphical
   Anaconda installer is used:
   1. `Enable RPM Fusion nonfree for Fedora gaming packages? [y/N]`
   2. Interface font size, default `12`
   3. Primary modifier key (`super` or `alt`), default `super`
   4. Default master-area ratio, default `0.55`
   5. Default number of master windows, default `1`
2. Each question shows its default; pressing Enter accepts it. An invalid
   answer is rejected with a short message and the same question is asked
   again. Validation ranges must match `scripts/configure-build.sh`
   (font size 6-48, master count 1-10, ratio 0.05-0.95, modkey `super|alt`).
3. **No timeout, no bypass.** The questions are asked on every boot of
   either ISO. The installer waits on them until a person answers and must
   never proceed on its own with defaults. There is no boot argument, answers
   file or other way to skip them.
4. **Local screen and keyboard are required.** Before the first question the
   screen states that this installer needs a local screen and keyboard. The
   same requirement is written in `SPEC.md` and in the user install docs.
   Headless installs (serial console, VNC/RDP, PXE without a local console)
   are unsupported for these two ISOs.
5. Gaming packages (the current `/tmp/kinetixos-gaming-packages` list) are
   installed only when question 1 is answered yes. A no (or Enter, since the
   default is no) installs none of them. This applies to the ISOs only.
6. The answers to questions 2-5 reach `scripts/configure-build.sh` through its
   existing environment variables (`DWM_FONT_SIZE`, `DWM_MODKEY`, `DWM_MFACT`,
   `DWM_NMASTER`), so the generated `config.h` and the single dwm build use
   them.
7. In both ISOs the refresh rate is not asked and is fixed at `60`
   (`DWM_REFRESH_RATE=60`): the installer has no X session to detect it, and
   the user changes it later in settings. This rule applies to the ISOs only.
8. Cursor warp ("warp the pointer to the focused window") defaults to **off**
   everywhere, and is not asked in the ISOs:
   - `config.def.h`: `cursorwarp = 0`
   - `scripts/configure-build.sh`: `cursorwarp=${DWM_CURSORWARP:-0}`
   This change covers both ISOs and `install.sh`, which keeps asking the
   question, now defaulting to no.

## Non-goals

- No other change to `install.sh` behavior. It keeps every question it asks
  today, including the refresh rate with its auto-detection, the gaming
  repository question for the `full` profile, NVIDIA, display setup and
  graphical login. Only the cursor-warp default changes, because it comes from
  `configure-build.sh` and `config.def.h`.
- No first-login wizard. Display setup and the other deferred items stay as
  they are.
- No change to the ISO repository set. RPM Fusion free and nonfree stay
  declared in both Kickstarts whatever the gaming answer, because the NVIDIA
  ISO needs nonfree for `akmod-nvidia` and SPEC 5.11 already treats the image
  choice as consent to its repository policy. Only the gaming packages depend
  on the answer. (Owner direction: "if no, do not install the gaming
  packages".)
- The prebuilt system-image path is out of scope (owner: "leave the
  precompiled ISO, I will use it in the future"). That covers both
  `dwm-fedora-image.ks` and `scripts/build-dwm-fedora-system-image.py`.
  **Known limitation, accepted by the owner:** that builder installs
  `dwm-fedora.ks` / `dwm-fedora-nvidia.ks` unattended in a headless VM
  (`-display none`, `inst.text console=ttyS0`). After this change it will
  wait forever on the questions until its timeout kills it. Do not add a
  bypass for it now. Record the limitation in `SPEC.md` and
  `docs/RELEASING.md` (or wherever the system-image build is documented),
  and keep that script otherwise unchanged. Fixing it is future work.
  - Trap for that future work: the script runs
    `ks.replace('set -eu\n', 'set -eu\nexec > /dev/ttyS0 2>&1\n')` on every
    occurrence. If the new `%pre` body starts with `set -eu`, it will be
    rewritten too.
- `swallowfloating` and `resizehints` are not asked in the ISOs and keep
  their current defaults.

## Anti-goals

- The installation must never finish with silently chosen defaults while
  nobody answered.
- A no to the gaming question must never leave Steam, Gamescope, GameMode or
  MangoHud on the installed system.
- No change to the user-facing `install.sh` beyond the cursor-warp default.
- Anaconda's own explicit choices (disk selection, destructive-change
  confirmation, user creation) must not be preselected or bypassed.

## Constraints

- Fedora 44, Server Network Install ISO base, x86_64 (SPEC 5.11).
- `%pre` runs in the Anaconda installer environment before the UI and before
  `%packages` is resolved, which is why it already produces the gaming include
  file. The questions belong in `%pre`, and `%packages` keeps
  `%include /tmp/kinetixos-gaming-packages`, which becomes empty on no.
- `%pre` output is not attached to a terminal by default. The questions must
  be shown on a virtual console (redirect stdin/stdout to a free tty and
  switch to it with `chvt`), and Anaconda's normal console must be restored
  afterwards so the graphical installer appears as it does today.
- `%post` runs `su - "$target_user" -c '...'`. `su -` starts a clean login
  environment, so the `DWM_*` variables must be set inside the `-c` command
  string (or read from a file there), not exported in `%post`.
- The answers have to cross from the installer environment into the chroot
  `%post`. The existing `%post --nochroot` already copies from the installer
  side into `/mnt/sysimage`. Copy the answers file there too.
- The two Kickstarts must stay aligned: the same question logic in both.
  `tests/test-kickstart-variants.sh` already checks the invariants between
  them.
- Shell rules from `AGENTS.md`: ASCII, ShellCheck and shfmt clean. `%pre`
  bodies use the declared interpreter (`/bin/sh` today; switching to
  `/bin/bash` is acceptable if it is available in the installer image).
- Answers are values, not code. Never `eval` or source them; after
  validation, pass them as quoted literals.

## Decided by the owner

- The questions are asked during ISO installation, not at first login.
- The question list and defaults are as given in Goals 1-2.
- Refresh rate: not asked in the ISOs, fixed at 60.
- Cursor warp: not asked in the ISOs, default off in both ISOs and in
  `install.sh`.
- No timeout: wait until someone answers.
- The questions are always asked, with no bypass. The user is told that a
  local screen and keyboard are required.
- Only the two normal installer ISOs are in scope. The precompiled image
  and its builder are left for later, and its builder will hang meanwhile.
- The gaming answer affects only the ISOs; `install.sh` is unchanged.

## Calls made by the designer (owner may override)

- RPM Fusion repositories stay declared in both Kickstarts regardless of the
  gaming answer (see Non-goals).
- The questions are shown on the local console only. Following a serial
  console is not attempted, because headless installs are unsupported.
- The gaming question keeps its exact `install.sh` wording, with `[y/N]` and
  the default no.
- The question text stays in English, like the rest of the installer.

## Required companion changes

- `SPEC.md`: record that both installer ISOs ask the gaming question and the
  four build questions during installation, install the gaming set only on
  approval, use refresh rate 60, and that cursor warp now defaults to off.
  Also record that these ISOs require a local screen and keyboard, and the
  known system-image builder limitation.
  Update the section 5.10/5.11 text that currently implies the image decides
  its own package set.
- `tests/test-kickstart-variants.sh`: assert that both Kickstarts contain the
  question logic, that the gaming include is produced empty on no, and that
  `%post` passes the four `DWM_*` values and `DWM_REFRESH_RATE=60`.
- `tests/test-configure-build.sh`: cover the new cursor-warp default (it
  currently sets the value explicitly, so add a default-case assertion).
- Docs: `docs/src/content/troubleshooting.md` currently says to verify
  `cursorwarp = 1` and `docs/src/content/patches.md` describes cursor warp as
  always on. Update both, and the install page if it describes the ISO flow.
- `CHANGELOG.md` entry.

## Left to the builder

- Inline `%pre` shell, or a script under `scripts/image/` read from the
  embedded checkout. If a script, verify that `/run/install/repo/kinetixos`
  is mounted at `%pre` time on both BIOS and UEFI boots. If that cannot be
  verified, inline it.
- Which virtual console to use, and how the screen looks (header, spacing).
  Verify the Fedora 44 Anaconda console layout before picking a tty, so the
  graphical installer is not hidden.
- How to factor the validation so it cannot drift from
  `configure-build.sh` (shared ranges or a test that compares them).
- Whether an answers file or an env-prefix string carries the values into
  `su -`.

## Validation

- `scripts/run-tests make check-kickstart` (ksvalidator plus invariants).
- `scripts/run-tests make check-shell check-format`.
- `scripts/run-tests tests/test-configure-build.sh`.
- Full gate: `scripts/run-tests`.
- Real install evidence (static checks are not enough, SPEC 5.11): build each
  ISO, install it in a VM once with gaming yes and non-default build values,
  and once with gaming no. Confirm that the questions wait with no timeout,
  that Anaconda appears normally afterwards, that `config.h` in
  `~/.local/share/kinetixos` holds the answers with `refresh_rate = 60` and
  `cursorwarp = 0`, and that `rpm -q steam gamescope gamemode mangohud`
  matches the answer.
