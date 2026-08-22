#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-test.XXXXXX")
version=$(cat "$repo_dir/VERSION")
generated_release="$repo_dir/dist"
trap 'rm -rf "$temporary" "$generated_release"' EXIT HUP INT TERM

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
refute "$temporary/bypass-dry-run.txt" '--permission-mode' \
  'bypass flag must suppress the default permission mode'

CLAUDE_KISS_DRY_RUN=1 "$repo_dir/bin/claude-kiss" --permission-mode acceptEdits \
  >"$temporary/mode-dry-run.txt"
grep -q '\[--permission-mode\] \[acceptEdits\]' "$temporary/mode-dry-run.txt"
refute "$temporary/mode-dry-run.txt" '\[default\]' \
  'explicit permission mode must not be overridden'
refute "$temporary/dry-run.txt" '--disable-slash-commands' \
  'slash commands must remain enabled by default for /model'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CHROME=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/chrome-enabled.txt"
refute "$temporary/chrome-enabled.txt" '--no-chrome' \
  'CLAUDE_KISS_CHROME=1 must not disable the Chrome integration'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --chrome >"$temporary/chrome-direct.txt"
refute "$temporary/chrome-direct.txt" '--no-chrome' \
  'a direct --chrome argument must win over the KISS default'

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
refute "$temporary/plain.txt" '--add-dir' \
  'plain compaction must not load KISS compact memory'
refute "$temporary/plain.txt" '--autocompact' \
  'plain compaction must use the model default window'
grep -q '^DISABLE_AUTO_COMPACT=1$' "$temporary/manual.txt"
grep -q '^DISABLE_COMPACT=0$' "$temporary/manual.txt"
grep -q -- '--add-dir' "$temporary/manual.txt"
grep -q '^DISABLE_AUTO_COMPACT=1$' "$temporary/off.txt"
grep -q '^DISABLE_COMPACT=1$' "$temporary/off.txt"
refute "$temporary/off.txt" '--add-dir' \
  'disabled compaction must not load compact memory'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT=early CLAUDE_KISS_AUTOCOMPACT=400k \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/early.txt"
grep -q '\[--autocompact\] \[400k\]' "$temporary/early.txt"

if CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_COMPACT=wrong CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >/dev/null 2>&1; then
  printf 'error: invalid compaction profile must fail\n' >&2
  exit 1
fi

# A direct Claude argument must suppress the matching KISS default.
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --tools Read >"$temporary/direct-tools.txt"
argv_of "$temporary/direct-tools.txt" >"$temporary/direct-tools.cmd"
grep -q '\[--tools\] \[Read\]' "$temporary/direct-tools.cmd"
refute "$temporary/direct-tools.cmd" 'Bash,Glob,Grep,Read,Edit,Write' \
  'a direct --tools argument must not be paired with the KISS default list'

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

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" --mcp-config ./mcp.json >"$temporary/direct-mcp.txt"
grep -q -- '--strict-mcp-config' "$temporary/direct-mcp.txt"
refute "$temporary/direct-mcp.txt" 'mcpServers' \
  'a direct --mcp-config argument must not be paired with the empty KISS config'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_MCP=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/mcp-enabled.txt"
refute "$temporary/mcp-enabled.txt" 'strict-mcp-config' \
  'CLAUDE_KISS_MCP=1 must restore normal MCP discovery'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_SETTING_SOURCES=user,project \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" \
  >"$temporary/setting-sources.txt"
grep -q '\[--setting-sources\] \[user,project\]' "$temporary/setting-sources.txt"

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_CLAUDE_MD=0 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" >"$temporary/no-claude-md.txt"
grep -q '^compact memory: disabled$' "$temporary/no-claude-md.txt"
refute "$temporary/no-claude-md.txt" '--add-dir' \
  'CLAUDE_KISS_CLAUDE_MD=0 must not load compact memory'

isolated_config="$temporary/isolated-config"
CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_ISOLATED=1 CLAUDE_KISS_CONFIG_DIR="$isolated_config" \
  CLAUDE_KISS_HOME="$repo_dir" "$repo_dir/bin/claude-kiss" >/dev/null
[ -d "$isolated_config" ]

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
[ ! -e "$temporary/unsafe" ]

"$repo_dir/install.sh" --prefix "$temporary/empty-prefix" \
  --data-dir "$temporary/empty-data" --uninstall >"$temporary/uninstall-empty.txt"
grep -q 'No claude-kiss installation found' "$temporary/uninstall-empty.txt"

python3 - "$repo_dir" "$generated_release" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

repo, release = Path(sys.argv[1]), Path(sys.argv[2])
meta = json.loads((release / "release.json").read_text())
archive = (release / "claude-kiss.tar.gz").read_bytes()
assert meta["version"] == (repo / "VERSION").read_text().strip()
assert meta["sha256"] == hashlib.sha256(archive).hexdigest()
assert meta["sha256"] == (release / "claude-kiss.tar.gz.sha256").read_text().strip()
assert meta["archive"].endswith(f"v{meta['version']}/claude-kiss.tar.gz")
PY

CLAUDE_KISS_CONFIG_HOME="$installer_config" \
  "$repo_dir/install.sh" --prefix "$temporary/prefix" --uninstall >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss" ]
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
[ ! -e "$temporary/prefix/share/claude-kiss" ]
grep -q '^preserve me$' "$installer_config/prompt.md"

printf 'All Claude KISS tests passed.\n'
