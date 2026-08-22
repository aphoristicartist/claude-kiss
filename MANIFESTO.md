# Claude KISS Manifesto

Claude KISS starts from one premise:

**Frontier models are already powerful. The harness should help, not get in the way.**

KISS does not mean bare-bones, featureless, or artificially constrained. It means keeping useful capability while removing duplicated policy, unnecessary orchestration, hidden vendor behavior, and complexity that does not earn its place.

**Keep the capability. Remove the bullshit.**

## 1. The model works for the user

Vendor defaults are not user requirements.

Skills, artifacts, connectors, workflows, telemetry, memory, integrations, and other product features may be useful, but they should not become ambient behavior simply because the vendor ships them.

Vendor incentives and user incentives are not guaranteed to align.

Claude KISS therefore starts from user control:

**nothing gets a free pass because Anthropic added it.**

Useful features can be enabled. Unnecessary ones stay out.

## 2. Simple does not mean minimal

KISS is not a contest to produce the smallest prompt, fewest tools, or lowest line count.

Removing a useful primitive can make the system less simple by forcing the model to reconstruct it indirectly.

The goal is not minimum capability.

The goal is:

**maximum useful capability per unit of complexity.**

Six clear tools can be simpler than four overloaded ones.

A meaningful prompt can be better than an artificially tiny prompt.

Simplicity is about removing accidental complexity, not capability.

## 3. Every component should provide distinct value

A tool, rule, setting, skill, integration, or agent should exist because it contributes something meaningfully different.

If two prompt rules express the same invariant, merge them.

If a wrapper feature merely reproduces a native Claude Code feature, prefer the native one.

If an integration is unused, keep it off.

If a tool provides a clean primitive that the model uses well, keep it.

**Remove duplication, not usefulness.**

## 4. Use the right capability set for the task

There is no universal perfect toolset.

Coding may need:

`Read / Edit / Write / Grep / Glob / Bash`

and nothing from the web.

Research may need:

`WebSearch / WebFetch / Read`

and no editing or execution at all.

A coding task that requires current documentation may need both.

KISS is therefore **task-relative**.

Start with the smallest coherent capability set for the work being done, then add capabilities only when they provide distinct value.

**Right tools. Right context. Right time.**

## 5. The prompt defines behavior, not ceremony

The system prompt should contain useful behavioral invariants, such as:

* understand before changing
* do what the user actually asked
* questions do not imply edits
* fix root causes
* preserve unrelated behavior
* avoid unnecessary scope expansion
* make complete rather than lazy fixes
* validate proportionally
* use tools when they advance the task
* report what matters

These rules are useful.

Repeating the same idea in five different ways is not.

The objective is **semantic compression**, not arbitrary prompt reduction.

Keep meaningful policy. Remove repetition.

## 6. Protect behavior, not wording

Tests should verify outcomes rather than freeze exact prompt sentences.

If KISS wants Claude to fix root causes, test whether it fixes root causes.

If KISS wants questions to remain questions, test that behavior.

Prompt wording should remain replaceable.

The rule is:

**Behavior is protected. Implementation is disposable.**

## 7. Skills are just-in-time knowledge

Skills fit KISS when they add specialized knowledge without permanently polluting context.

A good skill should be:

* focused
* transparent
* task-specific
* loaded only when useful
* easy to inspect and replace

A security-review skill can load for security review.

A database-migration skill can load for a migration.

Neither needs to occupy every coding session.

Skills may be available by default without being injected by default.

**Available is not the same as active.**

Avoid turning skills into another framework of routers, dependency graphs, lifecycle hooks, and hidden activation logic.

A skill adds knowledge. Nothing more.

## 8. Subagents are optional execution

Most tasks should start with one capable model.

Subagents earn their place when they provide something distinct:

* independent review
* fresh context
* parallel investigation
* isolated exploration
* genuinely separable work

They should not be the default execution model.

Do not recreate a software company with planner, architect, coder, tester, critic, reviewer, and manager agents unless the task genuinely requires that structure.

A KISS subagent is simple:

> Give another model a bounded task, minimum necessary context, appropriate tools, and return the result.

**A skill adds knowledge. A subagent adds independent execution.**

## 9. Research should stay lean too

Research often needs capabilities that ordinary coding does not.

Web search and fetch should therefore be easy to enable for research without becoming ambient coding tools.

A normal research loop can remain simple:

**search → inspect evidence → follow useful sources → synthesize**

Deep research may justify parallel subagents.

Ordinary research usually does not.

Do not build orchestration simply because research sounds complex.

**Do not orchestrate what one strong model can already do.**

## 10. Prefer native mechanisms

Claude KISS should not become another agent runtime.

Claude Code already provides execution, sessions, authentication, tools, models, and native capabilities.

Use those mechanisms wherever they are sufficient.

KISS should mostly:

* remove unwanted defaults
* expose useful controls
* constrain behavior
* provide clearer policy
* make optional capabilities explicit

Every KISS-specific abstraction creates another thing to maintain.

**Native first. Wrapper only when necessary.**

## 11. Keep the system inspectable

The user should be able to understand what is active:

* prompt
* settings
* tools
* skills
* MCP
* web access
* integrations
* subagents
* effective Claude command

Hidden behavior creates loss of control.

Dry-run and diagnostics are valuable because they make the harness explain itself.

**Transparency beats magic.**

## 12. Measure outcomes, not ideology

KISS is not dogma.

Four tools are not automatically better than six.

A shorter prompt is not automatically better.

One agent is not automatically better than two.

Measure what matters:

* correctness
* robustness
* scope discipline
* unnecessary work
* tokens
* latency
* cost
* context usage
* reliability

Also watch complexity itself:

* duplicated prompt semantics
* unnecessary configuration
* wrapper abstractions
* ambient capabilities
* hidden policy

If additional complexity buys meaningful value, keep it.

If it does not, remove it.

## The rule

Claude KISS can be reduced to this:

> **Keep every capability that provides distinct value. Remove duplicated policy, unnecessary orchestration, hidden vendor behavior, and complexity that does not.**

Keep the model powerful.

Keep the harness understandable.

Use skills when knowledge helps.

Use subagents when independent execution helps.

Use web tools when research needs them.

Use vendor features when the user wants them.

Nothing ambient merely because it exists.

Nothing removed merely to look minimal.

**Simple is not bare-bones.
Simple is capability without unnecessary complexity.
The model works for the user. Keep it that way.**
