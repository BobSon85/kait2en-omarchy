#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

for script in "$ROOT"/scripts/*.sh "$ROOT"/eq/*.sh; do
  [[ -x "$script" ]] || { echo "not executable: $script" >&2; exit 1; }
done

models=(
  MacBookAir8,1 MacBookAir8,2 MacBookAir9,1
  MacBookPro15,1 MacBookPro15,2 MacBookPro15,3 MacBookPro15,4
  MacBookPro16,1 MacBookPro16,2 MacBookPro16,3 MacBookPro16,4
)

for model in "${models[@]}"; do
  grep -qE "$model" "$ROOT/scripts/install.sh"
  grep -qE "$model" "$ROOT/scripts/update-system.sh"
  grep -qE "$model" "$ROOT/scripts/status.sh"
  grep -qE "$model" "$ROOT/eq/apply.sh"
done

grep -qE 'HiFi: Mic: source' "$ROOT/scripts/update-system.sh"
grep -qE 'monitor\.alsa\.rules' "$ROOT/scripts/update-system.sh"
grep -qE 'alsa-ucm-conf' "$ROOT/scripts/install.sh"
grep -qE 't2bce_audio-alsa-ucm-conf' "$ROOT/scripts/update-system.sh"
grep -qE 'modinfo t2bce_audio' "$ROOT/scripts/install.sh"

if grep -qE 'MacBookPro15,\*|MacBookPro16,\*' "$ROOT/scripts/install.sh"; then
  echo 'installer contains an overly broad MacBook Pro pattern' >&2
  exit 1
fi
printf '%s\n' 'MacBook model matrix: OK'
