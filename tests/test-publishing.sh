#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

for required in manifest.json README.md LICENSE SECURITY.md; do
  [[ -s "$ROOT/$required" ]] || { echo "missing required file: $required" >&2; exit 1; }
done

python3 - "$ROOT/manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
required = ("schemaVersion", "id", "name", "version", "author", "description", "kinds", "entryPoints")
missing = [key for key in required if key not in manifest]
if missing:
    raise SystemExit(f"manifest missing: {', '.join(missing)}")
if "." not in manifest["id"]:
    raise SystemExit("manifest id is not namespaced")
PY

if rg -n '<owner>|<github-user>|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|gh[pousr]_[A-Za-z0-9]+' \
  "$ROOT" -g '!tests/test-publishing.sh' -g '!.git'; then
  echo 'publication scan found a placeholder or credential pattern' >&2
  exit 1
fi

printf '%s\n' 'publication structure and secret scan: OK'
