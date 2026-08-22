# Claude KISS

<p align="center">
  <strong>Claude Code, tuned for people who ship.</strong>
</p>

<p align="center">
  Less surface. More shipping. A second launcher for Claude Code with concise,
  user-owned defaults: questions stay questions, fixes stay focused, extras are explicit,
  and you can inspect the exact command before it runs.
</p>

<p align="center">
  <a href="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml"><img src="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://github.com/aphoristicartist/claude-kiss/releases/latest"><img src="https://img.shields.io/github/v/release/aphoristicartist/claude-kiss?display_name=tag&include_prereleases&label=release" alt="Latest release"></a>
  <a href="https://claude-kiss.com"><img src="https://img.shields.io/website?url=https%3A%2F%2Fclaude-kiss.com&down_color=red&down_message=offline&up_color=2aa198&up_message=online" alt="claude-kiss.com status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aphoristicartist/claude-kiss?color=blue" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-informational" alt="Supported platforms">
  <img src="https://img.shields.io/badge/requires-Claude%20Code-6e5cf0" alt="Requires Claude Code">
</p>

<p align="center">
  <a href="https://claude-kiss.com">
    <img src="https://claude-kiss.com/og.jpg" alt="Claude Code, tuned for people who ship">
  </a>
</p>

---

## Install

Install [Claude Code](https://claude.com/claude-code) and authenticate with `claude` first.
Then install Claude KISS:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh
```

Prefer to inspect code before running it? You should:

```sh
curl -fsSL https://claude-kiss.com/install.sh -o claude-kiss-install.sh
less claude-kiss-install.sh
sh claude-kiss-install.sh
```

Check the effective installation:

```sh
claude-kiss doctor
```

Start a KISS session:

```sh
claude-kiss
```

Your ordinary command remains exactly where it was:

```sh
claude
```

Claude KISS does **not** replace `claude`, patch its binary, rewrite `~/.claude`, or change
your existing Claude Code defaults.

Sessions prompt for tool permissions by default. This deliberately overrides a global
`dontAsk` mode, which silently denies edits and commands in otherwise interactive
sessions. Opt out explicitly:

```sh
claude-kiss --dangerously-skip-permissions   # full bypass; you own the risk
claude-kiss --permission-mode acceptEdits    # auto-approve file edits only
```

## What, why, and how

**What:** Claude KISS is a transparent second launcher. It keeps Claude Code, but supplies
a builder-first prompt, a smaller default tool surface, strict MCP behavior, an editable
compact-handoff policy, and files you own. The design rules behind those choices are
written down in [MANIFESTO.md](MANIFESTO.md).

**Why:** recent Claude Code and Opus 5 discussions repeatedly describe a capable coding
model wrapped in defaults that turn a small request into a project: scope creep,
over-engineering, verbose narration, surprise tool use, context loss, and avoidable token
burn. Claude KISS attacks that at the launcher layer instead of hiding it behind another
framework.

Public examples from the last three weeks include
[“My Opus 5 experience in a nutshell”](https://www.reddit.com/r/ClaudeAI/comments/1vgpyni/my_opus_5_experience_in_a_nutshell/),
[“Why does Opus 5 feel worse to work with?”](https://news.ycombinator.com/item?id=49296740),
and
[“Claude Code efficiency feels noticeably worse”](https://www.reddit.com/r/ClaudeCode/comments/1voaq2b/claude_code_efficiency_feels_noticeably_worse_aug/).

| Recent frustration | Claude KISS response |
|---|---|
| “I asked a question; it edited files.” | Treat questions as questions. Edit only when asked. |
| “A one-line fix became a refactor.” | Deliver the requested scope; preserve unrelated behavior, formatting, and user edits. |
| “It rewrote comments or created reports I did not request.” | Preserve comment density; do not add comments, plans, or documentation unless needed or requested. |
| “It over-engineered a simple change.” | Use the simplest complete robust solution; avoid speculative abstractions and frameworks. |
| “Concise meant lazy or incomplete.” | KISS explicitly excludes stubs, TODOs, hardcoded results, swallowed errors, and production-path shortcuts. |
| “Extra tools and agents burned the budget.” | Six core tools by default; add capabilities explicitly. |
| “MCP discovered more than I intended.” | Strict MCP mode; no unrelated discovery unless you enable it. |
| “After compaction, it forgot the objective.” | An editable handoff records the objective, acceptance criteria, validation state, and next action. |
| “Vendor defaults drifted.” | User-owned prompt, settings, and memory; `doctor` reports where every choice came from. |
| “Another wrapper wants custody of my setup.” | Ordinary `claude` and `~/.claude` remain untouched; there is no wrapper telemetry or auto-update. |

**How:** install, inspect, then launch:

```sh
claude-kiss doctor
claude-kiss
claude-kiss init
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

This is a launcher with strong defaults, not a promise that instructions are always obeyed
or that a model bug can be prompted away. It also is not a sandbox: `Bash` remains
powerful, and MCP must still be reviewed when enabled.

## What it does

Claude KISS is a transparent launcher and configuration layer, not a fork or API proxy.
It gives Claude Code:

- a concise builder-first system prompt;
- six core coding tools by default;
- no bundled skills, workflows, connectors, artifacts, or agent view;
- no normal MCP discovery unless explicitly requested;
- no Claude in Chrome integration unless explicitly requested;
- no built-in git workflow instructions or git status snapshot in the system prompt;
- no attribution inserted into commits or PRs;
- supported opt-outs for telemetry, error reporting, feedback, auto-update, and related
  nonessential traffic;
- an editable long-session compact-handoff policy;
- user-owned files that installer updates never overwrite.

The important distinction is what “concise” means here:

> KISS is the smallest complete robust solution—not minimal effort, a stub, or a special
> case that passes one visible test.

## The 60-second tour

### 1. Try the defaults

```sh
claude-kiss
```

Default tools:

```text
Bash
Glob
Grep
Read
Edit
Write
```

Ask a question and Claude answers rather than turning it into an editing project. Ask for
a fix and Claude inspects the relevant code, repairs the root cause, validates the change,
and stays inside the requested scope.

### 2. See exactly what will run

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

The wrapper prints the native Claude Code command, selected prompt, settings, and memory
path. There is no hidden runtime and no second vendor to trust.

### 3. Own the configuration

```sh
claude-kiss init
```

This copies the managed assets to your user configuration directory:

```text
~/.config/claude-kiss/
  prompt.md
  settings.json
  memory/CLAUDE.md
```

The files are yours. Edit them with any editor. Future Claude KISS updates replace managed
defaults, never these files.

### 4. Inspect where every choice came from

```sh
claude-kiss doctor
```

`doctor` reports whether each asset is using:

```text
managed default
user-owned file
environment override
```

It also verifies that the installed Claude Code supports every native flag KISS uses.

## What changes immediately

| Area | Ordinary Claude Code | Claude KISS |
|---|---|---|
| System prompt | Claude Code default | Concise builder-first replacement |
| Built-in tools | Broader default surface | Six core coding tools |
| Bundled skills/workflows | Available by default | Disabled |
| Agent view, artifacts, connectors, remote control | Available through normal surface | Disabled |
| MCP | Normal discovery | Strict mode; no unrelated discovery |
| Claude in Chrome | Connects when the extension is available | Disabled |
| Git instructions and status snapshot | Included in the system prompt | Removed |
| Project/local settings | Loaded | Skipped by default |
| User settings | Loaded | Loaded, so `/model` still works |
| Repository memory | Normal behavior | Normal project-root behavior retained |
| Auto memory | Vendor default | Disabled |
| Attribution | Claude attribution | Removed |
| Auto-update, telemetry, surveys, error reporting | Vendor defaults | Supported opt-outs enabled |
| Compaction | Normal behavior | Normal timing plus KISS handoff policy |
| Existing installation | — | Untouched |

Optional capability remains one argument or environment variable away.

## Configure without a config framework

There is no YAML, plugin system, profile marketplace, or nested abstraction. Use native
Claude flags, environment variables, and plain files you own.

| Goal | Command |
|---|---|
| Restore Claude’s broader built-in tool set | `CLAUDE_KISS_TOOLS=default claude-kiss` |
| Add one tool | `CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,Agent claude-kiss` |
| Disable slash commands | `CLAUDE_KISS_DISABLE_COMMANDS=1 claude-kiss` |
| Use one explicit MCP config | `claude-kiss --mcp-config ./mcp.json` |
| Restore normal MCP discovery | `CLAUDE_KISS_MCP=1 claude-kiss` |
| Restore the Claude in Chrome integration | `CLAUDE_KISS_CHROME=1 claude-kiss` |
| Disable CLAUDE.md loading | `CLAUDE_KISS_CLAUDE_MD=0 claude-kiss` |
| Use a separate Claude config directory | `CLAUDE_KISS_ISOLATED=1 claude-kiss` |
| Replace the system prompt directly | `claude-kiss --system-prompt-file ./prompt.md` |
| Show the final command | `CLAUDE_KISS_DRY_RUN=1 claude-kiss` |

Direct native Claude arguments win over KISS defaults. The wrapper scans for the relevant
flags and does not add a competing value.

## Own every file

Configuration precedence is deliberately simple:

```text
direct Claude CLI argument
  > CLAUDE_KISS_* environment override
  > user-owned file
  > managed KISS default
```

After `claude-kiss init`, edit:

```sh
$EDITOR ~/.config/claude-kiss/prompt.md
$EDITOR ~/.config/claude-kiss/settings.json
$EDITOR ~/.config/claude-kiss/memory/CLAUDE.md
```

Use a different location:

```sh
CLAUDE_KISS_CONFIG_HOME=~/.config/my-kiss claude-kiss init
CLAUDE_KISS_CONFIG_HOME=~/.config/my-kiss claude-kiss
```

Installer updates do not merge, migrate, overwrite, or “improve” these files.

## Context compaction

Long sessions fail when the model remembers activity but loses the objective. Claude KISS
adds one thing here: an editable compact-handoff policy. Timing stays with Claude Code, so
there is no KISS profile layer to learn.

```sh
# Handoff policy plus Claude's own compaction timing
claude-kiss

# Compact earlier
claude-kiss --autocompact 400k

# Keep context until you explicitly compact
DISABLE_AUTO_COMPACT=1 claude-kiss

# Disable compaction completely
DISABLE_AUTO_COMPACT=1 DISABLE_COMPACT=1 claude-kiss

# Skip the KISS handoff policy
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss
```

## Trust boundary

Claude KISS reduces the default product surface, but it is not a sandbox.

Be explicit about what that means:

- `Bash` remains available and is powerful.
- Tool restrictions are an attention and behavior surface, not filesystem isolation.
- MCP is hidden unless explicitly enabled; it is not made safe by hiding it.
- Your own user settings are loaded, so hooks configured in `~/.claude/settings.json` still
  run and your own skills stay available. Subagents need the `Agent` tool, which is not in
  the default tool list.
- Review MCP configs, repository instructions, aliases, and Claude permissions as you
  normally would.
- The compact-memory deny rules discourage normal `Read`/`Edit` access; they do not make
  the file immutable.

What Claude KISS does guarantee is transparency:

- one shell wrapper you can read;
- one installer you can inspect;
- native flags shown by dry-run;
- managed defaults separated from your files;
- ordinary Claude Code left unchanged.

## Measured, not magical

The repository includes a paired evaluator rather than a marketing benchmark. It runs
ordinary Claude and Claude KISS against identical isolated fixtures and measures:

- task correctness;
- file scope;
- created files;
- added comments;
- hidden anti-hardcoding behavior;
- visible and hidden test results;
- response size;
- reported tokens, cost, turns, and wall time.

Current task families:

| Flow | Task |
|---|---|
| Answer without editing | `concise_answer` |
| Minimal root-cause fix | `minimal_bugfix` |
| Focused implementation | `scope_discipline` |
| No lazy special case | `no_lazy_workaround` |
| Regression-test discipline | `targeted_regression_test` |
| Cross-file bug fix | `cross_file_bugfix` |
| Review-only response | `review_no_edit` |
| Resume from a handoff | `long_horizon_handoff` |

Run it:

```sh
python3 evals/run_evals.py
```

Model requests can cost real money. Control the run:

```sh
python3 evals/run_evals.py \
  --model YOUR_MODEL \
  --effort high \
  --budget 1.0
```

Results are written to `evals/results/latest/` (gitignored) so every run stays
reproducible instead of checked in and stale.

## Install options

From a checkout:

```sh
./install.sh
```

Defaults:

```text
executable:  ~/.local/bin/claude-kiss
assets:      ~/.local/share/claude-kiss
user config: ~/.config/claude-kiss
```

Custom managed locations:

```sh
./install.sh --prefix ~/.opt --data-dir ~/.opt/share/claude-kiss
~/.opt/bin/claude-kiss
```

The installer:

- requires Claude Code to be installed;
- checks required native CLI capabilities;
- uses `curl` or `wget` for a standalone release install;
- verifies the SHA-256 checksum of the official domain release archive;
- does not use `sudo`;
- stages files beside their destinations for same-filesystem replacement;
- leaves user configuration untouched.

Uninstall managed files:

```sh
./install.sh --uninstall
```

Your `~/.config/claude-kiss` directory remains.

## Requirements

- macOS or Linux
- Claude Code CLI with support for the native flags listed by `claude-kiss doctor`
- `curl` or `wget` only for standalone installation
- Python 3 only for the optional evaluator and repository tests
- `shellcheck` and `ruff` only for linting

## Release archive

```sh
./build-release.sh
```

This creates a standalone archive and SHA-256 checksum under `dist/`. Upload both files to
the matching GitHub release; the separate website repository downloads and serves those
immutable artifacts.

## Verify locally

```sh
./tests/test.sh
sh -n bin/claude-kiss install.sh tests/test.sh build-release.sh
python3 -m py_compile evals/run_evals.py
python3 -m json.tool config/settings.json
```

The tests cover launcher argument precedence, user-owned configuration, failure paths,
`exec` and `auth` passthrough, installer guardrails and update/uninstall behavior, release
packaging and metadata, settings invariants, compaction behavior, and evaluator checks.

Linting is the same pair CI runs, and both tools are optional locally:

```sh
shellcheck bin/claude-kiss install.sh tests/test.sh build-release.sh
ruff check evals/run_evals.py
```

## Why no profiles?

Named profiles are convenient until they become another framework. A raw tool list is more
honest and easier to reason about:

```sh
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch claude-kiss
```

If you use that combination often, own it in your shell:

```sh
alias ck-research='CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch claude-kiss'
```

Claude KISS does not need to know about your aliases.

## No-BS policy

- Less is more: product code and website source live in separate repositories.
- No wrapper telemetry.
- No auto-update.
- No marketplace.
- No bundled prompt packages.
- No cloud sync.
- No config format invented for this project.
- No claim that a prompt replaces review, testing, or security judgment.
- No silent fallback when a required Claude Code capability is missing.

## Website

[claude-kiss.com](https://claude-kiss.com) is maintained in the separate
[claude-kiss-site](https://github.com/aphoristicartist/claude-kiss-site) repository. The
launcher repository owns the release archive; the website repository owns copy, design,
and Cloudflare deployment.

## Contributing

Small, complete changes win.

Before submitting:

```sh
./tests/test.sh
```

Keep changes scoped to the stated objective. Do not weaken a failing check, hide behavior
under a test-specific special case, or add a configuration layer when an environment
variable and a plain file already solve the problem.

## License

[MIT](LICENSE) © Aleksandr Lisenko

Claude KISS is an independent project. It is not produced by, endorsed by, or affiliated
with Anthropic.
