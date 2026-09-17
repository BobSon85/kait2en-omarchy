#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_CONFIG=$(mktemp -d)
trap 'rm -rf "$TEST_CONFIG"' EXIT

XDG_CONFIG_HOME="$TEST_CONFIG" KAIT2EN_SKIP_RESTART=1 \
  "$ROOT/eq/apply.sh" 1 -2 -1 0 1 2 1 0 -1 >/tmp/kait2en-eq-test.out
CONF="$TEST_CONFIG/wireplumber/wireplumber.conf.d/70-kait2en-user-eq.conf"
[[ -f "$CONF" ]]
[[ $(rg -c 'label = bq_peaking' "$CONF") -eq 8 ]]
rg -q 'filter.smart.name = "filter.sink.kait2en-user-eq"' "$CONF"
rg -q 'filter.smart.target = \{ node.name = "audio_effect.t2-81-speakers" \}' "$CONF"

XDG_CONFIG_HOME="$TEST_CONFIG" KAIT2EN_SKIP_RESTART=1 \
  "$ROOT/eq/apply.sh" 0 0 0 0 0 0 0 0 0 >/tmp/kait2en-eq-flat-test.out
[[ ! -e "$CONF" ]]
printf '%s\n' 'EQ generation and Flat disable: OK'
