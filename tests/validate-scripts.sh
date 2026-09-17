#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for file in "$ROOT/scripts/status.sh" "$ROOT/scripts/diagnose.sh" "$ROOT/scripts/install.sh" "$ROOT/scripts/update-system.sh" "$ROOT/scripts/set-bass.sh" "$ROOT/scripts/uninstall.sh" "$ROOT/scripts/repair-duplicate.sh" "$ROOT/eq/apply.sh"; do
  bash -n "$file"
done
omarchy plugin validate "$ROOT"
"$ROOT/tests/test-eq.sh"
printf '%s\n' 'plugin manifest and shell scripts: OK'
