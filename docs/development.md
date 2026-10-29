# Android development

[English overview](../README.md) · [Русское описание](../README.ru.md)

This checkout contains the client and client tests. It does not start a server. The installed app connects to the existing invitation-only pilot; local unit and visual tests use synthetic responses.

## Toolchain

The Windows setup uses these project pins:

- Flutter stable: the exact version in [`mobile/.flutter-version`](../mobile/.flutter-version).
- JDK 17: at least the update in [`mobile/.java-version`](../mobile/.java-version). Set `JAVA_HOME` to that installation.
- Android platform 36, Build Tools 36.1.0, and command-line tools from [`mobile/.android-command-line-tools-version`](../mobile/.android-command-line-tools-version). Point `ANDROID_HOME` to the installed Android SDK. The Flutter pin determines the NDK version used by Gradle.
- Python 3.13 for the coverage checker; it uses only the standard library.

Use a dedicated Flutter installation matching the pin. The commands below assume its `bin` directory and the qualified JDK's `bin` directory are on this terminal's PATH. Check `flutter --version` and `java -version` before running them. The Windows Gradle wrapper uses the client build helpers in `scripts/` to select JDK 17 and reject an older or incomplete installation. Keep `android/local.properties` and all signing configuration local; they are ignored by Git.

## Local checks

From the repository root:

```powershell
cd mobile
flutter pub get --enforce-lockfile
dart run build_runner build
git diff --exit-code -- lib/core/network/api_models.g.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage --concurrency=1
python ../scripts/assert_mobile_coverage.py --lcov coverage/lcov.info --source-root lib
flutter test tool/golden_screenshots_test.dart
flutter test tool/mobile_mockup_acceptance_test.dart
```

The checked-in API snapshot must match both its SHA-256 file and the JSON contract in `docs/api/`. The design-token document is used by visual checks. Neither document contains server implementation.

On Windows, the JDK selector also has focused checks using the built-in Windows PowerShell Pester module. Run from the repository root:

```powershell
powershell -NoProfile -Command "Import-Module Pester -RequiredVersion 3.4.0; Invoke-Pester scripts/tests/android-java.Tests.ps1 -EnableExit"
```

Do not regenerate reference images merely to make a failed test pass. Compare the affected screens before accepting a visual change. Device integration tests are under `mobile/integration_test/`; tests under `mobile/backend_test/` are optional client requests against a separately prepared test service, not server code.

## Debug APK

From `mobile/`, after the checks:

```powershell
$schema = (Get-Content contracts/openapi-v1.sha256 -Raw).Trim()
$revision = (git rev-parse HEAD).Trim()
flutter build apk --debug --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://compliance-pilot.ms777.ru --dart-define=OPENAI_API_ENABLED=false --dart-define=AI_PROVIDER_AUTO_SWITCH=false --dart-define=GIT_COMMIT_SHA=$revision --dart-define=API_SCHEMA_SHA256=$schema
```

The result is `mobile/build/app/outputs/flutter-apk/app-staging-debug.apk`. This is a development build. Its signing identity differs from the distributed pilot, so use a separate test device or emulator. Do not uninstall a working app containing data merely to install a debug build.

For normal installation or updates, use the [signed pilot APK](https://compliance-pilot.ms777.ru/android/).

## Release signing

Release tasks require an external properties file passed to Gradle with `-PCOMPLIANCE_SIGNING_PROPERTIES=<absolute-path>`. It supplies `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Keep that file and its keystore outside this repository; do not put secrets in command arguments, commits, reports or screenshots. The public certificate fingerprint in `mobile/android/pilot-signing-certificate.json` is not a private key.

Publishing a release requires the owner's signing identity and the full release checks. A successful unit test or debug build does not establish physical-device acceptance or permission to publish to Google Play.

## Ideas and fixes

We welcome suggestions, clearer wording and improvements to the app. Open an [issue](https://github.com/ub3dqy/ComplianceNavigato-Android/issues/new) with a short description and steps to reproduce a problem. Use fictional examples and remove information about real people, passwords and tokens.
