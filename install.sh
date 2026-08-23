#!/bin/sh
set -eu

source_dir=""
# Only a real package file named install.sh may use adjacent source assets. When this
# script arrives on stdin, $0 names the shell (normally "sh"); always download and
# verify the release instead of trusting a repo-shaped current working directory.
if [ "${0##*/}" = install.sh ] && [ -f "$0" ]; then
  source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fi
source_temporary=""
temporary=""
executable_temporary=""
prefix=${PREFIX:-$HOME/.local}
data_dir=""
data_dir_explicit=false
if [ "${DATA_DIR+x}" = x ]; then
  data_dir=$DATA_DIR
  data_dir_explicit=true
fi
config_home=${CLAUDE_KISS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/claude-kiss}
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
Standalone installs download the matching immutable release from claude-kiss.com. For a
mirror, set CLAUDE_KISS_ARCHIVE or CLAUDE_KISS_REPO. Review install.sh before running it.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { printf '%s requires a value\n' "$1" >&2; exit 2; }
      prefix=$2
      shift 2
      ;;
    --prefix=*)
      prefix=${1#*=}
      shift
      ;;
    --data-dir)
      [ "$#" -ge 2 ] || { printf '%s requires a value\n' "$1" >&2; exit 2; }
      data_dir=$2
      data_dir_explicit=true
      shift 2
      ;;
    --data-dir=*)
      data_dir=${1#*=}
      data_dir_explicit=true
      shift
      ;;
    --no-path-check) modify_path=false; shift ;;
    --uninstall) mode=uninstall; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[ "$data_dir_explicit" = true ] || data_dir=$prefix/share/claude-kiss

if [ -z "$prefix" ] || [ -z "$data_dir" ]; then
  printf 'Refusing empty installation paths: prefix=%s data_dir=%s\n' "$prefix" "$data_dir" >&2
  exit 2
fi
case "$prefix$data_dir" in
  *'
'*)
    printf 'Refusing installation paths containing a newline.\n' >&2
    exit 2
    ;;
esac

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
  esac
}

prefix=$(absolute_path "$prefix")
data_dir=$(absolute_path "$data_dir")

# Relative inputs inherit the current directory, so validate the resolved values too.
case "$prefix$data_dir" in
  *'
'*)
    printf 'Refusing installation paths containing a newline.\n' >&2
    exit 2
    ;;
esac

for path in "$prefix" "$data_dir"; do
  case "/$path/" in
    */../*)
      printf 'Refusing installation paths containing a parent-directory component: %s\n' \
        "$path" >&2
      exit 2
      ;;
  esac
done
[ ! -d "$prefix" ] || prefix=$(CDPATH='' cd -- "$prefix" && pwd -P)
[ ! -d "$data_dir" ] || data_dir=$(CDPATH='' cd -- "$data_dir" && pwd -P)
canonical_home=$HOME
[ ! -d "$HOME" ] || canonical_home=$(CDPATH='' cd -- "$HOME" && pwd -P)

if [ "$data_dir" = / ] || [ "$data_dir" = "$canonical_home" ]; then
  printf 'Refusing unsafe installation paths: prefix=%s data_dir=%s\n' "$prefix" "$data_dir" >&2
  exit 2
fi

cleanup() {
  [ -z "$temporary" ] || rm -rf "$temporary"
  [ -z "$source_temporary" ] || rm -rf "$source_temporary"
  [ -z "$executable_temporary" ] || rm -rf "$executable_temporary"
}
trap cleanup EXIT HUP INT TERM

is_marked_launcher() {
  candidate=$1
  [ -f "$candidate" ] || return 1
  grep -Fqx '# Managed by Claude KISS install.sh.' "$candidate"
}

is_legacy_launcher() {
  candidate=$1
  [ -f "$candidate" ] || return 1
  # v0.6 and earlier predate the marker. Require several stable, project-specific
  # strings before treating one of those launchers as ours.
  grep -Fq 'claude-kiss — Claude Code' "$candidate" &&
    grep -Fq 'default_home=' "$candidate" &&
    grep -Fq 'CLAUDE_KISS_HOME' "$candidate" &&
    grep -Fq 'prompt/claude-kiss.md' "$candidate"
}

is_managed_profile() {
  candidate=$1
  [ -f "$candidate" ] || return 1
  grep -Fq 'claude-kiss-profile — named Claude KISS tool profiles' "$candidate" &&
    grep -Fq 'CLAUDE_KISS_PROFILES_DIR' "$candidate"
}

if [ "$mode" = uninstall ]; then
  launcher=$prefix/bin/claude-kiss
  profile_launcher=$prefix/bin/claude-kiss-profile
  launcher_managed=0
  launcher_legacy=0
  profile_managed=0
  data_marked=0
  if is_marked_launcher "$launcher"; then
    launcher_managed=1
  elif is_legacy_launcher "$launcher"; then
    launcher_managed=1
    launcher_legacy=1
  fi
  is_managed_profile "$profile_launcher" && profile_managed=1
  [ ! -f "$data_dir/.claude-kiss-managed" ] || data_marked=1

  [ "$launcher_managed" -eq 1 ] || [ "$profile_managed" -eq 1 ] || \
    [ "$data_marked" -eq 1 ] || {
    printf 'No claude-kiss installation found under the requested paths.\n'
    [ ! -f "$launcher" ] || printf 'Preserved unrecognized launcher: %s\n' "$launcher"
    [ ! -f "$profile_launcher" ] || \
      printf 'Preserved unrecognized profile helper: %s\n' "$profile_launcher"
    exit 0
  }
  if [ "$launcher_managed" -eq 1 ]; then
    rm -f "$launcher"
    printf 'Removed %s/bin/claude-kiss\n' "$prefix"
  elif [ -f "$launcher" ]; then
    printf 'Preserved unrecognized launcher: %s\n' "$launcher"
  fi
  # Remove the short-lived v0.3.0 helper; profile state under XDG_STATE_HOME is user data.
  if [ "$profile_managed" -eq 1 ]; then
    rm -f "$profile_launcher"
    printf 'Removed obsolete %s/bin/claude-kiss-profile\n' "$prefix"
  elif [ -f "$profile_launcher" ]; then
    printf 'Preserved unrecognized profile helper: %s\n' "$profile_launcher"
  fi

  managed_data=$data_marked
  # v0.6 and earlier did not write an ownership marker. Limit compatibility cleanup to
  # their standard dedicated data path paired with an installed launcher.
  if [ "$managed_data" -eq 0 ] && [ "$launcher_legacy" -eq 1 ] && \
    [ "$data_dir" = "$prefix/share/claude-kiss" ]; then
    managed_data=1
  fi

  if [ "$managed_data" -eq 1 ]; then
    rm -f "$data_dir/prompt/claude-kiss.md" "$data_dir/config/settings.json" \
      "$data_dir/memory/CLAUDE.md" "$data_dir/.claude-kiss-managed"
    rmdir "$data_dir/prompt" "$data_dir/config" "$data_dir/memory" 2>/dev/null || :
    if rmdir "$data_dir" 2>/dev/null; then
      printf 'Removed %s\n' "$data_dir"
    else
      printf 'Preserved non-Claude-KISS files in %s\n' "$data_dir"
    fi
  elif [ -d "$data_dir" ]; then
    printf 'Preserved unmarked data directory: %s\n' "$data_dir"
  fi
  if [ -d "$config_home" ]; then
    printf 'Preserved your user configuration: %s\n' "$config_home"
  fi
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
claude --strict-mcp-config --disable-slash-commands --no-chrome --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects the KISS tool/MCP/skill/browser flags.\n' >&2
  exit 1
}

if [ -z "$source_dir" ] || [ ! -f "$source_dir/prompt/claude-kiss.md" ] || \
  [ ! -f "$source_dir/config/settings.json" ] || \
  [ ! -f "$source_dir/memory/CLAUDE.md" ] || [ ! -f "$source_dir/bin/claude-kiss" ]; then
  release_version=${CLAUDE_KISS_VERSION:-0.7.1}
  if [ -n "${CLAUDE_KISS_ARCHIVE:-}" ]; then
    archive=$CLAUDE_KISS_ARCHIVE
  else
    repository=${CLAUDE_KISS_REPO:-https://github.com/aphoristicartist/claude-kiss}
    case "$repository" in
      *.git) repository=${repository%.git} ;;
    esac
    if [ "${CLAUDE_KISS_REPO+x}" = x ]; then
      archive="$repository/archive/refs/tags/v$release_version.tar.gz"
    else
      archive="https://claude-kiss.com/releases/v$release_version/claude-kiss.tar.gz"
    fi
  fi
  source_temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-source.XXXXXX")
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$archive" -o "$source_temporary/source.tar.gz"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$source_temporary/source.tar.gz" "$archive"
  else
    printf 'Downloading Claude KISS requires curl or wget.\n' >&2
    exit 1
  fi

  case "$archive" in
    https://claude-kiss.com/releases/*)
      checksum_url="$archive.sha256"
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$checksum_url" -o "$source_temporary/source.sha256"
      else
        wget -qO "$source_temporary/source.sha256" "$checksum_url"
      fi
      expected_checksum=$(awk '{print $1}' "$source_temporary/source.sha256")
      if ! printf '%s\n' "$expected_checksum" | grep -Eq '^[0-9A-Fa-f]{64}$'; then
        printf 'Claude KISS archive checksum file is invalid.\n' >&2
        exit 1
      fi
      expected_checksum=$(printf '%s' "$expected_checksum" | tr '[:upper:]' '[:lower:]')
      if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$source_temporary/source.tar.gz" | awk '{print $1}')
      else
        actual_checksum=$(shasum -a 256 "$source_temporary/source.tar.gz" | awk '{print $1}')
      fi
      if [ "$actual_checksum" != "$expected_checksum" ]; then
        printf 'Claude KISS archive checksum mismatch.\n' >&2
        exit 1
      fi
      ;;
  esac

  tar -xzf "$source_temporary/source.tar.gz" -C "$source_temporary" --strip-components=1
  source_dir=$source_temporary
fi

[ -f "$source_dir/prompt/claude-kiss.md" ] || { printf 'Missing prompt/claude-kiss.md\n' >&2; exit 1; }
[ -f "$source_dir/config/settings.json" ] || { printf 'Missing config/settings.json\n' >&2; exit 1; }
[ -f "$source_dir/memory/CLAUDE.md" ] || { printf 'Missing memory/CLAUDE.md\n' >&2; exit 1; }

claude --settings "$source_dir/config/settings.json" --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects --settings.\n' >&2
  exit 1
}
claude --add-dir "$source_dir" --disallowedTools "Read($source_dir/**)" --version >/dev/null 2>&1 || {
  printf 'Your Claude Code lacks or rejects the KISS memory flags.\n' >&2
  exit 1
}

umask 022
mkdir -p "$prefix/bin" "$data_dir/prompt" "$data_dir/config" "$data_dir/memory"
# Stage beside the canonical assets so each final replacement is a same-filesystem move.
temporary=$(mktemp -d "$data_dir/.install.XXXXXX")
executable_temporary=$(mktemp -d "$prefix/bin/.claude-kiss-install.XXXXXX")

cp "$source_dir/prompt/claude-kiss.md" "$temporary/claude-kiss.md"
cp "$source_dir/config/settings.json" "$temporary/settings.json"
cp "$source_dir/memory/CLAUDE.md" "$temporary/compact-CLAUDE.md"
# Embed the data directory as a shell literal. Escape it once for single-quoted shell
# syntax, then once for the sed replacement expression.
quoted_data_dir=$(printf "'%s'" "$(printf '%s' "$data_dir" | sed "s/'/'\\\\''/g")")
escaped_data_dir=$(printf '%s' "$quoted_data_dir" | sed 's/[\\&|]/\\&/g')
sed "s|__CLAUDE_KISS_DEFAULT_HOME__|$escaped_data_dir|g" \
  "$source_dir/bin/claude-kiss" > "$executable_temporary/claude-kiss"
chmod 755 "$executable_temporary/claude-kiss"
printf 'managed by claude-kiss install.sh\n' > "$temporary/.claude-kiss-managed"

# Keep each update atomic. Managed assets are replaced; `claude-kiss init` owns
# persistent user forks under CLAUDE_KISS_CONFIG_HOME.
mv "$temporary/claude-kiss.md" "$data_dir/prompt/claude-kiss.md"
mv "$temporary/settings.json" "$data_dir/config/settings.json"
mv "$temporary/compact-CLAUDE.md" "$data_dir/memory/CLAUDE.md"
mv "$executable_temporary/claude-kiss" "$prefix/bin/claude-kiss"
mv "$temporary/.claude-kiss-managed" "$data_dir/.claude-kiss-managed"
rmdir "$executable_temporary"
# Remove the short-lived v0.3.0 helper without touching an unrelated file at the same path.
if is_managed_profile "$prefix/bin/claude-kiss-profile"; then
  rm -f "$prefix/bin/claude-kiss-profile"
elif [ -f "$prefix/bin/claude-kiss-profile" ]; then
  printf 'Preserved unrecognized profile helper: %s/bin/claude-kiss-profile\n' "$prefix" >&2
fi

printf 'Installed %s/bin/claude-kiss\nInstalled assets in %s\n' "$prefix" "$data_dir"

if [ "$modify_path" = true ]; then
  case ":$PATH:" in
    *":$prefix/bin:"*) ;;
    *)
      printf '\nWarning: %s/bin is not in PATH. Add it, for example:\n' "$prefix" >&2
      # shellcheck disable=SC2016  # $PATH is printed literally for the user to copy.
      printf '  export PATH="%s/bin:$PATH"\n' "$prefix" >&2
      ;;
  esac
fi

printf '\nRun:\n  claude-kiss\n'
# shellcheck disable=SC2016  # Backticks are literal punctuation, not substitution.
printf 'The normal `claude` command remains unchanged.\n'
