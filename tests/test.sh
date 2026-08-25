#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-test.XXXXXX")
version=$(cat "$repo_dir/VERSION")
generated_release="$temporary/release"
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

expect_status() {
  expected_status=$1
  shift
  actual_status=0
  "$@" >/dev/null 2>&1 || actual_status=$?
  [ "$actual_status" -eq "$expected_status" ] || {
    printf 'error: expected exit %s, got %s: %s\n' \
      "$expected_status" "$actual_status" "$*" >&2
    exit 1
  }
}

# A dry run prints the argv on its first line and resolution details after it.
argv_of() {
  head -n 1 "$1"
}

refute() {
  if grep -q -- "$2" "$1"; then
    printf 'error: %s\n' "$3" >&2
    exit 1
  fi
}

grep -q "version=\"$version\"" "$repo_dir/bin/claude-kiss"
grep -Fqx '# Managed by Claude KISS install.sh.' "$repo_dir/bin/claude-kiss"
grep -q "release_version=\${CLAUDE_KISS_VERSION:-$version}" "$repo_dir/install.sh"
grep -q 'https://claude-kiss.com/install.sh' "$repo_dir/README.md"
grep -q 'https://github.com/aphoristicartist/claude-kiss' "$repo_dir/install.sh"
# shellcheck disable=SC2016  # The literal shell variable name is the thing being matched.
grep -q 'https://claude-kiss.com/releases/v$release_version/claude-kiss.tar.gz' \
  "$repo_dir/install.sh"
grep -q 'source.sha256' "$repo_dir/install.sh"
[ ! -e "$repo_dir/bin/claude-kiss-profile" ]

python3 - <<'PY'
import json
from pathlib import Path

settings = json.loads(Path("config/settings.json").read_text())
experiment_settings = json.loads(Path("config/prog-python-settings.json").read_text())
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
# Compaction timing stays the user's choice: no managed override of the vendor default.
assert "autoCompactEnabled" not in settings
assert settings["includeGitInstructions"] is False
for key, value in settings.items():
    assert experiment_settings[key] == value, key
assert experiment_settings["permissions"] == {
    "defaultMode": "dontAsk",
    "disableAutoMode": "disable",
    "disableBypassPermissionsMode": "disable",
    "allow": ["Bash(prog *)", "Bash(python3 *)"],
}
hook = experiment_settings["hooks"]["PreToolUse"]
assert hook[0]["matcher"] == "Bash"
assert hook[0]["hooks"][0]["command"] == '"$CLAUDE_KISS_PROG_PYTHON_GUARD"'
# Prompt and compact-memory behavior is protected by evals/run_evals.py.
# Asserting exact sentences here would freeze wording instead of outcomes.
assert Path("prompt/claude-kiss.md").read_text().strip()
assert Path("prompt/prog-python.md").read_text().strip()
assert Path("memory/CLAUDE.md").read_text().strip()

guard = Path("bin/prog-python-guard")
assert guard.stat().st_mode & 0o111


def guard_result(command):
    import subprocess

    completed = subprocess.run(
        [str(guard.resolve())],
        input=json.dumps({"tool_input": {"command": command}}),
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout


for allowed in [
    "prog",
    "prog run -- cargo test --workspace",
    "python3 -c 'from pathlib import Path; print(Path.cwd())'",
]:
    assert guard_result(allowed) == "", allowed

for denied in [
    "ls -la",
    "prog run -- cargo test && git status",
    "python3 -c 'print(1)' | cat",
    "python3 -c 'print(1)' <<< value",
    "python3 -c 'print(1)'\nrm file",
    "python3 -c 'print($(pwd))'",
]:
    decision = json.loads(guard_result(denied))
    output = decision["hookSpecificOutput"]
    assert output["hookEventName"] == "PreToolUse"
    assert output["permissionDecision"] == "deny"
    assert output["permissionDecisionReason"], denied

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
python3 "$repo_dir/evals/run_evals.py" --dry-run --include-prog-python \
  --tasks concise_answer --output-dir "$temporary/prog-python-eval-dry-run" >/dev/null
python3 - "$temporary/prog-python-eval-dry-run/summary.json" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
assert list(summary["summaries"]) == ["kiss", "prog-python", "regular"]
records = {record["runner"]: record for record in summary["records"]}
assert records["prog-python"]["environment"] == {
    "CLAUDE_KISS_EXPERIMENT": "prog-python"
}
assert "--permission-mode" not in records["prog-python"]["command"]
assert "--permission-mode" in records["regular"]["command"]
assert "--permission-mode" in records["kiss"]["command"]
PY

python3 - "$repo_dir" <<'PY'
import importlib.util
import tempfile
from pathlib import Path
from types import SimpleNamespace

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

report_records = [
    {
        "runner": runner,
        "task": "concise_answer",
        "passed": True,
        "checks": {"answer": True},
        "result_words": 1,
        "result_chars": 4,
        "output_tokens": 2,
        "cost_usd": 0.01,
        "wall_seconds": 1.0,
        "changed_files": [],
        "models": ["test-model"],
        "num_turns": 1,
    }
    for runner in evals.RUNNER_LABELS
]
report_summaries = {
    runner: evals.aggregate(
        [record for record in report_records if record["runner"] == runner]
    )
    for runner in evals.RUNNER_LABELS
}
with tempfile.TemporaryDirectory() as report_directory:
    report_path = Path(report_directory) / "RESULTS.md"
    evals.write_report(
        SimpleNamespace(report=str(report_path)), report_records, report_summaries
    )
    report = report_path.read_text()
assert "| Metric | Regular Claude | Claude KISS | Prog + Python |" in report
assert "| Mean agent turns | +0.0% | +0.0% |" in report
assert "| Prog + Python | test-model |" in report


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
user_memory=$(CDPATH='' cd -- "$user_memory" && pwd -P)

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/user-dry-run.txt"
grep -F -- "$user_config/prompt.md" "$temporary/user-dry-run.txt" >/dev/null
grep -F -- "$user_config/settings.json" "$temporary/user-dry-run.txt" >/dev/null
grep -F -- "$user_memory" "$temporary/user-dry-run.txt" >/dev/null
refute "$temporary/user-dry-run.txt" 'Read(//' \
  'compact memory tool pattern contains a double slash'

CLAUDE_KISS_CONFIG_HOME="$user_config" CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" doctor >"$temporary/user-doctor.txt"
grep -q '^prompt source: user$' "$temporary/user-doctor.txt"
grep -q '^settings source: user$' "$temporary/user-doctor.txt"
grep -q '^user settings: .*/settings\.json$' "$temporary/user-doctor.txt"
grep -q '^compact memory source: user$' "$temporary/user-doctor.txt"
grep -q '^tools: Bash,Glob,Grep,Read,Edit,Write$' "$temporary/user-doctor.txt"
grep -q '^web: disabled$' "$temporary/user-doctor.txt"
grep -q '^skills: disabled$' "$temporary/user-doctor.txt"
grep -q '^delegation: disabled$' "$temporary/user-doctor.txt"
grep -q '^mcp: disabled$' "$temporary/user-doctor.txt"
grep -q '^slash commands: enabled$' "$temporary/user-doctor.txt"

CLAUDE_KISS_WEB=1 CLAUDE_KISS_SKILLS=1 CLAUDE_KISS_DELEGATION=1 CLAUDE_KISS_MCP=1 \
  CLAUDE_KISS_DISABLE_COMMANDS=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" doctor \
  >"$temporary/opt-in-doctor.txt"
grep -q '^web: enabled$' "$temporary/opt-in-doctor.txt"
grep -q '^skills: enabled$' "$temporary/opt-in-doctor.txt"
grep -q '^delegation: enabled$' "$temporary/opt-in-doctor.txt"
grep -q '^mcp: enabled$' "$temporary/opt-in-doctor.txt"
grep -q '^slash commands: disabled$' "$temporary/opt-in-doctor.txt"

environment_prompt="$temporary/environment-prompt.md"
cp "$user_config/prompt.md" "$environment_prompt"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CONFIG_HOME="$user_config" \
  CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_PROMPT="$environment_prompt" \
  "$repo_dir/bin/claude-kiss" >"$temporary/environment-dry-run.txt"
grep -F -- "$environment_prompt" "$temporary/environment-dry-run.txt" >/dev/null

installer_config="$temporary/installer-config"
mkdir -p "$installer_config"
printf 'preserve me\n' >"$installer_config/prompt.md"

cat >"$temporary/prefix/bin/claude-kiss-profile" <<'PROFILE'
#!/bin/sh
# claude-kiss-profile — named Claude KISS tool profiles
profiles_dir=${CLAUDE_KISS_PROFILES_DIR:-unused}
PROFILE
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --no-path-check >/dev/null
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --no-path-check >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
[ -f "$temporary/prefix/share/claude-kiss/.claude-kiss-managed" ]
CLAUDE_KISS_CONFIG_HOME="$installer_config" "$temporary/prefix/bin/claude-kiss" doctor

# Custom install paths are embedded as data, never executable shell source. Exercise the
# characters that are meaningful to both shell quoting and sed replacement expressions.
special_prefix="$temporary/prefix with 'quotes' & pipes|semi; dollar\$"
special_data="$temporary/data with 'quotes' & pipes|semi; dollar\$"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$special_prefix" --data-dir "$special_data" \
  --no-path-check >/dev/null
[ -f "$special_data/.claude-kiss-managed" ]
special_data_real=$(CDPATH='' cd -- "$special_data" && pwd -P)
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$special_prefix/bin/claude-kiss" doctor >"$temporary/special-path-doctor.txt"
grep -F -q "home: $special_data_real" "$temporary/special-path-doctor.txt"

# Uninstall removes only files owned by the installer, even inside a custom directory.
touch "$special_data/keep.txt"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$special_prefix" --data-dir "$special_data" \
  --uninstall >"$temporary/special-path-uninstall.txt"
[ ! -e "$special_prefix/bin/claude-kiss" ]
[ ! -e "$special_data/.claude-kiss-managed" ]
[ ! -e "$special_data/prompt/claude-kiss.md" ]
[ -f "$special_data/keep.txt" ]
grep -q 'Preserved non-Claude-KISS files' "$temporary/special-path-uninstall.txt"

# A current launcher installed with custom assets must not make an unmarked default data
# path look like a legacy installation when --data-dir is accidentally omitted.
mismatch_prefix="$temporary/mismatch-prefix"
mismatch_data="$temporary/mismatch-data"
mismatch_default="$mismatch_prefix/share/claude-kiss"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$mismatch_prefix" --data-dir "$mismatch_data" \
  --no-path-check >/dev/null
mkdir -p "$mismatch_default/prompt"
printf 'unrelated\n' >"$mismatch_default/prompt/claude-kiss.md"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$mismatch_prefix" --uninstall \
  >"$temporary/mismatch-uninstall.txt"
[ -f "$mismatch_default/prompt/claude-kiss.md" ]
[ -f "$mismatch_data/.claude-kiss-managed" ]
grep -q 'Preserved unmarked data directory' "$temporary/mismatch-uninstall.txt"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$mismatch_prefix" --data-dir "$mismatch_data" \
  --uninstall >/dev/null

# Installer option meaning is independent of ordering, and an explicit CLI data path
# overrides DATA_DIR from the environment.
ordered_prefix="$temporary/ordered-prefix"
ordered_data="$temporary/ordered-data"
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --data-dir "$ordered_data" --prefix "$ordered_prefix" \
  --no-path-check >/dev/null
[ -f "$ordered_data/.claude-kiss-managed" ]
[ ! -e "$ordered_prefix/share/claude-kiss" ]
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --data-dir "$ordered_data" --prefix "$ordered_prefix" \
  --uninstall >/dev/null

cli_prefix="$temporary/cli-prefix"
cli_data="$temporary/cli-data"
environment_data="$temporary/environment-data"
DATA_DIR="$environment_data" CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$cli_prefix" --data-dir "$cli_data" \
  --no-path-check >/dev/null
[ -f "$cli_data/.claude-kiss-managed" ]
[ ! -e "$environment_data" ]
DATA_DIR="$environment_data" CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$cli_prefix" --data-dir "$cli_data" \
  --uninstall >/dev/null

OUTPUT_DIR="$generated_release" "$repo_dir/build-release.sh" >"$temporary/release-build.txt"
[ -f "$generated_release/claude-kiss.tar.gz" ]
[ -f "$generated_release/claude-kiss.tar.gz.sha256" ]
[ -f "$generated_release/release.json" ]
tar -tzf "$generated_release/claude-kiss.tar.gz" | grep -q '^claude-kiss/bin/claude-kiss$'
tar -tzf "$generated_release/claude-kiss.tar.gz" | \
  grep -q '^claude-kiss/bin/prog-python-guard$'
first_release_checksum=$(cat "$generated_release/claude-kiss.tar.gz.sha256")
OUTPUT_DIR="$generated_release" "$repo_dir/build-release.sh" \
  >"$temporary/release-build-again.txt"
[ "$(cat "$generated_release/claude-kiss.tar.gz.sha256")" = "$first_release_checksum" ]
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  CLAUDE_KISS_ARCHIVE="file://$generated_release/claude-kiss.tar.gz" \
  "$repo_dir/install.sh" --prefix "$temporary/release-prefix" --no-path-check >/dev/null
CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$temporary/release-prefix/bin/claude-kiss" doctor >/dev/null
[ -x "$temporary/release-prefix/share/claude-kiss/bin/prog-python-guard" ]
[ -f "$temporary/release-prefix/share/claude-kiss/prompt/prog-python.md" ]
[ -f "$temporary/release-prefix/share/claude-kiss/config/prog-python-settings.json" ]

CLAUDE_KISS_DRY_RUN=1 "$temporary/prefix/bin/claude-kiss" test |
  grep -q -- '--system-prompt-file'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" hello >"$temporary/dry-run.txt"
grep -q '\[--setting-sources\] \[user,project,local\]' "$temporary/dry-run.txt"
grep -q '\[--permission-mode\] \[default\]' "$temporary/dry-run.txt"
grep -q -- '--strict-mcp-config' "$temporary/dry-run.txt"
grep -q -- '--no-chrome' "$temporary/dry-run.txt"
grep -q 'Bash,Glob,Grep,Read,Edit,Write' "$temporary/dry-run.txt"
grep -q -- '--add-dir' "$temporary/dry-run.txt"
grep -q -- '--disallowedTools' "$temporary/dry-run.txt"
refute "$temporary/dry-run.txt" '--autocompact' \
  'compaction timing must stay with Claude unless the user passes --autocompact'

# The prog + Python treatment keeps one Claude tool and two executable entry points.
profile_path="$temporary/profile-path"
mkdir -p "$profile_path"
printf '#!/bin/sh\nexit 0\n' >"$profile_path/prog"
chmod +x "$profile_path/prog"
PATH="$profile_path:$PATH" CLAUDE_KISS_DRY_RUN=1 \
  CLAUDE_KISS_EXPERIMENT=prog-python CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" hello >"$temporary/prog-python.txt"
grep -q '^experiment: prog-python$' "$temporary/prog-python.txt"
grep -q '\[--tools\] \[Bash\]' "$temporary/prog-python.txt"
grep -q '\[--permission-mode\] \[dontAsk\]' "$temporary/prog-python.txt"
grep -q '\[--setting-sources\] \[\]' "$temporary/prog-python.txt"
grep -q -- '--disable-slash-commands' "$temporary/prog-python.txt"
grep -q -- '--strict-mcp-config' "$temporary/prog-python.txt"
grep -q 'mcpServers' "$temporary/prog-python.txt"
grep -F -q "$repo_dir/prompt/prog-python.md" "$temporary/prog-python.txt"
grep -F -q "$repo_dir/config/prog-python-settings.json" "$temporary/prog-python.txt"
refute "$temporary/prog-python.txt" 'Glob,Grep,Read,Edit,Write' \
  'prog-python must not expose the normal file tools'
refute "$temporary/prog-python.txt" 'ToolSearch' \
  'prog-python must not expose MCP discovery'

PATH="$profile_path:$PATH" CLAUDE_KISS_EXPERIMENT=prog-python \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" doctor \
  >"$temporary/prog-python-doctor.txt"
grep -q '^experiment: prog-python$' "$temporary/prog-python-doctor.txt"
grep -q '^tools: Bash$' "$temporary/prog-python-doctor.txt"
grep -q '^setting sources: $' "$temporary/prog-python-doctor.txt"
grep -q '^slash commands: disabled$' "$temporary/prog-python-doctor.txt"
grep -q '^permission mode: dontAsk$' "$temporary/prog-python-doctor.txt"
grep -F -q "command guard: $repo_dir/bin/prog-python-guard" \
  "$temporary/prog-python-doctor.txt"

for conflicting_capability in CLAUDE_KISS_WEB CLAUDE_KISS_SKILLS \
  CLAUDE_KISS_DELEGATION CLAUDE_KISS_MCP; do
  expect_status 2 env PATH="$profile_path:$PATH" CLAUDE_KISS_HOME="$repo_dir" \
    CLAUDE_KISS_EXPERIMENT=prog-python "$conflicting_capability=1" \
    "$repo_dir/bin/claude-kiss"
done
expect_status 2 env PATH="$profile_path:$PATH" CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_EXPERIMENT=prog-python "$repo_dir/bin/claude-kiss" \
  --mcp-config ./mcp.json
expect_status 2 env PATH="$profile_path:$PATH" CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_EXPERIMENT=prog-python "$repo_dir/bin/claude-kiss" \
  --settings "$repo_dir/config/settings.json"
expect_status 2 env PATH="$profile_path:$PATH" CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_EXPERIMENT=prog-python "$repo_dir/bin/claude-kiss" \
  --plugin-dir ./plugin
expect_status 2 env CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_EXPERIMENT=unknown \
  "$repo_dir/bin/claude-kiss"

CLAUDE_KISS_DRY_RUN=1 "$repo_dir/bin/claude-kiss" --dangerously-skip-permissions \
  >"$temporary/bypass-dry-run.txt"
grep -q -- '--dangerously-skip-permissions' "$temporary/bypass-dry-run.txt"
refute "$temporary/bypass-dry-run.txt" '--permission-mode' \
  'bypass flag must suppress the default permission mode'

CLAUDE_KISS_DRY_RUN=1 "$repo_dir/bin/claude-kiss" --permission-mode acceptEdits \
  >"$temporary/mode-dry-run.txt"
grep -q '\[--permission-mode\] \[acceptEdits\]' "$temporary/mode-dry-run.txt"
refute "$temporary/mode-dry-run.txt" '\[default\]' \
  'explicit permission mode must not be overridden'
refute "$temporary/dry-run.txt" '--disable-slash-commands' \
  'slash commands must remain enabled by default for /model'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_DISABLE_COMMANDS=1 \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/commands-disabled.txt"
grep -q -- '--disable-slash-commands' "$temporary/commands-disabled.txt"

# The capability surface is the product. Each switch adds exactly its own tools.
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_WEB=1 \
  "$repo_dir/bin/claude-kiss" >"$temporary/web.txt"
grep -q '\[--tools\] \[Bash,Glob,Grep,Read,Edit,Write,WebFetch,WebSearch\]' "$temporary/web.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_DELEGATION=1 \
  "$repo_dir/bin/claude-kiss" >"$temporary/delegation.txt"
grep -q '\[--tools\] \[Bash,Glob,Grep,Read,Edit,Write,Agent\]' "$temporary/delegation.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_SKILLS=1 \
  "$repo_dir/bin/claude-kiss" >"$temporary/skills.txt"
grep -q '\[--tools\] \[Bash,Glob,Grep,Read,Edit,Write,Skill\]' "$temporary/skills.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_MCP=1 \
  "$repo_dir/bin/claude-kiss" >"$temporary/mcp-tools.txt"
# ToolSearch must ship with MCP: tool search is on by default, so without it a session
# can see a server's deferred tool names but cannot load them. ReadMcpResourceDirTool must
# ship with it too, or a listed directory resource can never be expanded.
grep -q 'ToolSearch,ListMcpResourcesTool,ReadMcpResourceTool,ReadMcpResourceDirTool,WaitForMcpServers\]' \
  "$temporary/mcp-tools.txt"
refute "$temporary/web.txt" 'ToolSearch' \
  'ToolSearch must belong to the MCP capability, not to any other switch'
refute "$temporary/web.txt" 'Mcp' \
  'the MCP resource tools must belong to the MCP capability, not to any other switch'
# A capability is only inspectable if the technical reference names what it adds.
for mcp_tool in ToolSearch ListMcpResourcesTool ReadMcpResourceTool ReadMcpResourceDirTool \
  WaitForMcpServers; do
  grep -q "\`$mcp_tool\`" "$repo_dir/REFERENCE.md" || {
    printf 'error: REFERENCE.md does not name the MCP tool %s\n' "$mcp_tool" >&2
    exit 1
  }
done

# Chrome is not one of the four, so it stays off no matter what.
grep -q -- '--no-chrome' "$temporary/web.txt"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CHROME=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/chrome-attempt.txt"
grep -q -- '--no-chrome' "$temporary/chrome-attempt.txt"

# There must be no way to widen the surface past the four capabilities.
for rejected in --tools --chrome; do
  if CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
    "$repo_dir/bin/claude-kiss" "$rejected" default >"$temporary/rejected.txt" 2>&1; then
    printf 'FAIL: %s must be rejected, not honoured\n' "$rejected" >&2
    exit 1
  fi
  grep -q 'is not accepted' "$temporary/rejected.txt"
done

# Anthropic's own skills and workflows stay off even with skills enabled.
grep -q '"disableBundledSkills": true' "$repo_dir/config/settings.json"
grep -q '"disableWorkflows": true' "$repo_dir/config/settings.json"
grep -q '"syncClaudeAiSkills": false' "$repo_dir/config/settings.json"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT_MEMORY=0 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/no-compact-memory.txt"
grep -q '^compact memory: disabled$' "$temporary/no-compact-memory.txt"
refute "$temporary/no-compact-memory.txt" '--add-dir' \
  'CLAUDE_KISS_COMPACT_MEMORY=0 must not load compact memory'

# Compaction stays native: the launcher reports the environment instead of overwriting it.
DISABLE_AUTO_COMPACT=1 DISABLE_COMPACT=1 CLAUDE_KISS_DRY_RUN=1 \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/native-compaction.txt"
grep -q '^DISABLE_AUTO_COMPACT=1$' "$temporary/native-compaction.txt"
grep -q '^DISABLE_COMPACT=1$' "$temporary/native-compaction.txt"
grep -q -- '--add-dir' "$temporary/native-compaction.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --autocompact 400k >"$temporary/autocompact.txt"
grep -q '\[--autocompact\] \[400k\]' "$temporary/autocompact.txt"

# A direct Claude argument must suppress the matching KISS default, except for the
# capability arguments, which are rejected rather than honoured.
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --settings "$repo_dir/config/settings.json" \
  >"$temporary/direct-settings.txt"
argv_of "$temporary/direct-settings.txt" >"$temporary/direct-settings.cmd"
[ "$(grep -c -- '\[--settings\]' "$temporary/direct-settings.cmd")" -eq 1 ]

direct_prompt="$temporary/direct-prompt.md"
printf 'direct prompt\n' >"$direct_prompt"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --system-prompt-file "$direct_prompt" \
  >"$temporary/direct-prompt.txt"
argv_of "$temporary/direct-prompt.txt" >"$temporary/direct-prompt.cmd"
grep -F -q -- "$direct_prompt" "$temporary/direct-prompt.cmd"
refute "$temporary/direct-prompt.cmd" 'prompt/claude-kiss.md' \
  'a direct --system-prompt-file argument must not be paired with the managed prompt'

direct_settings="$temporary/direct-settings.json"
printf '{}\n' >"$direct_settings"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --settings "$direct_settings" \
  >"$temporary/direct-settings.txt"
argv_of "$temporary/direct-settings.txt" >"$temporary/direct-settings.cmd"
grep -F -q -- "$direct_settings" "$temporary/direct-settings.cmd"
refute "$temporary/direct-settings.cmd" 'config/settings.json' \
  'a direct --settings argument must not be paired with the managed settings'

# Native option scanning stops at -- and does not reinterpret positional text as
# launcher options.
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" -p -- --settings --tools \
  >"$temporary/argument-separator.txt"
grep -q "\[--settings\] \[$repo_dir/config/settings.json\]" \
  "$temporary/argument-separator.txt"
grep -q '\[--\] \[--settings\] \[--tools\]' "$temporary/argument-separator.txt"

# Replaced environment-selected files are Claude's responsibility and are not prevalidated
# by the launcher.
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_PROMPT="$temporary/missing-environment-prompt" \
  CLAUDE_KISS_SETTINGS="$temporary/missing-environment-settings" \
  "$repo_dir/bin/claude-kiss" --system-prompt direct \
  --settings "$temporary/direct-settings-owned-by-claude" \
  >"$temporary/replaced-environment-files.txt"
grep -q '\[--system-prompt\] \[direct\]' "$temporary/replaced-environment-files.txt"
grep -q '\[--settings\] \[.*/direct-settings-owned-by-claude\]' \
  "$temporary/replaced-environment-files.txt"
argv_of "$temporary/replaced-environment-files.txt" \
  >"$temporary/replaced-environment-files.cmd"
refute "$temporary/replaced-environment-files.cmd" 'missing-environment' \
  'direct arguments must replace environment-selected prompt and settings files'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --mcp-config ./mcp.json >"$temporary/direct-mcp.txt"
grep -q -- '--strict-mcp-config' "$temporary/direct-mcp.txt"
refute "$temporary/direct-mcp.txt" 'mcpServers' \
  'a direct --mcp-config argument must not be paired with the empty KISS config'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_MCP=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/mcp-enabled.txt"
refute "$temporary/mcp-enabled.txt" 'strict-mcp-config' \
  'CLAUDE_KISS_MCP=1 must restore normal MCP discovery'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --setting-sources user,project \
  >"$temporary/setting-sources.txt"
grep -q '\[--setting-sources\] \[user,project\]' "$temporary/setting-sources.txt"
refute "$temporary/setting-sources.txt" '\[--setting-sources\] \[user,project,local\]' \
  'a direct --setting-sources argument must not be paired with the KISS default'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CLAUDE_MD=0 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/no-claude-md.txt"
grep -q '^compact memory: disabled$' "$temporary/no-claude-md.txt"
refute "$temporary/no-claude-md.txt" '--add-dir' \
  'CLAUDE_KISS_CLAUDE_MD=0 must not load compact memory'

isolated_config="$temporary/isolated-config"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_ISOLATED=1 CLAUDE_CONFIG_DIR="$isolated_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" >/dev/null
[ -d "$isolated_config" ]

# doctor must report the effective setting sources and name the user-scope settings file.
CLAUDE_CONFIG_DIR="$isolated_config" CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" doctor >"$temporary/config-dir-doctor.txt"
grep -q '^setting sources: user,project,local$' "$temporary/config-dir-doctor.txt"
grep -q "^user settings: $isolated_config/settings.json\$" \
  "$temporary/config-dir-doctor.txt"

"$repo_dir/bin/claude-kiss" --version >"$temporary/version.txt"
grep -q "^claude-kiss $version\$" "$temporary/version.txt"

# Missing capabilities must fail loudly instead of falling back silently.
expect_status 127 env CLAUDE_BIN="$temporary/no-such-claude" "$repo_dir/bin/claude-kiss"
expect_status 1 env CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_PROMPT="$temporary/missing-prompt.md" "$repo_dir/bin/claude-kiss"
expect_status 1 env CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_SETTINGS="$temporary/missing-settings.json" "$repo_dir/bin/claude-kiss"
expect_status 1 env CLAUDE_KISS_HOME="$repo_dir" \
  CLAUDE_KISS_COMPACT_MEMORY="$temporary" "$repo_dir/bin/claude-kiss"
expect_status 2 env CLAUDE_KISS_HOME="$repo_dir" CLAUDE_KISS_CONFIG_HOME="$user_config" \
  "$repo_dir/bin/claude-kiss" init extra-argument

# The wrapper must exec Claude with the composed argv, and leave auth alone.
stub_claude="$temporary/stub-claude"
cat >"$stub_claude" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" >"$STUB_LOG"
STUB
chmod +x "$stub_claude"

STUB_LOG="$temporary/stub-launch.txt" CLAUDE_BIN="$stub_claude" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" hello
grep -q -- '^--system-prompt-file$' "$temporary/stub-launch.txt"
grep -q '^hello$' "$temporary/stub-launch.txt"

STUB_LOG="$temporary/stub-auth.txt" CLAUDE_BIN="$stub_claude" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" auth login
grep -q '^auth$' "$temporary/stub-auth.txt"
grep -q '^login$' "$temporary/stub-auth.txt"
refute "$temporary/stub-auth.txt" 'system-prompt-file' \
  'auth must pass through without KISS session flags'

# Installer guardrails must reject unsafe or malformed invocations.
expect_status 2 "$repo_dir/install.sh" --prefix "$temporary/unsafe" --data-dir /
expect_status 2 env HOME="$temporary/fake-home" "$repo_dir/install.sh" \
  --prefix "$temporary/unsafe" --data-dir "$temporary/fake-home"
expect_status 2 "$repo_dir/install.sh" --unknown-option
expect_status 2 "$repo_dir/install.sh" --prefix
expect_status 2 "$repo_dir/install.sh" --prefix ''
expect_status 2 "$repo_dir/install.sh" --data-dir ''
[ ! -e "$temporary/unsafe" ]

# Reading the installer on stdin must download the requested archive even when the
# current directory itself looks like a source package.
if (
  cd "$repo_dir"
  CLAUDE_KISS_ARCHIVE="file:///definitely-missing-claude-kiss.tar.gz" \
    sh -s -- --prefix "$temporary/stdin-prefix" --data-dir "$temporary/stdin-data" \
    --no-path-check <"$repo_dir/install.sh"
) >/dev/null 2>&1; then
  printf 'error: stdin installer trusted assets from the current directory\n' >&2
  exit 1
fi
[ ! -e "$temporary/stdin-prefix" ]
[ ! -e "$temporary/stdin-data" ]

newline_cwd=$(printf '%s\n%s' "$temporary/newline-cwd" suffix)
mkdir -p "$newline_cwd"
newline_status=0
(
  cd "$newline_cwd"
  "$repo_dir/install.sh" --prefix relative-prefix --data-dir relative-data \
    --no-path-check
) >/dev/null 2>&1 || newline_status=$?
[ "$newline_status" -eq 2 ] || {
  printf 'error: expected newline-bearing cwd paths to be rejected, got %s\n' \
    "$newline_status" >&2
  exit 1
}
[ ! -e "$newline_cwd/relative-prefix" ]
[ ! -e "$newline_cwd/relative-data" ]

"$repo_dir/install.sh" --prefix "$temporary/empty-prefix" \
  --data-dir "$temporary/empty-data" --uninstall >"$temporary/uninstall-empty.txt"
grep -q 'No claude-kiss installation found' "$temporary/uninstall-empty.txt"

# Uninstall never claims or removes unrelated files that happen to use managed names.
foreign_prefix="$temporary/foreign-prefix"
foreign_data="$temporary/foreign-data"
mkdir -p "$foreign_prefix/bin" "$foreign_data"
printf '#!/bin/sh\nprintf foreign\\n\n' >"$foreign_prefix/bin/claude-kiss"
printf '#!/bin/sh\nprintf foreign-profile\\n\n' >"$foreign_prefix/bin/claude-kiss-profile"
printf 'keep\n' >"$foreign_data/keep.txt"
"$repo_dir/install.sh" --prefix "$foreign_prefix" --data-dir "$foreign_data" \
  --uninstall >"$temporary/uninstall-foreign.txt"
[ -f "$foreign_prefix/bin/claude-kiss" ]
[ -f "$foreign_prefix/bin/claude-kiss-profile" ]
[ -f "$foreign_data/keep.txt" ]
grep -q 'Preserved unrecognized launcher' "$temporary/uninstall-foreign.txt"

python3 - "$repo_dir" "$generated_release" <<'PY'
import hashlib
import json
import sys
import tarfile
from pathlib import Path

repo, release = Path(sys.argv[1]), Path(sys.argv[2])
meta = json.loads((release / "release.json").read_text())
archive = (release / "claude-kiss.tar.gz").read_bytes()
assert meta["version"] == (repo / "VERSION").read_text().strip()
assert meta["sha256"] == hashlib.sha256(archive).hexdigest()
assert meta["sha256"] == (release / "claude-kiss.tar.gz.sha256").read_text().strip()
assert meta["archive"].endswith(f"v{meta['version']}/claude-kiss.tar.gz")
expected = {
    "claude-kiss",
    *(f"claude-kiss/{directory}" for directory in ("assets", "bin", "config", "prompt", "memory", "evals", "tests")),
    *(f"claude-kiss/{path}" for path in (
        "install.sh", "LICENSE", "NOTICE", "README.md", "WHY.md", "MANIFESTO.md",
        "REFERENCE.md", "CONTRIBUTING.md", "SECURITY.md", "VERSION",
        "assets/mark.svg", "bin/claude-kiss", "bin/prog-python-guard",
        "config/settings.json", "config/prog-python-settings.json",
        "prompt/claude-kiss.md", "prompt/prog-python.md",
        "memory/CLAUDE.md", "evals/run_evals.py", "tests/test.sh",
    )),
}
with tarfile.open(release / "claude-kiss.tar.gz", "r:gz") as package:
    members = package.getmembers()
assert {member.name for member in members} == expected
assert all(member.uid == 0 and member.gid == 0 and member.mtime == 0 for member in members)
PY

CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --uninstall >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss" ]
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
[ ! -e "$temporary/prefix/share/claude-kiss" ]
grep -q '^preserve me$' "$installer_config/prompt.md"

printf 'All Claude KISS tests passed.\n'
