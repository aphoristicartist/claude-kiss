# Contributing to Claude KISS

Claude KISS is intentionally small. Changes should make the launcher more correct,
inspectable, or useful without creating a second agent runtime.

Read [MANIFESTO.md](MANIFESTO.md) for the design rules and
[REFERENCE.md](REFERENCE.md) for the current mechanics before changing behavior.

## What makes a good change

- Fix one concrete problem at the layer that owns it.
- Prefer native Claude Code mechanisms over wrapper-specific abstractions.
- Keep managed defaults strong without describing them as a sandbox.
- Preserve the normal `claude` command and user-owned KISS configuration.
- Add focused coverage for behavior changes.
- Update public documentation when a switch, flag, path, tool, or trust boundary changes.

Open an issue before building a new capability, profile system, integration layer, background
service, dependency, or configuration language. Those choices change the project's shape.

## Local setup

The repository has no install step or vendored dependencies. For the full validation suite,
use macOS or Linux with:

- a recent Claude Code CLI in `PATH`;
- POSIX `sh`;
- Python 3;
- ShellCheck;
- `pipx` for the pinned Ruff invocation used by CI.

The integration suite exercises CLI flags with `claude --version`; it does not send model
requests. The evaluator sends requests only when run without `--dry-run`.

## Validate a change

Run the integration suite first:

```sh
./tests/test.sh
```

Run the same static checks as CI:

```sh
sh -n bin/claude-kiss install.sh tests/test.sh build-release.sh
shellcheck bin/claude-kiss install.sh tests/test.sh build-release.sh
python3 -m py_compile evals/run_evals.py
python3 -m json.tool config/settings.json >/dev/null
pipx run --spec ruff==0.16.4 ruff check evals/run_evals.py
```

Confirm the release archive still builds:

```sh
./build-release.sh
```

Report the exact commands you ran. If a required check could not run, state why and identify
the remaining risk.

## Test expectations

Behavior changes belong in `tests/test.sh`. Prefer assertions about resolved arguments,
files, exit status, preservation, and configuration state over assertions that freeze prose.

Prompt behavior belongs in the paired evaluator when it can be checked from resulting files
or a precise answer. Inspect a planned invocation without spending budget:

```sh
python3 evals/run_evals.py --dry-run --tasks scope_discipline
```

A live evaluator run is a smoke test, not a universal benchmark. Record the model, effort,
budget, Claude Code version, date, and per-task results when publishing a comparison.

## Documentation expectations

Keep each document focused:

- `README.md` helps a user decide, install, inspect, customize, update, and uninstall.
- `REFERENCE.md` owns exact tools, flags, variables, precedence, paths, and edge cases.
- `WHY.md` owns sourced evidence and explicit tradeoffs.
- `MANIFESTO.md` owns durable design principles.

Avoid copying the same technical inventory into multiple files. Use relative links and verify
heading anchors after renaming a section. Describe Claude Code behavior as version-sensitive
unless the launcher itself enforces it.

## Version changes

The release version appears in three source locations:

```text
VERSION
bin/claude-kiss
install.sh
```

`tests/test.sh` verifies that they agree. A version change should also update examples that
show the wrapper version, build and inspect the release archive, and produce release notes
that explain user-visible behavior and compatibility changes.

Publishing tags, GitHub releases, or website artifacts is maintainer work. A release is not
complete until the canonical installer, archive, checksum, GitHub release, and documentation
all resolve to the same version and a clean standalone installation succeeds.

## Pull requests

Keep pull requests narrow. Include:

- the user-visible problem;
- the reason the chosen layer owns the fix;
- behavior and compatibility changes;
- validation commands and results;
- documentation or release implications.

Do not include generated `dist/`, evaluator results, caches, or unrelated formatting changes.
