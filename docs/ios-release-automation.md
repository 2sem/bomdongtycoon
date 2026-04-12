# iOS Release Automation

This repo includes a manual GitHub Actions workflow for uploading `BomDongTycoon` builds to TestFlight or submitting them to App Store review.

## What It Does

- Runs only with `workflow_dispatch`
- Installs Tuist from `mise.toml`
- Regenerates `BomDongTycoon.xcworkspace`
- Imports a distribution certificate and provisioning profile from base64 secrets
- Uses Fastlane to switch the app target to manual signing and increment the build number
- Archives and exports an IPA
- Uploads to TestFlight or submits the binary for App Store review

## Required GitHub Secrets

- `APPLE_TEAM_ID`: Apple Developer team ID
- `IOS_CERT_P12_BASE64`: base64-encoded Apple Distribution `.p12`
- `IOS_CERT_P12_PASSWORD`: password for the `.p12`
- `IOS_PROFILE_BASE64`: base64-encoded App Store provisioning profile
- `IOS_KEYCHAIN_PASSWORD`: password used for the temporary CI keychain
- `ASC_API_KEY_JSON_BASE64`: base64-encoded App Store Connect API key JSON file used by Fastlane

## Required GitHub Variables

- `IOS_PROFILE_NAME`: provisioning profile name as shown in Apple Developer / Xcode export options

## Triggering The Workflow

1. Open `Actions` in GitHub.
2. Select `Deploy iOS`.
3. Click `Run workflow`.
4. Choose `testflight` or `app_store_review`.
5. Enter the changelog text.
6. Run the workflow.

## Assumptions

- `tuist generate --no-open` creates `BomDongTycoon.xcworkspace` and `BomDongTycoon.xcodeproj` at the repository root.
- The app scheme is `BomDongTycoon`.
- The provisioning profile is an App Store distribution profile that matches `com.leesam.bomdongtycoon`.
- The App Store Connect API key JSON contains the full credentials Fastlane needs for `api_key_path`.

## Local Dry Run Hints

You can validate the generated project and archive assumptions locally before wiring GitHub secrets:

```bash
mise install
tuist install
tuist generate --no-open
xcodebuild -workspace BomDongTycoon.xcworkspace -scheme BomDongTycoon -configuration Release -destination 'generic/platform=iOS' -showBuildSettings >/dev/null
fastlane ios upload
```

The final `fastlane ios upload` command only works after exporting the same environment variables the workflow uses.
