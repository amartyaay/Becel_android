# Becel

Becel is an Android-first, local-first health companion for Fitbit Air users. It is designed to make available activity and wellness data easier to inspect while clearly separating imported values from Becel estimates.

## Current state

Today, Activity, and Data Sources read Health Connect on-device and display a health record only when its source package is Fitbit or Google Health and its device metadata exactly identifies Fitbit Air. Steps are summed from matching records only. Missing or nonmatching metadata, every other source/device, and preview values are excluded from live screens; Becel does not upload these records. Health Connect device metadata is optional and supplied by the writing app, so a match is not cryptographic proof of the physical device. Until the reported Air identity is checked on paired hardware, the app calls it an Air metadata match, not independently verified provenance. Trends remain empty until suitable Air-matched history is available. Debug builds include an experimental direct Bluetooth haptic test in Settings, based on the community Golden Gate bridge; it waits for the Air to advertise, connects for the test, then closes Becel's connection so Google Health can reconnect. Becel cannot force Google Health to release the band, and handoff has not yet been validated on this Becel build with a physical Air. The bridge is absent from release builds. There is no persistent local import or export yet.

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
