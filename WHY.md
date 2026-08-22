# Claude KISS: What, Why, How

This document is the argument behind the project: what the problem actually is, why it is
worth a launcher, and how Claude KISS addresses it.

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

### The complaint is not that the model is weak

Frontier coding models are strong. The recurring complaint from people using them daily is
that the harness spends that strength on work nobody asked for.

The pattern is consistent across releases:

- you ask a question and files get edited;
- a one-line fix arrives with a new abstraction, a summary document, and rewritten comments;
- every session starts with skills, connectors, and integrations loaded, used or not;
- a long session remembers all the activity and loses the objective.

Anthropic's own prompting guidance for its newest models is explicit that a model "can also
expand the scope of a task, adding steps that weren't requested," that it verifies its own
work unprompted, and that it delegates to subagents more readily than earlier models — a
habit the documentation notes adds cost and time.

The community version is blunter. The most-shared example of the past month began as a
request to fix a sitemap and ended as a full site rebuild: new colour palette, new copy,
replaced images, a broken animation, and the deletion of the only backup of the original
files. Nothing in that list was requested. The scope expansion was survivable; the deleted
backup was not.

### The overhead is measurable

Ambient capability is not free. It is paid for in context before you type anything.

- A well-documented tool schema runs roughly 200–800 tokens. Multiply that across several
  connected servers and the preload dominates. One user documented 67,000 tokens consumed
  purely by connecting four MCP servers; a five-server, 58-tool setup has been measured at
  roughly 55,000 tokens before the conversation starts.
- Community measurements of the current model generation report output roughly 1.8–2.1×
  longer than the previous generation on identical prompts at no additional reasoning
  effort.
- Compaction fires near the top of the context window and summarises lossily. The reported
  failure mode is not that detail is missing but that the objective is: stack traces reduce
  to "there was an error," rejected approaches are forgotten, and repository instructions
  are sometimes dropped entirely.

Treat the specific figures as community measurement rather than vendor benchmark. The
direction is not in dispute; the decimal places are.

### The fixes people found are configuration changes

The advice that circulated alongside those complaints was not "use a different model." It
was: delete your accumulated skills, MCP servers, and instruction files, start fresh, and
stop telling the model *how* to do the thing.

The strongest version of that came from inside the product. Claude Code's own team is
reported to have removed more than 80% of the existing system prompt and found the model
performed better.

That is the whole premise of this project, stated by the people best positioned to know:
**the behaviour people dislike is mostly configuration, and less of it works better.**

### The vendor fix addresses one symptom

In v2.1.237 Claude Code shipped a built-in **Concise** output style: lead with the result,
skip preamble, keep responses short. It is a genuine improvement and it is free. Use it if
you are not using this launcher.

It is also narrow by construction, and worth understanding precisely:

- **It appends.** The documentation states that Claude Code "adds each output style's
  custom instructions to the end of the system prompt," and that "adding instructions to the
  system prompt increases input tokens." The remedy for an overlong prompt is more prompt.
- **It needs repeating.** All output styles "trigger reminders for Claude to adhere to the
  output style instructions during the conversation." A rule re-injected every turn is being
  compensated for, not enforced.
- **It changes narration, not behaviour.** By design, Concise does the engineering work "as
  thoroughly as in the Default style." It shortens the report. It does not change what gets
  built.
- **It is scoped to the project.** Selecting it through `/config` writes `outputStyle` to
  `.claude/settings.local.json`, per repository.
- **It stops at the main conversation.** Subagents run their own system prompt.

Claude Code's creator described it as "a quick band aid" while a longer-term fix is in
progress. That is a fair description, and it is not a criticism: verbosity was the cheapest
symptom to fix and the most complained about.

But verbosity costs output tokens. Scope expansion costs a deleted backup. Those are not
the same problem, and shortening the summary does not touch the second one.

## How

Claude KISS makes the same class of change one layer lower — at the launcher — so it covers
behaviour, tools, and product surface rather than tone alone.

### 1. Replace the prompt instead of appending to it

The launcher passes `--system-prompt-file`. You get one readable policy document rather
than a vendor prompt with corrections stapled to the end.

That prompt carries the concision rules — lead with the outcome, keep routine work to a few
lines, do not narrate routine reads — at no added token cost, because they are part of the
prompt rather than an addition to it.

It also carries the rules concision cannot express:

| Behaviour | Rule |
|---|---|
| Questions stay questions | Treat a question as a request for an answer; do not edit files merely because the question concerns code |
| Scope holds | Make the smallest coherent change; deliver the requested scope; do not fix unrelated defects or run broad migrations |
| Nothing irreversible by surprise | Never overwrite or delete a backup, recovery point, or unrelated user file; no `rm -rf`, `git reset --hard`, `git checkout --`, or force-push unless explicitly requested |
| Concise is not lazy | No production-path stubs, TODOs, hardcoded results, swallowed errors, or temporary hacks |
| Delegation is deliberate | Do not delegate work you can finish in a few tool calls |
| Verification is proportional | Narrow check first, broaden only while uncertainty remains, report the exact commands |

### 2. Start with the coding toolset

Sessions start with `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`. The `Agent` tool is not
in that list, so eager delegation is not available by default rather than merely discouraged.

Anything else is one argument away, per task:

```sh
CLAUDE_KISS_TOOLS=Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch claude-kiss
```

This is the point of MANIFESTO §4: the right capability set is task-relative, so it belongs
on the command line, not in a permanent configuration.

### 3. Leave ambient surface off

Bundled skills and workflows, agent view, artifacts, connectors, remote control, Claude in
Chrome, auto memory, git instructions in the prompt, telemetry, surveys, error reporting,
and auto-update all start disabled. MCP is strict — no discovery unless you enable it.
Project and local settings are skipped; your own user settings still load, so `/model` and
your account defaults keep working.

None of this is a judgement that those features are bad. It is a judgement about defaults.
A feature earns its place in a session by being useful for the task in front of you.

### 4. Give compaction a job

Compaction timing stays Claude's. Claude KISS adds a handoff policy that requires a
compaction to record the objective, acceptance criteria, changed files, validation state,
and the next action — and requires the model to reconstruct state from that handoff rather
than assume prior work is intact.

The failure mode being targeted is specific: long sessions keep the activity and lose the
objective.

### 5. Keep it inspectable

```sh
CLAUDE_KISS_DRY_RUN=1 claude-kiss   # print the exact native command
claude-kiss doctor                  # effective configuration, and where each value came from
```

`doctor` verifies that your Claude Code supports every flag the launcher uses, and fails
loudly if one is missing rather than silently falling back. Hidden behaviour is the thing
this project exists to remove; it would be a poor result to add some.

### Precedence

```text
direct Claude CLI argument  >  CLAUDE_KISS_* variable  >  your file  >  managed default
```

Run `claude-kiss init` and the prompt, settings, and compact policy become your files.
Updates replace the managed defaults and never touch those.

## What this does not fix

Being accurate about the boundary is more useful than claiming the boundary is elsewhere.

- **It cannot prompt away a model bug.** Strong defaults raise the floor. They are not a
  guarantee that instructions are obeyed.
- **It does not change model routing.** Classifier false positives, safety fallbacks between
  models, and the pricing consequences of those fallbacks are server-side. Choosing the
  model with `/model` is the extent of the control available here.
- **It does not change your plan limits.** It reduces per-session overhead. Quotas are
  unaffected.
- **It is not a sandbox.** `Bash` is still available and still powerful. Limiting the tool
  list shapes attention; it is not filesystem isolation. Hiding MCP does not make a server
  safe. Review MCP configs, repository instructions, and permissions exactly as you would
  without this launcher.

## Further reading

- [README.md](README.md) — install, daily use, configuration reference
- [MANIFESTO.md](MANIFESTO.md) — the twelve design rules, including why simple is not
  bare-bones

Claude KISS is an independent project. It is not produced by, endorsed by, or affiliated
with Anthropic.
