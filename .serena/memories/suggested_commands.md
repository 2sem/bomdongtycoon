Useful commands (run from repo root):
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "BomDongTycoon" -destination "generic/platform=iOS Simulator" build` (app build)
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "GameCoreTests" -destination "platform=iOS Simulator,name=iPhone 16" test` (unit tests)
- `xcodebuild -workspace "BomDongTycoon.xcworkspace" -scheme "GameCoreTests" -destination "platform=iOS Simulator,name=iPhone 16" -enableCodeCoverage YES test` (tests with coverage)
- `git status` (check working tree)
- `xcrun simctl list devices` (available simulators)