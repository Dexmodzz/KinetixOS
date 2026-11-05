# macOS Tahoe Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `macos-tahoe` theme: macOS-style Quickshell top bar, a Quickshell dock, blur, GTK CSS and wallpaper, selectable from the existing theme menu.

**Architecture:** Everything is driven by new `[style.*]` tokens whose defaults reproduce today's look, so other themes do not change. dwm learns to reserve a bottom dock separately from the top panel. Quickshell reads the tokens through the existing `style-value` provider path.

**Tech Stack:** C99/Xlib (dwm), Bash (helpers), QML/Quickshell, picom 13 (glx, dual_kawase), ImageMagick.

**Spec:** `docs/superpowers/specs/2026-11-05-macos-tahoe-design.md`

## Global Constraints

- No new packages. Optional `rsms-inter-fonts` only after explicit approval.
- Defaults of every new token reproduce the current behaviour exactly.
- ASCII punctuation in source and docs; Bash `set -euo pipefail`, POSIX `set -eu`; shellcheck + shfmt clean.
- QML: no polling timers, a single `PanelWindow` per surface (no per-screen `Variants`).
- Never overwrite `config.h` or user TOML without a backup.
- C99, `-Wall` clean, no blocking work in the X event loop.
- Local commits on `codex/macos-tahoe-theme`; no push/PR without user approval.

## Review Focus

1. Theme switch away from tahoe while the dock is mapped: dwm must release `dockh` (window unmapped/destroyed) and tiled windows regain the bottom space.
2. Dock appears before the top panel (startup order): the panel must still become `barwin`, the dock `dockwin`.
3. A user theme that sets an invalid new token (`bar_layout = "foo"`, `dock_apps = "a b"`): style marked invalid, falls back to classic, no QML errors.
4. A favorite in `dock_apps` with no installed desktop file: skipped silently, no empty icon.
5. Picom without blur support/stopped compositor: theme still applies; blur block omitted, no failure.

---

### Task 1: dwm reserves a bottom dock separately from the top panel

**Files:**
- Modify: `dwm.c` (struct `Monitor`, `updatealtbar`, `updatebarpos`, `scanaltbars`, unmap/destroy paths that clear `barwin`, `updateclientlist`)
- Create: `tests/test-dock-reserve-xvfb.sh`
- Modify: `Makefile` (`check-dock-reserve: all` target, add to `check:`)

**Interfaces:**
- Produces: `Monitor.dockwin` (Window), `Monitor.dockh` (int); `static int getstrutbottom(Window w)` returning the bottom strut in pixels or -1.

- [ ] **Step 1: Write the failing Xvfb test.** Same scaffolding as `tests/test-xvfb-runtime.sh` (Xvfb 1024x768, temp HOME with repo TOML). A C client with modes `panel` (dock-type 1024x32 at y=0), `dock` (dock-type 600x96 at y=672, `_NET_WM_STRUT_PARTIAL` bottom=72) and `normal`. Assertions:
  - after panel + normal: normal window `y >= 32` and `y+h <= 768`;
  - after dock is mapped: `_NET_CLIENT_LIST` contains the panel window, normal window `y >= 32` and `y+h <= 696`;
  - dock started BEFORE panel (fresh dwm): same two bounds hold;
  - after killing the dock client: normal window `y+h > 696`.
- [ ] **Step 2: Run `scripts/run-tests tests/test-dock-reserve-xvfb.sh`.** Expected: FAIL (dock replaces barwin, bound `y >= 32` broken).
- [ ] **Step 3: Implement.** In `updatealtbar`, a window whose center is in the bottom half of the monitor sets `dockwin`/`dockh` (`dockh = getstrutbottom(win)` if >= 0, else `wa->height`) and returns changed; otherwise current behaviour. `updatebarpos` subtracts `dockh` from `wh` after the bar logic. Wherever `barwin` is cleared on unmap/destroy, also match `dockwin` and clear `dockwin`/`dockh`, then `arrange`. `updateclientlist` lists `dockwin` like `barwin`. `getstrutbottom` reads `_NET_WM_STRUT_PARTIAL` (index 3), falling back to `_NET_WM_STRUT`.
- [ ] **Step 4: Run the test and `scripts/run-tests make clean all check-xvfb-runtime check-monitor-tags`.** Expected: PASS, no warnings. Update `tests/test-monitor-tag-switching.sh` greps only if a refactor changed a matched line.
- [ ] **Step 5: Commit** `feat(dwm): reserve a bottom dock separately from the top panel`.

### Task 2: New style tokens in the provider and Theme

**Files:**
- Modify: `scripts/dwm-settings-appearance` (`style_schema`, `validate_styles`)
- Modify: `config/quickshell/core/Theme.qml` (`applyStyle`, new properties)
- Test: `tests/test-dwm-settings-appearance.sh`, `tests/test-quickshell-design-system.sh`

**Interfaces:**
- Produces (schema): `bar_layout|enum|default,macos`, `bar_opacity|int|0|100`, `dock|bool`, `dock_icon_size|int|24|96`, `dock_magnify|int|100|200`, `dock_radius|int|0|64`, `dock_opacity|int|0|100`, `dock_apps|list|0|0`, `blur|bool`.
- Produces (Theme): `styleBarLayout: string` ("default"), `styleBarOpacity: int` (100), `styleDock: bool` (false), `styleDockIconSize: int` (48), `styleDockMagnify: int` (100), `styleDockRadius: int` (0), `styleDockOpacity: int` (100), `styleDockApps: var` ([]), `styleBlur: bool` (false); helper `function withOpacity(color, percent): string`.

- [ ] **Step 1: Failing provider tests:** a fixture style with all tokens valid emits `style-value\tbar_layout\tmacos` and `style-value\tdock_apps\tAlacritty,thunar`; `bar_layout = "foo"` -> error `invalid-value` and theme style invalid; `dock_apps = "a b"` -> `invalid-value`.
- [ ] **Step 2: Run** `scripts/run-tests tests/test-dwm-settings-appearance.sh` -> FAIL.
- [ ] **Step 3: Implement** kinds `enum` (min field holds comma-separated allowed values) and `list` (regex `^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$`, max 32 entries). Theme: parse `dock_apps` by splitting on `,`; bools as `=== "true"`.
- [ ] **Step 4: Design-system test** asserts `applyStyle("x", {})` keeps `styleBarLayout === "default"` and `styleDock === false` (grep-style, like the existing test). Run both tests -> PASS.
- [ ] **Step 5: Commit** `feat(appearance): add bar layout, dock and blur style tokens`.

### Task 3: macOS layout for the top bar

**Files:**
- Modify: `config/quickshell/panel/DwmPanel.qml`, `panel/LogoButton.qml`, `panel/WorkspaceButton.qml`, `core/ClockModel.qml`
- Test: `tests/test-quickshell-panel-settings.sh` (or the panel test that already greps `DwmPanel.qml`), `scripts/quickshell-qmllint`

**Interfaces:**
- Consumes: Task 2 Theme properties.
- Produces: `DwmPanel.macLayout: bool`; `ClockModel.macText: string` (`Qt.formatDateTime(now, "ddd d MMM HH:mm")`, locale from system); `LogoButton.glyph` override; `WorkspaceButton.dot: bool`.

- [ ] **Step 1: Failing structural test:** greps that `DwmPanel.qml` gates `RunningAppsArea` and the centre clock on `!root.macLayout`, and that `macLayout` derives only from `Theme.styleBarLayout === "macos"`.
- [ ] **Step 2: Run** -> FAIL.
- [ ] **Step 3: Implement** per spec section 3: full-width background `Theme.withOpacity(Theme.barBackground, Theme.styleBarOpacity)`, logo glyph U+F179, active app name (class, capitalised) bold `Theme.styleFontWeightStrong`, window title hidden, workspace buttons as 6 px dots, right side: existing widgets + `clock.macText`. Default layout bindings unchanged.
- [ ] **Step 4: Run** test + `scripts/run-tests make check-quickshell-qml` -> PASS.
- [ ] **Step 5: Commit** `feat(panel): add a macOS menu bar layout`.

### Task 4: Quickshell dock

**Files:**
- Create: `config/quickshell/dock/Dock.qml`, `dock/DockItem.qml`, `dock/qmldir`
- Modify: `config/quickshell/shell.qml` (one `Loader { active: Theme.styleDock }` on the focused screen)
- Create: `tests/test-quickshell-dock.sh`; Modify: `Makefile` (`check-quickshell-dock`, add to `check:`)

**Interfaces:**
- Consumes: `DwmState.runningApps` ([{windowId, appClass}]), `DwmState.focusWindow(windowId)`, `DwmState.focusedScreen()`, `Commands.launcherHelperCommand(action, args)`, Task 2 dock tokens, Quickshell `DesktopEntries.byId(id)`.
- Produces: `Dock.reservedHeight: int` = `iconSize + 2*padding + bottomMargin` (exclusiveZone).

- [ ] **Step 1: Failing test** (grep + qmllint): Dock has no `Timer`, no `Variants`; `exclusiveZone: root.reservedHeight`; window height >= `iconSize * magnify/100`; unknown desktop IDs filtered (`entry !== null`).
- [ ] **Step 2: Run** -> FAIL.
- [ ] **Step 3: Implement** per spec section 4. Launch action: read `scripts/dwm-quickshell-launcher` usage and use its existing launch-by-desktop-id action. Magnification: scale by horizontal distance from `MouseArea.mouseX`, cosine falloff over 2.5 icons, only while `containsMouse`.
- [ ] **Step 4: Run** test + qmllint -> PASS.
- [ ] **Step 5: Commit** `feat(dock): add a Quickshell dock driven by the style profile`.

### Task 5: Picom blur from the style profile

**Files:**
- Modify: `scripts/dwm-settings-picom` (`apply-theme-style` accepts optional 6th arg `blur=0|1`), `scripts/theme-apply.sh` (`picom_style_args`)
- Test: `tests/test-picom.py`

- [ ] **Step 1: Failing test:** with blur=1 the marked block contains `blur-method = "dual_kawase";`, `blur-strength = 5;`, `blur-background = false;` and a rule `match = "class_g = 'quickshell'"; blur-background = true;`; with 5 args the block is byte-identical to today.
- [ ] **Step 2: Run** `scripts/run-tests make check-picom` (or the target owning `test-picom.py`) -> FAIL.
- [ ] **Step 3: Implement**; verify the real Quickshell WM_CLASS with `xprop` on the running panel before fixing the match string.
- [ ] **Step 4: Run** -> PASS; shellcheck/shfmt.
- [ ] **Step 5: Commit** `feat(picom): blur shell surfaces for styles that ask for it`.

### Task 6: GTK CSS block for styled themes

**Files:**
- Modify: `scripts/theme-apply.sh`
- Create: `config/gtk/tahoe.css` (shared GTK3/GTK4 rules: accent `#0A84FF`, radii)
- Test: `tests/test-dwm-settings-theme.sh` (or a new `tests/test-gtk-style-css.sh`)

- [ ] **Step 1: Failing test:** applying a theme with `style = "tahoe"` writes `/* kinetixos style css begin */ ... end */` into `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`, creating `gtk.css.kinetixos-backup` once if the file pre-existed; applying `nord` removes the block and leaves the rest untouched.
- [ ] **Step 2: Run** -> FAIL. **Step 3: Implement** (CSS file installed via the existing install-user-files path; look it up in `$data_home/kinetixos/config/gtk/<style>.css`). **Step 4: Run** -> PASS. **Step 5: Commit** `feat(theme): style-scoped GTK CSS`.

### Task 7: The macos-tahoe theme, wallpaper, docs

**Files:**
- Modify: `config/themes.toml` (`[theme.macos-tahoe]`, `[style.tahoe]` with spec values), header list of themes
- Create: `assets/wallpapers/tahoe-dusk.png` (generated, ImageMagick script in `scripts/generate-tahoe-wallpaper.sh`)
- Modify: `CHANGELOG.md`, `docs/src/content/...` theme list page if it lists themes

- [ ] **Step 1:** `scripts/run-tests tests/test-dwm-settings-appearance-inventory.sh` with the new theme -> provider reports `macos-tahoe` valid, `style tahoe` valid.
- [ ] **Step 2:** full gate `scripts/run-tests` -> PASS.
- [ ] **Step 3: Commit** `feat(theme): add the macos-tahoe theme`.

### Task 8: Live install and verification

- [ ] Backup `~/.config/kinetixos/themes.toml`, `~/.config/picom.conf`, `~/.config/gtk-3.0/*`, `~/.config/gtk-4.0/*` to `~/.local/state/kinetixos/backup-2026-11-05/`.
- [ ] `scripts/dev-sync-install.sh`, then `dwm-settings-theme merge-shipped`, restart dwm (`kill -HUP`) and Quickshell (`dwm-quickshell-controlcenter action restart-quickshell`).
- [ ] Apply `macos-tahoe` from the menu; `maim` screenshot; compare with the reference; fix and repeat.
- [ ] Checks: tiled windows clear of bar and dock; `ps -o %cpu` of quickshell near 0 over 30 s idle; Thunar (GTK3) and File Roller (GTK4) themed; switch to `moderno-morbido` and back.
