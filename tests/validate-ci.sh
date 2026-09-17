#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for file in "$ROOT/scripts/status.sh" "$ROOT/scripts/diagnose.sh" "$ROOT/scripts/install.sh" "$ROOT/scripts/update-system.sh" "$ROOT/scripts/set-bass.sh" "$ROOT/scripts/uninstall.sh" "$ROOT/scripts/repair-duplicate.sh" "$ROOT/eq/apply.sh"; do
  bash -n "$file"
done
python3 -m json.tool "$ROOT/manifest.json" >/dev/null
"$ROOT/tests/test-model-matrix.sh"
"$ROOT/tests/test-publishing.sh"
printf '%s\n' 'portable shell and manifest checks: OK'
