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

Claude KISS is a second launcher for the Claude Code you already have. Same binary, same
account, same sessions — different defaults: a concise builder-first system prompt, six
core tools, and nothing running that you did not ask for.

It is for builders who want the model at full capability and the harness under their own
control. Every default here is one you can read, print, edit, or override.

Your normal `claude` command is left exactly as it was.

## Why this exists

Claude Code ships a capable model wrapped in defaults that reward showing capability. Day
to day, that looks like:

- you ask a question and files get edited;
- a one-line fix arrives with a new abstraction, a summary document, and rewritten comments;
- every session starts with skills, connectors, and integrations loaded, used or not;
- a long session remembers all the activity and loses the objective.

None of that is a model limitation. It is configuration — spread across a system prompt, a
settings file, a tool list, and a dozen flags most people never pass.

Vendor defaults are not user requirements. A feature earns its place in your session by
being useful for the task in front of you, not by having shipped in the box. Claude KISS
inverts the default: sessions start lean, and you add capability deliberately.

It does that once, at the launcher layer, using Claude Code's own native flags. It is not a
fork, a proxy, an agent framework, or a plugin marketplace. It is one shell script you can
read, and you can print the exact command before it runs.

| What you keep hitting | What Claude KISS does about it |
|---|---|
| “I asked a question; it edited files.” | Questions stay questions. Edits happen when you ask for edits. |
| “A one-line fix became a refactor.” | Deliver the requested scope; preserve unrelated behavior, formatting, and comments. |
| “It over-engineered a simple change.” | Simplest complete solution; no speculative abstractions or frameworks. |
| “Extra tools and agents burned the budget.” | Six core tools by default; everything else is one argument away. |
| “After compaction it forgot the objective.” | An editable handoff policy records objective, acceptance criteria, and next action. |

This is a launcher with strong defaults, not a guarantee that instructions are always
obeyed. It cannot prompt away a model bug.

## What KISS means here

Keep It Simple, Stupid — pointed at the harness, not at your work:

> The smallest **complete, robust** solution. Not minimal effort, not a stub, not a special
> case that happens to pass one visible test.

That cuts both ways, and both halves matter:

- **For the model.** “Concise” is not permission to be lazy. The prompt rules out stubs,
  TODOs, hardcoded results, swallowed errors, and production-path shortcuts. A short answer
  that leaves the bug in place is not a KISS answer.
- **For the launcher.** Fewer tools is not automatically better. Six clear tools the model
  uses well beat four that force it to rebuild the missing one through `Bash`. Capability
  stays; accidental complexity goes.

The same rule applies to this project itself. It adds no telemetry, no auto-update, no
marketplace, no plugin format, and no configuration language of its own. Where Claude Code
already has a mechanism, Claude KISS uses it instead of inventing a competing one.

The full design rules are in [MANIFESTO.md](MANIFESTO.md).

## Install

Install [Claude Code](https://claude.com/claude-code) and authenticate with `claude` first,
then:

```sh
curl -fsSL https://claude-kiss.com/install.sh | sh
```

Prefer to read code before running it? You should:

```sh
curl -fsSL https://claude-kiss.com/install.sh -o claude-kiss-install.sh
less claude-kiss-install.sh
sh claude-kiss-install.sh
```

From a checkout, `./install.sh` does the same thing. Either way you get:

```text
~/.local/bin/claude-kiss      the launcher
~/.local/share/claude-kiss    managed prompt, settings, and compact policy
~/.config/claude-kiss         your files, once you run `claude-kiss init`
```

Nothing touches `~/.claude`, `~/.claude.json`, or the `claude` command.

Confirm the install, then start a session:

```sh
claude-kiss doctor
claude-kiss
```

`doctor` prints the effective configuration and verifies that your Claude Code supports
every flag the launcher uses. If a required flag is missing, it fails loudly instead of
silently falling back.

## Use it efficiently

### Ask before you build

A question gets an answer, not an editing project. Use that. Reviews, explanations, and
“what does this actually return” questions cost one turn and leave the tree clean.

```sh
claude-kiss -p "What does format_price(1250) return? One sentence."
```

### Give a symptom, not a plan

The prompt already says: read the relevant code, fix the root cause, stay in scope,
validate. You do not need to spell that out on every request. Say what is wrong and where.

> Fix the receipt total — it prints 1250 instead of $12.50. Keep `total_cents` in cents.

### Add capability per task, not forever

The default tools are the coding set: `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`.
When a task genuinely needs more, ask for more — for that task.

```sh
# research session with web access
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch claude-kiss

# let it delegate to subagents
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,Agent claude-kiss

# Claude's full built-in surface
CLAUDE_KISS_TOOLS=default claude-kiss
```

There is no profile system to learn, because your shell already has one:

```sh
alias ck-research='CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch claude-kiss'
```

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

### Look at what actually runs

When a session behaves oddly, check the command instead of guessing:

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss
```

It prints the native Claude Code invocation, the selected prompt and settings, and the
compact-policy path. No hidden runtime, nothing to reverse-engineer.

## What changes

| Area | Ordinary Claude Code | Claude KISS |
|---|---|---|
| System prompt | Vendor default | Concise builder-first replacement |
| Built-in tools | Broad default surface | Six core coding tools |
| Bundled skills and workflows | Available | Disabled |
| Agent view, artifacts, connectors, remote control | Available | Disabled |
| MCP | Normal discovery | Strict; no discovery unless you enable it |
| Claude in Chrome | Connects when available | Disabled |
| Git instructions and status snapshot | In the system prompt | Removed |
| Project and local settings | Loaded | Skipped by default |
| User settings | Loaded | Loaded, so `/model` and your account defaults still work |
| Auto memory | Vendor default | Disabled |
| Commit and PR attribution | Added | Removed |
| Telemetry, surveys, error reports, auto-update | Vendor defaults | Opted out |
| Compaction | Normal | Normal timing plus an editable handoff policy |
| Your existing setup | — | Untouched |

## Configuration

Precedence is deliberately flat:

```text
direct Claude CLI argument  >  CLAUDE_KISS_* variable  >  your file  >  managed default
```

Pass a native Claude argument and it replaces the matching KISS default rather than
fighting it: `--tools`, `--system-prompt-file`, `--settings`, `--setting-sources`,
`--permission-mode`, `--mcp-config`, `--chrome`. Everything else passes straight through.

| Variable | Effect |
|---|---|
| `CLAUDE_KISS_TOOLS=list` | Built-in tool list, or `default` for Claude's full set |
| `CLAUDE_KISS_MCP=1` | Restore normal MCP discovery |
| `CLAUDE_KISS_CHROME=1` | Restore the Claude in Chrome integration |
| `CLAUDE_KISS_DISABLE_COMMANDS=1` | Disable all skills and slash commands |
| `CLAUDE_KISS_CLAUDE_MD=0` | Do not load `CLAUDE.md` memory files |
| `CLAUDE_KISS_COMPACT_MEMORY=path` | Use another compact policy directory, or `0` to skip it |
| `CLAUDE_KISS_PROMPT=path` | Replacement system-prompt file |
| `CLAUDE_KISS_SETTINGS=path` | Replacement settings file |
| `CLAUDE_KISS_CONFIG_HOME=path` | Keep your files somewhere other than `~/.config/claude-kiss` |
| `CLAUDE_KISS_ISOLATED=1` | Use a separate Claude config directory for KISS sessions |
| `CLAUDE_KISS_DRY_RUN=1` | Print the command instead of launching Claude |
| `CLAUDE_BIN=path` | Use a specific Claude executable |

Run `claude-kiss --help` for the full list, or `claude-kiss doctor` to see which value is
actually in effect and where it came from.

## Trust boundary

Claude KISS reduces the default product surface. It is not a sandbox, and pretending
otherwise would be worse than useless:

- `Bash` is still available and still powerful.
- Tool limits shape attention and behavior; they are not filesystem isolation.
- MCP is hidden unless you enable it. Hiding it does not make a server safe.
- Your own user settings are still loaded, so hooks in `~/.claude/settings.json` still run
  and your own skills stay available. Subagents need the `Agent` tool, which is not in the
  default list.
- The compact-policy deny rules discourage reading and editing that file; they do not make
  it immutable.

Review MCP configs, repository instructions, and permissions exactly as you would without
this launcher.

## Uninstall

```sh
./install.sh --uninstall
```

That removes the launcher and the managed assets. `~/.config/claude-kiss` stays, and your
Claude Code installation is untouched.

## Requirements

- macOS or Linux
- Claude Code CLI, recent enough to support the flags `claude-kiss doctor` verifies
- `curl` or `wget`, for the one-line install only

## License

[MIT](LICENSE) © Aleksandr Lisenko

Claude KISS is an independent project. It is not produced by, endorsed by, or affiliated
with Anthropic.
