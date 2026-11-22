import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/progress.dart';

import 'game_test.dart' show TestFarm;

const _producers = [
  (
    Activity.dairy,
    Capacity.dairy,
    (Tool.feed, Tool.water, Tool.brush, Tool.milk),
    4,
    4,
    6,
    Tool.lasso,
  ),
  (
    Activity.chickens,
    Capacity.chickens,
    (Tool.feed, Tool.water, Tool.cleanNest, Tool.collectEggs),
    5,
    4,
    4,
    Tool.farmDog,
  ),
  (
    Activity.sheep,
    Capacity.sheep,
    (Tool.feed, Tool.water, Tool.brush, Tool.shear),
    4,
    5,
    7,
    Tool.shepherdsCrook,
  ),
  (
    Activity.bees,
    Capacity.bees,
    (Tool.plantFlowers, Tool.water, Tool.smokeHive, Tool.collectHoney),
    5,
    5,
    6,
    Tool.noisemaker,
  ),
];

void main() {
  const balance = GameBalance.standard;
  const hazardBalance = GameBalance(spawnChance: 1);
  final unlocked = FarmProgress.fresh(balance)
      .copyWith(completed: {1, 2, 3, 4, 5, 6, 7});

  test(
    'producers unlock in order, scale, and repeat using their starting spaces',
    () async {
      final test = TestFarm(
        progress: FarmProgress.fresh(balance).copyWith(completed: {1, 2, 3, 4}),
      );
      final farm = test.farm;
      for (final (activity, capacity, actions, target, wait, pay, emergency)
          in _producers) {
        final number = activity.index + 1;
        final expanded = balance.level(2, number);
        expect(expanded.number, number + Activity.values.length);
        expect(expanded.objective, target + balance.objectiveGrowth);
        expect(expanded.unitValue, BigInt.from((5 * pay + 2) ~/ 4));
        expect(balance.price(capacity, 2), BigInt.from(47));
        expect(
          [
            for (final n in [1, 2, 10]) balance.capacityLimit(capacity, n),
          ],
          [4, 6, 22],
        );
        if (activity != Activity.bees) {
          expect(farm.canPlay(Activity.values[number]), false);
        }
        expect(farm.canPlay(activity), true);
        farm.start(activity);
        final level = farm.level;
        expect(level.production!.actions, actions);
        expect(level.production!.hazard.tool, emergency);
        expect(level.production!.growth, Duration(seconds: wait));
        expect(level.objective, target);
        expect(level.unitValue, BigInt.from(pay));
        expect(farm.plots.length, 2);
        final before = farm.cash;
        await test.act(level.collect);
        await test.act(level.beginProduction);
        expect(farm.plots.first, emptyPlot);
        for (var collected = 0; collected < target;) {
          final batch = (target - collected).clamp(1, farm.plots.length);
          for (var index = 0; index < batch; index++) {
            await test.tend(index);
            expect(farm.plots[index].stage, Stage.tended);
            await test.act(level.collect, index);
            expect(farm.plots[index].stage, Stage.tended);
            await test.act(level.beginProduction, index);
            await test.act(level.beginProduction, index);
          }
          const boundary = Duration(milliseconds: 1);
          test.advance(level.production!.growth - boundary);
          expect(
            farm.plots.take(batch).map((plot) => plot.stage),
            everyElement(Stage.growing),
          );
          await test.act(level.collect);
          expect(farm.harvested, collected);
          test.advance(boundary);
          final first = test.act(level.collect);
          await farm.tap(0);
          await first;
          for (var index = 1; index < batch; index++) {
            await test.act(level.collect, index);
          }
          collected += batch;
          expect(farm.harvested, collected);
          expect(farm.plots, everyElement(emptyPlot));
        }
        expect(farm.result.completed, true);
        expect(farm.result.replay, false);
        expect(farm.cash - before, BigInt.from(target * pay));
        farm.returnToMap();
      }
      expect(farm.progress.highestUnlocked, 9);
      expect(farm.canPlay(Activity.market), false);
      expect(farm.canPlay(Activity.fair), false);
      farm.start(Activity.dairy);
      await test.complete();
      expect(farm.result.replay, true);
      expect(farm.progress.completed.length, 8);
    },
  );

  for (final (activity, capacity, _, _, _, _, emergency) in _producers) {
    test(
      '${activity.label} relaxed hazard preserves work and blocks one space',
      () async {
        final test = TestFarm(balance: hazardBalance, progress: unlocked);
        final farm = test.farm..start(activity);
        const beforeSpawn = Duration(seconds: 1);
        test.advance(hazardBalance.safePeriod - beforeSpawn);
        for (var i = 0; i < 2; i++) {
          await test.tend(i);
          await test.act(farm.level.beginProduction, i);
        }
        farm.targetVisible = (index) => index == 0;
        test.advance(beforeSpawn);
        expect(farm.hazard?.index, 0);
        await test.act(farm.level.collect);
        test.advance(hazardBalance.cooldown);
        expect(farm.hazard?.index, 0);
        expect(farm.plots.first.stage, Stage.growing);
        await test.act(farm.level.collect, 1);
        expect(farm.harvested, 1);
        await test.act(emergency);
        expect(farm.hazard, isNull);
        const boundary = Duration(milliseconds: 1);
        final remaining = farm.level.production!.growth - beforeSpawn;
        test.advance(remaining - boundary);
        expect(farm.plots.first.stage, Stage.growing);
        test.advance(boundary);
        expect(farm.plots.first.stage, Stage.ready);
      },
    );

    test(
      '${activity.label} timed hazard can be cleared or resets one cycle',
      () async {
        final test = TestFarm(
          balance: hazardBalance,
          progress: unlocked.copyWith(mode: Mode.timed),
        );
        final farm = test.farm..start(activity);
        await test.tend(0);
        await test.tend(1);
        farm.targetVisible = (index) => index == 0;
        test.advance(hazardBalance.safePeriod);
        expect(farm.hazard?.index, 0);
        const boundary = Duration(milliseconds: 1);
        test.advance(hazardBalance.responseWindow - boundary);
        await test.act(farm.level.beginProduction);
        expect(farm.hazard?.index, 0);
        await test.act(emergency);
        expect(farm.hazard, isNull);
        expect(farm.plots.first.stage, Stage.tended);
        test.advance(hazardBalance.cooldown);
        expect(farm.hazard?.index, 0);
        test.advance(hazardBalance.responseWindow);
        expect(farm.hazard, isNull);
        expect(farm.plots.first, emptyPlot);
        expect(farm.plots[1].stage, Stage.tended);
        expect(farm.progress.capacity(capacity), 2);
        expect(farm.cash, BigInt.zero);
        expect(farm.harvested, 0);
      },
    );
  }

  test('expiry retains producer earnings and existing completion; exit resets the clock', () async {
    final test = TestFarm(progress: unlocked.copyWith(mode: Mode.timed));
    final farm = test.farm..start(Activity.bees);
    await test.produce();
    final earned = farm.cash;
    await test.tend();
    await test.act(farm.level.beginProduction);
    farm.pause();
    farm.returnToMap();
    test.advance(balance.timedDuration);
    farm.start(Activity.bees);
    expect(farm.remaining, balance.timedDuration.inSeconds);
    expect(farm.plots, everyElement(emptyPlot));
    expect(farm.harvested, 0);
    expect(farm.cash, earned);
    await test.produce();
    test.advance(balance.timedDuration);
    expect(farm.result.completed, false);
    expect(farm.result.bonus, BigInt.zero);
    expect(farm.cash, earned * BigInt.two);
    expect(farm.isComplete(Activity.bees), false);
    farm.returnToMap();
    farm.start(Activity.dairy);
    test.advance(balance.timedDuration);
    expect(farm.result.completed, false);
    expect(farm.isComplete(Activity.dairy), true);
  });

  test('Feature 1 save migrates, keeps crop progress, and persists independent purchases', () async {
    final dir = await Directory.systemTemp.createTemp('producer-save-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File.fromUri(dir.uri.resolve('farm-v1.json'));
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'money': '351',
        'expansion': 1,
        'fieldPlots': 7,
        'appleTrees': 3,
        'mode': 'timed',
        'completed': [1, 2, 3, 4],
        'highestUnlocked': 5,
      }),
    );
    final store = FileProgressStore(file);
    final migrated = (await store.load(balance))!;
    final farm = TestFarm(progress: migrated, store: store).farm;
    expect(farm.canPlay(Activity.dairy), true);
    expect(farm.canPlay(Activity.chickens), false);
    expect(migrated.completed, {1, 2, 3, 4});
    expect(migrated.money, BigInt.from(351));
    expect(migrated.mode, Mode.timed);
    expect(migrated.expansion, 1);
    for (final (_, kind, _, _, _, _, _) in _producers) {
      expect(farm.progress.capacity(kind), 2);
      final purchase = farm.buy(kind);
      await farm.buy(kind);
      await purchase;
      expect(farm.progress.capacity(kind), 3);
      await farm.buy(kind);
      expect(farm.progress.capacity(kind), 4);
      expect(farm.canBuy(kind), false);
    }
    expect(farm.cash, BigInt.from(71));
    farm.start(Activity.dairy);
    expect(farm.plots.length, 4);
    final saved = (await store.load(balance))!;
    expect(saved.encode(), farm.progress.encode());
    expect(
      jsonDecode(await file.readAsString())['version'],
      FarmProgress.schemaVersion,
    );
    expect(saved.fieldPlots, 7);
    expect(saved.appleTrees, 3);
    expect(saved.completed, migrated.completed);
    final expanded = TestFarm(progress: saved.copyWith(expansion: 2)).farm;
    await expanded.buy(Capacity.bees);
    await expanded.buy(Capacity.bees);
    expect(expanded.progress.capacity(Capacity.bees), 5);
    expect(expanded.progress.capacity(Capacity.dairy), 4);
    expect(expanded.cash, BigInt.from(24));
  });
}
