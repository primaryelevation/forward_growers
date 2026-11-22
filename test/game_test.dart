import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/progress.dart';

class MemoryStore implements ProgressStore {
  FarmProgress? saved;
  Completer<void>? writeGate;
  bool rejectWrites = false;

  @override
  Future<FarmProgress?> load(GameBalance balance) async => saved;

  @override
  Future<void> save(FarmProgress progress) async {
    if (writeGate case final gate?) await gate.future;
    if (rejectWrites) throw const FileSystemException('Write failed');
    saved = progress;
  }
}

class TestFarm {
  TestFarm({
    this.balance = const GameBalance(spawnChance: 0),
    FarmProgress? progress,
    ProgressStore? store,
  }) {
    farm = Farm(
      progress: progress ?? FarmProgress.fresh(balance),
      balance: balance,
      store: store ?? MemoryStore(),
      clock: Clock(
        () => DateTime.fromMicrosecondsSinceEpoch(time.inMicroseconds),
      ).stopwatch(),
    );
    addTearDown(farm.dispose);
  }

  final GameBalance balance;
  late final Farm farm;
  Duration time = Duration.zero;

  void advance(Duration span) {
    time += span;
    farm.tick();
  }

  Future<void> act(Tool tool, [int index = 0]) {
    farm.select(tool);
    return farm.tap(index);
  }

  Future<void> tend([int index = 0]) async {
    await act(farm.level.prepare, index);
    await act(farm.level.tend, index);
  }

  Future<void> produce([int index = 0]) async {
    await tend(index);
    await act(farm.level.beginProduction, index);
    advance(farm.level.production!.growth);
    await act(farm.level.collect, index);
  }

  Future<void> complete() async {
    final objective = farm.level.objective;
    for (var i = 0; i < objective; i++) {
      await produce();
    }
  }
}

void main() {
  const balance = GameBalance.standard;

  test(
    'activities are reused across generated expansions and safely validated',
    () {
      expect(Activity.values.length, 10);
      expect(balance.level(2, 1).number, 11);
      expect(balance.level(2, 4).number, 14);
      expect(balance.level(10, 1).number, 91);
      expect(balance.level(10, 10).number, 100);
      expect(balance.level(11, 1).number, 101);
      expect(balance.level(1, 1).objective, 3);
      expect(balance.level(1, 2).objective, 4);
      expect(balance.level(1, 3).objective, 5);
      expect(balance.level(1, 4).objective, 4);
      expect(balance.level(2, 1).objective, 5);
      expect(balance.level(2, 4).objective, 6);
      expect(balance.level(10, 1).objective, 21);
      expect(const GameBalance(objectiveGrowth: 3).level(2, 1).objective, 6);
      expect(balance.level(11, 1).activity, balance.level(1, 1).activity);
      expect(balance.level(1, 9).playable, true);
      expect(() => balance.level(0, 1), throwsRangeError);
      expect(() => balance.level(1, 0), throwsRangeError);
      expect(() => balance.level(1, 11), throwsRangeError);
    },
  );

  test('capacity limits and whole-dollar scaling are generated', () {
    for (final (expansion, field, trees) in [
      (1, 8, 4),
      (2, 12, 6),
      (10, 44, 22),
    ]) {
      expect(balance.capacityLimit(Capacity.field, expansion), field);
      expect(balance.capacityLimit(Capacity.orchard, expansion), trees);
    }
    expect(balance.price(Capacity.field, 1), BigInt.from(20));
    expect(balance.price(Capacity.orchard, 1), BigInt.from(30));
    expect(balance.price(Capacity.field, 2), BigInt.from(27));
    expect(balance.price(Capacity.orchard, 2), BigInt.from(41));
    expect(balance.price(Capacity.field, 3), BigInt.from(36));
    expect(balance.level(2, 1).unitValue, BigInt.from(3));
    expect(balance.level(10, 1).unitValue, BigInt.from(15));
    expect(balance.completionBonus(Mode.timed, BigInt.from(6)), BigInt.two);
    expect(balance.level(100, 1).unitValue! > BigInt.from(1000000000), true);
  });

  test(
    'planting order and configured growth earn once under rapid taps',
    () async {
      final store = MemoryStore();
      final test = TestFarm(
        store: store,
        balance: const GameBalance(
          wheatGrowth: Duration(seconds: 4),
          spawnChance: 0,
        ),
      );
      final farm = test.farm..start(Activity.wheat);
      await test.act(Tool.plant);
      expect(farm.plots.first, emptyPlot);
      expect(farm.feedback, 'Plow first.');
      await test.act(Tool.plow);
      expect(farm.plots.first.stage, Stage.prepared);
      await test.act(Tool.water);
      expect(farm.plots.first.stage, Stage.prepared);
      await test.act(Tool.plant);
      expect(farm.plots.first.stage, Stage.tended);
      await test.act(Tool.water);
      expect(farm.plots.first.stage, Stage.growing);
      test.advance(const Duration(seconds: 3));
      expect(farm.plots.first.stage, Stage.growing);
      test.advance(const Duration(seconds: 1));
      expect(farm.plots.first.stage, Stage.ready);
      store.writeGate = Completer<void>();
      final first = test.act(Tool.harvest);
      await farm.tap(0);
      expect(farm.cash, BigInt.zero);
      store.writeGate!.complete();
      await first;
      await farm.tap(0);
      expect(farm.cash, farm.level.unitValue);
      expect(farm.harvested, 1);
      expect(farm.plots.first, emptyPlot);
    },
  );

  test('sequential unlocks, orchard cycle, shared plots and replay', () async {
    final test = TestFarm(
      progress: FarmProgress.fresh(balance).copyWith(fieldPlots: 5),
    );
    final farm = test.farm;
    expect(farm.canPlay(Activity.wheat), true);
    expect(farm.canPlay(Activity.corn), false);
    for (final activity in [
      Activity.wheat,
      Activity.corn,
      Activity.carrots,
      Activity.apples,
    ]) {
      expect(farm.canPlay(activity), true);
      farm.start(activity);
      expect(farm.plots.length, activity == Activity.apples ? 2 : 5);
      if (activity == Activity.apples) {
        await test.act(Tool.fertilize);
        expect(farm.plots.first, emptyPlot);
        await test.act(Tool.prune);
        expect(farm.plots.first.stage, Stage.prepared);
        await test.act(Tool.fertilize);
        expect(farm.plots.first.stage, Stage.tended);
        await test.act(Tool.water);
        test.advance(farm.level.production!.growth);
        expect(farm.plots.first.stage, Stage.ready);
        final before = farm.cash;
        await test.act(Tool.pick);
        await farm.tap(0);
        expect(farm.cash - before, farm.level.unitValue);
        expect(farm.harvested, 1);
        expect(farm.plots.first, emptyPlot);
        expect(farm.progress.appleTrees, 2);
        for (var i = 1; i < farm.level.objective; i++) {
          await test.produce();
        }
      } else {
        await test.complete();
      }
      expect(farm.result.completed, true);
      expect(farm.result.replay, false);
      farm.returnToMap();
    }
    expect(farm.progress.highestUnlocked, 5);
    expect(farm.canPlay(Activity.dairy), true);
    farm.start(Activity.market);
    expect(farm.phase, Phase.map);
    farm.start(Activity.wheat);
    await test.complete();
    expect(farm.result.replay, true);
    expect(farm.progress.completed, {1, 2, 3, 4});
  });

  test(
    'capacity purchases serialize, roll back on failure and retain ownership',
    () async {
      final store = MemoryStore();
      final test = TestFarm(
        store: store,
        progress: FarmProgress.fresh(balance)
            .copyWith(money: BigInt.from(80), fieldPlots: 7),
      );
      final farm = test.farm;
      store.writeGate = Completer<void>();
      final pending = farm.buy(Capacity.field);
      await farm.buy(Capacity.orchard);
      await farm.buy(Capacity.field);
      store.writeGate!.complete();
      await pending;
      expect(farm.progress.fieldPlots, 8);
      expect(farm.progress.appleTrees, 2);
      expect(farm.cash, BigInt.from(60));
      expect(farm.canBuy(Capacity.field), false);
      store.rejectWrites = true;
      await farm.buy(Capacity.orchard);
      expect(farm.progress.appleTrees, 2);
      expect(farm.cash, BigInt.from(60));
      store.rejectWrites = false;
      await farm.buy(Capacity.orchard);
      await farm.buy(Capacity.orchard);
      await farm.buy(Capacity.orchard);
      expect(farm.progress.appleTrees, 4);
      expect(farm.cash, BigInt.zero);
      final futureProgress = store.saved!.copyWith(expansion: 2);
      final next = TestFarm(progress: futureProgress).farm;
      expect(next.progress.fieldPlots, 8);
      expect(next.progress.appleTrees, 4);
      expect(next.canBuy(Capacity.field), false);
      await next.buy(Capacity.field);
      expect(next.cash, BigInt.zero);
      expect(next.progress.fieldPlots, 8);
    },
  );

  test('timed success pays the rounded attempt bonus; expiry retains only earnings', () async {
    final test = TestFarm();
    final farm = test.farm;
    expect(farm.mode, Mode.relaxed);
    await farm.setMode(Mode.timed);
    farm.start(Activity.wheat);
    expect(farm.remaining, 120);
    await farm.setMode(Mode.relaxed);
    expect(farm.mode, Mode.timed);
    await test.produce();
    test.advance(balance.timedDuration);
    expect(farm.result.completed, false);
    expect(farm.result.bonus, BigInt.zero);
    expect(farm.cash, BigInt.two);
    expect(farm.isComplete(Activity.wheat), false);
    farm.returnToMap();
    farm.start(Activity.wheat);
    await test.complete();
    expect(farm.result.bonus, BigInt.two);
    expect(farm.cash, BigInt.from(10));
    expect(farm.isComplete(Activity.wheat), true);
  });

  test(
    'relaxed hazard filters visible active targets and blocks until resolved',
    () async {
      const rules = GameBalance(spawnChance: 1);
      final test = TestFarm(balance: rules);
      final farm = test.farm..start(Activity.wheat);
      expect(farm.remaining, isNull);
      await test.tend(0);
      await test.tend(1);
      farm.targetVisible = (index) => index != 1;
      test.advance(rules.safePeriod - const Duration(milliseconds: 1));
      await test.act(Tool.water);
      expect(farm.hazard, isNull);
      test.advance(const Duration(milliseconds: 1));
      expect(farm.hazard?.index, 0);
      await test.act(Tool.harvest);
      test.advance(rules.cooldown);
      expect(farm.hazard?.index, 0);
      expect(farm.plots.first.stage, Stage.growing);
      await test.act(Tool.water, 1);
      farm.targetVisible = (_) => true;
      await test.act(Tool.hammer);
      expect(farm.hazard, isNull);
      test.advance(rules.cooldown - const Duration(milliseconds: 1));
      expect(farm.plots.first.stage, Stage.ready);
      expect(farm.plots[1].stage, Stage.ready);
      expect(farm.hazard, isNull);
      await test.tend(2);
      test.advance(const Duration(milliseconds: 1));
      expect(farm.hazard?.index, 2);
    },
  );

  for (final (activity, expected) in [
    (Activity.wheat, Stage.bare),
    (Activity.corn, Stage.prepared),
    (Activity.carrots, Stage.prepared),
    (Activity.apples, Stage.bare),
  ]) {
    test(
      '${activity.label} timed hazard setback preserves permanent capacity',
      () async {
        const rules = GameBalance(spawnChance: 1);
        final test = TestFarm(
          balance: rules,
          progress: FarmProgress.fresh(rules)
              .copyWith(mode: Mode.timed, completed: {1, 2, 3}),
        );
        final farm = test.farm..start(activity);
        final owned = farm.plots.length;
        await test.tend();
        test.advance(rules.safePeriod);
        expect(farm.hazard?.index, 0);
        final beforeDeadline =
            rules.responseWindow - const Duration(milliseconds: 1);
        test.advance(beforeDeadline);
        await test.act(Tool.water);
        expect(farm.hazard?.index, 0);
        expect(farm.plots.first.stage, Stage.tended);
        test.advance(const Duration(milliseconds: 1));
        expect(farm.hazard, isNull);
        expect(farm.plots.first.stage, expected);
        expect(farm.plots.length, owned);
        expect(farm.cash, BigInt.zero);
        expect(farm.harvested, 0);
        await test.tend(1);
        test.advance(rules.cooldown);
        expect(farm.hazard?.index, 1);
        await test.act(farm.level.production!.hazard.tool, 1);
        expect(farm.hazard, isNull);
        expect(farm.plots[1].stage, Stage.tended);
      },
    );
  }

  test('completion stops hazards while clearing an already active one', () async {
    const rules = GameBalance(spawnChance: 1);
    final test = TestFarm(balance: rules);
    final farm = test.farm..start(Activity.wheat);
    for (var i = 0; i < farm.level.objective - 1; i++) {
      // Exclude plots from hazard eligibility while building up the objective.
      farm.targetVisible = (_) => false;
      await test.produce();
    }
    farm.targetVisible = (index) => index == 1;
    await test.tend(1);
    test.advance(rules.spawnInterval);
    expect(farm.hazard?.index, 1);
    await test.produce();
    expect(farm.phase, Phase.results);
    expect(farm.hazard, isNull);
    test.advance(rules.cooldown + rules.spawnInterval);
    expect(farm.hazard, isNull);
  });

  test(
    'atomic file saves survive relaunch and abandon only the active attempt',
    () async {
      final dir = await Directory.systemTemp.createTemp('forward-growers-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File.fromUri(dir.uri.resolve('farm-v1.json'));
      final store = FileProgressStore(file);
      expect(await store.load(balance), isNull);
      final initial = FarmProgress.fresh(balance);
      expect(
        (
          initial.money,
          initial.fieldPlots,
          initial.appleTrees,
          initial.mode,
          initial.highestUnlocked,
        ),
        (BigInt.zero, 4, 2, Mode.relaxed, 1),
      );
      final test = TestFarm(
        store: store,
        progress: initial.copyWith(money: BigInt.from(99)),
      );
      final farm = test.farm;
      await farm.buy(Capacity.field);
      await farm.buy(Capacity.orchard);
      await farm.setMode(Mode.timed);
      farm.start(Activity.wheat);
      await test.produce();
      final restored = (await FileProgressStore(file).load(balance))!;
      expect(restored.encode(), farm.progress.encode());
      expect(restored.fieldPlots, 5);
      expect(restored.appleTrees, 3);
      expect(restored.mode, Mode.timed);
      expect(restored.money, BigInt.from(51));
      final relaunched = TestFarm(store: store, progress: restored);
      expect(relaunched.farm.phase, Phase.map);
      expect(relaunched.farm.isComplete(Activity.wheat), false);
      relaunched.farm.start(Activity.wheat);
      expect(relaunched.farm.harvested, 0);
      await relaunched.complete();
      final finished = (await store.load(balance))!;
      expect(finished.completed, {1});
      expect(finished.highestUnlocked, 2);
      expect(finished.money, BigInt.from(59));
      expect(await File('${file.path}.pending').exists(), false);
    },
  );

  test(
    'prototype-shaped, corrupt, incomplete and future saves are rejected',
    () {
      final valid = FarmProgress.fresh(balance).encode();
      for (final json in [
        '{',
        '{"level":3,"cash":99}',
        '{"version":1}',
        valid.replaceFirst('"version":3', '"version":99'),
        valid.replaceFirst('"money":"0"', '"money":"-1"'),
        valid.replaceFirst('"money":"0"', '"money":"0x10"'),
        valid.replaceFirst('"fieldPlots":4', '"fieldPlots":99'),
        valid.replaceFirst('"completed":[]', '"completed":[2]'),
      ]) {
        expect(() => FarmProgress.decode(json, balance), throwsFormatException);
      }
    },
  );
}
