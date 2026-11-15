#!/bin/bash
# Raw App Store captures from the simulator, driven by the DEBUG launch arguments in
# Sources/App/Dot/DotDebug.swift. Needs a Debug build installed on the device:
#
#   tools/screenshots/capture.sh [device-udid]     # default: iPhone 18 Pro Max (6.9", 1320x2868)
#   python3 tools/screenshots/compose.py
set -euo pipefail

DEVICE=${1:-39D7367E-86EA-41EA-8AC9-48F907B48F02}
BUNDLE=com.leesam.bomdongtycoon
RAW="$(cd "$(dirname "$0")" && pwd)/raw"

xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

# shot <lang> <name> <seconds to settle> <launch arguments...>
shot() {
  local lang=$1 name=$2 wait=$3; shift 3
  local locale=ko_KR shop="봄동 가게"
  if [ "$lang" = en ]; then locale=en_US; shop="Bomdong"; fi
  mkdir -p "$RAW/$lang"
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" -dotNoAds -AppleLanguages "($lang)" -AppleLocale "$locale" \
    -dotShopName "$shop" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$DEVICE" screenshot "$RAW/$lang/$name.png" 2>/dev/null
  echo "$lang/$name"
}

for lang in ko en; do
  shot "$lang" late_noon     14 -dotSeed late -dotPhase noon
  shot "$lang" late_fever    14 -dotSeed late -dotPhase dusk -dotFever -dotTips
  shot "$lang" late_staff    12 -dotSeed late -dotPhase noon -dotSheet staff
  shot "$lang" late_upgrades 12 -dotSeed late -dotPhase noon -dotSheet upgrades
  shot "$lang" mid_petals    14 -dotSeed mid -dotPhase morning -dotWeather petals -dotGolden
  # -dotAdsGrant marks the rewarded placement ready, so the x2 button shows instead of "ad loading".
  shot "$lang" late_offline  12 -dotSeed late -dotPhase night -dotSheet offline -dotAdsGrant
  shot "$lang" late_snow     14 -dotSeed late -dotPhase night -dotWeather snow
done
