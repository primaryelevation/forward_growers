import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forward_growers/balance.dart';
import 'package:forward_growers/game.dart';
import 'package:forward_growers/main.dart';
import 'package:forward_growers/progress.dart';
import 'package:forward_growers/screens.dart';

import 'game_test.dart' show MemoryStore;

void main() {
  const balance = GameBalance(spawnChance: 0);
  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets('map, wheat playthrough, results and relaunch at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      Future<({Farm farm, String? notice})> load() async => (
        farm: Farm(
          progress: await store.load(balance) ?? FarmProgress.fresh(balance),
          store: store,
          balance: balance,
          clock: clock.stopwatch(),
        ),
        notice: null,
      );
      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('County Fair'), findsOneWidget);
      expect(find.text('Field plots: 4 / 8'), findsOneWidget);
      expect(find.text('Relaxed Mode'), findsWidgets);
      await tester.tap(find.text('Play'));
      await tester.pump();
      final plots = find.byType(PlotTile);
      expect(plots, findsNWidgets(4));
      expect(find.text('TIME'), findsNothing);

      Future<void> apply(String action) async {
        await tester.tap(find.byTooltip(action));
        await tester.pump();
        for (var i = 0; i < balance.level(1, 1).objective; i++) {
          await tester.tap(plots.at(i));
          await tester.pump();
        }
      }

      await apply('Plow');
      await apply('Plant Wheat');
      await apply('Water');
      await tester.pump(balance.level(1, 1).production!.growth);
      expect(find.text('Ready to harvest'), findsNWidgets(3));
      await apply('Harvest');
      expect(find.text('Objective completed'), findsOneWidget);
      expect(find.text('First completion'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text(r'Wallet $6'), findsOneWidget);
      await tester.tap(find.text('Wheat').first);
      await tester.pump();
      expect(find.text('Replay'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text(r'Wallet $6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact landscape orchard has all tools and separate capacity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore();
    await tester.pumpWidget(
      ForwardGrowers(
        loadFarm: () async => (
          farm: Farm(
            progress: FarmProgress.fresh(balance)
                .copyWith(completed: {1, 2, 3}, mode: Mode.timed),
            store: store,
            balance: balance,
            clock: clock.stopwatch(),
          ),
          notice: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apple trees: 2 / 4'), findsOneWidget);
    expect(find.text('Pick 4 harvests'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);
    expect(find.byType(PlotTile), findsNWidgets(2));
    for (final tool in [
      'Prune',
      'Fertilize',
      'Water',
      'Pick',
      'Orchard Whistle',
    ]) {
      expect(find.byTooltip(tool).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'debug expansion and full-field preview isolate the original farm',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      await tester.pumpWidget(
        ForwardGrowers(
          loadFarm: () async => (
            farm: Farm(
              progress: FarmProgress.fresh(balance),
              store: store,
              balance: balance,
            ),
            notice: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview Expansion 2'));
      await tester.tap(find.text('Preview Expansion 2'));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 2'), findsOneWidget);
      await tester.tap(find.text('Wheat').first);
      await tester.pump();
      expect(find.text('Level 11'), findsOneWidget);
      expect(find.text('Field plots: 4 / 12'), findsOneWidget);
      await tester.ensureVisible(find.text('Exit Debug Expansion'));
      await tester.tap(find.text('Exit Debug Expansion'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview 16 × 16 Field'));
      await tester.tap(find.text('Preview 16 × 16 Field'));
      await tester.pumpAndSettle();

      final tiles = find.byType(PlotTile);
      expect(tiles, findsNWidgets(256));
      expect(tiles.last.hitTestable(), findsOneWidget);
      await tester.tap(tiles.last);
      await tester.pump();
      expect(tester.widget<PlotTile>(tiles.last).plot.stage, Stage.prepared);
      final point = tester.getCenter(tiles.at(119));
      final first = await tester.startGesture(point - const Offset(20, 0));
      final second = await tester.startGesture(point + const Offset(20, 0));
      await first.moveBy(const Offset(-55, 0));
      await second.moveBy(const Offset(55, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('Full Field'), findsNothing);
      expect(tester.widget<PlotTile>(tiles.at(119)).plot.stage, Stage.bare);
      await tester.tap(tiles.at(119));
      await tester.pump();
      expect(tester.widget<PlotTile>(tiles.at(119)).plot.stage, Stage.prepared);
      await tester.tap(find.text('Exit Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('Field plots: 4 / 8'), findsOneWidget);
      expect(store.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mode selection persists and timed expiration returns to the map',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(568, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      await tester.pumpWidget(
        ForwardGrowers(
          loadFarm: () async => (
            farm: Farm(
              progress: FarmProgress.fresh(balance),
              store: store,
              balance: balance,
              clock: clock.stopwatch(),
            ),
            notice: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<Mode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed Challenge').last);
      await tester.pumpAndSettle();
      expect(store.saved?.mode, Mode.timed);
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(balance.timedDuration);
      expect(find.text('Time expired'), findsOneWidget);
      expect(find.text('No completion bonus'), findsOneWidget);
      expect(find.text('Level remains incomplete'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Farm Map · Expansion 1'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'producer panels buy capacity and all four activities play on a compact phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(568, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      await tester.pumpWidget(
        ForwardGrowers(
          loadFarm: () async => (
            farm: Farm(
              progress: FarmProgress.fresh(balance).copyWith(
                money: BigInt.from(40),
                completed: {1, 2, 3, 4, 5, 6, 7},
              ),
              store: store,
              balance: balance,
              clock: clock.stopwatch(),
            ),
            notice: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final activity in [
        Activity.dairy,
        Activity.chickens,
        Activity.sheep,
        Activity.bees,
      ]) {
        await tester.tap(find.text(activity.label).first);
        await tester.pump();
        final level = balance.level(1, activity.index + 1);
        final kind = level.capacity;
        if (activity == Activity.dairy) {
          final buy = find.text(r'Buy cow stall · $35');
          await tester.ensureVisible(buy);
          await tester.tap(buy);
          await tester.pump();
          expect(find.text('Cow stalls: 3 / 4'), findsOneWidget);
        }
        await tester.tap(
          find.text(activity == Activity.bees ? 'Play' : 'Replay'),
        );
        await tester.pump();
        final tiles = find.byType(PlotTile);
        expect(tiles, findsNWidgets(activity == Activity.dairy ? 3 : 2));
        final (first, second, third, collect) = level.production!.actions;
        for (final tool in [
          first,
          second,
          third,
          collect,
          level.production!.hazard.tool,
        ]) {
          expect(find.byTooltip(tool.label).hitTestable(), findsOneWidget);
        }
        for (final tool in [first, second, third, collect]) {
          await tester.tap(find.byTooltip(tool.label));
          await tester.pump();
          await tester.tap(tiles.first);
          await tester.pump();
          if (tool == third) await tester.pump(level.production!.growth);
        }
        expect(tester.widget<PlotTile>(tiles.first).plot.stage, Stage.bare);
        expect(store.saved?.capacity(kind), activity == Activity.dairy ? 3 : 2);
        await tester.tap(find.byTooltip('Pause'));
        await tester.pump();
        await tester.tap(find.text('Leave Attempt'));
        await tester.pump();
      }
      await tester.tap(find.text('Farmers Market').first);
      await tester.pump();
      expect(
        find.text('Complete the previous activity to unlock'),
        findsOneWidget,
      );
      expect(find.text('Play'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bee Yard to ribbon, purchase, Level 11, relaunch and Expansion 1 replay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(568, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore();
      late Farm farm;
      Future<({Farm farm, String? notice})> load() async {
        final progress =
            await store.load(balance) ??
            FarmProgress.fresh(balance)
                .copyWith(completed: {1, 2, 3, 4, 5, 6, 7});
        farm = Farm(
          progress: progress,
          store: store,
          balance: balance,
          clock: clock.stopwatch(),
        );
        return (farm: farm, notice: null);
      }

      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();

      Future<void> apply(Tool tool, Finder tile) async {
        final label = tool == Tool.plant
            ? 'Plant ${farm.level.activity.label}'
            : tool.label;
        final action = find.byTooltip(label);
        if (action.hitTestable().evaluate().isEmpty) {
          await tester.ensureVisible(action);
          await tester.pump();
        }
        await tester.tap(action);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump();
      }

      Future<void> play() async {
        await tester.tap(find.text('Play'));
        await tester.pump();
        final level = farm.level;
        for (var i = 0; i < level.objective; i++) {
          if (level.orders case final rules?) {
            final table = find.byType(OrderTile).first;
            expect(find.text('Next: Take Order'), findsOneWidget);
            await apply(Tool.takeOrder, table);
            final products = farm.orderAt(0)!.products;
            expect(find.text('○ ${products.first.label}'), findsOneWidget);
            while (farm.orderAt(0) != null) {
              final next = farm.orderAt(0)!.next(rules);
              if (next == Tool.gather) {
                final current = farm.orderAt(0)!;
                final product = current.products.firstWhere(current.needs);
                final button = find.byTooltip(product.label);
                await tester.ensureVisible(button);
                await tester.tap(button);
                await tester.pump();
                await tester.tap(table);
                await tester.pump();
              } else {
                await apply(next, table);
              }
            }
          } else {
            final tile = find.byType(PlotTile).first;
            await apply(level.prepare, tile);
            await apply(level.tend, tile);
            await apply(level.beginProduction, tile);
            await tester.pump(level.production!.growth);
            await apply(level.collect, tile);
          }
        }
        expect(find.text('Objective completed'), findsOneWidget);
      }

      Future<void> continueToMap() async {
        await tester.tap(find.text('Continue'));
        await tester.pump();
      }

      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Buy Expansion'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      for (final number in [8, 9, 10]) {
        expect(find.text('Level $number'), findsOneWidget);
        await play();
        expect(farm.level.number, number);
        if (number == 10) {
          expect(find.text('Blue Ribbon awarded!'), findsOneWidget);
        }
        await continueToMap();
      }

      expect(find.byTooltip('Blue Ribbon'), findsOneWidget);
      expect(farm.cash, BigInt.from(122));
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(find.textContaining(r'Price: $100'), findsOneWidget);
      await tester.tap(find.text('Buy Expansion'));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 2'), findsOneWidget);
      expect(find.text('Level 11'), findsOneWidget);
      expect(farm.cash, BigInt.from(22));
      await play();
      expect(farm.level.number, 11);
      await continueToMap();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ForwardGrowers(loadFarm: load));
      await tester.pumpAndSettle();
      expect(find.text('Farm Map · Expansion 2'), findsOneWidget);
      expect(find.text('Level 12'), findsOneWidget);
      expect(find.byTooltip('Blue Ribbon'), findsOneWidget);
      expect(farm.cash, BigInt.from(37));
      await tester.tap(find.byTooltip('Choose Expansion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expansion 1'));
      await tester.pumpAndSettle();
      expect(find.text('Level 10'), findsOneWidget);
      await tester.tap(find.text('Replay'));
      await tester.pump();
      expect(farm.level.number, 10);
      expect(find.byType(OrderTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
