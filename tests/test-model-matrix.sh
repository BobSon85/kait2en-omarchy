#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

models=(
  MacBookAir8,1 MacBookAir8,2 MacBookAir9,1
  MacBookPro15,1 MacBookPro15,2 MacBookPro15,3 MacBookPro15,4
  MacBookPro16,1 MacBookPro16,2 MacBookPro16,3 MacBookPro16,4
)

for model in "${models[@]}"; do
  rg -q "$model" "$ROOT/scripts/install.sh"
  rg -q "$model" "$ROOT/scripts/update-system.sh"
  rg -q "$model" "$ROOT/scripts/status.sh"
  rg -q "$model" "$ROOT/eq/apply.sh"
done

rg -q 'HiFi: Mic: source' "$ROOT/scripts/update-system.sh"
rg -q 'monitor\.alsa\.rules' "$ROOT/scripts/update-system.sh"

if rg -q 'MacBookPro15,\*|MacBookPro16,\*' "$ROOT/scripts/install.sh"; then
  echo 'installer contains an overly broad MacBook Pro pattern' >&2
  exit 1
fi
printf '%s\n' 'MacBook model matrix: OK'
