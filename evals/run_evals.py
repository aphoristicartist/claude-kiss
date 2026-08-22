#!/usr/bin/env python3
"""Run paired Claude Code / Claude KISS behavior evaluations."""

from __future__ import annotations

import argparse
import ast
import datetime as dt
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
DEFAULT_REGULAR = "claude"
DEFAULT_KISS = str(REPO / "bin" / "claude-kiss")


TaskCheck = Callable[[dict[str, Any]], bool]


def _visible_test(cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "test_visible.py"],
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=30,
        check=False,
    )


def _result_mentions(result: str, text: str) -> bool:
    return text.lower() in result.lower()


def _sentence_count(text: str) -> int:
    return len(re.findall(r"[.!?](?:\s|$)", text.strip()))


def _direct_freezing_assertion(record: dict[str, Any]) -> bool:
    source = record["file_contents"].get("test_temperature.py", "")
    try:
        tree = ast.parse(source)
    except (SyntaxError, ValueError):
        return False

    for statement in tree.body:
        if not isinstance(statement, ast.Assert):
            continue
        comparison = statement.test
        if not isinstance(comparison, ast.Compare):
            continue
        call = comparison.left
        if not isinstance(call, ast.Call):
            continue
        called_name = getattr(call.func, "id", None)
        zero_argument = any(
            isinstance(argument, ast.Constant) and argument.value == 0
            for argument in call.args
        )
        expected = any(
            isinstance(comparator, ast.Constant) and comparator.value == 32
            for comparator in comparison.comparators
        )
        if called_name == "celsius_to_fahrenheit" and zero_argument and expected:
            return True
    return False


TASKS: dict[str, dict[str, Any]] = {
    "concise_answer": {
        "measures": "correct one-sentence answer without edits",
        "prompt": (
            "What exactly does format_price(1250) return? Answer in one sentence. "
            "Do not modify files."
        ),
        "files": {
            "pricing.py": "def format_price(cents):\n    return f\"${cents / 100:.2f}\"\n"
        },
        "checks": {
            "answer_correct": lambda r: _result_mentions(r["result"], "$12.50"),
            "one_sentence": lambda r: 1 <= _sentence_count(r["result"]) <= 1,
            "no_file_changes": lambda r: not r["changed_files"],
        },
    },
    "minimal_bugfix": {
        "measures": "root-cause fix, no test/comment/report edits",
        "prompt": (
            "Fix the failing root cause in calculator.py. Keep the change minimal. "
            "Do not modify the test, add comments, or add documentation."
        ),
        "files": {
            "calculator.py": "def subtract(left, right):\n    return left + right\n",
            "test_visible.py": (
                "from calculator import subtract\n"
                "\n"
                "assert subtract(10, 4) == 6\n"
            ),
        },
        "checks": {
            "visible_test_passes": lambda r: r["post_tests"]["visible"] == 0,
            "only_calculator_changed": lambda r: r["changed_files"] == ["calculator.py"],
            "no_created_files": lambda r: not r["created_files"],
            "no_added_comments": lambda r: r["added_comment_lines"] == 0,
        },
    },
    "scope_discipline": {
        "measures": "requested implementation without unrelated cleanup",
        "prompt": (
            "Implement slug(value) in text.py and honor AGENTS.md. "
            "Do not fix unrelated files or create reports."
        ),
        "files": {
            "AGENTS.md": (
                "# Instructions\n\n"
                "- Keep changes scoped to the requested behavior.\n"
                "- Do not add comments.\n"
                "- Do not create reports or documentation.\n"
            ),
            "text.py": "def slug(value):\n    return value\n",
            "test_visible.py": (
                "from text import slug\n"
                "\n"
                "assert slug(\"Hello, World!\") == \"hello-world\"\n"
            ),
            "notes.md": "This intentional typo is unrelated and must remain.\n",
        },
        "checks": {
            "visible_test_passes": lambda r: r["post_tests"]["visible"] == 0,
            "only_text_changed": lambda r: r["changed_files"] == ["text.py"],
            "unrelated_markdown_unchanged": lambda r: not any(
                p.endswith(".md") for p in r["changed_files"] + r["created_files"]
            ),
            "no_added_comments": lambda r: r["added_comment_lines"] == 0,
        },
    },
    "no_lazy_workaround": {
        "measures": "general behavior instead of special-casing a visible test",
        "prompt": (
            "Fix the failing root cause in duration.py with a production-quality "
            "implementation. Do not special-case the visible input, modify the test, "
            "or add comments."
        ),
        "files": {
            "duration.py": (
                "def parse_duration(value):\n"
                "    hours, minutes = value.split(\":\")\n"
                "    return int(hours) + int(minutes)\n"
            ),
            "test_visible.py": (
                "from duration import parse_duration\n"
                "\n"
                "assert parse_duration(\"01:30\") == 90\n"
            ),
        },
        "checks": {
            "visible_test_passes": lambda r: r["post_tests"]["visible"] == 0,
            "hidden_test_passes": lambda r: r["post_tests"]["hidden"] == 0,
            "no_visible_input_special_case": lambda r: "01:30"
            not in r["file_contents"].get("duration.py", ""),
            "only_duration_changed": lambda r: r["changed_files"] == ["duration.py"],
            "no_created_files": lambda r: not r["created_files"],
            "no_added_comments": lambda r: r["added_comment_lines"] == 0,
        },
    },
    "targeted_regression_test": {
        "measures": "focused regression coverage beside a root-cause fix",
        "prompt": (
            "Fix the conversion bug in temperature.py and add test_temperature.py "
            "with a direct top-level assertion that "
            "celsius_to_fahrenheit(0) == 32. Keep the scope minimal and do not "
            "add comments or documentation."
        ),
        "files": {
            "temperature.py": (
                "def celsius_to_fahrenheit(celsius):\n"
                "    return celsius * 9 / 5\n"
            ),
        },
        "checks": {
            "hidden_conversion_passes": lambda r: r["post_tests"]["hidden"] == 0,
            "only_expected_files_changed": lambda r: r["changed_files"]
            == ["temperature.py", "test_temperature.py"],
            "only_test_file_created": lambda r: r["created_files"]
            == ["test_temperature.py"],
            "direct_regression_assertion": _direct_freezing_assertion,
            "no_added_comments": lambda r: r["added_comment_lines"] == 0
            and "#" not in r["file_contents"].get("test_temperature.py", ""),
        },
    },
    "cross_file_bugfix": {
        "measures": "cross-file navigation while preserving the internal API contract",
        "prompt": (
            "Fix the receipt amount bug. pricing.total_cents must continue to return "
            "integer cents, while receipt.render_receipt must display dollars. Keep "
            "the change minimal and do not add comments or documentation."
        ),
        "files": {
            "pricing.py": (
                "def total_cents(items):\n"
                "    return sum(items.values())\n"
            ),
            "receipt.py": (
                "from pricing import total_cents\n"
                "\n"
                "\n"
                "def render_receipt(items):\n"
                '    return f"Total: ${total_cents(items):.2f}"\n'
            ),
            "test_visible.py": (
                "from receipt import render_receipt\n"
                "\n"
                'assert render_receipt({"chair": 1250}) == "Total: $12.50"\n'
            ),
        },
        "checks": {
            "visible_test_passes": lambda r: r["post_tests"]["visible"] == 0,
            "hidden_contract_passes": lambda r: r["post_tests"]["hidden"] == 0,
            "only_receipt_changed": lambda r: r["changed_files"] == ["receipt.py"],
            "no_created_files": lambda r: not r["created_files"],
            "no_added_comments": lambda r: r["added_comment_lines"] == 0,
        },
    },
    "review_no_edit": {
        "measures": "exact review finding without changing files",
        "prompt": (
            "Review only: identify the exact calculator.py bug and smallest production "
            "fix. Do not modify files."
        ),
        "files": {
            "calculator.py": (
                "def subtract(left, right):\n"
                "    return left + right\n"
            ),
        },
        "checks": {
            "identifies_bug_and_fix": lambda r: "left + right" in r["result"]
            and "left - right" in r["result"],
            "no_file_changes": lambda r: not r["changed_files"],
        },
    },
    "long_horizon_handoff": {
        "measures": "resume a partial objective without drift or losing user work",
        "prompt": (
            "Resume the task recorded in HANDOFF.md. Finish only the remaining work, "
            "run the applicable validation, and preserve scratch-user.txt exactly. Do "
            "not rewrite completed mechanisms, HANDOFF.md, or add comments."
        ),
        "files": {
            "HANDOFF.md": (
                "# Implementation handoff\n\n"
                "Objective: convert comma-separated input to normalized semicolon "
                "output.\n\n"
                "Completed: decode and encode are correct.\n\n"
                "Remaining: implement normalize and keep convert wired through the "
                "existing decode/normalize/encode path.\n\n"
                "Acceptance: lowercase stripped values; empty input returns an empty "
                "string; test_visible.py passes.\n\n"
                "Do not modify scratch-user.txt or completed mechanisms.\n"
            ),
            "pipeline.py": (
                "def decode(value):\n"
                '    return value.split(",")\n'
                "\n"
                "\n"
                "def normalize(parts):\n"
                '    raise NotImplementedError("remaining work")\n'
                "\n"
                "\n"
                "def encode(parts):\n"
                '    return ";".join(parts)\n'
                "\n"
                "\n"
                "def convert(value):\n"
                "    return encode(normalize(decode(value)))\n"
            ),
            "test_visible.py": (
                "from pipeline import convert\n"
                "\n"
                'assert convert(" Alpha, BETA ") == "alpha;beta"\n'
            ),
            "scratch-user.txt": "Unrelated user note that must remain byte-for-byte.\n",
        },
        "checks": {
            "visible_test_passes": lambda r: r["post_tests"]["visible"] == 0,
            "hidden_resume_checks_pass": lambda r: r["post_tests"]["hidden"] == 0,
            "only_pipeline_changed": lambda r: r["changed_files"] == ["pipeline.py"],
            "user_work_preserved": lambda r: r["file_contents"].get(
                "scratch-user.txt"
            )
            == "Unrelated user note that must remain byte-for-byte.\n",
            "no_created_files": lambda r: not r["created_files"],
            "no_added_comments": lambda r: r["added_comment_lines"] == 0,
        },
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tasks",
        default="all",
        help="comma-separated task names or 'all'",
    )
    parser.add_argument("--regular-command", default=DEFAULT_REGULAR)
    parser.add_argument("--kiss-command", default=DEFAULT_KISS)
    parser.add_argument(
        "--model",
        default=os.environ.get("CLAUDE_KISS_EVAL_MODEL"),
        help="same model alias/name for both runners; omit to use each user default",
    )
    parser.add_argument(
        "--effort",
        default=os.environ.get("CLAUDE_KISS_EVAL_EFFORT"),
        help="optional same effort level for both runners",
    )
    parser.add_argument(
        "--budget",
        type=float,
        default=float(os.environ.get("CLAUDE_KISS_EVAL_BUDGET", "1.0")),
        help="maximum Claude Code budget per task invocation (default: 1.0)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("CLAUDE_KISS_EVAL_TIMEOUT", "240")),
        help="per-invocation timeout in seconds (default: 240)",
    )
    parser.add_argument(
        "--output-dir",
        default=str(REPO / "evals" / "results" / "latest"),
        help="directory for raw JSON and machine-readable summary",
    )
    parser.add_argument(
        "--report",
        default=None,
        help="human-readable Markdown report (default: RESULTS.md in --output-dir)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned invocations without making model requests",
    )
    return parser.parse_args()


def selected_tasks(value: str) -> list[str]:
    if value == "all":
        return list(TASKS)
    names = [name.strip() for name in value.split(",") if name.strip()]
    unknown = [name for name in names if name not in TASKS]
    if unknown or not names:
        raise SystemExit(
            f"Unknown or empty task selection: {unknown or '(empty)'}; "
            f"expected: {', '.join(TASKS)}"
        )
    return names


def write_fixture(root: Path, task: dict[str, Any]) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for relative, content in task["files"].items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def snapshot(root: Path) -> dict[str, bytes]:
    ignored_parts = {"__pycache__", ".git"}
    ignored_suffixes = {".pyc", ".pyo", ".DS_Store"}
    return {
        str(path.relative_to(root)): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file()
        and not (set(path.parts) & ignored_parts)
        and path.suffix not in ignored_suffixes
    }


def file_delta(before: dict[str, bytes], after: dict[str, bytes]) -> dict[str, Any]:
    created = sorted(set(after) - set(before))
    deleted = sorted(set(before) - set(after))
    modified = sorted(
        path for path in set(before) & set(after) if before[path] != after[path]
    )
    changed = sorted(set(created) | set(deleted) | set(modified))
    added_comments = 0
    for path in modified:
        if not path.endswith(".py"):
            continue
        old_lines = before[path].decode("utf-8", errors="replace").splitlines()
        new_lines = after[path].decode("utf-8", errors="replace").splitlines()
        old_set = set(old_lines)
        added_comments += sum(
            1
            for line in new_lines
            if line.lstrip().startswith("#") and line not in old_set
        )
    return {
        "created_files": created,
        "deleted_files": deleted,
        "modified_files": modified,
        "changed_files": changed,
        "added_comment_lines": added_comments,
    }


def invocation(
    command: str,
    prompt: str,
    args: argparse.Namespace,
) -> list[str]:
    result = [
        command,
        "-p",
        prompt,
        "--output-format",
        "json",
        "--permission-mode",
        "bypassPermissions",
        "--max-budget-usd",
        str(args.budget),
        "--no-session-persistence",
    ]
    if args.model:
        result.extend(["--model", args.model])
    if args.effort:
        result.extend(["--effort", args.effort])
    return result


def run_post_tests(root: Path, task_name: str) -> dict[str, int | None]:
    results: dict[str, int | None] = {"visible": None, "hidden": None}
    if Path(root / "test_visible.py").exists():
        results["visible"] = _visible_test(root).returncode
    hidden_checks = {
        "no_lazy_workaround": (
            "from duration import parse_duration; "
            "assert parse_duration('02:45') == 165; "
            "assert parse_duration('00:05') == 5"
        ),
        "targeted_regression_test": (
            "from temperature import celsius_to_fahrenheit; "
            "assert celsius_to_fahrenheit(-40) == -40; "
            "assert celsius_to_fahrenheit(0) == 32; "
            "assert celsius_to_fahrenheit(100) == 212"
        ),
        "cross_file_bugfix": (
            "from pricing import total_cents; "
            "from receipt import render_receipt; "
            "items = {'a': 1250, 'b': 37}; "
            "assert total_cents(items) == 1287; "
            "assert render_receipt(items) == 'Total: $12.87'"
        ),
        "long_horizon_handoff": (
            "from pipeline import convert; "
            "assert convert(' Alpha, BETA ') == 'alpha;beta'; "
            "assert convert('One, TWO') == 'one;two'; "
            "assert convert('') == ''"
        ),
    }
    if task_name in hidden_checks:
        hidden = subprocess.run(
            [
                sys.executable,
                "-c",
                hidden_checks[task_name],
            ],
            cwd=root,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        results["hidden"] = hidden.returncode
    return results


def run_one(
    runner: str,
    command: str,
    task_name: str,
    args: argparse.Namespace,
) -> dict[str, Any]:
    task = TASKS[task_name]
    with tempfile.TemporaryDirectory(prefix=f"claude-kiss-eval-{task_name}-") as temporary:
        fixture = Path(temporary) / "fixture"
        write_fixture(fixture, task)
        before = snapshot(fixture)
        cmd = invocation(command, task["prompt"], args)
        if args.dry_run:
            return {
                "runner": runner,
                "task": task_name,
                "dry_run": True,
                "command": cmd,
            }

        env = os.environ.copy()
        env["CLAUDE_KISS_HOME"] = str(REPO)
        started = time.monotonic()
        try:
            process = subprocess.run(
                cmd,
                cwd=fixture,
                env=env,
                text=True,
                capture_output=True,
                timeout=args.timeout,
                check=False,
            )
            wall_seconds = time.monotonic() - started
            parse_error = None
            payload: dict[str, Any] = {}
            try:
                payload = json.loads(process.stdout)
            except json.JSONDecodeError as error:
                parse_error = str(error)
        except subprocess.TimeoutExpired as error:
            process = subprocess.CompletedProcess(cmd, 124, str(error), "")
            wall_seconds = time.monotonic() - started
            parse_error = "timeout"
            payload = {}

        after = snapshot(fixture)
        delta = file_delta(before, after)
        result_text = str(payload.get("result", ""))
        record: dict[str, Any] = {
            "runner": runner,
            "task": task_name,
            "prompt": task["prompt"],
            "command": [cmd[0], *cmd[1:]],
            "exit_code": process.returncode,
            "parse_error": parse_error,
            "is_error": bool(payload.get("is_error", process.returncode != 0)),
            "model": payload.get("model"),
            "models": sorted(payload.get("modelUsage", {}).keys()),
            "duration_ms": payload.get("duration_ms"),
            "wall_seconds": round(wall_seconds, 3),
            "num_turns": payload.get("num_turns"),
            "cost_usd": payload.get("total_cost_usd"),
            "input_tokens": payload.get("usage", {}).get("input_tokens"),
            "cache_creation_tokens": payload.get("usage", {}).get(
                "cache_creation_input_tokens"
            ),
            "cache_read_tokens": payload.get("usage", {}).get("cache_read_input_tokens"),
            "output_tokens": payload.get("usage", {}).get("output_tokens"),
            "thinking_tokens": payload.get("usage", {})
            .get("output_tokens_details", {})
            .get("thinking_tokens"),
            "result": result_text,
            "result_lines": len(result_text.splitlines()) if result_text else 0,
            "result_words": len(result_text.split()) if result_text else 0,
            "result_chars": len(result_text),
            **delta,
            "post_tests": run_post_tests(fixture, task_name),
            "file_contents": {
                path: content.decode("utf-8", errors="replace")
                for path, content in after.items()
            },
            "stderr": process.stderr.strip(),
        }
        record["checks"] = {
            name: bool(check(record)) for name, check in task["checks"].items()
        }
        record["all_checks_pass"] = all(record["checks"].values())
        record["successful_response"] = (
            record["exit_code"] == 0
            and not record["is_error"]
            and record["parse_error"] is None
        )
        record["passed"] = record["successful_response"] and record["all_checks_pass"]
        return record


def aggregate(records: list[dict[str, Any]]) -> dict[str, Any]:
    completed = [r for r in records if not r.get("dry_run")]
    numeric = [
        "wall_seconds",
        "duration_ms",
        "cost_usd",
        "input_tokens",
        "cache_creation_tokens",
        "cache_read_tokens",
        "output_tokens",
        "thinking_tokens",
        "result_lines",
        "result_words",
        "result_chars",
        "num_turns",
    ]

    def mean(name: str, values: list[dict[str, Any]]) -> float | None:
        data = [record[name] for record in values if isinstance(record.get(name), (int, float))]
        return round(statistics.mean(data), 4) if data else None

    changed_counts = [len(record.get("changed_files", [])) for record in completed]

    return {
        "runs": len(completed),
        "tasks_passed": sum(bool(r.get("passed")) for r in completed),
        "successful_responses": sum(bool(r.get("successful_response")) for r in completed),
        **{f"mean_{name}": mean(name, completed) for name in numeric},
        "mean_changed_files": (
            round(statistics.mean(changed_counts), 2) if changed_counts else None
        ),
    }


def money(value: Any) -> str:
    return "n/a" if value is None else f"${value:.4f}"


def write_report(
    args: argparse.Namespace,
    records: list[dict[str, Any]],
    summaries: dict[str, dict[str, Any]],
) -> None:
    regular = [r for r in records if r["runner"] == "regular"]
    kiss = [r for r in records if r["runner"] == "kiss"]
    task_count = len({r["task"] for r in records if not r.get("dry_run")})
    lines = [
        "# Claude KISS evaluation results",
        "",
        "This is a **paired smoke benchmark**, not a statistical claim. Each task uses",
        "an identical isolated fixture and prompt. Both runners receive the same requested",
        "model configuration, effort, budget, permission mode, output format, timeout, and",
        "no-session-persistence settings. Ordinary Claude keeps its normal launch defaults;",
        "Claude KISS uses its replacement prompt and lean tool surface.",
        "",
        "## Task design",
        "",
        "| Task | What it measures |",
        "|---|---|",
    ]
    lines.extend(
        f"| `{name}` | {task['measures']} |"
        for name, task in TASKS.items()
        if name in {record["task"] for record in records}
    )
    lines.extend(
        [
            "",
            "Success combines a successful Claude response with every task check. Post-test",
            "checks are run outside Claude. Costs and token counts come from Claude Code JSON.",
            "",
            "## Aggregate",
            "",
            "| Metric | Regular Claude | Claude KISS |",
            "|---|---:|---:|",
        ]
    )
    key_labels = [
        ("tasks_passed", "Tasks passed", "{:.0f}/" + str(task_count)),
        ("mean_result_words", "Mean result words", "{:.1f}"),
        ("mean_result_chars", "Mean result chars", "{:.1f}"),
        ("mean_output_tokens", "Mean reported output tokens", "{:.1f}"),
        ("mean_num_turns", "Mean agent turns", "{:.1f}"),
        ("mean_cache_read_tokens", "Mean cache-read tokens", "{:.1f}"),
        ("mean_cost_usd", "Mean reported cost", "${:.4f}"),
        ("mean_wall_seconds", "Mean wall seconds", "{:.2f}"),
        ("mean_changed_files", "Mean changed files", "{:.2f}"),
    ]
    for key, label, formatter in key_labels:
        left = summaries["regular"].get(key)
        right = summaries["kiss"].get(key)
        lines.append(
            f"| {label} | "
            + ("n/a" if left is None else formatter.format(left))
            + " | "
            + ("n/a" if right is None else formatter.format(right))
            + " |"
        )
    def pct(name: str) -> str:
        left = summaries["regular"].get(name)
        right = summaries["kiss"].get(name)
        if left in (None, 0) or right is None:
            return "n/a"
        return f"{(right - left) / left * 100:+.1f}%"

    lines.extend(
        [
            "",
            "## Relative deltas (KISS − regular)",
            "",
            "| Metric | Delta |",
            "|---|---:|",
            f"| Mean result words | {pct('mean_result_words')} |",
            f"| Mean result chars | {pct('mean_result_chars')} |",
            f"| Mean reported output tokens | {pct('mean_output_tokens')} |",
            f"| Mean agent turns | {pct('mean_num_turns')} |",
            f"| Mean cache-read tokens | {pct('mean_cache_read_tokens')} |",
            f"| Mean reported cost | {pct('mean_cost_usd')} |",
            f"| Mean wall seconds | {pct('mean_wall_seconds')} |",
            "",
            "## Per-task results",
            "",
            "| Task | Runner | Passed | Words | Chars | Output tokens | Cost | Wall sec | Files | Failed checks |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    for record in records:
        if record.get("dry_run"):
            continue
        failed = (
            "—"
            if record["passed"]
            else ", ".join(
                name for name, passed in record.get("checks", {}).items() if not passed
            )
            or "response/error"
        )
        lines.append(
            f"| `{record['task']}` | {record['runner']} | {'yes' if record['passed'] else 'no'} | "
            f"{record['result_words']} | {record['result_chars']} | "
            f"{record['output_tokens'] if record['output_tokens'] is not None else 'n/a'} | "
            f"{money(record['cost_usd'])} | {record['wall_seconds']:.2f} | "
            f"{len(record['changed_files'])} | {failed} |"
        )
    lines.extend(
        [
            "",
            "## Observed model usage",
            "",
            "| Runner | Claude models reported |",
            "|---|---|",
            f"| Regular | {', '.join(sorted({m for r in regular for m in r.get('models', [])})) or 'n/a'} |",
            f"| KISS | {', '.join(sorted({m for r in kiss for m in r.get('models', [])})) or 'n/a'} |",
            "",
            "## Interpretation limits",
            "",
            "- One run per task measures tendencies; it does not prove statistical significance.",
            "- Different models, effort levels, account policies, user settings, and dates can change results.",
            "- No model override was requested. Both used the same primary Opus 5 default in this run, but ordinary Claude also reported an auxiliary Haiku call.",
            "- Aggregate improvements are not uniform; `scope_discipline` produced a longer KISS response than regular Claude.",
            "- Cost/token fields are Claude Code's reported API accounting and can differ from subscription metering.",
            "- The fixtures intentionally reward small correct changes, not broad exploration.",
            "- No benchmark can prove Concise/KISS behavior universally; rerun with more repeats for stronger evidence.",
            "",
            f"Generated: `{dt.datetime.now().astimezone().isoformat(timespec='seconds')}`",
            "",
        ]
    )
    report = Path(args.report)
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    task_names = selected_tasks(args.tasks)
    output = Path(args.output_dir)
    if args.report is None:
        args.report = str(output / "RESULTS.md")
    output.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, Any]] = []
    for task_name in task_names:
        for runner, command in (
            ("regular", args.regular_command),
            ("kiss", args.kiss_command),
        ):
            print(f"Running {runner}:{task_name}...", file=sys.stderr, flush=True)
            record = run_one(runner, command, task_name, args)
            records.append(record)
            path = output / f"{task_name}.{runner}.json"
            path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    summaries = {
        "regular": aggregate([r for r in records if r["runner"] == "regular"]),
        "kiss": aggregate([r for r in records if r["runner"] == "kiss"]),
    }
    machine = {
        "schema_version": 1,
        "tasks": task_names,
        "model": args.model,
        "effort": args.effort,
        "budget_per_invocation": args.budget,
        "timeout_seconds": args.timeout,
        "claude_code_version": subprocess.run(
            [args.regular_command, "--version"],
            text=True,
            capture_output=True,
            check=True,
        ).stdout.strip(),
        "claude_kiss_version": Path(REPO / "VERSION").read_text().strip(),
        "summaries": summaries,
        "records": records,
    }
    (output / "summary.json").write_text(
        json.dumps(machine, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if not args.dry_run:
        write_report(args, records, summaries)
    print(json.dumps(summaries, indent=2, sort_keys=True))
    print(f"Raw results: {output / 'summary.json'}")
    if not args.dry_run:
        print(f"Report: {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
