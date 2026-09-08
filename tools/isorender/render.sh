#!/usr/bin/env bash
#
# Render one asset through the isometric rig and report its geometry.
#
#   tools/isorender/render.sh wall_shop_left
#   tools/isorender/render.sh calibrate                    # verifies the rig itself
#   tools/isorender/render.sh wall_shop_left 3             # explicit render scale
#   tools/isorender/render.sh wall_shop_left 3 --install   # also drop it into the app
#
# Requires Blender: brew install --cask blender

set -euo pipefail

ASSET="${1:?usage: render.sh <asset> [scale] [--install]}"
SCALE="${2:-3}"
INSTALL="${3:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"

if [[ ! -x "$BLENDER" ]]; then
  echo "Blender not found at $BLENDER — brew install --cask blender" >&2
  exit 1
fi

"$BLENDER" -b -P "$HERE/rig.py" -- --asset "$ASSET" --scale "$SCALE" | grep -E '^\[isorender\]' || true
python3 "$HERE/postprocess.py" --asset "$ASSET" --scale "$SCALE"

if [[ "$INSTALL" == "--install" ]]; then
  python3 "$HERE/install.py" --asset "$ASSET"
fi
