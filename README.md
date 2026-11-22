# Forward Growers

A landscape farming game for Android and iOS. The farm map opens wheat, corn,
carrots, and the apple orchard in sequence. Completed activities can be replayed.
The other six map locations are previews of future activities.

## Run locally

Use Flutter with Dart 3.13.2 or newer in the Dart 3 series. Start an Android
emulator or iOS simulator, or connect a device, then run:

```sh
flutter pub get
flutter devices
flutter run --debug -d DEVICE_ID
```

Replace `DEVICE_ID` with an ID from `flutter devices`. A physical iOS device
requires a development team configured in Xcode.

## Play

- Field activities share four starting plots. Select Plow, the active crop,
  Water, then Harvest once the crop is ready.
- The orchard starts with two separate trees. Select Prune, Fertilize, Water,
  then Pick once the fruit is ready.
- Buy more capacity from an unlocked activity panel. Plot purchases apply to
  all field activities, and tree purchases apply to the orchard.
- Change modes from the map. Relaxed Mode has no timer and hazards block their
  target until cleared. Timed Challenge has a two-minute timer, activity-specific
  hazard setbacks, and a completion bonus. Expiring keeps earned product money.

## Saves and debug tools

The old prototype held progress in memory. This release starts with a new,
versioned local save. The wallet is stored as a decimal whole-dollar string.
Unreadable or unsupported saves are backed up beside the active file before a
fresh farm opens. Committed earnings, purchases, mode, and progression persist
across restarts. An in-progress attempt starts over after relaunch.

In a debug build, the activity panel offers a confirmed save reset, an isolated
Expansion 2 preview with the first four activities ready to play, and the
isolated 16 × 16 field preview. These controls are absent from release builds.

## Validate

```sh
dart format lib test
flutter analyze
flutter test
```
