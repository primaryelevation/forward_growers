# Forward Growers

A landscape farming game for Android and iOS. The farm map opens wheat, corn,
carrots, the apple orchard, Dairy Barn, Chicken Coop, Sheep Pasture, and Bee Yard
in sequence, followed by Farmers Market and County Fair. Completed activities
can be replayed, including activities in earlier expansions.

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
- Dairy and sheep use Feed, Water, Brush, then Milk or Shear. Chickens use Feed,
  Water, Clean Nest, and Collect Eggs. Bees use Plant Flowers, Water, Smoke Hive,
  and Collect Honey. Each space can repeat its cycle after collection.
- Buy more capacity from an unlocked activity panel. Plot purchases apply to
  all field activities. Trees, cow stalls, chicken nests, sheep spaces, and
  beehives are purchased separately.
- Market and Fair share permanent order tables. Take an order, use Gather
  Products once per listed item, then pack, deliver, and collect payment. Fair
  orders also need weighing before packing.
- The first Fair completion earns a permanent Blue Ribbon. Open **Expand** on
  the map to buy the next expansion. Use **Choose Expansion** to return to an
  earlier map.
- Change modes from the map. Relaxed Mode has no timer and hazards block their
  target until cleared. Timed Challenge has a two-minute timer, activity-specific
  hazard setbacks, and a completion bonus. Expiring keeps earned product money.

## Saves and debug tools

The old prototype held progress in memory. This release starts with a new,
versioned local save. Versions 1 and 2 keep their permanent progress and gain
one order table. Version 1 also gains the starting producer spaces. The next
successful save writes version 3 to the same file, with completions by absolute
level and the Blue Ribbon retained through Fair completion history. The wallet
is stored as a decimal whole-dollar string.
Unreadable or unsupported saves are backed up beside the active file before a
fresh farm opens. Committed earnings, purchases, mode, and progression persist
across restarts. An in-progress attempt starts over after relaunch.

In a debug build, the activity panel offers a confirmed save reset, an isolated
Expansion 2 preview with all ten activities ready to play, and the
isolated 16 × 16 field preview. These controls are absent from release builds.

## Validate

```sh
dart format lib test
flutter analyze
flutter test
```
