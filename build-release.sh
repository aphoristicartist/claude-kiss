#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
version=$(cat "$repo/VERSION")
output=${OUTPUT_DIR:-"$repo/dist"}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/claude-kiss-release.XXXXXX")

cleanup() {
  rm -rf "$temporary"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$output" "$temporary/release"

archive="$temporary/release/claude-kiss.tar.gz"
python3 - "$repo" "$archive" <<'PY'
import gzip
import io
import stat
import sys
import tarfile
from pathlib import Path

repo = Path(sys.argv[1])
archive = Path(sys.argv[2])
directories = ("assets", "bin", "config", "prompt", "memory", "evals", "tests")
files = (
    "install.sh",
    "LICENSE",
    "NOTICE",
    "README.md",
    "WHY.md",
    "MANIFESTO.md",
    "REFERENCE.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "VERSION",
    "assets/mark.svg",
    "bin/claude-kiss",
    "config/settings.json",
    "prompt/claude-kiss.md",
    "memory/CLAUDE.md",
    "evals/run_evals.py",
    "tests/test.sh",
)


def base_info(name: str) -> tarfile.TarInfo:
    info = tarfile.TarInfo(name)
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    return info


with archive.open("wb") as raw:
    with gzip.GzipFile(
        filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0
    ) as compressed:
        with tarfile.open(
            fileobj=compressed, mode="w", format=tarfile.USTAR_FORMAT
        ) as output:
            for directory in ("", *directories):
                name = "claude-kiss" if not directory else f"claude-kiss/{directory}"
                info = base_info(name)
                info.type = tarfile.DIRTYPE
                info.mode = 0o755
                output.addfile(info)

            for relative in files:
                source = repo / relative
                source_stat = source.lstat()
                if not stat.S_ISREG(source_stat.st_mode):
                    raise SystemExit(f"release input is not a regular file: {source}")

                data = source.read_bytes()
                info = base_info(f"claude-kiss/{relative}")
                # Git records only the executable bit, so normalize all other mode bits.
                info.mode = 0o755 if source_stat.st_mode & 0o111 else 0o644
                info.size = len(data)
                output.addfile(info, fileobj=io.BytesIO(data))
PY

if command -v sha256sum >/dev/null 2>&1; then
  checksum=$(sha256sum "$archive" | awk '{print $1}')
else
  checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
fi
printf '%s\n' "$checksum" >"$temporary/release/claude-kiss.tar.gz.sha256"
printf '{"version":"%s","archive":"https://claude-kiss.com/releases/v%s/claude-kiss.tar.gz","sha256":"%s"}\n' \
  "$version" "$version" "$checksum" >"$temporary/release/release.json"

for artifact in claude-kiss.tar.gz claude-kiss.tar.gz.sha256 release.json; do
  mv "$temporary/release/$artifact" "$output/$artifact"
done

printf 'Built Claude KISS release %s\n' "$version"
printf '  archive:  %s\n' "$output/claude-kiss.tar.gz"
printf '  sha256:   %s\n' "$checksum"
