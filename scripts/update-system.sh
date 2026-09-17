#!/usr/bin/env bash
set -Eeuo pipefail

BASE=/var/lib/kait2en-dsp
REPO="$BASE/KaiT2en-Fedora"
BANK="$BASE/bankstown"
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
SETTINGS=/etc/kait2en-omarchy/settings.conf
PIPEWIRE_CONF=/etc/pipewire/pipewire.conf.d/90-kait2en-t2-audio.conf
PIPEWIRE_MARKER='# Managed by KaiT2en Omarchy: T2 audio stability.'
PIPEWIRE_CONF_CHANGED=0

restart_logged_in_audio() {
  local user uid runtime bus
  user=$(loginctl list-users --no-legend 2>/dev/null | awk '$1 >= 1000 { print $2; exit }' || true)
  [[ -n "$user" ]] || return 0
  uid=$(id -u "$user")
  runtime="/run/user/$uid"
  bus="unix:path=$runtime/bus"
  runuser -u "$user" -- env XDG_RUNTIME_DIR="$runtime" DBUS_SESSION_BUS_ADDRESS="$bus" \
    systemctl --user restart pipewire pipewire-pulse wireplumber || true
}

ensure_pipewire_stability() {
  mkdir -p "$(dirname "$PIPEWIRE_CONF")" "$BASE/backups"
  if [[ -f "$PIPEWIRE_CONF" ]] && ! grep -Fq "$PIPEWIRE_MARKER" "$PIPEWIRE_CONF"; then
    cp -a "$PIPEWIRE_CONF" "$BASE/backups/$(date +%Y%m%d-%H%M%S)-pipewire-quantum.conf"
  fi
  if [[ ! -f "$PIPEWIRE_CONF" ]] || ! grep -Fq "$PIPEWIRE_MARKER" "$PIPEWIRE_CONF"; then
    cat > "$PIPEWIRE_CONF" <<'EOF'
# Managed by KaiT2en Omarchy: T2 audio stability.
# Apple T2 speaker paths are prone to ALSA underruns at 256 frames.
context.properties = {
    default.clock.quantum = 1024
    default.clock.min-quantum = 1024
}
EOF
    PIPEWIRE_CONF_CHANGED=1
  fi
}

profile_for_model() {
  case "$1" in
    MacBookAir8,1) printf '8_1' ;; MacBookAir8,2) printf '8_2' ;;
    MacBookAir9,1) printf '9_1' ;; MacBookPro15,1) printf '15_1' ;;
    MacBookPro15,2) printf '15_2' ;; MacBookPro15,3) printf '15_3' ;;
    MacBookPro15,4) printf '15_4' ;; MacBookPro16,1) printf '16_1' ;;
    MacBookPro16,2) printf '16_2' ;; MacBookPro16,3) printf '16_3' ;;
    MacBookPro16,4) printf '16_4' ;; iMac20,1) printf 'imac20_1' ;;
    iMacPro1,1) printf 'imacpro1_1' ;; *) return 1 ;;
  esac
}

PROFILE=$(profile_for_model "$MODEL") || {
  echo "KAIT2EN: unsupported model $MODEL; leaving audio untouched" >&2
  exit 0
}

mkdir -p "$BASE" "$BASE/backups"

BASS_AMT=3.0
if [[ -f "$SETTINGS" ]]; then
  # Read only the documented key; never execute settings as shell code.
  configured_bass=$(sed -n 's/^BASS_AMT[[:space:]]*=[[:space:]]*//p' "$SETTINGS" | head -1)
  [[ -n "$configured_bass" ]] || { echo 'KAIT2EN: missing BASS_AMT' >&2; exit 1; }
  BASS_AMT="$configured_bass"
fi
[[ "$BASS_AMT" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo 'KAIT2EN: invalid BASS_AMT' >&2; exit 1; }
awk -v v="$BASS_AMT" 'BEGIN { exit !(v >= 0 && v <= 15) }' || { echo 'KAIT2EN: BASS_AMT outside 0..15' >&2; exit 1; }
if [[ ! -f "$SETTINGS" && -f "/usr/share/t2-dsp/profiles/$PROFILE/graph.json" ]]; then
  current_amt=$(sed -n 's/.*"amt"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' "/usr/share/t2-dsp/profiles/$PROFILE/graph.json" | head -1)
  [[ "$current_amt" =~ ^[0-9]+([.][0-9]+)?$ ]] && BASS_AMT="$current_amt"
fi

mkdir -p "$BASE" "$BASE/backups"
if [[ ! -d "$REPO/.git" ]]; then
  git clone --depth 1 --branch main https://github.com/kaiT2en/KaiT2en-Fedora "$REPO"
else
  git -C "$REPO" fetch --depth 1 origin main
  git -C "$REPO" reset --hard origin/main
fi
if [[ ! -d "$BANK/.git" ]]; then
  git clone --depth 1 https://github.com/chadmed/bankstown "$BANK"
else
  git -C "$BANK" fetch --depth 1 origin main
  git -C "$BANK" reset --hard origin/main
fi

REV=$(git -C "$REPO" rev-parse HEAD)
BANK_REV=$(git -C "$BANK" rev-parse HEAD)
UCM_SRC="$REPO/modules/t2bce_audio-alsa-ucm-conf/ucm2"
if [[ -f "$BASE/installed-rev" && $(<"$BASE/installed-rev") == "$REV" && \
      -f "$BASE/installed-bank-rev" && $(<"$BASE/installed-bank-rev") == "$BANK_REV" && \
      -f "$BASE/installed-bass" && $(<"$BASE/installed-bass") == "$BASS_AMT" && \
      -f "/usr/share/t2-dsp/profiles/$PROFILE/graph.json" && \
      -f "/usr/share/alsa/ucm2/AppleT2/HiFi-x2.conf" ]]; then
  ensure_pipewire_stability
  echo "KAIT2EN: already current ($REV)"
  (( PIPEWIRE_CONF_CHANGED )) && restart_logged_in_audio
  exit 0
fi

make -C "$REPO/dsp" build test
cargo build --release --manifest-path "$BANK/Cargo.toml"
[[ -f "$REPO/dsp/build/profiles/$PROFILE/graph.json" && -f "$REPO/dsp/build/profiles/$PROFILE/mic.json" ]] || {
  echo "KAIT2EN: upstream did not produce complete profile $PROFILE" >&2
  exit 1
}
ensure_pipewire_stability

STAMP=$(date +%Y%m%d-%H%M%S)
[[ -d "$UCM_SRC" ]] || { echo "KAIT2EN: upstream UCM files are missing" >&2; exit 1; }
[[ -d /usr/share/t2-dsp ]] && cp -a /usr/share/t2-dsp "$BASE/backups/$STAMP-t2-dsp"
[[ -d /usr/lib/lv2/bankstown.lv2 ]] && cp -a /usr/lib/lv2/bankstown.lv2 "$BASE/backups/$STAMP-bankstown"
[[ -d /usr/share/alsa/ucm2/AppleT2 ]] && cp -a /usr/share/alsa/ucm2/AppleT2 "$BASE/backups/$STAMP-AppleT2-ucm"
for ucm_dir in AppleT2x2 AppleT2x4 AppleT2x6; do
  [[ -d "/usr/share/alsa/ucm2/conf.d/$ucm_dir" ]] && \
    cp -a "/usr/share/alsa/ucm2/conf.d/$ucm_dir" "$BASE/backups/$STAMP-$ucm_dir-ucm"
done

install -d /usr/share/alsa/ucm2 /usr/share/alsa/ucm2/conf.d
cp -a "$UCM_SRC/AppleT2" /usr/share/alsa/ucm2/
for ucm_dir in AppleT2x2 AppleT2x4 AppleT2x6; do
  [[ -d "$UCM_SRC/conf.d/$ucm_dir" ]] && cp -a "$UCM_SRC/conf.d/$ucm_dir" /usr/share/alsa/ucm2/conf.d/
done

install -d /usr/share/t2-dsp/profiles /usr/lib/lv2/bankstown.lv2 /usr/share/wireplumber/wireplumber.conf.d
if [[ -d /usr/share/t2-dsp/profiles ]]; then
  mv /usr/share/t2-dsp/profiles "$BASE/backups/$STAMP-profiles"
fi
cp -a "$REPO/dsp/build/profiles" /usr/share/t2-dsp/
# Older T2 kernels expose the BCE card as "Audio". Newer upstream setups use
# the model-specific t2-* ALSA id. Patch only the active profile to the live
# card id; all other profiles retain upstream's portable t2-* target.
card_id="t2-$PROFILE"
for id_file in /sys/class/sound/card*/id; do
  [[ -r "$id_file" ]] || continue
  if [[ $(<"$id_file") == Audio ]]; then
    card_id=Audio
    break
  fi
done
sed -Ei "s#alsa_output\.hw_t2-${PROFILE}_0#alsa_output.hw_${card_id}_0#g" \
  "/usr/share/t2-dsp/profiles/$PROFILE/graph.json"
sed -Ei "0,/\"amt\"[[:space:]]*:[[:space:]]*[0-9.]+/s//\"amt\": $BASS_AMT/" \
  "/usr/share/t2-dsp/profiles/$PROFILE/graph.json"
if [[ -d /usr/lib/lv2/bankstown.lv2 ]]; then
  mv /usr/lib/lv2/bankstown.lv2 "$BASE/backups/$STAMP-bankstown-lv2"
  install -d /usr/lib/lv2/bankstown.lv2
fi
install -m 0755 "$BANK/target/release/libbankstown.so" /usr/lib/lv2/bankstown.lv2/bankstown.so
install -m 0644 "$BANK/bankstown.ttl" "$BANK/manifest.ttl" /usr/lib/lv2/bankstown.lv2/
install -d /usr/lib/udev/rules.d
install -m 0644 "$REPO/dsp/build/89-t2-dsp.rules" /usr/lib/udev/rules.d/89-kait2en-dsp.rules
udevadm control --reload-rules || true

cat > /usr/share/wireplumber/wireplumber.conf.d/51-kait2en-dsp.conf <<EOF
node.software-dsp.rules = [
  {
    matches = [ { alsa.id = "t2-$PROFILE", api.alsa.pcm.stream = "playback", device.profile.name = "HiFi: Speaker: sink" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/graph.json", hide-parent = false } }
  },
  {
    matches = [ { alsa.id = "Audio", api.alsa.pcm.stream = "playback", device.profile.name = "HiFi: Speaker: sink" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/graph.json", hide-parent = false } }
  },
  {
    matches = [ { alsa.id = "t2-$PROFILE", api.alsa.pcm.stream = "capture", device.profile.name = "HiFi: Mic: source" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/mic.json", hide-parent = false } }
  },
  {
    matches = [ { alsa.id = "Audio", api.alsa.pcm.stream = "capture", device.profile.name = "HiFi: Mic: source" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/mic.json", hide-parent = false } }
  }
]
monitor.alsa.rules = [
  {
    matches = [ { alsa.id = "t2-$PROFILE", api.alsa.pcm.stream = "capture", device.profile.name = "HiFi: Mic: source" } ]
    actions = { update-props = { node.name = "alsa_input.t2-$PROFILE.RawMic" } }
  },
  {
    matches = [ { alsa.id = "Audio", api.alsa.pcm.stream = "capture", device.profile.name = "HiFi: Mic: source" } ]
    actions = { update-props = { node.name = "alsa_input.t2-$PROFILE.RawMic" } }
  }
]
wireplumber.profiles = { main = { node.software-dsp = required } }
EOF

printf '%s\n' "$REV" > "$BASE/installed-rev"
printf '%s\n' "$BANK_REV" > "$BASE/installed-bank-rev"
printf '%s\n' "$BASS_AMT" > "$BASE/installed-bass"
restart_logged_in_audio
echo "KAIT2EN: installed $MODEL ($PROFILE), KAIT2EN $REV, Bankstown $BANK_REV, bass amount $BASS_AMT"
