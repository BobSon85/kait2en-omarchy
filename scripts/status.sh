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
  MacBookAir8,1) profile=8_1; dsp_name=81 ;;
  MacBookAir8,2) profile=8_2; dsp_name=82 ;;
  MacBookAir9,1) profile=9_1; dsp_name=91 ;;
  MacBookPro15,1) profile=15_1; dsp_name=151 ;;
  MacBookPro15,2) profile=15_2; dsp_name=152 ;;
  MacBookPro15,3) profile=15_3; dsp_name=153 ;;
  MacBookPro15,4) profile=15_4; dsp_name=154 ;;
  MacBookPro16,1) profile=16_1; dsp_name=161 ;;
  MacBookPro16,2) profile=16_2; dsp_name=162 ;;
  MacBookPro16,3) profile=16_3; dsp_name=163 ;;
  MacBookPro16,4) profile=16_4; dsp_name=164 ;;
  *) profile=unsupported ;;
esac

sink=$(pactl info 2>/dev/null | sed -n 's/^Default Sink: //p')
[[ -n "$sink" ]] || sink=unknown
if pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -Fxq "audio_effect.t2-${dsp_name:-unsupported}-speakers"; then
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

bass=3.0
if [[ "$profile" != unsupported && -f "/usr/share/t2-dsp/profiles/$profile/graph.json" ]]; then
  detected_bass=$(sed -n 's/.*"amt"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' "/usr/share/t2-dsp/profiles/$profile/graph.json" | head -1)
  [[ "$detected_bass" =~ ^[0-9]+([.][0-9]+)?$ ]] && bass="$detected_bass"
fi

printf '{"model":"%s","profile":"%s","profileInstalled":%s,"dspSink":%s,"defaultSink":"%s","timerEnabled":%s,"duplicateBankstown":%s,"bassAmount":%s}\n' \
  "$(json_escape "$model")" "$profile" "$profile_installed" "$dsp_sink" "$(json_escape "$sink")" "$timer_enabled" "$duplicate_bankstown" "$bass"
