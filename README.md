# Claude KISS

Claude KISS is a builder-focused launcher for Claude Code. It keeps the useful execution
harness, replaces the vendor-heavy default prompt with concise user-first instructions,
and removes the tool, skill, connector, attribution, and telemetry surface that most
developers do not ask for. The normal `claude` command stays untouched.

```sh
claude-kiss
```

## Problem

Claude Code is a strong coding harness, but its default launch configuration is optimized
for Anthropic's broad product surface rather than for an individual builder working in a
real repository. That produces avoidable overhead:

- a large vendor system prompt and bundled skill catalog before the user's task begins;
- extra agent, workflow, connector, remote-control, artifact, and MCP surface;
- verbose narration, padded explanations, scope creep, and unrequested artifacts;
- quality loss when “concise” is implemented as lazy shortcuts instead of small complete fixes;
- long-horizon drift after compaction or a resumed session;
- vendor attribution, feedback prompts, auto-updates, and nonessential traffic.

Developers generally want the opposite defaults: inspect the relevant code, make the
smallest complete robust change, test it meaningfully, preserve the worktree, and report
the result briefly.

## Solution

Claude KISS provides those defaults as a separate command:

- a concise replacement system prompt optimized for users, not product placement;
- a deliberately small built-in tool surface;
- no bundled skills or workflows by default;
- explicit MCP opt-in rather than broad discovery;
- user settings and `/model` preserved;
- project `CLAUDE.md`/`AGENTS.md` memory preserved;
- root-cause fixes and focused regression coverage;
- long-horizon state continuity through compaction;
- no commit/PR attribution and supported opt-outs for telemetry, error reporting, feedback
  prompts, terminal-title generation, auto-memory, and auto-updates.

The ordinary `claude` command, `~/.claude`, and `~/.claude.json` remain unchanged. A
developer can use both commands side by side and compare them directly.

Claude KISS is for builders and developers who want maximum practical output from Claude
Code with minimal vendor noise. It is not a binary patch, API proxy, or attempt to hide
every Claude Code capability; optional tools and MCP remain available through documented
overrides.

## What it changes

The default profile:

- replaces Claude Code's vendor system prompt through the official `--system-prompt-file` flag;
- exposes only `Bash`, `Glob`, `Grep`, `Read`, `Edit`, and `Write`;
- disables bundled skills/workflows, remote control, artifacts, agent view, connectors, and MCP discovery;
- loads user settings so `/model` and its saved default work, while skipping project/local settings;
- keeps project `CLAUDE.md`/`AGENTS.md` instructions by default;
- uses a concise KISS compaction policy while retaining Claude's tuned automatic timing;
- opts out of nonessential traffic, telemetry, error reporting, feedback prompts, terminal-title generation, auto-memory, and auto-updates;
- removes Claude attribution from commits and pull requests;
- leaves `~/.claude` and the ordinary `claude` command unmodified.

The result is not a binary patch or API proxy. It uses supported per-invocation CLI behavior,
so Claude Code can continue updating normally.

## Install

From a checkout:

```sh
./install.sh
claude-kiss
```

Defaults:

- executable: `~/.local/bin/claude-kiss`
- assets: `~/.local/share/claude-kiss`

Custom locations:

```sh
./install.sh --prefix ~/.opt --data-dir ~/.opt/share/claude-kiss
~/.opt/bin/claude-kiss
```

Remove it:

```sh
./install.sh --uninstall
```

Install the tagged release:

```sh
curl -fsSL https://raw.githubusercontent.com/aphoristicartist/claude-kiss/v0.2.2/install.sh | sh
```

The standalone installer detects that its assets are absent and downloads the matching
tagged source archive. It does not use `sudo` or modify the default Claude configuration.
For a private/different repository:

```sh
curl -fsSL .../install.sh | CLAUDE_KISS_REPO=https://example.invalid/repo sh
```

Review `install.sh` before piping it into a shell. Prefer a reviewed tag over a moving
branch for managed machines.

## Evaluations

The repository includes a paired harness that compares ordinary `claude` and `claude-kiss`
on identical temporary fixtures. It measures task correctness, file scope, created files,
added comments, hidden anti-hardcoding checks, response size, reported token usage and
cost, agent turns, and wall time.

Run the default four-task smoke benchmark:

```sh
python3 evals/run_evals.py
```

Model requests can cost real money. Set an explicit model, effort level, and per-call
budget when needed:

```sh
python3 evals/run_evals.py --model opus --effort high --budget 1.0
```

The current local run is recorded in [`evals/RESULTS.md`](evals/RESULTS.md). Both launchers
passed all four checks and changed the same expected files. Claude KISS averaged 56.6%
fewer result words, 61.0% lower reported API cost, 49.5% fewer cache-read tokens, and
29.1% lower wall time. It also used more agent turns in that run, so the result is not a
claim that KISS always takes fewer actions.

## Why this design

Claude Code has several overlapping customization mechanisms:

- `--append-system-prompt` leaves the entire vendor prompt in place.
- Custom output styles replace coding instructions, but are persistent state and still interact with output-style machinery.
- Patching the native binary is brittle and disappears on every update.
- Rewriting requests through an `ANTHROPIC_BASE_URL` proxy adds a runtime dependency and can break streaming, caching, authentication, and API evolution.
- `--system-prompt-file` is the supported way to replace the main prompt for one invocation.

Claude KISS therefore combines `--system-prompt-file` with explicit invocation flags and a
temporary settings file. `--setting-sources user` preserves the user's model choice and
authentication without loading project/local settings. Bundled skills and workflows are
removed through supported settings instead of `--disable-slash-commands`; that flag would
also remove built-in commands such as `/model`.

Claude Code still sends the schemas for enabled tools. The lean default removes most tool
schemas and all skill catalog overhead. `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1` requests
abbreviated tool descriptions as an additional supported reduction.

## Quality posture

KISS means the smallest complete robust solution, not the least effort. Claude KISS
requires root-cause fixes at the appropriate layer and explicitly rejects finished work
containing production-path stubs, TODOs, hardcoded results, swallowed errors, lazy
workarounds, or other temporary hacks unless the user asked for temporary behavior. Tests
must not pass through weakened assertions or mocks that hide the behavior under test.

For changed behavior, Claude adds or updates focused coverage for the required behavior,
important edge cases, and regressions when equivalent tests do not already exist. It starts
with the narrow applicable check and broadens only when uncertainty or blast radius
justifies it.

Long-horizon work keeps a compact internal state for the objective, acceptance criteria,
decisions, changed files, diagnostics, and pending validation. After compaction or a
resumed session, Claude reconstructs state from the handoff, repository instructions,
worktree, and source before continuing. The default compaction policy preserves the same
critical information.

## Opus 5 behavior audit

August 2026 discussions and Anthropic's own Opus 5 prompting guide repeatedly identify
the same user-facing problems: long conversational replies, agentic narration, scope creep,
verbose code comments, unrequested reports, repeated verification, and eager delegation.
Claude KISS addresses the controllable harness and prompt side without weakening useful
validation:

| Complaint pattern | Claude KISS response |
|---|---|
| Exhausting, essay-like replies | Explicit brevity, plain language, and a final tone reminder |
| Narration of every read or command | One short preface, then updates only for findings, turns, or blockers |
| Narrow requests becoming projects | Requested-scope rule, smallest coherent change, no speculative scaffolding |
| Questions triggering edits | Questions request answers; repository edits require an action request |
| Padded comments and reports | Preserve comment density; no unrequested comments, plans, or reports |
| Over-verification | One targeted check for deterministic results; broaden only on uncertainty |
| Subagent and token blowouts | `Agent` is absent by default; optional use is explicitly constrained |
| Instruction drift | Supplied user/repository instructions override default habits |
| Loss of backups or unrelated files | Dirty-worktree preservation and explicit recovery-point protection |

This cannot repair provider incidents, model refusals, or other account/service problems.
It also cannot make reasoning-effort changes reliably shorten visible output; explicit
communication rules are required for that. Keep `/model` available for model selection.

Sources:

- [Anthropic: Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
- [Reddit: Opus 5 is too verbose and hard to understand](https://www.reddit.com/r/ClaudeCode/comments/1vhaxfj/opus_5_is_too_verbose_and_hard_to_understand/)
- [Reddit: Opus 5 is actually almost rage-inducing to use](https://www.reddit.com/r/ClaudeAI/comments/1vn8ml6/opus_5_is_actually_almost_rageinducing_to_use/)
- [Reddit: Claude Code efficiency feels noticeably worse](https://www.reddit.com/r/ClaudeCode/comments/1voaq2b/claude_code_efficiency_feels_noticeably_worse_aug/)
- [Hacker News: Why does Opus 5 feel worse to work with?](https://news.ycombinator.com/item?id=49296740)
- [Claude status history](https://status.claude.com/history)
- [explainx analysis of Opus 5 over-engineering reactions](https://explainx.ai/blog/opus-5-over-engineering-reddit-reaction-august-2026)
- [Botmonster analysis of Opus 5 Reddit reception](https://botmonster.com/ai/claude-opus-5-reddit-reception/)

## What Claude KISS takes from Codex

Claude KISS does not paste Codex's model-specific prompt into Claude. It borrows the parts
that are model- and harness-independent:

- Concise, direct, friendly communication.
- Finish the user's actual task before yielding.
- Prefer root-cause fixes over surface patches.
- Keep existing-workspace changes minimal and focused.
- Respect dirty worktrees and never revert unrelated user changes.
- Avoid speculative complexity, unrelated fixes, and unnecessary comments.
- Validate with targeted tests first, then broaden as needed.
- Report outcomes and file references briefly.

The compact policy follows Codex's handoff-summary shape—progress and decisions,
constraints and preferences, concrete next steps, and critical references/data—while
omitting Codex's generic prompt boilerplate. Claude-specific tool names, permission
behavior, safety rules, verification workflow, and KISS operating policy were rewritten for
Claude Code. Codex's Apache-2.0 license and source notice are retained in `LICENSE` and
`NOTICE`.

## Context compaction

Claude Code does not officially expose a Codex-style `compact_prompt` replacement. Its
supported customization points are:

- automatic compaction on/off;
- the automatic compaction window;
- `/compact [instructions]` for a manual focused summary;
- a `## Compact Instructions` section in `CLAUDE.md`;
- awareness that system prompts and root `CLAUDE.md` files survive, while path-scoped
  rules and nested memory must be reloaded later.

Claude KISS wraps those controls in five profiles:

| Profile | Default? | Timing | Compact instructions |
|---|---:|---|---|
| `kiss` | yes | Claude's model-tuned automatic timing | KISS handoff policy |
| `plain` | no | Claude's model-tuned automatic timing | Claude's normal behavior |
| `early` | no | Compact at `500k` by default | KISS handoff policy |
| `manual` | no | Disable automatic compaction; keep `/compact` | KISS handoff policy |
| `off` | no | Disable automatic and manual compaction | None |

Examples:

```sh
# Default: tuned automatic timing plus the KISS handoff policy.
claude-kiss

# Use Claude's normal compaction behavior and no extra KISS memory.
CLAUDE_KISS_COMPACT=plain claude-kiss

# Compact earlier. The value uses Claude Code's --autocompact syntax.
CLAUDE_KISS_COMPACT=early claude-kiss
CLAUDE_KISS_COMPACT=early CLAUDE_KISS_AUTOCOMPACT=400k claude-kiss

# Keep manual control.
CLAUDE_KISS_COMPACT=manual claude-kiss

# Disable both automatic and manual compaction.
CLAUDE_KISS_COMPACT=off claude-kiss
```

The KISS policy is installed at:

```text
~/.local/share/claude-kiss/memory/CLAUDE.md
```

Edit that file to choose exactly what your summaries preserve. It is loaded as an
additional `CLAUDE.md`, so Claude Code's official compaction path sees it. The wrapper
also denies its file tools access to that installation directory.

Use a different policy directory with:

```sh
CLAUDE_KISS_COMPACT_MEMORY=~/prompt-policies/kiss claude-kiss
```

Disable only the KISS compact memory with:

```sh
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss
```

For one focused manual summary, prefer:

```text
/compact preserve the API design decisions, current diff, failed tests, and next steps
```

Path-scoped `.claude/rules` and nested `CLAUDE.md` files do not survive compaction;
Claude reloads them only after a matching file is read again. Put durable rules in the
project-root `CLAUDE.md` without `paths:` frontmatter.

## Daily use

Normal Claude Code arguments are passed through:

```sh
claude-kiss -c
claude-kiss -p "fix the failing test"
claude-kiss --model sonnet
claude-kiss --add-dir ../shared
```

Explicit `--setting-sources`, `--settings`, `--system-prompt`, `--system-prompt-file`,
or `--tools` arguments replace the wrapper's corresponding default rather than competing
with it.

Authentication commands are passed through without session flags:

```sh
claude-kiss auth login
claude-kiss auth status
```

Check the installation:

```sh
claude-kiss doctor
```

### Profiles and overrides

```sh
# Keep the KISS prompt but restore Claude's full built-in tool set.
CLAUDE_KISS_TOOLS=default claude-kiss

# Add a tool without restoring everything.
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,Agent claude-kiss

# Explicit MCP config only; unrelated MCP servers stay hidden.
claude-kiss --mcp-config ./mcp.json

# Restore normal MCP discovery when you really need it.
CLAUDE_KISS_MCP=1 claude-kiss

# Strictly isolated settings; /model selections will not persist to KISS launches.
CLAUDE_KISS_SETTING_SOURCES="" claude-kiss

# Disable every skill and slash command, including built-ins such as /model.
CLAUDE_KISS_DISABLE_COMMANDS=1 claude-kiss

# Ignore all CLAUDE.md/AGENTS.md memory files.
CLAUDE_KISS_CLAUDE_MD=0 claude-kiss

# Use a personal prompt fork persistently.
CLAUDE_KISS_PROMPT=~/prompts/my-kiss.md claude-kiss

# Preview exact wrapper arguments without calling the model.
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

`Agent` is intentionally absent by default. If enabled, Claude's separate subagent prompts
still use Claude Code's own subagent machinery. For strict behavior across a subagent-heavy
workflow, define custom agents explicitly or keep the lean default.

### Complete isolation

By default, Claude KISS uses per-invocation isolation and shares Claude authentication. To
put sessions, plugins, and config under a separate directory as well:

```sh
CLAUDE_KISS_ISOLATED=1 claude-kiss
CLAUDE_KISS_ISOLATED=1 claude-kiss auth login
```

This uses `~/.local/state/claude-kiss/config` or `CLAUDE_KISS_CONFIG_DIR`. It may require a
separate one-time login.

## Compatibility

Developed and tested with Claude Code `2.1.236` on macOS. The script targets POSIX shells
on macOS, Linux, and WSL; native Windows PowerShell support is not included. The installer
checks required CLI flags at runtime. The `--system-prompt-file` behavior documented for
current Claude Code replaces the
entire default main prompt, including its general tool and safety instructions. Tool schemas
remain available, and Claude KISS supplies its own concise safety and verification rules.

The concise prompt structure is informed by OpenAI's Apache-2.0 Codex CLI prompts; see
`NOTICE`. Claude KISS is independent and not endorsed by Anthropic or OpenAI.

## Verification

From a checkout:

```sh
./tests/test.sh
```

The tests validate settings, dry-run arguments, installation, doctor output, and uninstall
behavior without making a model request.
