## Problem

What user-visible problem does this solve?

## Change

Why does this layer own the fix? Note behavior, compatibility, documentation, and release
implications.

## Validation

List the exact commands and results. At minimum:

- [ ] `./tests/test.sh`
- [ ] `git diff --check`
- [ ] `./build-release.sh` when packaging or installer behavior changes

If a check could not run, explain why and identify the remaining risk.

## Scope and safety

- [ ] The change is focused and contains no unrelated formatting or generated artifacts.
- [ ] Public behavior and trust-boundary changes are documented.
- [ ] Logs, screenshots, and fixtures contain no credentials, private source, or personal paths.
