# KinetixOS Roadmap

## Current scope

KinetixOS 0.1.0 is the first independent release line. The desktop source
update workflow in Settings > System follows the plan below.

## Desktop updates

1. Record installed revisions and managed file hashes; detect upstream changes,
   file drift, unsupported sources, and incomplete installations.
2. Build a confirmed revision without elevation and stage the full managed
   installation. Authorize only the root-owned manifest's system-file layout.
3. Display update discovery, confirmation, streamed progress, retained results,
   and restart guidance in the first System card.
4. Preserve personal configuration and recover interrupted replacement without
   overwriting newer installations or subsequent user changes.
5. Validate focused worker and UI scenarios, privileged boundaries in a disposable
   Fedora container, complete repository gates, and the actual managed X11 shell.
6. Complete independent review, address findings, publish the branch, and open a
   ready-for-review PR with validation evidence and any explicit runtime limits.

Exit: checks distinguish outdated source from stale installed files; a confirmed
update is backed up, staged, verified, and visible across Settings closure;
installation and activation are reported separately; recovery and authorization
failure are tested; the PR contains the required local review and validation.
