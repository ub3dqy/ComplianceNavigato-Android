# Android client

- This repository contains the Flutter Android client, its tests, the API contract and design tokens. Keep server implementation, deployment files and server setup instructions in the separate private project.
- Use the stable Flutter version pinned in `mobile/.flutter-version` and JDK 17 at least as recent as `mobile/.java-version`. Do not change another project's SDK.
- Preserve the green-v1 design, organisation isolation, session security, API contract hashes and the requirement to confirm an update before installing it.
- Keep credentials, signing keys, accounts, real company records, personal data and backups outside Git and public test artifacts. Test data and screenshots must be fictional.
- Do not add analytics, advertising, trackers, external AI calls or paid integrations.
- Before completing changes, run formatting, analysis, all client tests, coverage thresholds, both visual test suites, dependency auditing when online, and a secret scan. Report actual results and explicit limitations.
- Follow `docs/development.md`. Release keys are supplied separately; a debug build is for development and cannot replace the signed pilot update.
