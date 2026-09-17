#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kait2en-omarchy"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d"
CONF="$CONF_DIR/70-kait2en-user-eq.conf"
mkdir -p "$STATE_DIR" "$CONF_DIR"

restart_wireplumber() {
  [[ "${KAIT2EN_SKIP_RESTART:-0}" == 1 ]] || systemctl --user restart wireplumber
}

enabled=${1:-0}; shift || true
freqs=(60 120 250 500 1000 2000 4000 8000)
(( $# == 8 )) || { echo 'usage: apply.sh <0|1> <8 gains in dB>' >&2; exit 2; }
gains=("$@")

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$model" in
  MacBookAir8,1) target=audio_effect.t2-81-speakers ;;
  MacBookAir8,2) target=audio_effect.t2-82-speakers ;;
  MacBookAir9,1) target=audio_effect.t2-91-speakers ;;
  MacBookPro15,1) target=audio_effect.t2-151-speakers ;;
  MacBookPro15,2) target=audio_effect.t2-152-speakers ;;
  MacBookPro15,3) target=audio_effect.t2-153-speakers ;;
  MacBookPro15,4) target=audio_effect.t2-154-speakers ;;
  MacBookPro16,1) target=audio_effect.t2-161-speakers ;;
  MacBookPro16,2) target=audio_effect.t2-162-speakers ;;
  MacBookPro16,3) target=audio_effect.t2-163-speakers ;;
  MacBookPro16,4) target=audio_effect.t2-164-speakers ;;
  *) echo "unsupported model: $model" >&2; exit 2 ;;
esac

for gain in "$@"; do
  [[ "$gain" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || { echo "invalid gain: $gain" >&2; exit 2; }
  awk -v v="$gain" 'BEGIN { exit !(v >= -6 && v <= 6) }' || { echo "gain outside -6..6 dB: $gain" >&2; exit 2; }
done

if [[ "$enabled" != 1 ]]; then
  rm -f "$CONF" "$STATE_DIR/eq.state"
  restart_wireplumber
  exit 0
fi

{
  printf '%s\n' 'wireplumber.components = ['
  printf '%s\n' '  {'
  printf '%s\n' '    name = libpipewire-module-filter-chain, type = pw-module-client'
  printf '%s\n' '    arguments = {'
  printf '%s\n' '      node.name = "filter.sink.kait2en-user-eq"'
  printf '%s\n' '      node.description = "KaiT2en User Equalizer"'
  printf '%s\n' '      media.name = "KaiT2en User Equalizer"'
  printf '%s\n' '      filter.graph = {'
  printf '%s\n' '        nodes = ['
  for i in "${!freqs[@]}"; do
    printf '          { type = builtin name = eq_%s label = bq_peaking control = { "Freq" = %s "Q" = 1.0 "Gain" = %s } }\n' "$i" "${freqs[$i]}" "${gains[$i]}"
  done
  printf '%s\n' '        ]'
  printf '%s\n' '        links = ['
  for ((i=0; i<7; i++)); do printf '          { output = "eq_%s:Out" input = "eq_%s:In" }\n' "$i" "$((i+1))"; done
  printf '%s\n' '        ]'
  printf '%s\n' '      }'
  printf '%s\n' '      audio.channels = 2'
  printf '%s\n' '      audio.position = [ FL FR ]'
  printf '%s\n' '      capture.props = {'
  printf '        media.class = Audio/Sink\n        filter.smart = true\n        filter.smart.name = "filter.sink.kait2en-user-eq"\n        filter.smart.target = { node.name = "%s" }\n' "$target"
  printf '%s\n' '      }'
  printf '%s\n' '      playback.props = { node.passive = true media.role = "DSP" }'
  printf '%s\n' '    }'
  printf '%s\n' '    provides = filter.sink.kait2en-user-eq'
  printf '%s\n' '    requires = [ support.client-context ]'
  printf '%s\n' '  }'
  printf '%s\n' ']'
  printf '%s\n' 'wireplumber.profiles = { main = { filter.sink.kait2en-user-eq = required } }'
} > "$CONF"
printf '%s\n' "$*" > "$STATE_DIR/eq.state"
restart_wireplumber
echo "Applied KaiT2en user EQ for $model"
