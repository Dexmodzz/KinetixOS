# ISO Install-Time Questions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two installer ISOs (`dwm-fedora.ks`, `dwm-fedora-nvidia.ks`) ask the gaming question and four dwm build questions during installation, install gaming packages only on yes, and make cursor warp default to off everywhere.

**Architecture:** One POSIX `sh` helper, `scripts/image/iso-questions.sh`, owns the questions, their validation and the answers file. Both Kickstarts call it from `%pre` (asking on a virtual console, writing the gaming `%include`) and from `%post` (turning the answers into validated `DWM_*` assignments for `install.sh`). The cursor-warp default changes in `config.def.h` and `scripts/configure-build.sh`.

**Tech Stack:** POSIX sh, Bash tests, Fedora Kickstart (Anaconda `%pre`/`%post`), ksvalidator, ShellCheck, shfmt.

**Spec:** `docs/superpowers/specs/2026-10-18-iso-install-questions-design.md`

## Global Constraints

- Questions, in order, with defaults: `Enable RPM Fusion nonfree for Fedora gaming packages? [y/N]` (no); interface font size (`12`); primary modifier key `super` or `alt` (`super`); default master-area ratio (`0.55`); default number of master windows (`1`).
- Validation must equal `scripts/configure-build.sh`: font size integer 6-48; master count integer 1-10; ratio matches `^(0|1)(\.[0-9]+)?$` and 0.05-0.95; modkey `super|alt`, case-insensitive.
- No timeout and no bypass: never write answers that a person did not give (Enter on a shown default counts as an answer). End of input means failure, never defaults.
- Banner before the first question must say a screen and keyboard are required (physical, or a VM console such as Proxmox).
- In the ISOs: `DWM_REFRESH_RATE=60` and `DWM_CURSORWARP=0`, neither asked.
- Cursor warp default off: `config.def.h` `cursorwarp = 0`; `configure-build.sh` `cursorwarp=${DWM_CURSORWARP:-0}`. `install.sh` itself is not edited.
- Gaming packages (steam, gamescope, gamemode.x86_64, gamemode.i686, mangohud.x86_64, mangohud.i686, x86_64 only) are installed only on yes. Repository lines in the Kickstarts do not change.
- Out of scope: `dwm-fedora-image.ks`, `scripts/build-dwm-fedora-system-image.py` (document its known hang only).
- Both Kickstarts keep identical `%pre` blocks.
- ASCII only; `set -eu` for sh; ShellCheck and shfmt clean; answers are never `eval`ed or sourced.
- Branch `codex/iso-install-questions`; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Input ends before all answers (closed tty, Ctrl+D): the installer must abort with a message, not continue with defaults. Test: `ask_fails_on_eof` (Task 2).
2. A tampered or hand-edited answers file (shell metacharacters, missing key): `env` must refuse and print nothing, so `%post` fails before running `install.sh`. Tests: `env_rejects_injection`, `env_rejects_missing_key` (Task 2).
3. Answers typed with odd case or spaces (`Y`, `YES`, ` alt `, `ALT`): accepted and normalised. Test: `ask_normalises_case_and_spaces` (Task 2).
4. Range drift between this helper and `configure-build.sh`: a boundary accepted here must be accepted there and vice versa. Test: `ranges_match_configure_build` (Task 2).
5. The two Kickstarts drifting apart, or a no answer still leaving gaming packages in `%packages`. Tests: `%pre` identical check and the executed `%pre` fixtures for yes and no (Task 3).

---

### Task 1: Cursor warp defaults to off

**Files:**
- Modify: `config.def.h:7`
- Modify: `scripts/configure-build.sh:160`
- Modify: `tests/test-configure-build.sh`
- Modify: `docs/src/content/troubleshooting.md:120`, `docs/src/content/patches.md:93`

**Interfaces:**
- Produces: `configure-build.sh --non-interactive` with no `DWM_CURSORWARP` writes `cursorwarp = 0`.

- [ ] **Step 1: Write the failing test.** In `tests/test-configure-build.sh`, add a default-case run: `env -u DWM_CURSORWARP scripts/configure-build.sh --non-interactive --template "$repo_dir/config.def.h" --output "$default_output"` and assert `grep -Eq 'cursorwarp[[:space:]]*=[[:space:]]*0;' "$default_output"`. Also assert `grep -Eq '^static const int cursorwarp[[:space:]]*=[[:space:]]*0;' "$repo_dir/config.def.h"`.
- [ ] **Step 2: Run it and see it fail.** `scripts/run-tests tests/test-configure-build.sh` -> FAIL on the new assertion.
- [ ] **Step 3: Implement.** `config.def.h` -> `cursorwarp = 0;` (keep the comment). `configure-build.sh` -> `cursorwarp=${DWM_CURSORWARP:-0}`. Docs: troubleshooting says cursor warp is off by default and is enabled with `cursorwarp = 1` in `config.h`; patches.md says the patch is present but off by default.
- [ ] **Step 4: Run.** `scripts/run-tests tests/test-configure-build.sh` -> PASS. Do not touch the local `config.h`.
- [ ] **Step 5: Commit.** `git commit -m "feat: default cursor warp to off"` with the files above.

### Task 2: `scripts/image/iso-questions.sh` helper

**Files:**
- Create: `scripts/image/iso-questions.sh`
- Create: `tests/test-iso-questions.sh`
- Modify: `Makefile` (`check-shell`, `check-format`: add `scripts/image/iso-questions.sh`; `check-kickstart`: run `tests/test-iso-questions.sh` before `tests/test-kickstart-variants.sh`)

**Interfaces:**
- Produces, CLI (POSIX sh, `set -eu`):
  - `iso-questions.sh ask ANSWERS_FILE` - shows the banner and the five questions, re-asks on invalid input with one line naming the accepted values, writes `ANSWERS_FILE` (mode 0600, written to a temp file then `mv`) and exits 0. Exits 1 without creating the file if input ends. I/O device comes from `KINETIXOS_QUESTIONS_TTY` (default `/dev/tty8`). Value `stdio` means use the current stdin/stdout and skip `chvt`. Otherwise redirect stdin/stdout/stderr to that device, run `chvt 8` before the questions and `chvt 1` after (a missing `chvt` only warns).
  - Answers file format, exactly these lines in this order: `KINETIXOS_GAMING=yes|no`, `DWM_FONT_SIZE=<int>`, `DWM_MODKEY=super|alt`, `DWM_MFACT=<decimal>`, `DWM_NMASTER=<int>`.
  - `iso-questions.sh gaming ANSWERS_FILE` - prints `yes` or `no`; exits 1 on a missing or invalid file.
  - `iso-questions.sh env ANSWERS_FILE` - re-validates every value and prints one line: `DWM_REFRESH_RATE=60 DWM_CURSORWARP=0 DWM_FONT_SIZE=<v> DWM_MODKEY=<v> DWM_MFACT=<v> DWM_NMASTER=<v>`; exits 1 and prints nothing to stdout on any missing, duplicate, unknown or invalid line.
- Parse the file line by line with `case`/`read`; never source it.

- [ ] **Step 1: Write the failing tests** in `tests/test-iso-questions.sh` (Bash, `set -euo pipefail`, temp dir with trap, `KINETIXOS_QUESTIONS_TTY=stdio`):
  - `ask_defaults`: input `'\n\n\n\n\n'` -> file equals `KINETIXOS_GAMING=no`, `DWM_FONT_SIZE=12`, `DWM_MODKEY=super`, `DWM_MFACT=0.55`, `DWM_NMASTER=1`; file mode `600`.
  - `ask_custom`: `'y\n14\nalt\n0.60\n2\n'` -> `yes`, `14`, `alt`, `0.60`, `2`.
  - `ask_retries_invalid`: `'maybe\nn\n500\n5\n49\n16\nctrl\nsuper\n1.5\n0.04\n0.5\n0\n11\n3\n'` -> `no`, `16`, `super`, `0.5`, `3`.
  - `ask_normalises_case_and_spaces`: `'YES\n 20 \n ALT \n0.7\n4\n'` -> `yes`, `20`, `alt`, `0.7`, `4`.
  - `ask_fails_on_eof`: `'y\n14\n'` -> exit status non-zero and the answers file does not exist.
  - `ask_banner`: output of a default run contains `screen and keyboard` and `Proxmox`.
  - `gaming_reads_answer`: prints `yes` for the custom file, `no` for the defaults file.
  - `env_line`: custom file -> exactly `DWM_REFRESH_RATE=60 DWM_CURSORWARP=0 DWM_FONT_SIZE=14 DWM_MODKEY=alt DWM_MFACT=0.60 DWM_NMASTER=2`.
  - `env_rejects_injection`: file with `DWM_FONT_SIZE=12;reboot` -> non-zero, empty stdout.
  - `env_rejects_missing_key`: file without `DWM_NMASTER` -> non-zero, empty stdout.
  - `ranges_match_configure_build`: for font 6, 48 and nmaster 1, 10 and mfact 0.05, 0.95, both `ask` (via stdio) and `scripts/configure-build.sh --non-interactive --output <tmp>` with the matching `DWM_*` accept; for font 5, 49, nmaster 0, 11, mfact 0.04, 0.96 `configure-build.sh` fails and `ask` re-asks (feed a valid value after it and check the valid value is stored).
- [ ] **Step 2: Run and see it fail.** `scripts/run-tests tests/test-iso-questions.sh` -> FAIL (helper missing).
- [ ] **Step 3: Implement** `scripts/image/iso-questions.sh` to the interface above. Banner text (exact copy, ASCII):

  ```
  KinetixOS installer setup

  This installer needs a screen and keyboard: a physical machine, or a
  virtual machine console such as Proxmox. It waits until every question
  is answered. Press Enter to accept the default shown in brackets.
  ```

  Prompts: `Enable RPM Fusion nonfree for Fedora gaming packages? [y/N] `, `Interface font size [12]: `, `Primary modifier key (super or alt) [super]: `, `Default master-area ratio [0.55]: `, `Default number of master windows [1]: `. Trim leading/trailing spaces; yes = `y|yes` any case, no = `n|no` any case or empty.
- [ ] **Step 4: Wire the Makefile** (lint lists and `check-kickstart`).
- [ ] **Step 5: Run.** `scripts/run-tests tests/test-iso-questions.sh` -> PASS; `scripts/run-tests make check-shell check-format` -> PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: add ISO install question helper"`.

### Task 3: Wire both Kickstarts

**Files:**
- Modify: `dwm-fedora.ks`, `dwm-fedora-nvidia.ks` (`%pre`, `%post --nochroot`, `%post`)
- Modify: `tests/test-kickstart-variants.sh`

**Interfaces:**
- Consumes: `iso-questions.sh ask|gaming|env` from Task 2.
- Produces: installer-side `/tmp/kinetixos-install-answers`; target-side `/root/kinetixos-install-answers` (removed after `install.sh` succeeds).

- [ ] **Step 1: Write the failing tests** in `tests/test-kickstart-variants.sh`, inside the per-Kickstart loop unless noted:
  - The `%pre` block (from `%pre` to its `%end`) is byte-identical in both Kickstarts (outside the loop).
  - `%pre` is declared `%pre --interpreter=/bin/sh --erroronfail` and its first body line is not `set -eu` (the system-image builder rewrites that line).
  - Executed `%pre` fixture: extract the `%pre` body, `sed` `/run/install/repo/kinetixos` -> `$repo` and `/tmp/` -> `$work/pre/`, run with `KINETIXOS_QUESTIONS_TTY=stdio`. Input `'y\n\n\n\n\n'` -> `$work/pre/kinetixos-gaming-packages` holds exactly the six gaming lines (x86_64 host). Input `'\n\n\n\n\n'` -> that file exists and is empty. Input `''` -> non-zero exit.
  - `grep -Fq 'install -m 0600 /tmp/kinetixos-install-answers /mnt/sysimage/root/kinetixos-install-answers'`.
  - `grep -Fq 'iso-questions.sh" env /root/kinetixos-install-answers'` and the `su` line contains `$install_env dbus-run-session`.
  - Keep the existing assertions (`./install.sh --non-interactive --profile recommended`, the literal `export DBUS_SYSTEM_BUS_ADDRESS=\$DBUS_SESSION_BUS_ADDRESS; exec ./install.sh`, `%include /tmp/kinetixos-gaming-packages`, `case "$(uname -m)" in`, the gaming packages in `required_packages`).
- [ ] **Step 2: Run and see it fail.** `scripts/run-tests tests/test-kickstart-variants.sh` -> FAIL.
- [ ] **Step 3: Implement `%pre`** (same text in both files): set `answers=/tmp/kinetixos-install-answers`, `gaming_packages=/tmp/kinetixos-gaming-packages`, `questions=/run/install/repo/kinetixos/scripts/image/iso-questions.sh`; truncate the gaming file; exit 1 with a message if `questions` is not readable; `sh "$questions" ask "$answers" || exit 1`; if `sh "$questions" gaming "$answers"` prints `yes`, keep today's `case "$(uname -m)" in x86_64)` heredoc writing the six packages. Check every command with `|| exit 1` instead of a leading `set -eu`.
- [ ] **Step 4: Implement `%post --nochroot`:** after the checkout copy, add `install -m 0600 /tmp/kinetixos-install-answers /mnt/sysimage/root/kinetixos-install-answers`.
- [ ] **Step 5: Implement `%post`:** after `chown -R ... "$target_repo_dir"`, set `install_env=$(sh "$repo_dir/scripts/image/iso-questions.sh" env /root/kinetixos-install-answers)`. Change the `su` line to double-quoted form so the validated assignments are prefixed:

  ```sh
  su - "$target_user" -c "cd \"\$HOME/.local/share/kinetixos\" && $install_env dbus-run-session -- sh -c 'export DBUS_SYSTEM_BUS_ADDRESS=\$DBUS_SESSION_BUS_ADDRESS; exec ./install.sh --non-interactive --profile recommended'"
  rm -f /root/kinetixos-install-answers
  ```

  Keep the comment above it. `$repo_dir` (`/opt/kinetixos`) is still present at that point; it is removed later.
- [ ] **Step 6: Run.** `scripts/run-tests make check-kickstart` -> PASS (ksvalidator, invariants, ISO builder checks).
- [ ] **Step 7: Commit.** `git commit -m "feat: ask install questions in the installer ISOs"`.

### Task 4: Requirements, docs and changelog

**Files:**
- Modify: `SPEC.md` (section 5.10 paragraph at the Kickstart repository text near line 246; section 5.11 Fedora Image Contract)
- Modify: `docs/src/content/install.md` (new subsection under "Fedora ISO")
- Modify: `docs/COMPRESSED-IMAGES.md` (known limitation near the `build-dwm-fedora-system-image.py` example)
- Modify: `CHANGELOG.md` (`[Unreleased]`)

- [ ] **Step 1: SPEC.md 5.11.** Add: both installer ISOs ask, before Anaconda's UI, the gaming question and the font size, modifier key, master ratio and master count questions, with no timeout and no bypass; they install the Fedora gaming set only on yes; they build with refresh rate 60 and cursor warp off; they require a screen and keyboard (physical or a VM display console such as Proxmox VE; serial-only, `inst.vnc` and `inst.rdp` installs are unsupported). Add: the system-image builder installs these Kickstarts unattended and currently waits on the questions until its timeout; this is a known limitation. In 5.10 add that cursor warp defaults to off.
- [ ] **Step 2: install.md.** Add "### Installer ISO questions" listing the five questions and defaults, the screen and keyboard requirement with Proxmox noted as supported, and that refresh rate (60) is changed later in Settings.
- [ ] **Step 3: COMPRESSED-IMAGES.md.** One paragraph: the factory build currently hangs on the installer questions; not fixed yet.
- [ ] **Step 4: CHANGELOG.md.** Under `### Added`: installer ISOs ask the gaming and dwm layout questions, and install gaming packages only on yes. Under `### Changed`: cursor warp is off by default.
- [ ] **Step 5: Check ASCII.** `LC_ALL=C grep -nP '[^\x00-\x7F]'` on the changed lines added by this task -> none new.
- [ ] **Step 6: Commit.** `git commit -m "docs: document ISO install questions"`.

### Task 5: Full gate and hand-off

- [ ] **Step 1:** `scripts/run-tests` -> PASS (full `make check`). Report any failure faithfully.
- [ ] **Step 2:** If `make check` cannot run a target here (missing ksvalidator, Xvfb), run `scripts/run-tests make check-kickstart check-build-config check-shell check-format` and report which targets were skipped and why.
- [ ] **Step 3:** Push the branch and open a ready PR (`gh pr create`), body ending with the Claude Code attribution line. Do not merge.
- [ ] **Step 4:** Tell the owner the manual VM checks still required from the spec's Validation section (standard and NVIDIA ISO; gaming yes and no; one run in a Proxmox VM via noVNC; `config.h` values; `rpm -q steam gamescope gamemode mangohud`), and note that the `chvt 8`/`chvt 1` console choice is verified only by that run.
