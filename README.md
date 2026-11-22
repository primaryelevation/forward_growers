# Forward Growers

A 32-level landscape farming game for Android and iOS. Plow the soil, plant
wheat, water it, then harvest when ready. Hammer a mole within two seconds to
save the crop. After that, hammer it to clear the damaged plot, then plow again.

## Run locally

Use a Flutter SDK with Dart 3.13.2 or newer in the Dart 3 series. Start an
Android emulator or iOS simulator, or connect a device.

```sh
flutter pub get
flutter devices
flutter run --debug -d DEVICE_ID
```

Replace `DEVICE_ID` with an ID listed by `flutter devices`. A physical iOS
device requires a development team configured in Xcode.

## Play and preview

Harvest 3 crops in Level 1, then 2 more per level through 65 in Level 32.
Each round gives you two minutes of active play. Every extra plot costs $20,
and you can own up to 256. Corn is a permanent unlock. Cash, purchased plots,
and unlocked crops carry into later rounds and retries within the app session.

In a debug build, select **Preview 16 × 16 Field** from the opening
instructions, pause overlay, or results screen. The preview has its own field
and a fixed clock for inspecting sample crop stages. Pinch to zoom and drag to
pan. Tap **Full Field** to reset the view and **Exit Preview** to return to
your farm.

## Validate

```sh
dart format lib test
flutter analyze
flutter test
```
