#!/bin/bash
# App Store app preview (6.9" iPhone, 886x1920 portrait, 30 fps, ~25 s) recorded from the simulator.
# Needs a Debug build installed on the device, like capture.sh:
#
#   tools/screenshots/preview_video.sh               # record + narrate -> fastlane/app_previews/{ko,en}.mp4
#   tools/screenshots/preview_video.sh --voice-only  # re-narrate the existing videos, no recording
#
# Narration is edge-tts (pip install edge-tts), one line per scene, starting 0.3 s after each cut.
# Upload by hand in App Store Connect (fastlane deliver cannot upload app previews).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

VOICE_ONLY=0
if [ "${1:-}" = --voice-only ]; then VOICE_ONLY=1; shift; fi
DEVICE=${1:-39D7367E-86EA-41EA-8AC9-48F907B48F02}
BUNDLE=com.leesam.bomdongtycoon
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
OUT="$ROOT/fastlane/app_previews"
mkdir -p "$OUT"

# narrate <lang> <voice> <line 1> <line 2> <line 3> <line 4>
# Scene cuts sit at 0, 5.6, 11.2 and 17.8 s (see the xfade offsets below).
narrate() {
  local lang=$1 voice=$2; shift 2
  local i=0 delays=(300 5900 11500 18100) inputs=() mix=""
  for line in "$@"; do
    edge-tts --voice "$voice" --rate=+8% --text "$line" --write-media "$WORK/$lang-vo$i.mp3" 2>/dev/null
    inputs+=(-i "$WORK/$lang-vo$i.mp3")
    mix+="[$((i + 1)):a]adelay=${delays[$i]}|${delays[$i]},aformat=channel_layouts=stereo[v$i];"
    i=$((i + 1))
  done
  ffmpeg -v error -y -i "$OUT/$lang.mp4" "${inputs[@]}" \
    -filter_complex "${mix}[v0][v1][v2][v3]amix=inputs=4:normalize=0,apad[a]" \
    -map 0:v -map "[a]" -shortest -c:v copy -c:a aac -b:a 256k -ar 44100 -movflags +faststart "$WORK/$lang-vo.mp4"
  mv "$WORK/$lang-vo.mp4" "$OUT/$lang.mp4"
  echo "$OUT/$lang.mp4 (narrated)"
}

if [ "$VOICE_ONLY" = 0 ]; then
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

# clip <lang> <name> <seconds kept> <launch arguments...>
# Launch, let the scene settle (10 s, as for the stills), record, keep the middle <seconds kept>.
clip() {
  local lang=$1 name=$2 keep=$3; shift 3
  local locale=ko_KR shop="봄동 가게"
  if [ "$lang" = en ]; then locale=en_US; shop="Bomdong"; fi
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" -dotNoAds -AppleLanguages "($lang)" -AppleLocale "$locale" \
    -dotShopName "$shop" "$@" >/dev/null
  sleep 10
  xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$WORK/raw.mp4" 2>/dev/null &
  local pid=$!
  sleep $((keep + 2))
  kill -INT $pid; wait $pid || true
  # 1320x2868 -> 886x1925, then trim 5 px of status-bar margin to the 886x1920 Apple wants.
  ffmpeg -v error -y -ss 1 -t "$keep" -i "$WORK/raw.mp4" \
    -vf "fps=30,scale=886:-2:flags=neighbor,crop=886:1920:0:2,setsar=1" \
    -an -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p "$WORK/$lang-$name.mp4"
  echo "$WORK/$lang-$name.mp4"
}

for lang in ko en; do
  clip "$lang" petals 6 -dotSeed mid  -dotPhase morning -dotWeather petals -dotGolden -dotAutoplay -dotSpeed 2
  clip "$lang" noon   6 -dotSeed late -dotPhase noon -dotAutoplay -dotSpeed 2
  clip "$lang" fever  7 -dotSeed late -dotPhase dusk -dotFever -dotAutoplay -dotSpeed 2
  clip "$lang" snow   6 -dotSeed late -dotPhase night -dotWeather snow -dotAutoplay -dotSpeed 2

  # Short crossfades between scenes; a silent stereo AAC track, since App Store Connect wants audio.
  ffmpeg -v error -y \
    -i "$WORK/$lang-petals.mp4" -i "$WORK/$lang-noon.mp4" -i "$WORK/$lang-fever.mp4" -i "$WORK/$lang-snow.mp4" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
    -filter_complex "[0][1]xfade=transition=fade:duration=0.4:offset=5.6[a];\
[a][2]xfade=transition=fade:duration=0.4:offset=11.2[b];\
[b][3]xfade=transition=fade:duration=0.4:offset=17.8,fps=30,format=yuv420p[v]" \
    -map "[v]" -map 4:a -shortest -c:v libx264 -profile:v high -preset slow -crf 16 \
    -c:a aac -b:a 256k -movflags +faststart "$OUT/$lang.mp4"
  echo "$OUT/$lang.mp4"
done
fi

narrate ko ko-KR-SunHiNeural "봄동을 키우고, 황금 봄동도 수확해요!" "손님으로 북적이는 나만의 봄동 가게!" \
  "피버 타임엔 세 배로 팔아요!" "비, 눈, 꽃잎 날리는 하루. 봄동 타이쿤!"
narrate en en-US-JennyNeural "Grow cabbages, and harvest golden ones!" "Run your own cabbage shop, packed with customers!" \
  "Fever time: sell at triple the price!" "Rain, snow, and blossoms. Bomdong Tycoon!"
rm -rf "$WORK"
