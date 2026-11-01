# Android app

This Flutter client is for the invitation-only Compliance Navigator pilot. It connects to the hosted REST API at `https://compliance-pilot.ms777.ru/api/v1/`; this repository does not contain the server implementation, service credentials, customer records or signing keys.

The app lets a user work with organisation details, a questionnaire, tasks, documents and reports. Access to company records follows the user's organisation membership. Enter only information you are allowed to process. The server-side assistant uses the owner's subscription; personal data must not be sent to it.

The current signed pilot APK is available from the [Android download page](https://compliance-pilot.ms777.ru/android/). Updates can also be checked in **Settings → App update**. Android asks the user to confirm installation. The app is not distributed through Google Play.

For the pinned toolchain, local checks and build instructions, see the [development guide](../docs/development.md). The [API snapshot](../docs/api/openapi-v1.json) and [design tokens](../docs/android-design-green-v1.tokens.json) describe the client contract and visual theme.

Suggestions and reports are welcome. Please use fictional examples and leave out real people's information, passwords and tokens when [opening an issue](https://github.com/ub3dqy/ComplianceNavigato-Android/issues/new).
