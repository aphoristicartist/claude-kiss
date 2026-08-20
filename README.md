# Claude KISS

**Claude Code configured for builders, not for vendor product-surface goals.**

Claude KISS gives Claude Code a second launcher with concise user-first defaults: answer
the actual request, make the smallest complete robust change, run meaningful checks,
preserve the user's repository, and stop. It keeps Claude Code's useful execution harness,
but replaces its large default prompt and broad tool/skill/connector surface. It also
gives you explicit control over long-horizon context compaction.

```sh
claude-kiss
```

Your normal `claude` command remains untouched, so you can use both launchers side by side.

## Why builders want this

Claude Code already has strong file, shell, search, and edit machinery. The frustration is
what comes with it before your task starts:

- a large vendor system prompt and bundled skill catalog;
- broad agent, workflow, connector, remote-control, artifact, and MCP surfaces;
- long narrated replies when you asked for a result;
- narrow fixes that expand into projects, comments, plans, and reports you did not request;
- “concise” behavior implemented as lazy shortcuts rather than complete root-cause fixes;
- lost context and drifted objectives after compaction or a resumed session;
- commit/PR attribution, feedback prompts, auto-updates, telemetry, and other nonessential
  traffic that is not part of your coding task.

Claude KISS reverses the defaults:

| Builder need | Claude KISS default |
|---|---|
| “Answer my question” | Treat it as a question. Do not edit the repository unless asked. |
| “Fix this bug” | Inspect the relevant code, fix the root cause, and avoid speculative scope. |
| “Keep it concise” | Short plain answers, without weakening tests or shipping stubs. |
| “Don't touch unrelated work” | Preserve dirty worktrees and never revert unrelated user changes. |
| “Finish a long task” | Preserve objective, acceptance criteria, decisions, diagnostics, and next steps. |
| “Let me choose” | Keep `/model`, repository memory, and explicit MCP/tool overrides. |

This is not a stripped-down toy mode. KISS means the smallest complete robust solution,
not minimal effort.

## Contents

- [Why builders want this](#why-builders-want-this)
- [Quick start](#quick-start)
- [What changes immediately](#what-changes-immediately)
- [Measured difference](#measured-difference)
- [Concision without lazy work](#concision-without-lazy-work)
- [Daily use](#daily-use)
- [Context compaction](#context-compaction)
- [Trust and safety](#trust-and-safety)
- [Why this design](#why-this-design)
- [August 2026 Opus 5 behavior audit](#august-2026-opus-5-behavior-audit)
- [What Claude KISS takes from Codex](#what-claude-kiss-takes-from-codex)
- [Compatibility](#compatibility)
- [Verification](#verification)
- [Support](#support)
- [Contributing](#contributing)
- [Project status](#project-status)
- [License](#license)

## Quick start

Install Claude Code and authenticate normally first.

Install the tagged Claude KISS release:

```sh
curl -fsSL https://raw.githubusercontent.com/aphoristicartist/claude-kiss/v0.3.0/install.sh | sh
```

Check the installation and resulting Claude Code version:

```sh
claude-kiss doctor
```

Start a session:

```sh
claude-kiss
```

That is the normal workflow. You can still run ordinary Claude:

```sh
claude
```

Claude KISS does not replace it, patch it, or rewrite your existing Claude configuration.

### Install and uninstall locally

From a repository checkout:

```sh
./install.sh
claude-kiss
```

Defaults:

- executables: `~/.local/bin/claude-kiss` and `~/.local/bin/claude-kiss-profile`
- assets: `~/.local/share/claude-kiss`

Custom locations:

```sh
./install.sh --prefix ~/.opt --data-dir ~/.opt/share/claude-kiss
~/.opt/bin/claude-kiss
```

Remove Claude KISS:

```sh
./install.sh --uninstall
```

The standalone installer downloads the matching tagged source archive when its assets are
not already present. It does not use `sudo`.

For a private or mirrored repository:

```sh
curl -fsSL .../install.sh | CLAUDE_KISS_REPO=https://example.invalid/repo sh
```

Review `install.sh` before piping it to a shell. On a managed machine, prefer a reviewed
tag rather than a moving branch.

## What changes immediately

| Area | Ordinary Claude Code launch | Claude KISS launch |
|---|---|---|
| Main system prompt | Claude Code's vendor default | Concise builder-first replacement prompt |
| Core built-in tools | Claude Code's broader default tool set | `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write` |
| Bundled skills/workflows | Available by default | Disabled by default |
| Remote control, artifacts, agent view, connectors | Available through the normal surface | Disabled by default |
| MCP | Normal discovery | Strict mode; explicit config required |
| Model selection | Normal Claude Code behavior | Kept, including `/model` and saved user model choice |
| User settings | Loaded | Loaded, so authentication and model choice work |
| Project/local settings | Loaded | Skipped by default to avoid surprise harness changes |
| Repository memory | Normal `CLAUDE.md`/`AGENTS.md` behavior | Project-root `CLAUDE.md`/`AGENTS.md` kept |
| Attribution | Claude attribution on commits/PRs | Removed |
| Nonessential traffic | Vendor defaults | Supported opt-outs for telemetry, error reporting, feedback, terminal-title generation, auto-memory, and auto-updates |
| Compaction | Normal behavior | KISS handoff policy plus five selectable timing profiles |
| Existing installation | N/A | Ordinary `claude`, `~/.claude`, and `~/.claude.json` remain unchanged |

Claude KISS uses supported per-invocation CLI flags and a temporary settings file. It is
not a binary patch and not an API proxy. Claude Code can continue updating normally.

Optional capability is still available:

```sh
# Use Claude's broader built-in tool selection; KISS product-surface disablements remain.
CLAUDE_KISS_TOOLS=default claude-kiss

# Add one tool without restoring everything.
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,Agent claude-kiss

# Use one explicit MCP config; unrelated discovered servers stay hidden.
claude-kiss --mcp-config ./mcp.json

# Restore normal MCP discovery for a workflow that really needs it.
CLAUDE_KISS_MCP=1 claude-kiss
```

`Agent` is intentionally absent by default. When enabled, Claude Code still supplies its
own subagent machinery and prompts. For strict behavior across subagent-heavy work,
define custom agents explicitly or keep the lean default.

For repeatable opt-ins, use a named profile instead of retyping the environment variable:

```sh
claude-kiss-profile create research lsp web-fetch web-search tool-search
claude-kiss-profile research
```

## Measured difference

The repository includes a paired evaluator, not a marketing chart. It runs ordinary
`claude` and `claude-kiss` against identical temporary fixtures and measures task
correctness, file scope, created files, added comments, hidden anti-hardcoding checks,
response size, reported token usage and cost, agent turns, and wall time.

Run the default four-task smoke benchmark:

```sh
python3 evals/run_evals.py
```

Model requests can cost real money. Control the model, effort, and budget when needed:

```sh
python3 evals/run_evals.py --model opus --effort high --budget 1.0
```

Current local paired run:

Recorded with Claude KISS `v0.2.2`; the repository includes the harness so you can rerun
it against the current release.

| Metric | Regular Claude | Claude KISS | Relative change |
|---|---:|---:|---:|
| Tasks passed | 4/4 | 4/4 | — |
| Mean result words | 81.2 | 35.2 | −56.6% |
| Mean cache-read tokens | 121,458.8 | 61,363.8 | −49.5% |
| Mean reported cost | $0.2153 | $0.0840 | −61.0% |
| Mean wall time | 27.60s | 19.56s | −29.1% |
| Mean agent turns | 5.0 | 8.8 | +75.0% |

Read the complete methodology, task results, and caveats in
[`evals/RESULTS.md`](evals/RESULTS.md).

Be precise about what this proves:

- It is one local paired run, not statistical proof.
- Both launchers passed all four tasks and changed the same expected files.
- No model override was used; both primarily used Opus 5, while regular Claude also
  reported one auxiliary Haiku call.
- Claude KISS used more turns, and one task produced a longer KISS response.
- The evaluator is included so you can rerun and challenge it on your own tasks.

## Concision without lazy work

The prompt's quality bar is deliberately strict:

- fix the root cause at the appropriate layer;
- keep the change small, coherent, and reviewable;
- do not introduce speculative complexity or unrelated “improvements”;
- preserve existing comment density rather than adding filler;
- avoid unrequested plans, comments, reports, and artifacts;
- finish the requested work before yielding;
- protect unrelated dirty-worktree changes;
- choose focused tests, then broaden only when uncertainty or blast radius justifies it.

For changed behavior, Claude must add or update focused coverage for required behavior,
important edge cases, and regressions when equivalent tests do not already exist.

It must not present production-path stubs, TODOs, hardcoded results, swallowed errors,
lazy workarounds, or other temporary hacks as finished work unless the user explicitly
asked for temporary behavior. It must never weaken assertions or use mocks to hide the
behavior under test.

## Daily use

Normal Claude Code arguments pass through:

```sh
claude-kiss -c
claude-kiss -p "fix the failing test"
claude-kiss --model sonnet
claude-kiss --add-dir ../shared
```

`/model` remains available, and user settings are loaded so a saved model choice persists
across Claude KISS launches.

Authentication commands also work:

```sh
claude-kiss auth login
claude-kiss auth status
```

### Named tool profiles

`claude-kiss-profile` stores a named set of opt-in features and launches Claude KISS with
the resulting built-in tool list. It is a reusable launch profile, not a Claude Code
session ID. Normal session arguments still pass through.

Create interactively:

```sh
claude-kiss-profile create work
```

Create without prompts:

```sh
claude-kiss-profile create research lsp web-fetch web-search tool-search
claude-kiss-profile create agents agent tasks
claude-kiss-profile create bare none
```

Launch, inspect, and remove profiles:

```sh
claude-kiss-profile research
claude-kiss-profile research --model sonnet
claude-kiss-profile list
claude-kiss-profile show research
claude-kiss-profile rm research
```

Available opt-in features:

| Feature | Added tools |
|---|---|
| `lsp` | `LSP`; requires a configured Claude Code language-server plugin |
| `agent` | `Agent`, `TaskStop` |
| `tasks` | `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskStop` |
| `skill` | `Skill`; bundled skills remain disabled |
| `web-fetch` | `WebFetch` |
| `web-search` | `WebSearch` |
| `worktree` | `EnterWorktree`, `ExitWorktree` |
| `mcp-resources` | `ListMcpResourcesTool`, `ReadMcpResourceTool` |
| `tool-search` | `ToolSearch` |
| `none` | No optional tools |

The six core tools are always included. Profiles never enable normal MCP discovery. To
use an MCP server, pass its config explicitly:

```sh
claude-kiss-profile research --mcp-config ./mcp.json
```

`Agent` is accepted in the tool list and initializes as Claude Code's internal `Task`
tool. Excluding web tools does not sandbox `Bash`; network isolation requires Claude
Code's sandbox and permission controls.

Profiles are stored under:

```text
~/.local/state/claude-kiss/profiles
```

Use `CLAUDE_KISS_PROFILES_DIR` to choose another directory.

### Common controls

```sh
# Strictly isolated settings; /model selections will not persist to KISS launches.
CLAUDE_KISS_SETTING_SOURCES="" claude-kiss

# Disable every skill and slash command, including built-ins such as /model.
CLAUDE_KISS_DISABLE_COMMANDS=1 claude-kiss

# Ignore all CLAUDE.md/AGENTS.md memory files.
CLAUDE_KISS_CLAUDE_MD=0 claude-kiss

# Use a personal prompt fork persistently.
CLAUDE_KISS_PROMPT=~/prompts/my-kiss.md claude-kiss

# Use a different settings file persistently.
CLAUDE_KISS_SETTINGS=~/settings/claude-kiss.json claude-kiss

# Preview the exact Claude command without calling the model.
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

Explicit `--setting-sources`, `--settings`, `--system-prompt`,
`--system-prompt-file`, or `--tools` arguments replace the wrapper's corresponding
default rather than competing with it.

### Complete isolation

By default, Claude KISS uses per-invocation isolation and shares your existing Claude
authentication. To place sessions, plugins, and config in a separate directory as well:

```sh
CLAUDE_KISS_ISOLATED=1 claude-kiss
CLAUDE_KISS_ISOLATED=1 claude-kiss auth login
```

This uses `~/.local/state/claude-kiss/config` or `CLAUDE_KISS_CONFIG_DIR`. It may require
a one-time separate login.

## Context compaction

Long-horizon coding fails when compaction saves a generic summary but loses the objective,
acceptance criteria, current diff, failed checks, and next steps. Claude KISS supplies a
small, editable handoff policy while leaving timing control to you.

Claude Code's supported customization points are:

- automatic compaction on/off;
- automatic compaction window;
- `/compact [instructions]` for a focused manual summary;
- a `## Compact Instructions` section in `CLAUDE.md`;
- awareness that system prompts and root `CLAUDE.md` files survive, while path-scoped
  rules and nested memory must be reloaded later.

### Profiles

| Profile | Default? | Timing | Compact instructions |
|---|---:|---|---|
| `kiss` | yes | Claude's model-tuned automatic timing | KISS handoff policy |
| `plain` | no | Claude's model-tuned automatic timing | Claude's normal behavior |
| `early` | no | Compact at `500k` by default | KISS handoff policy |
| `manual` | no | Disable automatic compaction; keep `/compact` | KISS handoff policy |
| `off` | no | Disable automatic and manual compaction | None |

```sh
# Default: model-tuned timing plus the KISS handoff policy.
claude-kiss

# Use Claude's normal compaction behavior without extra KISS memory.
CLAUDE_KISS_COMPACT=plain claude-kiss

# Compact earlier. The value uses Claude Code's --autocompact syntax.
CLAUDE_KISS_COMPACT=early claude-kiss
CLAUDE_KISS_COMPACT=early CLAUDE_KISS_AUTOCOMPACT=400k claude-kiss

# Keep manual control.
CLAUDE_KISS_COMPACT=manual claude-kiss

# Disable automatic and manual compaction.
CLAUDE_KISS_COMPACT=off claude-kiss
```

The default policy is installed at:

```text
~/.local/share/claude-kiss/memory/CLAUDE.md
```

Edit that file to control exactly what summaries preserve. Claude Code loads it as an
additional `CLAUDE.md`, so its official compaction path sees the policy. The wrapper denies
its file tools access to the installation directory.

Use a different policy directory:

```sh
CLAUDE_KISS_COMPACT_MEMORY=~/prompt-policies/kiss claude-kiss
```

Disable only the KISS compact memory:

```sh
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss
```

For one focused manual summary:

```text
/compact preserve the API design decisions, current diff, failed tests, and next steps
```

Path-scoped `.claude/rules` and nested `CLAUDE.md` files do not survive compaction; Claude
reloads them only after a matching file is read again. Put durable project rules in the
project-root `CLAUDE.md` without `paths:` frontmatter.

## Trust and safety

Claude KISS is deliberately conservative:

- It uses supported Claude Code flags and settings.
- It does not patch the Claude Code binary.
- It does not run an API proxy or intercept your model traffic.
- It does not modify ordinary `claude`, `~/.claude`, or `~/.claude.json`.
- It does not use `sudo`.
- It leaves Claude Code updating normally.
- Its installer can be reviewed before use.
- Its tests do not make model requests.
- It does not remove optional capability permanently; tools and MCP have explicit overrides.
- It does not provide OS-level sandboxing; permission rules and Claude Code sandboxing
  still govern shell and network access.

Claude KISS cannot fix provider incidents, model refusals, account limits, or every model
behavior. It changes the controllable launcher, prompt, tool surface, settings, and
compaction behavior. Those are meaningful levers, not magic.

## Why this design

Claude Code has several customization mechanisms:

- `--append-system-prompt` leaves the entire vendor prompt in place.
- Output styles replace coding instructions, but are persistent state and still interact
  with output-style machinery.
- Patching the binary is brittle and disappears with every update.
- An `ANTHROPIC_BASE_URL` proxy adds a runtime dependency and can break streaming, caching,
  authentication, and API evolution.
- `--system-prompt-file` is the supported way to replace the main prompt for one invocation.

Claude KISS therefore combines `--system-prompt-file`, explicit invocation flags, and a
temporary settings file. `--setting-sources user` preserves model choice and authentication
without loading project/local settings. Bundled skills and workflows are removed through
supported settings rather than `--disable-slash-commands`, which would also remove
built-ins such as `/model`.

Claude Code still sends schemas for enabled tools. The lean default removes most tool
schemas and the skill catalog. `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1` requests abbreviated
tool descriptions as an additional supported reduction.

## August 2026 Opus 5 behavior audit

August 2026 discussions and Anthropic's own Opus 5 prompting guide repeatedly identify the
same user-facing problems: long conversational replies, agentic narration, scope creep,
verbose comments, unrequested reports, repeated verification, and eager delegation.
Claude KISS addresses the controllable prompt and harness side without weakening useful
validation:

| Complaint pattern | Claude KISS response |
|---|---|
| Exhausting, essay-like replies | Explicit brevity, plain language, and a final tone reminder |
| Narration of every read or command | One short preface, then updates only for findings, turns, or blockers |
| Narrow requests becoming projects | Requested-scope rule, smallest coherent change, no speculative scaffolding |
| Questions triggering edits | Questions request answers; repository edits require an action request |
| Padded comments and reports | Preserve comment density; no unrequested plans or reports |
| Over-verification | One targeted check for deterministic results; broaden only on uncertainty |
| Subagent and token blowouts | `Agent` is absent by default; optional use is constrained |
| Instruction drift | Supplied user/repository instructions override default habits |
| Loss of backups or unrelated files | Dirty-worktree preservation and explicit recovery-point protection |

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

Claude KISS does not paste Codex's model-specific prompt into Claude. It borrows parts that
are model- and harness-independent:

- concise, direct, friendly communication;
- finish the user's actual task before yielding;
- prefer root-cause fixes over surface patches;
- keep existing-workspace changes minimal and focused;
- respect dirty worktrees and never revert unrelated user changes;
- avoid speculative complexity, unrelated fixes, and unnecessary comments;
- validate with targeted tests first, then broaden as needed;
- report outcomes and file references briefly.

The compact policy follows Codex's handoff-summary shape—progress and decisions,
constraints and preferences, concrete next steps, and critical references/data—while
omitting generic prompt boilerplate. Claude-specific tool names, permission behavior,
safety rules, verification workflow, and KISS operating policy were rewritten for Claude
Code. The reviewed Codex source is acknowledged in `NOTICE`.

## Compatibility

Developed and tested with Claude Code `2.1.237` on macOS. The script targets POSIX shells
on macOS, Linux, and WSL; native Windows PowerShell is not supported.

The installer checks required CLI flags at runtime. `--system-prompt-file` replaces the
entire default main prompt, including its general tool and safety instructions. Tool
schemas remain available, and Claude KISS supplies its own concise safety and verification
rules.

Claude KISS is independent and not endorsed by Anthropic or OpenAI.

## Verification

From a checkout:

```sh
./tests/test.sh
```

The tests validate settings, prompt quality markers, dry-run arguments, installation,
doctor output, and uninstall behavior without making a model request.

```sh
git diff --check
```

Use this before submitting changes to catch trailing whitespace and patch formatting
problems.

## Support

Open a [GitHub issue](https://github.com/aphoristicartist/claude-kiss/issues) for:

- installation problems;
- compatibility failures with a current Claude Code version;
- behavior that claims to be KISS but produces lazy or incomplete work;
- focused proposals for new controls.

Include the output of:

```sh
claude-kiss doctor
claude-kiss --version
```

Do not post credentials or private repository content.

## Contributing

Small, complete, tested changes are preferred.

1. Open or reference an issue first.
2. Keep behavior and documentation changes focused.
3. Preserve the no-model-call test property.
4. Run `./tests/test.sh` and `git diff --check`.
5. Submit a pull request with the reason for the change and evidence.

Compatibility changes should use supported Claude Code interfaces wherever possible.
Breaking changes and new mandatory dependencies need a strong reason.

## Project status

Current release: `v0.3.0`.

Claude KISS is a working, deliberately small launcher. Its interfaces depend on Claude
Code CLI flags, so compatibility checks are built into installation and tests. The design
goal is fewer moving parts, not another framework to maintain.

## License

MIT License. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

Claude KISS prompt guidance is original to this project, but its concise coding-agent
structure was informed by prompts in OpenAI's Apache-2.0 Codex CLI. OpenAI does not
sponsor or endorse Claude KISS. "Claude", "Claude Code", "Codex", and "OpenAI" are
trademarks of their respective owners.
