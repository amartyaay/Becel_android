# Becel

Becel is an Android-first, local-first health companion for Fitbit Air users. It is designed to make available activity and wellness data easier to inspect while clearly separating imported values from Becel estimates.

## Current state

Today, Health (heart, sleep, recovery, strain, energy, biology), Trends, and Data Sources read Health Connect on-device and display a health record only when it was written by the Fitbit app or Google Health and, when device metadata is present, identifies Fitbit Air. On the tested paired Air, Fitbit-app steps and heart-rate records carry no device metadata, so the Fitbit app source is accepted for them; records naming another device and every other source app are excluded. Steps are summed from accepted records only. Preview values are excluded from live screens; Becel does not upload these records. Health Connect device metadata is optional and supplied by the writing app, so a match is not cryptographic proof of the physical device. On the target handset (October 2026), the Air's synced types include steps, heart rate (high-resolution samples), sleep with stages, exercise, resting heart rate, HRV, respiratory rate, and skin temperature; SpO2 and VO2 max were absent, and distance/floors/active-calorie/basal-metabolic-rate records remain unconfirmed. Charts and score estimates stay empty until suitable Air-matched history is available, and every calculated value is labeled as a Becel estimate. Debug builds include an experimental direct Bluetooth haptic test in Settings, based on the community Golden Gate bridge; it waits for the Air to advertise, connects for the test, then closes Becel's connection so Google Health can reconnect. The Air only advertises while no other app holds its BLE connection, so the band must first be released (for example, revoke the health app's Nearby-devices permission or force-stop it), and handoff has not yet been validated on this Becel build with a physical Air. The bridge is absent from release builds. There is no persistent local import or export yet.

See [GOAL.md](GOAL.md) for the product scope, data-access feasibility gates, technical plan, and acceptance criteria.

## Run locally

Requirements: Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`, Android SDK, and an Android device or emulator.

The experimental haptic test also needs Android SDK platform 36, NDK, CMake 3.22.1, and network access to resolve the debug-only Fitbit GATT dependency. The first debug build compiles the included Golden Gate native transport. Its upstream Apache license and notices are preserved under `android/fitbit_air_bridge/`. The bridge source is based on [paceaitian/fitbit-air-notification-bridge](https://github.com/paceaitian/fitbit-air-notification-bridge). The experiment supports arm64 Android devices, is only available in `flutter run --debug` builds, and has not been device-validated in Becel.

```sh
flutter pub get
flutter run
```

## Product principles

- Preserve and label source data; keep estimates and annotations separate.
- Show data freshness and missing-data states.
- Keep the initial product local-first.
- Do not present example values as live measurements or health estimates as medical advice.
- Confirm actual Fitbit Air data availability on the target device before building dependent features.
- The debug-only Air haptic experiment waits for the Air to advertise, toggles the haptics setting briefly, verifies restoration, then closes its BLE connection. It cannot force Google Health to release the band or guarantee that Health reconnects; do not treat it as a supported or safety-critical alert path.
