#!/usr/bin/env bash
set -Eeuo pipefail

value=${1:-}
[[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo 'usage: set-bass.sh <0..15>' >&2; exit 2; }
awk -v v="$value" 'BEGIN { exit !(v >= 0 && v <= 15) }' || { echo 'bass amount must be between 0 and 15' >&2; exit 2; }

sudo install -d -m 0755 /etc/kait2en-omarchy
printf 'BASS_AMT=%s\n' "$value" | sudo install -m 0644 /dev/stdin /etc/kait2en-omarchy/settings.conf
sudo systemctl start kait2en-dsp-update.service
echo "Saved KAIT2EN bass amount: $value"
