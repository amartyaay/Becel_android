# Becel

Becel is an Android-first, local-first health companion for Fitbit Air users. It is designed to make available activity and wellness data easier to inspect while clearly separating imported values from Becel estimates.

## Current state

Today, Activity, and Data Sources can request read-only Health Connect access and display available steps, heart-rate samples, sleep sessions, and workouts. Records are read on-device when those screens refresh; Becel does not upload them. Fitbit Air data provenance still needs to be verified on a paired target device. Debug builds include an experimental direct Bluetooth haptic test in Settings, based on the community Golden Gate bridge; it is absent from release builds and has not yet been validated on this Becel build with a physical Air. Trends and some settings remain previews, and there is no persistent local import or export yet.

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
- The debug-only Air haptic experiment may interrupt Google Health syncing. It toggles the band haptics setting briefly and verifies restoration; do not treat it as a supported or safety-critical alert path.
