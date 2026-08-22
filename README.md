# Claude KISS

<p align="center">
  <strong>Claude Code, tuned for people who ship.</strong>
</p>

<p align="center">
  <a href="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml"><img src="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://github.com/aphoristicartist/claude-kiss/releases/latest"><img src="https://img.shields.io/github/v/release/aphoristicartist/claude-kiss?display_name=tag&include_prereleases&label=release" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aphoristicartist/claude-kiss?color=blue" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-informational" alt="Supported platforms">
  <img src="https://img.shields.io/badge/requires-Claude%20Code-6e5cf0" alt="Requires Claude Code">
</p>

**Claude KISS is a second launcher for the Claude Code you already have.** Same binary, same
account, same sessions — different defaults: a concise builder-first system prompt, six core
tools, and nothing running that you did not ask for.

It is one shell script. It is not a fork, a proxy, an agent framework, or a plugin
marketplace. Your normal `claude` command is left exactly as it was.

## Install

Install [Claude Code](https://claude.com/claude-code) and sign in with `claude` first, then:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh
```

Prefer to read code before you run it? You should:

```sh
curl -fsSL https://claude-kiss.com/install.sh -o claude-kiss-install.sh
less claude-kiss-install.sh
sh claude-kiss-install.sh
```

Then start a session:

```sh
claude-kiss
```

Nothing touches `~/.claude`, `~/.claude.json`, or the `claude` command.

## See exactly what you get

No hidden runtime, nothing to reverse-engineer. `doctor` prints the whole configuration and
where each value came from:

```console
$ claude-kiss doctor
claude-kiss 0.7.0
home: /home/you/.local/share/claude-kiss
user config: /home/you/.config/claude-kiss
prompt: /home/you/.local/share/claude-kiss/prompt/claude-kiss.md
prompt source: managed
settings: /home/you/.local/share/claude-kiss/config/settings.json
settings source: managed
setting sources: user,project,local
user settings: /home/you/.claude/settings.json
tools: Bash,Glob,Grep,Read,Edit,Write
web: disabled
skills: disabled
delegation: disabled
mcp: disabled
slash commands: enabled
permission mode: default
DISABLE_AUTO_COMPACT=0
DISABLE_COMPACT=0
compact memory: /home/you/.local/share/claude-kiss/memory/CLAUDE.md
compact memory source: managed
claude: /usr/local/bin/claude
2.1.239 (Claude Code)
```

That is the entire output — nothing is elided.

It also verifies that your Claude Code supports every flag the launcher uses, and fails
loudly if one is missing instead of silently falling back.

To see the exact native command before it runs:

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

## Why this exists

Claude Code ships a capable model wrapped in defaults that reward showing capability. Day to
day, that looks like:

| What you keep hitting | What Claude KISS does about it |
|---|---|
| "I asked a question; it edited files." | Questions stay questions. Edits happen when you ask for edits. |
| "A one-line fix became a refactor." | Deliver the requested scope; preserve unrelated behavior, formatting, and comments. |
| "It over-engineered a simple change." | Simplest complete solution; no speculative abstractions or frameworks. |
| "Extra tools and agents burned the budget." | Six core tools by default; four capabilities you can add, and nothing else. |
| "After compaction it forgot the objective." | A handoff policy records objective, acceptance criteria, and next action. |

None of that is a model limitation. It is configuration — spread across a system prompt, a
settings file, a tool list, and a dozen flags most people never pass.

Anthropic's own [Opus 5 prompting guide][opus5] documents the same behaviors and publishes
prompt text to correct them. Claude KISS ships that correction as a default instead of
leaving it as homework.

> **Vendor defaults are not user requirements.** A feature earns its place in your session by
> being useful for the task in front of you, not by having shipped in the box.

This is a launcher with strong defaults, not a guarantee that instructions are always obeyed.
It cannot prompt away a model bug.

**[WHY.md](WHY.md) has the full case**, with sources: what the problem is, what the
measurements show, why Anthropic's own concision fix addresses one symptom, and what this
launcher does *not* fix.

## What KISS means here

Keep It Simple, Stupid — pointed at the harness, not at your work:

> The smallest **complete, robust** solution. Not minimal effort, not a stub, not a special
> case that happens to pass one visible test.

That cuts both ways, and both halves matter:

- **For the model.** "Concise" is not permission to be lazy. The prompt rules out stubs,
  TODOs, hardcoded results, swallowed errors, and production-path shortcuts. A short answer
  that leaves the bug in place is not a KISS answer.
- **For the launcher.** Fewer tools is not automatically better. Six clear tools the model
  uses well beat four that force it to rebuild the missing one through `Bash`. Capability
  stays; accidental complexity goes.

The same rule applies to this project. It adds no telemetry, no auto-update, no marketplace,
no plugin format, and no configuration language of its own. Where Claude Code already has a
mechanism, Claude KISS uses it instead of inventing a competing one.

The full design rules are in [MANIFESTO.md](MANIFESTO.md).

## What changes

| Area | Ordinary Claude Code | Claude KISS |
|---|---|---|
| System prompt | Vendor default | Concise builder-first replacement |
| Built-in tools | 40+ tool default surface | Six, plus four capabilities you can add |
| Bundled skills and workflows | Available | Disabled, with no way to re-enable |
| Plugin marketplace, claude.ai skill sync | Available | Disabled |
| Agent view, artifacts, connectors, remote control | Available | Disabled |
| MCP | Normal discovery | Strict, unless `CLAUDE_KISS_MCP=1` |
| Claude in Chrome | Connects when available | Disabled |
| Git instructions and status snapshot | In the system prompt | Removed |
| User, project, and local settings | Loaded | Loaded, so `/model` and per-repository config still work |
| Auto memory | Vendor default | Disabled |
| Commit and PR attribution | Added | Removed |
| Telemetry, surveys, error reports, auto-update | Vendor defaults | Opted out |
| Compaction | Normal | Normal timing plus an editable handoff policy |
| Your existing setup | — | Untouched |

## How to use it

### Ask before you build

A question gets an answer, not an editing project. Use that. Reviews, explanations, and
"what does this actually return" questions cost one turn and leave the tree clean.

```sh
claude-kiss -p "What does format_price(1250) return? One sentence."
```

### Give a symptom, not a plan

The prompt already says: read the relevant code, fix the root cause, stay in scope, validate.
You do not need to spell that out on every request. Say what is wrong and where.

> Fix the receipt total — it prints 1250 instead of $12.50. Keep `total_cents` in cents.

### Add capability per task, not forever

Four capabilities can be added for a task. These four are the whole list.

```sh
CLAUDE_KISS_WEB=1 claude-kiss          # WebFetch, WebSearch
CLAUDE_KISS_SKILLS=1 claude-kiss       # Skill
CLAUDE_KISS_DELEGATION=1 claude-kiss   # Agent
CLAUDE_KISS_MCP=1 claude-kiss          # MCP discovery, tool search, resources
```

They combine, and there is no profile system to learn because your shell already has one:

```sh
alias ck-research='CLAUDE_KISS_WEB=1 claude-kiss'
alias ck-wide='CLAUDE_KISS_WEB=1 CLAUDE_KISS_DELEGATION=1 claude-kiss'
```

There is no switch that turns everything on, and `--tools` is refused rather than passed
through. If you want Claude Code's full product surface, that product exists and is called
`claude`.

### Choose the right permission mode

Sessions prompt for tool permissions by default. This deliberately overrides a global
`dontAsk` setting, which silently denies edits and commands mid-session and looks like the
model refusing to work.

```sh
claude-kiss                                   # prompt for each new permission
claude-kiss --permission-mode acceptEdits     # auto-approve edits, still ask for commands
claude-kiss --dangerously-skip-permissions    # full bypass; you own the risk
```

### Survive long sessions

Long sessions fail when the model keeps the activity and loses the objective. Claude KISS
loads a compact-handoff policy that forces a compaction to record the objective, acceptance
criteria, changed files, validation state, and the next action.

Compaction timing stays Claude's, so you keep the native controls:

```sh
claude-kiss                                    # handoff policy, Claude's own timing
claude-kiss --autocompact 400k                 # compact earlier in a large repository
DISABLE_AUTO_COMPACT=1 claude-kiss             # only compact when you run /compact
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss       # skip the handoff policy entirely
```

Run `/compact` yourself when you finish one objective and start another. That is the moment
the handoff is worth the most.

### Make the prompt yours

The defaults are a starting point, not a doctrine:

```sh
claude-kiss init
$EDITOR ~/.config/claude-kiss/prompt.md
```

`init` copies the prompt, settings, and compact policy into `~/.config/claude-kiss`. From
then on they are your files. Updates replace the managed defaults and never touch these.

## Capabilities

Claude Code ships more than forty built-in tools. Claude KISS starts with six and can add
four things. A tool that is not named is unavailable for the session, not merely discouraged.

**Always on — the coding set**

| Tool | What it does |
|---|---|
| `Bash` | Runs shell commands |
| `Glob` | Finds files by pattern |
| `Grep` | Searches file contents |
| `Read` | Reads files |
| `Edit` | Makes targeted edits |
| `Write` | Creates or overwrites files |

**Available on request — the only four**

| Variable | Adds | For |
|---|---|---|
| `CLAUDE_KISS_WEB=1` | `WebFetch`, `WebSearch` | Research, current documentation |
| `CLAUDE_KISS_SKILLS=1` | `Skill` | Letting Claude load *your* skills when relevant |
| `CLAUDE_KISS_DELEGATION=1` | `Agent` | Genuinely independent parallel work |
| `CLAUDE_KISS_MCP=1` | MCP discovery, `ToolSearch`, `ListMcpResourcesTool`, `ReadMcpResourceTool`, `WaitForMcpServers` | Tools and data behind an MCP server |

`ToolSearch` is part of the MCP capability rather than a separate switch. Claude Code defers
MCP tool definitions by default and loads them on demand through `ToolSearch`, so a session
with MCP enabled and `ToolSearch` missing could see a server's tool names without being able
to call them. `WaitForMcpServers` covers the same wait on deployments where tool search is
off, such as a custom `ANTHROPIC_BASE_URL`.

Enabling skills lets Claude reach ***your*** skills. It does not bring back `/code-review`
and friends — Anthropic's bundled skills, workflows, plugin marketplace, and claude.ai skill
sync stay off in every session, and no setting in this project turns them back on.

<details>
<summary><strong>Off, permanently</strong> — every tool that stays disabled</summary>

There is no variable, flag, or settings key in this project that turns any of these on.

| Group | Tools |
|---|---|
| Vendor orchestration | `Workflow`, `SendMessage`, `ListAgents` |
| Planning and task tracking | `EnterPlanMode`, `ExitPlanMode`, `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskOutput`, `TaskStop`, `TodoWrite` |
| claude.ai surface | `Artifact`, `RemoteTrigger`, `PushNotification`, `SendUserFile`, `ShareOnboardingGuide` |
| Scheduling and background work | `CronCreate`, `CronDelete`, `CronList`, `ScheduleWakeup`, `Monitor` |
| Git worktrees | `EnterWorktree`, `ExitWorktree` |
| Editors and language servers | `NotebookEdit`, `LSP`, `PowerShell` |
| Conversation control | `AskUserQuestion`, `EndConversation`, `ReportFindings` |

Claude Code itself no longer provides the task-tracking tools by default on current models,
so that row is largely already off upstream rather than something this launcher takes away.

</details>

## Configuration

Precedence is deliberately flat:

```text
direct Claude CLI argument  >  CLAUDE_KISS_* variable  >  your file  >  managed default
```

Pass a native Claude argument and it replaces the matching KISS default rather than fighting
it: `--system-prompt-file`, `--settings`, `--setting-sources`, `--permission-mode`,
`--mcp-config`. Everything else passes straight through.

Two arguments are refused with a non-zero exit rather than honoured: `--tools` and
`--chrome`. Both would widen the surface past the four capabilities, which is the one thing
this launcher exists to prevent. It says so and stops, instead of silently ignoring you.

<details>
<summary><strong>All environment variables</strong></summary>

| Variable | Effect |
|---|---|
| `CLAUDE_KISS_WEB=1` | Add `WebFetch` and `WebSearch` |
| `CLAUDE_KISS_SKILLS=1` | Add `Skill`, so Claude can load your skills when relevant |
| `CLAUDE_KISS_DELEGATION=1` | Add `Agent`, so Claude can run subagents |
| `CLAUDE_KISS_MCP=1` | Restore MCP discovery and add the MCP tool-search and resource tools |
| `CLAUDE_KISS_DISABLE_COMMANDS=1` | Also stop you typing `/skill-name` yourself |
| `CLAUDE_KISS_CLAUDE_MD=0` | Do not load `CLAUDE.md` memory files |
| `CLAUDE_KISS_COMPACT_MEMORY=path` | Use another compact policy directory, or `0` to skip it |
| `CLAUDE_KISS_PROMPT=path` | Replacement system-prompt file |
| `CLAUDE_KISS_SETTINGS=path` | Replacement settings file |
| `CLAUDE_KISS_CONFIG_HOME=path` | Keep your files somewhere other than `~/.config/claude-kiss` |
| `CLAUDE_KISS_ISOLATED=1` | Use a separate Claude config directory for KISS sessions |
| `CLAUDE_KISS_DRY_RUN=1` | Print the command instead of launching Claude |
| `CLAUDE_BIN=path` | Use a specific Claude executable |

</details>

Run `claude-kiss --help` for the short version, or `claude-kiss doctor` to see which value is
actually in effect and where it came from.

## Does it actually behave differently?

Claims about behavior should be testable, so the behaviors this project claims are the ones
it measures. `evals/run_evals.py` runs paired tasks — identical fixture, identical prompt,
identical model and budget — through ordinary `claude` and through `claude-kiss`, then checks
the resulting files rather than the prose:

| Task | What it measures |
|---|---|
| `concise_answer` | Correct one-sentence answer without edits |
| `minimal_bugfix` | Root-cause fix, no test/comment/report edits |
| `scope_discipline` | Requested implementation without unrelated cleanup |
| `no_lazy_workaround` | General behavior instead of special-casing a visible test |
| `targeted_regression_test` | Focused regression coverage beside a root-cause fix |
| `cross_file_bugfix` | Cross-file navigation while preserving an internal API contract |
| `review_no_edit` | Exact review finding without changing files |
| `long_horizon_handoff` | Resume a partial objective without drift or losing user work |

```sh
python3 evals/run_evals.py --dry-run          # print the planned invocations, no requests
python3 evals/run_evals.py --tasks scope_discipline
```

It writes raw JSON plus a Markdown report. It is a **paired smoke benchmark, not a
statistical claim**: one run per task measures tendencies, and the report says so in its own
interpretation-limits section. Rerun with more repeats before drawing a strong conclusion.

## Trust boundary

Claude KISS reduces the default product surface. It is not a sandbox, and pretending
otherwise would be worse than useless:

- `Bash` is still available and still powerful.
- Tool limits shape attention and behavior; they are not filesystem isolation.
- MCP is hidden unless you enable it. Hiding it does not make a server safe.
- User, project, and local settings are all loaded, so hooks in `~/.claude/settings.json`
  and in a repository's `.claude/settings.json` still run, and your own skills stay
  available. Claude Code's own trust prompt is what gates a first-time directory, not this
  launcher. **Treat a cloned repository's settings as code you are about to run.**
- The compact-policy deny rules discourage reading and editing that file; they do not make it
  immutable.

Review MCP configs, repository instructions, and permissions exactly as you would without
this launcher.

## Where things live

```text
~/.local/bin/claude-kiss      the launcher
~/.local/share/claude-kiss    managed prompt, settings, and compact policy
~/.config/claude-kiss         your files, once you run `claude-kiss init`
```

## Requirements

- macOS or Linux
- Claude Code CLI, recent enough to support the flags `claude-kiss doctor` verifies
- `curl` or `wget`, for the one-line install only

## Uninstall

```sh
./install.sh --uninstall
```

That removes the launcher and the managed assets. `~/.config/claude-kiss` stays, and your
Claude Code installation is untouched.

## License

[MIT](LICENSE) © Aleksandr Lisenko

Claude KISS is an independent project. It is not produced by, endorsed by, or affiliated with
Anthropic.

[opus5]: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
