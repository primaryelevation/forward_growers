# Forward Growers

A two-level landscape farming game for Android and iOS. Plow the soil, plant
wheat, water it, then harvest when ready. Use the hammer on a plot with a mole
before it destroys the crop.

## Run locally

Use a Flutter SDK with Dart 3.13.2 or newer in the Dart 3 series. Start an
Android emulator or iOS simulator, or connect a device.

```sh
flutter pub get
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with an ID listed by `flutter devices`. A physical iOS
device requires a development team configured in Xcode.

## Play the prototype

Harvest three crops in Level 1 and five in Level 2. Each level gives you two
minutes of active play. The farm shop between levels sells a permanent corn
unlock and up to two extra plots. You can start Level 2 without a purchase.
Failed attempts preserve earned cash, so retries can fund both plot upgrades
even though a perfect first attempt earns only $12.

Farm progress lasts for the current app session.

## Validate

```sh
dart format .
flutter analyze
flutter test
```
