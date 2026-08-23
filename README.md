<p align="center">
  <img src="assets/mark.svg" width="112" height="112" alt="Claude KISS geometric K mark">
</p>

<h1 align="center">Claude KISS</h1>

<p align="center"><strong>Claude Code, with a smaller default surface.</strong></p>

<p align="center">
  <a href="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml"><img src="https://github.com/aphoristicartist/claude-kiss/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://github.com/aphoristicartist/claude-kiss/releases/latest"><img src="https://img.shields.io/github/v/release/aphoristicartist/claude-kiss?display_name=tag&label=stable" alt="Latest stable release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aphoristicartist/claude-kiss" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://claude-kiss.com">Website</a> ·
  <a href="WHY.md">Why</a> ·
  <a href="REFERENCE.md">Reference</a> ·
  <a href="MANIFESTO.md">Manifesto</a>
</p>

Claude KISS is a transparent shell launcher for the Claude Code CLI you already use. It
supplies a focused system prompt, passes six core coding tools, and keeps web, skills,
delegation, and normal MCP discovery opt-in through four convenience switches.

It is not a fork, proxy, agent framework, or background service. It launches the same
`claude` binary with native flags. Your account and sessions remain available, and the normal
`claude` command stays unchanged.

## Install

Install [Claude Code](https://claude.com/claude-code), run `claude` once to sign in, then:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh
```

Prefer to inspect the installer first:

```sh
curl -fsSL https://claude-kiss.com/install.sh -o claude-kiss-install.sh
less claude-kiss-install.sh
sh claude-kiss-install.sh
```

Start a session:

```sh
claude-kiss
```

The installer writes the launcher and managed assets under `~/.local` by default. It does not
modify `~/.claude`, `~/.claude.json`, or the `claude` command. Sessions still use your existing
Claude configuration and session storage unless you enable isolated mode.

## What changes

These are managed defaults, not a sealed security boundary:

| Area | Ordinary Claude Code | Claude KISS managed default |
|---|---|---|
| System prompt | Claude Code default | Focused builder-first replacement |
| Core coding tools | Claude Code chooses its normal surface | Passes `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write` |
| Web, skills, delegation | Available according to product and configuration | Off until enabled for the session |
| MCP | Normal configured discovery | Strict empty config unless enabled or given a direct `--mcp-config` |
| Bundled product surfaces | Available according to product and account | Managed settings disable bundled skills, workflows, artifacts, connectors, agent view, and remote control |
| Settings | User, project, and local settings load | The same settings load; slash commands remain enabled |
| Permissions | Your configured behavior | Explicit `default` mode unless you pass a native permission argument |
| Compaction | Claude Code timing and summary | Native timing plus an editable handoff policy |
| Existing `claude` setup | — | Left in place |

Claude Code can still add an unremovable `EndConversation` tool in supported interactive
sessions. MCP server tools are not filtered by `--tools`. Direct native arguments, user-owned
settings, hooks, plugins, and repository configuration can also add behavior or surface.
[REFERENCE.md](REFERENCE.md) documents the exact boundary.

## Add capability for one session

```sh
CLAUDE_KISS_WEB=1 claude-kiss          # WebFetch, WebSearch
CLAUDE_KISS_SKILLS=1 claude-kiss       # Skill
CLAUDE_KISS_DELEGATION=1 claude-kiss   # Agent
CLAUDE_KISS_MCP=1 claude-kiss          # normal MCP discovery and helper tools
```

The switches combine:

```sh
CLAUDE_KISS_WEB=1 CLAUDE_KISS_DELEGATION=1 claude-kiss
```

These are the only convenience switches Claude KISS defines. They are not the only native
extension mechanisms Claude Code has. In particular, a direct `--mcp-config` can connect
servers without `CLAUDE_KISS_MCP=1`, and their tools remain outside the built-in tool list.

There is no “enable everything” switch. Use `claude` when you want Claude Code's ordinary
product surface.

## Inspect it

See the resolved launcher inputs and confirm required Claude Code capabilities:

```sh
claude-kiss doctor
```

Print the exact native command instead of launching it:

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

`doctor` reports launcher-owned paths, sources, tools, switches, compaction state, and core
flag compatibility. Dry-run shows the actual argument vector. Neither command expands the
contents of loaded settings, hooks, plugins, or MCP servers.

## Make it yours

```sh
claude-kiss init
$EDITOR ~/.config/claude-kiss/prompt.md
```

`init` copies three managed files into `~/.config/claude-kiss`:

```text
prompt.md
settings.json
memory/CLAUDE.md
```

Those copies become yours. Future installer runs replace managed defaults but do not merge,
migrate, or overwrite your files. A direct native argument can replace the matching launcher
default; resolution is documented in [REFERENCE.md](REFERENCE.md#argument-handling).

## Permission modes

```sh
claude-kiss                                   # prompt in Claude Code's default mode
claude-kiss --permission-mode acceptEdits     # approve edits, still ask for commands
claude-kiss --dangerously-skip-permissions    # bypass prompts; you own the risk
```

The launcher supplies `--permission-mode default` when you do not choose a native mode. This
prevents a global `dontAsk` setting from silently denying edits and commands in KISS sessions.

## Long sessions

Claude KISS adds compact instructions that ask Claude to preserve the objective, acceptance
criteria, changed files, validation state, and next action. They improve handoffs; like any
model instruction, they are not a guarantee.

Compaction timing remains native:

```sh
claude-kiss                                    # handoff policy, native timing
claude-kiss --autocompact 400k                 # choose an earlier threshold
DISABLE_AUTO_COMPACT=1 claude-kiss             # compact only with /compact
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss       # omit the handoff policy
```

## Trust boundary

Claude KISS narrows managed defaults. It is not a sandbox.

- `Bash` remains available and powerful.
- User, project, and local settings load; their hooks and plugins can run.
- Repository instructions still enter context, subject to Claude Code's native trust flow.
- `--tools` limits built-in tools, not tools exposed by connected MCP servers.
- Claude Code may add required internal tools such as `EndConversation`.
- User-owned settings and direct native arguments can replace managed defaults.
- Prompt rules shape behavior; they cannot guarantee model compliance.

Treat cloned repository settings, hooks, plugins, MCP configs, and shell permissions as code
you are about to run.

## Update and uninstall

Update by running the installer again:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh
```

Each managed file is replaced atomically. Files created by `claude-kiss init` are preserved.

Uninstall the default locations:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh -s -- --uninstall
```

The user configuration under `~/.config/claude-kiss` remains. If you installed with a custom
`--prefix` or `--data-dir`, pass the same values when updating or uninstalling.

## Evaluate and develop

The repository includes eight paired smoke tasks for scope, correctness, concision, review,
and long-session handoff. Each pair uses the same fixture, prompt, requested model, effort,
and budget. If `--model` is omitted, each command uses its current default.

```sh
python3 evals/run_evals.py --dry-run
python3 evals/run_evals.py --tasks scope_discipline
```

The evaluator writes raw JSON and a Markdown report. One run per task is evidence to inspect,
not a statistical claim.

For local validation and pull-request expectations, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- [WHY.md](WHY.md) — evidence and tradeoffs behind the launcher
- [MANIFESTO.md](MANIFESTO.md) — the project's design principles
- [REFERENCE.md](REFERENCE.md) — tools, switches, arguments, paths, and installer mechanics
- [SECURITY.md](SECURITY.md) — support policy and private vulnerability reporting
- [GitHub Releases](https://github.com/aphoristicartist/claude-kiss/releases) — version history

## Requirements

- macOS or Linux
- A recent Claude Code CLI; `claude-kiss doctor` checks the core flags it needs
- `curl` or `wget` for a standalone download

## License

[MIT](LICENSE) © Aleksandr Lisenko

Claude KISS is independent software. It is not produced by, endorsed by, or affiliated with
Anthropic.
