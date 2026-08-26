#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC_KIT_REPO="${SPEC_KIT_REPO:-https://github.com/github/spec-kit.git}"
SPEC_KIT_REF="${SPEC_KIT_REF:-main}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spec-kit-skills.XXXXXX")"
UPSTREAM_DIR="$WORK_DIR/spec-kit"
PROJECT_DIR="$WORK_DIR/project"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }
command -v uv >/dev/null || { echo "uv is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

git clone --quiet --no-checkout "$SPEC_KIT_REPO" "$UPSTREAM_DIR"
git -C "$UPSTREAM_DIR" checkout --quiet --detach "$SPEC_KIT_REF"

mkdir -p "$PROJECT_DIR"
(
  cd "$PROJECT_DIR"
  # Run the CLI from the checked-out upstream project; never install specify globally.
  uv run --project "$UPSTREAM_DIR" specify init \
    --here \
    --force \
    --non-interactive \
    --integration codex \
    --integration-options="--skills" \
    --ignore-agent-tools \
    --script sh
)

SOURCE_SKILLS="$PROJECT_DIR/.agents/skills"
if [[ ! -d "$SOURCE_SKILLS" ]]; then
  echo "Official specify CLI did not generate $SOURCE_SKILLS" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/skills" "$ROOT_DIR/THIRD_PARTY_NOTICES"
rsync -a --delete -- "$SOURCE_SKILLS/" "$ROOT_DIR/skills/"
install -m 0644 "$UPSTREAM_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY_NOTICES/spec-kit-LICENSE"

UPSTREAM_COMMIT="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
UPSTREAM_VERSION="$(sed -nE 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$UPSTREAM_DIR/pyproject.toml" | head -n 1)"
if [[ -z "$UPSTREAM_VERSION" ]]; then
  echo "Could not read project.version from upstream pyproject.toml" >&2
  exit 1
fi

SPEC_KIT_REPO="$SPEC_KIT_REPO" SPEC_KIT_REF="$SPEC_KIT_REF" \
UPSTREAM_COMMIT="$UPSTREAM_COMMIT" UPSTREAM_VERSION="$UPSTREAM_VERSION" \
python3 - "$ROOT_DIR/UPSTREAM.json" <<'PY'
import json
import os
import pathlib
import sys

payload = {
    "repository": os.environ["SPEC_KIT_REPO"],
    "ref": os.environ["SPEC_KIT_REF"],
    "commit": os.environ["UPSTREAM_COMMIT"],
    "version": os.environ["UPSTREAM_VERSION"],
}
pathlib.Path(sys.argv[1]).write_text(
    json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
)
PY

"$ROOT_DIR/scripts/check.sh"
echo "Synced Spec Kit $UPSTREAM_COMMIT ($UPSTREAM_VERSION)"
