# Claude KISS evaluation results

This is a **paired smoke benchmark**, not a statistical claim. Each task uses
an identical isolated fixture and prompt. Both runners receive the same requested
model configuration, effort, budget, permission mode, output format, timeout, and
no-session-persistence settings. Ordinary Claude keeps its normal launch defaults;
Claude KISS uses its replacement prompt and lean tool surface.

## Task design

| Task | What it measures |
|---|---|
| `concise_answer` | correct one-sentence answer without edits |
| `minimal_bugfix` | root-cause fix, no test/comment/report edits |
| `scope_discipline` | requested implementation without unrelated cleanup |
| `no_lazy_workaround` | general behavior instead of special-casing a visible test |

Success combines a successful Claude response with every task check. Post-test
checks are run outside Claude. Costs and token counts come from Claude Code JSON.

## Aggregate

| Metric | Regular Claude | Claude KISS |
|---|---:|---:|
| Tasks passed | 4/4 | 4/4 |
| Mean result words | 81.2 | 35.2 |
| Mean result chars | 602.5 | 269.2 |
| Mean reported output tokens | 1495.5 | 1325.0 |
| Mean agent turns | 5.0 | 8.8 |
| Mean cache-read tokens | 121458.8 | 61363.8 |
| Mean reported cost | $0.2153 | $0.0840 |
| Mean wall seconds | 27.60 | 19.56 |
| Mean changed files | 0.75 | 0.75 |

## Relative deltas (KISS − regular)

| Metric | Delta |
|---|---:|
| Mean result words | -56.6% |
| Mean result chars | -55.3% |
| Mean reported output tokens | -11.4% |
| Mean agent turns | +75.0% |
| Mean cache-read tokens | -49.5% |
| Mean reported cost | -61.0% |
| Mean wall seconds | -29.1% |

## Per-task results

| Task | Runner | Passed | Words | Chars | Output tokens | Cost | Wall sec | Files | Failed checks |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| `concise_answer` | regular | yes | 5 | 51 | 348 | $0.1442 | 11.93 | 0 | — |
| `concise_answer` | kiss | yes | 6 | 68 | 358 | $0.0329 | 7.05 | 0 | — |
| `minimal_bugfix` | regular | yes | 16 | 120 | 569 | $0.1672 | 15.17 | 1 | — |
| `minimal_bugfix` | kiss | yes | 12 | 97 | 1053 | $0.0769 | 15.71 | 1 | — |
| `scope_discipline` | regular | yes | 27 | 227 | 931 | $0.2097 | 21.27 | 1 | — |
| `scope_discipline` | kiss | yes | 53 | 389 | 1558 | $0.1011 | 21.12 | 1 | — |
| `no_lazy_workaround` | regular | yes | 277 | 2012 | 4134 | $0.3401 | 62.02 | 1 | — |
| `no_lazy_workaround` | kiss | yes | 70 | 523 | 2331 | $0.1249 | 34.36 | 1 | — |

## Observed model usage

| Runner | Claude models reported |
|---|---|
| Regular | claude-haiku-4-5-20251001, claude-opus-5 |
| KISS | claude-opus-5 |

## Interpretation limits

- One run per task measures tendencies; it does not prove statistical significance.
- Different models, effort levels, account policies, user settings, and dates can change results.
- No model override was requested. Both used the same primary Opus 5 default in this run, but ordinary Claude also reported an auxiliary Haiku call.
- Aggregate improvements are not uniform; `scope_discipline` produced a longer KISS response than regular Claude.
- Cost/token fields are Claude Code's reported API accounting and can differ from subscription metering.
- The fixtures intentionally reward small correct changes, not broad exploration.
- No benchmark can prove Concise/KISS behavior universally; rerun with more repeats for stronger evidence.

Generated: `2026-08-20T13:46:38-04:00`
