#!/usr/bin/env bash
set -Eeuo pipefail

echo "This removes the KAIT2EN system integration and keeps backups in /var/lib/kait2en-dsp."
echo "Shared AppleT2 UCM profiles are kept for other T2 audio components."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

sudo systemctl disable --now kait2en-dsp-update.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/kait2en-dsp-update.service \
  /etc/systemd/system/kait2en-dsp-update.timer \
  /usr/local/libexec/kait2en-omarchy-update \
  /usr/lib/udev/rules.d/89-kait2en-dsp.rules \
  /etc/kait2en-omarchy/settings.conf \
  /etc/pipewire/pipewire.conf.d/90-kait2en-t2-audio.conf \
  /usr/share/wireplumber/wireplumber.conf.d/51-kait2en-dsp.conf
sudo systemctl daemon-reload
sudo udevadm control --reload-rules || true
if ! systemctl --user restart pipewire pipewire-pulse wireplumber; then
  echo "Warning: could not restart the current user's audio session." >&2
fi
echo "KAIT2EN system integration removed. Backups were not deleted."
