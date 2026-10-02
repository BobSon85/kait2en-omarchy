#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for file in "$ROOT"/scripts/*.sh "$ROOT"/eq/*.sh; do
  bash -n "$file"
done
python3 -m json.tool "$ROOT/manifest.json" >/dev/null
"$ROOT/tests/test-eq.sh"
"$ROOT/tests/test-model-matrix.sh"
"$ROOT/tests/test-publishing.sh"
printf '%s\n' 'portable shell and manifest checks: OK'
