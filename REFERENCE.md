# Claude KISS reference

This document describes the launcher mechanics shipped in this repository. Claude Code is a
separate product and changes independently; run `claude-kiss doctor` after updating either
one.

The short version is in [README.md](README.md). The design rationale is in
[WHY.md](WHY.md).

## Managed defaults and hard boundaries

Claude KISS is a set of strong managed defaults, not a sealed runtime.

The launcher always:

- executes the selected `claude` binary rather than a fork or proxy;
- passes a built-in tool list assembled from six core coding tools and enabled convenience
  switches;
- rejects direct `--tools` and `--chrome` arguments;
- adds `--no-chrome`;
- supplies its prompt, settings, setting sources, and permission mode unless a matching
  native argument replaces them;
- adds strict empty MCP configuration unless MCP discovery or a direct MCP config was chosen.

The launcher does not prevent Claude Code or user configuration from adding every other kind
of surface. In particular:

- Claude Code may inject an unremovable `EndConversation` tool in supported interactive
  sessions even when it is absent from `--tools`.
- `--tools` controls built-in tools; it does not filter tools exposed by connected MCP
  servers.
- User, project, and local settings load by default, including hooks and plugins.
- A user-owned or directly supplied settings file can replace the managed opt-outs.
- Native arguments not explicitly rejected pass through.

Tool restriction shapes the session and the model's attention. It is not process,
filesystem, network, or account isolation.

## Tool surface

### Core coding tools

The launcher passes these six built-in tools in every normal session:

| Tool | Purpose |
|---|---|
| `Bash` | Run shell commands |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `Read` | Read files |
| `Edit` | Make targeted edits |
| `Write` | Create or overwrite files |

`Bash` supports background commands. Because `TaskOutput` and `TaskStop` are not passed,
Claude cannot manage those commands through those tools. The user can still inspect and stop
background tasks with Claude Code's `/tasks` interface.

### Convenience switches

| Variable | Adds to the built-in tool list | Effect |
|---|---|---|
| `CLAUDE_KISS_WEB=1` | `WebFetch`, `WebSearch` | Current documentation and web research |
| `CLAUDE_KISS_SKILLS=1` | `Skill` | Let Claude load available user skills |
| `CLAUDE_KISS_DELEGATION=1` | `Agent` | Let Claude launch subagents |
| `CLAUDE_KISS_MCP=1` | `ToolSearch`, `ListMcpResourcesTool`, `ReadMcpResourceTool`, `ReadMcpResourceDirTool`, `WaitForMcpServers` | Restore normal MCP discovery and its helper tools |

These are the only convenience switches defined by Claude KISS. They are not an exhaustive
list of Claude Code extension mechanisms.

`ToolSearch` is grouped with MCP because Claude Code normally defers MCP tool definitions and
loads them on demand. `WaitForMcpServers` covers deployments where tool search is off.
`ReadMcpResourceDirTool` expands directory resources named by the resource listing tool.

### MCP behavior

MCP has two separate surfaces:

1. Built-in discovery, tool-search, wait, and resource helper tools.
2. Tools exposed by a connected MCP server.

With neither an environment switch nor a native MCP argument, the launcher passes:

```text
--strict-mcp-config --mcp-config {"mcpServers":{}}
```

That suppresses configured server discovery for the session.

With `CLAUDE_KISS_MCP=1`, the launcher stops adding the strict empty configuration and adds
the five MCP helper tools above. Claude Code then performs its normal MCP discovery.

A direct `--mcp-config FILE` prevents the empty config from being added but leaves strict mode
on when `CLAUDE_KISS_MCP` is off. Servers in that explicit file can load, and their own tools
can reach Claude because MCP tools are outside the built-in `--tools` filter. The five helper
tools are still absent unless `CLAUDE_KISS_MCP=1` is set.

Review every MCP configuration and server as executable integration code.

### Built-ins not passed

The following tools from Anthropic's public tools reference are not passed by the launcher.
Claude Code may change its catalog independently, and its required `EndConversation` tool is
the known exception to the allowlist in supported interactive sessions.

| Group | Built-in tools not passed |
|---|---|
| Vendor orchestration | `Workflow`, `SendMessage`, `ListAgents` |
| Planning and task tracking | `EnterPlanMode`, `ExitPlanMode`, `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskOutput`, `TaskStop`, `TodoWrite` |
| claude.ai surface | `Artifact`, `RemoteTrigger`, `PushNotification`, `SendUserFile`, `ShareOnboardingGuide` |
| Scheduling and background work | `CronCreate`, `CronDelete`, `CronList`, `ScheduleWakeup`, `Monitor` |
| Git worktrees | `EnterWorktree`, `ExitWorktree` |
| Editors and language servers | `NotebookEdit`, `LSP`, `PowerShell` |
| Conversation control | `AskUserQuestion`, `ReportFindings` |

Some task-tracking tools are already absent by default on current models. Claude Code binaries
also carry tools not listed in the public reference. The explicit built-in list excludes those
unless Claude Code treats one as required independently of `--tools`.

## Prompt and settings

The managed files are:

```text
prompt/claude-kiss.md
config/settings.json
memory/CLAUDE.md
```

The settings file currently disables bundled skills and workflows, agent view, artifacts,
claude.ai connectors, remote control, claude.ai skill sync, auto memory, git instructions,
commit and PR attribution, spinner tips, telemetry, error reporting, feedback surveys,
marketplace autoinstall, terminal title changes, and auto-update for the KISS process.

These are defaults, not immutable policy. Run `claude-kiss init` to create user-owned copies:

```text
~/.config/claude-kiss/prompt.md
~/.config/claude-kiss/settings.json
~/.config/claude-kiss/memory/CLAUDE.md
```

Once present, those files take the place of their managed counterparts. Installer updates do
not modify them.

## Argument handling

There is no universal precedence ladder across unrelated features. Resolution is per input.

For the following native arguments, a direct argument prevents the launcher from adding its
matching default:

| Native argument | Default it replaces |
|---|---|
| `--system-prompt` or `--system-prompt-file` | Managed, user, or environment-selected prompt |
| `--settings` | Managed, user, or environment-selected settings file |
| `--setting-sources` | `user,project,local` |
| `--permission-mode` or `--dangerously-skip-permissions` | `--permission-mode default` |
| `--mcp-config` | The empty MCP config when MCP discovery is off |

`--tools` and `--chrome` are rejected with exit status 2 because they directly conflict with
the launcher's built-in surface. `--no-chrome` is always added. Other native Claude Code
arguments pass through, but they do not necessarily widen the built-in tool list. For example,
`--allowedTools` controls permissions for available tools; it does not add an absent tool.

Environment-selected prompt, settings, and compact-memory paths take precedence over
user-owned copies. User-owned copies take precedence over managed files.

## Session environment variables

| Variable | Effect |
|---|---|
| `CLAUDE_KISS_WEB=1` | Add `WebFetch` and `WebSearch` |
| `CLAUDE_KISS_SKILLS=1` | Add `Skill` |
| `CLAUDE_KISS_DELEGATION=1` | Add `Agent` |
| `CLAUDE_KISS_MCP=1` | Restore normal MCP discovery and add MCP helper tools |
| `CLAUDE_KISS_DISABLE_COMMANDS=1` | Pass `--disable-slash-commands` |
| `CLAUDE_KISS_CLAUDE_MD=0` | Disable Claude memory files and omit the compact handoff policy |
| `CLAUDE_KISS_COMPACT_MEMORY=PATH` | Use a directory containing `CLAUDE.md`; use `0` to omit it |
| `CLAUDE_KISS_PROMPT=PATH` | Use another system-prompt file |
| `CLAUDE_KISS_SETTINGS=PATH` | Use another settings file |
| `CLAUDE_KISS_HOME=PATH` | Use another managed asset directory |
| `CLAUDE_KISS_CONFIG_HOME=PATH` | Use another user-owned configuration directory |
| `CLAUDE_KISS_ISOLATED=1` | Use a separate Claude configuration directory |
| `CLAUDE_KISS_DRY_RUN=1` | Print the command instead of launching Claude |
| `CLAUDE_BIN=PATH` | Use a specific Claude executable |

Relevant native environment variables remain available:

| Variable | Effect in a KISS session |
|---|---|
| `DISABLE_AUTO_COMPACT=1` | Compact only when requested manually |
| `DISABLE_COMPACT=1` | Disable compaction |
| `CLAUDE_CONFIG_DIR=PATH` | Select Claude's configuration directory; also overrides the isolated-mode default |
| `XDG_CONFIG_HOME=PATH` | Changes the default parent of the KISS user configuration directory |

The default isolated Claude configuration directory is
`~/.local/state/claude-kiss/config`. Isolated mode separates user-level Claude configuration
and state; it does not make repository settings, tools, or the filesystem safe.

## Setting sources and hooks

The launcher passes this default:

```text
--setting-sources user,project,local
```

That keeps user preferences and repository configuration available. It also means hooks and
plugins declared by those settings can run. Claude Code's own trust prompt gates an unfamiliar
working directory; Claude KISS adds no second trust system.

Pass a direct `--setting-sources` value when a task needs a narrower set. Use
`CLAUDE_KISS_ISOLATED=1` when you also want separate user-level Claude state.

## Compaction

Claude KISS does not set a compaction threshold. It adds `memory/CLAUDE.md` as an additional
directory so Claude receives handoff instructions during compaction. The launcher denies its
own `Read` and `Edit` tools access to that managed policy path as a behavioral guard; this is
not filesystem enforcement.

Controls:

```sh
claude-kiss --autocompact 400k
DISABLE_AUTO_COMPACT=1 claude-kiss
DISABLE_COMPACT=1 claude-kiss
CLAUDE_KISS_COMPACT_MEMORY=/path/to/policy-directory claude-kiss
CLAUDE_KISS_COMPACT_MEMORY=0 claude-kiss
```

`CLAUDE_KISS_CLAUDE_MD=0` exports Claude Code's native memory-disable variable and also omits
the KISS compact policy.

## Diagnostics

`claude-kiss doctor` reports:

- wrapper and Claude Code versions;
- managed and user configuration locations;
- selected prompt, settings, and compact-memory sources;
- the built-in tool string and convenience-switch states;
- setting sources, slash-command state, permission default, and compaction variables;
- the resolved Claude executable;
- compatibility with the core flags the launcher needs.

It does not print settings contents, enumerate hooks or plugins, inspect MCP servers, model the
effects of arbitrary direct arguments, or test `--mcp-config` itself.

`CLAUDE_KISS_DRY_RUN=1 claude-kiss ...` prints the exact argument vector that would be passed
for that invocation plus the resolved prompt, settings, and compact-memory state.

## Commands

| Command | Effect |
|---|---|
| `claude-kiss [arguments]` | Launch a KISS session with native arguments |
| `claude-kiss auth [arguments]` | Run Claude authentication without KISS session flags |
| `claude-kiss doctor` | Report resolved launcher state and run compatibility checks |
| `claude-kiss init` | Create user-owned prompt, settings, and compact policy files |
| `claude-kiss --help` | Show launcher help |
| `claude-kiss --version` | Show wrapper and Claude Code versions |

## Filesystem layout

Default locations:

```text
~/.local/bin/claude-kiss             launcher
~/.local/share/claude-kiss           managed assets
~/.config/claude-kiss                user-owned files after `claude-kiss init`
~/.local/state/claude-kiss/config    isolated Claude config when requested
```

`PREFIX`, `DATA_DIR`, `CLAUDE_KISS_HOME`, `CLAUDE_KISS_CONFIG_HOME`, `XDG_CONFIG_HOME`, and
`CLAUDE_CONFIG_DIR` can change these locations according to the tables above and below.

## Installer

Installer options:

| Option | Effect |
|---|---|
| `--prefix PATH` | Installation prefix; default `~/.local` |
| `--data-dir PATH` | Managed asset directory; default `PREFIX/share/claude-kiss` |
| `--no-path-check` | Do not warn when `PREFIX/bin` is outside `PATH` |
| `--uninstall` | Remove the launcher and managed assets at the selected paths |

Installer environment variables:

| Variable | Effect |
|---|---|
| `PREFIX` | Default installation prefix |
| `DATA_DIR` | Default managed asset directory |
| `CLAUDE_KISS_CONFIG_HOME` | User configuration path to preserve and report |
| `CLAUDE_KISS_VERSION` | Release version for a standalone download |
| `CLAUDE_KISS_ARCHIVE` | Exact archive URL for a mirror or local release |
| `CLAUDE_KISS_REPO` | GitHub-compatible repository used to construct a tagged archive URL |

The canonical standalone installer downloads an immutable versioned archive from
`claude-kiss.com` and verifies its SHA-256 checksum. Custom archive and repository URLs do not
use the canonical checksum endpoint; secure and verify mirrors separately.

Install and update stage replacements beside their destinations before moving them into place.
Each managed file is replaced atomically; user-owned configuration is preserved. The installer
records an ownership marker, warns about `PATH`, and never edits a shell startup file. Empty,
root, home-directory, newline-containing, and parent-traversal data paths are rejected.

Uninstall removes a recognized Claude KISS launcher and only the named managed files in a
marked asset directory. Unrecognized launchers, unknown files, and unmarked custom directories
are preserved. A compatibility path recognizes the standard pre-v0.7 asset location when its
launcher is also identifiable. User-owned KISS configuration and the ordinary Claude Code
installation are always preserved.

## Requirements

- POSIX `sh`
- macOS or Linux
- Claude Code with the core flags checked by `claude-kiss doctor`
- `curl` or `wget` for standalone downloads
- `tar` and either `sha256sum` or `shasum` for canonical release extraction and verification
