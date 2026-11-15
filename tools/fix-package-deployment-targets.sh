#!/bin/sh
# Google's packages declare iOS 12 and Xcode 27 rejects simulator targets below 15, so a plain
# Xcode build fails. Tuist's PackageSettings reaches the source targets but not the resource-bundle
# targets it generates, so the generated package projects are patched instead.
# Run after every `tuist install` / `tuist generate` (the `generate` mise task does both).
set -e
cd "$(dirname "$0")/.."
find Tuist/.build/tuist-derived -name project.pbxproj -print0 |
  xargs -0 sed -i '' -E 's/IPHONEOS_DEPLOYMENT_TARGET = 1[0-6]\.[0-9]+;/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/'
