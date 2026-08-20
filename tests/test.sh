#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
version=$(cat "$repo_dir/VERSION")
grep -q "version=\"$version\"" "$repo_dir/bin/claude-kiss"
grep -q "release_version=\${CLAUDE_KISS_VERSION:-$version}" "$repo_dir/install.sh"
grep -q "claude-kiss/v$version/install.sh" "$repo_dir/README.md"
grep -q 'https://github.com/aphoristicartist/claude-kiss' "$repo_dir/install.sh"
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
assert "## Compact Instructions" in Path("memory/CLAUDE.md").read_text()

prompt = Path("prompt/claude-kiss.md").read_text()
assert "Treat a question as a request for an answer" in prompt
assert "preserve its comment density" in prompt
assert "report only an important finding, direction change, or blocker" in prompt
assert "KISS is not minimal effort or a shortcut" in prompt
assert "Fix the root cause at the appropriate layer" in prompt
assert "lazy workaround" in prompt
assert "After compaction or a resumed session" in prompt
assert "add or update focused tests" in prompt
assert "Never ignore, skip, or weaken a relevant failing check" in prompt
assert "never to hide the behavior under test" in prompt
assert "<tone_preference>" in prompt

compact = Path("memory/CLAUDE.md").read_text()
assert "Required test coverage" in compact
assert "design invariants" in compact

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

mkdir -p "$temporary/prefix/bin"
: >"$temporary/prefix/bin/claude-kiss-profile"
"$repo_dir/install.sh" --prefix "$temporary/prefix" --no-path-check
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
"$temporary/prefix/bin/claude-kiss" doctor

CLAUDE_KISS_DRY_RUN=1 "$temporary/prefix/bin/claude-kiss" test |
  grep -q -- '--system-prompt-file'

CLAUDE_KISS_DRY_RUN=1 CLAUDE_KISS_HOME="$repo_dir" \
  "$repo_dir/bin/claude-kiss" hello >"$temporary/dry-run.txt"
grep -q '\[--setting-sources\] \[user\]' "$temporary/dry-run.txt"
grep -q -- '--strict-mcp-config' "$temporary/dry-run.txt"
grep -q 'Bash,Glob,Grep,Read,Edit,Write' "$temporary/dry-run.txt"
grep -q -- '--add-dir' "$temporary/dry-run.txt"
grep -q -- '--disallowedTools' "$temporary/dry-run.txt"
grep -q '^compaction: kiss$' "$temporary/dry-run.txt"
grep -q '^DISABLE_AUTO_COMPACT=0$' "$temporary/dry-run.txt"
grep -q '^DISABLE_COMPACT=0$' "$temporary/dry-run.txt"
if grep -q -- '--disable-slash-commands' "$temporary/dry-run.txt"; then
  printf 'error: slash commands must remain enabled by default for /model\n' >&2
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

"$repo_dir/install.sh" --prefix "$temporary/prefix" --uninstall >/dev/null
[ ! -e "$temporary/prefix/bin/claude-kiss" ]
[ ! -e "$temporary/prefix/bin/claude-kiss-profile" ]
[ ! -e "$temporary/prefix/share/claude-kiss" ]

printf 'All Claude KISS tests passed.\n'
