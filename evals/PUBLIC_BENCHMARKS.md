# Optional public benchmark recipes

Claude KISS does not install these benchmarks, run them automatically, or vendor their
tasks. They are explicit, expensive, containerized probes for people changing the
launcher or prompt. The cheap paired evaluator in [`run_evals.py`](run_evals.py) remains
the normal regression check.

## Rules for useful results

- Pin the exact benchmark commit and Claude Code version.
- Use the same model, effort, attempt count, timeout, container provider, and date for
  any runs being compared.
- Record task IDs, verifier outcomes, cost, wall time, turns, failures, and all local
  patches.
- Prefer a few repeated, relevant tasks over a broad single-attempt sweep.
- Never compare a public-benchmark Claude Code run with a KISS run unless both runners
  are demonstrably launched through the intended executable and configuration.
- Do not turn a favorable run into a claim of universal superiority.

## Common builder workflows: Terminal-Bench 2.1

- Source: <https://github.com/harbor-framework/terminal-bench-2-1>
- Benchmark: <https://www.tbench.ai/>
- Pinned commit: `7131e4375048a0e408a8fb404b5f499d726b695b`
- License: Apache-2.0
- Full suite: 89 container tasks

The selected ten tasks cover the recurring builder flows that Claude KISS is meant to
improve: repository recovery, implementation, debugging, build repair, data recovery,
data integration, query performance, service configuration, security repair, and
migration.

| Task ID | Workflow probe |
|---|---|
| `fix-git` | Recover lost work without speculative repository changes |
| `cancel-async-tasks` | Implement a complete concurrency and cleanup behavior |
| `custom-memory-heap-crash` | Diagnose a release-only native-code failure |
| `build-cython-ext` | Repair a source build against current dependencies |
| `sqlite-db-truncate` | Recover structured data from damaged state |
| `multi-source-data-merger` | Integrate heterogeneous inputs deterministically |
| `query-optimize` | Preserve output while improving performance |
| `nginx-request-logging` | Configure and verify a local service |
| `fix-code-vulnerability` | Fix a real security defect at the correct layer |
| `modernize-scientific-stack` | Migrate legacy code without inventing behavior |

Optional local recipe:

```sh
git clone https://github.com/harbor-framework/terminal-bench-2-1.git
git -C terminal-bench-2-1 checkout 7131e4375048a0e408a8fb404b5f499d726b695b
uv tool install harbor

export ANTHROPIC_API_KEY=...  # Never commit a real key.
for task in \
  fix-git cancel-async-tasks custom-memory-heap-crash build-cython-ext \
  sqlite-db-truncate multi-source-data-merger query-optimize \
  nginx-request-logging fix-code-vulnerability modernize-scientific-stack
do
  harbor trial start \
    --path "terminal-bench-2-1/tasks/$task" \
    --agent claude-code \
    --model "$MODEL"
done
```

This is currently a public-workload compatibility probe. Harbor's installed
`claude-code` adapter is not automatically a paired Claude KISS adapter. Do not pretend
that changing `PATH` makes a valid comparison unless the full remote installation and
launch path is audited.

## Long-horizon stress: Long-Horizon Terminal-Bench

- Source: <https://github.com/zli12321/LHTB>
- Benchmark: <https://zli12321.github.io/LHTB/>
- Paper: <https://arxiv.org/abs/2607.08964>
- Pinned commit: `84d7ba5ee34fae6c11f0d7cb8ed5faa73a9ece54`
- License: Apache-2.0
- Full suite: 46 tasks

The initial three-task probe is intentionally small:

| Task ID | Why it matters |
|---|---|
| `great-expectations-audit` | Sustained repository audit and repair |
| `langchain-version-migration` | Long dependency migration with hidden behavioral checks |
| `commit0-multilib-tdd` | Multi-library implementation, self-testing, and completion discipline |

Use the benchmark's bundled modified Harbor when running tasks that depend on
`continue_until_timeout`; stock Harbor changes their semantics. On Apple Silicon, export
`DOCKER_DEFAULT_PLATFORM=linux/amd64` because many images are amd64-only. Follow the
pinned repository's setup and pass credentials only through the environment.

These tasks can run for one to five hours each and may cost substantial model budget.
They are for deliberate prompt/launcher experiments, not routine `tests/test.sh`.

## Deferred benchmarks

| Benchmark | Reason for deferral |
|---|---|
| SWE-bench Verified | Useful and familiar, but frozen, Python-heavy, contamination-prone, and costly to run fairly |
| SWE-bench Live | Better recency, but dataset revisions and adapter work add more moving parts than the first release needs |
| SWE-bench Pro | Strong long-horizon signal, but infrastructure and cost are disproportionate for routine launcher validation |
| CodeScaleBench | Good large-repository taxonomy, but materially Sourcegraph/retrieval-centric for the current six-tool default |
| Aider Polyglot / LiveCodeBench | Useful model probes, but weak representations of terminal repository workflows |

Adding one of these requires a pinned task manifest, a reproducible adapter, and actual
results—not a leaderboard screenshot.
