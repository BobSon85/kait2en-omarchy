#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$MODEL" in
  MacBookAir8,1|MacBookAir8,2|MacBookAir9,1|\
  MacBookPro15,1|MacBookPro15,2|MacBookPro15,3|MacBookPro15,4|\
  MacBookPro16,1|MacBookPro16,2|MacBookPro16,3|MacBookPro16,4) ;;
  *) echo "KAIT2EN: unsupported or unknown model: $MODEL" >&2; exit 2 ;;
esac

if [[ ! -f /etc/arch-release ]]; then
  echo "This installer currently targets Arch Linux/Omarchy." >&2
  exit 2
fi

echo "KAIT2EN installer for $MODEL"
echo "This will install dependencies, build upstream DSP components and create a system timer."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

sudo pacman -S --needed pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber lsp-plugins-lv2 git rust base-devel
sudo install -d /usr/local/libexec /etc/systemd/system
sudo install -m 0755 "$ROOT/scripts/update-system.sh" /usr/local/libexec/kait2en-omarchy-update
sudo install -m 0644 "$ROOT/systemd/kait2en-dsp-update.service" /etc/systemd/system/kait2en-dsp-update.service
sudo install -m 0644 "$ROOT/systemd/kait2en-dsp-update.timer" /etc/systemd/system/kait2en-dsp-update.timer
sudo systemctl daemon-reload
sudo systemctl enable kait2en-dsp-update.timer
sudo systemctl start kait2en-dsp-update.service
sudo systemctl start kait2en-dsp-update.timer
systemctl --user restart wireplumber
sleep 2
echo
echo "KAIT2EN installation finished. Check with: wpctl status"
