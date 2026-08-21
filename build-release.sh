#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
version=$(cat "$repo/VERSION")
output="$repo/dist"
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-release.XXXXXX")

cleanup() {
  rm -rf "$temporary"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$output" "$temporary/claude-kiss/bin" "$temporary/claude-kiss/config" \
  "$temporary/claude-kiss/prompt" "$temporary/claude-kiss/memory" \
  "$temporary/claude-kiss/evals" "$temporary/claude-kiss/tests"

cp "$repo/install.sh" "$repo/LICENSE" "$repo/NOTICE" "$repo/README.md" "$repo/VERSION" \
  "$temporary/claude-kiss/"
cp "$repo/bin/claude-kiss" "$temporary/claude-kiss/bin/"
cp "$repo/config/settings.json" "$temporary/claude-kiss/config/"
cp "$repo/prompt/claude-kiss.md" "$temporary/claude-kiss/prompt/"
cp "$repo/memory/CLAUDE.md" "$temporary/claude-kiss/memory/"
cp "$repo/evals/run_evals.py" "$temporary/claude-kiss/evals/"
cp "$repo/tests/test.sh" "$temporary/claude-kiss/tests/"

archive="$output/claude-kiss.tar.gz"
COPYFILE_DISABLE=1 tar -czf "$archive" -C "$temporary" claude-kiss

if command -v sha256sum >/dev/null 2>&1; then
  checksum=$(sha256sum "$archive" | awk '{print $1}')
else
  checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
fi
printf '%s\n' "$checksum" >"$output/claude-kiss.tar.gz.sha256"
printf '%s\n' \
  '{"version":"'$version'","archive":"https://claude-kiss.com/releases/v'$version'/claude-kiss.tar.gz","sha256":"'$checksum'"}' \
  >"$output/release.json"

printf 'Built Claude KISS release %s\n' "$version"
printf '  archive:  %s\n' "$archive"
printf '  sha256:   %s\n' "$checksum"
