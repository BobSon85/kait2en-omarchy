#!/usr/bin/env bash
set -Eeuo pipefail

source_dir="$HOME/.lv2/bankstown.lv2"
disabled_dir="$HOME/.lv2/bankstown.lv2.disabled"
if [[ ! -d "$source_dir" ]]; then
  echo 'No user-local Bankstown copy found.'
  exit 0
fi
if [[ -e "$disabled_dir" ]]; then
  echo "Refusing to overwrite existing $disabled_dir" >&2
  exit 2
fi
mv "$source_dir" "$disabled_dir"
systemctl --user restart wireplumber
echo "Moved duplicate Bankstown to $disabled_dir and restarted WirePlumber."
