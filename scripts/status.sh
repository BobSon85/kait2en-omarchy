#!/usr/bin/env bash
set -u

json_escape() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || printf 'unknown')
case "$model" in
  MacBookAir8,1) profile=8_1 ;;
  MacBookAir8,2) profile=8_2 ;;
  MacBookAir9,1) profile=9_1 ;;
  MacBookPro15,1) profile=15_1 ;;
  MacBookPro15,2) profile=15_2 ;;
  MacBookPro15,3) profile=15_3 ;;
  MacBookPro15,4) profile=15_4 ;;
  MacBookPro16,1) profile=16_1 ;;
  MacBookPro16,2) profile=16_2 ;;
  MacBookPro16,3) profile=16_3 ;;
  MacBookPro16,4) profile=16_4 ;;
  *) profile=unsupported ;;
esac

sink=$(pactl info 2>/dev/null | sed -n 's/^Default Sink: //p')
[[ -n "$sink" ]] || sink=unknown
if pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -Fxq audio_effect.t2-81-speakers; then
  dsp_sink=true
else
  dsp_sink=false
fi

if systemctl is-enabled --quiet kait2en-dsp-update.timer 2>/dev/null; then
  timer_enabled=true
else
  timer_enabled=false
fi

if [[ "$profile" != unsupported && -f "/usr/share/t2-dsp/profiles/$profile/graph.json" ]]; then
  profile_installed=true
else
  profile_installed=false
fi

if [[ -d "$HOME/.lv2/bankstown.lv2" && -d /usr/lib/lv2/bankstown.lv2 ]]; then
  duplicate_bankstown=true
else
  duplicate_bankstown=false
fi

printf '{"model":"%s","profile":"%s","profileInstalled":%s,"dspSink":%s,"defaultSink":"%s","timerEnabled":%s,"duplicateBankstown":%s}\n' \
  "$(json_escape "$model")" "$profile" "$profile_installed" "$dsp_sink" "$(json_escape "$sink")" "$timer_enabled" "$duplicate_bankstown"
