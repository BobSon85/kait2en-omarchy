#!/usr/bin/env bash
set -Eeuo pipefail

BASE=/var/lib/kait2en-dsp
REPO="$BASE/KaiT2en-Fedora"
BANK="$BASE/bankstown"
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
SETTINGS=/etc/kait2en-omarchy/settings.conf

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

BASS_AMT=3.0
if [[ -f "$SETTINGS" ]]; then
  # Only this variable is accepted from the administrator-owned settings file.
  # shellcheck disable=SC1090
  source "$SETTINGS"
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
if [[ -f "$BASE/installed-rev" && $(<"$BASE/installed-rev") == "$REV" && -f "$BASE/installed-bass" && $(<"$BASE/installed-bass") == "$BASS_AMT" && -f "/usr/share/t2-dsp/profiles/$PROFILE/graph.json" ]]; then
  echo "KAIT2EN: already current ($REV)"
  exit 0
fi

make -C "$REPO/dsp" build test
cargo build --release --manifest-path "$BANK/Cargo.toml"
[[ -f "$REPO/dsp/build/profiles/$PROFILE/graph.json" ]] || {
  echo "KAIT2EN: upstream did not produce profile $PROFILE" >&2
  exit 1
}

STAMP=$(date +%Y%m%d-%H%M%S)
[[ -d /usr/share/t2-dsp ]] && cp -a /usr/share/t2-dsp "$BASE/backups/$STAMP-t2-dsp"
[[ -d /usr/lib/lv2/bankstown.lv2 ]] && cp -a /usr/lib/lv2/bankstown.lv2 "$BASE/backups/$STAMP-bankstown"

install -d /usr/share/t2-dsp/profiles /usr/lib/lv2/bankstown.lv2 /usr/share/wireplumber/wireplumber.conf.d
rm -rf /usr/share/t2-dsp/profiles
cp -a "$REPO/dsp/build/profiles" /usr/share/t2-dsp/
sed -Ei "0,/\"amt\"[[:space:]]*:[[:space:]]*[0-9.]+/s//\"amt\": $BASS_AMT/" \
  "/usr/share/t2-dsp/profiles/$PROFILE/graph.json"
rm -rf /usr/lib/lv2/bankstown.lv2
install -m 0755 "$BANK/target/release/libbankstown.so" /usr/lib/lv2/bankstown.lv2/bankstown.so
install -m 0644 "$BANK/bankstown.ttl" "$BANK/manifest.ttl" /usr/lib/lv2/bankstown.lv2/

cat > /usr/share/wireplumber/wireplumber.conf.d/51-kait2en-dsp.conf <<EOF
node.software-dsp.rules = [
  {
    matches = [ { alsa.id = "t2-$PROFILE", api.alsa.pcm.stream = "playback", device.profile.name = "HiFi: Speaker: sink" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/graph.json", hide-parent = false } }
  },
  {
    matches = [ { alsa.id = "Audio", api.alsa.pcm.stream = "playback", device.profile.name = "HiFi: Speaker: sink" } ]
    actions = { create-filter = { filter-path = "/usr/share/t2-dsp/profiles/$PROFILE/graph.json", hide-parent = false } }
  }
]
wireplumber.profiles = { main = { node.software-dsp = required } }
EOF

printf '%s\n' "$REV" > "$BASE/installed-rev"
printf '%s\n' "$BASS_AMT" > "$BASE/installed-bass"
echo "KAIT2EN: installed $MODEL ($PROFILE), revision $REV, bass amount $BASS_AMT"
