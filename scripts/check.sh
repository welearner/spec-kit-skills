#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"
LICENSE_FILE="$ROOT_DIR/THIRD_PARTY_NOTICES/spec-kit-LICENSE"
UPSTREAM_FILE="$ROOT_DIR/UPSTREAM.json"
CORE_SKILLS=(
  speckit-constitution
  speckit-specify
  speckit-plan
  speckit-tasks
  speckit-implement
)

fail() {
  echo "check failed: $*" >&2
  exit 1
}

[[ -d "$SKILLS_DIR" ]] || fail "skills/ is missing"
[[ -f "$UPSTREAM_FILE" ]] || fail "UPSTREAM.json is missing"
[[ -f "$LICENSE_FILE" ]] || fail "THIRD_PARTY_NOTICES/spec-kit-LICENSE is missing"

python3 - "$UPSTREAM_FILE" <<'PY'
import json
import pathlib
import sys

try:
    payload = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"invalid UPSTREAM.json: {exc}")
for key in ("repository", "ref", "commit", "version"):
    if not isinstance(payload.get(key), str) or not payload[key].strip():
        raise SystemExit(f"UPSTREAM.json requires a non-empty {key!r}")
PY

skill_count=0
speckit_count=0
while IFS= read -r -d '' skill_dir; do
  skill_count=$((skill_count + 1))
  if [[ "$(basename "$skill_dir")" == speckit-* ]]; then
    speckit_count=$((speckit_count + 1))
  fi
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || fail "$(basename "$skill_dir") has no SKILL.md"
  [[ -s "$skill_file" ]] || fail "$skill_file is empty"
  python3 - "$skill_file" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
if not lines or lines[0].strip() != "---":
    raise SystemExit(f"{path}: frontmatter must start with ---")
try:
    end = next(index for index, line in enumerate(lines[1:], 1) if line.strip() == "---")
except StopIteration:
    raise SystemExit(f"{path}: frontmatter is not terminated")
frontmatter = "\n".join(lines[1:end])
for key in ("name", "description"):
    if not re.search(rf"(?m)^{key}:\s*\S", frontmatter):
        raise SystemExit(f"{path}: frontmatter requires non-empty {key}")
PY
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

[[ "$speckit_count" -gt 0 ]] || fail "no speckit-* skills found"
for skill in "${CORE_SKILLS[@]}"; do
  [[ -s "$SKILLS_DIR/$skill/SKILL.md" ]] || fail "required core skill missing: $skill"
done

echo "check passed: $skill_count skill directories ($speckit_count speckit skills)"
