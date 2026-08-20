#!/bin/sh
set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_temporary=""
temporary=""
prefix=${PREFIX:-$HOME/.local}
data_dir=${DATA_DIR:-$prefix/share/claude-kiss}
mode=install
modify_path=true

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --prefix PATH     Installation prefix (default: ~/.local)
  --data-dir PATH   Asset directory (default: PREFIX/share/claude-kiss)
  --no-path-check   Do not warn if PREFIX/bin is outside PATH
  --uninstall       Remove only files installed by this script
  -h, --help        Show help

The installer does not modify ~/.claude, ~/.claude.json, or the normal `claude` command.
When run remotely, set CLAUDE_KISS_REPO or use the project's documented install URL.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { printf '%s requires a value\n' "$1" >&2; exit 2; }
      prefix=$2
      data_dir=${DATA_DIR:-$prefix/share/claude-kiss}
      shift 2
      ;;
    --prefix=*)
      prefix=${1#*=}
      data_dir=${DATA_DIR:-$prefix/share/claude-kiss}
      shift
      ;;
    --data-dir)
      [ "$#" -ge 2 ] || { printf '%s requires a value\n' "$1" >&2; exit 2; }
      data_dir=$2
      shift 2
      ;;
    --data-dir=*)
      data_dir=${1#*=}
      shift
      ;;
    --no-path-check) modify_path=false; shift ;;
    --uninstall) mode=uninstall; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$prefix" ] || [ -z "$data_dir" ] || [ "$data_dir" = / ] || [ "$data_dir" = "$HOME" ]; then
  printf 'Refusing unsafe installation paths: prefix=%s data_dir=%s\n' "$prefix" "$data_dir" >&2
  exit 2
fi

cleanup() {
  [ -z "$temporary" ] || rm -rf "$temporary"
  [ -z "$source_temporary" ] || rm -rf "$source_temporary"
}
trap cleanup EXIT HUP INT TERM

if [ "$mode" = uninstall ]; then
  if [ -z "$prefix" ] || [ -z "$data_dir" ] || [ "$data_dir" = / ] || [ "$data_dir" = "$HOME" ]; then
    printf 'Refusing unsafe uninstall paths: prefix=%s data_dir=%s\n' "$prefix" "$data_dir" >&2
    exit 2
  fi
  [ -f "$prefix/bin/claude-kiss" ] || [ -f "$prefix/bin/claude-kiss-profile" ] || [ -d "$data_dir" ] || {
    printf 'No claude-kiss installation found under the requested paths.\n'
    exit 0
  }
  [ -f "$prefix/bin/claude-kiss" ] && rm -f "$prefix/bin/claude-kiss"
  # Remove the short-lived v0.3.0 helper; profile state under XDG_STATE_HOME is user data.
  if [ -f "$prefix/bin/claude-kiss-profile" ]; then
    rm -f "$prefix/bin/claude-kiss-profile"
    printf 'Removed obsolete %s/bin/claude-kiss-profile\n' "$prefix"
  fi
  [ -d "$data_dir" ] && rm -rf "$data_dir"
  printf 'Removed %s/bin/claude-kiss\n' "$prefix"
  printf 'Removed %s\n' "$data_dir"
  printf 'The default Claude Code configuration was not changed.\n'
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  printf 'Claude Code was not found in PATH. Install it first:\n' >&2
  printf '  https://code.claude.com/docs/en/setup\n' >&2
  exit 1
fi

claude --system-prompt-file /dev/null --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects --system-prompt-file.\n' >&2
  printf 'Update Claude Code and retry.\n' >&2
  exit 1
}
claude --setting-sources "" --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects --setting-sources.\n' >&2
  exit 1
}
claude --tools default --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects --tools.\n' >&2
  exit 1
}
claude --autocompact auto --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects --autocompact.\n' >&2
  exit 1
}
claude --strict-mcp-config --disable-slash-commands --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects the KISS tool/MCP/skill flags.\n' >&2
  exit 1
}

if [ ! -f "$source_dir/prompt/claude-kiss.md" ] || [ ! -f "$source_dir/config/settings.json" ]; then
  repository=${CLAUDE_KISS_REPO:-https://github.com/aphoristicartist/claude-kiss}
  release_version=${CLAUDE_KISS_VERSION:-0.4.0}
  case "$repository" in
    *.git) repository=${repository%.git} ;;
  esac
  archive="$repository/archive/refs/tags/v$release_version.tar.gz"
  source_temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-source.XXXXXX")
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$archive" -o "$source_temporary/source.tar.gz"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$source_temporary/source.tar.gz" "$archive"
  else
    printf 'Downloading Claude KISS requires curl or wget.\n' >&2
    exit 1
  fi
  tar -xzf "$source_temporary/source.tar.gz" -C "$source_temporary" --strip-components=1
  source_dir=$source_temporary
fi

[ -f "$source_dir/prompt/claude-kiss.md" ] || { printf 'Missing prompt/claude-kiss.md\n' >&2; exit 1; }
[ -f "$source_dir/config/settings.json" ] || { printf 'Missing config/settings.json\n' >&2; exit 1; }
[ -f "$source_dir/memory/CLAUDE.md" ] || { printf 'Missing memory/CLAUDE.md\n' >&2; exit 1; }

umask 022
mkdir -p "$prefix/bin" "$data_dir/prompt" "$data_dir/config" "$data_dir/memory"
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-install.XXXXXX")

cp "$source_dir/prompt/claude-kiss.md" "$temporary/claude-kiss.md"
cp "$source_dir/config/settings.json" "$temporary/settings.json"
cp "$source_dir/memory/CLAUDE.md" "$temporary/compact-CLAUDE.md"
sed "s|__CLAUDE_KISS_DEFAULT_HOME__|$data_dir|g" "$source_dir/bin/claude-kiss" > "$temporary/claude-kiss"
chmod 755 "$temporary/claude-kiss"

# Keep each update atomic. Existing canonical assets are intentionally replaced;
# use CLAUDE_KISS_PROMPT/CLAUDE_KISS_SETTINGS for persistent personal forks.
mv "$temporary/claude-kiss.md" "$data_dir/prompt/claude-kiss.md"
mv "$temporary/settings.json" "$data_dir/config/settings.json"
mv "$temporary/compact-CLAUDE.md" "$data_dir/memory/CLAUDE.md"
mv "$temporary/claude-kiss" "$prefix/bin/claude-kiss"
# Remove the short-lived v0.3.0 helper without touching user profile data.
rm -f "$prefix/bin/claude-kiss-profile"

printf 'Installed %s/bin/claude-kiss\nInstalled assets in %s\n' "$prefix" "$data_dir"

if [ "$modify_path" = true ]; then
  case ":$PATH:" in
    *":$prefix/bin:"*) ;;
    *)
      printf '\nWarning: %s/bin is not in PATH. Add it, for example:\n' "$prefix" >&2
      printf '  export PATH="%s/bin:$PATH"\n' "$prefix" >&2
      ;;
  esac
fi

printf '\nRun:\n  claude-kiss\n'
printf 'The normal `claude` command remains unchanged.\n'
