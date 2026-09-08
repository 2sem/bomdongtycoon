Useful commands (run from repo root):
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "BomDongTycoon" -destination "generic/platform=iOS Simulator" build` (app build)
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "GameCoreTests" -destination "platform=iOS Simulator,name=iPhone 16" test` (unit tests)
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "GameCoreTests" -destination "platform=iOS Simulator,name=iPhone 16" -enableCodeCoverage YES test` (tests with coverage)
- `git status` (check working tree)
- `xcrun simctl list devices` (available simulators)
- `tools/isorender/render.sh calibrate` (verify the sprite render rig; must print CALIBRATION PASS)
- `tools/isorender/render.sh wall_shop_left` (render a sprite from its asset spec, trim it, print its measurement table — see tools/isorender/README.md; needs `brew install --cask blender`)