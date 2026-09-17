#!/usr/bin/env bash
set -u
printf '%s\n' '=== KAIT2EN Audio diagnostic ==='
printf 'Model: '; cat /sys/class/dmi/id/product_name 2>/dev/null || printf 'unknown\n'
printf '%s\n' '--- PipeWire sinks ---'
pactl list sinks short 2>&1 || true
printf '%s\n' '--- KAIT2EN nodes ---'
wpctl status 2>&1 | sed -n '/Audio/,$p' | head -80 || true
printf '%s\n' '--- updater ---'
systemctl --no-pager --full status kait2en-dsp-update.timer 2>&1 | head -35 || true
printf '%s\n' '--- duplicate LV2 paths ---'
for path in "$HOME/.lv2/bankstown.lv2" /usr/lib/lv2/bankstown.lv2; do
  [[ -d "$path" ]] && printf '%s\n' "$path"
done
printf '%s\n' '--- recent WirePlumber errors ---'
journalctl --user -b --no-pager -u wireplumber -p warning..err 2>&1 | tail -40 || true
printf '%s\n' '' 'Naciśnij Q, aby zamknąć to okno.'
while IFS= read -r -n 1 key; do
  [[ "$key" == "q" || "$key" == "Q" ]] && break
done
