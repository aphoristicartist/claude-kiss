# Claude KISS: What, Why, How

This document is the argument behind the project: what the problem actually is, why it is
worth a launcher, and how Claude KISS addresses it. Every claim links to a source.

[README.md](README.md) covers installation and daily use. [MANIFESTO.md](MANIFESTO.md)
covers the design rules. This file covers the reasoning.

## What

Claude KISS is a second launcher for the Claude Code you already have. Same binary, same
account, same sessions — different defaults.

It replaces the vendor system prompt with a concise builder-first one, starts sessions with
the six core coding tools, and leaves ambient product features switched off until you ask
for them. Your normal `claude` command is untouched.

It is not a fork, a proxy, an agent framework, or a plugin marketplace. It is one shell
script that assembles native Claude Code flags, and you can print the exact command before
it runs.

## Why

### The behaviour is documented, not imagined

The most useful evidence is not a complaint thread. It is Anthropic's own guide,
[Prompting Claude Opus 5][opus5], which documents the behaviours that "most often require
tuning" and gives prompt text to correct them:

> "Claude Opus 5 can also expand the scope of a task, adding steps that weren't requested
> or applying its own judgment about what the task should be."

> "Claude Opus 5 verifies its own work without being told to. If your prompt contains
> explicit verification instructions … remove them: instructions like these cause
> over-verification on Claude Opus 5, and removing them reduces wasted tokens with no loss
> in quality."

> "Claude Opus 5 delegates to subagents more readily than prior models. Delegation pays off
> on genuinely independent, sizeable tracks of work, but it multiplies cost and time when
> applied to small tasks."

> "Claude Opus 5's default user-facing responses run longer than prior Opus models'. The
> effort parameter controls how much the model thinks rather than how much it says …
> To control response length, prompt for it explicitly."

Separately, the guide notes that files the model writes to disk "are often longer than on
prior models," and that it "narrates corrections to its earlier statements more than prior
models do."

None of that is a defect report. It is a vendor telling you that the defaults need tuning
and handing you the tuning. The question this project answers is where that tuning belongs.

### What it looks like when nobody does the tuning

The most-shared example of recent months began as a request to fix a sitemap on some legacy
HTML. It ended as a full rebuild — new colour palette, unrequested copy, replaced images, a
broken animation — with the original files' only backup deleted along the way, [as reported
from an August 2026 r/ClaudeAI thread][incident].

Treat that as community anecdote rather than measurement. It is included because it
separates two problems that get discussed as one: the scope expansion was survivable, and
the deleted backup was not. A shorter summary would not have helped.

On the verbosity side, community measurements in [an open Claude Code issue][issue83510]
report the current generation producing roughly 1.8–2.1× the output tokens of the previous
one on identical prompts at no additional reasoning effort. Those figures are user-run, not
vendor benchmarks; the direction matches Anthropic's own documentation above.

### Ambient context costs real money

Claude Code's [cost guidance][costs] is explicit that context size drives spend, and its
recommendations are mostly subtractive:

- **"Disable unused servers: Run `/mcp` to see configured servers and disable any you're
  not actively using."**
- **"Prefer CLI tools when available: Tools like `gh`, `aws`, `gcloud`, and `sentry-cli` are
  still more context-efficient than MCP servers because they don't add any per-tool
  listing."**
- **"Your `CLAUDE.md` file is loaded into context at session start. If it contains detailed
  instructions for specific workflows … those tokens are present even when you're doing
  unrelated work."**
- On agent teams: **"approximately 7x more tokens than standard sessions when teammates run
  in plan mode,"** and teammates "load CLAUDE.md, MCP servers, and skills automatically."

One correction worth making explicitly, because the figure circulates widely: MCP tool
schemas are no longer preloaded in full. The docs state that **"MCP tool definitions are
deferred by default, so only tool names and server instructions enter context until Claude
uses a specific tool."** Older posts quoting tens of thousands of tokens of MCP schema
preload describe behaviour that has since changed. The remaining cost is per-tool listing
and whatever loads once a server is actually used — smaller than it was, and still not zero.

Long sessions have their own drift. Claude Code auto-compacts by summarising older history
near the [auto-compact window][costs], and compaction of a large context "is itself a large
request." The recurring complaint is not that detail goes missing but that the objective
does.

### The vendor's own fix addresses one symptom

In v2.1.237 Claude Code shipped a built-in **Concise** output style: lead with the result,
skip preamble, keep responses short. It is a real improvement and it is free. If you are not
using this launcher, use it.

It is also narrow by construction, and the [output styles documentation][styles] says how:

- **It appends.** "Claude Code adds each output style's custom instructions to the end of
  the system prompt," and "adding instructions to the system prompt increases input tokens."
- **It relies on repetition.** "All output styles trigger reminders for Claude to adhere to
  the output style instructions during the conversation."
- **It changes narration, not behaviour.** Concise does the engineering work "as thoroughly
  as in the Default style." It shortens the report, not the work.
- **It is project-scoped.** Selecting it through `/config` writes `outputStyle` to
  `.claude/settings.local.json`, per repository.
- **It stops at the main conversation.** "A subagent runs its own system prompt, so styles
  don't change how subagents respond."

Claude Code's creator described it as ["a quick band aid"][bandaid] while a longer-term fix
is in progress. That is a fair description and not a criticism: verbosity was the cheapest
symptom to fix and the most complained about.

But verbosity costs output tokens. Scope expansion costs a deleted backup. Shortening the
summary does not touch the second one.

## How

Claude KISS applies the same tuning one layer lower — at the launcher — so it reaches
behaviour, tools, and product surface rather than tone alone.

### 1. Replace the prompt instead of appending to it

The launcher passes `--system-prompt-file`, so you get one readable policy document rather
than a vendor prompt with corrections stapled to the end.

What goes in it is not invented. Anthropic publishes prompt text for each documented Opus 5
behaviour; Claude KISS ships that guidance as a default instead of leaving it as an exercise:

| Anthropic's documented remedy ([source][opus5]) | Claude KISS default ([`prompt/claude-kiss.md`](prompt/claude-kiss.md)) |
|---|---|
| "Deliver what was asked, at the scope intended … say so in a sentence and continue with the task as asked rather than quietly narrowing, widening, or transforming it." | "Deliver the requested scope … If a better approach exists, say so in one sentence and continue with the requested direction rather than quietly widening or transforming the task." |
| "Do not delegate work you can finish yourself in a handful of tool calls, and do not use subagents to verify or double-check your own work." | "Do not delegate work you can finish in a few tool calls. If a subagent tool is explicitly enabled, never use it merely to re-check your own work." |
| "Before your first tool call, say in one sentence what you're about to do. While working, give a brief update only when you find something important or change direction. When you finish, lead with the outcome." | "Before the first tool call, say at most one short sentence about what you are doing. While working, report only an important finding, direction change, or blocker … Lead with the outcome." |
| "Only correct an earlier statement when the error would change the user's code, conclusions, or decisions." | "Correct an earlier statement only when the correction changes the user's code, conclusions, or decisions." |
| "Match the length of written documents to what the task needs … do not pad with filler sections, redundant summaries, or boilerplate." | "Match a requested document to its needed length and substance without padding." |
| Remove explicit verification instructions; they cause over-verification. | "Prefer a narrow check first and broaden only while uncertainty remains … do not repeat a passed deterministic check unless an input changed." |
| `<tone_preference>` reminder near the end of a long prompt. | Ships a `<tone_preference>` block as the last thing in the prompt. |

One consequence of replacing the prompt is worth stating plainly, because it is a real
obligation rather than a free win. The Opus 5 guide notes that Claude Code "adds a
delegation instruction of its own on Claude Opus 5 only when you use its `claude_code`
system prompt preset; with a custom or omitted system prompt, add a delegation instruction
such as the example in this section yourself." Claude KISS uses a custom prompt, so it
carries its own delegation rule. If you replace the prompt with your own, you inherit that
obligation too.

The prompt also carries the rules concision cannot express:

| Behaviour | Rule |
|---|---|
| Questions stay questions | Treat a question as a request for an answer; do not edit files merely because the question concerns code |
| Scope holds | Make the smallest coherent change; do not fix unrelated defects or run broad migrations |
| Nothing irreversible by surprise | Never overwrite or delete a backup, recovery point, or unrelated user file; no `rm -rf`, `git reset --hard`, `git checkout --`, or force-push unless explicitly requested |
| Concise is not lazy | No production-path stubs, TODOs, hardcoded results, swallowed errors, or temporary hacks |

### 2. Start with the coding toolset

Sessions start with `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`. The `Agent` tool is not
in that list, so eager delegation is unavailable by default rather than merely discouraged —
a stronger version of the deterministic caps the Opus 5 guide recommends.

Four capabilities can be added for a task, and only four:

```sh
CLAUDE_KISS_WEB=1 claude-kiss          # WebFetch, WebSearch
CLAUDE_KISS_SKILLS=1 claude-kiss       # Skill
CLAUDE_KISS_DELEGATION=1 claude-kiss   # Agent
CLAUDE_KISS_MCP=1 claude-kiss          # MCP discovery, tool search, resources
```

This is [MANIFESTO.md](MANIFESTO.md) §4: the right capability set is task-relative, so it
belongs on the command line rather than in permanent configuration.

There is deliberately no switch that turns everything on, and `--tools` is refused rather
than passed through. A launcher whose entire purpose is a defensible default surface should
not ship a one-word bypass of it. If you want the full product, the full product still
exists and is called `claude`.

### 3. Leave ambient surface off

Bundled skills and workflows, agent view, artifacts, connectors, remote control, Claude in
Chrome, plugin marketplace autoinstall, claude.ai skill sync, auto memory, git instructions
in the prompt, telemetry, surveys, error reporting, and auto-update all start disabled. MCP
is strict — no discovery unless you enable it.

Anthropic's own skills and workflows stay off even when you enable the skills capability.
`CLAUDE_KISS_SKILLS=1` lets Claude reach *your* skills when they are relevant; it does not
bring back `/code-review` and the rest. That is the distinction [MANIFESTO.md](MANIFESTO.md)
§7 draws: a skill should add knowledge you chose, not occupy every session because it
shipped in the box.

This is the same advice as "disable any you're not actively using," applied as a default
rather than as cleanup you remember to do.

Settings are the deliberate exception. User, project, and local settings all load, so
`/model`, your account defaults, and a repository's own configuration keep working. Claude
Code already gates a first-time codebase behind [trust verification][security], so skipping
project settings would duplicate a native guard rather than add one — and [MANIFESTO.md](MANIFESTO.md)
§10 says to prefer the native mechanism. The full tool list, enabled and disabled, is in
[README.md](README.md#default-tools).

### 4. Give compaction a job

Compaction timing stays Claude's. Claude KISS adds a handoff policy requiring a compaction
to record the objective, acceptance criteria, changed files, validation state, and the next
action, and requiring the model to reconstruct state from that handoff rather than assume
prior work is intact.

This uses the native mechanism: Claude Code already supports [custom compaction
instructions][costs] through `CLAUDE.md`. Claude KISS supplies a policy rather than a new
subsystem.

### 5. Keep it inspectable

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss   # print the exact native command
claude-kiss doctor                  # effective configuration, and where each value came from
```

`doctor` verifies that your Claude Code supports every flag the launcher uses and fails
loudly if one is missing rather than silently falling back. Hidden behaviour is the thing
this project exists to remove; it would be a poor result to add some.

## What this does not fix

- **It cannot prompt away a model bug.** Strong defaults raise the floor. They are not a
  guarantee that instructions are obeyed.
- **It does not change model routing.** Classifier false positives and safety fallbacks
  between models are server-side. Choosing the model with `/model` is the extent of the
  control available here.
- **It does not change your plan limits.** It reduces per-session overhead. Quotas are
  unaffected.
- **It does not shrink your conversation.** Claude Code "sends your full conversation with
  every request," so a long session costs what a long session costs. `/clear` between
  unrelated tasks still does more for that than any launcher.
- **It is not a sandbox.** `Bash` is still available and still powerful. Limiting the tool
  list shapes attention; it is not filesystem isolation. Hiding MCP does not make a server
  safe. Review MCP configs, repository instructions, and permissions exactly as you would
  without this launcher.

## Sources

- [Prompting Claude Opus 5][opus5] — Anthropic. Scope expansion, over-verification, subagent
  delegation, response length, narration, correction narration, and the recommended prompt
  text for each.
- [Output styles][styles] — Claude Code documentation. How output styles modify the system
  prompt, and the scope of the built-in Concise style.
- [Manage costs effectively][costs] — Claude Code documentation. MCP tool-definition
  deferral, CLI versus MCP context cost, `CLAUDE.md` load behaviour, agent team token
  multiples, auto-compaction, and why usage climbs in long sessions.
- [Security][security] — Claude Code documentation. Trust verification for first-time
  codebases, which is what gates project settings from an unfamiliar repository.
- [Claude Code issue #83510][issue83510] — community-run verbosity measurements across model
  generations. User-reported, not a vendor benchmark.
- [Concise output style write-up][bandaid] — secondary source for the "quick band aid"
  characterisation.
- [Over-engineering incident write-up][incident] — secondary source for the August 2026
  r/ClaudeAI thread. Anecdote, not measurement.

Documentation moves. If a quotation here no longer matches the linked page, trust the page.

[opus5]: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
[security]: https://code.claude.com/docs/en/security
[styles]: https://code.claude.com/docs/en/output-styles
[costs]: https://code.claude.com/docs/en/costs
[issue83510]: https://github.com/anthropics/claude-code/issues/83510
[bandaid]: https://explainx.ai/blog/claude-code-concise-output-style-config-august-2026
[incident]: https://www.explainx.ai/blog/opus-5-over-engineering-reddit-reaction-august-2026

---

Claude KISS is an independent project. It is not produced by, endorsed by, or affiliated
with Anthropic.
