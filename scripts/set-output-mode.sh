#!/usr/bin/env bash
set -Eeuo pipefail

mode=${1:-}
case "$mode" in
  dsp|native) ;;
  *)
    echo "Usage: $0 {dsp|native}" >&2
    exit 2
    ;;
esac

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$model" in
  MacBookAir8,1) dsp_name=81 ;; MacBookAir8,2) dsp_name=82 ;; MacBookAir9,1) dsp_name=91 ;;
  MacBookPro15,1) dsp_name=151 ;; MacBookPro15,2) dsp_name=152 ;; MacBookPro15,3) dsp_name=153 ;;
  MacBookPro15,4) dsp_name=154 ;; MacBookPro16,1) dsp_name=161 ;; MacBookPro16,2) dsp_name=162 ;;
  MacBookPro16,3) dsp_name=163 ;; MacBookPro16,4) dsp_name=164 ;;
  *) echo "KAIT2EN: unsupported model: $model" >&2; exit 2 ;;
esac

dsp_sink="audio_effect.t2-${dsp_name}-speakers"
native_sink=$(pactl list short sinks | awk '$2 ~ /^alsa_output\..*HiFi__Speaker__sink$/ { print $2; exit }')
[[ -n "$native_sink" ]] || {
  echo "KAIT2EN: native internal speaker sink not found" >&2
  exit 1
}

sink_exists() {
  pactl list short sinks | awk -v target="$1" '$2 == target { found=1 } END { exit !found }'
}

set_default_verified() {
  local target=$1
  local current
  local attempt

  for attempt in 1 2 3 4 5; do
    pactl set-default-sink "$target" >/dev/null 2>&1 || true
    sleep 0.6
    current=$(pactl info 2>/dev/null | sed -n 's/^Default Sink: //p')
    if [[ "$current" == "$target" ]]; then
      return 0
    fi
  done

  echo "KAIT2EN: default sink did not settle on $target (current: ${current:-unknown})" >&2
  return 1
}

restart_and_wait_for_dsp() {
  systemctl --user restart wireplumber
  for _ in {1..60}; do
    sink_exists "$dsp_sink" && return 0
    sleep 0.25
  done
  return 1
}

if [[ "$mode" == dsp ]] && ! sink_exists "$dsp_sink"; then
  restart_and_wait_for_dsp || restart_and_wait_for_dsp || true
  sink_exists "$dsp_sink" || {
    echo "KAIT2EN: DSP sink did not return after restarting the audio graph" >&2
    exit 1
  }
  # WirePlumber may still be applying its routing policy after the filter appears.
  sleep 1
fi

if [[ "$mode" == dsp ]]; then
  target="$dsp_sink"
else
  target="$native_sink"
fi

sink_exists "$target" || {
  echo "KAIT2EN: requested sink is not available: $target" >&2
  exit 1
}

if ! set_default_verified "$target"; then
  if [[ "$mode" == dsp ]] && restart_and_wait_for_dsp; then
    sleep 1
    set_default_verified "$target"
  else
    exit 1
  fi
fi
while read -r input_id; do
  [[ -n "$input_id" ]] && pactl move-sink-input "$input_id" "$target" || true
done < <(pactl list short sink-inputs | awk '{ print $1 }')

# Moving streams can trigger another policy pass; verify the final state too.
if ! set_default_verified "$target"; then
  if [[ "$mode" == dsp ]] && restart_and_wait_for_dsp; then
    sleep 1
    set_default_verified "$target" || exit 1
  else
    exit 1
  fi
fi

printf 'KAIT2EN: output mode %s (%s)\n' "$mode" "$target"
