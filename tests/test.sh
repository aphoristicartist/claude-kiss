#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-test.XXXXXX")
version=$(cat "$repo_dir/VERSION")
generated_release="$repo_dir/dist"
trap 'rm -rf "$temporary" "$generated_release"' EXIT HUP INT TERM
grep -q "version=\"$version\"" "$repo_dir/bin/claude-kiss"
grep -q "release_version=\${CLAUDE_KISS_VERSION:-$version}" "$repo_dir/install.sh"
grep -q 'https://claude-kiss.com/install.sh' "$repo_dir/README.md"
grep -q 'https://github.com/aphoristicartist/claude-kiss' "$repo_dir/install.sh"
grep -q 'https://claude-kiss.com/releases/v$release_version/claude-kiss.tar.gz' \
  "$repo_dir/install.sh"
grep -q 'source.sha256' "$repo_dir/install.sh"
[ ! -e "$repo_dir/bin/claude-kiss-profile" ]

python3 - <<'PY'
import json
from pathlib import Path

settings = json.loads(Path("config/settings.json").read_text())
assert settings["disableBundledSkills"] is True
assert settings["disableWorkflows"] is True
assert settings["disableArtifact"] is True
assert settings["disableRemoteControl"] is True
assert settings["disableClaudeAiConnectors"] is True
assert settings["attribution"] == {"commit": "", "pr": "", "sessionUrl": False}
assert settings["env"]["DISABLE_TELEMETRY"] == "1"
assert settings["env"]["DISABLE_ERROR_REPORTING"] == "1"
assert settings["env"]["DISABLE_AUTOUPDATER"] == "1"
assert settings["env"]["CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY"] == "1"
assert settings["env"]["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] == "1"
assert settings["env"]["CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL"] == "1"
assert settings["env"]["CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT"] == "1"
assert "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" not in settings["env"]
assert settings["autoMemoryEnabled"] is False
assert settings["autoCompactEnabled"] is True
assert settings["includeGitInstructions"] is False
# Prompt and compact-memory behavior is protected by evals/run_evals.py.
# Asserting exact sentences here would freeze wording instead of outcomes.
assert Path("prompt/claude-kiss.md").read_text().strip()
assert Path("memory/CLAUDE.md").read_text().strip()

launcher = Path("bin/claude-kiss").read_text()
for forced_env in [
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
    "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL",
    "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY",
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE",
    "CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT",
    "CLAUDE_CODE_ATTRIBUTION_HEADER",
    "DISABLE_AUTOUPDATER",
    "DISABLE_ERROR_REPORTING",
    "DISABLE_TELEMETRY",
]:
    assert f"export {forced_env}=" not in launcher

assert Path("LICENSE").read_text().startswith("MIT License\n")
assert "Copyright (c) 2026 Aleksandr Lisenko" in Path("LICENSE").read_text()
assert "Ratatui" not in Path("NOTICE").read_text()
PY

"$repo_dir/bin/claude-kiss" --help | grep -q 'system-prompt'
python3 "$repo_dir/evals/run_evals.py" --dry-run \
  --tasks concise_answer --output-dir "$temporary/eval-dry-run" >/dev/null

python3 - "$repo_dir" <<'PY'
import importlib.util
import tempfile
from pathlib import Path

repo = Path(__import__("sys").argv[1])
spec = importlib.util.spec_from_file_location("claude_kiss_evals", repo / "evals" / "run_evals.py")
evals = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(evals)

assert list(evals.TASKS) == [
    "concise_answer",
    "minimal_bugfix",
    "scope_discipline",
    "no_lazy_workaround",
    "targeted_regression_test",
    "cross_file_bugfix",
    "review_no_edit",
    "long_horizon_handoff",
]


def check_expected(name, mutate, result="done"):
    task = evals.TASKS[name]
    with tempfile.TemporaryDirectory() as temporary:
        fixture = Path(temporary) / "fixture"
        evals.write_fixture(fixture, task)
        before = evals.snapshot(fixture)
        mutate(fixture)
        after = evals.snapshot(fixture)
        record = {
            "result": result,
            **evals.file_delta(before, after),
            "post_tests": evals.run_post_tests(fixture, name),
            "file_contents": {
                path: content.decode("utf-8", errors="replace")
                for path, content in after.items()
            },
        }
        checks = {key: bool(check(record)) for key, check in task["checks"].items()}
        assert all(checks.values()), (name, checks)


def targeted_regression(fixture):
    (fixture / "temperature.py").write_text(
        "def celsius_to_fahrenheit(celsius):\n"
        "    return celsius * 9 / 5 + 32\n",
        encoding="utf-8",
    )
    (fixture / "test_temperature.py").write_text(
        "from temperature import celsius_to_fahrenheit\n"
        "\n"
        "assert celsius_to_fahrenheit(0) == 32\n",
        encoding="utf-8",
    )


def cross_file_bugfix(fixture):
    (fixture / "receipt.py").write_text(
        "from pricing import total_cents\n"
        "\n"
        "\n"
        "def render_receipt(items):\n"
        '    return f"Total: ${total_cents(items) / 100:.2f}"\n',
        encoding="utf-8",
    )


def long_horizon_handoff(fixture):
    (fixture / "pipeline.py").write_text(
        "def decode(value):\n"
        '    return value.split(",")\n'
        "\n"
        "\n"
        "def normalize(parts):\n"
        '    return [part.strip().lower() for part in parts]\n'
        "\n"
        "\n"
        "def encode(parts):\n"
        '    return ";".join(parts)\n'
        "\n"
        "\n"
        "def convert(value):\n"
        "    return encode(normalize(decode(value)))\n",
        encoding="utf-8",
    )


check_expected("targeted_regression_test", targeted_regression)
check_expected("cross_file_bugfix", cross_file_bugfix)
check_expected("review_no_edit", lambda fixture: None, "Use left - right, not left + right.")
check_expected("long_horizon_handoff", long_horizon_handoff)
PY

mkdir -p "$temporary/prefix/bin"

user_config="$temporary/user-config"
user_memory="$user_config/memory"
CLAUDE_KISS_CONFIG_HOME="$user_config" CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" init >"$temporary/init.txt"
[ -f "$user_config/prompt.md" ]
[ -f "$user_config/settings.json" ]
[ -f "$user_config/memory/CLAUDE.md" ]
printf 'owned prompt\n' >"$user_config/prompt.md"
CLAUDE_KISS_CONFIG_HOME="$user_config" CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" init >"$temporary/init-again.txt"
grep -q '^exists:' "$temporary/init-again.txt"
grep -q '^owned prompt$' "$user_config/prompt.md"
user_memory=$(CDPATH= cd -- "$user_memory" && pwd -P)

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/user-dry-run.txt"
grep -F -- "$user_config/prompt.md" "$temporary/user-dry-run.txt" >/dev/null
grep -F -- "$user_config/settings.json" "$temporary/user-dry-run.txt" >/dev/null
grep -F -- "$user_memory" "$temporary/user-dry-run.txt" >/dev/null
if grep -q -- 'Read(//' "$temporary/user-dry-run.txt"; then
  printf 'error: compact memory tool pattern contains a double slash\n' >&2
  exit 1
fi

CLAUDE_KISS_CONFIG_HOME="$user_config" CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" doctor >"$temporary/user-doctor.txt"
grep -q '^prompt source: user$' "$temporary/user-doctor.txt"
grep -q '^settings source: user$' "$temporary/user-doctor.txt"
grep -q '^compact memory source: user$' "$temporary/user-doctor.txt"
grep -q '^subagents: unavailable$' "$temporary/user-doctor.txt"
grep -q '^web search: unavailable$' "$temporary/user-doctor.txt"
grep -q '^web fetch: unavailable$' "$temporary/user-doctor.txt"
grep -q '^mcp: strict (no discovery)$' "$temporary/user-doctor.txt"
grep -q '^chrome: disabled$' "$temporary/user-doctor.txt"
grep -q '^skills and slash commands: enabled$' "$temporary/user-doctor.txt"

CLAUDE_KISS_TOOLS=default CLAUDE_KISS_MCP=1 CLAUDE_KISS_CHROME=1 \
  CLAUDE_KISS_DISABLE_COMMANDS=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" doctor \
  >"$temporary/opt-in-doctor.txt"
grep -q '^subagents: available$' "$temporary/opt-in-doctor.txt"
grep -q '^web search: available$' "$temporary/opt-in-doctor.txt"
grep -q '^mcp: normal discovery$' "$temporary/opt-in-doctor.txt"
grep -q '^chrome: enabled$' "$temporary/opt-in-doctor.txt"
grep -q '^skills and slash commands: disabled$' "$temporary/opt-in-doctor.txt"

environment_prompt="$temporary/environment-prompt.md"
cp "$user_config/prompt.md" "$environment_prompt"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_PROMPT="$environment_prompt" \
  "$repo_dir/bin/claude-kiss" >"$temporary/environment-dry-run.txt"
grep -F -- "$environment_prompt" "$temporary/environment-dry-run.txt" >/dev/null

installer_config="$temporary/installer-config"
mkdir -p "$installer_config"
printf 'preserve me\n' >"$installer_config/prompt.md"

: >"$temporary/prefix/bin/claude-kiss-profile"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --no-path-check >/dev/null
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --no-path-check >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
CLAUDE_KISS_CONFIG_HOME="$installer_config" "$temporary/prefix/bin/claude-kiss" doctor

"$repo_dir/build-release.sh" >"$temporary/release-build.txt"
[ -f "$generated_release/claude-kiss.tar.gz" ]
[ -f "$generated_release/claude-kiss.tar.gz.sha256" ]
[ -f "$generated_release/release.json" ]
tar -tzf "$generated_release/claude-kiss.tar.gz" | grep -q '^claude-kiss/bin/claude-kiss$'
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  CLAUDE_KISS_ARCHIVE="file://$generated_release/claude-kiss.tar.gz" \
  "$repo_dir/install.sh" --prefix "$temporary/release-prefix" --no-path-check >/dev/null
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$temporary/release-prefix/bin/claude-kiss" doctor >/dev/null

CLAUDE_KISS_DRY_RUN=1 "$temporary/prefix/bin/claude-kiss" test |
  grep -q -- '--system-prompt-file'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" hello >"$temporary/dry-run.txt"
grep -q '\[--setting-sources\] \[user\]' "$temporary/dry-run.txt"
grep -q '\[--permission-mode\] \[default\]' "$temporary/dry-run.txt"
grep -q -- '--strict-mcp-config' "$temporary/dry-run.txt"
grep -q -- '--no-chrome' "$temporary/dry-run.txt"
grep -q 'Bash,Glob,Grep,Read,Edit,Write' "$temporary/dry-run.txt"
grep -q -- '--add-dir' "$temporary/dry-run.txt"
grep -q -- '--disallowedTools' "$temporary/dry-run.txt"
grep -q '^compaction: kiss$' "$temporary/dry-run.txt"
grep -q '^DISABLE_AUTO_COMPACT=0$' "$temporary/dry-run.txt"
grep -q '^DISABLE_COMPACT=0$' "$temporary/dry-run.txt"

CLAUDE_KISS_DRY_RUN=1 "$repo_dir/bin/claude-kiss" --dangerously-skip-permissions \
  >"$temporary/bypass-dry-run.txt"
grep -q -- '--dangerously-skip-permissions' "$temporary/bypass-dry-run.txt"
if grep -q -- '--permission-mode' "$temporary/bypass-dry-run.txt"; then
  printf 'fail: bypass flag must suppress the default permission mode\n' >&2
  exit 1
fi

CLAUDE_KISS_DRY_RUN=1 "$repo_dir/bin/claude-kiss" --permission-mode acceptEdits \
  >"$temporary/mode-dry-run.txt"
grep -q '\[--permission-mode\] \[acceptEdits\]' "$temporary/mode-dry-run.txt"
if grep -q '\[default\]' "$temporary/mode-dry-run.txt"; then
  printf 'fail: explicit permission mode must not be overridden\n' >&2
  exit 1
fi
if grep -q -- '--disable-slash-commands' "$temporary/dry-run.txt"; then
  printf 'error: slash commands must remain enabled by default for /model\n' >&2
  exit 1
fi

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CHROME=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/chrome-enabled.txt"
if grep -q -- '--no-chrome' "$temporary/chrome-enabled.txt"; then
  printf 'error: CLAUDE_KISS_CHROME=1 must not disable the Chrome integration\n' >&2
  exit 1
fi

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --chrome >"$temporary/chrome-direct.txt"
if grep -q -- '--no-chrome' "$temporary/chrome-direct.txt"; then
  printf 'error: a direct --chrome argument must win over the KISS default\n' >&2
  exit 1
fi

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_DISABLE_COMMANDS=1 \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/commands-disabled.txt"
grep -q -- '--disable-slash-commands' "$temporary/commands-disabled.txt"

direct_tools='Bash,Glob,Grep,Read,Edit,Write,LSP,Agent,TaskStop,WebFetch,WebSearch,ToolSearch'
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_TOOLS="$direct_tools" "$repo_dir/bin/claude-kiss" \
  >"$temporary/direct-tools.txt"
grep -q "\[--tools\] \[$direct_tools\]" "$temporary/direct-tools.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_TOOLS=default "$repo_dir/bin/claude-kiss" \
  >"$temporary/default-tools.txt"
grep -q '\[--tools\] \[default\]' "$temporary/default-tools.txt"

for profile in plain early manual off; do
  CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT="$profile" \
    CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
    >"$temporary/$profile.txt"
done
if grep -q -- '--add-dir' "$temporary/plain.txt"; then
  printf 'error: plain compaction must not load KISS compact memory\n' >&2
  exit 1
fi
if grep -q -- '--autocompact' "$temporary/plain.txt"; then
  printf 'error: plain compaction must use the model default window\n' >&2
  exit 1
fi
grep -q '^DISABLE_AUTO_COMPACT=1$' "$temporary/manual.txt"
grep -q '^DISABLE_COMPACT=0$' "$temporary/manual.txt"
grep -q -- '--add-dir' "$temporary/manual.txt"
grep -q '^DISABLE_AUTO_COMPACT=1$' "$temporary/off.txt"
grep -q '^DISABLE_COMPACT=1$' "$temporary/off.txt"
if grep -q -- '--add-dir' "$temporary/off.txt"; then
  printf 'error: disabled compaction must not load compact memory\n' >&2
  exit 1
fi

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT=early CLAUDE_KISS_AUTOCOMPACT=400k \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/early.txt"
grep -q '\[--autocompact\] \[400k\]' "$temporary/early.txt"

if CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT=wrong CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >/dev/null 2>&1; then
  printf 'error: invalid compaction profile must fail\n' >&2
  exit 1
fi

CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --uninstall >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss" ]
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
[ ! -e "$temporary/prefix/share/claude-kiss" ]
grep -q '^preserve me$' "$installer_config/prompt.md"

printf 'All Claude KISS tests passed.\n'
