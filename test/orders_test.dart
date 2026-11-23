import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/progress.dart';
import 'package:forward_growers/orders.dart';

import 'game_test.dart' show MemoryStore, TestFarm;

const balance = GameBalance.standard;

Set<int> through(int number) => {for (var i = 1; i <= number; i++) i};

Future<void> gatherProduct(
  TestFarm test,
  Goods product, [
  int index = 0,
]) async {
  test.farm.selectProduct(product);
  await test.farm.tap(index);
}

Future<void> nextStep(TestFarm test, int index) async {
  final order = test.farm.orderAt(index)!;
  final next = order.next(test.farm.level.orders!);
  if (next == Tool.gather) {
    await gatherProduct(test, order.products.firstWhere(order.needs), index);
  } else {
    await test.act(next, index);
  }
}

Future<void> fillOrder(TestFarm test, [int index = 0]) async {
  final farm = test.farm;
  final rules = farm.level.orders!;
  if (farm.orderAt(index) == null) await test.act(Tool.takeOrder, index);
  while (farm.orderAt(index)!.next(rules) != Tool.collectMoney) {
    await nextStep(test, index);
  }
  await test.act(Tool.collectMoney, index);
}

Future<void> finishOrders(TestFarm test) async {
  final target = test.farm.level.objective;
  for (var i = 0; i < target; i++) {
    await fillOrder(test);
  }
}

void main() {
  test(
    'Eggs and Milk must be gathered separately and duplicate quantities count',
    () {
      final rules = balance.orders(Activity.market)!;
      const initial = TableOrder([Goods.eggs, Goods.milk, Goods.eggs]);
      final milk = initial.gather(rules, Goods.milk);
      expect(milk.gather(rules, Goods.milk), same(milk));
      final firstEgg = milk.gather(rules, Goods.eggs);
      expect(firstEgg.requested(Goods.eggs), 2);
      expect(firstEgg.gatheredCount(Goods.eggs), 1);
      expect(firstEgg.next(rules), Tool.gather);
      expect(firstEgg.gather(rules, Goods.corn), same(firstEgg));
      final complete = firstEgg.gather(rules, Goods.eggs);
      expect(complete.next(rules), Tool.pack);
      final setback = complete.setback(rules);
      expect(setback.gatheredProducts, [Goods.milk, Goods.eggs]);
      expect(setback.needs(Goods.eggs), true);
      expect(setback.needs(Goods.milk), false);
    },
  );

  test(
    'market orders use independent tables, controlled templates and one payout',
    () async {
      final store = MemoryStore();
      final starting = FarmProgress.fresh(balance)
          .copyWith(money: BigInt.from(100), completed: through(8));
      final test = TestFarm(progress: starting, store: store);
      final farm = test.farm;
      expect(farm.progress.capacity(Capacity.tables), 1);
      expect(farm.capacityLimit(Capacity.tables), 2);
      expect(farm.canPlay(Activity.market), true);
      expect(farm.canPlay(Activity.fair), false);
      await farm.buy(Capacity.tables);
      await farm.buy(Capacity.tables);
      expect(farm.cash, BigInt.from(50));
      expect(farm.progress.capacity(Capacity.tables), 2);
      farm.start(Activity.market);
      final rules = farm.level.orders!;
      expect(rules.steps, [
        Tool.takeOrder,
        Tool.gather,
        Tool.pack,
        Tool.deliver,
        Tool.collectMoney,
      ]);
      await test.act(Tool.pack);
      expect(farm.orderAt(0), isNull);
      await test.act(Tool.takeOrder, 0);
      await test.act(Tool.takeOrder, 1);
      expect(farm.orderAt(0)!.products, rules.templates.first);
      expect(farm.orderAt(1)!.products, rules.templates[1]);
      expect(farm.canSelectProduct(Goods.eggs), true);
      expect(farm.canSelectProduct(Goods.milk), true);
      expect(farm.canSelectProduct(Goods.honey), false);
      await gatherProduct(test, Goods.milk);
      expect(farm.orderAt(0)!.gathered, 0);
      expect(farm.canApply(1), true);
      await gatherProduct(test, Goods.eggs);
      expect(farm.orderAt(0)!.gatheredProducts, [Goods.eggs]);
      expect(farm.orderAt(1)!.gathered, 0);
      await test.act(Tool.deliver);
      expect(farm.orderAt(0)!.next(rules), Tool.gather);
      await gatherProduct(test, Goods.wheat);
      await test.act(Tool.pack);
      await test.act(Tool.deliver);
      expect(farm.cash, BigInt.from(50));
      store.writeGate = Completer<void>();
      final collect = test.act(Tool.collectMoney);
      await farm.tap(0);
      store.writeGate!.complete();
      await collect;
      await farm.tap(0);
      expect(farm.cash, BigInt.from(58));
      expect(farm.harvested, 1);
      expect(farm.orderAt(0), isNull);
      await fillOrder(test, 1);
      await fillOrder(test);
      await fillOrder(test);
      expect(farm.result.earnings, BigInt.from(32));
      farm.returnToMap();
      expect(farm.canPlay(Activity.fair), true);
    },
  );

  for (final (activity, clear) in [
    (Activity.market, Tool.broom),
    (Activity.fair, Tool.tarp),
  ]) {
    for (final mode in Mode.values) {
      test(
        '${activity.label} hazard in ${mode.label} is isolated and resolves correctly',
        () async {
          const ruleset = GameBalance(spawnChance: 1);
          final progress = FarmProgress.fresh(ruleset)
              .copyWith(mode: mode, completed: through(activity.index))
              .withPurchase(Capacity.tables, 2, BigInt.zero);
          final test = TestFarm(balance: ruleset, progress: progress);
          final farm = test.farm..start(activity);
          final rules = farm.level.orders!;
          await test.act(Tool.takeOrder);
          while (farm.orderAt(0)!.next(rules) != Tool.deliver) {
            await nextStep(test, 0);
          }
          final before = farm.orderAt(0)!;
          farm.targetVisible = (index) => index == 0;
          test.advance(ruleset.safePeriod);
          expect(farm.hazard?.index, 0);
          await test.act(Tool.deliver);
          expect(farm.orderAt(0), same(before));
          await fillOrder(test, 1);
          expect(farm.harvested, 1);
          expect(farm.hazard?.index, 0);
          if (mode == Mode.relaxed) {
            test.advance(ruleset.cooldown);
            expect(farm.hazard?.index, 0);
            await test.act(clear);
            expect(farm.orderAt(0), same(before));
          } else {
            test.advance(ruleset.responseWindow);
            final after = farm.orderAt(0)!;
            if (activity == Activity.market) {
              expect(after.next(rules), Tool.gather);
              expect(after.gathered, before.gathered - 1);
            } else {
              expect(after.next(rules), Tool.weigh);
              expect(after.gathered, before.gathered);
            }
          }
          expect(farm.hazard, isNull);
          await fillOrder(test);
          expect(farm.harvested, 2);
        },
      );
    }
  }

  test('timed fair replay retains paid orders without another ribbon or completion bonus on expiry', () async {
    final test = TestFarm(
      progress: FarmProgress.fresh(balance)
          .copyWith(mode: Mode.timed, completed: through(10)),
    );
    final farm = test.farm..start(Activity.fair);
    await fillOrder(test);
    test.advance(balance.timedDuration);
    expect(farm.result.completed, false);
    expect(farm.result.awardedRibbon, false);
    expect(farm.result.bonus, BigInt.zero);
    expect(farm.cash, BigInt.from(12));
    expect(farm.progress.hasBlueRibbon, true);
    expect(farm.isComplete(Activity.fair), true);
  });

  test('first fair awards one ribbon; expansion save failure and duplicate requests are safe', () async {
    final store = MemoryStore();
    final test = TestFarm(
      store: store,
      progress: FarmProgress.fresh(balance)
          .copyWith(money: BigInt.from(110), completed: through(9)),
    );
    final farm = test.farm;
    expect(farm.canExpand, false);
    await farm.buyNextExpansion(1);
    expect(farm.cash, BigInt.from(110));
    farm.start(Activity.fair);
    expect(farm.level.orders!.steps, [
      Tool.takeOrder,
      Tool.gather,
      Tool.weigh,
      Tool.pack,
      Tool.deliver,
      Tool.collectMoney,
    ]);
    await finishOrders(test);
    expect(farm.result.awardedRibbon, true);
    expect(farm.result.earnings, BigInt.from(60));
    expect(farm.progress.hasBlueRibbon, true);
    farm.returnToMap();
    farm.start(Activity.fair);
    await finishOrders(test);
    expect(farm.result.replay, true);
    expect(farm.result.awardedRibbon, false);
    expect(farm.result.earnings, BigInt.from(60));
    farm.returnToMap();
    store.rejectWrites = true;
    await farm.buyNextExpansion(1);
    expect(farm.progress.expansion, 1);
    expect(store.saved?.expansion, 1);
    expect(farm.cash, BigInt.from(230));
    store.rejectWrites = false;
    store.writeGate = Completer<void>();
    final buy = farm.buyNextExpansion(1);
    await farm.buyNextExpansion(1);
    store.writeGate!.complete();
    await buy;
    await farm.buyNextExpansion(1);
    expect(farm.progress.expansion, 2);
    expect(farm.cash, BigInt.from(130));
    expect(farm.nextExpansionPrice, BigInt.from(200));
    expect(farm.canExpand, false);
    expect(store.saved?.encode(), farm.progress.encode());
    for (final activity in Activity.values) {
      expect(farm.definition(activity).number, activity.index + 11);
      expect(farm.canPlay(activity), activity == Activity.wheat);
      expect(farm.canPlay(activity, expansion: 1), true);
      expect(farm.isComplete(activity, expansion: 1), true);
    }
    expect(farm.definition(Activity.market).unitValue, BigInt.from(10));
    expect(farm.definition(Activity.fair).objective, 7);
    expect(farm.capacityLimit(Capacity.tables), 3);
    farm.start(Activity.wheat);
    await test.complete();
    expect(farm.canPlay(Activity.corn), true);
    expect(farm.isComplete(Activity.wheat), true);
    expect(farm.progress.hasBlueRibbon, true);
  });

  test('starting-capacity first loop earns enough, and two fair replays fund a zero-wallet ribbon holder', () async {
    final test = TestFarm();
    final farm = test.farm;
    for (final activity in Activity.values) {
      expect(farm.canPlay(activity), true);
      farm.start(activity);
      if (farm.level.orders == null) {
        await test.complete();
      } else {
        await finishOrders(test);
      }
      farm.returnToMap();
    }
    expect(farm.cash, BigInt.from(247));
    expect(farm.canExpand, true);
    final spent = TestFarm(
      progress: farm.progress.copyWith(money: BigInt.zero),
    );
    expect(spent.farm.canExpand, false);
    for (var i = 0; i < 2; i++) {
      spent.farm.start(Activity.fair);
      await finishOrders(spent);
      spent.farm.returnToMap();
      expect(spent.farm.canExpand, i == 1);
    }
    expect(spent.farm.cash, BigInt.from(120));
  });

  test('schema 2 reloads progress and persists absolute completions, ribbon and expansion together', () async {
    final dir = await Directory.systemTemp.createTemp('expansion-save-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File.fromUri(dir.uri.resolve('farm-v1.json'));
    final base = FarmProgress.fresh(balance)
        .copyWith(
          money: BigInt.from(120),
          fieldPlots: 6,
          appleTrees: 3,
          mode: Mode.timed,
          completed: through(8),
        )
        .withPurchase(Capacity.bees, 3, BigInt.from(120));
    final legacy = jsonDecode(base.encode()) as Map<String, dynamic>;
    legacy['version'] = 2;
    (legacy['producers'] as Map).remove('tables');
    await file.writeAsString(jsonEncode(legacy));
    final store = FileProgressStore(file);
    final migrated = (await store.load(balance))!;
    expect(migrated.capacity(Capacity.tables), 1);
    expect(migrated.hasBlueRibbon, false);
    expect(migrated.completed, through(8));
    expect(migrated.mode, Mode.timed);
    final test = TestFarm(store: store, progress: migrated);
    final farm = test.farm..start(Activity.market);
    await finishOrders(test);
    farm.returnToMap();
    farm.start(Activity.fair);
    await finishOrders(test);
    expect(farm.result.bonus, BigInt.from(15));
    farm.returnToMap();
    await farm.buyNextExpansion(1);
    farm.start(Activity.wheat);
    await test.complete();
    final restored = (await store.load(balance))!;
    expect(restored.expansion, 2);
    expect(restored.completed, through(11));
    expect(restored.hasBlueRibbon, true);
    expect(restored.unlockedIn(2), 2);
    expect(restored.fieldPlots, 6);
    expect(restored.appleTrees, 3);
    expect(restored.capacity(Capacity.bees), 3);
    final relaunched = TestFarm(progress: restored).farm;
    relaunched.start(Activity.market, expansion: 1);
    expect(relaunched.level.number, 9);
  });
  test('later expansion purchases keep previous partial progress and table ownership', () async {
    final progress = FarmProgress.fresh(balance)
        .copyWith(expansion: 2, completed: through(11))
        .withPurchase(Capacity.tables, 3, BigInt.from(200));
    final test = TestFarm(progress: progress);
    final farm = test.farm;
    expect(farm.canExpand, true);
    await farm.buyNextExpansion(2);
    final restored = FarmProgress.decode(farm.progress.encode(), balance);
    expect(restored.expansion, 3);
    expect(restored.money, BigInt.zero);
    expect(restored.hasBlueRibbon, true);
    expect(restored.capacity(Capacity.tables), 3);
    expect(farm.capacityLimit(Capacity.tables), 4);
    expect(farm.nextExpansionPrice, BigInt.from(400));
    expect(farm.definition(Activity.wheat).number, 21);
    expect(farm.canPlay(Activity.wheat), true);
    expect(farm.canPlay(Activity.corn), false);
    expect(farm.canPlay(Activity.corn, expansion: 2), true);
    expect(farm.isComplete(Activity.corn, expansion: 2), false);
    farm.start(Activity.corn, expansion: 2);
    expect(farm.level.number, 12);
    await test.complete();
    expect(farm.progress.completed, through(12));
    expect(farm.progress.unlockedIn(3), 1);
  });
}
